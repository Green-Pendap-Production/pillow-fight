-- @ScriptType: LocalScript
--[[
    Nama File  : ShopClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Mengisi ShopPage dari template modular Studio (TemplateCard & StarterBundle)
                 berdasarkan ShopConfig, menambahkan animasi hover/press halus, serta
                 menghubungkan pembelian Coin/Robux ke ShopService.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local configsFolder = ReplicatedStorage:WaitForChild("Configs")
local ShopConfig = require(configsFolder:WaitForChild("ShopConfig"))
local ShopUIHelper = require(script.Parent:WaitForChild("ShopUIHelper"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ShopActionEvent = remotesFolder:WaitForChild("ShopActionEvent")
local SyncInventoryEvent = remotesFolder:WaitForChild("SyncInventoryEvent")

local playerGui = player:WaitForChild("PlayerGui")

local COLOR_AFFORDABLE = Color3.fromRGB(72, 196, 56)
local COLOR_UNAVAILABLE = Color3.fromRGB(115, 130, 105)
local COLOR_OWNED_TINT = Color3.fromRGB(205, 232, 205)

local ownedSet = { [ShopConfig.DEFAULT_PILLOW_ID] = true }
local cardBindings = {}
local currentRootGui: ScreenGui? = nil
local currentToastLabel: TextLabel? = nil
local currentToastScale: UIScale? = nil
local toastVersion = 0

local function showToast(message: string, isOk: boolean?)
	if type(message) ~= "string" or message == "" then
		return
	end
	local toastLabel = currentToastLabel
	local toastScale = currentToastScale
	if not toastLabel or not toastScale or not toastLabel.Parent then
		return
	end
	toastVersion += 1
	local currentVersion = toastVersion
	toastLabel.Text = message
	toastLabel.TextColor3 = if isOk == false then Color3.fromRGB(255, 145, 145) else Color3.fromRGB(175, 255, 165)
	toastScale.Scale = 0.88
	toastLabel.Visible = true
	TweenService:Create(toastScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	task.delay(2.5, function()
		if toastVersion == currentVersion and currentToastLabel == toastLabel then
			toastLabel.Visible = false
		end
	end)
end

local function hasRobuxOffer(item): boolean
	return (type(item.gamePassId) == "number" and item.gamePassId > 0)
		or (type(item.robuxProductId) == "number" and item.robuxProductId > 0)
		or (type(item.robuxFallbackPrice) == "number" and item.robuxFallbackPrice > 0)
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

local function handleCoinPurchase(item)
	if ownedSet[item.id] then
		showToast(item.name .. " sudah kamu miliki.", true)
		return
	end
	local currentCoins = player:GetAttribute("Coins") or 0
	if type(item.coinPrice) == "number" and currentCoins < item.coinPrice then
		local needed = item.coinPrice - currentCoins
		showToast("Coins kurang " .. tostring(needed) .. " lagi!", false)
		return
	end
	ShopActionEvent:FireServer("buy_coin", item.id)
end

local function clearGeneratedCards(itemGridFrame: Frame, templateCard: GuiObject)
	for _, child in ipairs(itemGridFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= templateCard then
			child:Destroy()
		end
	end
	table.clear(cardBindings)
end

local function ensureFallbackPlaceholder(card: GuiObject): TextLabel
	local existing = card:FindFirstChild("NoIconLabel")
	if existing and existing:IsA("TextLabel") then
		return existing
	end
	local label = Instance.new("TextLabel")
	label.Name = "NoIconLabel"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.47)
	label.Size = UDim2.fromScale(0.55, 0.25)
	label.Font = Enum.Font.FredokaOne
	label.Text = "?"
	label.TextColor3 = Color3.fromRGB(224, 255, 214)
	label.TextScaled = true
	label.Visible = false
	label.Parent = card
	return label
end

local function buildCards(itemGridFrame: Frame, templateCard: GuiObject)
	clearGeneratedCards(itemGridFrame, templateCard)

	for index, item in ipairs(ShopConfig.PILLOWS) do
		local card = templateCard:Clone()
		card.Name = "Card_" .. item.id
		card.LayoutOrder = index
		card.Visible = true
		card.Parent = itemGridFrame

		ShopUIHelper.bindBounce(card, 1.03, 0.97)

		local titleLabel = card:FindFirstChild("TitleLabel")
		if titleLabel and titleLabel:IsA("TextLabel") then
			titleLabel.Text = item.name
		end

		local iconImage = card:FindFirstChild("IconImage")
		local fallbackLabel = ensureFallbackPlaceholder(card)
		ShopUIHelper.applyPillowIcon(
			if iconImage and iconImage:IsA("ImageLabel") then iconImage else nil,
			item.icon,
			fallbackLabel
		)

		local actionsRow = card:FindFirstChild("ActionsRow")
		local coinBtn = actionsRow and actionsRow:FindFirstChild("CoinButton")
		local robuxBtn = actionsRow and actionsRow:FindFirstChild("RobuxButton")
		local ownedPill = actionsRow and actionsRow:FindFirstChild("OwnedPill")

		if coinBtn and coinBtn:IsA("GuiButton") then
			local priceLabel = coinBtn:FindFirstChild("PriceLabel")
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = tostring(item.coinPrice or 0)
			end
			ShopUIHelper.bindBounce(coinBtn, 1.08, 0.92)
			coinBtn.MouseButton1Click:Connect(function()
				handleCoinPurchase(item)
			end)
		end

		if robuxBtn and robuxBtn:IsA("GuiButton") then
			local priceLabel = robuxBtn:FindFirstChild("PriceLabel")
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = tostring(item.robuxFallbackPrice or "?")
			end
			ShopUIHelper.bindBounce(robuxBtn, 1.08, 0.92)
			robuxBtn.MouseButton1Click:Connect(function()
				promptRobuxItem(item)
			end)
		end

		if card:IsA("GuiButton") then
			card.MouseButton1Click:Connect(function()
				if ownedSet[item.id] then
					showToast(item.name .. " sudah kamu miliki.", true)
				elseif type(item.coinPrice) == "number" and item.coinPrice > 0 then
					handleCoinPurchase(item)
				else
					promptRobuxItem(item)
				end
			end)
		end

		cardBindings[item.id] = {
			card = card,
			item = item,
			coinBtn = if coinBtn and coinBtn:IsA("GuiButton") then coinBtn else nil,
			robuxBtn = if robuxBtn and robuxBtn:IsA("GuiButton") then robuxBtn else nil,
			ownedPill = if ownedPill and ownedPill:IsA("GuiObject") then ownedPill else nil,
		}
	end
end

local function refreshCardStates()
	local currentCoins = player:GetAttribute("Coins") or 0

	for itemId, binding in pairs(cardBindings) do
		local isOwned = ownedSet[itemId] == true
		local item = binding.item

		if binding.ownedPill then
			binding.ownedPill.Visible = isOwned
		end

		if binding.coinBtn then
			local showCoin = (not isOwned) and type(item.coinPrice) == "number" and item.coinPrice > 0
			binding.coinBtn.Visible = showCoin
			if showCoin then
				local affordable = currentCoins >= item.coinPrice
				binding.coinBtn.BackgroundColor3 = if affordable then COLOR_AFFORDABLE else COLOR_UNAVAILABLE
			end
		end

		if binding.robuxBtn then
			binding.robuxBtn.Visible = (not isOwned) and not item.isDefault and hasRobuxOffer(item)
		end

		if binding.card:IsA("ImageButton") then
			binding.card.ImageColor3 = if isOwned then COLOR_OWNED_TINT else Color3.fromRGB(255, 255, 255)
		end
	end
end

local function bindStarterBundle(itemScroller: ScrollingFrame)
	local starterBundle = itemScroller:FindFirstChild("StarterBundle")
	if not (starterBundle and starterBundle:IsA("GuiObject")) then
		return
	end
	local bundleData = ShopConfig.STARTER_BUNDLE
	local titleLabel = starterBundle:FindFirstChild("TitleLabel")
	local descLabel = starterBundle:FindFirstChild("DescLabel")
	local buyWrap = starterBundle:FindFirstChild("BuyButtonWrap")
	local buyBtn = buyWrap and buyWrap:FindFirstChild("BuyButton")

	if bundleData then
		if titleLabel and titleLabel:IsA("TextLabel") then
			titleLabel.Text = "TRY THE " .. bundleData.name
		end
		if descLabel and descLabel:IsA("TextLabel") then
			descLabel.Text = bundleData.description
		end
		if buyBtn and buyBtn:IsA("GuiButton") then
			local priceLabel = buyBtn:FindFirstChild("PriceLabel")
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = tostring(bundleData.robuxFallbackPrice or 299)
			end
			ShopUIHelper.bindBounce(buyBtn, 1.07, 0.93)
			buyBtn.MouseButton1Click:Connect(function()
				if bundleData.robuxProductId and bundleData.robuxProductId > 0 then
					MarketplaceService:PromptProductPurchase(player, bundleData.robuxProductId)
				else
					showToast("Starter Bundle belum dihubungkan ke Developer Product ID.", false)
				end
			end)
		end
	end

	ShopUIHelper.bindBounce(starterBundle, 1.02, 0.98)
	if starterBundle:IsA("GuiButton") then
		starterBundle.MouseButton1Click:Connect(function()
			if bundleData and bundleData.robuxProductId and bundleData.robuxProductId > 0 then
				MarketplaceService:PromptProductPurchase(player, bundleData.robuxProductId)
			else
				showToast("Starter Bundle belum dihubungkan ke Developer Product ID.", false)
			end
		end)
	end
end

local function createToast(shopPage: Frame)
	local existing = shopPage:FindFirstChild("ShopToast")
	if existing then
		existing:Destroy()
	end

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "ShopToast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.fromScale(0.5, 0.97)
	toastLabel.Size = UDim2.fromScale(0.62, 0.085)
	toastLabel.BackgroundColor3 = Color3.fromRGB(22, 42, 20)
	toastLabel.BackgroundTransparency = 0.08
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.Font = Enum.Font.FredokaOne
	toastLabel.TextScaled = true
	toastLabel.Visible = false
	toastLabel.ZIndex = 20
	toastLabel.Parent = shopPage

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0.35, 0)
	toastCorner.Parent = toastLabel

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = Color3.fromRGB(16, 48, 14)
	toastStroke.Thickness = 2
	toastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toastStroke.Parent = toastLabel

	local toastScale = Instance.new("UIScale")
	toastScale.Parent = toastLabel

	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingLeft = UDim.new(0.05, 0)
	toastPad.PaddingRight = UDim.new(0.05, 0)
	toastPad.PaddingTop = UDim.new(0.1, 0)
	toastPad.PaddingBottom = UDim.new(0.1, 0)
	toastPad.Parent = toastLabel

	currentToastLabel = toastLabel
	currentToastScale = toastScale
end

local function bindGui(rootGui: ScreenGui)
	if currentRootGui == rootGui then
		return
	end
	currentRootGui = rootGui
	rootGui.ResetOnSpawn = false

	local mainPanel = rootGui:WaitForChild("MainPanel")
	local pages = mainPanel:WaitForChild("Pages")
	local shopPage = pages:WaitForChild("ShopPage") :: Frame
	local itemScroller = shopPage:WaitForChild("ItemScroller") :: ScrollingFrame
	local itemGridFrame = itemScroller:WaitForChild("ItemGridFrame") :: Frame
	local templateCard = itemGridFrame:WaitForChild("TemplateCard") :: GuiObject
	templateCard.Visible = false

	-- Matikan script placeholder lama jika masih ada di Studio
	local legacyController = shopPage:FindFirstChild("ShopController")
	if legacyController and legacyController:IsA("LocalScript") then
		legacyController.Disabled = true
	end

	createToast(shopPage)
	bindStarterBundle(itemScroller)

	local refreshGrid = ShopUIHelper.bindResponsiveGrid(itemGridFrame, 1.0)
	buildCards(itemGridFrame, templateCard)
	refreshCardStates()
	refreshGrid()
	ShopActionEvent:FireServer("sync", "")
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

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "PlayerGui" and child:IsA("ScreenGui") then
		task.defer(bindGui, child)
	end
end)

local initialRootGui = playerGui:WaitForChild("PlayerGui")
if initialRootGui:IsA("ScreenGui") then
	bindGui(initialRootGui)
end

print("[ShopClient] Berhasil diinisialisasi.")
