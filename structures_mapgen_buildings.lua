-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Global functions - Buildings

-- analyzes buildings in the mapgen table and acts accordingly
function mapgen_buildings_get (pos, scale_h, boxes, group)
	local new_scheme = { }
	-- store the bounding boxes of areas to avoid, must begin with start position
	local new_rectangles = boxes
	table.insert(new_rectangles, { start_x = pos.x, start_z = pos.z, end_x = pos.x, end_z = pos.z })

	-- first generate a list of indexes for all buildings, an entry for each time a building will be spawned
	local instances = { }
	for i, entry in ipairs(mapgen_table) do
		-- only advance if this is a building which belongs to the chosen mapgen group
		if (entry[1] == group) and (entry[2] == "building") then
			for x = 1, tonumber(entry[4]) do
				table.insert(instances, i)
			end
		end
	end
	-- now randomize the table so building instances won't be spawned in an uniform order
	calculate_table_shuffle(instances)

	-- go through the instances in the mapgen table
	-- mapgen table, buildings: group [1], type [2], structure [3], count [4], offset [5]
	for i, instance in ipairs(instances) do
		entry = mapgen_table[instance]

		-- used later to check if a position was found
		local found_pos = false
		-- location will be fully determined later
		local location = { x = pos.x, y = pos.y + tonumber(entry[5]), z = pos.z }

		-- choose angle (0, 90, 180, 270)
		-- TODO: Find a way to orient buildings uniformly, difficult because position is determined later but we already need to know angle + size for position
		local angle = 90 * math.random(0, 3)
		local size = io_get_size(angle, entry[3])

		-- determine the X and Z position of this building
		-- first shuffle the rectangles table, to avoid a fixed search order
		calculate_table_shuffle(new_rectangles)
		-- loop 1: go through the recrangles we want to place this building next to
		for w, rectangle1 in ipairs(new_rectangles) do
			-- there are two ways to attempt placing this building around the rectangle: under it or right of it
			-- TODO: Possibly add support for positioning left and above as well, so buildings can go in all directions
			local pos_under = { x = rectangle1.start_x, z = rectangle1.end_z + 1 }
			local pos_right = { x = rectangle1.end_x + 1, z = rectangle1.start_z }
			local found_under = true
			local found_right = true

			-- loop 2: go through the recrangles that might intersect this building here
			for v, rectangle2 in ipairs(new_rectangles) do
				-- only check if this rectangle intersects our range
				if (v ~= w) and
				((rectangle2.start_x >= rectangle1.start_x) or (rectangle2.end_x >= rectangle1.start_x)) and
				((rectangle2.start_z >= rectangle1.start_z) or (rectangle2.end_z >= rectangle1.start_z)) then
					-- check under
					if (found_under == true) and
					(pos_under.x + size.x >= rectangle2.start_x) and (pos_under.z + size.z >= rectangle2.start_z) then
						found_under = false
					end
					-- check right
					if (found_right == true) and
					(pos_right.x + size.x >= rectangle2.start_x) and (pos_right.z + size.z >= rectangle2.start_z) then
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
			(pos_under.x + size.x <= pos.x + scale_h) and (pos_under.z + size.z <= pos.z + scale_h) then
				location.x = pos_under.x
				location.z = pos_under.z
				found_pos = true
				break
			elseif (found_right == true) and
			(pos_right.x + size.x <= pos.x + scale_h) and (pos_right.z + size.z <= pos.z + scale_h) then
				location.x = pos_right.x
				location.z = pos_right.z
				found_pos = true
				break
			end
		end

		-- only if this building was found in the loop above
		if (found_pos == true) then
			local name = entry[3]
			local pos_center = { x = math.floor(location.x + (size.x / 2)), y = location.y, z = math.floor(location.z + (size.z / 2)) }
			local expressions = {
				{ "POSITION_X", tostring(pos_center.x) }, { "POSITION_Y", tostring(pos_center.y) }, { "POSITION_Z", tostring(pos_center.z) },
				{ "SIZE_X", tostring(size.x) }, { "SIZE_Y", tostring(size.y) }, { "SIZE_Z", tostring(size.z) },
				{ "ANGLE", tostring(angle) }, { "NUMBER", tostring(i) }, { "NAME", name }, { "GROUP", group }
			}

			-- insert the building into the schemes table
			-- schematics: name [1], position [2], angle [3], size [4]
			table.insert(new_scheme, { name, location, angle, size } )

			-- add this building's corners to the rectangle list
			local rectangle = { start_x = location.x, start_z = location.z, end_x = location.x + size.x - 1, end_z = location.z + size.z - 1 }
			table.insert(new_rectangles, rectangle)
		end
	end

	-- return the structure scheme of buildings
	return new_scheme
end
