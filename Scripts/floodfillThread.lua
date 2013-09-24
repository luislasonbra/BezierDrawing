------------------------------------------------
-- Rendering thread for creating filled images.
-------------------------------------------------
-- gets new shapes in the form:
-- ID{minX,minY,maxX,maxY}x1,y1|x2,y2|x3,y3| ...

require('love.image')
require('love.filesystem')
require('love.graphics')
require('love.timer')
require('Scripts/misc')
require('Scripts/point')

thisThread = love.thread.getThread()

local shapeQueue = {}
local lastTime = love.timer.getMicroTime()
local newTime --= love.timer.getMicroTime()

local newShape, ID, pos, boundingBox, pointList
local minX,minY,maxX,maxY
local tmpPoints
local seedFinishded,coveredPixels

local outCol = {
	r = 250,
	g = 250,
	b = 250,
	a = 250
}
local insCol = {
	r = 255,
	g = 255,
	b = 255,
	a = 255
}

local col = {
	r = 255,
	g = 255,
	b = 255,
	a = 255
}

thisThread:set("msg", "started")

local function split( str, sep )
	if str:sub( -1 ) ~= sep then
		str = str .. sep
	end
	return str:match((str:gsub("[^"..sep.."]*"..sep, "([^"..sep.."]*)"..sep)))
end

function sign( a )
	return ( a > 0 and 1 ) or ( a < 0 and -1 ) or 0
end

function clamp( a, b, c )
	if a > c then return c
	elseif a < b then return b
	else return a
	end
end

function setColor( r, g, b, a)
	col.r, col.g, col.b, col.a = r, g, b, a
end

function alphaOverlayColor( imageData, x, y, r, g, b, a )
	-- original values:
	local ro, go, bo, ao = imageData:getPixel( x, y )
	
	a = a/255
	ao = ao/255
	
	-- final values:
	local af = a + (1-a)*ao
	
	local rf = (a*r + (1-a)*ao*ro)/af
	local gf = (a*g + (1-a)*ao*go)/af
	local bf = (a*b + (1-a)*ao*bo)/af
	
	imageData:setPixel( x, y, rf, gf, bf, af*255 )
end

function drawLine( imgData, x1, y1, x2, y2 )
	--thisThread:set("msg", "line: " .. x1 .. " " .. y1 .. " " .. x2 .. " " .. y2 .. " " .. col.r .. " " .. col.b .. " " ..col.g .. " " .. col.a .. " ")
	
	--[[x1 = math.floor(x1)
	y1 = math.floor(y1)
	x2 = math.floor(x2)
	y2 = math.floor(y2)
	]]--
	
	local dx = x2-x1
	local dy = y2-y1
	local incrX = sign(dx)
	local incrY = sign(dy)
	dx = math.abs(dx)
	dy = math.abs(dy)
	local pdx, pdy, el, es, ddx, ddy

	if dx > dy then
		--/* x ist schnelle Richtung */
		pdx=incrX; pdy=0;    --/* pd. ist Parallelschritt */
		ddx=incrX; ddy=incrY; --/* dd. ist Diagonalschritt */
		es =dy;   el =dx;   --/* Fehlerschritte schnell, langsam */
	else
		--/* y ist schnelle Richtung */
		pdx=0;    pdy=incrY; --/* pd. ist Parallelschritt */
		ddx=incrX; ddy=incrY; --/* dd. ist Diagonalschritt */
		es =dx;   el =dy;   --/* Fehlerschritte schnell, langsam */
	end
	
	local x = x1
	local y = y1
	
	
	x = clamp(math.floor(x), 0, imgData:getWidth()-1)
	y = clamp(math.floor(y), 0, imgData:getHeight()-1)
	alphaOverlayColor( imgData, x, y, col.r, col.g, col.b, col.a )
	local err = dx/2

	for t=0,el do
		--/* Aktualisierung Fehlerterm */
		err = err - es
		if err<0 then
			--/* Fehlerterm wieder positiv (>=0) machen */
			err = err + el;
			--/* Schritt in langsame Richtung, Diagonalschritt */
			x = x + ddx;
			y = y + ddy;
		else
			--/* Schritt in schnelle Richtung, Parallelschritt */
			x = x + pdx;
			y = y + pdy;
		end
      
		x = clamp(math.floor(x), 0, imgData:getWidth()-1)
		y = clamp(math.floor(y), 0, imgData:getHeight()-1)
		alphaOverlayColor( imgData, x, y, col.r, col.g, col.b, col.a )
   end
end

function plot( imgData, x, y, alpha )
	alphaOverlayColor( imgData, x, y, col.r, col.g, col.b, alpha*255 )
	--imgData:setPixel( x, y, col.r, col.g, col.b, alpha*255 )
end

function drawLineAA( imgData, x0, y0, x1, y1 )
	local steep = math.abs(y1-y0) > math.abs(x1 - x0)
	
	if steep then
		x0, y0 = y0, x0
		x1, y1 = y1, x1
	end
	if x0 > x1 then
		x0, x1 = x1, x0
		y0, y1 = y1, y0
	end
	
	local dx = x1 - x0
	local dy = y1 - y0
	local gradient = dy/dx
	
	     -- handle first endpoint
     local xend = round(x0)
     local yend = y0 + gradient * (xend - x0)
     local xgap = rfpart(x0 + 0.5)
     local xpxl1 = xend   --this will be used in the main loop
     local ypxl1 = math.floor(yend)
     if steep then
         plot( imgData,ypxl1,   xpxl1, rfpart(yend) * xgap)
         plot( imgData, ypxl1+1, xpxl1,  fpart(yend) * xgap)
     else
         plot( imgData, xpxl1, ypxl1  , rfpart(yend) * xgap)
         plot( imgData, xpxl1, ypxl1+1,  fpart(yend) * xgap)
     end
     local intery = yend + gradient -- first y-intersection for the main loop
 
     -- handle second endpoint
     xend = round(x1)
     yend = y1 + gradient * (xend - x1)
     xgap = fpart(x1 + 0.5)
     local xpxl2 = xend --this will be used in the main loop
     local ypxl2 = math.floor(yend)
     if steep then
         plot( imgData,ypxl2,   xpxl2, rfpart(yend) * xgap)
         plot( imgData, ypxl2+1, xpxl2,  fpart(yend) * xgap)
     else
         plot( imgData, xpxl2, ypxl2,  rfpart(yend) * xgap)
         plot( imgData, xpxl2, ypxl2+1, fpart(yend) * xgap)
     end
 
     -- main loop
 
     for x = xpxl1 + 1, xpxl2 - 1 do
          if  steep then
             plot( imgData, math.floor(intery)  , x, rfpart(intery))
             plot( imgData, math.floor(intery)+1, x,  fpart(intery))
         else
             plot( imgData, x, math.floor (intery),  rfpart(intery))
             plot( imgData, x, math.floor (intery)+1, fpart(intery))
         end
         intery = intery + gradient
     end
end

function drawOutline( shape )
	shape.imageData = love.image.newImageData(
						shape.maxX - shape.minX + 10, shape.maxY - shape.minY + 10 )
	
	setColor( outCol.r,outCol.g,outCol.b,outCol.a )
	
	for k = 1, #shape.points-1 do
		drawLine( shape.imageData, shape.points[k].x, shape.points[k].y,
							shape.points[k+1].x, shape.points[k+1].y)
	end
end

function newScanlineSeed( shape, x, y )
	shape.seedList[#shape.seedList+1] = {
		x = x, y = y
	}
end

-- Fills a shape recursively. The function interupts itself after every
-- single line, so that other shapes can be worked on and communication
-- with the main thread doesn't stop. Will plant new seeds if the line
-- is finished processing.
function scanlineFill( shape, seed )
	local r,g,b,a, y

	local covered = 0
	if not seed.lineFilled then
		-- check towards the top
		
		r,g,b,a = shape.imageData:getPixel( seed.x, seed.y )
		if (a ~= 0) then
			return
		end
		
		y = seed.y
		seed.minY = 0
		while y >= seed.minY do
			r,g,b,a = shape.imageData:getPixel( seed.x, y )
			if (a ~= 0) then
				seed.minY = y
				break
			end
			shape.imageData:setPixel( seed.x, y, insCol.r,insCol.g,insCol.b,insCol.a )
			y = y - 1
			covered = covered + 1
		end
		
		y = seed.y+1 -- don't check starting pos!
		seed.maxY = shape.imageData:getHeight()-1
		while y <= seed.maxY do
			r,g,b,a =shape.imageData:getPixel( seed.x, y )
			if (a ~= 0) then
				seed.maxY = y
				break			
			end
			shape.imageData:setPixel( seed.x, y, insCol.r,insCol.g,insCol.b,insCol.a )
			y = y + 1
			covered = covered + 1
		end
		
		seed.lineFilled = true
		
	
	-- Next, scan the neighbouring lines on the left and right side:
	-- (first up, then down)
	elseif not seed.leftCheckedUp then
		if seed.x > 0 then
			y = seed.currentLeftUp or seed.y
			while y > seed.minY do
				r,g,b,a = shape.imageData:getPixel( seed.x - 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x - 1, y )
					seed.currentLeftUp = y
					break			
				end
				y = y - 1
			end
		else
			y = seed.minY
		end
		if y <= seed.minY then
			seed.leftCheckedUp = true
		end
	elseif not seed.leftCheckedDown then
		if seed.x > 0 then
			y = seed.currentLeftDown or seed.y
			while y < seed.maxY do
				r,g,b,a = shape.imageData:getPixel( seed.x - 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x - 1, y )
					seed.currentLeftDown = y
					break			
				end
				y = y + 1
			end
		else
			y = seed.maxY
		end
		if y >= seed.maxY then
			seed.leftCheckedDown = true
		end
	elseif not seed.rightCheckedUp then
		if seed.x < shape.imageData:getWidth()-1 then
			y = seed.currentRightUp or seed.y
			while y > seed.minY do
				r,g,b,a = shape.imageData:getPixel( seed.x + 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x + 1, y )
					seed.currentRightUp = y
					break			
				end
				y = y - 1
			end
		else
			y = seed.minY
		end
		if y <= seed.minY then
			seed.rightCheckedUp = true
		end
	elseif not seed.rightCheckedDown then
		if seed.x < shape.imageData:getWidth()-1 then
			y = seed.currentRightDown or seed.y
			while y < seed.maxY do
				r,g,b,a = shape.imageData:getPixel( seed.x + 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x + 1, y )
					seed.currentRightDown = y
					break			
				end
				y = y + 1
			end
		else
			y = seed.maxY
		end
		if y >= seed.maxY then
			seed.rightCheckedDown = true
			return true		-- done, checked in all directions!
		end
	end
	
	return false, covered
end

-- This function repeats the ray-cast algorithm in 4 directions,
-- because one-pixel-wide lines can make the single ray unprecise.
-- The case where the border of the shape lies on the edge of the
-- image can be discared: it can never happen because the shape is
-- padded by a few pixels in all directions (phew!)
function isInsideShape( shape, x, y )
	if x < 0 or x > shape.imageData:getWidth() - 1 or 
		y < 0 or y > shape.imageData:getHeight() - 1 then
			thisThread:set("msg", 0)
		return false
	end
	
	local r,g,b,a = shape.imageData:getPixel( x, y )
	
	-- On outline? Then return false - not inside shape!
	if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisThread:set("msg", 1)
		return false
	end
	
	local iterations = 0
	local intersectionsUp = 0
	local lastWasOnLine, thisIsOnLine = false, false
	for y1 = y-1,0,-1 do	-- move upwards and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x, y1 )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsUp = intersectionsUp + 1
		end
		iterations = iterations +1
		--thisThread:set("msg", iterations .. " " .. tostring(lastWasOnLine) .. " " .. tostring(thisIsOnLine))
		--os.execute("sleep .1")
		lastWasOnLine = thisIsOnLine
	end
		--thisThread:set("msg", "intersectionsUp: " .. intersectionsUp)
		--os.execute("sleep .1")
	
	local intersectionsDown = 0
	lastWasOnLine, thisIsOnLine = false, false
	for y1 = y+1,shape.imageData:getHeight()-1,1 do	-- move downwards and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x, y1 )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsDown = intersectionsDown + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	local intersectionsLeft = 0
	lastWasOnLine, thisIsOnLine = false, false
	for x1 = x-1,0,-1 do	-- move left and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x1, y )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsLeft = intersectionsLeft + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	local intersectionsRight = 0
	lastWasOnLine, thisIsOnLine = false, false
	for x1 = x+1,shape.imageData:getWidth()-1,1 do	-- move right and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x1, y )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsRight = intersectionsRight + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	if intersectionsUp % 2 == 1 and intersectionsDown % 2 == 1 and
		intersectionsLeft % 2 == 1 and intersectionsRight % 2 == 1 then
		return true
	end
	--thisThread:set("msg", intersectionsUp .. " " .. intersectionsDown .. " " .. intersectionsLeft .. " " .. intersectionsRight)
	return false
end



function checkShapeThickness( shape )
	if not shape.thickness then
		shape.thickness = {}
		--shape.thickness
	end
end


-- Make sure shape is oriented counter-clockwise!!
function correctShapeDirection( shape )

	local checked = false
	local needsTurning = false
	local dir, normal1, normal2, len
	
	local k = 1
	while not checked and k < #shape.points-1 do
		dir = shape.points[k+1] - shape.points[k]
	
		normal1 = Point:new( -dir.y, dir.x )
		len = normal1:getLength()
		normal1 = normal1*(3/len)	-- normalize to 3 pixels!
		
		normal2 = Point:new( dir.y, -dir.x )
		len = normal2:getLength()
		normal2 = normal2*(3/len)	-- normalize to 3 pixels!
		
		isInside1 = isInsideShape( shape,
					shape.points[k].x + normal1.x, shape.points[k].y + normal1.y )
		
		isInside2 = isInsideShape( shape,
					shape.points[k].x + normal2.x, shape.points[k].y + normal2.y )
					
		if isInside1 and not isInside2 then
			checked = true
		elseif not isInside1 and isInside2 then		-- the wrong normal is inside!!
			checked = true
			needsTurning = true
		end
		k = k+1
	end
	
	-- If the check above returned that the shape was clockwise, 
	-- then turn it around to now be counter-clockwise.
	if needsTurning then
		local newList = {}
		for k = 1, #shape.points do
			newList[k] = shape.points[#shape.points + 1 - k]
		end
		shape.points = newList
	end
	shape.bool_directionCorrected = true
end

function calcNormals( shape )
	for k = 1, #shape.points do
	
		local normal1, normal2
		local P1, P2, P3
	
		local segDir1, segDir2
		local startPoint, endPoint
	
		P2 = shape.points[k]
	
		if k == 1 then
			P1 = shape.points[#shape.points-1]
		else
			P1 = shape.points[k-1]
		end
		segDir1 = P2 - P1
		normal1 = Point:new( -segDir1.y, segDir1.x )
		normal1 = normal1*(10/normal1:getLength())
	
		if k == #shape.points then
			P3 = shape.points[2]
		else
			P3 = shape.points[k+1]
		end
		segDir2 = P3 - P2
		normal2 = Point:new( -segDir2.y, segDir2.x )
		normal2 = normal2*(10/normal2:getLength())
	
		--thisThread:set("msg", tostring(P1 + normal1) .. tostring(P2 + normal1) .. tostring(P2 + normal2) .. tostring(P3 + normal2))
		local intersection = lineIntersections( P2 + normal1, P1 + normal1,
												P2 + normal2, P3 + normal2)
		
		if intersection then
			--[[setColor ( 255,0,0, 255)
		drawLine( shape.imageData, (P2).x, (P2).y, (P2 + normal1).x, (P2 + normal1).y )
			setColor ( 255,0,255, 255)
		drawLine( shape.imageData, (P2).x, (P2).y, (P2 + normal2).x, (P2 + normal2).y )
			]]--
			shape.points[k].normal = intersection - shape.points[k]
		else
			shape.points[k].normal = normal1
		end
		
		--shape.points[k].normal = shape.points[k].normal
		shape.points[k].lineNormal = normal2
	end
	
	--drawNormals( shape )
	shape.bool_normalsCalculated = true
end

function drawNormals( shape )

	local dir, normal, endPoint
	for k = 1, #shape.points do
	
		if shape.points[k].normal then
			endPoint = shape.points[k] + shape.points[k].normal*20
			
			setColor( 0, 255, 0, 255 )
			drawLine( shape.normalMap, shape.points[k].x, shape.points[k].y, endPoint.x, endPoint.y )
		end
		
	end
end

function resetNormalMap(x, y, r, g, b, a)
	if a > 0 then
		return 128,128,255,255
	else
		return r, g, b, a
	end
end

function drawNormalMap( shape )
	if not shape.normalMap then
		shape.normalMap = love.image.newImageData( shape.width, shape.height )
		shape.normalMap:paste( shape.imageData, 0, 0 )
		shape.normalMap:mapPixel( resetNormalMap )
		shape.step_nM = 1
	else
		k = shape.step_nM

		local P1, P2
		
		local thickness = 20
		
		local covered = 0
		local x,y,z, len
		while covered < thickness do
		
			--Color.rgb = Normal.xyz / 2.0 + 0.5;
			
			x = -shape.points[k].lineNormal.x
			y = shape.points[k].lineNormal.y
			z = covered/thickness
		
			len = math.sqrt(x*x+y*y+z*z)
			x = (x/len)/2+0.5
			y = (y/len)/2+0.5
			z = (z/len)/2+0.5
		
			setColor( 255*x, 255*y, 255*z, 255*(thickness-covered)/thickness )
			
			P1 = shape.points[k] + shape.points[k].normal*(covered/thickness)
			P2 = shape.points[k+1] + shape.points[k+1].normal*(covered/thickness)
		
			drawLineAA( shape.normalMap, P1.x, P1.y, P2.x, P2.y, 1 )
			
			covered = covered + 1
		end

		shape.step_nM = shape.step_nM + 1
		
		if shape.step_nM == #shape.points then
			shape.bool_normalMap = true
		end
	end
end

	
function runThread()
	while true do
		newTime = love.timer.getMicroTime()
		dt = newTime - lastTime
		lastTime = newTime
	
		-- Check if there's a new shape in the queue. If so, put it in a table to process later:
		newShape = thisThread:get("newShape")
		if newShape then
			pos = newShape:find( "{" )
			if pos then
				ID = newShape:sub( 1, pos - 1 )
				newShape = newShape:sub( pos + 1 )
				pos = newShape:find( "}" )
				minX,minY,maxX,maxY = split(newShape:sub(1, pos-1), ",")
				minX,minY,maxX,maxY = tonumber(minX),tonumber(minY),tonumber(maxX),tonumber(maxY)
				-- minX,minY,maxX,maxY = math.floor(minX),math.floor(minY),math.floor(maxX),math.floor(maxY)

				pointList = newShape:sub(pos+1)
			
				--tmpPoints = {split(pointList, "|")}
			
				tmpPoints = {}
				pos = pointList:find("|")
				while pos do
					tmpPoints[#tmpPoints + 1] = pointList:sub(1, pos-1)
					pointList = pointList:sub( pos+1 )
					pos = pointList:find("|")
				end
			
				-- disregard any earlier rendering for this shape:
				shapeQueue[ID] = {
					percent = 0,
					minX = minX,
					minY = minY,
					maxX = maxX,
					maxY = maxY,
					points = {},
					seedList = {},
					currentLine = 0,
					pixelsFilled = 0,
				}
			
			
				for k = 1, #tmpPoints do
					shapeQueue[ID].points[k] = Point:new( split(tmpPoints[k], ",") )
					shapeQueue[ID].points[k].x = tonumber( shapeQueue[ID].points[k].x ) - minX + 5
					shapeQueue[ID].points[k].y = tonumber( shapeQueue[ID].points[k].y ) - minY + 5
					shapeQueue[ID].points[k].x = math.floor( shapeQueue[ID].points[k].x )
					shapeQueue[ID].points[k].y = math.floor( shapeQueue[ID].points[k].y )
				end
			
			
				msg = "New shape for: " .. ID ..
					" " .. minX .. 
					" " .. minY .. 
					" " .. maxX .. 
					" " .. maxY ..
					"\n\tnumPoints:" .. #shapeQueue[ID].points
				thisThread:set("msg", msg)
			
				drawOutline(shapeQueue[ID])
			
				shapeQueue[ID].width = shapeQueue[ID].imageData:getWidth()
				shapeQueue[ID].height = shapeQueue[ID].imageData:getHeight()
				shapeQueue[ID].pixels = (shapeQueue[ID].width-10)*(shapeQueue[ID].height-10)
			
				-- Find starting point inside shape. Choose random point and check if it's inside.
				local a,b
				repeat			
					a = math.random(0, shapeQueue[ID].width-1)
					b = math.random(0, shapeQueue[ID].height-1)
				until isInsideShape( shapeQueue[ID], a, b )
			
				shapeQueue[ID].seedList[1] = {
					x = a,
					y = b,
				}
				
				correctShapeDirection( shapeQueue[ID] )
				drawNormals( shapeQueue[ID] )
			end
		end
	
		for ID, s in pairs(shapeQueue) do
		
			seeds = shapeQueue[ID].seedList
			if #seeds > 0 then
				seedFinishded, coveredPixels = scanlineFill( s, seeds[#seeds] )
				if seedFinishded then
					seeds[#seeds] = nil -- remove last seed!
				end
				--thisThread:set( ID .. "(img)", s.imageData )
				--os.execute("sleep .0001")
				
				if coveredPixels then
					s.pixelsFilled = s.pixelsFilled + coveredPixels
					thisThread:set(ID .. "(%)", math.floor(100*s.pixelsFilled/shapeQueue[ID].pixels))
				end
				
			else
				if not s.bool_directionCorrected then
					correctShapeDirection( s )
				elseif not s.bool_normalsCalculated then
					calcNormals( s )
				elseif not s.bool_normalMap then
					drawNormalMap( s )
				else
					setColor(0,0,0,255)
					drawLineAA( s.normalMap, 10, 10, s.imageData:getWidth()-10, s.imageData:getHeight()-10, 1)
					drawLineAA( s.normalMap, s.normalMap:getWidth()/2, 10, s.normalMap:getWidth()/2-10, s.normalMap:getHeight()-10, 1)
					thisThread:set( ID .. "(img)", s.imageData )
					thisThread:set( ID .. "(nm)", s.normalMap )
					thisThread:set(  ID .. "(done)", true )
					shapeQueue[ID] = nil
					thisThread:set( "msg", "Done: " .. ID )
				end
			end
		end
	end
end


runThread()		-- start the whole process

