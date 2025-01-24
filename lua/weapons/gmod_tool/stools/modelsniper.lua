TOOL.Category = "Construction"
TOOL.Name = "#tool.modelsniper.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ServerConVar["maxspawns"] = 16

TOOL.ClientConVar["searchradius"] = 30
TOOL.ClientConVar["filterragdolls"] = 0
TOOL.ClientConVar["filterprops"] = 0
TOOL.ClientConVar["filterplayers"] = 0

TOOL.ClientConVar["spawnradius"] = 4
TOOL.ClientConVar["spawnshape"] = "Circle"

local shouldRebuild = true
function TOOL:Think()
	if CLIENT and shouldRebuild then
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

---@module "modelsniper.client.ui"
local ui = include("modelsniper/client/ui.lua")

---@param cPanel ControlPanel|DForm
function TOOL.BuildCPanel(cPanel)
	local panelChildren = ui.ConstructPanel(cPanel, {}, {})
	ui.HookPanel(panelChildren, {}, {})
end

TOOL.Information = {
	{ name = "info" },
	{ name = "left" },
	{ name = "right" },
}
