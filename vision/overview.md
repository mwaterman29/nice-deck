# nice-deck: Design Overview

## Motivation

Balatro's modding scene has great mods that don't always talk to each other:
- **Pokermon** adds Pokemon-themed items (mega stones, pokeballs) but its Rogue Deck has a +4 ante penalty
- **Multiplayer's Cocktail Deck** lets you combine deck effects, but only works with vanilla decks (hardcoded whitelist)

We're filling two gaps:
1. Pokermon decks that give items with **negative edition** (no slot cost, pure upside)
2. A universal deck combiner that works across all mods

## Deck Specs

### Mega++ Deck
- **Effect**: Start with Negative Mega Stone
- **Ante change**: None (unlike Rogue Deck's +4)
- **Why negative?**: Mega Stone doesn't consume a consumable slot, giving pure strategic flexibility
- **Depends on**: Pokermon (needs mega stone item)

### Gameshark Deck
- **Effect**: Start with Negative Master Ball + Negative Mega Stone
- **Ante change**: None
- **Thematic**: Named after the classic game cheat device — you're starting with the best items, no cost
- **Depends on**: Pokermon

### Mocktail Deck
- **Effect**: Combine effects of any number of other decks (including modded ones)
- **Key difference from Cocktail**: No whitelist, no random selection, no deck count limit
- **UI**: Click deck in menu → overlay shows all available decks → click to toggle
- **Depends on**: Steamodded only (fully standalone)

## Technical Insights

### Negative Edition Items
Balatro's `config.consumables` auto-creates items but gives no control over edition.
To get negative edition, we bypass it entirely and manually create cards in `apply()`.
See `vision/negative-edition.md` for details.

### Cocktail → Mocktail Adaptation
The Cocktail Deck's core is portable — the merge function, effect composition, and calculate delegation all work without Multiplayer's infrastructure. The whitelist is a single line to remove.
See `vision/mocktail-architecture.md` for the full adaptation guide.
