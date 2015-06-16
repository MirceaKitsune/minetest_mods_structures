-- Default town for the Structures mod
-- Metadata: $POSITION_X, $POSITION_Y, $POSITION_Z, $SIZE_X, $SIZE_Y, $SIZE_Z, $ANGLE, $NUMBER, $NAME, $GROUP

structures:define({
	name = "default_town",
	probability = 1,
	biomes = {1, 2},
	noiseparams = {
	   offset = 20,
	   scale = 20,
	   spread = {x = 250, y = 250, z = 250},
	   seed = nil,
	   octaves = 5,
	   persist = 0.6
	},

	buildings = {
		{
			name = "default_town_house_tiny_1",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_tiny_2",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_tiny_3",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_small",
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_medium",
			count = 50,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_large_1",
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_large_2",
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_hotel",
			name_start = "default_town_hotel_(",
			name_end = "default_town_hotel_)",
			count = 25,
			offset = 0,
			alignment = 0.5,
			floors = 2,
		},
		{
			name = "default_town_tower",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_farm",
			count = 15,
			offset = -2,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_park",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_fountain",
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_well",
			count = 15,
			offset = -7,
			alignment = 0.5,
			floors = 0,
		},
	},

	roads = {
		{
			name_I = "default_town_road_I",
			name_L = "default_town_road_L",
			name_P = "default_town_road_P",
			name_T = "default_town_road_T",
			name_X = "default_town_road_X",
			count = 50,
			offset = -8,
			alignment = 0.75,
		},
	},

	metadata = {
		{
			name = "default:sign_wall",
			item = "text",
			value = "$NUMBER, $NAME, $GROUP",
			format = "string",
			probability = 1,
		},
		{
			name = "default:sign_wall",
			item = "infotext",
			value = "$NUMBER, $NAME, $GROUP",
			format = "string",
			probability = 1,
		},
	},
})
