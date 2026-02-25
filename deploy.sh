#!/usr/bin/env bash
# Deploy nice-deck mods to Balatro's Mods folder
# Usage: bash deploy.sh

MODS_DIR="C:/Users/Matt/AppData/Roaming/Balatro/Mods"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DECKS=("mega-plus-plus" "action-replay" "mocktail")

for deck in "${DECKS[@]}"; do
    src="$PROJECT_DIR/$deck"
    dest="$MODS_DIR/$deck"

    if [ ! -d "$src" ]; then
        echo "SKIP: $deck (not found in project)"
        continue
    fi

    # Remove old version, copy fresh
    rm -rf "$dest"
    cp -r "$src" "$dest"
    echo "  OK: $deck -> $dest"
done

echo "Done. Restart Balatro to load changes."
