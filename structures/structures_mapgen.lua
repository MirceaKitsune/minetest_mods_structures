-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Local & Global values

-- stores the structure groups
structures.mapgen_groups = {}
-- stores the virtual cubes in which cities are calculated
structures.mapgen_cubes = {}
-- stores the size of the virtual cube
structures.mapgen_cube_horizontal = 0
structures.mapgen_cube_vertical = 0

-- Local functions

-- returns the size of this group in nodes
local function group_size (id)
	local scale_horizontal = 0
	local scale_vertical = 0
	local num = 0

	-- loop through buildings
	for i, entry in ipairs(structures.mapgen_groups[id].buildings) do
		-- if the name is a table, choose a random schematic from it
		entry.name = calculate_entry(entry.name)
		entry.name_start = calculate_entry(entry.name_start)
		entry.name_end = calculate_entry(entry.name_end)
		local size = io_get_size(0, entry.name)

		-- if this building has floors, use the maximum height of all segments
		if entry.floors_min and entry.floors_max and entry.floors_max > 0 then
			local size_start = io_get_size(0, entry.name_start)
			local size_end = io_get_size(0, entry.name_end)
			size.y = size_start.y + size_end.y + size.y * (entry.floors_max - 1)
		end

		if size ~= nil then
			-- add the estimated horizontal scale of buildings
			scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * entry.count

			-- if this is the tallest structure, use its vertical size plus offset
			local height = size.y + entry.offset
			if height > scale_vertical then
				scale_vertical = height
			end

			num = num + entry.count
		end
	end

	-- loop through roads
	for i, entry in ipairs(structures.mapgen_groups[id].roads) do
		-- if the name is a table, choose a random schematic from it
		entry.name_I = calculate_entry(entry.name_I)
		entry.name_L = calculate_entry(entry.name_L)
		entry.name_P = calculate_entry(entry.name_P)
		entry.name_T = calculate_entry(entry.name_T)
		entry.name_X = calculate_entry(entry.name_X)
		local size = io_get_size(0, entry.name_I)

		if size ~= nil then
			-- add the estimated horizontal scale of roads
			scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * entry.count

			-- if this is the tallest structure, use its vertical size plus offset
			local height = size.y + entry.offset
			if height > scale_vertical then
				scale_vertical = height
			end

			num = num + entry.count
		end
	end

	-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
	scale_horizontal = math.ceil(scale_horizontal / math.sqrt(num))

	return scale_horizontal, scale_vertical
end

-- returns the index of the virtual cube addressed by the given position
local function generate_cube (pos)
	local cube_minp = {
		x = math.floor(pos.x / structures.mapgen_cube_horizontal) * structures.mapgen_cube_horizontal,
		y = math.floor(pos.y / structures.mapgen_cube_vertical) * structures.mapgen_cube_vertical,
		z = math.floor(pos.z / structures.mapgen_cube_horizontal) * structures.mapgen_cube_horizontal,
	}
	local cube_maxp = {
		x = cube_minp.x + structures.mapgen_cube_horizontal - 1,
		y = cube_minp.y + structures.mapgen_cube_vertical - 1,
		z = cube_minp.z + structures.mapgen_cube_horizontal - 1,
	}

	-- check if this position intersects an existing cube and return it if so
	for i, cube in ipairs(structures.mapgen_cubes) do
		if cube_maxp.x >= cube.minp.x and cube_minp.x <= cube.maxp.x and
		cube_maxp.y >= cube.minp.y and cube_minp.y <= cube.maxp.y and
		cube_maxp.z >= cube.minp.z and cube_minp.z <= cube.maxp.z then
			return i
		end
	end

	-- if this position didn't intersect an existing cube, create a new one
	local index = #structures.mapgen_cubes + 1
	structures.mapgen_cubes[index] = {
		minp = cube_minp,
		maxp = cube_maxp,
	}
	return index
end

-- main mapgen function, plans or spawns the town
local function mapgen_generate (minp, maxp, seed)
	local pos = {
		x = (minp.x + maxp.x) / 2,
		y = (minp.y + maxp.y) / 2,
		z = (minp.z + maxp.z) / 2,
	}
	local cube_index = generate_cube(pos)
	local cube = structures.mapgen_cubes[cube_index]

	-- if a city is not already planned for this cube, generate one
	if not structures.mapgen_cubes[cube_index].structures then
		structures.mapgen_cubes[cube_index].structures = {}

		-- first obtain a list of acceptable groups, then choose a random entry from it
		local groups_id = {}
		for i, entry in ipairs(structures.mapgen_groups) do
			-- check if this area is located at the correct height
			if entry.height_min <= cube.maxp.y and entry.height_max >= cube.minp.y then
				-- check if this area is located in the corect biome
				-- only relevant if the mapgen can report biomes, assume true if not
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
			local group = structures.mapgen_groups[group_id]
			structures.mapgen_cubes[cube_index].group = group_id

			-- choose a random position within the cube
			local position_start = {
				x = math.random(cube.minp.x, cube.maxp.x - group.size_horizontal + 1),
				y = cube.minp.y,
				z = math.random(cube.minp.z, cube.maxp.z - group.size_horizontal + 1),
			}
			local position_end = {
				x = position_start.x + group.size_horizontal,
				y = position_start.y + group.size_vertical,
				z = position_start.z + group.size_horizontal,
			}

			-- execute the group's spawn function if one is present, and abort spawning if it returns false
			if group.spawn_group and not group.spawn_group(position_start, position_end, perlin) then return end

			-- get the building and road lists
			local schemes_roads, rectangles_roads = mapgen_roads_get(position_start, position_end, group.roads)
			local schemes_buildings = mapgen_buildings_get(position_start, position_end, rectangles_roads, group.buildings)
			-- add everything to the cube's structure scheme
			-- buildings should be first, so their number is represented most accurately in custom spawn functions
			structures.mapgen_cubes[cube_index].structures = schemes_buildings
			for _, road in ipairs(schemes_roads) do
				table.insert(cube.structures, road)
			end
		end
	end

	-- if a city is planned for this cube and there are valid structures, create the structures touched by this mapblock
	if cube.structures then
		local group_id = cube.group
		local group = structures.mapgen_groups[group_id]
		local heightmap = minetest.get_mapgen_object("heightmap")
		local last_height = {}

		for i, structure in pairs(cube.structures) do
			if structure.pos.x >= minp.x and structure.pos.x <= maxp.x and
			structure.pos.y >= minp.y and structure.pos.y <= maxp.y and
			structure.pos.z >= minp.z and structure.pos.z <= maxp.z then
				-- schedule structure creation to execute after the spawn delay
				minetest.after(structures.mapgen_delay * i, function()
					-- note 1: since the I/O function doesn't include the start and end nodes, decrease start position by 1 to get the right spot
					-- note 2: the X and Z positions of the structure represent the full position, but Y only represents the offset, since we can only scan the heightmap and determine real height here
					-- determine the corners of the structure's cube, X and Z
					local pos_start = {x = structure.pos.x - 1, z = structure.pos.z - 1}
					local pos_end = {x = pos_start.x + structure.size.x + 1, z = pos_start.z + structure.size.z + 1}
					local height = calculate_heightmap_pos(heightmap, minp, maxp, math.floor((pos_start.x + pos_end.x) / 2), math.floor((pos_start.z + pos_end.z) / 2))
					if height then
						-- if chaining is enabled for this structure, limit its height offset in relation to other structures of its type
						if structure.chain and last_height[structure.name] then
							if height + last_height[structure.name] > height + structure.chain then
								height = last_height[structure.name] + structure.chain
							elseif height - last_height[structure.name] < height - structure.chain then
								height = last_height[structure.name] - structure.chain
							end
						end
						-- determine the corners of the structure's cube, Y
						pos_start.y = height + structure.pos.y - 1
						pos_end.y = pos_start.y + structure.size.y + 1

						-- only spawn this structure if it's within the allowed height limits
						if height >= group.height_min and height <= group.height_max then
							-- execute the structure's pre-spawn function if one is present, and abort spawning if it returns false
							local spawn = true
							if group.spawn_structure_pre then spawn = group.spawn_structure_pre(structure.name, i, pos_start, pos_end, structure.size, structure.angle) end
							if spawn then
								-- import the structure
								io_area_import(pos_start, pos_end, structure.angle, structure.name, false)

								-- execute the structure's post-spawn function if one is present
								if group.spawn_structure_post then group.spawn_structure_post(structure.name, i, pos_start, pos_end, structure.size, structure.angle) end

								-- record the average height of this structure type
								last_height[structure.name] = height
							end
						end
					end

					-- remove this structure from the list
					if not structures.mapgen_keep_structures then
						structures.mapgen_cubes[cube_index].structures[i] = nil
					end
				end)
			end
		end
	end
end

-- Global functions

-- the function used to define a structure group
function structures:register_group(def)
	table.insert(structures.mapgen_groups, def)

	-- calculate the size of this group, and store it as a set of extra properties
	local size_horizontal, size_vertical = group_size(#structures.mapgen_groups)
	structures.mapgen_groups[#structures.mapgen_groups].size_horizontal = size_horizontal
	structures.mapgen_groups[#structures.mapgen_groups].size_vertical = size_vertical

	-- determine the scale of the virtual cube based on the largest town
	local largest_horizontal = size_horizontal * structures.mapgen_cube_multiply_horizontal
	if largest_horizontal > structures.mapgen_cube_horizontal then
		structures.mapgen_cube_horizontal = largest_horizontal
	end
	local largest_vertical = size_vertical * structures.mapgen_cube_multiply_vertical
	if largest_vertical > structures.mapgen_cube_vertical then
		structures.mapgen_cube_vertical = largest_vertical
	end
end

-- Minetest functions

-- run the map_generate function
minetest.register_on_generated(function(minp, maxp, seed)
	-- execute the main generate function
	mapgen_generate(minp, maxp, seed)
end)

-- save and load mapgen cubes to and from file
if structures.mapgen_keep_cubes then
	local file = io.open(minetest:get_worldpath().."/structures.mapgen_cubes.txt", "r")
	if file then
		local table = minetest.deserialize(file:read("*all"))
		if type(table) == "table" then
			structures.mapgen_cubes = table
		else
			minetest.log("error", "Corrupted mapgen cube file")
		end
		file:close()
	end

	local function save_cubes()
		local file = io.open(minetest:get_worldpath().."/structures.mapgen_cubes.txt", "w")
		if file then
			file:write(minetest.serialize(structures.mapgen_cubes))
			file:close()
		else
			minetest.log("error", "Can't save mapgen cubes to file")
		end
	end

	local save_cubes_timer = 0
	minetest.register_globalstep(function(dtime)
		save_cubes_timer = save_cubes_timer + dtime
		if save_cubes_timer > 10 then
			save_cubes_timer = 0
			save_cubes()
		end
	end)

	minetest.register_on_shutdown(function()
		save_cubes()
	end)
end
