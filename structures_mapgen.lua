-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings
local MAPGEN_FILE = "mapgen.txt"

-- Global functions - Add / remove to / from file

function mapgen_add (filename, group)
	print("Got to add function. Mapgen group is "..group)
end

function mapgen_remove (filename, group)
	print("Got to remove function. Mapgen group is "..group)
end
