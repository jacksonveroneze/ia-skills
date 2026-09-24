---
name: create-value-object
description: 'Cria um value object de domínio (.NET/C#, camada Domain, sem identidade) em Domain/ValueObjects — tipos de valor como Money, Cpf, Cnpj, Email, AccountNumber, Cep, Currency, PhoneNumber. Use sempre que o usuário pedir um value object, VO ou tipo de valor, mesmo sem usar o termo (ex. um tipo para representar dinheiro, ou um Cpf com validação). Não use para entidades com identidade (create-entity) nem para DTOs de request/response.'
---

# Criar Value Object (.NET / Clean Architecture)

Gera **um** value object (VO) de domínio conforme a `dotnet-conventions.md` na raiz do projeto.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID ao justificar decisões.

## O que gera
Um único arquivo: `{DomainProjectDir}/ValueObjects/{Name}.cs`, onde `{DomainProjectDir}` é a
pasta do `.csproj` do projeto Domain. **Todo VO vai em `ValueObjects/`** — não há VO por agregado.

O tipo é um `sealed record` imutável, construído só pela factory `Create(...)`, com os erros das
invariantes declarados como **campos `private static readonly Error` no próprio VO**.

## Escopo (quando usar / NÃO usar)
- **Usar:** o conceito é um **valor sem identidade** (dois iguais são intercambiáveis).
- **NÃO usar:** tem identidade/ciclo de vida → `create-entity`. É contrato de borda → é `Request`/`Response`, não VO.

## Contrato

### Rules enforçadas (CONV)
- **CONV-025 / CONV-068** VO é `sealed record` imutável, igualdade por valor, auto-validado via factory — mesmo com comportamento.
- **CONV-085** `Create` retorna `Result<{Name}>`; invariante violada → `FromInvalid(error)`.
- **CONV-021** cada erro é `Error.Create("{Name}.{Reason}", ...)` declarado uma vez no VO. **CONV-069** nunca `null`/`throw` para regra.
- **CONV-059** dinheiro é `decimal` no VO `Money`; nunca `float`/`double`.
- **CONV-086** regex com timeout, tamanho verificado antes, âncoras `\A`/`\z`.
- **CONV-054** VO que carrega PII não expõe o valor em `ToString()`.
- **CONV-063** identificadores em inglês, exceto termos brasileiros sem tradução (`Cpf`, `Cnpj`, `Cep`).
- **CONV-064** `sealed`. **CONV-065** acesso mais restritivo. **CONV-015** `private static readonly` e `const` em PascalCase.
- **CONV-006 / CONV-024** Domain puro: sem EF/ORM, sem atributo de persistência, sem I/O.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace = RootNamespace do `.csproj` + pasta.
- **CONV-087** nenhum pacote novo sem confirmação.

### Pré-condições
O projeto Domain referencia `JacksonVeroneze.NET.Result` (`Result`, `Result<T>`, `Error`,
`ResultType`).

### Inputs
1. **Name** — em inglês, PascalCase (`Money`, `Email`, `AccountNumber`); termos brasileiros sem tradução ficam no original (`Cpf`, `Cnpj`, `Cep`).
2. **Fields** — o(s) valor(es) encapsulado(s) e tipo(s).
3. **Invariantes** — as regras de validação (formato, faixa, obrigatoriedade). Cada uma vira um `Error`.
4. **RootNamespace** — resolvido por ReAct a partir do `.csproj`, nunca perguntado de cara.

Faltando Name, Fields ou Invariantes e sem inferência segura, pergunte antes de gerar.
**Não invente invariante que o usuário não pediu** (ex.: não proíba valor negativo em `Money`
se ninguém pediu). Guard de tamanho antes de regex (CONV-086) não é invariante inventada: é
defesa obrigatória.

## Fluxo (ReAct)
1. **Localizar o projeto Domain.** Encontre o `.csproj` do Domain (ex.: `find . -name "*Domain*.csproj"`).
2. **Resolver RootNamespace a partir desse `.csproj`.** Nunca use o namespace dos exemplos desta skill.
   - Preferencial: `dotnet msbuild <Domain.csproj> -getProperty:RootNamespace` — avalia o valor efetivo, defaults incluídos.
   - Fallback: `<RootNamespace>` no `.csproj`; senão `<AssemblyName>`; senão o nome do arquivo `.csproj` sem extensão (default do MSBuild).
   - Namespace do VO = `{RootNamespace}.ValueObjects`.
3. **Checar usings globais.** Se o Domain já declara `global using JacksonVeroneze.NET.Result`
   (`<Using Include="JacksonVeroneze.NET.Result" />` no `.csproj` ou `GlobalUsings.cs`), **não**
   repita o `using` no arquivo (`IDE0005` é erro). Senão, declare-o.
4. **Checar duplicidade.** Se `ValueObjects/{Name}.cs` já existe, não sobrescreva: relate.
5. **Alinhar estilo** a um VO irmão em `ValueObjects/`, se houver.
6. **Decidir** membros, invariantes, erros e PII (CoT abaixo).
7. **Escrever** o arquivo.
8. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Tem **identidade**? Se sim, é entity → pare e use `create-entity`.
- Quais campos são **parte do valor**? Todos entram na igualdade.
- Qual o **mínimo de invariantes** pedido? Cada uma vira um `private static readonly Error {Reason}` com `Code` `{Name}.{Reason}` + uma guard clause **com chaves** retornando `FromInvalid`.
- Validação de **formato**?
  - Primeiro, tente sem regex (`Length`, `char.IsAsciiLetter`, `char.IsAsciiDigit`).
  - Se regex for necessário, use `[GeneratedRegex(pattern, options, matchTimeoutMilliseconds)]`, torne o record `partial`, verifique o tamanho máximo **antes** do match, ancore com `\A…\z` e use quantificadores limitados sem aninhamento (CONV-086).
  - Não capture `RegexMatchTimeoutException`.
- Há **normalização** (lower, upper, tirar máscara)? Só depois de validar, no `WithSuccess`.
- O valor é **PII** (Cpf, Cnpj, Email, PhoneNumber, AccountNumber)? Sobrescreva `ToString()` com máscara. O `ToString` sintetizado do record imprime o valor em log, exceção e debugger (CONV-054).
- Precisa de **comportamento** (ex.: `Money.Add`)? Só se pedido.
  - Retorna novo VO → `Result<{Name}>`; sem retorno → `Result`.
  - Violação de regra entre valores válidos (ex.: somar moedas diferentes) → `FromRuleViolation`, não `FromInvalid`.

## Template canônico
`{RootNamespace}` é placeholder: substitua pelo valor resolvido no passo 2 do Fluxo, nunca
copie literalmente.

```csharp
// using System.Text.RegularExpressions;   // só quando usar [GeneratedRegex]
// using JacksonVeroneze.NET.Result;       // só se não houver global using (passo 3)

namespace {RootNamespace}.ValueObjects;

public sealed record {Name}          // 'partial' só se usar source generator (ex.: [GeneratedRegex])
{
    // um Error por invariante, Code {Name}.{Reason}
    private static readonly Error {Reason} =
        Error.Create("{Name}.{Reason}", 
            "<mensagem clara>");

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

    // só para PII:
    // public override string ToString() => /* valor mascarado */;
}
```

## Exemplos (few-shot ❌/✅)
Nos exemplos, `{RootNamespace}` também é placeholder. Os `using` aparecem como se **não**
houvesse global using da lib.

❌ Sem contexto — record público, `double`, `throw`, erro inline:
```csharp
public record Money(double Amount, string Currency)               // posicional, ctor público
{
    public static Money Create(double amount, string currency)
    {
        if (amount < 0)                                            // invariante não pedida
            throw new ArgumentException("negative");               // exceção p/ regra; sem chaves
        return new Money(amount, currency);                        // sem validar currency
    }
}
```

✅ Flagship — `Email` (regex com timeout e guard de tamanho, PII mascarada, normalização após validar):
```csharp
using System.Text.RegularExpressions;
using JacksonVeroneze.NET.Result;

namespace {RootNamespace}.ValueObjects;

public sealed partial record Email
{
    private const int MaxLength = 254;

    private static readonly Error Required =
        Error.Create("Email.Required", 
            "Email is required.");

    private static readonly Error TooLong =
        Error.Create("Email.TooLong", 
            "Email must have at most 254 characters.");

    private static readonly Error InvalidFormat =
        Error.Create("Email.InvalidFormat", 
            "Email format is invalid.");

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

        if (value.Length > MaxLength)
        {
            return Result<Email>.FromInvalid(TooLong);
        }

        if (!EmailRegex().IsMatch(value))
        {
            return Result<Email>.FromInvalid(InvalidFormat);
        }

        return Result<Email>.WithSuccess(
            new Email(value.ToLowerInvariant()));
    }

    public override string ToString()
    {
        int atIndex = Value.IndexOf('@');

        return $"{Value[0]}***{Value[atIndex..]}";
    }

    [GeneratedRegex(
        @"\A[A-Za-z0-9._%+-]{1,64}@"
        + @"(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.){1,8}[A-Za-z]{2,63}\z",
        RegexOptions.CultureInvariant,
        matchTimeoutMilliseconds: 100)]
    private static partial Regex EmailRegex();
}
```

✅ Segundo caso — `Money` (dois campos, negativo permitido, validação sem regex):
```csharp
using JacksonVeroneze.NET.Result;

namespace {RootNamespace}.ValueObjects;

public sealed record Money
{
    private const int CurrencyLength = 3;

    private static readonly Error InvalidCurrency =
        Error.Create("Money.InvalidCurrency", 
            "Currency must have exactly 3 letters.");

    public decimal Amount { get; }

    public string Currency { get; }

    private Money(decimal amount, string currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public static Result<Money> Create(decimal amount, string currency)
    {
        if (string.IsNullOrEmpty(currency)
            || currency.Length != CurrencyLength
            || !currency.All(char.IsAsciiLetter))
        {
            return Result<Money>.FromInvalid(InvalidCurrency);
        }

        return Result<Money>.WithSuccess(
            new Money(amount, currency.ToUpperInvariant()));
    }
}
```

Diferença entre os exemplos ✅ e o ❌:
- `sealed record` com ctor privado: construção só via `Create` (CONV-025/064).
- `decimal` para dinheiro (CONV-059), e nenhuma invariante que não foi pedida: `Amount` aceita negativo.
- Cada invariante é um `private static readonly Error` com `Code` `{Name}.{Reason}`, criado uma vez e referenciado no `FromInvalid` (CONV-021/085).
- Regex só quando necessário, com timeout, guard de tamanho e âncoras `\A`/`\z` (CONV-086).
- PII mascarada no `ToString` (CONV-054). Normalização só depois de validar.

## Anti-patterns (recusar)
- Construtor público, positional record ou setter — quebra construção validada.
- `class` em vez de `record` para VO, mesmo com comportamento (CONV-068).
- `throw` para valor inválido em vez de `Result<{Name}>.FromInvalid(...)`.
- `Error` como propriedade expression-bodied (`static Error X => ...`) — aloca a cada acesso; use `static readonly`.
- `Error` inline/repetido (`Error.Create(...)` dentro do `Create`) em vez de campo único.
- Criar arquivo `{Name}Error` ou central de erros — o erro do VO mora **no VO**.
- `Error` `public` — só o `Create` do VO usa; deve ser `private` (CONV-065). Testes validam por `HasErrorForCode`.
- Failure sem `Error` (`FromInvalid()`) ou `Result<T>.WithSuccess()` sem valor (CONV-085).
- `if` de validação **sem chaves** (`IDE0011` = error).
- Regex sem timeout, sem guard de tamanho, ancorado com `^…$` ou com quantificador aninhado (CONV-086).
- Capturar `RegexMatchTimeoutException` para devolver `FromInvalid`.
- VO de PII sem `ToString` mascarado (CONV-054).
- Invariante que o usuário não pediu.
- Lib externa de validação sem confirmação (CONV-087).
- Traduzir termo brasileiro (`BrazilianTaxId` para `Cpf`) (CONV-063).
- `float`/`double` para dinheiro. Atributos `[Key]`/`[Column]` ou referência a `DbContext`.
- Namespace copiado dos exemplos ou placeholder `{RootNamespace}` deixado literal.

## Checklist + Harness

Checklist (mapeado a CONV):
- [ ] Arquivo em `{DomainProjectDir}/ValueObjects/{Name}.cs`; namespace `{RootNamespace}.ValueObjects` com RootNamespace resolvido do `.csproj` (CONV-013).
- [ ] `sealed record` (`partial` só se usar source-gen), um tipo por arquivo, file-scoped namespace (CONV-025/064/068/012/011).
- [ ] Construtor `private`; construção só via `Create` (CONV-025/065).
- [ ] Cada invariante tem `private static readonly Error` com `Code` `{Name}.{Reason}` e guard clause **com chaves** retornando `FromInvalid` (CONV-021/085/065).
- [ ] Só as invariantes pedidas (+ guard de tamanho quando houver regex).
- [ ] `Create` retorna `Result<{Name}>`; `WithSuccess(value)` no caminho feliz, após normalizar (CONV-085).
- [ ] Sem `null` para erro, sem `throw` para regra, sem `!` null-forgiving (CONV-069/003).
- [ ] Regex (se houver): `[GeneratedRegex]` com `matchTimeoutMilliseconds`, tamanho verificado antes, `\A…\z`, sem quantificador aninhado (CONV-086).
- [ ] PII: `ToString` sobrescrito com máscara (CONV-054).
- [ ] `using` da lib só se não houver global using; `const`/`static readonly` em PascalCase (CONV-015).
- [ ] Dinheiro é `decimal` (CONV-059). Identificadores em inglês, exceto `Cpf`/`Cnpj`/`Cep` (CONV-063). Zero EF/ORM/I/O (CONV-006/024). Nenhum pacote novo (CONV-087).

Harness (gate — só conclui quando os dois passam):
1. `dotnet build <Domain.csproj>` sem warnings. Com CONV-002 isso cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Domain.csproj> --verify-no-changes` sem diferenças: pega whitespace, espaço no fim de linha e quebras de linha.

Se algum teste já referencia o tipo, ele também precisa estar verde.