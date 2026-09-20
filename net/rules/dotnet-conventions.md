---
name: dotnet-conventions
version: 2.1.0
applies-to: "**/*.cs"
stack: .NET 10, C# 14
last-updated: 2026-09-19
---

# Convenções .NET

Fonte única de verdade de como o código é escrito neste repositório. Revisores e ferramentas
citam violações pelo ID (ex.: "viola CONV-021").

Regras mecânicas/de estilo são enforçadas por `.editorconfig` + `TreatWarningsAsErrors` e
**não** se repetem aqui — ver §16. Se uma convenção pode virar entrada de analyzer/editorconfig,
o lugar dela é lá, não aqui. Mantenha este arquivo enxuto.

## Precedência e normatividade
- Ordem em conflito: **instrução explícita da tarefa atual > este arquivo > defaults da ferramenta.**
- `DEVE` / `NÃO DEVE` = invariante rígido, sem exceção.
- `PREFERIR` = default; só divergir com motivo declarado em comentário de código ou no PR.
- IDs de regra são **identificadores estáveis atribuídos na criação**, não uma sequência — a
  ordem no arquivo pode diferir da ordem dos IDs, e IDs aposentados deixam lacuna. Regra nova
  recebe o próximo número livre; IDs existentes nunca mudam.

---

## §1 — Meta e build
- **CONV-001** `src/Directory.Build.props` define, para todos os projetos: `TargetFramework=net10.0`, `LangVersion=14`, `Nullable=enable`, `ImplicitUsings=enable`. O `.csproj` individual NÃO DEVE repetir estas propriedades.
- **CONV-002** `TreatWarningsAsErrors=true` e code style/analyzers tratados como erro, também em `src/Directory.Build.props`.
- **CONV-003** NÃO DEVE usar o operador null-forgiving `!` em `Domain` ou `Application`. Permitido só em testes, contra valores comprovadamente não-nulos.
- **CONV-058** Central Package Management: todas as versões de pacote em `Directory.Packages.props`. O `.csproj` individual NÃO DEVE fixar versão; mantê-lo mínimo (só `ProjectReference`/`PackageReference` sem versão).

## §2 — Layout da solution e regra de dependência
- **CONV-005** Quatro projetos: `Domain`, `Application`, `Infrastructure`, `Api`. Dependências fluem **só para dentro**.
- **CONV-006** `Domain` depende só da BCL e do FluentResults (lib pura). Sem ORM, framework ou infra.
- **CONV-007** `Application` → `Domain`. `Infrastructure` → `Application` (+ `Domain`). `Api` → `Application` + `Infrastructure` (apenas composition root).
- **CONV-008** Camada de baixo NÃO DEVE referenciar camada de cima. Enforçado por project reference.
- **CONV-009** Organização por **vertical slice dentro de cada camada**, não por tipo técnico. Os arquivos de uma feature ficam em `Features/{Aggregate}/{UseCase}/`.
- **CONV-010** A porta de repositório vive em `Application` e tem escopo **por agregado** (`IAccountRepository`), compartilhada pelos slices daquele agregado — nunca uma porta por use case.

Layout alvo (autoritativo para a estrutura; conteúdo do slice é ilustrativo):
```
src/
  Directory.Build.props                        # props globais (CONV-001/002)
  Directory.Packages.props                     # versões (CONV-058)
  Domain/
    Accounts/                                  # Account (entity), Money, AccountNumber (VOs)
    Common/Errors/                             # taxonomia AppError (ver §6)
  Application/
    Features/Accounts/GetAccountById/          # Request, Response, UseCase, Validator, Mapping
    Abstractions/Accounts/IAccountRepository.cs # porta, por agregado
    Common/
  Infrastructure/
    Persistence/Configurations/AccountConfiguration.cs
    Persistence/Repositories/AccountRepository.cs
    DependencyInjection.cs                      # AddInfrastructure()
  Api/
    Features/Accounts/AccountsEndpoints.cs
    Common/ResultToProblemDetails.cs
    Program.cs
tests/
  Application.UnitTests/Features/Accounts/GetAccountById/GetAccountByIdUseCaseTests.cs
```

## §3 — Namespaces e arquivos
- **CONV-011** Somente file-scoped namespaces.
- **CONV-012** Um tipo de topo por arquivo; nome do arquivo == nome do tipo.
- **CONV-013** Namespace espelha o caminho da pasta, slice incluído: `Bank.Application.Features.Accounts.GetAccountById`.

## §4 — Nomenclatura
- **CONV-014** Interfaces com prefixo `I`. Métodos assíncronos terminam em `Async`.
- **CONV-015** Campos privados `_camelCase`; constantes `PascalCase`.
- **CONV-016** Use case = verbo + sujeito (+ qualificador) + sufixo `UseCase`: `GetAccountByIdUseCase`, `TransferMoneyUseCase`. A operação-base (`GetAccountById`) nomeia os demais artefatos do slice.
- **CONV-017** Input = `{Operation}Request`; output = `{Operation}Response`. Ex.: `GetAccountByIdRequest`/`GetAccountByIdResponse`, `TransferMoneyRequest`/`TransferMoneyResponse`.
- **CONV-018** Validator = `{Operation}Validator`. NÃO existe tipo `Handler` — o use case é o handler (§8).

## §5 — Padrões de código C#
- **CONV-063** Código em inglês: todos os identificadores (classes, métodos, propriedades, records, interfaces, enums, variáveis, namespaces, arquivos e pastas técnicas). Documentação, comentários e specs podem ser em português. NÃO DEVE misturar português em identificador C#.
- **CONV-064** Classes/records `sealed` por padrão.
- **CONV-065** Modificador de acesso mais restritivo possível.
- **CONV-066** Primary constructors para injeção de dependência.
- **CONV-067** Guard clauses para entradas inválidas no início do método.
- **CONV-068** `record` para dados imutáveis; `class` para tipos com identidade ou comportamento (entidades, serviços).
- **CONV-069** NÃO DEVE retornar `null` para representar erro de negócio — usar `Result` (§6).
- **CONV-070** NÃO DEVE expor entidades de persistência (EF) em contratos de API — usar DTOs da Application (§10).
- **CONV-071** `System.Text.Json` para serialização. `Newtonsoft.Json` é PROIBIDO.

## §6 — Contrato de resultado (FluentResults) — compartilhado
- **CONV-019** Todo use case retorna `Task<Result<TResponse>>` (ou `Task<Result>` quando void). NÃO DEVE lançar exceção para falha esperada/de negócio.
- **CONV-020** Exceção só para o realmente excepcional (bug, infra fora). Nunca para fluxo de controle.
- **CONV-021** Falha DEVE usar um erro tipado da taxonomia em `Domain/Common/Errors`. NÃO DEVE usar `Result.Fail("string")` numa borda.
- **CONV-022** NÃO DEVE serializar `IError`/`Result` do FluentResults direto. Mapear para `ProblemDetails` (§10).
- **CONV-083** NÃO DEVE engolir exceção (catch vazio, ou catch-log-continua sem tratar).

Taxonomia de erro (componente compartilhado — base + subclasses, cada uma com `Code` estável):
```csharp
public abstract class AppError : Error
{
    protected AppError(string code, string message) : base(message) => WithMetadata("code", code);
    public string Code => Metadata.TryGetValue("code", out var c) ? (string)c : "unknown";
}

public sealed class ValidationError(string message)   : AppError("validation", message);
public sealed class NotFoundError(string message)     : AppError("not_found", message);
public sealed class ConflictError(string message)     : AppError("conflict", message);       // 409
public sealed class BusinessRuleError(string message) : AppError("business_rule", message);  // 422 — regra violada / estado inválido
public sealed class UnauthorizedError(string message) : AppError("unauthorized", message);
public sealed class ForbiddenError(string message)    : AppError("forbidden", message);
```

## §7 — Domain
- **CONV-023** Entidades: setter privado, mutação só por métodos; construção via factory estática que retorna `Result<T>` validando invariantes. Sem ctor público sem parâmetros para uso de domínio.
- **CONV-024** Domain NÃO DEVE referenciar EF/ORM nem atributos de persistência (`[Key]`, `[Table]`, `[Column]`). Mapeamento vive na Infrastructure (§9).
- **CONV-025** Value objects: imutáveis, igualdade por valor (`record` ou `IEquatable<T>`), auto-validados via factory.
- **CONV-026** Domain guarda regra de negócio (entidades, VOs, factories, policies, invariantes) — sem orquestração, sem I/O, sem DTOs.
- **CONV-059** Valores monetários DEVEM ser `decimal`, encapsulados no value object `Money` (amount + currency). NÃO DEVE usar `float`/`double` para dinheiro em nenhum ponto da solution.

## §8 — Application
- **CONV-027** Cada use case é uma classe concreta única `{Operation}UseCase` — ela **é** o handler; não há tipo `Handler` separado nem interface por use case. O endpoint depende do use case concreto; o use case depende das portas.
- **CONV-028** Contratos de borda (`Request` / `Response`) são `record` imutáveis.
- **CONV-029** Validação de input é um `AbstractValidator<T>` (FluentValidation) separado, nunca inline no use case. Validação de forma roda na borda (§10); o use case só aplica regra de **negócio**.
- **CONV-030** Portas de repositório vivem em `Application/Abstractions/{Aggregate}/`. Application NÃO DEVE referenciar tipo concreto de infra (`DbContext`, tipos de provider).
- **CONV-031** Mapeamento entity → `Response` via **Mapster com `IRegister` explícito por feature**. Sem mapeamento por convenção/implícito — todo membro declarado; a config DEVE falhar em membro de destino não mapeado.
- **CONV-072** Use cases são **agnósticos a transporte**: NÃO DEVEM referenciar HTTP, MCP, gRPC, GraphQL nem `HttpContext`. A adaptação de protocolo acontece só na Api.

## §9 — Infrastructure (agnóstica ao store)
> O store concreto (EF Core, event store, etc.) é escolhido pelas skills de persistência, não aqui. Estas regras valem de qualquer forma.
- **CONV-032** Contém só: implementação de repositório, configuração de persistência, integrações externas. Zero regra de negócio.
- **CONV-033** Mapeamento de persistência é definido na Infrastructure, uma unidade de mapeamento por agregado — nunca na entidade de domínio. (Com EF Core: um `IEntityTypeConfiguration<T>` por agregado.)
- **CONV-034** Repositório implementa a porta da Application; async + `CancellationToken`; retorna entidades de domínio (ou `null`). NÃO DEVE vazar tipo de query do store (ex.: `IQueryable`) para fora do seu limite.
- **CONV-084** Use constraints de banco para integridade, mas regra de negócio vive em Domain/Application — nunca só no banco.

## §10 — API (Minimal API) — mapeador compartilhado
- **CONV-035** Somente Minimal API (sem controllers MVC). Endpoints agrupados por feature com `MapGroup`.
- **CONV-036** Usar typed results (`Results<Ok<T>, NotFound, ...>`). Sem corpo `IResult` não tipado.
- **CONV-037** Reusar os DTOs `Request` / `Response` da Application na borda — sem camada de contrato de API separada.
- **CONV-038** Validação de input roda via endpoint filter (FluentValidation) **antes** do use case. Inválido → `400` `ValidationProblemDetails`.
- **CONV-039** Um único `ResultToProblemDetails` mapeia falhas para HTTP e todo endpoint roteia falha por ele.
- **CONV-040** Endpoints são finos: parse → chama use case → mapeia `Result`. Sem regra de negócio.
- **CONV-061** Um middleware global de exceção (`IExceptionHandler`) mapeia exceção não tratada → `500` `ProblemDetails`, loga e NÃO DEVE vazar detalhe interno. Falha esperada segue via `Result` (§6), nunca por este caminho.
- **CONV-073** Versionamento de API explícito; OpenAPI exposto (Scalar/Swagger).

Mapa falha → HTTP (componente compartilhado):
```csharp
public static IResult ToProblem(this IError error) => error switch
{
    ValidationError e    => Results.Problem(e.Message, statusCode: 400, title: e.Code),
    NotFoundError e      => Results.Problem(e.Message, statusCode: 404, title: e.Code),
    ConflictError e      => Results.Problem(e.Message, statusCode: 409, title: e.Code),
    BusinessRuleError e  => Results.Problem(e.Message, statusCode: 422, title: e.Code),
    UnauthorizedError e  => Results.Problem(e.Message, statusCode: 401, title: e.Code),
    ForbiddenError e     => Results.Problem(e.Message, statusCode: 403, title: e.Code),
    _                    => Results.Problem(statusCode: 500, title: "internal_error"),
};
```

## §11 — Injeção de dependência
- **CONV-041** Cada projeto expõe uma extension `Add{Layer}()` (`AddApplication`, `AddInfrastructure`); `Program` compõe.
- **CONV-042** NÃO DEVE usar assembly scanning (sem Scrutor, sem registro por reflection). Todo registro é explícito.
- **CONV-043** Lifetime default: `Scoped` para use cases, repositórios, `DbContext`. `Singleton` só para config sem estado (ex.: `TypeAdapterConfig` do Mapster).

## §12 — Async, tempo e concorrência
- **CONV-044** `CancellationToken` propagado em toda chamada async, ponta a ponta (endpoint → use case → repo).
- **CONV-045** NÃO DEVE bloquear em async: sem `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`.
- **CONV-046** Todo I/O é async. Não espalhar `ConfigureAwait` — ASP.NET Core não tem sync context.
- **CONV-047** Sem `async void`.
- **CONV-060** Tempo vem de um `TimeProvider` injetado; todos os instantes em UTC (`DateTimeOffset`). PROIBIDO `DateTime.Now`/`.UtcNow` direto. No Domain o instante entra como **parâmetro** do método (ex.: `account.Accrue(rate, asOf)`); o `TimeProvider` é injetado na Application/Infrastructure, nunca na entidade.
- **CONV-074** O parâmetro `CancellationToken` se chama `cancellationToken` e NÃO DEVE ter valor default. Propagar a EF, HTTP, Redis, cache, mensageria.
- **CONV-075** NÃO DEVE usar `Task.Run` para esconder I/O bloqueante server-side; não ignorar task retornada; não engolir cancelamento.
- **CONV-076** `Task`/`Task<T>` por padrão; `ValueTask` só com motivo real de performance e ciência das restrições.

## §13 — Testes
- **CONV-048** Stack: xUnit + Moq + Shouldly.
- **CONV-049** Nome: `Method_Scenario_ExpectedResult`.
- **CONV-050** Estrutura AAA; um comportamento por teste.
- **CONV-051** Todo use case entrega ao menos um teste de unidade **passando** — critério de conclusão do slice.
- **CONV-052** Mockar só portas (interfaces de repositório). Usar o objeto real para entidades, VOs e mappers.
- **CONV-053** Asserção sobre `Result`: sucesso valida `IsSuccess` + value; falha valida o **tipo** do erro e o `Code`, não a string da mensagem.

## §14 — Segurança e observabilidade (banking)
- **CONV-054** NÃO DEVE logar PII, saldos, número de conta, CPF, tokens ou payloads completos. Logar só identificadores / correlation id.
- **CONV-055** Secrets nunca em código ou `appsettings` commitado — usar user-secrets / Key Vault / env vars.
- **CONV-056** Autorização por posse é enforçada no use case. Nunca confiar em identificador vindo do cliente para autorização.
- **CONV-057** Resposta de erro NÃO DEVE vazar interno (stack trace, SQL). `ProblemDetails` carrega só código seguro e estável.
- **CONV-062** Logging estruturado via `ILogger<T>` com message templates (`_logger.LogInformation("... {AccountId}", id)`) — nunca interpolação de string, nunca `Console.WriteLine`.
- **CONV-077** Health checks para dependências externas.
- **CONV-078** Observabilidade: distinguir logs (diagnóstico), métricas (comportamento mensurável) e traces (fluxo distribuído); OpenTelemetry quando disponível; incluir correlation/trace/request id.
- **CONV-079** Authorization por policy no ASP.NET Core.
- **CONV-080** Proteger contra overposting / mass assignment na borda.

## §15 — Anti-overengineering
- **CONV-081** NÃO DEVE introduzir sem necessidade clara: generic repository, unit of work sobre EF, mediator pipeline, CQRS completo, domain events, microservices, base classes genéricas, factories/reflection desnecessárias, abstração de implementação única, extension methods sem ganho claro, frameworks internos.
- **CONV-082** As portas de repositório (CONV-010/030) são exceção explícita ao veto de "abstração de implementação única": justificadas por DIP + seam de teste.

## §16 — Fronteira com .editorconfig / APIs banidas (não repetido acima)
Enforçado mecanicamente como erro de build; listado para este arquivo não duplicar:
indentação, espaçamento, limite de 100 chars, uso de `var`, qualificação `this.`,
ordenação/posição de usings, expression-bodied, estilo de chaves, trailing commas,
analyzers de casing, severidade de IDE/CA. APIs proibidas em `BannedSymbols.txt`
(via BannedApiAnalyzers) são restrição rígida — o build tem de passar.