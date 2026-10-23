--!strict
local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Net = require(script.Parent.Net)
local Notifications = require(script.Parent.Notifications)
local PetsMenu = require(script.Parent.PetsMenu)
local PlotMenu = require(script.Parent.PlotMenu)
local ShopMenu = require(script.Parent.ShopMenu)
local World = require(script.Parent.World)

local screen = Instance.new("ScreenGui")
screen.Name = "GameUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Notifications.create(screen)
Hud.create(screen)
ShopMenu.create(screen)
PetsMenu.create(screen)
PlotMenu.create(screen)
Effects.init()
World.init()
Combat.init()

Net.Notify:Connect(function(text: string, kind: string?)
	if type(text) == "string" then
		Notifications.toast(text, kind)
	end
end)

Notifications.toast("Defeat monsters in Slime Meadow (east) to earn coins, XP and eggs!", "info")
