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

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@return table
function ui.ConstructPanel(cPanel, panelProps)
	local modelCategory = makeCategory(cPanel, "Model Set", "DForm")
	modelCategory:Help(
		"Input the model paths to spawn with this toolgun. Ensure model paths are separated line by line"
	)

	local modelList = vgui.Create("DTextEntry", cPanel)
	modelCategory:AddItem(modelList)

	modelList:SetPlaceholderText("Example: kleiner.mdl or models/kleiner.mdl")
	modelList:Dock(TOP)
	modelList:SizeTo(-1, 250, 0)
	modelList:StretchToParent(0, 0, 0, 0)
	modelList:SetMultiline(true)
	modelList:SetAllowNonAsciiCharacters(true)
	modelList:SetEnterAllowed(false)

	local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()

	local modelCount = modelCategory:Help("Model Count: 0" .. " < " .. maxSpawns)
	local clearList = modelCategory:Button("Clear list", "")

	modelCategory:Help(
		"Valid models are shown here as icons. You can also click here to spawn props as you would with the spawnmenu."
	)

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

	local filters = makeCategory(settings, "Filters", "DForm")
	local filterRagdolls = filters:CheckBox("Ragdolls", "modelsniper_filterragdolls")
	filterRagdolls:SetTooltip("Disallow ragdolls from list appending or model spawning")
	local filterProps = filters:CheckBox("Props", "modelsniper_filterprops")
	filterProps:SetTooltip("Disallow effect or physics props from list appending or model spawning")
	local filterPlayers = filters:CheckBox("Players", "modelsniper_filterplayers")
	filterPlayers:SetTooltip("Disallow players and its descendants (weapons, PAC3 items) from list appending")
	local filterDuplicates = filters:CheckBox("Duplicates", "modelsniper_filterduplicates")
	filterDuplicates:SetTooltip(
		"If unchecked, duplicate models in the list can be appended to and spawned, rather than just one of them"
	)

	local spawning = makeCategory(settings, "Spawning", "DForm")
	local spawnShape = spawning:ComboBox("Spawn Shape", "modelsniper_spawnshape")
	---@cast spawnShape DComboBox
	for shapeName, _ in pairs(shapes.toInt) do
		spawnShape:AddChoice(string.NiceName(shapeName), shapeName)
	end
	local option = GetConVar("modelsniper_spawnshape"):GetString()
	spawnShape:ChooseOption(string.NiceName(option), shapes.toInt[string.lower(option)] + 1)
	spawnShape:Dock(TOP)
	local spawnRadius = spawning:NumSlider("Spawn Radius", "modelsniper_spawnradius", 32, 256)
	spawnRadius:Dock(TOP)
	local visualizeSpawn = spawning:CheckBox("Visualize spawn", "")
	visualizeSpawn:Dock(TOP)

	local searching = makeCategory(settings, "Searching", "DForm")
	local visualizeSearch = searching:CheckBox("Visualize search", "")
	local searchRadius = searching:NumSlider("Search Radius", "modelsniper_searchradius", 0.01, 400)

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
		net.WriteUInt(shapes.toInt[string.lower(spawnShape:GetSelected())], math.log(shapes.count + 1, 2))
		net.SendToServer()
	end

	local function updateCount()
		local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()
		local value = count > maxSpawns and count .. "!" or count
		modelCount:SetText("Model Count: " .. value .. " <= " .. maxSpawns)
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
