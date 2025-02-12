---Functions taken from https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua
---Lazily constructed to use the shapes module, which explains the tremendous argument count per function

---@module "modelsniper.shared.shapes"
local shapes = include("modelsniper/shared/shapes.lua")

---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L6
---A little hacky function to help prevent spawning props partially inside walls
---Maybe it should use physics object bounds, not OBB, and use physics object bounds to initial position too
---@param ply Player
---@param ent Entity
---@param hitpos Vector
---@param mins Vector
---@param maxs Vector
local function fixupProp(ply, ent, hitpos, mins, maxs)
	local entPos = ent:GetPos()
	local endposD = ent:LocalToWorld(mins)
	local tr_down = util.TraceLine({
		start = entPos,
		endpos = endposD,
		filter = { ent, ply },
	})

	local endposU = ent:LocalToWorld(maxs)
	local tr_up = util.TraceLine({
		start = entPos,
		endpos = endposU,
		filter = { ent, ply },
	})

	-- Both traces hit meaning we are probably inside a wall on both sides, do nothing
	if tr_up.Hit and tr_down.Hit then
		return
	end

	if tr_down.Hit then
		ent:SetPos(entPos + (tr_down.HitPos - endposD))
	end
	if tr_up.Hit then
		ent:SetPos(entPos + (tr_up.HitPos - endposU))
	end
end

---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L29
---@param ply Player
---@param ent Entity
---@param hitpos Vector
local function TryFixPropPosition(ply, ent, hitpos)
	fixupProp(ply, ent, hitpos, Vector(ent:OBBMins().x, 0, 0), Vector(ent:OBBMaxs().x, 0, 0))
	fixupProp(ply, ent, hitpos, Vector(0, ent:OBBMins().y, 0), Vector(0, ent:OBBMaxs().y, 0))
	fixupProp(ply, ent, hitpos, Vector(0, 0, ent:OBBMins().z), Vector(0, 0, ent:OBBMaxs().z))
end

---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L195
---@param prop Entity
local function FixInvalidPhysicsObject(prop)
	local PhysObj = prop:GetPhysicsObject()
	if not IsValid(PhysObj) then
		return
	end

	local min, max = PhysObj:GetAABB()
	if not min or not max then
		return
	end

	local PhysSize = (min - max):Length()
	if PhysSize > 5 then
		return
	end

	local mins = prop:OBBMins()
	local maxs = prop:OBBMaxs()
	if not mins or not maxs then
		return
	end

	local ModelSize = (mins - maxs):Length()
	local Difference = math.abs(ModelSize - PhysSize)
	if Difference < 10 then
		return
	end

	-- This physics object is definitiely weird.
	-- Make a new one.
	prop:PhysicsInitBox(mins, maxs)
	prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	-- Check for success
	PhysObj = prop:GetPhysicsObject()
	if not IsValid(PhysObj) then
		return
	end

	PhysObj:SetMass(100)
	PhysObj:Wake()
end

---@param ply Player
---@param entity_name string
---@param model string
---@param iSkin integer
---@param strBody string?
---@param index integer
---@param radius number
---@param shape "circle"|"square"
---@param count integer
---@param filter Entity[]
---@return Entity
local function DoPlayerEntitySpawn(ply, entity_name, model, iSkin, strBody, index, radius, shape, count, filter)
	local vStart = ply:GetShootPos()
	local vForward = ply:GetAimVector()

	local trace = {}
	trace.start = vStart
	trace.endpos = vStart + (vForward * 2048)
	trace.filter = { ply, unpack(filter) }

	local tr = util.TraceLine(trace)

	local ent = ents.Create(entity_name)
	if not IsValid(ent) then
		return NULL
	end

	local ang = ply:EyeAngles()
	ang.yaw = ang.yaw + 180 -- Rotate it 180 degrees in my favour
	ang.roll = 0
	ang.pitch = 0

	if entity_name == "prop_ragdoll" then
		ang.pitch = -90
		tr.HitPos = tr.HitPos
	end

	---@type Vector
	tr.HitPos = shapes.choose(shape, count, tr.HitPos, radius, index, vForward)

	ent:SetModel(model)
	ent:SetSkin(iSkin)
	ent:SetAngles(ang)
	if strBody then
		ent:SetBodyGroups(strBody)
	end
	ent:SetPos(tr.HitPos)
	ent:Spawn()
	ent:Activate()

	-- Special case for effects
	---@diagnostic disable-next-line: undefined-field
	if strBody and entity_name == "prop_effect" and IsValid(ent.AttachedEntity) then
		---@diagnostic disable-next-line: undefined-field
		ent.AttachedEntity:SetBodyGroups(strBody)
	end

	-- Attempt to move the object so it sits flush
	-- We could do a TraceEntity instead of doing all
	-- of this - but it feels off after the old way
	local vFlushPoint = tr.HitPos - (tr.HitNormal * 512) -- Find a point that is definitely out of the object in the direction of the floor
	vFlushPoint = ent:NearestPoint(vFlushPoint) -- Find the nearest point inside the object to that point
	vFlushPoint = ent:GetPos() - vFlushPoint -- Get the difference
	vFlushPoint = tr.HitPos + vFlushPoint -- Add it to our target pos

	if entity_name ~= "prop_ragdoll" then
		-- Set new position
		ent:SetPos(vFlushPoint)
		ply:SendLua("achievements.SpawnedProp()")
	else
		-- With ragdolls we need to move each physobject
		local VecOffset = vFlushPoint - ent:GetPos()
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local phys = ent:GetPhysicsObjectNum(i)
			phys:SetPos(phys:GetPos() + VecOffset)
		end

		ply:SendLua("achievements.SpawnedRagdoll()")
	end

	TryFixPropPosition(ply, ent, tr.HitPos)

	return ent
end

---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L107
---@param ply Player
---@param model string
---@param iSkin integer
---@param strBody string?
---@param index integer
---@param radius number
---@param filter Entity[]
---@param shape "circle"|"square"
local function GMODSpawnRagdoll(ply, model, iSkin, strBody, index, radius, shape, count, filter)
	if IsValid(ply) and not gamemode.Call("PlayerSpawnRagdoll", ply, model) then
		return
	end
	local e = DoPlayerEntitySpawn(ply, "prop_ragdoll", model, iSkin, strBody, index, radius, shape, count, filter)

	if IsValid(ply) then
		gamemode.Call("PlayerSpawnedRagdoll", ply, model, e)
	end

	---@diagnostic disable-next-line: undefined-global
	DoPropSpawnedEffect(e)

	ply:AddCleanup("ragdolls", e)

	return e, "Ragdoll"
end

---https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L261
---@param ply Player
---@param model string
---@param iSkin integer
---@param strBody string?
---@param index integer
---@param radius number
---@param filter Entity[]
---@param shape "circle"|"square"
local function GMODSpawnEffect(ply, model, iSkin, strBody, index, radius, shape, count, filter)
	if IsValid(ply) and not gamemode.Call("PlayerSpawnEffect", ply, model) then
		return
	end

	local e = DoPlayerEntitySpawn(ply, "prop_effect", model, iSkin, strBody, index, radius, shape, count, filter)
	if not IsValid(e) then
		return
	end

	if IsValid(ply) then
		gamemode.Call("PlayerSpawnedEffect", ply, model, e)
	end

	---@diagnostic disable-next-line: undefined-field
	if IsValid(e.AttachedEntity) then
		---@diagnostic disable-next-line: undefined-field, undefined-global
		DoPropSpawnedEffect(e.AttachedEntity)
	end

	ply:AddCleanup("effects", e)

	return e, "Effect"
end

---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L231
---@param ply Player
---@param model string
---@param iSkin integer
---@param strBody string?
---@param index integer
---@param radius number
---@param filter Entity[]
---@param shape "circle"|"square"
local function GMODSpawnProp(ply, model, iSkin, strBody, index, radius, shape, count, filter)
	if IsValid(ply) and not gamemode.Call("PlayerSpawnProp", ply, model) then
		return
	end

	local e = DoPlayerEntitySpawn(ply, "prop_physics", model, iSkin, strBody, index, radius, shape, count, filter)
	if not IsValid(e) then
		return
	end

	if IsValid(ply) then
		gamemode.Call("PlayerSpawnedProp", ply, model, e)
	end

	-- This didn't work out - todo: Find a better way.
	--timer.Simple( 0.01, CheckPropSolid, e, COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD )

	FixInvalidPhysicsObject(e)

	---@diagnostic disable-next-line: undefined-global
	DoPropSpawnedEffect(e)

	ply:AddCleanup("props", e)

	return e, "Physics Prop"
end

---Modified CCSpawn which uses the shapes module for spawning entities at different points and returns the spawned entity
---@source https://github.com/Facepunch/garrysmod/blob/ee0b187dc1eadfbe456d86d6d6f030e87e074cf4/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L39
---@param ply Player
---@param model string
---@param index integer
---@param radius number
---@param shape "circle"|"square"
---@param count integer
---@param filter Entity[]
---@param skin integer?
---@param body string?
local function spawn(ply, model, index, radius, shape, count, filter, skin, body)
	if model == nil then
		return
	end
	if model:find("%.[/\\]") then
		return
	end

	-- Clean up the path from attempted blacklist bypasses
	model = model:gsub("\\\\+", "/")
	model = model:gsub("//+", "/")
	model = model:gsub("\\/+", "/")
	model = model:gsub("/\\+", "/")

	if not gamemode.Call("PlayerSpawnObject", ply, model, skin) then
		return
	end
	if not util.IsValidModel(model) then
		return
	end

	local iSkin = skin or 0
	local strBody = body or nil

	if util.IsValidProp(model) then
		return GMODSpawnProp(ply, model, iSkin, strBody, index, radius, shape, count, filter)
	end

	if util.IsValidRagdoll(model) then
		return GMODSpawnRagdoll(ply, model, iSkin, strBody, index, radius, shape, count, filter)
	end

	-- Not a ragdoll or prop.. must be an 'effect' - spawn it as one
	return GMODSpawnEffect(ply, model, iSkin, strBody, index, radius, shape, count, filter)
end

return spawn
