# Padrão: endpoint de busca por identificador único (GetById)

Use quando o use case é `GetById{Aggregate}` (padrão `get-by-id.md` do `create-read-use-case`).
Rota `GET /{resource}/{id:guid}`; método de extensão `AddGetById`; classe `{Operation}Endpoint`.
`{Operation}` = `GetById{Aggregate}` (ex.: `GetByIdAccount`), já existente na Application. Placeholders e regras comuns: `SKILL.md`.
Arquivo (em `Endpoints/{AggregateFolder}/v1/`): `{Operation}Endpoint.cs`.

## Raciocínio antes de escrever (CoT) — específico deste padrão
- Antes de gerar: (1) `I{Operation}UseCase`, `{Operation}Request` e `{Operation}Response` existem na Application? Senão, `create-read-use-case`; (2) `RouteNames.Get{Aggregate}ById` existe? Senão, acrescente essa constante ao `RouteNames` existente (`public const string Get{Aggregate}ById = "Get{Aggregate}ById";`); `RouteNames` inexistente → pare e reporte; (3) `AuthorizationPolicies.{AggregateFolder}Read` existe? Senão, pare e pergunte.
- Not-found e demais falhas chegam como `Result` do use case: **sempre** `output.ToIResult()` (404 vem de `ResultType.NotFound`); nunca `Results.NotFound()` à mão.
- Sucesso devolve o response da Application (`DataResponse<{Aggregate}Response>`): `Produces<{Operation}Response>()`; sem DTO REST neste padrão.
- `WithName(...)` é obrigatório: o `Location` do endpoint de criação usa esse nome (`ToCreatedResultFromRoute`).
- `{id:guid}` na rota; `Guid.Empty` chega ao use case e vira not-found, sem validação extra. Sem `try/catch` (CONV-061).
- Parâmetros do handler: serviços com `[FromServices]`, depois o valor de rota, `CancellationToken` por último.

## Template canônico
```csharp
// Endpoints/{AggregateFolder}/v1/{Operation}Endpoint.cs
using Microsoft.AspNetCore.Mvc;                                   // só se não houver global using
using {ApiRootNamespace}.Endpoints.Extensions;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};
// + using dos namespaces reais de RouteNames, AuthorizationPolicies e AddDefaultResponseEndpoints

namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1;

internal static class {Operation}Endpoint
{
    public static RouteGroupBuilder AddGetById(
        this RouteGroupBuilder builder)
    {
        builder.MapGet("{id:guid}", async (
                [FromServices] I{Operation}UseCase useCase,
                Guid id,
                CancellationToken cancellationToken) =>
            {
                {Operation}Request input = new(id);

                var output = await useCase.ExecuteAsync(
                    input, cancellationToken);

                return output.ToIResult();
            })
            .WithName(RouteNames.Get{Aggregate}ById)
            .Produces<{Operation}Response>()
            .AddDefaultResponseEndpoints()
            .RequireAuthorization(AuthorizationPolicies.{AggregateFolder}Read);

        return builder;
    }
}
```
Cadeia em `RouteMappings` (`prerequisites.md`, Bloco B): acrescentar `.AddGetById()`.

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — lógica e acesso a dados no endpoint, status à mão, sem autorização, nome copiado:
```csharp
app.MapGet("/api/accounts/{id}", async (Guid id, AppDbContext db) =>              // DbContext no endpoint (CONV-040/030)
{
    try                                                                           // try/catch (CONV-061)
    {
        var account = await db.Accounts.FindAsync(id);                            // sem use case, sem CancellationToken (CONV-044)
        if (account is null) return Results.NotFound();                           // status à mão, deveria ser ToIResult()
        return Results.Ok(account);                                               // expõe entidade (CONV-070)
    }
    catch (Exception ex) { return Results.Problem(ex.ToString()); }              // vaza detalhe interno (CONV-057)
})
.WithName("GetShortUrlById");                                                     // nome copiado; sem RequireAuthorization (CONV-079)
```

✅ Com contexto — `Account`:
```csharp
using Microsoft.AspNetCore.Mvc;
using {ApiRootNamespace}.Endpoints.Extensions;
using {ApplicationRootNamespace}.Features.Accounts.GetByIdAccount;

namespace {ApiRootNamespace}.Endpoints.Accounts.v1;

internal static class GetByIdAccountEndpoint
{
    public static RouteGroupBuilder AddGetById(
        this RouteGroupBuilder builder)
    {
        builder.MapGet("{id:guid}", async (
                [FromServices] IGetByIdAccountUseCase useCase,
                Guid id,
                CancellationToken cancellationToken) =>
            {
                GetByIdAccountRequest input = new(id);

                var output = await useCase.ExecuteAsync(
                    input, cancellationToken);

                return output.ToIResult();
            })
            .WithName(RouteNames.GetAccountById)
            .Produces<GetByIdAccountResponse>()
            .AddDefaultResponseEndpoints()
            .RequireAuthorization(AuthorizationPolicies.AccountsRead);

        return builder;
    }
}
```

Diferença: só adapta protocolo — monta o `Request`, chama o use case, devolve `ToIResult()` (CONV-040/039); nenhum
`DbContext`, `try/catch` ou status manual; devolve o response da Application, não a entidade (CONV-070); nome de rota
próprio do agregado; policy por constante (CONV-079); `CancellationToken` último e repassado (CONV-044/074).

## Anti-patterns específicos deste padrão (além dos comuns do SKILL.md)
- `Results.NotFound()`/`Results.Ok(output.Value)` no lugar de `output.ToIResult()`.
- Sem `WithName`, ou com nome de outra feature (`GetShortUrlById`); rota sem a constraint `{id:guid}`.
- Response REST próprio (`RestResponse`) neste padrão; validar o `Guid` no endpoint.
- Nome da classe fora de `{Operation}Endpoint` (ex.: `GetAccountByIdEndpoint`).

## Checklist específico deste padrão (além do geral do SKILL.md)
- [ ] `MapGet("{id:guid}", ...)` com `[FromServices] I{Operation}UseCase useCase`, `Guid id`, `CancellationToken` por último.
- [ ] `{Operation}Request input = new(id)`; retorno `output.ToIResult()`.
- [ ] `.WithName(RouteNames.Get{Aggregate}ById)` (constante existe), `.Produces<{Operation}Response>()`, `.AddDefaultResponseEndpoints()`, `.RequireAuthorization(...)`.
- [ ] Método `AddGetById` na classe `{Operation}Endpoint`, e `.AddGetById()` na cadeia do `RouteMappings`.

## Cenários mínimos de teste (Harness, passo 3 do SKILL.md)
Integração com `WebApplicationFactory`; substitua `I{Operation}UseCase` por mock (Moq) e use autenticação de teste com a policy `{AggregateFolder}Read`.
- Use case retorna sucesso → 200 e corpo com `data` mapeado.
- Use case retorna `Result` NotFound → 404 `ProblemDetails` com título "Resource Not Found".
- Sem credencial → 401; credencial sem a policy → 403; o use case não é chamado.
- `id` que não é Guid → 404 (rota não casa); o use case não é chamado.
- O endpoint tem o nome `RouteNames.Get{Aggregate}ById` nos metadados (serve ao `Location` do Create).
