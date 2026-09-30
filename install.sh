#!/bin/bash

echo "==> Instalando skills"

installed=()

for d in "$HOME"/workspace/ia-skills/net/*/; do
  d="${d%/}"
  name="$(basename "$d")"
  [ -f "$d/SKILL.md" ] || continue

  #mkdir -p "$HOME/.codex/skills" "$HOME/.copilot/skills"
  ln -sfn "$d" "$HOME/.codex/skills/$name"
  ln -sfn "$d" "$HOME/.copilot/skills/$name"

  echo "  ✓ $name"
  installed+=("$name")
done

echo "==> Concluído: ${#installed[@]} skill(s) instalada(s) em Codex e Copilot"