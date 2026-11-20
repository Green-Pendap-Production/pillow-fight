-- @ScriptType: ModuleScript
--[[
    Nama File  : EmojiService
    Layer      : Server (Service)
    Deskripsi  : Memvalidasi & meneruskan permintaan emoji dari pemain yang
                 sedang berada di match, lengkap dengan cooldown anti-spam.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmojiConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("EmojiConfig"))

local EmojiService = {}

local lastSentAt = {} -- [Player] = os.clock()
local emojiEvent = nil

local function getOrCreateRemote(remotesFolder, name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

function EmojiService.init()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	emojiEvent = getOrCreateRemote(remotesFolder, "EmojiEvent")

	emojiEvent.OnServerEvent:Connect(function(player, emojiId)
		if typeof(emojiId) ~= "string" then
			return
		end
		if not EmojiConfig.getById(emojiId) then
			return
		end

		local now = os.clock()
		local prev = lastSentAt[player]
		if prev and (now - prev) < (EmojiConfig.COOLDOWN - 0.1) then
			return
		end
		lastSentAt[player] = now

		emojiEvent:FireAllClients(player, emojiId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSentAt[player] = nil
	end)

	print("[EmojiService] Ready")
end

return EmojiService
