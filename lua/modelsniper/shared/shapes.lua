local shapes = {}
shapes.count = 2
shapes.toInt = { ["circle"] = 0, ["square"] = 1, ["point"] = 2 }
shapes.toShape = table.Flip(shapes.toInt)

---This returns a point on a line, which is perpendicular to the player look vector and is some `length` away from the other point
---@param center Vector
---@param length number
---@param index integer
---@param lookVector Vector
---@returns Vector point
function shapes.line(center, length, index, lookVector)
	---@diagnostic disable-next-line: param-type-mismatch
	lookVector[3] = 0
	lookVector:Normalize()

	local right = lookVector:Angle():Right()
	local sign = index == 1 and 1 or -1

	right:Mul(sign * length)
	center:Add(right)
	return center
end

---Returns a point on the circumference of a circle, which is made up of an equally-spaced locus
---@param center Vector
---@param radius number
---@param index integer
---@param total integer
---@param lookVector Vector
---@returns Vector point
function shapes.circle(center, radius, index, total, lookVector)
	---@diagnostic disable-next-line: param-type-mismatch
	lookVector[3] = 0
	lookVector:Normalize()
	lookVector:Mul(radius)
	lookVector:Rotate(Angle(0, 360 * (index - 1) / total, 0))

	center:Add(lookVector)
	return center
end

---Returns a point on a square grid.
---@param center Vector
---@param length number
---@param index integer
---@param total integer
---@param lookVector Vector
---@returns Vector point
function shapes.square(center, length, index, total, lookVector)
	---@diagnostic disable-next-line: param-type-mismatch
	lookVector[3] = 0
	lookVector:Normalize()
	local diag = lookVector:Angle():Right() + lookVector

	local rowMax = math.floor(math.sqrt(total))
	local xRow = index - 1
	local x = length * (xRow % rowMax) / (rowMax - 1)
	local y = length * math.floor(xRow / rowMax)
	local right = lookVector:Angle():Right() * x
	lookVector:Mul(y)

	center:Add(lookVector)
	center:Add(right)
	lookVector:Normalize()
	right:Normalize()
	center:Sub(diag * length * 0.5)

	return center
end

---@param shape "circle"|"square"|"point"
---@param count integer
---@param center Vector
---@param radius number
---@param index integer
---@param lookVector Vector
---@return Vector
function shapes.choose(shape, count, center, radius, index, lookVector)
	if shape == "point" then
		return center
	elseif shape == "square" and count > 3 then
		return shapes.square(center, radius, index, count, lookVector)
	elseif count >= 3 then
		return shapes.circle(center, radius, index, count, lookVector)
	elseif count == 2 then
		return shapes.line(center, radius, index, lookVector)
	end

	return center
end

return shapes
