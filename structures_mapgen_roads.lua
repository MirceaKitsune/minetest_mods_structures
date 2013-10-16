-- Structures: Mapgen functions: Roads
-- This file contains the building mapgen functions, for structures meant to be placed as roads

-- Settings

-- minimum space between two roads in segments
MAPGEN_ROADS_MIN = 3

-- Local functions - Branch

-- when a new point branches from an existing one, this determines its distance
local function branch_size (length_start, length_end, axis, size, rectangles)
	local dist = 0
	local dist_scan = math.abs(length_start - length_end)
	local size_min = size * MAPGEN_ROADS_MIN

	-- scan the rectangles of other roads and detect if this segment would intersect any
	for i, rectangle in ipairs(rectangles) do

		if ((axis >= rectangle.start_z) and (axis <= rectangle.end_z)) or
		((axis >= rectangle.start_x) and (axis <= rectangle.end_x)) then
			local dist_limit_X = dist_scan
			local dist_limit_Z = dist_scan

			-- positive X
			if (length_start <= rectangle.end_x) and (length_end >= rectangle.start_x) then
				dist_limit_X = math.abs(rectangle.start_x - length_start) - size
			-- negative X
			elseif (length_end <= rectangle.end_x) and (length_start >= rectangle.start_x) then
				dist_limit_X = math.abs(rectangle.end_x - length_start)
			end

			-- positive Z
			if (length_start <= rectangle.end_z) and (length_end >= rectangle.start_z) then
				dist_limit_Z = math.abs(rectangle.start_z - length_start) - size
			-- negative Z
			elseif (length_end <= rectangle.end_z) and (length_start >= rectangle.start_z) then
				dist_limit_Z = math.abs(rectangle.end_z - length_start)
			end

			-- if scan distance cuts through this road, limit it to the intersection point
			dist_scan = math.min(dist_limit_X, dist_limit_Z)
		end
	end

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

	-- if distance is zero, we can't create a new point
	if (dist < size ) then
		return nil
	end

	-- handle negative direction
	if (length_start > length_end) then
		dist = -dist
	end

	return dist
end

-- branches multiple points from each point in a list
TIMES = 0
local function branch (points, mins, maxs, name, size, schemes, rectangles)
	-- notice: tables in Lua ar passed to functions by reference, so it's easier to modify schemes and rectangles here directly

	local new_points = { }

	-- loop through all points in the list
	for i, point in ipairs(points) do
		local new_points_this = { }

		-- each point may branch in any direction except the one it came from
		-- directions: 1 = left, 2 = up, 3 = right, 4 = down
		if (point.paths[1] == true) then
			-- create a new point to the left
			local distance = branch_size (point.x - 1, mins.x + size, point.z, size, rectangles)
			if (distance ~= nil) then
				point.paths[1] = false
				local new_point = {x = point.x + distance, z = point.z, paths = {true, true, false, true} }
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- road rectangle
				local new_rectangle = { start_x = new_point.x + size, start_z = new_point.z, end_x = point.x - 1, end_z = point.z + size - 1 }
				table.insert(rectangles, new_rectangle)
				-- intersection rectangle
				local new_rectangle_intersection = { start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size - 1, end_z = new_point.z + size - 1 }
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if (point.paths[2] == true) then
			-- create a new point upward
			local distance = branch_size (point.z + size, maxs.z - size, point.x, size, rectangles)
			if (distance ~= nil) then
				point.paths[2] = false
				local new_point = {x = point.x, z = point.z + distance, paths = {true, true, true, false} }
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)
				z_highest = new_point.z

				-- road rectangle
				local new_rectangle = { start_x = point.x, start_z = point.z + size, end_x = new_point.x + size - 1, end_z = new_point.z - 1 }
				table.insert(rectangles, new_rectangle)
				-- intersection rectangle
				local new_rectangle_intersection = { start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size - 1, end_z = new_point.z + size - 1 }
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if (point.paths[3] == true) then
			-- create a new point to the right
			local distance = branch_size (point.x + size, maxs.x - size, point.z, size, rectangles)
			if (distance ~= nil) then
				point.paths[3] = false
				local new_point = {x = point.x + distance, z = point.z, paths = {false, true, true, true} }
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- road rectangle
				local new_rectangle = { start_x = point.x + size, start_z = point.z, end_x = new_point.x - 1, end_z = new_point.z + size - 1 }
				table.insert(rectangles, new_rectangle)
				-- intersection rectangle
				local new_rectangle_intersection = { start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size - 1, end_z = new_point.z + size - 1 }
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if (point.paths[4] == true) then
			-- create a new point downward
			local distance = branch_size (point.z - 1, mins.z + size, point.x, size, rectangles)
			if (distance ~= nil) then
				point.paths[4] = false
				local new_point = {x = point.x, z = point.z + distance, paths = {true, false, true, true} }
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- road rectangle
				local new_rectangle = { start_x = new_point.x, start_z = new_point.z + size, end_x = point.x + size - 1, end_z = point.z - 1 }
				table.insert(rectangles, new_rectangle)
				-- intersection rectangle
				local new_rectangle_intersection = { start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size - 1, end_z = new_point.z + size - 1 }
				table.insert(rectangles, new_rectangle_intersection)
			end
		end

		-- insert this piece of road to the schemes table
		-- scheme: start_point [1], end_points [2], name[3], size[4]
		local new_scheme = {point, new_points_this, name, size}
		table.insert(schemes, new_scheme)
	end

	-- return the new points that were generated, as well as the road scheme we got
	return new_points
end

-- Global functions - Roads

-- once a point and its directions have been determined, this spawns the road segments
function mapgen_roads_spawn (schemes, height)
	-- scheme: start_point [1], end_points [2], name [3], size [4]
	for i, scheme in ipairs(schemes) do

		local pos_start = { x = scheme[1].x, z = scheme[1].z }
		local name = scheme[3]
		local size = scheme[4]

		-- loop through the end points
		if (scheme[2] ~= nil) and (#scheme[2] > 0) then
			for x, point in ipairs(scheme[2]) do
				local pos_end = { x = point.x, z = point.z }

				-- determine the direction of this end point from the starting point, and draw the road accordingly
				-- TODO: Get and use correct y size for road segments
				if (pos_start.x > pos_end.x) then
					-- the point is left
					for w = pos_start.x - size, pos_end.x + size, -size do
						local pos1 = { x = w - 1, y = height, z = pos_start.z - 1 }
						local pos2 = { x = w + size, y = height + size, z = pos_start.z + size }
						io_area_import(pos1, pos2, 0, name.."_I", false)
					end
				elseif (pos_start.x < pos_end.x) then
					-- the point is right
					for w = pos_start.x + size, pos_end.x - size, size do
						local pos1 = { x = w - 1, y = height, z = pos_start.z - 1 }
						local pos2 = { x = w + size, y = height + size, z = pos_start.z + size }
						io_area_import(pos1, pos2, 180, name.."_I", false)
					end
				elseif (pos_start.z > pos_end.z) then
					-- the point is down
					for w = pos_start.z - size, pos_end.z + size, -size do
						local pos1 = { x = pos_start.x - 1, y = height, z = w - 1 }
						local pos2 = { x = pos_start.x + size, y = height + size, z = w }
						io_area_import(pos1, pos2, 90, name.."_I", false)
					end
				elseif (pos_start.z < pos_end.z) then
					-- the point is up
					for w = pos_start.z + size, pos_end.z - size, size do
						local pos1 = { x = pos_start.x - 1, y = height, z = w - 1 }
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
	-- parameters: group [1], type [2], structure [3], count [4], bury [5]

	local mins = {x = pos.x, z = pos.z}
	local maxs = {x = pos.x + scale_horizontal, z = pos.z + scale_horizontal}
	-- roads table which will be filled and returned by this function
	local schemes = { }
	local rectangles = { }

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
				local instances = tonumber(entry[4]) - 1
				local points = { {x = math.random(mins.x, maxs.x), z = math.random(mins.z, maxs.z), paths = {true, true, true, true} } }
				table.insert(rectangles, { start_x = points[1].x, start_z = points[1].z, end_x = points[1].x + size.x - 1, end_z = points[1].z + size.z - 1 })

				while (instances > 0) do
					-- if we have more points than the remaining probability of this road, trim the point table
					if (#points > instances) then
						for i = #points - instances + 1, #points do
							points[i] = nil
						end
					end

					local new_points = branch(points, mins, maxs, entry[3], size.x, schemes, rectangles)
					points = new_points

					-- keep going as long as new points exist
					if (#new_points > 0) then
						instances = instances - #new_points
					else
						break
					end
				end
			end
		end
	end

	-- return the scheme containing pieces of road designs, which will later be put together and generated
	return schemes, rectangles
end
