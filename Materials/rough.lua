-- material to be used in vessel construction

local function profile( dir, amount )
	local len = 1-amount
	local normal3D = dir
	return normal3D.x, normal3D.y, amount
end

local function pattern( x, y )
	return 20,20,20,255
end

local function patternNormal( x, y )
	return 0,0,1
end

local function patternSpecular( x, y )
	local amount = math.random(64) + 190
	return amount, amount, amount, 255
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	col = { r = 50, g=50, b=50, a=255 },
	-- profile function:
	profile = profile,
	profileDepth = 30,
	specular = { r = 255, g=155, b=60 },
	--profileSpecular = profileSpecular,
	patternWidth = 20,
	patternHeight = 30,
	pattern = pattern,
	patternNormal = patternNormal,
	patternSpecular = patternSpecular,
}

return mat
