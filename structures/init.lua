-- Structures: Item definitions
-- This file contains the item definitions and logics for the Manager and Markers

structures = {}

-- Settings

-- number of nodes in which a structure manager searches for markers
-- higher values allow for larger areas but cause a longer loop to execute
local CONNECT_DISTANCE = 100

-- Global functions - Calculate

-- checks if two tables contain a matching entry
function calculate_matching (table1, table2)
	for _, entry1 in ipairs(table1) do
		for _, entry2 in ipairs(table2) do
			if entry1 == entry2 then
				return true
			end
		end
	end
	return false
end

-- calculates the linear interpolation between two numbers
function calculate_lerp (value_start, value_end, control)
	return (1 - control) * value_start + control * value_end
end

-- returns the distance between two origins
function calculate_distance (pos1, pos2)
	local size = {x = 0, y = 0, z = 0}
	if pos1.x < pos2.x then size.x = pos2.x - pos1.x else size.x = pos1.x - pos2.x end
	if pos1.y < pos2.y then size.y = pos2.y - pos1.y else size.y = pos1.y - pos2.y end
	if pos1.z < pos2.z then size.z = pos2.z - pos1.z else size.z = pos1.z - pos2.z end

	return size
end

-- checks if the node is in the specified list
function calculate_node_in_table (node, list)
	for i, v in ipairs(list) do
		if node == v then
			return true
		end
	end

	return false
end

-- shuffle the entries of a table
function calculate_table_shuffle(list)
	local count = #list
	for i in ipairs(list) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(count)

		-- swap the two entries
		local old = list[i]
		list[i] = list[rand]
		list[rand] = old
	end

	return list
end

-- returns a random entry if value is a table
function calculate_entry (value)
	if type(value) == "table" then
		return value[math.random(1, #value)]
	else
		return value
	end
end

-- returns the height based on height map
function calculate_heightmap_pos (heightmap, minp, maxp, pos_x, pos_z)
	local chunksize = maxp.x - minp.x + 1
	local index = (pos_z - minp.z) * chunksize + (pos_x - minp.x) + 1
	local height = heightmap[index]
	return height
end

-- Local functions - Formspec

local function make_formspec_size (pos, pos_markers)
	local size = calculate_distance(pos, pos_markers)

	-- remove edge from calculation
	size.x = size.x - 1
	size.y = size.y - 1
	size.z = size.z - 1

	return size
end

local function make_formspec_nodes (pos, pos_markers)
	local nodes = 0

	for loop_x = math.min(pos.x, pos_markers.x) + 1, math.max(pos.x, pos_markers.x) - 1 do
		for loop_y = math.min(pos.y, pos_markers.y) + 1, math.max(pos.y, pos_markers.y) - 1 do
			for loop_z = math.min(pos.z, pos_markers.z) + 1, math.max(pos.z, pos_markers.z) - 1 do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if calculate_node_in_table(minetest.env:get_node(pos_here).name, structures.IO_ignore) == false then
					nodes = nodes + 1
				end
			end
		end
	end

	return nodes
end

local function make_formspec (file, pos, angle, replace)
	local pos_markers = markers_get(pos)
	local area_info = ""

	if pos_markers.x == nil then
		area_info = "Error: No marker found on X axis!"
	elseif pos_markers.y == nil then
		area_info = "Error: No marker found on Y axis!"
	elseif pos_markers.z == nil then
		area_info = "Error: No marker found on Z axis!"
	else
		local area_size = make_formspec_size(pos, pos_markers)
		local area_nodes = make_formspec_nodes(pos, pos_markers)
		area_info = "Size: X = "..area_size.x.." Y = "..area_size.y.." Z = "..area_size.z.." Nodes: "..area_nodes
	end

	local formspec="size[6,5]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"field[0,0;4,2;file;File;"..file.."]"..
		"field[4,0;2,2;angle;Import angle;"..angle.."]"..
		"field[0,1;6,2;replace;Import replace (a=b,c=d);"..replace.."]"..
		"label[0,2;"..area_info.."]"..
		"button[0,3;2,1;io_import;Import]"..
		"button[2,3;2,1;io_export;Export]"..
		"button[4,3;2,1;io_clear;Clear]"..
		"button_exit[0,4;6,1;exit;OK]"
	return formspec
end

-- Global functions - Item connections

-- removes all 3 markers and disables the manager node
function markers_remove (pos)
	local pos_markers = markers_get(pos)

	-- remove X
	if pos_markers.x ~= nil then
		local pos_here = {x = pos_markers.x, y = pos.y, z = pos.z}
		if minetest.env:get_node(pos_here).name == "structures:marker" then
			minetest.env:remove_node(pos_here)
		end
	end
	-- remove Y
	if pos_markers.y ~= nil then
		local pos_here = {x = pos.x, y = pos_markers.y, z = pos.z}
		if minetest.env:get_node(pos_here).name == "structures:marker" then
			minetest.env:remove_node(pos_here)
		end
	end
	-- remove Z
	if pos_markers.z ~= nil then
		local pos_here = {x = pos.x, y = pos.y, z = pos_markers.z}
		if minetest.env:get_node(pos_here).name == "structures:marker" then
			minetest.env:remove_node(pos_here)
		end
	end
end

-- search for in-line markers on the X / Y / Z axes within radius and return their positions
function markers_get (pos)
	local pos_markers = {x = nil, y = nil, z = nil}

	-- search +X
	if pos_markers.x == nil then
		for search = pos.x + 1, pos.x + CONNECT_DISTANCE, 1 do
			local pos_search = {x = search, y = pos.y, z = pos.z}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.x = pos_search.x
				break
			end
		end
	end

	-- search -X
	if pos_markers.x == nil then
		for search = pos.x - 1, pos.x - CONNECT_DISTANCE, -1 do
			local pos_search = {x = search, y = pos.y, z = pos.z}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.x = pos_search.x
				break
			end
		end
	end

	-- search +Y
	if pos_markers.y == nil then
		for search = pos.y + 1, pos.y + CONNECT_DISTANCE, 1 do
			local pos_search = {x = pos.x, y = search, z = pos.z}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.y = pos_search.y
				break
			end
		end
	end

	-- search -Y
	if pos_markers.y == nil then
		for search = pos.y - 1, pos.y - CONNECT_DISTANCE, -1 do
			local pos_search = {x = pos.x, y = search, z = pos.z}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.y = pos_search.y
				break
			end
		end
	end

	-- search +Z
	if pos_markers.z == nil then
		for search = pos.z + 1, pos.z + CONNECT_DISTANCE, 1 do
			local pos_search = {x = pos.x, y = pos.y, z = search}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.z = pos_search.z
				break
			end
		end
	end

	-- search -Z
	if pos_markers.z == nil then
		for search = pos.z - 1, pos.z - CONNECT_DISTANCE, -1 do
			local pos_search = {x = pos.x, y = pos.y, z = search}
			local pos_name = minetest.env:get_node(pos_search).name
			if pos_name == "structures:marker" then
				pos_markers.z = pos_search.z
				break
			end
		end
	end

	return pos_markers
end

-- Item definitions

minetest.register_privilege("structures", {
	description = "Import & Export structures",
	give_to_singleplayer = true
})

minetest.register_node("structures:manager", {
	description = "Structure Manager",
	tiles = {"structure_io_plus_y.png", "structure_io_minus_y.png", "structure_io_plus_x.png", "structure_io_minus_x.png", "structure_io_plus_z.png", "structure_io_minus_z.png"},
	is_ground_content = true,
	groups = {cracky = 1, level = 2},
	drop = 'structures:manager',
	sounds = default.node_sound_metal_defaults(),

	on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		local formspec = make_formspec("structure", pos, 0, "")
		meta:set_string("file", "structure")
		meta:set_float("angle", 0)
		meta:set_string("formspec", formspec)
		meta:set_string("infotext", "Structure not configured")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		local player = sender:get_player_name()
		if not minetest.check_player_privs(player, {structures=true}) then
			minetest.chat_send_player(player, "Error: You need the \"structures\" privilege to use the structure manager", false)
			return
		end

		if fields.file and fields.angle then
			local pos_markers = markers_get(pos)
			local infotext = ""
			if pos_markers.x ~= nil and pos_markers.y ~= nil and pos_markers.z ~= nil then
				if fields.io_export then
					io_area_export(pos, pos_markers, fields.file..".mts")
					io_get_size_uncache(fields.file..".mts")
				elseif fields.io_import then
					-- determine node replacements
					local replace = {}
					if fields.replace then
						-- separate string by comma (",")
						for token_comma in string.gmatch(fields.replace, "[^,]+") do
							-- separate string by equals ("=")
							local entries = {}
							for token_equals in string.gmatch(token_comma, "[^=]+") do
								table.insert(entries, token_equals)
							end
							replace[entries[1]] = entries[2]
						end
					end

					io_get_size_cache(fields.file..".mts")
					io_area_import(pos, pos_markers, tonumber(fields.angle), fields.file..".mts", replace, true, true, nil)

					-- we need to call on_construct for each node that has it, otherwise some nodes won't work correctly or cause a crash
					local vm = VoxelManip()
					local minp, maxp = vm:read_from_map(pos, pos_markers)
					local data = vm:get_data()
					local va = VoxelArea:new{MinEdge = minp, MaxEdge = maxp}
					local pos_start = {x = math.min(pos.x, pos_markers.x) + 1, y = math.min(pos.y, pos_markers.y) + 1, z = math.min(pos.z, pos_markers.z) + 1}
					local pos_end = {x = math.max(pos.x, pos_markers.x) - 1, y = math.max(pos.y, pos_markers.y) - 1, z = math.max(pos.z, pos_markers.z) - 1}
					for search_x = pos_start.x, pos_end.x do
						for search_y = pos_start.y, pos_end.y do
							for search_z = pos_start.z, pos_end.z do
								local search_pos = {x = search_x, y = search_y, z = search_z}
								local i = va:indexp(search_pos)
								local name = minetest.get_name_from_content_id(data[i])
								if minetest.registered_nodes[name] and minetest.registered_nodes[name].on_construct then
									minetest.registered_nodes[name].on_construct(search_pos)
								end
							end
						end
					end
				elseif fields.io_clear then
					local vm = VoxelManip()
					local minp, maxp = vm:read_from_map(pos, pos_markers)
					local data = vm:get_data()
					local va = VoxelArea:new{MinEdge = minp, MaxEdge = maxp}
					local pos_start = {x = math.min(pos.x, pos_markers.x) + 1, y = math.min(pos.y, pos_markers.y) + 1, z = math.min(pos.z, pos_markers.z) + 1}
					local pos_end = {x = math.max(pos.x, pos_markers.x) - 1, y = math.max(pos.y, pos_markers.y) - 1, z = math.max(pos.z, pos_markers.z) - 1}
					local node_content_air = minetest.get_content_id("air")
					for search_x = pos_start.x, pos_end.x do
						for search_y = pos_start.y, pos_end.y do
							for search_z = pos_start.z, pos_end.z do
								local search_pos = {x = search_x, y = search_y, z = search_z}
								local i = va:indexp(search_pos)
								data[i] = node_content_air
							end
						end
					end

					-- update vm and node data
					vm:set_data(data)
					vm:update_liquids()
					vm:calc_lighting()
					vm:write_to_map()
				end
				infotext = "Structure: "..fields.file
			else
				minetest.chat_send_player(player, "Error: The area marked by the markers is invalid", false)
				infotext = "Structure: "..fields.file.." (error)"
			end

			local meta = minetest.env:get_meta(pos)
			local formspec = make_formspec(fields.file, pos, fields.angle, fields.replace)
			meta:set_string("file", fields.file)
			meta:set_float("angle", fields.angle)
			meta:set_string("formspec", formspec)
			meta:set_string("infotext", infotext)
		end
	end
})

minetest.register_node("structures:marker", {
	description = "Structure Marker",
	drawtype = "nodebox",
	tiles = {"structure_io_marker.png"},
	paramtype = "light",
	is_ground_content = true,
	groups = {cracky = 1, level = 2},
	drop = 'structures:marker',
	sounds = default.node_sound_metal_defaults(),

	node_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},
		},
	}
})

-- Other scripts

dofile(minetest.get_modpath("structures").."/structures_io.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen_roads.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen_buildings.lua")
