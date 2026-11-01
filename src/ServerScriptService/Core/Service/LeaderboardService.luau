--[[
    Nama File  : LeaderboardService.lua
    Layer      : Service
    Penulis    : Rifqi RR / Yusufg Ahaayy
    Deskripsi  : Mengelola akumulasi Win, WinStreak, PlayTime, serta sinkronisasi
                 ke OrderedDataStore dan fetching data untuk papan peringkat global.
    Tanggal    : 13 Agustus 2026
    Versi      : 1.1 (Lengkap dengan TopData Fetcher & Caching)
]]

local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateRepository = require(ServerScriptService.Core.Repository.PlayerStateRepository)
local StreakDisplayService = require(ServerScriptService.Core.Service.StreakDisplayService)

-- ================================================================
-- REALTIME UPDATE SIGNAL
-- ================================================================
-- Dipancarkan (Fire) setiap kali data suatu board (Wins/WinStreak/PlayTime)
-- BERHASIL tersimpan ke OrderedDataStore, supaya LeaderboardDisplayServer bisa
-- langsung refresh papan yang bersangkutan tanpa nunggu loop periodik
-- (yang cuma jalan tiap REFRESH_INTERVAL detik). Loop periodik tetap jalan
-- sebagai fallback/full-sync, event ini cuma bikin papan kerasa realtime.
LeaderboardService.BoardUpdated = Instance.new("BindableEvent")

-- ORDERED DATASTORES (Papan Peringkat Global)
local WinsOrderedDS = DataStoreService:GetOrderedDataStore("Leaderboard_TotalWins_v1")
local WinStreakOrderedDS = DataStoreService:GetOrderedDataStore("Leaderboard_WinStreak_v1")
local PlayTimeOrderedDS = DataStoreService:GetOrderedDataStore("Leaderboard_PlayTime_v1")

-- RAM TRACKING
local sessionStartTimes = {}
local usernameCache = {}

-- Player Studio test-client (Test > Local Server / multi-client) dikasih
-- UserId NEGATIF sama Roblox, bukan akun asli. Kalau ini gak difilter,
-- setiap kali dev nge-test di Studio, entry "-1"/"-2"/dst ikut ke-SetAsync
-- ke OrderedDataStore PRODUCTION (yang sama dipakai game live) --
-- GetNameFromUserIdAsync buat UserId negatif itu pasti gagal (bukan akun
-- asli), jatuh ke fallback "Player_" .. userId, makanya leaderboard keliatan
-- kotor "Player_-1"/"Player_-2" dst. Guard ini nyegah tulisan dari sumbernya.
local function isRealPlayer(player)
	return player.UserId > 0
end

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- ================================================================
-- HELPER: CONVERT SECONDS TO "X hari Y jam Z menit"
-- ================================================================
function LeaderboardService.formatPlayTime(totalSeconds)
	totalSeconds = math.max(0, math.floor(totalSeconds or 0))

	local days = math.floor(totalSeconds / 86400)
	local hours = math.floor((totalSeconds % 86400) / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)

	-- Format Opsi A (Lengkap):
	return string.format("%d hari %d jam %d menit", days, hours, minutes)

	-- Format Opsi B (Singkat/Ringkas jika papannya sempit):
	-- return string.format("%dd %dh %dm", days, hours, minutes)
end

-- Helper: Mengambil nama pemain dari UserId dengan caching RAM
local function getPlayerName(userId)
	if usernameCache[userId] then
		return usernameCache[userId]
	end

	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success and name then
		usernameCache[userId] = name
		return name
	end

	return "Player_" .. tostring(userId)
end

-- ================================================================
-- 1. WIN & WINSTREAK MANAGEMENT
-- ================================================================

-- Dipanggil saat pemain MEMENANGKAN pertandingan
function LeaderboardService.recordWin(player)
	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	local currentWins = (state.totalWins or 0) + 1
	local currentStreak = (state.winStreak or 0) + 1
	local bestStreak = state.bestWinStreak or 0

	-- Update RAM State
	PlayerStateRepository.set(player, "totalWins", currentWins)
	PlayerStateRepository.set(player, "winStreak", currentStreak)
	PlayerStateRepository.set(player, "sessionWins", (state.sessionWins or 0) + 1)

	-- Update badge streak di atas kepala (di atas nametag) -- badge pakai
	-- streak yang JALAN SEKARANG, bukan rekor tertinggi
	StreakDisplayService.updateStreak(player, currentStreak)

	-- Cek apakah rekor baru dipecahkan. Leaderboard WinStreak nyimpen REKOR
	-- TERTINGGI per UID (bukan streak yang lagi jalan), jadi begitu pemain
	-- kalah dan streak-nya reset, angka di leaderboard TETAP rekor terbaiknya
	-- -- gak ikut ke-reset ke 0.
	local isNewRecord = currentStreak > bestStreak
	if isNewRecord then
		bestStreak = currentStreak
		PlayerStateRepository.set(player, "bestWinStreak", bestStreak)
	end

	-- Update Global OrderedDataStore (Async safe)
	-- Skip kalau ini test-client Studio (UserId negatif) -- lihat catatan
	-- isRealPlayer() di atas kenapa ini penting.
	if isRealPlayer(player) then
		task.spawn(function()
			local success, err = pcall(function()
				WinsOrderedDS:SetAsync(tostring(player.UserId), currentWins)
				if isNewRecord then
					WinStreakOrderedDS:SetAsync(tostring(player.UserId), bestStreak)
				end
			end)

			if success then
				-- Baru pancarkan sinyal SETELAH SetAsync beneran sukses, supaya pas
				-- LeaderboardDisplayServer nge-query ulang, datanya udah kebaca.
				LeaderboardService.BoardUpdated:Fire("Wins")
				if isNewRecord then
					LeaderboardService.BoardUpdated:Fire("WinStreak")
				end
			else
				warn(
					"[LeaderboardService] GAGAL menyimpan Wins/WinStreak untuk " .. player.Name .. ": " .. tostring(err)
				)
			end
		end)
	end

	print(
		string.format(
			"[LeaderboardService] %s Menang! Total Wins: %d | Streak: %d | Rekor Terbaik: %d",
			player.Name,
			currentWins,
			currentStreak,
			bestStreak
		)
	)
end

-- Dipanggil saat pemain KALAH pertandingan
function LeaderboardService.recordLoss(player)
	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	-- Reset WinStreak (streak yang lagi jalan) ke 0.
	-- CATATAN: Leaderboard_WinStreak_v1 TIDAK ikut di-reset di sini, karena
	-- yang disimpan di sana adalah REKOR TERTINGGI pemain (bestWinStreak),
	-- bukan streak yang sedang berjalan. Kalau kalah, cuma streak lokal yang
	-- reset -- rekor di leaderboard tetap seperti terakhir kali dia pecahkan.
	PlayerStateRepository.set(player, "winStreak", 0)

	-- Hilangkan badge streak di atas kepala (karena streak yang lagi jalan udah balik ke 0)
	StreakDisplayService.updateStreak(player, 0)

	print(
		string.format(
			"[LeaderboardService] %s Kalah! WinStreak di-reset ke 0 (rekor terbaik %d tetap tersimpan).",
			player.Name,
			state.bestWinStreak or 0
		)
	)
end

-- ================================================================
-- 2. PLAYING TIME MANAGEMENT (Session Based)
-- ================================================================

-- Dipanggil dari PlayerAdded / Init
function LeaderboardService.onPlayerJoined(player)
	sessionStartTimes[player.UserId] = os.time()
end

-- Dipanggil dari PlayerRemoving (Saat Pemain Keluar)
function LeaderboardService.onPlayerLeaving(player)
	local startTime = sessionStartTimes[player.UserId]
	if not startTime then
		return
	end

	local sessionDuration = os.time() - startTime
	sessionStartTimes[player.UserId] = nil

	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	local currentTotalPlayTime = (state.totalPlayTime or 0) + sessionDuration
	PlayerStateRepository.set(player, "totalPlayTime", currentTotalPlayTime)

	PlayerStateRepository.set(player, "sessionPlayTime", (state.sessionPlayTime or 0) + sessionDuration)
	-- Simpan Total Waktu (dalam detik) ke OrderedDataStore -- skip kalau
	-- test-client Studio (UserId negatif), lihat isRealPlayer() di atas.
	if isRealPlayer(player) then
		local success, err = pcall(function()
			PlayTimeOrderedDS:SetAsync(tostring(player.UserId), currentTotalPlayTime)
		end)

		if success then
			LeaderboardService.BoardUpdated:Fire("PlayTime")
		else
			warn("[LeaderboardService] GAGAL menyimpan PlayTime untuk " .. player.Name .. ": " .. tostring(err))
		end
	end

	print(
		string.format(
			"[LeaderboardService] %s Keluar. Tambahan waktu: %ds | Total: %s",
			player.Name,
			sessionDuration,
			LeaderboardService.formatPlayTime(currentTotalPlayTime)
		)
	)
end

-- ================================================================
-- 3. FETCH DATA FOR LEADERBOARD DISPLAY
-- ================================================================

-- Dipanggil oleh LeaderboardDisplayServer untuk mengambil Top Players
function LeaderboardService.getTopData(boardType, maxAmount)
	maxAmount = maxAmount or 10
	local targetDS = nil

	if boardType == "Wins" then
		targetDS = WinsOrderedDS
	elseif boardType == "WinStreak" then
		targetDS = WinStreakOrderedDS
	elseif boardType == "PlayTime" then
		targetDS = PlayTimeOrderedDS
	end

	if not targetDS then
		warn("[LeaderboardService] Tipe board tidak dikenal: " .. tostring(boardType))
		return {}
	end

	local success, pages = pcall(function()
		return targetDS:GetSortedAsync(false, maxAmount)
	end)

	if not success or not pages then
		warn("[LeaderboardService] Gagal mengambil data DataStore untuk: " .. tostring(boardType))
		return {}
	end

	local topList = {}
	local entries = pages:GetCurrentPage()

	for rank, data in ipairs(entries) do
		local userId = tonumber(data.key)
		local rawValue = tonumber(data.value) or 0
		local name = getPlayerName(userId)

		local formattedValue = tostring(rawValue)
		if boardType == "PlayTime" then
			formattedValue = LeaderboardService.formatPlayTime(rawValue)
		elseif boardType == "Wins" then
			formattedValue = rawValue .. " Wins"
		elseif boardType == "WinStreak" then
			formattedValue = rawValue .. " Streak"
		end

		table.insert(topList, {
			Rank = rank,
			Name = name,
			Value = formattedValue,
		})
	end

	return topList
end

return LeaderboardService
