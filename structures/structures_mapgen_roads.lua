-- Structures: Mapgen functions: Roads
-- This file contains the building mapgen functions, for structures meant to be placed as roads

-- Local functions - Branch

-- determines the distance of an end point branching from its starting point
local function mapgen_roads_branch_size (length_start, length_end, axis, size, rectangles, entry)
	-- axis is essentially the start position across one axis (x or z), while length_start and length_end are the start and end positions across the other axis
	local dist = 0
	local dist_scan = math.abs(length_start - length_end)
	local size_segment = math.max(size.x or size.z)
	local size_min = size_segment * entry.branch_min
	local size_max = size_segment * entry.branch_max

	-- scan the rectangles of other roads and detect if this segment would intersect any
	for _, rectangle in ipairs(rectangles) do
		if calculate_matching(rectangle.layers, entry.layers) and
		((axis + size_segment - 1 >= rectangle.start_x and axis <= rectangle.end_x) or
		(axis + size_segment - 1 >= rectangle.start_z and axis <= rectangle.end_z)) then
			local dist_limit_x = dist_scan
			local dist_limit_z = dist_scan

			-- positive X
			if length_start <= rectangle.end_x and length_end >= rectangle.start_x then
				dist_limit_x = math.abs(rectangle.start_x - length_start) - size_segment
			-- negative X
			elseif length_end <= rectangle.end_x and length_start >= rectangle.start_x then
				dist_limit_x = math.abs(rectangle.end_x - length_start)
			end
			-- positive Z
			if length_start <= rectangle.end_z and length_end >= rectangle.start_z then
				dist_limit_z = math.abs(rectangle.start_z - length_start) - size_segment
			-- negative Z
			elseif length_end <= rectangle.end_z and length_start >= rectangle.start_z then
				dist_limit_z = math.abs(rectangle.end_z - length_start)
			end

			-- if scan distance cuts through this road, limit it to the intersection point
			local dist_limit = math.min(dist_limit_x, dist_limit_z)
			if dist_limit < dist_scan then
				dist_scan = dist_limit
			end
		end
	end

	-- handle minimum and maximum segment settings
	if dist_scan < size_min then
		return nil
	elseif dist_scan > size_max then
		dist_scan = size_max
	end

	-- randomize between minimum and maximum distance
	dist_scan = math.random(size_min, dist_scan)

	-- now determine how many road segments fit inside this distance
	while (dist_scan >= size_segment) do
		dist = dist + size_segment
		dist_scan = dist_scan - size_segment
	end

	-- handle negative direction
	if length_start > length_end then
		dist = -dist
	end

	return dist
end

-- decides which shape and which angle an intersection has, based on the roads it connects
local function mapgen_roads_branch_draw_intersection(paths, entry)
	-- intersection shapes are assumed to start down-up and left-right at 0 angle
	-- directions: 1 = left, 2 = up, 3 = right, 4 = down

	-- intersections that connect to 4 point (X shape), default
	local name = entry.name_x
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
local function mapgen_roads_branch_draw (point_start, points_end, size, entry)
	local new_scheme = {}
	local pos_start = {x = point_start.x, z = point_start.z}

	-- draw the intersection at the starting point
	local point_start_pos = {x = pos_start.x, y = entry.offset, z = pos_start.z}
	local point_start_name, point_start_angle = mapgen_roads_branch_draw_intersection(point_start.paths, entry)
	table.insert(new_scheme, {name = point_start_name, pos = point_start_pos, angle = point_start_angle, size = size, replacements = entry.replacements, force = entry.force, flatness = entry.flatness})

	-- loop through the end points if any
	for _, point_end in ipairs(points_end) do
		local pos_end = {x = point_end.x, z = point_end.z}

		-- determine the direction of this end point from the starting point, and draw the road accordingly
		if pos_start.x > pos_end.x then
			-- the point is left
			for w = pos_start.x - size.x, pos_end.x + size.x, -size.x do
				local pos = {x = w, y = entry.offset, z = pos_start.z}
				table.insert(new_scheme, {name = entry.name_I, pos = pos, angle = 90, size = size, replacements = entry.replacements, force = entry.force, flatness = entry.flatness})
			end
		elseif pos_start.x < pos_end.x then
			-- the point is right
			for w = pos_start.x + size.x, pos_end.x - size.x, size.x do
				local pos = {x = w, y = entry.offset, z = pos_start.z}
				table.insert(new_scheme, {name = entry.name_I, pos = pos, angle = 270, size = size, replacements = entry.replacements, force = entry.force, flatness = entry.flatness})
			end
		elseif pos_start.z > pos_end.z then
			-- the point is down
			for w = pos_start.z - size.z, pos_end.z + size.z, -size.z do
				local pos = {x = pos_start.x, y = entry.offset, z = w}
				table.insert(new_scheme, {name = entry.name_I, pos = pos, angle = 180, size = size, replacements = entry.replacements, force = entry.force, flatness = entry.flatness})
			end
		elseif pos_start.z < pos_end.z then
			-- the point is up
			for w = pos_start.z + size.z, pos_end.z - size.z, size.z do
				local pos = {x = pos_start.x, y = entry.offset, z = w}
				table.insert(new_scheme, {name = entry.name_I, pos = pos, angle = 0, size = size, replacements = entry.replacements, force = entry.force, flatness = entry.flatness})
			end
		end
	end

	return new_scheme
end

-- calculates the branching of end points from starting points
local function mapgen_roads_branch (points, mins, maxs, size, branches, schemes, rectangles, entry)
	local new_points = {}
	local new_branches = branches

	-- loop through the starting points
	for _, point in ipairs(points) do
		local new_points_this = {}

		-- each point may branch in any direction except the one it came from, as long as the branch limit of this road hasn't been reached
		-- directions: 1 = left, 2 = up, 3 = right, 4 = down
		if point.paths[1] == false and new_branches > 0 then
			-- create a new point to the left
			local distance = mapgen_roads_branch_size(point.x - 1, mins.x, point.z, size, rectangles, entry)
			if distance ~= nil then
				point.paths[1] = true
				new_branches = new_branches - 1

				local new_point = {x = point.x + distance, z = point.z, paths = {false, false, true, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = new_point.x + size.x, start_z = new_point.z, end_x = point.x - 1, end_z = point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size.x - 1, end_z = new_point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[2] == false and new_branches > 0 then
			-- create a new point upward
			local distance = mapgen_roads_branch_size(point.z + size.z, maxs.z, point.x, size, rectangles, entry)
			if distance ~= nil then
				point.paths[2] = true
				new_branches = new_branches - 1

				local new_point = {x = point.x, z = point.z + distance, paths = {false, false, false, true}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = point.x, start_z = point.z + size.z, end_x = new_point.x + size.x - 1, end_z = new_point.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size.x - 1, end_z = new_point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[3] == false and new_branches > 0 then
			-- create a new point to the right
			local distance = mapgen_roads_branch_size(point.x + size.x, maxs.x, point.z, size, rectangles, entry)
			if distance ~= nil then
				point.paths[3] = true
				new_branches = new_branches - 1

				local new_point = {x = point.x + distance, z = point.z, paths = {true, false, false, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = point.x + size.x, start_z = point.z, end_x = new_point.x - 1, end_z = new_point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size.x - 1, end_z = new_point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end
		if point.paths[4] == false and new_branches > 0 then
			-- create a new point downward
			local distance = mapgen_roads_branch_size(point.z - 1, mins.z, point.x, size, rectangles, entry)
			if distance ~= nil then
				point.paths[4] = true
				new_branches = new_branches - 1

				local new_point = {x = point.x, z = point.z + distance, paths = {false, true, false, false}}
				table.insert(new_points, new_point)
				table.insert(new_points_this, new_point)

				-- add road rectangle
				local new_rectangle = {start_x = new_point.x, start_z = new_point.z + size.z, end_x = point.x + size.x - 1, end_z = point.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle)
				-- add intersection rectangle
				local new_rectangle_intersection = {start_x = new_point.x, start_z = new_point.z, end_x = new_point.x + size.x - 1, end_z = new_point.z + size.z - 1, layers = entry.layers}
				table.insert(rectangles, new_rectangle_intersection)
			end
		end

		if point.paths[1] or point.paths[2] or point.paths[3] or point.paths[4] then
			-- get the structures for this piece of road design, and add them to the schemes table
			local new_scheme = mapgen_roads_branch_draw(point, new_points_this, size, entry)
			for _, road in ipairs(new_scheme) do
				table.insert(schemes, road)
			end
		end
	end

	-- return the new points that were generated, which will be sent back to this function to continue the road network
	return new_points, new_branches
end

-- Global functions - Roads

-- analyzes roads in the mapgen table and acts accordingly
function mapgen_roads_get (pos_start, pos_end, roads)
	-- before we can begin tracing any roads, we must determine the location of each road instance's starting point, and make sure that no starting points intersect each other
	local mins = {x = pos_start.x, z = pos_start.z}
	local maxs = {x = pos_end.x, z = pos_end.z}
	local schemes = {}
	local rectangles = {}

	-- step 1: create a list of indexes from the roads table
	-- note: the instances table is indexed by layer
	local instances = {}
	for i, entry in ipairs(roads) do
		for _, layer in ipairs(entry.layers) do
			if not instances[layer] then
				instances[layer] = {}
			end
			-- spawn this road based on its probability divided by branches
			local count = math.floor(entry.count / entry.branch_count)
			for x = 1, count do
				table.insert(instances[layer], i)
			end
		end
	end

	-- step 2: split the zone across which the city spans into multiple areas of equal size, based on the number of road instances
	-- note: the start_areas table is indexed by layer
	local start_areas = {}
	for i, layer in ipairs(instances) do
		if not start_areas[i] then
			start_areas[i] = {}
		end
		-- divide the town's area by the square root of the total number of start points
		local start_areas_size_x = math.floor((maxs.x - mins.x) / math.sqrt(#layer))
		local start_areas_size_z = math.floor((maxs.z - mins.z) / math.sqrt(#layer))
		for pos_x = mins.x, maxs.x - start_areas_size_x, start_areas_size_x do
			for pos_z = mins.z, maxs.z - start_areas_size_z, start_areas_size_z do
				table.insert(start_areas[i], {start_x = pos_x, start_z = pos_z, end_x = pos_x + start_areas_size_x - 1, end_z = pos_z + start_areas_size_z - 1})
			end
		end
		-- additionally shuffle the instances table, to an uniform road order
		calculate_table_shuffle(instances[i])
	end

	-- step 3: loop through all road instances and create a starting point in a randomly chosen area
	local start_segments = {}
	for i, layer in ipairs(instances) do
		for _, instance in ipairs(layer) do
			-- check that we still have areas left
			if #start_areas[i] == 0 then
				break
			end
			-- get the properties of this road
			local entry = roads[instance]
			entry.name_I = calculate_entry(entry.name_I)
			entry.name_L = calculate_entry(entry.name_L)
			entry.name_P = calculate_entry(entry.name_P)
			entry.name_T = calculate_entry(entry.name_T)
			entry.name_x = calculate_entry(entry.name_x)
			local size = io_get_size(0, calculate_entry(entry.name_I))
			-- now create the starting point in an available area
			local area_index = math.random(1, #start_areas[i])
			local area = start_areas[i][area_index]
			local pos_x = math.random(area.start_x, area.end_x - size.x)
			local pos_z = math.random(area.start_z, area.end_z - size.z)
			table.insert(start_segments, {pos = {x = pos_x, z = pos_z}, size = size, entry = entry})
			-- all starting points must be present in the rectangles table before branching begins, so they can be detected when calculating branches
			table.insert(rectangles, {start_x = pos_x, start_z = pos_z, end_x = pos_x + size.x - 1, end_z = pos_z + size.z - 1, layers = entry.layers})
			-- remove the area from the table so it's not chosen by a future road instance
			table.remove(start_areas[i], area_index)
		end
	end

	-- step 4: loop through all starting segments and begin creating the actual roads
	for _, segment in ipairs(start_segments) do
		-- begin from the position and number of branches of the starting segment
		local points = {{x = segment.pos.x, z = segment.pos.z, paths = {false, false, false, false}}}
		local branches = segment.entry.branch_count - 1
		while (#points > 0) do
			-- branch the existing points, then prepare the new ones for branching in the next loop iteration
			-- this loop ends when no new points are created and all existing points were handled
			points, branches = mapgen_roads_branch(points, mins, maxs, segment.size, branches, schemes, rectangles, segment.entry)
		end
	end

	-- step 5: return the structure scheme of the road design, as well as the bounding boxes of roads
	return schemes, rectangles
end
