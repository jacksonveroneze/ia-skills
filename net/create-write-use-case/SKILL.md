---
name: create-write-use-case
description: 'Cria um caso de uso de escrita (.NET/C#, camada Application) — Request, Response e o UseCase que muta o domínio, persiste via repositório e retorna Result. É o limite transacional. Use sempre que o usuário pedir uma operação que cria, altera ou remove estado (ex. OpenAccount, TransferMoney, CancelOrder), ou um use case de escrita ou comando, mesmo sem usar o termo. Não use para leitura ou consulta (create-read-use-case) nem para endpoint HTTP (create-endpoint).'
---

# Criar Use Case de Escrita (.NET / Clean Architecture)

Gera um slice de escrita (Request + Response + UseCase) conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Três arquivos em `src/Application/Features/{Aggregate}/{Operation}/`:
`{Operation}Request.cs`, `{Operation}Response.cs`, `{Operation}UseCase.cs`.

## Escopo (quando usar / NÃO usar)
- **Usar:** operação que **muta estado** (cria/altera/remove um agregado).
- **NÃO usar:** leitura → `create-read-use-case`. Adaptação HTTP → `create-endpoint`. Regra/mutação do agregado → é método de domínio (`create-entity`).

## Contrato

### Rules enforçadas (CONV)
- **CONV-016/017** nome `{Operation}UseCase`; input `{Operation}Request`, output `{Operation}Response`.
- **CONV-019** retorna `Task<Result<{Operation}Response>>`; não lança para fluxo esperado.
- **CONV-027** classe concreta única (sem interface); é o handler; primary ctor injeta portas e `TimeProvider`.
- **CONV-028** `Request`/`Response` são `record` imutáveis. **CONV-064** `sealed`. **CONV-072** agnóstico a transporte.
- **CONV-023** muta **só via factory/método de domínio** (que retorna `Result`); nunca seta propriedade da entidade.
- **CONV-021** falha de composição/invariante → `ValidationError`; regra de negócio → `BusinessRuleError` (vinda do domínio).
- **CONV-060** instante vem do `TimeProvider` injetado e é passado ao domínio como parâmetro.
- **CONV-030** persiste pela porta (`AddAsync`/`UpdateAsync`); **CONV-081** sem unit of work genérico. **CONV-044/074** `cancellationToken` nomeado, sem default.

### Pré-condições
Existem a entidade e seus VOs, e a porta `I{Aggregate}Repository` com o método de mutação
necessário (`AddAsync`/`UpdateAsync` — estenda com `create-repository`). `TimeProvider` registrado.

### Inputs
1. **Operation/Aggregate** — a operação e o agregado.
2. **Tipo de mutação** — cria novo agregado (factory) ou altera existente (carrega + método).
3. **Request** — dados de entrada.
4. **Response** — saída mínima (ex.: `Id` do agregado criado).
5. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Conferir a porta**: tem `AddAsync`/`UpdateAsync`? Faltando, estenda com `create-repository`.
3. **Conferir a factory/método de domínio** que realiza a mutação; faltando, gere com `create-entity`.
4. **Modelar** a composição (VOs → factory/método → persistência) — CoT.
5. **Escrever** os três arquivos.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- A mutação acontece **dentro do domínio** (factory/método → `Result`)? O use case só orquestra, nunca seta estado (CONV-023).
- Componho VOs? Cada `Create` → `Result`; **propague a primeira falha** antes de seguir.
- Preciso de instante? `timeProvider.GetUtcNow()`, passado ao domínio como parâmetro (CONV-060).
- Onde persisto? Pela porta (`AddAsync`/`UpdateAsync`); **este use case é o limite transacional**; um agregado por use case (sem UoW — CONV-081).
- Concorrência/idempotência são preocupações de escrita — trate se a operação exigir, sem inventar abstração.
- Apareceu tipo de transporte/infra? Está errado (CONV-072/030).

## Template canônico
```csharp
// {Operation}Request.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};
public sealed record {Operation}Request(/* campos de entrada */);
```
```csharp
// {Operation}Response.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};
public sealed record {Operation}Response(/* saída mínima, ex.: Guid Id */);
```
```csharp
// {Operation}UseCase.cs
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};

public sealed class {Operation}UseCase(I{Aggregate}Repository {aggregate}s, TimeProvider timeProvider)
{
    public async Task<Result<{Operation}Response>> HandleAsync(
        {Operation}Request request, CancellationToken cancellationToken)
    {
        // 1. compõe VOs (cada Create → Result), propagando falha
        // 2. cria via factory (Result) OU carrega + chama método de domínio (Result)
        // 3. persiste pela porta (AddAsync/UpdateAsync) — limite transacional
        // 4. return Result.Ok(new {Operation}Response(...));
    }
}
```

## Exemplos (few-shot ❌/✅)

Pedido: "OpenAccount: abre uma conta com número e depósito inicial, retorna o Id."

❌ Sem contexto — infra na Application, estado cru, relógio direto, sem Result:
```csharp
public class OpenAccountHandler(AppDbContext db)             // infra na Application (CONV-030/072)
{
    public async Task<Guid> Handle(OpenAccountRequest r)     // sem Result (CONV-019)
    {
        var account = new Account { Balance = r.Amount };    // ctor público, estado cru (CONV-023)
        account.OpenedAt = DateTime.UtcNow;                  // relógio direto (CONV-060)
        db.Accounts.Add(account);
        await db.SaveChangesAsync();                         // SaveChanges na Application
        return account.Id;
    }
}
```
✅ Com contexto:
```csharp
namespace Bank.Application.Features.Accounts.OpenAccount;
public sealed record OpenAccountRequest(string Number, decimal Amount, string Currency);
```
```csharp
namespace Bank.Application.Features.Accounts.OpenAccount;
public sealed record OpenAccountResponse(Guid Id);
```
```csharp
namespace Bank.Application.Features.Accounts.OpenAccount;

public sealed class OpenAccountUseCase(IAccountRepository accounts, TimeProvider timeProvider)
{
    public async Task<Result<OpenAccountResponse>> HandleAsync(
        OpenAccountRequest request, CancellationToken cancellationToken)
    {
        var number = AccountNumber.Create(request.Number);
        if (number.IsFailed)
            return number.ToResult<OpenAccountResponse>();

        var deposit = Money.Create(request.Amount, request.Currency);
        if (deposit.IsFailed)
            return deposit.ToResult<OpenAccountResponse>();

        var account = Account.Open(number.Value, deposit.Value, timeProvider.GetUtcNow());
        if (account.IsFailed)
            return account.ToResult<OpenAccountResponse>();

        await accounts.AddAsync(account.Value, cancellationToken);
        return Result.Ok(new OpenAccountResponse(account.Value.Id));
    }
}
```
Diferença: muta só via factory `Account.Open` (CONV-023), não `new`+setter; compõe VOs propagando
`Result` (CONV-021); tempo via `TimeProvider` passado ao domínio (CONV-060); persiste pela porta,
que é o limite transacional, sem `DbContext`/`SaveChanges` na Application (CONV-030/081); retorna
`Result` (CONV-019); `cancellationToken` nomeado sem default (CONV-074). Para **alterar** um
agregado existente: `var acc = await accounts.GetByIdAsync(id, ct)` → `acc.Withdraw(...)` (Result)
→ `accounts.UpdateAsync(acc, ct)`.

## Anti-patterns (recusar)
- `new Entity { ... }` + setter em vez de factory/método de domínio.
- Injetar `DbContext`/`IQueryable`; `SaveChanges` no use case fora da porta.
- `DateTime.Now`/`.UtcNow`; calcular o instante dentro em vez do `TimeProvider`.
- Exceção para regra; retornar id/DTO cru sem `Result`.
- Unit of work genérico; mutar vários agregados num use case sem necessidade.
- MediatR / `IRequestHandler` / interface por use case / `HttpContext`.

## Checklist + Harness
Checklist (CONV):
- [ ] `{Operation}UseCase` `sealed`, concreto, primary ctor com porta + `TimeProvider` (CONV-027/060).
- [ ] `Request`/`Response` `record`; nomes corretos (CONV-017/028).
- [ ] Muta só via factory/método de domínio (`Result`); nunca seta propriedade (CONV-023).
- [ ] Compõe VOs propagando `Result`; retorna `Task<Result<{Operation}Response>>` (CONV-021/019).
- [ ] Persiste pela porta; limite transacional no use case; sem UoW (CONV-030/081).
- [ ] Sem transporte/infra na assinatura; `cancellationToken` nomeado sem default (CONV-072/074).

Harness (gate):
- `dotnet build` de `Application` limpo (CONV-002).
- Teste de unidade verde: mock da porta; verifica método de domínio chamado, persistência e `Result` (CONV-051/052).
- Arquitetura: `Application` não referencia EF nem transporte (§16/CONV-030/072).
