-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings

-- file which contains the mapgen entries
local MAPGEN_FILE = "mapgen.txt"
-- probability of a structure group to spawn, per piece of world being generated
local MAPGEN_GROUP_PROBABILITY = 0.2
-- distance that groups must have from each other in order to spawn
-- high values decrease the risk of groups spawning into each other as well as mapgen stress, but means rarer structures
local MAPGEN_GROUP_DISTANCE = 200
-- amount of origins to maintain in the group avoidance list
-- low values increase the risk of groups being ignored from distance calculations, high values store more data
local MAPGEN_GROUP_DISTANCE_COUNT = 10
-- amount by which structures inherit the probability of previously structures, to compensate for them taking up space
-- must be balanced so that the probability of each structure tends to be respected despite spawn order in the file
local MAPGEN_STRUCTURE_PROBABILITY_COMPENSATE = 0.5
-- each structure is delayed by this many seconds in a probability loop
-- high values cause structures to spawn more slowly, low values deal more stress to the CPU and encourage incomplete spawns
local MAPGEN_STRUCTURE_DELAY = 1
-- amount by which the the probability and separation of each structure from other structures influences spawn radius
-- must be balanced so the higher probability and distance, the farther structures can spawn while maintaining their density
local MAPGEN_STRUCTURE_DENSITY = 1
-- number of steps (in nodes) by which structures avoid each other when searching for an origin
-- high values mean less accuracy, low values mean longer costly loops
local MAPGEN_STRUCTURE_AVOID_STEPS = 5
-- create a floor under each structure by this many nodes to fill empty space
-- high values cover longer areas which looks better, but also mean adding more nodes and doing more costly checks
local MAPGEN_STRUCTURE_FILL = 20

-- Local functions - Table

-- the mapgen table and groups table
local mapgen_table = {}
local mapgen_groups = {}

-- updates the groups table with all mapgen groups
local function update_groups ()
	mapgen_groups = {}
	for i, v in ipairs(mapgen_table) do
		local found = false
		for ii, w in ipairs(mapgen_groups) do
			if (v[5] == w) then
				found = true
				break
			end
		end

		if (found == false) then
			table.insert(mapgen_groups, v[5])
		end
	end

	return false
end

-- writes the mapgen file into the mapgen table
local function file_to_table ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "r")
	if (file == nil) then return end

	mapgen_table = {}
	-- loop through each line
	for line in io.lines(path) do
		local parameters = {}
		-- loop through each parameter in the line
		for item in string.gmatch(line, "%S+") do
			table.insert(parameters, item)
		end
		table.insert(mapgen_table, parameters)
	end

	file:close()
	update_groups()
end

-- writes the mapgen table into the mapgen file
local function table_to_file ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- loop through each entry
	for i, entry1 in ipairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in ipairs(entry1) do
			s = s..entry2.." "
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
	update_groups()
end

-- Local functions - Spawn

-- store the origin of each group in the group avoidance list
local group_avoid = {}

-- adds entries to the group avoidance list
local function group_avoid_add (pos)
	-- if the maximum amount of group avoid origins was reached, delete the oldest one
	if (table.getn(group_avoid) >= MAPGEN_GROUP_DISTANCE_COUNT) then
		table.remove(group_avoid, 1)
	end

	table.insert(group_avoid, pos)
end

-- checks if a given distance is far enough from all group avoidance origins
local function group_avoid_check (pos)
	for i, org in ipairs(group_avoid) do
		local dist = calculate_distance(pos, org)
		if (dist.x < MAPGEN_GROUP_DISTANCE) and (dist.y < MAPGEN_GROUP_DISTANCE) and (dist.z < MAPGEN_GROUP_DISTANCE) then
			return false
		end
	end

	return true
end

-- naturally spawns a structure with the given parameters
local function spawn_structure (filename, pos, angle, size, node)
	-- choose center on X and Z axes and bottom on Y
	local pos1 = { x = pos.x - size.x / 2, y = pos.y, z = pos.z - size.z / 2 }
	local pos2 = { x = pos.x + size.x / 2, y = pos.y + size.y, z = pos.z + size.z / 2 }
	io_area_import(pos1, pos2, angle, filename)

	-- we spawned the structure on a suitable node, but what if it was the top of a peak?
	-- to avoid parts of the building left floating, cover everything until all 4 corners touch the ground
	for cover_y = pos.y - 1, pos.y - MAPGEN_STRUCTURE_FILL, -1 do
		local c1 = { x = pos1.x, y = cover_y, z = pos1.z }
		local c2 = { x = pos1.x, y = cover_y, z = pos2.z }
		local c3 = { x = pos2.x, y = cover_y, z = pos1.z }
		local c4 = { x = pos2.x, y = cover_y, z = pos2.z }
		local n1 = minetest.env:get_node(c1)
		local n2 = minetest.env:get_node(c2)
		local n3 = minetest.env:get_node(c3)
		local n4 = minetest.env:get_node(c4)

		if (n1.name == "air") or (n2.name == "air") or (n3.name == "air") or (n4.name == "air") then
			for cover_x = pos1.x, pos2.x do
				for cover_z = pos1.z, pos2.z do
					pos_fill = { x = cover_x, y = cover_y, z = cover_z }
					node_fill = minetest.env:get_node(pos_fill)
					if (node_fill.name ~= node) then
						minetest.env:add_node(pos_fill, { name = node })
					end
				end
			end
		else
			break
		end
	end
end

-- finds a structure group to spawn and calculates each entry's properties
local function spawn_group (minp, maxp)
	-- test group probability for this piece of world
	if(math.random() > MAPGEN_GROUP_PROBABILITY) then return end

	-- choose center on the X and Z axes and top on Y
	local pos = { }
	pos.x = minp.x + (maxp.x - minp.x) / 2
	pos.y = maxp.y
	pos.z = minp.z + (maxp.z - minp.z) / 2

	-- if this group is too close to another group, stop here
	if (group_avoid_check(pos) == false) then return end

	-- store the origin of this group instance so other groups won't be triggered too close
	group_avoid_add(pos)

	-- randomly choose a mapgen group to spawn here
	local group = math.random(1, table.getn(mapgen_groups))

	-- whenever a building spawns, it takes up space and decreases the probability of future buildings
	-- to compensate, add the probabilities of previous buildings to the current building
	local probability_compensate = 0

	-- store the origin of each spawned building from this group instance, in order to avoid it for future buildings
	local avoid = {}

	-- go through all structures in the mapgen table
	for i, entry in ipairs(mapgen_table) do
		-- only go further if this structure belongs to the chosen mapgen group
		if (entry[5] == mapgen_groups[group]) then

			-- global settings for this structure
			local probability = tonumber(entry[7]) + probability_compensate
			local height = { minimum = tonumber(entry[8]), maximum = tonumber(entry[9]) }
			local distance = tonumber(entry[10])
			local range = (probability + distance) * MAPGEN_STRUCTURE_DENSITY

			-- attempt to create this structure by the amount of probability it has
			-- everything inside are parameters of each attempt to spawn this structure
			for x = 1, probability do
				-- choose random X and Z coordinates within range
				local coords = { }
				coords.x = pos.x + math.random(-range / 2, range / 2)
				coords.y = pos.y
				coords.z = pos.z + math.random(-range / 2, range / 2)

				-- choose angle (0, 90, 180, 270) and avoidance direction (see below) based on distance from group center
				-- it's hard to find an accurate formula here, but it still keeps buildings oriented uniformly
				local angle = 0
				local size = { }
				local avoid_step_x = 0
				local avoid_step_z = 0
				if (coords.x < pos.x) and (coords.z < pos.z) then
					angle = 270
					size = { x = entry[3], y = entry[2], z = entry[1] }
					avoid_step_x = -MAPGEN_STRUCTURE_AVOID_STEPS
					avoid_step_z = -MAPGEN_STRUCTURE_AVOID_STEPS
				elseif (coords.x < pos.x) then
					angle = 90
					size = { x = entry[3], y = entry[2], z = entry[1] }
					avoid_step_x = -MAPGEN_STRUCTURE_AVOID_STEPS
					avoid_step_z = MAPGEN_STRUCTURE_AVOID_STEPS
				elseif (coords.z < pos.z) then
					angle = 180
					size = { x = entry[1], y = entry[2], z = entry[3] }
					avoid_step_x = MAPGEN_STRUCTURE_AVOID_STEPS
					avoid_step_z = -MAPGEN_STRUCTURE_AVOID_STEPS
				else
					angle = 0
					size = { x = entry[1], y = entry[2], z = entry[3] }
					avoid_step_x = MAPGEN_STRUCTURE_AVOID_STEPS
					avoid_step_z = MAPGEN_STRUCTURE_AVOID_STEPS
				end

				-- scan avoid origins, and push away until we're far enough from all of them
				-- this loop executes until that happens or we're out of range
				local found_origin = false
				while (found_origin == false) do
					found_origin = true

					-- check that the origin is still in bounds, and fail the spawn attempt if not
					if (coords.x < pos.x - range / 2) or (coords.x > pos.x + range / 2) or
					(coords.y < pos.y - range / 2) or (coords.y > pos.y + range / 2) or
					(coords.z < pos.z - range / 2) or (coords.z > pos.z + range / 2) then
						found_origin = false
						break
					end

					-- loop through the all avoid origins in the table
					for w, org in ipairs(avoid) do
						-- if we are too close to this avoid origin, move away until we're clear of it
						local dist = calculate_distance(coords, org)
						while (dist.x < distance) and (dist.z < distance) do
							if (dist.x < distance) then
								coords.x = coords.x + avoid_step_x
							end
							if (dist.z < distance) then
								coords.z = coords.z + avoid_step_z
							end

							dist = calculate_distance(coords, org)
							found_origin = false
						end

						-- we had to avoid an origin, start the scan all over again to make sure we're avoiding everything
						if (found_origin == false) then
							break
						end
					end
				end

				-- if we get this far, we found X and Z coordinates we are happy with
				-- now scan downward until we find the trigger node of this structure at surface level
				-- if we don't, this attempt to spawn the structure is lost
				if (found_origin == true) then
					local search_target = coords.y - range
					for search = pos.y, search_target, -1 do
						-- also check that the position is within the structure's height range
						if (search > height.minimum) and (search < height.maximum) then
							coords.y = search
							local node_here = minetest.env:get_node(coords)
							local pos_down = { x = coords.x, y = coords.y - 1, z = coords.z }
							local node_down = minetest.env:get_node(pos_down)

							if (node_here.name == "air") and (node_down.name == entry[6]) then
								-- schedule the building to spawn based on its position in the loop
								delay = x * MAPGEN_STRUCTURE_DELAY
								minetest.after(delay, function()
									spawn_structure(entry[4], coords, angle, size, entry[6])
								end)

								table.insert(avoid, coords)
								probability_compensate = probability_compensate + (probability * MAPGEN_STRUCTURE_PROBABILITY_COMPENSATE)
								break
							end
						end
					end
				end
			end
		end
	end
end

-- Global functions - Add / remove to / from file

function mapgen_add (pos, ends, filename, group, node, probability, height_min, height_max, spacing)
	-- remove the existing entry
	mapgen_remove (filename)

	-- we need to store the size of the structure
	local dist = calculate_distance(pos, ends)

	-- add file to the mapgen table
	entry = {dist.x, dist.y, dist.z, filename, group, node, probability, height_min, height_max, spacing }
	table.insert(mapgen_table, entry)

	table_to_file()
end

function mapgen_remove (filename)
	for i, entry in ipairs(mapgen_table) do
		if (entry[4] == filename) then
			table.remove(mapgen_table, i)
			break
		end
	end

	table_to_file()
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, file_to_table)

minetest.register_on_generated(function(minp, maxp, seed)
	spawn_group (minp, maxp)
end)
