-- settings

CONNECT_DISTANCE = 50
EXPORT_IGNORE = {"air", "structures:io_disabled", "structures:io_enabled", "structures:io_marker"}

-- import and export functions
local function calculate_distance (pos1, pos2)
	local size = { x = 0, y = 0, z = 0 }
	if pos1.x < pos2.x then size.x = pos2.x - pos1.x else size.x = pos1.x - pos2.x end
	if pos1.y < pos2.y then size.y = pos2.y - pos1.y else size.y = pos1.y - pos2.y end
	if pos1.z < pos2.z then size.z = pos2.z - pos1.z else size.z = pos1.z - pos2.z end

	return size
end

local function structure_export (pos, filename)
	-- exports structure to a text file

	-- re-check markers and get their positions
	local positions = io_connect_get(pos)
	if (positions[0] == nil) or (positions[1] == nil) or (positions[2] == nil) then return false end
	-- [0] = x, [1] = y, [2] = z
	local points = { x = positions[0].x, y = positions[1].y, z = positions[2].z }
	local file = io.open(filename, "w")

	-- write each node in the marked area to a line
	for loop_x = math.min(pos.x, points.x), math.max(pos.x, points.x) do
		for loop_y = math.min(pos.y, points.y), math.max(pos.y, points.y) do
			for loop_z = math.min(pos.z, points.z), math.max(pos.z, points.z) do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				-- see if this node is in the ignore list
				found_ignored = false
				for i, v in ipairs(EXPORT_IGNORE) do
					if (minetest.env:get_node(pos_here).name == v) then
						found_ignored = true
					end
				end

				if (found_ignored == false) then
					-- we want to save origins as distance from the main I/O node
					local dist = calculate_distance(pos, pos_here)

					-- parameter order: node type, x position, y position, z position
					s = minetest.env:get_node(pos_here).name.." "..
					dist.x.." "..dist.y.." "..dist.z.."\n"
					file:write(s)
				end
			end
		end
	end

	file:close()

	return true
end

local function structure_import (pos, filename)
	-- imports structure from a text file

	-- re-check markers and get their positions
	local positions = io_connect_get(pos)
	if (positions[0] == nil) or (positions[1] == nil) or (positions[2] == nil) then return false end
	-- [0] = x, [1] = y, [2] = z
	local start = { x = math.min(pos.x, positions[0].x), y = math.min(pos.y, positions[1].y), z = math.min(pos.z, positions[2].z) }
	local file = io.open(filename, "r")

	for line in io.lines(filename) do
		local parameters = {}
		for item in string.gmatch(line, "%S+") do
			table.insert(parameters, item)
		end

		-- parameter order: node type [1], x position [2], y position [3], z position [4]
		local origin = { x = start.x + tonumber(parameters[2]), y = start.y + tonumber(parameters[3]), z = start.z + tonumber(parameters[4]) }
		minetest.env:add_node(origin, { name = parameters[1] })

	end

	file:close()


	
end

io_formspec = "size[4,2]"..
	"field[0,0;4,2;file;File;structure.txt]"..
	"button[0,1;2,1;import;Import]"..
	"button[2,1;2,1;export;Export]";

-- functions

io_connect_get = function (pos)
	-- search for in-line markers on the X / Y / Z axes within radius and return their positions

	positions = {nil, nil, nil}
	-- search X
	for search = pos.x - CONNECT_DISTANCE, pos.x + CONNECT_DISTANCE do
		pos_search = {x = search, y = pos.y, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			positions[0] = pos_search
		end
	end
	-- search Y
	for search = pos.y - CONNECT_DISTANCE, pos.y + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = search, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			positions[1] = pos_search
		end
	end
	-- search Z
	for search = pos.z - CONNECT_DISTANCE, pos.z + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = pos.y, z = search}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			positions[2] = pos_search
		end
	end
	return positions
end

io_connect_morph = function (pos)
	-- check that the block is connected to 3 markers and change it accordingly

	local positions = io_connect_get(pos)
	if (positions[0] ~= nil)
	and (positions[1] ~= nil)
	and (positions[2] ~= nil) then
		if(minetest.env:get_node(pos).name == "structures:io_disabled") then
			minetest.env:add_node(pos, { name = "structures:io_enabled" })
		end
	else
		if(minetest.env:get_node(pos).name == "structures:io_enabled") then
			minetest.env:add_node(pos, { name = "structures:io_disabled" })
		end
	end
end

-- item definitions

minetest.register_node("structures:io_disabled", {
	description = "Structure I/O",
	tiles = {"structure_io_disabled.png"},
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("structures:io_enabled", {
	description = "Structure I/O",
	tiles = {"structure_io_enabled.png"},
	is_ground_content = true,
	groups = {not_in_creative_inventory = 1, cracky = 1,level = 2},
	sounds = default.node_sound_stone_defaults(),

	on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("formspec", io_formspec)
		meta:set_string("infotext", "I/O ready")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		if (fields.export) then
			structure_export(pos, fields.file)
		end

		if (fields.import) then
			structure_import(pos, fields.file)
		end
	end
})

minetest.register_node("structures:io_marker", {
	description = "Structure I/O marker",
	drawtype = "nodebox",
	tiles = {"structure_io_marker.png"},
	paramtype = "light",
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	sounds = default.node_sound_stone_defaults(),
	node_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},
		},
	}
})

minetest.register_abm({
	nodenames = { "structures:io_disabled", "structures:io_enabled" },
	interval = 1,
	chance = 1,

	action = function(pos, node, active_object_count, active_object_count_wider)
		io_connect_morph(pos)
	end
})
