---
name: create-repository
description: 'Cria o repositório de um agregado (.NET/C#, Clean Architecture) — a porta na camada Application e a implementação na Infrastructure via JacksonVeroneze.NET.EntityFramework (IEfCoreRepository). Use sempre que o usuário pedir um repository, repositório, porta de persistência ou acesso a dados de um agregado (ex. AccountRepository, OrderRepository), mesmo sem usar o termo. Não use para regra de negócio (Domain) nem para orquestração de caso de uso (create-read-use-case).'
---

# Criar Repository (.NET / Clean Architecture)

Gera o par **porta + implementação** de um agregado conforme a `dotnet-conventions.md` na raiz
do projeto. Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

> ✅ **Verificado contra o código-fonte real**, tag `1.4.0` de
> `github.com/jacksonveroneze/JacksonVeroneze.NET.EntityFramework` (a mesma versão publicada no
> NuGet). O branch `main` do repo está desatualizado (ainda em `1.0.1`, com uma API antiga —
> `IBaseRepository<TEntity, TKey>` + `IUnitOfWork.CommitAsync()`); **não use `main` como
> referência**, use a tag da versão instalada. `IEfCoreRepository<TEntity, TDbContext>` expõe
> `DbContext`/`DbSet` como propriedades, e `GetPagedAsync<TKey>` exige `expression` e
> `orderExpression` — **nenhum dos dois é opcional/anulável** na interface real (diferente de
> uma versão anterior desta skill, que presumia isso).

## O que gera
Dois arquivos, em dois projetos diferentes:
- Porta: `{ApplicationProjectDir}/Abstractions/Repositories/{Aggregate}/I{Aggregate}Repository.cs`
- Impl: `{InfrastructureProjectDir}/Repositories/{Aggregate}Repository.cs`

Cada `{X}ProjectDir` é a pasta do `.csproj` daquele projeto. **Os dois projetos têm
`RootNamespace` próprios** — resolva os dois separadamente (Fluxo, passo 2).

## Escopo (quando usar / NÃO usar)
- **Usar:** dar acesso de persistência a **um agregado** (uma porta por agregado), leitura e/ou escrita conforme os use cases exigirem.
- **NÃO usar:** regra de negócio → Domain. Orquestração → use case. Mapeamento de tabela → `create-persistence-config`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-010** uma porta por agregado, compartilhada pelos slices; nunca uma por use case.
- **CONV-082** a porta de repositório é exceção explícita ao veto de "abstração de implementação única" (CONV-081) — é por isso que essa skill existe.
- **CONV-030** porta vive na Application; sem tipo concreto de infra na assinatura. `Page<{Aggregate}>` na porta é aceitável — é um DTO de paginação (`JacksonVeroneze.NET.Pagination`), não um tipo de infra.
- **CONV-034** impl async + `CancellationToken`; retorna entidade de domínio, `Page<T>` ou `null`; nunca vaza `IQueryable`.
- **CONV-007/008** dependência: Infra → Application; a porta não conhece a impl.
- **CONV-032** Infra sem regra de negócio.
- **CONV-081** sem generic repository **nem unit of work**; o método de mutação faz o `SaveChanges` (limite transacional, 1 agregado por transação) — aqui via `efRepository.DbContext.SaveChangesAsync(...)`.
- **CONV-044/074** `cancellationToken` propagado, nomeado, sem default. **CONV-064** impl `sealed`. **CONV-063** inglês.
- **CONV-088** método que só repassa uma única chamada async (sem processamento depois) NÃO usa `async`/`await` — retorna a `Task` direto com `return`, em corpo de bloco. Duas ou mais chamadas em sequência (ex.: `CreateAsync` + `SaveChangesAsync`) mantêm `async`/`await`.
- **CONV-089** todo método usa corpo em bloco (chaves) — nunca `=>` (expression-bodied), nem para repasse de uma linha.
- **CONV-090** parâmetro de lambda tem nome descritivo do papel (ex.: `filter` num predicado), nunca `x`/`y`/`i` genérico.
- **CONV-013** namespace = `RootNamespace` do `.csproj` de **cada** projeto + pasta — não presuma um único RootNamespace para os dois arquivos.
- **CONV-087** pacote novo só com confirmação — `JacksonVeroneze.NET.EntityFramework` (Infrastructure) e `JacksonVeroneze.NET.Pagination` (Application, porque `Page<T>` aparece na porta) **já estão confirmados** por decisão explícita do Jackson; não pergunte de novo para esses dois.

**Nota — por que não usa `Result`:** repositório não representa falha de negócio (CONV-034); ele
devolve a entidade, `Page<T>` ou `null`. "Não encontrado" como falha de negócio é modelado no use
case (`Result<T>.FromNotFound`), não aqui. Não envolva o retorno da porta em `Result`.

### Pré-condições
A entidade do agregado existe no Domain (se faltar, gere com `create-entity` antes). **EF Core
já é a store decidida do projeto**, mas a impl **não injeta o `DbContext` diretamente** — injeta
`IEfCoreRepository<{Aggregate}, {DbContextType}>` (de `JacksonVeroneze.NET.EntityFramework`,
confirmado na tag `1.4.0` — não use o branch `main`, está desatualizado), que abstrai o
`DbSet`/`DbContext` mas também os expõe como propriedades (`efRepository.DbContext`,
`efRepository.DbSet`) quando precisar. **Não presuma o nome `AppDbContext`**; resolva o nome real
da classe no repo (Fluxo, passo 5) — ele só é usado como argumento genérico, nunca injetado
sozinho. `Application` referencia `JacksonVeroneze.NET.Pagination` (para `Page<T>`/
`PaginationParameters` na porta); `Infrastructure` referencia `JacksonVeroneze.NET.EntityFramework`.
Além dos métodos do catálogo abaixo, a interface também expõe `AnyAsync`, `CountAsync`,
`GetAllAsync`, `GetSingleOrDefaultAsync` e `GetPagedCursorAsync` (paginação por cursor, não por
offset) — não gere wrappers para eles a menos que um use case peça (CONV-081); esta nota existe
só para você saber que estão disponíveis quando precisar. O registro no DI (incluindo como o
`IEfCoreRepository<,>` é registrado) é feito por `register-dependencies`, não aqui — essa skill
ainda não existe.

### Inputs
1. **Aggregate** — nome do agregado (`Account`) e sua pasta (`Accounts`).
2. **Operações necessárias** — só as que os use cases atuais exigem, do catálogo: leitura (`GetByIdAsync`, `GetPagedAsync`) e/ou escrita (`CreateAsync`, `UpdateAsync`, `DeleteAsync`). Não especular CRUD (CONV-081) — o catálogo abaixo mostra como escrever cada uma corretamente quando for pedida, não uma lista para gerar por completo.
3. **IdType** — tipo do identificador (`Guid` por padrão).
4. **RootNamespace** de Application e de Infrastructure — resolvidos por ReAct, não perguntados de cara.

## Fluxo (ReAct)
1. **Localizar os `.csproj` de Application e de Infrastructure.**
2. **Resolver o `RootNamespace` de cada um, separadamente.** Nunca use o namespace dos exemplos desta skill, e nunca presuma que os dois projetos compartilham o mesmo RootNamespace.
   - Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace` para cada projeto.
   - Fallback: `<RootNamespace>` no `.csproj`; senão `<AssemblyName>`; senão o nome do arquivo `.csproj` sem extensão.
   - Namespace da porta = `{ApplicationRootNamespace}.Abstractions.{Aggregate}`.
   - Namespace da impl = `{InfrastructureRootNamespace}.Persistence.Repositories`.
3. **Checar usings globais** de cada projeto — se `JacksonVeroneze.NET.Pagination.Offset` já é `global using` na Application, ou `JacksonVeroneze.NET.EntityFramework.Interfaces` já é `global using` na Infrastructure, não repita o `using` (`IDE0005`).
4. **Ler a entidade** no Domain para tipar o retorno e o `Id`.
5. **Localizar o `DbContext` real do projeto.** Não presuma `AppDbContext` — encontre a classe (ex.: `find . -name "*DbContext.cs"`) e use o nome exato dela como argumento genérico de `IEfCoreRepository<{Aggregate}, {DbContextType}>`. Diferente da versão anterior desta skill, **não é mais necessário ler o `DbSet`** — a lib resolve isso internamente a partir do tipo `{Aggregate}`.
6. **Checar porta existente** do agregado: se já existe, **adicione o método** faltante, não recrie.
7. **Decidir** as operações mínimas — leitura e/ou escrita (CoT). Para `GetPagedAsync`, lembre que `expression` e `orderExpression` são obrigatórios na interface real (não há overload sem eles).
8. **Escrever** porta e impl.
9. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Quais operações os use cases **hoje** precisam? Só essas entram (CONV-081).
- O retorno é **entidade de domínio**, `Page<T>` ou `null`? Nunca DTO de persistência, nunca `IQueryable`, nunca `Result`.
- A assinatura menciona algum tipo de EF/infra (`DbContext`, `DbSet`)? Se sim, está errada — a porta é agnóstica (CONV-030); `IEfCoreRepository<,>` e `{DbContextType}` só aparecem no construtor da **impl**, nunca na porta.
- Um write use case precisa persistir? Use `efRepository.CreateAsync`/`Update`/`Delete` e feche com `efRepository.DbContext.SaveChangesAsync(cancellationToken)` — este é o **limite transacional**, 1 agregado por transação, sem UoW (CONV-081).
- Precisa **excluir**? `DeleteAsync` recebe a entidade e chama `efRepository.Delete(...)` (síncrono) — é **hard delete** por padrão. A lib também tem `efRepository.SoftDelete(...)`, mas hoje ela só chama `Update` por baixo (ver nota abaixo) — não é soft delete pronto para uso. Pergunte antes de assumir hard delete numa entidade que parece precisar de exclusão lógica.
- Precisa de **listagem paginada**? `GetPagedAsync<TKey>(pagination, expression, orderExpression, cancellationToken)` — `expression` (predicado) e `orderExpression` (ordenação) são **obrigatórios** na interface real, sem default nem `?`. Sem filtro pedido, passe `entity => true`; a ordenação default (quando nenhuma foi pedida) é `entity => entity.Id`. Se o use case precisar filtrar de verdade, a porta precisa expor os campos de filtro — não especule isso sem um use case pedindo.
- A `IEfCoreRepository` também tem `SoftDelete(entity)`, mas na versão atual ele só chama `Update` internamente — não marca campo nenhum como excluído nem filtra automaticamente nas próximas queries. Se a entidade precisa de exclusão lógica de verdade, o estado "excluído" tem que vir de um método de comportamento na entidade (fora do escopo de `create-entity` hoje) e o filtro de leitura é configurado à parte (via `create-persistence-config`, ainda não criada) — `SoftDelete` da lib sozinho não resolve isso.
- A impl tem alguma **decisão de negócio**? Isso é do Domain/use case, não do repositório (CONV-032).
- O método repassa **uma única** chamada async, sem nada depois dela? Não use `async`/`await` — retorne a `Task` direto com `return`, em corpo de bloco (nunca `=>`). Só use `async`/`await` quando há duas ou mais chamadas em sequência (CONV-088/089). Note que o exemplo de referência do próprio Jackson (`ProfileRepository`) usa `async`/`await` desnecessário no `GetByIdAsync` — essa skill não repete isso; segue CONV-088.

## Template canônico
`{ApplicationRootNamespace}`/`{InfrastructureRootNamespace}` são placeholders: substitua pelos
valores resolvidos no passo 2 do Fluxo, nunca copie literalmente.

```csharp
// {ApplicationProjectDir}/Abstractions/{Aggregate}/I{Aggregate}Repository.cs
using JacksonVeroneze.NET.Pagination.Offset;   // só se não houver global using (passo 3)

namespace {ApplicationRootNamespace}.Abstractions.{Aggregate};

public interface I{Aggregate}Repository
{
    // leitura — cada método abaixo é opt-in: só entra se um use case precisar (CONV-081)
    Task<{Aggregate}?> GetByIdAsync(
        {IdType} id,
        CancellationToken cancellationToken);

    // GetPagedAsync<TKey> da lib exige filtro e ordenação; aqui a porta fica simples
    // (sem filtro real) — expanda os parâmetros só quando um use case pedir filtro
    Task<Page<{Aggregate}>> GetPagedAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken);

    // escrita — idem, adicionar quando um write use case precisar (não especular)
    Task CreateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken);

    Task UpdateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken);

    Task DeleteAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken);
}
```
```csharp
// {InfrastructureProjectDir}/Persistence/Repositories/{Aggregate}Repository.cs
using JacksonVeroneze.NET.EntityFramework.Interfaces;   // só se não houver global using (passo 3)
using JacksonVeroneze.NET.Pagination.Offset;             // só se não houver global using (passo 3)

namespace {InfrastructureRootNamespace}.Persistence.Repositories;

public sealed class {Aggregate}Repository(
    IEfCoreRepository<{Aggregate}, {DbContextType}> efRepository) : I{Aggregate}Repository
{
    // uma única chamada async, nada depois dela → sem async/await (CONV-088); sempre chaves (CONV-089)
    public Task<{Aggregate}?> GetByIdAsync(
        {IdType} id,
        CancellationToken cancellationToken)
    {
        return efRepository.GetByIdAsync(
            filter => filter.Id == id, cancellationToken);
    }

    // GetPagedAsync<TKey> da IEfCoreRepository — expression e orderExpression são obrigatórios,
    // sem overload sem eles; sem filtro real pedido, usa predicado sempre-verdadeiro
    public Task<Page<{Aggregate}>> GetPagedAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        PaginationParameters pagination = new(page, pageSize);

        return efRepository.GetPagedAsync(
            pagination,
            entity => true,
            entity => entity.Id,
            cancellationToken);
    }

    // duas chamadas async em sequência → precisa de async/await
    public async Task CreateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        await efRepository.CreateAsync(
            {aggregate}, cancellationToken);

        await efRepository.DbContext.SaveChangesAsync(cancellationToken);   // limite transacional (CONV-081)
    }

    // Update() é síncrono; só a Task de SaveChangesAsync é repassada → sem async/await (CONV-088)
    public Task UpdateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        efRepository.Update({aggregate});

        return efRepository.DbContext.SaveChangesAsync(cancellationToken);   // limite transacional (CONV-081)
    }

    // Delete() é síncrono; hard delete — ver CoT para o caso de soft delete
    public Task DeleteAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        efRepository.Delete({aggregate});

        return efRepository.DbContext.SaveChangesAsync(cancellationToken);   // limite transacional (CONV-081)
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — generic repository, síncrono, injeta `DbContext` direto, vaza `IQueryable`, na camada errada:
```csharp
namespace Bank.Infrastructure;                      // porta junto da impl, fora da Application
public interface IRepository<T>                     // generic repository (CONV-081)
{
    IQueryable<T> Query();                           // vaza IQueryable (CONV-034)
    T GetById(int id);                                // síncrono, sem CancellationToken (CONV-044)
}

public class AccountRepository(AppDbContext db)      // injeta DbContext direto — não usa IEfCoreRepository
{
}
```

✅ Com contexto — porta por agregado na Application, impl na Infra via `IEfCoreRepository<,>`:
```csharp
using JacksonVeroneze.NET.Pagination.Offset;

namespace {ApplicationRootNamespace}.Abstractions.Accounts;

public interface IAccountRepository
{
    Task<Account?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken);
}
```
```csharp
using JacksonVeroneze.NET.EntityFramework.Interfaces;

namespace {InfrastructureRootNamespace}.Persistence.Repositories;

public sealed class AccountRepository(
    IEfCoreRepository<Account, {DbContextType}> efRepository) : IAccountRepository
{
    // uma única chamada async, nada depois dela → sem async/await (CONV-088); sempre chaves (CONV-089)
    public Task<Account?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return efRepository.GetByIdAsync(
            filter => filter.Id == id, cancellationToken);
    }
}
```

✅ Forma de escrita (sob demanda, quando um write use case precisar) — `SaveChanges` via `efRepository.DbContext`:
```csharp
// duas chamadas async em sequência → precisa de async/await
public async Task CreateAsync(
    Account account,
    CancellationToken cancellationToken)
{
    await efRepository.CreateAsync(
        account, cancellationToken);

    await efRepository.DbContext.SaveChangesAsync(cancellationToken);   // limite transacional, 1 agregado, sem UoW
}
```

✅ Forma de exclusão (hard delete — ver CoT para quando a entidade precisa de soft delete):
```csharp
// Delete() é síncrono; só a Task de SaveChangesAsync é repassada → sem async/await (CONV-088)
public Task DeleteAsync(
    Account account,
    CancellationToken cancellationToken)
{
    efRepository.Delete(account);

    return efRepository.DbContext.SaveChangesAsync(cancellationToken);   // limite transacional, 1 agregado, sem UoW
}
```

Diferença: porta específica do agregado na Application, com o `RootNamespace` **daquele**
projeto (CONV-010/030/013); retorna `Account?`/`Page<Account>`, não `IQueryable` nem `Result`
(CONV-034); construtor primário injeta `IEfCoreRepository<Account, {DbContextType}>`, **nunca**
o `DbContext` direto; `{DbContextType}` é o nome real da classe no repo, usado só como argumento
genérico; async com `cancellationToken` sem default, um parâmetro por linha, inclusive no
construtor primário com um só parâmetro (CONV-044/074); `GetByIdAsync`/`DeleteAsync`/`UpdateAsync`
repassam uma única chamada async cada, sem `async`/`await`, mas com corpo em bloco (CONV-088/089)
— diferente do exemplo de referência original do Jackson, que usava `async`/`await`
desnecessário nesse ponto; lambda com nome descritivo (`filter`, não `x`/`conf`) (CONV-090);
`CreateAsync` encadeia duas chamadas, por isso mantém `async`/`await` (CONV-088); `SaveChanges`
sempre via `efRepository.DbContext`, nunca um `DbContext` injetado à parte; impl `sealed` na
Infra, com o `RootNamespace` **dela**, não o da Application (CONV-064/007); persistência
confinada ao método de mutação, que é o limite transacional (CONV-081).

## Anti-patterns (recusar)
- `IRepository<T>` genérico, unit of work especulativo.
- Injetar `{DbContextType}` diretamente no construtor da impl — injete `IEfCoreRepository<{Aggregate}, {DbContextType}>`.
- Retornar `IQueryable`/`DbSet` ou expor `.Include(...)` para fora.
- Envolver o retorno da porta em `Result`/`Result<T>` — repositório não representa falha de negócio.
- Método síncrono ou `CancellationToken cancellationToken = default`.
- Porta na Infra, ou tipo de infra (`DbContext`/`IEfCoreRepository`) na assinatura da porta — só `Page<T>` é aceitável, por ser DTO de paginação.
- `SaveChanges` fora do método de mutação, ou chamado num `DbContext` injetado à parte em vez de `efRepository.DbContext` (no use case, ou num UoW genérico).
- Especular `CreateAsync`/`UpdateAsync`/`DeleteAsync`/`GetPagedAsync` que nenhum use case usa ainda.
- Qualquer regra de negócio dentro do repositório.
- Presumir o nome `AppDbContext` sem checar a classe real do projeto.
- Usar o mesmo `RootNamespace` para porta e impl, ou copiar o namespace do exemplo.
- `async`/`await` num método que só repassa uma única chamada async sem processamento depois — retorne a `Task` direto (CONV-088). Não copie o `async`/`await` desnecessário do exemplo de referência original.
- Membro expression-bodied (`=>`) em método, mesmo de uma linha só — sempre corpo em bloco com chaves (CONV-089).
- Parâmetro de lambda genérico (`x`, `y`, `i`, `conf`) em vez de um nome que descreva o papel (`filter`, `item`) (CONV-090).
- Parâmetros do método (ou do construtor primário, mesmo com um só parâmetro) na mesma linha da assinatura — cada parâmetro em sua própria linha, indentado.
- `DeleteAsync` fazendo `Delete` direto numa entidade que precisa de soft delete — sem o método de comportamento na entidade (fora do escopo de `create-entity` hoje), pare e pergunte em vez de assumir hard delete.
- Gerar `GetPagedAsync` sem os parâmetros `expression`/`orderExpression` (são obrigatórios na `IEfCoreRepository`, não há overload sem eles) — ou nomeá-los diferente do que a interface usa.
- Nome de pacote errado (`JacksonVeroneze.NET.EF`, `...EFCore`) — o pacote real é `JacksonVeroneze.NET.EntityFramework`.

## Checklist + Harness
Checklist (CONV):
- [ ] Porta em `{ApplicationProjectDir}/Abstractions/{Aggregate}/`, namespace com o `RootNamespace` da **Application** (CONV-010/030/013).
- [ ] Impl `sealed` em `{InfrastructureProjectDir}/Persistence/Repositories/`, namespace com o `RootNamespace` da **Infrastructure**, implementa a porta (CONV-064/034/013).
- [ ] Construtor primário injeta `IEfCoreRepository<{Aggregate}, {DbContextType}>`, nunca o `DbContext` direto.
- [ ] `using JacksonVeroneze.NET.EntityFramework.Interfaces` (impl) e `using JacksonVeroneze.NET.Pagination.Offset` (porta e impl, se `GetPagedAsync` existir) presentes ou global using confirmado.
- [ ] Nome da classe `DbContext` real confirmado no repo, usado só como argumento genérico — nunca presumido como `AppDbContext`, nunca injetado sozinho.
- [ ] Async + `cancellationToken` nomeado sem default; retorna entidade, `Page<T>` ou `null`, nunca `Result` (CONV-044/074/034).
- [ ] Sem `IQueryable`/`DbContext` na porta; só `Page<T>` como exceção; só operações usadas hoje (CONV-030/081).
- [ ] Método de mutação (se houver) faz `SaveChanges` via `efRepository.DbContext`, dentro do próprio método; sem UoW (CONV-081).
- [ ] Cada parâmetro em sua própria linha, indentado (interface, impl e construtor primário, mesmo com um só parâmetro).
- [ ] Todo método com corpo em bloco (chaves); nenhum `=>` em método (CONV-089).
- [ ] Método com uma única chamada async e nada depois dela não usa `async`/`await` (CONV-088).
- [ ] Lambda com nome descritivo do papel, nunca `x`/`y`/`i`/`conf` (CONV-090).
- [ ] `DeleteAsync` (se houver) é hard delete via `efRepository.Delete`; se a entidade precisa de soft delete, foi confirmado com o usuário em vez de assumido.
- [ ] `GetPagedAsync` (se houver) passa `expression` e `orderExpression` — nunca omitidos, nunca `null` — e usa `entity => true`/`entity => entity.Id` como default quando o use case não pediu filtro/ordenação específicos.
- [ ] Os dois RootNamespaces resolvidos dos respectivos `.csproj`, nenhum placeholder ou exemplo copiado.
- [ ] Nenhum pacote novo sem confirmação, além de `JacksonVeroneze.NET.EntityFramework`/`JacksonVeroneze.NET.Pagination` já aprovados (CONV-087).

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Application.csproj>` sem warnings.
2. `dotnet build <Infrastructure.csproj>` sem warnings. Com CONV-002 os dois cobrem analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
3. `dotnet format <Application.csproj> --verify-no-changes` e o mesmo para Infrastructure.
4. Revisão da porta gerada: grep por termos de infra (`DbContext`, `IQueryable`, `[Key]`, `[Table]`) — deve dar vazio (exceção: `Page<T>` é esperado). Se o repo já tiver um teste de arquitetura automatizado para isso, rode-o em vez do grep.

Se qualquer comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia,
etc.) em vez de reprovar por conteúdo do arquivo, **não trate como passo concluído**: tente
novamente uma vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não
declare a criação do repositório como concluída.

Se algum teste já referencia o tipo, ele também precisa estar verde.