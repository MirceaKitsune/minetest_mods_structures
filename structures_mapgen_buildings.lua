-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Settings

-- add this many nodes to each side when cutting and adding the floor
local MAPGEN_BUILDINGS_BORDER = 2

-- Global functions - Buildings

-- analyzes buildings in the mapgen group and returns them as a lists of parameters
function mapgen_buildings_get (pos, scale_horizontal, scale_vertical, group)
	-- parameters: group [1], type [2], structure [3], count [4], bury [5]
	-- x = left & right, z = up & down

	-- buildings table which will be filled and returned by this function
	local buildings = { }

	-- first generate a list of indexes for all buildings, containing an entry for each time it will be spawned
	local instances = { }
	for i, entry in ipairs(mapgen_table) do
		-- only if this is a building which belongs to the chosen mapgen group
		if (entry[1] == group) and (entry[2] == "building") then
			for x = 1, tonumber(entry[4]) do
				table.insert(instances, i)
			end
		end
	end

	-- now randomize the table so building instances won't be spawned in an uniform order
	local count = #instances
	for i in ipairs(instances) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(count)

		-- swap the two entries
		local old = instances[i]
		instances[i] = instances[rand]
		instances[rand] = old
	end

	-- store the top-right corners of buildings in the left and right columns (compared to the current column)
	-- in each colum, we check the left list and set the right one for later use, then right becomes left when we advance to the next colum
	local points_left = { }
	local points_right = { }
	-- the column and row we are currently in
	local row = 0
	local column = 0
	-- largest X size, used to calculate columns based on row width
	local largest_x = 0

	-- go through the mapgen table
	for i, instance in ipairs(instances) do
		entry = mapgen_table[instance]

		-- if the current row was filled, jump to the next column
		if (row > scale_horizontal) then
			-- start again from the top at next column
			row = 0
			column = column + largest_x
			largest_x = 0
			-- the list of next points becomes the list of current points
			points_left = points_right
			points_right = { }
		end
		-- if the columns were filled, return the sturcute table and stop doing anything
		if (column > scale_horizontal) then
			return buildings
		end

		-- location will be gradually determined in each direction
		local location = { x = 0, y = pos.y, z = 0, number = 0 }
		location.z = pos.z + row -- we determined Z location

		-- choose angle (0, 90, 180, 270) based on distance from center, and size based on angle
		-- it's hard to find an accurate formula here, but it keeps buildings oriented uniformly
		local angle = 0
		if (row < scale_horizontal / 2) and (column < scale_horizontal / 2) then
			angle = 180
		elseif (row < scale_horizontal / 2) then
			angle = 90
		elseif (column < scale_horizontal / 2) then
			angle = 270
		end
		local size = io_get_size(angle, entry[3])
		-- actual space the building will take up
		local building_width = size.x + MAPGEN_BUILDINGS_BORDER * 2
		local building_height = size.z + MAPGEN_BUILDINGS_BORDER * 2

		-- determine which of the buildings in the left row have their top-right corners intersecting this building, and push this building to the right accordingly
		local edge = pos.x
		for w, point in ipairs(points_left) do
			-- check if the point intersects our building
			if (point.z >= location.z - building_height) and (point.z <= location.z + building_height) then
				-- if this point is further to the right than the last one, bump the edge past its location
				if (edge < point.x) then
					edge = point.x
				end
			end
		end
		location.x = edge -- we determined X location

		-- add the loop iteration into the location table (used for address signs)
		location.number = i

		-- the building may spawn, insert it into the buildings table
		-- parameters: name [1], position [2], angle [3], size [4], bury [5]
		table.insert(buildings, { entry[3], location, angle, size, entry[5] } )

		-- add this building's upper-right corner to the right point list
		upright = { }
		upright.x = location.x + building_width
		upright.z = location.z
		table.insert(points_right, upright)
		-- push the row so the next building will spawn right under this one
		row = row + building_height
		-- update the largest X size of this row
		if (building_width > largest_x) then
			largest_x = building_width
		end
	end

	return buildings
end

-- naturally spawns a building with the given parameters
function mapgen_buildings_spawn (name, pos, angle, size, bury, group)

	-- determine the corners of the spawn cube
	-- since the I/O function doesn't include the start and end values as valid locations (only the space between them), decrease start position by 1 to get the right spot
	local pos1 = { x = pos.x + MAPGEN_BUILDINGS_BORDER - 1, y = pos.y - 1, z = pos.z + MAPGEN_BUILDINGS_BORDER - 1 }
	local pos2 = { x = pos.x + size.x + MAPGEN_BUILDINGS_BORDER, y = pos.y + size.y, z = pos.z + size.z + MAPGEN_BUILDINGS_BORDER }
	local pos1_frame = { x = pos.x - 1, y = pos.y - 1, z = pos.z - 1 }
	local pos2_frame = { x = pos.x + size.x + MAPGEN_BUILDINGS_BORDER * 2, y = pos.y + size.y, z = pos.z + size.z + MAPGEN_BUILDINGS_BORDER * 2}

	-- clear the area before spawning
	io_area_fill(pos1_frame, pos2_frame, nil)

	-- apply burying
	pos1.y = pos1.y - bury
	pos2.y = pos2.y - bury

	-- at last, create the building itself
	io_area_import(pos1, pos2, angle, name, false)

	-- apply metadata changes after spawning
	local expressions = {
		{ "POSITION_X", tostring(pos.x) }, { "POSITION_Y", tostring(pos.y) }, { "POSITION_Z", tostring(pos.z) },
		{ "SIZE_X", tostring(size.x) }, { "SIZE_Y", tostring(size.y) }, { "SIZE_Z", tostring(size.z) },
		{ "ANGLE", tostring(angle) }, { "NUMBER", tostring(pos.number) }, { "NAME", name }, { "GROUP", group }
	}
	metadata_set(pos1, pos2, expressions, group)
end
