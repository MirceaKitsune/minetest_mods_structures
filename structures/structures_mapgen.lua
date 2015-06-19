-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Local & Global values

-- stores the structure groups
structures.mapgen_groups = {}
-- stores the virtual areas in which cities are calculated
structures.mapgen_areas = {}
-- stores the size of the virtual area
structures.mapgen_area_size = 0

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

-- returns the index of the virtual area addressed by the given position
local function generate_area (pos)
	local area_minp = {
		x = math.floor(pos.x / structures.mapgen_area_size) * structures.mapgen_area_size,
		z = math.floor(pos.z / structures.mapgen_area_size) * structures.mapgen_area_size,
	}
	local area_maxp = {
		x = area_minp.x + structures.mapgen_area_size - 1,
		z = area_minp.z + structures.mapgen_area_size - 1,
	}

	-- check if this position intersects an existing area and return it if so
	for i, area in ipairs(structures.mapgen_areas) do
		if area_maxp.x >= area.minp.x and area_minp.x <= area.maxp.x and
		area_maxp.z >= area.minp.z and area_minp.z <= area.maxp.z then
			return i
		end
	end

	-- if this position didn't intersect an existing area, create a new one
	local index = #structures.mapgen_areas + 1
	structures.mapgen_areas[index] = {
		minp = area_minp,
		maxp = area_maxp,
	}
	return index
end

-- main mapgen function, plans or spawns the town
local function mapgen_generate (minp, maxp, seed)
	local pos = {
		x = (minp.x + maxp.x) / 2,
		z = (minp.z + maxp.z) / 2,
	}
	local area_index = generate_area(pos)
	local area = structures.mapgen_areas[area_index]

	-- if a city is not already planned for this area, generate one
	if not structures.mapgen_areas[area_index].structures then
		structures.mapgen_areas[area_index].structures = {}

		-- first obtain a list of acceptable groups, then choose a random entry from it
		local groups_id = {}
		for i, entry in ipairs(structures.mapgen_groups) do
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

		if #groups_id > 0 then
			-- choose a random group from the list of possible groups
			local group_id = groups_id[math.random(1, #groups_id)]
			local group = structures.mapgen_groups[group_id]
			structures.mapgen_areas[area_index].group = group_id

			-- choose a random position within the area
			local position_start = {
				x = math.random(area.minp.x, area.maxp.x - group.size_horizontal + 1),
				z = math.random(area.minp.z, area.maxp.z - group.size_horizontal + 1),
			}
			local position_end = {
				x = position_start.x + group.size_horizontal,
				z = position_start.z + group.size_horizontal,
			}

			-- execute the group's spawn function if one is present, and abort spawning if it returns false
			if group.spawn_group and not group.spawn_group(position_start, position_end, perlin) then return end

			-- get the building and road lists
			local schemes_roads, rectangles_roads = mapgen_roads_get(position_start, position_end, group.roads)
			local schemes_buildings = mapgen_buildings_get(position_start, position_end, rectangles_roads, group.buildings)
			-- add everything to the area's structure scheme
			-- buildings should be first, so their number is represented most accurately in custom spawn functions
			structures.mapgen_areas[area_index].structures = schemes_buildings
			for _, road in ipairs(schemes_roads) do
				table.insert(area.structures, road)
			end
		end
	end

	-- if a city is planned for this area and there are valid structures, create the structures touched by this mapblock
	if area.structures then
		local group_id = area.group
		local group = structures.mapgen_groups[group_id]
		local heightmap = minetest.get_mapgen_object("heightmap")

		for i, structure in pairs(area.structures) do
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
						-- if flatness is enabled for this structure, limit its height offset from the first structure
						if structure.flatness and structure.flatness > 0 and area.first_height then
							height = calculate_lerp(height, area.first_height, structure.flatness)
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

								-- record the height of the first structure
								if not structures.mapgen_areas[area_index].first_height then
									structures.mapgen_areas[area_index].first_height = height
								end
							end
						end
					end

					-- remove this structure from the list
					if not structures.mapgen_keep_structures then
						structures.mapgen_areas[area_index].structures[i] = nil
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

	-- determine the scale of the virtual area based on the largest town
	local largest_horizontal = size_horizontal * structures.mapgen_area_multiply
	if largest_horizontal > structures.mapgen_area_size then
		structures.mapgen_area_size = largest_horizontal
	end
end

-- Minetest functions

-- run the map_generate function
minetest.register_on_generated(function(minp, maxp, seed)
	-- execute the main generate function
	mapgen_generate(minp, maxp, seed)
end)

-- save and load mapgen areas to and from file
if structures.mapgen_keep_areas then
	local file = io.open(minetest:get_worldpath().."/mapgen_areas.txt", "r")
	if file then
		local table = minetest.deserialize(file:read("*all"))
		if type(table) == "table" then
			structures.mapgen_areas = table
		else
			minetest.log("error", "Corrupted mapgen area file")
		end
		file:close()
	end

	local function save_areas()
		local file = io.open(minetest:get_worldpath().."/mapgen_areas.txt", "w")
		if file then
			file:write(minetest.serialize(structures.mapgen_areas))
			file:close()
		else
			minetest.log("error", "Can't save mapgen areas to file")
		end
	end

	local save_areas_timer = 0
	minetest.register_globalstep(function(dtime)
		save_areas_timer = save_areas_timer + dtime
		if save_areas_timer > 10 then
			save_areas_timer = 0
			save_areas()
		end
	end)

	minetest.register_on_shutdown(function()
		save_areas()
	end)
end
