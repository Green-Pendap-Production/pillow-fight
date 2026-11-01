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
	CONVERSATION_DISTANCE = 20,

	INITIAL_PROMPT = "Halo! Mau ikut latihan dasar bertarung bantal denganku?",
	GOODBYE_DIALOG = "Babay! Datang lagi kalau kamu mau latihan.",

	-- Dialog choices untuk native Roblox Dialog
	CHOICE_TUTORIAL_USER = "Ayo, ajari aku bertarung!",
	CHOICE_TUTORIAL_RESPONSE = "Bagus! Pegang bantalmu, kita mulai latihannya.",

	CHOICE_ABOUT_USER = "Siapa kamu?",
	CHOICE_ABOUT_RESPONSE = "Aku Sir Nattos, pelatih di sini. Aku bisa mengajarimu teknik bantal!",
}

return TutorialConfig
