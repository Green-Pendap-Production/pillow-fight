-- @ScriptType: ModuleScript
--[[
    Nama File  : CoinService.lua
    Layer      : Service
    Deskripsi  : Mengelola virtual coin pemain: kasih reward tiap match selesai,
                 nambah/ngurangin saldo, dan sinkron ke client.

                 Sinkron ke client lewat 2 jalur:
                 - Attribute "Coins" di Player -> saldo terkini. Attribute
                   otomatis ke-replicate (termasuk ke client yang baru join /
                   script UI yang telat jalan), jadi gak perlu handshake.
                 - CoinRewardEvent -> cuma buat popup "+X coin" + breakdown-nya
                   pas match selesai.

                 Persistensi ke DataStore diurus PlayerDataService (field
                 "coins"), pakai pola delta-save yang sama kayak totalWins:
                 yang disimpan "nilai lama di DataStore + sessionCoinsDelta".
    Tanggal    : 17 Oktober 2026
    Versi      : 1.0
]]

local CoinService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateRepository = require(ServerScriptService.Core.Repository.PlayerStateRepository)
local RemoteSafety = require(ServerScriptService.Core.Service.RemoteSafety)
local CoinConfig = require(ReplicatedStorage.Configs.CoinConfig)

local COINS_ATTRIBUTE = "Coins"

local CoinRewardEvent

function CoinService.init()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	CoinRewardEvent = remotesFolder:FindFirstChild("CoinRewardEvent")
	if not CoinRewardEvent then
		CoinRewardEvent = Instance.new("RemoteEvent")
		CoinRewardEvent.Name = "CoinRewardEvent"
		CoinRewardEvent.Parent = remotesFolder
	end

	print("[CoinService] Berhasil diinisialisasi.")
end

local function syncAttribute(player, coins)
	if RemoteSafety.isRealPlayer(player) then
		player:SetAttribute(COINS_ATTRIBUTE, coins)
	end
end

-- Dipanggil PlayerDataService.loadData setelah "coins" diisi dari DataStore.
function CoinService.onDataLoaded(player)
	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end
	syncAttribute(player, state.coins or 0)
end

function CoinService.getCoins(player)
	local state = PlayerStateRepository.get(player)
	return state and state.coins or 0
end

-- Tambah coin. amount harus positif; return saldo baru (atau nil kalau gagal).
function CoinService.addCoins(player, amount, reason)
	if RemoteSafety.isBot(player) then
		return nil
	end
	if type(amount) ~= "number" or amount <= 0 then
		return nil
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return nil
	end

	amount = math.floor(amount)
	local newCoins = (state.coins or 0) + amount
	PlayerStateRepository.set(player, "coins", newCoins)
	PlayerStateRepository.set(player, "sessionCoinsDelta", (state.sessionCoinsDelta or 0) + amount)
	syncAttribute(player, newCoins)

	print(string.format("[CoinService] %s +%d coin (%s). Saldo: %d", player.Name, amount, reason or "-", newCoins))
	return newCoins
end

-- Kurangi coin (buat shop/kosmetik nanti). Return true kalau saldo cukup &
-- berhasil dipotong, false kalau saldo kurang -- saldo gak pernah minus.
function CoinService.spendCoins(player, amount, reason)
	if RemoteSafety.isBot(player) then
		return false
	end
	if type(amount) ~= "number" or amount <= 0 then
		return false
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return false
	end

	amount = math.floor(amount)
	local current = state.coins or 0
	if current < amount then
		return false
	end

	local newCoins = current - amount
	PlayerStateRepository.set(player, "coins", newCoins)
	PlayerStateRepository.set(player, "sessionCoinsDelta", (state.sessionCoinsDelta or 0) - amount)
	syncAttribute(player, newCoins)

	print(string.format("[CoinService] %s -%d coin (%s). Saldo: %d", player.Name, amount, reason or "-", newCoins))
	return true
end

-- ================================================================
-- REWARD MATCH
-- ================================================================
-- Hitung reward + breakdown buat satu pemain. Breakdown dikirim ke client
-- apa adanya buat ditampilin, jadi label-nya dibikin di sini.
local function computeReward(player, didWin, isBotMatch, forfeited)
	local breakdown = {}

	if isBotMatch then
		local base = didWin and CoinConfig.BOT_WIN or CoinConfig.BOT_LOSS
		if base > 0 then
			table.insert(breakdown, { label = didWin and "Win vs Bot" or "Played vs Bot", amount = base })
		end
	elseif didWin then
		table.insert(breakdown, { label = "Win", amount = CoinConfig.PVP_WIN })

		-- winStreak di sini udah ke-update sama LeaderboardService.recordWin
		-- (endMatch manggil itu duluan). Streak 1 = gak ada bonus.
		local state = PlayerStateRepository.get(player)
		local streak = state and state.winStreak or 0
		if streak >= 2 then
			local bonus = math.min((streak - 1) * CoinConfig.STREAK_BONUS_PER_WIN, CoinConfig.STREAK_BONUS_MAX)
			table.insert(breakdown, { label = "Streak x" .. streak, amount = bonus })
		end
	else
		local base = forfeited and CoinConfig.FORFEIT_LOSS or CoinConfig.PVP_LOSS
		if base > 0 then
			table.insert(breakdown, { label = "Participation", amount = base })
		end
	end

	local total = 0
	for _, item in ipairs(breakdown) do
		total += item.amount
	end
	return total, breakdown
end

local function rewardPlayer(player, didWin, isBotMatch, forfeited)
	if not player or RemoteSafety.isBot(player) then
		return
	end

	local total, breakdown = computeReward(player, didWin, isBotMatch, forfeited)
	if total > 0 then
		CoinService.addCoins(player, total, didWin and "match win" or "match loss")
	end

	-- Tetap dikirim walau total 0, biar client bisa nampilin hasil match
	-- secara konsisten (mis. "+0" vs bot pas kalah).
	RemoteSafety.fire(CoinRewardEvent, player, {
		total = total,
		didWin = didWin,
		breakdown = breakdown,
		balance = CoinService.getCoins(player),
	})
end

-- Dipanggil ArenaService.endMatch (match beneran selesai dengan pemenang).
-- Match yang di-invalidate/abort sengaja TIDAK lewat sini -> gak ada coin.
--   opts.isBotMatch     : match vs bot (reward kecil, gak ada streak bonus)
--   opts.loserForfeited : loser kalah karena AFK / reset karakter
function CoinService.awardMatchResult(winner, loser, opts)
	opts = opts or {}
	rewardPlayer(winner, true, opts.isBotMatch, false)
	rewardPlayer(loser, false, opts.isBotMatch, opts.loserForfeited)
end

return CoinService
