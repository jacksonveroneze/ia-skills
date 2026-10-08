# link-rules.sh — gerencia net/<skill>/references/dotnet-conventions.md
#
# Uso:
#   ./link-rules.sh            cria o link em toda skill de net/ (padrão)
#   ./link-rules.sh <qualquer> remove os links criados (qualquer parâmetro ativa a remoção,
#                              ex.: ./link-rules.sh --remove)
#
# Só remove symlinks; arquivo real em references/ nunca é apagado.
# Apaga references/ apenas se ficar vazia.

#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/net"

if [ $# -eq 0 ]; then
  [ -f rules/dotnet-conventions.md ] || { echo "✗ rules/dotnet-conventions.md não encontrado"; exit 1; }
fi

for skill in */; do
  skill="${skill%/}"
  [ -f "$skill/SKILL.md" ] || continue
  link="$skill/references/dotnet-conventions.md"

  if [ $# -eq 0 ]; then
    mkdir -p "$skill/references"
    ln -sfn ../../rules/dotnet-conventions.md "$link"
    echo "  ✓ $skill: link criado"
  else
    if [ -L "$link" ]; then
      rm "$link"
      rmdir "$skill/references" 2>/dev/null || true
      echo "  - $skill: link removido"
    fi
  fi
done