---@module "modelsniper.shared.helpers"
local helpers = include("modelsniper/shared/helpers.lua")

---@module "modelsniper.shared.shapes"
local shapes = include("modelsniper/shared/shapes.lua")

local MODELS_PREFIX = "models/"
local ENTITY_FILTER = {
	proxyent_tf2itempaint = true,
	proxyent_tf2critglow = true,
	proxyent_tf2cloakeffect = true,
}

local getPhrase = language.GetPhrase
local getAncestor = helpers.getAncestor

local ui = {}
ui.MAX_SELECTION_ALPHA = 64

local MAX_SELECTION_ALPHA = ui.MAX_SELECTION_ALPHA

local function getBoolOrFloatConVar(convar, isBool)
	return GetConVar(convar) and Either(isBool, GetConVar(convar):GetBool(), GetConVar(convar):GetFloat())
end

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

local contentPanel
hook.Remove("PopulateContent", "modelsniper_modeldirectory")
hook.Add("PopulateContent", "modelsniper_modeldirectory", function(pnlContent)
	-- Anytime this is called, set the content panel so that we can access it outside of the hook
	contentPanel = pnlContent
end)

-- Holds ContentContainers for specific directories so they don't get recreated
-- TODO: It would be nice if we could directly point to an existing view panel, so that
-- we don't have to create a content container
local folderContents = {}

---@param model string
local function viewModelFolder(model)
	if not contentPanel then
		return
	end
	local modelDirectory = string.Split(model, "/")
	modelDirectory[#modelDirectory] = "*.mdl"
	local modelSearch = table.concat(modelDirectory, "/")
	modelDirectory[#modelDirectory] = ""
	local folder = table.concat(modelDirectory, "/") .. "/"
	local models = file.Find("models/" .. modelSearch, "GAME")

	if models and #models > 1 then
		local propPanel = folderContents[folder]
		if not propPanel then
			propPanel = vgui.Create("ContentContainer", contentPanel)
			for _, prop in ipairs(models) do
				local cp = spawnmenu.GetContentType("model")
				---INFO: Prop panel is a Panel class
				---@diagnostic disable-next-line: param-type-mismatch
				cp(propPanel, { model = "models/" .. folder .. "/" .. prop })
			end
			folderContents[folder] = propPanel
		end
		propPanel:SetVisible(false)
		propPanel:SetTriggerSpawnlistChange(true)

		contentPanel:SwitchPanel(propPanel)
	end
end

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@return table
function ui.ConstructPanel(cPanel, panelProps)
	local modelCategory = makeCategory(cPanel, "#ui.modelsniper.model", "DForm")
	modelCategory:Help("#ui.modelsniper.model.list")
	modelCategory:Help("#ui.modelsniper.model.shortcuts")

	local modelList = vgui.Create("DTextEntry", cPanel)
	modelCategory:AddItem(modelList)

	modelList:SetPlaceholderText("#ui.modelsniper.model.example")
	modelList:Dock(TOP)
	modelList:SizeTo(-1, 250, 0)
	modelList:StretchToParent(0, 0, 0, 0)
	modelList:SetMultiline(true)
	modelList:SetAllowNonAsciiCharacters(true)
	modelList:SetEnterAllowed(false)
	modelList:SetUpdateOnType(true)

	local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()

	local modelCount = modelCategory:Help(getPhrase("ui.modelsniper.model.count") .. "0" .. " <= " .. maxSpawns)
	local clearList = modelCategory:Button("#ui.modelsniper.model.clear", "")

	modelCategory:Help("#ui.modelsniper.model.icons")

	local modelGalleryScroll = vgui.Create("DScrollPanel", modelCategory)
	modelGalleryScroll:Dock(TOP)
	modelGalleryScroll:DockMargin(10, 10, 10, 10)
	modelGalleryScroll:SizeTo(-1, 250, 0)
	function modelGalleryScroll:Paint(w, h)
		derma.SkinHook("Paint", "Tree", self, w, h)
		return true
	end
	modelGalleryScroll:SetPaintBackgroundEnabled(true)
	modelGalleryScroll:SetPaintBorderEnabled(true)
	modelGalleryScroll:SetPaintBackground(true)

	local modelGallery = vgui.Create("DIconLayout", modelGalleryScroll)
	modelGallery:Dock(FILL)
	modelGallery:SetBorder(10)

	local settings = makeCategory(cPanel, "Settings", "DForm")

	local filters = makeCategory(settings, "#ui.modelsniper.filters", "DForm")
	local filterRagdolls = filters:CheckBox("#ui.modelsniper.filters.ragdolls", "modelsniper_filterragdolls")
	filterRagdolls:SetTooltip("#ui.modelsniper.filters.ragdolls.tooltip")
	local filterProps = filters:CheckBox("#ui.modelsniper.filters.props", "modelsniper_filterprops")
	filterProps:SetTooltip("#ui.modelsniper.filters.props.tooltip")
	local filterPlayers = filters:CheckBox("#ui.modelsniper.filters.players", "modelsniper_filterplayers")
	filterPlayers:SetTooltip("#ui.modelsniper.filters.players.tooltip")
	local filterDuplicates = filters:CheckBox("#ui.modelsniper.filters.duplicates", "modelsniper_filterduplicates")
	filterDuplicates:SetTooltip("#ui.modelsniper.filters.duplicates.tooltip")

	local spawning = makeCategory(settings, "#ui.modelsniper.spawn", "DForm")
	local spawnGroup = spawning:CheckBox("#ui.modelsniper.spawn.group", "modelsniper_spawngroup")
	spawnGroup:SetTooltip("#ui.modelsniper.spawn.group.tooltip")
	spawnGroup:Dock(TOP)
	local spawnShape = spawning:ComboBox("#ui.modelsniper.spawn.shape", "modelsniper_spawnshape")
	---@cast spawnShape DComboBox
	for shapeName, _ in pairs(shapes.toInt) do
		spawnShape:AddChoice(string.NiceName(shapeName), shapeName)
	end
	local option = GetConVar("modelsniper_spawnshape"):GetString()
	spawnShape:ChooseOption(string.NiceName(option), shapes.toInt[string.lower(option)] + 1)
	spawnShape:Dock(TOP)
	local spawnRadius = spawning:NumSlider("#ui.modelsniper.spawn.radius", "modelsniper_spawnradius", 32, 256)
	spawnRadius:Dock(TOP)
	local visualizeSpawn = spawning:CheckBox("#ui.modelsniper.spawn.visual", "")
	visualizeSpawn:Dock(TOP)

	local searching = makeCategory(settings, "#ui.modelsniper.search", "DForm")
	local visualizeSearch = searching:CheckBox("#ui.modelsniper.search.visual", "")
	local searchRadius = searching:NumSlider("#ui.modelsniper.search.radius", "modelsniper_searchradius", 0.01, 400)

	return {
		modelList = modelList,
		modelGallery = modelGallery,
		filterDuplicates = filterDuplicates,
		searchRadius = searchRadius,
		visualizeSearch = visualizeSearch,
		visualizeSpawn = visualizeSpawn,
		clearList = clearList,
		filterRagdolls = filterRagdolls,
		filterProps = filterProps,
		filterPlayers = filterPlayers,
		modelCount = modelCount,
		spawnGroup = spawnGroup,
		spawnShape = spawnShape,
		spawnRadius = spawnRadius,
	}
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	local modelList = panelChildren.modelList
	local modelGallery = panelChildren.modelGallery
	local filterDuplicates = panelChildren.filterDuplicates
	local searchRadius = panelChildren.searchRadius
	local visualizeSearch = panelChildren.visualizeSearch
	local visualizeSpawn = panelChildren.visualizeSpawn
	local clearList = panelChildren.clearList
	local filterRagdolls = panelChildren.filterRagdolls
	local filterProps = panelChildren.filterProps
	local filterPlayers = panelChildren.filterPlayers
	local modelCount = panelChildren.modelCount
	local spawnRadius = panelChildren.spawnRadius
	local spawnShape = panelChildren.spawnShape

	panelState.searchRadius = GetConVar("modelsniper_searchradius"):GetFloat()
	panelState.spawnRadius = GetConVar("modelsniper_spawnradius"):GetFloat()

	-- This will be networked when we request to spawn some models
	local models = ""
	local count = 0

	local function sendModels()
		local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()
		if count > maxSpawns then
			return
		end

		local compressed = util.Compress(models)

		net.Start("modelsniper_send")
		net.WriteUInt(#compressed, 16)
		net.WriteData(compressed, #compressed)
		net.WriteBool(filterRagdolls:GetChecked())
		net.WriteBool(filterProps:GetChecked())
		net.WriteFloat(spawnRadius:GetValue())
		net.WriteUInt(shapes.toInt[string.lower(spawnShape:GetSelected())], math.ceil(math.log(shapes.count + 1, 2)))
		net.SendToServer()
	end

	local function updateCount()
		local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()
		local value = count > maxSpawns and count .. "!" or count
		modelCount:SetText(getPhrase("ui.modelsniper.model.count") .. value .. " <= " .. maxSpawns)
	end

	---@param lines string
	local function updateGallery(lines)
		-- Fill this up to ensure that we don't get duplicate icons if we get any
		local modelSet = {}
		local modelArray = {}

		modelGallery:Clear()
		---@type Model[]
		local modelPaths = string.Split(lines, "\n")
		for _, model in ipairs(modelPaths) do
			if string.StartsWith(model, MODELS_PREFIX) then
				model = string.sub(model, #MODELS_PREFIX + 1, #model)
			end

			if not IsUselessModel(model) and (not modelSet[model] or not filterDuplicates:GetChecked()) then
				modelSet[model] = true

				local icon = vgui.Create("SpawnIcon", modelGallery)
				icon:SetModel(MODELS_PREFIX .. model)
				icon:SetSize(50, 50)
				-- Enable spawning from the gallery as we would with the regular spawnmenu
				function icon:DoClick()
					surface.PlaySound("ui/buttonclickrelease.wav")
					RunConsoleCommand("gm_spawn", self:GetModelName(), self:GetSkinID() or 0, self:GetBodyGroup() or "")
				end
				function icon:DoRightClick()
					local menu = DermaMenu()
					menu:AddOption("#ui.modelsniper.icon.copy", function()
						SetClipboardText(MODELS_PREFIX .. model)
					end)
					menu:AddOption("#ui.modelsniper.icon.view", function()
						viewModelFolder(model)
					end)
					menu:Open()
				end

				modelGallery:Add(icon)
				modelGallery:Layout()
				table.insert(modelArray, MODELS_PREFIX .. model)
			end
		end

		-- Forces an update to the panel, allowing icons to render
		modelGallery:GetParent():SizeTo(-1, 250, 0)

		models = table.concat(modelArray, "\n")
		count = #modelArray
		panelState.modelArray = modelArray
		updateCount()
	end

	function spawnShape:OnSelect(index, val, data)
		GetConVar("modelsniper_spawnshape"):SetString(val)
		panelState.spawnShape = val
	end

	function visualizeSearch:OnChange(val)
		panelState.visualizeSearch = val
	end

	function visualizeSpawn:OnChange(val)
		panelState.visualizeSpawn = val
	end

	function spawnRadius:OnValueChanged(newVal)
		panelState.spawnRadius = newVal
	end

	function searchRadius:OnValueChanged(newVal)
		panelState.searchRadius = newVal
	end

	function clearList:DoClick()
		modelList:SetValue("")
	end

	function modelList:OnLoseFocus()
		self:UpdateConvarValue()

		hook.Call("OnTextEntryLoseFocus", nil, self)
		updateGallery(modelList:GetValue())
	end

	local function updateModelList(newText)
		modelList:SetText(newText)
		modelList:OnValueChange(newText)
	end

	function modelList:OnKeyCode(code)
		local textArray = string.Split(self:GetValue(), "\n")
		local oldPos = self:GetCaretPos()
		-- As of 26 January 2025, there isn't an official way to get current selected line. This does it for us
		local _, currentLine = string.gsub(string.Left(self:GetValue(), oldPos), "\n", "")
		currentLine = currentLine + 1
		-- For copying/cutting single lines, we require shift key, so we don't override
		-- old copying behavior
		if input.IsKeyDown(KEY_LCONTROL) and input.IsKeyDown(KEY_LSHIFT) then
			if code == KEY_C or code == KEY_X then
				SetClipboardText(textArray[currentLine] .. "\n")
			end
			if code == KEY_X then
				local linePos = 0
				for i = 1, currentLine - 1 do
					linePos = linePos + #textArray[i] + 1
				end
				table.remove(textArray, currentLine)
				local newText = table.concat(textArray, "\n")
				updateModelList(newText)

				self:SetCaretPos(linePos)
			end
		elseif input.IsKeyDown(KEY_LALT) then
			if code == KEY_UP or code == KEY_DOWN then
				local direction = code == KEY_UP and -1 or 1
				local nextLine = math.Clamp(currentLine + direction, 1, #textArray)
				local temp = textArray[currentLine]
				if input.IsShiftDown() then
					table.insert(textArray, direction < 0 and nextLine + 1 or nextLine, temp)
				else
					textArray[currentLine] = textArray[nextLine]
					textArray[nextLine] = temp
				end

				-- SetText resets the `CaretPos`
				-- Therefore, we attempt to preserve the original caret position with respect to the old line
				-- This isn't the usual way to preserve them, but it gets us that VSCode behavior
				local isLarger = #textArray[currentLine] > #temp
				local caretDisplacement = direction * math.min(#temp, #textArray[currentLine]) + direction
				if isLarger then
					caretDisplacement = caretDisplacement + direction * math.abs(#textArray[currentLine] - #temp)
				end
				local newText = table.concat(textArray, "\n")
				updateModelList(newText)

				if input.IsShiftDown() and direction < 0 then
					caretDisplacement = 0
				end
				self:SetCaretPos(oldPos + caretDisplacement)
			end
		end
		-- print(textArray[currentLine])
	end

	function modelList:OnValueChange(newValue)
		updateGallery(newValue)
	end

	function filterDuplicates:OnChange()
		updateGallery(modelList:GetValue())
	end

	local function appendValueToList(list, value)
		local newValue = list:GetValue() .. "\n" .. value
		list:SetValue(string.Trim(newValue, "\n"))
	end

	net.Receive("modelsniper_request", sendModels)

	net.Receive("modelsniper_append", function()
		local entity = net.ReadEntity()
		if IsValid(entity) and entity.GetModel and not IsUselessModel(entity:GetModel()) then
			local model = entity:GetModel()
			if util.IsValidRagdoll(model) and filterRagdolls:GetChecked() then
				return
			end
			if util.IsValidProp(model) and filterProps:GetChecked() then
				return
			end

			appendValueToList(modelList, entity:GetModel())
		end
	end)

	net.Receive("modelsniper_appendradius", function()
		local trace = LocalPlayer():GetEyeTrace()
		if not trace.HitPos then
			return
		end

		panelState.showSelection = true
		panelState.selectionAlpha = MAX_SELECTION_ALPHA
		panelState.selectionCenter = trace.HitPos

		---@type Entity[]
		local searchResult = ents.FindInSphere(trace.HitPos, searchRadius:GetValue())
		local list = ""
		for _, entity in ipairs(searchResult) do
			if
				IsValid(entity)
				and entity:EntIndex() > 0
				and not ENTITY_FILTER[entity:GetClass()]
				and entity.GetModel
				and entity:GetModel()
				and util.IsValidModel(entity:GetModel())
				and entity:GetModel() ~= "models/error.mdl"
			then
				local model = entity:GetModel()
				local ancestor = getAncestor(entity)
				if filterPlayers:GetChecked() then
					if ancestor:IsPlayer() or ancestor:GetClass() == "viewmodel" then
						continue
					end
				end
				if util.IsValidRagdoll(model) and filterRagdolls:GetChecked() then
					continue
				end
				if util.IsValidProp(model) and filterProps:GetChecked() then
					continue
				end
				if string.find(models, model) and filterDuplicates:GetChecked() then
					continue
				end

				table.insert(
					panelState.selectionBoxes,
					{ entity:GetPos() + entity:OBBCenter(), entity:GetAngles(), entity:OBBMins(), entity:OBBMaxs() }
				)
				list = list .. model .. "\n"
			end
		end

		if #list > 0 then
			appendValueToList(modelList, string.TrimRight(list, "\n"))
		end
	end)
end

return ui
