-- Action Replay Deck: Start with a Negative Master Ball and Negative Mega Stone
-- Requires Pokermon mod for both items

SMODS.Atlas({
    key = "back",
    px = 71,
    py = 95,
    path = "back.png"
})

if (SMODS.Mods["Pokermon"] or {}).can_load then
    SMODS.Back({
        key = "actionreplay",
        atlas = "back",
        pos = { x = 0, y = 0 },
        config = {},
        loc_vars = function(self, info_queue, center)
            return { vars = {} }
        end,
        apply = function(self)
            delay(0.4)
            G.E_MANAGER:add_event(Event({
                func = function()
                    -- Create Negative Master Ball
                    local masterball = SMODS.create_card({ key = "c_poke_masterball" })
                    masterball:set_edition({ negative = true }, true)
                    masterball:add_to_deck()
                    G.consumeables:emplace(masterball)

                    -- Create Negative Mega Stone
                    local megastone = SMODS.create_card({ key = "c_poke_megastone" })
                    megastone:set_edition({ negative = true }, true)
                    megastone:add_to_deck()
                    G.consumeables:emplace(megastone)

                    return true
                end
            }))
        end,
    })
end
