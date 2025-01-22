local helpers = {}

---@param entity Entity
---@return Entity
function helpers.getAncestor(entity)
	while entity:GetParent() ~= NULL do
		entity = entity:GetParent()
	end
	return entity
end

return helpers
