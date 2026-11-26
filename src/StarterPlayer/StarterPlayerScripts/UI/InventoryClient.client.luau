-- @ScriptType: LocalScript
--[[
    Nama File  : InventoryClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Menampilkan bantal yang dimiliki pemain di InventoryPage menggunakan
                 DetailBanner & TemplateCard modular Studio, serta menangani preview dan
                 Equip/Unequip via ShopActionEvent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local configsFolder = ReplicatedStorage:WaitForChild("Configs")
local ShopConfig = require(configsFolder:WaitForChild("ShopConfig"))
local ShopUIHelper = require(script.Parent:WaitForChild("ShopUIHelper"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ShopActionEvent = remotesFolder:WaitForChild("ShopActionEvent")
local SyncInventoryEvent = remotesFolder:WaitForChild("SyncInventoryEvent")

local playerGui = player:WaitForChild("PlayerGui")

local COLOR_EQUIP = Color3.fromRGB(72, 196, 56)
local COLOR_EQUIPPED = Color3.fromRGB(28, 92, 24)
local COLOR_UNEQUIP = Color3.fromRGB(220, 68, 68)
local COLOR_STROKE_DEFAULT = Color3.fromRGB(16, 48, 14)
local COLOR_STROKE_SELECTED = Color3.fromRGB(255, 224, 96)

local ownedSet = { [ShopConfig.DEFAULT_PILLOW_ID] = true }
local equippedId = ShopConfig.DEFAULT_PILLOW_ID
local selectedId = ShopConfig.DEFAULT_PILLOW_ID
local cardRefs = {}

local currentRootGui: ScreenGui? = nil
local currentItemGridFrame: Frame? = nil
local currentTemplateCard: GuiObject? = nil
local bannerIcon: Instance? = nil
local bannerTitle: Instance? = nil
local bannerDesc: Instance? = nil
local bannerActionBtn: Instance? = nil
local bannerRarity: Instance? = nil

local function updateDetailBanner()
	local item = ShopConfig.getPillowById(selectedId) or ShopConfig.getPillowById(equippedId)
	if not item then
		return
	end

	if bannerTitle and bannerTitle:IsA("TextLabel") then
		bannerTitle.Text = item.name
	end
	if bannerDesc and bannerDesc:IsA("TextLabel") then
		bannerDesc.Text = item.description or ""
	end
	if bannerRarity and bannerRarity:IsA("TextLabel") then
		bannerRarity.Text = item.rarity or "Basic"
	end
	ShopUIHelper.applyPillowIcon(
		if bannerIcon and bannerIcon:IsA("ImageLabel") then bannerIcon else nil,
		item.icon,
		nil
	)

	if bannerActionBtn and bannerActionBtn:IsA("TextButton") then
		local isEquipped = (item.id == equippedId)
		if isEquipped and item.id ~= ShopConfig.DEFAULT_PILLOW_ID then
			bannerActionBtn.Text = "Unequip"
			bannerActionBtn.BackgroundColor3 = COLOR_UNEQUIP
			bannerActionBtn.Active = true
		elseif isEquipped then
			bannerActionBtn.Text = "Equipped"
			bannerActionBtn.BackgroundColor3 = COLOR_EQUIPPED
			bannerActionBtn.Active = false
		else
			bannerActionBtn.Text = "Equip"
			bannerActionBtn.BackgroundColor3 = COLOR_EQUIP
			bannerActionBtn.Active = true
		end
	end
end

local function updateSelectionHighlights()
	for id, ref in pairs(cardRefs) do
		local isSelected = (id == selectedId)
		if ref.stroke then
			ref.stroke.Color = if isSelected then COLOR_STROKE_SELECTED else COLOR_STROKE_DEFAULT
			ref.stroke.Thickness = if isSelected then 3.5 else 3
			ref.stroke.Transparency = if isSelected then 0 else 1
		end
	end
end

local function clearGridCards()
	local gridFrame = currentItemGridFrame
	local template = currentTemplateCard
	if not gridFrame then
		table.clear(cardRefs)
		return
	end
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template then
			child:Destroy()
		end
	end
	table.clear(cardRefs)
end

local function triggerEquip(itemId: string)
	if itemId == equippedId then
		if itemId ~= ShopConfig.DEFAULT_PILLOW_ID then
			ShopActionEvent:FireServer("equip", ShopConfig.DEFAULT_PILLOW_ID)
		end
		return
	end
	ShopActionEvent:FireServer("equip", itemId)
end

local function rebuildInventory()
	local gridFrame = currentItemGridFrame
	local template = currentTemplateCard
	if not (gridFrame and template and gridFrame.Parent) then
		return
	end

	clearGridCards()

	if not ownedSet[selectedId] then
		selectedId = equippedId
	end

	local order = 0
	for _, item in ipairs(ShopConfig.PILLOWS) do
		if ownedSet[item.id] then
			order += 1
			local card = template:Clone()
			card.Name = "Inv_" .. item.id
			card.LayoutOrder = order
			card.Visible = true
			card.Parent = gridFrame

			ShopUIHelper.bindBounce(card, 1.03, 0.97)

			local titleLabel = card:FindFirstChild("TitleLabel")
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = item.name
			end

			local iconImage = card:FindFirstChild("IconImage")
			ShopUIHelper.applyPillowIcon(
				if iconImage and iconImage:IsA("ImageLabel") then iconImage else nil,
				item.icon,
				nil
			)

			local isEquipped = (equippedId == item.id)
			local equipBtn = card:FindFirstChild("EquipButton")
			if equipBtn and equipBtn:IsA("TextButton") then
				equipBtn.Text = if isEquipped then "EQUIPPED" else "EQUIP"
				equipBtn.BackgroundColor3 = if isEquipped then COLOR_EQUIPPED else COLOR_EQUIP
				ShopUIHelper.bindBounce(equipBtn, 1.08, 0.92)
				equipBtn.MouseButton1Click:Connect(function()
					selectedId = item.id
					updateDetailBanner()
					updateSelectionHighlights()
					if equippedId ~= item.id then
						ShopActionEvent:FireServer("equip", item.id)
					end
				end)
			end

			if card:IsA("GuiButton") then
				card.MouseButton1Click:Connect(function()
					selectedId = item.id
					updateDetailBanner()
					updateSelectionHighlights()
				end)
			end

			cardRefs[item.id] = {
				card = card,
				stroke = card:FindFirstChildOfClass("UIStroke"),
			}
		end
	end

	updateDetailBanner()
	updateSelectionHighlights()
end

local function bindGui(rootGui: ScreenGui)
	if currentRootGui == rootGui then
		return
	end
	currentRootGui = rootGui
	rootGui.ResetOnSpawn = false

	local mainPanel = rootGui:WaitForChild("MainPanel")
	local pages = mainPanel:WaitForChild("Pages")
	local inventoryPage = pages:WaitForChild("InventoryPage")
	local itemScroller = inventoryPage:WaitForChild("ItemScroller")
	local detailBanner = itemScroller:WaitForChild("DetailBanner")
	local itemGridFrame = itemScroller:WaitForChild("ItemGridFrame") :: Frame
	local templateCard = itemGridFrame:WaitForChild("TemplateCard") :: GuiObject
	templateCard.Visible = false

	currentItemGridFrame = itemGridFrame
	currentTemplateCard = templateCard

	bannerIcon = detailBanner:FindFirstChild("IconImage")
	bannerTitle = detailBanner:FindFirstChild("TitleLabel")
	bannerDesc = detailBanner:FindFirstChild("DescLabel")
	local bannerBtnRow = detailBanner:FindFirstChild("ButtonRow")
	bannerActionBtn = bannerBtnRow and bannerBtnRow:FindFirstChild("ActionButton")
	bannerRarity = bannerBtnRow and bannerBtnRow:FindFirstChild("RarityBadge")

	if bannerActionBtn and bannerActionBtn:IsA("GuiButton") then
		ShopUIHelper.bindBounce(bannerActionBtn, 1.06, 0.94)
		bannerActionBtn.MouseButton1Click:Connect(function()
			triggerEquip(selectedId)
		end)
	end

	local refreshGrid = ShopUIHelper.bindResponsiveGrid(itemGridFrame, 1.0)
	rebuildInventory()
	refreshGrid()
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

	if type(payload.equippedPillow) == "string" then
		equippedId = payload.equippedPillow
		if not ownedSet[selectedId] then
			selectedId = equippedId
		end
	end

	rebuildInventory()
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "PlayerGui" and child:IsA("ScreenGui") then
		task.defer(bindGui, child)
	end
end)

local initialRootGui = playerGui:WaitForChild("PlayerGui")
if initialRootGui:IsA("ScreenGui") then
	bindGui(initialRootGui)
end

print("[InventoryClient] Berhasil diinisialisasi.")
