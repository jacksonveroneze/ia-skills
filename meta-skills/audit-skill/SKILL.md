---
name: audit-skill
description: 'Audita outra skill: executa a skill indicada de forma padronizada (sem perguntas, sem sair do escopo), N vezes em contexto limpo, e emite um relatório com critérios passou/falhou, classificação de cada falha e variação entre execuções. Use quando o usuário pedir para testar, auditar, avaliar ou validar uma skill (ex. "audite a create-value-object", "teste a skill X"). Não use para criar ou editar skills (skill-creator) nem para executar a skill em produção.'
---

# Auditar uma skill

Esta skill é o **avaliador**. Ela não gera o artefato da skill auditada: delega a um **executor** isolado e depois mede o resultado contra critérios que o executor nunca viu.

Princípio: o prompt do teste **não dita** o que a skill deve decidir (caminho, nome do tipo, namespace, códigos de erro, tipo de retorno). Se ditasse, o teste mediria obediência ao prompt, não a skill.

## Inputs

1. **Skill alvo** — nome da skill a auditar (obrigatório).
2. **Tarefa** — o pedido em linguagem natural que seria dado à skill (obrigatório). Ex.: "Crie um value object para representar o nome. Input: name: string | required".
3. **Critérios** — caminho de um arquivo de caso (`tests/{skill}/case-NN.md`) ou lista inline. Se ausente, derive-os do `SKILL.md` alvo (Passo 3) e **mostre-os no relatório**.
4. **N** — número de execuções. Padrão: 3.
5. **Estado inicial** — `limpo` (padrão) ou descrição de um cenário (ex.: "`ValueObjects/Name.cs` já existe").

Faltando Skill alvo ou Tarefa: pare e relate o que faltou. Não pergunte nada.

## Regras do executor (injetadas em TODA execução, literalmente)

```
Use a skill {skill}. {tarefa}

Regras:
- Invoque a skill pela ferramenta Skill, como faria normalmente. Não leia
  o SKILL.md dela com Read, cat ou similar.
- Não pergunte nada. Se faltar informação que a skill não resolve sozinha,
  pare e relate o que era esperado e onde.
- Não crie nem altere nada fora do escopo da skill.
- Antes de escrever o arquivo, declare: nome do tipo, namespace, caminho
  e se o arquivo já existe.

Ao final, informe: valores resolvidos, arquivos criados ou reaproveitados,
o resultado do harness da skill (build, format, testes) e cada decisão
que você tomou sem respaldo explícito na skill (ex.: normalizações,
sobrescritas, limites, validações extras).
```

Adapte só o trecho "declare: ..." ao que a skill alvo resolve (ex.: para `create-entity`, acrescente "agregado e campos de identidade"). Nunca acrescente dica de como resolver.

### Como a skill alvo é invocada

O executor **invoca a skill alvo pela ferramenta `Skill`**, exatamente como o Claude Code faria numa sessão real. Isso testa também o que o arquivo não mostra: se a `description` dispara a skill e se o conteúdo carregado pelo mecanismo de skills basta para a execução.

- O avaliador **nunca** cola o conteúdo do `SKILL.md` alvo no prompt do executor, nem indica o caminho do arquivo.
- O executor **não** lê o `SKILL.md` alvo com `Read`/`cat`. A leitura do arquivo é tarefa só do avaliador, para extrair o contrato (Passo 2).
- Se a skill alvo não aparecer na lista de skills disponíveis do executor, ou se a chamada `Skill` falhar, a auditoria **para e relata** (skill não instalada, nome errado ou sem permissão). Não há fallback para ler o arquivo: isso mascararia justamente o problema de descoberta/carregamento da skill.
- O subagente precisa ter a ferramenta `Skill` (use um tipo com todas as ferramentas, como `general-purpose`).

## Fluxo

1. **Localizar a skill alvo.** Confirme que ela consta nas skills disponíveis e leia o `SKILL.md` inteiro **só para o avaliador** (extrair contrato e critérios). Se não existir ou não estiver instalada, pare e relate o que procurou e onde.
2. **Extrair o contrato.** Do `SKILL.md` alvo, levante:
   - Rules/CONV citadas e o que cada uma exige.
   - Inputs e o que a skill diz resolver sozinha (ReAct/CoT).
   - Checklist, Harness e Anti-patterns.
   - **Lacunas**: decisões plausíveis que o texto não fixa (ex.: `Trim`, `ToString` mascarado, limite de tamanho). São as variáveis que você vigiará entre execuções.
3. **Montar os critérios** em quatro grupos. Cada item é marcado como `determinístico` (checável por comando/grep) ou `julgamento` (lido do transcript):
   - **Fluxo** — invocou a skill pela ferramenta `Skill` (sem ler o `SKILL.md` dela); declarou valores resolvidos antes de escrever; checou duplicidade; não perguntou; não inventou contexto.
   - **Estrutura** — arquivo, pasta, namespace, modificadores, construtor, proibições (`!`, `=>`, etc.), conforme o contrato.
   - **Comportamento** — o que o artefato faz, conforme o contrato; nenhuma regra além das que a skill manda.
   - **Harness** — build sem warnings, format sem diff, testes verdes.

   Não inclua critério que o contrato da skill não sustenta. Se o usuário pediu um e o contrato não o cobre, marque como **"fora do contrato"** e reporte como lacuna da skill, não como falha do modelo.
4. **Preparar o estado.** Antes de cada execução, garanta o estado inicial pedido. Prefira isolamento por worktree (`isolation: "worktree"`) para as execuções não se contaminarem. Sem worktree, `git clean -fd && git checkout .` entre execuções.
5. **Executar N vezes.** Para cada execução, dispare um subagente em contexto limpo com as regras do executor acima.
   - O subagente **não recebe** os critérios, este `SKILL.md`, o conteúdo nem o caminho do `SKILL.md` alvo. Ele só recebe o prompt do executor e invoca a skill pela ferramenta `Skill`.
   - Em sequência se compartilharem pastas; em paralelo só com worktrees isoladas.
   - Sem subagente disponível, execute inline, também invocando a skill pela ferramenta `Skill`, e registre no relatório o viés (o avaliador viu os critérios e o `SKILL.md`).
6. **Coletar evidências por execução:**
   - Transcript final do executor (declaração pré-escrita, resumo, decisões sem respaldo).
   - Chamadas de ferramenta do executor: existe chamada `Skill` com o nome da skill alvo e **não** existe `Read`/`cat` do `SKILL.md` dela. Se a skill não disparou pela `Skill`, registre como falha de Fluxo (origem provável: `description` da skill ambígua ou fraca).
   - `git status --porcelain` e diff: arquivos criados/alterados.
   - Saída de `dotnet build`, `dotnet format --verify-no-changes` e testes, **rodados pelo avaliador**, sem confiar no relato do executor.
7. **Checagens determinísticas.** Rode `grep`/scripts para o que for mecânico (modificadores, `!`, `=>`, padrão de código de erro por regex, número de arquivos novos, caminho exato). Registre o comando e o resultado.
8. **Checagens por julgamento.** Leia o transcript: declarou antes de escrever? Verificou duplicidade? Perguntou algo? Inventou contexto? Cite o trecho que sustenta cada veredito (uma linha).
9. **Classificar cada falha** em exatamente uma origem:
   - **Skill ambígua ou incompleta** — o texto permite mais de uma leitura ou não cobre o caso. *Pede ajuste de arquivo.*
   - **Regra ausente ou errada nas conventions** — o CONV não existe, conflita ou está desatualizado. *Pede ajuste de arquivo.*
   - **Erro do modelo** — a instrução era clara e foi ignorada. *Não pede ajuste; se recorrer, reavalie a clareza.*
   - **Ambiente/fixture** — build quebrado por motivo alheio à skill.
10. **Comparar execuções.** Para cada critério e cada lacuna do passo 2, compare as N execuções. Decisão que varia (ex.: `Trim` numa, não em outra) = **decisão solta na skill**, mesmo que todas passem.
11. **Emitir o relatório** (formato abaixo). Não altere a skill alvo: proponha o ajuste, não aplique.

## Formato do relatório

```
# Auditoria: {skill} — {data}
Tarefa: {tarefa}   Estado inicial: {estado}   N: {N}   Executor: {subagente|inline}

## Veredito
{APROVADA | APROVADA COM RESSALVAS | REPROVADA} — {uma frase}

## Valores resolvidos (por execução)
| Item | Exec 1 | Exec 2 | Exec 3 |
|---|---|---|---|
| Tipo | | | |
| Namespace | | | |
| Caminho | | | |
| Arquivo já existia? | | | |

## Critérios
| Grupo | Critério | Tipo | Exec 1 | Exec 2 | Exec 3 |
|---|---|---|---|---|---|
(✅ passou / ❌ falhou / ➖ fora do contrato)

## Falhas
| # | Critério | Exec | Origem | Evidência | Ajuste proposto |
|---|---|---|---|---|---|

## Decisões sem respaldo na skill
| Decisão | Exec 1 | Exec 2 | Exec 3 | Estável? |
|---|---|---|---|---|

## Lacunas da skill (decisões soltas)
- {lacuna}: {como variou} → {texto sugerido para a skill}

## Harness
| Execução | build | format | testes |
|---|---|---|---|

## Ajustes recomendados
1. {arquivo}: {mudança}  (origem: skill | conventions)
```

Veredito:
- **APROVADA** — todos os critérios passam em todas as execuções e nenhuma lacuna varia.
- **APROVADA COM RESSALVAS** — critérios passam, mas há decisão solta ou item fora do contrato.
- **REPROVADA** — qualquer falha de origem *skill* ou *conventions*, ou falha em ≥1 execução de critério de Estrutura/Harness.

## Cenários de borda (rode quando o usuário pedir bateria completa)

- **Artefato já existe** — esperado: parar e relatar, sem sobrescrever.
- **Input incompleto** — esperado: parar e relatar o que faltou e onde, sem perguntar e sem inventar.
- **Pedido fora do escopo da skill** (ex.: entidade pedida a uma skill de VO) — esperado: recusar e apontar a skill correta.

## Anti-patterns (recusar)

- Passar critérios, caminho, nome do tipo ou códigos de erro ao executor.
- Colar o conteúdo do `SKILL.md` alvo no prompt do executor, ou mandá-lo ler o arquivo, em vez de invocar a skill pela ferramenta `Skill`.
- Cair em fallback silencioso (ler o arquivo) quando a chamada `Skill` falha: pare e relate.
- Confiar no relato do executor sobre build/testes em vez de rodar.
- Aceitar execução única como prova de estabilidade.
- Corrigir a skill alvo durante a auditoria.
- Culpar o modelo quando o texto da skill permite duas leituras.
- Criar critério que o contrato da skill não sustenta e contá-lo como falha.
- Deixar o executor escrever os testes que o avaliarão: use testes de contrato fixos, fornecidos pelo caso.

## Arquivo de caso (opcional)

Se o caso vier de `tests/{skill}/case-NN.md`, o arquivo contém: tarefa, estado inicial, critérios e (opcional) testes de contrato a copiar para o projeto de testes **após** a execução. Sem arquivo de caso, use os critérios derivados no passo 3 e sugira salvá-los como `case-01.md` no relatório.