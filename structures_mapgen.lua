-- Structures: Mapgen functions
-- This file contains the base mapgen functions, used to place structures during world generation

-- Settings

-- file which contains the mapgen entries
local MAPGEN_FILE = "mapgen_structures.txt"
-- when enabled, the mapgen system will only work with one group at a time, deactivating until that group finishes spawning
-- this prevents the server being overwhelmed by too many cities spawning at once, but also makes new groups wait in line if any are triggered during that time
local MAPGEN_SINGLE = true
-- if the area we're spawning in didn't finish loading, or the server is busy with another group (MAPGEN_SINGLE), retry this many seconds
-- low values preform checks more frequently, higher values are recommended when the world is slow to load
local MAPGEN_GROUP_DELAY_RETRY = 5
-- how many times to try spawning the group before giving up
-- lower values give less chances of success, higher values cause attempts doomed to failure to clog the server for a longer time
local MAPGEN_GROUP_DELAY_ATTEMPTS = 20
-- preparations are delayed by this many seconds
-- high values cause calculations to take place later, giving more time for other operations to finish
local MAPGEN_GROUP_DELAY = 5
-- spawning is delayed by this many seconds
-- high values cause structures to spawn later, giving more time for other operations to finish
local MAPGEN_GROUP_DELAY_SPAWN = 1
-- amount of origins to maintain in the group avoidance list
-- low values increase the risk of groups being ignored from distance calculations, high values store more data
local MAPGEN_GROUP_TABLE_COUNT = 10
-- resolution (in nodes) of area checks, used to detect terrain roughness and unloaded spots (1 is best quality)
-- lower values mean a greater chance of detecting holes and bumps in terrain, but also more intensive checking
local MAPGEN_GROUP_AREA_POINTS = 15
-- how much the horizontal size of a group represents terrain roughness limit, eg: 0.1 means a group 100 nodes wide accepts a roughness of 10 nodes
-- higher means more probability but greater holes in mountains and larger floors
local MAPGEN_GROUP_AREA_ROUGHNESS = 0.5

-- Local & Global values - Groups and mapgen

-- true when the mapgen system is busy
local mapgen_busy = false

-- stores the origin of each group in the group avoidance list
local groups_avoid = { }

-- the mapgen table and groups table
mapgen_table = { }

-- Local functions - Groups

-- adds entries to the group avoidance list
local function groups_avoid_add (pos, scale_horizontal, scale_vertical)
	-- if the maximum amount of entries was reached, delete the oldest one
	if (#groups_avoid >= MAPGEN_GROUP_TABLE_COUNT) then
		table.remove(groups_avoid, 1)
	end

	table.insert(groups_avoid, { x = pos.x, y = pos.y, z = pos.z, h = scale_horizontal, v = scale_vertical } )
end

-- checks if a given distance is far enough from all existing groups
local function groups_avoid_check (pos, scale_horizontal, scale_vertical)
	for i, group in ipairs(groups_avoid) do
		-- each group begins at the lower-left corner (down-up and left-right), so:
		-- if this group is above / right of the other group, we check distance against that group's scale
		-- if this group is under / left of the other group, we check distance against this group's scale
		local target_horizontal = 0
		if (pos.x < group.x) or (pos.z < group.z) then
			target_horizontal = scale_horizontal
		else
			target_horizontal = group.h
		end

		local target_vertical = 0
		if (pos.y < group.y) then
			target_vertical = scale_vertical
		else
			target_vertical = group.v
		end

		-- now check the distance and height
		local dist = calculate_distance(pos, group)
		if (dist.x < target_horizontal) and (dist.y < target_vertical) and (dist.z < target_horizontal) then
			return false
		end
	end

	return true
end

-- returns the size of this group in nodes
local function groups_get_scale (group)
	local scale_horizontal = 0
	local scale_vertical = 0
	local structures = 0

	-- loop through the mapgen table
	for i, entry in ipairs(mapgen_table) do
		local size = nil

		-- only if this structure belongs to the mapgen group
		if (entry[1] == group) then
			-- get size based on the type of structure
			if (entry[2] == "building") then
				size = io_get_size(0, entry[3])
			elseif (entry[2] == "road") then
				size = io_get_size(0, entry[3].."_X")
			end

			if (size ~= nil) then
				-- add the estimated horizontal scale of buildings to group space
				scale_horizontal = scale_horizontal + math.ceil((size.x + size.z) / 2) * tonumber(entry[4])

				-- if this is the tallest structure, use its vertical size plus offset value
				local height = size.y + tonumber(entry[5])
				if (height > scale_vertical) then
					scale_vertical = height
				end

				-- increase the structure count
				structures = structures + tonumber(entry[4])
			end
		end
	end
	-- divide horizontal space by the square root of total buildings to get the proper row / column sizes
	scale_horizontal = math.ceil(scale_horizontal / math.sqrt(structures))

	return scale_horizontal, scale_vertical
end

-- choose a mapgen group appropriate for the given area, and return the necessary parameters for this group
local function groups_get (center, height_start, height_end)
	-- each acceptable group is added to this table
	local list_group = { }

	-- go through the mapgen table and read all group settings
	-- settings: group [1], type [2], trigger nodes [3], filler nodes [4], height_min [5], height_max [6], probability [7]
	for i, entry in ipairs(mapgen_table) do
		if (entry[2] == "settings") then
			local scale_horizontal, scale_vertical = groups_get_scale(entry[1])

			-- only advance if this area is within the area's height range, to avoid wasting resources
			if (height_start < tonumber(entry[6])) and (height_end > tonumber(entry[5])) then
				-- actual position of the group, true y is set later
				local pos = { x = center.x - math.ceil(scale_horizontal / 2), y = center.y, z = center.z - math.ceil(scale_horizontal / 2) }

				-- if this group is too close to another group stop here
				if (groups_avoid_check(pos, scale_horizontal, scale_vertical) == true) then
					-- below is the point check, which verifies terrain roughness and if we hit an unloaded area
					-- first, generate the list of points to verify within the group's area horizontally
					local points = { }
					local points_spacing = math.min(scale_horizontal, MAPGEN_GROUP_AREA_POINTS)
					for points_x = pos.x, pos.x + scale_horizontal, points_spacing do
						for points_z = pos.z, pos.z + scale_horizontal, points_spacing do
							table.insert(points, { x = math.ceil(points_x), z = math.ceil(points_z) } )
						end
					end
					local points_total = #points
					-- the values below store minimum and maximum ground height
					-- in order for the scan to work, they must be initialized in reverse
					local corner_top = height_start
					local corner_bottom = height_end
					-- now loop through all of the group's points
					for x, v in ipairs(points) do
						-- scan from the highest spot to the lowest
						for search = height_end, height_start, -1 do
							local found = false
							local pos_here = { x = v.x, y = search, z = v.z }
							local node_here = minetest.env:get_node(pos_here)

							-- if we hit an ignore node, this area didn't finish loading, so return nil and let this function re-run later
							if (node_here.name == "ignore") then
								return nil
							end

							-- scan each entry in the trigger node list
							for item in entry[3]:gmatch("%S+") do
								-- check that this node is a trigger node, and account it for terrain height if so
								if (node_here.name == item) then
									if (corner_bottom > search) then
										corner_bottom = search
									end
									if (corner_top < search) then
										corner_top = search
									end

									found = true
									break
								end
							end

							-- we checked what we needed for this corner, remove it
							if (found == true) then
								points_total = points_total - 1
								break
							end
						end

						-- if the loop iteration doesn't equal the number of remaining points, the corner failed so don't keep going
						if (points_total ~= #points - x) then
							break
						end
					end

					-- check if terrain level was detected and the trigger node was found
					if (points_total == 0) and
					-- now test the group's probability, and only advance if it's true
					-- this is purposely done at the stage, since the point check needs preform even if the group won't spawn, otherwise unloaded areas would influence probability
					(math.random() <= tonumber(entry[7])) and
					-- check if terrain roughness is within acceptable range
					(corner_top - corner_bottom <= scale_horizontal * MAPGEN_GROUP_AREA_ROUGHNESS) then
						-- center the group in the middle of the detected terrain
						pos.y = math.floor((corner_bottom + corner_top) / 2)

						-- see if this height is within range
						if (pos.y >= tonumber(entry[5])) and (pos.y <= tonumber(entry[6])) then
							-- randomly choose a filler node
							local fillers = { }
							for item in entry[4]:gmatch("%S+") do
								table.insert(fillers, item)
							end
							local filler = fillers[math.random(1, #fillers)]

							-- add this group and its properties to the list of potential groups
							-- group: name [1], position [2], scale [3], terrain [4], filler [5]
							table.insert(list_group, { entry[1], pos, { h = scale_horizontal, v = scale_vertical }, { low = corner_bottom, high = corner_top }, filler })
						end
					end
				end
			end
		end
	end

	-- if no suitable groups exist, return an empty string
	if (#list_group == 0) then return "" end
	-- randomly choose an entry from the list of acceptable groups
	local list_group_random = list_group[math.random(1, #list_group)]
	return list_group_random[1], list_group_random[2], list_group_random[3], list_group_random[4], list_group_random[5]
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
		-- loop through each parameter in the line, ignore comments and empty lines
		if (line ~= "") and (string.sub(line, 1, 1) ~= "#") then
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

-- clears and prepares an area before the structures are spawned
local function generate_spawn_prepare (pos, terrain, scale_horizontal, scale_vertical, filler)
	local pos1 = { x = pos.x - 1, y = pos.y - 1, z = pos.z - 1}
	local pos2 = { x = pos.x + scale_horizontal + 1, y = pos.y + scale_vertical + 1, z = pos.z + scale_horizontal + 1}

	-- clear the volume of the group, or highest intersecting terrain if that's taller
	pos2.y = math.max(pos2.y - 1, terrain.high)
	io_area_fill(pos1, pos2, nil)

	-- build the floor, down to the estimated bottom of the terrain
	pos1.y = pos1.y + 1
	pos2.y = terrain.low
	io_area_fill(pos1, pos2, filler)
end

-- spawns all structures in the given schematic
function generate_spawn_structures (schematics, group)
	-- schematics: name [1], position [2], angle [3], size [4]
	for i, structure in ipairs(schematics) do
		local name = structure[1]
		local pos = structure[2]
		local angle = structure[3]
		local size = structure[4]

		-- determine the corners of the structure's cube
		-- since the I/O function doesn't include the start and end nodes themselves, decrease start position by 1 to get the right spot
		local pos1 = { x = pos.x - 1, y = pos.y - 1, z = pos.z - 1 }
		local pos2 = { x = pos.x + size.x, y = pos.y + size.y, z = pos.z + size.z }

		-- clear the structure's area before spawning
		io_area_fill(pos1, pos2, nil)

		-- at last, import the structure itself
		io_area_import(pos1, pos2, angle, name, false)

		-- apply metadata
		local expressions = {
			{ "POSITION_X", tostring(pos.x) }, { "POSITION_Y", tostring(pos.y) }, { "POSITION_Z", tostring(pos.z) },
			{ "SIZE_X", tostring(size.x) }, { "SIZE_Y", tostring(size.y) }, { "SIZE_Z", tostring(size.z) },
			{ "ANGLE", tostring(angle) }, { "NUMBER", tostring(i) }, { "NAME", name }, { "GROUP", group }
		}
		mapgen_metadata_set(pos1, pos2, expressions, group)
	end
end

-- this fetches the structures of the given group and organizes them in a list
local function generate_spawn (group, pos, scale, terrain, filler)
	-- the mapgen system started working
	if (MAPGEN_SINGLE == true) then
		mapgen_busy = true
	end

	-- get the the buildings and roads lists
	local schemes_roads, rectangles_roads = mapgen_roads_get(pos, scale.h, group)
	local schemes_buildings = mapgen_buildings_get(pos, scale.h, rectangles_roads, group)
	-- add everything to one scheme
	-- buildings should be first, so they're represented most accurately by metadata numbers
	local schemes = schemes_buildings
	for w, road in ipairs(schemes_roads) do
		table.insert(schemes, road)
	end

	-- schedule the buildings and roads for spawning
	minetest.after(MAPGEN_GROUP_DELAY_SPAWN, function()
		generate_spawn_prepare (pos, terrain, scale.h, scale.v, filler)
		generate_spawn_structures(schemes, group)

		-- the mapgen system finished
		mapgen_busy = false
	end)
end

-- this runs for each piece of world being generated
local function generate (minp, maxp, attempts)
	-- if we're out of attempts give up
	if (attempts > MAPGEN_GROUP_DELAY_ATTEMPTS) then return end
	attempts = attempts + 1

	-- if the mapgen system is busy spawning another group, schedule this to run later
	if (mapgen_busy == true) then
		minetest.after(MAPGEN_GROUP_DELAY_RETRY, function()
			generate (minp, maxp, attempts)
		end)
		return
	end

	-- choose the middle of the generated area as the center of the group
	local center_x = math.floor((minp.x + maxp.x) / 2)
	local center_z = math.floor((minp.z + maxp.z) / 2)
	local center = { x = center_x, y = minp.y, z = center_z }

	-- choose a mapgen group
	local group, pos, scale, terrain, filler = groups_get(center, minp.y, maxp.y)

	-- if group is nil, the area one of the groups would occupy hasn't finished loading, so schedule a retry
	if (group == nil) then
		minetest.after(MAPGEN_GROUP_DELAY_RETRY, function()
			generate (minp, maxp, attempts)
		end)
		return
	end

	-- if group is an empty string, no suitable groups were found for this area
	if (group == "") then return end

	-- if this function executed multiple times simultaneously, the groups spawned by each instance might have not gotten the chance to check each other
	-- so preform the avoidance check here too as a failsafe, and abort if a collision is detected
	if (groups_avoid_check(pos, scale.h, scale.v) == false) then return end

	-- add this group to the group avoidance list
	groups_avoid_add(pos, scale.h, scale.v)

	-- begin spawning the group we chose
	generate_spawn (group, pos, scale, terrain, filler)
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, mapgen_to_table)

-- register the main mapgen function to on_generated
minetest.register_on_generated(function(minp, maxp, seed)
	-- schedule the main generate function
	minetest.after(MAPGEN_GROUP_DELAY, function()
		generate (minp, maxp, 0)
	end)
end)
