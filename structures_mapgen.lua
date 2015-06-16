-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- spawning is delayed by this many seconds per structure
-- higher values give more time for other mapgen operations to finish and reduce lag, but cause towns to appear more slowly
-- example: if the delay is 0.1 and a town has 1000 structures, it will take the entire town 100 seconds to spawn
local MAPGEN_DELAY = 0.25
-- whether to keep structures in the table after they have been placed by on_generate
-- enabling this uses more resources and may cause overlapping schematics to be spawned multiple times, but reduces the chances of structures failing to spawn
local MAPGEN_KEEP_STRUCTURES = false
-- multiply the size of the virtual cube (determined by the largest town) by this amount
-- larger values decrease town frequency, but give more room for towns to be sorted in
local MAPGEN_CUBE_MULTIPLY_HORIZONTAL = 1
local MAPGEN_CUBE_MULTIPLY_VERTICAL = 2

-- Local & Global values - Groups and mapgen

-- the mapgen table and groups table
mapgen_table = {}
-- stores the virtual cubes in which cities are calculated
mapgen_cubes = {}
-- stores the size of the largest town in order to determine the virtual cube
mapgen_cube_horizontal = 0
mapgen_cube_vertical = 0

-- Local functions

-- returns the size of this group in nodes
local function group_size (id)
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

-- gets the perlin map and its minimum and maximum height
local function generate_perlin(minp, maxp, seed, noiseparams)
	if not noiseparams.seed then
		noiseparams.seed = seed
	end
	local pos = {
		x = minp.x,
		y = minp.z,
	}
	local size = {
		x = maxp.x - minp.x,
		y = maxp.z - minp.z,
	}
	local perlin = minetest.get_perlin_map(noiseparams, size):get2dMap(pos)
	return perlin
end

-- returns the index of the virtual cube addressed by the given position
local function generate_cube (pos)
	local cube_minp = {
		x = math.floor(pos.x / mapgen_cube_horizontal) * mapgen_cube_horizontal,
		y = math.floor(pos.y / mapgen_cube_vertical) * mapgen_cube_vertical,
		z = math.floor(pos.z / mapgen_cube_horizontal) * mapgen_cube_horizontal,
	}
	local cube_maxp = {
		x = cube_minp.x + mapgen_cube_horizontal - 1,
		y = cube_minp.y + mapgen_cube_vertical - 1,
		z = cube_minp.z + mapgen_cube_horizontal - 1,
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

	-- if a city is not already planned for this cube, generate one
	if not mapgen_cubes[cube_index].structures then
		mapgen_cubes[cube_index].structures = {}

		-- first obtain a list of acceptable groups, then choose a random entry from it
		local groups_id = {}
		for i, entry in pairs(mapgen_table) do
			-- check if the minimum and maximum height generated by the perlin noise is within this cube
			local height_min = entry.noiseparams.offset
			local height_max = entry.noiseparams.offset + entry.noiseparams.scale + entry.size_vertical
			if height_min >= mapgen_cubes[cube_index].minp.y and height_max <= mapgen_cubes[cube_index].maxp.y then
				-- check if this area is located in the corect biome
				local has_biome = false
				local biomes = minetest.get_mapgen_object("biomemap")
				if not biomes or #biomes == 0 or not entry.biomes or #entry.biomes == 0 then
					has_biome = true
				else
					for _, biome1 in ipairs(biomes) do
						for _, biome2 in ipairs(entry.biomes) do
							if biome1 == biome2 then
								has_biome = true
							end
							-- stop looping if we found a matching biome
							if has_biome then break end
						end
						-- stop looping if we found a matching biome
						if has_biome then break end
					end
				end
				if has_biome then
					-- add this group to the list of possible groups
					table.insert(groups_id, i)
				end
			end
		end

		if #groups_id > 0 then
			-- choose a random group from the list of possible groups
			local group_id = groups_id[math.random(1, #groups_id)]
			local group = mapgen_table[group_id]
			mapgen_cubes[cube_index].group = group_id

			-- check probability
			if group.probability >= math.random() then
				-- choose a random position within the cube
				local position_start = {
					x = math.random(mapgen_cubes[cube_index].minp.x, mapgen_cubes[cube_index].maxp.x - group.size_horizontal + 1),
					y = mapgen_cubes[cube_index].minp.y,
					z = math.random(mapgen_cubes[cube_index].minp.z, mapgen_cubes[cube_index].maxp.z - group.size_horizontal + 1),
				}
				local position_end = {
					x = position_start.x + group.size_horizontal,
					y = position_start.y + group.size_vertical,
					z = position_start.z + group.size_horizontal,
				}

				-- get the perlin noise used to determine structure height
				local perlin = generate_perlin(position_start, position_end, seed, group.noiseparams)
				-- determine minimum and maximum height
				local height_min = group.noiseparams.offset
				local height_max = group.noiseparams.offset + group.noiseparams.scale
				local center = math.floor((height_min + height_max) / 2)

				-- get the building and road lists
				local schemes_roads, rectangles_roads = mapgen_roads_get(position_start, position_end, center, perlin, group.roads)
				local schemes_buildings = mapgen_buildings_get(position_start, position_end, center, perlin, rectangles_roads, group.buildings)
				-- add everything to the cube's structure scheme
				-- buildings should be first, so they're represented most accurately by metadata numbers
				mapgen_cubes[cube_index].structures = schemes_buildings
				for w, road in ipairs(schemes_roads) do
					table.insert(mapgen_cubes[cube_index].structures, road)
				end
			end
		end
	end

	-- if a city is planned for this cube and there are valid structures, create the structures touched by this mapblock
	if mapgen_cubes[cube_index].structures then
		-- schematics: name [1], position [2], angle [3], size [4]
		for i, structure in pairs(mapgen_cubes[cube_index].structures) do
			-- schedule the function to execute after the spawn delay
			minetest.after(MAPGEN_DELAY * i, function()
				local name = structure[1]
				local position = structure[2]
				local angle = structure[3]
				local size = structure[4]
				if position.x >= minp.x and position.x <= maxp.x and
				position.y >= minp.y and position.y <= maxp.y and
				position.z >= minp.z and position.z <= maxp.z then
					-- determine the corners of the structure's cube
					-- since the I/O function doesn't include the start and end nodes themselves, decrease start position by 1 to get the right spot
					local position1 = {x = position.x - 1, y = position.y - 1, z = position.z - 1}
					local position2 = {x = position.x + size.x, y = position.y + size.y, z = position.z + size.z}

					-- import the structure
					io_area_import(position1, position2, angle, name, false)

					-- apply metadata
					local group = mapgen_cubes[cube_index].group
					local expressions = {
						{"POSITION_X", tostring(position.x)}, {"POSITION_Y", tostring(position.y)}, {"POSITION_Z", tostring(position.z)},
						{"SIZE_X", tostring(size.x)}, {"SIZE_Y", tostring(size.y)}, {"SIZE_Z", tostring(size.z)},
						{"ANGLE", tostring(angle)}, {"NUMBER", tostring(i)}, {"NAME", name}, {"GROUP", mapgen_table[group].name}
					}
					mapgen_metadata_set(position1, position2, expressions, group)

					-- remove this structure from the list
					if not MAPGEN_KEEP_STRUCTURES then
						mapgen_cubes[cube_index].structures[i] = nil
					end
				end
			end)
		end
	end
end

-- Global functions

-- the function used to define a structure group
function structures:define(def)
	table.insert(mapgen_table, def)

	-- calculate the size of this group, and store it as a set of extra properties
	local size_horizontal, size_vertical = group_size(#mapgen_table)
	mapgen_table[#mapgen_table].size_horizontal = size_horizontal
	mapgen_table[#mapgen_table].size_vertical = size_vertical

	-- determine the scale of the virtual cube based on the largest town
	-- for height, also account the scale of the perlin map
	local largest_horizontal = size_horizontal * MAPGEN_CUBE_MULTIPLY_HORIZONTAL
	if largest_horizontal > mapgen_cube_horizontal then
		mapgen_cube_horizontal = largest_horizontal
	end
	local largest_vertical = (mapgen_table[#mapgen_table].noiseparams.scale + size_vertical) * MAPGEN_CUBE_MULTIPLY_VERTICAL
	if largest_vertical > mapgen_cube_vertical then
		mapgen_cube_vertical = largest_vertical
	end
end

-- Minetest functions

-- run the map_generate function
minetest.register_on_generated(function(minp, maxp, seed)
	-- execute the main generate function
	mapgen_generate(minp, maxp, seed)
end)
