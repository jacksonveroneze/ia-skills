# Padrão: endpoint de listagem paginada (GetPaged)

Use quando o use case é `GetPaged{AggregateFolder}` (padrão `get-paged.md` do `create-read-use-case`).
Rota `GET /{resource}` com a paginação na query string; método de extensão `AddGetPaged`; classe `{Operation}Endpoint`.
`{Operation}` = `GetPaged{AggregateFolder}` (ex.: `GetPagedAccounts`), já existente na Application. Placeholders e regras comuns: `SKILL.md`.
Diferente do `get-by-id.md`: o `Request` da Application (`PagedRequest`) **não é vinculável** por `[AsParameters]`
(ctor protegido, `init` com lógica), então o endpoint usa um `RestRequest`/`RestResponse` + Mapster, e **valida antes** do
use case, porque o Validator gerado pelo `create-read-use-case` ainda não está ligado a nada.

Arquivos: em `Endpoints/{AggregateFolder}/v1/` → `{Operation}Endpoint.cs`; em `Endpoints/{AggregateFolder}/v1/Models/` →
`{Operation}RestRequest.cs`, `{Operation}RestResponse.cs`, `{Operation}RestMapper.cs`.

## Decisões de design fixadas neste padrão (documentadas para revisão)
1. **`RestRequest`** é um record com parâmetros de construtor **anuláveis e opcionais** (o `[AsParameters]` vincula por construtor): espelha os campos de entrada do `Request` da Application (`Page`, `PageSize`, `OrderBy`, `Order` + filtros).
2. **`null` mantém o default do `PagedRequest`**: o mapper usa `IgnoreNullValues(true)`. Sem isso, `page` ausente vira `null` explícito, sobrescreve o default 1/20 e o Validator (`NotNull`) responde 400 a uma chamada válida.
3. **Validação inline** com `IValidator<{Operation}Request>` sobre o Request já mapeado, antes do use case; inválido → `Results.ValidationProblem(...)` (400) e o use case **não** é chamado.
4. **`RestResponse`** tem hoje a mesma forma do response da Application (`PagedResponse<List<{Aggregate}Response>>`) e existe como ponto de desacoplamento do contrato HTTP. Sem divergência prevista, considere devolver o response da Application (como no GetById) e dispensar o mapeamento.

## Raciocínio antes de escrever (CoT) — específico deste padrão
- Antes de gerar: (1) `I{Operation}UseCase`, `{Operation}Request` (com seus filtros), `{Operation}Response` e `{Operation}Validator` existem na Application? Senão, `create-read-use-case`; (2) `AuthorizationPolicies.{AggregateFolder}Read` existe? Senão, pare e pergunte; (3) já existe `{Operation}RestRequest`/`RestResponse`/`RestMapper`? Existindo, reuse e só acrescente o filtro novo (no `RestRequest`, no `.Map` do mapper); nunca crie um segundo.
- Falha do use case → `output.ToIResult()`; sucesso → mapeia para o `RestResponse` e `Results.Ok`. Página vazia é sucesso (200 com `data` vazio).
- `output.Value!` é aceito na Api (CONV-003 veta `!` só em Domain/Application) e só depois do guard `IsFailure`.
- Mapeamento explícito de todo membro (CONV-031): duas configs no `{Operation}RestMapper` (REST → Request e Response → REST); o registro do `IRegister` na Api é de `register-dependencies`.
- `Order`/`OrderBy` nulos já são tratados pelo `PagedRequest`; `Page`/`PageSize` nulos, pelo `IgnoreNullValues`. `0` vira o default no próprio `PagedRequest` (`pageSize=0` → 20, não é 400): teste valores inválidos com `-1` e `> MaxPageSize`.
- Parâmetros do handler: serviços com `[FromServices]`, depois `[AsParameters]`, `CancellationToken` por último. Sem `WithName` (não há Location para listagem).

## Template canônico
```csharp
// Endpoints/{AggregateFolder}/v1/{Operation}Endpoint.cs
using FluentValidation;                                           // só se não houver global using
using FluentValidation.Results;
using MapsterMapper;
using Microsoft.AspNetCore.Mvc;
using {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1.Models;
using {ApiRootNamespace}.Endpoints.Extensions;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};
// + using dos namespaces reais de AuthorizationPolicies e AddDefaultResponseEndpoints

namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1;

internal static class {Operation}Endpoint
{
    public static RouteGroupBuilder AddGetPaged(
        this RouteGroupBuilder builder)
    {
        builder.MapGet(string.Empty, async (
                [FromServices] IMapper mapper,
                [FromServices] IValidator<{Operation}Request> validator,
                [FromServices] I{Operation}UseCase useCase,
                [AsParameters] {Operation}RestRequest request,
                CancellationToken cancellationToken) =>
            {
                var input = mapper.Map<{Operation}RestRequest,
                    {Operation}Request>(request);

                ValidationResult validation = await validator
                    .ValidateAsync(input, cancellationToken);

                if (!validation.IsValid)
                {
                    return Results.ValidationProblem(validation.ToDictionary());
                }

                var output = await useCase.ExecuteAsync(
                    input, cancellationToken);

                if (output.IsFailure)
                {
                    return output.ToIResult();
                }

                var response = mapper.Map<{Operation}Response,
                    {Operation}RestResponse>(output.Value!);

                return Results.Ok(response);
            })
            .Produces<{Operation}RestResponse>()
            .AddDefaultResponseEndpoints()
            .RequireAuthorization(AuthorizationPolicies.{AggregateFolder}Read);

        return builder;
    }
}
```
```csharp
// Endpoints/{AggregateFolder}/v1/Models/{Operation}RestRequest.cs
// + using do namespace real de SortDirection
namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1.Models;

public sealed record {Operation}RestRequest(
    int? Page = null,
    int? PageSize = null,
    string? OrderBy = null,
    SortDirection? Order = null,
    string? CampoDeFiltro = null);
// um parâmetro por filtro do Request da Application, mesmos nomes, todos anuláveis
```
```csharp
// Endpoints/{AggregateFolder}/v1/Models/{Operation}RestResponse.cs
using {ApplicationRootNamespace}.Common.Models.Common.Response;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;

namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1.Models;

public sealed record {Operation}RestResponse
    : PagedResponse<List<{Aggregate}Response>>;
```
```csharp
// Endpoints/{AggregateFolder}/v1/Models/{Operation}RestMapper.cs — REST → Request e Response → REST (CONV-031)
using Mapster;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1.Models;

public sealed class {Operation}RestMapper : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);

        // null do cliente mantém o default do PagedRequest (Page 1, PageSize 20)
        config.NewConfig<{Operation}RestRequest, {Operation}Request>()
            .IgnoreNullValues(true)
            .Map(dest => dest.Page, src => src.Page)
            .Map(dest => dest.PageSize, src => src.PageSize)
            .Map(dest => dest.OrderBy, src => src.OrderBy)
            .Map(dest => dest.Order, src => src.Order)
            .Map(dest => dest.CampoDeFiltro, src => src.CampoDeFiltro);

        config.NewConfig<{Operation}Response, {Operation}RestResponse>()
            .Map(dest => dest.Data, src => src.Data)
            .Map(dest => dest.Pagination, src => src.Pagination);
    }
}
```
Cadeia em `RouteMappings` (`prerequisites.md`, Bloco B): acrescentar `.AddGetPaged()`.

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — liga o `PagedRequest` direto no `[AsParameters]`, não valida, ignora falha, `!` sem guard, sem autorização:
```csharp
app.MapGet("/api/accounts", async (
    [AsParameters] GetPagedAccountsRequest request,                              // PagedRequest não é vinculável; sem RestRequest
    IGetPagedAccountsUseCase useCase) =>                                         // sem CancellationToken (CONV-044)
{
    var output = await useCase.ExecuteAsync(request, default);                   // `default` no token; sem validação: pageSize=999999 chega ao repositório
    return Results.Ok(output.Value!);                                            // `!` sem checar falha; expõe o response da Application
});                                                                              // sem RequireAuthorization (CONV-079)
```

✅ Com contexto — `Account`, filtro por `Currency`:
```csharp
// GetPagedAccountsRestRequest.cs
public sealed record GetPagedAccountsRestRequest(
    int? Page = null,
    int? PageSize = null,
    string? OrderBy = null,
    SortDirection? Order = null,
    string? Currency = null);
```
```csharp
// GetPagedAccountsRestMapper.cs — dentro de Register
config.NewConfig<GetPagedAccountsRestRequest, GetPagedAccountsRequest>()
    .IgnoreNullValues(true)
    .Map(dest => dest.Page, src => src.Page)
    .Map(dest => dest.PageSize, src => src.PageSize)
    .Map(dest => dest.OrderBy, src => src.OrderBy)
    .Map(dest => dest.Order, src => src.Order)
    .Map(dest => dest.Currency, src => src.Currency);

config.NewConfig<GetPagedAccountsResponse, GetPagedAccountsRestResponse>()
    .Map(dest => dest.Data, src => src.Data)
    .Map(dest => dest.Pagination, src => src.Pagination);
```
O endpoint segue o template com `GetPagedAccounts`, `AuthorizationPolicies.AccountsRead` e `Currency` como filtro.

Diferença: `RestRequest` vinculável por construtor e mapeado com `IgnoreNullValues` (defaults preservados); validação do
Request **antes** do use case (400 sem chamá-lo); falha do use case por `ToIResult()`; `Value!` só depois do guard;
mapeamento explícito nos dois sentidos (CONV-031); policy por constante e `CancellationToken` último e repassado.

## Anti-patterns específicos deste padrão (além dos comuns do SKILL.md)
- `[AsParameters]` com o `Request` da Application; `RestRequest` com parâmetros não anuláveis ou sem default.
- Mapper REST sem `IgnoreNullValues(true)` (quebra os defaults de `Page`/`PageSize`) ou com membro sem `.Map`.
- Chamar o use case sem validar; validar o `RestRequest` em vez do `Request` mapeado; `Results.ValidationProblem` depois da chamada.
- `output.Value!` sem o guard `IsFailure`; `Results.Ok(output.Value)` devolvendo o response da Application sem mapear.
- Filtro do `Request` da Application sem o parâmetro correspondente no `RestRequest` ou sem `.Map` (e vice-versa).
- Segundo `RestRequest`/`RestResponse`/`RestMapper` para o mesmo use case.

## Checklist específico deste padrão (além do geral do SKILL.md)
- [ ] Handler com `IMapper`, `IValidator<{Operation}Request>`, `I{Operation}UseCase`, `[AsParameters]` `RestRequest` e `CancellationToken` por último.
- [ ] Ordem: mapear → validar (400 sem chamar o use case) → executar → `IsFailure` → mapear resposta → `Results.Ok`.
- [ ] `RestRequest` com parâmetros anuláveis/opcionais, um por filtro do `Request`; `RestResponse : PagedResponse<List<{Aggregate}Response>>`.
- [ ] `RestMapper` com as duas configs, `IgnoreNullValues(true)` na primeira, todo membro com `.Map`.
- [ ] `.Produces<{Operation}RestResponse>()`, `.AddDefaultResponseEndpoints()`, `.RequireAuthorization(...)`; sem `WithName`.
- [ ] `AddGetPaged` na classe `{Operation}Endpoint`, e `.AddGetPaged()` na cadeia do `RouteMappings`.

## Cenários mínimos de teste (Harness, passo 3 do SKILL.md)
Integração com `WebApplicationFactory`; substitua `I{Operation}UseCase` por mock (Moq), use o `IValidator` real e autenticação de teste com a policy `{AggregateFolder}Read`.
- Sem query string → 200 e o use case recebe `Request` com defaults (`Page` 1, `PageSize` 20, `OrderBy`/`Order` default).
- `pageSize=-1`, `pageSize` acima do máximo, `page=-1` ou `orderBy` fora de `AllowedOrderBy` → 400 e o use case **não** é chamado. (`pageSize=0` e `page=0` viram o default, não 400.)
- Filtros da query chegam ao `Request` (o mock recebe os valores).
- Página vazia → 200 com `data` vazio; falha do use case → status vindo do `ResultType` (ex.: `Invalid` → 400).
- Sem credencial → 401; credencial sem a policy → 403; o use case não é chamado.
- Unitário do mapper: `TypeAdapterConfig` com `{Operation}RestMapper` aplicado explicitamente e `Compile()` sem membro de destino não mapeado; `null` em `Page`/`PageSize` preserva os defaults.
