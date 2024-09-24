-- Interactable

for _type = 1, #spawn_tiers do

    local obj = Interactable.new("klehrik", "printer".._type)
    obj.obj_sprite = sPrinter
    obj.spawn_with_sacrifice = true
    obj.required_tile_space = 2.0
    add_to_stages(obj)

    local printer_tier  = spawn_tiers[_type]
    obj.spawn_cost      = spawn_costs[_type]
    obj.spawn_weight    = spawn_weights[_type]
    obj.default_spawn_rarity_override = spawn_rarities[_type]

    obj:onCreate(function(self)
        local selfData = self:get_data()

        -- Set general variables
        selfData.box_x = self.x + box_x_offset
        selfData.box_y = self.y + box_y_offset

        -- [Single/Host]  Set up printer
        if Net.get_type() == Net.TYPE.client then return end

        selfData.init = true

        -- Pick printer item
        -- Make sure that the item is:
        --      of the same rarity
        --      not in the item ban list
        --      is actually unlocked (if applicable)
        local item_id, item = 0, nil
        repeat
            item_id = gm.irandom_range(0, #Class.ITEM - 1)
            item = Item.wrap(item_id)
        until
            item.tier == printer_tier
            and item.namespace and item.identifier
            and (not Helper.table_has(ban_list, item.namespace.."-"..item.identifier))
            and item:is_unlocked()

        -- Set item variables
        selfData.item_id = item_id
        selfData.item = item

        -- Set prompt text
        selfData.item_name = Language.translate_token(item.token_name)
        self.text = "Print "..text_colors[item.tier + 1]..selfData.item_name.." <y>(1 "..tier_names[item.tier + 1].." item)"
    
        -- [Host]  Send setup data to clients
        if Net.get_type() == Net.TYPE.host then
            table.insert(printer_setup_queue, {self, item_id, 6})
        end
    end)

    obj:onActivate(function(self, actor)
        if not actor:same(Player.get_client()) then return end

        if Net.get_type() == Net.TYPE.single then
            printer_use(self, nil, actor, item_id_taken)

        else
            local taken = printer_use(self, nil, actor, item_id_taken)
            if taken then
                Net.send("Printers.use", Net.TARGET.all, nil, nil, self.m_id, actor.user_name, taken)
            end
        end
    end)

    -- Draw above player
    obj:onStateDraw(function(self)
        local selfData = self:get_data()

        draw_item_sprite(selfData.taken.sprite_id, self.activator.x, self.activator.y - 48)

        if selfData.animation_time < animation_held_time then selfData.animation_time = selfData.animation_time + 1
        else
            selfData.taken_x = self.activator.x
            selfData.taken_y = self.activator.y - 48
            selfData.taken_scale = 1.0
            self:set_state(2)
        end
    end, 1)

    -- Slide item towards input box
    obj:onStateDraw(function(self)
        local selfData = self:get_data()

        draw_item_sprite(selfData.taken.sprite_id, selfData.taken_x, selfData.taken_y, selfData.taken_scale)
        
        selfData.taken_x = gm.lerp(selfData.taken_x, selfData.box_x, 0.1)
        selfData.taken_y = gm.lerp(selfData.taken_y, selfData.box_y, 0.1)
        selfData.taken_scale = gm.lerp(selfData.taken_scale, box_input_scale, 0.1)

        if gm.point_distance(selfData.taken_x, selfData.taken_y, selfData.box_x, selfData.box_y) < 1 then
            selfData.animation_time = 0
            self:set_state(3)
        end
    end, 2)

    -- Close box for a bit
    obj:onStateStep(function(self)
        local selfData = self:get_data()
        self.image_speed = 1.0

        if self.image_index == 10.0 then self.value:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1.0, 1.0, self.x, self.y, 1.0)
        elseif self.image_index >= 21.0 then
            if selfData.animation_time < animation_print_time then selfData.animation_time = selfData.animation_time + 1
            else self:set_state(4)
            end
        end
    end, 3)

    -- Create item drop and reset
    obj:onStateStep(function(self)
        local selfData = self:get_data()
        self.image_speed = -1.0

        -- [Single/Host]  Create item drop
        if Net.get_type() ~= Net.TYPE.client then
            local created = selfData.item:create(selfData.box_x, selfData.box_y, self)
            created.is_printed = true
        end

        self:set_state(0)
    end, 4)

    obj:onStep(function(self)
        if self.image_speed < 0.0 and self.image_index <= 0 then
            self.image_speed = 0.0
        end
    end)

    obj:onDraw(function(self)
        local selfData = self:get_data()
        if not selfData.init then return end

        local frame = gm.variable_global_get("_current_frame")

        -- Draw hovering sprite
        draw_item_sprite(selfData.item.sprite_id,
                        self.x + 10,
                        self.y - 33 + gm.dsin(frame * 1.333) * 3,
                        0.8,
                        0.8 + gm.dsin(frame * 4) * 0.25)

        -- Display item name (if enabled)
        if config.show_names then
            local cb = 0
            local c = item_colors[selfData.item.tier + 1]
            gm.draw_set_font(gm.asset_get_index("fntNormal"))
            gm.draw_set_halign(1)   -- fa_center
            for i = 1, 2 do gm.draw_text_color(self.x + i, self.y - 68 + i, selfData.item_name, cb, cb, cb, cb, 1.0) end
            gm.draw_text_color(self.x, self.y - 68, selfData.item_name, c, c, c, c, 1.0)
        end
    end)

end