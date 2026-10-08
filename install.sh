#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(.codex .copilot .claude)
installed=()

install_dir() {
  local src="$1" d name t dest

  for t in "${TARGETS[@]}"; do
    [ -d "$HOME/$t" ] || continue
    [ -d "$HOME/$t/skills" ] || mkdir -p "$HOME/$t/skills"

    for d in "$src"/*/; do
      d="${d%/}"
      name="$(basename "$d")"
      [ -f "$d/SKILL.md" ] || continue

      dest="$HOME/$t/skills/$name"
      [ -L "$dest" ] && rm "$dest"
      if [ -e "$dest" ]; then
        echo "  ! $name ($t): já existe e não é link; ignorado"
        continue
      fi
      ln -sfn "$d" "$dest"

      echo "  - $name ($(basename "$src")) -> $t"
      installed+=("$name")
    done
  done
}

echo "==> Criando links das convenções"
"$ROOT/link-rules.sh"

echo "==> Instalando skills"

install_dir "$ROOT/net"
install_dir "$ROOT/meta-skills"

echo "==> Concluído: ${#installed[@]} link(s) criado(s)"

echo "==> Criando links das convenções"
"$ROOT/link-rules.sh"