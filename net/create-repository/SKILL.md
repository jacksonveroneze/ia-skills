---
name: create-repository
description: 'Cria o repositório de um agregado (.NET/C#, Clean Architecture) — a porta na camada Application e a implementação na Infrastructure via JacksonVeroneze.NET.EntityFramework (IEfCoreRepository). Use sempre que o usuário pedir um repository, repositório, porta de persistência ou acesso a dados de um agregado (ex. AccountRepository, OrderRepository), mesmo sem usar o termo. Não use para regra de negócio (Domain) nem para orquestração de caso de uso.'
---

# Criar Repository (.NET / Clean Architecture)

Gera o par **porta + implementação** de um agregado conforme a `dotnet-conventions.md` da raiz do
projeto. Esta skill é a fábrica; as rules são o contrato — cite o CONV pelo ID sempre que
justificar uma decisão.

Em conflito entre o Template canônico e os Exemplos abaixo, o Template vence — os exemplos são
reforço didático, não a fonte primária.

## O que gera
Dois arquivos, em dois projetos diferentes. `{X}ProjectDir` é a pasta do `.csproj` daquele
projeto, e **cada projeto tem `RootNamespace` próprio**.

- Porta: `{ApplicationProjectDir}/Abstractions/Repositories/{AggregateFolder}/I{Aggregate}Repository.cs`, namespace `{ApplicationRootNamespace}.Abstractions.Repositories.{AggregateFolder}`.
- Implementação: `{InfrastructureProjectDir}/Repositories/{AggregateFolder}/{Aggregate}Repository.cs`, namespace `{InfrastructureRootNamespace}.Repositories.{AggregateFolder}`.

A porta e a implementação expõem sempre o catálogo completo: `GetByIdAsync`, `GetPagedAsync`,
`CreateAsync`, `UpdateAsync` e `DeleteAsync`. Nada além disso: sem entidade, sem mapeamento de
persistência, sem registro de DI, sem teste. Se algum desses faltar como pré-requisito, esta skill
para (ver Pré-condições) em vez de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** dar acesso de persistência a **um agregado** — uma porta por agregado, com o catálogo completo.
- **NÃO usar:** regra de negócio (é do Domain). Orquestração (é do use case). Mapeamento de tabela. Registro de DI.

## Contrato

### Rules de repositório / Infrastructure
- **CONV-010** Porta de repositório vive na Application, escopo **por agregado** (`IAccountRepository`), compartilhada pelos slices daquele agregado — nunca uma porta por use case.
- **CONV-030** Porta de repositório vive em `Application/Abstractions/Repositories/{AggregateFolder}/`. Application NÃO DEVE referenciar tipo concreto de infra (`DbContext`, provider). *Aqui:* `Page<{Aggregate}>` na assinatura é aceitável — é um DTO de paginação (`JacksonVeroneze.NET.Pagination`), não um tipo de infra.
- **CONV-032** Infrastructure contém só: repositório, configuração de persistência, integração externa. Zero regra de negócio.
- **CONV-034** Repositório implementa a porta; async + `CancellationToken`; retorna entidade, `Page<T>` ou `null`. NÃO DEVE vazar tipo de query do store (`IQueryable`). *Aqui:* `null` significa ausência, não erro de negócio (ver Nota).
- **CONV-007/008 (trecho de dependência)** `Infrastructure` referencia `Application` (+ `Domain`). Camada de baixo NÃO DEVE referenciar camada de cima: a porta não conhece a implementação e a Application não referencia a Infrastructure.
- **CONV-082** A porta de repositório é exceção explícita ao veto de "abstração de implementação única" do CONV-081, justificada por DIP + seam de teste.
- **Local desta skill (catálogo completo):** a porta e a implementação sempre trazem as cinco operações do catálogo, mesmo que nenhum use case as use ainda. É decisão de projeto declarada aqui, não especulação.
- **Local desta skill (`IEfCoreRepository`):** a implementação injeta `IEfCoreRepository<{Aggregate}, {DbContextType}>`, nunca o `DbContext` direto. O `DbContext` só é acessado por `efRepository.DbContext`.
- **Local desta skill (limite transacional):** o método de mutação faz o `SaveChangesAsync` dentro dele mesmo, via `efRepository.DbContext.SaveChangesAsync(cancellationToken)`. Um agregado por transação, sem unit of work.
- **Local desta skill (formatação):** cada parâmetro de método, da interface, da implementação e do construtor primário (mesmo com um só parâmetro), fica em sua própria linha, indentado.

### Rules gerais (dotnet-conventions.md)
- **CONV-081** sem generic repository nem unit of work.
- **CONV-044** `CancellationToken` propagado a toda operação que o aceita. **CONV-074** parâmetro chamado `cancellationToken`, sem valor default.
- **CONV-064** implementação `sealed`. **CONV-066** primary constructor para a injeção. **CONV-063** identificadores em inglês.
- **CONV-069** sem `null` para erro de negócio (ver Nota).
- **CONV-088** `await` só quando o resultado é usado no próprio método ou há mais de uma chamada em sequência. Método que só repassa uma única chamada async retorna a `Task` direto, sem `async`/`await`.
- **CONV-089** todo método usa corpo em bloco (chaves); nunca `=>`, nem para repasse de uma linha.
- **CONV-090** parâmetro de lambda com nome descritivo do papel (ex.: `filter`, `entity`), nunca `x`/`y`/`i`.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha o caminho da pasta — com o `RootNamespace` do `.csproj` de **cada** projeto, sem presumir que os dois são iguais.
- **CONV-087** pacote novo só com confirmação. `JacksonVeroneze.NET.EntityFramework` (Infrastructure) e `JacksonVeroneze.NET.Pagination` (Application, porque `Page<T>` aparece na porta) já estão confirmados; não pergunte de novo para esses dois.

**Nota — por que não usa `Result`:** repositório não representa falha de negócio (CONV-034); ele
devolve a entidade, `Page<T>` ou `null`. "Não encontrado" como falha de negócio é modelado no use
case (`Result<T>.FromNotFound`), não aqui. Não envolva o retorno da porta em `Result`.

### Referência da API (JacksonVeroneze.NET.EntityFramework)
- A referência é o código-fonte do pacote na **tag da versão instalada**.
- `IEfCoreRepository<TEntity, TDbContext>` expõe `DbContext` e `DbSet` como propriedades (`efRepository.DbContext`, `efRepository.DbSet`) e resolve o `DbSet` a partir de `TEntity`.
- `GetPagedAsync<TKey>(pagination, expression, orderExpression, cancellationToken)`: `expression` e `orderExpression` são **obrigatórios e não anuláveis**; não existe overload sem eles.
- `Update(...)` e `Delete(...)` são síncronos. `SoftDelete(...)` só chama `Update` por baixo: não marca campo nenhum como excluído nem filtra as próximas queries.
- A interface também expõe `AnyAsync`, `CountAsync`, `GetAllAsync`, `GetSingleOrDefaultAsync` e `GetPagedCursorAsync` (cursor, não offset). Estão fora do catálogo: não gere wrapper para eles.

### Pré-condições
A entidade do agregado existe em `{DomainProjectDir}/{AggregateFolder}/{Aggregate}.cs`. A Application
referencia o Domain e o pacote `JacksonVeroneze.NET.Pagination`. A Infrastructure referencia a
Application e o pacote `JacksonVeroneze.NET.EntityFramework`. Existe no repo uma classe `DbContext`
real — **não presuma o nome `AppDbContext`**; ele só é usado como argumento genérico, nunca
injetado sozinho. Esta skill não cria entidade, `DbContext`, mapeamento de persistência, registro
de DI, nem qualquer outro artefato fora dos dois arquivos descritos em "O que gera": se um
pré-requisito estiver ausente, ela para e relata o que falta e onde era esperado — sem apontar como
resolver.

### Inputs
1. **Aggregate** — nome da entidade, PascalCase, singular (`Account`, `Order`). `{aggregate}` é o mesmo nome em camelCase.
2. **AggregateFolder** — pasta do agregado, normalmente plural (`Accounts`); é a pasta onde a entidade já está no Domain.
3. **IdType** — tipo do `Id`, lido da entidade (`Guid` por padrão).

`RootNamespace` dos dois projetos, `EntityNamespace` e `DbContextType` são resolvidos pelo Fluxo,
não perguntados. Faltando o agregado e sem inferência segura, pergunte antes de gerar.

## Fluxo (ReAct)
1. **Localizar os `.csproj`** de Domain, Application e Infrastructure.
2. **Resolver identificação.** Nunca use o namespace dos exemplos desta skill, e nunca presuma que os projetos compartilham o mesmo `RootNamespace`.
   - `ApplicationRootNamespace` e `InfrastructureRootNamespace`, cada um do seu `.csproj`. Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace`. Fallback: `<RootNamespace>` do `.csproj`, senão `<AssemblyName>`, senão o nome do arquivo `.csproj` sem extensão.
   - `EntityNamespace` e `IdType`: leia o arquivo da entidade em `{DomainProjectDir}/{AggregateFolder}/{Aggregate}.cs`; o namespace é o da linha `namespace` do arquivo, o tipo é o da propriedade `Id`. Entidade ausente: pare e relate.
   - `DbContextType`: encontre a classe real (ex.: `find . -name "*DbContext.cs"`) e use o nome exato dela. Nenhuma ou mais de uma: pare e pergunte.
   - Declare, num bloco só, antes de escrever qualquer coisa: `Aggregate=`, `AggregateFolder=`, `IdType=`, `EntityNamespace=`, `ApplicationRootNamespace=`, `InfrastructureRootNamespace=`, `DbContextType=`, e o path final dos dois arquivos.
3. **Checar existência.** Se a porta ou a implementação já existe, pare aqui — não sobrescreva nem adicione método; relate qual arquivo já existe.
4. **Conferir referências.** A Application referencia o Domain e `JacksonVeroneze.NET.Pagination`; a Infrastructure referencia a Application e `JacksonVeroneze.NET.EntityFramework`. Faltando alguma, pare e relate o que falta e onde era esperado; não adicione a referência aqui.
5. **Checar usings globais** de cada projeto. Se `EntityNamespace`, `JacksonVeroneze.NET.Pagination.Offset` ou `JacksonVeroneze.NET.EntityFramework.Interfaces` já são `global using` no projeto do arquivo, não repita o `using` (`IDE0005` é erro).
6. **Modelar** as cinco operações (CoT abaixo).
7. **Escrever** porta e implementação.
8. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- A assinatura da porta menciona tipo de EF ou infra (`DbContext`, `DbSet`, `IQueryable`, `IEfCoreRepository`)? Está errada: a porta é agnóstica (CONV-030). `IEfCoreRepository<,>` e `{DbContextType}` só aparecem no construtor da **implementação**.
- O retorno é entidade de domínio, `Page<T>` ou `null`? Nunca DTO de persistência, `IQueryable` nem `Result` (CONV-034). `null` aqui é ausência; o use case decide se vira falha.
- Escrita: `CreateAsync` encadeia duas chamadas async (`efRepository.CreateAsync` e `SaveChangesAsync`), então mantém `async`/`await`. `UpdateAsync` e `DeleteAsync` chamam `Update`/`Delete` (síncronos) e retornam direto a `Task` do `SaveChangesAsync`, sem `async`/`await` (CONV-088). Sempre em corpo de bloco (CONV-089).
- Exclusão: `DeleteAsync` é **hard delete** via `efRepository.Delete(...)`. `SoftDelete` da lib só chama `Update`, então não resolve exclusão lógica. Se o pedido ou a entidade indicar exclusão lógica (ex.: campo de status ou `DeletedAt`), pare e pergunte antes de gerar `DeleteAsync`.
- Paginação: `expression` e `orderExpression` são obrigatórios. Sem filtro pedido, passe `entity => true` e ordene por `entity => entity.Id`. A porta expõe só `page` e `pageSize`; não invente parâmetros de filtro que o usuário não definiu.
- A implementação tem alguma decisão de negócio? Não é do repositório (CONV-032) — remova.
- O método repassa **uma única** chamada async, sem nada depois dela? Sem `async`/`await`, com `return` direto (CONV-088).

## Template canônico
`{ApplicationRootNamespace}`, `{InfrastructureRootNamespace}`, `{EntityNamespace}`, `{AggregateFolder}` e
`{DbContextType}` são placeholders: substitua pelos valores resolvidos no passo 2 do Fluxo, nunca
copie literalmente.

```csharp
// {ApplicationProjectDir}/Abstractions/Repositories/{AggregateFolder}/I{Aggregate}Repository.cs
// using {EntityNamespace};                        // só se não houver global using (passo 5)
// using JacksonVeroneze.NET.Pagination.Offset;    // só se não houver global using (passo 5)

namespace {ApplicationRootNamespace}.Abstractions.Repositories.{AggregateFolder};

public interface I{Aggregate}Repository
{
    Task<{Aggregate}?> GetByIdAsync(
        {IdType} id,
        CancellationToken cancellationToken);

    // GetPagedAsync<TKey> da lib exige filtro e ordenação; a porta fica simples (sem filtro real)
    Task<Page<{Aggregate}>> GetPagedAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken);

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
// {InfrastructureProjectDir}/Repositories/{AggregateFolder}/{Aggregate}Repository.cs
// using {EntityNamespace};                                    // só se não houver global using (passo 5)
// using JacksonVeroneze.NET.EntityFramework.Interfaces;       // só se não houver global using (passo 5)
// using JacksonVeroneze.NET.Pagination.Offset;                // só se não houver global using (passo 5)

namespace {InfrastructureRootNamespace}.Repositories.{AggregateFolder};

public sealed class {Aggregate}Repository(
    IEfCoreRepository<{Aggregate}, {DbContextType}> efRepository) : I{Aggregate}Repository
{
    // uma única chamada async, nada depois dela: sem async/await (CONV-088); sempre chaves (CONV-089)
    public Task<{Aggregate}?> GetByIdAsync(
        {IdType} id,
        CancellationToken cancellationToken)
    {
        return efRepository.GetByIdAsync(
            filter => filter.Id == id, cancellationToken);
    }

    // expression e orderExpression são obrigatórios na lib; sem filtro real pedido, predicado sempre-verdadeiro
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

    // duas chamadas async em sequência: precisa de async/await
    public async Task CreateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        await efRepository.CreateAsync(
            {aggregate}, cancellationToken);

        await efRepository.DbContext
            .SaveChangesAsync(cancellationToken);   // limite transacional
    }

    // Update() é síncrono; só a Task do SaveChangesAsync é repassada: sem async/await (CONV-088)
    public Task UpdateAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        efRepository.Update({aggregate});

        return efRepository.DbContext
            .SaveChangesAsync(cancellationToken);   // limite transacional
    }

    // Delete() é síncrono; hard delete (ver CoT para exclusão lógica)
    public Task DeleteAsync(
        {Aggregate} {aggregate},
        CancellationToken cancellationToken)
    {
        efRepository.Delete({aggregate});

        return efRepository.DbContext
            .SaveChangesAsync(cancellationToken);   // limite transacional
    }
}
```

## Exemplos (certo/errado)
Pedido: "repositório do agregado Account." (`Aggregate=Account`, `AggregateFolder=Accounts`,
`IdType=Guid`.)

Errado — sem contexto: generic repository, síncrono, vaza `IQueryable`, porta junto da
implementação e fora da Application, injeta `DbContext` direto:
```csharp
namespace Bank.Infrastructure;                        // porta junto da impl, fora da Application
public interface IRepository<T>                       // generic repository (CONV-081)
{
    IQueryable<T> Query();                            // vaza IQueryable (CONV-034)
    T GetById(int id);                                // síncrono, sem CancellationToken (CONV-044)
}

public class AccountRepository(AppDbContext db)       // injeta DbContext direto, nome presumido
{
}
```

Certo — com contexto. Porta em
`{ApplicationProjectDir}/Abstractions/Repositories/Accounts/IAccountRepository.cs`:
```csharp
using {EntityNamespace};
using JacksonVeroneze.NET.Pagination.Offset;

namespace {ApplicationRootNamespace}.Abstractions.Repositories.Accounts;

public interface IAccountRepository
{
    Task<Account?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken);

    Task<Page<Account>> GetPagedAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken);

    Task CreateAsync(
        Account account,
        CancellationToken cancellationToken);

    Task UpdateAsync(
        Account account,
        CancellationToken cancellationToken);

    Task DeleteAsync(
        Account account,
        CancellationToken cancellationToken);
}
```

Implementação em `{InfrastructureProjectDir}/Repositories/Accounts/AccountRepository.cs`:
```csharp
using {EntityNamespace};
using JacksonVeroneze.NET.EntityFramework.Interfaces;
using JacksonVeroneze.NET.Pagination.Offset;

namespace {InfrastructureRootNamespace}.Repositories.Accounts;

public sealed class AccountRepository(
    IEfCoreRepository<Account, {DbContextType}> efRepository) : IAccountRepository
{
    public Task<Account?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return efRepository.GetByIdAsync(
            filter => filter.Id == id, cancellationToken);
    }

    public Task<Page<Account>> GetPagedAsync(
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

    public async Task CreateAsync(
        Account account,
        CancellationToken cancellationToken)
    {
        await efRepository.CreateAsync(
            account, cancellationToken);

        await efRepository.DbContext
            .SaveChangesAsync(cancellationToken);
    }

    public Task UpdateAsync(
        Account account,
        CancellationToken cancellationToken)
    {
        efRepository.Update(account);

        return efRepository.DbContext
            .SaveChangesAsync(cancellationToken);
    }

    public Task DeleteAsync(
        Account account,
        CancellationToken cancellationToken)
    {
        efRepository.Delete(account);

        return efRepository.DbContext
            .SaveChangesAsync(cancellationToken);
    }
}
```

Diferença: porta específica do agregado na Application e implementação na Infrastructure, cada
uma com o `RootNamespace` do **seu** projeto (CONV-010/030/013); retorna `Account?`/`Page<Account>`,
não `IQueryable` nem `Result` (CONV-034); construtor primário injeta
`IEfCoreRepository<Account, {DbContextType}>`, nunca o `DbContext` direto, e `{DbContextType}` é o
nome real da classe no repo; async com `cancellationToken` sem default, um parâmetro por linha
(CONV-044/074); `GetByIdAsync`, `GetPagedAsync`, `UpdateAsync` e `DeleteAsync` repassam uma única
chamada async cada, sem `async`/`await` e com corpo em bloco (CONV-088/089); `CreateAsync` encadeia
duas chamadas, por isso mantém `async`/`await`; lambda com nome descritivo (`filter`, `entity`),
nunca `x` (CONV-090); `SaveChanges` sempre via `efRepository.DbContext`, dentro do método de
mutação, que é o limite transacional; implementação `sealed` (CONV-064).

## Anti-patterns (recusar)
- `IRepository<T>` genérico ou unit of work (CONV-081).
- Injetar `{DbContextType}` diretamente no construtor da implementação — injete `IEfCoreRepository<{Aggregate}, {DbContextType}>`.
- Retornar `IQueryable`/`DbSet` ou expor `.Include(...)` para fora (CONV-034).
- Envolver o retorno da porta em `Result`/`Result<T>` — repositório não representa falha de negócio.
- Método síncrono, ou `CancellationToken cancellationToken = default` (CONV-044/074).
- Porta na Infrastructure, ou tipo de infra (`DbContext`, `IEfCoreRepository`) na assinatura da porta — só `Page<T>` é aceitável, por ser DTO de paginação (CONV-030).
- `SaveChangesAsync` fora do método de mutação, ou chamado num `DbContext` injetado à parte em vez de `efRepository.DbContext`.
- Omitir uma operação do catálogo, ou gerar wrapper para método da lib fora do catálogo (`AnyAsync`, `CountAsync`, `GetAllAsync`, `GetSingleOrDefaultAsync`, `GetPagedCursorAsync`).
- Qualquer regra de negócio dentro do repositório (CONV-032).
- Presumir o nome `AppDbContext` sem checar a classe real do projeto.
- Usar o mesmo `RootNamespace` para porta e implementação, copiar o namespace do exemplo, ou deixar placeholder (`{ApplicationRootNamespace}`, `{EntityNamespace}`...) literal.
- `async`/`await` num método que só repassa uma única chamada async sem processamento depois (CONV-088).
- Membro expression-bodied (`=>`) em método, mesmo de uma linha só (CONV-089).
- Parâmetro de lambda genérico (`x`, `y`, `i`) em vez de um nome que descreva o papel (CONV-090).
- Parâmetros do método (ou do construtor primário, mesmo com um só) na mesma linha da assinatura — cada um em sua própria linha, indentado.
- `DeleteAsync` com hard delete numa entidade que indica exclusão lógica sem confirmar com o usuário; tratar `efRepository.SoftDelete` como exclusão lógica pronta.
- `GetPagedAsync` sem `expression`/`orderExpression` (são obrigatórios; não há overload sem eles), ou com esses parâmetros nomeados diferente da interface da lib.
- Nome de pacote errado (`JacksonVeroneze.NET.EF`, `...EFCore`) — o pacote real é `JacksonVeroneze.NET.EntityFramework`. Pacote novo sem confirmação (CONV-087).
- Sobrescrever arquivo existente, ou adicionar método a uma porta que já existe.
- Criar a entidade, o `DbContext`, o mapeamento ou qualquer outro artefato fora do escopo, em vez de parar e relatar.

## Checklist + Harness

Checklist (mapeado a CONV):
- [ ] Os dois arquivos nos paths e namespaces de "O que gera", cada um com o `RootNamespace` do próprio `.csproj`; entidade importada pelo `EntityNamespace` real (CONV-010/030/013).
- [ ] Implementação `sealed`, um tipo por arquivo, file-scoped namespace, implementa a porta, com primary constructor (CONV-064/012/011/066/034).
- [ ] Construtor injeta `IEfCoreRepository<{Aggregate}, {DbContextType}>`, nunca o `DbContext` direto.
- [ ] Nome da classe `DbContext` real confirmado no repo, usado só como argumento genérico — nunca presumido como `AppDbContext`.
- [ ] Usings presentes ou `global using` confirmado; nenhum `using` duplicado.
- [ ] Catálogo completo na porta e na implementação: `GetByIdAsync`, `GetPagedAsync`, `CreateAsync`, `UpdateAsync`, `DeleteAsync`; nada fora dele.
- [ ] Async + `cancellationToken` nomeado, sem default; retorna entidade, `Page<T>` ou `null`, nunca `Result` (CONV-044/074/034).
- [ ] Sem `IQueryable`/`DbContext`/`IEfCoreRepository` na porta; só `Page<T>` como exceção (CONV-030).
- [ ] Método de mutação faz `SaveChangesAsync` via `efRepository.DbContext`, dentro do próprio método; sem unit of work (CONV-081).
- [ ] Cada parâmetro em sua própria linha, indentado (interface, implementação e construtor primário, mesmo com um só parâmetro).
- [ ] Todo método com corpo em bloco (chaves); nenhum `=>` (CONV-089).
- [ ] Método com uma única chamada async e nada depois dela não usa `async`/`await` (CONV-088).
- [ ] Lambda com nome descritivo do papel, nunca `x`/`y`/`i` (CONV-090).
- [ ] `DeleteAsync` é hard delete via `efRepository.Delete`; se a entidade indica exclusão lógica, foi confirmado com o usuário em vez de assumido.
- [ ] `GetPagedAsync` passa `expression` e `orderExpression`, nunca omitidos nem `null`, com `entity => true`/`entity => entity.Id` como default.
- [ ] Zero regra de negócio na implementação (CONV-032).
- [ ] Identificadores em inglês (CONV-063). Nenhum pacote novo além dos dois já aprovados (CONV-087).
- [ ] Nenhum placeholder ou namespace de exemplo copiado.
- [ ] Nenhum pré-requisito ausente foi criado por esta skill — o que faltava foi relatado, não gerado.

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Application.csproj>` sem warning.
2. `dotnet build <Infrastructure.csproj>` sem warning. Com CONV-002, os dois cobrem analyzer, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
3. `dotnet format <Application.csproj> --verify-no-changes` e o mesmo para a Infrastructure, sem diferença.
4. Revisão da porta gerada: grep por termos de infra (`DbContext`, `IQueryable`, `IEfCoreRepository`, `[Key]`, `[Table]`) — deve dar vazio. Se o repo já tiver teste de arquitetura automatizado para isso, rode-o em vez do grep.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, etc.)
em vez de reprovar por conteúdo do arquivo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a criação do
repositório como concluída.

Se algum teste já referencia o tipo, ele também precisa estar verde.