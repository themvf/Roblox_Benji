#!/usr/bin/env bash
# Gate a saved map and commit it, without waiting on anybody.
#
# After the first save of a new map -- which needs a .lua data file written by hand --
# saving is self-contained: the geometry is in the .rbxm and the gates read it. Routing
# that through a second person makes them a queue rather than a contributor.
#
#     bash tools/save_map.sh                  gate only, commit nothing
#     bash tools/save_map.sh -c "message"     gate, then commit and push if clean
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

COMMIT=""
if [ "${1:-}" = "-c" ]; then
    COMMIT="${2:-Update map geometry}"
fi

FAILED=0
for gate in check_bake check_maps check_fortress_layout check_decor check_convergence_entry check_finale_plan; do
    printf '  %-24s ' "$gate"
    if out=$(lune run "tools/$gate.luau" 2>&1); then
        echo "OK"
    else
        echo "FAIL"
        echo "$out" | sed 's/^/        /' | head -12
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo
    echo "Gates failed. Nothing committed."
    echo "A work-in-progress map failing a check is a to-do list, not a rejection --"
    echo "the map still loads. Fix them, or commit deliberately with git if you want it saved as is."
    exit 1
fi

echo
echo "All gates pass."
if [ -z "$COMMIT" ]; then
    git status --short -- assets/environment/baked | sed 's/^/  /'
    echo "Run with -c \"message\" to commit and push."
    exit 0
fi

git add assets/environment/baked || exit 1
if git diff --cached --quiet; then
    echo "Nothing changed; no commit made."
    exit 0
fi
git commit -m "$COMMIT" --author="$(git config user.name) <$(git config user.email)>" | tail -2
git push origin HEAD:master 2>&1 | tail -2
