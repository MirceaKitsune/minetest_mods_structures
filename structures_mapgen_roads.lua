-- Structures: Mapgen functions: Roads
-- This file contains the building mapgen functions, for structures meant to be placed as roads

-- Settings

-- minimum space between two roads in segments
MAPGEN_ROADS_MIN = 3

-- Local functions - Branch

-- when a new point branches from an existing one, this determines its distance
local function branch_size (current_pos, new_pos, size)
	local dist = 0
	local dist_scan = math.abs(current_pos - new_pos) - size
	local size_min = size * MAPGEN_ROADS_MIN

	-- if there's not enough room to fit one road segment, do nothing
	if (dist_scan < size_min) then
		return nil
	end

	-- randomize between current value (max) and the size of a segment (min)
	dist_scan = math.random(size_min, dist_scan)

	-- now see how many road segments fit inside this distance
	while (dist_scan >= size) do
		dist = dist + size
		dist_scan = dist_scan - size
	end

	-- handle negative direction
	if (current_pos > new_pos) then
		dist = -dist
	end

	return dist
end

-- branches multiple points from each point in a list
local function branch (points, mins, maxs, name, size)

	local new_points = { }
	local new_schemes = { }

	-- loop through all points in the list
	for i, point in ipairs(points) do
		local new_points_this = { }

		-- loop through the directions of this point
		for x, dir in ipairs(point.paths) do

			-- each point may randomly branch in any direction except the one it came from
			path_first = math.random(0, 1) == 1
			path_second = math.random(0, 1) == 1
			path_third = math.random(0, 1) == 1

			-- create a new point in this direction if it's free
			if (dir == true) then
				-- directions: 1 = left, 2 = up, 3 = right, 4 = down
				if (x == 1) then
					-- create a new point to the left
					local distance = branch_size (point.x, mins.x, size)
					if (distance ~= nil) then
						local new_point = {x = point.x + distance, z = point.z, paths = {path_first, path_second, false, path_third} }
						table.insert(new_points, new_point)
						table.insert(new_points_this, new_point)
					end
				elseif (x == 2) then
					-- create a new point upward
					local distance = branch_size (point.z, maxs.z, size)
					if (distance ~= nil) then
						local new_point = {x = point.x, z = point.z + distance, paths = {path_first, path_second, path_third, false} }
						table.insert(new_points, new_point)
						table.insert(new_points_this, new_point)
					end
				elseif (x == 3) then
					-- create a new point to the right
					local distance = branch_size (point.x, maxs.x, size)
					if (distance ~= nil) then
						local new_point = {x = point.x + distance, z = point.z, paths = {false, path_first, path_second, path_third} }
						table.insert(new_points, new_point)
						table.insert(new_points_this, new_point)
					end
				elseif (x == 4) then
					-- create a new point downward
					local distance = branch_size (point.z, mins.z, size)
					if (distance ~= nil) then
						local new_point = {x = point.x, z = point.z + distance, paths = {path_first, false, path_second, path_third} }
						table.insert(new_points, new_point)
						table.insert(new_points_this, new_point)
					end
				end
			end
		end

		-- insert this piece of road to the schemes table
		-- scheme: start_point [1], end_points [2], name[3], size[4]
		if (#new_points_this > 0) then
			local new_scheme = {point, new_points_this, name, size}
			table.insert(new_schemes, new_scheme)
		end
	end

	-- return the new points that were generated, as well as the road scheme we got
	return new_points, new_schemes
end

-- Global functions - Roads

-- once a point and its directions have been determined, this spawns the road segments
function mapgen_roads_spawn (schemes, height)
	-- scheme: start_point [1], end_points [2], name[3], size[4]
	for i, scheme in ipairs(schemes) do

		local pos_start = { x = scheme[1].x, z = scheme[1].z }
		local name = scheme[3]
		local size = scheme[4]

		-- loop through the end points
		if (scheme[2] ~= nil) and (#scheme[2] > 0) then
			for x, point in ipairs(scheme[2]) do
				local pos_end = { x = point.x, z = point.z }

				-- determine the direction of this end point from the starting point, and draw the road accordingly
				if (pos_start.x > pos_end.x) then
					-- the point is left
					for w = pos_start.x, pos_end.x - size, -size do
						local pos1 = { x = w - size, y = height, z = pos_start.z }
						local pos2 = { x = w, y = height + size, z = pos_start.z + size }
						io_area_import(pos1, pos2, 0, name.."_I", false)
					end
				elseif (pos_start.x < pos_end.x) then
					-- the point is right
					for w = pos_start.x + size, pos_end.x - size, size do
						local pos1 = { x = w, y = height, z = pos_start.z }
						local pos2 = { x = w + size, y = height + size, z = pos_start.z + size }
						io_area_import(pos1, pos2, 180, name.."_I", false)
					end
				elseif (pos_start.z > pos_end.z) then
					-- the point is down
					for w = pos_start.z, pos_end.z - size, -size do
						local pos1 = { x = pos_start.x, y = height, z = w - size }
						local pos2 = { x = pos_start.x + size, y = height + size, z = w }
						io_area_import(pos1, pos2, 90, name.."_I", false)
					end
				elseif (pos_start.z < pos_end.z) then
					-- the point is up
					for w = pos_start.z + size, pos_end.z - size, size do
						local pos1 = { x = pos_start.x, y = height, z = w }
						local pos2 = { x = pos_start.x + size, y = height + size, z = w + size }
						io_area_import(pos1, pos2, 270, name.."_I", false)
					end
				end
			end
		end

	end
end

-- analyzes buildings in the mapgen group and returns them as a lists of parameters
function mapgen_roads_get (pos, scale_horizontal, group)
	-- parameters: group [1], type [2], structure [3], node [4], min height [5], max height [6], count [7], bury [8]

	local mins = {x = pos.x, z = pos.z}
	local maxs = {x = pos.x + scale_horizontal, z = pos.z + scale_horizontal}
	-- roads table which will be filled and returned by this function
	local schemes = { }

	for i, entry in ipairs(mapgen_table) do
		-- only if this is a road which belongs to the chosen mapgen group
		if (entry[1] == group) and (entry[2] == "road") then

			-- get the size of this road
			-- each segment must be square and all segments the same size horizontally
			local size = nil
			local roads = {"_I", "_L", "_T", "_X" }
			for w, road in ipairs(roads) do
				local current_size = io_get_size(0, entry[3]..road)
				if (current_size.x ~= current_size.z) then
					print("Structure Mapgen Error: The segment is not square, skipping this road.")
					size = nil
					break
				elseif (w > 1) and (size.x ~= current_size.x) then
					print("Structure Mapgen Error: Two segments of the same road type are of different sizes, skipping this road.")
					size = nil
					break
				end
				size = current_size
			end

			if (size ~= nil) then
				-- initialize the road network with a starting point
				local instances = tonumber(entry[7]) - 1
				local points = { {x = math.random(mins.x, maxs.x), z = math.random(mins.z, maxs.z), paths = {true, true, true, true} } }

				while (instances > 0) do
					local new_points, new_schemes = branch(points, mins, maxs, entry[3], size.x)
					points = new_points

					-- keep going as long as new points exist
					if (#new_points > 0) then
						instances = instances - #new_points
					else
						break
					end

					-- add the new schemes to the final schemes table
					for _, v in ipairs(new_schemes) do
						table.insert(schemes, v)
					end
				end
			end
		end
	end

	-- return the scheme containing pieces of road designs, which will later be put together and generated
	return schemes
end
