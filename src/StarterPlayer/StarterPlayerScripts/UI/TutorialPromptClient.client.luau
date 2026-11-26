-- @ScriptType: LocalScript
--[[
	Nama File : TutorialPromptClient
	Layer     : Client (UI)
	Deskripsi : Custom Dialogue Box (gaya cinematic 3D tanpa portrait:
	            nama pembicara dinamis, efek ketik, pilihan opsi vertikal,
	            kunci gerak player, & kamera bergantian fokus NPC <-> Player)
	            + efek battle tutorial: slow-mo, screen shake, FOV punch, flash.
	Dependensi: ReplicatedStorage > Remotes > TutorialPromptEvent
	            ReplicatedStorage > Configs > TutorialConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local promptEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialPromptEvent")
local TutorialConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("TutorialConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local NPC_NAME = string.upper(TutorialConfig.NPC_DISPLAY_NAME or "SIR NATTOS")
-- Palet konsisten dengan UI Lobby (CoinHud, Shop, & Lobby Buttons)
local NPC_ACCENT = Color3.fromRGB(255, 205, 60) -- Gold (sama dengan CoinHudClient)
local PLAYER_ACCENT = Color3.fromRGB(110, 225, 105) -- Hijau cerah (senada tombol Lobby/Shop)
local PANEL_BG = Color3.fromRGB(20, 26, 22) -- Gelap kehijauan hangat
local PILL_BG = Color3.fromRGB(28, 38, 30)
local DARK_TEXT = Color3.fromRGB(32, 24, 10)
local BTN_GREEN = Color3.fromRGB(62, 175, 58)
local BTN_GREEN_STROKE = Color3.fromRGB(20, 62, 20)
local TYPE_SPEED = 0.022 -- detik per huruf

-- ================================================================
-- UI CONSTRUCTION
-- ================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialPrompt"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Root container untuk Dialogue Box + Options (memudahkan positioning relatif)
local root = Instance.new("Frame")
root.Name = "DialogueRoot"
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = UDim2.fromScale(0.5, 0.94)
root.Size = UDim2.fromScale(0.56, 0.19)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = gui

local rootSizeLimit = Instance.new("UISizeConstraint")
rootSizeLimit.MinSize = Vector2.new(380, 115)
rootSizeLimit.MaxSize = Vector2.new(860, 180)
rootSizeLimit.Parent = root

-- Main Dialogue Box (selaras dengan gaya panel & stroke Lobby/Shop)
local frame = Instance.new("TextButton")
frame.Name = "DialogueBox"
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = PANEL_BG
frame.BackgroundTransparency = 0.12
frame.Text = ""
frame.AutoButtonColor = false
frame.Parent = root
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = NPC_ACCENT
stroke.Thickness = 2.5
stroke.Transparency = 0.15
stroke.Parent = frame

local boxScale = Instance.new("UIScale")
boxScale.Parent = frame

-- Speaker Name Pill (atas-kiri menempel di tepi atas box)
local speakerPill = Instance.new("Frame")
speakerPill.Name = "SpeakerPill"
speakerPill.AnchorPoint = Vector2.new(0, 0.5)
speakerPill.Position = UDim2.fromScale(0.03, 0)
speakerPill.Size = UDim2.fromScale(0.32, 0.27)
speakerPill.AutomaticSize = Enum.AutomaticSize.X
speakerPill.BackgroundColor3 = PILL_BG
speakerPill.Parent = frame
Instance.new("UICorner", speakerPill).CornerRadius = UDim.new(0, 10)

local speakerStroke = Instance.new("UIStroke")
speakerStroke.Color = NPC_ACCENT
speakerStroke.Thickness = 2.5
speakerStroke.Parent = speakerPill

local speakerPad = Instance.new("UIPadding")
speakerPad.PaddingLeft = UDim.new(0, 14)
speakerPad.PaddingRight = UDim.new(0, 14)
speakerPad.Parent = speakerPill

local speaker = Instance.new("TextLabel")
speaker.BackgroundTransparency = 1
speaker.Size = UDim2.fromScale(1, 1)
speaker.AutomaticSize = Enum.AutomaticSize.X
speaker.Font = Enum.Font.FredokaOne
speaker.TextSize = 18
speaker.TextColor3 = NPC_ACCENT
speaker.Text = NPC_NAME
speaker.Parent = speakerPill

-- Body Text
local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromScale(0.035, 0.22)
body.Size = UDim2.fromScale(0.93, 0.52)
body.Font = Enum.Font.GothamBold
body.TextWrapped = true
body.TextScaled = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = Color3.fromRGB(250, 252, 248)
body.Text = ""
body.Parent = frame
Instance.new("UITextSizeConstraint", body).MaxTextSize = 24

-- Key Badge (untuk instruksi aksi di battle tutorial)
local keyBadge = Instance.new("TextLabel")
keyBadge.AnchorPoint = Vector2.new(0, 1)
keyBadge.Position = UDim2.fromScale(0.035, 0.92)
keyBadge.Size = UDim2.fromScale(0.14, 0.23)
keyBadge.BackgroundColor3 = NPC_ACCENT
keyBadge.Font = Enum.Font.FredokaOne
keyBadge.TextSize = 18
keyBadge.TextColor3 = DARK_TEXT
keyBadge.Visible = false
keyBadge.Parent = frame
Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 8)
local keyBadgeStroke = Instance.new("UIStroke")
keyBadgeStroke.Color = Color3.fromRGB(145, 105, 15)
keyBadgeStroke.Thickness = 2
keyBadgeStroke.Parent = keyBadge
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = keyBadge

-- Tombol Lanjut [E]
local contBtn = Instance.new("TextButton")
contBtn.AnchorPoint = Vector2.new(1, 1)
contBtn.Position = UDim2.fromScale(0.97, 0.92)
contBtn.Size = UDim2.fromScale(0.24, 0.24)
contBtn.BackgroundColor3 = BTN_GREEN
contBtn.AutoButtonColor = false
contBtn.Font = Enum.Font.FredokaOne
contBtn.TextScaled = true
contBtn.Text = "LANJUT [E]"
contBtn.TextColor3 = Color3.new(1, 1, 1)
contBtn.Visible = false
contBtn.Parent = frame
Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 10)
local contStroke = Instance.new("UIStroke")
contStroke.Color = BTN_GREEN_STROKE
contStroke.Thickness = 2
contStroke.Parent = contBtn
local contGrad = Instance.new("UIGradient")
contGrad.Rotation = 90
contGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(95, 210, 85)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 145, 42)),
})
contGrad.Parent = contBtn
Instance.new("UITextSizeConstraint", contBtn).MaxTextSize = 18

-- Options Container (Kanan-Atas di atas Dialogue Box — gaya Genshin/Zelda)
local optionsContainer = Instance.new("Frame")
optionsContainer.Name = "OptionsContainer"
optionsContainer.AnchorPoint = Vector2.new(1, 1)
optionsContainer.Position = UDim2.new(1, 0, 0, -14)
optionsContainer.Size = UDim2.fromScale(0.46, 0)
optionsContainer.AutomaticSize = Enum.AutomaticSize.Y
optionsContainer.BackgroundTransparency = 1
optionsContainer.Visible = false
optionsContainer.Parent = root

local optionsLayout = Instance.new("UIListLayout")
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
optionsLayout.Padding = UDim.new(0, 8)
optionsLayout.Parent = optionsContainer

-- Efek layar (Slow-mo & Flash untuk battle tutorial)
local colorFx = Instance.new("ColorCorrectionEffect")
colorFx.Name = "TutorialSlowMo"
colorFx.Parent = Lighting

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 0
flash.Parent = gui

local SLOW_ON = { Saturation = -0.6, Contrast = 0.2, TintColor = Color3.fromRGB(170, 200, 255) }
local SLOW_OFF = { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }

-- ================================================================
-- STATE
-- ================================================================

local typeToken = 0
local isTyping = false
local badgePulse
local canContinue = false

-- Lobby Dialog State
local inLobbyDialog = false
local currentNodeId = nil
local currentChoices = nil
local selectedChoiceIndex = 1
local optionButtons = {}
local lobbySessionToken = 0

-- Camera & Movement Lock State
local camTween = nil
local savedCameraType = nil
local savedWalkSpeed = nil
local savedJumpPower = nil
local savedUseJumpPower = nil
local playerControls = nil

-- ================================================================
-- MOVEMENT LOCK & CAMERA FOCUS (NPC <-> PLAYER)
-- ================================================================

local function getControls()
	if playerControls then
		return playerControls
	end
	local pm = playerScripts:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		if ok and mod and mod.GetControls then
			playerControls = mod:GetControls()
		end
	end
	return playerControls
end

local function setMovementLocked(locked)
	local controls = getControls()
	if controls then
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if locked then
			if savedWalkSpeed == nil then
				savedWalkSpeed = hum.WalkSpeed
				savedJumpPower = hum.JumpPower
				savedUseJumpPower = hum.UseJumpPower
			end
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		else
			if savedWalkSpeed ~= nil then
				hum.WalkSpeed = savedWalkSpeed
				hum.JumpPower = savedJumpPower
				hum.UseJumpPower = savedUseJumpPower
				savedWalkSpeed = nil
				savedJumpPower = nil
				savedUseJumpPower = nil
			end
		end
	end

	ProximityPromptService.Enabled = not locked
end

local function getSirNattosModel()
	return workspace:FindFirstChild(TutorialConfig.NPC_NAME or "Sir Nattos", true)
end

local function getFocusCFrame(targetKind)
	local npc = getSirNattosModel()
	local char = player.Character

	local npcHead = npc and (npc:FindFirstChild("Head") or npc.PrimaryPart)
	local playerHead = char and (char:FindFirstChild("Head") or char.PrimaryPart)

	if targetKind == "npc" and npcHead then
		-- Kamera di depan-kanan NPC menghadap wajah NPC (sedikit over-the-shoulder)
		local lookAt = npcHead.Position - Vector3.new(0, 0.35, 0)
		local forward = npcHead.CFrame.LookVector
		local right = npcHead.CFrame.RightVector
		local camPos = lookAt + forward * 5.2 + right * 1.6 + Vector3.new(0, 0.7, 0)
		return CFrame.lookAt(camPos, lookAt)
	elseif targetKind == "player" and playerHead then
		-- Kamera menghadap Player (sedikit dari samping arah NPC agar terasa dialog 2 arah)
		local lookAt = playerHead.Position - Vector3.new(0, 0.3, 0)
		local dirToNpc = npcHead and (npcHead.Position - playerHead.Position) or playerHead.CFrame.LookVector
		dirToNpc = Vector3.new(dirToNpc.X, 0, dirToNpc.Z)
		if dirToNpc.Magnitude < 0.01 then
			dirToNpc = playerHead.CFrame.LookVector
		else
			dirToNpc = dirToNpc.Unit
		end
		local right = dirToNpc:Cross(Vector3.yAxis)
		local camPos = lookAt + dirToNpc * 4.8 - right * 1.8 + Vector3.new(0, 0.65, 0)
		return CFrame.lookAt(camPos, lookAt)
	end
	return nil
end

local function focusCameraOn(targetKind)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if savedCameraType == nil then
		savedCameraType = cam.CameraType
	end

	local targetCF = getFocusCFrame(targetKind)
	if not targetCF then
		return
	end

	cam.CameraType = Enum.CameraType.Scriptable
	if camTween then
		camTween:Cancel()
	end
	camTween = TweenService:Create(
		cam,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = targetCF }
	)
	camTween:Play()
end

local function restoreCamera()
	if camTween then
		camTween:Cancel()
		camTween = nil
	end
	local cam = workspace.CurrentCamera
	if cam and savedCameraType ~= nil then
		cam.CameraType = savedCameraType
		savedCameraType = nil
	end
end

-- ================================================================
-- TYPEWRITER & UI HELPERS
-- ================================================================

local function setSpeakerStyle(speakerKind)
	if speakerKind == "player" then
		local displayName = string.upper(player.DisplayName or player.Name)
		speaker.Text = displayName
		speaker.TextColor3 = PLAYER_ACCENT
		speakerStroke.Color = PLAYER_ACCENT
		stroke.Color = PLAYER_ACCENT
	else
		speaker.Text = NPC_NAME
		speaker.TextColor3 = NPC_ACCENT
		speakerStroke.Color = NPC_ACCENT
		stroke.Color = NPC_ACCENT
	end
end

local function clearOptions()
	optionsContainer.Visible = false
	for _, btn in ipairs(optionButtons) do
		btn:Destroy()
	end
	table.clear(optionButtons)
	currentChoices = nil
end

local function updateOptionHighlight()
	for i, btn in ipairs(optionButtons) do
		local isSelected = (i == selectedChoiceIndex)
		local btnStroke = btn:FindFirstChildOfClass("UIStroke")
		local numBadge = btn:FindFirstChild("NumBadge")
		if isSelected then
			btn.BackgroundColor3 = Color3.fromRGB(36, 68, 38)
			if btnStroke then
				btnStroke.Color = PLAYER_ACCENT
				btnStroke.Transparency = 0
			end
			if numBadge then
				numBadge.BackgroundColor3 = PLAYER_ACCENT
			end
		else
			btn.BackgroundColor3 = PANEL_BG
			if btnStroke then
				btnStroke.Color = Color3.fromRGB(75, 95, 78)
				btnStroke.Transparency = 0.35
			end
			if numBadge then
				numBadge.BackgroundColor3 = NPC_ACCENT
			end
		end
	end
end

local function finishTypingNow()
	if not isTyping then
		return false
	end
	typeToken += 1
	isTyping = false
	body.MaxVisibleGraphemes = -1
	return true
end

local function typeText(text, onFinished)
	typeToken += 1
	local token = typeToken
	isTyping = true
	body.Text = text
	body.MaxVisibleGraphemes = 0

	task.spawn(function()
		local len = utf8.len(text) or #text
		for i = 1, len do
			if token ~= typeToken then
				return
			end
			body.MaxVisibleGraphemes = i
			task.wait(TYPE_SPEED)
		end
		if token ~= typeToken then
			return
		end
		isTyping = false
		body.MaxVisibleGraphemes = -1
		if onFinished then
			onFinished()
		end
	end)
end

local function pulseBadge()
	if badgePulse then
		badgePulse:Cancel()
	end
	badgeScale.Scale = 1
	badgePulse = TweenService:Create(
		badgeScale,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.05 }
	)
	badgePulse:Play()
end

local function animateBoxIn()
	if not root.Visible then
		root.Visible = true
		boxScale.Scale = 0.92
		root.Position = UDim2.fromScale(0.5, 1.02)
		TweenService
			:Create(boxScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		TweenService:Create(
			root,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.94) }
		):Play()
	end
end

-- ================================================================
-- LOBBY DIALOG FLOW (WITH CHOICES + CAMERA SWITCHING)
-- ================================================================

local showLobbyNode -- forward declaration

local function closeLobbyDialog(triggerAction)
	inLobbyDialog = false
	lobbySessionToken += 1
	currentNodeId = nil
	clearOptions()
	typeToken += 1
	isTyping = false
	canContinue = false
	contBtn.Visible = false
	root.Visible = false

	restoreCamera()
	setMovementLocked(false)

	if triggerAction == "startTutorial" then
		promptEvent:FireServer("startTutorial")
	end
end

local function selectChoice(index)
	if not inLobbyDialog or not currentChoices then
		return
	end
	local choice = currentChoices[index]
	if not choice then
		return
	end

	clearOptions()

	if choice.nextNode then
		showLobbyNode(choice.nextNode)
	elseif choice.action then
		closeLobbyDialog(choice.action)
	else
		closeLobbyDialog()
	end
end

local function renderChoices(choices)
	clearOptions()
	currentChoices = choices
	selectedChoiceIndex = 1

	for i, choice in ipairs(choices) do
		local btn = Instance.new("TextButton")
		btn.Name = "Option_" .. i
		btn.LayoutOrder = i
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.BackgroundColor3 = PANEL_BG
		btn.BackgroundTransparency = 0.08
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.Parent = optionsContainer
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2.5
		btnStroke.Color = Color3.fromRGB(75, 95, 78)
		btnStroke.Transparency = 0.35
		btnStroke.Parent = btn

		local numBadge = Instance.new("TextLabel")
		numBadge.Name = "NumBadge"
		numBadge.AnchorPoint = Vector2.new(0, 0.5)
		numBadge.Position = UDim2.new(0, 10, 0.5, 0)
		numBadge.Size = UDim2.fromOffset(26, 26)
		numBadge.BackgroundColor3 = NPC_ACCENT
		numBadge.Font = Enum.Font.FredokaOne
		numBadge.TextSize = 15
		numBadge.TextColor3 = DARK_TEXT
		numBadge.Text = tostring(i)
		numBadge.Parent = btn
		Instance.new("UICorner", numBadge).CornerRadius = UDim.new(0, 7)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(44, 0)
		label.Size = UDim2.new(1, -54, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = Color3.fromRGB(250, 252, 248)
		label.Text = choice.text or ""
		label.Parent = btn

		btn.MouseEnter:Connect(function()
			selectedChoiceIndex = i
			updateOptionHighlight()
		end)
		btn.Activated:Connect(function()
			selectChoice(i)
		end)

		table.insert(optionButtons, btn)
	end

	updateOptionHighlight()
	optionsContainer.Visible = true
end

showLobbyNode = function(nodeId)
	local dialogTree = TutorialConfig.LOBBY_DIALOG
	local node = dialogTree and dialogTree[nodeId]
	if not node then
		closeLobbyDialog()
		return
	end

	currentNodeId = nodeId
	local token = lobbySessionToken
	clearOptions()
	keyBadge.Visible = false
	canContinue = false
	contBtn.Visible = false

	animateBoxIn()
	setSpeakerStyle(node.speaker or "npc")
	focusCameraOn(node.focus or node.speaker or "npc")

	local function onReady()
		if not inLobbyDialog or token ~= lobbySessionToken or currentNodeId ~= nodeId then
			return
		end
		if node.choices and #node.choices > 0 then
			if node.choiceFocus then
				focusCameraOn(node.choiceFocus)
			end
			renderChoices(node.choices)
		elseif node.autoCloseDelay then
			task.delay(node.autoCloseDelay, function()
				if inLobbyDialog and token == lobbySessionToken and currentNodeId == nodeId then
					closeLobbyDialog(node.action)
				end
			end)
		else
			canContinue = true
			contBtn.Visible = true
		end
	end

	typeText(node.text or "", onReady)
end

local function openLobbyDialog()
	if inLobbyDialog then
		return
	end
	inLobbyDialog = true
	lobbySessionToken += 1
	setMovementLocked(true)
	showLobbyNode("start")
end

-- ================================================================
-- BATTLE TUTORIAL PROMPT (BACKWARD COMPATIBLE)
-- ================================================================

local function showPrompt(data)
	-- Jika dialog lobby masih terbuka saat battle mulai, pastikan bersih
	if inLobbyDialog then
		closeLobbyDialog()
	end

	data = data or {}
	animateBoxIn()
	clearOptions()
	setSpeakerStyle(data.speaker or "npc")

	typeText(data.text or "")

	if data.key then
		keyBadge.Text = data.key
		keyBadge.Visible = true
		pulseBadge()
	else
		keyBadge.Visible = false
		if badgePulse then
			badgePulse:Cancel()
		end
	end

	canContinue = data.cont == true
	contBtn.Visible = canContinue
end

local function hidePrompt()
	typeToken += 1
	isTyping = false
	canContinue = false
	clearOptions()
	if badgePulse then
		badgePulse:Cancel()
	end
	root.Visible = false
end

local function handleContinueAction()
	if inLobbyDialog then
		local dialogTree = TutorialConfig.LOBBY_DIALOG
		local node = dialogTree and currentNodeId and dialogTree[currentNodeId]
		if not node then
			return
		end

		if finishTypingNow() then
			-- Teks selesai di-skip; tampilkan opsi atau tombol lanjut
			if node.choices and #node.choices > 0 then
				if node.choiceFocus then
					focusCameraOn(node.choiceFocus)
				end
				renderChoices(node.choices)
			elseif node.nextNode then
				canContinue = true
				contBtn.Visible = true
			elseif node.autoCloseDelay then
				closeLobbyDialog(node.action)
			end
			return
		end

		if canContinue and node.nextNode then
			canContinue = false
			contBtn.Visible = false
			showLobbyNode(node.nextNode)
		elseif canContinue then
			closeLobbyDialog(node.action)
		end
		return
	end

	-- Battle tutorial continue
	if not canContinue then
		return
	end
	canContinue = false
	contBtn.Visible = false
	promptEvent:FireServer("continue")
end

contBtn.Activated:Connect(handleContinueAction)
frame.Activated:Connect(function()
	if inLobbyDialog then
		if currentChoices and not isTyping then
			return
		end
		handleContinueAction()
	end
end)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if inLobbyDialog then
		if currentChoices and #optionButtons > 0 and not isTyping then
			local num = NUMBER_KEYS[input.KeyCode]
			if num and num <= #optionButtons then
				selectChoice(num)
				return
			end
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.W then
				selectedChoiceIndex = ((selectedChoiceIndex - 2) % #optionButtons) + 1
				updateOptionHighlight()
				return
			elseif input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.S then
				selectedChoiceIndex = (selectedChoiceIndex % #optionButtons) + 1
				updateOptionHighlight()
				return
			elseif
				input.KeyCode == Enum.KeyCode.E
				or input.KeyCode == Enum.KeyCode.Return
				or input.KeyCode == Enum.KeyCode.Space
			then
				selectChoice(selectedChoiceIndex)
				return
			end
		end

		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
			handleContinueAction()
		end
		return
	end

	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		handleContinueAction()
	end
end)

-- ================================================================
-- BATTLE TUTORIAL VFX
-- ================================================================

local function shake(strength, duration)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	task.spawn(function()
		local startedAt = os.clock()
		while os.clock() - startedAt < duration and hum.Parent do
			local fade = 1 - (os.clock() - startedAt) / duration
			hum.CameraOffset =
				Vector3.new((math.random() - 0.5) * strength * fade, (math.random() - 0.5) * strength * fade, 0)
			task.wait()
		end
		if hum.Parent then
			hum.CameraOffset = Vector3.zero
		end
	end)
end

local function fovPunch(amount, duration)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local base = cam.FieldOfView
	cam.FieldOfView = base + amount
	TweenService
		:Create(cam, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		:Play()
end

local function doFlash(color, alpha, duration)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = alpha
	TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

local function playFx(kind)
	if kind == "hit" then
		shake(0.6, 0.18)
		fovPunch(-4, 0.2)
	elseif kind == "heavy" then
		shake(1.4, 0.35)
		fovPunch(-8, 0.3)
		doFlash(Color3.new(1, 1, 1), 0.7, 0.25)
	elseif kind == "good" then
		fovPunch(-5, 0.25)
		doFlash(Color3.fromRGB(120, 255, 170), 0.8, 0.35)
	elseif kind == "bad" then
		shake(1.0, 0.3)
		doFlash(Color3.fromRGB(255, 70, 70), 0.65, 0.4)
	elseif kind == "telegraph" then
		fovPunch(6, 0.35)
		doFlash(Color3.fromRGB(255, 80, 80), 0.85, 0.3)
	elseif kind == "win" then
		shake(0.8, 0.4)
		doFlash(Color3.fromRGB(255, 220, 120), 0.6, 0.6)
	end
end

promptEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "openLobbyDialog" then
		openLobbyDialog()
	elseif kind == "show" then
		showPrompt(data)
	elseif kind == "hide" then
		hidePrompt()
	elseif kind == "slowmo" then
		TweenService:Create(colorFx, TweenInfo.new(0.25), data and SLOW_ON or SLOW_OFF):Play()
	elseif kind == "fx" then
		playFx(data)
	end
end)
