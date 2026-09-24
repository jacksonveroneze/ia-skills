---
name: create-read-use-case
description: 'Cria um caso de uso de leitura (.NET/C#, camada Application) — Request, Response e o UseCase que consulta um repositório e retorna Result, sem mutação. Use sempre que o usuário pedir uma consulta, query, busca, listagem ou um use case de leitura (ex. GetAccountById, ListOrders), mesmo sem usar o termo. Não use para escrita ou mutação (será create-write-use-case) nem para endpoint HTTP (create-endpoint).'
---

# Criar Use Case de Leitura (.NET / Clean Architecture)

Gera um slice de leitura (Request + Response + UseCase) conforme a `dotnet-conventions.md` na
raiz do projeto. Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Até quatro arquivos em `{ApplicationProjectDir}/Features/{Aggregate}/{Operation}/`:
`{Operation}Request.cs`, `{Operation}Response.cs`, `{Operation}UseCase.cs` sempre; e
`{Operation}Mapping.cs` só se o mapeamento daquela feature ainda não existir (ver aviso acima).

## Escopo (quando usar / NÃO usar)
- **Usar:** operação de **leitura** (consulta/projeção), sem mutar estado.
- **NÃO usar:** muta/persiste → `create-write-use-case`. Adaptação HTTP → `create-endpoint`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-016/017** nome `{Operation}UseCase`; input `{Operation}Request`, output `{Operation}Response`.
- **CONV-085** retorna `Task<Result<{Operation}Response>>`; ausência → `FromNotFound(error)`, nunca exceção.
- **CONV-021** cada erro é `Error.Create("{Operation}.{Reason}", ...)` declarado uma vez como `private static readonly Error` no próprio UseCase — mesmo padrão do VO/entity, não uma taxonomia central.
- **CONV-027** classe concreta única (sem interface por use case); é o handler; primary ctor injeta portas.
- **CONV-028** `Request`/`Response` são `record` imutáveis. **CONV-064** `sealed`.
- **CONV-072** agnóstico a transporte: sem HTTP/MCP/gRPC/`HttpContext`.
- **CONV-031** mapeia entidade→Response via `IMapper` (Mapster), configurado por `IRegister` explícito da própria feature.
- **CONV-044/074** `cancellationToken` nomeado, sem default.
- **CONV-088** só usa `async`/`await` quando há processamento depois do `await` — aqui `HandleAsync` sempre tem (checar not-found + mapear), então mantém `async`/`await`.
- **CONV-089** todo método com corpo em bloco; **chaves obrigatórias em todo `if`**, mesmo de uma linha (IDE0011 = error, §16) — inclusive o `if` de not-found.
- **CONV-013** namespace = `RootNamespace` do `.csproj` da **Application** + pasta — não presuma; e os `using` para a entidade do Domain e para a porta da Application são **explícitos**, nunca implícitos (são namespaces irmãos, C# não importa sozinho).
- **CONV-087** nenhum pacote novo sem confirmação — Mapster já é stack decidida, não precisa confirmar de novo.

### Pré-condições
A porta `I{Aggregate}Repository` já existe com o método de leitura necessário (`create-repository`
— se faltar, gere/estenda antes). A entidade do agregado existe no Domain (`create-entity`). O
mapeamento `{Operation}Mapping` existe **ou** é gerado por esta skill (ver aviso no topo). O
registro de `IMapper`/`TypeAdapterConfig` no DI é feito por `register-dependencies`, não aqui —
essa skill ainda não existe.

### Inputs
1. **Operation** — verbo + sujeito (`GetAccountById`).
2. **Aggregate** — agregado/pasta (`Accounts`).
3. **Request** — dados de entrada (ex.: `Id`).
4. **Response** — forma de saída (campos já desempacotados dos VOs).
5. **RootNamespace** de Application e de Domain — resolvidos por ReAct, não perguntados de cara.

## Fluxo (ReAct)
1. **Localizar os `.csproj` de Application e de Domain.**
2. **Resolver o `RootNamespace` de cada um, separadamente.** Nunca use o namespace dos exemplos desta skill.
   - Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace` para cada um.
   - Fallback: `<RootNamespace>` no `.csproj`; senão `<AssemblyName>`; senão o nome do arquivo `.csproj` sem extensão.
   - Namespace do slice = `{ApplicationRootNamespace}.Features.{Aggregate}.{Operation}`.
   - `using` da entidade = `{DomainRootNamespace}.{Aggregate}`.
   - `using` da porta = `{ApplicationRootNamespace}.Abstractions.{Aggregate}` — mesma raiz do slice, mas namespace irmão: **precisa de `using` explícito mesmo assim**, C# não importa sozinho.
3. **Checar usings globais** da Application — se `JacksonVeroneze.NET.Result` e/ou `MapsterMapper`/`Mapster` já são `global using`, não repita nos arquivos (`IDE0005`).
4. **Conferir a porta**: existe o método de leitura necessário (`GetByIdAsync` ou equivalente)? Faltando, gere/estenda com `create-repository` antes.
5. **Conferir o mapeamento** entidade→Response: já existe um `IRegister` para essa feature? Faltando, esta skill gera `{Operation}Mapping.cs` (ver aviso no topo).
6. **Checar duplicidade**: se a pasta `Features/{Aggregate}/{Operation}/` já tem algum desses arquivos, não sobrescreva: relate.
7. **Modelar** Request/Response e o fluxo (CoT).
8. **Escrever** os arquivos.
9. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- É leitura pura? Não há mutação nem transação — só consulta + projeção.
- O que o Request precisa carregar? O mínimo para localizar o dado.
- Entidade ausente é **esperado** → `Result<{Operation}Response>.FromNotFound(NotFound)`, nunca exceção (CONV-085/021). O `Error` é `private static readonly` com mensagem **fixa** (ex.: `"Account not found."`) — não dá pra interpolar o id recebido, porque o campo é uma instância única compartilhada por todas as chamadas; o id em si já fica visível no `Request`/nos logs, não precisa duplicar na mensagem do erro.
- A projeção para Response é do **mapper** (CONV-031), não código manual no handler.
- Algum tipo de transporte apareceu na assinatura? Se sim, está errado (CONV-072).
- O `HandleAsync` faz **uma** chamada async (buscar a entidade) e depois processa (checa null, mapeia) — isso justifica manter `async`/`await` (CONV-088); não é um repasse de chamada única.

## Template canônico
`{ApplicationRootNamespace}`/`{DomainRootNamespace}` são placeholders: substitua pelos valores
resolvidos no passo 2 do Fluxo, nunca copie literalmente.

```csharp
// {Operation}Request.cs
namespace {ApplicationRootNamespace}.Features.{Aggregate}.{Operation};

public sealed record {Operation}Request(
    /* campos de entrada, um por linha se houver mais de um */);
```
```csharp
// {Operation}Response.cs
namespace {ApplicationRootNamespace}.Features.{Aggregate}.{Operation};

public sealed record {Operation}Response(
    /* campos de saída, já desempacotados, um por linha */);
```
```csharp
// {Operation}Mapping.cs — só se o mapeamento da feature ainda não existir (ver aviso no topo)
using Mapster;
using {DomainRootNamespace}.{Aggregate};

namespace {ApplicationRootNamespace}.Features.{Aggregate}.{Operation};

public sealed class {Operation}Mapping : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<{Aggregate}, {Operation}Response>();
        // .Map(dest => dest.Campo, src => src.CampoDoDominio) só onde o nome difere
        // ou o campo vem de dentro de um VO (ex.: src.Balance.Amount)
    }
}
```
```csharp
// {Operation}UseCase.cs
using JacksonVeroneze.NET.Result;   // só se não houver global using (passo 3)
using MapsterMapper;                 // só se não houver global using (passo 3)
using {DomainRootNamespace}.{Aggregate};
using {ApplicationRootNamespace}.Abstractions.{Aggregate};

namespace {ApplicationRootNamespace}.Features.{Aggregate}.{Operation};

public sealed class {Operation}UseCase(
    I{Aggregate}Repository {aggregate}Repository,
    IMapper mapper)
{
    private static readonly Error NotFound =
        Error.Create("{Operation}.NotFound", "{Aggregate} not found.");

    public async Task<Result<{Operation}Response>> HandleAsync(
        {Operation}Request request,
        CancellationToken cancellationToken)
    {
        {Aggregate}? {aggregate} = await {aggregate}Repository.GetByIdAsync(
            request.Id, cancellationToken);

        if ({aggregate} is null)
        {
            return Result<{Operation}Response>.FromNotFound(NotFound);
        }

        return Result<{Operation}Response>.WithSuccess(
            mapper.Map<{Operation}Response>({aggregate}));
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — MediatR + interface, `DbContext` na Application, exceção para not-found, `if` sem chaves, sem `using`:
```csharp
public class GetAccountByIdHandler(AppDbContext db)       // infra na Application (CONV-030/072)
    : IRequestHandler<GetAccountByIdQuery, GetAccountByIdResponse>   // MediatR + interface (CONV-027)
{
    public async Task<GetAccountByIdResponse> Handle(GetAccountByIdQuery q, CancellationToken ct)
    {
        var a = await db.Accounts.FindAsync(q.Id)
            ?? throw new NotFoundException();                        // exceção p/ fluxo (CONV-021)
        return new GetAccountByIdResponse(a.Id, a.Balance.Amount, a.Balance.Currency);
    }
}
```

✅ Com contexto — `using` completo, `Result` real, chaves no `if`, parâmetro por linha:
```csharp
namespace {ApplicationRootNamespace}.Features.Accounts.GetAccountById;

public sealed record GetAccountByIdRequest(
    Guid Id);
```
```csharp
namespace {ApplicationRootNamespace}.Features.Accounts.GetAccountById;

public sealed record GetAccountByIdResponse(
    Guid AccountId,
    decimal Balance,
    string Currency);
```
```csharp
using Mapster;
using {DomainRootNamespace}.Accounts;

namespace {ApplicationRootNamespace}.Features.Accounts.GetAccountById;

public sealed class GetAccountByIdMapping : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<Account, GetAccountByIdResponse>()
            .Map(dest => dest.AccountId, src => src.Id)
            .Map(dest => dest.Balance, src => src.Balance.Amount)
            .Map(dest => dest.Currency, src => src.Balance.Currency);
    }
}
```
```csharp
using JacksonVeroneze.NET.Result;
using MapsterMapper;
using {DomainRootNamespace}.Accounts;
using {ApplicationRootNamespace}.Abstractions.Accounts;

namespace {ApplicationRootNamespace}.Features.Accounts.GetAccountById;

public sealed class GetAccountByIdUseCase(
    IAccountRepository accountRepository,
    IMapper mapper)
{
    private static readonly Error NotFound =
        Error.Create("GetAccountById.NotFound", "Account not found.");

    public async Task<Result<GetAccountByIdResponse>> HandleAsync(
        GetAccountByIdRequest request,
        CancellationToken cancellationToken)
    {
        Account? account = await accountRepository.GetByIdAsync(
            request.Id, cancellationToken);

        if (account is null)
        {
            return Result<GetAccountByIdResponse>.FromNotFound(NotFound);
        }

        return Result<GetAccountByIdResponse>.WithSuccess(
            mapper.Map<GetAccountByIdResponse>(account));
    }
}
```

Diferença: classe concreta sem MediatR nem interface (CONV-027); depende da porta, não do
`DbContext` (CONV-030/072); `using` explícito para a entidade do Domain e para a porta da
Application — namespaces irmãos, o C# não importa sozinho, e o exemplo original desta skill
nunca tinha isso, o que fazia o few-shot antigo não compilar; `NotFound` como `private static
readonly Error` único, não uma classe `NotFoundError` nem erro montado inline (CONV-021/085);
`FromNotFound` em vez de exceção (CONV-085); `if` com chaves mesmo sendo uma linha só (§16);
projeção via `IMapper`/`IRegister` explícito da própria feature (CONV-031); `cancellationToken`
nomeado sem default, parâmetro por linha inclusive no primary ctor (CONV-044/074); parâmetro do
ctor `accountRepository` (singular + sufixo), não `accounts` — evita o problema de pluralização
irregular já visto em `create-repository`.

## Anti-patterns (recusar)
- MediatR / `IRequestHandler` / interface por use case.
- Injetar `DbContext`, `IQueryable`, `IEfCoreRepository` ou qualquer tipo de infra/transporte.
- Exceção para not-found; retornar `null` em vez de `Result`.
- `NotFoundError` ou qualquer classe de erro própria — o erro é `Error.Create(...)` da lib, `private static readonly`, dono do UseCase.
- `Error` como propriedade expression-bodied (`static Error X => ...`) — usa `static readonly`.
- Tentar interpolar dado dinâmico (ex.: o id) na mensagem do `Error` estático — a mensagem é fixa; o dado dinâmico fica no `Request`/logs.
- Mapear manualmente no handler (`new {Operation}Response(a.Id, a.Balance.Amount, ...)`) em vez de usar o `IMapper`.
- Mutar estado num use case de leitura.
- `if` sem chaves, mesmo de uma linha (`if (x is null) return ...;`).
- Omitir o `using` da entidade do Domain ou da porta da Application — são namespaces irmãos, não se importam sozinhos.
- Copiar o namespace do exemplo, ou usar `{ApplicationRootNamespace}.Application.Features...` (duplicando "Application" — o RootNamespace do `.csproj` já inclui isso).
- Parâmetro do ctor plural manual (`accounts`) em vez de `{aggregate}Repository` — pluralização irregular quebra em agregados como `Category`.
- `async`/`await` só quando não há processamento depois do `await` — aqui `HandleAsync` sempre tem (not-found + mapeamento), então isso não se aplica, mas não adicione `async`/`await` em nenhum outro método que só repasse uma chamada.

## Checklist + Harness
Checklist (CONV):
- [ ] Arquivos em `{ApplicationProjectDir}/Features/{Aggregate}/{Operation}/`, namespace com o `RootNamespace` da Application (CONV-013).
- [ ] `{Operation}UseCase` `sealed`, concreto, sem interface; primary ctor com portas, um parâmetro por linha (CONV-027/064).
- [ ] `Request`/`Response` são `record` imutáveis, campos um por linha, nomes corretos (CONV-017/028).
- [ ] `using` explícito (ou global using confirmado) para a entidade do Domain e para a porta da Application.
- [ ] Retorna `Task<Result<{Operation}Response>>`; not-found → `Result<T>.FromNotFound(NotFound)`, `NotFound` como `private static readonly Error` único no UseCase (CONV-085/021).
- [ ] `if` de not-found com chaves (§16/IDE0011).
- [ ] Sem transporte/infra na assinatura; projeção via `IMapper` (CONV-072/031).
- [ ] Mapeamento (`{Operation}Mapping`) existe ou foi gerado por esta skill, como `IRegister` explícito da própria feature — sem convenção implícita.
- [ ] `cancellationToken` nomeado, sem default (CONV-074).
- [ ] Os dois RootNamespaces (Application, Domain) resolvidos dos respectivos `.csproj`, nenhum placeholder ou exemplo copiado.
- [ ] Nenhum pacote novo sem confirmação (CONV-087).

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Application.csproj>` sem warnings. Com CONV-002 isso cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Application.csproj> --verify-no-changes` sem diferenças.
3. Teste de unidade do use case **verde** — mock da porta (Moq), `IMapper` real configurado com o `{Operation}Mapping` gerado, cobrindo o caminho de sucesso e o de not-found; critério de conclusão do slice (CONV-048/051/052/053).
4. Revisão do `Application`: grep por termos de infra/transporte (`DbContext`, `HttpContext`, `IQueryable`) — deve dar vazio.

Se qualquer comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia,
etc.) em vez de reprovar por conteúdo do arquivo, **não trate como passo concluído**: tente
novamente uma vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não
declare a criação do use case como concluída.