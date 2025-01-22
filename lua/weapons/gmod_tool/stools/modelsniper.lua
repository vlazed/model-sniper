TOOL.Category = "Construction"
TOOL.Name = "#tool.modelsniper.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["allowduplicates"] = 0
TOOL.ClientConVar["searchradius"] = 30

local models = ""
---Spawn model(s) from the model set
---@param tr table|TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	if CLIENT then
		return true
	end

	local modelList = string.Split(models, "\n")
	for _, model in ipairs(modelList) do
		CCSpawn(self:GetOwner(), nil, { model }) ---@diagnostic disable-line
	end

	return true
end

---Append the selected entity's model to the model set. Alternatively, get all models in a radius and append to the model set
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	if CLIENT then
		return true
	end

	if IsValid(tr.Entity) then
		net.Start("modelsniper_append", false)
		net.WriteEntity(tr.Entity)
		net.Send(self:GetOwner())
	elseif tr.HitWorld then
		net.Start("modelsniper_appendradius", false)
		net.Send(self:GetOwner())
	end

	return true
end

if SERVER then
	net.Receive("modelsniper_send", function(len, ply)
		models = util.Decompress(net.ReadData(len / 8))
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
