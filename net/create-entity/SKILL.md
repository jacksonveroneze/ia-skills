---
name: create-entity
description: 'Cria o esqueleto de uma entidade / aggregate root de domínio (.NET/C#, camada Domain, com identidade) — ex. Account, Order, Customer, Transaction, Invoice. Gera só construtor privado e factory estática; não gera métodos de mutação/comportamento. Use sempre que o usuário pedir para criar uma entity, entidade, aggregate, aggregate root ou modelo de domínio com identidade, mesmo sem usar o termo. Não use para value objects sem identidade, nem para DTOs/records de request/response.'
---

# Criar Entity / Aggregate Root (.NET / Clean Architecture)

Gera uma entidade de domínio conforme a `dotnet-conventions.md` da raiz do projeto. Esta skill é
a fábrica; as rules são o contrato — cite o CONV pelo ID sempre que justificar uma decisão.

Em conflito entre o Template canônico e os Exemplos abaixo, o Template vence — os exemplos são
reforço didático, não a fonte primária.

## O que gera
Um único arquivo: `{DomainProjectDir}/{Aggregate}/{Name}.cs` — a classe da entidade, com
construtor privado e factory estática. Nada além disso: sem value object, sem método de
comportamento, sem teste, sem registro de DI. Se algum desses faltar como pré-requisito, esta
skill para (ver Pré-condições) em vez de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito tem identidade e ciclo de vida — dois exemplares com o mesmo estado ainda são distintos.
- **NÃO usar:** é um valor sem identidade (é value object, não entidade). É um contrato de borda (é `Request`/`Response`, não entidade).

Esta skill gera só o esqueleto de construção: `sealed class` com identidade, construtor privado
e factory estática (`Create`/`Open`) que valida invariantes de nascimento e retorna
`Result<{Name}>`. Ela não gera métodos de comportamento/mutação (ex.: `Withdraw`, `Cancel`,
`Approve`). Se o pedido incluir comportamento, gere só a construção e avise, ao final, que
comportamento ficou fora do escopo.

## Contrato

### Rules de entidade / Domain
- **CONV-023** Entidade: setter privado, mutação só por método; construção via factory estática `Result<T>` validando invariantes. Sem ctor público sem parâmetros. *Nesta skill:* como nenhum método de mutação é gerado, `get`-only é o padrão; setter privado só onde a propriedade for descrita como mutável ao longo da vida da entidade (ver CoT).
- **CONV-024** Domain NÃO DEVE referenciar EF/ORM nem atributo de persistência (`[Key]`, `[Table]`, `[Column]`). Mapeamento vive na Infrastructure.
- **CONV-025** Value object: imutável, igualdade por valor (`record`/`IEquatable<T>`), auto-validado via factory. *Aqui:* todo valor da entidade é um VO (ex.: `Money`, `AccountNumber`); a entidade só consome, não define VO.
- **CONV-026** Domain guarda só regra de negócio — sem orquestração, I/O ou DTO.
- **CONV-085** Factory (`Create`/`Open` de VO ou entidade) retorna `Result<T>`: invariante violada é `FromInvalid(erro)`; sucesso é `WithSuccess(valor)`.
- **CONV-021 (trecho de Domain)** Erro só do tipo que o declara: campo `private static readonly Error` na própria entidade. Erro compartilhado entre tipos (ex.: not-found) não nasce na entidade: fica em `Domain/Common/DomainErrors.cs`, classe estática por agregado (`{Aggregate}Error`).
- **CONV-059 (trecho de Domain)** Dinheiro é encapsulado no VO `Money` (amount + currency); a entidade nunca guarda `decimal` cru para dinheiro.
- **CONV-060 (trecho de Domain)** O instante entra como **parâmetro** da factory; `TimeProvider` nunca é injetado na entidade.
- **Local desta skill (fora do CONV-063):** termo brasileiro sem tradução (`Cpf`, `Cnpj`, `Cep`) pode ficar no original.

### Rules gerais (dotnet-conventions.md)
- **CONV-020** falha esperada é `Result`; sem `throw` para invariante de nascimento. **CONV-069** sem `null` para erro de negócio.
- **CONV-021** cada erro é `Error.Create("{Name}.{Reason}", ...)` declarado uma vez, com `Code` estável `{Tipo}.{Motivo}`. Sem `Result.Fail("string")` solto, sem hierarquia de `Error`.
- **CONV-059** dinheiro é `decimal`, nunca `float`/`double`. **CONV-060** proibidos `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now` e `DateTimeOffset.UtcNow`; tempo sempre UTC (`DateTimeOffset`).
- **CONV-063** identificadores em inglês. **CONV-064** `sealed`. **CONV-068** `class` para tipo com identidade — nunca `record`.
- **CONV-065** acesso mais restritivo. **CONV-015** `private static readonly Error` em PascalCase.
- **CONV-067** guard clause no início da factory. **CONV-096** preferir imutabilidade (`get`-only).
- **CONV-089** corpo em bloco em todo método; nenhum `=>` (expression-bodied), nem no `Create`.
- **CONV-003** sem `!` (null-forgiving). **CONV-087** nenhum pacote novo sem confirmação.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha o caminho da pasta.

Nota sobre `ToString()`: a entidade é `class`, não `record` (CONV-068) — o `ToString()`
sintetizado do `object` imprime só o nome do tipo, sem vazar propriedade nenhuma. Diferente do
value object, aqui não é preciso sobrescrever.

### Pré-condições
O projeto Domain referencia `JacksonVeroneze.NET.Result` (`Result`, `Result<T>`, `Error`,
`ResultType`). Todo value object que a entidade usa precisa já existir em
`Domain/ValueObjects/`. Esta skill não cria value object, método de comportamento, nem qualquer
outro artefato fora do arquivo descrito em "O que gera": se um pré-requisito estiver ausente,
ela para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Name** — em inglês, PascalCase (`Account`, `Order`); termo brasileiro sem tradução fica no original.
2. **Aggregate** — pasta/agregado dono (normalmente plural: `Accounts`).
3. **Identity** — tipo do Id (`Guid` por padrão, gerado com `Guid.NewGuid()` dentro do `Create`; ou VO de id forte se o projeto usar — aí o Id é `Result<T>` validado antes da entidade).
4. **Estado** — propriedades e tipos (preferir VO; dinheiro é `Money`). Para cada propriedade, diga se ela é fixa no nascimento ou muda depois (mesmo sem comportamento gerado agora).
5. **Invariantes de criação** — o que precisa valer para a entidade nascer válida.

Faltando Name, estado ou invariante e sem inferência segura, pergunte antes de gerar. Não crie
uma invariante que não foi pedida.

## Fluxo (ReAct)
1. **Localizar o projeto Domain.** Encontre o `.csproj` do Domain.
2. **Resolver identificação.** A partir do `.csproj`, resolva `RootNamespace` (preferencial: `dotnet msbuild <Domain.csproj> -getProperty:RootNamespace`; fallback: `<RootNamespace>` do `.csproj`, senão `<AssemblyName>`, senão o nome do arquivo `.csproj` sem extensão). Declare, num bloco só, antes de escrever qualquer coisa: `Name=`, `Aggregate=`, `RootNamespace=`, e o path final `{DomainProjectDir}/{Aggregate}/{Name}.cs`.
3. **Checar existência.** Se `{Aggregate}/{Name}.cs` já existe, pare aqui — não sobrescreva, relate que o arquivo já existe.
4. **Checar usings globais.** Se o Domain já declara `global using JacksonVeroneze.NET.Result`, não repita o `using` no arquivo (`IDE0005` é erro).
5. **Conferir os value objects necessários.** Para cada valor que deveria ser VO, confirme que existe em `Domain/ValueObjects/`. Faltando algum, pare — relate qual VO falta e onde era esperado; não use primitivo cru no lugar dele e não crie o VO aqui.
6. **Modelar** identidade, estado e invariantes de nascimento (CoT abaixo).
7. **Escrever** o arquivo.
8. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem identidade e ciclo de vida? Se não, não é entidade.
- Qual o mínimo de estado? O que é VO, o que é primitivo?
- Para cada propriedade: ela é fixa no nascimento (`get`-only) ou o usuário disse que muda depois (`private set`, mesmo sem método gerado agora — deixa a costura pronta)?
- Quais invariantes valem no nascimento? Cada uma vira `private static readonly Error {Name}.{Reason}` + guard clause com chaves retornando `FromInvalid`.
- A factory precisa de um instante (ex.: `openedAt`)? Entra como parâmetro — nunca `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now` nem `DateTimeOffset.UtcNow` dentro da entidade, e nunca `TimeProvider` injetado nela (CONV-060).
- A entidade tenta I/O, orquestração ou mapeamento? Não é do Domain — remova.
- O pedido incluiu comportamento (ex.: "Withdraw exige saldo suficiente")? Gere só a construção; não crie o método. Avise ao final que comportamento ficou fora do escopo.

## Template canônico
`{RootNamespace}` é placeholder: substitua pelo valor resolvido no passo 2 do Fluxo, nunca copie
literalmente.

```csharp
// using JacksonVeroneze.NET.Result;   // só se não houver global using (passo 4)

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

## Exemplos (certo/errado)
Pedido: "Account com AccountNumber, Balance (Money) e OpenedAt. Abre com depósito inicial não
negativo." (Sem comportamento pedido — só construção.)

Errado — sem contexto: setter e ctor públicos, atributo de EF, `decimal` cru, exceção, API
inexistente:
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

Certo — com contexto (`{DomainProjectDir}/Accounts/Account.cs`):
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
(CONV-025/059); `openedAt` entra como parâmetro, zero `DateTime.Now` (CONV-060); sem atributo de
EF (CONV-024); todas as propriedades `get`-only — nada muda depois do nascimento, porque nenhum
comportamento foi pedido nem gerado; `Error` único, `Code` estável (CONV-021).

## Anti-patterns (recusar)
- Setter público, ctor público, ou `public Account() { }` — quebra invariante.
- `class` sem `sealed`, ou `record` em vez de `class` para tipo com identidade (CONV-064/068).
- `throw` para invariante de nascimento em vez de `Result<{Name}>.FromInvalid(...)` (CONV-020/085).
- `Error` inline/repetido em vez de `private static readonly Error` único por invariante.
- `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now` ou `DateTimeOffset.UtcNow` dentro da entidade; `TimeProvider` injetado na entidade (CONV-060).
- Atributo `[Key]`/`[Table]`/`[Column]` ou referência a `DbContext`/repositório.
- Chamar serviço, repositório, mapper ou fazer I/O de dentro da entidade.
- Expor coleção interna mutável (`List<T>`) — exponha como `IReadOnlyList<T>`.
- Gerar método de comportamento/mutação (`Withdraw`, `Cancel`, ...) — fora do escopo desta skill.
- `private set` numa propriedade sem nenhum método que a use e sem o usuário ter descrito mudança futura — vira código morto; use `get`-only.
- Primitivo cru onde existe (ou cabe) VO — em especial `decimal`/`float`/`double` cru para dinheiro (CONV-059).
- Membro expression-bodied (`=>`) em qualquer método, mesmo o `Create` (CONV-089).
- Lib externa sem confirmação (CONV-087).
- Namespace copiado dos exemplos ou placeholder `{RootNamespace}`/`{Aggregate}` deixado literal.
- Criar o value object que falta, ou qualquer outro artefato fora do escopo, em vez de parar e relatar.

## Checklist + Harness

Checklist (mapeado a CONV):
- [ ] Arquivo em `{DomainProjectDir}/{Aggregate}/{Name}.cs`; namespace `{RootNamespace}.{Aggregate}` com RootNamespace resolvido do `.csproj` (CONV-013).
- [ ] `sealed class`, um tipo por arquivo, file-scoped namespace (CONV-064/068/012/011).
- [ ] Construtor privado; sem ctor público sem parâmetros; construção só via factory `Result<T>` (CONV-023).
- [ ] Propriedade `get`-only por padrão; `private set` só onde o usuário descreveu mudança futura (CONV-023/096).
- [ ] Cada invariante de nascimento tem `private static readonly Error` com `Code` `{Name}.{Reason}` e guard clause com chaves retornando `FromInvalid` (CONV-021/085/065/067).
- [ ] Só as invariantes pedidas — nenhuma inventada.
- [ ] `Create`/`Open` retorna `Result<{Name}>`; `WithSuccess(value)` no caminho feliz (CONV-085).
- [ ] Valor como VO; dinheiro é `Money` (CONV-025/059).
- [ ] Instante (se houver) entra como parâmetro da factory; zero `DateTime.Now`/`.UtcNow`/`DateTimeOffset.Now`/`.UtcNow` e zero `TimeProvider` injetado (CONV-060).
- [ ] Zero atributo/using de EF; zero I/O, orquestração ou DTO (CONV-024/026).
- [ ] Zero método de comportamento/mutação gerado.
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` null-forgiving (CONV-069/020/003).
- [ ] Corpo em bloco em todo método, nenhum `=>` (CONV-089).
- [ ] `using` da lib só se não houver global using; `static readonly` em PascalCase (CONV-015).
- [ ] Identificador em inglês, exceto termo brasileiro sem tradução (exceção local desta skill; CONV-063 não a prevê). Nenhum pacote novo (CONV-087).
- [ ] Nenhum pré-requisito ausente foi criado por esta skill — o que faltava foi relatado, não gerado.

Harness (gate — só conclui quando os dois passam):
1. `dotnet build <Domain.csproj>` sem warning. Com CONV-002 isso cobre analyzer, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Domain.csproj> --verify-no-changes` sem diferença: pega espaço em branco, espaço no fim de linha e quebra de linha.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, etc.)
em vez de reprovar por conteúdo do arquivo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a criação
da entidade como concluída.

Se algum teste já referencia o tipo, ele também precisa estar verde.