---
name: dotnet-conventions
version: 1.0.0
applies-to: "**/*.cs"
stack: .NET 10, C# 14
scope: qualquer tipo de projeto .NET (API REST, MVC, GraphQL, gRPC, console, Lambda, worker)
last-updated: 2026-09-28
---

# Convenções .NET

Fonte única de verdade das convenções **gerais** de código deste repositório. Revisores e
ferramentas citam violações pelo ID (ex.: "viola CONV-021").

Vale para qualquer tipo de projeto. Regra específica de arquitetura, camada, protocolo ou
artefato (use case, entidade, repositório, endpoint...) vive na skill correspondente e mantém o
seu ID `CONV-xxx`.

Regra mecânica/de estilo é enforçada por `.editorconfig` + `TreatWarningsAsErrors` e **não** se
repete aqui — ver §13. Se vira entrada de analyzer/editorconfig, o lugar dela é lá, não aqui.

## Precedência e normatividade
- Conflito: **instrução explícita da tarefa atual > este arquivo > defaults da ferramenta.**
- `DEVE` / `NÃO DEVE` = invariante rígido, sem exceção. `PREFERIR` = default; só divergir com motivo declarado em comentário de código ou no PR.
- IDs são **estáveis desde a criação**, não sequenciais — ordem no arquivo pode diferir da ordem dos IDs. Lacuna na sequência é ID aposentado **ou** movido para uma skill (onde mantém o mesmo ID). Regra nova recebe o próximo número livre; ID existente nunca muda.

---

## §1 — Meta e build
- **CONV-001** `src/Directory.Build.props` define, para todos os projetos: `TargetFramework=net10.0`, `LangVersion=14`, `Nullable=enable`, `ImplicitUsings=enable`. O `.csproj` individual NÃO DEVE repetir essas propriedades.
- **CONV-002** `TreatWarningsAsErrors=true` e code style/analyzers como erro, também em `Directory.Build.props`.
- **CONV-003** NÃO DEVE usar `!` (null-forgiving) em código de produção. Permitido só em testes, contra valor comprovadamente não-nulo.
- **CONV-058** Central Package Management: versão de pacote só em `Directory.Packages.props`. O `.csproj` NÃO DEVE fixar versão.
- **CONV-087** Pacote novo (fora da stack decidida) só com confirmação explícita do usuário. NÃO DEVE adicionar `PackageReference` sem isso.

## §2 — Princípios gerais
- **CONV-091** PREFERIR clareza a esperteza e código explícito a "mágica" (reflection, convenção implícita, registro automático).
- **CONV-092** PREFERIR métodos pequenos e focados: uma responsabilidade por método.
- **CONV-093** PREFERIR classes coesas. Construtor com dependências demais é sinal de responsabilidade demais: dividir a classe, não injetar mais.
- **CONV-094** NÃO DEVE duplicar regra de negócio: cada regra tem um único lugar.
- **CONV-095** DEVE preservar o comportamento existente em manutenção e refatoração, salvo pedido explícito da tarefa.
- Abstração prematura e overengineering: ver §12.

## §3 — Namespaces e arquivos
- **CONV-011** Somente file-scoped namespaces.
- **CONV-012** Um tipo de topo por arquivo; nome do arquivo == nome do tipo.
- **CONV-013** Namespace espelha o caminho da pasta, slice incluído: `Bank.Application.Features.Accounts.GetAccountById`.

## §4 — Nomenclatura e idioma
- **CONV-014** Interfaces com prefixo `I`. Métodos assíncronos terminam em `Async`.
- **CONV-015** Campos privados `_camelCase`; constantes `PascalCase`.
- **CONV-063** Identificadores em inglês (classes, métodos, propriedades, records, interfaces, enums, variáveis, namespaces, arquivos e pastas técnicas). Documentação, comentários e arquivos de especificação podem ser pt-BR. NÃO DEVE misturar português no identificador.
- **CONV-090** Parâmetro de lambda com nome descritivo do papel (ex.: `filter`, `item`). NÃO DEVE ser genérico (`x`, `y`, `i`, `conf`).
- **CONV-097** PREFERIR nomes claros e orientados à intenção a abreviações ou nomes genéricos (`data`, `manager`, `helper`).

## §5 — Padrões de código C#
- **CONV-064** Classes/records `sealed` por padrão.
- **CONV-065** Modificador de acesso mais restritivo possível.
- **CONV-066** Primary constructors para injeção de dependência.
- **CONV-067** Guard clauses no início do método para entrada inválida.
- **CONV-068** `record` para dado imutável; `class` para tipo com identidade ou comportamento.
- **CONV-096** PREFERIR imutabilidade quando fizer sentido.
- **CONV-071** `System.Text.Json`. `Newtonsoft.Json` é PROIBIDO.
- **CONV-089** Todo método usa corpo em bloco. NÃO DEVE usar membro expression-bodied (`=>`), nem para repasse de uma linha (também via `.editorconfig`/analyzer, §13).
- **CONV-098** Extensão justificada (ver CONV-081) usa blocos `extension` do C# 14. NÃO DEVE criar método de extensão novo no formato clássico (`this` no primeiro parâmetro).
- **CONV-099** NÃO DEVE usar estado global mutável (`static` mutável) nem service locator (resolver dependência via `IServiceProvider` fora do ponto de composição).
- **CONV-059** Dinheiro é `decimal`. NÃO DEVE usar `float`/`double` para dinheiro.

## §6 — Resultado e erros
- **CONV-020** Falha esperada de negócio/aplicação é `Result`/`Result<T>` (lib compartilhada `JacksonVeroneze.NET.Result`); NÃO DEVE lançar exceção para ela. Exceção só para o realmente excepcional (bug, infra fora), nunca para fluxo de controle.
- **CONV-069** NÃO DEVE retornar `null` para erro de negócio — usar `Result` (CONV-020).
- **CONV-021** Cada falha é `Error.Create(code, message)`, `code` estável em `{Tipo}.{Motivo}` (ex.: `Account.InitialDepositNegative`). Erro só do tipo que o declara: campo `private static readonly Error` nele; onde fica o erro cross-tipo (ex.: not-found) é definido pela skill de arquitetura. NÃO DEVE usar `Result.Fail("string")` solto, nem criar hierarquia de `Error` ou taxonomia paralela ao `ResultType` da lib (`Invalid`/`NotFound`/`Conflict`/`RuleViolation`/`Error`).
- **CONV-022** NÃO DEVE serializar `Error`/`Result` direto para fora do processo. O ponto de entrada traduz para a saída nativa do protocolo (CONV-036).
- **CONV-083** NÃO DEVE engolir exceção (catch vazio, ou catch-log-continua sem tratar).

## §7 — Validação e fronteiras
> Vale para todo ponto de entrada: endpoint HTTP, RPC gRPC, tool MCP, consumer de mensagem,
> handler Lambda, comando CLI. O mecanismo exato de cada item é definido pela skill do tipo de projeto.
- **CONV-029** Validação de input é um validator separado (FluentValidation quando aplicável), nunca inline na regra de negócio. A regra de negócio só aplica regra de **negócio**.
- **CONV-038** Toda entrada externa (requisição, mensagem, arquivo, argumento, payload) é validada no ponto de entrada, **antes** de qualquer lógica de negócio; inválido não avança.
- **CONV-036** Cada tipo de ponto de entrada devolve a representação nativa de sucesso/falha do protocolo (ex.: resposta HTTP, status gRPC, exit code) por um único tradutor de `Result`/`Result<T>` (CONV-020). NÃO DEVE montar essa representação à mão, espalhar o mapeamento, nem usar contrato de resultado paralelo ao da lib.
- **CONV-061** Um único ponto por tipo de entrada (exception handler, wrapper de handler, try/catch de topo) traduz exceção não tratada para a falha nativa, loga e NÃO DEVE vazar detalhe interno. Falha esperada segue via `Result` (§6), nunca por aqui.
- **CONV-070** NÃO DEVE expor entidade de persistência (ex.: EF) em contrato de saída (resposta de API, mensagem, evento, tool) — usar DTO/contrato próprio.
- **CONV-084** Constraint de banco garante integridade, mas regra de negócio vive no código de negócio — nunca só no banco nem só na validação de entrada.

## §8 — Async, tempo e concorrência
- **CONV-044** `CancellationToken` propagado ponta a ponta e repassado a toda operação que o aceita: EF Core, HTTP, Redis/cache, mensageria e operações longas.
- **CONV-045** NÃO DEVE bloquear em async: sem `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` (sync-over-async causa thread pool starvation).
- **CONV-046** Todo I/O é async; não espalhar `ConfigureAwait` (ASP.NET Core não tem sync context).
- **CONV-047** Sem `async void`, exceto em event handlers.
- **CONV-060** Tempo vem de `TimeProvider` injetado, sempre UTC (`DateTimeOffset`). PROIBIDO `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now` e `DateTimeOffset.UtcNow` direto. Lógica de negócio pura (sem dependências injetadas) recebe o instante como **parâmetro**; `TimeProvider` só é injetado em serviços de orquestração/integração.
- **CONV-074** Parâmetro se chama `cancellationToken`, sem valor default.
- **CONV-075** NÃO DEVE usar `Task.Run` para esconder I/O bloqueante; não ignorar task retornada; não engolir cancelamento.
- **CONV-076** `Task`/`Task<T>` por padrão; `ValueTask` só com motivo real de performance.
- **CONV-088** `await` só quando o resultado é usado no próprio método, ou há mais de uma chamada em sequência. Repasse de uma única chamada assíncrona sem uso do resultado retorna a `Task`/`Task<T>` direto (`return outraChamada(...)`), sem `async`/`await`.

## §9 — Injeção de dependência
- **CONV-041** Cada projeto/módulo expõe `Add{Module}()` (ex.: `AddApplication`, `AddInfrastructure`); o ponto de composição (`Program`) compõe.
- **CONV-042** NÃO DEVE usar assembly scanning (sem Scrutor, sem reflection). Todo registro explícito.
- **CONV-043** Lifetime default: `Scoped` (serviços de negócio e acesso a dados, ex.: `DbContext`); `Singleton` só para config/serviço sem estado (`TypeAdapterConfig`).

## §10 — Segurança e observabilidade
- **CONV-054** NÃO DEVE logar PII, senha, secret, token, saldo, número de conta, CPF ou payload completo. Logar só identificador/correlation id.
- **CONV-055** Secret nunca em código nem em arquivo commitado (`appsettings`, `.env` com credencial real, connection string real, token, certificado) — user-secrets/Key Vault/env var. NÃO DEVE hardcodar credencial.
- **CONV-056** Autorização por posse é enforçada na camada de negócio, não só no ponto de entrada. NÃO DEVE confiar em identificador vindo do cliente.
- **CONV-057** Resposta de erro NÃO DEVE vazar interno (stack trace, SQL). Saída de falha do ponto de entrada carrega só código seguro e estável.
- **CONV-062** Log estruturado via `ILogger<T>` com message template — nunca interpolação de string, nunca `Console.WriteLine`. Serilog como provider quando disponível no projeto.
- **CONV-077** Health checks para dependência externa.
- **CONV-078** Log (diagnóstico), métrica (comportamento mensurável) e trace (fluxo distribuído) são coisas distintas; OpenTelemetry/Prometheus quando disponíveis no projeto; incluir correlation/trace/request id.
- **CONV-079** Toda operação exposta é protegida por controle de acesso explícito no ponto de entrada (ex.: policy-based authorization no ASP.NET Core, interceptor em gRPC, tool gating em MCP).
- **CONV-080** Proteger contra overposting/mass assignment no ponto de entrada.
- **CONV-086** Regex usa `[GeneratedRegex(...)]` com timeout, tamanho da entrada verificado antes do match e âncoras `\A`…`\z`. NÃO DEVE usar regex sem timeout, sem guard de tamanho, ancorada com `^`…`$`, nem capturar `RegexMatchTimeoutException` para convertê-la em falha de validação.

## §11 — Testes
- **CONV-048** Stack: xUnit + Moq + Shouldly.
- **CONV-049** Nome: `Method_Scenario_ExpectedResult`.
- **CONV-050** Estrutura AAA; um comportamento por teste.
- **CONV-051** Toda funcionalidade nova entrega ao menos um teste de unidade **passando** — critério de conclusão.
- **CONV-052** Mockar só dependência de fronteira (repositório, cliente HTTP, mensageria). Objeto real para lógica, entidade, value object e mapper.
- **CONV-053** Asserção sobre `Result`: sucesso valida `IsSuccess` + value; falha valida o **tipo** do erro e o `Code`, não a mensagem.

## §12 — Anti-overengineering
- **CONV-081** NÃO DEVE introduzir sem necessidade clara: generic repository, unit of work sobre EF, mediator pipeline, CQRS completo, domain events, microservices, base class genérica, factory/reflection desnecessária, abstração de implementação única, extension method sem ganho claro, framework interno. Exceção só quando a skill de arquitetura a declara (ex.: porta de repositório/use case, por DIP + seam de teste).

## §13 — Fronteira com .editorconfig / APIs banidas (não repetido acima)
Enforçado mecanicamente como erro de build: indentação, espaçamento, limite de 100 chars, `var`,
qualificação `this.`, ordenação/posição de usings, expression-bodied, chaves, trailing commas,
analyzer de casing, severidade IDE/CA. API proibida em `BannedSymbols.txt` (BannedApiAnalyzers) —
o build tem de passar.