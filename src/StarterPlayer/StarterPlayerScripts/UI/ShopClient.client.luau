-- @ScriptType: LocalScript
--[[
    Nama File  : ShopClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Menghubungkan card UI ShopPage yang sudah ada (ItemCard1..N & StarterBundle)
                 dengan backend ShopService via ShopActionEvent & SyncInventoryEvent,
                 tanpa mengubah/menghapus tampilan placeholder asli di Studio.
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
local cardBindings = {}

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

local function promptRobuxItem(item)
	if item.gamePassId and item.gamePassId > 0 then
		MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)
	elseif item.robuxProductId and item.robuxProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, item.robuxProductId)
	else
		showToast("Produk Robux untuk " .. item.name .. " belum diatur.", false)
	end
end

local function handleCardClick(item)
	if ownedSet[item.id] then
		showToast(item.name .. " sudah kamu miliki.", true)
		return
	end

	if type(item.coinPrice) == "number" and item.coinPrice > 0 then
		ShopActionEvent:FireServer("buy_coin", item.id)
	else
		promptRobuxItem(item)
	end
end

local function ensureOwnedBadge(card: GuiObject): TextLabel
	local existing = card:FindFirstChild("OwnedBadge")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local badge = Instance.new("TextLabel")
	badge.Name = "OwnedBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0.04)
	badge.Size = UDim2.fromScale(0.55, 0.14)
	badge.BackgroundColor3 = Color3.fromRGB(24, 65, 24)
	badge.BackgroundTransparency = 0.15
	badge.Font = Enum.Font.FredokaOne
	badge.Text = "OWNED"
	badge.TextColor3 = Color3.fromRGB(205, 255, 195)
	badge.TextScaled = true
	badge.ZIndex = card.ZIndex + 2
	badge.Visible = false
	badge.Parent = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = badge

	return badge
end

local function bindExistingCards()
	for index, item in ipairs(ShopConfig.PILLOWS) do
		local targetName = item.cardName or ("ItemCard" .. tostring(index))
		local card = itemGridFrame:FindFirstChild(targetName)
		if card and card:IsA("GuiObject") then
			local titleLabel = card:FindFirstChild("TitleLabel", true)
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = item.name
			end

			local iconImage = card:FindFirstChild("IconImage", true)
			if iconImage and iconImage:IsA("ImageLabel") and item.icon and item.icon ~= "rbxassetid://0" then
				iconImage.Image = item.icon
			end

			local coinBtn = card:FindFirstChild("CoinButton", true)
			local robuxBtn = card:FindFirstChild("RobuxButton", true)

			if coinBtn and coinBtn:IsA("GuiButton") then
				coinBtn.MouseButton1Click:Connect(function()
					ShopActionEvent:FireServer("buy_coin", item.id)
				end)
			end
			if robuxBtn and robuxBtn:IsA("GuiButton") then
				robuxBtn.MouseButton1Click:Connect(function()
					promptRobuxItem(item)
				end)
			end

			if card:IsA("GuiButton") then
				card.MouseButton1Click:Connect(function()
					handleCardClick(item)
				end)
			end

			cardBindings[item.id] = {
				card = card,
				item = item,
				badge = ensureOwnedBadge(card),
			}
		end
	end
end

local function refreshCardStates()
	for itemId, binding in pairs(cardBindings) do
		local isOwned = ownedSet[itemId] == true
		binding.badge.Visible = isOwned
		if binding.card:IsA("ImageButton") or binding.card:IsA("ImageLabel") then
			binding.card.ImageColor3 = if isOwned then Color3.fromRGB(185, 215, 185) else Color3.fromRGB(255, 255, 255)
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

bindExistingCards()
refreshCardStates()
ShopActionEvent:FireServer("sync", "")

print("[ShopClient] Berhasil diinisialisasi (mempertahankan card UI asli).")
