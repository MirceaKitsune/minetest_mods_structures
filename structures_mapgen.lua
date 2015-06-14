-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- file which contains the mapgen entries
local MAPGEN_FILE = "mapgen_structures.txt"
-- spawning is delayed by this many seconds after being triggered by on_generate
-- higher values give more time for other mapgen operations to finish, decreasing the probability of structures being cut by the cavegen and potentially reducing lag
local MAPGEN_DELAY = 5
-- the size of the virtual cube used per town, must be larger than the radius of the biggest possible town
local MAPGEN_CUBE_SIZE = 250

-- Local & Global values - Groups and mapgen

-- the mapgen table and groups table
mapgen_table = {}
-- stores the virtual cubes in which cities are calculated
mapgen_cubes = {}

-- Local functions - Tables and files

-- writes the mapgen file into the mapgen table
local function mapgen_to_table ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "r")
	if (file == nil) then return end

	mapgen_table = {}
	-- loop through each line
	for line in io.lines(path) do
		-- loop through each parameter in the line, ignore comments and empty lines
		if (line ~= "") and (string.sub(line, 1, 1) ~= "#") then
			local parameters = {}
			for item in line:gmatch("[^\t]+") do
				table.insert(parameters, item)
			end
			table.insert(mapgen_table, parameters)
		end
	end

	file:close()
end

-- writes the mapgen table into the mapgen file
local function mapgen_to_file ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- loop through each entry
	for i, entry1 in ipairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in ipairs(entry1) do
			s = s..entry2.."	"
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
end

-- Local functions - Generate

-- returns the size of this group in nodes
local function generate_group_scale (group)
	local scale_horizontal = 0
	local scale_vertical = 0
	local structures = 0

	-- loop through the mapgen table
	for i, entry in ipairs(mapgen_table) do
		local size = nil

		-- only if this structure belongs to the mapgen group
		if (entry[1] == group) then
			-- get size based on the type of structure
			if (entry[2] == "building") then
				size = io_get_size(0, entry[3])

				-- if this building has floors, use the maximum height of all segments
				local floors = calculate_random(entry[6], true)
				if (floors > 0) then
					local size_start = io_get_size(0, entry[3].."_(")
					local size_end = io_get_size(0, entry[3].."_)")
					size.y = size_start.y + size_end.y + (size.y * floors)
				end
			elseif (entry[2] == "road") then
				size = io_get_size(0, entry[3].."_X")
			end

			if (size ~= nil) then
				local count = calculate_random(entry[4], true)

				-- add the estimated horizontal scale of buildings to group space
				scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * count

				-- if this is the tallest structure, use its vertical size plus offset value
				local height = size.y + calculate_random(entry[5], true)
				if (height > scale_vertical) then
					scale_vertical = height
				end

				-- increase the structure count
				structures = structures + count
			end
		end
	end
	-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
	scale_horizontal = math.ceil(scale_horizontal / math.sqrt(structures))

	return scale_horizontal, scale_vertical
end

-- returns the index of the virtual cube addressed by the given position
local function generate_cube (pos)
	-- determine the position and size of the virtual cube we are accessing
	local cube_minp = {
		x = math.floor(pos.x / MAPGEN_CUBE_SIZE) * MAPGEN_CUBE_SIZE,
		y = math.floor(pos.y / MAPGEN_CUBE_SIZE) * MAPGEN_CUBE_SIZE,
		z = math.floor(pos.z / MAPGEN_CUBE_SIZE) * MAPGEN_CUBE_SIZE,
	}
	local cube_maxp = {
		x = cube_minp.x + MAPGEN_CUBE_SIZE - 1,
		y = cube_minp.y + MAPGEN_CUBE_SIZE - 1,
		z = cube_minp.z + MAPGEN_CUBE_SIZE - 1,
	}

	-- check if this mapblock intersects an existing cube and return it if so
	for i, cube in pairs(mapgen_cubes) do
		if cube_maxp.x >= cube.minp.x and cube_minp.x <= cube.maxp.x and
		cube_maxp.y >= cube.minp.y and cube_minp.y <= cube.maxp.y and
		cube_maxp.z >= cube.minp.z and cube_minp.z <= cube.maxp.z then
			return i
		end
	end

	-- if this mapblock didn't intersect an existing cube, create a new one
	local index = #mapgen_cubes + 1
	mapgen_cubes[index] = {
		minp = cube_minp,
		maxp = cube_maxp,
	}
	return index
end

local function mapgen_generate (minp, maxp)
	local pos = {
		x = (minp.x + maxp.x) / 2,
		y = (minp.y + maxp.y) / 2,
		z = (minp.z + maxp.z) / 2,
	}
	-- get the index of the cube this mapblock is addressing
	local cube_index = generate_cube(pos)

	-- if a city is not already planned for this cube, generate one
	if not mapgen_cubes[cube_index].structures then
		mapgen_cubes[cube_index].structures = {}

		-- first obtain a list of acceptable groups, then choose a random entry from it
		-- settings: group [1], type [2], trigger nodes [3], filler nodes [4], height_min [5], height_max [6], probability [7]
		local groups = {}
		for i, entry in pairs(mapgen_table) do
			if (entry[2] == "settings") then
				-- check if the probability succeeds
--				if tonumber(entry[7]) >= math.random() then
					-- check if the height requirements are met
--					if (pos.y <= tonumber(entry[6])) and (pos.y >= tonumber(entry[5])) then
						-- check if any of the necessary trigger nodes exist
						local nodes = minetest.find_nodes_in_area_under_air(minp, maxp, entry[3]:gmatch("%S+"))
--						if nodes and #nodes > 0 then
							-- add this group to the list of possible groups
							table.insert(groups, entry[1])
--						end
--					end
--				end
			end
		end

		if #groups > 0 then
			-- choose a random group from the list of possible groups
			local group = groups[math.random(1, #groups)]
			local group_size = generate_group_scale(group)
			if group_size > MAPGEN_CUBE_SIZE then
				-- warn if the city is larger than the cube and limit its size
				print("Mapgen Warning: Group "..group.." exceeds grid size ("..group_size.." / "..MAPGEN_CUBE_SIZE.." nodes). Please decrease your structure count or increase the value of MAPGEN_CUBE_SIZE!")
				group_size = MAPGEN_CUBE_SIZE
			end
			mapgen_cubes[cube_index].group = group

			-- get the building and road lists
			local schemes_roads, rectangles_roads = mapgen_roads_get(pos, group_size, group)
			local schemes_buildings = mapgen_buildings_get(pos, group_size, rectangles_roads, group)
			-- add everything to the cube's structure scheme
			-- buildings should be first, so they're represented most accurately by metadata numbers
			mapgen_cubes[cube_index].structures = schemes_buildings
			for w, road in ipairs(schemes_roads) do
				table.insert(mapgen_cubes[cube_index].structures, road)
			end
		end
	end

	-- if a city is planned for this cube and there are valid structures, create the structures touched by this mapblock
	if mapgen_cubes[cube_index].structures then
		-- schedule the function to execute after the spawn delay
		minetest.after(MAPGEN_DELAY, function()
			-- TODO: Clear areas within the group's radius here, and apply the floor (filler node)

			-- schematics: name [1], position [2], angle [3], size [4]
			for i, structure in pairs(mapgen_cubes[cube_index].structures) do
				local name = structure[1]
				local position = structure[2]
				local angle = structure[3]
				local size = structure[4]
				if position.x >= minp.x and position.x <= maxp.x and
				position.y >= minp.y and position.y <= maxp.y and
				position.z >= minp.z and position.z <= maxp.z then
					-- determine the corners of the structure's cube
					-- since the I/O function doesn't include the start and end nodes themselves, decrease start position by 1 to get the right spot
					local position1 = { x = position.x - 1, y = position.y - 1, z = position.z - 1 }
					local position2 = { x = position.x + size.x, y = position.y + size.y, z = position.z + size.z }

					-- import the structure
					io_area_import(position1, position2, angle, name, false)

					-- apply metadata
					local expressions = {
						{ "POSITION_X", tostring(position.x) }, { "POSITION_Y", tostring(position.y) }, { "POSITION_Z", tostring(position.z) },
						{ "SIZE_X", tostring(size.x) }, { "SIZE_Y", tostring(size.y) }, { "SIZE_Z", tostring(size.z) },
						{ "ANGLE", tostring(angle) }, { "NUMBER", tostring(i) }, { "NAME", name }, { "GROUP", mapgen_cubes[cube_index].group }
					}
					mapgen_metadata_set(position1, position2, expressions, structure[1])

					-- remove this structure from the list
					mapgen_cubes[cube_index].structures[i] = nil
				end
			end
		end)
	end
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, mapgen_to_table)

-- run the map_generate function
minetest.register_on_generated(function(minp, maxp, seed)
	-- schedule the main generate function
	mapgen_generate(minp, maxp)
end)
