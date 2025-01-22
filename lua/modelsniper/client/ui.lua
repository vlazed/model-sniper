local MODELS_PREFIX = "models/"
local ENTITY_FILTER = {
	proxyent_tf2itempaint = true,
	proxyent_tf2critglow = true,
	proxyent_tf2cloakeffect = true,
}

local ui = {}

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
---@param panelState PanelState
---@return table
function ui.ConstructPanel(cPanel, panelProps, panelState)
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
	local filterRagdolls = filters:CheckBox("Filter ragdolls", "modelsniper_filterragdolls")
	filterRagdolls:SetTooltip("Disallow ragdolls from list appending or model spawning")
	local filterProps = filters:CheckBox("Filter props", "modelsniper_filterprops")
	filterProps:SetTooltip("Disallow effect or physics props from list appending or model spawning")
	local allowDuplicates = filters:CheckBox("Allow duplicates", "modelsniper_allowduplicates")
	allowDuplicates:SetTooltip("If checked, duplicate models in the list can be spawned, rather than just one of them")

	local visualizeSearch = settings:CheckBox("Visualize search", "")
	local searchRadius = settings:NumSlider("Search Radius", "modelsniper_searchradius", 0.01, 400)

	return {
		modelList = modelList,
		modelGallery = modelGallery,
		allowDuplicates = allowDuplicates,
		searchRadius = searchRadius,
		visualizeSearch = visualizeSearch,
		clearList = clearList,
		filterRagdolls = filterRagdolls,
		filterProps = filterProps,
		modelCount = modelCount,
	}
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	local modelList = panelChildren.modelList
	local modelGallery = panelChildren.modelGallery
	local allowDuplicates = panelChildren.allowDuplicates
	local searchRadius = panelChildren.searchRadius
	local visualizeSearch = panelChildren.visualizeSearch
	local clearList = panelChildren.clearList
	local filterRagdolls = panelChildren.filterRagdolls
	local filterProps = panelChildren.filterProps
	local modelCount = panelChildren.modelCount

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
				model = string.sub(model, #MODELS_PREFIX, #model)
			end

			if not IsUselessModel(model) and (not modelSet[model] or allowDuplicates:GetChecked()) then
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
		updateCount()
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

	function allowDuplicates:OnChange()
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
			then
				local model = entity:GetModel()
				if util.IsValidRagdoll(model) and filterRagdolls:GetChecked() then
					continue
				end
				if util.IsValidProp(model) and filterProps:GetChecked() then
					continue
				end

				list = list .. model .. "\n"
			end
		end

		if #list > 0 then
			appendValueToList(modelList, string.TrimRight(list, "\n"))
		end
	end)

	local radiusColor = Color(255, 0, 0, 64)
	local centerColor = Color(128, 255, 0)
	hook.Remove("PostDrawTranslucentRenderables", "modelsniper_visualizesearch")
	hook.Add("PostDrawTranslucentRenderables", "modelsniper_visualizesearch", function(depth, skybox)
		if not IsValid(visualizeSearch) or not visualizeSearch:GetChecked() then
			return
		end
		if skybox then
			return
		end
		local player = LocalPlayer()
		local weapon = player:GetActiveWeapon()
		---@diagnostic disable-next-line
		if weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "modelsniper" then
			local pos = player:GetEyeTrace().HitPos

			render.SetColorMaterial()
			render.DrawSphere(pos, 1, 10, 10, centerColor)
			render.DrawSphere(pos, searchRadius:GetValue(), 10, 10, radiusColor)
		end
	end)
end

return ui
