-- @ScriptType: LocalScript
--[[
    Nama File  : EmojiWheelClient
    Layer      : Client (UI)
    Deskripsi  : Tombol emoji di kanan-tengah layar saat match berlangsung.
                 Bisa di-drag langsung (Mouse/Touch) atau pakai shortcut
                 tahan tombol [Tab] + arahkan mouse untuk membuka kipas emoji
                 (ala Mobile Legends); lepas untuk mengirim emoji ke atas
                 kepala karakter.
    Dependensi : - ReplicatedStorage > Configs > EmojiConfig
                 - ReplicatedStorage > Remotes > EmojiEvent
                 - ReplicatedStorage > Remotes > MatchLockEvent
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EmojiConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("EmojiConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local EmojiEvent = remotes:WaitForChild("EmojiEvent")
local MatchLockEvent = remotes:WaitForChild("MatchLockEvent")

-- ================================================================
-- CONSTANTS & PALETTE (selaras dengan ResultScreenClient)
-- ================================================================
local TRIGGER_SIZE = 62
local SLOT_SIZE = 80
local TRIGGER_CORNER = 16
local SLOT_CORNER = 16
local BUBBLE_CORNER = 18
local MAX_SELECT_DIST = EmojiConfig.FAN_RADIUS + 125
local RESULT_SCREEN_ATTRIBUTE = "ResultScreenOpen"

local WHITE = Color3.new(1, 1, 1)
local TRIGGER_TOP = Color3.fromRGB(255, 225, 90)
local TRIGGER_BOTTOM = Color3.fromRGB(240, 165, 25)
local TRIGGER_STROKE = Color3.fromRGB(95, 50, 10)
local TRIGGER_SHADOW = Color3.fromRGB(150, 92, 12)

-- ================================================================
-- UI HELPERS
-- ================================================================
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function addTextStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function addGradient(parent, topColor, bottomColor)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function populateEmojiVisual(parent, emoji, textSize)
	if emoji.image and emoji.image ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(0.84, 0.84)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.BackgroundTransparency = 1
		img.Image = emoji.image
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = parent.ZIndex + 1
		img.Parent = parent
		addCorner(img, 10)
	else
		local sym = Instance.new("TextLabel")
		sym.Size = UDim2.fromScale(1, 1)
		sym.BackgroundTransparency = 1
		sym.Font = Enum.Font.GothamBlack
		sym.Text = emoji.symbol
		sym.TextColor3 = WHITE
		sym.TextSize = textSize or 18
		sym.ZIndex = parent.ZIndex + 1
		sym.Parent = parent
		addTextStroke(sym, emoji.rimColor, 2.5)
	end
end

-- ================================================================
-- BUILD UI
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EmojiWheelGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 12
screenGui.Enabled = false
screenGui.Parent = playerGui

local anchor = Instance.new("Frame")
anchor.Name = "Anchor"
anchor.AnchorPoint = Vector2.new(1, 0.5)
anchor.Position = UDim2.new(1, -20, 0.5, 0)
anchor.Size = UDim2.fromOffset(TRIGGER_SIZE, TRIGGER_SIZE)
anchor.BackgroundTransparency = 1
anchor.Parent = screenGui

-- Shadow 3D di bawah tombol utama
local triggerShadow = Instance.new("Frame")
triggerShadow.Name = "TriggerShadow"
triggerShadow.Position = UDim2.fromOffset(0, 4)
triggerShadow.Size = UDim2.fromScale(1, 1)
triggerShadow.BackgroundColor3 = TRIGGER_SHADOW
triggerShadow.BorderSizePixel = 0
triggerShadow.ZIndex = 4
triggerShadow.Parent = anchor
addCorner(triggerShadow, TRIGGER_CORNER)

local triggerBtn = Instance.new("TextButton")
triggerBtn.Name = "EmojiTrigger"
triggerBtn.Size = UDim2.fromScale(1, 1)
triggerBtn.BackgroundColor3 = WHITE
triggerBtn.BorderSizePixel = 0
triggerBtn.Text = ":D"
triggerBtn.Font = Enum.Font.GothamBlack
triggerBtn.TextSize = 24
triggerBtn.TextColor3 = WHITE
triggerBtn.AutoButtonColor = false
triggerBtn.ZIndex = 5
triggerBtn.Parent = anchor
addCorner(triggerBtn, TRIGGER_CORNER)
addGradient(triggerBtn, TRIGGER_TOP, TRIGGER_BOTTOM)
local triggerStroke = addStroke(triggerBtn, TRIGGER_STROKE, 3, 0)
addTextStroke(triggerBtn, TRIGGER_STROKE, 2.5)

local triggerScale = Instance.new("UIScale")
triggerScale.Scale = 1
triggerScale.Parent = triggerBtn

-- Keycap badge "[TAB]" di bawah tombol
local tabBadge = Instance.new("Frame")
tabBadge.Name = "TabBadge"
tabBadge.AnchorPoint = Vector2.new(0.5, 0)
tabBadge.Position = UDim2.new(0.5, 0, 1, 6)
tabBadge.Size = UDim2.fromOffset(42, 18)
tabBadge.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
tabBadge.BorderSizePixel = 0
tabBadge.ZIndex = 6
tabBadge.Parent = anchor
addCorner(tabBadge, 6)
addStroke(tabBadge, Color3.fromRGB(16, 18, 28), 2, 0)

local tabBadgeText = Instance.new("TextLabel")
tabBadgeText.Size = UDim2.fromScale(1, 1)
tabBadgeText.BackgroundTransparency = 1
tabBadgeText.Font = Enum.Font.GothamBlack
tabBadgeText.Text = "TAB"
tabBadgeText.TextColor3 = Color3.fromRGB(235, 240, 255)
tabBadgeText.TextSize = 10
tabBadgeText.ZIndex = 7
tabBadgeText.Parent = tabBadge

-- Overlay cooldown di atas tombol utama
local cooldownOverlay = Instance.new("Frame")
cooldownOverlay.Name = "CooldownOverlay"
cooldownOverlay.Size = UDim2.fromScale(1, 1)
cooldownOverlay.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
cooldownOverlay.BackgroundTransparency = 0.28
cooldownOverlay.BorderSizePixel = 0
cooldownOverlay.Visible = false
cooldownOverlay.ZIndex = 8
cooldownOverlay.Parent = triggerBtn
addCorner(cooldownOverlay, TRIGGER_CORNER)

local cdLabel = Instance.new("TextLabel")
cdLabel.Size = UDim2.fromScale(1, 1)
cdLabel.BackgroundTransparency = 1
cdLabel.Font = Enum.Font.GothamBlack
cdLabel.Text = ""
cdLabel.TextColor3 = WHITE
cdLabel.TextSize = 16
cdLabel.ZIndex = 9
cdLabel.Parent = cooldownOverlay
addTextStroke(cdLabel, Color3.fromRGB(15, 18, 26), 2)

-- Build slot-slot kipas
local slots = {}
local count = #EmojiConfig.EMOJIS
local spreadRad = math.rad(EmojiConfig.FAN_SPREAD_DEG)

for index, emoji in ipairs(EmojiConfig.EMOJIS) do
	local t = (count > 1) and ((index - 1) / (count - 1) - 0.5) or 0
	local angle = math.pi + t * spreadRad -- menghadap ke kiri (pi rad)
	local dir = Vector2.new(math.cos(angle), math.sin(angle))
	local targetOffset = dir * EmojiConfig.FAN_RADIUS

	local slotHolder = Instance.new("Frame")
	slotHolder.Name = "Slot_" .. emoji.id
	slotHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	slotHolder.Position = UDim2.fromScale(0.5, 0.5)
	slotHolder.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	slotHolder.BackgroundTransparency = 1
	slotHolder.Visible = false
	slotHolder.ZIndex = 3
	slotHolder.Parent = anchor

	local slotScale = Instance.new("UIScale")
	slotScale.Scale = 0.4
	slotScale.Parent = slotHolder

	-- Shadow 3D di bawah medali emoji
	local slotShadow = Instance.new("Frame")
	slotShadow.Position = UDim2.fromOffset(0, 4)
	slotShadow.Size = UDim2.fromScale(1, 1)
	slotShadow.BackgroundColor3 = emoji.rimColor
	slotShadow.BorderSizePixel = 0
	slotShadow.ZIndex = 2
	slotShadow.Parent = slotHolder
	addCorner(slotShadow, SLOT_CORNER)

	-- Medali emoji dengan gradient + outline tebal
	local medal = Instance.new("Frame")
	medal.Size = UDim2.fromScale(1, 1)
	medal.BackgroundColor3 = WHITE
	medal.BorderSizePixel = 0
	medal.ZIndex = 3
	medal.Parent = slotHolder
	addCorner(medal, SLOT_CORNER)
	addGradient(medal, emoji.topColor, emoji.bottomColor)
	local slotStroke = addStroke(medal, emoji.rimColor, 3, 0)

	populateEmojiVisual(medal, emoji, 18)

	-- Pill label saat di-hover
	local tag = Instance.new("TextLabel")
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 0, 1, 7)
	tag.Size = UDim2.fromOffset(66, 20)
	tag.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.GothamBlack
	tag.Text = emoji.label
	tag.TextColor3 = WHITE
	tag.TextSize = 11
	tag.Visible = false
	tag.ZIndex = 10
	tag.Parent = slotHolder
	addCorner(tag, 7)
	addStroke(tag, emoji.rimColor, 2, 0)

	slots[index] = {
		emoji = emoji,
		holder = slotHolder,
		stroke = slotStroke,
		scale = slotScale,
		tag = tag,
		dir = dir,
		targetOffset = targetOffset,
	}
end

-- ================================================================
-- RADIAL FAN INTERACTION (DRAG BUTTON + SHORTCUT TAB)
-- ================================================================
local isInMatch = false
local isFanOpen = false
local openMode = nil -- "pointer" | "tab"
local activeInput = nil
local tabOriginMousePos = nil
local hoveredIndex = nil
local cooldownUntil = 0

local function setHoveredSlot(newIndex)
	if hoveredIndex == newIndex then
		return
	end
	if hoveredIndex and slots[hoveredIndex] then
		local prev = slots[hoveredIndex]
		prev.tag.Visible = false
		prev.stroke.Color = prev.emoji.rimColor
		prev.stroke.Thickness = 3
		TweenService:Create(prev.scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end

	hoveredIndex = newIndex

	if hoveredIndex and slots[hoveredIndex] then
		local curr = slots[hoveredIndex]
		curr.tag.Visible = true
		curr.stroke.Color = WHITE
		curr.stroke.Thickness = 3.5
		TweenService:Create(curr.scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.25,
		}):Play()
	end
end

local function openFan(mode)
	if isFanOpen then
		return
	end
	isFanOpen = true
	openMode = mode
	hoveredIndex = nil

	TweenService:Create(triggerScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 0.92 }):Play()
	triggerStroke.Color = WHITE

	for _, slot in ipairs(slots) do
		slot.holder.Visible = true
		slot.holder.Position = UDim2.fromScale(0.5, 0.5)
		slot.scale.Scale = 0.35
		slot.tag.Visible = false
		slot.stroke.Color = slot.emoji.rimColor
		slot.stroke.Thickness = 3

		TweenService:Create(
			slot.holder,
			TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, slot.targetOffset.X, 0.5, slot.targetOffset.Y) }
		):Play()
		TweenService
			:Create(slot.scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

local function closeFan()
	if not isFanOpen then
		return
	end
	isFanOpen = false
	openMode = nil
	activeInput = nil
	tabOriginMousePos = nil
	setHoveredSlot(nil)

	TweenService:Create(triggerScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	triggerStroke.Color = TRIGGER_STROKE

	for _, slot in ipairs(slots) do
		local posTween = TweenService:Create(
			slot.holder,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 0.5) }
		)
		TweenService:Create(slot.scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.3,
		}):Play()
		posTween:Play()
		posTween.Completed:Connect(function()
			if not isFanOpen then
				slot.holder.Visible = false
			end
		end)
	end
end

local function startCooldownVisual()
	cooldownOverlay.Visible = true
	task.spawn(function()
		while true do
			local remaining = cooldownUntil - os.clock()
			if remaining <= 0 then
				cooldownOverlay.Visible = false
				cdLabel.Text = ""
				return
			end
			cdLabel.Text = string.format("%.1f", remaining)
			task.wait(0.1)
		end
	end)
end

local function sendChosenEmoji(chosenIndex)
	if chosenIndex and slots[chosenIndex] and os.clock() >= cooldownUntil then
		cooldownUntil = os.clock() + EmojiConfig.COOLDOWN
		startCooldownVisual()
		EmojiEvent:FireServer(slots[chosenIndex].emoji.id)
	end
end

local function updateHoverFromPointerDrag(screenPos)
	local center = anchor.AbsolutePosition + anchor.AbsoluteSize * 0.5
	local delta = Vector2.new(screenPos.X, screenPos.Y) - center
	local dist = delta.Magnitude

	if dist < EmojiConfig.CANCEL_RADIUS or dist > MAX_SELECT_DIST then
		setHoveredSlot(nil)
		return
	end

	local bestIndex = nil
	local bestDist = math.huge
	for i, slot in ipairs(slots) do
		local d = (delta - slot.targetOffset).Magnitude
		if d < bestDist then
			bestDist = d
			bestIndex = i
		end
	end
	setHoveredSlot(bestIndex)
end

-- Mode Tab: arah gerak mouse dari posisi awal saat Tab ditekan dipetakan ke kipas.
-- Gerak ke atas -> slot paling atas, ke kiri -> slot tengah, ke bawah -> slot bawah.
local function updateHoverFromTabDirection(mousePos)
	if not tabOriginMousePos then
		return
	end
	local delta = Vector2.new(mousePos.X, mousePos.Y) - tabOriginMousePos
	if delta.Magnitude < EmojiConfig.TAB_DEADZONE then
		setHoveredSlot(nil)
		return
	end

	local unitDir = Vector2.new(-math.max(0.25, math.abs(delta.X)), delta.Y).Unit
	local bestIndex = nil
	local bestDot = -math.huge
	for i, slot in ipairs(slots) do
		local dot = unitDir:Dot(slot.dir)
		if dot > bestDot then
			bestDot = dot
			bestIndex = i
		end
	end
	setHoveredSlot(bestIndex)
end

local function refreshVisibility()
	local resultOpen = player:GetAttribute(RESULT_SCREEN_ATTRIBUTE) == true
	screenGui.Enabled = isInMatch and not resultOpen
	if not screenGui.Enabled and isFanOpen then
		closeFan()
	end
end

triggerBtn.InputBegan:Connect(function(input)
	if not screenGui.Enabled or isFanOpen then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeInput = input
		openFan("pointer")
		updateHoverFromPointerDrag(input.Position)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not screenGui.Enabled or isFanOpen then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		tabOriginMousePos = UserInputService:GetMouseLocation()
		openFan("tab")
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not isFanOpen then
		return
	end
	if openMode == "pointer" and activeInput then
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseMovement then
			updateHoverFromPointerDrag(input.Position)
		end
	elseif openMode == "tab" and input.UserInputType == Enum.UserInputType.MouseMovement then
		updateHoverFromTabDirection(UserInputService:GetMouseLocation())
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not isFanOpen then
		return
	end

	if openMode == "pointer" and activeInput then
		local isSameTouch = (input == activeInput)
		local isMouseRelease = (
			activeInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1
		)
		if isSameTouch or isMouseRelease then
			local chosenIndex = hoveredIndex
			closeFan()
			sendChosenEmoji(chosenIndex)
		end
	elseif openMode == "tab" and input.KeyCode == Enum.KeyCode.Tab then
		local chosenIndex = hoveredIndex
		closeFan()
		sendChosenEmoji(chosenIndex)
	end
end)

-- ================================================================
-- OVERHEAD WORLD DISPLAY
-- ================================================================
local EMOJI_SOUND = EmojiConfig.SOUND or {}

-- Bunyi emoji, 3D dari kepala pengirim. Sound dibuat per pemutaran lalu
-- dibuang setelah selesai -- emoji dibatasi cooldown, jadi tidak menumpuk.
-- Ikut master SFX (attribute SFXVolume di SoundService) seperti
-- SoundController, supaya slider volume SFX juga mengecilkan emoji.
local function playEmojiSound(adornee, emoji)
	if type(emoji.sound) ~= "string" or emoji.sound == "" then
		return
	end

	local sfxMaster = SoundService:GetAttribute("SFXVolume")
	local sfxMult = if type(sfxMaster) == "number" then math.clamp(sfxMaster, 0, 1) else 1
	if sfxMult <= 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "EmojiSound"
	sound.SoundId = emoji.sound
	sound.Volume = (EMOJI_SOUND.VOLUME or 1) * sfxMult
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = EMOJI_SOUND.ROLLOFF_MIN_DISTANCE or 12
	sound.RollOffMaxDistance = EMOJI_SOUND.ROLLOFF_MAX_DISTANCE or 85
	sound.Parent = adornee

	sound.Ended:Once(function()
		sound:Destroy()
	end)
	-- Jaring pengaman kalau Ended tidak pernah datang (asset gagal load /
	-- masih dimoderasi): jangan biarkan Sound menumpuk di kepala karakter.
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)

	sound:Play()
end

local function showOverheadEmoji(sender, emoji)
	if not sender or not sender.Character then
		return
	end
	local adornee = sender.Character:FindFirstChild("Head") or sender.Character:FindFirstChild("HumanoidRootPart")
	if not adornee then
		return
	end

	local existing = adornee:FindFirstChild("EmojiBillboard")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EmojiBillboard"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(96, 96)
	billboard.StudsOffset = Vector3.new(0, 2.9, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 85
	billboard.Parent = adornee

	playEmojiSound(adornee, emoji)

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromScale(0.9, 0.9)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 0.1
	scale.Parent = container

	local shadow = Instance.new("Frame")
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = emoji.rimColor
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = container
	addCorner(shadow, BUBBLE_CORNER)

	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = WHITE
	bubble.BorderSizePixel = 0
	bubble.ZIndex = 2
	bubble.Parent = container
	addCorner(bubble, BUBBLE_CORNER)
	addGradient(bubble, emoji.topColor, emoji.bottomColor)
	addStroke(bubble, emoji.rimColor, 3.5, 0)

	populateEmojiVisual(bubble, emoji, 26)

	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not billboard.Parent then
			conn:Disconnect()
			return
		end
		elapsed += dt
		local bob = math.sin(elapsed * 5.2) * 0.18
		billboard.StudsOffset = Vector3.new(0, 2.8 + bob, 0)
	end)

	task.delay(EmojiConfig.DISPLAY_DURATION, function()
		if conn then
			conn:Disconnect()
		end
		if not billboard.Parent then
			return
		end
		local out = TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0.05 }
		)
		out:Play()
		out.Completed:Connect(function()
			if billboard.Parent then
				billboard:Destroy()
			end
		end)
	end)
end

EmojiEvent.OnClientEvent:Connect(function(sender, emojiId)
	local emoji = EmojiConfig.getById(emojiId)
	if emoji then
		showOverheadEmoji(sender, emoji)
	end
end)

MatchLockEvent.OnClientEvent:Connect(function(locked)
	isInMatch = locked == true
	refreshVisibility()
end)

player:GetAttributeChangedSignal(RESULT_SCREEN_ATTRIBUTE):Connect(refreshVisibility)

print("[EmojiWheelClient] Ready")
