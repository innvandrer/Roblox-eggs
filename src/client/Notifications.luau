--!strict
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local Notifications = {}

local MAX_TOASTS = 4
local KIND_COLORS = {
	info = Color3.fromRGB(60, 65, 90),
	success = Color3.fromRGB(45, 140, 75),
	error = Color3.fromRGB(170, 55, 55),
	reward = Color3.fromRGB(170, 120, 30),
}

local container: Frame? = nil
local bannerLabel: TextLabel? = nil
local order = 0

function Notifications.create(screen: ScreenGui)
	container = Ui.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(420, 200),
		Parent = screen,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	bannerLabel = Ui.label({
		Name = "Banner",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Colors.Gold,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(0.8, 0, 0, 60),
		MaxTextSize = 48,
		Visible = false,
		Parent = screen,
	})
end

function Notifications.toast(text: string, kind: string?)
	local parent = container
	if not parent then
		return
	end
	order += 1
	local toasts = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts >= MAX_TOASTS do
		local oldest = table.remove(toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local toast = Ui.new("Frame", {
		BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		Size = UDim2.fromOffset(420, 36),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(8) })
	local label = Ui.label({
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		MaxTextSize = 18,
		Parent = toast,
	})

	task.delay(3, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

function Notifications.banner(text: string)
	local label = bannerLabel
	if not label then
		return
	end
	label.Text = text
	label.TextTransparency = 0
	label.Visible = true
	local stamp = os.clock()
	label:SetAttribute("Stamp", stamp)
	task.delay(2.5, function()
		if label:GetAttribute("Stamp") == stamp then
			label.Visible = false
		end
	end)
end

return Notifications
