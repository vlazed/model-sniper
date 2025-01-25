TOOL.Category = "Construction"
TOOL.Name = "#tool.modelsniper.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ServerConVar["maxspawns"] = 16

TOOL.ClientConVar["searchradius"] = 30
TOOL.ClientConVar["filterduplicates"] = 1
TOOL.ClientConVar["filterragdolls"] = 0
TOOL.ClientConVar["filterprops"] = 0
TOOL.ClientConVar["filterplayers"] = 0

TOOL.ClientConVar["spawnradius"] = 4
TOOL.ClientConVar["spawnshape"] = "Circle"

local shouldRebuild = true
function TOOL:Think()
	if CLIENT and shouldRebuild and IsValid(spawnmenu.ActiveControlPanel()) then
		self:RebuildControlPanel()
		shouldRebuild = false
	end
end

---Spawn model(s) from the model set
---@param tr table|TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	if CLIENT then
		return true
	end

	net.Start("modelsniper_request")
	net.Send(self:GetOwner())

	return true
end

---Append the selected entity's model to the model set. Alternatively, get all models in a radius and append to the model set
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	if CLIENT then
		return true
	end

	local entity = tr.Entity
	if IsValid(entity) and entity:GetBrushPlaneCount() == 0 then
		net.Start("modelsniper_append", false)
		net.WriteEntity(entity)
		net.Send(self:GetOwner())
	elseif tr.HitWorld or entity:GetBrushPlaneCount() > 0 then
		net.Start("modelsniper_appendradius", false)
		net.Send(self:GetOwner())
	end

	return true
end

if SERVER then
	---@module "modelsniper.shared.spawn"
	local spawn = include("modelsniper/shared/spawn.lua")
	---@module "modelsniper.shared.shapes"
	local shapes = include("modelsniper/shared/shapes.lua")

	net.Receive("modelsniper_send", function(_, ply)
		local maxSpawns = GetConVar("modelsniper_maxspawns"):GetInt()

		local len = net.ReadUInt(16)
		local models = util.Decompress(net.ReadData(len))
		local willFilterRagdolls = net.ReadBool()
		local willFilterProps = net.ReadBool()
		local spawnRadius = net.ReadFloat()
		local spawnShapeIndex = net.ReadUInt(math.log(shapes.count + 1, 2))

		local modelList = string.Split(models, "\n")
		local spawns = #modelList
		if spawns > maxSpawns then
			ErrorNoHalt(ply:Nick(), " attempted to spawn more models than the maximum! ", #modelList, " > ", maxSpawns)
			return
		end

		local filter = {}
		for i, model in ipairs(modelList) do
			if not util.IsValidModel(model) then
				continue
			end
			if util.IsValidRagdoll(model) and willFilterRagdolls then
				continue
			end
			if util.IsValidProp(model) and willFilterProps then
				continue
			end

			table.insert(filter, spawn(ply, model, i, spawnRadius, shapes.toShape[spawnShapeIndex], spawns, filter)) ---@diagnostic disable-line
		end
	end)
	return
end

TOOL:BuildConVarList()

---@module "modelsniper.client.ui"
local ui = include("modelsniper/client/ui.lua")
---@module "modelsniper.shared.shapes"
local shapes = include("modelsniper/shared/shapes.lua")

local MAX_SELECTION_ALPHA = ui.MAX_SELECTION_ALPHA

---@type PanelState
local panelState = {
	showSelection = false,
	selectionCenter = vector_origin,
	searchRadius = GetConVar("modelsniper_searchradius") and GetConVar("modelsniper_searchradius"):GetFloat() or 4,
	spawnRadius = GetConVar("modelsniper_spawnradius") and GetConVar("modelsniper_spawnradius"):GetFloat() or 32,
	selectionAlpha = MAX_SELECTION_ALPHA,
	selectionBoxes = {},

	visualizeSpawn = false,
	visualizeSearch = false,

	spawnShape = GetConVar("modelsniper_spawnshape") and GetConVar("modelsniper_spawnshape"):GetString() or "point",
	modelArray = {},
}

---@param cPanel ControlPanel|DForm
function TOOL.BuildCPanel(cPanel)
	local panelChildren = ui.ConstructPanel(cPanel, {})
	ui.HookPanel(panelChildren, {}, panelState)
end

do
	local radiusColor = Color(255, 0, 0, MAX_SELECTION_ALPHA)
	local centerColor = Color(128, 255, 0)
	local pointColor = Color(0, 255, 0)
	local selectionColor = Color(0, 128, 255, panelState.selectionAlpha)
	local whiteColor = Color(255, 255, 255, panelState.selectionAlpha)
	hook.Remove("PostDrawTranslucentRenderables", "modelsniper_visualize")
	hook.Add("PostDrawTranslucentRenderables", "modelsniper_visualize", function(depth, skybox)
		if skybox then
			return
		end

		local player = LocalPlayer()
		---@type TraceResult
		local trace = player:GetEyeTrace()
		render.SetColorMaterial()

		if panelState.showSelection then
			local searchRadius = (1 - math.ease.InExpo(panelState.selectionAlpha / MAX_SELECTION_ALPHA))
				* panelState.searchRadius
			for _, box in ipairs(panelState.selectionBoxes) do
				if panelState.selectionCenter:DistToSqr(box[1]) < searchRadius ^ 2 then
					render.DrawWireframeBox(box[1], box[2], box[3], box[4], whiteColor, true)
				end
			end
			render.DrawSphere(panelState.selectionCenter, searchRadius, 10, 10, selectionColor)
			panelState.selectionAlpha = panelState.selectionAlpha - 0.5
			selectionColor.a = math.ease.InExpo(panelState.selectionAlpha / MAX_SELECTION_ALPHA) * MAX_SELECTION_ALPHA
			whiteColor.a = math.ease.InExpo(panelState.selectionAlpha / MAX_SELECTION_ALPHA) * MAX_SELECTION_ALPHA
			if panelState.selectionAlpha <= 0 then
				panelState.selectionBoxes = {}
				panelState.showSelection = false
			end
		end

		if panelState.visualizeSpawn then
			for i, _ in ipairs(panelState.modelArray) do
				if trace.HitPos then
					local center = trace.HitPos * 1
					local pos = shapes.choose(
						string.lower(panelState.spawnShape),
						#panelState.modelArray,
						center,
						panelState.spawnRadius,
						i,
						player:GetAimVector()
					)
					render.DrawSphere(pos, 1, 5, 5, pointColor)
				end
			end
		end

		if not panelState.visualizeSearch then
			return
		end
		local weapon = player:GetActiveWeapon()
		---@diagnostic disable-next-line
		if weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "modelsniper" then
			local pos = trace.HitPos

			render.DrawSphere(pos, 1, 10, 10, centerColor)
			render.DrawSphere(pos, panelState.searchRadius, 10, 10, radiusColor)
		end
	end)
end

TOOL.Information = {
	{ name = "info" },
	{ name = "left" },
	{ name = "right" },
}
