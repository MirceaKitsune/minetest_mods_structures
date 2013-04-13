-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings
local MAPGEN_FILE = "mapgen.txt"

-- Local functions - Table

-- the mapgen table
local mapgen_table = {}

-- writes the mapgen file into the mapgen table
local function file_to_table ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "r")
	if (file == nil) then return end

	mapgen_table = {}
	-- loop through each line
	for line in io.lines(path) do
		local parameters = {}
		-- loop through each parameter in the line
		for item in string.gmatch(line, "%S+") do
			table.insert(parameters, item)
		end
		table.insert(mapgen_table, parameters)
	end

	file:close()
end

-- writes the mapgen table into the mapgen file
local function table_to_file ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- loop through each entry
	for i, entry1 in pairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in pairs(entry1) do
			s = s..entry2.." "
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
end

-- Global functions - Add / remove to / from file

function mapgen_add (filename, group, node, probability, height_min, height_max, spacing)
	-- remove the existing entry
	mapgen_remove (filename)

	-- add file to the mapgen table
	entry = { filename, group, node, probability, height_min, height_max, spacing }
	table.insert(mapgen_table, entry)

	table_to_file()
end

function mapgen_remove (filename)
	for i, entry in pairs(mapgen_table) do
		if (entry[1] == filename) then
			table.remove(mapgen_table, i)
			break
		end
	end

	table_to_file()
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, file_to_table)
