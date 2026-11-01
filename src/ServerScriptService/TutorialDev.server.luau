-- @ScriptType: Script
--[[
	Nama File : TutorialDev.server.luau
	Layer     : Server (Dev / Testing)
	Deskripsi : Tool development untuk memicu tutorial lewat command chat /tutorial
	            dan shortcut testing.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")

local TutorialBattleService = require(ServerScriptService.Core.Service.TutorialBattleService)

local function triggerTutorial(player)
	print("[TutorialDev] /tutorial dipicu oleh " .. player.Name)
	local started = TutorialBattleService.start(player)
	if not started then
		warn(
			"[TutorialDev] Gagal memulai tutorial untuk "
				.. player.Name
				.. " (pemain sedang match / matchmaking / tutorial sudah aktif)"
		)
	end
end

-- 1. Support modern TextChatService (/tutorial atau /tut)
local textCommands = TextChatService:FindFirstChild("TextChatCommands")
if not textCommands then
	textCommands = Instance.new("Folder")
	textCommands.Name = "TextChatCommands"
	textCommands.Parent = TextChatService
end

local tutorialCmd = textCommands:FindFirstChild("TutorialCommand")
if not tutorialCmd then
	tutorialCmd = Instance.new("TextChatCommand")
	tutorialCmd.Name = "TutorialCommand"
	tutorialCmd.PrimaryAlias = "/tutorial"
	tutorialCmd.SecondaryAlias = "/tut"
	tutorialCmd.Parent = textCommands
end

tutorialCmd.Triggered:Connect(function(textSource, _message)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if player then
		triggerTutorial(player)
	end
end)

-- 2. Fallback legacy Player.Chatted
local function registerPlayer(player)
	player.Chatted:Connect(function(message)
		local cleaned = string.lower(string.gsub(message, "%s+", ""))
		if cleaned == "/tutorial" or cleaned == "/tut" then
			triggerTutorial(player)
		end
	end)
end

Players.PlayerAdded:Connect(registerPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	registerPlayer(player)
end

print("[TutorialDev] Command /tutorial siap digunakan di chat.")
