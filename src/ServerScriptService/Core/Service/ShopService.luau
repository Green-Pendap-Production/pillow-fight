-- @ScriptType: ModuleScript
--[[
    Nama File  : ShopService.luau
    Layer      : Service
    Deskripsi  : Menangani transaksi Shop (Coins & Robux MarketplaceService),
                 kepemilikan bantal (ownedPillows), serta Equip bantal ke karakter.
                 Seluruh validasi harga, kepemilikan, dan rate-limit dilakukan di Server.
]]

local ShopService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateRepository = require(ServerScriptService.Core.Repository.PlayerStateRepository)
local CoinService = require(ServerScriptService.Core.Service.CoinService)
local ArenaService = require(ServerScriptService.Core.Service.ArenaService)
local RemoteSafety = require(ServerScriptService.Core.Service.RemoteSafety)
local ShopConfig = require(ReplicatedStorage.Configs.ShopConfig)
local GameplayConfig = require(ReplicatedStorage.Configs.GameplayConfig)

local ACTION_COOLDOWN = 0.35

local ShopActionEvent
local SyncInventoryEvent

local _lastActionTime = {}
local _processedReceipts = {}

local function getOrCreateRemote(remotesFolder, name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local function buildOwnedList(state)
	local list = {}
	if state and type(state.ownedPillows) == "table" then
		for id, owned in pairs(state.ownedPillows) do
			if owned == true then
				table.insert(list, id)
			end
		end
	end
	if not table.find(list, ShopConfig.DEFAULT_PILLOW_ID) then
		table.insert(list, ShopConfig.DEFAULT_PILLOW_ID)
	end
	return list
end

local function syncToClient(player, ok: boolean?, notice: string?)
	if not RemoteSafety.isRealPlayer(player) then
		return
	end
	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	RemoteSafety.fire(SyncInventoryEvent, player, {
		ownedPillows = buildOwnedList(state),
		equippedPillow = state.equippedPillow or ShopConfig.DEFAULT_PILLOW_ID,
		ok = ok,
		notice = notice,
	})
end

local function grantPillow(player, itemId: string)
	local item = ShopConfig.getPillowById(itemId)
	if not item then
		return false
	end
	local state = PlayerStateRepository.get(player)
	if not state then
		return false
	end

	state.ownedPillows = state.ownedPillows or { [ShopConfig.DEFAULT_PILLOW_ID] = true }
	state.ownedPillows[itemId] = true
	return true
end

local function swapPillowIfHolding(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local toolName = GameplayConfig.PILLOW_TOOL_NAME
	local hasInChar = character and character:FindFirstChild(toolName)
	local hasInBag = backpack and backpack:FindFirstChild(toolName)

	if hasInChar or hasInBag then
		ArenaService.equipPillow({ player }, true)
	end
end

local function handleBuyWithCoins(player, itemId: string)
	local item = ShopConfig.getPillowById(itemId)
	if not item then
		syncToClient(player, false, "Item tidak ditemukan.")
		return
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	if state.ownedPillows and state.ownedPillows[itemId] then
		syncToClient(player, false, "Kamu sudah memiliki bantal ini.")
		return
	end

	if type(item.coinPrice) ~= "number" or item.coinPrice <= 0 then
		syncToClient(player, false, "Item ini tidak bisa dibeli dengan Coins.")
		return
	end

	local paid = CoinService.spendCoins(player, item.coinPrice, "Shop:" .. itemId)
	if not paid then
		syncToClient(player, false, "Coins kamu tidak cukup!")
		return
	end

	grantPillow(player, itemId)
	print(string.format("[ShopService] %s membeli %s (%d Coins)", player.Name, itemId, item.coinPrice))
	syncToClient(player, true, "Berhasil membeli " .. item.name .. "!")
end

local function handleEquip(player, itemId: string)
	local item = ShopConfig.getPillowById(itemId)
	if not item then
		syncToClient(player, false, "Item tidak ditemukan.")
		return
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return
	end

	if state.isPlaying then
		syncToClient(player, false, "Tidak bisa ganti bantal saat pertandingan berlangsung.")
		return
	end

	if not (state.ownedPillows and state.ownedPillows[itemId]) then
		syncToClient(player, false, "Kamu belum memiliki bantal ini.")
		return
	end

	PlayerStateRepository.set(player, "equippedPillow", itemId)
	swapPillowIfHolding(player)

	print(string.format("[ShopService] %s memakai bantal %s", player.Name, itemId))
	syncToClient(player, true, "Memakai " .. item.name)
end

local function onShopAction(player, action, itemId)
	if not RemoteSafety.isRealPlayer(player) then
		return
	end
	if type(action) ~= "string" or type(itemId) ~= "string" then
		return
	end

	local now = os.clock()
	if _lastActionTime[player.UserId] and (now - _lastActionTime[player.UserId]) < ACTION_COOLDOWN then
		return
	end
	_lastActionTime[player.UserId] = now

	if action == "buy_coin" then
		handleBuyWithCoins(player, itemId)
	elseif action == "equip" then
		handleEquip(player, itemId)
	elseif action == "sync" then
		syncToClient(player)
	end
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local state = PlayerStateRepository.get(player)
	if not state then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if _processedReceipts[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	local bundle = ShopConfig.STARTER_BUNDLE
	if bundle and bundle.robuxProductId and bundle.robuxProductId == productId then
		if type(bundle.coinReward) == "number" and bundle.coinReward > 0 then
			CoinService.addCoins(player, bundle.coinReward, "Shop:StarterBundle")
		end
		if type(bundle.pillowIds) == "table" then
			for _, pillowId in ipairs(bundle.pillowIds) do
				grantPillow(player, pillowId)
			end
		end
		_processedReceipts[receiptInfo.PurchaseId] = true
		syncToClient(player, true, "Starter Bundle berhasil diklaim!")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local item = ShopConfig.getPillowByProductId(productId)
	if item then
		grantPillow(player, item.id)
		_processedReceipts[receiptInfo.PurchaseId] = true
		syncToClient(player, true, "Berhasil membeli " .. item.name .. "!")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn("[ShopService] ProductId tidak dikenali di ProcessReceipt: " .. tostring(productId))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function checkGamePasses(player)
	-- Di Studio, akun creator otomatis memiliki semua Game Pass yang dibuatnya sendiri.
	-- Lewati auto-grant saat di Studio agar developer tetap bisa menguji Shop/pembelian.
	if RunService:IsStudio() then
		return
	end
	for _, item in ipairs(ShopConfig.PILLOWS) do
		if item.gamePassId and item.gamePassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.gamePassId)
			end)
			if ok and owns then
				grantPillow(player, item.id)
			end
		end
	end
end

function ShopService.onDataLoaded(player)
	if not RemoteSafety.isRealPlayer(player) then
		return
	end
	task.spawn(function()
		checkGamePasses(player)
		syncToClient(player)
	end)
end

function ShopService.cleanup(player)
	if player then
		_lastActionTime[player.UserId] = nil
	end
end

function ShopService.init()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	ShopActionEvent = getOrCreateRemote(remotesFolder, "ShopActionEvent")
	SyncInventoryEvent = getOrCreateRemote(remotesFolder, "SyncInventoryEvent")

	ShopActionEvent.OnServerEvent:Connect(onShopAction)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if not wasPurchased or not RemoteSafety.isRealPlayer(player) then
			return
		end
		for _, item in ipairs(ShopConfig.PILLOWS) do
			if item.gamePassId and item.gamePassId == gamePassId then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
				end)
				if (ok and owns) or RunService:IsStudio() then
					grantPillow(player, item.id)
					syncToClient(player, true, "GamePass " .. item.name .. " aktif!")
				end
				break
			end
		end
	end)

	print("[ShopService] Berhasil diinisialisasi.")
end

return ShopService
