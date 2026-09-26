# Pré-requisitos comuns dos use cases (verificar; se não existir, criar)

Executar **antes** de qualquer padrão de use case (`get-by-id.md`, `get-paged.md` e os próximos).
Independe da operação: serve para todo use case da Application.

## Procedimento
1. Resolver `{ApplicationRootNamespace}` e `{EntityNamespace}` (passo 2 do Fluxo do `SKILL.md`).
2. Para cada tipo abaixo, procurar **pelo nome** na Application (ex.: Grep `interface IBaseRequest`), não pelo caminho.
   - **Existe** → não criar, editar nem duplicar; usar o namespace onde já está. Divergência que
     importa (tipo base, membros, assinatura, namespace inesperado) → pare e reporte, não sobrescreva.
     Modificadores (`sealed`/`abstract`), nome de campo privado e formatação **não** são divergência.
   - **Não existe** → criar no caminho indicado; um tipo por arquivo (CONV-012), namespace espelhando a pasta (CONV-013).
3. Ordem: Bloco A, A.2, B. Ao terminar, informar o que foi criado e o que foi reaproveitado.

## Bloco A — comum a todos os use cases (Application, uma vez por solution)

```csharp
// Abstractions/UseCases/IBaseRequest.cs
namespace {ApplicationRootNamespace}.Abstractions.UseCases;

public interface IBaseRequest;
```
```csharp
// Abstractions/UseCases/IResponse.cs
namespace {ApplicationRootNamespace}.Abstractions.UseCases;

public interface IResponse;
```
```csharp
// Abstractions/UseCases/IUseCase.cs
namespace {ApplicationRootNamespace}.Abstractions.UseCases;

public interface IUseCase<in TRequest, TResponse>
    where TRequest : IBaseRequest
{
    Task<TResponse> ExecuteAsync(
        TRequest request,
        CancellationToken cancellationToken);
}
```
```csharp
// Common/Models/Response/DataResponse.cs
using {ApplicationRootNamespace}.Abstractions.UseCases;

namespace {ApplicationRootNamespace}.Common.Models.Response;

public abstract record DataResponse<TType> : IResponse
{
    public TType? Data { get; init; }
}
```

### Bloco A.2 — paginação (usado por todo GetPaged)
```csharp
// Common/Models/Response/PageInfoResponse.cs
namespace {ApplicationRootNamespace}.Common.Models.Response;

public sealed record PageInfoResponse
{
    public int Page { get; init; }

    public int PageSize { get; init; }

    public int TotalPages { get; init; }

    public int TotalElements { get; init; }

    public bool? IsFirstPage { get; init; }

    public bool? IsLastPage { get; init; }

    public bool? HasNextPage { get; init; }

    public bool? HasBackPage { get; init; }

    public int? NextPage { get; init; }

    public int? BackPage { get; init; }
}
```
```csharp
// Common/Models/Response/PagedResponse.cs
namespace {ApplicationRootNamespace}.Common.Models.Response;

public abstract record PagedResponse<TType>
    : DataResponse<TType>
{
    public PageInfoResponse? Pagination { get; init; }
}
```
```csharp
// Common/Mappers/PageInfoResponseMapper.cs — PageInfo (lib Pagination) -> PageInfoResponse (CONV-031)
using JacksonVeroneze.NET.Pagination.Offset;
using Mapster;
using {ApplicationRootNamespace}.Common.Models.Response;

namespace {ApplicationRootNamespace}.Common.Mappers;

public sealed class PageInfoResponseMapper : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);

        config.NewConfig<PageInfo, PageInfoResponse>()
            .Map(dest => dest.Page, src => src.Page)
            .Map(dest => dest.PageSize, src => src.PageSize)
            .Map(dest => dest.TotalPages, src => src.TotalPages)
            .Map(dest => dest.TotalElements, src => src.TotalElements)
            .Map(dest => dest.IsFirstPage, src => src.IsFirstPage)
            .Map(dest => dest.IsLastPage, src => src.IsLastPage)
            .Map(dest => dest.HasNextPage, src => src.HasNextPage)
            .Map(dest => dest.HasBackPage, src => src.HasBackPage)
            .Map(dest => dest.NextPage, src => src.NextPage)
            .Map(dest => dest.BackPage, src => src.BackPage);
    }
}
```
```csharp
// Common/Models/Request/PagedRequest.cs
// + using do namespace real de SortDirection (resolver no repo/lib)
namespace {ApplicationRootNamespace}.Common.Models.Request;

public abstract record PagedRequest
{
    private const int DefaultPage = 1;

    private const int DefaultPageSize = 20;

    private readonly int? _page;

    private readonly int? _pageSize;

    private readonly string? _orderBy;

    private readonly SortDirection? _order;

    protected PagedRequest(
        string defaultOrderBy,
        SortDirection defaultOrder)
    {
        ArgumentException.ThrowIfNullOrEmpty(defaultOrderBy);

        _orderBy = defaultOrderBy;
        _order = defaultOrder;

        _page = DefaultPage;
        _pageSize = DefaultPageSize;
    }

    public int? Page
    {
        get => _page;
        init => _page = value != 0 ? value : DefaultPage;
    }

    public int? PageSize
    {
        get => _pageSize;
        init => _pageSize = value != 0 ? value : DefaultPageSize;
    }

    public string? OrderBy
    {
        get => _orderBy;
        init => _orderBy = value ?? _orderBy;
    }

    public SortDirection? Order
    {
        get => _order;
        init => _order = value ?? _order;
    }
}
```
Comportamento (vale para todo padrão paginado): `Page`/`PageSize` nascem 1/20; `0` volta ao default;
`null` explícito **não** volta ao default e valores negativos passam — por isso todo GetPaged gera um
Validator com `NotNull` e limites. `SortDirection` não resolvido: pare **só** se o padrão em execução
for paginado; nos demais, siga sem criar `PagedRequest` e registre isso no resumo final.

## Bloco B — por agregado (independe de GetById ou GetPaged)
`{Aggregate}` = tipo singular (`Account`); `{AggregateFolder}` = pasta plural (`Accounts`).
- Campos do `{Aggregate}Response`: os pedidos pelo usuário; senão, as propriedades públicas relevantes da entidade, desempacotando value objects; dado sensível (ex.: CPF) só se pedido. Liste os campos no resumo final.
- Já existe → faltando campo, acrescente o campo **e** o `.Map`; nunca crie um segundo response do agregado.
- Um `.Map` por membro do response, inclusive os de mesmo nome (CONV-031); todo membro citado precisa existir no response e vice-versa.

```csharp
// Features/{AggregateFolder}/Common/Models/{Aggregate}Response.cs
namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;

public sealed record {Aggregate}Response(
    /* campos de saída, já desempacotados, um por linha */);
```
```csharp
// Features/{AggregateFolder}/Common/Mappers/{Aggregate}ResponseMapper.cs
using Mapster;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;
using {EntityNamespace};                         // namespace real da entidade

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Mappers;

public sealed class {Aggregate}ResponseMapper : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);

        config.NewConfig<{Aggregate}, {Aggregate}Response>()
            .Map(dest => dest.Campo, src => src.CampoDoDominio);
    }
}
```
Exemplo (`Account`, campos vindos de um value object):
```csharp
public sealed record AccountResponse(
    Guid Id,
    decimal Balance,
    string Currency);

// dentro de Register:
config.NewConfig<Account, AccountResponse>()
    .Map(dest => dest.Id, src => src.Id)
    .Map(dest => dest.Balance, src => src.Balance.Amount)
    .Map(dest => dest.Currency, src => src.Balance.Currency);
```

## Anti-patterns
- Duplicar um tipo que já existe (outro namespace, nome ou pasta), ou sobrescrever um existente em vez de reportar divergência.
- Dois tipos no mesmo arquivo.
- Um `{Aggregate}Response` ou mapper de item novo por operação em vez de reusar o do `Common`.
- Mapper por convenção (`NewConfig` sem `.Map` por membro) ou com `.Map` de membro inexistente; classe/record criado sem `sealed` (CONV-064).

## Checklist
- [ ] Todos os itens (Bloco A: 4; A.2: 4; B: 2) foram procurados por nome antes de qualquer criação; só se criou o que faltava.
- [ ] Um `PagedRequest` existente não foi editado; divergência foi reportada.
- [ ] Todo membro do `{Aggregate}Response` tem `.Map`, e nenhum `.Map` aponta para membro inexistente.
- [ ] Resumo final: criado, reaproveitado e campos do response.
