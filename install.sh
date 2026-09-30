#!/bin/bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(.codex .copilot .claude)
installed=()

install_dir() {
  local src="$1" d name t

  for d in "$src"/*/; do
    d="${d%/}"
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue

    for t in "${TARGETS[@]}"; do
      ln -sfn "$d" "$HOME/$t/skills/$name"
    done

    echo "  ✓ $name ($(basename "$src"))"
    installed+=("$name")
  done
}

echo "==> Instalando skills"

install_dir "$ROOT/net"
install_dir "$ROOT/meta-skills"

echo "==> Concluído: ${#installed[@]} skill(s) instalada(s) em ${TARGETS[*]}"