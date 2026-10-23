--!strict
local Services = script.Parent.Services

local CombatService = require(Services.CombatService)
local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local MonsterService = require(Services.MonsterService)
local PetService = require(Services.PetService)
local PlotService = require(Services.PlotService)
local ShopService = require(Services.ShopService)
local ZoneService = require(Services.ZoneService)

MapService.build()
MonsterService.init()
CombatService.init()
ShopService.init()
PetService.init()
PlotService.init()
ZoneService.init()
-- Last, so every onLoaded hook is registered before the first profile loads.
DataService.init()
