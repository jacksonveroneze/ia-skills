---
name: create-rule
description: 'Cria, edita e otimiza as RULES invariantes deste projeto no catálogo dotnet-conventions (entradas CONV) — restrições que valem SEMPRE e são majoritariamente negativas (fronteiras de camada, bibliotecas proibidas, seams obrigatórios, proibições de acoplamento). Uma rule ocupa contexto de forma permanente, então é curta e verificável. Use SEMPRE que uma correção for uma invariante transversal (nunca isto, toda classe X deve aquilo), ao migrar um finding ou incidente para restrição explícita, ou quando create-skill indicar que o caso é rule e não skill.'
---

# Meta-skill: criação de Rules

Uma **rule** codifica **conhecimento negativo**: o que um artefato deste projeto está
proibido de fazer. Esse conhecimento é o que mais importa e o que o agente menos consegue
inferir sozinho — porque **o que um artefato foi proibido de fazer não deixa rastro no
código.** Ausência não produz evidência. RAG, busca semântica e janela gigante resolvem a
metade positiva (induzível do código) e não encostam nesta.

Por isso a rule precisa ser **declarada por quem tomou a decisão**. O agente não pergunta —
ele completa. A rule é o que o impede de completar errado.

Neste projeto o catálogo de rules é o **`dotnet-conventions`**; cada rule é uma entrada
`CONV-NNN`. Esta meta-skill **estende esse catálogo**, não cria um formato paralelo.

## Rule ou Skill? Confirme antes de escrever

| Sinal | Artefato |
|---|---|
| "Nunca…" / "Toda classe X deve…" — invariante, vale sempre | **Rule** (aqui → `CONV-NNN`) |
| "Para montar Y…" — procedimento sob demanda | **Skill** (`create-skill`) |

Uma rule é curta e majoritariamente negativa porque **está sempre no contexto**. Se o que
você quer escrever precisa de mais de ~2 linhas de procedimento, é skill. Se depende de
leitura humana para ser verificada, provavelmente é skill.

Nota: o `dotnet-conventions` também tem entradas de **padronização** (escolhas entre opções
válidas, por consistência — ex.: sufixo `Request`/`Response`, Mapster em vez de AutoMapper).
Essas já existem no catálogo-base. Esta meta-skill trata do que dá mais trabalho: as
**invariantes/cicatrizes** que o agente não seguiria sozinho.

## Onde a rule entra
Uma entrada `CONV-NNN` na seção adequada do `dotnet-conventions` (§ por camada/tema). ID novo
recebe o próximo número livre; IDs existentes nunca mudam. Regra mecânica (enforçável por
ferramenta) referencia o §16 e mora no `.editorconfig`/analyzers/`BannedSymbols.txt`, não na
prosa.

## Como escrever a entrada CONV
Uma entrada bem formada carrega, em uma linha enxuta:

1. **Estado afirmativo** no texto (`DEVE …`) e a **proibição concreta** (`NÃO DEVE …`).
2. **Alternativa correta no mesmo item** — nunca proibição órfã.
3. **Escopo** implícito pela § (ou explícito quando o escopo é um path específico).
4. **Verificação** — o nível mais forte disponível (ver abaixo).
5. **Origem** — sufixo `(origem: …)` **apenas** para regras que são cicatriz de
   incidente/finding. Padronização de base não precisa.

### Verificação — o que separa restrição de sugestão
Rule que depende de o agente *lembrar de ler* é comentário. Escolha o nível mais forte:

1. **Analyzer Roslyn / `BannedSymbols.txt` / teste de arquitetura** (NetArchTest ou
   ArchUnitNET) → quebra o build antes do review e vale também para os humanos. **Prefira.**
   Registre em §16.
2. **Teste automatizado** direcionado que falha se o guardrail for violado.
3. **Leitura humana** → sinal de alerta: se só dá para verificar lendo, provavelmente
   **deveria ser skill**, não rule. Reconsidere.

Se o mecanismo ainda não existe, registre a pendência no próprio item
(`verificação: TODO — NetArchTest em tests/Architecture/…`) para não mascarar uma rule
não-verificada como verificada.

### Origem — o que impede o catálogo de apodrecer
Daqui a oito meses alguém proporá remover uma regra que "não faz sentido". O link para o
incidente responde antes da discussão. Boa parte das proibições de um harness maduro é a
cicatriz de um incidente que custou dinheiro ou madrugada. Sem `origem`, a rule vira
folclore e some na primeira limpeza.

## Regras de conteúdo
**Toda negativa vem com a alternativa no mesmo item.** `NÃO DEVE` sem o `DEVE` correto faz o
modelo cair na segunda opção mais provável — normalmente tão ruim quanto a primeira.

**Uma rule por invariante.** Não empacote três proibições num CONV só — cada uma tem escopo,
verificação e origem próprios, e ID próprio.

**Título/estado afirmativo, cláusula negativa.** O texto diz o estado correto do mundo; o
`NÃO DEVE` diz o que viola.

## Exemplo de entrada bem formada (few-shot)

Cicatriz de incidente virando CONV (seção nova de agentes, quando a camada for formalizada):
```markdown
## §17 — Agentes e guardrails
- **CONV-085** Um guardrail de agente DEVE cobrir os dois transportes: implementar ambos os
  overloads e registrar com `.Use(runFunc: g.HandleAsync, runStreamingFunc: g.HandleAsync)`,
  com a rejeição num único `TryPass()` compartilhado. NÃO DEVE registrar só `runStreamingFunc`
  — o path HTTP `RunAsync` bypassa a checagem em silêncio.
  (verificação: teste de arquitetura em tests/Architecture/GuardrailCoverageTests.cs;
  origem: finding dual-transport AG-UI usa RunStreamingAsync, HTTP usa RunAsync)
```
Repare: estado afirmativo, proibição concreta, alternativa no mesmo item, verificação
automatizada e origem rastreável. Quem ler só o `NÃO DEVE` já sabe o que evitar; o CI garante
que não passa nem por esquecimento.

## Sementes prontas neste projeto
Findings já documentados (learnings) que devem virar CONV com `origem` preenchida — não
esperar o sintoma reaparecer, ele já ocorreu. Pertencem à **camada de agentes/MCP** do
projeto; ao formalizá-la, abrir a(s) seção(ões) correspondente(s) no `dotnet-conventions`:

- Camada Agent **não** conhece provider/OAuth/hosting.
- Saída do LLM é **input não confiável** → validada contra schema na camada MCP.
- Controle de side-effect de tool vai em `DelegatingAIFunction.InvokeCoreAsync`, **nunca** em
  output-stream middleware (a tool já executou quando o update chega).
- **Nunca** desabilitar validação TLS fora de teste isolado (MITM no canal que carrega bearer
  + dado bancário).
- Segredos OAuth **nunca** no repositório → user-secrets/KeyVault. (já coberto por CONV-055;
  especializar se necessário).

## Pré-condição: contexto íntegro
Como em `create-skill`: **não gere rule a partir de contexto compactado.** A rule nasce da
correção exata que funcionou; a compactação apaga isso. Se compactou, adie.

## O que esta meta-skill NÃO faz
- **Não** cria CONV positiva óbvia que o agente já seguiria sozinho.
- **Não** aceita CONV sem a alternativa correta (negativa órfã).
- **Não** aceita CONV sem verificação real — no máximo com a pendência declarada.
- **Não** aceita cicatriz sem `origem`.
- **Não** empacota múltiplas invariantes num CONV só.
- **Não** transforma procedimento em rule — isso é `create-skill`.
- **Não** escreve rule de contexto compactado.

## Cuidado: rule errada escala o erro
Sem harness, o agente erra de formas variadas e a variedade chama atenção. **Com** uma rule
errada, ele erra de forma consistente: quarenta PRs errados do mesmo jeito, com justificativa
articulada citando a regra. Erro sistemático é barato de corrigir na origem e difícil de
enxergar no review. Rule é código — passa por review, tem dono, e é revista quando a
arquitetura muda.