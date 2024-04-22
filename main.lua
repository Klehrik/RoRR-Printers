-- Scrappers v1.0.0
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sScrapper     = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapper.png", 23, false, false, 36, 48)
local sScrapWhite   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapWhite.png", 1, false, false, 16, 16)
local sScrapGreen   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapGreen.png", 1, false, false, 16, 16)
local sScrapRed     = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapRed.png", 1, false, false, 16, 16)
local sScrapYellow  = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapYellow.png", 1, false, false, 16, 16)

local class_item    = nil
local class_stage   = nil

local scrapper_base = gm.constants.oCustomObject_pInteractableCrate
local create_scrapper = false

local scrap_names = {"White", "Green", "Red", "Yellow"}
local scrap_sprites = {sScrapWhite, sScrapGreen, sScrapRed, sScrapYellow}


-- Parameters
local scrapper_chance       = 0.25
local max_scrap_amount      = 10    -- Upper limit to how many can be scrapped at once

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = -18   -- Location of the hole of the scrapper relative to the origin
local box_y_offset          = -22
local box_input_scale       = 0     -- Item scale when it enters the scrapper



-- ========== Functions ==========

local function spawn_command_crate(x, y)
    local c = gm.instance_create_depth(x, y, 1, scrapper_base)

    -- All of the following are absolutely necessary,
    -- and are not set from creating the instance directly
    c.active = 0.0
    c.owner = -4.0
    c.activator = -4.0
    c.buy_button_visible = 0.0
    c.can_activate_frame = 0.0
    c.mouse_x_last = 0.0
    c.mouse_y_last = 0.0
    c.last_move_was_mouse = false
    c.using_mouse = false
    c.last_activated_frame = -1.0
    c.cam_rect_x1 = x - 100
    c.cam_rect_y1 = y - 100
    c.cam_rect_x2 = x + 100
    c.cam_rect_y2 = y + 100
    c.contents = nil
    c.inventory = 76.0
    c.flash = 0.0
    c.interact_scroll_index = 6.0
    c.interact_scroll_index_inactive = 5.0
    c.surf_text_cost_large = -1.0
    c.surf_text_cost_small = -1.0
    c.text = "Choose an item."
    c.spawned = true
    c.cost = 0.0
    c.cost_type = 0.0
    c.selection = 0.0
    c.select_cd = 0.0
    c.sprite_death = 1373.0
    c.fade_alpha = 0.0
    c.col_index = 0.0
    c.m_id = 0.0
    c.my_player = -4.0
    c.__custom_id = 0.0
    c.__object_index = 800.0

    return c
end


local function spawn_scrapper(x, y)
    local s = spawn_command_crate(x, y)
    s.is_scrapper = true
    s.sprite_index = sScrapper
    s.text = "Use scrapper"
    s.image_speed = 0.0

    s.animation_state = nil
    s.box_x = s.x + box_x_offset
    s.box_y = s.y + box_y_offset
end


local function spawn_scrap(x, y, rarity)
    local base = gm.instance_create_depth(x, y, 0, gm.constants.oNugget)
    base.item_id = gm.item_find("scrappers-scrap"..scrap_names[rarity])

    local item = class_item[base.item_id + 1]
    base.text1 = item[3]
    base.text2 = item[4]
    base.tier = item[7]
    base.sprite_index = item[8]
end


local function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, 16777215, alpha or 1.0)
end



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Get global references
    if not class_item then
        -- Global references
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
    end

    -- Create scrap items
    if not gm.item_find("scrappers-scrapWhite") then
        for i = 1, #scrap_names do
            local id = gm.item_create("scrappers", "scrap"..scrap_names[i])
            local item = class_item[id + 1]
            gm.array_set(item, 2, "Item Scrap ("..scrap_names[i]..")")
            gm.array_set(item, 3, "Does nothing. Prioritized when using printers.")
            gm.array_set(item, 6, (i == 4 and 4) or (i - 1))
            gm.array_set(item, 7, scrap_sprites[i])
        end
    end


    -- Place down scrapper on stage load (check when the player exists)
    if create_scrapper and Helper.get_client_player() then
        create_scrapper = false

        -- Prevent scrappers from spawning on the Contact Light
        if class_stage[gm.variable_global_get("stage_id") + 1][2] ~= "riskOfRain" then

            -- Get valid terrain
            local blocks = Helper.find_active_instance_all(gm.constants.oB)
            local tp = Helper.get_teleporter()

            -- Maybe spawn a scrapper
            if Helper.chance(scrapper_chance) then
                -- Make sure the scrapper doesn't spawn on the teleporter,
                -- as that prevents the player from using it
                while true do
                    local block = blocks[gm.irandom_range(1, #blocks)]
                    local x, y = block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1
                    if gm.point_distance(x, y, tp.x, tp.y) > 64 then
                        spawn_scrapper(x, y)
                        break
                    end
                end
            end
            
        end
    end
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Check if this is a scrapper
    if self.is_scrapper then

        -- Prevent use if it's already in use
        if self.animation_state then return false end

        local contents = gm.array_create()
        local contents_ids = gm.array_create()
        local contents_count = gm.array_create()

        -- Replace contents with player inventory
        if gm.array_length(other.inventory_item_order) > 0 then
            -- Get ids of scrap items
            local ids = {}
            for i = 1, #scrap_names do
                table.insert(ids, gm.item_find("scrappers-scrap"..scrap_names[i]))
            end

            -- Loop through inventory and add
            for _, i in ipairs(other.inventory_item_order) do

                -- Do not allow scraps to be scrapped
                if not (i == ids[1] or i == ids[2] or i == ids[3] or i == ids[4]) then

                    -- Do not allow purple+ items to be scrapped
                    if class_item[i + 1][7] <= 4.0 then

                        local count = gm.item_count(other, i, false)
                        if count > 0 then
                            gm.array_push(contents, class_item[i + 1][9])
                            gm.array_push(contents_ids, i)
                            gm.array_push(contents_count, count)
                        end
                    end
                end
            end
        end

        if #contents <= 0 then
            gm.audio_play_sound(gm.constants.wError, 0, false)
            return false
        end

        self.contents = contents
        self.contents_ids = contents_ids
        self.contents_count = contents_count
    end
end)


gm.pre_code_execute(function(self, other, code, result, flags)
    -- Check if this is a scrapper
    if self.is_scrapper then
        if code.name:match("oCustomObject_pInteractableCrate_Draw_0") then

            -- Scrapper is used
            if self.active > 1.0 then

                -- Prevent destruction of the scrapper
                -- and give back player control
                self.active = 0.0
                self.activator.activity = 0.0
                self.activator.activity_free = true
                self.activator.activity_move_factor = 1.0
                self.activator.activity_type = 0.0
                self.last_move_was_mouse = true


                -- Start scrapper animation
                self.taken = self.contents_ids[self.selection + 1]
                self.taken_count = math.min(self.contents_count[self.selection + 1], max_scrap_amount)
                self.taken_rarity = class_item[self.taken + 1][7]

                self.animation_state = 0

                gm.item_take(self.activator, self.taken, self.taken_count, false)
                gm.audio_play_sound(gm.constants.wDroneRecycler_Activate, 0, false)
            end
        end
    end
end)


gm.post_code_execute(function(self, other, code, result, flags)
    if code.name:match("oInit_Draw_7") then

        -- Loop through all scrappers
        local base_obj = Helper.find_active_instance_all(scrapper_base)
        for _, p in ipairs(base_obj) do
            if p.is_scrapper then

                -- Scrapper animation
                if p.animation_state then

                    -- Initialize animation stuff
                    if p.animation_state == 0 then
                        p.animation_state = 1
                        p.animation_time = 0
                        p.animation_items = gm.array_create()

                        for i = 1, p.taken_count do
                            local offset = ((p.taken_count - 1) * -17) + ((i - 1) * 34)
                            local array = gm.array_create()
                            gm.array_push(array, class_item[p.taken + 1][8], offset, -48, 1.0)   -- Sprite, x offset, y offset, scale
                            gm.array_push(p.animation_items, array)
                        end

                    -- Draw above player
                    elseif p.animation_state == 1 then
                        for _, i in ipairs(p.animation_items) do
                            draw_item_sprite(i[1], p.activator.x + i[2], p.activator.y + i[3])
                        end

                        if p.animation_time < animation_held_time then p.animation_time = p.animation_time + 1
                        else
                            p.animation_state = 2

                            -- Set offset values to absolute position values
                            for _, i in ipairs(p.animation_items) do
                                gm.array_set(i, 1, p.activator.x + i[2])
                                gm.array_set(i, 2, p.activator.y + i[3])
                            end
                        end

                    -- Lerp all items towards hole
                    elseif p.animation_state == 2 then
                        for _, i in ipairs(p.animation_items) do
                            draw_item_sprite(i[1], i[2], i[3], Helper.ease_out(i[4], 3))

                            gm.array_set(i, 1, gm.lerp(i[2], p.box_x, 0.1))
                            gm.array_set(i, 2, gm.lerp(i[3], p.box_y, 0.1))
                            gm.array_set(i, 3, gm.lerp(i[4], box_input_scale, 0.1))
                        end

                        local first = p.animation_items[1]
                        if gm.point_distance(first[2], first[3], p.box_x, p.box_y) < 1 then
                            p.animation_state = 3
                            p.animation_time = 0
                            gm.audio_play_sound(gm.constants.wDroneRecycler_Recycling, 0, false)
                        end

                    -- Delay for scrapping sfx
                    elseif p.animation_state == 3 then
                        if p.animation_time < animation_print_time then p.animation_time = p.animation_time + 1
                        else p.animation_state = 4
                        end

                    -- Create scrap drop(s)
                    elseif p.animation_state == 4 then
                        p.animation_state = nil

                        for i = 1, p.taken_count do spawn_scrap(p.box_x, p.box_y, (p.taken_rarity == 4 and 4) or (p.taken_rarity + 1)) end

                    end
                end
                
            end
        end

    end
end)


gm.post_script_hook(gm.constants.stage_roll_next, function(self, other, result, args)
    create_scrapper = true
end)

gm.post_script_hook(gm.constants.stage_goto, function(self, other, result, args)
    create_scrapper = true
end)


-- Debug
gui.add_imgui(function()
    local player = Helper.find_active_instance(gm.constants.oP)
    if player and ImGui.Begin("Scrappers") then

        if ImGui.Button("Spawn command crate") then
            spawn_command_crate(player.x, player.y)
        elseif ImGui.Button("Spawn scrapper") then
            spawn_scrapper(player.x, player.y)
        elseif ImGui.Button("Give white scrap") then
            for i = 1, 4 do spawn_scrap(player.x, player.y, i) end
        end

    end

    ImGui.End()
end)