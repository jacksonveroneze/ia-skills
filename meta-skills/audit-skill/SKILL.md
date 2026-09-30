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

## Fluxo

1. **Localizar a skill alvo.** Leia o `SKILL.md` inteiro. Se não existir, pare e relate o caminho procurado.
2. **Extrair o contrato.** Do `SKILL.md` alvo, levante:
   - Rules/CONV citadas e o que cada uma exige.
   - Inputs e o que a skill diz resolver sozinha (ReAct/CoT).
   - Checklist, Harness e Anti-patterns.
   - **Lacunas**: decisões plausíveis que o texto não fixa (ex.: `Trim`, `ToString` mascarado, limite de tamanho). São as variáveis que você vigiará entre execuções.
3. **Montar os critérios** em quatro grupos. Cada item é marcado como `determinístico` (checável por comando/grep) ou `julgamento` (lido do transcript):
   - **Fluxo** — declarou valores resolvidos antes de escrever; checou duplicidade; não perguntou; não inventou contexto.
   - **Estrutura** — arquivo, pasta, namespace, modificadores, construtor, proibições (`!`, `=>`, etc.), conforme o contrato.
   - **Comportamento** — o que o artefato faz, conforme o contrato; nenhuma regra além das que a skill manda.
   - **Harness** — build sem warnings, format sem diff, testes verdes.

   Não inclua critério que o contrato da skill não sustenta. Se o usuário pediu um e o contrato não o cobre, marque como **"fora do contrato"** e reporte como lacuna da skill, não como falha do modelo.
4. **Preparar o estado.** Antes de cada execução, garanta o estado inicial pedido. Prefira isolamento por worktree (`isolation: "worktree"`) para as execuções não se contaminarem. Sem worktree, `git clean -fd && git checkout .` entre execuções.
5. **Executar N vezes.** Para cada execução, dispare um subagente em contexto limpo com as regras do executor acima.
   - O subagente **não recebe** os critérios nem este `SKILL.md`.
   - Em sequência se compartilharem pastas; em paralelo só com worktrees isoladas.
   - Sem subagente disponível, execute inline e registre no relatório o viés (o avaliador viu os critérios).
6. **Coletar evidências por execução:**
   - Transcript final do executor (declaração pré-escrita, resumo, decisões sem respaldo).
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
- Confiar no relato do executor sobre build/testes em vez de rodar.
- Aceitar execução única como prova de estabilidade.
- Corrigir a skill alvo durante a auditoria.
- Culpar o modelo quando o texto da skill permite duas leituras.
- Criar critério que o contrato da skill não sustenta e contá-lo como falha.
- Deixar o executor escrever os testes que o avaliarão: use testes de contrato fixos, fornecidos pelo caso.

## Arquivo de caso (opcional)

Se o caso vier de `tests/{skill}/case-NN.md`, o arquivo contém: tarefa, estado inicial, critérios e (opcional) testes de contrato a copiar para o projeto de testes **após** a execução. Sem arquivo de caso, use os critérios derivados no passo 3 e sugira salvá-los como `case-01.md` no relatório.