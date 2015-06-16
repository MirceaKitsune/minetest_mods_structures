-- Structures: Mapgen functions: Roads
-- This file contains the building mapgen functions, for structures meant to be placed as roads

-- Local functions - Branch

-- determines the distance of an end point branching from its starting point
local function branch_size (length_start, length_end, axis, size, rectangles, entry)
	local dist = 0
	local dist_scan = math.abs(length_start - length_end)
	local size_min = size * entry.branch_min

	-- scan the rectangles of other roads and detect if this segment would intersect any
	for i, rectangle in ipairs(rectangles) do
		if not (rectangle.layer and entry.layer and rectangle.layer ~= entry.layer) and
		((axis >= rectangle.start_z and axis <= rectangle.end_z) or
		(axis >= rectangle.start_x and axis <= rectangle.end_x)) then
			local dist_limit_X = dist_scan
			local dist_limit_Z = dist_scan

			-- positive X
			if length_start <= rectangle.end_x and length_end >= rectangle.start_x then
				dist_limit_X = math.abs(rectangle.start_x - length_start) - size
			-- negative X
			elseif length_end <= rectangle.end_x and length_start >= rectangle.start_x then
				dist_limit_X = math.abs(rectangle.end_x - length_start)
			end
			-- positive Z
			if length_start <= rectangle.end_z and length_end >= rectangle.start_z then
				dist_limit_Z = math.abs(rectangle.start_z - length_start) - size
			-- negative Z
			elseif length_end <= rectangle.end_z and length_start >= rectangle.start_z then
				dist_limit_Z = math.abs(rectangle.end_z - length_start)
			end

			-- if scan distance cuts through this road, limit it to the intersection point
			dist_scan = math.min(dist_limit_X, dist_limit_Z)
		end
	end

	-- if there's not enough room to fit the minimum amount of road segments, do nothing
	if dist_scan < size_min then
		return nil
	end

	-- randomize between minimum and maximum distance
	dist_scan = math.random(size_min, dist_scan)

	-- now determine how many road segments fit inside this distance
	while (dist_scan >= size) do
		dist = dist + size
		dist_scan = dist_scan - size
	end

	-- handle negative direction
	if length_start > length_end then
		dist = -dist
	end

	return dist
end

-- decides which shape and which angle an intersection has, based on the roads it connects
local function branch_draw_intersection(paths, entry)
	-- intersection shapes are assumed to start down-up and left-right at 0 angle
	-- directions: 1 = left, 2 = up, 3 = right, 4 = down

	-- intersections that connect to 4 point (X shape), default
	local name = entry.name_X
	local angle = 90 * math.random(0, 3)

	-- intersections that connect to 1 point (P shape)
	if paths[1] == true and paths[2] == false and paths[3] == false and paths[4] == false then
		name = entry.name_P
		angle = 90
	elseif paths[1] == false and paths[2] == true and paths[3] == false and paths[4] == false then
		name = entry.name_P
		angle = 180
	elseif paths[1] == false and paths[2] == false and paths[3] == true and paths[4] == false then
		name = entry.name_P
		angle = 270
	elseif paths[1] == false and paths[2] == false and paths[3] == false and paths[4] == true then
		name = entry.name_P
		angle = 0

	-- intersections that connect to 2 point (L shape)
	elseif paths[1] == true and paths[2] == false and paths[3] == false and paths[4] == true then
		name = entry.name_L
		angle = 0
	elseif paths[1] == false and paths[2] == false and paths[3] == true and paths[4] == true then
		name = entry.name_L
		angle = 270
	elseif paths[1] == true and paths[2] == true and paths[3] == false and paths[4] == false then
		name = entry.name_L
		angle = 90
	elseif paths[1] == false and paths[2] == true and paths[3] == true and paths[4] == false then
		name = entry.name_L
		angle = 180

	-- intersections that connect to 2 point (I shape)
	elseif paths[1] == false and paths[2] == true and paths[3] == false and paths[4] == true then
		name = entry.name_I
		angle = 180 * math.random(0, 1)
	elseif paths[1] == true and paths[2] == false and paths[3] == true and paths[4] == false then
		name = entry.name_I
		angle = 90 + (180 * math.random(0, 1))

	-- intersections that connect to 3 point (T shape)
	elseif paths[1] == true and paths[2] == false and paths[3] == true and paths[4] == true then
		name = entry.name_T
		angle = 0
	elseif paths[1] == true and paths[2] == true and paths[3] == false and paths[4] == true then
		name = entry.name_T
		angle = 90
	elseif paths[1] == true and paths[2] == true and paths[3] == true and paths[4] == false then
		name = entry.name_T
		angle = 180
	elseif paths[1] == false and paths[2] == true and paths[3] == true and paths[4] == true then
		name = entry.name_T
		angle = 270
	end

	return name, angle
end

-- obtains the position and rotation of all road segments between the given points
local function branch_draw (point_start, points_end, mins, maxs, size_h, size_v, center, perlin, entry)
	local new_scheme = {}
	local pos_start = {x = point_start.x, z = point_start.z}
	local size = {x = size_h, y = size_v, z = size_h}

	-- draw the intersection at the starting point
	local point_start_height = calculate_perlin_height(perlin, maxs.x - pos_start.x, maxs.z - pos_start.z, center, entry.alignment)
	local point_start_pos = {x = pos_start.x, y = point_start_height + entry.offset, z = pos_start.z}
	local point_start_name, point_start_angle = branch_draw_intersection(point_start.paths, entry)
	table.insert(new_scheme, {point_start_name, point_start_pos, point_start_angle, size})

	-- loop through the end points if any
	for x, point_end in ipairs(points_end) do
		local pos_end = {x = point_end.x, z = point_end.z}

		-- determine the direction of this end point from the starting point, and draw the road accordingly
		if pos_start.x > pos_end.x then
			-- the point is left
			for w = pos_start.x - size_h, pos_end.x + size_h, -size_h do
				local pos = {x = w, z = pos_start.z}
				local height = calculate_perlin_height(perlin, maxs.x - pos.x, maxs.z - pos.z, center, entry.alignment)
				pos.y = height + entry.offset
				table.insert(new_scheme, {entry.name_I, pos, 90, size})
			end
		elseif pos_start.x < pos_end.x then
			-- the point is right
			for w = pos_start.x + size_h, pos_end.x - size_h, size_h do
				local pos = {x = w, z = pos_start.z}
				local height = calculate_perlin_height(perlin, maxs.x - pos.x, maxs.z - pos.z, center, entry.alignment)
				pos.y = height + entry.offset
				table.insert(new_scheme, {entry.name_I, pos, 270, size})
			end
		elseif pos_start.z > pos_end.z then
			-- the point is down
			for w = pos_start.z - size_h, pos_end.z + size_h, -size_h do
				local pos = {x = pos_start.x, z = w}
				local height = calculate_perlin_height(perlin, maxs.x - pos.x, maxs.z - pos.z, center, entry.alignment)
				pos.y = height + entry.offset
				table.insert(new_scheme, {entry.name_I, pos, 180, size})
			end
		elseif pos_start.z < pos_end.z then
			-- the point is up
			for w = pos_start.z + size_h, pos_end.z - size_h, size_h do
				local pos = {x = pos_start.x, z = w}
				local height = calculate_perlin_height(perlin, maxs.x - pos.x, maxs.z - pos.z, center, entry.alignment)
				pos.y = height + entry.offset
				table.insert(new_scheme, {entry.name_I, pos, 0, size})
			end
		end
	end

	return new_scheme
end

-- calculates the branching of end points from starting points
local function branch (points, mins, maxs, size, limit, schemes, rectangles, center, perlin, entry)
	local new_points = {}
	local new_limit = limit

	-- loop through the starting points
	for i, point in ipairs(points) do
		local new_points_this = {}
		local size_h = size.x
		local size_v = size.y

		-- each point may branch in any direction except the one it came from, as long as the point limit of this road hasn't been reached
		-- directions: 1 = left, 2 = up, 3 = right, 4 = down
		if point.paths[1] == false and new_limit > 0 then
			-- create a new point to the left
			local distance = branch_size(point.x - 1, mins.x, point.z, size_h, rectangles, entry)
			if distance ~= nil then
				point.paths[1] = true
				new_limit = new_limit - 1

				local new_point = {x = point.x + distance, z = point.z, paths = {false, false, true, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = new_point.x + size_h, start_z = new_point.z, end_x = point.x - 1, end_z = point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size_h - 1, end_z = new_point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[2] == false and new_limit > 0 then
			-- create a new point upward
			local distance = branch_size(point.z + size_h, maxs.z, point.x, size_h, rectangles, entry)
			if distance ~= nil then
				point.paths[2] = true
				new_limit = new_limit - 1

				local new_point = {x = point.x, z = point.z + distance, paths = {false, false, false, true}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = point.x, start_z = point.z + size_h, end_x = new_point.x + size_h - 1, end_z = new_point.z - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size_h - 1, end_z = new_point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[3] == false and limit > 0 then
			-- create a new point to the right
			local distance = branch_size(point.x + size_h, maxs.x, point.z, size_h, rectangles, entry)
			if distance ~= nil then
				point.paths[3] = true
				new_limit = new_limit - 1

				local new_point = {x = point.x + distance, z = point.z, paths = {true, false, false, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = point.x + size_h, start_z = point.z, end_x = new_point.x - 1, end_z = new_point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size_h - 1, end_z = new_point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[4] == false and new_limit > 0 then
			-- create a new point downward
			local distance = branch_size(point.z - 1, mins.z, point.x, size_h, rectangles, entry)
			if distance ~= nil then
				point.paths[4] = true
				new_limit = new_limit - 1

				local new_point = {x = point.x, z = point.z + distance, paths = {false, true, false, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = new_point.x, start_z = new_point.z + size_h, end_x = point.x + size_h - 1, end_z = point.z - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size_h - 1, end_z = new_point.z + size_h - 1, layer = entry.layer}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end

		-- get the structures for this piece of road design, and add them to the schemes table
		local new_scheme = branch_draw(point, new_points_this, mins, maxs, size_h, size_v, center, perlin, entry)
		for v, road in ipairs(new_scheme) do
			table.insert(schemes, road)
		end
	end

	-- return the new points that were generated, which will be sent back to this function to continue the road network
	return new_points, new_limit
end

-- Global functions - Roads

-- analyzes roads in the mapgen table and acts accordingly
function mapgen_roads_get (pos_start, pos_end, center, perlin, roads)
	local mins = {x = pos_start.x, z = pos_start.z}
	local maxs = {x = pos_end.x, z = pos_end.z}
	-- roads table which will be filled and returned by this function
	local schemes = {}
	local rectangles = {}

	for i, entry in ipairs(roads) do
		-- get the size of this road
		-- each segment must be square and all segments the same size horizontally
		local size = nil
		local roads = {entry.name_I, entry.name_L, entry.name_P, entry.name_T, entry.name_X}
		for w, road in ipairs(roads) do
			local current_size = io_get_size(0, road)
			if current_size.x ~= current_size.z then
				print("Structure Mapgen Error: The segment is not square, skipping this road.")
				size = nil
				break
			elseif w > 1 and size.x ~= current_size.x then
				print("Structure Mapgen Error: Two segments of the same road type are of different sizes, skipping this road.")
				size = nil
				break
			end
			size = current_size
		end

		if size ~= nil then
			-- initialize the road network with a starting point
			local limit = calculate_random(entry.count, false) - 1
			local points = {{x = math.random(mins.x, maxs.x - size.x), z = math.random(mins.z, maxs.z - size.z), paths = {false, false, false, false}}}
			table.insert(rectangles, {start_x = points[1].x, start_z = points[1].z, end_x = points[1].x + size.x - 1, end_z = points[1].z + size.z - 1, layer = entry.layer})

			while (#points > 0) do
				-- branch the existing points, then prepare the new ones for branching in the next loop iteration
				-- this loop ends when no new points are created and all existing points were handles
				local new_points, new_limit = branch(points, mins, maxs, size, limit, schemes, rectangles, center, perlin, entry)
				points = new_points
				limit = new_limit
			end
		end
	end

	-- return the structure scheme of the road design, as well as the bounding boxes of roads
	return schemes, rectangles
end
