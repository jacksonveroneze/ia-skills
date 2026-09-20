---
name: create-validator
description: 'Cria um validator de input (.NET/C#, camada Application) com FluentValidation para o Request de um use case, checando forma e presença — não regra de negócio. Roda na borda via endpoint filter. Use sempre que o usuário pedir validação de input, validador, FluentValidation ou regras de formato de um Request. Não coloque regra de negócio, acesso a repositório ou I/O no validator, pois isso é domínio e volta como Result.'
---

# Criar Validator (.NET / FluentValidation)

Gera o validator de forma do `Request` de uma feature conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Um arquivo: `src/Application/Features/{Aggregate}/{Operation}/{Operation}Validator.cs`,
uma `sealed class {Operation}Validator : AbstractValidator<{Operation}Request>`.

## Escopo (quando usar / NÃO usar)
- **Usar:** validar **forma e presença** do `Request` (obrigatório, tamanho, faixa, regex).
- **NÃO usar:** regra de negócio (existência, saldo, estado atual) → é domínio/use case, volta como `Result`. Sem I/O, sem repositório.

## Contrato

### Rules enforçadas (CONV)
- **CONV-018** nome `{Operation}Validator`. **CONV-029** validator **separado**, nunca inline no use case; só regra de forma.
- **CONV-038** roda na **borda** via endpoint filter (registrado na Api), antes do use case; inválido → `400`.
- **CONV-064** `sealed`. **CONV-063** inglês.

### Pré-condições
Existe o `{Operation}Request`. O endpoint filter de validação está registrado na Api (bootstrap).

### Inputs
1. **Operation/Aggregate** — localizam o slice e o `Request`.
2. **Regras de forma** — por campo: obrigatoriedade, tamanho, faixa, padrão. **Não** regra de negócio.
3. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Ler o `Request`** e listar os campos.
3. **Classificar cada regra**: é forma/presença (fica) ou negócio (não entra — CoT).
4. **Escrever** o validator.
5. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Cada regra é **forma/presença** (não obrigatório, tamanho, faixa, regex)? Se envolve "existe no banco",
  "tem saldo", "está nesse estado", é **regra de negócio** → NÃO aqui; vai pro domínio/use case e volta como `Result` (CONV-029).
- O validator precisa de **I/O ou dependência**? Não pode ter (`MustAsync` com repositório é proibido).
- **Sobreposição com o VO:** o validator faz presença + forma grosseira para um `400` limpo na borda;
  o **VO é o dono do formato semântico** e a última linha de defesa. Evite duplicar validação profunda — deixe-a no VO.

## Template canônico
```csharp
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};

public sealed class {Operation}Validator : AbstractValidator<{Operation}Request>
{
    public {Operation}Validator()
    {
        RuleFor(x => x.{Field})
            .NotEmpty();
        // .Length / .GreaterThanOrEqualTo / .Matches conforme a forma exigida
    }
}
```

## Exemplos (few-shot ❌/✅)

Pedido: validar `OpenAccountRequest(string Number, decimal Amount, string Currency)`.

❌ Sem contexto — regra de negócio e I/O no validator:
```csharp
public class OpenAccountValidator : AbstractValidator<OpenAccountRequest>
{
    public OpenAccountValidator(IAccountRepository repo)                 // dependência de I/O (CONV-029)
    {
        RuleFor(x => x.Number)
            .MustAsync(async (n, ct) => !await repo.ExistsAsync(n, ct))  // regra de negócio + I/O na borda
            .WithMessage("Account already exists");
    }
}
```
✅ Com contexto — só forma e presença:
```csharp
namespace Bank.Application.Features.Accounts.OpenAccount;

public sealed class OpenAccountValidator : AbstractValidator<OpenAccountRequest>
{
    public OpenAccountValidator()
    {
        RuleFor(x => x.Number)
            .NotEmpty()
            .Length(10);

        RuleFor(x => x.Amount)
            .GreaterThanOrEqualTo(0);

        RuleFor(x => x.Currency)
            .NotEmpty()
            .Length(3);
    }
}
```
Diferença: sem dependência nem I/O (CONV-029); só forma/presença — unicidade da conta é **regra de
negócio**, tratada no use case/domínio e retornada como `Result` (`ConflictError`/`BusinessRuleError`),
não aqui; roda na borda por endpoint filter (CONV-038). O `10` dígitos aqui é fail-fast para um `400`
limpo; o `AccountNumber` (VO) continua sendo o dono autoritativo do formato.

## Anti-patterns (recusar)
- `MustAsync`/`Must` que consulta repositório, banco ou serviço (I/O na borda).
- Injetar qualquer dependência no validator.
- Regra de negócio (existência, saldo, transição de estado) — pertence ao domínio/use case.
- Validar dentro do use case em vez de num validator separado (CONV-029).
- Reimplementar toda a validação semântica do VO (duplicação) — deixe o profundo no VO.
- Mensagem que vaza detalhe interno.

## Checklist + Harness
Checklist (CONV):
- [ ] `sealed class {Operation}Validator : AbstractValidator<{Operation}Request>` no slice (CONV-018/064).
- [ ] Só regras de forma/presença; zero I/O, zero dependência, zero regra de negócio (CONV-029).
- [ ] Pensado para rodar na borda (endpoint filter), não no use case (CONV-038).
- [ ] Sem duplicar a validação semântica do VO. RootNamespace do repo.

Harness (gate):
- `dotnet build` de `Application` limpo (CONV-002).
- Teste do validator verde: casos válidos passam, inválidos falham no campo certo.
- O validator não tem construtor com dependências (checagem simples de assinatura).
