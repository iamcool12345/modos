local MineOSInterface = require("MineOSInterface")
local GUI = require("GUI")
local event = require("event")
local component = require("component")
local computer = require("computer")

---------------------------------------------------------------------------------------------------------

local world
if component.isAvailable("debug") then
	world = component.debug.getWorld()
else
	GUI.alert("This program requires debug card to run")
	return
end

local container = MineOSInterface.addBackgroundContainer(MineOSInterface.mainContainer, "Fuck The Rain")

local lines = string.wrap("This script works as background daemon and checks rain condition in specified interval", 36)
container.layout:addChild(GUI.textBox(1, 1, 36, #lines, nil, 0xA5A5A5, lines, 1, 0, 0))

local daemonSwitch = container.layout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0x2D2D2D, 0xE1E1E1, 0x696969, "Daemon enabled:", _G.fuckTheRainTimerID and true or false)).switch
local signalSwitch = container.layout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0x2D2D2D, 0xE1E1E1, 0x696969, "Sound signal:", _G.fuckTheRainSignal)).switch

local intervalSlider = container.layout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0x2D2D2D, 0xE1E1E1, 0x696969, 1, 10, 2, false, "Interval: ", " s"))
intervalSlider.roundValues = true
intervalSlider.height = 2

container.layout:addChild(GUI.button(1, 1, 36, 3, 0x444444, 0xFFFFFF, 0x2D2D2D, 0xFFFFFF, "OK")).onTouch = function()
	_G.fuckTheRainSignal = signalSwitch.state and true or nil

	if daemonSwitch.state then
		if not _G.fuckTheRainTimerID then
			_G.fuckTheRainTimerID = event.timer(intervalSlider.value, function()
				if world.isRaining() or world.isThundering() then
					world.setThundering(false)
					world.setRaining(false)

					if _G.fuckTheRainSignal then
						computer.beep(1500)
					end
				end
			end, math.huge)
		end
	else
		if _G.fuckTheRainTimerID then
			event.cancel(_G.fuckTheRainTimerID)
			_G.fuckTheRainTimerID = nil
		end
	end

	container:remove()
	MineOSInterface.mainContainer:drawOnScreen()
end











