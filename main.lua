-- Printers v1.0.13
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for _, m in pairs(mods) do if type(m) == "table" and m.RoRR_Modding_Toolkit then Achievement = m.Achievement Actor = m.Actor Alarm = m.Alarm Array = m.Array Artifact = m.Artifact Buff = m.Buff Callback = m.Callback Class = m.Class Color = m.Color Equipment = m.Equipment Helper = m.Helper Instance = m.Instance Interactable = m.Interactable Item = m.Item Language = m.Language List = m.List Net = m.Net Object = m.Object Player = m.Player Resources = m.Resources Skill = m.Skill State = m.State Survivor_Log = m.Survivor_Log Survivor = m.Survivor Wrap = m.Wrap break end end end)

config = {
    show_names = false
}
local file_path = path.combine(paths.plugins_data(), _ENV["!guid"]..".txt")
local success, file = pcall(toml.decodeFromFile, file_path)
if success then config = file.config end

sPrinter = nil
item_colors = {}
text_colors = {"", "<g>", "<r>", "", "<y>"}
tier_names = {"common", "uncommon", "rare", "", "boss"}
scrap_names = {"White", "Green", "Red", "", "Yellow"}

animation_held_time   = 80
animation_print_time  = 32
box_x_offset          = -18     -- Location of the input box of the printer relative to the origin
box_y_offset          = -22
box_input_scale       = 0.4     -- Item scale when it enters the input box

printer_setup_queue = {}

ban_list = {
    "scrappers-scrapWhite",
    "scrappers-scrapGreen",
    "scrappers-scrapRed",
    "scrappers-scrapYellow",
    "betterCrates-cancel"
}

-- Parameters
-- Common, Uncommon, Rare, Boss
spawn_tiers = nil
spawn_costs = {65, 75, 140, 140}    -- Small chest is 50, large chest is 110, and basic shrine is 65
spawn_weights = {6, 3, 1, 1}        -- Small/large chests and basic shrines are 8
spawn_rarities = {1, 1, 4, 4}       -- Small/large chests are 1, and drone upgraders/recyclers are 4



-- ========== Main ==========

function __initialize()
    sPrinter = Resources.sprite_load("klehrik", "printer", _ENV["!plugins_mod_folder_path"].."/sPrinter.png", 23, 36, 48)
    item_colors = {
        Color.ITEM_WHITE,
        Color.ITEM_GREEN,
        Color.ITEM_RED,
        0,
        Color.ITEM_YELLOW
    }

    spawn_tiers = {Item.TIER.common, Item.TIER.uncommon, Item.TIER.rare, Item.TIER.boss}

    require("./helper")
    require("./interactable")

    Callback.add("onStageStart", "Printers.stage_start",
    function()
        -- [Single/Host]  Create guaranteed printers in the Contact Light's cabin
        local stage_identifier = Class.STAGE:get(gm.variable_global_get("stage_id")):get(1)
        if stage_identifier == "riskOfRain" then
            for r = 0, 2 do
                Object.find("klehrik-printer"..(r + 1)):create(7650 + (160 * r), 3264)
            end
        end

        -- Destroy printers if Command is active
        local active = Artifact.find("ror-command").active
        if active == true or active == 1.0 then
            for i = 1, #spawn_tiers do
                local ps = Instance.find_all(Object.find("klehrik-printer"..i))
                for _, p in ipairs(ps) do p:destroy() end
            end
        end
    end, true)

    Callback.add("postStep", "Printers.setup_queue",
    function()
        for i, p in ipairs(printer_setup_queue) do
            if p[3] > 0 then p[3] = p[3] - 1
            else
                Net.send("Printers.setup", Net.TARGET.all, nil, p[1].m_id, p[2])
                table.remove(printer_setup_queue, i)
            end
        end
    end, true)

    Net.register("Printers.setup", setup_printer)
    Net.register("Printers.use", printer_use)
end


gui.add_to_menu_bar(function()
    local value, pressed = ImGui.Checkbox("Show item names", config.show_names)
    if pressed then
        config.show_names = value
        pcall(toml.encodeToFile, {config = config}, {file = file_path, overwrite = true})
    end
end)