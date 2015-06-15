-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- spawning is delayed by this many seconds after being triggered by on_generate
-- higher values give more time for other mapgen operations to finish, decreasing the probability of structures being cut by the cavegen and potentially reducing lag
-- the delay is randomized per structure and ranges between the min and max values, to avoid clutter and the engine doing too much work at once
local MAPGEN_DELAY_MIN = 5
local MAPGEN_DELAY_MAX = 10
-- whether to keep structures in the table after they have been placed by on_generate
-- enabling this uses more resources and may cause overlapping schematics to be spawned multiple times, but reduces the chances of structures failing to spawn
local MAPGEN_KEEP_STRUCTURES = false
-- the size of the virtual cube used per town, must be larger than the radius of the biggest possible town
local MAPGEN_CUBE_SIZE_HORIZONTAL = 500
local MAPGEN_CUBE_SIZE_VERTICAL = 100

-- Local & Global values - Groups and mapgen

-- the mapgen table and groups table
mapgen_table = {}
-- stores the virtual cubes in which cities are calculated
mapgen_cubes = {}


-- Local functions

-- returns the size of this group in nodes
local function generate_group_size (id)
	local scale_horizontal = 0
	local scale_vertical = 0
	local structures = 0

	-- loop through buildings
	for i, entry in ipairs(mapgen_table[id].buildings) do
		local size = io_get_size(0, entry.name or entry.name_I)

		-- if this building has floors, use the maximum height of all segments
		local floors = calculate_random(entry.floors, true)
		if floors and floors > 0 then
			local size_start = io_get_size(0, entry.name_start)
			local size_end = io_get_size(0, entry.name_end)
			size.y = size_start.y + size_end.y + (size.y * floors)
		end

		if size ~= nil then
			local count = calculate_random(entry.count, true)

			-- add the estimated horizontal scale of buildings to group space
			scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * count

			-- if this is the tallest structure, use its vertical size plus offset value
			local height = size.y + calculate_random(entry.offset, true)
			if height > scale_vertical then
				scale_vertical = height
			end

			structures = structures + count
		end
	end

	-- loop through roads
	for i, entry in ipairs(mapgen_table[id].roads) do
		local size = io_get_size(0, entry.name or entry.name_I)

		if size ~= nil then
			local count = calculate_random(entry.count, true)

			-- add the estimated horizontal scale of roads to group space
			scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * count

			-- if this is the tallest structure, use its vertical size plus offset value
			local height = size.y + calculate_random(entry.offset, true)
			if height > scale_vertical then
				scale_vertical = height
			end

			structures = structures + count
		end
	end

	-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
	scale_horizontal = math.ceil(scale_horizontal / math.sqrt(structures))

	return scale_horizontal, scale_vertical
end

-- gets the minimum and maximum height from the perlin map
local function generate_height(minp, maxp, seed)
	local noiseparams = {
	   offset = -4,
	   scale = 20,
	   spread = {x=250, y=250, z=250},
	   seed = seed,
	   octaves = 5,
	   persist = 0.6
	}
	local size = {
		x = maxp.x - minp.x,
		y = maxp.y - minp.y,
		z = maxp.z - minp.z,
	}
	local perlin = minetest.get_perlin_map(noiseparams, size):get2dMap_flat(minp)

	local lowest = maxp.y
	local highest = minp.y
	for _, entry in ipairs(perlin) do
		if entry > highest then
			highest = math.floor(entry)
		end
		if entry < lowest then
			lowest = math.ceil(entry)
		end
	end
	return lowest, highest
end

-- returns the index of the virtual cube addressed by the given position
local function generate_cube (pos)
	local cube_minp = {
		x = math.floor(pos.x / MAPGEN_CUBE_SIZE_HORIZONTAL) * MAPGEN_CUBE_SIZE_HORIZONTAL,
		y = math.floor(pos.y / MAPGEN_CUBE_SIZE_VERTICAL) * MAPGEN_CUBE_SIZE_VERTICAL,
		z = math.floor(pos.z / MAPGEN_CUBE_SIZE_HORIZONTAL) * MAPGEN_CUBE_SIZE_HORIZONTAL,
	}
	local cube_maxp = {
		x = cube_minp.x + MAPGEN_CUBE_SIZE_HORIZONTAL - 1,
		y = cube_minp.y + MAPGEN_CUBE_SIZE_VERTICAL - 1,
		z = cube_minp.z + MAPGEN_CUBE_SIZE_HORIZONTAL - 1,
	}

	-- check if this mapblock intersects an existing cube and return it if so
	for i, cube in ipairs(mapgen_cubes) do
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

local function mapgen_generate (minp, maxp, seed)
	local pos = {
		x = (minp.x + maxp.x) / 2,
		y = (minp.y + maxp.y) / 2,
		z = (minp.z + maxp.z) / 2,
	}
	local cube_index = generate_cube(pos)

	local lowest, height = generate_height(mapgen_cubes[cube_index].minp, mapgen_cubes[cube_index].maxp, seed)

	-- if a city is not already planned for this cube, generate one
	if not mapgen_cubes[cube_index].structures then
		mapgen_cubes[cube_index].structures = {}

		-- first obtain a list of acceptable groups, then choose a random entry from it
		local groups_id = {}
		for i, entry in pairs(mapgen_table) do
			-- check probability
			if entry.probability >= math.random() then
				-- check if the height requirements are met
				if maxp.y >= entry.height_min and minp.y <= entry.height_max then
					-- add this group to the list of possible groups
					table.insert(groups_id, i)
				end
			end
		end

		if #groups_id > 0 then
			-- choose a random group from the list of possible groups
			local group_id = groups_id[math.random(1, #groups_id)]
			local group = mapgen_table[group_id]
			local group_size_horizontal, group_size_vertical = generate_group_size(group_id)
			if group_size_horizontal > MAPGEN_CUBE_SIZE_HORIZONTAL or group_size_vertical > MAPGEN_CUBE_SIZE_VERTICAL then
				-- warn if the city is larger than the cube and limit its size
				print("Mapgen Warning: Group "..group.name.." exceeds grid size ("..group_size_horizontal.." of "..MAPGEN_CUBE_SIZE_HORIZONTAL.." horizontally, "..group_size_horizontal.." of "..MAPGEN_CUBE_SIZE_VERTICAL.." vertically). Please decrease your structure count or increase the value of MAPGEN_CUBE_SIZE_*!")
				group_size_horizontal = math.min(group_size_horizontal, MAPGEN_CUBE_SIZE_HORIZONTAL)
				group_size_vertical = math.min(group_size_vertical, MAPGEN_CUBE_SIZE_VERTICAL)
			end
			mapgen_cubes[cube_index].group_size_horizontal = group_size_horizontal
			mapgen_cubes[cube_index].group_size_vertical = group_size_vertical
			mapgen_cubes[cube_index].group = group_id

			-- choose a random position within the cube
			local position = {
				x = math.random(mapgen_cubes[cube_index].minp.x, mapgen_cubes[cube_index].maxp.x - group_size_horizontal),
				y = math.min(group.height_max, math.max(group.height_min, height)),
				z = math.random(mapgen_cubes[cube_index].minp.z, mapgen_cubes[cube_index].maxp.z - group_size_horizontal),
			}

			-- get the building and road lists
			local schemes_roads, rectangles_roads = mapgen_roads_get(position, group_size_horizontal, group.roads)
			local schemes_buildings = mapgen_buildings_get(position, group_size_horizontal, rectangles_roads, group.buildings)
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
		local delay = MAPGEN_DELAY_MIN + math.random() * (MAPGEN_DELAY_MAX - MAPGEN_DELAY_MIN)
		minetest.after(delay, function()
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
					local group = mapgen_cubes[cube_index].group
					local expressions = {
						{ "POSITION_X", tostring(position.x) }, { "POSITION_Y", tostring(position.y) }, { "POSITION_Z", tostring(position.z) },
						{ "SIZE_X", tostring(size.x) }, { "SIZE_Y", tostring(size.y) }, { "SIZE_Z", tostring(size.z) },
						{ "ANGLE", tostring(angle) }, { "NUMBER", tostring(i) }, { "NAME", name }, { "GROUP", mapgen_table[group].name }
					}
					mapgen_metadata_set(position1, position2, expressions, group)

					-- remove this structure from the list
					if not MAPGEN_KEEP_STRUCTURES then
						mapgen_cubes[cube_index].structures[i] = nil
					end
				end
			end
		end)
	end
end

-- Global functions

-- the function used to define a structure group
function structures:define(def)
	table.insert(mapgen_table, def)
end

-- Minetest functions

-- run the map_generate function
minetest.register_on_generated(function(minp, maxp, seed)
	-- execute the main generate function
	mapgen_generate(minp, maxp, seed)
end)
