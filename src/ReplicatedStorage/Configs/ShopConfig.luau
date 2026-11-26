--[[
    Nama File  : ShopConfig
    Layer      : Config (Shared)
    Deskripsi  : Konfigurasi katalog bantal & bundle untuk Shop & Inventory.
                 Cukup tambahkan entry baru di PILLOWS (id, name, icon, harga,
                 dan templateName di ServerStorage/Templates/Pillows).
]]

local ShopConfig = {}

ShopConfig.DEFAULT_PILLOW_ID = "basic_pillow"

-- Folder template Tool bantal di ServerStorage (prioritas: ServerStorage/Templates/Pillows,
-- lalu ServerStorage/Pillows, lalu fallback ke StarterPack/Pillow).
ShopConfig.TEMPLATE_FOLDER_PATH = { "Templates", "Pillows" }

-- Katalog bantal yang tampil di Shop & Inventory (urutan sesuai array ini).
ShopConfig.PILLOWS = {
	{
		id = "basic_pillow",
		cardName = "ItemCard1",
		name = "BASIC PILLOW",
		description = "Bantal standar andalan setiap petarung.",
		icon = "rbxassetid://0", -- Ganti dengan ID gambar icon kamu
		templateName = "BasicPillow",
		coinPrice = 0,
		robuxProductId = nil,
		gamePassId = nil,
		isDefault = true,
	},
	{
		id = "cloud_pillow",
		cardName = "ItemCard2",
		name = "CLOUD PILLOW",
		description = "Ringan dan empuk seperti awan.",
		icon = "rbxassetid://0",
		templateName = "CloudPillow",
		coinPrice = 150,
		robuxProductId = nil, -- Isi dengan Developer Product ID jika dijual pakai Robux
		robuxFallbackPrice = 49,
		gamePassId = nil,
		isDefault = false,
	},
	{
		id = "royal_pillow",
		cardName = "ItemCard3",
		name = "ROYAL PILLOW",
		description = "Bantal mewah berlapis emas kerajaan.",
		icon = "rbxassetid://0",
		templateName = "RoyalPillow",
		coinPrice = 400,
		robuxProductId = nil,
		robuxFallbackPrice = 99,
		gamePassId = nil,
		isDefault = false,
	},
	{
		id = "shadow_pillow",
		cardName = "ItemCard4",
		name = "SHADOW PILLOW",
		description = "Gelap, misterius, tapi tetap empuk.",
		icon = "rbxassetid://0",
		templateName = "ShadowPillow",
		coinPrice = 750,
		robuxProductId = nil,
		robuxFallbackPrice = 149,
		gamePassId = nil,
		isDefault = false,
	},
}

-- Konfigurasi banner Starter Bundle di bagian atas ShopPage.
ShopConfig.STARTER_BUNDLE = {
	id = "starter_bundle",
	name = "STARTER BUNDLE",
	description = "Great offer just for you!",
	robuxProductId = nil, -- Isi dengan Developer Product ID Starter Bundle
	robuxFallbackPrice = 299,
	coinReward = 500,
	pillowIds = { "royal_pillow" },
}

local _pillowById = {}
local _pillowByProductId = {}

for _, item in ipairs(ShopConfig.PILLOWS) do
	_pillowById[item.id] = item
	if item.robuxProductId and item.robuxProductId > 0 then
		_pillowByProductId[item.robuxProductId] = item
	end
end

function ShopConfig.getPillowById(itemId: string)
	if type(itemId) ~= "string" then
		return nil
	end
	return _pillowById[itemId]
end

function ShopConfig.getPillowByProductId(productId: number)
	if type(productId) ~= "number" then
		return nil
	end
	return _pillowByProductId[productId]
end

return ShopConfig
