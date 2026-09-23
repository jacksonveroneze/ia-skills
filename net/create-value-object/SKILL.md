---
name: create-value-object
description: 'Cria um value object de domínio (.NET/C#, camada Domain, sem identidade) — tipos de valor como Money, Cpf, Cnpj, Email, AccountNumber, Cep, Currency, PhoneNumber. Use sempre que o usuário pedir um value object, VO ou tipo de valor, mesmo sem usar o termo (ex. um tipo para representar dinheiro, ou um Cpf com validação). Não use para entidades com identidade (create-entity) nem para DTOs de request/response.'
---

# Criar Value Object (.NET / Clean Architecture)

Gera **um** value object (VO) de domínio conforme a `dotnet-conventions.md` na raiz do projeto.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID ao justificar decisões.

## O que gera
Um único arquivo: `src/main/Domain/{Aggregate}/{Name}.cs` (VO de agregado) **ou**
`src/main/Domain/ValueObjects/{Name}.cs` (VO compartilhado, ex.: `Money`, `Email`). Ajuste ao
layout real do repo. O tipo é um `sealed record` imutável, construído só pela factory `Create(...)`,
com os erros das invariantes declarados como **propriedades `static Error` no próprio VO**.

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito é um **valor sem identidade** (dois iguais são intercambiáveis).
- **NÃO usar:** tem identidade/ciclo de vida → `create-entity`. É contrato de borda → é `Request`/`Response`, não VO.

## Contrato

### Rules enforçadas (CONV)
- **CONV-025** VO imutável, igualdade por valor, auto-validado via factory.
- **CONV-059** dinheiro é `decimal` no VO `Money`; nunca `float`/`double`.
- **CONV-021 / CONV-069** falha vira `Error` tipado via `Result` (`FromInvalid`) — nunca `null`, nunca `throw` para regra.
- **CONV-063** identificadores em inglês. **CONV-064** `sealed`. **CONV-065** acesso mais restritivo.
- **CONV-006 / CONV-024** Domain puro: sem EF/ORM, sem atributo de persistência, sem I/O.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha a pasta.

### Pré-condições
O `Domain` referencia a lib de resultado do projeto (`JacksonVeroneze.NET.Result` — `Result`/`Error`),
com `global using`. **Os erros do VO ficam no próprio VO** (propriedades `static Error`), não num
arquivo central nem inline. Um `DomainErrors.cs` central, se existir, é para erros de entidade/use-case,
não para VO.

### Inputs
1. **Name** — em inglês, PascalCase (`Money`, `Email`, `AccountNumber`).
2. **Escopo** — `ValueObjects` (compartilhado) ou o agregado dono (`Accounts`).
3. **Fields** — o(s) valor(es) encapsulado(s) e tipo(s).
4. **Invariantes** — as regras de validação (formato, faixa, obrigatoriedade). Cada uma vira um `Error` estático.
5. **RootNamespace** — resolvido por ReAct, não perguntado de cara.

Faltando Name, Fields ou Invariantes e sem inferência segura, pergunte antes de gerar. Não
invente invariante que o usuário não pediu.

## Fluxo (ReAct)
1. **Resolver RootNamespace.** `<RootNamespace>` em `Directory.Build.props`; senão derive do
   `namespace` de um arquivo existente em `Domain/**`; só pergunte se o Domain vazio.
2. **Checar duplicidade.** Se `{Name}.cs` já existe, não sobrescreva: relate.
3. **Alinhar estilo** a um VO irmão, se houver (mesma forma de erro e de factory).
4. **Decidir** membros, invariantes e os `Error` estáticos (CoT abaixo).
5. **Escrever** o arquivo no caminho correto.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem **identidade**? Se sim, é entity → pare e use `create-entity`.
- Quais campos são **parte do valor** (entram na igualdade)? Todos entram.
- Qual o **mínimo de invariantes**? Cada uma vira um `static Error {Reason}` chaveado `{Name}.{Reason}` + uma guard clause.
- Validação de **formato**? Use `[GeneratedRegex]` (BCL, source-gen) e torne o record `partial` — **sem lib externa**. Confirme antes de adicionar qualquer pacote.
- Há **normalização** (trim, lower, tirar máscara)? Só depois de validar, no `WithSuccess`.
- Precisa de **comportamento** (ex.: `Money.Add`)? Operação que pode falhar retorna `Result<T>`.

## Template canônico
```csharp
using JacksonVeroneze.NET.Result;
// using System.Text.RegularExpressions;   // só quando usar [GeneratedRegex]

namespace {RootNamespace}.Domain.{Scope};

public sealed record {Name}          // 'partial' só se usar source generator (ex.: [GeneratedRegex])
{
    // um Error estático por invariante, chaveado {Name}.{Reason}
    public static Error {Reason} =>
        Error.Create("{Name}.{Reason}", "<mensagem clara>");

    public {FieldType} {FieldName} { get; }

    private {Name}({FieldType} {fieldParam})
    {
        {FieldName} = {fieldParam};
    }

    public static Result<{Name}> Create({FieldType} {fieldParam})
    {
        if (/* invariante violada */)
        {
            return Result<{Name}>.FromInvalid({Reason});
        }

        // normalização só após validar
        return Result<{Name}>.WithSuccess(
            new {Name}(/* valores normalizados */));
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — record público, `double`, `throw`, e erro montado inline:
```csharp
public record Money(double Amount, string Currency)               // público, mutável via with
{
    public static Money Create(double amount, string currency)
    {
        if (amount < 0)
            throw new ArgumentException("negative");               // exceção p/ regra esperada
        return new Money(amount, currency);                        // sem validar currency
    }
}
```

✅ Flagship — `Email` (formato via `[GeneratedRegex]`, record `partial`, normalização após validar):
```csharp
using System.Text.RegularExpressions;
using JacksonVeroneze.NET.Result;

namespace Api.Domain.ValueObjects;

public sealed partial record Email
{
    public static Error Required =>
        Error.Create("Email.Required", "Email is required.");

    public static Error InvalidFormat =>
        Error.Create("Email.InvalidFormat", "Email format is invalid.");

    public string Value { get; }

    private Email(string value)
    {
        Value = value;
    }

    public static Result<Email> Create(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return Result<Email>.FromInvalid(Required);
        }

        if (!EmailRegex().IsMatch(value))
        {
            return Result<Email>.FromInvalid(InvalidFormat);
        }

        return Result<Email>.WithSuccess(
            new Email(value.ToLowerInvariant()));
    }

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.CultureInvariant)]
    private static partial Regex EmailRegex();
}
```

✅ Segundo caso — `Money` (dois campos, erros estáticos):
```csharp
using JacksonVeroneze.NET.Result;

namespace Api.Domain.ValueObjects;

public sealed record Money
{
    public static Error AmountNegative =>
        Error.Create("Money.AmountNegative", 
            "Amount cannot be negative.");

    public static Error InvalidCurrency =>
        Error.Create("Money.InvalidCurrency", 
            "Currency must be a 3-letter ISO code.");

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
            return Result<Money>
            .FromInvalid(AmountNegative);
        }

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
        {
            return Result<Money>
            .FromInvalid(InvalidCurrency);
        }

        return Result<Money>.WithSuccess(
            new Money(amount, currency.ToUpperInvariant()));
    }
}
```
Diferença: `sealed record` com ctor privado (construção só via `Create` — CONV-025/064); `decimal`
(CONV-059); cada invariante é um `static Error {Name}.{Reason}` referenciado no `FromInvalid`, não
uma string inline nem um arquivo central (CONV-021/069); formato por `[GeneratedRegex]` da BCL (sem
lib nova); normalização só depois de validar.

## Anti-patterns (recusar)
- Construtor público, positional record ou setter — quebra construção validada.
- `throw` para valor inválido em vez de `Result<{Name}>.FromInvalid(...)`.
- **`Error` inline/repetido** (`Error.Create("Email", "msg")` espalhado) em vez de propriedade `static Error {Name}.{Reason}`.
- Criar arquivo `{Name}Error` separado — o erro do VO mora **no VO**.
- Validar formato com **lib externa** sem confirmar; use `[GeneratedRegex]` (BCL).
- `float`/`double` para dinheiro. Atributos `[Key]`/`[Column]` ou referência a `DbContext`.
- `class` sem `IEquatable` (igualdade por referência) para algo que é valor.

## Checklist + Harness

Checklist (mapeado a CONV):
- [ ] `sealed record` (`partial` só se usar source-gen), um tipo por arquivo, file-scoped namespace (CONV-064/012/011/013).
- [ ] Construtor `private`; construção só via `Create` (CONV-025/065).
- [ ] Cada invariante tem `static Error {Name}.{Reason}` e uma guard clause com `FromInvalid` (CONV-021/069).
- [ ] `Create` retorna `Result<{Name}>` (`WithSuccess` no caminho feliz, após normalizar).
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` null-forgiving (CONV-069/003).
- [ ] Formato por `[GeneratedRegex]` (BCL); nenhuma lib nova sem confirmação.
- [ ] Dinheiro é `decimal` (CONV-059). Identificadores em inglês (CONV-063). Zero EF/ORM/I/O (CONV-006/024).
- [ ] RootNamespace resolvido do repo, não placeholder.

Harness (gate — só conclui quando passa):
- `dotnet build` do `Domain` compila sem warning (CONV-002 trata warning como erro).
- Analyzers / `.editorconfig` / `BannedSymbols.txt` sem violação (§16).
- Se algum teste já referencia o tipo, ele está verde.