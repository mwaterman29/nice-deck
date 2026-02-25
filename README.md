# nice-deck

Custom Balatro deck mods built on [Steamodded (SMODS)](https://github.com/Steamopollys/Steamodded).

## Decks

### Mega++ Deck
Start with a **Negative** Mega Stone (no consumable slot used).
Unlike the Rogue Deck from Pokermon+, there's no ante requirement change — just pure mega evolution power.

**Requires**: [Pokermon](https://github.com/InertSteak/Pokermon) (>=3.6.0)

### Action Replay Deck
Start with a **Negative** Master Ball and a **Negative** Mega Stone.
Both items take no consumable slots. Catch 'em all from turn one.

**Requires**: [Pokermon](https://github.com/InertSteak/Pokermon) (>=3.6.0)

### Mocktail Deck
Like Multiplayer's Cocktail Deck, but works with **all** mods' decks — not just vanilla.
Click the deck to open a selection overlay and directly choose which decks to combine. No hard limit.

**Requires**: [Steamodded](https://github.com/Steamopollys/Steamodded) (>=1.0.0) only — no Multiplayer dependency.

### Mocktail With Friends Deck
Multiplayer version of Mocktail Deck. The host selects which decks to combine,
and the selection syncs to the guest via the lobby. Both players play with the same merged deck.
Gracefully handles mod mismatches — if the host picks a deck the guest doesn't have, it's skipped.

**Requires**: [Steamodded](https://github.com/Steamopollys/Steamodded) (>=1.0.0) + [Multiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer) (>=0.3.0)

## Installation

Copy any deck folder (e.g. `mega-plus-plus/`) into your Balatro `Mods/` directory.

## Project Structure

```
nice-deck/
├── mega-plus-plus/   # Mega++ Deck mod
├── action-replay/    # Action Replay Deck mod
├── mocktail/                # Mocktail Deck mod
├── mocktail-with-friends/   # Mocktail With Friends (MP) mod
├── vision/                  # Design docs and learnings
└── references/       # Cloned reference repos for study
```

## Credits & Inspiration

- [Pokermon](https://github.com/InertSteak/Pokermon) — the base Pokemon x Balatro mod
- [PokermonPlus](https://github.com/SonfiveTV/PokermonPlus) — Rogue Deck pattern and negative edition technique
- [BalatroMultiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer) — Cocktail Deck effect composition
