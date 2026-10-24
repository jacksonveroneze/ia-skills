# Relatório: open-pull-request

Formato fixo, por parte.

## Parte A - Preview
```
Repositório: <org/repo>
Base: <branch base>
Branch: <tipo>/<slug>
Commit: <tipo>(<escopo>): <descrição>
Título do PR: <tipo>(<escopo>): <descrição>

Arquivos (esperado -> alterado):
| Arquivo | Esperado | Alterado |
|---|---|---|
| <caminho> | sim | sim |
Fora da lista: <nenhum | arquivos>
Dados protegidos: <nenhum encontrado | arquivo>

Descrição do PR:
## Contexto
<por que>
## O que muda
<lista curta>
## Como testar
<comandos e resultado informados | não informados>
## Link de origem
<link | não informado>
## Checklist
- [ ] <critério ou item informado>

Confirma a criação desta branch, deste commit e deste PR para <base>?
```

## Parte B - Relatório final
```
Branch criada: <nome>
Commit: <hash curto> - <mensagem>
PR: <link> (base: <base>)
Conferência: <base correta e arquivos iguais aos esperados | divergência: ...>
```

## Em caso de falha
```
Criado: <lista>
Não criado: <lista>
Erro: <mensagem>
Como proceder? (não refaço o que já existe)
```
