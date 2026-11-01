-- @ScriptType: LocalScript
--[[
    Nama File  : CoinHudClient.lua
    Layer      : Client (UI)
    Deskripsi  : Nampilin saldo virtual coin di pojok kanan atas + popup
                 "+X" (dengan breakdown Win/Streak/dll) tiap match selesai.
                 GUI-nya dibikin lewat script, gak perlu nyiapin apa-apa di
                 Studio -- tinggal taruh di StarterPlayerScripts.

                 Sumber data:
                 - player Attribute "Coins" (di-set CoinService di server) ->
                   saldo. Attribute ke-replicate otomatis, jadi aman walau
                   script ini jalan telat.
                 - Remotes.CoinRewardEvent -> payload popup reward.
                 - Remotes.MatchLockEvent  -> HUD disembunyiin selama match
                   (kayak UI lobby lainnya, lihat MatchUIVisibilityClient).
                   Reward yang masuk pas masih di match ditahan dulu, baru
                   dipopup begitu balik ke lobby.
    Tanggal    : 17 Oktober 2026
    Versi      : 1.0
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CoinRewardEvent = remotes:WaitForChild("CoinRewardEvent")
local MatchLockEvent = remotes:WaitForChild("MatchLockEvent")

-- ================================================================
-- CONFIG
-- ================================================================
local COINS_ATTRIBUTE = "Coins"

-- Kosongin buat pakai coin gambar-sendiri (Frame bulat); isi "rbxassetid://..."
-- kalau udah ada icon coin. JANGAN pakai emoji 🪙 -- font emoji Roblox belum
-- support, jadinya cuma kotak kosong.
local COIN_ICON_IMAGE = ""

-- Posisi panel (pojok kanan atas, di bawah safe-area topbar)
local PANEL_ANCHOR = Vector2.new(1, 0)
local PANEL_POSITION = UDim2.new(1, -16, 0, 12)
local PANEL_SIZE = Vector2.new(150, 40)

local REFERENCE_WIDTH = 1280
local MIN_UI_SCALE = 0.85
local MAX_UI_SCALE = 1.35

local COLOR_GOLD = Color3.fromRGB(255, 205, 60)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_PANEL = Color3.fromRGB(20, 20, 28)

local COUNT_UP_DURATION = 0.8 -- detik animasi angka naik
local TOAST_HOLD = 2.2 -- detik popup "+X" diam sebelum fade
local TOAST_FADE = 0.5

-- ================================================================
-- BUILD UI
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHudGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "CoinPanel"
panel.AnchorPoint = PANEL_ANCHOR
panel.Position = PANEL_POSITION
panel.Size = UDim2.new(0, PANEL_SIZE.X, 0, PANEL_SIZE.Y)
panel.BackgroundColor3 = COLOR_PANEL
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Parent = screenGui

do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_GOLD
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = panel
end

local uiScale = Instance.new("UIScale")
uiScale.Parent = panel

local icon
if COIN_ICON_IMAGE ~= "" then
	icon = Instance.new("ImageLabel")
	icon.Image = COIN_ICON_IMAGE
	icon.ScaleType = Enum.ScaleType.Fit
	icon.BackgroundTransparency = 1
else
	-- Coin digambar dari Frame: lingkaran emas + ring gelap + huruf "C"
	icon = Instance.new("Frame")
	icon.BackgroundColor3 = COLOR_GOLD
	icon.BorderSizePixel = 0

	local circle = Instance.new("UICorner")
	circle.CornerRadius = UDim.new(1, 0)
	circle.Parent = icon

	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(190, 130, 20)
	rim.Thickness = 2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = icon

	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.Text = "C"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(150, 95, 10)
	mark.Parent = icon

	local markPadding = Instance.new("UIPadding")
	markPadding.PaddingTop = UDim.new(0.18, 0)
	markPadding.PaddingBottom = UDim.new(0.18, 0)
	markPadding.Parent = mark
end
icon.Name = "Icon"
icon.AnchorPoint = Vector2.new(0, 0.5)
icon.Position = UDim2.new(0, 8, 0.5, 0)
icon.Size = UDim2.new(0, 26, 0, 26)
icon.Parent = panel

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "Amount"
amountLabel.BackgroundTransparency = 1
amountLabel.AnchorPoint = Vector2.new(1, 0.5)
amountLabel.Position = UDim2.new(1, -12, 0.5, 0)
amountLabel.Size = UDim2.new(1, -52, 1, -8)
amountLabel.Font = Enum.Font.GothamBold
amountLabel.TextSize = 20
amountLabel.TextColor3 = COLOR_TEXT
amountLabel.TextXAlignment = Enum.TextXAlignment.Right
amountLabel.Text = "0"
amountLabel.Parent = panel

-- Popup reward, nongol di bawah panel
local toast = Instance.new("Frame")
toast.Name = "RewardToast"
toast.AnchorPoint = Vector2.new(1, 0)
toast.Position = UDim2.new(1, 0, 1, 6)
toast.Size = UDim2.new(0, 220, 0, 48)
toast.BackgroundTransparency = 1
toast.Visible = false
toast.Parent = panel

local toastAmount = Instance.new("TextLabel")
toastAmount.Name = "Total"
toastAmount.BackgroundTransparency = 1
toastAmount.Size = UDim2.new(1, 0, 0, 28)
toastAmount.Font = Enum.Font.GothamBlack
toastAmount.TextSize = 26
toastAmount.TextColor3 = COLOR_GOLD
toastAmount.TextXAlignment = Enum.TextXAlignment.Right
toastAmount.TextStrokeTransparency = 0.4
toastAmount.Parent = toast

local toastDetail = Instance.new("TextLabel")
toastDetail.Name = "Breakdown"
toastDetail.BackgroundTransparency = 1
toastDetail.Position = UDim2.new(0, 0, 0, 28)
toastDetail.Size = UDim2.new(1, 0, 0, 18)
toastDetail.Font = Enum.Font.GothamMedium
toastDetail.TextSize = 14
toastDetail.TextColor3 = COLOR_TEXT
toastDetail.TextXAlignment = Enum.TextXAlignment.Right
toastDetail.TextStrokeTransparency = 0.5
toastDetail.Parent = toast

-- ================================================================
-- RESPONSIVE SCALE
-- ================================================================
local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewportX = camera and camera.ViewportSize.X or REFERENCE_WIDTH
	if viewportX <= 0 then
		return
	end

	local scaleFactor = math.clamp(viewportX / REFERENCE_WIDTH, MIN_UI_SCALE, MAX_UI_SCALE)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		scaleFactor = math.clamp(scaleFactor * 1.08, MIN_UI_SCALE, MAX_UI_SCALE + 0.1)
	end
	uiScale.Scale = scaleFactor
end

updateScale()

do
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCamera = Workspace.CurrentCamera
		if newCamera then
			newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
end

-- ================================================================
-- SALDO (count-up animation)
-- ================================================================
local function formatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local displayValue = Instance.new("NumberValue")
displayValue.Value = player:GetAttribute(COINS_ATTRIBUTE) or 0
amountLabel.Text = formatNumber(displayValue.Value)

displayValue.Changed:Connect(function(value)
	amountLabel.Text = formatNumber(value)
end)

local countTween
local function animateBalanceTo(target)
	if countTween then
		countTween:Cancel()
	end
	countTween = TweenService:Create(
		displayValue,
		TweenInfo.new(COUNT_UP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = target }
	)
	countTween:Play()
end

-- ================================================================
-- REWARD POPUP
-- ================================================================
local isInMatch = false
local pendingReward = nil
local toastToken = 0

local function setToastTransparency(alpha)
	toastAmount.TextTransparency = alpha
	toastAmount.TextStrokeTransparency = 0.4 + 0.6 * alpha
	toastDetail.TextTransparency = alpha
	toastDetail.TextStrokeTransparency = 0.5 + 0.5 * alpha
end

local function showReward(payload)
	local total = tonumber(payload.total) or 0
	animateBalanceTo(player:GetAttribute(COINS_ATTRIBUTE) or displayValue.Value)

	if total <= 0 then
		return
	end

	local parts = {}
	for _, item in ipairs(payload.breakdown or {}) do
		table.insert(parts, string.format("%s +%d", tostring(item.label), tonumber(item.amount) or 0))
	end

	toastAmount.Text = "+" .. formatNumber(total)
	toastDetail.Text = table.concat(parts, "  •  ")

	toastToken += 1
	local myToken = toastToken

	setToastTransparency(0)
	toast.Position = UDim2.new(1, 0, 1, 16)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 0, 1, 6),
	}):Play()

	task.delay(TOAST_HOLD, function()
		if toastToken ~= myToken then
			return
		end

		local fadeInfo = TweenInfo.new(TOAST_FADE)
		TweenService:Create(toastAmount, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(toastDetail, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

		task.delay(TOAST_FADE, function()
			if toastToken == myToken then
				toast.Visible = false
			end
		end)
	end)
end

CoinRewardEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if isInMatch then
		-- Masih di layar match (announcement "X WINS THE MATCH!") -- tahan
		-- dulu, dipopup begitu MatchLockEvent(false) / balik ke lobby.
		pendingReward = payload
	else
		showReward(payload)
	end
end)

-- Perubahan saldo di luar reward match (mis. belanja di shop nanti)
player:GetAttributeChangedSignal(COINS_ATTRIBUTE):Connect(function()
	if not isInMatch and not pendingReward then
		animateBalanceTo(player:GetAttribute(COINS_ATTRIBUTE) or 0)
	end
end)

-- ================================================================
-- VISIBILITY (sembunyi selama match)
-- ================================================================
MatchLockEvent.OnClientEvent:Connect(function(locked)
	isInMatch = locked == true
	screenGui.Enabled = not isInMatch

	if not isInMatch then
		if pendingReward then
			local payload = pendingReward
			pendingReward = nil
			showReward(payload)
		else
			animateBalanceTo(player:GetAttribute(COINS_ATTRIBUTE) or 0)
		end
	end
end)

print("[CoinHudClient] Berhasil diinisialisasi")
