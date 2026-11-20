-- @ScriptType: LocalScript
--[[
    Nama File  : ResultScreenClient
    Layer      : Client (UI)
    Deskripsi  : Layar hasil match (VICTORY / DEFEAT) yang muncul begitu match
                 beneran selesai. Kiri: mahkota + judul + pita + avatar pemain.
                 Kanan: panel MATCH STATS, kartu REWARDS, dan tombol LOBBY.
                 GUI-nya dibikin lewat script, gak perlu nyiapin apa-apa di
                 Studio.

                 Alur:
                 - Server (ArenaService.endMatch) nembak MatchResultEvent ke
                   tiap pemain asli. Teleport balik ke lobby terjadi ~2.6 detik
                   kemudian, DI BELAKANG layar ini.
                 - Tombol LOBBY (atau Enter / ButtonA, atau auto-close) cuma
                   nutup layar -- pemain udah ada di lobby saat itu.
                 - Selama layar kebuka, atribut lokal "ResultScreenOpen" di
                   LocalPlayer = true. CoinHudClient nahan popup "+X coin"-nya
                   sampai layar ini ditutup.

                 Payload MatchResultEvent:
                   { didWin, isBotMatch, opponentName, score = {mine, theirs},
                     stats = { hits, perfectDodges, ffylSurvived, bestCombo },
                     rewards = { coins = n, ... } }
    Dependensi : - ReplicatedStorage > Remotes > MatchResultEvent
                 - StarterPlayerScripts > UI > AvatarUtil
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local AvatarUtil = require(script.Parent:WaitForChild("AvatarUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MatchResultEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchResultEvent")

-- ================================================================
-- CONFIG
-- ================================================================
local OPEN_ATTRIBUTE = "ResultScreenOpen"
local DISPLAY_ORDER = 100 -- di atas HUD/KO text, di bawah blink kamera (1000)

-- Ukuran kanvas desain. Semua posisi di bawah pakai piksel kanvas ini, lalu
-- di-scale (UIScale) supaya muat di layar apa pun tanpa merusak proporsi.
local CANVAS = Vector2.new(1200, 720)
local MAX_SCALE = 1.4

local SHOW_DELAY = 0.25
local AUTO_CLOSE_SECONDS = 25 -- 0 = gak pernah nutup sendiri
local BLUR_SIZE = 14

-- Kosongin buat pakai emoji; isi "rbxassetid://..." kalau udah ada gambarnya.
local VICTORY_ICON_IMAGE = ""
local DEFEAT_ICON_IMAGE = ""

-- Urutan baris MATCH STATS. key = field di payload.stats.
local STAT_ROWS = {
	{ key = "hits", label = "Pillow Smacked" },
	{ key = "perfectDodges", label = "Perfect Dodge" },
	{ key = "ffylSurvived", label = "FFYL Survived" },
	{ key = "bestCombo", label = "Best Combo" },
}

-- Kartu REWARDS. Cuma yang key-nya ADA di payload.rewards yang ditampilin,
-- jadi XP/Token tinggal dikirim server -- kartunya otomatis muncul.
-- image kosong = badge bulat digambar dari Frame + huruf `letter`.
local REWARD_CARDS = {
	{
		key = "coins",
		label = "Coins",
		letter = "C",
		color = Color3.fromRGB(255, 205, 60),
		rim = Color3.fromRGB(190, 130, 20),
		ink = Color3.fromRGB(150, 95, 10),
		image = "",
	},
	{
		key = "xp",
		label = "XP",
		letter = "XP",
		color = Color3.fromRGB(110, 170, 255),
		rim = Color3.fromRGB(30, 60, 150),
		ink = Color3.fromRGB(20, 40, 110),
		image = "",
	},
	{
		key = "tokens",
		label = "Tokens",
		letter = "T",
		color = Color3.fromRGB(205, 140, 255),
		rim = Color3.fromRGB(110, 50, 170),
		ink = Color3.fromRGB(80, 30, 130),
		image = "",
	},
}

local WHITE = Color3.new(1, 1, 1)

local THEMES = {
	victory = {
		title = "VICTORY",
		subtitle = "YOU WON THE PILLOW FIGHT!",
		icon = "👑",
		iconImage = VICTORY_ICON_IMAGE,
		titleStroke = Color3.fromRGB(26, 72, 34),
		ribbonTop = Color3.fromRGB(95, 205, 80),
		ribbonBottom = Color3.fromRGB(30, 140, 45),
		ribbonTail = Color3.fromRGB(22, 100, 34),
		ribbonStroke = Color3.fromRGB(18, 66, 26),
		panelTop = Color3.fromRGB(110, 215, 95),
		panelBottom = Color3.fromRGB(70, 190, 70),
		panelStroke = Color3.fromRGB(22, 80, 30),
		inner = Color3.fromRGB(42, 145, 48),
		innerStroke = Color3.fromRGB(28, 100, 34),
		card = Color3.fromRGB(44, 150, 52),
	},
	defeat = {
		title = "DEFEAT",
		subtitle = "BETTER LUCK NEXT TIME!",
		icon = "💤",
		iconImage = DEFEAT_ICON_IMAGE,
		titleStroke = Color3.fromRGB(92, 26, 34),
		ribbonTop = Color3.fromRGB(235, 90, 85),
		ribbonBottom = Color3.fromRGB(170, 40, 50),
		ribbonTail = Color3.fromRGB(120, 28, 38),
		ribbonStroke = Color3.fromRGB(80, 20, 28),
		panelTop = Color3.fromRGB(125, 135, 220),
		panelBottom = Color3.fromRGB(90, 100, 195),
		panelStroke = Color3.fromRGB(32, 36, 90),
		inner = Color3.fromRGB(60, 68, 150),
		innerStroke = Color3.fromRGB(40, 46, 110),
		card = Color3.fromRGB(64, 72, 158),
	},
}

-- Tombol LOBBY selalu hijau (ajakan aksi), menang ataupun kalah.
local BUTTON_TOP = Color3.fromRGB(70, 220, 60)
local BUTTON_BOTTOM = Color3.fromRGB(20, 150, 30)
local BUTTON_STROKE = Color3.fromRGB(14, 70, 20)
local BUTTON_SHADOW = Color3.fromRGB(12, 60, 18)

-- ================================================================
-- HELPERS
-- ================================================================
local function create(className, props, children)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function textStroke(color, thickness)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function gradient(top, bottom)
	return create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

local function text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextColor3 = WHITE,
		TextSize = 20,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local children = defaults.Children
	defaults.Children = nil
	return create("TextLabel", defaults, children)
end

local function tween(inst, duration, props, style, direction, delay)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		props
	)
	t:Play()
	return t
end

local function formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Header seksi "—— MATCH STATS ——"
local function sectionHeader(parent, title, position, width)
	local holder = create("Frame", {
		Name = title:gsub(" ", "") .. "Header",
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromOffset(width, 36),
		Parent = parent,
	})
	text({
		Text = title,
		TextSize = 20,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(200, 36),
		Parent = holder,
	})
	local lineWidth = (width - 200) / 2 - 24
	for _, side in ipairs({ 0, 1 }) do
		create("Frame", {
			BackgroundColor3 = Color3.fromRGB(15, 40, 18),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(side, 0.5),
			Position = UDim2.new(side, side == 0 and 24 or -24, 0.5, 0),
			Size = UDim2.fromOffset(lineWidth, 3),
			Parent = holder,
		}, { corner(2) })
	end
	return holder
end

-- Badge bulat buat kartu reward (atau ImageLabel kalau def.image diisi)
local function rewardBadge(def, parent)
	if def.image and def.image ~= "" then
		return create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = def.image,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 26),
			Size = UDim2.fromOffset(72, 72),
			Parent = parent,
		})
	end

	local badge = create("Frame", {
		Name = "Icon",
		BackgroundColor3 = def.color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(72, 72),
		Parent = parent,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke(def.rim, 4),
	})
	text({
		Text = def.letter,
		TextScaled = true,
		TextColor3 = def.ink,
		Size = UDim2.fromScale(1, 1),
		Parent = badge,
		Children = {
			create("UIPadding", {
				PaddingTop = UDim.new(0.22, 0),
				PaddingBottom = UDim.new(0.22, 0),
				PaddingLeft = UDim.new(0.15, 0),
				PaddingRight = UDim.new(0.15, 0),
			}),
		},
	})
	return badge
end

-- ================================================================
-- STATE
-- ================================================================
local current = nil -- tabel hasil buildScreen yang lagi tampil
local openToken = 0

local function setOpenAttribute(isOpen)
	player:SetAttribute(OPEN_ATTRIBUTE, isOpen)
end
setOpenAttribute(false)

-- keepOpenAttribute: dipakai pas layar lama langsung diganti layar baru,
-- supaya CoinHudClient gak sempat ngira layarnya udah ketutup.
local function destroyCurrent(keepOpenAttribute)
	if current then
		ContextActionService:UnbindAction("ResultScreenClose")
		current.gui:Destroy()
		if current.blur then
			current.blur:Destroy()
		end
		current = nil
	end
	if not keepOpenAttribute then
		setOpenAttribute(false)
	end
end

local function closeScreen()
	local screen = current
	if not screen or screen.closing then
		return
	end
	screen.closing = true
	ContextActionService:UnbindAction("ResultScreenClose")

	-- Kolom kiri keluar ke kiri, kanan ke kanan, latar memudar.
	local duration = 0.35
	local easeIn = Enum.EasingDirection.In
	tween(screen.overlay, duration, { BackgroundTransparency = 1 })
	tween(screen.leftColumn, duration, { Position = UDim2.fromOffset(-CANVAS.X, 0) }, Enum.EasingStyle.Back, easeIn)
	tween(screen.rightColumn, duration, { Position = UDim2.fromOffset(CANVAS.X, 0) }, Enum.EasingStyle.Back, easeIn)
	if screen.blur then
		tween(screen.blur, duration, { Size = 0 })
	end

	task.delay(duration, function()
		if current == screen then
			destroyCurrent()
		end
	end)
end

-- ================================================================
-- BUILD
-- ================================================================
local function buildScreen(result)
	local didWin = result.didWin == true
	local theme = didWin and THEMES.victory or THEMES.defeat
	local stats = type(result.stats) == "table" and result.stats or {}
	local rewards = type(result.rewards) == "table" and result.rewards or {}

	local gui = create("ScreenGui", {
		Name = "ResultScreenGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = DISPLAY_ORDER,
		Parent = playerGui,
	})

	-- Latar: gelap transparan + gradasi (atas lebih terang) + blur dunia
	local overlay = create("Frame", {
		Name = "Overlay",
		BackgroundColor3 = Color3.fromRGB(10, 18, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true, -- telan klik ke dunia di belakang
		Parent = gui,
	}, {
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
		}),
	})

	local blur = create("BlurEffect", { Name = "ResultScreenBlur", Size = 0, Parent = Lighting })

	local canvas = create("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		Parent = gui,
	})
	local canvasScale = create("UIScale", { Parent = canvas })

	local function updateScale()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or CANVAS
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		canvasScale.Scale = math.min(viewport.X / CANVAS.X, viewport.Y / CANVAS.Y, MAX_SCALE)
	end
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		gui.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end

	-- Kolom kiri & kanan dibungkus Frame selebar kanvas supaya bisa digeser
	-- barengan pas animasi tutup.
	local leftColumn = create("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = canvas,
	})
	local rightColumn = create("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = canvas,
	})

	-- ---------------- KIRI ----------------
	local LEFT_X = 330

	-- Avatar seluruh badan, nempel di bawah kanvas (paling belakang)
	local avatar = create("ImageLabel", {
		Name = "Avatar",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(LEFT_X, CANVAS.Y + 120),
		Size = UDim2.fromOffset(440, 440),
		ImageTransparency = 1,
		ZIndex = 1,
		Parent = leftColumn,
	})
	AvatarUtil.setThumbnail(avatar, player.UserId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)

	-- Ikon (mahkota / zzz)
	local icon
	if theme.iconImage ~= "" then
		icon = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = theme.iconImage,
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		icon = text({ Text = theme.icon, TextScaled = true })
	end
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromOffset(LEFT_X, 20)
	icon.Size = UDim2.fromOffset(84, 84)
	icon.Rotation = -25
	icon.ZIndex = 4
	icon.Parent = leftColumn

	-- Judul besar + bayangan di belakangnya
	local titleHolder = create("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(LEFT_X, 172),
		Size = UDim2.fromOffset(620, 130),
		ZIndex = 3,
		Parent = leftColumn,
	})
	local titleScale = create("UIScale", { Scale = 0.2, Parent = titleHolder })
	text({
		Name = "Shadow",
		Text = theme.title,
		TextScaled = true,
		TextColor3 = theme.titleStroke,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = titleHolder,
		Children = { textStroke(theme.titleStroke, 7) },
	})
	text({
		Name = "Label",
		Text = theme.title,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = titleHolder,
		Children = { textStroke(theme.titleStroke, 7) },
	})

	-- Pita di bawah judul (dengan "ekor" lipatan di kiri-kanan)
	local ribbon = create("Frame", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(LEFT_X, 266),
		Size = UDim2.fromOffset(470, 50),
		ZIndex = 3,
		Parent = leftColumn,
	})
	local ribbonScale = create("UIScale", { Scale = 0.01, Parent = ribbon })
	for _, side in ipairs({ 0, 1 }) do
		create("Frame", {
			Name = "Tail",
			BackgroundColor3 = theme.ribbonTail,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.new(side, side == 0 and -26 or 26, 0, 10),
			Size = UDim2.fromOffset(70, 46),
			ZIndex = 3,
			Parent = ribbon,
		}, { corner(6), stroke(theme.ribbonStroke, 3) })
	end
	local ribbonFace = create("Frame", {
		Name = "Face",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = ribbon,
	}, { corner(8), stroke(theme.ribbonStroke, 3), gradient(theme.ribbonTop, theme.ribbonBottom) })
	text({
		Text = theme.subtitle,
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = ribbonFace,
		Children = { textStroke(theme.ribbonStroke, 2) },
	})

	-- Baris "vs Lawan  •  2 - 1"
	local score = type(result.score) == "table" and result.score or {}
	local matchupParts = {}
	if type(result.opponentName) == "string" and result.opponentName ~= "" then
		table.insert(matchupParts, "vs " .. result.opponentName)
	end
	if score[1] and score[2] then
		table.insert(matchupParts, string.format("%d - %d", tonumber(score[1]) or 0, tonumber(score[2]) or 0))
	end
	local matchup = text({
		Name = "Matchup",
		Text = table.concat(matchupParts, "   •   "),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(LEFT_X, 318),
		Size = UDim2.fromOffset(470, 28),
		ZIndex = 5,
		Parent = leftColumn,
		Children = { textStroke(Color3.fromRGB(10, 18, 40), 2) },
	})
	local matchupStroke = matchup:FindFirstChildOfClass("UIStroke")
	matchupStroke.Transparency = 1

	-- ---------------- KANAN ----------------
	local PANEL_X, PANEL_Y = 700, 24
	local PANEL_W, PANEL_H = 470, 548
	local INNER_W = PANEL_W - 32

	local panel = create("Frame", {
		Name = "Panel",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PANEL_X + 560, PANEL_Y),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		ZIndex = 2,
		Parent = rightColumn,
	}, { corner(16), stroke(theme.panelStroke, 4), gradient(theme.panelTop, theme.panelBottom) })

	-- Kotak MATCH STATS
	local rowHeight = 38
	local statsBoxHeight = 56 + rowHeight * #STAT_ROWS + 14
	local statsBox = create("Frame", {
		Name = "Stats",
		BackgroundColor3 = theme.inner,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(INNER_W, statsBoxHeight),
		Parent = panel,
	}, { corner(10), stroke(theme.innerStroke, 2) })
	sectionHeader(statsBox, "MATCH STATS", UDim2.fromOffset(0, 10), INNER_W)

	local rowsHolder = create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 56),
		Size = UDim2.fromOffset(INNER_W - 56, rowHeight * #STAT_ROWS),
		Parent = statsBox,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical }),
	})

	local statRows = {}
	for index, def in ipairs(STAT_ROWS) do
		local row = create("Frame", {
			Name = def.key,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, rowHeight),
			Parent = rowsHolder,
		})
		local nameLabel = text({
			Text = def.label,
			Font = Enum.Font.GothamBold,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1,
			Size = UDim2.fromScale(0.75, 1),
			Parent = row,
		})
		local valueLabel = text({
			Text = "0",
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.25, 1),
			Parent = row,
		})
		table.insert(statRows, {
			nameLabel = nameLabel,
			valueLabel = valueLabel,
			value = tonumber(stats[def.key]) or 0,
		})
	end

	-- REWARDS
	local rewardsY = 16 + statsBoxHeight + 14
	sectionHeader(panel, "REWARDS", UDim2.fromOffset(16, rewardsY), INNER_W)

	local cardsY = rewardsY + 42
	local cardsHeight = PANEL_H - cardsY - 16
	local cardsHolder = create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, cardsY),
		Size = UDim2.fromOffset(INNER_W, cardsHeight),
		Parent = panel,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})

	local shownCards = {}
	for _, def in ipairs(REWARD_CARDS) do
		if rewards[def.key] ~= nil then
			table.insert(shownCards, def)
		end
	end
	local cardWidth = math.min(170, (INNER_W - 10 * math.max(#shownCards - 1, 0)) / math.max(#shownCards, 1))

	local rewardCards = {}
	for index, def in ipairs(shownCards) do
		local card = create("Frame", {
			Name = def.key,
			BackgroundColor3 = theme.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(cardWidth, cardsHeight),
			Parent = cardsHolder,
		}, { corner(10), stroke(theme.innerStroke, 2) })
		local cardScale = create("UIScale", { Scale = 0.01, Parent = card })
		rewardBadge(def, card)
		local amountLabel = text({
			Name = "Amount",
			Text = "+ 0",
			TextSize = 34,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -40),
			Size = UDim2.new(1, -8, 0, 42),
			Parent = card,
			Children = { textStroke(theme.panelStroke, 2) },
		})
		text({
			Name = "Label",
			Text = def.label,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -8, 0, 22),
			Parent = card,
		})
		table.insert(rewardCards, {
			scale = cardScale,
			amountLabel = amountLabel,
			value = tonumber(rewards[def.key]) or 0,
		})
	end

	-- Tombol LOBBY: holder (pulse idle) > shadow + button (hover/press)
	local BUTTON_Y = PANEL_Y + PANEL_H + 20
	local buttonHolder = create("Frame", {
		Name = "LobbyButton",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(PANEL_X + PANEL_W / 2, CANVAS.Y + 40),
		Size = UDim2.fromOffset(PANEL_W, 100),
		ZIndex = 2,
		Parent = rightColumn,
	})
	local pulseScale = create("UIScale", { Parent = buttonHolder })
	create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = BUTTON_SHADOW,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = buttonHolder,
	}, { corner(16) })
	local button = create("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		-- Modal: lepas kunci mouse (Shift Lock dll) selama tombol ini tampil,
		-- kalau nggak tombolnya gak bisa diklik.
		Modal = true,
		ZIndex = 3,
		Parent = buttonHolder,
	}, {
		corner(16),
		stroke(BUTTON_STROKE, 4),
		gradient(BUTTON_TOP, BUTTON_BOTTOM),
	})
	-- Teks di label terpisah: satu objek cuma bisa pakai satu UIStroke, dan
	-- stroke tombol sudah dipakai buat tepinya.
	text({
		Name = "Label",
		Text = "LOBBY",
		TextSize = 52,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = button,
		Children = { textStroke(BUTTON_STROKE, 3) },
	})
	local buttonScale = create("UIScale", { Parent = button })

	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		tween(buttonScale, 0.12, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		tween(buttonScale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(buttonScale, 0.08, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(buttonScale, 0.12, { Scale = hovering and 1.04 or 1 })
	end)
	button.Activated:Connect(closeScreen)

	return {
		gui = gui,
		blur = blur,
		overlay = overlay,
		leftColumn = leftColumn,
		rightColumn = rightColumn,
		closing = false,

		icon = icon,
		titleScale = titleScale,
		ribbonScale = ribbonScale,
		matchup = matchup,
		matchupStroke = matchupStroke,
		avatar = avatar,
		panel = panel,
		panelTarget = UDim2.fromOffset(PANEL_X, PANEL_Y),
		buttonHolder = buttonHolder,
		buttonTarget = UDim2.fromOffset(PANEL_X + PANEL_W / 2, BUTTON_Y),
		pulseScale = pulseScale,
		statRows = statRows,
		rewardCards = rewardCards,
	}
end

-- ================================================================
-- ANIMASI MASUK
-- ================================================================
local function countUp(screen, label, target, duration, delay, prefix)
	local value = Instance.new("NumberValue")
	value.Parent = screen.gui
	value.Changed:Connect(function(v)
		label.Text = (prefix or "") .. formatNumber(v)
	end)
	label.Text = (prefix or "") .. "0"
	tween(value, duration, { Value = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
end

local function playIntro(screen)
	local back = Enum.EasingStyle.Back
	local out = Enum.EasingDirection.Out

	tween(screen.overlay, 0.35, { BackgroundTransparency = 0.12 })
	tween(screen.blur, 0.35, { Size = BLUR_SIZE })

	-- Kiri
	tween(screen.titleScale, 0.5, { Scale = 1 }, back, out, 0.05)
	tween(screen.icon, 0.5, { Position = UDim2.fromOffset(330, 62), Rotation = 0 }, back, out, 0.2)
	tween(screen.ribbonScale, 0.4, { Scale = 1 }, back, out, 0.3)
	tween(screen.matchup, 0.3, { TextTransparency = 0 }, nil, nil, 0.5)
	tween(screen.matchupStroke, 0.3, { Transparency = 0 }, nil, nil, 0.5)
	tween(screen.avatar, 0.55, {
		Position = UDim2.fromOffset(330, 720),
		ImageTransparency = 0,
	}, Enum.EasingStyle.Quart, out, 0.25)

	-- Kanan
	tween(screen.panel, 0.55, { Position = screen.panelTarget }, Enum.EasingStyle.Quint, out, 0.15)
	tween(screen.buttonHolder, 0.5, { Position = screen.buttonTarget }, back, out, 0.4)

	-- Baris statistik muncul satu-satu, angkanya naik
	local rowDelay = 0.6
	for i, row in ipairs(screen.statRows) do
		local d = rowDelay + (i - 1) * 0.1
		tween(row.nameLabel, 0.2, { TextTransparency = 0 }, nil, nil, d)
		tween(row.valueLabel, 0.2, { TextTransparency = 0 }, nil, nil, d)
		countUp(screen, row.valueLabel, row.value, 0.5, d)
	end

	-- Kartu reward pop + angka naik
	local cardDelay = rowDelay + #screen.statRows * 0.1 + 0.15
	for i, card in ipairs(screen.rewardCards) do
		local d = cardDelay + (i - 1) * 0.12
		tween(card.scale, 0.35, { Scale = 1 }, back, out, d)
		countUp(screen, card.amountLabel, card.value, 0.7, d + 0.1, "+ ")
	end

	-- Tombol "napas" pelan begitu intro selesai
	task.delay(cardDelay + 0.6, function()
		if screen.gui.Parent and not screen.closing then
			TweenService:Create(
				screen.pulseScale,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.035 }
			):Play()
		end
	end)
end

-- ================================================================
-- ENTRY
-- ================================================================
local function showResult(result)
	destroyCurrent(true)

	local screen = buildScreen(result)
	current = screen
	setOpenAttribute(true)

	ContextActionService:BindAction("ResultScreenClose", function(_, state)
		if state == Enum.UserInputState.Begin then
			closeScreen()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)

	playIntro(screen)

	if AUTO_CLOSE_SECONDS > 0 then
		task.delay(AUTO_CLOSE_SECONDS, function()
			if current == screen then
				closeScreen()
			end
		end)
	end
end

MatchResultEvent.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then
		return
	end
	openToken += 1
	local myToken = openToken
	-- Atribut dinyalain duluan (bukan nunggu SHOW_DELAY) supaya CoinHudClient
	-- udah tau layar ini bakal muncul begitu reward-nya masuk.
	setOpenAttribute(true)
	task.delay(SHOW_DELAY, function()
		if openToken == myToken then
			showResult(result)
		end
	end)
end)

print("[ResultScreenClient] Berhasil diinisialisasi")
