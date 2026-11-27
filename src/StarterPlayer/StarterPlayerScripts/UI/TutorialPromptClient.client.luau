-- @ScriptType: LocalScript
--[[
	Nama File : TutorialPromptClient
	Layer     : Client (UI)
	Deskripsi : UI & animasi Tutorial (Lobby Dialog Mr. Noob + Battle Coach Prompt):
	            - Palet terbatas konsisten Pillow Fight (#47C83E, #1C5E1A, #133A10, #FFCD3C, #D94136)
	            - Outline kartun tegas 3.5-5px + shadow padat, tanpa dots/bullets/dekorasi ramai
	            - Dual-mode layout: Lobby (bawah-tengah + pilihan opsi) & Battle (atas-tengah bebas HUD)
	            - Adaptif PC vs Mobile + aset ikon ForgeGUI + animasi transisi & feedback
	Dependensi: ReplicatedStorage > Remotes > TutorialPromptEvent
	            ReplicatedStorage > Configs > TutorialConfig
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local promptEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialPromptEvent")
local TutorialConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("TutorialConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

-- ================================================================
-- PALETTE & ASSET CONFIG (5 WARNA TERBATAS PILLOW FIGHT)
-- ================================================================

local NPC_NAME = string.upper(TutorialConfig.NPC_DISPLAY_NAME or "MR. NOOB")

local GREEN_MAIN = Color3.fromRGB(71, 200, 62) -- #47C83E
local GREEN_DARK = Color3.fromRGB(28, 94, 26) -- #1C5E1A
local GREEN_PASSIVE = Color3.fromRGB(43, 120, 40) -- #2B7828
local OUTLINE_DARK = Color3.fromRGB(19, 58, 16) -- #133A10
local GOLD_ACCENT = Color3.fromRGB(255, 205, 60) -- #FFCD3C
local RED_ERROR = Color3.fromRGB(217, 65, 54) -- #D94136
local RED_DARK = Color3.fromRGB(94, 26, 26) -- #5E1A1A
local WHITE = Color3.fromRGB(255, 255, 255)

local TYPE_SPEED = 0.022

-- Aset hasil ForgeGUI yang sudah dipublish ke Roblox
local ASSET_IDS = {
	FRAME = "rbxassetid://83693210412537",
	LIGHT = "rbxassetid://72653438829348",
	HEAVY = "rbxassetid://133548976419073",
	DODGE = "rbxassetid://140704569112328",
}

local LOBBY_POS = UDim2.fromScale(0.5, 0.94)
local BATTLE_POS = LOBBY_POS -- Battle tetap memakai kotak dialog di bawah-tengah yang sama

-- ================================================================
-- HELPERS
-- ================================================================

local function addCorner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function addBorderStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function addTextStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function addSolidShadow(parent: GuiObject, radius: number, offsetY: number, zIndex: number): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = OUTLINE_DARK
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, offsetY)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = zIndex
	shadow.Parent = parent
	addCorner(shadow, radius)
	return shadow
end

local function isTouchOnlyDevice(): boolean
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then
		return true
	end
	if
		lastInput == Enum.UserInputType.MouseButton1
		or lastInput == Enum.UserInputType.MouseMovement
		or lastInput == Enum.UserInputType.Keyboard
	then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- ================================================================
-- UI CONSTRUCTION
-- ================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialPrompt"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "DialogueRoot"
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = LOBBY_POS
root.Size = UDim2.fromScale(0.54, 0.19)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = gui

local rootSizeLimit = Instance.new("UISizeConstraint")
rootSizeLimit.MinSize = Vector2.new(360, 118)
rootSizeLimit.MaxSize = Vector2.new(760, 168)
rootSizeLimit.Parent = root

local boxScale = Instance.new("UIScale")
boxScale.Parent = root

-- Bayangan padat di belakang kotak utama
addSolidShadow(root, 20, 7, 1)

-- Frame luar hijau Pillow Fight (atau skin ForgeGUI saat mode normal)
local frame = Instance.new("TextButton")
frame.Name = "DialogueBox"
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = GREEN_MAIN
frame.BorderSizePixel = 0
frame.Text = ""
frame.AutoButtonColor = false
frame.ZIndex = 2
frame.Parent = root
addCorner(frame, 18)
addBorderStroke(frame, OUTLINE_DARK, 4.5)

-- Skin 9-slice ForgeGUI (opsional; default false agar border vector seragam tajam dengan pill & pilihan)
local frameArt = Instance.new("ImageLabel")
frameArt.Name = "ForgeFrameArt"
frameArt.AnchorPoint = Vector2.new(0.5, 0.5)
frameArt.Position = UDim2.fromScale(0.5, 0.5)
frameArt.Size = UDim2.new(1, 32, 1, 44)
frameArt.BackgroundTransparency = 1
frameArt.Image = ASSET_IDS.FRAME
frameArt.ScaleType = Enum.ScaleType.Slice
frameArt.SliceCenter = Rect.new(143, 155, 881, 382)
frameArt.SliceScale = 0.25
frameArt.ZIndex = 2
frameArt.Visible = false
frameArt.Parent = frame

-- Panel dalam hijau gelap tenang (kontras tinggi untuk teks putih)
local innerBox = Instance.new("Frame")
innerBox.Name = "InnerBox"
innerBox.AnchorPoint = Vector2.new(0.5, 0.5)
innerBox.Position = UDim2.fromScale(0.5, 0.5)
innerBox.Size = UDim2.new(1, -20, 1, -20)
innerBox.BackgroundColor3 = GREEN_DARK
innerBox.BorderSizePixel = 0
innerBox.ZIndex = 3
innerBox.Parent = frame
addCorner(innerBox, 12)
addBorderStroke(innerBox, OUTLINE_DARK, 3.5)

-- Speaker Pill (menempel di atas-kiri saat Lobby Dialog)
local speakerHolder = Instance.new("Frame")
speakerHolder.Name = "SpeakerPill"
speakerHolder.AnchorPoint = Vector2.new(0, 0.5)
speakerHolder.Position = UDim2.fromScale(0.03, 0)
speakerHolder.Size = UDim2.fromOffset(148, 38)
speakerHolder.AutomaticSize = Enum.AutomaticSize.X
speakerHolder.BackgroundTransparency = 1
speakerHolder.ZIndex = 6
speakerHolder.Parent = frame

local speakerScale = Instance.new("UIScale")
speakerScale.Parent = speakerHolder

addSolidShadow(speakerHolder, 11, 4, 5)

local speakerBg = Instance.new("Frame")
speakerBg.Name = "Bg"
speakerBg.Size = UDim2.fromScale(1, 1)
speakerBg.AutomaticSize = Enum.AutomaticSize.X
speakerBg.BackgroundColor3 = GOLD_ACCENT
speakerBg.BorderSizePixel = 0
speakerBg.ZIndex = 6
speakerBg.Parent = speakerHolder
addCorner(speakerBg, 11)
addBorderStroke(speakerBg, OUTLINE_DARK, 4)

local speakerPad = Instance.new("UIPadding")
speakerPad.PaddingLeft = UDim.new(0, 16)
speakerPad.PaddingRight = UDim.new(0, 16)
speakerPad.Parent = speakerBg

local speakerLabel = Instance.new("TextLabel")
speakerLabel.Name = "Label"
speakerLabel.BackgroundTransparency = 1
speakerLabel.Size = UDim2.fromScale(0, 1)
speakerLabel.AutomaticSize = Enum.AutomaticSize.X
speakerLabel.Font = Enum.Font.FredokaOne
speakerLabel.TextSize = 18
speakerLabel.TextColor3 = OUTLINE_DARK
speakerLabel.Text = NPC_NAME
speakerLabel.ZIndex = 7
speakerLabel.Parent = speakerBg
local speakerTextStroke = addTextStroke(speakerLabel, OUTLINE_DARK, 2)
speakerTextStroke.Enabled = false

-- Body Text (seimbang, bersih, outline kontekstual terbaca)
local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(18, 22)
body.Size = UDim2.new(1, -36, 1, -62)
body.Font = Enum.Font.GothamBold
body.TextWrapped = true
body.TextScaled = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = WHITE
body.Text = ""
body.ZIndex = 4
body.Parent = innerBox
addTextStroke(body, OUTLINE_DARK, 1.8)
local bodyTextConstraint = Instance.new("UITextSizeConstraint")
bodyTextConstraint.MinTextSize = 13
bodyTextConstraint.MaxTextSize = 21
bodyTextConstraint.Parent = body

-- Action Badge (kanan-bawah kotak saat Battle Mode)
local actionBadgeHolder = Instance.new("Frame")
actionBadgeHolder.Name = "ActionBadge"
actionBadgeHolder.AnchorPoint = Vector2.new(1, 1)
actionBadgeHolder.Position = UDim2.new(1, -14, 1, -10)
actionBadgeHolder.Size = UDim2.fromOffset(0, 40)
actionBadgeHolder.AutomaticSize = Enum.AutomaticSize.X
actionBadgeHolder.BackgroundTransparency = 1
actionBadgeHolder.Visible = false
actionBadgeHolder.ZIndex = 5
actionBadgeHolder.Parent = innerBox

local badgeSizeLimit = Instance.new("UISizeConstraint")
badgeSizeLimit.MinSize = Vector2.new(108, 40)
badgeSizeLimit.MaxSize = Vector2.new(210, 40)
badgeSizeLimit.Parent = actionBadgeHolder

local badgeScale = Instance.new("UIScale")
badgeScale.Parent = actionBadgeHolder

addSolidShadow(actionBadgeHolder, 11, 4, 4)

local actionBadgeBtn = Instance.new("Frame")
actionBadgeBtn.Name = "Bg"
actionBadgeBtn.Size = UDim2.fromScale(1, 1)
actionBadgeBtn.AutomaticSize = Enum.AutomaticSize.X
actionBadgeBtn.BackgroundColor3 = GOLD_ACCENT
actionBadgeBtn.BorderSizePixel = 0
actionBadgeBtn.ZIndex = 5
actionBadgeBtn.Parent = actionBadgeHolder
addCorner(actionBadgeBtn, 11)
addBorderStroke(actionBadgeBtn, OUTLINE_DARK, 3.5)

local badgeLayout = Instance.new("UIListLayout")
badgeLayout.FillDirection = Enum.FillDirection.Horizontal
badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
badgeLayout.Padding = UDim.new(0, 8)
badgeLayout.Parent = actionBadgeBtn

local badgePad = Instance.new("UIPadding")
badgePad.PaddingLeft = UDim.new(0, 12)
badgePad.PaddingRight = UDim.new(0, 12)
badgePad.Parent = actionBadgeBtn

local actionIcon = Instance.new("ImageLabel")
actionIcon.Name = "Icon"
actionIcon.Size = UDim2.fromOffset(28, 28)
actionIcon.BackgroundTransparency = 1
actionIcon.ScaleType = Enum.ScaleType.Fit
actionIcon.Visible = false
actionIcon.ZIndex = 6
actionIcon.Parent = actionBadgeBtn

local actionText = Instance.new("TextLabel")
actionText.Name = "Text"
actionText.Size = UDim2.fromOffset(0, 32)
actionText.AutomaticSize = Enum.AutomaticSize.X
actionText.BackgroundTransparency = 1
actionText.Font = Enum.Font.FredokaOne
actionText.TextSize = 16
actionText.TextColor3 = OUTLINE_DARK
actionText.Text = "KLIK KIRI"
actionText.ZIndex = 6
actionText.Parent = actionBadgeBtn
local actionTextStroke = addTextStroke(actionText, OUTLINE_DARK, 2)
actionTextStroke.Enabled = false

-- Tombol Lanjut (Lobby kanan-bawah & Battle kanan-tengah)
local contHolder = Instance.new("Frame")
contHolder.Name = "ContinueHolder"
contHolder.AnchorPoint = Vector2.new(1, 1)
contHolder.Position = UDim2.new(1, -14, 1, -10)
contHolder.Size = UDim2.fromOffset(0, 38)
contHolder.AutomaticSize = Enum.AutomaticSize.X
contHolder.BackgroundTransparency = 1
contHolder.Visible = false
contHolder.ZIndex = 5
contHolder.Parent = innerBox

local contSizeLimit = Instance.new("UISizeConstraint")
contSizeLimit.MinSize = Vector2.new(124, 38)
contSizeLimit.MaxSize = Vector2.new(190, 44)
contSizeLimit.Parent = contHolder

local contScale = Instance.new("UIScale")
contScale.Parent = contHolder

addSolidShadow(contHolder, 11, 4, 4)

local contBtn = Instance.new("TextButton")
contBtn.Name = "ContinueBtn"
contBtn.Size = UDim2.fromScale(1, 1)
contBtn.AutomaticSize = Enum.AutomaticSize.X
contBtn.BackgroundColor3 = GREEN_MAIN
contBtn.BorderSizePixel = 0
contBtn.AutoButtonColor = false
contBtn.Text = ""
contBtn.ZIndex = 5
contBtn.Parent = contHolder
addCorner(contBtn, 11)
addBorderStroke(contBtn, OUTLINE_DARK, 3.5)

local contPad = Instance.new("UIPadding")
contPad.PaddingLeft = UDim.new(0, 14)
contPad.PaddingRight = UDim.new(0, 14)
contPad.Parent = contBtn

local contLayout = Instance.new("UIListLayout")
contLayout.FillDirection = Enum.FillDirection.Horizontal
contLayout.VerticalAlignment = Enum.VerticalAlignment.Center
contLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contLayout.Padding = UDim.new(0, 8)
contLayout.Parent = contBtn

local contLabel = Instance.new("TextLabel")
contLabel.BackgroundTransparency = 1
contLabel.Size = UDim2.fromOffset(0, 26)
contLabel.AutomaticSize = Enum.AutomaticSize.X
contLabel.Font = Enum.Font.FredokaOne
contLabel.TextSize = 17
contLabel.TextColor3 = WHITE
contLabel.Text = "LANJUT"
contLabel.ZIndex = 6
contLabel.Parent = contBtn
addTextStroke(contLabel, OUTLINE_DARK, 2)

local contKeycap = Instance.new("TextLabel")
contKeycap.Name = "Keycap"
contKeycap.Size = UDim2.fromOffset(26, 24)
contKeycap.BackgroundColor3 = GOLD_ACCENT
contKeycap.BorderSizePixel = 0
contKeycap.Font = Enum.Font.FredokaOne
contKeycap.TextSize = 14
contKeycap.TextColor3 = OUTLINE_DARK
contKeycap.Text = "E"
contKeycap.ZIndex = 6
contKeycap.Parent = contBtn
addCorner(contKeycap, 6)
addBorderStroke(contKeycap, OUTLINE_DARK, 2.5)

-- Options Container (Kanan-Atas di atas Dialogue Box saat Lobby)
local optionsContainer = Instance.new("Frame")
optionsContainer.Name = "OptionsContainer"
optionsContainer.AnchorPoint = Vector2.new(1, 1)
optionsContainer.Position = UDim2.new(1, 0, 0, -14)
optionsContainer.Size = UDim2.fromScale(0.45, 0)
optionsContainer.AutomaticSize = Enum.AutomaticSize.Y
optionsContainer.BackgroundTransparency = 1
optionsContainer.Visible = false
optionsContainer.ZIndex = 5
optionsContainer.Parent = root

local optionsLayout = Instance.new("UIListLayout")
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
optionsLayout.Padding = UDim.new(0, 10)
optionsLayout.Parent = optionsContainer

-- Efek layar (Slow-mo & Flash untuk battle tutorial)
local colorFx = Instance.new("ColorCorrectionEffect")
colorFx.Name = "TutorialSlowMo"
colorFx.Parent = Lighting

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = WHITE
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 0
flash.Parent = gui

local SLOW_ON = { Saturation = -0.55, Contrast = 0.16, TintColor = Color3.fromRGB(175, 205, 255) }
local SLOW_OFF = { Saturation = 0, Contrast = 0, TintColor = WHITE }

-- ================================================================
-- STATE
-- ================================================================

local currentMode: "lobby" | "battle" = "lobby"
local currentSpeakerKind: string? = nil
local visToken = 0
local visScaleTween: Tween? = nil
local visPosTween: Tween? = nil
local typeToken = 0
local shakeToken = 0
local isTyping = false
local badgePulse: Tween? = nil
local canContinue = false

-- Lobby Dialog State
local inLobbyDialog = false
local currentNodeId: string? = nil
local currentChoices = nil
local selectedChoiceIndex = 1
local optionButtons = {}
local lobbySessionToken = 0
local lobbyNodeShownAt = 0
local choicesShownAt = 0

-- Camera & Movement Lock State
local camTween: Tween? = nil
local charRotTween: Tween? = nil
local savedCameraType: Enum.CameraType? = nil
local savedWalkSpeed: number? = nil
local savedJumpPower: number? = nil
local savedUseJumpPower: boolean? = nil
local savedAutoRotate: boolean? = nil
local playerControls = nil

-- Mobile Button Highlight State
local highlightedMobileBtn: GuiObject? = nil
local highlightedMobileTween: Tween? = nil

-- ================================================================
-- CONTINUE BUTTON HOVER / PRESS
-- ================================================================

do
	local hovering = false
	contBtn.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(contScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.04,
		}):Play()
	end)
	contBtn.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(contScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
	contBtn.MouseButton1Down:Connect(function()
		TweenService:Create(contScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.95,
		}):Play()
	end)
	contBtn.MouseButton1Up:Connect(function()
		TweenService:Create(contScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = hovering and 1.04 or 1,
		}):Play()
	end)
end

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

local function setMovementLocked(locked: boolean)
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
				savedAutoRotate = hum.AutoRotate
			end
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.AutoRotate = false
		elseif savedWalkSpeed ~= nil then
			if charRotTween then
				charRotTween:Cancel()
				charRotTween = nil
			end
			hum.WalkSpeed = savedWalkSpeed
			hum.JumpPower = savedJumpPower :: number
			hum.UseJumpPower = savedUseJumpPower :: boolean
			if savedAutoRotate ~= nil then
				hum.AutoRotate = savedAutoRotate
			end
			savedWalkSpeed = nil
			savedJumpPower = nil
			savedUseJumpPower = nil
			savedAutoRotate = nil
		end
	end

	ProximityPromptService.Enabled = not locked
end

local function getCoachNpcModel(): Model?
	local primary = TutorialConfig.NPC_NAME and workspace:FindFirstChild(TutorialConfig.NPC_NAME, true)
	if primary and primary:IsA("Model") then
		return primary
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

local function facePlayerTowardNpc()
	local npc = getCoachNpcModel()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local npcRoot = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc.PrimaryPart)
	if not (hrp and hrp:IsA("BasePart") and npcRoot and npcRoot:IsA("BasePart")) then
		return
	end

	local flatDir = Vector3.new(npcRoot.Position.X - hrp.Position.X, 0, npcRoot.Position.Z - hrp.Position.Z)
	if flatDir.Magnitude < 0.05 then
		return
	end
	flatDir = flatDir.Unit

	local targetCF = CFrame.lookAt(hrp.Position, hrp.Position + flatDir)
	if charRotTween then
		charRotTween:Cancel()
	end
	charRotTween = TweenService:Create(
		hrp,
		TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = targetCF }
	)
	charRotTween:Play()
end

local function getFocusCFrame(targetKind: string): CFrame?
	local npc = getCoachNpcModel()
	local char = player.Character

	local npcHead = npc and (npc:FindFirstChild("Head") or npc.PrimaryPart)
	local playerHead = char and (char:FindFirstChild("Head") or char.PrimaryPart)

	local pToNpc = Vector3.new(0, 0, -1)
	if npcHead and npcHead:IsA("BasePart") and playerHead and playerHead:IsA("BasePart") then
		local delta =
			Vector3.new(npcHead.Position.X - playerHead.Position.X, 0, npcHead.Position.Z - playerHead.Position.Z)
		if delta.Magnitude >= 0.05 then
			pToNpc = delta.Unit
		end
	end

	if targetKind == "npc" and npcHead and npcHead:IsA("BasePart") then
		local lookAt = npcHead.Position - Vector3.new(0, 0.72, 0)
		local forward = Vector3.new(npcHead.CFrame.LookVector.X, 0, npcHead.CFrame.LookVector.Z)
		if forward.Magnitude < 0.05 then
			forward = -pToNpc
		else
			forward = forward.Unit
		end
		local right = forward:Cross(Vector3.yAxis).Unit
		-- Pilih sisi lateral yang tidak tertutup badan player jika player berdiri di depan NPC
		local sideSign = 1
		if playerHead and playerHead:IsA("BasePart") then
			local relToNpc = playerHead.Position - npcHead.Position
			if relToNpc:Dot(right) > 0.25 then
				sideSign = -1
			end
		end
		local camPos = lookAt + forward * 4.9 + right * (2.15 * sideSign) + Vector3.new(0, 0.85, 0)
		return CFrame.lookAt(camPos, lookAt)
	elseif targetKind == "player" and playerHead and playerHead:IsA("BasePart") then
		local lookAt = playerHead.Position - Vector3.new(0, 0.65, 0)
		local dirToNpc = pToNpc
		if not (npcHead and npcHead:IsA("BasePart")) then
			local flat = Vector3.new(playerHead.CFrame.LookVector.X, 0, playerHead.CFrame.LookVector.Z)
			dirToNpc = if flat.Magnitude >= 0.05 then flat.Unit else Vector3.new(0, 0, -1)
		end
		local right = dirToNpc:Cross(Vector3.yAxis).Unit
		local camPos = lookAt + dirToNpc * 4.7 - right * 1.7 + Vector3.new(0, 0.65, 0)
		return CFrame.lookAt(camPos, lookAt)
	elseif
		targetKind == "both"
		and npcHead
		and npcHead:IsA("BasePart")
		and playerHead
		and playerHead:IsA("BasePart")
	then
		local mid = (npcHead.Position + playerHead.Position) * 0.5 - Vector3.new(0, 0.85, 0)
		local side = pToNpc:Cross(Vector3.yAxis).Unit
		local sep = math.clamp((npcHead.Position - playerHead.Position).Magnitude, 4.5, 13)
		local camPos = mid - side * (sep * 0.88 + 4.2) - pToNpc * 0.9 + Vector3.new(0, 1.35, 0)
		return CFrame.lookAt(camPos, mid)
	elseif npcHead and npcHead:IsA("BasePart") then
		local lookAt = npcHead.Position - Vector3.new(0, 0.72, 0)
		local camPos = lookAt
			+ npcHead.CFrame.LookVector * 5.0
			+ npcHead.CFrame.RightVector * 1.9
			+ Vector3.new(0, 0.85, 0)
		return CFrame.lookAt(camPos, lookAt)
	end
	return nil
end

local function focusCameraOn(targetKind: string)
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
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
-- MOBILE BUTTON HIGHLIGHT
-- ================================================================

local MOBILE_BTN_BY_ACTION = {
	light = "LightBtn",
	heavy = "HeavyBtn",
	dodge = "DodgeBtn",
}

local function clearMobileHighlight()
	if highlightedMobileTween then
		highlightedMobileTween:Cancel()
		highlightedMobileTween = nil
	end
	if highlightedMobileBtn and highlightedMobileBtn.Parent then
		local sc = highlightedMobileBtn:FindFirstChild("_TutHighlightScale")
		if sc and sc:IsA("UIScale") then
			sc.Scale = 1
		end
	end
	highlightedMobileBtn = nil
end

local function setMobileHighlight(actionKind: string?)
	clearMobileHighlight()
	if not actionKind or not isTouchOnlyDevice() then
		return
	end
	local btnName = MOBILE_BTN_BY_ACTION[actionKind]
	if not btnName then
		return
	end
	local mobileGui = playerGui:FindFirstChild("MobileBattleGui")
	local container = mobileGui and mobileGui:FindFirstChild("ButtonContainer")
	local btn = container and container:FindFirstChild(btnName)
	if not btn or not btn:IsA("GuiObject") then
		return
	end

	local sc = btn:FindFirstChild("_TutHighlightScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "_TutHighlightScale"
		sc.Parent = btn
	end
	if sc:IsA("UIScale") then
		sc.Scale = 1
		highlightedMobileBtn = btn
		highlightedMobileTween = TweenService:Create(
			sc,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.12 }
		)
		highlightedMobileTween:Play()
	end
end

-- ================================================================
-- VISUAL MODE, SPEAKER, MOOD, & ANIMATION HELPERS
-- ================================================================

local function applyMoodTheme(mood: string?)
	local m = mood or "normal"
	if m == "error" then
		frame.BackgroundColor3 = RED_ERROR
		innerBox.BackgroundColor3 = RED_DARK
	else
		frame.BackgroundColor3 = GREEN_MAIN
		innerBox.BackgroundColor3 = GREEN_DARK
	end
end

local function configureLayoutMode(mode: "lobby" | "battle")
	currentMode = mode
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromScale(0.54, 0.19)
	rootSizeLimit.MinSize = Vector2.new(360, 118)
	rootSizeLimit.MaxSize = Vector2.new(760, 168)

	speakerHolder.Visible = true
	body.Position = UDim2.fromOffset(18, 22)
	body.Size = UDim2.new(1, -36, 1, -68)
	bodyTextConstraint.MaxTextSize = 21

	contHolder.AnchorPoint = Vector2.new(1, 1)
	contHolder.Position = UDim2.new(1, -14, 1, -10)
	contHolder.Size = UDim2.fromOffset(0, 38)
	contSizeLimit.MinSize = Vector2.new(124, 38)
end

local function updateBattleBodyWidth(_hasRightWidget: boolean)
	-- Bentuk kotak battle sama persis dengan lobby; teks tetap memakai area atas yang lega
	if currentMode ~= "battle" then
		return
	end
	body.Position = UDim2.fromOffset(18, 22)
	body.Size = UDim2.new(1, -36, 1, -68)
	bodyTextConstraint.MaxTextSize = 21
end

local function updateContinueButtonLabels()
	local mobile = isTouchOnlyDevice()
	contKeycap.Visible = not mobile
	contLabel.Text = if mobile then "TAP LANJUT" else "LANJUT"
end

local function setSpeakerStyle(speakerKind: string)
	local changed = (currentSpeakerKind ~= speakerKind)
	currentSpeakerKind = speakerKind

	if speakerKind == "player" then
		speakerLabel.Text = string.upper(player.DisplayName or player.Name)
		speakerBg.BackgroundColor3 = GREEN_MAIN
		speakerLabel.TextColor3 = WHITE
		speakerTextStroke.Enabled = true
	else
		speakerLabel.Text = NPC_NAME
		speakerBg.BackgroundColor3 = GOLD_ACCENT
		speakerLabel.TextColor3 = OUTLINE_DARK
		speakerTextStroke.Enabled = false
	end

	if changed and root.Visible and speakerHolder.Visible then
		speakerScale.Scale = 1.12
		TweenService:Create(speakerScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
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
	for i, holder in ipairs(optionButtons) do
		local isSelected = (i == selectedChoiceIndex)
		local btn = holder:FindFirstChild("Btn") :: TextButton?
		local numBadge = btn and btn:FindFirstChild("NumBadge") :: TextLabel?
		local btnScale = holder:FindFirstChildOfClass("UIScale")

		if btn then
			btn.BackgroundColor3 = if isSelected then GREEN_MAIN else GREEN_DARK
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = if isSelected then UDim2.fromOffset(-4, 0) else UDim2.fromOffset(0, 0),
			}):Play()
		end
		if numBadge then
			numBadge.BackgroundColor3 = if isSelected then GOLD_ACCENT else GREEN_PASSIVE
			numBadge.TextColor3 = if isSelected then OUTLINE_DARK else WHITE
		end
		if btnScale and not holder:GetAttribute("_Pressing") then
			TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = if isSelected then 1.02 else 1,
			}):Play()
		end
	end
end

local function finishTypingNow(): boolean
	if not isTyping then
		return false
	end
	typeToken += 1
	isTyping = false
	body.MaxVisibleGraphemes = -1
	return true
end

local function typeText(text: string, onFinished: (() -> ())?)
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

local function stopBadgePulse()
	if badgePulse then
		badgePulse:Cancel()
		badgePulse = nil
	end
	badgeScale.Scale = 1
end

local function pulseBadge()
	stopBadgePulse()
	badgeScale.Scale = 1
	badgePulse = TweenService:Create(
		badgeScale,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
	)
	badgePulse:Play()
end

local function cancelVisTweens()
	if visScaleTween then
		visScaleTween:Cancel()
		visScaleTween = nil
	end
	if visPosTween then
		visPosTween:Cancel()
		visPosTween = nil
	end
end

local function animateBoxIn(mode: "lobby" | "battle")
	visToken += 1
	cancelVisTweens()
	local targetPos = if mode == "lobby" then LOBBY_POS else BATTLE_POS
	local startOffset = if mode == "lobby" then UDim2.fromOffset(0, 22) else UDim2.fromOffset(0, -18)

	if not root.Visible then
		root.Visible = true
		boxScale.Scale = 0.90
		root.Position = targetPos + startOffset
		visScaleTween = TweenService:Create(
			boxScale,
			TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		visPosTween = TweenService:Create(
			root,
			TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = targetPos }
		)
		visScaleTween:Play()
		visPosTween:Play()
	else
		root.Position = targetPos
		boxScale.Scale = 1
	end
end

local function animateBoxOut()
	if not root.Visible then
		return
	end
	visToken += 1
	cancelVisTweens()
	local token = visToken
	local targetPos = if currentMode == "lobby" then LOBBY_POS else BATTLE_POS
	local endOffset = if currentMode == "lobby" then UDim2.fromOffset(0, 18) else UDim2.fromOffset(0, -14)

	visScaleTween = TweenService:Create(
		boxScale,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.93 }
	)
	visPosTween = TweenService:Create(
		root,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = targetPos + endOffset }
	)
	visScaleTween:Play()
	visPosTween:Play()

	task.delay(0.15, function()
		if token == visToken then
			root.Visible = false
			boxScale.Scale = 1
			root.Position = targetPos
		end
	end)
end

local function popBox()
	if not root.Visible then
		return
	end
	boxScale.Scale = 1.05
	TweenService:Create(boxScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function shakeBox()
	if not root.Visible then
		return
	end
	shakeToken += 1
	local token = shakeToken
	local basePos = if currentMode == "lobby" then LOBBY_POS else BATTLE_POS
	task.spawn(function()
		local offsets = { -6, 6, -4, 4, -2, 0 }
		for _, dx in ipairs(offsets) do
			if token ~= shakeToken or not root.Visible then
				return
			end
			root.Position = basePos + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		if token == shakeToken then
			root.Position = basePos
		end
	end)
end

-- ================================================================
-- ACTION BADGE LOGIC (PC + MOBILE ADAPTIVE)
-- ================================================================

local ACTION_SPEC = {
	light = {
		pcText = "KLIK KIRI",
		mobileText = "TAP BIRU",
		icon = ASSET_IDS.LIGHT,
		bg = GOLD_ACCENT,
		fg = OUTLINE_DARK,
		stroke = false,
	},
	heavy = {
		pcText = "KLIK KANAN",
		mobileText = "TAP MERAH",
		icon = ASSET_IDS.HEAVY,
		bg = GOLD_ACCENT,
		fg = OUTLINE_DARK,
		stroke = false,
	},
	dodge = {
		pcText = "TEKAN Q",
		mobileText = "TAP KUNING",
		icon = ASSET_IDS.DODGE,
		bg = GOLD_ACCENT,
		fg = OUTLINE_DARK,
		stroke = false,
	},
}

local function configureActionBadge(data): boolean
	local actionKind = data.action
	local keyText = data.key
	local mood = data.mood

	if mood == "reward" then
		actionBadgeHolder.Visible = true
		actionBadgeBtn.BackgroundColor3 = GREEN_MAIN
		actionText.TextColor3 = WHITE
		actionTextStroke.Enabled = true
		actionText.Text = "MANTAP"
		actionIcon.Visible = false
		stopBadgePulse()
		return true
	end

	if not actionKind and not keyText then
		actionBadgeHolder.Visible = false
		stopBadgePulse()
		return false
	end

	local spec = actionKind and ACTION_SPEC[actionKind]
	local mobile = isTouchOnlyDevice()
	actionBadgeHolder.Visible = true

	if mood == "error" then
		actionBadgeBtn.BackgroundColor3 = RED_ERROR
		actionText.TextColor3 = WHITE
		actionTextStroke.Enabled = true
	else
		actionBadgeBtn.BackgroundColor3 = if spec then spec.bg else GOLD_ACCENT
		actionText.TextColor3 = if spec then spec.fg else OUTLINE_DARK
		actionTextStroke.Enabled = if spec then spec.stroke else false
	end

	if spec then
		actionText.Text = if mobile then spec.mobileText else spec.pcText
		local hasIcon = (not mobile) and type(spec.icon) == "string" and spec.icon ~= ""
		actionIcon.Image = if hasIcon then spec.icon else ""
		actionIcon.Visible = hasIcon
	else
		actionText.Text = string.upper(tostring(keyText))
		actionIcon.Visible = false
	end

	pulseBadge()
	return true
end

-- ================================================================
-- LOBBY DIALOG FLOW (WITH CHOICES + CAMERA SWITCHING)
-- ================================================================

local showLobbyNode -- forward declaration

local function closeLobbyDialog(triggerAction: string?)
	inLobbyDialog = false
	lobbySessionToken += 1
	currentNodeId = nil
	clearOptions()
	clearMobileHighlight()
	typeToken += 1
	isTyping = false
	canContinue = false
	contHolder.Visible = false
	animateBoxOut()

	restoreCamera()
	setMovementLocked(false)

	if triggerAction == "startTutorial" then
		promptEvent:FireServer("startTutorial")
	end
end

local function selectChoice(index: number)
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
	local token = lobbySessionToken

	for i, choice in ipairs(choices) do
		local holder = Instance.new("Frame")
		holder.Name = "Option_" .. i
		holder.LayoutOrder = i
		holder.Size = UDim2.new(1, 0, 0, 46)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 5
		holder.Parent = optionsContainer

		local optScale = Instance.new("UIScale")
		optScale.Scale = 0.92
		optScale.Parent = holder

		addSolidShadow(holder, 12, 4, 4)

		local btn = Instance.new("TextButton")
		btn.Name = "Btn"
		btn.Size = UDim2.fromScale(1, 1)
		btn.BackgroundColor3 = GREEN_DARK
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.ZIndex = 5
		btn.Parent = holder
		addCorner(btn, 12)
		addBorderStroke(btn, OUTLINE_DARK, 4)

		local numBadge = Instance.new("TextLabel")
		numBadge.Name = "NumBadge"
		numBadge.AnchorPoint = Vector2.new(0, 0.5)
		numBadge.Position = UDim2.new(0, 10, 0.5, 0)
		numBadge.Size = UDim2.fromOffset(28, 28)
		numBadge.BackgroundColor3 = GREEN_PASSIVE
		numBadge.BorderSizePixel = 0
		numBadge.Font = Enum.Font.FredokaOne
		numBadge.TextSize = 15
		numBadge.TextColor3 = WHITE
		numBadge.Text = tostring(i)
		numBadge.ZIndex = 6
		numBadge.Parent = btn
		addCorner(numBadge, 8)
		addBorderStroke(numBadge, OUTLINE_DARK, 3)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(48, 0)
		label.Size = UDim2.new(1, -58, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = WHITE
		label.Text = choice.text or ""
		label.ZIndex = 6
		label.Parent = btn
		addTextStroke(label, OUTLINE_DARK, 1.8)

		btn.MouseEnter:Connect(function()
			selectedChoiceIndex = i
			updateOptionHighlight()
		end)
		btn.MouseButton1Down:Connect(function()
			holder:SetAttribute("_Pressing", true)
			TweenService:Create(optScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 0.96,
			}):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			holder:SetAttribute("_Pressing", nil)
			updateOptionHighlight()
		end)
		btn.Activated:Connect(function()
			selectChoice(i)
		end)

		table.insert(optionButtons, holder)

		-- Staggered pop-in
		task.delay((i - 1) * 0.035, function()
			if token == lobbySessionToken and holder.Parent then
				TweenService:Create(optScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = if i == selectedChoiceIndex then 1.02 else 1,
				}):Play()
			end
		end)
	end

	updateOptionHighlight()
	optionsContainer.Visible = true
end

showLobbyNode = function(nodeId: string)
	local dialogTree = TutorialConfig.LOBBY_DIALOG
	local node = dialogTree and dialogTree[nodeId]
	if not node then
		closeLobbyDialog()
		return
	end

	currentNodeId = nodeId
	lobbyNodeShownAt = os.clock()
	choicesShownAt = 0
	local token = lobbySessionToken
	clearOptions()
	clearMobileHighlight()
	actionBadgeHolder.Visible = false
	stopBadgePulse()
	canContinue = false
	contHolder.Visible = false

	configureLayoutMode("lobby")
	applyMoodTheme("normal")
	animateBoxIn("lobby")
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
			choicesShownAt = os.clock()
			renderChoices(node.choices)
		elseif node.autoCloseDelay then
			task.delay(node.autoCloseDelay, function()
				if inLobbyDialog and token == lobbySessionToken and currentNodeId == nodeId then
					closeLobbyDialog(node.action)
				end
			end)
		else
			canContinue = true
			updateContinueButtonLabels()
			contHolder.Visible = true
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
	facePlayerTowardNpc()
	showLobbyNode("start")
end

-- ================================================================
-- BATTLE TUTORIAL PROMPT
-- ================================================================

local function showPrompt(data)
	if inLobbyDialog then
		closeLobbyDialog()
	end

	data = data or {}
	configureLayoutMode("battle")
	applyMoodTheme(data.mood)
	clearOptions()
	animateBoxIn("battle")
	setSpeakerStyle(data.speaker or "npc")

	canContinue = data.cont == true
	updateContinueButtonLabels()
	contHolder.Visible = canContinue

	local hasBadge = false
	if not canContinue then
		hasBadge = configureActionBadge(data)
	else
		actionBadgeHolder.Visible = false
		stopBadgePulse()
	end

	updateBattleBodyWidth(canContinue or hasBadge)
	setMobileHighlight(if not canContinue then data.action else nil)

	if data.mood == "reward" then
		popBox()
	elseif data.mood == "error" then
		shakeBox()
	end

	typeText(data.text or "")
end

local function hidePrompt()
	typeToken += 1
	isTyping = false
	canContinue = false
	clearOptions()
	clearMobileHighlight()
	stopBadgePulse()
	contHolder.Visible = false
	actionBadgeHolder.Visible = false
	animateBoxOut()
end

local function handleContinueAction()
	if inLobbyDialog then
		local dialogTree = TutorialConfig.LOBBY_DIALOG
		local node = dialogTree and currentNodeId and dialogTree[currentNodeId]
		if not node then
			return
		end

		if finishTypingNow() then
			if node.choices and #node.choices > 0 then
				if node.choiceFocus then
					focusCameraOn(node.choiceFocus)
				end
				renderChoices(node.choices)
			elseif node.nextNode then
				canContinue = true
				updateContinueButtonLabels()
				contHolder.Visible = true
			elseif node.autoCloseDelay then
				closeLobbyDialog(node.action)
			end
			return
		end

		if canContinue and node.nextNode then
			canContinue = false
			contHolder.Visible = false
			showLobbyNode(node.nextNode)
		elseif canContinue then
			closeLobbyDialog(node.action)
		end
		return
	end

	if not canContinue then
		return
	end
	canContinue = false
	contHolder.Visible = false
	promptEvent:FireServer("continue")
end

contBtn.Activated:Connect(handleContinueAction)
frame.Activated:Connect(function()
	if inLobbyDialog then
		if currentChoices and not isTyping then
			return
		end
		handleContinueAction()
	elseif canContinue then
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
		local now = os.clock()
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
				(now - choicesShownAt >= 0.28)
				and (
					input.KeyCode == Enum.KeyCode.Return
					or input.KeyCode == Enum.KeyCode.Space
					or (not processed and input.KeyCode == Enum.KeyCode.E)
				)
			then
				selectChoice(selectedChoiceIndex)
				return
			end
		end

		if
			(now - lobbyNodeShownAt >= 0.28)
			and (
				input.KeyCode == Enum.KeyCode.Space
				or input.KeyCode == Enum.KeyCode.Return
				or (not processed and input.KeyCode == Enum.KeyCode.E)
			)
		then
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

local function shakeCamera(strength: number, duration: number)
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

local function fovPunch(amount: number, duration: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local base = cam.FieldOfView
	cam.FieldOfView = base + amount
	TweenService:Create(cam, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = base,
	}):Play()
end

local function doFlash(color: Color3, alpha: number, duration: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = alpha
	TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

local function playFx(kind: string)
	if kind == "hit" then
		shakeCamera(0.6, 0.18)
		fovPunch(-4, 0.2)
		popBox()
	elseif kind == "heavy" then
		shakeCamera(1.4, 0.35)
		fovPunch(-8, 0.3)
		doFlash(WHITE, 0.7, 0.25)
		popBox()
	elseif kind == "good" then
		fovPunch(-5, 0.25)
		doFlash(Color3.fromRGB(120, 255, 170), 0.8, 0.35)
		popBox()
	elseif kind == "bad" then
		shakeCamera(1.0, 0.3)
		doFlash(RED_ERROR, 0.68, 0.4)
		shakeBox()
	elseif kind == "telegraph" then
		fovPunch(6, 0.35)
		doFlash(RED_ERROR, 0.86, 0.3)
	elseif kind == "win" then
		shakeCamera(0.8, 0.4)
		doFlash(GOLD_ACCENT, 0.65, 0.6)
		popBox()
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
