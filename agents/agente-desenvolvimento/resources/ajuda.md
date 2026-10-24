# Ajuda

Fonte da CONV-011. Mostre só a seção pedida (a da etapa atual; "como usar" mostra a Geral). Todo exemplo é fictício.

## Geral (como usar)
- Fluxo: Leitura e validação, Plano, Testes e código, Revisão, Entrega.
- Você informa só o link do card. A spec do card manda; o agente não deduz nada e valida tudo antes de começar.
- No modo rígido, cada etapa termina parada até você responder o gate. Gates: AVANÇAR, APROVAR PLANO (libera código), APROVAR PR (libera push, PR e comentário), COMENTAR (libera comentário de bloqueio).
- O processo está em `resources/fluxo.md`: estados, transições, gates e modo. Para tirar uma aprovação manual ou ligar a automação, edite esse arquivo.
- O progresso fica em `estado.json`; se a sessão cair, o agente retoma de onde parou.

## Etapa 1 - Leitura e validação
- Informe o link do card. A pasta atual deve ser o repositório do card.
- O agente confere o card (label `agent-ready`, spec completa) e depois o ambiente: repositório e branch certos, árvore limpa, base atualizada, ferramentas, acesso ao GitHub, arquivos citados pela spec, dependências e build/teste/lint passando antes de qualquer mudança.
- Qualquer falha: o agente lista o que corrigir e oferece comentar no card. Tudo certo: mostra o relatório e espera AVANÇAR.

EXEMPLO (fictício): "Implementa este card: https://trello.com/c/AbCd1234"

## Etapa 2 - Plano
- O agente lê a referência do card e propõe o plano: arquivos, testes, comandos e riscos.
- Nada é escrito até você responder APROVAR PLANO. Para mudar o plano, diga o que ajustar.

## Etapa 3 - Testes e código
- Testes saem dos critérios de aceite, antes do código. O agente mostra os testes e espera AVANÇAR antes de escrever o código.
- O código só toca os arquivos do card. Build, teste e lint rodam até 3 tentativas; depois disso o agente para e resume.
- Comandos passando: o agente mostra o resultado e espera AVANÇAR.

## Etapa 4 - Revisão
- Um revisor confere o diff com a spec (critérios, restrições, fora de escopo, segurança).
- Reprovado: o agente corrige e revisa de novo, até 2 ciclos.
- Aprovado: o agente mostra o parecer e espera AVANÇAR.

## Etapa 5 - Entrega
- O agente mostra o preview do PR e do comentário no card.
- Nada é enviado até você responder APROVAR PR. O PR vai para a branch base do card; o merge é seu.
