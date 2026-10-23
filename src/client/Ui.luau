--!strict
-- Tiny helpers for building UI in code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Colors = {
	Panel = Color3.fromRGB(28, 30, 40),
	Row = Color3.fromRGB(44, 47, 62),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(160, 165, 185),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(70, 190, 100),
	Blue = Color3.fromRGB(70, 130, 230),
	Purple = Color3.fromRGB(150, 90, 230),
	Red = Color3.fromRGB(210, 70, 70),
	Grey = Color3.fromRGB(90, 92, 105),
}

function Ui.new(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.padding(px: number): UIPadding
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 20, Parent = label })
	return label
end

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults: { [string]: any } = {
		BackgroundColor3 = Ui.Colors.Blue,
		Font = Ui.Font,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local button = Ui.new("TextButton", defaults, {
		Ui.corner(6),
		Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 18 }),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	button.Activated:Connect(onClick)
	return button
end

function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

function Ui.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function Ui.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return `{seconds}s`
end

function Ui.rarityColor(rarity: string): Color3
	local egg = Config.Eggs[rarity]
	return if egg then egg.Color else Ui.Colors.Text
end

-- A scrollable list that grows with its content.
function Ui.list(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	local list = Ui.new("ScrollingFrame", defaults)
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Ui.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = list })
	return list
end

function Ui.row(parent: Instance, height: number, order: number): Frame
	return Ui.new("Frame", {
		BackgroundColor3 = Ui.Colors.Row,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(8) })
end

function Ui.progressBar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local back = Ui.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BorderSizePixel = 0,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = parent,
	}, { Ui.corner(6) })
	local fill = Ui.new("Frame", {
		BackgroundColor3 = props.Color or Ui.Colors.Green,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = back,
	}, { Ui.corner(6) })
	return back, fill
end

return Ui
