-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings
local MAPGEN_FILE = "mapgen.txt"
local MAPGEN_PROBABILITY = 1
local MAPGEN_RANGE = 80

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
			if (v[2] == w) then
				found = true
				break
			end
		end

		if (found == false) then
			table.insert(mapgen_groups, v[2])
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
	for i, entry1 in pairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in pairs(entry1) do
			s = s..entry2.." "
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
	update_groups()
end

-- Local functions - Spawn

local function spawn_structure (filename, pos, node)
	-- randomize X and Z coordinates within range
	pos.x = pos.x + math.random(-MAPGEN_RANGE, MAPGEN_RANGE)
	pos.z = pos.z + math.random(-MAPGEN_RANGE, MAPGEN_RANGE)

	-- now scan downward on these coordinates until we find a suitable spot
	-- if we don't, this attempt to spawn the structure is lost
	local target_y = pos.y - MAPGEN_RANGE * 2
	for loop = pos.y, target_y, -1 do
		local pos_here = { x = pos.x, y = loop, z = pos.z }
		local node_here = minetest.env:get_node(pos_here)
		local pos_down = { x = pos.x, y = loop - 1, z = pos.z }
		local node_down = minetest.env:get_node(pos_down)

		if (node_here.name == "air") and (node_down.name == node) then
			pos1 = { x = pos_here.x - 10, y = pos_here.y - 0, z = pos_here.z - 10 }
			pos2 = { x = pos_here.x + 10, y = pos_here.y + 20, z = pos_here.z + 10 }
			io_area_import(pos1, pos2, 0 , filename)
			break
		end
	end
end

local function spawn_group (minp, maxp)
	if(math.random() > MAPGEN_PROBABILITY) then return end

	-- randomly choose a mapgen group
	local group = math.random(1, table.getn(mapgen_groups))

	-- choose middle location on the X and Z axes, top on Y
	local coords_x = minp.x + (maxp.x - minp.x) / 2
	local coords_y = maxp.y
	local coords_z = minp.z + (maxp.z - minp.z) / 2
	local pos = { x = coords_x, y = coords_y, z = coords_z }

	-- go through all entries in the mapgen table which belong to this group
	for i, entry in pairs(mapgen_table) do
		if (entry[2] == mapgen_groups[group]) then
			-- account structure probability
			-- if < 1 (eg: 0.5) use this as a chance
			-- it > 1 (eg: 2.0) spawn it this many times
			local probability = tonumber(entry[4])
			if (probability <= 1) then
				if (probability >= math.random()) then
					spawn_structure(entry[1], pos, entry[3])
				end
			else
				for x = 1, probability, 1 do
					spawn_structure(entry[1], pos, entry[3])
				end
			end
		end
	end
end

-- Global functions - Add / remove to / from file

function mapgen_add (filename, group, node, probability, height_min, height_max, spacing)
	-- remove the existing entry
	mapgen_remove (filename)

	-- add file to the mapgen table
	entry = { filename, group, node, probability, height_min, height_max, spacing }
	table.insert(mapgen_table, entry)

	table_to_file()
end

function mapgen_remove (filename)
	for i, entry in pairs(mapgen_table) do
		if (entry[1] == filename) then
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
