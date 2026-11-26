-- @ScriptType: ModuleScript
--[[
	Nama File : TutorialConfig
	Layer     : Config (shared)
	Deskripsi : Konfigurasi NPC tutorial (Sir Nattos) dan dialog di lobby.
]]

local TutorialConfig = {
	-- Nama model NPC di Workspace (dicari rekursif).
	NPC_NAME = "Sir Nattos",
	NPC_DISPLAY_NAME = "Sir Nattos",
	CONVERSATION_DISTANCE = 14,
	PROMPT_ACTION_TEXT = "Ngobrol",

	-- Pohon percakapan Custom Dialogue Box di Lobby
	-- speaker: "npc" | "player"
	-- focus  : "npc" | "player" (arah kamera saat teks muncul)
	-- choiceFocus: "player" | "npc" (opsional: arah kamera saat daftar opsi muncul)
	LOBBY_DIALOG = {
		start = {
			speaker = "npc",
			focus = "npc",
			choiceFocus = "player",
			text = "Mau pemanasan dulu sebelum masuk arena?",
			choices = {
				{ id = "tutorial", text = "Ayo, ajarin aku.", nextNode = "accept" },
				{ id = "about", text = "Kamu siapa?", nextNode = "about" },
				{ id = "later", text = "Nanti aja.", nextNode = "goodbye" },
			},
		},
		about = {
			speaker = "npc",
			focus = "npc",
			text = "Aku Sir Nattos, pelatih di sini. Kalau baru main, mending latihan sebentar biar gak langsung tumbang.",
			nextNode = "about_reply",
		},
		about_reply = {
			speaker = "player",
			focus = "player",
			text = "Oke, latihannya lama gak?",
			nextNode = "about_confirm",
		},
		about_confirm = {
			speaker = "npc",
			focus = "npc",
			choiceFocus = "player",
			text = "Sebentar aja. Pukul, menghindar, beres. Gimana?",
			choices = {
				{ id = "tutorial", text = "Gas, mulai sekarang.", nextNode = "accept" },
				{ id = "later", text = "Lain kali deh.", nextNode = "goodbye" },
			},
		},
		accept = {
			speaker = "npc",
			focus = "npc",
			text = "Siap. Pegang bantalmu.",
			action = "startTutorial",
			autoCloseDelay = 0.9,
		},
		goodbye = {
			speaker = "npc",
			focus = "npc",
			text = "Oke. Balik ke sini aja kalau mau latihan.",
			autoCloseDelay = 0.9,
		},
	},
}

return TutorialConfig
