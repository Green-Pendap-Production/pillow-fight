-- @ScriptType: LocalScript
--[[
	Nama File : TutorialPromptClient
	Layer     : Client (UI)
	Deskripsi : Dialog "Sir Nattos" (efek ketik, badge tombol berdenyut, tombol Lanjut)
	            + efek: slow-mo, screen shake, FOV punch, flash.
	Dependensi: ReplicatedStorage > Remotes > TutorialPromptEvent
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local promptEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialPromptEvent")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SPEAKER = "SIR NATTOS"
local TYPE_SPEED = 0.022 -- detik per huruf

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialPrompt"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.fromScale(0.5, 0.93)
frame.Size = UDim2.fromScale(0.55, 0.2)
frame.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
frame.BackgroundTransparency = 0.1
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Parent = frame
stroke.Color = Color3.fromRGB(255, 190, 70)
stroke.Thickness = 3
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.Parent = frame
sizeLimit.MinSize = Vector2.new(360, 110)
local scale = Instance.new("UIScale")
scale.Parent = frame

local speaker = Instance.new("TextLabel")
speaker.BackgroundTransparency = 1
speaker.Position = UDim2.fromScale(0.03, 0.06)
speaker.Size = UDim2.fromScale(0.35, 0.2)
speaker.Font = Enum.Font.GothamBlack
speaker.TextScaled = true
speaker.TextXAlignment = Enum.TextXAlignment.Left
speaker.TextColor3 = Color3.fromRGB(255, 190, 70)
speaker.Text = SPEAKER
speaker.Parent = frame

local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromScale(0.03, 0.28)
body.Size = UDim2.fromScale(0.94, 0.45)
body.Font = Enum.Font.GothamBold
body.TextWrapped = true
body.TextScaled = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = Color3.new(1, 1, 1)
body.Text = ""
body.Parent = frame
Instance.new("UITextSizeConstraint", body).MaxTextSize = 26

local keyBadge = Instance.new("TextLabel")
keyBadge.AnchorPoint = Vector2.new(0, 1)
keyBadge.Position = UDim2.fromScale(0.03, 0.94)
keyBadge.Size = UDim2.fromScale(0.15, 0.2)
keyBadge.BackgroundColor3 = Color3.fromRGB(255, 190, 70)
keyBadge.Font = Enum.Font.GothamBlack
keyBadge.TextSize = 22
--keyBadge.TextScaled = true
keyBadge.TextColor3 = Color3.fromRGB(30, 20, 10)
keyBadge.Visible = false
keyBadge.Parent = frame
Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 8)
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = keyBadge

local contBtn = Instance.new("TextButton")
contBtn.AnchorPoint = Vector2.new(1, 1)
contBtn.Position = UDim2.fromScale(0.97, 0.94)
contBtn.Size = UDim2.fromScale(0.25, 0.2)
contBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
contBtn.Font = Enum.Font.GothamBlack
contBtn.TextScaled = true
contBtn.Text = "LANJUT [E]"
contBtn.TextColor3 = Color3.new(1, 1, 1)
contBtn.Visible = false
contBtn.Parent = frame
Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 8)

-- Efek layar
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

local typeToken = 0
local badgePulse
local canContinue = false

local function typeText(text)
	typeToken += 1
	local token = typeToken
	body.Text = text
	body.MaxVisibleGraphemes = 0
	task.spawn(function()
		for i = 1, utf8.len(text) or #text do
			if token ~= typeToken then
				return
			end
			body.MaxVisibleGraphemes = i
			task.wait(TYPE_SPEED)
		end
		body.MaxVisibleGraphemes = -1
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

local function showPrompt(data)
	data = data or {}
	local wasVisible = frame.Visible
	frame.Visible = true
	if not wasVisible then
		scale.Scale = 0.85
		frame.Position = UDim2.fromScale(0.5, 1.05)
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService
			:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.93) })
			:Play()
	end

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
	canContinue = false
	if badgePulse then
		badgePulse:Cancel()
	end
	frame.Visible = false
end

local function sendContinue()
	if not canContinue then
		return
	end
	canContinue = false
	contBtn.Visible = false
	promptEvent:FireServer("continue")
end

contBtn.Activated:Connect(sendContinue)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		sendContinue()
	end
end)

-- Screen shake lewat Humanoid.CameraOffset (tidak bentrok dengan script kamera)
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
	if kind == "show" then
		showPrompt(data)
	elseif kind == "hide" then
		hidePrompt()
	elseif kind == "slowmo" then
		TweenService:Create(colorFx, TweenInfo.new(0.25), data and SLOW_ON or SLOW_OFF):Play()
	elseif kind == "fx" then
		playFx(data)
	end
end)

local hookedDialogs = {}

local function hookDialog(dialog)
	if hookedDialogs[dialog] then
		return
	end
	hookedDialogs[dialog] = true

	dialog.DialogChoiceSelected:Connect(function(playerWhoSelected, choice)
		if playerWhoSelected == player then
			local userText = string.lower(choice.UserDialog or "")
			if
				choice.Name == "StartTutorial"
				or string.find(userText, "latihan")
				or string.find(userText, "tarung")
			then
				print("[TutorialPromptClient] Pemain memilih latihan, mengirim startTutorial ke server...")
				promptEvent:FireServer("startTutorial")
			end
		end
	end)
end

local function scanForSirNattos()
	local npc = workspace:FindFirstChild("Sir Nattos", true)
	if npc then
		local head = npc:FindFirstChild("Head") or npc:WaitForChild("Head", 3)
		if head then
			local dialog = head:FindFirstChildOfClass("Dialog") or head:WaitForChild("Dialog", 3)
			if dialog then
				hookDialog(dialog)
			end
		end
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Dialog") then
			local model = descendant:FindFirstAncestorOfClass("Model")
			if model and model.Name == "Sir Nattos" then
				hookDialog(descendant)
			end
		end
	end)
end

task.spawn(scanForSirNattos)
