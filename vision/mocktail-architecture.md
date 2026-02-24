# Mocktail Deck: Architecture & Cocktail Adaptation

## What Cocktail Does

The Multiplayer mod's Cocktail Deck (`references/BalatroMultiplayer/objects/decks/ZZ_cocktail.lua`) lets you combine effects of 3 other decks. It has 6 key systems:

1. **Deck scanning** — `MP.get_cocktail_decks()` finds all Back-type entries in `G.P_CENTERS`
2. **Config merging** — Recursive `merge()` function: numbers add, tables recursively merge
3. **Effect application** — `apply()` merges configs then calls each sub-deck's `apply()`
4. **Runtime calculation** — `calculate()` temporarily switches back via `change_to()`, triggers effects
5. **Config preservation** — `Back.change_to` override saves/restores merged config during temporary switches
6. **Selection UI** — Card.click overlay with highlight toggling, config stored as string of 0/1/2

## What Mocktail Changes

### Removed: Whitelist

**Cocktail (line 100):**
```lua
if not (v.mod and not G.P_CENTERS["b_mp_cocktail"].mod_whitelist[v.mod.id]) then ret[#ret + 1] = k end
```

**Mocktail:**
```lua
if v.set == "Back" and k ~= "b_challenge" and k ~= "b_mocktail_mocktail" then
    ret[#ret + 1] = k
end
```

This single change is what makes Mocktail work with ALL mods' decks.

### Removed: Deck Count Limit

Cocktail caps at 3 randomly chosen from the pool. Mocktail has no limit — all toggled decks are used. Players choose the chaos level.

### Removed: Random Selection

Cocktail uses `pseudoshuffle` + `pseudoseed` to randomly pick 3 from the enabled pool. Mocktail uses the exact set the player toggled — what you pick is what you get.

### Removed: Multiplayer Dependencies

All `MP.*` function calls replaced with local equivalents:
- `MP.get_cocktail_decks()` → `get_mocktail_decks()`
- `MP.cocktail_cfg_edit()` → `mocktail_cfg_edit()`
- `MP.cocktail_cfg_readpos()` → `mocktail_cfg_readpos()`
- `MP.cocktail_cfg_get()` → `mocktail_cfg_get()`
- `MP.LOBBY.config.cocktail` → `SMODS.Mods["Mocktail"].config.selection`

### Simplified: Config String

Cocktail uses 0/1/2 (deselected/enabled/forced) + H/S (hide/show stickers).
Mocktail uses just 0/1 (deselected/selected) — no forced concept, no sticker visibility toggle.

### Kept Verbatim

- `merge()` function — it works, don't fix what ain't broke
- `Back.change_to` override pattern — essential for runtime effect delegation
- `calculate()` pattern — temporarily switch back, trigger, switch back
- Vanilla deck `loc_vars` handling in `generate_card_ui` — needed for tooltip correctness
- Checkered Deck special case — suit swap needs manual handling

## Potential Edge Cases

1. **Conflicting apply() functions** — Two decks both modifying the same global (e.g. both changing `win_ante`). Numbers ADD via merge, which may not always be desired.
2. **Many decks selected** — Selecting 10+ decks could have unexpected compounding effects. This is intentional — player's choice.
3. **Mods that override Back.change_to** — If another mod (including Multiplayer's Cocktail) also overrides `Back.change_to`, there could be conflicts. Load order matters.
4. **Decks with complex events in apply()** — Some modded decks may create events that assume they're the only active deck. Merging can't solve this.

## Key Files

- `mocktail/main.lua` — All code in one file (atlas, helpers, SMODS.Back, UI overrides)
- `references/BalatroMultiplayer/objects/decks/ZZ_cocktail.lua` — Original source (648 lines)
