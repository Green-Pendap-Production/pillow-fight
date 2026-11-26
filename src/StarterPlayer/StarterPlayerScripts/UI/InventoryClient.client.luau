-- @ScriptType: LocalScript
--[[
    Nama File  : InventoryClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Menampilkan bantal yang dimiliki pemain di InventoryPage dengan
                 meng-clone desain ItemCard1 asli yang ada di Studio, dan menangani
                 Equip via ShopActionEvent.
]]

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
local inventoryPage = pages:WaitForChild("InventoryPage")
local itemScroller = inventoryPage:WaitForChild("ItemScroller")
local itemGridFrame = itemScroller:WaitForChild("ItemGridFrame")

-- Sembunyikan placeholder StarterBundle di InventoryPage
local placeholderBundle = itemScroller:FindFirstChild("StarterBundle")
if placeholderBundle and placeholderBundle:IsA("GuiObject") then
	placeholderBundle.Visible = false
end

-- Simpan ItemCard1 asli sebagai template desain artist
local baseCardTemplate
local existingCard = itemGridFrame:FindFirstChild("ItemCard1")
if existingCard and existingCard:IsA("GuiObject") then
	baseCardTemplate = existingCard:Clone()
end

local ownedSet = { [ShopConfig.DEFAULT_PILLOW_ID] = true }
local equippedId = ShopConfig.DEFAULT_PILLOW_ID

local function clearGridCards()
	for _, child in ipairs(itemGridFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function attachStatusBadge(card: GuiObject, isEquipped: boolean, itemName: string)
	local label = Instance.new("TextLabel")
	label.Name = "EquipBadge"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.96)
	label.Size = UDim2.fromScale(0.84, 0.16)
	label.BackgroundColor3 = if isEquipped then Color3.fromRGB(30, 95, 30) else Color3.fromRGB(235, 180, 40)
	label.Font = Enum.Font.FredokaOne
	label.Text = if isEquipped then "EQUIPPED" else ("EQUIP " .. itemName)
	label.TextColor3 = if isEquipped then Color3.fromRGB(210, 255, 200) else Color3.fromRGB(35, 25, 10)
	label.TextScaled = true
	label.ZIndex = card.ZIndex + 2
	label.Parent = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.28, 0)
	corner.Parent = label
end

local function rebuildInventory()
	clearGridCards()
	if not baseCardTemplate then
		return
	end

	local order = 0
	for _, item in ipairs(ShopConfig.PILLOWS) do
		if ownedSet[item.id] then
			order += 1
			local card = baseCardTemplate:Clone()
			card.Name = "Inv_" .. item.id
			card.LayoutOrder = order
			card.Visible = true

			local titleLabel = card:FindFirstChild("TitleLabel", true)
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = item.name
			end

			local iconImage = card:FindFirstChild("IconImage", true)
			if iconImage and iconImage:IsA("ImageLabel") and item.icon and item.icon ~= "rbxassetid://0" then
				iconImage.Image = item.icon
			end

			local isEquipped = (equippedId == item.id)
			attachStatusBadge(card, isEquipped, item.name)

			local clickTarget = if card:IsA("GuiButton") then card else card:FindFirstChildOfClass("GuiButton")
			if clickTarget then
				clickTarget.MouseButton1Click:Connect(function()
					if equippedId ~= item.id then
						ShopActionEvent:FireServer("equip", item.id)
					end
				end)
			end

			card.Parent = itemGridFrame
		end
	end
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
	end

	rebuildInventory()
end)

rebuildInventory()
print("[InventoryClient] Berhasil diinisialisasi (menggunakan template card UI asli).")
