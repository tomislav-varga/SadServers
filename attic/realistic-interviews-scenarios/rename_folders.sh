#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

for dir in "$TARGET_DIR"/*/; do
    name=$(basename "$dir")
    new_name=$(echo "$name" | sed 's/^[0-9]*-//')

    if [ "$name" != "$new_name" ]; then
        echo "Renaming: '$name' -> '$new_name'"
        mv "$TARGET_DIR/$name" "$TARGET_DIR/$new_name"
    fi
done
