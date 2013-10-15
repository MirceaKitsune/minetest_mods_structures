-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Settings

-- add this many nodes to each side when cutting and adding the floor
local MAPGEN_BUILDINGS_BORDER = 2

-- Global functions - Buildings

-- analyzes buildings in the mapgen group and returns them as a lists of parameters
function mapgen_buildings_get (pos, scale_horizontal, boxes, group)
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
	calculate_table_shuffle(instances)

	-- stores the bounding boxes of areas to avoid, must contain start position
	local rectangles = boxes
	table.insert(rectangles, { start_x = pos.x, start_z = pos.z, end_x = pos.x, end_z = pos.z })

	-- go through the instances
	for i, instance in ipairs(instances) do
		entry = mapgen_table[instance]

		-- used later to check if a position was found
		local found_pos = false
		-- location will be fully determined later
		local location = { x = pos.x, y = pos.y, z = pos.z, number = 0 }

		-- choose angle (0, 90, 180, 270)
		-- TODO: Find a way to orient them uniformly, harder because position is determined later but we need to know angle + size for position
		local angle = 90 * math.random(1, 4)
		local size = io_get_size(angle, entry[3])
		-- actual space the building will take up
		local building_width = size.x + MAPGEN_BUILDINGS_BORDER * 2
		local building_height = size.z + MAPGEN_BUILDINGS_BORDER * 2

		-- determine the X and Z position of this building
		-- first shuffle the rectangles table, to avoid a fixed search order
		calculate_table_shuffle(rectangles)
		-- loop 1: go through the recrangles we want to place this building next to
		for w, rectangle1 in ipairs(rectangles) do
			-- there are two ways to attempt placing this building around the rectangle: under it or right of it
			local pos_under = { x = rectangle1.start_x, z = rectangle1.end_z + 1 }
			local pos_right = { x = rectangle1.end_x + 1, z = rectangle1.start_z }
			local found_under = true
			local found_right = true

			-- loop 2: go through the recrangles that might intersect this building
			for v, rectangle2 in ipairs(rectangles) do
				-- only check if this rectangle intersects our range
				if (v ~= w) and
				((rectangle2.start_x >= rectangle1.start_x) or (rectangle2.end_x >= rectangle1.start_x)) and
				((rectangle2.start_z >= rectangle1.start_z) or (rectangle2.end_z >= rectangle1.start_z)) then
					-- check under
					if (found_under == true) and
					(pos_under.x + building_width >= rectangle2.start_x) and (pos_under.z + building_height >= rectangle2.start_z) then
						found_under = false
					end
					-- check right
					if (found_right == true) and
					(pos_right.x + building_width >= rectangle2.start_x) and (pos_right.z + building_height >= rectangle2.start_z) then
						found_right = false
					end
				end

				-- if both options failed, there's no need to keep going
				if (found_under == false) and (found_right == false) then
					break
				end
			end

			-- see which options succeeded if any (prefer under)
			-- also make sure the building would still be within the group's bounds
			if (found_under == true) and
			(pos_under.x + building_width <= pos.x + scale_horizontal) and (pos_under.z + building_height <= pos.z + scale_horizontal) then
				location.x = pos_under.x
				location.z = pos_under.z
				found_pos = true
				break
			elseif (found_right == true) and
			(pos_right.x + building_width <= pos.x + scale_horizontal) and (pos_right.z + building_height <= pos.z + scale_horizontal) then
				location.x = pos_right.x
				location.z = pos_right.z
				found_pos = true
				break
			end
		end

		-- only if this building was found in the loop above
		if (found_pos == true) then
			-- add the loop iteration into the location table (used for address signs)
			location.number = i

			-- the building may spawn, insert it into the buildings table
			-- parameters: name [1], position [2], angle [3], size [4], bury [5]
			table.insert(buildings, { entry[3], location, angle, size, entry[5] } )

			-- add this building's corners to the rectangle list
			local rectangle_new = { start_x = location.x, start_z = location.z, end_x = location.x + building_width - 1, end_z = location.z + building_height - 1 }
			table.insert(rectangles, rectangle_new)
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
