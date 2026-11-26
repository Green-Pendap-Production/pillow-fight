-- @ScriptType: LocalScript
--[[
    Nama File  : ShopClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Mengelola tampilan dinamis ShopPage dari ShopConfig, pembelian via
                 Coins (ShopActionEvent) maupun Robux (MarketplaceService), serta
                 sinkronisasi status kepemilikan dari SyncInventoryEvent.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local configsFolder = ReplicatedStorage:WaitForChild("Configs")
local ShopConfig = require(configsFolder:WaitForChild("ShopConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ShopActionEvent = remotesFolder:WaitForChild("ShopActionEvent")
local SyncInventoryEvent = remotesFolder:WaitForChild("SyncInventoryEvent")

local playerGui = player:WaitForChild("PlayerGui")
local rootGui = playerGui:WaitForChild("PlayerGui")
local mainPanel = rootGui:WaitForChild("MainPanel")
local pages = mainPanel:WaitForChild("Pages")
local shopPage = pages:WaitForChild("ShopPage")
local itemScroller = shopPage:WaitForChild("ItemScroller")
local itemGridFrame = itemScroller:WaitForChild("ItemGridFrame")

-- Matikan script placeholder lama jika masih ada di Studio
local legacyController = shopPage:FindFirstChild("ShopController")
if legacyController and legacyController:IsA("LocalScript") then
	legacyController.Disabled = true
end

local ownedSet = { [ShopConfig.DEFAULT_PILLOW_ID] = true }
local cardRefs = {} -- [itemId] = { coinBtn, robuxBtn, ownedLabel, coinPrice }

local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "ShopToast"
toastLabel.AnchorPoint = Vector2.new(0.5, 1)
toastLabel.Position = UDim2.fromScale(0.5, 0.97)
toastLabel.Size = UDim2.fromScale(0.65, 0.08)
toastLabel.BackgroundColor3 = Color3.fromRGB(24, 34, 24)
toastLabel.BackgroundTransparency = 0.1
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.Font = Enum.Font.FredokaOne
toastLabel.TextScaled = true
toastLabel.Visible = false
toastLabel.ZIndex = 20
toastLabel.Parent = shopPage

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0.25, 0)
toastCorner.Parent = toastLabel

local toastVersion = 0
local function showToast(message: string, isOk: boolean?)
	if type(message) ~= "string" or message == "" then
		return
	end
	toastVersion += 1
	local currentVersion = toastVersion
	toastLabel.Text = message
	toastLabel.TextColor3 = if isOk == false then Color3.fromRGB(255, 130, 130) else Color3.fromRGB(165, 255, 150)
	toastLabel.Visible = true
	task.delay(2.5, function()
		if toastVersion == currentVersion then
			toastLabel.Visible = false
		end
	end)
end

local function clearPlaceholderCards()
	for _, child in ipairs(itemGridFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function createFallbackCard(item)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. item.id
	card.BackgroundColor3 = Color3.fromRGB(46, 138, 42)
	card.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 55, 18)
	stroke.Thickness = 2
	stroke.Parent = card

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.85
	aspect.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.04)
	title.Size = UDim2.fromScale(0.88, 0.16)
	title.Font = Enum.Font.FredokaOne
	title.Text = item.name
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Name = "IconImage"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0.15, 0.22)
	icon.Size = UDim2.fromScale(0.7, 0.48)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = item.icon or "rbxassetid://0"
	icon.Parent = card

	local coinBtn = Instance.new("TextButton")
	coinBtn.Name = "CoinButton"
	coinBtn.Position = UDim2.fromScale(0.06, 0.74)
	coinBtn.Size = UDim2.fromScale(0.42, 0.2)
	coinBtn.BackgroundColor3 = Color3.fromRGB(235, 180, 40)
	coinBtn.Font = Enum.Font.FredokaOne
	coinBtn.TextColor3 = Color3.fromRGB(35, 25, 10)
	coinBtn.TextScaled = true
	coinBtn.Text = item.coinPrice and ("C " .. tostring(item.coinPrice)) or "-"
	coinBtn.Parent = card

	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(0.25, 0)
	coinCorner.Parent = coinBtn

	local robuxBtn = Instance.new("TextButton")
	robuxBtn.Name = "RobuxButton"
	robuxBtn.Position = UDim2.fromScale(0.52, 0.74)
	robuxBtn.Size = UDim2.fromScale(0.42, 0.2)
	robuxBtn.BackgroundColor3 = Color3.fromRGB(70, 195, 70)
	robuxBtn.Font = Enum.Font.FredokaOne
	robuxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	robuxBtn.TextScaled = true
	robuxBtn.Text = item.robuxFallbackPrice and ("R$ " .. tostring(item.robuxFallbackPrice)) or "R$"
	robuxBtn.Parent = card

	local robuxCorner = Instance.new("UICorner")
	robuxCorner.CornerRadius = UDim.new(0.25, 0)
	robuxCorner.Parent = robuxBtn

	local ownedLabel = Instance.new("TextLabel")
	ownedLabel.Name = "OwnedLabel"
	ownedLabel.Position = UDim2.fromScale(0.08, 0.74)
	ownedLabel.Size = UDim2.fromScale(0.84, 0.2)
	ownedLabel.BackgroundColor3 = Color3.fromRGB(30, 85, 30)
	ownedLabel.Font = Enum.Font.FredokaOne
	ownedLabel.Text = "OWNED"
	ownedLabel.TextColor3 = Color3.fromRGB(210, 255, 200)
	ownedLabel.TextScaled = true
	ownedLabel.Visible = false
	ownedLabel.Parent = card

	local ownedCorner = Instance.new("UICorner")
	ownedCorner.CornerRadius = UDim.new(0.25, 0)
	ownedCorner.Parent = ownedLabel

	return card
end

local function setButtonLabel(button: GuiObject?, text: string)
	if not button then
		return
	end
	local priceLabel = button:FindFirstChild("PriceLabel")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = text
	elseif button:IsA("TextButton") then
		button.Text = text
	end
end

local function promptRobuxItem(item)
	if item.gamePassId and item.gamePassId > 0 then
		MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)
	elseif item.robuxProductId and item.robuxProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, item.robuxProductId)
	else
		showToast("Produk Robux untuk " .. item.name .. " belum diatur.", false)
	end
end

local function buildCards()
	clearPlaceholderCards()

	local templatesFolder = ReplicatedStorage:FindFirstChild("Templates")
	local cardTemplate = templatesFolder and templatesFolder:FindFirstChild("ShopCardTemplate")

	for index, item in ipairs(ShopConfig.PILLOWS) do
		local card = if cardTemplate then cardTemplate:Clone() else createFallbackCard(item)
		card.Name = "Card_" .. item.id
		card.LayoutOrder = index
		card.Visible = true

		local titleLabel = card:FindFirstChild("TitleLabel", true)
		if titleLabel and titleLabel:IsA("TextLabel") then
			titleLabel.Text = item.name
		end

		local iconImage = card:FindFirstChild("IconImage", true)
		if iconImage and iconImage:IsA("ImageLabel") then
			iconImage.Image = item.icon or "rbxassetid://0"
		end

		local coinBtn = card:FindFirstChild("CoinButton", true)
		local robuxBtn = card:FindFirstChild("RobuxButton", true)
		local ownedLabel = card:FindFirstChild("OwnedLabel", true)

		if coinBtn and coinBtn:IsA("GuiButton") then
			if type(item.coinPrice) == "number" and item.coinPrice > 0 then
				setButtonLabel(coinBtn, "C " .. tostring(item.coinPrice))
				coinBtn.MouseButton1Click:Connect(function()
					ShopActionEvent:FireServer("buy_coin", item.id)
				end)
			else
				coinBtn.Visible = false
			end
		end

		if robuxBtn and robuxBtn:IsA("GuiButton") then
			local hasRobux = (item.robuxProductId and item.robuxProductId > 0)
				or (item.gamePassId and item.gamePassId > 0)
				or (item.robuxFallbackPrice and item.robuxFallbackPrice > 0)

			if hasRobux and not item.isDefault then
				setButtonLabel(robuxBtn, "R$ " .. tostring(item.robuxFallbackPrice or "?"))
				robuxBtn.MouseButton1Click:Connect(function()
					promptRobuxItem(item)
				end)
			else
				robuxBtn.Visible = false
			end
		end

		cardRefs[item.id] = {
			coinBtn = coinBtn,
			robuxBtn = robuxBtn,
			ownedLabel = ownedLabel,
			item = item,
		}

		card.Parent = itemGridFrame
	end
end

local function refreshCardStates()
	local currentCoins = player:GetAttribute("Coins") or 0

	for itemId, ref in pairs(cardRefs) do
		local isOwned = ownedSet[itemId] == true
		local item = ref.item

		if ref.ownedLabel then
			ref.ownedLabel.Visible = isOwned
		end

		if ref.coinBtn and ref.coinBtn:IsA("GuiButton") then
			local canBuyCoin = not isOwned and type(item.coinPrice) == "number" and item.coinPrice > 0
			ref.coinBtn.Visible = canBuyCoin
			if canBuyCoin then
				local affordable = currentCoins >= item.coinPrice
				ref.coinBtn.BackgroundColor3 = if affordable
					then Color3.fromRGB(235, 180, 40)
					else Color3.fromRGB(140, 125, 85)
			end
		end

		if ref.robuxBtn and ref.robuxBtn:IsA("GuiButton") then
			local hasRobux = (item.robuxProductId and item.robuxProductId > 0)
				or (item.gamePassId and item.gamePassId > 0)
				or (item.robuxFallbackPrice and item.robuxFallbackPrice > 0)
			ref.robuxBtn.Visible = (not isOwned) and hasRobux and (not item.isDefault)
		end
	end
end

local starterBundleBtn = itemScroller:FindFirstChild("StarterBundle")
if starterBundleBtn and starterBundleBtn:IsA("GuiButton") then
	starterBundleBtn.MouseButton1Click:Connect(function()
		local bundle = ShopConfig.STARTER_BUNDLE
		if bundle and bundle.robuxProductId and bundle.robuxProductId > 0 then
			MarketplaceService:PromptProductPurchase(player, bundle.robuxProductId)
		else
			showToast("Starter Bundle belum dihubungkan ke Developer Product ID.", false)
		end
	end)
end

SyncInventoryEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if type(payload.ownedPillows) == "table" then
		local nextSet = {}
		for _, id in ipairs(payload.ownedPillows) do
			nextSet[id] = true
		end
		ownedSet = nextSet
	end

	refreshCardStates()
	if payload.notice then
		showToast(payload.notice, payload.ok)
	end
end)

player:GetAttributeChangedSignal("Coins"):Connect(refreshCardStates)

buildCards()
refreshCardStates()
ShopActionEvent:FireServer("sync", "")

print("[ShopClient] Berhasil diinisialisasi.")
