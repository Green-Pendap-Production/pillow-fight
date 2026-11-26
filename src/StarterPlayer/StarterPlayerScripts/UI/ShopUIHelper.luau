--[[
    Nama File  : ShopUIHelper
    Layer      : Client (UI Helper)
    Deskripsi  : Helper animasi hover/press UIScale dan grid layout responsif 4-kolom
                 yang proporsinya diukur langsung dari mockup SHOP/INVENTORY UI Details.
]]

local TweenService = game:GetService("TweenService")

local ShopUIHelper = {}

local HOVER_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function ShopUIHelper.bindBounce(target: GuiObject, hoverScale: number?, pressScale: number?)
	if target:GetAttribute("_BounceBound") then
		return
	end
	target:SetAttribute("_BounceBound", true)

	local scaleObj = target:FindFirstChildOfClass("UIScale")
	if not scaleObj then
		scaleObj = Instance.new("UIScale")
		scaleObj.Parent = target
	end
	scaleObj.Scale = 1

	local hover = hoverScale or 1.05
	local press = pressScale or 0.94
	local isHovering = false

	target.MouseEnter:Connect(function()
		isHovering = true
		TweenService:Create(scaleObj, HOVER_TWEEN, { Scale = hover }):Play()
	end)

	target.MouseLeave:Connect(function()
		isHovering = false
		TweenService:Create(scaleObj, HOVER_TWEEN, { Scale = 1 }):Play()
	end)

	if target:IsA("GuiButton") then
		target.MouseButton1Down:Connect(function()
			TweenService:Create(scaleObj, PRESS_TWEEN, { Scale = press }):Play()
		end)
		target.MouseButton1Up:Connect(function()
			TweenService:Create(scaleObj, HOVER_TWEEN, { Scale = if isHovering then hover else 1 }):Play()
		end)
	end
end

function ShopUIHelper.bindResponsiveGrid(gridFrame: Frame, aspectRatio: number?)
	local gridLayout = gridFrame:FindFirstChildOfClass("UIGridLayout")
	if not gridLayout then
		return function() end
	end

	local ratio = aspectRatio or 1.0

	local function refresh()
		local width = gridFrame.AbsoluteSize.X
		if width <= 0 then
			return
		end

		-- Inset ~3.11% kiri-kanan (29px dari 932px lebar Banner) agar tepi card sejajar 1:1
		-- dengan pengukuran langsung FullShop.png & FullInventory.png.
		local inset = math.max(8, math.floor(width * 0.0311 + 0.5))
		local pad = gridFrame:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, inset)
			pad.PaddingRight = UDim.new(0, inset)
		end

		local innerWidth = math.max(200, width - inset * 2)
		local columns = if width < 400 then 3 else 4
		-- Gap 30px dari innerWidth 874px (~3.43%) -> menghasilkan 4 card tepat 196x196px.
		local gap = math.max(10, math.floor(innerWidth * 0.0343 + 0.5))
		local cellW = math.max(76, math.floor((innerWidth - gap * (columns - 1)) / columns))
		local cellH = math.floor(cellW / ratio)

		gridLayout.CellPadding = UDim2.fromOffset(gap, gap)
		gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)

		local contentY = gridLayout.AbsoluteContentSize.Y
		gridFrame.Size = UDim2.new(1, 0, 0, math.max(contentY + 28, cellH))
	end

	gridFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
	task.defer(refresh)

	return refresh
end

function ShopUIHelper.applyPillowIcon(iconImage: ImageLabel?, iconId: string?, fallbackLabel: TextLabel?)
	local hasValidIcon = type(iconId) == "string" and iconId ~= "" and iconId ~= "rbxassetid://0"
	if iconImage then
		iconImage.Image = if hasValidIcon then iconId :: string else ""
		iconImage.Visible = hasValidIcon
	end
	if fallbackLabel then
		fallbackLabel.Visible = not hasValidIcon
	end
end

return ShopUIHelper
