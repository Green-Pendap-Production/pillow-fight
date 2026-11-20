-- @ScriptType: ModuleScript
--[[
    Nama File  : EmojiConfig
    Layer      : ReplicatedStorage (Configs)
    Deskripsi  : Daftar emoji/emote untuk radial fan in-game + pengaturan
                 cooldown & durasi tampil di atas kepala karakter.
                 Field `image` dikosongkan sebagai dummy (akan render badge
                 simbol & label). Tinggal isi "rbxassetid://..." kalau aset
                 gambar sudah siap.
]]

local EmojiConfig = {}

EmojiConfig.COOLDOWN = 2.5 -- detik antar kirim emoji
EmojiConfig.DISPLAY_DURATION = 2.2 -- detik emoji tampil di atas kepala

-- Pengaturan kipas (radial fan) di sisi kanan tengah layar
EmojiConfig.FAN_RADIUS = 115 -- pixel jarak slot dari tombol utama
EmojiConfig.FAN_SPREAD_DEG = 140 -- total sudut kipas menghadap ke kiri (derajat)
EmojiConfig.CANCEL_RADIUS = 32 -- jarak dari pusat tombol untuk batal/cancel

EmojiConfig.EMOJIS = {
	{
		id = "gg",
		label = "GG!",
		symbol = "GG",
		color = Color3.fromRGB(255, 200, 60),
		image = "",
	},
	{
		id = "happy",
		label = "EZ!",
		symbol = ":D",
		color = Color3.fromRGB(90, 220, 130),
		image = "",
	},
	{
		id = "angry",
		label = "GRR!",
		symbol = ">:(",
		color = Color3.fromRGB(245, 85, 85),
		image = "",
	},
	{
		id = "laugh",
		label = "HAHA",
		symbol = "XD",
		color = Color3.fromRGB(255, 155, 65),
		image = "",
	},
	{
		id = "cry",
		label = "HUHU",
		symbol = "T_T",
		color = Color3.fromRGB(100, 185, 255),
		image = "",
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
