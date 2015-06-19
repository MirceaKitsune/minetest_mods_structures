-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Local functions - Draw

-- obtains the position and rotation of all building parts
local function mapgen_buildings_draw (pos, size, angle, floors, entry)
	local new_scheme = {}

	if floors == 0 then
		-- insert the building into the schemes table
		-- types: 1 = normal & center, 2 = start, 3 = end
		table.insert(new_scheme, {name = entry.name, pos = pos, angle = angle, size = size, flatness = entry.flatness})
	else
		local size_start = {x = size.x, y = size.y_start, z = size.z}
		local size_middle = {x = size.x, y = size.y, z = size.z}
		local size_end = {x = size.x, y = size.y_end, z = size.z}

		-- add the start segment to the schemes table
		table.insert(new_scheme, {name = entry.name_start, pos = pos, angle = angle, size = size_start, flatness = nil})

		-- loop through the middle segments
		local height_middle_start = pos.y + size_start.y
		local height_middle_end = height_middle_start + (size_middle.y * (floors - 1))
		for height = height_middle_start, height_middle_end, size_middle.y do
			-- add the middle segments to the schemes table
			local pos_middle = {x = pos.x, y = height, z = pos.z}
			table.insert(new_scheme, {name = entry.name, pos = pos_middle, angle = angle, size = size_middle, flatness = nil})
		end

		-- add the end segment to the schemes table
		local height_end = height_middle_end + size_middle.y
		local pos_end = {x = pos.x, y = height_end, z = pos.z}
		table.insert(new_scheme, {name = entry.name_end, pos = pos_end, angle = angle, size = size_end, flatness = nil})
	end

	return new_scheme
end

-- Global functions - Buildings

-- analyzes buildings in the mapgen table and acts accordingly
function mapgen_buildings_get (pos_start, pos_end, rectangles, buildings)
	local schemes = {}
	-- store the bounding boxes of areas to avoid
	-- if the function is called without any boxes (eg: roads), add a point in the center
	local new_rectangles = rectangles
	if #new_rectangles == 0 then
		local center_x = math.floor((pos_start.x + pos_end.x) / 2)
		local center_z = math.floor((pos_start.z + pos_end.z) / 2)
		table.insert(new_rectangles, {start_x = center_x, start_z = center_z, end_x = center_x, end_z = center_z, layer = nil})
	end

	-- although the group size tries to match the number of structures, buildings that spawn first may still decrease the probability of following buildings
	-- so instead of looping through the buildings table directly, create a list of indexes and randomize it, then loop through that
	local instances = {}
	-- first generate a list of indexes for all buildings, an entry for each time a building will be spawned
	for i, entry in ipairs(buildings) do
		-- spawn this building based on its probability
		for x = 1, entry.count do
			table.insert(instances, i)
		end
	end
	-- now randomize the table so building instances won't be spawned in an uniform order
	calculate_table_shuffle(instances)

	for i, instance in ipairs(instances) do
		local entry = buildings[instance]

		-- if the name is a table, choose a random schematic from it
		entry.name = calculate_entry(entry.name)
		entry.name_start = calculate_entry(entry.name_start)
		entry.name_end = calculate_entry(entry.name_end)

		-- choose angle (0, 90, 180, 270)
		local angle = 90 * math.random(0, 3)

		-- get number of floors this building has
		local floors = 0
		if entry.floors_min and entry.floors_max and entry.floors_max > 0 then
			floors = math.random(entry.floors_min, entry.floors_max)
		end

		-- obtain this building's size
		local size = io_get_size(angle, entry.name)
		if floors and floors > 0 then
			local size_start = io_get_size(angle, entry.name_start)
			local size_end = io_get_size(angle, entry.name_end)

			-- the height of each segment might be different, so store that of the start and end segments separately
			size.y_start = size_start.y
			size.y_end = size_end.y
		end

		-- used later to check if a position was found
		local found_pos = false

		-- X and Z positions, Y only represents the offset
		local pos = {x = pos_start.x, y = entry.offset, z = pos_start.z}

		-- determine the X and Z position of this building
		-- first shuffle the rectangles table, to avoid a fixed search order
		calculate_table_shuffle(new_rectangles)
		-- loop 1: go through the recrangles we want to place this building next to
		for w, rectangle1 in ipairs(new_rectangles) do
			-- only if it's a rectangle on the same layer
			if not (rectangle1.layer and entry.layer and rectangle1.layer ~= entry.layer) then
				-- there are two ways to attempt placing this building around the rectangle: under it or right of it
				local pos_under = {x = rectangle1.start_x, z = rectangle1.end_z + 1}
				local pos_right = {x = rectangle1.end_x + 1, z = rectangle1.start_z}
				local pos_over = {x = rectangle1.start_x, z = rectangle1.start_z - size.z}
				local pos_left = {x = rectangle1.start_x - size.x, z = rectangle1.start_z}
				local found_under = true
				local found_right = true
				local found_over = true
				local found_left = true

				-- loop 2: go through the recrangles that might intersect this building here
				for v, rectangle2 in ipairs(new_rectangles) do
					-- only if it's a rectangle on the same layer, and not the rectangle this building is next to
					if not (rectangle2.layer and entry.layer and rectangle2.layer ~= entry.layer) and v ~= w then
						-- check under
						if found_under == true and
						pos_under.x <= rectangle2.end_x and pos_under.x + size.x >= rectangle2.start_x and
						pos_under.z <= rectangle2.end_z and pos_under.z + size.z >= rectangle2.start_z then
							found_under = false
						end
						-- check right
						if found_right == true and
						pos_right.x <= rectangle2.end_x and pos_right.x + size.x >= rectangle2.start_x and
						pos_right.z <= rectangle2.end_z and pos_right.z + size.z >= rectangle2.start_z then
							found_right = false
						end
						-- check over
						if found_over == true and
						pos_over.x <= rectangle2.end_x and pos_over.x + size.x >= rectangle2.start_x and
						pos_over.z <= rectangle2.end_z and pos_over.z + size.z >= rectangle2.start_z then
							found_over = false
						end
						-- check left
						if found_left == true and
						pos_left.x <= rectangle2.end_x and pos_left.x + size.x >= rectangle2.start_x and
						pos_left.z <= rectangle2.end_z and pos_left.z + size.z >= rectangle2.start_z then
							found_left = false
						end
					end

					-- if all options failed, there's no need to keep going
					if found_under == false and found_right == false and found_over == false and found_left == false then
						break
					end
				end

				-- see which options succeeded if any (prefer under)
				-- also make sure the building would still be within the group's bounds
				if found_under == true and
				pos_under.x + size.x - 1 <= pos_end.x and pos_under.z + size.z - 1 <= pos_end.z and
				pos_under.x >= pos_start.x and pos_under.z >= pos_start.z then
					pos.x = pos_under.x
					pos.z = pos_under.z
					found_pos = true
					break
				elseif found_right == true and
				pos_right.x + size.x - 1 <= pos_end.x and pos_right.z + size.z - 1 <= pos_end.z and
				pos_right.x >= pos_start.x and pos_right.z >= pos_start.z then
					pos.x = pos_right.x
					pos.z = pos_right.z
					found_pos = true
					break
				elseif found_over == true and
				pos_over.x + size.x - 1 <= pos_end.x and pos_over.z + size.z - 1 <= pos_end.z and
				pos_over.x >= pos_start.x and pos_over.z >= pos_start.z then
					pos.x = pos_over.x
					pos.z = pos_over.z
					found_pos = true
					break
				elseif found_left == true and
				pos_left.x + size.x - 1 <= pos_end.x and pos_left.z + size.z - 1 <= pos_end.z and
				pos_left.x >= pos_start.x and pos_left.z >= pos_start.z then
					pos.x = pos_left.x
					pos.z = pos_left.z
					found_pos = true
					break
				end
			end
		end

		-- only if this building was found in the loop above
		if found_pos == true then
			local new_scheme = mapgen_buildings_draw(pos, size, angle, floors, entry)
			for v, building in ipairs(new_scheme) do
				table.insert(schemes, building)
			end

			-- add this building's corners to the rectangle list
			local rectangle = {start_x = pos.x, start_z = pos.z, end_x = pos.x + size.x - 1, end_z = pos.z + size.z - 1, layer = entry.layer}
			table.insert(new_rectangles, rectangle)
		end
	end

	-- return the structure scheme of buildings
	return schemes
end
