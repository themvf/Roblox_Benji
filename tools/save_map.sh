#!/usr/bin/env bash
# Map authoring entry point. The work is in tools/map.luau; this only finds the repo.
#
#     bash tools/save_map.sh new <Name>              start a blank Convergence draft
#     bash tools/save_map.sh <Name>                  convert the saved source into the playable map
#     bash tools/save_map.sh <Name> --commit "msg"   ...and commit just this map's files (never pushes)
#     bash tools/save_map.sh duplicate <From> <To>   copy a draft under a new name
#     bash tools/save_map.sh status [<Name>]         is the playable version your latest save?
#     bash tools/save_map.sh restore <Name> [<n>]    list or restore earlier saved sources
#     bash tools/save_map.sh --all                   every project gate, the way CI runs them
#
# Converting checks the named map only; an unrelated map's failure is reported by
# --all and CI instead of blocking a draft. Nothing is staged, committed or pushed
# unless --commit is given, and publishing (pushing) is always a separate, deliberate step.
# Windows without Git Bash: tools\save_map.cmd takes the same arguments.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

case "${1:-}" in
    --all)
        FAILED=0
        for gate in check_maps check_bake check_fortress_layout check_decor check_convergence_entry \
            check_finale_plan check_map_authoring; do
            printf '  %-24s ' "$gate"
            if out=$(lune run "tools/$gate.luau" 2>&1); then
                echo "OK"
            else
                echo "FAIL"
                echo "$out" | grep -v '^PASS' | sed 's/^/        /' | head -16
                FAILED=1
            fi
        done
        exit "$FAILED"
        ;;
    new | duplicate | copy | status | restore | help | "")
        exec lune run tools/map.luau "$@"
        ;;
    -*)
        exec lune run tools/map.luau help
        ;;
    *)
        exec lune run tools/map.luau convert "$@"
        ;;
esac
