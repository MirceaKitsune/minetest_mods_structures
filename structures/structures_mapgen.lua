-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Local & Global values

-- stores the nodes to generate post-spawn, used temporarily during each instance of mapgen_generate
-- format: {pos_start = {x = 0, y = 0, z = 0}, pos_end = {x = 0, y = 0, z = 0}, node = "", force = false}
local mapgen_nodes = {}

-- stores the structure groups
structures.mapgen_groups = {}
-- stores the virtual areas in which cities are calculated
structures.mapgen_areas = {}
-- stores the size of the virtual area
structures.mapgen_area_size = 0

-- Local functions

-- saves mapgen areas to the file
local function mapgen_save_areas()
	local file = io.open(minetest:get_worldpath().."/areas.txt", "w")
	if file then
		file:write(minetest.serialize(structures.mapgen_areas))
		file:close()
	else
		minetest.log("error", "Can't save mapgen areas to file")
	end
end

-- returns the size of this group in nodes
local function mapgen_group_size (id)
	-- not indexed by layers
	local scale_vertical = {size = 0}
	-- indexed by layers
	local scale_horizontal = {}

	-- loop through buildings
	for _, entry in ipairs(structures.mapgen_groups[id].buildings) do
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
			for _, layer in ipairs(entry.layers) do
				if not scale_horizontal[layer] then
					scale_horizontal[layer] = {size = 0, count = 0}
				end
				scale_horizontal[layer].size = scale_horizontal[layer].size + math.ceil((size.x + size.z) / 2) * entry.count
				scale_horizontal[layer].count = scale_horizontal[layer].count + entry.count
			end

			-- if this is the tallest structure, use its vertical size plus offset
			local height = size.y + entry.offset
			if height > scale_vertical.size then
				scale_vertical.size = height
			end
		end
	end

	-- loop through roads
	for _, entry in ipairs(structures.mapgen_groups[id].roads) do
		-- if the name is a table, choose a random schematic from it
		entry.name_I = calculate_entry(entry.name_I)
		entry.name_L = calculate_entry(entry.name_L)
		entry.name_P = calculate_entry(entry.name_P)
		entry.name_T = calculate_entry(entry.name_T)
		entry.name_X = calculate_entry(entry.name_X)
		local size = io_get_size(0, entry.name_I)

		if size ~= nil then
			-- add the estimated horizontal scale of roads
			for _, layer in ipairs(entry.layers) do
				if not scale_horizontal[layer] then
					scale_horizontal[layer] = {size = 0, count = 0}
				end
				scale_horizontal[layer].size = scale_horizontal[layer].size + math.ceil((size.x + size.z) / 2) * entry.count
				scale_horizontal[layer].count = scale_horizontal[layer].count + entry.count
			end

			-- if this is the tallest structure, use its vertical size plus offset
			local height = size.y + entry.offset
			if height > scale_vertical.size then
				scale_vertical.size = height
			end
		end
	end

	-- extract the largest layer
	local scale_vertical_largest = scale_vertical.size
	local scale_horizontal_largest = 0
	for _, scale in ipairs(scale_horizontal) do
		-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
		local size = math.ceil(scale.size / math.sqrt(scale.count))
		if size > scale_horizontal_largest then
			scale_horizontal_largest = size
		end
	end

	return scale_horizontal_largest, scale_vertical_largest
end

-- returns the index of the virtual area addressed by the given position
local function mapgen_generate_area (pos)
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
	mapgen_save_areas()
	return index
end

-- handles spawning the given structure, returns true if a schematic was imported
local function mapgen_generate_structure (structure_index, area_index, minp, maxp, heightmap, vm)
	local area = structures.mapgen_areas[area_index]
	local structure = area.structures[structure_index]
	local group_id = area.group
	local group = structures.mapgen_groups[group_id]
	-- note 1: since the I/O function doesn't include the start and end nodes, decrease start position by 1 to get the right spot
	-- note 2: the X and Z positions of the structure represent the full position, but Y only represents the offset, since we can only scan the heightmap and determine real height here
	-- determine the corners of the structure's cube, part X and Z
	local pos_start = {
		x = math.floor(structure.pos.x - 1),
		z = math.floor(structure.pos.z - 1)}
	local pos_end = {
		x = math.floor(pos_start.x + structure.size.x + 1),
		z = math.floor(pos_start.z + structure.size.z + 1)}

	-- get the height at each valid point and note down the lowest and highest
	local height_lowest = nil
	local height_highest = nil
	for px = pos_start.x, pos_end.x do
		for pz = pos_start.z, pos_end.z do
			local height = calculate_heightmap_pos(heightmap, minp, maxp, px, pz)
			if height then
				if (not height_lowest or height < height_lowest) then
					height_lowest = height
				end
				if (not height_highest or height > height_highest) then
					height_highest = height
				end
			end
		end
	end

	-- calculate the final elevation based on the results above
	-- if chaining is enabled for this structure, center it toward the position of the first structure
	-- also bound between minimum and maximum height rather than letting the structure not spawn, to prevent road segments getting cut if the road gets too high or too low
	local height_final = nil
	if height_lowest and height_highest then
		height_final = math.floor(calculate_lerp(height_lowest, height_highest, group.elevation))
	end
	if structure.link and area.chain[structure.link] then
		height_final = math.floor(calculate_lerp(height_final, area.chain[structure.link], structure.flatness))
		height_final = math.max(group.height_min, math.min(group.height_max, height_final))
	end

	-- calculate the maximum terrain noise level allowed for this structure based on its width
	-- for linked road segments, only spawn if the distance from terrain in either direction is under the tolerance level
	local tolerance = false
	if structure.flatness ~= nil then
		local tolerance_pos_low = math.floor(height_lowest - math.max(structure.size.x, structure.size.z) * group.tolerance_roads)
		local tolerance_pos_high = math.floor(height_highest + math.max(structure.size.x, structure.size.z) * group.tolerance_roads)
		tolerance = height_final >= tolerance_pos_low and height_final <= tolerance_pos_high
	else
		local tolerance_noise = math.floor(math.max(structure.size.x, structure.size.z) * group.tolerance_buildings)
		tolerance = height_highest - height_lowest <= tolerance_noise
	end

	if height_final ~= nil and tolerance == true then
		-- determine the corners of the structure's cube, part Y
		pos_start.y = math.floor(height_final + structure.pos.y - 1)
		pos_end.y = math.floor(pos_start.y + structure.size.y + 1)

		-- only spawn this structure if it's within the allowed height limits
		if height_final >= group.height_min and height_final + structure.size.y <= group.height_max + group.size_vertical then
			-- execute the structure's pre-spawn function if one is present, and abort spawning if it returns false
			local spawn = true
			if group.spawn_structure_pre then spawn = group.spawn_structure_pre(structure.name, structure_index, pos_start, pos_end, structure.size, structure.angle) end
			if spawn == nil or spawn == false then return false end

			-- import the structure
			local imported = false
			if pos_start.x <= maxp.x and pos_end.x >= minp.x and
			pos_start.y <= maxp.y and pos_end.y >= minp.y and
			pos_start.z <= maxp.z and pos_end.z >= minp.z then
				io_area_import(pos_start, pos_end, structure.angle, structure.name, structure.replacements, structure.force, false, vm)
				imported = true
			end

			if structure.base ~= nil then
				-- generate the base below this structure
				local pos_base_start = {
					x = math.floor(pos_start.x + 1),
					y = math.floor(math.max(height_lowest, group.height_min - structures.mapgen_structure_base_padding)),
					z = math.floor(pos_start.z + 1)}
				local pos_base_end = {
					x = math.floor(pos_end.x - 1),
					y = math.floor(pos_start.y),
					z = math.floor(pos_end.z - 1)}
				if pos_base_start.x <= maxp.x and pos_base_end.x >= minp.x and
				pos_base_start.y <= maxp.y and pos_base_end.y >= minp.y and
				pos_base_start.z <= maxp.z and pos_base_end.z >= minp.z then
					if pos_base_end.x > pos_base_start.x + 1 and pos_base_end.y > pos_base_start.y + 1 and pos_base_end.z > pos_base_start.z + 1 then
						table.insert(mapgen_nodes, {pos_start = pos_base_start, pos_end = pos_base_end, node = structure.base, force = structure.force})
					end
				end

				-- clear the terrain above this structure
				local pos_clear_start = {
					x = math.floor(pos_start.x + 1),
					y = math.floor(pos_end.y),
					z = math.floor(pos_start.z + 1)}
				local pos_clear_end = {
					x = math.floor(pos_end.x - 1),
					y = math.floor(math.min(height_highest, group.height_max) + structures.mapgen_structure_base_padding),
					z = math.floor(pos_end.z - 1)}
				if pos_clear_start.x <= maxp.x and pos_clear_end.x >= minp.x and
				pos_clear_start.y <= maxp.y and pos_clear_end.y >= minp.y and
				pos_clear_start.z <= maxp.z and pos_clear_end.z >= minp.z then
					if pos_clear_end.x > pos_clear_start.x + 1 and pos_clear_end.y > pos_clear_start.y + 1 and pos_clear_end.z > pos_clear_start.z + 1 then
						table.insert(mapgen_nodes, {pos_start = pos_clear_start, pos_end = pos_clear_end, node = "air", force = structure.force})
					end
				end
			end

			-- record the height of the first structure in the chain
			if structure.link and not structures.mapgen_areas[area_index].chain[structure.link] then
				structures.mapgen_areas[area_index].chain[structure.link] = height_final
			end

			-- execute the structure's post-spawn function if one is present
			if group.spawn_structure_post then group.spawn_structure_post(structure.name, structure_index, pos_start, pos_end, structure.size, structure.angle) end

			return imported
		end
	end
	return false
end

-- main mapgen function, plans or spawns the town
local function mapgen_generate (minp, maxp, seed)
	if #structures.mapgen_groups == 0 then return end

	-- clear the temporary nodes table
	mapgen_nodes = {}

	local pos = {
		x = (minp.x + maxp.x) / 2,
		z = (minp.z + maxp.z) / 2,
	}
	local area_index = mapgen_generate_area(pos)
	local area = structures.mapgen_areas[area_index]

	-- if a city is not already planned for this area, generate one
	if not area.structures then
		-- first obtain a list of acceptable groups, then choose a random entry from it
		local groups_id = {}
		for i, group in ipairs(structures.mapgen_groups) do
			-- check if this group's height intersect the vertical position of this chunk
			if minp.y <= group.height_max + group.size_vertical and maxp.y >= group.height_min then
				-- only activate this area if this chunk intersects the height of any group
				-- this prevents someone who explores an area at say height -1000 making towns never spawn at the same X and Z positions if they're later explored at height 0
				-- since the chunk is lower or higher than the position of any group, there's no risk of generating a spot in a potential town before its buildings are planned, so this is okay
				structures.mapgen_areas[area_index].structures = {}
				structures.mapgen_areas[area_index].chain = {}
				mapgen_save_areas()

				-- check if this group is located in an allowed biome
				-- only relevant if the mapgen can report biomes, assume true if not
				-- note that like all things, the biome must be detected from the first chunk that runs in this area and activates it, meaning that success might be probabilistic
				local has_biome = false
				local biomes = minetest.get_mapgen_object("biomemap")
				if not biomes or #biomes == 0 or not group.biomes or #group.biomes == 0 then
					has_biome = true
				else
					for _, biome1 in ipairs(biomes) do
						for _, biome2 in ipairs(group.biomes) do
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

			-- store the updated area with the new structures
			mapgen_save_areas()
		end
	end

	-- if a city is planned for this area and there are valid structures, create the structures touched by this mapblock
	if area.structures and area.group then
		local group_id = area.group
		local group = structures.mapgen_groups[group_id]

		-- only advance if this chunk intersects a height where buildings might exist
		if minp.y <= group.height_max + group.size_vertical and maxp.y >= group.height_min then
			local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
			local heightmap = minetest.get_mapgen_object("heightmap")

			-- spawn this structure
			-- only check the position horizontally here as vertical position is determined later
			local imported = false
			for i, structure in pairs(area.structures) do
				if structure.pos.x <= maxp.x and structure.pos.x + structure.size.x >= minp.x and
				structure.pos.z <= maxp.z and structure.pos.z + structure.size.z >= minp.z then
					local imported_this = mapgen_generate_structure(i, area_index, minp, maxp, heightmap, vm)
					imported = imported or imported_this
				end
			end

			-- loop through all nodes in this area and preform post-spawn operations
			if imported == true or #mapgen_nodes > 0 then
				local data = vm:get_data()
				local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
				local node_content_air = minetest.get_content_id("air")
				for i in area:iterp(minp, maxp) do
					local pos = area:position(i)
					local name = minetest.get_name_from_content_id(data[i])

					-- spawn additional nodes added by structures
					for _, node in ipairs(mapgen_nodes) do
						if pos.x >= node.pos_start.x and pos.x <= node.pos_end.x and
						pos.y >= node.pos_start.y and pos.y <= node.pos_end.y and
						pos.z >= node.pos_start.z and pos.z <= node.pos_end.z then
							if(data[i] == node_content_air or node.force == true) then
								data[i] = minetest.get_content_id(node.node)
							end
						end
					end

					-- we need to call on_construct for each node that has it, otherwise some nodes won't work correctly or cause a crash
					if minetest.registered_nodes[name] and minetest.registered_nodes[name].on_construct then
						minetest.registered_nodes[name].on_construct(pos)
					end
				end

				-- update vm and node data
				vm:set_data(data)
				vm:update_liquids()
				vm:calc_lighting()
				vm:write_to_map()
			end
		end
	end

	-- clear the temporary nodes table
	mapgen_nodes = {}
end

-- Global functions

-- the function used to define a structure group
function structures:register_group(def)
	table.insert(structures.mapgen_groups, def)

	-- calculate the size of this group, and store it as a set of extra properties
	local size_horizontal, size_vertical = mapgen_group_size(#structures.mapgen_groups)
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
	mapgen_generate(minp, maxp, seed)
end)

-- load mapgen areas from the file on first run
local file = io.open(minetest:get_worldpath().."/areas.txt", "r")
if file then
	local table = minetest.deserialize(file:read("*all"))
	if type(table) == "table" then
		structures.mapgen_areas = table
	else
		minetest.log("error", "Corrupted mapgen area file")
	end
	file:close()
end
