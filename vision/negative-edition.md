# Negative Edition Consumables: How It Works

## The Problem

We want decks that give the player starting items with **negative edition** (items that don't consume a consumable slot). Balatro's built-in `config.consumables` mechanism creates items automatically but with no edition control:

```lua
-- This gives a normal mega stone (no edition)
config = {consumables = {"c_poke_megastone"}}
```

## The Solution

Bypass `config.consumables` entirely. Leave `config = {}` and manually create cards in the deck's `apply()` function:

```lua
apply = function(self)
    G.E_MANAGER:add_event(Event({
        func = function()
            local card = SMODS.create_card({key = "c_poke_megastone"})
            card:set_edition({negative = true}, true)  -- true = immediate (skip animation)
            card:add_to_deck()
            G.consumeables:emplace(card)
            return true
        end
    }))
end
```

## Why This Works

1. `SMODS.create_card({key = ...})` creates the card object
2. `set_edition({negative = true}, true)` applies the negative edition before it enters play
3. `add_to_deck()` registers it with the game's deck tracking
4. `G.consumeables:emplace(card)` places it in the consumable area

The event wrapper (`G.E_MANAGER:add_event`) ensures this runs at the right time during game initialization.

## Reference Code

This pattern is proven in PokermonPlus — the Meltan Pokemon creates a negative Metal Coat:

```lua
-- references/PokermonPlus/src/pokemon/808_meltan_line.lua:34-38
local _card = create_card('Item', G.consumeables, nil, nil, nil, nil, 'c_poke_metalcoat')
local edition = {negative = true}
_card:set_edition(edition, true)
_card:add_to_deck()
G.consumeables:emplace(_card)
```

Note: Meltan uses the older `create_card()` function. We use `SMODS.create_card()` which is the modern SMODS equivalent.

## Key Pokermon Item Keys

- Mega Stone: `c_poke_megastone`
- Master Ball: `c_poke_masterball`

(Confirmed from `references/PokermonPlus/src/challenges/000_balls_of_patience.lua`)
