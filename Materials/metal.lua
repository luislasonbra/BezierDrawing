-- material to be used in vessel construction

local function profile( dir, amount )
	local len = 1-amount
	local normal3D = dir*len
	return normal3D.x, normal3D.y, amount
end

local function profileSpecular( dir, amount )
	return 255,255,255
end


local mat = {
	col = { r = 140, g=140, b=110, a=255 },
	profile = profile,
	profileDepth = 60,
	specular = { r = 255, g=255, b=255 },
	profileSpecular = profileSpecular,
}

return mat
