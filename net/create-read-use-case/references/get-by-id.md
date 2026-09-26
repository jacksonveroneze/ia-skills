# Padrão: busca por identificador único (GetById)

Use quando o pedido é localizar **um** registro pelo `Id` do agregado. Ausência é resultado
esperado, modelado como `NotFound` — nunca sucesso vazio nem exceção.

`{Operation}` = `GetById{Aggregate}` (ex.: `GetByIdAccount`). Placeholders e regras comuns: `SKILL.md`.
Arquivos (em `Features/{AggregateFolder}/{Operation}/`): `Request`, `Response`,
`I{Operation}UseCase`, `{Operation}UseCase`, `{Operation}Mapper`.

## Raciocínio antes de escrever (CoT) — específico deste padrão
- Antes de gerar: (1) `DomainErrors.{Aggregate}Error.NotFound` — existindo, use; não existindo, adicione seguindo o padrão dos vizinhos; `DomainErrors` inexistente → pare e pergunte; (2) `I{Aggregate}Repository.GetByIdAsync` existe? Se faltar, estenda a porta (`create-repository`); (3) qualifique o tipo da entidade inline só se houver ambiguidade de nome.
- Ausente é esperado → `FromNotFound(DomainErrors.{Aggregate}Error.NotFound)`, nunca exceção (CONV-085/021). O erro vive no Domain: sem `Error` local.
- `{Operation}Response` é só o envelope `DataResponse<{Aggregate}Response>`; a forma do dado e o mapper dela são do `Common` (`prerequisites.md`). O mapper da operação só liga `Data <- src`; todo membro explícito (CONV-031).

## Template canônico

```csharp
// {Operation}Request.cs
using {ApplicationRootNamespace}.Abstractions.UseCases;

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed record {Operation}Request(
    Guid Id) : IBaseRequest;
```
```csharp
// {Operation}Response.cs
using {ApplicationRootNamespace}.Common.Models.Response;
using {ApplicationRootNamespace}.Features.{AggregateFolder}.Common.Models;

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed record {Operation}Response
    : DataResponse<{Aggregate}Response>;
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
using MapsterMapper;                                          // só se não houver global using
using {ApplicationRootNamespace}.Abstractions.{AggregateFolder};
using {EntityNamespace};                         // namespace real da entidade
// + using do namespace real de DomainErrors, se não houver global using

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

        var entity = await repository
            .GetByIdAsync(request.Id, cancellationToken);

        if (entity is null)
        {
            return Result.Result<{Operation}Response>
                .FromNotFound(DomainErrors.{Aggregate}Error.NotFound);
        }

        var response = mapper
            .Map<{Aggregate}, {Operation}Response>(entity);

        return Result.Result<{Operation}Response>
            .WithSuccess(response);
    }
}
```
```csharp
// {Operation}Mapper.cs — só liga Data <- entidade; a forma do dado é do Common
using Mapster;
using {EntityNamespace};

namespace {ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation};

public sealed class {Operation}Mapper : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);

        config.NewConfig<{Aggregate}, {Operation}Response>()
            .Map(dest => dest.Data, src => src);
    }
}
```
`{Aggregate}Response` e `{Aggregate}ResponseMapper` (Common): template em `prerequisites.md` (Bloco B).

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — MediatR, `DbContext` na Application, exceção para not-found, erro e log no use case:
```csharp
public class GetAccountByIdHandler(AppDbContext db, ILogger<GetAccountByIdHandler> logger)   // infra na Application (CONV-030/072); logger
    : IRequestHandler<GetAccountByIdQuery, GetAccountByIdResponse>                            // MediatR, não IUseCase
{
    private static readonly Error NotFound = Error.Create("x", "y");                          // erro local; deveria ser DomainErrors

    public async Task<GetAccountByIdResponse> Handle(                                          // deveria ser ExecuteAsync
        GetAccountByIdQuery q, CancellationToken ct)
    {
        var a = await db.Accounts.FindAsync(q.Id)
            ?? throw new NotFoundException();                                                  // exceção p/ fluxo (CONV-021)
        logger.LogInformation("found {Balance}", a.Balance);                                   // log + dado sensível (CONV-054)
        return new GetAccountByIdResponse(a.Id, a.Balance.Amount, a.Balance.Currency);         // campos duplicados no response
    }
}
```

✅ Com contexto — `Account` (demais arquivos: o template com `GetByIdAccount`/`AccountResponse`):
```csharp
using MapsterMapper;
using {ApplicationRootNamespace}.Abstractions.Accounts;
using {EntityNamespace};

namespace {ApplicationRootNamespace}.Features.Accounts.GetByIdAccount;

public sealed class GetByIdAccountUseCase(
    IMapper mapper,
    IAccountRepository repository) : IGetByIdAccountUseCase
{
    public async Task<Result.Result<GetByIdAccountResponse>> ExecuteAsync(
        GetByIdAccountRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var entity = await repository
            .GetByIdAsync(request.Id, cancellationToken);

        if (entity is null)
        {
            return Result.Result<GetByIdAccountResponse>
                .FromNotFound(DomainErrors.AccountError.NotFound);
        }

        var response = mapper
            .Map<Account, GetByIdAccountResponse>(entity);

        return Result.Result<GetByIdAccountResponse>
            .WithSuccess(response);
    }
}
```
```csharp
// GetByIdAccountMapper.cs — dentro de Register
config.NewConfig<Account, GetByIdAccountResponse>()
    .Map(dest => dest.Data, src => src);
```

Diferença: depende da porta e de `IUseCase<,>`, não do `DbContext`/MediatR; o erro vem de `DomainErrors`, sem logger; `FromNotFound` em vez de exceção; `Response` é só envelope e o dado é do `Common`.

## Anti-patterns específicos deste padrão (além dos gerais do SKILL.md)
- Exceção ou `null` para not-found; `Error`/`NotFoundError` declarado no use case (o erro vem de `DomainErrors.{Aggregate}Error.NotFound`).
- Campos declarados em `{Operation}Response`; response ou mapper de item novo por operação; mapper da operação com `.Map` além de `Data <- src`.

## Checklist específico deste padrão (além do geral do SKILL.md)
- [ ] Not-found → `FromNotFound(DomainErrors.{Aggregate}Error.NotFound)`; nenhum `Error` local.
- [ ] `Response : DataResponse<{Aggregate}Response>` sem campos; mapper da operação só com `Data <- src`; response e mapper de item do `Common` reaproveitados.

## Cenários mínimos do teste de unidade (Harness, passo 3 do SKILL.md)
`IMapper` **real** (CONV-052): `TypeAdapterConfig` com `{Operation}Mapper` e `{Aggregate}ResponseMapper` aplicados explicitamente e `Compile()`; mocke só a porta.
- Porta retorna a entidade → sucesso, `Data` com todos os campos mapeados.
- Porta retorna `null` → falha `ResultType.NotFound` com o erro de `DomainErrors.{Aggregate}Error.NotFound` (mesmo `Code`) (CONV-053).
- `request` nulo → `ArgumentNullException`.
- A configuração compila sem membro de destino não mapeado.
