---
name: create-entity
description: 'Cria uma entidade ou aggregate root de domínio (.NET/C#, camada Domain, com identidade e comportamento) — ex. Account, Order, Customer, Transaction, Invoice. Use sempre que o usuário pedir para criar uma entity, entidade, aggregate, aggregate root ou modelo de domínio com identidade, mesmo sem usar o termo. Não use para value objects sem identidade (create-value-object) nem para DTOs/records de request/response.'
---

# Criar Entity / Aggregate Root (.NET / Clean Architecture)

Gera **uma** entidade de domínio conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID ao justificar decisões.

## O que gera
Um único arquivo: `src/Domain/{Aggregate}/{Name}.cs` — uma `sealed class` com identidade,
propriedades de setter privado, construtor `private`, factory estática (`Create`/`Open`/...)
retornando `Result<{Name}>`, e métodos de comportamento que mutam via setter privado e
retornam `Result`.

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito tem **identidade e ciclo de vida** (dois com o mesmo estado ainda são distintos).
- **NÃO usar:** é valor sem identidade → `create-value-object`. É contrato de borda → `Request`/`Response`.

## Contrato

### Rules enforçadas (CONV)
- **CONV-023** setter privado; mutação só por métodos; construção via factory `Result<T>`; sem ctor público sem parâmetros.
- **CONV-024** sem EF/ORM nem atributos de persistência (`[Key]`, `[Table]`, `[Column]`).
- **CONV-025** usa value objects para valores (ex.: `Money`, `AccountNumber`).
- **CONV-026** só regra de negócio: sem orquestração, I/O ou DTO.
- **CONV-059** dinheiro como `Money`/`decimal`. **CONV-060** tempo entra como **parâmetro**, nunca `DateTime.Now`.
- **CONV-021** falha vira erro tipado (`ValidationError` na criação, `BusinessRuleError` em regra violada) via `Result`.
- **CONV-063** inglês. **CONV-064** `sealed`. **CONV-065/068** `class` para tipo com identidade.

### Pré-condições
Taxonomia de erro (`AppError` + subclasses) em `src/Domain/Common/Errors/` (rule §6) e os value
objects que a entidade usa. Se um VO necessário faltar, gere-o antes com `create-value-object`.

### Inputs
1. **Name** — em inglês, PascalCase (`Account`, `Order`).
2. **Aggregate** — pasta/agregado dono (normalmente o nome no plural: `Accounts`).
3. **Identity** — tipo do Id (`Guid` por padrão; ou VO de id forte se o projeto usar).
4. **Estado** — propriedades e tipos (preferir VOs; dinheiro é `Money`).
5. **Invariantes de criação** — o que precisa valer para a entidade nascer válida.
6. **Comportamentos** — métodos que mutam; os que dependem de tempo recebem o instante por parâmetro (`asOf`/`occurredAt`).
7. **RootNamespace** — resolvido por ReAct.

Faltando Name, estado ou invariantes e sem inferência segura, pergunte antes de gerar.

## Fluxo (ReAct)
1. **Resolver RootNamespace.** `<RootNamespace>` em `src/Directory.Build.props`; senão derive de
   arquivo existente em `src/Domain/**`; só pergunte se o Domain vazio.
2. **Conferir VOs.** Para cada valor que deveria ser VO, verifique se existe; faltando, gere
   primeiro — não use primitivo cru onde cabe VO.
3. **Checar duplicidade.** Se `{Name}.cs` existe, não sobrescreva: relate.
4. **Modelar** identidade, estado, invariantes e comportamentos (CoT abaixo).
5. **Escrever** o arquivo.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem **identidade e ciclo de vida**? Se não, é VO → `create-value-object`.
- Qual o **mínimo de estado**? O que é VO, o que é primitivo?
- Quais invariantes valem **no nascimento** (factory) e quais **em cada transição** (métodos)?
- Cada comportamento: quais **pré-condições** (guard → `BusinessRuleError`)? O que muda no estado?
- Algum comportamento depende de **tempo**? Recebe o instante por parâmetro (CONV-060).
- A entidade tenta **I/O, orquestração ou mapeamento**? Não é do Domain — remova.

## Template canônico
```csharp
namespace {RootNamespace}.Domain.{Aggregate};

public sealed class {Name}
{
    public {IdType} Id { get; }
    // estado com setter privado quando muta; get-only quando imutável
    
    public {VoType} {Prop} { get; private set; }

    private {Name}({IdType} id, /* ... */)
    {
        Id = id;
        // atribuições
    }

    public static Result<{Name}> Create(/* VOs + dados + instante quando aplicável */)
    {
        // invariantes de criação → ValidationError
        if (/* invariante violada */)
        {
            return Result.Fail<{Name}>(
                new ValidationError("<mensagem>"));
        }

        return Result.Ok(new {Name}(/* ... */));
    }

    public Result {Behavior}(/* args + instante quando aplicável */)
    {
        // pré-condições de negócio → BusinessRuleError
        if (/* regra violada */)
        {
            return Result.Fail(
                new BusinessRuleError("<mensagem>"));
        }

        // mutação via setter privado
        return Result.Ok();
    }
}
```

## Exemplos (few-shot ❌/✅)

Pedido: "Account com AccountNumber, Balance (Money) e OpenedAt. Abre com depósito inicial não
negativo. Withdraw exige mesma moeda e saldo suficiente; registra o instante do movimento."

❌ Sem contexto — setters/ctor públicos, atributo EF, `decimal` cru, exceção, relógio direto:
```csharp
public class Account                                   // não-sealed, aberto a herança
{
    [Key] public Guid Id { get; set; }                 // atributo de EF no domínio
    public decimal Balance { get; set; }               // primitivo, mutável de fora

    public void Withdraw(decimal amount)
    {
        if (amount > Balance) throw new InvalidOperationException();  // exceção p/ regra
        Balance -= amount;
        LastMovementAt = DateTime.Now;                 // relógio direto no domínio
    }
    public DateTime LastMovementAt { get; set; }
}
```
✅ Com contexto (`src/Domain/Accounts/Account.cs`):
```csharp
namespace Bank.Domain.Accounts;

public sealed class Account
{
    public Guid Id { get; }
    
    public AccountNumber Number { get; }
    
    public Money Balance { get; private set; }
    
    public DateTimeOffset OpenedAt { get; }
    
    public DateTimeOffset? LastMovementAt { get; private set; }

    private Account(Guid id, AccountNumber number, 
        Money balance, DateTimeOffset openedAt)
    {
        Id = id;
        Number = number;
        Balance = balance;
        OpenedAt = openedAt;
    }

    public static Result<Account> Open(
        AccountNumber number, 
        Money initialDeposit, 
        DateTimeOffset openedAt)
    {
        if (initialDeposit.Amount < 0)
        {
            return Result.Fail<Account>(new ValidationError(
                    "Initial deposit cannot be negative."));
        }

        return Result.Ok(new Account(
            Guid.NewGuid(), number, 
            initialDeposit, openedAt));
    }

    public Result Withdraw(Money amount, DateTimeOffset occurredAt)
    {
        if (amount.Currency != Balance.Currency)
        {
            return Result.Fail(
                new BusinessRuleError("Currency mismatch."));
        }

        if (amount.Amount > Balance.Amount)
        {
            return Result.Fail(
                new BusinessRuleError("Insufficient funds."));
        }

        var updated = Money.Create(
            Balance.Amount - amount.Amount, Balance.Currency);
        
        if (updated.IsFailed)
        {
            return updated.ToResult();
        }

        Balance = updated.Value;
        LastMovementAt = occurredAt;
        
        return Result.Ok();
    }
}
```
Diferença: `sealed class` com ctor privado e setters privados (CONV-023/064); factory `Open`
valida e retorna `Result<Account>` (CONV-023/021); `Withdraw` protege as regras com
`BusinessRuleError` → 422 (CONV-021); usa VOs `Money`/`AccountNumber` (CONV-025/059); tempo por
parâmetro, zero `DateTime.Now` (CONV-060); sem atributo de EF (CONV-024); desempacota
`Result<Money>` só após `IsFailed`, sem `!` (CONV-003).

## Anti-patterns (recusar)
- Setter público, ctor público, ou `public Account() { }` — quebra invariantes.
- `throw` para regra de negócio em vez de `Result.Fail(new BusinessRuleError(...))`.
- `DateTime.Now`/`DateTimeOffset.UtcNow` dentro da entidade.
- Atributos `[Key]`/`[Table]`/`[Column]` ou referência a `DbContext`/repositório.
- Chamar serviço, repositório, mapper ou fazer I/O de dentro da entidade.
- Expor coleção interna mutável (`List<T>`) — exponha como `IReadOnlyList<T>`.

## Checklist + Harness

Checklist (manual, mapeado a CONV):
- [ ] `sealed class`, um tipo por arquivo, file-scoped namespace espelhando a pasta (CONV-064/012/011/013).
- [ ] Construtor `private`; sem ctor público sem parâmetros; construção via factory `Result<T>` (CONV-023).
- [ ] Propriedades com setter privado (ou get-only); mutação só por métodos (CONV-023).
- [ ] Comportamento retorna `Result`; regra → `BusinessRuleError`; criação inválida → `ValidationError` (CONV-021).
- [ ] Valores como VO; dinheiro é `Money` (CONV-025/059).
- [ ] Tempo por parâmetro; zero `DateTime.Now`/`.UtcNow` (CONV-060).
- [ ] Zero atributo/using de EF; zero I/O, orquestração ou DTO (CONV-024/026).
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` (CONV-069/003). Inglês (CONV-063).
- [ ] RootNamespace resolvido do repo, não placeholder.

Harness (gate automatizado — só conclui quando passa):
- `dotnet build` do projeto `Domain` compila sem warning (CONV-002 trata warning como erro).
- Analyzers / `.editorconfig` / `BannedSymbols.txt` sem violação (§16).
- Se algum teste já referencia a entidade, ele está verde.