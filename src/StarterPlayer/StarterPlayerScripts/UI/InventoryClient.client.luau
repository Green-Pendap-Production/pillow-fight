-- @ScriptType: LocalScript
--[[
    Nama File  : InventoryClient.client.luau
    Layer      : Client (UI)
    Deskripsi  : Menampilkan bantal yang dimiliki pemain di InventoryPage dan
                 menangani tombol Equip bantal via ShopActionEvent.
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

-- Sembunyikan placeholder StarterBundle di InventoryPage jika masih ada di Studio
local placeholderBundle = itemScroller:FindFirstChild("StarterBundle")
if placeholderBundle and placeholderBundle:IsA("GuiObject") then
	placeholderBundle.Visible = false
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

local function createFallbackCard(item)
	local card = Instance.new("Frame")
	card.Name = "Inv_" .. item.id
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

	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipButton"
	equipBtn.Position = UDim2.fromScale(0.08, 0.74)
	equipBtn.Size = UDim2.fromScale(0.84, 0.2)
	equipBtn.Font = Enum.Font.FredokaOne
	equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipBtn.TextScaled = true
	equipBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0.25, 0)
	btnCorner.Parent = equipBtn

	return card
end

local function setEquipButtonState(button: GuiButton, isEquipped: boolean)
	local textLabel = button:FindFirstChild("TextLabel")
	local labelText = if isEquipped then "EQUIPPED" else "EQUIP"

	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = labelText
	elseif button:IsA("TextButton") then
		button.Text = labelText
	end

	button.BackgroundColor3 = if isEquipped then Color3.fromRGB(30, 85, 30) else Color3.fromRGB(235, 180, 40)
	if button:IsA("TextButton") then
		button.TextColor3 = if isEquipped then Color3.fromRGB(200, 255, 190) else Color3.fromRGB(35, 25, 10)
	end
end

local function rebuildInventory()
	clearGridCards()

	local templatesFolder = ReplicatedStorage:FindFirstChild("Templates")
	local cardTemplate = templatesFolder and templatesFolder:FindFirstChild("InventoryCardTemplate")

	local order = 0
	for _, item in ipairs(ShopConfig.PILLOWS) do
		if ownedSet[item.id] then
			order += 1
			local card = if cardTemplate then cardTemplate:Clone() else createFallbackCard(item)
			card.Name = "Inv_" .. item.id
			card.LayoutOrder = order
			card.Visible = true

			local titleLabel = card:FindFirstChild("TitleLabel", true)
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = item.name
			end

			local iconImage = card:FindFirstChild("IconImage", true)
			if iconImage and iconImage:IsA("ImageLabel") then
				iconImage.Image = item.icon or "rbxassetid://0"
			end

			local equipBtn = card:FindFirstChild("EquipButton", true)
			if equipBtn and equipBtn:IsA("GuiButton") then
				local isEquipped = (equippedId == item.id)
				setEquipButtonState(equipBtn, isEquipped)
				equipBtn.MouseButton1Click:Connect(function()
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
print("[InventoryClient] Berhasil diinisialisasi.")
