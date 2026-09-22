---
name: create-repository
description: 'Cria o repositório de um agregado (.NET/C#, Clean Architecture) — a porta na camada Application e a implementação na Infrastructure. Use sempre que o usuário pedir um repository, repositório, porta de persistência ou acesso a dados de um agregado (ex. AccountRepository, OrderRepository), mesmo sem usar o termo. Não use para regra de negócio (Domain) nem para orquestração de caso de uso (create-read-use-case).'
---

# Criar Repository (.NET / Clean Architecture)

Gera o par **porta + implementação** de um agregado conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Dois arquivos:
- Porta: `src/Application/Abstractions/{Aggregate}/I{Aggregate}Repository.cs`
- Impl: `src/Infrastructure/Persistence/Repositories/{Aggregate}Repository.cs`

## Escopo (quando usar / NÃO usar)
- **Usar:** dar acesso de persistência a **um agregado** (uma porta por agregado), leitura e/ou escrita conforme os use cases exigirem.
- **NÃO usar:** regra de negócio → Domain. Orquestração → use case. Mapeamento de tabela → `create-persistence-config`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-010** uma porta por agregado, compartilhada pelos slices; nunca uma por use case.
- **CONV-030** porta vive na Application; sem tipo concreto de infra na assinatura.
- **CONV-034** impl async + `CancellationToken`; retorna entidade de domínio (ou `null`); nunca vaza `IQueryable`.
- **CONV-007/008** dependência: Infra → Application; a porta não conhece a impl.
- **CONV-032** Infra sem regra de negócio.
- **CONV-081** sem generic repository **nem unit of work**; o método de mutação faz o `SaveChanges` (limite transacional, 1 agregado por transação).
- **CONV-044/074** `cancellationToken` propagado, nomeado, sem default. **CONV-064** impl `sealed`. **CONV-063** inglês.

### Pré-condições
A entidade do agregado existe no Domain. A impl assume EF Core com um `DbContext` (bootstrap da
Infra) — **a decisão EF vs Event Store ainda está aberta**: a porta é agnóstica e definitiva; a
impl é EF-flavored e provisória até essa decisão. O registro no DI é feito por
`register-dependencies`, não aqui.

### Inputs
1. **Aggregate** — nome do agregado (`Account`) e sua pasta (`Accounts`).
2. **Operações necessárias** — só as que os use cases atuais exigem: leitura (`GetByIdAsync`) e/ou escrita (`AddAsync`/`UpdateAsync`). Não especular CRUD (CONV-081).
3. **IdType** — tipo do identificador (`Guid` por padrão).
4. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace** (`Directory.Build.props` → arquivo do Domain → perguntar).
2. **Ler a entidade** para tipar o retorno e o Id.
3. **Checar porta existente** do agregado: se já existe, **adicione o método** faltante, não recrie.
4. **Decidir** as operações mínimas — leitura e/ou escrita (CoT).
5. **Escrever** porta e impl.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Quais operações os use cases **hoje** precisam? Só essas entram (CONV-081).
- O retorno é **entidade de domínio** ou `null`? Nunca DTO de persistência, nunca `IQueryable`.
- A assinatura menciona algum tipo de EF/infra? Se sim, está errada — a porta é agnóstica (CONV-030).
- Um write use case precisa persistir? Adicione `AddAsync`/`UpdateAsync`; o `SaveChanges` vive **dentro** do método — este é o **limite transacional**, 1 agregado por transação, sem UoW (CONV-081).
- Leitura pura pode usar `AsNoTracking` (mais leve); se a mesma consulta alimenta escrita, mantenha rastreada (ou re-attach no `Update`).
- A impl tem alguma **decisão de negócio**? Isso é do Domain/use case, não do repositório (CONV-032).

## Template canônico
```csharp
// Application/Abstractions/{Aggregate}/I{Aggregate}Repository.cs
namespace {RootNamespace}.Application.Abstractions.{Aggregate};

public interface I{Aggregate}Repository
{
    // leitura
    Task<{Aggregate}?> GetByIdAsync({IdType} id, CancellationToken cancellationToken);

    // escrita — adicionar quando um write use case precisar (não especular)
    Task AddAsync({Aggregate} {aggregate}, CancellationToken cancellationToken);
    Task UpdateAsync({Aggregate} {aggregate}, CancellationToken cancellationToken);
}
```
```csharp
// Infrastructure/Persistence/Repositories/{Aggregate}Repository.cs
namespace {RootNamespace}.Infrastructure.Persistence.Repositories;

public sealed class {Aggregate}Repository(AppDbContext db) : I{Aggregate}Repository
{
    // use o DbSet como nomeado no AppDbContext (o plural nem sempre é +s: Category -> Categories)
    public async Task<{Aggregate}?> GetByIdAsync({IdType} id, CancellationToken cancellationToken)
        => await db.{Aggregate}s.FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task AddAsync({Aggregate} {aggregate}, CancellationToken cancellationToken)
    {
        await db.{Aggregate}s.AddAsync({aggregate}, cancellationToken);
        await db.SaveChangesAsync(cancellationToken);   // limite transacional (CONV-081)
    }

    public async Task UpdateAsync({Aggregate} {aggregate}, CancellationToken cancellationToken)
    {
        db.{Aggregate}s.Update({aggregate});
        await db.SaveChangesAsync(cancellationToken);   // limite transacional (CONV-081)
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — generic repository, síncrono, vaza `IQueryable`, na camada errada:
```csharp
namespace Bank.Infrastructure;                     // porta junto da impl, fora da Application
public interface IRepository<T>                    // generic repository (CONV-081)
{
    IQueryable<T> Query();                          // vaza IQueryable (CONV-034)
    T GetById(int id);                             // síncrono, sem CancellationToken (CONV-044)
}
```
✅ Com contexto — porta por agregado na Application, impl async na Infra:
```csharp
namespace Bank.Application.Abstractions.Accounts;

public interface IAccountRepository
{
    Task<Account?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}
```
```csharp
namespace Bank.Infrastructure.Persistence.Repositories;

public sealed class AccountRepository(AppDbContext db) : IAccountRepository
{
    public async Task<Account?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => await db.Accounts.FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
}
```
✅ Forma de escrita (sob demanda, quando um write use case precisar) — `SaveChanges` no método:
```csharp
public async Task AddAsync(Account account, CancellationToken cancellationToken)
{
    await db.Accounts.AddAsync(account, cancellationToken);
    await db.SaveChangesAsync(cancellationToken);       // limite transacional, 1 agregado, sem UoW
}
```
Diferença: porta específica do agregado na Application (CONV-010/030); retorna `Account?`, não
`IQueryable` (CONV-034); async com `cancellationToken` sem default (CONV-044/074); impl `sealed`
na Infra (CONV-064/007); persistência confinada ao método de mutação, que é o limite transacional (CONV-081).

## Anti-patterns (recusar)
- `IRepository<T>` genérico, unit of work especulativo.
- Retornar `IQueryable`/`DbSet` ou expor `.Include(...)` para fora.
- Método síncrono ou `CancellationToken cancellationToken = default`.
- Porta na Infra, ou entidade EF/atributo na assinatura da porta.
- `SaveChanges` fora do método de mutação (no use case, ou num UoW genérico).
- Especular `AddAsync`/`UpdateAsync`/`DeleteAsync` que nenhum use case usa ainda.
- Qualquer regra de negócio dentro do repositório.

## Checklist + Harness
Checklist (CONV):
- [ ] Porta em `Application/Abstractions/{Aggregate}/`, uma por agregado (CONV-010/030).
- [ ] Impl `sealed` em `Infrastructure/Persistence/Repositories/`, implementa a porta (CONV-064/034).
- [ ] Async + `cancellationToken` nomeado sem default; retorna entidade ou `null` (CONV-044/074/034).
- [ ] Sem `IQueryable`/tipo de EF na porta; só operações usadas hoje (CONV-030/081).
- [ ] Método de mutação (se houver) faz `SaveChanges` no próprio método; sem UoW (CONV-081).
- [ ] RootNamespace do repo, não placeholder.

Harness (gate):
- `dotnet build` de `Application` e `Infrastructure` limpo (CONV-002).
- Teste de arquitetura: `Application` não referencia tipos de EF (§16/CONV-030).
- Analyzers / `.editorconfig` / `BannedSymbols.txt` sem violação.