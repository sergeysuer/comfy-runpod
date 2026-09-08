#!/usr/bin/env bash
# Reads /build/nodes.txt and installs every enabled custom node.
# Deliberately does NOT abort on a single bad node - it reports at the end.
set -uo pipefail

NODES_DIR="/comfyui/custom_nodes"
LIST="/build/nodes.txt"

mkdir -p "$NODES_DIR"
cd "$NODES_DIR"

OK=()
FAILED=()

while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw%%#*}"                       # drop comments
    line="$(echo "$line" | tr -d '\r' | xargs || true)"   # trim + strip CRLF
    [ -z "$line" ] && continue

    name="$(basename "$line" .git)"
    echo ""
    echo "-------------------------------------------"
    echo ">>> $name"
    echo "-------------------------------------------"

    if git clone --depth 1 "$line" "$name"; then
        if [ -f "$name/requirements.txt" ]; then
            if pip install --no-cache-dir -r "$name/requirements.txt"; then
                OK+=("$name")
            else
                FAILED+=("$name  (requirements failed)")
            fi
        else
            OK+=("$name")
        fi

        if [ -f "$name/install.py" ]; then
            ( cd "$name" && python install.py ) || echo "!! $name install.py returned an error (continuing)"
        fi
    else
        FAILED+=("$name  (git clone failed)")
    fi
done < "$LIST"

echo ""
echo "==========================================="
echo "  NODE INSTALL SUMMARY"
echo "==========================================="
echo "Installed: ${#OK[@]}"
for n in "${OK[@]:-}"; do [ -n "$n" ] && echo "   OK   $n"; done

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo ""
    echo "  !!!! ${#FAILED[@]} NODE(S) FAILED !!!!"
    for n in "${FAILED[@]}"; do echo "   FAIL $n"; done
    echo ""
    echo "  The image still built. Comment those lines out in"
    echo "  nodes.txt if they keep failing."
fi
echo "==========================================="

# clean pip leftovers to keep the image smaller
rm -rf /root/.cache/pip || true
exit 0
