-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- file which contains the mapgen entries
local MAPGEN_FILE = "mapgen.txt"
-- probability of a structure group to spawn, per piece of world being generated
local MAPGEN_GROUP_PROBABILITY = 0.2
-- if the area we're spawning in didn't finish loading / generating, retry this many seconds
-- low values preform checks more frequently, higher values are recommended when the world is slow to load
local MAPGEN_GROUP_RETRY = 3
-- amount of origins to maintain in the group avoidance list
-- low values increase the risk of groups being ignored from distance calculations, high values store more data
local MAPGEN_GROUP_TABLE_COUNT = 10

-- Local values - Groups and mapgen

-- store the origin of each group in the group avoidance list
local groups_avoid = {}

-- the mapgen table and groups table
mapgen_groups = {}
mapgen_table = {}

-- Local functions - Groups

-- updates the groups table with all mapgen groups
local function groups_update ()
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

-- adds entries to the group avoidance list
local function groups_avoid_add (pos, scale_horizontal, scale_vertical)
	-- if the maximum amount of entries was reached, delete the oldest one
	if (table.getn(groups_avoid) >= MAPGEN_GROUP_TABLE_COUNT) then
		table.remove(groups_avoid, 1)
	end

	-- h = horizontal size, v = vertical size
	table.insert(groups_avoid, { x = pos.x, y = pos.y, z = pos.z, h = scale_horizontal, v = scale_vertical } )
end

-- checks if a given distance is far enough from all group avoidance origins
local function groups_avoid_check (pos, scale_horizontal, scale_vertical)
	for i, group in ipairs(groups_avoid) do
		-- for each group, structures are spawned from the upper-left corner (up-down and left-right), so:
		-- if this group is under / right of the other group, we check distance against that group's scale
		-- if this group is above / left of the other group, we check distance against this group's scale
		local target_horizontal = 0
		if (pos.x < group.x) or (pos.z < group.z) then
			target_horizontal = scale_horizontal
		else
			target_horizontal = group.h
		end
		-- same story with height
		local target_vertical = 0
		if (pos.y < group.y) then
			target_vertical = scale_vertical
		else
			target_vertical = group.v
		end

		-- check distance and height
		local dist = calculate_distance(pos, group)
		if (dist.x < target_horizontal) and (dist.y < target_vertical) and (dist.z < target_horizontal) then
			return false
		end
	end

	return true
end

-- Local functions - Mapgen

-- writes the mapgen file into the mapgen table
local function mapgen_to_table ()
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
	groups_update()
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
			s = s..entry2.." "
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
	groups_update()
end

-- Local functions - Generate

-- checks whether the area has finished loading or not
local function generate_get_loaded (pos, scale_horizontal, scale_vertical)
	local corners = { }
	table.insert(corners, { x = pos.x, y = pos.y, z = pos.z } )
	table.insert(corners, { x = pos.x, y = pos.y, z = pos.z + scale_horizontal } )
	table.insert(corners, { x = pos.x + scale_horizontal, y = pos.y, z = pos.z } )
	table.insert(corners, { x = pos.x + scale_horizontal, y = pos.y, z = pos.z + scale_horizontal } )
	table.insert(corners, { x = pos.x, y = pos.y + scale_vertical, z = pos.z } )
	table.insert(corners, { x = pos.x, y = pos.y + scale_vertical, z = pos.z + scale_horizontal } )
	table.insert(corners, { x = pos.x + scale_horizontal, y = pos.y + scale_vertical, z = pos.z } )
	table.insert(corners, { x = pos.x + scale_horizontal, y = pos.y + scale_vertical, z = pos.z + scale_horizontal } )
	for i, v in ipairs(corners) do
		local node = minetest.env:get_node(v)
		if (node.name == "ignore") then
			return false
		end
	end

	return true
end

-- returns the size of this group in nodes
local function generate_get_scale (group)
	local scale = 0
	local structures = 0
	-- loop through the mapgen table
	for i, entry in ipairs(mapgen_table) do
		-- only if this structure belongs to the chosen mapgen group
		if (entry[2] == mapgen_groups[group]) then
			-- add the estimated horizontal size of buildings to group space
			local size = io_get_size(0, entry[1])
			scale = scale + math.ceil((size.x + size.z) / 2) * tonumber(entry[6])
			-- increase the structure count
			structures = structures + tonumber(entry[6])
		end
	end
	-- divide space by the square root of total buildings to get the proper row / column sizes
	scale = math.ceil(scale / math.sqrt(structures))

	return scale
end

-- finds a structure group to spawn and calculates each entry's properties
local function spawn_group (minp, maxp, group)

	-- this function was called without specifying a mapgen group
	if (group == nil) then
		-- test group probability for this piece of world
		if(math.random() > MAPGEN_GROUP_PROBABILITY) then return end

		-- randomly choose a mapgen group
		group = math.random(1, table.getn(mapgen_groups))
	end

	-- choose top-left on the X and Z axes since that's where we start from, and bottom on Y axis
	local pos = { x = minp.x, y = minp.y, z = minp.z }
	-- calculate the area this group will use up
	scale_horizontal = generate_get_scale(group)
	scale_vertical = maxp.y - minp.y

	-- if this group is too close to another group stop here
	if (groups_avoid_check(pos, scale_horizontal, scale_vertical) == false) then return end

	-- if we're trying to spawn in an unloaded area, re-run this function as we wait for the area to load
	loaded = generate_get_loaded(pos, scale_horizontal, scale_vertical)
	if (loaded == false) then
		minetest.after(MAPGEN_GROUP_RETRY, function()
			spawn_group(minp, maxp, group)
		end)
		return
	end

	-- get the the building list
	local buildings = mapgen_buildings_get(pos, scale_horizontal, scale_vertical, group)

	-- no suitable buildings exist, return
	if (table.getn(buildings) == 0) then return end

	-- add this group to the group avoidance list
	groups_avoid_add(pos, scale_horizontal, scale_vertical)

	for i, building in ipairs(buildings) do
		-- schedule the building to spawn based on its position in the loop
		local delay = i * MAPGEN_BUILDINGS_DELAY
		minetest.after(delay, function()
			-- parameters: name [1], position [2], angle [3], size [4], bottom [5], bury [6], node [7]
			mapgen_buildings_spawn(building[1], building[2], building[3], building[4], building[5], building[6], building[7])
		end)
	end
end

-- Global functions - Add and remove to and from file

function mapgen_add (filename, group, node, height_min, height_max, count, bury)
	-- remove the existing entry
	mapgen_remove (filename)

	-- add file to the mapgen table
	entry = {filename, group, node, height_min, height_max, count, bury }
	table.insert(mapgen_table, entry)

	mapgen_to_file()
end

function mapgen_remove (filename)
	for i, entry in ipairs(mapgen_table) do
		if (entry[1] == filename) then
			table.remove(mapgen_table, i)
			break
		end
	end

	mapgen_to_file()
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, mapgen_to_table)

-- register the group spawn function to run on each piece of world being generated
minetest.register_on_generated(function(minp, maxp, seed)
	spawn_group (minp, maxp, nil)
end)
