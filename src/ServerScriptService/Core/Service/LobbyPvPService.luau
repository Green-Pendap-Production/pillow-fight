-- @ScriptType: ModuleScript
--[[
    Nama File  : LobbyPvPService.lua
    Layer      : Service
    Deskripsi  : PvP bebas di lobby (opt-in lewat toggle Settings > PvpPanel).
                 Pemain yang PvP-nya ON bisa saling pukul bantal di luar match:
                 tanpa balance/energi/ronde -- kena pukul cuma bikin animasi
                 hurt + knockback. Pemain yang PvP-nya OFF gak bisa mukul dan
                 gak bisa dipukul.

                 Status di-replicate ke client lewat attribute Player (diset
                 SERVER, jadi kebaca semua client):
                   LobbyPvP       = pilihan pemain (toggle ON/OFF)
                   LobbyPvPActive = PvP beneran jalan sekarang (ON + lagi di
                                    lobby, bukan di match/antrean/tutorial)

                 Input tetap lewat AttackFiredEvent yang sama dengan match;
                 CombatController yang nge-route ke sini kalau isActive().
    Tanggal    : 06 November 2026
    Versi      : 1.0
]]

local LobbyPvPService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local PlayerStateRepository = require(ServerScriptService.Core.Repository.PlayerStateRepository)
local HitboxService = require(ServerScriptService.Core.Service.HitboxService)
local VFXService = require(ServerScriptService.Core.Service.VFXService)
local RemoteSafety = require(ServerScriptService.Core.Service.RemoteSafety)

local GameplayConfig = require(ReplicatedStorage.Configs.GameplayConfig)
local HitboxConfig = require(ReplicatedStorage.Configs.HitboxConfig)

local ArenaService -- lazy require (ArenaService ikut nge-require banyak service)

-- ================================================================
-- CONFIG
-- ================================================================
local CONFIG = {
	-- Interval (detik) ngecek ulang status aktif semua pemain. Polling
	-- dipilih ketimbang hook ke tiap jalur masuk match (pad, bot match,
	-- tutorial, abort, respawn...) supaya gak ada jalur yang kelewat.
	TICK = 0.25,

	-- Jeda minimal antar toggle, biar gak bisa di-spam.
	TOGGLE_COOLDOWN = 1,

	-- Habis mukul / kena pukul, PvP gak bisa dimatiin selama ini. Tanpa
	-- ini pemain bisa mukul lalu langsung OFF biar gak bisa dibales.
	COMBAT_TAG = 5,

	-- Toleransi cooldown server terhadap GameplayConfig.COOLDOWNS (jitter
	-- jaringan bikin jarak antar paket bisa sedikit lebih pendek).
	COOLDOWN_TOLERANCE = 0.85,

	-- Knockback: kecepatan horizontal & vertikal (studs/detik) selama
	-- `duration` detik, ngejauh dari penyerang.
	KNOCKBACK = {
		light = { horizontal = 30, vertical = 10, duration = 0.15 },
		heavy = { horizontal = 60, vertical = 28, duration = 0.2 },
	},

	-- Tag "PVP" di atas kepala, di atas badge win streak (StudsOffset 3).
	TAG_OFFSET = Vector3.new(0, 4.6, 0),
	TAG_MAX_DISTANCE = 80,
}

local KNOCKBACK_NAME = "LobbyPvPKnockback"
local TAG_NAME = "LobbyPvPTag"

-- ================================================================
-- STATE
-- ================================================================
-- sessions[player] = {
--     wants, active, lastToggle, lastCombat,
--     cooldowns = {}, flinchUntil, lastDodge, swingId,
-- }
local sessions = {}

local ToggleEvent
local AttackResultEvent

local function newSession()
	return {
		wants = false,
		active = false,
		lastToggle = -math.huge,
		lastCombat = -math.huge,
		cooldowns = {},
		flinchUntil = 0,
		lastDodge = -math.huge,
		swingId = 0,
	}
end

-- ================================================================
-- STATUS
-- ================================================================
local function getAliveHumanoid(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
		return humanoid
	end
	return nil
end

-- Lagi di match (termasuk jeda antar ronde & tutorial), atau berdiri di
-- pad antrean.
local function isBusy(player)
	local state = PlayerStateRepository.get(player)
	if not state then return true end
	if state.isPlaying or state.isInMatchmaking then return true end

	ArenaService = ArenaService or require(ServerScriptService.Core.Service.ArenaService)
	return ArenaService.getOpponent(player) ~= nil
end

local function computeActive(player)
	local s = sessions[player]
	return s ~= nil and s.wants and not isBusy(player) and getAliveHumanoid(player) ~= nil
end

function LobbyPvPService.isActive(player)
	local s = sessions[player]
	-- Dihitung ulang (bukan cuma baca s.active) supaya serangan pertama
	-- setelah match mulai gak sempat nyasar ke sini sebelum tick berikutnya.
	return s ~= nil and s.active and computeActive(player)
end

-- ================================================================
-- TAG & BANTAL
-- ================================================================
local function addTag(character)
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild(TAG_NAME) then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromScale(2.2, 0.8)
	gui.StudsOffset = CONFIG.TAG_OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = CONFIG.TAG_MAX_DISTANCE
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	label.BackgroundTransparency = 0.1
	label.Text = "PVP"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.35, 0)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(90, 10, 10)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label

	gui.Parent = head
end

local function removeTag(character)
	local head = character and character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild(TAG_NAME)
	if tag then
		tag:Destroy()
	end
end

-- Bantal selalu di tangan selama PvP lobby aktif. Kalau pemain unequip
-- manual (Backspace / klik slot), tick berikutnya masang lagi -- tanpa
-- bantal ayunannya cuma meleset dan pemain gak ngerti kenapa.
local function ensurePillowEquipped(player)
	local character = player.Character
	if character and not character:FindFirstChildOfClass("Tool") then
		ArenaService = ArenaService or require(ServerScriptService.Core.Service.ArenaService)
		ArenaService.equipPillow({ player })
	end
end

-- ================================================================
-- UPDATE PER PEMAIN
-- ================================================================
local function update(player)
	local s = sessions[player]
	if not s then return end

	local active = computeActive(player)
	local character = player.Character

	if active then
		ensurePillowEquipped(player)
		addTag(character)
	else
		-- Bantal cuma disimpan kalau PvP-nya dimatiin di lobby. Kalau
		-- nonaktifnya gara-gara masuk match/antrean, ArenaService yang
		-- ngatur bantalnya sendiri.
		if s.active and not isBusy(player) then
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		removeTag(character)
	end

	if s.active ~= active then
		s.active = active
		player:SetAttribute("LobbyPvPActive", active)
	end
end

-- ================================================================
-- KNOCKBACK
-- ================================================================
-- LinearVelocity dibikin di SERVER, di-parent ke root korban. Karakter
-- di-own client korban, jadi set AssemblyLinearVelocity dari server bakal
-- ketimpa -- tapi instance constraint ikut ke-replicate dan disimulasikan
-- client pemiliknya.
local function applyKnockback(attacker, victim, actionType)
	local kb = CONFIG.KNOCKBACK[actionType]
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	local victimRoot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	if not (kb and attackerRoot and victimRoot) then return end

	local offset = victimRoot.Position - attackerRoot.Position
	local direction = Vector3.new(offset.X, 0, offset.Z)
	if direction.Magnitude < 0.01 then
		local look = attackerRoot.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	direction = direction.Unit

	local old = victimRoot:FindFirstChild(KNOCKBACK_NAME)
	if old then
		old:Destroy()
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = KNOCKBACK_NAME

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = direction * kb.horizontal + Vector3.new(0, kb.vertical, 0)
	velocity.MaxForce = math.huge
	velocity.Parent = attachment

	attachment.Parent = victimRoot
	Debris:AddItem(attachment, kb.duration)
end

-- ================================================================
-- COMBAT
-- ================================================================
local function getTargets(attacker)
	local targets = {}
	for player, s in pairs(sessions) do
		if player ~= attacker and s.active and getAliveHumanoid(player) then
			targets[player.Character] = player
		end
	end
	return targets
end

local function resolveHit(attacker, victim, actionType, contact, swingToken)
	local attackerSession = sessions[attacker]
	local victimSession = sessions[victim]
	if not (attackerSession and victimSession) then return end
	if attackerSession.swingId ~= swingToken then return end -- kepotong ayunan baru
	if not (LobbyPvPService.isActive(attacker) and LobbyPvPService.isActive(victim)) then return end

	local now = os.clock()
	attackerSession.lastCombat = now
	victimSession.lastCombat = now

	-- Dodge: aturan i-frame & perfect dodge sama kayak match
	-- (CombatController.resolveHit), minus refund energi.
	local sinceDodge = now - victimSession.lastDodge
	if sinceDodge < GameplayConfig.DODGE_IFRAME then
		if sinceDodge <= GameplayConfig.PERFECT_DODGE_WINDOW then
			attackerSession.flinchUntil = now + GameplayConfig.PERFECT_DODGE_PUNISH
			RemoteSafety.fire(AttackResultEvent, victim, "perfectDodge", true)
			RemoteSafety.fire(AttackResultEvent, attacker, "perfectDodgeHit", true)
		else
			RemoteSafety.fire(AttackResultEvent, victim, "dodgeSuccess", true)
			RemoteSafety.fire(AttackResultEvent, attacker, "dodgeSuccess", true)
		end
		return
	end

	victimSession.flinchUntil = now + (GameplayConfig.FLINCH[actionType] or GameplayConfig.FLINCH.light)

	if actionType == "heavy" then
		RemoteSafety.fire(AttackResultEvent, victim, "heavyHurt", true)
	else
		local variant = (contact and HitboxConfig.HURT_VARIANT_BY_SIDE[contact.side]) or 1
		RemoteSafety.fire(AttackResultEvent, victim, "lightHurt", true, variant)
	end
	RemoteSafety.fire(AttackResultEvent, attacker, "hitConfirm", true, actionType)

	applyKnockback(attacker, victim, actionType)
	VFXService.spawnHitEffect(contact and contact.position, actionType)
end

local function startSwing(attacker, actionType)
	local s = sessions[attacker]
	s.swingId += 1
	local swingToken = s.swingId

	local trail = VFXService.primeSwingTrail(attacker, actionType)

	task.spawn(function()
		local victim, contact = HitboxService.strikeAny(attacker, actionType, function()
			return getTargets(attacker)
		end)
		VFXService.endSwingTrail(trail)

		if victim then
			resolveHit(attacker, victim, actionType, contact, swingToken)
		end
	end)
end

-- Dipanggil CombatController buat AttackFiredEvent kalau isActive(player).
function LobbyPvPService.performAction(player, actionType)
	local s = sessions[player]
	if not s or not LobbyPvPService.isActive(player) then
		RemoteSafety.fire(AttackResultEvent, player, actionType, false)
		return false
	end

	local now = os.clock()

	if actionType ~= "dodge" and now < s.flinchUntil then
		RemoteSafety.fire(AttackResultEvent, player, actionType, false)
		return false
	end

	local cooldown = (GameplayConfig.COOLDOWNS[actionType] or 0) * CONFIG.COOLDOWN_TOLERANCE
	if now - (s.cooldowns[actionType] or -math.huge) < cooldown then
		RemoteSafety.fire(AttackResultEvent, player, actionType, false)
		return false
	end
	s.cooldowns[actionType] = now

	if actionType == "dodge" then
		s.lastDodge = now
	else
		startSwing(player, actionType)
	end

	RemoteSafety.fire(AttackResultEvent, player, actionType, true)
	return true
end

-- ================================================================
-- TOGGLE
-- ================================================================
-- Client -> server: FireServer(wantsPvP: boolean)
-- Server -> client (cuma kalau DITOLAK): FireClient(false, reason)
--   reason = "combat" | "cooldown"
-- Kalau diterima, client cukup dengerin attribute LobbyPvP berubah.
local function onToggle(player, wants)
	if type(wants) ~= "boolean" then return end
	local s = sessions[player]
	if not s or s.wants == wants then return end

	local now = os.clock()
	if now - s.lastToggle < CONFIG.TOGGLE_COOLDOWN then
		RemoteSafety.fire(ToggleEvent, player, false, "cooldown")
		return
	end
	if not wants and s.active and now - s.lastCombat < CONFIG.COMBAT_TAG then
		RemoteSafety.fire(ToggleEvent, player, false, "combat")
		return
	end

	s.lastToggle = now
	s.wants = wants
	player:SetAttribute("LobbyPvP", wants)
	update(player)
end

local function onPlayerAdded(player)
	if sessions[player] then return end
	sessions[player] = newSession()
	player:SetAttribute("LobbyPvP", false)
	player:SetAttribute("LobbyPvPActive", false)
end

function LobbyPvPService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	AttackResultEvent = remotes:WaitForChild("AttackResultEvent")

	ToggleEvent = remotes:FindFirstChild("LobbyPvPToggleEvent")
	if not ToggleEvent then
		ToggleEvent = Instance.new("RemoteEvent")
		ToggleEvent.Name = "LobbyPvPToggleEvent"
		ToggleEvent.Parent = remotes
	end
	ToggleEvent.OnServerEvent:Connect(onToggle)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(CONFIG.TICK)
			for player in pairs(sessions) do
				local ok, err = pcall(update, player)
				if not ok then
					warn("[LobbyPvPService] update gagal untuk " .. player.Name .. ": " .. tostring(err))
				end
			end
		end
	end)

	print("[LobbyPvPService] Berhasil diinisialisasi.")
end

return LobbyPvPService
