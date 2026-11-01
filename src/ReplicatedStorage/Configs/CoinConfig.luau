--[[
    Nama File  : CoinConfig
    Layer      : Config (Shared)
    Deskripsi  : Angka reward virtual coin per hasil match. Dibaca CoinService
                 (server) buat ngitung reward, dan CoinHudClient (client) cuma
                 buat label breakdown -- nilai yang beneran dikasih SELALU
                 dihitung di server.
    Tanggal    : 17 Oktober 2026
    Versi      : 1.0
]]

local CoinConfig = {
	-- Match PvP (lawan pemain asli)
	PVP_WIN = 50,
	PVP_LOSS = 15, -- hadiah partisipasi biar yang kalah tetap dapet sesuatu

	-- Match vs Bot. Sengaja kecil: bot gak dicatat ke leaderboard/anti-farming
	-- (lihat ArenaService.endMatch), jadi kalau reward-nya gede, farming
	-- coin lawan bot bakal jadi cara paling efisien.
	BOT_WIN = 10,
	BOT_LOSS = 0,

	-- Bonus win streak (PvP doang). Streak 2 = +5, streak 3 = +10, dst,
	-- mentok di STREAK_BONUS_MAX biar gak meledak.
	STREAK_BONUS_PER_WIN = 5,
	STREAK_BONUS_MAX = 25,

	-- Yang kalah karena AFK / reset karakter di tengah match (forfeit) gak
	-- dapet hadiah partisipasi.
	FORFEIT_LOSS = 0,
}

return CoinConfig
