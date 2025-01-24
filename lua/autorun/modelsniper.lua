-- From Ragdoll Mover (https://github.com/Winded/RagdollMover/blob/7c9dcde28b64ee3306237b2c61525d2ade796a6d/lua/autorun/ragdollmover_meta.lua#L37)
local shouldCallHook = false
hook.Add("EntityKeyValue", "modelsniper_allowtool", function(ent, key, val)
	if key == "gmod_allowtools" and not string.find(val, "modelsniper") then
		shouldCallHook = true
	end

	-- We can't call the hook at the same time the key is gmod_allowtools because ent.m_tblToolsAllowed
	-- must exist (which relies on the gmod_allowtools key), but it doesn't yet
	if shouldCallHook and key ~= "gmod_allowtools" then
		hook.Run("modelsniper_allowtool", ent)
		shouldCallHook = false
	end
end)

-- Some brush entities only allow a select number of tools (see https://wiki.facepunch.com/gmod/Sandbox_Specific_Mapping)
hook.Add("modelsniper_allowtool", "modelsniper_allowtool", function(ent)
	-- If the table is not filled, we don't want to insert it, as it would make other tools not work
	if istable(ent.m_tblToolsAllowed) and #ent.m_tblToolsAllowed > 0 then
		table.insert(ent.m_tblToolsAllowed, "modelsniper")
	end
end)

if SERVER then
	-- resource.AddWorkshop("")

	AddCSLuaFile("modelsniper/shared/shapes.lua")
	AddCSLuaFile("modelsniper/shared/helpers.lua")
	AddCSLuaFile("modelsniper/client/ui.lua")

	include("modelsniper/server/net.lua")
end
