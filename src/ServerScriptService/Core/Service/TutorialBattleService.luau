-- @ScriptType: ModuleScript
--[[
	Nama File : TutorialBattleService
	Layer     : Service
	Deskripsi : Battle tutorial vs bot dengan "Coach Bantal".
	            Tahap: ATTACK x2 -> ENERGI (tips) -> DODGE x2 (slow-mo, freeze sampai Q)
	                   -> HEAVY x2 (bot stun) -> FREE (easy) sampai menang.
	            Tiap tahap: Setup -> Coba -> Reward -> Napas.
	            Memakai ArenaService dengan opts {tutorial = true, winsNeeded = 1}.
	            Hanya 1 tutorial aktif sekaligus (map belum di-clone per pemain).
	Dependensi: - Workspace > TutorialMapTemplate > Arenas > BattleArena (SpawnPoint1/2)
	            - ReplicatedStorage > Remotes > TutorialPromptEvent (dibuat otomatis)
]]

local TutorialBattleService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Core = ServerScriptService.Core
local PlayerStateRepository = require(Core.Repository.PlayerStateRepository)
local RemoteSafety = require(Core.Service.RemoteSafety)
local BotAnimationService = require(Core.Service.BotAnimationService)
local VFXService = require(Core.Service.VFXService)
local CombatController = require(Core.Controller.CombatController)

local BalanceConfig = require(ReplicatedStorage.Configs.BalanceConfig)
local EnergyConfig = require(ReplicatedStorage.Configs.EnergyConfig)
local TutorialConfig = require(ReplicatedStorage.Configs.TutorialConfig)
local ArenaService, BotService -- lazy require (hindari circular dependency)

local CONFIG = {
	REPS = 2, -- berhasil berapa kali per tahap
	CONTINUE_TIMEOUT = 20, -- tombol Lanjut auto-lanjut kalau pemain diam
	REWARD_SECONDS = 2.2, -- minimal reward tampil
	BREATH_SECONDS = 1.6,

	WINDUP_SECONDS = 0.25, -- bot mengangkat bantal sebelum dibekukan
	SLOWMO_SPEED = { 0.05, 0.12 }, -- percobaan 1 lebih lambat, percobaan 2 lebih cepat
	DODGE_TIMEOUT = { 8, 4 }, -- detik menunggu Q (freeze)
	DODGE_SWING_DELAY = 0.12,
	HIT_RESOLVE_WAIT = 1.0,
	HIT_CHECK_TIMEOUT = 1.5,
	HEAVY_ENERGY_WAIT = 2.5, -- napas sebelum heavy supaya energi sempat pulih

	EASY_ATTACK_MIN = 4,
	EASY_ATTACK_MAX = 6,
	EASY_HEAVY_CHANCE = 0.15,
	IDLE_RESET_SECONDS = 10, -- player diam segini lama di mode FREE -> HP kedua pihak di-reset
}

-- Teks Coach (galak tapi lucu, POV Mr. Noob vs Player). Nilai berupa list = dipilih acak. Edit sesuka hati.
local LINES = {
	attackIntro = "Ayo mulai. Klik kiri buat pukul aku.",
	attackAgain = "Sekali lagi.",
	miss = {
		"Angin doang itu. Deketin lagi.",
		"Meleset. Majuin lagi.",
		"Kurang dekat, maju dikit.",
	},
	attackReward = {
		"Nah, kena.",
		"Pas. Lumayan juga.",
		"Bagus, gitu terus.",
		"Masuk!",
	},

	energy = "Perhatiin energimu. Tiap mukul butuh energi, kalau habis kamu bakal pusing.",

	dodgeIntro = "Sekarang giliranku mukul. Siapin jari di tombol Q.",
	dodgeNow = {
		"Awas! Tekan Q!",
		"Sekarang! Q!",
		"Hindar! Tekan Q!",
	},
	dodgeAgain = "Lagi. Kali ini kuayun lebih cepat.",
	dodgeFail = {
		"Kena kan. Tunggu aku ayun dulu, baru Q.",
		"Kecepetan atau telat tuh. Coba lagi.",
		"Liat bantalku pas mau kena, baru Q.",
	},
	dodgeReward = {
		"Licin.",
		"Mulus, gak kena sama sekali.",
		"Pas banget timingnya.",
		"Mantap, gitu cara hindarnya.",
	},

	heavyIntro = "Aku lagi kehabisan napas. Klik kanan buat pukulan berat.",
	heavyAgain = "Sekali lagi, yang keras.",
	heavyReward = {
		"Telak! Damage gede, tapi energinya juga boros.",
		"Mantap. Pakai pas aku lengah aja ya.",
		"Kena telak tuh.",
	},

	idleReset = "Kok bengong? Darah kuisi lagi, ayo gerak.",
	free = "Latihan beres. Sekarang coba tumbangin aku beneran.",
	done = "Mantap, kamu berhasil ngalahin aku. Sana buktiin di arena.",
}

local promptEvent
local initialized = false
-- Manajemen slot dinamis koordinat arena tutorial
local BASE_OFFSET = Vector3.new(6000, 120, 0) -- Jauh dari lobby sejak slot pertama
local SLOT_DISTANCE = 3500 -- Jarak antar arena tutorial (3500 studs saling berjauhan)
local occupiedSlots = {} -- [slotIndex] = true
local activeSessions = {} -- [player] = session table

local NOOB_YELLOW = Color3.fromRGB(245, 205, 48)
local NOOB_BLUE = Color3.fromRGB(13, 105, 172)
local NOOB_GREEN = Color3.fromRGB(164, 189, 71)

local function applyNoobSkinToModel(model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("Accessory") then
			child:Destroy()
		end
	end

	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Name = "Body Colors"
		bodyColors.Parent = model
	end
	bodyColors.HeadColor3 = NOOB_YELLOW
	bodyColors.LeftArmColor3 = NOOB_YELLOW
	bodyColors.RightArmColor3 = NOOB_YELLOW
	bodyColors.TorsoColor3 = NOOB_BLUE
	bodyColors.LeftLegColor3 = NOOB_GREEN
	bodyColors.RightLegColor3 = NOOB_GREEN

	local yellowParts = {
		"Head",
		"Left Arm",
		"Right Arm",
		"LeftUpperArm",
		"LeftLowerArm",
		"LeftHand",
		"RightUpperArm",
		"RightLowerArm",
		"RightHand",
	}
	local blueParts = { "Torso", "UpperTorso", "LowerTorso" }
	local greenParts = {
		"Left Leg",
		"Right Leg",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"LeftFoot",
		"RightUpperLeg",
		"RightLowerLeg",
		"RightFoot",
	}

	for _, name in ipairs(yellowParts) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = NOOB_YELLOW
		end
	end
	for _, name in ipairs(blueParts) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = NOOB_BLUE
		end
	end
	for _, name in ipairs(greenParts) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = NOOB_GREEN
		end
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Dynamic Head R15 (MeshPart dengan FaceControls) tidak cocok dengan UV Decal face.png
		if not head:FindFirstChildOfClass("FaceControls") then
			if head:IsA("MeshPart") then
				head.TextureID = ""
			end
			local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
			if not face then
				face = Instance.new("Decal")
				face.Name = "face"
				face.Face = Enum.NormalId.Front
				face.Parent = head
			end
			face.Texture = "rbxasset://textures/face.png"
		end
	end
end

local function ensureTutorialArenaStructure(container)
	if container:FindFirstChild("BattleArena", true) then
		return
	end

	local floor = Instance.new("Part")
	floor.Name = "TutorialFloor"
	floor.Size = Vector3.new(68, 4, 68)
	floor.Anchored = true
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(76, 152, 62)
	floor.CFrame = CFrame.new(0, -2, 0)
	floor.Parent = container

	local trim = Instance.new("Part")
	trim.Name = "TutorialTrim"
	trim.Size = Vector3.new(72, 2, 72)
	trim.Anchored = true
	trim.Material = Enum.Material.WoodPlanks
	trim.Color = Color3.fromRGB(162, 126, 74)
	trim.CFrame = CFrame.new(0, -2.5, 0)
	trim.Parent = container

	local arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = container

	local battleArena = Instance.new("Folder")
	battleArena.Name = "BattleArena"
	battleArena.Parent = arenasFolder

	local sp1 = Instance.new("Seat")
	sp1.Name = "SpawnPoint1"
	sp1.Size = Vector3.new(2, 1, 2)
	sp1.Transparency = 1
	sp1.Anchored = true
	sp1.CanCollide = false
	sp1.Disabled = false
	sp1.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -5), Vector3.new(0, 0.5, 5))
	sp1.Parent = battleArena

	local sp2 = Instance.new("Seat")
	sp2.Name = "SpawnPoint2"
	sp2.Size = Vector3.new(2, 1, 2)
	sp2.Transparency = 1
	sp2.Anchored = true
	sp2.CanCollide = false
	sp2.Disabled = false
	sp2.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 5), Vector3.new(0, 0.5, -5))
	sp2.Parent = battleArena
end

local function acquireSlot()
	local slot = 0
	while occupiedSlots[slot] do
		slot += 1
	end
	occupiedSlots[slot] = true
	return slot
end

local function releaseSlot(slot)
	occupiedSlots[slot] = nil
end

local function offsetInstance(inst, offset)
	if offset == Vector3.zero then
		return
	end
	for _, desc in ipairs(inst:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CFrame = desc.CFrame + offset
		end
	end
	if inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + offset
	end
end

local function getState(player)
	return PlayerStateRepository.get(player)
end

local function ensureState(player)
	local ps = PlayerStateRepository.get(player)
	if not ps and player and player.Parent == Players then
		PlayerStateRepository.init(player)
		ps = PlayerStateRepository.get(player)
	end
	return ps
end

local function getPromptEvent()
	if promptEvent and promptEvent.Parent then
		return promptEvent
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
	if not remotes then
		return nil
	end
	promptEvent = remotes:FindFirstChild("TutorialPromptEvent")
	if not promptEvent then
		promptEvent = Instance.new("RemoteEvent")
		promptEvent.Name = "TutorialPromptEvent"
		promptEvent.Parent = remotes
	end
	return promptEvent
end

local function pick(list)
	if type(list) == "string" then
		return list
	end
	return list[math.random(#list)]
end

-- Waktu tampil prompt otomatis: efek ketik + waktu baca, menyesuaikan panjang teks
local function readTime(text)
	local n = utf8.len(text) or #text
	return math.max(3, n * 0.022 + 1.8 + n * 0.045)
end

-- data: {text, key, cont, stage, rep, repTotal, action, mood}
local function say(s, text, key, canContinue, meta)
	local payload = {
		text = text,
		key = key,
		cont = canContinue,
	}
	if type(meta) == "table" then
		for k, v in pairs(meta) do
			payload[k] = v
		end
	end
	RemoteSafety.fire(getPromptEvent(), s.player, "show", payload)
end

local function hidePrompt(s)
	RemoteSafety.fire(getPromptEvent(), s.player, "hide")
end

local function fx(s, kind)
	RemoteSafety.fire(getPromptEvent(), s.player, "fx", kind)
end

-- Isi penuh HP (balance) dan energi kedua pihak, lalu sinkronkan ke UI pemain
local function resetBalances(s)
	local remotes = ReplicatedStorage.Remotes
	local maxHp, maxEnergy = BalanceConfig.MAX_BALANCE, EnergyConfig.MAX_ENERGY

	for _, who in ipairs({ s.player, s.bot }) do
		PlayerStateRepository.set(who, "balance", maxHp)
		PlayerStateRepository.set(who, "energy", maxEnergy)
		PlayerStateRepository.set(who, "isStun", false)
		PlayerStateRepository.set(who, "isFFYL", false)
		PlayerStateRepository.set(who, "isAlive", true)
	end

	RemoteSafety.fire(remotes.SyncBalanceEvent, s.player, maxHp)
	RemoteSafety.fire(remotes.SyncEnergyEvent, s.player, maxEnergy)
	RemoteSafety.fire(remotes.SyncOpponentStatsEvent, s.player, "balance", maxHp)
	RemoteSafety.fire(remotes.SyncOpponentStatsEvent, s.player, "energy", maxEnergy)
end

local function setAllowed(s, actions)
	PlayerStateRepository.set(s.player, "allowedActions", actions)
end

local function waitFor(live, condition, timeout)
	local startedAt = os.clock()
	while live() do
		if condition() then
			return true
		end
		if timeout and os.clock() - startedAt >= timeout then
			return false
		end
		task.wait(0.05)
	end
	return false
end

local function pause(live, seconds)
	local startedAt = os.clock()
	while live() and os.clock() - startedAt < seconds do
		task.wait(0.05)
	end
end

local function cleanup(s, keepPrompt)
	if activeSessions[s.player] ~= s then
		return
	end
	activeSessions[s.player] = nil
	s.runId += 1 -- hentikan coroutine tahap yang masih jalan

	local ps = getState(s.player)
	if ps then
		PlayerStateRepository.set(s.player, "allowedActions", false)
		PlayerStateRepository.set(s.player, "noDecay", false)
	end
	RemoteSafety.fire(promptEvent, s.player, "slowmo", false)
	if not keepPrompt then
		hidePrompt(s)
	end

	if s.slot then
		releaseSlot(s.slot)
	end

	if s.mapModel and s.mapModel.Parent == workspace then
		task.delay(4, function()
			if s.mapModel and s.mapModel.Parent == workspace then
				s.mapModel:Destroy()
				s.mapModel = nil
				print("[TutorialBattleService] Map tutorial dibersihkan dari Workspace untuk " .. s.player.Name)
			end
		end)
	end
end

local function runTutorial(s)
	s.runId += 1
	local id = s.runId

	local function live()
		local ps = getState(s.player)
		return activeSessions[s.player] == s and s.runId == id and ps ~= nil and ps.isPlaying == true
	end

	local function botLastHitTime()
		local bs = getState(s.bot)
		return bs and bs.lastHitTime or 0
	end

	-- Tips yang menunggu pemain menekan "Lanjut" (atau auto-lanjut kalau diam lama)
	local function tipWithContinue(text, meta)
		setAllowed(s, {})
		s.continued = false
		say(s, text, nil, true, meta)
		waitFor(live, function()
			return s.continued
		end, CONFIG.CONTINUE_TIMEOUT)
		hidePrompt(s)
		pause(live, 0.4)
	end

	-- Tips otomatis: durasi menyesuaikan panjang teks (readTime)
	local function tipAuto(text, key, meta)
		say(s, text, key, false, meta)
		pause(live, readTime(text))
	end

	local function reward(text, kind, meta)
		hidePrompt(s)
		fx(s, kind or "hit")
		local rewardMeta = { mood = "reward" }
		if type(meta) == "table" then
			for k, v in pairs(meta) do
				rewardMeta[k] = v
			end
		end
		say(s, text, nil, false, rewardMeta)
		pause(live, math.max(CONFIG.REWARD_SECONDS, readTime(text) - 0.8))
		hidePrompt(s)
		pause(live, CONFIG.BREATH_SECONDS)
	end

	-- Tunggu pemain mengayun, lalu pastikan pukulannya benar-benar mengenai bot
	local function waitForLandedHit(missKey, missMeta)
		while live() do
			local since = os.clock()
			if not waitFor(live, function()
				return s.lastSwingAt > since
			end) then
				return false
			end
			local swungAt = s.lastSwingAt
			if waitFor(live, function()
				return botLastHitTime() > swungAt
			end, CONFIG.HIT_CHECK_TIMEOUT) then
				return true
			end
			fx(s, "bad")
			say(s, pick(LINES.miss), missKey, false, missMeta)
		end
		return false
	end

	local function stageAttack()
		for rep = 1, CONFIG.REPS do
			setAllowed(s, { light = true })
			say(s, rep == 1 and LINES.attackIntro or LINES.attackAgain, "KLIK KIRI", false, {
				stage = "LATIHAN 1/4",
				rep = rep - 1,
				repTotal = CONFIG.REPS,
				action = "light",
				mood = "normal",
			})
			if
				not waitForLandedHit("KLIK KIRI", {
					stage = "COBA LAGI",
					rep = rep - 1,
					repTotal = CONFIG.REPS,
					action = "light",
					mood = "error",
				})
			then
				return false
			end
			setAllowed(s, {})
			reward(pick(LINES.attackReward), "hit", {
				stage = string.format("BERHASIL %d/%d", rep, CONFIG.REPS),
				rep = rep,
				repTotal = CONFIG.REPS,
			})
		end
		return true
	end

	-- Satu percobaan dodge. return: "ok" | "hit" | "retry" | nil (sesi berhenti)
	local function dodgeAttempt(rep)
		setAllowed(s, { dodge = true })

		local telegraphAt = os.clock()
		local track = BotAnimationService.play(s.bot, "light")
		if track then
			task.wait(math.min(CONFIG.WINDUP_SECONDS, track.Length * 0.3))
			track:AdjustSpeed(CONFIG.SLOWMO_SPEED[rep] or CONFIG.SLOWMO_SPEED[#CONFIG.SLOWMO_SPEED])
		end
		fx(s, "telegraph")
		RemoteSafety.fire(promptEvent, s.player, "slowmo", true)
		say(s, pick(LINES.dodgeNow), "Q", false, {
			stage = "LATIHAN 2/4",
			rep = rep - 1,
			repTotal = CONFIG.REPS,
			action = "dodge",
			mood = "telegraph",
		})

		local pressed = waitFor(live, function()
			local ps = getState(s.player)
			return ps and (ps.lastDodgeTime or 0) > telegraphAt
		end, CONFIG.DODGE_TIMEOUT[rep] or CONFIG.DODGE_TIMEOUT[#CONFIG.DODGE_TIMEOUT])

		if pressed then
			pause(live, CONFIG.DODGE_SWING_DELAY)
		end

		if track then
			track:AdjustSpeed(1)
		end
		RemoteSafety.fire(promptEvent, s.player, "slowmo", false)
		hidePrompt(s)
		if not live() then
			return nil
		end

		local swingAt = os.clock()
		if not CombatController.performAction(s.bot, "light") then
			pause(live, 0.5)
			return "retry"
		end

		pause(live, CONFIG.HIT_RESOLVE_WAIT)
		local ps = getState(s.player)
		if ps and (ps.lastHitTime or 0) > swingAt then
			return "hit"
		end
		return "ok"
	end

	local function stageDodge()
		local done = 0
		local first = true
		while live() and done < CONFIG.REPS do
			if first then
				tipWithContinue(LINES.dodgeIntro, {
					stage = "LATIHAN 2/4",
					action = "continue",
					mood = "normal",
				})
				first = false
			elseif done > 0 then
				tipAuto(LINES.dodgeAgain, nil, {
					stage = "LATIHAN 2/4",
					rep = done,
					repTotal = CONFIG.REPS,
					mood = "normal",
				})
				hidePrompt(s)
			end

			local result = dodgeAttempt(done + 1)
			if result == nil then
				return false
			end
			if result == "ok" then
				done += 1
				setAllowed(s, {})
				reward(pick(LINES.dodgeReward), "good", {
					stage = string.format("BERHASIL %d/%d", done, CONFIG.REPS),
					rep = done,
					repTotal = CONFIG.REPS,
				})
			elseif result == "hit" then
				setAllowed(s, {})
				fx(s, "bad")
				tipAuto(pick(LINES.dodgeFail), nil, {
					stage = "COBA LAGI",
					rep = done,
					repTotal = CONFIG.REPS,
					mood = "error",
				})
				hidePrompt(s)
				pause(live, CONFIG.BREATH_SECONDS)
			end
		end
		return live()
	end

	local function stageHeavy()
		for rep = 1, CONFIG.REPS do
			setAllowed(s, {})
			pause(live, CONFIG.HEAVY_ENERGY_WAIT)
			PlayerStateRepository.set(s.bot, "isStun", true)
			VFXService.setStunEffect(s.bot, true)
			fx(s, "telegraph")
			setAllowed(s, { heavy = true })
			say(s, rep == 1 and LINES.heavyIntro or LINES.heavyAgain, "KLIK KANAN", false, {
				stage = "LATIHAN 3/4",
				rep = rep - 1,
				repTotal = CONFIG.REPS,
				action = "heavy",
				mood = "normal",
			})

			local ok = waitForLandedHit("KLIK KANAN", {
				stage = "COBA LAGI",
				rep = rep - 1,
				repTotal = CONFIG.REPS,
				action = "heavy",
				mood = "error",
			})

			PlayerStateRepository.set(s.bot, "isStun", false)
			VFXService.setStunEffect(s.bot, false)
			if not ok then
				return false
			end
			setAllowed(s, {})
			if rep == CONFIG.REPS then
				reward(pick(LINES.heavyReward), "heavy", {
					stage = string.format("BERHASIL %d/%d", rep, CONFIG.REPS),
					rep = rep,
					repTotal = CONFIG.REPS,
				})
			else
				reward("Bagus! Sekali lagi, biar tangannya hafal.", "heavy", {
					stage = string.format("BERHASIL %d/%d", rep, CONFIG.REPS),
					rep = rep,
					repTotal = CONFIG.REPS,
				})
			end
		end
		return true
	end

	local function stageFree()
		s.reachedFree = true
		setAllowed(s, false)
		resetBalances(s)
		say(s, LINES.free, nil, false, {
			stage = "LATIHAN 4/4",
			mood = "normal",
		})
		task.delay(readTime(LINES.free), function()
			if live() then
				hidePrompt(s)
			end
		end)

		-- Pemain dibiarkan diam: reset HP kedua pihak supaya tutorial tidak "kalah sendiri"
		task.spawn(function()
			local idleSince = os.clock()
			local lastSeenAction = 0
			while live() do
				task.wait(0.5)
				local ps = getState(s.player)
				local action = ps and math.max(ps.lastActionTime or 0, ps.lastDodgeTime or 0, s.lastSwingAt) or 0
				if action ~= lastSeenAction then
					lastSeenAction = action
					idleSince = os.clock()
				elseif os.clock() - idleSince >= CONFIG.IDLE_RESET_SECONDS then
					idleSince = os.clock()
					resetBalances(s)
					say(s, LINES.idleReset, nil, false, {
						stage = "AYO GERAK",
						mood = "error",
					})
					task.delay(readTime(LINES.idleReset), function()
						if live() then
							hidePrompt(s)
						end
					end)
				end
			end
		end)

		while live() do
			pause(live, CONFIG.EASY_ATTACK_MIN + math.random() * (CONFIG.EASY_ATTACK_MAX - CONFIG.EASY_ATTACK_MIN))
			if not live() then
				break
			end

			local bs = getState(s.bot)
			if bs and bs.isAlive and not bs.isFFYL and not bs.isStun then
				local actionType = (math.random() < CONFIG.EASY_HEAVY_CHANCE) and "heavy" or "light"
				if CombatController.performAction(s.bot, actionType) then
					BotAnimationService.play(s.bot, actionType)
				end
			end
		end
	end

	task.spawn(function()
		if not s.reachedFree then
			if not stageAttack() then
				return
			end
			tipWithContinue(LINES.energy, {
				stage = "TIPS ENERGI",
				action = "continue",
				mood = "normal",
			})

			if not stageDodge() then
				return
			end
			if not stageHeavy() then
				return
			end
		end
		stageFree()
	end)
end

-- ===== Dipanggil ArenaService =====
function TutorialBattleService.onRoundStart(matchInfo)
	local player = matchInfo.players[1]
	local s = activeSessions[player]
	if s then
		runTutorial(s)
	end
end

-- winner = pemain yang menang match (nil kalau match dibatalkan)
function TutorialBattleService.onMatchEnd(winner, matchInfo)
	local targetPlayer = (matchInfo and matchInfo.players[1]) or winner
	local s = targetPlayer and activeSessions[targetPlayer]
	if not s then
		for _, session in pairs(activeSessions) do
			if session.player == winner or session.bot == winner then
				s = session
				break
			end
		end
	end
	if not s then
		return
	end

	if winner == s.player then
		PlayerStateRepository.set(s.player, "tutorialDone", true)
		fx(s, "win")
		say(s, LINES.done, nil, false, {
			stage = "TUTORIAL SELESAI",
			mood = "reward",
		})
		cleanup(s, true)
		task.delay(readTime(LINES.done), function()
			RemoteSafety.fire(promptEvent, s.player, "hide")

			-- Pastikan pemain kembali berdiri di spawn lobby
			local char = s.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local lobbySpawn = workspace:FindFirstChild("SpawnLocation")
					or workspace:FindFirstChild("Lobby")
					or workspace:FindFirstChild("Respawn")
					or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
				if lobbySpawn then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = 16
						humanoid.AutoRotate = true
					end
					char:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 3, 0))
				end
			end
		end)
	else
		cleanup(s)
	end
end

-- ===== Entry point =====
function TutorialBattleService.start(player)
	if activeSessions[player] then
		warn("[TutorialBattleService] Sesi tutorial sudah aktif untuk: " .. player.Name)
		return false
	end
	local ps = ensureState(player)
	if not ps or ps.isPlaying or ps.isInMatchmaking then
		warn("[TutorialBattleService] Pemain sedang match / matchmaking")
		return false
	end

	ArenaService = ArenaService or require(Core.Service.ArenaService)
	BotService = BotService or require(Core.Service.BotService)

	local slot = acquireSlot()
	local arenaName = "TutorialBattle_" .. player.UserId

	-- Pastikan map tutorial yang lengkap (memiliki BattleArena) dari ServerStorage/Workspace di-clone ke Workspace
	local ssTemplate = ServerStorage:FindFirstChild("TutorialMapTemplate")
	local wsTemplate = workspace:FindFirstChild("TutorialMapTemplate")
	local template = if ssTemplate and ssTemplate:FindFirstChild("BattleArena", true)
		then ssTemplate
		elseif wsTemplate and wsTemplate:FindFirstChild("BattleArena", true) then wsTemplate
		else ssTemplate or wsTemplate

	local mapClone
	if template then
		mapClone = template:Clone()
	else
		warn("[TutorialBattleService] TutorialMapTemplate tidak ditemukan; membuat arena tutorial fallback.")
		mapClone = Instance.new("Model")
	end

	mapClone.Name = arenaName
	ensureTutorialArenaStructure(mapClone)
	mapClone.Parent = workspace

	-- Geser map jauh dari lobby berdasarkan slot yang dialokasikan (slot 0 tetap jauh)
	local offset = BASE_OFFSET + Vector3.new(slot * SLOT_DISTANCE, 0, 0)
	offsetInstance(mapClone, offset)

	local battleArena = mapClone:FindFirstChild("BattleArena", true)
	if battleArena then
		local parts = {}
		for _, p in ipairs(battleArena:GetChildren()) do
			table.insert(parts, p.Name)
		end
		print(
			string.format(
				"[TutorialBattleService] Map tutorial di-clone untuk %s di %s (Slot %d, Offset: %s). BattleArena: %s (Isi: %s)",
				player.Name,
				arenaName,
				slot,
				tostring(offset),
				battleArena:GetFullName(),
				table.concat(parts, ", ")
			)
		)
	else
		warn("[TutorialBattleService] BattleArena tidak ditemukan di dalam mapClone " .. arenaName)
	end

	local coachName = TutorialConfig.NPC_DISPLAY_NAME or "Mr. Noob"
	local bot = BotService.create({
		name = coachName,
		displayName = coachName,
		style = "noob",
	})
	PlayerStateRepository.set(player, "noDecay", true)
	PlayerStateRepository.set(bot, "noDecay", true)
	local s = {
		player = player,
		bot = bot,
		runId = 0,
		lastSwingAt = 0,
		reachedFree = false,
		continued = false,
		slot = slot,
		arenaName = arenaName,
		mapModel = mapClone,
	}
	activeSessions[player] = s

	task.spawn(function()
		print("[TutorialBattleService] Memulai ArenaService.startMatch di " .. arenaName .. " untuk: " .. player.Name)
		ArenaService.startMatch(arenaName, { player, bot }, {
			tutorial = true,
			winsNeeded = 1,
			arenaFolder = battleArena,
		})
	end)
	return true
end

local function isNpcModelName(name)
	if name == TutorialConfig.NPC_NAME then
		return true
	end
	if type(TutorialConfig.NPC_ALIASES) == "table" then
		for _, alias in ipairs(TutorialConfig.NPC_ALIASES) do
			if name == alias then
				return true
			end
		end
	end
	return false
end

local function findNpcModel()
	local direct = TutorialConfig.NPC_NAME and workspace:FindFirstChild(TutorialConfig.NPC_NAME, true)
	if direct and direct:IsA("Model") then
		return direct
	end
	if type(TutorialConfig.NPC_ALIASES) == "table" then
		for _, alias in ipairs(TutorialConfig.NPC_ALIASES) do
			local found = workspace:FindFirstChild(alias, true)
			if found and found:IsA("Model") then
				return found
			end
		end
	end
	return nil
end

local function setupCoachNpc(model)
	local displayName = TutorialConfig.NPC_DISPLAY_NAME or "Mr. Noob"
	model.Name = displayName
	applyNoobSkinToModel(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = displayName
	end

	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5) or model.PrimaryPart
	if not head then
		warn("[TutorialService] NPC pelatih tidak memiliki Head atau PrimaryPart")
		return
	end

	-- Bersihkan native Roblox Dialog lama jika masih ada di model Studio
	local oldDialog = head:FindFirstChildOfClass("Dialog")
	if oldDialog then
		oldDialog:Destroy()
	end

	local prompt = head:FindFirstChild("TutorialTalkPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TutorialTalkPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = TutorialConfig.CONVERSATION_DISTANCE or 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = head
	end
	prompt.ObjectText = displayName
	prompt.ActionText = TutorialConfig.PROMPT_ACTION_TEXT or "Ngobrol"

	prompt.Triggered:Connect(function(player)
		if activeSessions[player] then
			return
		end
		local ps = ensureState(player)
		if not ps or ps.isPlaying or ps.isInMatchmaking then
			return
		end
		RemoteSafety.fire(getPromptEvent(), player, "openLobbyDialog")
	end)

	print("[TutorialService] ProximityPrompt " .. displayName .. " berhasil dipasang.")
end

local function initCoachNpcDetection()
	local existingNpc = findNpcModel()
	if existingNpc then
		task.spawn(setupCoachNpc, existingNpc)
	else
		local conn
		conn = workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Model") and isNpcModelName(descendant.Name) then
				conn:Disconnect()
				task.spawn(setupCoachNpc, descendant)
			end
		end)
	end
end

function TutorialBattleService.init()
	if initialized then
		return
	end
	initialized = true

	local event = getPromptEvent()
	if event then
		-- Klien menekan "Lanjut" atau memilih opsi latihan dari dialog Mr. Noob
		event.OnServerEvent:Connect(function(player, kind)
			if kind == "continue" then
				local s = activeSessions[player]
				if s then
					s.continued = true
				end
			elseif kind == "startTutorial" then
				print("[TutorialBattleService] Request startTutorial diterima dari client " .. player.Name)
				TutorialBattleService.start(player)
			end
		end)
	end

	CombatController.AttackStarted.Event:Connect(function(attacker)
		local s = activeSessions[attacker]
		if s then
			s.lastSwingAt = os.clock()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local s = activeSessions[player]
		if s then
			cleanup(s)
		end
	end)

	initCoachNpcDetection()
end

return TutorialBattleService
