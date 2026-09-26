---
name: create-endpoint
description: 'Cria o endpoint HTTP (Minimal API, camada Api) de um use case de leitura já existente — GetById ou GetPaged: classe do endpoint, RouteMappings da feature, registro no Program.cs e, na listagem, os modelos REST, o mapper e a validação. Traduz Result em HTTP via ResultTranslator. Use sempre que o usuário pedir um endpoint, rota, GET, API ou expor um use case por HTTP (ex. GET /profiles/{id}, listar profiles), mesmo sem usar o termo. Não use para criar o use case (create-read-use-case) nem para endpoints de escrita (POST/PUT/PATCH/DELETE), ainda sem skill.'
---

# Criar Endpoint de Leitura (.NET / Minimal API)

Gera o endpoint HTTP de um use case de leitura conforme a `dotnet-conventions.md` na raiz do
projeto. Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID. Aqui ficam as regras
**comuns**; o que é específico de cada endpoint está nos resources.

## Resources (leia o do padrão escolhido, inteiro, antes de escrever)
| Pedido / use case | Resource |
|---|---|
| Sempre, antes de qualquer padrão: `ResultTranslator`, helpers exigidos, `RouteMappings` e `Program.cs` | `prerequisites.md` |
| Use case `GetById{Aggregate}` | `get-by-id.md` |
| Use case `GetPaged{AggregateFolder}` | `get-paged.md` |

Outro use case (escrita, cursor, outra leitura): **não há padrão** — pare e pergunte, não improvise.
Template canônico, exemplos ❌/✅, anti-patterns e checklist **específicos** ficam no resource.

## O que gera
Em `{ApiProjectDir}/Endpoints/{AggregateFolder}/v1/`: `{Operation}Endpoint.cs` (uma classe por endpoint) e,
na listagem, `Models/{Operation}RestRequest.cs`, `Models/{Operation}RestResponse.cs` e
`Models/{Operation}RestMapper.cs`. Além disso: uma linha na cadeia do `RouteMappings` da feature e, se ainda
não estiver, `app.Add{AggregateFolder}Endpoints();` no `Program.cs` (ver `prerequisites.md`). Nunca sobrescreva arquivo existente.

## Escopo (quando usar / NÃO usar)
- **Usar:** expor por HTTP um use case de **leitura** que já existe na Application.
- **NÃO usar:** criar o use case → `create-read-use-case`. Escrita (POST/PUT/PATCH/DELETE) → sem skill ainda.

## Vocabulário (placeholders usados em toda a skill e nos resources)
- `{Operation}` nome da operação **já existente** na Application (`GetByIdAccount`, `GetPagedAccounts`) — leia da pasta `Features/{AggregateFolder}/{Operation}/`, não invente.
- `{Aggregate}` tipo singular (`Account`); `{AggregateFolder}` pasta plural (`Accounts`); `{resource}` segmento de rota: `{AggregateFolder}` em kebab-case minúsculo (`accounts`, `bank-accounts`).
- `{ApiProjectDir}` pasta do `.csproj` da Api.
- `{ApiRootNamespace}` e `{ApplicationRootNamespace}` resolvidos dos `.csproj`. São placeholders: nunca copie o valor de um exemplo.

## Contrato

### Rules enforçadas (CONV) — comuns a todos os padrões
- **CONV-035/073** Minimal API; um grupo por feature criado por `RouteGroupBuilderFactory.Factory(app, Resource, Version)`; versão explícita (`Version`, namespace `v1`).
- **CONV-040** endpoint fino: monta o Request, chama o use case, traduz o `Result`. Sem regra de negócio, sem repositório/`DbContext`, sem `try/catch` (exceção não tratada é do `IExceptionHandler` global, CONV-061).
- **CONV-039/022** `ResultTranslator.ToIResult()` é o único tradutor de `Result` → HTTP; nunca serializar `Result`/`Error` direto, nunca montar `Results.NotFound()` à mão.
- **CONV-079** toda rota com `.RequireAuthorization(AuthorizationPolicies.{AggregateFolder}Read)`. Posse do recurso é do use case (CONV-056).
- **CONV-044/074** `CancellationToken cancellationToken` é o último parâmetro do handler, sem default, repassado ao use case.
- **CONV-070/057** nunca expor entidade; resposta de erro sem detalhe interno.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha a pasta (`{ApiRootNamespace}.Endpoints.{AggregateFolder}.v1`). `using` explícito para os namespaces de `RouteNames`, `AuthorizationPolicies`, `AddDefaultResponseEndpoints` e do use case.
- **CONV-087** nenhum pacote novo sem confirmação.

### Decisões de design fixadas (documentadas para revisão)
1. **Retorno `IResult`** via `ToIResult()`, não typed results: o status HTTP nasce do `ResultType` (o `ResultTranslator` decide).
2. **Modelo de falha = `ResultType` da lib** (404 vem de `Result.NotFound`); não há taxonomia `AppError`.
3. **GetById devolve o response da Application; GetPaged usa `RestRequest`/`RestResponse` + Mapster** (o `[AsParameters]` não vincula o `PagedRequest`).
4. **Validação do paginado é inline** (`IValidator<{Operation}Request>` sobre o Request já mapeado, antes do use case): um filtro de endpoint validaria o `RestRequest`, tipo que o Validator não conhece.
5. **Um endpoint = uma classe** `{Operation}Endpoint` com um método de extensão `Add{GetById|GetPaged}`.

### Pré-condições
Use case, interface, Request e Response existem na Application (`create-read-use-case`; se faltar, gere antes). Os helpers da Api listados em `prerequisites.md` existem. O registro no DI (use cases, `IValidator<>`, `IMapper` e os `IRegister` da Api, explícito, sem scanning — CONV-042) é de `register-dependencies`, que ainda não existe: **sem ele o endpoint falha em runtime** — avise ao terminar.

### Inputs
1. **Use case alvo** — `{Operation}` (deduzido do pedido; confirme na Application). 2. **Aggregate / AggregateFolder.**
3. **Paginado:** filtros e campos ordenáveis vêm do `Request` da Application (não reinvente).
4. **RootNamespaces** — resolvidos por ReAct, não perguntados de cara.

## Fluxo (ReAct)
1. **Localizar os `.csproj` da Api e da Application.**
2. **Resolver `{ApiRootNamespace}` e `{ApplicationRootNamespace}`.** Nunca use o namespace dos exemplos.
   - Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace`. Fallback: `<RootNamespace>`; senão `<AssemblyName>`; senão o nome do `.csproj` sem extensão.
   - Namespace do endpoint = `{ApiRootNamespace}.Endpoints.{AggregateFolder}.v1`; do use case = `{ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation}` (`using` explícito).
3. **Checar usings globais** da Api (`Microsoft.AspNetCore.Mvc`, `MapsterMapper`, `FluentValidation`, a lib `Result`): se já são `global using`, não repita (`IDE0005`).
4. **Executar `prerequisites.md`** (verifica; cria só o que falta; para se faltar helper).
5. **Conferir o use case** na Application (`I{Operation}UseCase`, `{Operation}Request`, `{Operation}Response`). Faltando → `create-read-use-case` antes.
6. **Escolher o padrão** na tabela e ler o resource inteiro.
7. **Checar duplicidade:** `{Operation}Endpoint.cs` já existe, ou o método já está na cadeia do `RouteMappings`? Não sobrescreva nem duplique: relate.
8. **Escrever** o endpoint (+ modelos REST no paginado) pelo template; **acrescentar** `.Add{...}()` à cadeia do `RouteMappings`; garantir a chamada no `Program.cs`.
9. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT) — comum
- O endpoint só adapta protocolo? Se apareceu regra de negócio, consulta a repositório ou `try/catch`, está no lugar errado (CONV-040).
- Todo status HTTP vem do `ResultTranslator`? Qualquer `Results.NotFound()/BadRequest()` manual para falha de use case está errado.
- O tipo do Request/Response é o do use case existente? Nunca recriar contrato.
- Rota, versão, policy e nome de rota vêm de constantes existentes (`Resource`, `Version`, `AuthorizationPolicies`, `RouteNames`), nunca de string solta.

## Anti-patterns comuns (recusar)
- Regra de negócio, `DbContext`, repositório ou `try/catch` no endpoint; endpoint que chama outro endpoint.
- Traduzir `Result` à mão (`if (output.IsFailure) return Results.NotFound()`), serializar `Result`/`Error`, ou expor entidade.
- Rota sem `RequireAuthorization`, policy como string literal, versão ou `Resource` hard-coded fora do `RouteMappings`.
- Copiar nomes de exemplo (`GetShortUrlById`, `Profiles`) ou o namespace de um exemplo.
- Criar de novo `ResultTranslator`/`RouteMappings` que já existem, ou inventar helper ausente (`RouteGroupBuilderFactory`, `AuthorizationPolicies`, `LocationBuilder`...): pare e reporte.
- Registrar o mesmo endpoint duas vezes na cadeia, ou duplicar `app.Add{AggregateFolder}Endpoints()` no `Program.cs`.
- `CancellationToken` com default ou não repassado; omitir os `using` explícitos.

## Checklist + Harness
Checklist (comum; o resource acrescenta os itens do padrão):
- [ ] `prerequisites.md` executado e resource do padrão lido; nada duplicado.
- [ ] Arquivos em `Endpoints/{AggregateFolder}/v1/`, namespace com o `RootNamespace` da Api, um tipo por arquivo (CONV-012/013).
- [ ] Endpoint fino: só Request → use case → `ToIResult()` (CONV-040/039); sem `try/catch`.
- [ ] `RequireAuthorization(AuthorizationPolicies.{AggregateFolder}Read)` presente e a constante existe (CONV-079).
- [ ] `CancellationToken cancellationToken` último, sem default, repassado (CONV-044/074).
- [ ] Método na cadeia do `RouteMappings`; `Program.cs` chama `app.Add{AggregateFolder}Endpoints()` uma única vez.
- [ ] Nenhum helper recriado; nenhum pacote novo (CONV-087).

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Api.csproj>` sem warnings. Com CONV-002 cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Api.csproj> --verify-no-changes` sem diferenças.
3. Testes conforme os cenários do resource (integração com `WebApplicationFactory` e o use case substituído por mock; mapper REST com `Compile()`). Se o projeto de testes da Api não existe, **não o crie** (pacote novo, CONV-087): reporte Harness parcial (build + format) e pare.
4. Grep na Api por `DbContext`, `IRepository`, `catch (` e `Results.NotFound(` / `Results.BadRequest(` em endpoints — deve dar vazio.

Se qualquer comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, etc.) em vez de reprovar por conteúdo do arquivo, **não trate como passo concluído**: tente novamente uma vez e, se persistir, reporte como Harness incompleto e pare — não declare o endpoint concluído.
