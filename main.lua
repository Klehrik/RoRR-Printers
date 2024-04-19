-- Printers v1.0.0
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sPrinter = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sPrinter.png", 1, false, false, 30, 50)

local printer_base = gm.constants.oGunchest
local Colors = {
    16777215,   -- White
    5813365,    -- Green
    4007881,    -- Red
    0,
    4312538     -- Yellow
}

local class_item = nil
local lang_map = nil
local run_printer_swaps = false
local sine = 0

local min_printers = 2  -- Per stage
local max_printers = 3

-- White 62%, Green 32%, Red 3%, Yellow 3%
local yellow_chance = 0.03
local red_chance = 0.03
local green_chance = 0.32



-- ========== Functions ==========

local function spawn_printer(x, y)    
    local p = gm.instance_create_depth(x, y, 1, printer_base)
    p.is_printer = true
    p.cost = 0
    p.sprite_index = sPrinter

    local rarity = 0
    local roll = gm.random_range(0, 1)
    if roll <= yellow_chance then rarity = 4
    elseif roll <= yellow_chance + red_chance then rarity = 2
    elseif roll <= yellow_chance + red_chance + green_chance then rarity = 1
    end

    repeat
        p.item_id = gm.irandom_range(0, #class_item - 1)
        p.item = class_item[p.item_id + 1]
    until p.item[7] == rarity and p.item_id ~= 86.0

    local rarities = {"common", "uncommon", "rare", "", "boss"}
    p.name = gm.ds_map_find_value(lang_map, p.item[3])
    p.text = "Print "..p.name.." <y>(1 "..rarities[rarity + 1].." item)"

    return p
end



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    if not class_item then
        class_item = gm.variable_global_get("class_item")
        lang_map = gm.variable_global_get("_language_map")
    end


    -- Place down printers
    if run_printer_swaps and Helper.get_client_player() then
        run_printer_swaps = false

        local blocks = Helper.find_active_instance_all(gm.constants.oB)
        local tp = Helper.get_teleporter()
        local count = gm.irandom_range(min_printers, max_printers)
        for i = 1, count do
            -- Make sure the printer doesn't spawn on the teleporter,
            -- as that prevents the player from using it
            while true do
                local block = blocks[gm.irandom_range(1, #blocks)]
                local x, y = block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1
                if gm.point_distance(x, y, tp.x, tp.y) > 48 then
                    spawn_printer(x, y)
                    break
                end
            end
        end
    end


    -- Loop through all printers and check if used (active == 3.0)
    local chests = Helper.find_active_instance_all(printer_base)
    for _, p in ipairs(chests) do
        if p.is_printer then

            if p.active == 3.0 then
                -- Loop through user's items and get the ones that are of the same rarity
                local rarity = p.item[7]
                local user = p.activator

                local items = {}
                if gm.array_length(user.inventory_item_order) > 0 then
                    for _, i in ipairs(user.inventory_item_order) do
                        local item = class_item[i + 1]
                        local internal = item[1].."-"..item[2]
                        local count = gm.item_count(user, gm.item_find(internal), false)

                        if item[7] == rarity and count > 0 then table.insert(items, i + 1) end
                    end
                end


                -- Pick a random one (if there are any)
                if #items > 0 then
                    local random = items[gm.irandom_range(1, #items)] - 1
                    if #items > 1 then
                        -- Try to pick an item that isn't the one being printed
                        repeat random = items[gm.irandom_range(1, #items)] - 1 until random ~= p.item_id
                    end
                    gm.item_take(user, random, 1, false)

                    p.taken = random
                    p.taken_anim = 0
                    p.active = 4.0
                
                else p.active = 0.0
                end
            
            end
        end
    end
end)


gm.post_code_execute(function(self, other, code, result, flags)
    if code.name:match("oInit_Draw_7") then
        sine = sine + 1

        local chests = Helper.find_active_instance_all(printer_base)
        for _, p in ipairs(chests) do
            if p.is_printer then
                -- Draw hovering sprite
                gm.draw_sprite_ext(p.item[8], 0, p.x + 14, p.y - 36 + gm.dsin(sine) * 4, 0.75, 0.75, 0.0, Colors[1], 1.0)
                
                -- Display item name
                local cb = 0
                local c = Colors[p.item[7] + 1]
                for i = 1, 2 do gm.draw_text_color(p.x + i, p.y - 64 + i, p.name, cb, cb, cb, cb, 1.0) end
                gm.draw_text_color(p.x, p.y - 64, p.name, c, c, c, c, 1.0)


                -- Item take animation
                local function draw_taken(x, y)
                    gm.draw_sprite_ext(class_item[p.taken + 1][8], 0, x, y, 1.0, 1.0, 0.0, Colors[1], 1.0)
                end
                
                local user = p.activator
                local base_time = 60

                if p.active == 4.0 then
                    p.taken_anim = p.taken_anim + 1

                    if p.taken_anim < base_time then
                        draw_taken(user.x, user.y - 48)

                    elseif p.taken_anim == base_time then
                        p.taken_x, p.taken_y = user.x, user.y - 48

                    elseif p.taken_anim <= base_time + 2 then
                        draw_taken(p.taken_x, p.taken_y)
                        p.taken_x = gm.lerp(p.taken_x, p.x - 14, 0.1)
                        p.taken_y = gm.lerp(p.taken_y, p.y - 22, 0.1)
                        if gm.point_distance(p.taken_x, p.taken_y, p.x - 14, p.y - 22) > 1 then p.taken_anim = base_time + 1 end

                    else
                        p.active = 0.0
                        local created = gm.instance_create_depth(p.x, p.y, 0, p.item[9])
                        created.is_printed = true

                    end

                end
            end
        end
    end
end)


gm.pre_script_hook(gm.constants.callback_execute, function(self, other, result, args)
    -- Check for chest opening
    if args[1].value == 37.0 then
        if self.is_printer then
            self.active = 3.0
        end
    end
end)


gm.post_script_hook(gm.constants.stage_roll_next, function(self, other, result, args)
    run_printer_swaps = true
end)


gm.post_script_hook(gm.constants.stage_goto, function(self, other, result, args)
    run_printer_swaps = true
end)


-- gui.add_imgui(function()
--     local player = Helper.find_active_instance(gm.constants.oP)
--     if player and ImGui.Begin("Printers") then

--         if ImGui.Button("Spawn oPrinter") then
--             local printer = spawn_printer(player.x, player.y)
--         elseif ImGui.Button("Spawn on nearest block") then
--             local mouse_x = gm.variable_global_get("mouse_x")
--             local mouse_y = gm.variable_global_get("mouse_y")
--             local block = gm.instance_nearest(player.x, player.y, gm.constants.pBlockStatic)
--             spawn_printer(block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1)
--         end

--     end

--     ImGui.End()
-- end)