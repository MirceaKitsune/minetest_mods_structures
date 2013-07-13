-- Structures: Mapgen functions: Metadata
-- This file contains the metadata mapgen functions, for setting meta information on various types of nodes after creation

-- Settings

-- file containing node metadata information
METADATA_FILE = "mapgen_metadata.txt"

-- Local functions - Tables

-- the metadata table
metadata_table = {}

-- writes the metadata file into the metadata table
local function table_generate ()
	local path = minetest.get_modpath("structures").."/"..METADATA_FILE
	local file = io.open(path, "r")
	if (file == nil) then return end

	metadata_table = {}
	-- loop through each line
	for line in io.lines(path) do
		-- loop through each parameter in the line, ignore comments
		if (string.sub(line, 1, 1) ~= "#") then
			local parameters = {}
			for item in line:gmatch("[^\t]+") do
				table.insert(parameters, item)
			end
			table.insert(metadata_table, parameters)
		end
	end

	file:close()
end

-- shuffles the metadata table, so probabilities can be fully random
local function table_shuffle ()
	local count = #metadata_table
	for i in ipairs(metadata_table) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(count)

		-- swap the two entries
		local old = metadata_table[i]
		metadata_table[i] = metadata_table[rand]
		metadata_table[rand] = old
	end
end

-- Global functions - Metadata

-- set metadata accordingly for everything in this area
function metadata_set (minp, maxp, default)
	-- randomize the metadata table first
	-- parameters: name [1], field [2], value [3], probability [4]
	table_shuffle()

	-- go through each node in the given area
	for search_x = minp.x, maxp.x do
		for search_y = minp.y, maxp.y do
			for search_z = minp.z, maxp.z do
				local pos = { x = search_x, y = search_y, z = search_z }
				local node = minetest.env:get_node(pos)
				local liquidtype = minetest.registered_nodes[node.name].liquidtype

				-- don't even bother for nodes we shouldn't touch
				if (node.name ~= "air") and (liquidtype ~= "flowing") then
					-- loop through the metadata table until we find an entry for our node
					for i, entry in pairs(metadata_table) do
						if (node.name == entry[1]) then
							-- test the probability of this entry, if false keep going and maybe we'll find another entry later
							if(math.random() <= tonumber(entry[4])) then
								-- if the value is empty, apply the default field
								local value = entry[3]
								if ((value == nil) or (value == "\"\"")) and (default ~= nil) then
									value = default
								end
								-- finally, set the meta string of the item
								local meta = minetest.env:get_meta(pos)
								meta:set_string(entry[2], value)

								break
							end
						end
					end
				end
			end
		end
	end
end

-- Minetest functions

-- cache the metadata file at startup
minetest.after(0, table_generate)
