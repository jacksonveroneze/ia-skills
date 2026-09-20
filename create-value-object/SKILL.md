---
name: create-value-object
description: 'Cria um value object de domínio (.NET/C#, camada Domain, sem identidade) — tipos de valor como Money, Cpf, Cnpj, Email, AccountNumber, Cep, Currency, PhoneNumber. Use sempre que o usuário pedir um value object, VO ou tipo de valor, mesmo sem usar o termo (ex. um tipo para representar dinheiro, ou um Cpf com validação). Não use para entidades com identidade (create-entity) nem para DTOs de request/response.'
---

# Criar Value Object (.NET / Clean Architecture)

Gera **um** value object (VO) de domínio conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID ao justificar decisões.

## O que gera
Um único arquivo: `src/Domain/{Aggregate}/{Name}.cs` (VO de agregado) **ou**
`src/Domain/Common/{Name}.cs` (VO compartilhado, ex.: `Money`). O tipo é um `sealed record`
imutável, construído só pela factory estática `Create(...)`.

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito é um **valor sem identidade** (dois iguais são intercambiáveis).
- **NÃO usar:** tem identidade/ciclo de vida → `create-entity`. É contrato de borda → é `Request`/`Response`, não VO.

## Contrato

### Rules enforçadas (CONV)
- **CONV-025** VO imutável, igualdade por valor, auto-validado via factory.
- **CONV-059** dinheiro é `decimal` no VO `Money`; nunca `float`/`double`.
- **CONV-021 / CONV-069** falha vira erro tipado (`ValidationError`) via `Result` — nunca `null`, nunca `throw` para regra.
- **CONV-063** identificadores em inglês. **CONV-064** `sealed`. **CONV-065** acesso mais restritivo.
- **CONV-006 / CONV-024** Domain puro: sem EF/ORM, sem atributo de persistência, sem I/O.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha a pasta.

### Pré-condições
Taxonomia de erro (`AppError` + `ValidationError`, ...) em `src/Domain/Common/Errors/`
(componente compartilhado da rule §6). Se não existir, crie-a antes — é a única dependência.

### Inputs
1. **Name** — em inglês, PascalCase (`Money`, `AccountNumber`, `Cpf`).
2. **Escopo** — `Common` (compartilhado) ou o agregado dono (`Accounts`).
3. **Fields** — o(s) valor(es) encapsulado(s) e tipo(s).
4. **Invariantes** — as regras de validação (formato, faixa, obrigatoriedade).
5. **RootNamespace** — resolvido por ReAct, não perguntado de cara.

Faltando Name, Fields ou Invariantes e sem inferência segura, pergunte antes de gerar. Não
invente invariante que o usuário não pediu.

## Fluxo (ReAct)
1. **Resolver RootNamespace.** `<RootNamespace>` em `src/Directory.Build.props`; senão derive
   do `namespace` de um arquivo existente em `src/Domain/**`; só pergunte se o Domain vazio.
2. **Checar duplicidade.** Se `{Name}.cs` já existe no escopo alvo, não sobrescreva: relate.
3. **Alinhar estilo** a um VO irmão, se houver.
4. **Decidir** membros e invariantes (CoT abaixo).
5. **Escrever** o arquivo no caminho correto.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem **identidade**? Se sim, é entity → pare e use `create-entity`.
- Quais campos são **parte do valor** (entram na igualdade)? Todos entram.
- Qual o **mínimo de invariantes** para o valor ser sempre válido? Cada uma vira guard clause.
- Há **normalização** natural (trim, upper/lower, tirar máscara)? Só depois de validar.
- Precisa de **comportamento** (ex.: `Money.Add`)? Operação que pode falhar retorna `Result<T>`.

## Template canônico
```csharp
namespace {RootNamespace}.Domain.{Scope};

public sealed record {Name}
{
    public {FieldType} {FieldName} { get; }
    // ... demais campos get-only

    private {Name}({FieldType} {fieldParam} /* ... */)
    {
        {FieldName} = {fieldParam};
    }

    public static Result<{Name}> Create({FieldType} {fieldParam} /* ... */)
    {
        // guard clauses → ValidationError por invariante violada (CONV-021/069)
        if (/* invariante violada */)
        {
            return Result.Fail<{Name}>(
                new ValidationError("<mensagem clara>"));
        }

        // normalização opcional só após validar
        return Result.Ok(new {Name}(/* valores normalizados */));
    }
}
```

## Exemplos (few-shot ❌/✅)

Pedido: "Money com amount e currency; amount não pode ser negativo; currency ISO de 3 letras."

❌ Sem contexto — record posicional público, `double`, exceção para fluxo:
```csharp
public record Money(double Amount, string Currency)          // público e mutável via with
{
    public static Money Create(double amount, string currency)
    {
        if (amount < 0) throw new ArgumentException("negative");  // exceção p/ regra esperada
        return new Money(amount, currency);                       // sem validar currency
    }
}
```
✅ Com contexto:
```csharp
namespace Bank.Domain.Common;

public sealed record Money
{
    public decimal Amount { get; }
    
    public string Currency { get; }

    private Money(decimal amount, string currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public static Result<Money> Create(
        decimal amount, string currency)
    {
        if (amount < 0)
        {
            return Result.Fail<Money>(
                new ValidationError("Amount cannot be negative."));
        }

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
        {
            return Result.Fail<Money>(
                new ValidationError("Currency must be a 3-letter ISO code."));
        }

        return Result.Ok(new Money(
            amount, currency.ToUpperInvariant()));
    }
}
```
Diferença: `sealed record` com ctor privado — construção só via `Create` (CONV-025/064); `decimal`
em vez de `double` (CONV-059); `Result`+`ValidationError` em vez de `throw` (CONV-021/069);
toda invariante virou guard clause.

Segundo caso (✅, um campo com formato) — `AccountNumber` no agregado `Accounts`:
```csharp
namespace Bank.Domain.Accounts;

public sealed record AccountNumber
{
    public string Value { get; }

    private AccountNumber(string value) => Value = value;

    public static Result<AccountNumber> Create(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return Result.Fail<AccountNumber>(
                new ValidationError("Account number is required."));
        }

        if (value.Length != 10 || !value.All(char.IsDigit))
        {
            return Result.Fail<AccountNumber>(
                new ValidationError("Account number must be 10 digits."));
        }

        return Result.Ok(new AccountNumber(value));
    }
}
```

## Anti-patterns (recusar)
- Construtor público, positional record ou setter — quebra construção validada.
- `throw` para valor inválido em vez de `Result.Fail`.
- `float`/`double` para dinheiro.
- Atributos `[Key]`/`[Column]` ou referência a `DbContext`.
- `class` sem `IEquatable` (igualdade por referência) para algo que é valor.

## Checklist + Harness

Checklist (manual, mapeado a CONV):
- [ ] `sealed record`, um tipo por arquivo, file-scoped namespace espelhando a pasta (CONV-064/012/011/013).
- [ ] Construtor `private`; construção só via `Create` (CONV-025/065).
- [ ] `Create` retorna `Result<{Name}>`; cada invariante é guard clause com `ValidationError` (CONV-021/069).
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` null-forgiving (CONV-069/003).
- [ ] Dinheiro é `decimal` (CONV-059). Identificadores em inglês (CONV-063).
- [ ] Zero `using`/atributo de EF/ORM ou I/O (CONV-006/024).
- [ ] RootNamespace resolvido do repo, não placeholder.

Harness (gate automatizado — só conclui quando passa):
- `dotnet build` do projeto `Domain` compila sem warning (CONV-002 trata warning como erro).
- Analyzers / `.editorconfig` / `BannedSymbols.txt` sem violação (§16).
- Se algum teste já referencia o tipo, ele está verde.