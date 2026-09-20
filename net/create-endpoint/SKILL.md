---
name: create-endpoint
description: 'Cria um endpoint Minimal API (.NET/C#, camada Api) que recebe a request, chama o use case e mapeia Result para HTTP com ProblemDetails. Use sempre que o usuário pedir um endpoint, rota, route, HTTP GET/POST, ou expor um use case via API. Não use para controllers MVC nem para regra de negócio (que fica no use case).'
---

# Criar Endpoint (.NET / Minimal API)

Gera um endpoint fino que adapta HTTP para o use case conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Adiciona/edita `src/Api/Features/{Aggregate}/{Aggregate}Endpoints.cs` — um método de extensão
`Map{Aggregate}Endpoints` com `MapGroup` e o handler da rota, chamando o use case.

## Escopo (quando usar / NÃO usar)
- **Usar:** expor um use case por HTTP (Minimal API).
- **NÃO usar:** controller MVC; qualquer regra de negócio (fica no use case); validação de forma (é filtro/validator).

## Contrato

### Rules enforçadas (CONV)
- **CONV-035** Minimal API, endpoints agrupados por feature com `MapGroup`. **CONV-073** versionamento no grupo.
- **CONV-036** typed results (`Results<Ok<T>, ProblemHttpResult>`); sem `IResult` não tipado.
- **CONV-037** reusa `Request`/`Response` da Application. **CONV-070** nunca expõe entidade.
- **CONV-039** falha roteada pelo `ResultToProblemDetails` compartilhado. **CONV-040** endpoint fino, sem regra.
- **CONV-038** validação de forma via endpoint filter (registrado à parte). **CONV-061** exceções ficam com o middleware global (sem try/catch no endpoint).
- **CONV-044** `cancellationToken` do framework propagado. **CONV-072** transporte só aqui.

### Pré-condições
Existem o `{Operation}UseCase`, o `{Operation}Request`/`Response`, e o mapeador compartilhado
`ResultToProblemDetails` (bootstrap da Api). O use case é registrado por `register-dependencies`.

### Inputs
1. **Operation/Aggregate** — o use case a expor.
2. **Verbo e rota** — método HTTP e path (ex.: `GET /v1/accounts/{id}`).
3. **Ligação request** — como montar o `Request` a partir de rota/query/body (+ contexto como `userId` do token, se houver).
4. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Conferir** o `{Aggregate}Endpoints.cs`: existe? Então **adicione a rota** ao grupo, não recrie o arquivo.
3. **Confirmar** a assinatura do use case (Request/Response) para tipar o resultado.
4. **Escrever/estender** o grupo e o handler (CoT).
5. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- O endpoint só **traduz**: parse → `Request` → `useCase.HandleAsync` → mapeia `Result`. Nada além.
- Qual o **typed result**? Sucesso `Ok<Response>`; falha `ProblemHttpResult` via mapeador compartilhado.
- O `Request` precisa de dado fora do corpo (ex.: `userId`)? Monte-o aqui; o use case segue agnóstico (CONV-072).
- Há `try/catch`? Não — exceção é do middleware global (CONV-061).
- Expus alguma entidade? Só `Response` sai (CONV-037/070).

## Template canônico
```csharp
namespace {RootNamespace}.Api.Features.{Aggregate};

public static class {Aggregate}Endpoints
{
    public static IEndpointRouteBuilder Map{Aggregate}Endpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/{aggregate}s").WithTags("{Aggregate}s");

        group.MapGet("/{id:guid}", {Operation})
            .WithName(nameof({Operation}));

        return app;
    }

    private static async Task<Results<Ok<{Operation}Response>, ProblemHttpResult>> {Operation}(
        Guid id,
        {Operation}UseCase useCase,
        CancellationToken cancellationToken)
    {
        var result = await useCase.HandleAsync(new {Operation}Request(id), cancellationToken);

        return result.IsSuccess
            ? TypedResults.Ok(result.Value)
            : result.Errors.ToProblem();   // ResultToProblemDetails compartilhado (CONV-039)
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — controller MVC, expõe entidade, sem CT, infra e exceção no endpoint:
```csharp
[ApiController, Route("accounts")]                        // MVC controller (CONV-035)
public class AccountsController(AppDbContext db) : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<Account> Get(Guid id)               // expõe entidade, sem CT (CONV-037/070/044)
        => await db.Accounts.FindAsync(id)                // infra/regra no endpoint (CONV-040)
           ?? throw new KeyNotFoundException();            // exceção manual (CONV-061)
}
```
✅ Com contexto — Minimal API fino, typed results, mapeador compartilhado:
```csharp
namespace Bank.Api.Features.Accounts;

public static class AccountsEndpoints
{
    public static IEndpointRouteBuilder MapAccountsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/accounts").WithTags("Accounts");

        group.MapGet("/{id:guid}", GetAccountById)
            .WithName(nameof(GetAccountById));

        return app;
    }

    private static async Task<Results<Ok<GetAccountByIdResponse>, ProblemHttpResult>> GetAccountById(
        Guid id,
        GetAccountByIdUseCase useCase,
        CancellationToken cancellationToken)
    {
        var result = await useCase.HandleAsync(new GetAccountByIdRequest(id), cancellationToken);

        return result.IsSuccess
            ? TypedResults.Ok(result.Value)
            : result.Errors.ToProblem();
    }
}
```
Diferença: Minimal API com `MapGroup` versionado (CONV-035/073); typed results (CONV-036);
retorna `Response`, não `Account` (CONV-037/070); chama o use case, sem infra/regra (CONV-040);
falha pelo mapeador compartilhado (CONV-039); exceção fica com o middleware (CONV-061).

## Anti-patterns (recusar)
- Controller MVC / `[ApiController]` / `IActionResult`.
- Retornar/expor entidade de domínio.
- `try/catch` no endpoint; construir `ProblemDetails` inline em vez do mapeador compartilhado.
- Regra de negócio, acesso a repositório/`DbContext` no endpoint.
- Rota solta sem `MapGroup`/versão; `CancellationToken` ausente.

## Checklist + Harness
Checklist (CONV):
- [ ] Minimal API, `MapGroup` com prefixo de versão, agrupado por feature (CONV-035/073).
- [ ] Typed results `Results<Ok<Response>, ProblemHttpResult>` (CONV-036).
- [ ] Só `Request`/`Response` no contrato; nenhuma entidade exposta (CONV-037/070).
- [ ] Endpoint fino: parse → use case → `ToProblem` compartilhado; sem regra, sem `try/catch` (CONV-040/039/061).
- [ ] `cancellationToken` propagado (CONV-044). RootNamespace do repo.

Harness (gate):
- `dotnet build` da `Api` limpo (CONV-002).
- App sobe; a rota aparece no OpenAPI (CONV-073).
- (Quando houver) teste de integração do endpoint verde.
