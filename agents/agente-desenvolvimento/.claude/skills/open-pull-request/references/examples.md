# Exemplos: open-pull-request

Valores fictícios. Nunca copie literalmente.

## Nome de branch e commit
Resumo: "Adiciona a tool de sumário de transações do cartão", tipo `feat`.
- Correto: branch `feat/summarize-card-transactions`; commit e título `feat(cards): add summarize_card_transactions tool`.
- Errado: branch `minha-branch`, `feat/Summarize_Card_Transactions_Tool_Final_v2`; commit `ajustes`.

## Preview correto
```
Repositório: acme/pagamentos | Base: main
Branch: feat/summarize-card-transactions
Commit: feat(cards): add summarize_card_transactions tool
Título do PR: feat(cards): add summarize_card_transactions tool

Arquivos (esperado -> alterado):
| Arquivo | Esperado | Alterado |
|---|---|---|
| src/Tools/SummarizeCardTransactionsTool.cs | sim | sim |
| src/Extensions/McpExtensions.cs | sim | sim |
Fora da lista: nenhum
Dados protegidos: nenhum encontrado

Descrição do PR:
## Contexto
Clientes não conseguiam ver o gasto do cartão somado por período.
## O que muda
- Nova tool summarize_card_transactions
- Registro da tool no servidor
## Como testar
dotnet build: sucesso (informado). Testes: não informados.
## Link de origem
https://trello.com/c/AbCd1234
## Checklist
- [ ] Validação de período
- [ ] Autorização por policy

Confirma a criação desta branch, deste commit e deste PR para main?
```
Por que está certo: só leitura, arquivos conferidos, termina pedindo confirmação explícita.

## Errado
- Criar a branch ou o commit na Parte A "para testar".
- Abrir o PR logo após o usuário dizer "o preview está bom". Comentário não é autorização.
- `git add .` e incluir um arquivo que não estava na lista.
- Escrever "Testes: todos passando" quando ninguém informou o resultado.
- Fazer push direto na `main`.

## Arquivo fora da lista
Alterados: os 2 esperados e `appsettings.Development.json`.
- Correto: parar, informar o arquivo extra e perguntar o que fazer. Não commitar.
- Errado: incluir o arquivo extra "porque também mudou".

## Branch já existe
`feat/summarize-card-transactions` já existe.
- Correto: avisar e perguntar (usar outro nome, ou parar).
- Errado: sobrescrever a branch.

## Falha no meio
Branch e commit criados; o push retornou erro.
- Correto: parar, informar `Criado: branch e commit`, `Não criado: push e PR`, o erro, e perguntar como proceder.
- Errado: recriar a branch ou fazer force-push.

## Uso avulso, fora de qualquer fluxo
Pedido: "Abre um PR com estas mudanças para a develop. Tipo fix: corrige timeout. Arquivo: src/Http/Client.cs."
- Correto: Parte A, preview e espera da confirmação; só então criar.
- Errado: criar direto porque o pedido já dizia "abre".

## Autorização prévia
Quem chama informa: "Autorização prévia: automação configurada, permite criar branch, commit e PR para main."
- Correto: fazer a Parte A, registrar no relatório a autorização citada e executar a Parte B sem esperar resposta.
- Errado: executar a Parte B sem que ninguém tenha informado a autorização, ou inventar "autorizado por padrão".

## Pedido incompleto
Pedido: "Sobe isso pro GitHub." (sem base, tipo ou arquivos)
- Correto: perguntar só o que falta, nessa ordem: base, tipo, resumo, arquivos.
- Errado: supor `main` e `feat` e commitar tudo.
