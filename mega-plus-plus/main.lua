-- Mega++ Deck: Start with a Negative Mega Stone (no consumable slot used)
-- Requires Pokermon mod for Mega Stone item

SMODS.Atlas({
    key = "back",
    px = 71,
    py = 95,
    path = "back.png"
})

if (SMODS.Mods["Pokermon"] or {}).can_load then
    SMODS.Back({
        key = "megaplusplus",
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
                    local card = SMODS.create_card({ key = "c_poke_megastone" })
                    card:set_edition({ negative = true }, true)
                    card:add_to_deck()
                    G.consumeables:emplace(card)
                    return true
                end
            }))
        end,
    })
end
