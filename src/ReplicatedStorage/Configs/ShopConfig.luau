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
		name = "BASIC PILLOW",
		rarity = "Basic",
		description = "Bantal standar andalan setiap petarung.",
		icon = "rbxassetid://82441755964219",
		templateName = "BasicPillow",
		coinPrice = 0,
		robuxProductId = nil,
		gamePassId = nil,
		isDefault = true,
	},
	{
		id = "ikan_pillow",
		name = "IKAN PILLOW",
		rarity = "Common",
		description = "Bantal ikan biru empuk untuk menjatuhkan lawan.",
		icon = "rbxassetid://102037845231670",
		templateName = "IkanPillow",
		coinPrice = 150,
		robuxProductId = nil,
		robuxFallbackPrice = 49,
		gamePassId = 2099071224,
		isDefault = false,
	},
	{
		id = "paw_pillow",
		name = "PAW PILLOW",
		rarity = "Rare",
		description = "Bantal cakar kucing lucu dengan genggaman cincin.",
		icon = "rbxassetid://110302031231786",
		templateName = "PawPillow",
		coinPrice = 300,
		robuxProductId = nil,
		robuxFallbackPrice = 79,
		gamePassId = 2102316295,
		isDefault = false,
	},
	{
		id = "pisang_pillow",
		name = "PISANG PILLOW",
		rarity = "Rare",
		description = "Bantal pisang kuning cerah dengan ayunan maut.",
		icon = "rbxassetid://128978593335098",
		templateName = "PisangPillow",
		coinPrice = 450,
		robuxProductId = nil,
		robuxFallbackPrice = 99,
		gamePassId = 2099851125,
		isDefault = false,
	},
	{
		id = "tisu_pillow",
		name = "TISU PILLOW",
		rarity = "Epic",
		description = "Kotak tisu lembut untuk menyeka kekalahan lawan.",
		icon = "rbxassetid://106899199599670",
		templateName = "TisuPillow",
		coinPrice = 650,
		robuxProductId = nil,
		robuxFallbackPrice = 129,
		gamePassId = 2098183202,
		isDefault = false,
	},
}

-- Konfigurasi banner Starter Bundle di bagian atas ShopPage.
ShopConfig.STARTER_BUNDLE = {
	id = "starter_bundle",
	name = "STARTER BUNDLE",
	description = "Great offer just for you!",
	robuxProductId = 3736538186,
	robuxFallbackPrice = 299,
	coinReward = 500,
	pillowIds = { "paw_pillow" },
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
