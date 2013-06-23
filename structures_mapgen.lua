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
-- only spawn if the height of each corner is within this distance against the ground (top is air and bottom is not)
-- low values reduce spawns on extreme terrain, but also decrease count
local MAPGEN_STRUCTURE_LEVEL = 20
-- each structure is delayed by this many seconds
-- high values cause structures to spawn more slowly, low values deal more stress to the CPU and encourage incomplete spawns
local MAPGEN_STRUCTURE_DELAY = 1
-- add this many nodes to each side when cutting and adding the floor
local MAPGEN_STRUCTURE_BORDER = 2
-- if true, create a floor under each structure by this many nodes to fill empty space
local MAPGEN_STRUCTURE_FILL = true

-- Local values - Groups and mapgen

-- store the origin of each group in the group avoidance list
local groups_avoid = {}

-- the mapgen table and groups table
local mapgen_table = {}
local mapgen_groups = {}

-- Local functions - Groups

-- updates the groups table with all mapgen groups
local function groups_update ()
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

-- adds entries to the group avoidance list
local function groups_avoid_add (pos)
	-- if the maximum amount of group avoid origins was reached, delete the oldest one
	if (table.getn(groups_avoid) >= MAPGEN_GROUP_DISTANCE_COUNT) then
		table.remove(groups_avoid, 1)
	end

	table.insert(groups_avoid, pos)
end

-- checks if a given distance is far enough from all group avoidance origins
local function groups_avoid_check (pos)
	for i, org in ipairs(groups_avoid) do
		local dist = calculate_distance(pos, org)
		if (dist.x < MAPGEN_GROUP_DISTANCE) and (dist.y < MAPGEN_GROUP_DISTANCE) and (dist.z < MAPGEN_GROUP_DISTANCE) then
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

-- Local functions - Spawn

-- analyzes buildings in the mapgen group and returns them as a lists of parameters
local function spawn_get (pos, height, group)
	-- parameters: x size [1], y size [2], z size [3], structure [4], group [5], node [6], min height [7], max height [8], count [9]
	-- x = left & right, z = up & down

	-- structure table which will be filled and returned by this function
	local structures = { }

	-- first generate a list of indexes for all structures, containing an entry for each time it will be spawned
	local instances = { }
	for i, entry in ipairs(mapgen_table) do
		-- only if this structure belongs to the chosen mapgen group
		if (entry[5] == mapgen_groups[group]) then
			for x = 1, entry[9] do
				table.insert(instances, i)
			end
		end
	end

	-- now randomize the table so structure instances won't be spawned in an uniform order
	local size = table.getn(instances)
	for i in ipairs(instances) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(size)

		-- swap the two entries
		local old = instances[i]
		instances[i] = instances[rand]
		instances[rand] = old
	end

	-- obtain the list of columns and rows based on the total number of buildings
	local columns_rows = math.ceil(math.sqrt(table.getn(instances)))

	-- store the top-right corners of structures in the left and right columns (compared to the current column)
	-- in each colum, we check the left list and set the right one for later use, then right becomes left when we advance to the next colum
	local points_left = { }
	local points_right = { }
	-- the column and row we are currently in
	local row = 1
	local column = 1
	-- current Z location, we start at group position
	local current_z = pos.z

	-- go through the mapgen table
	for i, instance in ipairs(instances) do
		entry = mapgen_table[instance]

		-- if the current row was filled, jump to the next column
		if (row > columns_rows) then
			row = 1
			column = column + 1
			-- start again from the top
			current_z = pos.z
			-- the list of next points becomes the list of current points
			points_left = points_right
			points_right = { }
		end
		-- if the columns were filled, return the sturcute table and stop doing anything
		-- this is only a safety and we shouldn't get here, since we fill the columns + rows when the last building spawns
		if (column > columns_rows) then
			return structures
		end

		-- location will be set gradually in each direction
		local location = { x = 0, y = 0, z = 0 }
		-- we determined Z location, store it
		location.z = current_z

		-- choose angle (0, 90, 180, 270) based on distance from center, and size based on angle
		-- it's hard to find an accurate formula here, but it keeps buildings oriented uniformly
		local angle = 0
		local size = { }
		if (row < columns_rows / 2) and (column < columns_rows / 2) then
			angle = 180
			size = { x = entry[1], y = entry[2], z = entry[3] }
		elseif (row < columns_rows / 2) then
			angle = 90
			size = { x = entry[3], y = entry[2], z = entry[1] }
		elseif (column < columns_rows / 2) then
			angle = 270
			size = { x = entry[3], y = entry[2], z = entry[1] }
		else
			angle = 0
			size = { x = entry[1], y = entry[2], z = entry[3] }
		end

		-- determine which of the buildings in the left row have their top-right corners intersecting this structure, and push this structure to the right accordingly
		local edge = pos.x
		for w, point in ipairs(points_left) do
			-- check if the point intersects our structure
			if (point.z <= current_z + MAPGEN_STRUCTURE_BORDER) and (point.z >= current_z - size.z - MAPGEN_STRUCTURE_BORDER) then
				-- if this point is further to the right than the last one, bump the edge past its location
				if (edge < point.x) then
					edge = point.x
				end
			end
		end
		-- we determined X location, store it
		location.x = edge

		-- now that we know the location size and angle, we'll perform a few checks next to see if the structure may spawn
		local may_spawn = false

		-- scan downward until we find the trigger node of this structure at surface level
		-- if we don't, this building may not spawn
		for search = height.max, height.min, -1 do
			-- we scan from top to bottom, so the search might start above the structure's maximum height limit
			-- if however it gets below the minimum limit, there's no point to keep going and this structure may not spawn
			if (search <= tonumber(entry[7])) then
				may_spawn = false
				break
			elseif (search <= tonumber(entry[8])) then
				-- check if the node below is our trigger node
				local pos_down = { x = location.x, y = search - 1, z = location.z }
				local node_down = minetest.env:get_node(pos_down)
				if (node_down.name == entry[6]) then
					-- check if the node here is an air node
					local pos_here = { x = location.x, y = search, z = location.z }
					local node_here = minetest.env:get_node(pos_here)
					if(node_here.name == "air") then
						may_spawn = true
						-- we determined Y location, store it
						location.y = search
						break
					end
				end
			end
		end

		-- now check terrain roughness and decide if we can spawn the structure or not
		local bottom = location.y - 1 -- initial value, modified later
		if (may_spawn == true) then
			-- terrain leveling amount to check for in each direction
			local level = math.ceil(MAPGEN_STRUCTURE_LEVEL / 2)
			-- determine the location of each corner
			local location1_frame = { x = location.x - MAPGEN_STRUCTURE_BORDER, z = location.z - MAPGEN_STRUCTURE_BORDER }
			local location2_frame = { x = location.x + size.x + MAPGEN_STRUCTURE_BORDER, z = location.z + size.z + MAPGEN_STRUCTURE_BORDER }
			local corners = { }
			table.insert(corners, { x = location1_frame.x, z = location1_frame.z } )
			table.insert(corners, { x = location1_frame.x, z = location2_frame.z } )
			table.insert(corners, { x = location2_frame.x, z = location1_frame.z } )
			table.insert(corners, { x = location2_frame.x, z = location2_frame.z } )
			-- to know if each corner is close enough to the surface, check if there's air above center and solid below
			for i, v in ipairs(corners) do
				local found_air = false
				local found_solid = false
				for search = location.y - 1 + level, location.y - level, -1 do
					-- search air
					if (search >= location.y) and (found_air == false) then
						local pos = { x = v.x, y = search, z = v.z }
						local node = minetest.env:get_node(pos)
						if (node.name == "air") then
							found_air = true
						end
					end
					-- search solid
					if (search < location.y) and (found_solid == false) then
						if (found_air == false) then break end -- we didn't find air so don't waste time here
						local pos = { x = v.x, y = search, z = v.z }
						local node = minetest.env:get_node(pos)
						if (node.name ~= "air") and (node.name ~= "ignore") and (minetest.registered_nodes[node.name].drawtype == "normal") then
							found_solid = true
							-- also set bottom to the lowest solid location we detected
							if (search < bottom) then
								bottom = search
							end
							break
						end
					end
				end
				-- this corner failed the check, don't spawn the building and leave
				if (found_air == false) or (found_solid == false) then
					may_spawn = false
					break
				end
			end
		end

		-- if the structure may spawn, insert it into the table
		if (may_spawn == true) then
			-- parameters: name [1], position [2], angle [3], size [4], bottom [5], node [6]
			table.insert(structures, { entry[4], location, angle, size, bottom, entry[6] } )
		end

		-- add this structure's upper-right corner to the right point list
		upright = { }
		upright.x = location.x + size.x + MAPGEN_STRUCTURE_BORDER * 2 + 1
		upright.z = location.z
		table.insert(points_right, upright)

		-- lastly, push Z location so the next building in this row will try to spawn right under here
		current_z = current_z - size.z - MAPGEN_STRUCTURE_BORDER * 2 - 1

		-- increase the row count
		row = row + 1
	end

	return structures
end

-- naturally spawns a structure with the given parameters
local function spawn_structure (filename, pos, angle, size, bottom, trigger)

	-- determine the corners of the spawn cube
	local pos1 = { x = pos.x, y = pos.y, z = pos.z }
	local pos2 = { x = pos.x + size.x, y = pos.y + size.y, z = pos.z + size.z }
	local pos1_frame = { x = pos1.x - MAPGEN_STRUCTURE_BORDER, y = pos1.y, z = pos1.z - MAPGEN_STRUCTURE_BORDER }
	local pos2_frame = { x = pos2.x + MAPGEN_STRUCTURE_BORDER, y = pos2.y, z = pos2.z + MAPGEN_STRUCTURE_BORDER }

	-- we'll spawn the structure in a suitable spot, but what if it's the top of a peak?
	-- to avoid parts of the building left floating, cover everything to the bottom
	if (MAPGEN_STRUCTURE_FILL) then
		for cover_y = pos.y - 1, bottom + 1, -1 do
			-- fill up this layer
			for cover_x = pos1_frame.x, pos2_frame.x do
				for cover_z = pos1_frame.z, pos2_frame.z do
					pos_fill = { x = cover_x, y = cover_y, z = cover_z }
					node_fill = minetest.env:get_node(pos_fill)
					if (node_fill.name ~= node) then
						minetest.env:set_node(pos_fill, { name = trigger })
					end
				end
			end
		end
	end

	-- at last, create the structure itself
	io_area_clear(pos1_frame, pos2_frame)
	io_area_import(pos1, pos2, angle, filename)
end

-- finds a structure group to spawn and calculates each entry's properties
local function spawn_group (minp, maxp)
	-- test group probability for this piece of world
	if(math.random() > MAPGEN_GROUP_PROBABILITY) then return end

	-- choose center on the X and Z axes and top on Y
	local pos = { }
	pos.x = minp.x + (maxp.x - minp.x) / 2
	pos.y = 0
	pos.z = minp.z + (maxp.z - minp.z) / 2

	-- height to scan over
	local height = { }
	height.min = minp.y
	height.max = maxp.y

	-- if this group is too close to another group stop here, if not add it to the avoid list and move on
	if (groups_avoid_check(pos) == false) then return end
	groups_avoid_add(pos)

	-- randomly choose a mapgen group to spawn here
	local group = math.random(1, table.getn(mapgen_groups))

	-- go through the structure list and schedule each entry for spawning
	local structures = spawn_get(pos, height, group)

	for i, structure in ipairs(structures) do
		-- schedule the building to spawn based on its position in the loop
		delay = i * MAPGEN_STRUCTURE_DELAY
		minetest.after(delay, function()
			-- parameters: name [1], position [2], angle [3], size [4], node [5]
			spawn_structure(structure[1], structure[2], structure[3], structure[4], structure[5], structure[6])
		end)

	end
end

-- Global functions - Add / remove to / from file

function mapgen_add (pos, ends, filename, group, node, height_min, height_max, count)
	-- remove the existing entry
	mapgen_remove (filename)

	-- we need to store the size of the structure
	local dist = calculate_distance(pos, ends)

	-- add file to the mapgen table
	entry = {dist.x, dist.y, dist.z, filename, group, node, height_min, height_max, count }
	table.insert(mapgen_table, entry)

	mapgen_to_file()
end

function mapgen_remove (filename)
	for i, entry in ipairs(mapgen_table) do
		if (entry[4] == filename) then
			table.remove(mapgen_table, i)
			break
		end
	end

	mapgen_to_file()
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, mapgen_to_table)

minetest.register_on_generated(function(minp, maxp, seed)
	spawn_group (minp, maxp)
end)
