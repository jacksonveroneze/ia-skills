---
name: create-entity
description: 'Cria o esqueleto de uma entidade / aggregate root de domínio (.NET/C#, camada Domain, com identidade) — ex. Account, Order, Customer, Transaction, Invoice. Gera só construtor privado e factory estática; não gera métodos de mutação/comportamento. Use sempre que o usuário pedir para criar uma entity, entidade, aggregate, aggregate root ou modelo de domínio com identidade, mesmo sem usar o termo. Não use para value objects sem identidade (create-value-object) nem para DTOs/records de request/response.'
---

# Criar Entity / Aggregate Root (.NET / Clean Architecture)

Gera **uma** entidade de domínio conforme a `dotnet-conventions.md` na raiz do projeto.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID ao justificar decisões.

## Escopo desta skill
Gera **só** o esqueleto de construção: `sealed class` com identidade, construtor `private` e
factory estática (`Create`/`Open`/...) que valida invariantes de nascimento e retorna
`Result<{Name}>`. **Esta skill NÃO gera métodos de comportamento/mutação** (ex.: `Withdraw`,
`Cancel`, `Approve`). Se o pedido incluir comportamento, gere só construção agora e avise que
comportamento está fora do escopo desta skill.

## O que gera
Um único arquivo: `{DomainProjectDir}/{Aggregate}/{Name}.cs`, onde `{DomainProjectDir}` é a
pasta do `.csproj` do projeto Domain e `{Aggregate}` a pasta do agregado (ex.: `Accounts/`).

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito tem **identidade e ciclo de vida** (dois com o mesmo estado ainda são distintos).
- **NÃO usar:** é valor sem identidade → `create-value-object`. É contrato de borda → `Request`/`Response`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-023** construção via factory que retorna `Result<T>` validando invariantes; sem ctor público sem parâmetros. Setter privado **só** onde a propriedade for descrita como mutável ao longo da vida da entidade (ver CoT) — sem método que o use, `get`-only é o padrão.
- **CONV-024** sem EF/ORM nem atributos de persistência (`[Key]`, `[Table]`, `[Column]`).
- **CONV-025** usa value objects para valores (ex.: `Money`, `AccountNumber`). Se faltar, gere com `create-value-object` antes.
- **CONV-026** só regra de negócio: sem orquestração, I/O ou DTO.
- **CONV-059** dinheiro como `Money`/`decimal`. **CONV-060** tempo entra como **parâmetro** da factory, nunca `DateTime.Now`/`.UtcNow`.
- **CONV-085** `Create`/`Open` retorna `Result<{Name}>`; invariante de nascimento violada → `FromInvalid(error)`.
- **CONV-021** cada erro é `Error.Create("{Name}.{Reason}", ...)` declarado uma vez, com `Code` estável.
- **CONV-063** inglês, exceto termos brasileiros sem tradução (`Cpf`, `Cnpj`, `Cep`). **CONV-064** `sealed`. **CONV-068** `class` para tipo com identidade — nunca `record`.
- **CONV-065** acesso mais restritivo. **CONV-015** `private static readonly Error` em PascalCase.
- **CONV-087** nenhum pacote novo sem confirmação.

**Nota — `ToString()`:** entidade é `class`, não `record` (CONV-068), então o `ToString()`
sintetizado do `object` imprime só o nome do tipo, não as propriedades. Diferente do VO
(`record`), **não há PII vazando por `ToString()` aqui** — não é preciso sobrescrever.

### Pré-condições
O projeto Domain referencia `JacksonVeroneze.NET.Result` (`Result`, `Result<T>`, `Error`,
`ResultType`). Os value objects que a entidade usa já devem existir — se faltar algum, gere-o
antes com `create-value-object`.

### Inputs
1. **Name** — em inglês, PascalCase (`Account`, `Order`); termo brasileiro sem tradução fica no original.
2. **Aggregate** — pasta/agregado dono (normalmente plural: `Accounts`).
3. **Identity** — tipo do Id (`Guid` por padrão, gerado com `Guid.NewGuid()` dentro do `Create`; ou VO de id forte se o projeto usar — nesse caso o Id é `Result<T>` validado antes da entidade).
4. **Estado** — propriedades e tipos (preferir VOs; dinheiro é `Money`). Para cada propriedade, o usuário descreve se ela é fixa no nascimento ou muda depois (mesmo sem comportamento gerado agora).
5. **Invariantes de criação** — o que precisa valer para a entidade nascer válida.
6. **RootNamespace** — resolvido por ReAct, não perguntado de cara.

Faltando Name, estado ou invariantes e sem inferência segura, pergunte antes de gerar.
**Não invente invariante que o usuário não pediu.**

## Fluxo (ReAct)
1. **Localizar o projeto Domain e a pasta do agregado.** Encontre o `.csproj` do Domain; verifique se `{Aggregate}/` já existe.
2. **Resolver RootNamespace a partir desse `.csproj`.** Nunca use o namespace dos exemplos desta skill.
   - Preferencial: `dotnet msbuild <Domain.csproj> -getProperty:RootNamespace`.
   - Fallback: `<RootNamespace>` no `.csproj`; senão `<AssemblyName>`; senão o nome do arquivo `.csproj` sem extensão.
   - Namespace da entidade = `{RootNamespace}.{Aggregate}`.
3. **Checar usings globais.** Se o Domain já declara `global using JacksonVeroneze.NET.Result`, não repita o `using` no arquivo (`IDE0005` é erro).
4. **Conferir VOs.** Para cada valor que deveria ser VO, verifique se existe; faltando, gere primeiro com `create-value-object` — não use primitivo cru onde cabe VO.
5. **Checar duplicidade.** Se `{Aggregate}/{Name}.cs` já existe, não sobrescreva: relate.
6. **Modelar** identidade, estado e invariantes de nascimento (CoT abaixo).
7. **Escrever** o arquivo.
8. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem **identidade e ciclo de vida**? Se não, é VO → `create-value-object`.
- Qual o **mínimo de estado**? O que é VO, o que é primitivo?
- Para cada propriedade: ela é **fixa no nascimento** (`get`-only) ou o usuário disse que **muda depois** (`private set`, mesmo sem método gerado agora — deixa a costura pronta)?
- Quais invariantes valem **no nascimento**? Cada uma vira `private static readonly Error {Name}.{Reason}` + guard clause **com chaves** retornando `FromInvalid`.
- A factory precisa de um **instante** (ex.: `openedAt`)? Entra como parâmetro — nunca `DateTime.Now`/`.UtcNow` dentro da entidade (CONV-060).
- A entidade tenta **I/O, orquestração ou mapeamento**? Não é do Domain — remova.
- O pedido incluiu **comportamento** (ex.: "Withdraw exige saldo suficiente")? Gere só a construção; não crie o método. Avise ao final que o comportamento ficou fora do escopo desta skill.

## Template canônico
`{RootNamespace}` é placeholder: substitua pelo valor resolvido no passo 2 do Fluxo, nunca
copie literalmente.

```csharp
// using JacksonVeroneze.NET.Result;   // só se não houver global using (passo 3)

namespace {RootNamespace}.{Aggregate};

public sealed class {Name}
{
    private static readonly Error {Reason} =
        Error.Create("{Name}.{Reason}", "<mensagem clara>");

    public {IdType} Id { get; }

    // get-only quando fixa no nascimento; private set só se o usuário descreveu mudança futura
    public {PropType} {Prop} { get; }

    private {Name}({IdType} id, /* ... */)
    {
        Id = id;
        // atribuições
    }

    public static Result<{Name}> Create(/* VOs + dados + instante quando aplicável */)
    {
        if (/* invariante de nascimento violada */)
        {
            return Result<{Name}>.FromInvalid({Reason});
        }

        return Result<{Name}>.WithSuccess(
            new {Name}(Guid.NewGuid(), /* ... */));
    }
}
```

## Exemplo (few-shot ❌/✅)
Pedido: "Account com AccountNumber, Balance (Money) e OpenedAt. Abre com depósito inicial não
negativo." (Sem comportamento pedido — só construção.)

❌ Sem contexto — setters/ctor públicos, atributo EF, `decimal` cru, exceção, API inexistente:
```csharp
public class Account                                   // não-sealed, aberto a herança
{
    [Key] public Guid Id { get; set; }                 // atributo de EF no domínio
    public decimal Balance { get; set; }                // primitivo, mutável de fora

    public static Account Create(decimal balance)
    {
        if (balance < 0) throw new ArgumentException(); // exceção p/ regra; sem chaves
        return new Account { Id = Guid.NewGuid(), Balance = balance };
    }
}
```

✅ Com contexto (`{DomainProjectDir}/Accounts/Account.cs`):
```csharp
using JacksonVeroneze.NET.Result;

namespace {RootNamespace}.Accounts;

public sealed class Account
{
    private static readonly Error InitialDepositNegative =
        Error.Create("Account.InitialDepositNegative", 
            "Initial deposit cannot be negative.");

    public Guid Id { get; }

    public AccountNumber Number { get; }

    public Money Balance { get; }

    public DateTimeOffset OpenedAt { get; }

    private Account(Guid id, AccountNumber number, 
        Money balance, DateTimeOffset openedAt)
    {
        Id = id;
        Number = number;
        Balance = balance;
        OpenedAt = openedAt;
    }

    public static Result<Account> Open(
        AccountNumber number, Money initialDeposit, 
        DateTimeOffset openedAt)
    {
        if (initialDeposit.Amount < 0)
        {
            return Result<Account>
                .FromInvalid(InitialDepositNegative);
        }

        return Result<Account>.WithSuccess(
            new Account(Guid.NewGuid(), 
                number, initialDeposit, openedAt));
    }
}
```
Diferença: `sealed class` com ctor privado (CONV-023/064); `Open` valida e retorna
`Result<Account>` via `FromInvalid`/`WithSuccess` (CONV-085); usa VOs `Money`/`AccountNumber`
(CONV-025/059); `openedAt` entra como parâmetro, zero `DateTime.Now` (CONV-060); sem atributo
de EF (CONV-024); todas as propriedades `get`-only — nada muda depois do nascimento, porque
nenhum comportamento foi pedido nem gerado; `Error` único, `Code` estável (CONV-021).

## Anti-patterns (recusar)
- Setter público, ctor público, ou `public Account() { }` — quebra invariantes.
- `class` sem `sealed`, ou `record` em vez de `class` para tipo com identidade (CONV-064/068).
- `throw` para invariante de nascimento em vez de `Result<{Name}>.FromInvalid(...)`.
- `Error` inline/repetido em vez de `private static readonly Error` único por invariante.
- `DateTime.Now`/`DateTimeOffset.UtcNow` dentro da entidade.
- Atributos `[Key]`/`[Table]`/`[Column]` ou referência a `DbContext`/repositório.
- Chamar serviço, repositório, mapper ou fazer I/O de dentro da entidade.
- Expor coleção interna mutável (`List<T>`) — exponha como `IReadOnlyList<T>`.
- Gerar método de comportamento/mutação (`Withdraw`, `Cancel`, ...) — fora do escopo desta skill.
- `private set` numa propriedade sem nenhum método que a use e sem o usuário ter descrito mudança futura — vira código morto; use `get`-only.
- Primitivo cru onde existe (ou cabe) VO.
- Lib externa sem confirmação (CONV-087).
- Namespace copiado dos exemplos ou placeholder `{RootNamespace}`/`{Aggregate}` deixado literal.

## Checklist + Harness

Checklist (mapeado a CONV):
- [ ] Arquivo em `{DomainProjectDir}/{Aggregate}/{Name}.cs`; namespace `{RootNamespace}.{Aggregate}` com RootNamespace resolvido do `.csproj` (CONV-013).
- [ ] `sealed class`, um tipo por arquivo, file-scoped namespace (CONV-064/068/012/011).
- [ ] Construtor `private`; sem ctor público sem parâmetros; construção só via factory `Result<T>` (CONV-023).
- [ ] Propriedades `get`-only por padrão; `private set` só onde o usuário descreveu mudança futura (CONV-023).
- [ ] Cada invariante de nascimento tem `private static readonly Error` com `Code` `{Name}.{Reason}` e guard clause **com chaves** retornando `FromInvalid` (CONV-021/085/065).
- [ ] Só as invariantes pedidas — nenhuma inventada.
- [ ] `Create`/`Open` retorna `Result<{Name}>`; `WithSuccess(value)` no caminho feliz (CONV-085).
- [ ] Valores como VO; dinheiro é `Money` (CONV-025/059).
- [ ] Instante (se houver) entra como parâmetro da factory; zero `DateTime.Now`/`.UtcNow` (CONV-060).
- [ ] Zero atributo/using de EF; zero I/O, orquestração ou DTO (CONV-024/026).
- [ ] Zero método de comportamento/mutação gerado.
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` null-forgiving (CONV-069/003).
- [ ] `using` da lib só se não houver global using; `static readonly` em PascalCase (CONV-015).
- [ ] Identificadores em inglês, exceto termos brasileiros sem tradução (CONV-063). Nenhum pacote novo (CONV-087).

Harness (gate — só conclui quando os dois passam):
1. `dotnet build <Domain.csproj>` sem warnings. Com CONV-002 isso cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Domain.csproj> --verify-no-changes` sem diferenças: pega whitespace, espaço no fim de linha e quebras de linha.

Se qualquer comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia,
etc.) em vez de reprovar por conteúdo do arquivo, **não trate como passo concluído**: tente
novamente uma vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não
declare a criação da entidade como concluída.

Se algum teste já referencia o tipo, ele também precisa estar verde.