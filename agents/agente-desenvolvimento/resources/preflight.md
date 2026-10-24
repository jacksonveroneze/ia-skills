# Preflight

Executado no estado PREFLIGHT, antes do primeiro gate de passagem, para a execução nunca começar com pendência. Tudo é leitura, exceto a linha de base (P12), que roda os comandos do card. Item sem evidência conta como falha. Qualquer falha: evento `alguma verificação falhou` e BLOQUEADO, listando o que corrigir.

## Verificações

| # | Verificação | Como (evidência) | Falha quando |
|---|---|---|---|
| P1 | Repositório local é o do card | `git remote get-url origin` | difere do "Repositório" da spec |
| P2 | Branch atual é a base do card | `git branch --show-current` | difere da base da spec |
| P3 | Árvore limpa | `git status --porcelain` | há saída |
| P4 | Base atualizada | `git fetch origin <base>`; comparar `git rev-parse HEAD` e `origin/<base>` | HEAD atrás ou divergente |
| P5 | Sem trabalho em andamento | `estado.json` ausente ou do mesmo card; `git branch -a`; `gh pr list --state open` | outro card em andamento; branch ou PR do mesmo slug já existe |
| P6 | Ferramentas dos comandos do card | `command -v` do executável de build, teste e lint | algum ausente |
| P7 | Acesso ao GitHub com escrita | `gh auth status`; `gh repo view <repo> --json viewerPermission` | sem login ou permissão menor que WRITE |
| P8 | Referências existem | cada arquivo e linha de "Referência de implementação" e de `Siga:` | arquivo ou linha inexistente (spec desatualizada) |
| P9 | Arquivos do escopo | listar os caminhos de "Arquivos a criar ou alterar" | a alterar não existe; a criar já existe; diretório pai ausente |
| P10 | Dependências integradas no código | cada arquivo ou tipo que a spec diz vir de outra story | ausente na base |
| P11 | Dependência concluída no Trello | ler o card citado em `Depende de` | não concluída. Modo rígido: pergunta ao usuário e usa a resposta. Modo automático: falha |
| P12 | Linha de base verde | rodar os comandos do card na árvore limpa, um por vez | algum falha, ou a árvore fica suja depois |

As verificações de P1 a P11 são somente leitura e são a exceção listada à regra de comandos do card (CONV-013). Nenhuma delas altera arquivo, branch ou card.

## Relatório (formato fixo)
```
Preflight: ok | falhou
| # | Verificação | Estado | Evidência |
|---|---|---|---|
| P1 | Repositório local é o do card | ok ou falhou | <saída resumida> |
Pendências: <nenhuma | lista do que corrigir>
```

## Regras
- Falha na base (P12) não é culpa da story: pare antes de qualquer código.
- Não corrija nada por conta própria (nem `git pull`, nem trocar de branch). Informe o que o usuário deve fazer.
- Para incluir uma verificação, acrescente a linha aqui; o orquestrador a executa sem mudança no `AGENTS.md`.
