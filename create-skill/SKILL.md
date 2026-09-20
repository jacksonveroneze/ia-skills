---
name: create-skill
description: 'Cria, edita e otimiza as SKILLS de estereótipo deste projeto — value-object, entity, repository, use-case de leitura e de escrita, mapper, validator, endpoint, persistence-config, register-dependencies e afins. Uma skill descreve COMO montar um estereótipo conforme a dotnet-conventions, carregada sob demanda. Use SEMPRE que o usuário pedir para criar uma skill, documentar como fazer um artefato, ou transformar uma correção recorrente em procedimento reutilizável; e quando estiver em dúvida entre skill e rule (este arquivo traz o critério de decisão).'
---

# Meta-skill: criação de Skills

Uma **skill** captura a distância entre o que um code agent produz por padrão e o que
**este projeto** exige, para um estereótipo específico. Ela não ensina boas práticas
genéricas — ensina a fazer *igual ao resto da base*, segundo a `dotnet-conventions`.

O teste que decide se uma skill deve existir é único:

> **O agente teria produzido isso sem a skill?**
> Se sim, a skill não deve existir. Está ocupando contexto sem cobrir distância nenhuma.

Skills públicas nascem de material público — a mesma origem da massa de treinamento. A
distância que cobrem tende a zero. **Não baixe skills prontas de arquitetura.** O
conteúdo específico sai do nosso próprio código, das correções e da `dotnet-conventions`.

## Skill ou Rule? Decida antes de escrever

Declare a decisão no início do trabalho (chain of thought):

| Sinal | Artefato | Onde |
|---|---|---|
| "Para montar Y…" — procedimento de um estereótipo | **Skill** | Este arquivo |
| "Nunca…" / "Toda classe X deve…" — invariante transversal | **Rule** | `create-rule` → entrada `CONV-NNN` na `dotnet-conventions` |

- **Skill** custa contexto **apenas quando dispara** → pode ser longa e detalhada.
- **Rule** ocupa contexto **de forma permanente** → curta e negativa (`dotnet-conventions`).
- Invariante transformada em skill **nunca carrega no momento em que importa**.
- Procedimento transformado em rule **consome contexto antes da primeira linha**.

Se o pedido for uma invariante, **pare aqui** e vá para `create-rule`.

## Pré-condição inegociável: contexto íntegro

**Não gere skill a partir de contexto compactado.** A skill nasce das tentativas erradas,
das correções intermediárias e da redação exata que funcionou — material que a
compactação destrói, deixando só o resumo do que deu certo.

- Se a sessão foi compactada: **não crie a skill agora.** Registre que ficou pendente.
- Se a tarefa não coube num contexto: o problema é a tarefa. Quebre-a antes.

## Processo (ReAct: observar → decidir → escrever → verificar)

### 1. Observar a correção
Reúna, da sessão atual: o que o agente produziu por padrão (❌), o que a arquitetura
exigia (✅) e **por quê** — qual estereótipo/CONV ele ignorou ou reinventou. O erro quase
sempre tem direção fixa: **excesso**. O agente anexa responsabilidades que a arquitetura
já absorve noutro lugar (transporte, persistência, mapeamento, erro). Nomeie as anexações.

### 2. Confirmar que é skill, não rule
Reaplique a tabela. Em dúvida, prefira rule para invariantes de fronteira e skill para
"como montar o artefato".

### 3. Escrever a SKILL.md
Preencha a estrutura obrigatória (abaixo). Corpo imperativo. Explique o **porquê** de cada
restrição citando o CONV — o modelo adere mais a uma restrição que entende do que a um
"MUST" sem motivo.

### 4. Verificar contra a régua
Antes de dar por pronta, valide o output que a skill produziria pelas 6 dimensões,
ancoradas na `dotnet-conventions`:

| Dimensão | Pergunta (CONV) |
|---|---|
| Estereótipo | Usou o artefato e o naming do projeto (`{Operation}UseCase`/`Request`/`Response`, VO com factory `Result`) ou criou um paralelo? (CONV-016/017/023/025) |
| Dependências | Respeitou a regra de dependência e as portas? Zero infra concreta na Application. (CONV-005..008/030/072) |
| Erro/fluxo | `Result` tipado em vez de exceção; erro da taxonomia; nada de `null` para erro. (CONV-019/021/069) |
| Tempo/async | `CancellationToken` ponta a ponta e nomeado; `TimeProvider`; sem sync-over-async. (CONV-044/074/060/045) |
| Observabilidade/segurança | `ILogger<T>` estruturado; sem PII/CPF; sem vazar interno. (CONV-062/054/057) |
| Configuração | CPM; props no `Directory.Build.props`; binding tipado. (CONV-058/001) |

## Estrutura obrigatória da skill gerada — ordem canônica

Cinco princípios fixam a ordem: **contrato antes de exemplo**; **correto antes de errado**;
**recência para o gate** (checklist/harness por último); **ReAct externo, CoT interno**;
**progressive disclosure** (referência pesada em `references/`, não no corpo).

Ordem fixa das seções do corpo (não reordenar):
```
## O que gera
## Escopo (quando usar / NÃO usar)
## Contrato
### Rules enforçadas (CONV)
### Pré-condições
### Inputs
## Fluxo (ReAct)
## Raciocínio antes de escrever (CoT)
## Template canônico
## Exemplos (few-shot ❌/✅)
## Anti-patterns (recusar)
## Checklist + Harness
```
Onde cada técnica cai: CoT → *Raciocínio*; few-shot → *Exemplos*; ReAct → *Fluxo*;
o-que/como-não-fazer → *Anti-patterns* + a metade `❌` dos *Exemplos*; verificação →
*Checklist* (manual, mapeado a CONV) **e** *Harness* (gate automatizado — build/test/analyzer
que **prova** a conformidade; a skill só conclui quando passa).

### frontmatter
- **name**: kebab-case, igual ao nome da pasta.
- **description**: é o **gatilho**, não documentação. Diga **o quê + quando**, não o *como*
  interno. Mantenha os traços que **discriminam o disparo** (ex.: "de domínio", "com
  identidade", "sem identidade"), os sinônimos do estereótipo e o "quando NÃO usar"
  apontando a skill irmã. Corte detalhe de implementação (`sealed`, `Result`, setter
  privado) — não muda quando dispara. Restrições do empacotador: a `description` **não pode
  conter `:` nem `<` `>`** (use "retornando Result", não `Result<T>`).

### Corpo — regras de conteúdo
**Toda negativa vem com a alternativa no mesmo bloco.** Proibição isolada faz o modelo cair
na segunda opção mais provável — normalmente tão ruim quanto a primeira. Nunca "não faça X"
sem, ao lado, "faça Y assim".

**Declare a ausência.** A responsabilidade de um artefato se define pela preocupação que ele
**recusa** porque a arquitetura já a absorve. Liste o que o estereótipo **não** faz e qual
camada/porta assume o trabalho.

**O par ❌/✅ é o few-shot.** Mostre o código que sai sem contexto e o que sai com a
`dotnet-conventions`, lado a lado, com a diferença anotada e o CONV citado. É o mecanismo de
aprendizado mais forte da skill.

## Exemplo de skill bem formada (few-shot)

Trecho do estereótipo *use-case de leitura*:

❌ Sem contexto — anexou infra e lançou exceção para fluxo:
```csharp
public sealed class GetAccountByIdUseCase(AppDbContext db)     // depende de infra concreta
{
    public async Task<GetAccountByIdResponse> HandleAsync(Guid id)
    {
        var account = await db.Accounts.FindAsync(id)           // EF na Application
            ?? throw new KeyNotFoundException();                // exceção para fluxo esperado
        return new GetAccountByIdResponse(account.Id, account.Balance.Amount);
    }
}
```
✅ Com contexto — depende da porta, retorna `Result`, ignora transporte:
```csharp
public sealed class GetAccountByIdUseCase(IAccountRepository accounts)
{
    public async Task<Result<GetAccountByIdResponse>> HandleAsync(
        GetAccountByIdRequest request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(request.Id, cancellationToken);
        if (account is null)
            return Result.Fail<GetAccountByIdResponse>(
                new NotFoundError($"Account {request.Id} not found."));

        return Result.Ok(account.Adapt<GetAccountByIdResponse>());
    }
}
```
Diferença: depende da porta `IAccountRepository`, não de `AppDbContext` (CONV-030/072);
retorna `Result` com `NotFoundError` em vez de exceção (CONV-019/021); não conhece HTTP
(CONV-072); `cancellationToken` nomeado e sem default (CONV-074); mapeia via Mapster (CONV-031).

## O que esta meta-skill NÃO faz
- **Não** gera skills de boas práticas genéricas (usar DI, preferir async). Falhariam o teste "teria produzido sem a skill?".
- **Não** copia skills de outro projeto/arquitetura. Só skill de *ferramenta* (operar uma CLI/lib) se reaproveita.
- **Não** cria skill de invariante — isso é `create-rule`.
- **Não** escreve skill a partir de contexto compactado.
- **Não** infla a `description` com o *como* nem com contexto irrelevante que competiria pela atenção e reduziria a chance da skill certa carregar.

## Fonte da verdade
Os estereótipos e fronteiras vivem na `dotnet-conventions` (CONV) e no `CLAUDE.md`. Em
conflito entre esta skill e esses documentos, **eles vencem** — e abra um débito para
corrigir a skill. Skill é código: envelhece, contradiz a si mesma quando partes evoluem em
ritmos diferentes, e precisa de review.