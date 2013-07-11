-- Structures: Mapgen functions: Buildings
-- This file contains the building mapgen functions, for structures meant to be placed as buildings

-- Settings

-- each building is delayed by this many seconds
-- high values cause buildings to spawn more slowly, low values deal more stress to the CPU and encourage incomplete spawns
MAPGEN_BUILDINGS_DELAY = 0.5
-- only spawn if the height of each corner is within this distance against the ground (top is air and bottom is not)
-- low values reduce spawns on extreme terrain, but also decrease count
local MAPGEN_BUILDINGS_LEVEL = 20
-- add this many nodes to each side when cutting and adding the floor
local MAPGEN_BUILDINGS_BORDER = 2
-- if true, create a floor under each building by this many nodes to fill empty space
local MAPGEN_BUILDINGS_FILL = true
-- nodes that text can be assigned to for addresses (signs, screens, etc), leave empty to disable
local MAPGEN_BUILDINGS_SIGNS = {"default:sign_wall"}

-- Global functions - Buildings

-- analyzes buildings in the mapgen group and returns them as a lists of parameters
function mapgen_buildings_get (pos, scale_horizontal, scale_vertical, group)
	-- parameters: structure [1], group [2], node [3], min height [4], max height [5], count [6], bury [7]
	-- x = left & right, z = up & down

	-- buildings table which will be filled and returned by this function
	local buildings = { }

	-- first generate a list of indexes for all buildings, containing an entry for each time it will be spawned
	local instances = { }
	for i, entry in ipairs(mapgen_table) do
		-- only if this building belongs to the chosen mapgen group
		if (entry[2] == group) then
			for x = 1, tonumber(entry[6]) do
				table.insert(instances, i)
			end
		end
	end

	-- now randomize the table so building instances won't be spawned in an uniform order
	local structs = table.getn(instances)
	for i in ipairs(instances) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(structs)

		-- swap the two entries
		local old = instances[i]
		instances[i] = instances[rand]
		instances[rand] = old
	end

	-- store the top-right corners of buildings in the left and right columns (compared to the current column)
	-- in each colum, we check the left list and set the right one for later use, then right becomes left when we advance to the next colum
	local points_left = { }
	local points_right = { }
	-- the column and row we are currently in
	local row = 1
	local column = 1
	-- current Z location, we start at group position
	local current_z = pos.z
	-- largest X size, used to calculate columns based on row width
	local largest_x = 0

	-- go through the mapgen table
	for i, instance in ipairs(instances) do
		entry = mapgen_table[instance]

		-- if the current row was filled, jump to the next column
		if (row > scale_horizontal) then
			row = 1
			column = column + largest_x
			-- start again from the top
			current_z = pos.z
			-- the list of next points becomes the list of current points
			points_left = points_right
			points_right = { }
		end
		-- if the columns were filled, return the sturcute table and stop doing anything
		if (column > scale_horizontal) then
			return buildings
		end

		-- location will be gradually determined in each direction
		local location = { x = 0, y = 0, z = 0, number = 0 }
		location.z = current_z -- we determined Z location

		-- choose angle (0, 90, 180, 270) based on distance from center, and size based on angle
		-- it's hard to find an accurate formula here, but it keeps buildings oriented uniformly
		local angle = 0
		if (row < scale_horizontal / 2) and (column < scale_horizontal / 2) then
			angle = 180
		elseif (row < scale_horizontal / 2) then
			angle = 90
		elseif (column < scale_horizontal / 2) then
			angle = 270
		end
		local size = io_get_size(angle, entry[1])
		-- actual space the building will take up
		local building_width = size.x + MAPGEN_BUILDINGS_BORDER * 2
		local building_height = size.z + MAPGEN_BUILDINGS_BORDER * 2

		-- determine which of the buildings in the left row have their top-right corners intersecting this building, and push this building to the right accordingly
		local edge = pos.x
		for w, point in ipairs(points_left) do
			-- check if the point intersects our building
			if (point.z >= current_z - building_height) and (point.z <= current_z + building_height) then
				-- if this point is further to the right than the last one, bump the edge past its location
				if (edge < point.x) then
					edge = point.x
				end
			end
		end
		location.x = edge -- we determined X location

		-- add each of the building's corners to a table
		local corners = { }
		table.insert(corners, { x = location.x, z = location.z } )
		table.insert(corners, { x = location.x, z = location.z + building_height } )
		table.insert(corners, { x = location.x + building_width, z = location.z } )
		table.insert(corners, { x = location.x + building_width, z = location.z + building_height } )
		-- minimum and maximum heights will be calculated further down
		-- in order for the checks to work, initialize them in reverse
		local corner_bottom = pos.y + scale_vertical
		local corner_top = pos.y
		-- start scanning downward
		for search = pos.y + scale_vertical, pos.y, -1 do
			-- we scan from top to bottom, so the search might start above the building's maximum height limit
			-- if however it gets below the minimum limit, there's no point to keep going
			if (search <= tonumber(entry[4])) then
				break
			elseif (search <= tonumber(entry[5])) then
				-- loop through each corner at this height
				for i, v in pairs(corners) do
					-- check if the node below is the trigger node
					local pos_down = { x = v.x, y = search - 1, z = v.z }
					local node_down = minetest.env:get_node(pos_down)
					if (node_down.name == entry[3]) then
						-- check if the node here is an air node or plant
						local pos_here = { x = v.x, y = search, z = v.z }
						local node_here = minetest.env:get_node(pos_here)
						if (node_here.name == "air") or (minetest.registered_nodes[node_here.name].drawtype == "plantlike") then
							-- this corner is touching our trigger node at surface level
							-- check and apply minimum and maximum height
							if (corner_bottom > pos_down.y) then
								corner_bottom = pos_down.y
							end
							if (corner_top < pos_down.y) then
								corner_top = pos_down.y
							end
							-- we checked everything we needed for this corner, it can be removed from the table
							corners[i] = nil
						end
					end
				end
			end
		end

		-- each successful corner is removed from the table, so if there are any corners left it means something went wrong
		if (table.getn(corners) == 0) then
			-- calculate if terrain roughness is acceptable
			if (corner_top - corner_bottom <= MAPGEN_BUILDINGS_LEVEL) then
				-- set the average height
				local height_average = math.ceil((corner_bottom + corner_top) / 2)
				location.y = height_average -- we determined Y location

				-- add the loop iteration into the location table (used for address signs)
				location.number = i

				-- the building may spawn, insert it into the buildings table
				-- parameters: name [1], position [2], angle [3], size [4], bottom [5], bury [6], node [7]
				table.insert(buildings, { entry[1], location, angle, size, corner_bottom, entry[7], entry[3] } )
			end
		end

		-- add this building's upper-right corner to the right point list
		upright = { }
		upright.x = location.x + building_width
		upright.z = location.z
		table.insert(points_right, upright)
		-- push Z location so the next building in this row will spawn right under this building
		current_z = current_z + building_height
		-- update the largest X size of this row
		if (building_width > largest_x) then
			largest_x = building_width
		end
		-- increase the row size
		row = row + building_height
	end

	return buildings
end

-- naturally spawns a building with the given parameters
function mapgen_buildings_spawn (name, pos, angle, size, bottom, bury, trigger)

	-- determine the corners of the spawn cube
	-- since the I/O function doesn't include the start and end values as valid locations (only the space between them), decrease start position by 1 to get the right spot
	local pos1 = { x = pos.x + MAPGEN_BUILDINGS_BORDER - 1, y = pos.y - 1, z = pos.z + MAPGEN_BUILDINGS_BORDER - 1 }
	local pos2 = { x = pos.x + size.x + MAPGEN_BUILDINGS_BORDER, y = pos.y + size.y, z = pos.z + size.z + MAPGEN_BUILDINGS_BORDER }
	local pos1_frame = { x = pos.x - 1, y = pos.y - 1, z = pos.z - 1 }
	local pos2_frame = { x = pos.x + size.x + MAPGEN_BUILDINGS_BORDER * 2, y = pos.y + size.y, z = pos.z + size.z + MAPGEN_BUILDINGS_BORDER * 2}

	-- we'll spawn the building in a suitable spot, but what if it's the top of a peak?
	-- to avoid parts of the building left floating, cover everything to the bottom
	if (MAPGEN_BUILDINGS_FILL) then
		local floor1 = { x = pos1_frame.x, y = pos.y, z = pos1_frame.z }
		local floor2 = { x = pos2_frame.x, y = bottom, z = pos2_frame.z }
		io_area_fill(floor1, floor2, trigger)
	end
	-- clear the area before spawning
	io_area_fill(pos1_frame, pos2_frame, nil)

	-- apply burying
	pos1.y = pos1.y - bury
	pos2.y = pos2.y - bury

	-- at last, create the building itself
	io_area_import(pos1, pos2, angle, name, false)

	-- changes to node metadata after the building has spawned are performed in this code
	if (table.getn(MAPGEN_BUILDINGS_SIGNS) ~= 0) then
		for search_x = pos1.x, pos2.x do
			for search_y = pos1.y, pos2.y do
				for search_z = pos1.z, pos2.z do
					-- if the structure contains signs, set their text to the address of this building
					local pos_here = { x = search_x, y = search_y, z = search_z }
					local node_here = minetest.env:get_node(pos_here)
					if (node_here.name ~= "air") and (calculate_node_in_table(node_here, MAPGEN_BUILDINGS_SIGNS) == true) then
						local address = pos.number..", "..name
						local meta = minetest.env:get_meta(pos_here)
						meta:set_string("text", address)
						meta:set_string("infotext", '"'..address..'"')
					end
				end
			end
		end
	end
end
