#!/usr/bin/env bash
# Downloads the 604 Madinah Mushaf (Hafs, KFQC layout) page SVGs into the app bundle.
# Run on a Mac with internet access, from the repository root:
#     bash scripts/fetch_mushaf_svgs.sh
# Pages already present and valid are skipped, so the script can be re-run safely.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/SARI/Resources/mushaf/hafs-kfqc"
BASE="https://raw.githubusercontent.com/quranpedia/quran-svg/main/mushafs/hafs/kfqc/svg"

mkdir -p "$DEST"
ok=0
fail=0

is_valid_svg() {
  local file="$1"
  [[ -s "$file" ]] && [[ $(wc -c < "$file") -gt 1000 ]] \
    && head -c 16384 "$file" | tr '[:upper:]' '[:lower:]' | grep -q "<svg" \
    && head -c 16384 "$file" | tr '[:upper:]' '[:lower:]' | grep -q "viewbox"
}

for page in $(seq 1 604); do
  name=$(printf "%03d" "$page")
  out="$DEST/$name.svg"
  if is_valid_svg "$out"; then
    ok=$((ok + 1))
    continue
  fi
  if curl -fsSL --retry 3 --max-time 60 "$BASE/$name.svg" -o "$out.tmp" && is_valid_svg "$out.tmp"; then
    mv "$out.tmp" "$out"
    ok=$((ok + 1))
  else
    rm -f "$out.tmp"
    echo "FAILED page $name" >&2
    fail=$((fail + 1))
  fi
done

echo "pages ok: $ok, failed: $fail"
[[ $fail -eq 0 ]]
