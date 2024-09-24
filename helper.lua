-- Helper

function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, Color.WHITE, alpha or 1.0)
end


function add_to_stages(obj)
    obj:add_to_stage("ror-desolateForest")
    obj:add_to_stage("ror-driedLake")
    obj:add_to_stage("ror-dampCaverns")
    obj:add_to_stage("ror-skyMeadow")
    obj:add_to_stage("ror-ancientValley")
    obj:add_to_stage("ror-sunkenTombs")
    obj:add_to_stage("ror-magmaBarracks")
    obj:add_to_stage("ror-hiveCluster")
    obj:add_to_stage("ror-templeOfTheElders")
end


function setup_printer(m_id, item_id)
    -- Find target printer
    local p = nil
    local printers = Instance.find_all(
        Object.find("klehrik-printer1"),
        Object.find("klehrik-printer2"),
        Object.find("klehrik-printer3"),
        Object.find("klehrik-printer4")
    )
    for _, v in ipairs(printers) do
        if v.m_id == m_id then
            p = v
            break
        end
    end

    -- Check if target printer has been found
    if not p then return false end
    local pData = p:get_data()
    pData.init = true

    -- Set item variables
    pData.item_id = item_id
    pData.item = Item.wrap(item_id)

    -- Set prompt text
    pData.item_name = Language.translate_token(pData.item.token_name)
    p.text = "Print "..text_colors[pData.item.tier + 1]..pData.item_name.." <y>(1 "..tier_names[pData.item.tier + 1].." item)"

    return true
end


function printer_use(self, m_id, actor, item_id_taken)
    if not self then
        -- Find target printer
        local printers = Instance.find_all(
            Object.find("klehrik-printer1"),
            Object.find("klehrik-printer2"),
            Object.find("klehrik-printer3"),
            Object.find("klehrik-printer4")
        )
        for _, v in ipairs(printers) do
            if v.m_id == m_id then
                self = v
                break
            end
        end

        -- Check if target printer has been found
        if not self then return end
    end

    if type(actor) == "string" then actor = Player.get_from_name(actor) end

    local selfData = self:get_data()

    if not item_id_taken then
        local items = {}

        -- Check if the user has scrap for this tier
        local item = Item.find("scrappers-scrap"..scrap_names[selfData.item.tier + 1])
        if item and actor:item_stack_count(item, Item.TYPE.real) > 0 then
            selfData.taken = item
            
        -- Check if the user has a valid item to print with
        else
            local size = #actor.inventory_item_order
            if size > 0 then
                for i = 0, size - 1 do
                    local item = Item.wrap(actor.inventory_item_order:get(i))

                    if actor:item_stack_count(item, Item.TYPE.real) > 0 then
                        -- Valid item if the same rarity and NOT the same item as the printer
                        if item.tier == selfData.item.tier and item.value ~= selfData.item.value then
                            table.insert(items, {item, i})
                        end
                    end
                end
            end

            if #items <= 0 then
                self.value:sound_play_at(gm.constants.wError, 1.0, 1.0, self.x, self.y, 1.0)
                return false
            end

            -- Pick a random valid item
            local chosen = items[gm.irandom_range(1, #items)]
            selfData.taken = chosen[1]
            item_id_taken = chosen[2]
        end
    else selfData.taken = Item.wrap(item_id_taken)
    end

    -- [Single/Host]  Remove item from inventory
    if Net.get_type() ~= Net.TYPE.client then actor:item_remove(selfData.taken) end

    -- Set printer variables
    selfData.animation_time = 0
    self.value:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, self.x, self.y, 1.0)
    
    self:set_state(1)

    return item_id_taken
end