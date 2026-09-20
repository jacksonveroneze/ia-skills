---
name: create-read-use-case
description: 'Cria um caso de uso de leitura (.NET/C#, camada Application) — Request, Response e o UseCase que consulta um repositório e retorna Result, sem mutação. Use sempre que o usuário pedir uma consulta, query, busca, listagem ou um use case de leitura (ex. GetAccountById, ListOrders), mesmo sem usar o termo. Não use para escrita ou mutação (será create-write-use-case) nem para endpoint HTTP (create-endpoint).'
---

# Criar Use Case de Leitura (.NET / Clean Architecture)

Gera um slice de leitura (Request + Response + UseCase) conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Três arquivos em `src/Application/Features/{Aggregate}/{Operation}/`:
`{Operation}Request.cs`, `{Operation}Response.cs`, `{Operation}UseCase.cs`.

## Escopo (quando usar / NÃO usar)
- **Usar:** operação de **leitura** (consulta/projeção), sem mutar estado.
- **NÃO usar:** muta/persiste → `create-write-use-case`. Adaptação HTTP → `create-endpoint`. Mapeamento → `create-mapper`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-016/017** nome `{Operation}UseCase`; input `{Operation}Request`, output `{Operation}Response`.
- **CONV-019** retorna `Task<Result<{Operation}Response>>`; não lança para fluxo esperado.
- **CONV-027** classe concreta única (sem interface por use case); é o handler; primary ctor injeta portas.
- **CONV-028** `Request`/`Response` são `record` imutáveis. **CONV-064** `sealed`.
- **CONV-072** agnóstico a transporte: sem HTTP/MCP/gRPC/`HttpContext`.
- **CONV-021** ausência → `NotFoundError`; nunca exceção para not-found.
- **CONV-031** mapeia entidade→Response via `IMapper` (Mapster). **CONV-044/074** `cancellationToken` nomeado, sem default.

### Pré-condições
Existem: a porta `I{Aggregate}Repository` (`create-repository`), a entidade, e o mapeamento
`{Operation}Mapping` registrado (`create-mapper` + `register-dependencies`).

### Inputs
1. **Operation** — verbo + sujeito (`GetAccountById`).
2. **Aggregate** — agregado/pasta (`Accounts`).
3. **Request** — dados de entrada (ex.: `Id`).
4. **Response** — forma de saída (campos já desempacotados dos VOs).
5. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Conferir a porta**: existe `GetByIdAsync` (ou equivalente)? Faltando, gere/estenda com `create-repository`.
3. **Conferir o mapeamento** entidade→Response; faltando, gere com `create-mapper`.
4. **Modelar** Request/Response e o fluxo (CoT).
5. **Escrever** os três arquivos.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- É leitura pura? Não há mutação nem transação — só consulta + projeção.
- O que o Request precisa carregar? O mínimo para localizar o dado.
- Entidade ausente é **esperado** → `NotFoundError` via `Result`, nunca exceção (CONV-021).
- A projeção para Response é do **mapper** (CONV-031), não código manual no handler.
- Algum tipo de transporte apareceu na assinatura? Se sim, está errado (CONV-072).

## Template canônico
```csharp
// {Operation}Request.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};
public sealed record {Operation}Request(/* campos de entrada */);
```
```csharp
// {Operation}Response.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};
public sealed record {Operation}Response(/* campos de saída, já desempacotados */);
```
```csharp
// {Operation}UseCase.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};

public sealed class {Operation}UseCase(I{Aggregate}Repository {aggregate}s, IMapper mapper)
{
    public async Task<Result<{Operation}Response>> HandleAsync(
        {Operation}Request request, CancellationToken cancellationToken)
    {
        var entity = await {aggregate}s.GetByIdAsync(request.Id, cancellationToken);
        if (entity is null)
            return Result.Fail<{Operation}Response>(new NotFoundError($"{Aggregate} not found."));

        return Result.Ok(mapper.Map<{Operation}Response>(entity));
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — MediatR + interface, `DbContext` na Application, exceção para not-found:
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
✅ Com contexto:
```csharp
namespace Bank.Application.Features.Accounts.GetAccountById;
public sealed record GetAccountByIdRequest(Guid Id);
```
```csharp
namespace Bank.Application.Features.Accounts.GetAccountById;
public sealed record GetAccountByIdResponse(Guid AccountId, decimal Balance, string Currency);
```
```csharp
namespace Bank.Application.Features.Accounts.GetAccountById;

public sealed class GetAccountByIdUseCase(IAccountRepository accounts, IMapper mapper)
{
    public async Task<Result<GetAccountByIdResponse>> HandleAsync(
        GetAccountByIdRequest request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(request.Id, cancellationToken);
        if (account is null)
            return Result.Fail<GetAccountByIdResponse>(
                new NotFoundError($"Account {request.Id} not found."));

        return Result.Ok(mapper.Map<GetAccountByIdResponse>(account));
    }
}
```
Diferença: classe concreta sem MediatR nem interface (CONV-027); depende da porta, não do
`DbContext` (CONV-030/072); `NotFoundError` via `Result` em vez de exceção (CONV-019/021);
projeção via `IMapper` (CONV-031); `cancellationToken` nomeado sem default (CONV-074).

## Anti-patterns (recusar)
- MediatR / `IRequestHandler` / interface por use case.
- Injetar `DbContext`, `IQueryable` ou qualquer tipo de infra/transporte.
- Exceção para not-found; retornar `null`.
- Mapear manualmente no handler em vez de usar o mapper.
- Mutar estado num use case de leitura.

## Checklist + Harness
Checklist (CONV):
- [ ] `{Operation}UseCase` `sealed`, concreto, sem interface; primary ctor com portas (CONV-027/064).
- [ ] `Request`/`Response` são `record` imutáveis, nomes corretos (CONV-017/028).
- [ ] Retorna `Task<Result<{Operation}Response>>`; not-found → `NotFoundError` (CONV-019/021).
- [ ] Sem transporte/infra na assinatura; projeção via `IMapper` (CONV-072/031).
- [ ] `cancellationToken` nomeado, sem default (CONV-074). RootNamespace do repo.

Harness (gate):
- `dotnet build` de `Application` limpo (CONV-002).
- Teste de unidade do use case verde (mock da porta, `IMapper` real) — critério de conclusão (CONV-051/052).
- Arquitetura: `Application` não referencia EF nem tipos de transporte (§16/CONV-030/072).
