-- Mocktail With Friends: Multiplayer-synced version of Mocktail Deck
-- Host selects decks, selection syncs to guest via MP lobby config
-- Requires: Steamodded + Multiplayer

----------------------------------------------
-- Atlas
----------------------------------------------

SMODS.Atlas({
    key = "back",
    px = 71,
    py = 95,
    path = "back.png",
})

----------------------------------------------
-- Helper: Deep merge (from Cocktail Deck)
----------------------------------------------

local function merge(t1, t2, safe)
    local t3 = {}
    for k, v in pairs(t1) do
        if type(v) == "table" then
            t3[k] = merge(v, {})
        else
            t3[k] = v
        end
    end
    for k, v in pairs(t2) do
        local existing = t3[k]
        if type(existing) == "number" and type(v) == "number" then
            t3[k] = existing + v
        elseif type(existing) == "table" and type(v) == "table" then
            t3[k] = merge(existing, v, true)
        else
            if type(v) == "table" then
                t3[k] = merge(v, {})
            else
                local index = safe and #t3 + 1 or k
                t3[index] = v
            end
        end
    end
    return t3
end

----------------------------------------------
-- Helper: Get all available decks
----------------------------------------------

local function get_mwf_decks()
    local ret = {}
    for k, v in pairs(G.P_CENTERS) do
        if v.set == "Back"
            and k ~= "b_challenge"
            and k ~= "b_mwf_mocktailwithfriends"
            and k ~= "b_mocktail_mocktail"
            and k ~= "b_mp_cocktail"
        then
            ret[#ret + 1] = k
        end
    end
    table.sort(ret, function(a, b)
        return G.P_CENTERS[a].order < G.P_CENTERS[b].order
    end)
    return ret
end

----------------------------------------------
-- Local config persistence (position string)
----------------------------------------------

local function mwf_cfg()
    return SMODS.Mods["MocktailWithFriends"].config
end

local function mwf_cfg_get()
    return mwf_cfg().selection or ""
end

local function mwf_cfg_readpos(pos)
    local str = mwf_cfg_get()
    if type(pos) == "number" then
        return str:sub(pos, pos)
    end
    return str
end

local function mwf_cfg_edit(bool, deck)
    local decks = get_mwf_decks()
    local cfg = mwf_cfg()
    local num = (bool == 2) and "2" or (bool and "1" or "0")
    if not deck then
        local str = ""
        for i = 1, #decks do
            str = str .. num
        end
        cfg.selection = str
    else
        local function replace(s, pos, d)
            return s:sub(1, pos - 1) .. d .. s:sub(pos + 1)
        end
        for i, v in ipairs(decks) do
            if v == deck then
                cfg.selection = replace(cfg.selection, i, num)
                break
            end
        end
    end
    SMODS.save_mod_config(SMODS.Mods["MocktailWithFriends"])
end

----------------------------------------------
-- MP config functions
----------------------------------------------

local function is_mp_context()
    return MP and MP.LOBBY and MP.LOBBY.code
end

-- Serialize local position-string selection to comma-separated deck keys
local function selection_to_keys()
    local all_decks = get_mwf_decks()
    local keys = {}
    local str = mwf_cfg_get()
    for i, v in ipairs(all_decks) do
        local ch = str:sub(i, i)
        if ch == "1" or ch == "2" then
            keys[#keys + 1] = v
        end
    end
    return table.concat(keys, ",")
end

-- Parse comma-separated keys to list, filtering to locally available decks
local function keys_to_selected(key_string)
    local selected = {}
    if not key_string or key_string == "" then return selected end
    for key in key_string:gmatch("[^,]+") do
        if G.P_CENTERS[key] and G.P_CENTERS[key].set == "Back" then
            selected[#selected + 1] = key
        end
    end
    return selected
end

-- Read effective MP config (lobby when in lobby, local otherwise)
local function mwf_mp_cfg_get()
    if is_mp_context() and MP.LOBBY.deck and MP.LOBBY.deck.mocktail_wf then
        return MP.LOBBY.deck.mocktail_wf
    elseif is_mp_context() and MP.LOBBY.config and MP.LOBBY.config.mocktail_wf then
        return MP.LOBBY.config.mocktail_wf
    else
        return selection_to_keys()
    end
end

-- Sync local selection to MP lobby (host only)
local function mwf_sync()
    if not is_mp_context() then return end
    if not MP.LOBBY.is_host then return end
    local keys = selection_to_keys()
    MP.LOBBY.config.mocktail_wf = keys
    MP.ACTIONS.lobby_options()
end

----------------------------------------------
-- Get selected decks (MP-aware)
----------------------------------------------

local function get_selected_decks()
    if is_mp_context() then
        local key_string = mwf_mp_cfg_get()
        return keys_to_selected(key_string)
    else
        local all_decks = get_mwf_decks()
        local selected = {}
        local str = mwf_cfg_get()
        for i, v in ipairs(all_decks) do
            local ch = str:sub(i, i)
            if ch == "1" or ch == "2" then
                selected[#selected + 1] = v
            end
        end
        return selected
    end
end

----------------------------------------------
-- SMODS.Back definition
----------------------------------------------

SMODS.Back({
    key = "mocktailwithfriends",
    config = {},
    atlas = "back",
    pos = { x = 0, y = 0 },

    apply = function(self)
        G.GAME.modifiers.mocktail = {}
        local selected = get_selected_decks()
        local back = G.GAME.selected_back

        for i = 1, #selected do
            G.GAME.modifiers.mocktail[i] = selected[i]

            -- Special case: Checkered Deck suit swap
            if selected[i] == "b_checkered" then
                G.E_MANAGER:add_event(Event({
                    func = function()
                        for k, v in pairs(G.playing_cards) do
                            if v.base.suit == "Clubs" then v:change_suit("Spades") end
                            if v.base.suit == "Diamonds" then v:change_suit("Hearts") end
                        end
                        return true
                    end,
                }))
            end
        end

        -- Merge configs and apply effects from all selected decks
        for i = 1, #G.GAME.modifiers.mocktail do
            local center = G.P_CENTERS[G.GAME.modifiers.mocktail[i]]
            if center then
                back.effect.config = merge(back.effect.config, center.config)
                if back.effect.config.voucher then
                    back.effect.config.vouchers = back.effect.config.vouchers or {}
                    back.effect.config.vouchers[#back.effect.config.vouchers + 1] = back.effect.config.voucher
                    back.effect.config.voucher = nil
                end
                if center.apply and type(center.apply) == "function" then center:apply(back) end
            end
        end
        back.effect.mocktailed = true
    end,

    calculate = function(self, back, context)
        if G.GAME.modifiers.mocktail then
            for i = 1, #G.GAME.modifiers.mocktail do
                local center = G.P_CENTERS[G.GAME.modifiers.mocktail[i]]
                if center then
                    back:change_to(center)
                    local ret1, ret2 = back:trigger_effect(context)
                    back:change_to(G.P_CENTERS["b_mwf_mocktailwithfriends"])
                    if ret1 or ret2 then return ret1, ret2 end
                end
            end
        end
    end,
})

----------------------------------------------
-- Back.change_to override: preserve merged config
----------------------------------------------

local change_to_ref = Back.change_to
function Back:change_to(new_back)
    if self.effect.mocktailed then
        local t = copy_table(self.effect.config)
        local ret = change_to_ref(self, new_back)
        self.effect.config = copy_table(t)
        self.effect.mocktailed = true
        return ret
    end
    return change_to_ref(self, new_back)
end

----------------------------------------------
-- Hook copy_host_deck to include our config
----------------------------------------------

local copy_host_deck_ref = G.FUNCS.copy_host_deck
G.FUNCS.copy_host_deck = function()
    copy_host_deck_ref()
    if MP.LOBBY.config.mocktail_wf then
        MP.LOBBY.deck.mocktail_wf = MP.LOBBY.config.mocktail_wf
    end
end

----------------------------------------------
-- UI: Selection count tracking
----------------------------------------------

G.MWF_STATE = G.MWF_STATE or {}
G.MWF_STATE.count_text = "Done (0 selected)"
G.MWF_STATE.toggle_text = "Select All (A)"
G.MWF_STATE.readonly = false

local function update_mwf_count()
    local count = 0
    if G.mwf_select then
        for i = 1, #G.mwf_select do
            if G.mwf_select[i].cards then
                for j = 1, #G.mwf_select[i].cards do
                    if G.mwf_select[i].cards[j].highlighted then
                        count = count + 1
                    end
                end
            end
        end
    end
    G.MWF_STATE.count_text = "Done (" .. count .. " selected)"
    G.MWF_STATE.toggle_text = (count > 0) and "Deselect All (A)" or "Select All (A)"
end

local function mwf_select_all()
    if not G.mwf_select or not G.mwf_select[1] then return end
    if G.MWF_STATE.readonly then return end
    local any_highlighted = false
    for i = 1, #G.mwf_select do
        for j = 1, #G.mwf_select[i].cards do
            if G.mwf_select[i].cards[j].highlighted then
                any_highlighted = true
                break
            end
        end
        if any_highlighted then break end
    end
    local highlight = not any_highlighted
    for i = 1, #G.mwf_select do
        for j = 1, #G.mwf_select[i].cards do
            G.mwf_select[i].cards[j].highlighted = highlight
        end
    end
    if highlight then
        play_sound("cardSlide1")
    else
        play_sound("cardSlide2", nil, 0.3)
    end
    mwf_cfg_edit(highlight)
    mwf_sync()
    update_mwf_count()
end

----------------------------------------------
-- UI: Button functions
----------------------------------------------

G.FUNCS.mwf_done = function(e)
    G.FUNCS.exit_overlay_menu(e)
end

G.FUNCS.mwf_select_all = function(e)
    mwf_select_all()
end

----------------------------------------------
-- UI: "A" key to select all
----------------------------------------------

local key_press_ref = Controller.key_press_update
function Controller:key_press_update(key, dt)
    if key == "a" and G.mwf_select and G.mwf_select[1] and not G.MWF_STATE.readonly then
        mwf_select_all()
    end
    return key_press_ref(self, key, dt)
end

----------------------------------------------
-- UI: Detect MWF deck click
----------------------------------------------

local function is_mwf_select(card)
    if Galdur then
        return Galdur.run_setup
            and card.area == Galdur.run_setup.selected_deck_area
            and card.config.center.key == "b_mwf_mocktailwithfriends"
    else
        return G.GAME.viewed_back
            and G.GAME.viewed_back.effect
            and G.GAME.viewed_back.effect.center.key == "b_mwf_mocktailwithfriends"
            and card.facing == "back"
    end
end

----------------------------------------------
-- UI: Card click -> open deck selection overlay
----------------------------------------------

local click_ref = Card.click
function Card:click()
    click_ref(self)
    if G.STAGE == G.STAGES.MAIN_MENU then
        if is_mwf_select(self) then
            -- Determine host/guest mode
            local is_readonly = is_mp_context() and not MP.LOBBY.is_host
            G.MWF_STATE.readonly = is_readonly

            -- Clean up previous selection UI
            if G.mwf_select then
                for i = 1, #G.mwf_select do
                    G.mwf_select[i]:remove()
                    G.mwf_select[i] = nil
                end
            end

            -- Create card area rows
            G.mwf_select = {}
            for i = 1, 2 do
                G.mwf_select[i] = CardArea(
                    G.ROOM.T.x + 0.2 * G.ROOM.T.w / 1.5,
                    G.ROOM.T.h,
                    5.3 * G.CARD_W,
                    1.03 * G.CARD_H,
                    { card_limit = 5, type = "title", highlight_limit = 999, collection = true }
                )
            end

            -- Build selected key set for guest read-only mode
            local selected_key_set = {}
            if is_readonly then
                local key_str = mwf_mp_cfg_get()
                local selected_list = keys_to_selected(key_str)
                for _, sk in ipairs(selected_list) do
                    selected_key_set[sk] = true
                end
            end

            -- Populate with all available deck cards
            local decks = get_mwf_decks()
            for i, v in ipairs(decks) do
                local row = math.floor((((i - 1) / #decks) * 2) + 1)
                G.GAME.viewed_back = G.P_CENTERS[v]
                local card = Card(
                    G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
                    G.ROOM.T.h,
                    G.CARD_W,
                    G.CARD_H,
                    pseudorandom_element(G.P_CARDS),
                    G.P_CENTERS.c_base,
                    { playing_card = i, bypass_back = G.P_CENTERS[v].pos }
                )
                G.mwf_select[row]:emplace(card)
                card.sprite_facing = "back"
                card.facing = "back"
                card.mwf_select = v
                card.mwf_readonly = is_readonly

                -- Set highlight state
                if is_readonly then
                    card.highlighted = selected_key_set[v] or false
                else
                    local num = mwf_cfg_readpos(i)
                    card.highlighted = num == "1" or num == "2"
                end
            end
            G.GAME.viewed_back = G.P_CENTERS["b_mwf_mocktailwithfriends"]

            update_mwf_count()

            -- Build UI overlay
            local deck_tables = {}
            for i = 1, #G.mwf_select do
                deck_tables[i] = {
                    n = G.UIT.R,
                    config = { align = "cm", padding = 0, no_fill = true },
                    nodes = {
                        { n = G.UIT.O, config = { object = G.mwf_select[i] } },
                    },
                }
            end

            -- Build button row based on host/guest
            local button_nodes = {}
            if not is_readonly then
                -- Host: Done button + Select All
                button_nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.GREEN, hover = true, button = "mwf_done", minw = 3.5, minh = 0.6 },
                        nodes = {
                            { n = G.UIT.T, config = { ref_table = G.MWF_STATE, ref_value = "count_text", scale = 0.45, colour = G.C.WHITE, shadow = true } },
                        },
                    },
                    { n = G.UIT.C, config = { align = "cm", padding = 0.15 } },
                    {
                        n = G.UIT.C,
                        config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.BLUE, hover = true, button = "mwf_select_all", minw = 2, minh = 0.6 },
                        nodes = {
                            { n = G.UIT.T, config = { ref_table = G.MWF_STATE, ref_value = "toggle_text", scale = 0.4, colour = G.C.WHITE, shadow = true } },
                        },
                    },
                }
            end

            -- Instruction text
            local instruction_text = is_readonly
                and localize("k_mwf_readonly")
                or localize("k_mwf_select")
            local sub_instruction = is_readonly
                and ""
                or "Press A to select/deselect all"

            local contents = {
                { n = G.UIT.R, config = { align = "cl", padding = 0.4, minh = 0.4 } },
                {
                    n = G.UIT.R,
                    config = { align = "cm", minw = 2.5, padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
                    nodes = deck_tables,
                },
                {
                    n = G.UIT.R,
                    config = { align = "cl", padding = 0 },
                    nodes = {
                        { n = G.UIT.T, config = { text = instruction_text, scale = 0.48, colour = G.C.WHITE } },
                    },
                },
            }

            -- Sub-instruction (only for host)
            if sub_instruction ~= "" then
                contents[#contents + 1] = {
                    n = G.UIT.R,
                    config = { align = "cl", padding = 0 },
                    nodes = {
                        { n = G.UIT.T, config = { text = sub_instruction, scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
                    },
                }
            end

            contents[#contents + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.3, minh = 0.1 } }

            -- Button row (only for host)
            if #button_nodes > 0 then
                contents[#contents + 1] = {
                    n = G.UIT.R,
                    config = { align = "cm", padding = 0.1 },
                    nodes = button_nodes,
                }
            end

            local t = create_UIBox_generic_options({
                back_func = "setup_run",
                snap_back = true,
                contents = contents,
            })
            G.FUNCS.overlay_menu({
                definition = t,
            })
        end
    end
end

----------------------------------------------
-- UI: Hover label on MWF deck card
----------------------------------------------

local draw_ref = Card.draw
function Card:draw(layer)
    draw_ref(self, layer)
    if G.STAGE == G.STAGES.MAIN_MENU then
        if is_mwf_select(self) then
            local is_readonly = is_mp_context() and not MP.LOBBY.is_host
            local label_top = is_readonly and "View" or "Edit"
            if not self.children.view_deck then
                self.children.view_deck = UIBox({
                    definition = {
                        n = G.UIT.ROOT,
                        config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR },
                        nodes = {
                            {
                                n = G.UIT.R,
                                config = {
                                    align = "cm",
                                    padding = 0.05,
                                    r = 0.1,
                                    colour = adjust_alpha(G.C.BLACK, 0.5),
                                    func = "set_button_pip",
                                    focus_args = { button = "triggerright", orientation = "bm", scale = 0.6 },
                                    button = "deck_info",
                                },
                                nodes = {
                                    {
                                        n = G.UIT.R,
                                        config = { align = "cm", maxw = 2 },
                                        nodes = {
                                            { n = G.UIT.T, config = { text = label_top, scale = 0.48, colour = G.C.WHITE, shadow = true } },
                                        },
                                    },
                                    {
                                        n = G.UIT.R,
                                        config = { align = "cm", maxw = 2 },
                                        nodes = {
                                            { n = G.UIT.T, config = { text = "Deck", scale = 0.38, colour = G.C.WHITE, shadow = true } },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    config = { align = "cm", offset = { x = 0, y = 0 }, major = self, parent = self },
                })
                self.children.view_deck.states.collide.can = false
            end
            self.children.view_deck.states.visible = self.states.hover.is
        end
    end
end

----------------------------------------------
-- UI: Hover tooltips for deck cards
----------------------------------------------

local hover_ref = Card.hover
function Card:hover()
    hover_ref(self)
    if self.mwf_select then
        self.ability_UIBox_table = self:generate_UIBox_ability_table()
        self.config.h_popup = G.UIDEF.card_h_popup(self)
        self.config.h_popup_config = self:align_h_popup()
        Node.hover(self)
    end
end

----------------------------------------------
-- UI: Tooltip card info for deck cards
----------------------------------------------

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
    if card and card.mwf_select then
        _c = G.P_CENTERS[card.mwf_select]
        local ret = generate_card_ui_ref(
            _c, full_UI_table, specific_vars, "Back", badges, hide_desc, main_start, main_end, card
        )
        if not _c.generate_ui or type(_c.generate_ui) ~= "function" then
            local name_to_check = G.P_CENTERS[card.mwf_select].name

            if name_to_check == "Blue Deck" then
                specific_vars = { _c.config.hands }
            elseif name_to_check == "Red Deck" then
                specific_vars = { _c.config.discards }
            elseif name_to_check == "Yellow Deck" then
                specific_vars = { _c.config.dollars }
            elseif name_to_check == "Green Deck" then
                specific_vars = { _c.config.extra_hand_bonus, _c.config.extra_discard_bonus }
            elseif name_to_check == "Black Deck" then
                specific_vars = { _c.config.joker_slot, -_c.config.hands }
            elseif name_to_check == "Magic Deck" then
                specific_vars = {
                    localize({ type = "name_text", key = "v_crystal_ball", set = "Voucher" }),
                    localize({ type = "name_text", key = "c_fool", set = "Tarot" }),
                }
            elseif name_to_check == "Nebula Deck" then
                specific_vars = { localize({ type = "name_text", key = "v_telescope", set = "Voucher" }), -1 }
            elseif name_to_check == "Zodiac Deck" then
                specific_vars = {
                    localize({ type = "name_text", key = "v_tarot_merchant", set = "Voucher" }),
                    localize({ type = "name_text", key = "v_planet_merchant", set = "Voucher" }),
                    localize({ type = "name_text", key = "v_overstock_norm", set = "Voucher" }),
                }
            elseif name_to_check == "Painted Deck" then
                specific_vars = { _c.config.hand_size, _c.config.joker_slot }
            elseif name_to_check == "Anaglyph Deck" then
                specific_vars = { localize({ type = "name_text", key = "tag_double", set = "Tag" }) }
            elseif name_to_check == "Plasma Deck" then
                specific_vars = { _c.config.ante_scaling }
            end

            localize({ type = "descriptions", key = _c.key, set = _c.set, nodes = ret.main, vars = specific_vars })
        end
        return ret
    end
    return generate_card_ui_ref(
        _c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card
    )
end

----------------------------------------------
-- UI: Allow highlighting deck cards
----------------------------------------------

local can_highlight_ref = CardArea.can_highlight
function CardArea:can_highlight(card)
    if card.mwf_select then
        if card.mwf_readonly then return false end
        return true
    end
    return can_highlight_ref(self, card)
end

----------------------------------------------
-- UI: Toggle highlight = toggle selection
----------------------------------------------

local highlight_ref = Card.highlight
function Card:highlight(is_highlighted)
    if self.mwf_select then
        if self.mwf_readonly then
            return highlight_ref(self, self.highlighted)
        end
        mwf_cfg_edit(is_highlighted, self.mwf_select)
        mwf_sync()
    end
    local ret = highlight_ref(self, is_highlighted)
    if self.mwf_select then
        update_mwf_count()
    end
    return ret
end

----------------------------------------------
-- Init: Build default config on first load
----------------------------------------------

G.E_MANAGER:add_event(Event({
    func = function()
        local decks = get_mwf_decks()
        local cfg = mwf_cfg()
        if (not cfg.selection) or #decks ~= #cfg.selection then
            local str = ""
            for i = 1, #decks do
                str = str .. "0"
            end
            cfg.selection = str
        end
        SMODS.save_mod_config(SMODS.Mods["MocktailWithFriends"])
        return true
    end,
}))
