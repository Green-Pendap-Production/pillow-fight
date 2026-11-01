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

-- Teks Coach (galak tapi lucu). Nilai berupa list = dipilih acak. Edit sesuka hati.
local LINES = {
	attackIntro = "Itu lawanmu. Klik kiri, pukul dia pakai bantal.",
	attackAgain = "Sekali lagi. Pengulangan adalah kunci.",
	miss = {
		"Itu cuma angin. Dia ada di depanmu, lho.",
		"Meleset. Coba lagi.",
		"Mukul udara, ya? Lumayan buat olahraga lengan.",
	},
	attackReward = {
		"Nah, begitu. Kena!",
		"Lumayan. Bantalmu ternyata ada gunanya.",
		"Mantap. Lihat mukanya, dia kaget.",
		"Bagus. Pertahankan ritmenya.",
	},

	energy = "Tunggu dulu. Tiap pukulan makan energi, dan kalau habis kamu bakal ke-stun. Pukul saat ada celah.",

	dodgeIntro = "Sekarang gantian dia yang menyerang. Bersiaplah dan tekan Q untuk menghindar.",
	dodgeNow = {
		"Awas! Tekan Q sekarang!",
		"Dia mengayun! Q, Q, Q!",
		"Menghindar! Tekan Q!",
	},
	dodgeAgain = "Sekali lagi. Kali ini dia sedikit lebih cepat, jadi jangan kaget.",
	dodgeFail = {
		"Kena. Tunggu dia mengayun, baru tekan Q. Sabar.",
		"Aduh. Sakit? Wajar. Coba lagi, jangan terlalu cepat dan jangan terlambat.",
		"Kena lagi. Perhatikan gerakan bantalnya, lalu Q.",
	},
	dodgeReward = {
		"Licin banget.",
		"Hampir saja aku kagum. Hampir.",
		"Begitu caranya. Bantalnya cuma kena angin.",
		"Mulus. Kamu punya bakat.",
	},

	heavyIntro = "Dia kehabisan napas. Ini kesempatan emas buat pukulan berat. Klik kanan, kasih paham dia.",
	heavyAgain = "Sekali lagi, yang keras.",
	heavyReward = {
		"Boom! Energinya mahal, tapi damagenya juga mahal.",
		"Mantap. Tapi jangan sering-sering, energimu bisa habis",
		"Itu baru pukulan. Dia pasti ingat sampai besok.",
	},

	idleReset = "Kok bengong? Kuisi lagi darah kalian berdua. Ayo, bergerak.",
	free = "Latihan selesai... hampir. Sekarang lawan sungguhan. Dia sudah kusuruh lebih santai, jadi tumbangkan dia.",
	done = "Lulus. Aku bangga sama kamu. Sedikit. Sekarang pergi dan menangkan arena.",
}

local promptEvent
-- Manajemen slot dinamis koordinat arena tutorial
local SLOT_DISTANCE = 3500 -- Jarak antar arena tutorial (3500 studs saling berjauhan)
local occupiedSlots = {} -- [slotIndex] = true
local activeSessions = {} -- [player] = session table

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

-- data: {text, key, speaker}; key = label tombol yang berdenyut di UI
local function say(s, text, key, canContinue)
	RemoteSafety.fire(promptEvent, s.player, "show", { text = text, key = key, cont = canContinue })
end

local function hidePrompt(s)
	RemoteSafety.fire(promptEvent, s.player, "hide")
end

local function fx(s, kind)
	RemoteSafety.fire(promptEvent, s.player, "fx", kind)
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
	local function tipWithContinue(text)
		setAllowed(s, {})
		s.continued = false
		say(s, text, nil, true)
		waitFor(live, function()
			return s.continued
		end, CONFIG.CONTINUE_TIMEOUT)
		hidePrompt(s)
		pause(live, 0.4)
	end

	-- Tips otomatis: durasi menyesuaikan panjang teks (readTime)
	local function tipAuto(text, key)
		say(s, text, key, false)
		pause(live, readTime(text))
	end

	local function reward(text, kind)
		hidePrompt(s)
		fx(s, kind or "hit")
		say(s, text, nil, false)
		pause(live, math.max(CONFIG.REWARD_SECONDS, readTime(text) - 0.8))
		hidePrompt(s)
		pause(live, CONFIG.BREATH_SECONDS)
	end

	-- Tunggu pemain mengayun, lalu pastikan pukulannya benar-benar mengenai bot
	local function waitForLandedHit(missKey)
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
			say(s, pick(LINES.miss), missKey, false)
		end
		return false
	end

	local function stageAttack()
		for rep = 1, CONFIG.REPS do
			setAllowed(s, { light = true })
			say(s, rep == 1 and LINES.attackIntro or LINES.attackAgain, "KLIK KIRI", false)
			if not waitForLandedHit("KLIK KIRI") then
				return false
			end
			setAllowed(s, {})
			reward(pick(LINES.attackReward), "hit")
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
		say(s, pick(LINES.dodgeNow), "Q", false)

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
				tipWithContinue(LINES.dodgeIntro)
				first = false
			elseif done > 0 then
				tipAuto(LINES.dodgeAgain)
				hidePrompt(s)
			end

			local result = dodgeAttempt(done + 1)
			if result == nil then
				return false
			end
			if result == "ok" then
				done += 1
				setAllowed(s, {})
				reward(pick(LINES.dodgeReward), "good")
			elseif result == "hit" then
				setAllowed(s, {})
				fx(s, "bad")
				tipAuto(pick(LINES.dodgeFail))
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
			say(s, rep == 1 and LINES.heavyIntro or LINES.heavyAgain, "KLIK KANAN", false)

			local ok = waitForLandedHit("KLIK KANAN")

			PlayerStateRepository.set(s.bot, "isStun", false)
			VFXService.setStunEffect(s.bot, false)
			if not ok then
				return false
			end
			setAllowed(s, {})
			if rep == CONFIG.REPS then
				reward(pick(LINES.heavyReward), "heavy")
			else
				reward("Bagus! Sekali lagi, biar tangannya hafal.", "heavy")
			end
		end
		return true
	end

	local function stageFree()
		s.reachedFree = true
		setAllowed(s, false)
		resetBalances(s)
		say(s, LINES.free, nil, false)
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
					say(s, LINES.idleReset, nil, false)
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
			tipWithContinue(LINES.energy)

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
		say(s, LINES.done, nil, false)
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
	local ps = getState(player)
	if not ps or ps.isPlaying or ps.isInMatchmaking then
		warn("[TutorialBattleService] Pemain sedang match / matchmaking")
		return false
	end

	ArenaService = ArenaService or require(Core.Service.ArenaService)
	BotService = BotService or require(Core.Service.BotService)

	local slot = acquireSlot()
	local arenaName = "TutorialBattle_" .. player.UserId

	-- Pastikan map tutorial dari ServerStorage di-clone ke Workspace
	local template = ServerStorage:FindFirstChild("TutorialMapTemplate")
		or workspace:FindFirstChild("TutorialMapTemplate")

	local mapClone
	local battleArena
	if template then
		mapClone = template:Clone()
		mapClone.Name = arenaName
		mapClone.Parent = workspace

		-- Geser map secara dinamis berdasarkan slot yang dialokasikan
		local offset = Vector3.new(slot * SLOT_DISTANCE, 0, 0)
		offsetInstance(mapClone, offset)

		battleArena = mapClone:FindFirstChild("BattleArena", true)
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
	else
		warn("[TutorialBattleService] TutorialMapTemplate tidak ditemukan di ServerStorage!")
	end

	local bot = BotService.create()
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

local function setupSirNattos(model)
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5) or model.PrimaryPart
	if not head then
		warn("[TutorialService] Sir Nattos tidak memiliki Head atau PrimaryPart")
		return
	end

	local dialog = head:FindFirstChildOfClass("Dialog")
	if not dialog then
		dialog = Instance.new("Dialog")
		dialog.Name = "TutorialDialog"
		dialog.InitialPrompt = TutorialConfig.INITIAL_PROMPT
		dialog.GoodbyeDialog = TutorialConfig.GOODBYE_DIALOG
		dialog.ConversationDistance = TutorialConfig.CONVERSATION_DISTANCE
		dialog.Tone = Enum.DialogTone.Friendly
		dialog.Purpose = Enum.DialogPurpose.Help
		dialog.Parent = head
	end

	local choiceTutorial = dialog:FindFirstChild("StartTutorial")
	if not choiceTutorial then
		for _, child in ipairs(dialog:GetChildren()) do
			if
				child:IsA("DialogChoice")
				and (
					string.find(string.lower(child.UserDialog), "latihan")
					or string.find(string.lower(child.UserDialog), "tarung")
				)
			then
				choiceTutorial = child
				break
			end
		end
	end

	if not choiceTutorial then
		choiceTutorial = Instance.new("DialogChoice")
		choiceTutorial.Name = "StartTutorial"
		choiceTutorial.UserDialog = TutorialConfig.CHOICE_TUTORIAL_USER
		choiceTutorial.ResponseDialog = TutorialConfig.CHOICE_TUTORIAL_RESPONSE
		choiceTutorial.Parent = dialog
	end

	local choiceAbout = dialog:FindFirstChild("AboutSirNattos")
	if not choiceAbout then
		choiceAbout = Instance.new("DialogChoice")
		choiceAbout.Name = "AboutSirNattos"
		choiceAbout.UserDialog = TutorialConfig.CHOICE_ABOUT_USER
		choiceAbout.ResponseDialog = TutorialConfig.CHOICE_ABOUT_RESPONSE
		choiceAbout.Parent = dialog
	end

	dialog.DialogChoiceSelected:Connect(function(player, choice)
		if
			choice == choiceTutorial
			or choice.Name == "StartTutorial"
			or string.find(string.lower(choice.UserDialog), "latihan")
			or string.find(string.lower(choice.UserDialog), "tarung")
		then
			print("[TutorialService] " .. player.Name .. " memulai tutorial via dialog Sir Nattos")
			task.wait(1.5)
			TutorialBattleService.start(player)
		end
	end)

	print("[TutorialService] Dialog Sir Nattos berhasil dipasang.")
end

local function initSirNattosDetection()
	local existingNpc = workspace:FindFirstChild(TutorialConfig.NPC_NAME, true)
	if existingNpc then
		task.spawn(setupSirNattos, existingNpc)
	else
		local conn
		conn = workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Model") and descendant.Name == TutorialConfig.NPC_NAME then
				conn:Disconnect()
				task.spawn(setupSirNattos, descendant)
			end
		end)
	end
end

function TutorialBattleService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	promptEvent = remotes:FindFirstChild("TutorialPromptEvent")
	if not promptEvent then
		promptEvent = Instance.new("RemoteEvent")
		promptEvent.Name = "TutorialPromptEvent"
		promptEvent.Parent = remotes
	end

	-- Klien menekan "Lanjut" atau memilih opsi latihan dari dialog Sir Nattos
	promptEvent.OnServerEvent:Connect(function(player, kind)
		if kind == "continue" then
			local s = activeSessions[player]
			if s then
				s.continued = true
			end
		elseif kind == "startTutorial" then
			print("[TutorialBattleService] Request startTutorial diterima dari client " .. player.Name)
			task.wait(1.5) -- Beri waktu pemain membaca respon chat bubble Sir Nattos
			TutorialBattleService.start(player)
		end
	end)

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

	initSirNattosDetection()
end

return TutorialBattleService
