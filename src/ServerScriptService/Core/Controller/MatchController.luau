-- @ScriptType: ModuleScript
--[[
	Nama File : MatchController
	Layer     : Controller (ServerScriptService/Core/Controller)
	Deskripsi : Menyambungkan pad teleporter arena di lobby
	            (Workspace.World.Environment.PillowArena.<ArenaTeleporterN>.Teleporter)
	            ke MatchmakingService. Begitu karakter pemain nginjek pad,
	            pemain dimasukkan ke antrean arena tsb -- countdown, kunci
	            gerakan, tombol "LAWAN BOT", auto-bot, dan batal lewat Jump
	            semuanya ditangani MatchmakingService.
	Catatan   : File ini sebelumnya ketimpa isi PlayerStateRepository, jadi
	            MatchController.init() malah manggil PlayerStateRepository.init(nil)
	            dan crash "attempt to index nil with 'UserId'" -- akibatnya pad
	            teleporter mati total (gak ada countdown, gak ada tombol).
	Dependensi: MatchmakingService, PlayerStateRepository, ArenaService, BotService
]]

local MatchController = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = ServerScriptService.Core
local PlayerStateRepository = require(Core.Repository.PlayerStateRepository)
local MatchmakingService = require(Core.Service.MatchmakingService)

local ArenaService -- lazy (hindari circular require)

local WAIT_TIMEOUT = 10

-- Setelah keluar antrean (Jump-cancel), pemain biasanya mendarat lagi di
-- pad yang sama -> Touched nembak lagi -> langsung ke-queue ulang & gak
-- bisa keluar. Jeda ini mencegah itu. Saat match mulai, jeda ini juga
-- ke-set, tapi sudah lama habis begitu match selesai.
local REQUEUE_COOLDOWN = 3
local WATCH_INTERVAL = 0.25

local registeredTeleporters = {} -- [BasePart] = true
local pendingJoin = {} -- [Player] = true selagi addPlayerToQueue lagi diproses
local requeueBlockedUntil = {} -- [Player] = os.clock()

local function getPlayerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return player
end

local function canJoinQueue(player)
	if pendingJoin[player] then
		return false
	end
	if os.clock() < (requeueBlockedUntil[player] or 0) then
		return false
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return false -- data belum ke-load
	end
	if state.isPlaying or state.isInMatchmaking then
		return false
	end

	ArenaService = ArenaService or require(Core.Service.ArenaService)
	if ArenaService.getOpponent and ArenaService.getOpponent(player) ~= nil then
		return false
	end

	return true
end

-- Pantau sampai pemain keluar antrean (Jump / mati / match mulai), lalu
-- pasang jeda requeue.
local function watchQueueExit(player)
	task.spawn(function()
		while player.Parent do
			local state = PlayerStateRepository.get(player)
			if not state or not state.isInMatchmaking then
				break
			end
			task.wait(WATCH_INTERVAL)
		end
		requeueBlockedUntil[player] = os.clock() + REQUEUE_COOLDOWN
	end)
end

local function onTeleporterTouched(arenaTeleporterName, hit)
	local player = getPlayerFromHit(hit)
	if not player or not canJoinQueue(player) then
		return
	end

	-- addPlayerToQueue bisa yield (cek cooldown farming via DataStore), jadi
	-- jalankan di thread sendiri & guard supaya belasan Touched dari tiap
	-- BasePart karakter gak bikin request dobel.
	pendingJoin[player] = true
	task.spawn(function()
		local ok, err = pcall(MatchmakingService.addPlayerToQueue, player, arenaTeleporterName)
		pendingJoin[player] = nil

		if not ok then
			warn("[MatchController] addPlayerToQueue gagal untuk " .. player.Name .. ": " .. tostring(err))
			return
		end

		local state = PlayerStateRepository.get(player)
		if state and state.isInMatchmaking then
			watchQueueExit(player)
		end
	end)
end

local function registerArenaTeleporter(arenaFolder)
	if not arenaFolder:IsA("Folder") and not arenaFolder:IsA("Model") then
		return
	end

	task.spawn(function()
		local teleporter = arenaFolder:WaitForChild("Teleporter", WAIT_TIMEOUT)
		if not teleporter or not teleporter:IsA("BasePart") or registeredTeleporters[teleporter] then
			return
		end
		registeredTeleporters[teleporter] = true

		local arenaTeleporterName = arenaFolder.Name
		teleporter.Touched:Connect(function(hit)
			onTeleporterTouched(arenaTeleporterName, hit)
		end)

		teleporter.Destroying:Connect(function()
			registeredTeleporters[teleporter] = nil
		end)
	end)
end

function MatchController.init()
	Players.PlayerRemoving:Connect(function(player)
		pendingJoin[player] = nil
		requeueBlockedUntil[player] = nil
	end)

	task.spawn(function()
		local world = Workspace:WaitForChild("World", WAIT_TIMEOUT)
		local env = world and world:WaitForChild("Environment", WAIT_TIMEOUT)
		local pillowArena = env and env:WaitForChild("PillowArena", WAIT_TIMEOUT)
		if not pillowArena then
			warn(
				"[MatchController] Workspace.World.Environment.PillowArena tidak ditemukan -- pad teleporter tidak aktif."
			)
			return
		end

		pillowArena.ChildAdded:Connect(registerArenaTeleporter)
		for _, child in ipairs(pillowArena:GetChildren()) do
			registerArenaTeleporter(child)
		end

		print("[MatchController] Pad teleporter arena aktif.")
	end)
end

return MatchController
