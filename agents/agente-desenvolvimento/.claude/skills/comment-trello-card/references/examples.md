# Exemplos: comment-trello-card

Valores fictícios. Nunca copie literalmente.

## Preview correto
```
Card: [Story 2] Expor sumário na tool | Link: https://trello.com/c/AbCd1234
Duplicado: nenhum
Dados protegidos: nenhum encontrado

Texto do comentário:
PR aberto: https://github.com/acme/repo/pull/12. Implementado: validação de período e registro da tool. Pendente: nenhum.

Confirma a publicação deste comentário neste card?
```
Por que está certo: só leitura, texto exato, termina pedindo confirmação.

## Errado
- Publicar logo após o usuário dizer "o texto está bom". Comentário não é autorização.
- Publicar um texto diferente do mostrado no preview.
- Incluir um token ou e-mail de cliente no texto.

## Texto alterado depois do preview
O usuário pede para trocar uma frase após o preview.
- Correto: novo preview e nova confirmação.
- Errado: publicar a versão nova com a confirmação antiga.

## Duplicado
O card já tem um comentário idêntico.
- Correto: avisar e perguntar se publica mesmo assim.
- Errado: publicar de novo sem avisar.

## Falha ao publicar
- Correto: informar o erro e perguntar como proceder.
- Errado: tentar de novo em laço.

## Uso avulso, fora de qualquer fluxo
Pedido: "Comenta no card <link>: 'Revisão concluída'."
- Correto: Parte A, mostrar o preview e esperar a confirmação; só então publicar.
- Errado: publicar direto porque o pedido já dizia "comenta".

## Autorização prévia
Quem chama informa: "Autorização prévia: automação configurada, permite comentar neste card."
- Correto: fazer a Parte A, registrar a autorização citada e publicar sem esperar resposta.
- Errado: publicar sem autorização informada, ou inventar "autorizado por padrão".

## Pedido incompleto
Pedido: "Comenta no card." (sem link nem texto)
- Correto: perguntar o card e o texto. Não ler nem escrever.
- Errado: escolher o último card aberto.
