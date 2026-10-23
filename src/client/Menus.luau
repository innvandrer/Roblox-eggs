--!strict
-- Owns the centered menu panels; only one is open at a time.

local Ui = require(script.Parent.Ui)

local Menus = {}

type Panel = {
	Frame: Frame,
	OnOpen: (() -> ())?,
}

local panels: { [string]: Panel } = {}
local openName: string? = nil

-- Returns the panel frame and the content frame below its title bar.
function Menus.createPanel(screen: ScreenGui, name: string, title: string, onOpen: (() -> ())?): (Frame, Frame)
	local frame = Ui.new("Frame", {
		Name = name .. "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.5, 0.62),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	}, {
		Ui.corner(14),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(360, 300), MaxSize = Vector2.new(720, 560) }),
		Ui.new("UIStroke", { Color = Color3.fromRGB(80, 85, 110), Thickness = 2 }),
	})

	Ui.label({
		Text = title,
		Size = UDim2.new(1, -70, 0, 40),
		Position = UDim2.fromOffset(16, 8),
		MaxTextSize = 30,
		Parent = frame,
	})
	Ui.button({
		Text = "X",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -46, 0, 10),
		BackgroundColor3 = Ui.Colors.Red,
		MaxTextSize = 22,
		Parent = frame,
	}, function()
		Menus.close()
	end)

	local body = Ui.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 1, -70),
		Parent = frame,
	})

	panels[name] = { Frame = frame, OnOpen = onOpen }
	return frame, body
end

function Menus.open(name: string)
	for panelName, panel in panels do
		panel.Frame.Visible = panelName == name
	end
	openName = name
	local panel = panels[name]
	if panel and panel.OnOpen then
		panel.OnOpen()
	end
end

function Menus.close()
	for _, panel in panels do
		panel.Frame.Visible = false
	end
	openName = nil
end

function Menus.toggle(name: string)
	if openName == name then
		Menus.close()
	else
		Menus.open(name)
	end
end

function Menus.isOpen(name: string): boolean
	return openName == name
end

return Menus
