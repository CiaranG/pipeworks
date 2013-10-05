
--register aliases for when someone had technic installed, but then uninstalled it but not pipeworks
minetest.register_alias("technic:deployer_off", "pipeworks:deployer_off")
minetest.register_alias("technic:deployer_on", "pipeworks:deployer_on")

--define the functions from https://github.com/minetest/minetest/pull/834 while waiting for the devs to notice it
local function dir_to_facedir(dir, is6d)
	--account for y if requested
	if is6d and math.abs(dir.y) > math.abs(dir.x) and math.abs(dir.y) > math.abs(dir.z) then
		
		--from above
		if dir.y < 0 then
			if math.abs(dir.x) > math.abs(dir.z) then
				if dir.x < 0 then
					return 19
				else
					return 13
				end
			else
				if dir.z < 0 then
					return 10
				else
					return 4
				end
			end
		
		--from below
		else
			if math.abs(dir.x) > math.abs(dir.z) then
				if dir.x < 0 then
					return 15
				else
					return 17
				end
			else
				if dir.z < 0 then
					return 6
				else
					return 8
				end
			end
		end
	
	--otherwise, place horizontally
	elseif math.abs(dir.x) > math.abs(dir.z) then
		if dir.x < 0 then
			return 3
		else
			return 1
		end
	else
		if dir.z < 0 then
			return 2
		else
			return 0
		end
	end
end

local function facedir_to_dir(facedir)
	--a table of possible dirs
	return ({{x=0, y=0, z=1},
					{x=1, y=0, z=0},
					{x=0, y=0, z=-1},
					{x=-1, y=0, z=0},
					{x=0, y=-1, z=0},
					{x=0, y=1, z=0}})
					
					--indexed into by a table of correlating facedirs
					[({[0]=1, 2, 3, 4, 
						5, 2, 6, 4,
						6, 2, 5, 4,
						1, 5, 3, 6,
						1, 6, 3, 5,
						1, 4, 3, 2})
						
						--indexed into by the facedir in question
						[facedir]]
end

minetest.register_craft({
	output = 'pipeworks:deployer_off 1',
	recipe = {
		{'default:wood', 'default:chest','default:wood'},
		{'default:stone', 'mesecons:piston','default:stone'},
		{'default:stone', 'mesecons:mesecon','default:stone'},
	}
})

function hacky_swap_node(pos,name)
    local node=minetest.get_node(pos)
    local meta=minetest.get_meta(pos)
    local meta0=meta:to_table()
    if node.name == name then
        return
    end
    node.name=name
    minetest.add_node(pos, node)
    local meta=minetest.get_meta(pos)
    meta:from_table(meta0)
end

deployer_on = function(pos, node)
	if node.name ~= "pipeworks:deployer_off" then
		return
	end
	
	--locate the above and under positions
	local dir = facedir_to_dir(node.param2)
	local pos_under, pos_above = {x=pos.x - dir.x, y=pos.y - dir.y, z=pos.z - dir.z}, {x=pos.x - 2*dir.x, y=pos.y - 2*dir.y, z=pos.z - 2*dir.z}

	hacky_swap_node(pos,"pipeworks:deployer_on")
	nodeupdate(pos)
	
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local invlist = inv:get_list("main")
	for i, stack in ipairs(invlist) do
		if stack:get_name() ~= nil and stack:get_name() ~= "" and minetest.get_node(pos_under).name == "air" then --obtain the first non-empty item slot
			local owner = meta:get_string("owner")
			local placer = {
				get_player_name = function() return owner end,
				getpos = function() return pos end,
				get_player_control = function() return {jump=false,right=false,left=false,LMB=false,RMB=false,sneak=false,aux1=false,down=false,up=false} end,
				is_player = function() return true end,
				get_player_control_bits = function() return 0 end,
				get_look_dir = function() return {x = -dir.x, y = -dir.y, z = -dir.z} end,
			}
			local stack2 = minetest.item_place(stack, placer, {type="node", under=pos_under, above=pos_above})
			if minetest.setting_getbool("creative_mode") and not minetest.get_modpath("unified_inventory") then --infinite stacks ahoy!
				stack2:take_item()
			end
			invlist[i] = stack2
			inv:set_list("main", invlist)
			return
		end
	end
end

deployer_off = function(pos, node)
	if node.name == "pipeworks:deployer_on" then
		hacky_swap_node(pos,"pipeworks:deployer_off")
		nodeupdate(pos)
	end
end

minetest.register_node("pipeworks:deployer_off", {
	description = "Deployer",
	tile_images = {"pipeworks_deployer_top.png","pipeworks_deployer_bottom.png","pipeworks_deployer_side2.png","pipeworks_deployer_side1.png",
			"pipeworks_deployer_back.png","pipeworks_deployer_front_off.png"},
	mesecons = {effector={action_on=deployer_on,action_off=deployer_off}},
	tube={insert_object=function(pos,node,stack,direction)
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			return inv:add_item("main",stack)
		end,
		can_insert=function(pos,node,stack,direction)
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			return inv:room_for_item("main",stack)
		end,
		input_inventory="main",
		connect_sides={back=1}},
	is_ground_content = true,
	paramtype2 = "facedir",
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2, mesecon = 2,tubedevice=1, tubedevice_receiver=1},
	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec",
				"invsize[8,9;]"..
				"label[0,0;Deployer]"..
				"list[current_name;main;4,1;3,3;]"..
				"list[current_player;main;0,5;8,4;]")
		meta:set_string("infotext", "Deployer")
		local inv = meta:get_inventory()
		inv:set_size("main", 3*3)
	end,
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	after_place_node = function (pos, placer)
		tube_scanforobjects(pos, placer)
		local placer_pos = placer:getpos()
		
		--correct for the player's height
		if placer:is_player() then
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name())
			placer_pos.y = placer_pos.y + 1.5
		end
		
		--correct for 6d facedir
		if placer_pos then
			local dir = {
				x = pos.x - placer_pos.x,
				y = pos.y - placer_pos.y,
				z = pos.z - placer_pos.z
			}
			local node = minetest.get_node(pos)
			node.param2 = dir_to_facedir(dir, true)
			minetest.set_node(pos, node)
			minetest.log("action", "real (6d) facedir: " .. node.param2)
		end
	end,
	after_dig_node = tube_scanforobjects,
})

minetest.register_node("pipeworks:deployer_on", {
	description = "Deployer",
	tile_images = {"pipeworks_deployer_top.png","pipeworks_deployer_bottom.png","pipeworks_deployer_side2.png","pipeworks_deployer_side1.png",
			"pipeworks_deployer_back.png","pipeworks_deployer_front_on.png"},
	mesecons = {effector={action_on=deployer_on,action_off=deployer_off}},
	tube={insert_object=function(pos,node,stack,direction)
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			return inv:add_item("main",stack)
		end,
		can_insert=function(pos,node,stack,direction)
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			return inv:room_for_item("main",stack)
		end,
		input_inventory="main",
		connect_sides={back=1}},
	is_ground_content = true,
	paramtype2 = "facedir",
	tubelike=1,
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2, mesecon = 2,tubedevice=1, tubedevice_receiver=1,not_in_creative_inventory=1},
	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec",
				"invsize[8,9;]"..
				"label[0,0;Deployer]"..
				"list[current_name;main;4,1;3,3;]"..
				"list[current_player;main;0,5;8,4;]")
		meta:set_string("infotext", "Deployer")
		local inv = meta:get_inventory()
		inv:set_size("main", 3*3)
	end,
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	after_place_node = function (pos, placer)
		tube_scanforobjects(pos, placer)
		local placer_pos = placer:getpos()
		
		--correct for the player's height
		if placer:is_player() then placer_pos.y = placer_pos.y + 1.5 end
		
		--correct for 6d facedir
		if placer_pos then
			local dir = {
				x = pos.x - placer_pos.x,
				y = pos.y - placer_pos.y,
				z = pos.z - placer_pos.z
			}
			local node = minetest.get_node(pos)
			node.param2 = dir_to_facedir(dir, true)
			minetest.set_node(pos, node)
			minetest.log("action", "real (6d) facedir: " .. node.param2)
		end
	end,
	after_dig_node = tube_scanforobjects,
})
