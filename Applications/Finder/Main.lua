
local GUI = require("GUI")
local buffer = require("doubleBuffering")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")
local MineOSPaths = require("MineOSPaths")
local MineOSCore = require("MineOSCore")
local MineOSNetwork = require("MineOSNetwork")
local MineOSInterface = require("MineOSInterface")

local args, options = require("shell").parse(...)

------------------------------------------------------------------------------------------------------

local mainContainer, window = MineOSInterface.addWindow(MineOSInterface.filledWindow(1, 1, 88, 26, 0xF0F0F0))

local iconFieldYOffset = 2
local scrollTimerID

local favourites = {
	{text = "Root", path = "/"},
	{text = "Desktop", path = MineOSPaths.desktop},
	{text = "Applications", path = MineOSPaths.applications},
	{text = "Pictures", path = MineOSPaths.pictures},
	{text = "System", path = MineOSPaths.system},
	{text = "Trash", path = MineOSPaths.trash},
}
local resourcesPath = MineOSCore.getCurrentScriptDirectory()
local favouritesPath = MineOSPaths.applicationData .. "Finder/Favourites.cfg"

local function saveFavourites()
	table.toFile(favouritesPath, favourites)
end

if fs.exists(favouritesPath) then
	favourites = table.fromFile(favouritesPath)
else
	saveFavourites()
end

------------------------------------------------------------------------------------------------------

local workpathHistory = {}
local workpathHistoryCurrent = 0

local function updateFileListAndDraw()
	window.iconField:updateFileList()
	mainContainer:draw()
	buffer.draw()
end

local function workpathHistoryButtonsUpdate()
	window.prevButton.disabled = workpathHistoryCurrent <= 1
	window.nextButton.disabled = workpathHistoryCurrent >= #workpathHistory
end

local function addWorkpath(path)
	workpathHistoryCurrent = workpathHistoryCurrent + 1
	table.insert(workpathHistory, workpathHistoryCurrent, path)
	for i = workpathHistoryCurrent + 1, #workpathHistory do
		workpathHistory[i] = nil
	end

	workpathHistoryButtonsUpdate()
	window.searchInput.text = ""
	window.iconField.yOffset = iconFieldYOffset
	window.iconField:setWorkpath(path)
end

local function prevOrNextWorkpath(next)
	if next then
		if workpathHistoryCurrent < #workpathHistory then
			workpathHistoryCurrent = workpathHistoryCurrent + 1
		end
	else
		if workpathHistoryCurrent > 1 then
			workpathHistoryCurrent = workpathHistoryCurrent - 1
		end
	end

	workpathHistoryButtonsUpdate()
	window.iconField.yOffset = iconFieldYOffset
	window.iconField:setWorkpath(workpathHistory[workpathHistoryCurrent])
	
	updateFileListAndDraw()
end

------------------------------------------------------------------------------------------------------

local function newSidebarItem(textColor, text, path)
	local object = window.sidebarContainer.itemsContainer:addChild(
		GUI.object(
			1,
			#window.sidebarContainer.itemsContainer.children > 0 and window.sidebarContainer.itemsContainer.children[#window.sidebarContainer.itemsContainer.children].localY + 1 or 1,
			1,
			1
		)
	)
	
	if text then
		object.text = text
		object.textColor = textColor
		object.path = path

		object.draw = function(object)
			object.width = window.sidebarContainer.itemsContainer.width

			if object.path == window.iconField.workpath then
				buffer.square(object.x, object.y, object.width, 1, 0x3366CC, 0xFFFFFF, " ")
				buffer.text(object.x + 1, object.y, 0xFFFFFF, string.limit(object.text, object.width - 4, "center"))
				buffer.text(object.x + object.width - 2, object.y, 0xCCFFFF, "x")
			else
				buffer.text(object.x + 1, object.y, object.textColor, string.limit(object.text, object.width - 2, "center"))
			end
			
		end

		object.eventHandler = function(mainContainer, object, eventData)
			if eventData[1] == "touch" then
				if eventData[3] == object.x + object.width - 2 and object.favouriteIndex then
					table.remove(favourites, object.favouriteIndex)
					saveFavourites()

					computer.pushSignal("Finder", "updateFavourites")
				elseif fs.isDirectory(object.path) then
					addWorkpath(object.path)

					mainContainer:draw()
					buffer.draw()
					
					updateFileListAndDraw()
				end
			end
		end
	end

	return object
end

local function updateSidebar()
	window.sidebarContainer.itemsContainer:deleteChildren()
	
	window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x3C3C3C, MineOSCore.localization.favourite))
	for i = 1, #favourites do
		local object = window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x555555, " " .. fs.name(favourites[i].text), favourites[i].path))
		object.favouriteIndex = i
	end

	if MineOSCore.properties.network.enabled and MineOSNetwork.getProxyCount() > 0 then
		window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x3C3C3C))
		window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x3C3C3C, MineOSCore.localization.network))

		for proxy, path in fs.mounts() do
			if proxy.network then
				window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x555555, " " .. MineOSNetwork.getProxyName(proxy), path .. "/"))
			end
		end
	end

	window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x3C3C3C))

	window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x3C3C3C, MineOSCore.localization.mounts))
	for proxy, path in fs.mounts() do
		if path ~= "/" and not proxy.network then
			window.sidebarContainer.itemsContainer:addChild(newSidebarItem(0x555555, " " .. (proxy.getLabel() or fs.name(path)), path .. "/"))
		end
	end
end

window.titlePanel = window:addChild(GUI.panel(1, 1, 1, 3, 0xE1E1E1))

window.prevButton = window:addChild(GUI.adaptiveRoundedButton(9, 2, 1, 0, 0xFFFFFF, 0x3C3C3C, 0x3C3C3C, 0xFFFFFF, "<"))
window.prevButton.onTouch = function()
	prevOrNextWorkpath(false)
end
window.prevButton.colors.disabled.background = window.prevButton.colors.default.background
window.prevButton.colors.disabled.text = 0xC3C3C3

window.nextButton = window:addChild(GUI.adaptiveRoundedButton(14, 2, 1, 0, 0xFFFFFF, 0x3C3C3C, 0x3C3C3C, 0xFFFFFF, ">"))
window.nextButton.onTouch = function()
	prevOrNextWorkpath(true)
end
window.nextButton.colors.disabled = window.prevButton.colors.disabled

window.sidebarContainer = window:addChild(GUI.container(1, 4, 20, 1))
window.sidebarContainer.panel = window.sidebarContainer:addChild(GUI.panel(1, 1, window.sidebarContainer.width, 1, 0xFFFFFF, MineOSCore.properties.transparencyEnabled and 0.24))
window.sidebarContainer.itemsContainer = window.sidebarContainer:addChild(GUI.container(1, 1, window.sidebarContainer.width, 1))

window.iconField = window:addChild(
	MineOSInterface.iconField(
		1, 4, 1, 1, 2, 2, 0x3C3C3C, 0x3C3C3C,
		MineOSPaths.desktop
	)
)

local function updateScrollBar()
	local shownFilesCount = #window.iconField.fileList - window.iconField.fromFile + 1
	
	local horizontalLines = math.ceil(shownFilesCount / window.iconField.iconCount.horizontal)
	local minimumOffset = 3 - (horizontalLines - 1) * (MineOSCore.properties.iconHeight + MineOSCore.properties.iconVerticalSpaceBetween) - MineOSCore.properties.iconVerticalSpaceBetween
	
	if window.iconField.yOffset > iconFieldYOffset then
		window.iconField.yOffset = iconFieldYOffset
	elseif window.iconField.yOffset < minimumOffset then
		window.iconField.yOffset = minimumOffset
	end

	if shownFilesCount > window.iconField.iconCount.total then
		window.scrollBar.hidden = false
		window.scrollBar.maximumValue = math.abs(minimumOffset)
		window.scrollBar.value = math.abs(window.iconField.yOffset - iconFieldYOffset)
	else
		window.scrollBar.hidden = true
	end
end

window.iconField.eventHandler = function(mainContainer, object, eventData)
	if eventData[1] == "scroll" then
		window.iconField.yOffset = window.iconField.yOffset + eventData[5] * 2

		updateScrollBar()

		local delta = window.iconField.yOffset - window.iconField.iconsContainer.children[1].localY
		for i = 1, #window.iconField.iconsContainer.children do
			window.iconField.iconsContainer.children[i].localY = window.iconField.iconsContainer.children[i].localY + delta
		end

		mainContainer:draw()
		buffer.draw()

		if scrollTimerID then
			event.cancel(scrollTimerID)
			scrollTimerID = nil
		end

	scrollTimerID = event.timer(0.3, function()
		computer.pushSignal("Finder", "updateFileList")
	end, 1)
	elseif eventData[1] == "MineOSCore" or eventData[1] == "Finder" then
		if eventData[2] == "updateFileList" then
			window.iconField.yOffset = iconFieldYOffset
			updateFileListAndDraw()
		elseif eventData[2] == "updateFavourites" then
			if eventData[3] then
				table.insert(favourites, eventData[3])
			end
			saveFavourites()
			updateSidebar()

			mainContainer:draw()
			buffer.draw()
		end	
	end
end

window.iconField.launchers.directory = function(icon)
	addWorkpath(icon.path)
	updateFileListAndDraw()
end

window.iconField.launchers.showPackageContent = function(icon)
	addWorkpath(icon.path)
	updateFileListAndDraw()
end

window.iconField.launchers.showContainingFolder = function(icon)
	addWorkpath(fs.path(MineOSCore.readShortcut(icon.path)))
	updateFileListAndDraw()
end

window.scrollBar = window:addChild(GUI.scrollBar(1, 4, 1, 1, 0xC3C3C3, 0x444444, iconFieldYOffset, 1, 1, 1, 1, true))

window.searchInput = window:addChild(GUI.input(1, 2, 36, 1, 0xFFFFFF, 0x696969, 0xA5A5A5, 0xFFFFFF, 0x2D2D2D, nil, MineOSCore.localization.search, true))
window.searchInput.onInputFinished = function()
	window.iconField.filenameMatcher = window.searchInput.text
	window.iconField.fromFile = 1
	window.iconField.yOffset = iconFieldYOffset

	updateFileListAndDraw()
end

local overrideUpdateFileList = window.iconField.updateFileList
window.iconField.updateFileList = function(...)
	overrideUpdateFileList(...)
	updateScrollBar()
end

window.statusBar = window:addChild(GUI.object(1, 1, 1, 1))
window.statusBar.draw = function(object)
	buffer.square(object.x, object.y, object.width, object.height, 0xFFFFFF, 0x3C3C3C, " ")
	buffer.text(object.x + 1, object.y, 0x3C3C3C, string.limit(("root/" .. window.iconField.workpath):gsub("/+$", ""):gsub("%/+", " ► "), object.width - 1, "start"))
end
window.statusBar.eventHandler = function(mainContainer, object, eventData)
	if (eventData[1] == "component_added" or eventData[1] == "component_removed") and eventData[3] == "filesystem" then
		updateSidebar()

		mainContainer:draw()
		buffer.draw()
	elseif eventData[1] == "MineOSNetwork" then
		if eventData[2] == "updateProxyList" or eventData[2] == "timeout" then
			updateSidebar()

			mainContainer:draw()
			buffer.draw()
		end
	end
end
window.sidebarResizer = window:addChild(GUI.resizer(1, 4, 3, 5, 0xFFFFFF, 0x0))

local function calculateSizes(width, height)
	window.sidebarContainer.height = height - 3
	
	window.sidebarContainer.panel.width = window.sidebarContainer.width
	window.sidebarContainer.panel.height = window.sidebarContainer.height
	
	window.sidebarContainer.itemsContainer.width = window.sidebarContainer.width
	window.sidebarContainer.itemsContainer.height = window.sidebarContainer.height

	window.sidebarResizer.localX = window.sidebarContainer.width - 1
	window.sidebarResizer.localY = math.floor(window.sidebarContainer.localY + window.sidebarContainer.height / 2 - window.sidebarResizer.height / 2 - 1)

	window.backgroundPanel.width = width - window.sidebarContainer.width
	window.backgroundPanel.height = height - 4
	window.backgroundPanel.localX = window.sidebarContainer.width + 1
	window.backgroundPanel.localY = 4

	window.statusBar.localX = window.sidebarContainer.width + 1
	window.statusBar.localY = height
	window.statusBar.width = window.backgroundPanel.width

	window.titlePanel.width = width
	window.searchInput.width = math.floor(width * 0.25)
	window.searchInput.localX = width - window.searchInput.width - 1

	window.iconField.width = window.backgroundPanel.width
	window.iconField.height = height + 4
	window.iconField.localX = window.backgroundPanel.localX

	window.scrollBar.localX = window.width
	window.scrollBar.height = window.backgroundPanel.height
	window.scrollBar.shownValueCount = window.scrollBar.height - 1
	
	window.actionButtons:moveToFront()
end

window.onResize = function(width, height)
	calculateSizes(width, height)
	window.iconField:updateFileList()
end

window.sidebarResizer.onResize = function(mainContainer, object, eventData, dragWidth, dragHeight)
	window.sidebarContainer.width = window.sidebarContainer.width + dragWidth
	window.sidebarContainer.width = window.sidebarContainer.width >= 5 and window.sidebarContainer.width or 5
	calculateSizes(window.width, window.height)
end

window.sidebarResizer.onResizeFinished = function()
	window.iconField:updateFileList()
end

local overrideMaximize = window.actionButtons.maximize.onTouch
window.actionButtons.maximize.onTouch = function()
	window.iconField.yOffset = iconFieldYOffset
	overrideMaximize()
end

window.actionButtons.close.onTouch = function()
	window:close()
end

------------------------------------------------------------------------------------------------------

if options.o and args[1] and fs.isDirectory(args[1]) then
	addWorkpath(args[1])
else
	addWorkpath("/")
end

updateSidebar()
window:resize(window.width, window.height)

