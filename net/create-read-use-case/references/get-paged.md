# Padrão: listagem paginada (GetPaged)

Use quando o pedido é listar/paginar registros de um agregado. Diferente do `get-by-id.md`:
**não há not-found** — página sem resultados é sucesso (`Data` vazio, `Pagination.TotalElements == 0`),
nunca falha. Também exige validar `Page`/`PageSize`/`OrderBy` **antes** do repositório, porque
`PaginationParameters` (lib `Pagination`) lança exceção para valores inválidos, e exceção para entrada
externa inválida é o que a rule proíbe (CONV-020/038).

`{Operation}` = `Get{AggregateFolder}Paged` (ex.: `GetAccountsPaged`). Placeholders e regras comuns:
`SKILL.md`. Os tipos de paginação vêm de `prerequisites.md` (Bloco A.2).
Arquivos por operação (em `Features/{AggregateFolder}/{Operation}/`): `Request`, `Response`, `Validator`,
`I{Operation}UseCase`, `{Operation}UseCase`, `{Operation}Mapper`.
Compartilhado por agregado (criar **só se não existir**): `Features/{AggregateFolder}/Common/Filters/{Aggregate}PagedFilter.cs`.

Placeholders deste padrão: `{OrderableProperty}` é cada propriedade de `{Aggregate}Response` que o cliente
pode usar para ordenar; `{FilterType}` e `{FilterProperty}` são o tipo e o nome de cada filtro pedido
(repetir o bloco por filtro). Nomes de propriedade em inglês (CONV-063).

## Decisões de design fixadas neste padrão (documentadas para revisão)
1. **Envelope**: `{Operation}Response : PagedResponse<List<{Aggregate}Response>>`. O `Page<{Aggregate}>` da lib (retorno do repositório) não vaza para a API: o Mapster o converte em `Data` (via `{Aggregate}ResponseMapper`) e `Pagination` (`PageInfo` para `PageInfoResponse`, via `PageInfoResponseMapper`). O use case só chama `mapper.Map<Page<{Aggregate}>, {Operation}Response>(page)`, sem remontar envelope à mão.
2. **Validação**: este padrão **também gera** `{Operation}Validator.cs` (FluentValidation, CONV-029). O use case **não** revalida; confia no `Request` validado (CONV-038). Esta skill não liga o Validator a nenhum ponto de entrada — avise disso ao terminar.
3. **Filtro**: o `Request` vira `{Aggregate}PagedFilter` (Mapster), com os filtros do usuário + `PaginationParameters`. A porta recebe o filtro, não `page`/`pageSize` soltos.
4. **`OrderBy` vem do cliente como string**: o Validator só aceita nomes de uma lista explícita (`AllowedOrderBy`), e o default do `Request` tem de estar nela.

## Pré-condições específicas deste padrão
- A porta `I{Aggregate}Repository` tem `GetPagedAsync({Aggregate}PagedFilter filter, CancellationToken cancellationToken)`, retornando `Task<Page<{Aggregate}>>`. Ausente ou com outra assinatura (por exemplo `page`/`pageSize` soltos): pare e relate a assinatura esperada e onde.
- `{SortDirectionNamespace}` resolvido (Bloco A.2 de `prerequisites.md`); não resolvido: pare.

## Raciocínio antes de escrever (CoT) — específico deste padrão
- Antes de gerar: (1) `{Aggregate}PagedFilter` existindo, reuse — filtro novo entra no `Request`, no filtro **e** no `.Map`; (2) a porta expõe `GetPagedAsync({Aggregate}PagedFilter, CancellationToken)`.
- `Page`/`PageSize`/`OrderBy` chegam validados: o use case não checa de novo (CONV-029/038) e o teste de valor inválido é do Validator. `Page`/`PageSize` são `int?` (comportamento em `prerequisites.md`): **sem `!`** (CONV-003); o Validator exige `NotNull` e o mapper usa `GetValueOrDefault()`.
- Página vazia é sucesso, sempre `WithSuccess`; sem `Error`/`FromNotFound`.
- Mapeamento explícito (CONV-031): três configs no `{Operation}Mapper` (request para filtro, request para `PaginationParameters`, `Page<{Aggregate}>` para response); o `PageInfo` para `PageInfoResponse` é do mapper compartilhado.

## Template canônico

```csharp
// {Operation}Request.cs
using {ApplicationRootNamespace}.Abstractions.UseCases;
using {ApplicationRootNamespace}.Common.Models.Request;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;
using {SortDirectionNamespace};                  // namespace real de SortDirection

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed record {Operation}Request()
    : PagedRequest(DefaultOrderBy, DefaultOrder),
        IBaseRequest
{
    private const string DefaultOrderBy = nameof({Aggregate}Response.{OrderableProperty});

    private const SortDirection DefaultOrder = SortDirection.Ascending;

    // filtros que o usuário solicitar, um por linha, todos anuláveis
    public {FilterType}? {FilterProperty} { get; init; }
}
```
```csharp
// {Operation}Response.cs — envelope; a forma de UM item é {Aggregate}Response (Common)
using {ApplicationRootNamespace}.Common.Models.Response;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed record {Operation}Response
    : PagedResponse<List<{Aggregate}Response>>;
```
```csharp
// {Operation}Validator.cs — o use case confia nele (decisões 2 e 4)
using FluentValidation;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed class {Operation}Validator : AbstractValidator<{Operation}Request>
{
    private const int MaxPageSize = 100;

    // campos ordenáveis, um por linha; o default do Request tem de estar aqui
    private static readonly string[] AllowedOrderBy =
    [
        nameof({Aggregate}Response.{OrderableProperty})
    ];

    public {Operation}Validator()
    {
        RuleFor(request => request.Page)
            .NotNull()
            .GreaterThanOrEqualTo(1);

        RuleFor(request => request.PageSize)
            .NotNull()
            .InclusiveBetween(1, MaxPageSize);

        RuleFor(request => request.OrderBy)
            .Must(orderBy => AllowedOrderBy.Contains(orderBy));
    }
}
```
```csharp
// I{Operation}UseCase.cs
using {ApplicationRootNamespace}.Abstractions.UseCases;

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public interface I{Operation}UseCase :
    IUseCase<{Operation}Request, Result.Result<{Operation}Response>>;
```
```csharp
// {Operation}UseCase.cs
using JacksonVeroneze.NET.Pagination.Offset;                 // só se não houver global using
using MapsterMapper;                                          // só se não houver global using
using {ApplicationRootNamespace}.Abstractions.Repositories.{AggregateFolder};
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Filters;
using {EntityNamespace};                                      // namespace real da entidade

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed class {Operation}UseCase(
    IMapper mapper,
    I{Aggregate}Repository repository) : I{Operation}UseCase
{
    public async Task<Result.Result<{Operation}Response>> ExecuteAsync(
        {Operation}Request request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var filter = mapper
            .Map<{Operation}Request, {Aggregate}PagedFilter>(request);

        var page = await repository
            .GetPagedAsync(filter, cancellationToken);

        var response = mapper
            .Map<Page<{Aggregate}>, {Operation}Response>(page);

        return Result.Result<{Operation}Response>
            .WithSuccess(response);
    }
}
```
```csharp
// {Operation}Mapper.cs — request para filtro, request para PaginationParameters, página para response
using JacksonVeroneze.NET.Pagination.Offset;                 // só se não houver global using
using Mapster;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Filters;
using {EntityNamespace};

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed class {Operation}Mapper : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);

        config.NewConfig<{Operation}Request, {Aggregate}PagedFilter>()
            .Map(dest => dest.{FilterProperty}, src => src.{FilterProperty})
            .Map(dest => dest.Pagination, src => src);
        // um .Map por filtro do Request

        // Page/PageSize garantidos pelo Validator (NotNull); sem `!` (CONV-003)
        config.NewConfig<{Operation}Request, PaginationParameters>()
            .ConstructUsing(src =>
                new PaginationParameters(
                    src.Page.GetValueOrDefault(),
                    src.PageSize.GetValueOrDefault(),
                    src.OrderBy,
                    src.Order));

        config.NewConfig<Page<{Aggregate}>, {Operation}Response>()
            .Map(dest => dest.Data, src => src.Data)
            .Map(dest => dest.Pagination, src => src.PageInfo);
    }
}
```
```csharp
// Features/{AggregateFolder}/Common/Filters/{Aggregate}PagedFilter.cs — criar só se não existir
using System.Diagnostics.CodeAnalysis;
using JacksonVeroneze.NET.Pagination.Offset;                 // só se não houver global using

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Filters;

[ExcludeFromCodeCoverage]
public sealed record {Aggregate}PagedFilter
{
    // um campo por filtro do Request, mesmos nomes, todos anuláveis
    public {FilterType}? {FilterProperty} { get; init; }

    public PaginationParameters? Pagination { get; init; }
}
```
Tipos de paginação (`PageInfoResponse`, `PagedResponse`, `PageInfoResponseMapper`, `PagedRequest`): `prerequisites.md` (Bloco A.2).

## Exemplos (certo/errado)

Errado — sem contexto: sem `IUseCase`, valida no use case, porta com `page`/`pageSize` soltos, `!`,
expõe `Page<T>`, trata lista vazia como erro:
```csharp
public class GetAccountsPagedUseCase(IAccountRepository repo, IMapper mapper)             // sem interface/IUseCase, sem sealed
{
    public async Task<Result<Page<AccountResponse>>> HandleAsync(                          // HandleAsync; Page<T> da lib vazando; Result<> solto
        GetAccountsPagedRequest request, CancellationToken ct)
    {
        if (request.Page < 1) throw new ArgumentException("invalid page");                 // validação + exceção no use case (CONV-020/029)

        var page = await repo.GetPagedAsync(request.Page!.Value, request.PageSize!.Value, ct); // `!` (CONV-003); sem filtro/ordenação

        if (page.Data.Count == 0)
            return Result.Fail<Page<AccountResponse>>(
                new NotFoundError("No accounts found."));                                  // lista vazia não é not-found

        return Result.Ok(new Page<AccountResponse>(
            mapper.Map<List<AccountResponse>>(page.Data), page.PageInfo));                 // remontando o envelope à mão
    }
}
```

Certo — com contexto: `Account`, filtro por `Currency` (demais arquivos: o template com
`GetAccountsPaged`/`AccountResponse`):
```csharp
using {ApplicationRootNamespace}.Abstractions.UseCases;
using {ApplicationRootNamespace}.Common.Models.Request;
using {ApplicationRootNamespace}.Features.Accounts.Common.Models;
using {SortDirectionNamespace};

namespace {ApplicationRootNamespace}.Features.Accounts.GetAccountsPaged;

public sealed record GetAccountsPagedRequest()
    : PagedRequest(DefaultOrderBy, DefaultOrder),
        IBaseRequest
{
    private const string DefaultOrderBy = nameof(AccountResponse.Balance);

    private const SortDirection DefaultOrder = SortDirection.Ascending;

    public string? Currency { get; init; }
}
```
```csharp
// GetAccountsPagedValidator.cs — trecho
private static readonly string[] AllowedOrderBy =
[
    nameof(AccountResponse.Balance),
    nameof(AccountResponse.Currency)
];
```
```csharp
// GetAccountsPagedMapper.cs — dentro de Register
config.NewConfig<GetAccountsPagedRequest, AccountPagedFilter>()
    .Map(dest => dest.Currency, src => src.Currency)
    .Map(dest => dest.Pagination, src => src);

config.NewConfig<GetAccountsPagedRequest, PaginationParameters>()
    .ConstructUsing(src =>
        new PaginationParameters(
            src.Page.GetValueOrDefault(),
            src.PageSize.GetValueOrDefault(),
            src.OrderBy,
            src.Order));

config.NewConfig<Page<Account>, GetAccountsPagedResponse>()
    .Map(dest => dest.Data, src => src.Data)
    .Map(dest => dest.Pagination, src => src.PageInfo);
```

Diferença: `Request : PagedRequest, IBaseRequest` (CONV-028); envelope `PagedResponse` em vez do `Page<T>` da
lib, com item e mapper do `Common`; a validação é do Validator, que restringe `OrderBy` (CONV-029/038);
página vazia é `WithSuccess`; filtro montado por Mapster e entregue à porta (CONV-031); sem `!`
(CONV-003); operação nomeada `GetAccountsPaged`, verbo + agregado + qualificador (CONV-016).

## Anti-patterns específicos deste padrão (além dos comuns do SKILL.md)
- `FromNotFound`/`Error` para página vazia.
- Validar `Page`/`PageSize`/`OrderBy` dentro do `ExecuteAsync`; `!` em `Page`/`PageSize` (CONV-003).
- Expor `Page<T>` da lib como resposta, criar DTO de paginação próprio, ou remontar envelope/`PageInfo` à mão no use case.
- Passar `page`/`pageSize` soltos à porta em vez de `{Aggregate}PagedFilter`.
- `OrderBy` do cliente sem lista explícita no Validator (ou com default fora dela); `PageSize` sem teto.
- Filtro do `Request` sem o campo no `{Aggregate}PagedFilter` ou sem `.Map` (e vice-versa); response ou mapper de item novo por operação.

## Checklist específico deste padrão (além do comum do SKILL.md)
- [ ] `{Aggregate}PagedFilter` verificado (criado só se faltava); porta com `GetPagedAsync({Aggregate}PagedFilter, CancellationToken)` confirmada.
- [ ] Sempre `WithSuccess`; nenhum `!`; o use case não revalida nada.
- [ ] `Request : PagedRequest(DefaultOrderBy, DefaultOrder), IBaseRequest`; `Response : PagedResponse<List<{Aggregate}Response>>`.
- [ ] Validator: `NotNull` + limites em `Page`/`PageSize` (com teto); `OrderBy` em `AllowedOrderBy`, que contém o default.
- [ ] Mapper com as três configs; todo filtro do `Request` mapeado para o filtro.

## Cenários mínimos do teste de unidade (Harness, passo 3 do SKILL.md)
`IMapper` **real** (CONV-052): `TypeAdapterConfig` com `{Operation}Mapper`, `{Aggregate}ResponseMapper` e `PageInfoResponseMapper` aplicados explicitamente e `Compile()`; mocke só a porta.
- A configuração compila sem membro de destino não mapeado.
- Página com itens: sucesso, `Data` mapeado, `Pagination` igual ao `PageInfo` devolvido.
- Página **vazia** (`TotalElements == 0`): sucesso, `Data` vazio.
- A porta recebe o filtro com os valores do `Request` (filtros + `Page`, `PageSize`, `OrderBy`, `Order`); isso também exercita o `ConstructUsing`.
- `request` nulo: `ArgumentNullException`.
- Validator (teste separado, `{Operation}ValidatorTests`): `Page` nulo ou `< 1`; `PageSize` nulo ou fora de `[1, MaxPageSize]`; `OrderBy` fora de `AllowedOrderBy`: inválidos. `Request` default: válido.
