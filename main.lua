-- Printers v1.0.11
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for _, m in pairs(mods) do if type(m) == "table" and m.RoRR_Modding_Toolkit then Actor = m.Actor Buff = m.Buff Callback = m.Callback Helper = m.Helper Instance = m.Instance Item = m.Item Net = m.Net Player = m.Player Resources = m.Resources Survivor = m.Survivor break end end end)

local sPrinter = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sPrinter.png", 23, false, false, 36, 48)

local class_item = nil
local class_stage = nil
local class_artifact = nil
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

local config = {
    show_names = false
}
local file_path = path.combine(paths.plugins_data(), _ENV["!guid"]..".txt")
local success, file = pcall(toml.decodeFromFile, file_path)
if success then config = file.config end

local frame = 0

local printer_setup_queue = {}


-- Parameters
local printer_chances       = {0,0,0,0,  1,1,1,1,1,1,1,1,  2,2,2,2,2,  3,3,3}
local green_chance          = 0.32  -- White chance is 62%
local red_chance            = 0.03
local yellow_chance         = 0.03

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = -18   -- Location of the input box of the printer relative to the origin
local box_y_offset          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box

local ban_list = {
    "scrappers-scrapWhite",
    "scrappers-scrapGreen",
    "scrappers-scrapRed",
    "scrappers-scrapYellow",
    "betterCrates-cancel"
}



-- ========== Functions ==========

function spawn_printer(x, y, rarity)
    if Net.get_type() == Net.TYPE.client then return end

    -- Create printer base interactable
    local p = gm.instance_create_depth(x, y, 1, printer_base)

    -- Pick printer rarity
    if not rarity then
        rarity = 0
        local roll = gm.random_range(0, 1)
        if roll <= yellow_chance then rarity = 4
        elseif roll <= yellow_chance + red_chance then rarity = 2
        elseif roll <= yellow_chance + red_chance + green_chance then rarity = 1
        end
    end

    -- Pick printer item
    -- Make sure that the item is:
    --      of the same rarity
    --      not in the item ban list
    --      is actually unlocked (if applicable)
    local item_id, item = 0, nil
    repeat
        item_id = gm.irandom_range(0, #class_item - 1)
        item = class_item[item_id + 1]
    until item[7] == rarity and item[1] and item[2] and (not Helper.table_has(ban_list, item[1].."-"..item[2])) and (item[11] == nil or gm.achievement_is_unlocked(item[11]))

    -- Run setup
    set_up_printer(x, y, rarity, item_id)

    -- [Host]  Send setup data to clients
    if Net.get_type() == Net.TYPE.host then
        Net.send("Printers.setup", Net.TARGET.all, nil, x, y, rarity, item_id)
    end
end


function set_up_printer(x, y, rarity, item_id)
    local p = get_printer_at(x, y)
    if not p then return false end

    -- Set variables
    p.is_printer = true
    p.cost = 0
    p.sprite_index = sPrinter
    p.user_valid_items = {}

    p.box_x = p.x + box_x_offset
    p.box_y = p.y + box_y_offset

    p.item_id = item_id
    p.item = class_item[item_id + 1]

    -- Set prompt text
    local rarities = {"common", "uncommon", "rare", "", "boss"}
    local cols = {"", "<g>", "<r>", "", "<y>"}
    p.name = gm.ds_map_find_value(lang_map, p.item[3])
    p.text = "Print "..cols[rarity + 1]..p.name.." <y>(1 "..rarities[rarity + 1].." item)"

    return true
end


function get_printer_at(x, y)
    -- Look for base interactable at the given position
    local bases = Instance.find_all(printer_base)
    for _, b in ipairs(bases) do
        -- Doesn't spawn exactly on position for some reason
        if math.abs(b.x - x) <= 3 and math.abs(b.y - y) <= 3 then return b end
    end
    return nil
end


function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, Colors[1], alpha or 1.0)
end



-- ========== Main ==========

gui.add_to_menu_bar(function()
    local value, pressed = ImGui.Checkbox("Show item names", config.show_names)
    if pressed then
        config.show_names = value
        pcall(toml.encodeToFile, {config = config}, {file = file_path, overwrite = true})
    end
end)


gm.pre_script_hook(gm.constants.__input_system_tick, function()
    frame = frame + 1

    -- Get global references
    if not class_item then
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
        class_artifact = gm.variable_global_get("class_artifact")
        lang_map = gm.variable_global_get("_language_map")
    end


    if create_printers then
        -- Toggle initial spawning off if not host
        if Net.get_type() == Net.TYPE.client then create_printers = false end

        -- Do not create printers if Command is active
        if class_artifact[8][9] == true or class_artifact[8][9] == 1.0 then create_printers = false end
    end


    -- Create printers after level init is done (check when the player exists)
    if create_printers and Player.get_client() then
        create_printers = false

        -- Spawn 3 printers in the cabin room on the Contact Light
        if class_stage[gm.variable_global_get("stage_id") + 1][2] == "riskOfRain" then
            for r = 0, 2 do
                spawn_printer(7650 + (160 * r), 3264, r)
            end
            
        -- Normal printer spawning
        else
            -- Get valid terrain
            local blocks = Instance.find_all(gm.constants.oB)
            --local tp = Instance.find(Instance.teleporters)

            -- Spawn a random amount of printers
            local count = printer_chances[gm.irandom_range(1, #printer_chances)]
            for i = 1, count do
                -- Make sure the printer doesn't spawn on the teleporter,
                -- as that prevents the player from using it
                while true do
                    local edge_padding = 24
                    local min_dist = 70     -- from other interactables

                    local block = blocks[gm.irandom_range(1, #blocks)]
                    local x, y = (block.bbox_left + edge_padding) + gm.irandom_range(0, block.bbox_right - block.bbox_left - (edge_padding * 2)), block.bbox_top - 1

                    local closest = gm.instance_nearest(x, y, gm.constants.pInteractable)
                    if gm.point_distance(x, y, closest.x, closest.y) > min_dist then
                        spawn_printer(x, y)
                        break
                    end
                end
            end
            
        end
    end


    printer_setup_step()
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Check if this is a printer
    if self.is_printer then
        local player = args[2].value

        -- Check if this client is the activator
        if player == Player.get_client() then

            if Net.get_type() == Net.TYPE.single then
                printer_use(self, player)

            else
                local taken = printer_use(self, player)
                if taken then
                    Net.send("Printers.use", Net.TARGET.all, nil, self.x, self.y, player.user_name, taken)
                else self.active = 0.0
                end

            end

        end

        return false
    end
end)


function printer_use(printer, player, taken)
    if not printer then return end

    printer.taken = nil

    if not taken then
        local items = {}

        -- Check if the user has scrap for this tier
        local id = gm.item_find("scrappers-scrap"..scrap_names[printer.item[7] + 1])
        if id and gm.item_count(player, id, false) > 0 then
            printer.taken = id

        -- Check if the user has a valid item to print with
        else
            if gm.array_length(player.inventory_item_order) > 0 then
                for _, i in ipairs(player.inventory_item_order) do
                    if gm.item_count(player, i, false) > 0 then
                        local item = class_item[i + 1]

                        -- Valid item if the same rarity and NOT the same item as the printer
                        if item[7] == printer.item[7] and item[9] ~= printer.item[9] then table.insert(items, i + 1) end
                    end
                end
            end

            if #items <= 0 then
                gm.sound_play_at(gm.constants.wError, 1.0, 1.0, printer.x, printer.y, 1.0)
                return false
            end
        end

        -- Pick a random valid item
        if not printer.taken then printer.taken = items[gm.irandom_range(1, #items)] - 1 end
    else printer.taken = taken
    end

    -- Override "active" to 3.0 for custom functionality
    printer.active = 3
    printer.activator = player
    printer.animation_time = 0
    gm.sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, printer.x, printer.y, 1.0)
    
    -- [Single/Host]  Remove item from inventory
    if Net.get_type() ~= Net.TYPE.client then gm.item_take(player, printer.taken, 1, false) end

    return printer.taken
end


function printer_draw()
    -- Loop through all printers
    local base_obj = Instance.find_all(printer_base)
    for _, p in ipairs(base_obj) do
        if p.is_printer then

            -- Draw hovering sprite
            draw_item_sprite(p.item[8],
                            p.x + 10,
                            p.y - 33 + gm.dsin(frame * 1.333) * 3,
                            0.8,
                            0.8 + gm.dsin(frame * 4) * 0.25)

            -- Display item name
            if config.show_names then
                local cb = 0
                local c = Colors[p.item[7] + 1]
                for i = 1, 2 do gm.draw_text_color(p.x + i, p.y - 64 + i, p.name, cb, cb, cb, cb, 1.0) end
                gm.draw_text_color(p.x, p.y - 64, p.name, c, c, c, c, 1.0)
            end


            -- Printer animation
            if p.active >= 3 then

                -- Draw above player
                if p.active == 3 then
                    draw_item_sprite(class_item[p.taken + 1][8], p.activator.x, p.activator.y - 48)

                    if p.animation_time < animation_held_time then p.animation_time = p.animation_time + 1
                    else
                        p.active = 4
                        p.taken_x, p.taken_y, p.taken_scale = p.activator.x, p.activator.y - 48, 1.0
                    end

                -- Lerp item towards input box
                elseif p.active == 4 then
                    draw_item_sprite(class_item[p.taken + 1][8], p.taken_x, p.taken_y, p.taken_scale)
                    p.taken_x = gm.lerp(p.taken_x, p.box_x, 0.1)
                    p.taken_y = gm.lerp(p.taken_y, p.box_y, 0.1)
                    p.taken_scale = gm.lerp(p.taken_scale, box_input_scale, 0.1)

                    if gm.point_distance(p.taken_x, p.taken_y, p.box_x, p.box_y) < 1 then
                        p.active = 5
                        p.animation_time = 0
                    end

                -- Close box for a bit
                elseif p.active == 5 then
                    p.image_speed = 2.0

                    if p.image_index == 10.0 then gm.sound_play_at(gm.constants.wDroneRecycler_Recycling, 1.0, 1.0, p.x, p.y, 1.0)
                    elseif p.image_index >= 21.0 then
                        if p.animation_time < animation_print_time then p.animation_time = p.animation_time + 1
                        else
                            p.active = 6
                        end
                    end

                -- Create item drop
                elseif p.active == 6 then
                    p.active = 0.0
                    p.image_speed = -2.0

                    if Net.get_type() ~= Net.TYPE.client then
                        local created = Item.spawn_drop(p.item_id, p.box_x, p.box_y, p)
                        created.is_printed = true
                    end

                end
            end

            -- Open box again (can queue another print during this)
            if p.image_speed < 0.0 and p.image_index <= 0.0 then p.image_speed = 0.0 end
            
        end
    end
end


gm.post_script_hook(gm.constants.stage_roll_next, function(self, other, result, args)
    create_printers = true
end)

gm.post_script_hook(gm.constants.stage_goto, function(self, other, result, args)
    create_printers = true
end)

gm.post_script_hook(gm.constants.run_destroy, function(self, other, result, args)
    printer_setup_queue = {}
end)



-- ========== Net ==========

function printer_setup_helper(x, y, rarity, item_id)
    table.insert(printer_setup_queue, {x, y, rarity, item_id})
end


function printer_setup_step()
    for _, q in ipairs(printer_setup_queue) do
        if set_up_printer(q[1], q[2], q[3], q[4]) then table.remove(printer_setup_queue, _) end
    end
end


function printer_use_helper(x, y, name, taken)
    printer_use(get_printer_at(x, y), Player.get_from_name(name), taken)
end



-- ========== Main ==========

function __initialize()
    Callback.add("postHUDDraw", "Printers.draw", printer_draw, true)
    Net.register("Printers.setup", printer_setup_helper)
    Net.register("Printers.use", printer_use_helper)
end



-- ========== Debug ==========

-- gui.add_imgui(function()
--     local player = Player.get_client()
--     if player and ImGui.Begin("Printer debug") then

--         if ImGui.Button("Spawn oPrinter") then
--             local block = gm.instance_nearest(player.x, player.y, gm.constants.pBlockStatic)
--             spawn_printer(block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1)
--         elseif ImGui.Button("Spawn on nearest block") then
--             local mouse_x = gm.variable_global_get("mouse_x")
--             local mouse_y = gm.variable_global_get("mouse_y")
--             local block = gm.instance_nearest(player.x, player.y, gm.constants.pBlockStatic)
--             spawn_printer(block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1)
--         end

--     end

--     ImGui.End()
-- end)