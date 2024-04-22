-- Printers v1.0.6
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sPrinter = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sPrinter.png", 23, false, false, 36, 48)

local class_item = nil
local class_stage = nil
local lang_map = nil

local printer_base = gm.constants.oArtifactShrine   -- Unused interactable
local create_printers = false

local Colors = {
    16777215,   -- White
    5813365,    -- Green
    4007881,    -- Red
    0,
    4312538     -- Yellow
}

local scrap_names = {"White", "Green", "Red", "", "Yellow"}


-- Parameters
local printer_chances       = {0,0,0,0,  1,1,1,  2,2,  3}
local green_chance          = 0.32  -- White chance is 62%
local red_chance            = 0.03
local yellow_chance         = 0.03

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = -18   -- Location of the input box of the printer relative to the origin
local box_y_offset          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box



-- ========== Functions ==========

local function spawn_printer(x, y, rarity)
    -- Create printer base interactable
    local p = gm.instance_create_depth(x, y, 1, printer_base)
    p.is_printer = true
    p.cost = 0
    p.sprite_index = sPrinter
    p.user_valid_items = {}

    p.animation_state = nil
    p.box_x = p.x + box_x_offset
    p.box_y = p.y + box_y_offset

    -- Pick printer rarity
    if not rarity then
        rarity = 0
        local roll = gm.random_range(0, 1)
        if roll <= yellow_chance then rarity = 4
        elseif roll <= yellow_chance + red_chance then rarity = 2
        elseif roll <= yellow_chance + red_chance + green_chance then rarity = 1
        end
    end

    -- Pick printer item (vanilla only)
    repeat
        p.item_id = gm.irandom_range(0, #class_item - 1)
        p.item = class_item[p.item_id + 1]
    until p.item[7] == rarity and p.item_id ~= 86.0 and p.item[1] == "ror"

    -- Set prompt text
    local rarities = {"common", "uncommon", "rare", "", "boss"}
    local cols = {"", "<g>", "<r>", "", "<y>"}
    p.name = gm.ds_map_find_value(lang_map, p.item[3])
    p.text = "Print "..cols[rarity + 1]..p.name.." <y>(1 "..rarities[rarity + 1].." item)"

    return p
end


local function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, Colors[1], alpha or 1.0)
end



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Get global references
    if not class_item then
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
        lang_map = gm.variable_global_get("_language_map")
    end


    -- Place down printers on stage load (check when the player exists)
    if create_printers and Helper.get_client_player() then
        create_printers = false

        -- Spawn 3 printers in the cabin room on the Contact Light
        if class_stage[gm.variable_global_get("stage_id") + 1][2] == "riskOfRain" then
            for r = 0, 2 do
                spawn_printer(7650.0 + (160.0 * r), 3264.0, r)
            end
            
        -- Normal printer spawning
        else
            -- Get valid terrain
            local blocks = Helper.find_active_instance_all(gm.constants.oB)
            local tp = Helper.get_teleporter()

            -- Spawn a random amount of printers
            local count = printer_chances[gm.irandom_range(1, #printer_chances)]
            for i = 1, count do
                -- Make sure the printer doesn't spawn on the teleporter,
                -- as that prevents the player from using it
                while true do
                    local block = blocks[gm.irandom_range(1, #blocks)]
                    local x, y = (block.bbox_left + 24) + gm.irandom_range(0, block.bbox_right - block.bbox_left - 24), block.bbox_top - 1
                    if gm.point_distance(x, y, tp.x, tp.y) > 64 then
                        spawn_printer(x, y)
                        break
                    end
                end
            end
            
        end
    end
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Check if this is a printer
    if self.is_printer then

        self.taken = nil
        local items = {}

        -- Check if the user has scrap for this tier
        local id = gm.item_find("scrappers-scrap"..scrap_names[self.item[7] + 1])
        if id and gm.item_count(other, id, false) > 0 then
            self.taken = id

        -- Check if the user has a valid item to print with
        else
            if gm.array_length(other.inventory_item_order) > 0 then
                for _, i in ipairs(other.inventory_item_order) do
                    if gm.item_count(other, i, false) > 0 then
                        local item = class_item[i + 1]

                        -- Valid item if the same rarity and NOT the same item as the printer
                        if item[7] == self.item[7] and item[9] ~= self.item[9] then table.insert(items, i + 1) end
                    end
                end
            end

            if #items <= 0 then
                gm.audio_play_sound(gm.constants.wError, 0, false)
                return false
            end
        end


        -- Override "active" to 3.0 for custom functionality
        -- and start printer animation
        args[3].value = 3.0
        self.animation_state = 0
        self.animation_time = 0
        gm.audio_play_sound(gm.constants.wDroneRecycler_Activate, 0, false)
        
        -- Pick a random valid item
        if not self.taken then self.taken = items[gm.irandom_range(1, #items)] - 1 end
        gm.item_take(other, self.taken, 1, false)
    end
end)


gm.post_code_execute(function(self, other, code, result, flags)
    if code.name:match("oInit_Draw_7") then

        -- Loop through all printers
        local base_obj = Helper.find_active_instance_all(printer_base)
        for _, p in ipairs(base_obj) do
            if p.is_printer then

                -- Draw hovering sprite
                local sine = gm.variable_global_get("current_time")
                draw_item_sprite(p.item[8],
                                 p.x + 10,
                                 p.y - 33 + gm.dsin(sine / 12) * 3,
                                 0.8,
                                 0.8 + gm.dsin(sine / 4) * 0.25)

                -- Display item name
                local cb = 0
                local c = Colors[p.item[7] + 1]
                for i = 1, 2 do gm.draw_text_color(p.x + i, p.y - 64 + i, p.name, cb, cb, cb, cb, 1.0) end
                gm.draw_text_color(p.x, p.y - 64, p.name, c, c, c, c, 1.0)


                -- Printer animation
                if p.animation_state then

                    -- Draw above player
                    if p.animation_state == 0 then
                        draw_item_sprite(class_item[p.taken + 1][8], p.activator.x, p.activator.y - 48)

                        if p.animation_time < animation_held_time then p.animation_time = p.animation_time + 1
                        else
                            p.animation_state = 1
                            p.taken_x, p.taken_y, p.taken_scale = p.activator.x, p.activator.y - 48, 1.0
                        end

                    -- Lerp item towards input box
                    elseif p.animation_state == 1 then
                        draw_item_sprite(class_item[p.taken + 1][8], p.taken_x, p.taken_y, p.taken_scale)
                        p.taken_x = gm.lerp(p.taken_x, p.box_x, 0.1)
                        p.taken_y = gm.lerp(p.taken_y, p.box_y, 0.1)
                        p.taken_scale = gm.lerp(p.taken_scale, box_input_scale, 0.1)

                        if gm.point_distance(p.taken_x, p.taken_y, p.box_x, p.box_y) < 1 then
                            p.animation_state = 2
                            p.animation_time = 0
                        end

                    -- Close box for a bit
                    elseif p.animation_state == 2 then
                        p.image_speed = 2.0

                        if p.image_index == 10.0 then gm.audio_play_sound(gm.constants.wDroneRecycler_Recycling, 0, false)
                        elseif p.image_index >= 21.0 then
                            if p.animation_time < animation_print_time then p.animation_time = p.animation_time + 1
                            else p.animation_state = 3
                            end
                        end

                    -- Create item drop
                    elseif p.animation_state == 3 then
                        p.active = 0.0
                        p.image_speed = -2.0
                        p.animation_state = nil

                        local created = gm.instance_create_depth(p.box_x, p.box_y, 0, p.item[9])
                        created.is_printed = true

                    end
                end

                -- Open box again (can queue another print during this)
                if p.image_speed < 0.0 and p.image_index <= 0.0 then p.image_speed = 0.0 end
                
            end
        end

    end
end)


gm.post_script_hook(gm.constants.stage_roll_next, function(self, other, result, args)
    create_printers = true
end)

gm.post_script_hook(gm.constants.stage_goto, function(self, other, result, args)
    create_printers = true
end)


-- Debug
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