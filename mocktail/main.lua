-- Mocktail Deck: Like Cocktail Deck, but works with ALL mods and lets you choose directly
-- No Multiplayer dependency — standalone mod
-- Adapted from BalatroMultiplayer's Cocktail Deck (ZZ_cocktail.lua)

----------------------------------------------
-- Atlas
----------------------------------------------

SMODS.Atlas({
    key = "back",
    px = 71,
    py = 95,
    path = "back.png"
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
-- Helper: Get all available decks (NO whitelist)
----------------------------------------------

local function get_mocktail_decks()
    local ret = {}
    for k, v in pairs(G.P_CENTERS) do
        if v.set == "Back" and k ~= "b_challenge" and k ~= "b_mocktail_mocktail" then
            ret[#ret + 1] = k
        end
    end
    table.sort(ret, function(a, b)
        return G.P_CENTERS[a].order < G.P_CENTERS[b].order
    end)
    return ret
end

----------------------------------------------
-- Config persistence (stored in own mod config)
----------------------------------------------

local function mocktail_cfg()
    return SMODS.Mods["Mocktail"].config
end

local function mocktail_cfg_get()
    return mocktail_cfg().selection or ""
end

local function mocktail_cfg_readpos(pos)
    local str = mocktail_cfg_get()
    if type(pos) == "number" then
        return str:sub(pos, pos)
    end
    return str
end

local function mocktail_cfg_edit(bool, deck)
    local decks = get_mocktail_decks()
    local cfg = mocktail_cfg()
    local num = (bool == 2) and "2" or (bool and "1" or "0")
    if not deck then
        -- Set all decks to the same value
        local str = ""
        for i = 1, #decks do
            str = str .. num
        end
        cfg.selection = str
    else
        -- Update a single deck
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
    SMODS.save_mod_config(SMODS.Mods["Mocktail"])
end

----------------------------------------------
-- Get selected decks from config
----------------------------------------------

local function get_selected_decks()
    local all_decks = get_mocktail_decks()
    local selected = {}
    local str = mocktail_cfg_get()
    for i, v in ipairs(all_decks) do
        local ch = str:sub(i, i)
        if ch == "1" or ch == "2" then
            selected[#selected + 1] = v
        end
    end
    return selected
end

----------------------------------------------
-- SMODS.Back definition
----------------------------------------------

SMODS.Back({
    key = "mocktail",
    config = {},
    atlas = "back",
    pos = { x = 0, y = 0 },

    apply = function(self)
        G.GAME.modifiers.mocktail = {}
        local selected = get_selected_decks()
        local back = G.GAME.selected_back

        for i = 1, #selected do
            G.GAME.modifiers.mocktail[i] = selected[i]

            -- Special case: Checkered Deck suit swap (from Cocktail)
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
            back.effect.config = merge(back.effect.config, G.P_CENTERS[G.GAME.modifiers.mocktail[i]].config)
            -- Handle voucher merging edge case
            if back.effect.config.voucher then
                back.effect.config.vouchers = back.effect.config.vouchers or {}
                back.effect.config.vouchers[#back.effect.config.vouchers + 1] = back.effect.config.voucher
                back.effect.config.voucher = nil
            end
            -- Call each deck's apply() if it has one
            local obj = G.P_CENTERS[G.GAME.modifiers.mocktail[i]]
            if obj.apply and type(obj.apply) == "function" then obj:apply(back) end
        end
        back.effect.mocktailed = true
    end,

    calculate = function(self, back, context)
        if G.GAME.modifiers.mocktail then
            for i = 1, #G.GAME.modifiers.mocktail do
                back:change_to(G.P_CENTERS[G.GAME.modifiers.mocktail[i]])
                local ret1, ret2 = back:trigger_effect(context)
                back:change_to(G.P_CENTERS["b_mocktail_mocktail"])
                if ret1 or ret2 then return ret1, ret2 end
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
-- UI: Selection count tracking
----------------------------------------------

G.MOCKTAIL_STATE = G.MOCKTAIL_STATE or {}
G.MOCKTAIL_STATE.count_text = "Start (0 selected)"
G.MOCKTAIL_STATE.toggle_text = "Select All (A)"

local function update_mocktail_count()
    local count = 0
    if G.mocktail_select then
        for i = 1, #G.mocktail_select do
            if G.mocktail_select[i].cards then
                for j = 1, #G.mocktail_select[i].cards do
                    if G.mocktail_select[i].cards[j].highlighted then
                        count = count + 1
                    end
                end
            end
        end
    end
    G.MOCKTAIL_STATE.count_text = "Start (" .. count .. " selected)"
    local total = 0
    if G.mocktail_select then
        for i = 1, #G.mocktail_select do
            if G.mocktail_select[i].cards then
                total = total + #G.mocktail_select[i].cards
            end
        end
    end
    G.MOCKTAIL_STATE.toggle_text = (count > 0) and "Deselect All (A)" or "Select All (A)"
end

local function mocktail_select_all()
    if not G.mocktail_select or not G.mocktail_select[1] then return end
    -- If any are highlighted, deselect all; otherwise select all
    local any_highlighted = false
    for i = 1, #G.mocktail_select do
        for j = 1, #G.mocktail_select[i].cards do
            if G.mocktail_select[i].cards[j].highlighted then
                any_highlighted = true
                break
            end
        end
        if any_highlighted then break end
    end
    local highlight = not any_highlighted
    for i = 1, #G.mocktail_select do
        for j = 1, #G.mocktail_select[i].cards do
            G.mocktail_select[i].cards[j].highlighted = highlight
        end
    end
    if highlight then
        play_sound("cardSlide1")
    else
        play_sound("cardSlide2", nil, 0.3)
    end
    mocktail_cfg_edit(highlight)
    update_mocktail_count()
end

----------------------------------------------
-- UI: Button functions
----------------------------------------------

G.FUNCS.mocktail_start = function(e)
    G.FUNCS.exit_overlay_menu(e)
    G.FUNCS.start_run(e)
end

G.FUNCS.mocktail_select_all = function(e)
    mocktail_select_all()
end

----------------------------------------------
-- UI: "A" key to select all
----------------------------------------------

local key_press_ref = Controller.key_press_update
function Controller:key_press_update(key, dt)
    if key == "a" and G.mocktail_select and G.mocktail_select[1] then
        mocktail_select_all()
    end
    return key_press_ref(self, key, dt)
end

----------------------------------------------
-- UI: Detect Mocktail deck click
----------------------------------------------

local function is_mocktail_select(card)
    if Galdur then
        return Galdur.run_setup
            and card.area == Galdur.run_setup.selected_deck_area
            and card.config.center.key == "b_mocktail_mocktail"
    else
        return G.GAME.viewed_back
            and G.GAME.viewed_back.effect
            and G.GAME.viewed_back.effect.center.key == "b_mocktail_mocktail"
            and card.facing == "back"
    end
end

----------------------------------------------
-- UI: Card click → open deck selection overlay
----------------------------------------------

local click_ref = Card.click
function Card:click()
    click_ref(self)
    if G.STAGE == G.STAGES.MAIN_MENU then
        if is_mocktail_select(self) then
            -- Clean up previous selection UI
            if G.mocktail_select then
                for i = 1, #G.mocktail_select do
                    G.mocktail_select[i]:remove()
                    G.mocktail_select[i] = nil
                end
            end

            -- Create card area rows (2 rows to display decks)
            G.mocktail_select = {}
            for i = 1, 2 do
                G.mocktail_select[i] = CardArea(
                    G.ROOM.T.x + 0.2 * G.ROOM.T.w / 1.5,
                    G.ROOM.T.h,
                    5.3 * G.CARD_W,
                    1.03 * G.CARD_H,
                    { card_limit = 5, type = "title", highlight_limit = 999, collection = true }
                )
            end

            -- Populate with all available deck cards
            local decks = get_mocktail_decks()
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
                G.mocktail_select[row]:emplace(card)
                card.sprite_facing = "back"
                card.facing = "back"
                card.mocktail_select = v
                local num = mocktail_cfg_readpos(i)
                card.highlighted = num == "1" or num == "2"
            end
            G.GAME.viewed_back = G.P_CENTERS["b_mocktail_mocktail"]

            -- Update count for button display
            update_mocktail_count()

            -- Build UI overlay
            local deck_tables = {}
            for i = 1, #G.mocktail_select do
                deck_tables[i] = {
                    n = G.UIT.R,
                    config = { align = "cm", padding = 0, no_fill = true },
                    nodes = {
                        { n = G.UIT.O, config = { object = G.mocktail_select[i] } },
                    },
                }
            end
            local t = create_UIBox_generic_options({
                back_func = "setup_run",
                snap_back = true,
                contents = {
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
                            {
                                n = G.UIT.T,
                                config = { text = localize("k_mocktail_select"), scale = 0.48, colour = G.C.WHITE },
                            },
                        },
                    },
                    {
                        n = G.UIT.R,
                        config = { align = "cl", padding = 0 },
                        nodes = {
                            {
                                n = G.UIT.T,
                                config = { text = "Press A to select/deselect all", scale = 0.32, colour = G.C.UI.TEXT_INACTIVE },
                            },
                        },
                    },
                    { n = G.UIT.R, config = { align = "cm", padding = 0.3, minh = 0.1 } },
                    {
                        n = G.UIT.R,
                        config = { align = "cm", padding = 0.1 },
                        nodes = {
                            {
                                n = G.UIT.C,
                                config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.GREEN, hover = true, button = "mocktail_start", minw = 3.5, minh = 0.6 },
                                nodes = {
                                    { n = G.UIT.T, config = { ref_table = G.MOCKTAIL_STATE, ref_value = "count_text", scale = 0.45, colour = G.C.WHITE, shadow = true } },
                                },
                            },
                            { n = G.UIT.C, config = { align = "cm", padding = 0.15 } },
                            {
                                n = G.UIT.C,
                                config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.BLUE, hover = true, button = "mocktail_select_all", minw = 2, minh = 0.6 },
                                nodes = {
                                    { n = G.UIT.T, config = { ref_table = G.MOCKTAIL_STATE, ref_value = "toggle_text", scale = 0.4, colour = G.C.WHITE, shadow = true } },
                                },
                            },
                        },
                    },
                },
            })
            G.FUNCS.overlay_menu({
                definition = t,
            })
        end
    end
end

----------------------------------------------
-- UI: "Edit Deck" hover label on Mocktail card
----------------------------------------------

local draw_ref = Card.draw
function Card:draw(layer)
    draw_ref(self, layer)
    if G.STAGE == G.STAGES.MAIN_MENU then
        if is_mocktail_select(self) then
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
                                            {
                                                n = G.UIT.T,
                                                config = {
                                                    text = "Edit",
                                                    scale = 0.48,
                                                    colour = G.C.WHITE,
                                                    shadow = true,
                                                },
                                            },
                                        },
                                    },
                                    {
                                        n = G.UIT.R,
                                        config = { align = "cm", maxw = 2 },
                                        nodes = {
                                            {
                                                n = G.UIT.T,
                                                config = {
                                                    text = "Deck",
                                                    scale = 0.38,
                                                    colour = G.C.WHITE,
                                                    shadow = true,
                                                },
                                            },
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
-- UI: Hover tooltips for deck cards in selection
----------------------------------------------

local hover_ref = Card.hover
function Card:hover()
    hover_ref(self)
    if self.mocktail_select then
        self.ability_UIBox_table = self:generate_UIBox_ability_table()
        self.config.h_popup = G.UIDEF.card_h_popup(self)
        self.config.h_popup_config = self:align_h_popup()
        Node.hover(self)
    end
end

----------------------------------------------
-- UI: Tooltip card info for deck selection cards
----------------------------------------------

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
    if card and card.mocktail_select then
        _c = G.P_CENTERS[card.mocktail_select]
        local ret = generate_card_ui_ref(
            _c, full_UI_table, specific_vars, "Back", badges, hide_desc, main_start, main_end, card
        )
        if not _c.generate_ui or type(_c.generate_ui) ~= "function" then
            -- Vanilla deck loc_vars (from Cocktail Deck)
            local name_to_check = G.P_CENTERS[card.mocktail_select].name

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
-- UI: Allow highlighting deck cards in selection
----------------------------------------------

local can_highlight_ref = CardArea.can_highlight
function CardArea:can_highlight(card)
    if card.mocktail_select then return true end
    return can_highlight_ref(self, card)
end

----------------------------------------------
-- UI: Toggle highlight = toggle selection
----------------------------------------------

local highlight_ref = Card.highlight
function Card:highlight(is_highlighted)
    if self.mocktail_select then
        mocktail_cfg_edit(is_highlighted, self.mocktail_select)
    end
    local ret = highlight_ref(self, is_highlighted)
    if self.mocktail_select then
        update_mocktail_count()
    end
    return ret
end

----------------------------------------------
-- Init: Build default config on first load
----------------------------------------------

G.E_MANAGER:add_event(Event({
    func = function()
        local decks = get_mocktail_decks()
        local cfg = mocktail_cfg()
        if (not cfg.selection) or #decks ~= #cfg.selection then
            local str = ""
            for i = 1, #decks do
                str = str .. "0"
            end
            cfg.selection = str
        end
        SMODS.save_mod_config(SMODS.Mods["Mocktail"])
        return true
    end,
}))
