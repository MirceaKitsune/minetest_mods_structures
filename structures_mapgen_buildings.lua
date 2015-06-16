-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Local functions - Draw

-- obtains the position and rotation of all building parts
local function draw (names, pos, size, angle, floors)
	local new_scheme = {}

	if floors == 0 then
		-- insert the building into the schemes table
		-- types: 1 = normal & center, 2 = start, 3 = end
		table.insert(new_scheme, {names[1], pos, angle, size} )
	else
		local size_start = {x = size.x, y = size.y_start, z = size.z}
		local size_middle = {x = size.x, y = size.y, z = size.z}
		local size_end = {x = size.x, y = size.y_end, z = size.z}

		-- add the start segment to the schemes table
		table.insert(new_scheme, {names[2], pos, angle, size_start} )

		-- loop through the middle segments
		local height_middle_start = pos.y + size_start.y
		local height_middle_end = height_middle_start + (size_middle.y * (floors - 1))
		for height = height_middle_start, height_middle_end, size_middle.y do
			-- add the middle segments to the schemes table
			local pos_middle = {x = pos.x, y = height, z = pos.z}
			table.insert(new_scheme, {names[1], pos_middle, angle, size_middle} )
		end

		-- add the start segment to the schemes table
		local height_end = height_middle_end + size_middle.y
		local pos_end = {x = pos.x, y = height_end, z = pos.z}
		table.insert(new_scheme, {names[3], pos_end, angle, size_end} )
	end

	return new_scheme
end

-- Global functions - Buildings

-- analyzes buildings in the mapgen table and acts accordingly
function mapgen_buildings_get (pos_start, pos_end, center, perlin, boxes, buildings)
	local schemes = {}
	-- store the bounding boxes of areas to avoid
	-- if the function is called without any boxes (eg: roads), add a point in the center
	local new_rectangles = boxes
	if #new_rectangles == 0 then
		local center_x = math.floor((pos_start.x + pos_end.x) / 2)
		local center_z = math.floor((pos_start.z + pos_end.z) / 2)
		table.insert(new_rectangles, {start_x = center_x, start_z = center_z, end_x = center_x, end_z = center_z})
	end

	-- although the group size tries to match the number of structures, buildings that spawn first may still decrease the probability of following buildings
	-- so instead of looping through the buildings table directly, create a list of indexes and randomize it, then loop through that
	local instances = {}
	-- first generate a list of indexes for all buildings, an entry for each time a building will be spawned
	for i, entry in ipairs(buildings) do
		-- spawn this building based on its probability
		local count = calculate_random(entry.count, false)
		for x = 1, count do
			table.insert(instances, i)
		end
	end
	-- now randomize the table so building instances won't be spawned in an uniform order
	calculate_table_shuffle(instances)

	for i, instance in ipairs(instances) do
		local building = buildings[instance]

		-- get number of floors this building has
		local floors = calculate_random(building.floors, false)

		-- choose angle (0, 90, 180, 270)
		-- TODO: Find a way to orient buildings uniformly, difficult because position is determined later but we already need to know angle + size for position
		local angle = 90 * math.random(0, 3)

		-- obtain this building's size
		local size = io_get_size(angle, building.name)
		if floors and floors > 0 then
			local size_start = io_get_size(angle, building.name_start)
			local size_end = io_get_size(angle, building.name_end)

			-- the height of each segment might be different, so store that of the start and end segments separately
			size.y_start = size_start.y
			size.y_end = size_end.y

			-- make sure each building segment has the same size horizontally
			if size.x ~= size_start.x or size.z ~= size_start.z or
			size.x ~= size_end.z or size.x ~= size_end.z then
				print("Structure Mapgen Error: Two segments of the same building type are of different sizes, skipping this building.")
				size = nil
				break
			end
		end

		if size ~= nil then
			-- used later to check if a position was found
			local found_pos = false

			-- height will be determined later
			local location = {x = pos_start.x, z = pos_start.z}

			-- determine the X and Z position of this building
			-- first shuffle the rectangles table, to avoid a fixed search order
			calculate_table_shuffle(new_rectangles)
			-- loop 1: go through the recrangles we want to place this building next to
			for w, rectangle1 in ipairs(new_rectangles) do
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
					-- don't check the rectangle this building is next to
					if v ~= w then
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
					location.x = pos_under.x
					location.z = pos_under.z
					found_pos = true
					break
				elseif found_right == true and
				pos_right.x + size.x - 1 <= pos_end.x and pos_right.z + size.z - 1 <= pos_end.z and
				pos_right.x >= pos_start.x and pos_right.z >= pos_start.z then
					location.x = pos_right.x
					location.z = pos_right.z
					found_pos = true
					break
				elseif found_over == true and
				pos_over.x + size.x - 1 <= pos_end.x and pos_over.z + size.z - 1 <= pos_end.z and
				pos_over.x >= pos_start.x and pos_over.z >= pos_start.z then
					location.x = pos_over.x
					location.z = pos_over.z
					found_pos = true
					break
				elseif found_left == true and
				pos_left.x + size.x - 1 <= pos_end.x and pos_left.z + size.z - 1 <= pos_end.z and
				pos_left.x >= pos_start.x and pos_left.z >= pos_start.z then
					location.x = pos_left.x
					location.z = pos_left.z
					found_pos = true
					break
				end
			end

			-- determine height from the perlin map
			local height = calculate_perlin_height(perlin, pos_end.x - location.x, pos_end.z - location.z, center, building.alignment)
			local offset = calculate_random(building.offset, false)
			location.y = height + offset

			-- only if this building was found in the loop above
			if found_pos == true then
				names = {}
				names[1] = building.name
				names[2] = building.name_start
				names[3] = building.name_end
				new_scheme = draw(names, location, size, angle, floors)
				for v, building in ipairs(new_scheme) do
					table.insert(schemes, building)
				end

				-- add this building's corners to the rectangle list
				local rectangle = {start_x = location.x, start_z = location.z, end_x = location.x + size.x - 1, end_z = location.z + size.z - 1}
				table.insert(new_rectangles, rectangle)
			end
		end
	end

	-- return the structure scheme of buildings
	return schemes
end
