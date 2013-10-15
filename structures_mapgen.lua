-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- file which contains the mapgen entries
local MAPGEN_FILE = "mapgen_structures.txt"
-- probability of a structure group to spawn, per piece of world being generated
local MAPGEN_GROUP_PROBABILITY = 0.4
-- if the area we're spawning in didn't finish loading / generating, retry this many seconds
-- low values preform checks more frequently, higher values are recommended when the world is slow to load
local MAPGEN_GROUP_LOADED_RETRY = 3
-- how many times to try spawning the group before giving up
local MAPGEN_GROUP_LOADED_ATTEMPTS = 10
-- spawning is delayed by this many seconds
-- high values cause structures to spawn later, giving more time for other operations to finish
local MAPGEN_GROUP_DELAY = 5
-- amount of origins to maintain in the group avoidance list
-- low values increase the risk of groups being ignored from distance calculations, high values store more data
local MAPGEN_GROUP_TABLE_COUNT = 10

-- Local values - Groups and mapgen

-- store the origin of each group in the group avoidance list
local groups_avoid = {}

-- the mapgen table and groups table
mapgen_table = {}

-- Local functions - Groups

-- adds entries to the group avoidance list
local function groups_avoid_add (pos, scale_horizontal, scale_vertical)
	-- if the maximum amount of entries was reached, delete the oldest one
	if (#groups_avoid >= MAPGEN_GROUP_TABLE_COUNT) then
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

-- randomly choose a mapgen group accounting height limits, and return the necessary parameters for spawning this group
local function groups_get (pos_min, pos_max)
	-- each acceptable group is added to this table
	local list_group = { }

	-- go through the mapgen table and read all group settings
	-- settings: group [1], type [2], node [3], height_min [4], height_max [5], probability [6]
	for i, entry in ipairs(mapgen_table) do
		if (entry[2] == "settings") then
			-- actual highest and lowest areas to scan in
			local down = math.max(tonumber(entry[4]), pos_min.y)
			local up = math.min(tonumber(entry[5]), pos_max.y)

			-- only advance if this group is within the area's height range
			if (pos_max.y > down) and (pos_min.y < up) then
				-- minimum and maximum ground height will be calculated further down
				-- in order for the scan to work, they must be initialized in reverse
				local corner_top = down
				local corner_bottom = up

				-- loop through all of the group's corners
				local corners = { }
				table.insert(corners, { x = pos_min.x, z = pos_min.z } )
				table.insert(corners, { x = pos_min.x, z = pos_max.z } )
				table.insert(corners, { x = pos_max.x, z = pos_min.z } )
				table.insert(corners, { x = pos_max.x, z = pos_max.z } )
				local corners_total = #corners
				for i, v in pairs(corners) do
					-- scan from the highest point to the lowest
					for search = up, down, -1 do
						local pos_here = { x = v.x, y = search, z = v.z }
						local node_here = minetest.env:get_node(pos_here)

						-- check that this node is the trigger node, and account it for terrain height if so
						if (node_here.name == entry[3]) then
							if (corner_bottom > search) then
								corner_bottom = search
							end
							if (corner_top < search) then
								corner_top = search
							end

							-- we checked everything we needed for this corner, it can be removed from the table
							corners[i] = nil
							corners_total = corners_total - 1
							break
						end
					end
				end

				-- if terrain level was detected and the trigger node was found, this group may spawn
				if (corners_total == 0) then
					-- add this group by the amount of probability it has
					for x = 1, tonumber(entry[6]) do
						table.insert(list_group, { entry[1], { low = corner_bottom, high = corner_top }, entry[3] })
					end
				end

			end
		end
	end

	-- no suitable groups exist, return nil
	if (#list_group == 0) then return nil end
	-- randomly choose an entry from the list of acceptable groups
	local list_group_random = list_group[math.random(1, #list_group)]
	return list_group_random[1], list_group_random[2], list_group_random[3]
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
		-- loop through each parameter in the line, ignore comments
		if (string.sub(line, 1, 1) ~= "#") then
			local parameters = {}
			for item in line:gmatch("[^\t]+") do
				table.insert(parameters, item)
			end
			table.insert(mapgen_table, parameters)
		end
	end

	file:close()
end

-- writes the mapgen table into the mapgen file
local function mapgen_to_file ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- default header comment
	local h = "# name	position	angle	size	bottom	bury	node\n"
	file:write(h)

	-- loop through each entry
	for i, entry1 in ipairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in ipairs(entry1) do
			s = s..entry2.."	"
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
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
	local scale_horizontal = 0
	local scale_vertical = 0
	local structures = 0

	-- loop through the mapgen table
	for i, entry in ipairs(mapgen_table) do
		-- only if this structure belongs to the chosen mapgen group
		-- TODO: Add roads too
		if (entry[1] == group) and (entry[2] == "building") then
			local size = io_get_size(0, entry[3])

			-- add the estimated horizontal size of buildings to group space
			scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * tonumber(entry[4])

			-- if this building is the tallest, use its vertical size minus bury value
			local height = size.y - tonumber(entry[5])
			if (height > scale_vertical) then
				scale_vertical = height
			end

			-- increase the structure count
			structures = structures + tonumber(entry[4])
		end
	end
	-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
	scale_horizontal = math.ceil(scale_horizontal / math.sqrt(structures))

	return scale_horizontal, scale_vertical
end

-- prepares the area for structures to be spawned in
local function generate_prepare (pos, height, scale_horizontal, scale_vertical, node)
	-- build the floor, down to the estimated bottom of the terrain
	local pos_ground = { x = pos.x + scale_horizontal, y = height.low, z = pos.z + scale_horizontal }
	io_area_fill(pos, pos_ground, node)

	-- clear the volume of the group, or the area of terrain we estimate it would cut if it's taller
	local highest = math.max(pos.y + scale_vertical, height.high)
	local pos_clear = { x = pos.x + scale_horizontal, y = highest, z = pos.z + scale_horizontal }
	pos.y = pos.y - 1
	io_area_fill(pos, pos_clear, nil)
end

-- finds a structure group to spawn and calculates each entry's properties
local function spawn_group (start, height, group, node, attempts)
	-- if we're out of attempts give up
	if (attempts <= 0) then return end
	attempts = attempts - 1

	-- center height and choose the upper-left-bottom corner as the starting point
	local pos_height = math.floor((height.low + height.high) / 2)
	local pos = { x = start.x, y = pos_height, z = start.z }

	-- calculate the area this group will use up
	local scale_horizontal, scale_vertical = generate_get_scale(group)

	-- if this group is too close to another group stop here
	if (groups_avoid_check(pos, scale_horizontal, scale_vertical) == false) then return end

	-- if we're trying to spawn in an unloaded area, re-run this function as we wait for the area to load
	loaded = generate_get_loaded(pos, scale_horizontal, scale_vertical)
	if (loaded == false) then
		minetest.after(MAPGEN_GROUP_LOADED_RETRY, function()
			spawn_group(start, height, group, node, attempts)
		end)
		return
	end

	-- get the the building and road lists
	local roads, road_rectangles = mapgen_roads_get(pos, scale_horizontal, group)
	local buildings = mapgen_buildings_get(pos, scale_horizontal, road_rectangles, group)

	-- stop here if there's nothing to spawn
	if (#roads == 0) and (#buildings == 0) then return end

	-- add this group to the group avoidance list
	groups_avoid_add(pos, scale_horizontal, scale_vertical)

	-- schedule the buildings and roads for spawning
	minetest.after(MAPGEN_GROUP_DELAY, function()
		generate_prepare (pos, height, scale_horizontal, scale_vertical, node)

		mapgen_roads_spawn(roads, pos.y)

		for i, building in ipairs(buildings) do
			-- parameters: name [1], position [2], angle [3], size [4], bury [5]
			mapgen_buildings_spawn(building[1], building[2], building[3], building[4], building[5], group)
		end
	end)
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, mapgen_to_table)

-- register the group spawn function to run on each piece of world being generated
minetest.register_on_generated(function(minp, maxp, seed)
	-- test probability for this piece of world
	if(math.random() > MAPGEN_GROUP_PROBABILITY) then return end

	-- randomly choose a mapgen group
	local group, height, node = groups_get(minp, maxp)
	if (group == nil) then return end

	spawn_group (minp, height, group, node, MAPGEN_GROUP_LOADED_ATTEMPTS)
end)
