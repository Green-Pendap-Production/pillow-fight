-- @ScriptType: ModuleScript
--[[
    Nama File  : EmojiConfig
    Layer      : ReplicatedStorage (Configs)
    Deskripsi  : Daftar emoji/emote untuk radial fan in-game + pengaturan
                 cooldown & durasi tampil di atas kepala karakter.
]]

local EmojiConfig = {}

EmojiConfig.COOLDOWN = 2.5 -- detik antar kirim emoji
EmojiConfig.DISPLAY_DURATION = 2.2 -- detik emoji tampil di atas kepala

-- Pengaturan kipas (radial fan) di sisi kanan tengah layar
EmojiConfig.FAN_RADIUS = 172 -- pixel jarak slot dari tombol utama
EmojiConfig.FAN_SPREAD_DEG = 156 -- total sudut kipas menghadap ke kiri (derajat)
EmojiConfig.CANCEL_RADIUS = 30 -- jarak dari pusat untuk batal/cancel
EmojiConfig.TAB_DEADZONE = 18 -- jarak gerak mouse minimal saat hold Tab

-- Suara emoji (field `sound` per emoji di bawah, opsional -- emoji tanpa
-- `sound` tetap tampil, cuma tanpa bunyi). Diputar 3D dari kepala pengirim,
-- jadi pemain lain di dekatnya ikut dengar. Jarak rolloff disamakan dengan
-- BillboardGui.MaxDistance (85) supaya bunyi hilang di jarak yang sama
-- dengan gelembung emojinya.
EmojiConfig.SOUND = {
	VOLUME = 1,
	ROLLOFF_MIN_DISTANCE = 12,
	ROLLOFF_MAX_DISTANCE = 85,
}

EmojiConfig.EMOJIS = {
	{
		id = "cry",
		label = "CRY",
		symbol = "T_T",
		topColor = Color3.fromRGB(115, 185, 255),
		bottomColor = Color3.fromRGB(60, 115, 215),
		rimColor = Color3.fromRGB(28, 48, 105),
		image = "rbxassetid://120991223819434",
		sound = "rbxassetid://117951745739942", -- cry_emoji.mp3 (level disamakan -5.4 dB)
	},
	{
		id = "doomed",
		label = "DOOMED",
		symbol = "O_O",
		topColor = Color3.fromRGB(185, 150, 255),
		bottomColor = Color3.fromRGB(115, 70, 195),
		rimColor = Color3.fromRGB(52, 26, 100),
		image = "rbxassetid://87678979966873",
	},
	{
		id = "goofy",
		label = "GOOFY",
		symbol = ":P",
		topColor = Color3.fromRGB(255, 225, 85),
		bottomColor = Color3.fromRGB(240, 165, 25),
		rimColor = Color3.fromRGB(115, 65, 10),
		image = "rbxassetid://132419403022486",
		sound = "rbxassetid://87852299158768", -- smug.mp3
	},
	{
		id = "olok",
		label = "OLOK",
		symbol = "HAHA",
		topColor = Color3.fromRGB(255, 175, 75),
		bottomColor = Color3.fromRGB(225, 105, 30),
		rimColor = Color3.fromRGB(110, 42, 12),
		image = "rbxassetid://80711252424875",
	},
	{
		id = "laugh",
		label = "LAUGH",
		symbol = "XD",
		topColor = Color3.fromRGB(110, 225, 100),
		bottomColor = Color3.fromRGB(40, 165, 55),
		rimColor = Color3.fromRGB(20, 75, 28),
		image = "rbxassetid://78989481012686",
	},
	{
		id = "pfft",
		label = "PFFT",
		symbol = "PFFT",
		topColor = Color3.fromRGB(245, 95, 95),
		bottomColor = Color3.fromRGB(185, 40, 50),
		rimColor = Color3.fromRGB(90, 20, 28),
		image = "rbxassetid://140380484045651",
	},
}

local BY_ID = {}
for _, entry in ipairs(EmojiConfig.EMOJIS) do
	BY_ID[entry.id] = entry
end

function EmojiConfig.getById(id)
	return BY_ID[id]
end

return EmojiConfig
