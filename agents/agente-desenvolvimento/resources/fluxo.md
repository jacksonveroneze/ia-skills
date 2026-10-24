# Fluxo (máquina de estados)

Fonte única de estados, transições e gates. O orquestrador executa o que está aqui. Para mudar o processo (incluir, remover ou reordenar estados, trocar um gate), edite este arquivo; o `AGENTS.md` não muda.

## Modo

modo: rígido

Valores: `rígido` ou `automático`. A coluna de gate usada é a do modo. O modo é gravado em `estado.json` no início da execução e não muda no meio dela. O modo `automático` só deve ser ligado depois de rodar `evals/casos.md`.

## Gates

| Valor | Significado |
|---|---|
| `usuário:<PALAVRA>` | Para e espera a palavra exata. Palavras: AVANÇAR, APROVAR PLANO, APROVAR PR, COMENTAR |
| `auto` | Segue sem esperar, mostra o resultado do estado e grava a transição |

Guardas (coluna Condição) não são gates: valem em todos os modos e não se desligam por este arquivo. São os limites de tentativa, o escopo de escrita, o preflight e as regras de git das convenções.

## Estados

| Estado | Etapa | Nome da etapa | Ação do estado (gera o evento) |
|---|---|---|---|
| LEITURA | 1 | Leitura e validação | `read-trello-card`; conferir elegibilidade |
| PREFLIGHT | 1 | Leitura e validação | verificações de `resources/preflight.md` |
| PLANO | 2 | Plano | `code-explorer`; montar o plano |
| TESTES | 3 | Testes e código | `test-writer` (pula se o card diz sem testes) |
| CODIGO | 3 | Testes e código | `dotnet-implementer`; rodar os comandos do card |
| REVISAO | 4 | Revisão | `reviewer` |
| ENTREGA | 5 | Entrega | Parte A de `open-pull-request` e de `comment-trello-card` |
| BLOQUEADO | etapa em que parou | Bloqueado | resumir o motivo e oferecer comentário no card |
| CONCLUIDO | 5 | Concluído | encerrar |

## Transições

| # | De | Evento | Para | Condição | Ação ao disparar | Gate rígido | Gate automático |
|---|---|---|---|---|---|---|---|
| T1 | (início) | link do card informado | LEITURA | | | auto | auto |
| T2 | LEITURA | card elegível | PREFLIGHT | elegível | | auto | auto |
| T3 | LEITURA | card não elegível | BLOQUEADO | | | auto | auto |
| T4 | PREFLIGHT | todas as verificações ok | PLANO | nenhuma pendência | | usuário:AVANÇAR | auto |
| T5 | PREFLIGHT | alguma verificação falhou | BLOQUEADO | | | auto | auto |
| T6 | PLANO | plano montado | TESTES | | | usuário:APROVAR PLANO | auto |
| T7 | TESTES | testes escritos, ou card sem testes | CODIGO | | | usuário:AVANÇAR | auto |
| T8 | CODIGO | comandos passam | REVISAO | | | usuário:AVANÇAR | auto |
| T9 | CODIGO | comandos falham | CODIGO | `tentativas < 3` | soma 1 em `tentativas` | auto | auto |
| T10 | CODIGO | comandos falham | BLOQUEADO | `tentativas = 3` | | auto | auto |
| T11 | REVISAO | APROVADO | ENTREGA | | | usuário:AVANÇAR | auto |
| T12 | REVISAO | REPROVADO | CODIGO | `ciclos < 2` | soma 1 em `ciclos`; zera `tentativas` | auto | auto |
| T13 | REVISAO | REPROVADO | BLOQUEADO | `ciclos = 2` | | auto | auto |
| T14 | ENTREGA | previews prontos | CONCLUIDO | | Parte B de `open-pull-request`; depois Parte B de `comment-trello-card` | usuário:APROVAR PR | auto |
| T15 | BLOQUEADO | comentário sobre o bloqueio | CONCLUIDO | | `comment-trello-card` | usuário:COMENTAR | auto |

## Como o orquestrador usa esta tabela
1. Execute a ação do estado atual e determine o evento.
2. Ache a transição com `De`, `Evento` e `Condição` que casam.
3. Mostre o resultado do estado. Gate `usuário`: grave `aguardando` em `estado.json` e pare. Gate `auto`: siga.
4. Ao disparar, execute a ação da transição, atualize `estado.json` e entre no estado `Para`.
5. Estado ou transição inexistente neste arquivo: pare e pergunte.

## Como alterar
- **Remover uma aprovação manual:** troque o gate da linha por `auto` na coluna do modo desejado.
- **Ligar a automação:** troque `modo: rígido` por `modo: automático` (e ajuste a coluna automática, se quiser manter alguma parada).
- **Incluir um estado:** adicione a linha em Estados e as transições de entrada e saída.
- **Autorização das skills de escrita:** com gate `auto`, o orquestrador informa às skills `open-pull-request` e `comment-trello-card` a autorização prévia (modo e transição) no lugar da resposta do usuário.
