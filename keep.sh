#!/bin/bash
# keep.sh <source-dir-name> → delete every other source (and alert/ics.py if the survivor doesn't need it)
set -euo pipefail
cd "$(dirname "$0")"
keep=${1:?usage: keep.sh <source-dir-name>}
[[ -d sources/$keep ]] || { echo "no sources/$keep"; exit 1; }
for d in sources/*/; do
  d=${d%/}; [[ $d == "sources/$keep" ]] || rm -rf "$d"
done
[[ $keep == 07-* || $keep == 08-* ]] || rm -f alert/ics.py
[[ $keep == 07-* || $keep == 08-* ]] || rm -f tests/sample.ics
echo "kept sources/$keep. Now: ./install.sh $keep, trim README.md + config.env.example, commit."
