-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings
local MAPGEN_FILE = "mapgen.txt"
local MAPGEN_PROBABILITY = 0.1
local MAPGEN_DENSITY = 2
local MAPGEN_AVOID_STEPS = 5
local MAPGEN_FILL = 10

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

local function spawn_structure (filename, pos, angle, size, node)
	-- create our structure
	local pos1 = { x = pos.x - size.x / 2, y = pos.y, z = pos.z - size.z / 2 }
	local pos2 = { x = pos.x + size.x / 2, y = pos.y + size.y, z = pos.z + size.z / 2 }
	io_area_import(pos1, pos2, angle, filename)

	-- we spawned the structure on a suitable node, but what if it was the top of a peak?
	-- to avoid parts of the building left floating, cover everything until all 4 corners touch the ground
	for cover_y = pos.y - 1, pos.y - MAPGEN_FILL, -1 do
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

local function spawn_group (minp, maxp)
	if(math.random() > MAPGEN_PROBABILITY) then return end

	-- Stores the origins of spawned buildings in order to avoid them
	local avoid = {}

	-- randomly choose a mapgen group
	local group = math.random(1, table.getn(mapgen_groups))

	-- choose middle location on the X and Z axes, top on Y
	local pos = { }
	pos.x = minp.x + (maxp.x - minp.x) / 2
	pos.y = maxp.y
	pos.z = minp.z + (maxp.z - minp.z) / 2

	-- go through all entries in the mapgen table which belong to this group
	for i, entry in ipairs(mapgen_table) do
		if (entry[5] == mapgen_groups[group]) then
			-- global settings for this structure
			local probability = tonumber(entry[7])
			local height = { minimum = tonumber(entry[8]), maximum = tonumber(entry[9]) }
			local distance = tonumber(entry[10])
			local range = (probability + distance) * MAPGEN_DENSITY

			-- attempt creation of this structure by the amount of probability it has
			-- everything inside are settings of each attempt
			for x = 1, probability do
				-- choose a random angle (0, 90, 180, 270) and adjust the size to that
				local size = { }
				local angle = 90 * math.random(0, 3)
				if (angle == 90) or (angle == 270) then
					size = { x = entry[3], y = entry[2], z = entry[1] }
				else
					size = { x = entry[1], y = entry[2], z = entry[3] }
				end

				-- randomize X and Z coordinates within range
				local coords = { }
				coords.x = pos.x + math.random(-range / 2, range / 2)
				coords.y = pos.y
				coords.z = pos.z + math.random(-range / 2, range / 2)

				-- avoid away from the center of the group (see below)
				local avoid_step_x = MAPGEN_AVOID_STEPS
				if (coords.x < pos.x) then
					avoid_step_x = -avoid_step_x
				end
				local avoid_step_z = MAPGEN_AVOID_STEPS
				if (coords.z < pos.z) then
					avoid_step_z = -avoid_step_z
				end

				-- push away until we're far enough from all avoid origins
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

					-- loop through the avoid origins table
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

						-- we had to avoid an origin, start the scan all over again
						if (found_origin == false) then
							break
						end
					end
				end

				if (found_origin == true) then
					-- scan downward until we find the specified node at surface level
					-- if we don't, this attempt to spawn the structure is lost
					local search_target = coords.y - range
					for search = pos.y, search_target, -1 do
						-- check if the position is within the structure's height range
						if (search > height.minimum) and (search < height.maximum) then
							coords.y = search
							local node_here = minetest.env:get_node(coords)
							local pos_down = { x = coords.x, y = coords.y - 1, z = coords.z }
							local node_down = minetest.env:get_node(pos_down)

							if (node_here.name == "air") and (node_down.name == entry[6]) then
								spawn_structure(entry[4], coords, angle, size, entry[6])
								table.insert(avoid, coords)
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
