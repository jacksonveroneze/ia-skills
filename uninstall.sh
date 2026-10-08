#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(.codex .copilot .claude)
removed=0

echo "==> Removendo skills"

for t in "${TARGETS[@]}"; do
  dir="$HOME/$t/skills"
  if [ ! -d "$dir" ]; then
    echo "  . $t: sem pasta skills; ignorado"
    continue
  fi

  for l in "$dir"/*; do
    [ -L "$l" ] || continue                                  # só links
    case "$(readlink "$l")" in "$ROOT"/*) ;; *) continue ;; esac   # só os que apontam para este repositório

    rm "$l"
    echo "  - $(basename "$l") <- $t"
    removed=$((removed+1))
  done
done

if [ "$removed" -eq 0 ]; then
  echo "  nenhuma skill deste repositório estava instalada"
fi

echo "==> Removendo links das convenções"
"$ROOT/link-rules.sh" --remove

echo "==> Concluído: $removed link(s) removido(s)"