if SERVER then
	-- resource.AddWorkshop("")

	AddCSLuaFile("modelsniper/shared/helpers.lua")
	AddCSLuaFile("modelsniper/client/ui.lua")

	include("modelsniper/server/net.lua")
end
