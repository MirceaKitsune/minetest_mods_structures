-- Structures: Mapgen functions: Metadata
-- This file contains the metadata mapgen functions, for setting meta information on various types of nodes after creation

-- Global functions - Metadata

-- set metadata accordingly for everything in this area
function mapgen_metadata_set (minp, maxp, expressions, group)
	-- randomize the metadata table first
	-- parameters: group [1], type [2], node [3], item [4], value [5], format [6], probability [7]

	-- go through each node in the given area
	for search_x = minp.x, maxp.x do
		for search_y = minp.y, maxp.y do
			for search_z = minp.z, maxp.z do
				local pos = { x = search_x, y = search_y, z = search_z }
				local node = minetest.env:get_node(pos)

				-- don't even bother for air nodes
				if node.name ~= "air" then
					-- loop through the mapgen table
					-- TODO: Shuffle the loop, so the order of entries in the text file don't influence probability
					for i, entry in ipairs(mapgen_table[group].metadata) do
						-- see if this is a node of the type we want to edit
						if node.name == entry.name then
							-- test the probability of this entry
							if math.random() <= entry.probability then
								local item = entry.item
								local value = entry.value
								local format = entry.format
								local meta = minetest.env:get_meta(pos)

								-- set the meta of the item using the given format
								-- TODO: Also add inventory as a type, so inventories can be set too
								if format == "string" then
									-- replace expressions with the appropriate values
									for i, expression in ipairs(expressions) do
										value = string.gsub(value, "$"..expression[1], expression[2])
									end
									meta:set_string(item, value)
								elseif format == "float" then
									meta:set_float(item, tonumber(value))
								end
							end
						end
					end
				end
			end
		end
	end
end
