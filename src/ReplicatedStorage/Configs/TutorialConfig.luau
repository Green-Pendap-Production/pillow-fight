-- @ScriptType: ModuleScript
--[[
	Nama File : TutorialConfig
	Layer     : Config (shared)
	Deskripsi : Konfigurasi NPC tutorial (Mr. Noob) dan dialog di lobby.
]]

local TutorialConfig = {
	-- Nama model NPC di Workspace (dicari rekursif, termasuk alias lama).
	NPC_NAME = "Mr. Noob",
	NPC_ALIASES = { "Mr. Noob", "Sir Nattos" },
	NPC_DISPLAY_NAME = "Mr. Noob",
	CONVERSATION_DISTANCE = 8,
	PROMPT_ACTION_TEXT = "Ngobrol",

	NPC_ANIMATIONS = {
		hi = "rbxassetid://80472994468003", -- loop default & saat berhenti berbicara
		beforeIdle = "rbxassetid://82844705302962", -- sekali saat player mulai berbicara
		idle = "rbxassetid://99282187708889", -- loop setelah BeforeIdle sampai tutorial / selesai
	},

	-- Pohon percakapan Custom Dialogue Box di Lobby
	-- speaker: "npc" | "player"
	-- focus  : "npc" | "player" (arah kamera saat teks muncul)
	-- choiceFocus: "player" | "npc" (opsional: arah kamera saat daftar opsi muncul)
	LOBBY_DIALOG = {
		start = {
			speaker = "npc",
			focus = "npc",
			choiceFocus = "both",
			text = "Mau pemanasan dulu lawan aku sebelum masuk arena?",
			choices = {
				{ id = "tutorial", text = "Ayo, ajarin aku.", nextNode = "accept" },
				{ id = "about", text = "Kamu siapa?", nextNode = "about" },
				{ id = "later", text = "Nanti aja.", nextNode = "goodbye" },
			},
		},
		about = {
			speaker = "npc",
			focus = "npc",
			text = "Aku Mr. Noob, pelatih di sini. Kalau baru main, mending spar dulu lawan aku biar gak langsung tumbang.",
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
			choiceFocus = "both",
			text = "Sebentar aja. Pukul, hindar, beres. Gimana?",
			choices = {
				{ id = "tutorial", text = "Gas, mulai sekarang.", nextNode = "accept" },
				{ id = "later", text = "Lain kali deh.", nextNode = "goodbye" },
			},
		},
		accept = {
			speaker = "npc",
			focus = "both",
			text = "Siap. Pegang bantalmu, hadapin aku.",
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
