---
name: create-read-use-case
description: 'Cria um caso de uso de leitura (.NET/C#, camada Application) — busca por id (GetById) ou listagem paginada (GetPaged): Request, Response, Validator (paginada), interface + UseCase e mapper Mapster, retornando Result, sem mutação. Use sempre que o usuário pedir uma consulta, query, busca, listagem, paginação ou um use case de leitura (ex. GetAccountById, GetAccountsPaged), mesmo sem usar o termo. Não use para escrita ou mutação.'
---

# Criar Use Case de Leitura (.NET / Clean Architecture)

Gera um slice de leitura conforme a `dotnet-conventions.md` da raiz do projeto. Esta skill é a
fábrica; as rules são o contrato — cite o CONV pelo ID sempre que justificar uma decisão. Aqui
ficam as regras **comuns**; o que é específico de cada operação está nos resources.

Em conflito entre o template de um resource e os exemplos dele, o template vence — os exemplos
são reforço didático, não a fonte primária.

## Resources (leia o do padrão escolhido, inteiro, antes de escrever)
| Pedido | Resource |
|---|---|
| Sempre, antes de qualquer padrão: tipos base e response/mapper do agregado | `prerequisites.md` |
| Um registro pelo `Id` | `get-by-id.md` |
| Listar, paginar, filtrar ou ordenar | `get-paged.md` |

Outro tipo de leitura (por e-mail/documento, agregação, cursor): **não há padrão** — pare e
pergunte, não improvise. Template canônico, exemplos, anti-patterns, checklist e cenários de teste
**específicos** de cada padrão ficam no resource.

## O que gera
`{Operation}` é o nome da operação, definido no resource (`GetAccountById`, `GetAccountsPaged`).
Cada `{X}ProjectDir` é a pasta do `.csproj` daquele projeto.

- Slice: `{ApplicationProjectDir}/Features/{AggregateFolder}/{Operation}/`, namespace `{ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation}`, com `{Operation}Request.cs`, `{Operation}Response.cs`, `I{Operation}UseCase.cs`, `{Operation}UseCase.cs` e `{Operation}Mapper.cs` (+ `{Operation}Validator.cs` no paginado).
- Testes: `{ApplicationTestsProjectDir}/Features/{AggregateFolder}/{Operation}/{Operation}UseCaseTests.cs` (+ `{Operation}ValidatorTests.cs` no paginado), namespace `{ApplicationTestsRootNamespace}.Features.{AggregateFolder}.{Operation}`, com os cenários do resource.
- Compartilhados, **só se não existirem**: tipos base, response e mapper do agregado (`prerequisites.md`); filtro do agregado no paginado e `NotFound` em `DomainErrors` no GetById (resource).

Nada além disso: sem porta, sem entidade, sem registro de DI. Se algum desses faltar como
pré-requisito, esta skill para (ver Pré-condições) em vez de criá-lo. Nunca sobrescreva arquivo
existente.

## Escopo (quando usar / NÃO usar)
- **Usar:** operação de **leitura** (consulta/projeção), sem mutar estado.
- **NÃO usar:** operação que muta ou persiste estado.

## Contrato

### Rules de use case / Application
- **CONV-009** Vertical slice dentro de cada camada, não por tipo técnico: `Features/{AggregateFolder}/{Operation}/`.
- **CONV-016** Use case = verbo + sujeito (+ qualificador) + sufixo `UseCase`: `GetAccountByIdUseCase`, `TransferMoneyUseCase`. A operação-base (`GetAccountById`) nomeia os demais artefatos do slice. NÃO DEVE inverter a ordem (`GetByIdAccount`). *Aqui:* `Get{Aggregate}ById` e `Get{AggregateFolder}Paged` (ex.: `GetAccountById`, `GetAccountsPaged`).
- **CONV-017** Input = `{Operation}Request`; output = `{Operation}Response`.
- **CONV-018** Validator = `{Operation}Validator`. NÃO existe tipo `Handler` — o use case é o handler.
- **CONV-019** Todo use case retorna `Task<Result<TResponse>>`. NÃO DEVE lançar exceção para falha esperada/de negócio. *Aqui:* sempre `Task<Result.Result<{Operation}Response>>`, com `Result` qualificado.
- **CONV-027** Use case = interface `I{Operation}UseCase : IUseCase<{Operation}Request, TResponse>` (`IUseCase<TRequest, TResponse>` compartilhado, método `ExecuteAsync`) + classe concreta única `{Operation}UseCase` que a implementa — ela é o handler. NÃO DEVE existir `Handler` separado, mediator, `HandleAsync`, nem `ILogger` injetado no use case. *Aqui:* o primary constructor injeta `IMapper` e a porta (`repository`).
- **CONV-028** `Request`/`Response` são `record` imutáveis. *Aqui:* `Request : IBaseRequest`.
- **CONV-031** Mapeamento entidade para `Response` via Mapster com `IRegister` explícito por feature; todo membro declarado — a config DEVE falhar em membro de destino não mapeado. *Aqui:* todo membro com `.Map`, sem convenção implícita; nunca mapear à mão no use case.
- **CONV-072** Use case é **agnóstico a transporte**: NÃO DEVE referenciar HTTP, MCP, gRPC, GraphQL nem `HttpContext`. Adaptação de protocolo só na camada de transporte.
- **CONV-030 (trecho de Application)** Application NÃO DEVE referenciar tipo concreto de infra (`DbContext`, provider). *Aqui:* o use case depende só da porta `I{Aggregate}Repository`; nada de `IQueryable` nem `IEfCoreRepository` na assinatura.
- **CONV-021 (trecho de Application)** Erro compartilhado entre tipos (ex.: not-found) fica em `Domain/Common/DomainErrors.cs`, classe estática por agregado (`{Aggregate}Error`). O use case usa esse erro; NÃO DEVE declarar `Error` local nem classe de erro própria.
- **Local desta skill (formatação):** cada parâmetro de método, de interface e de primary constructor (mesmo com um só) fica em sua própria linha, indentado; `if` sempre com chaves (IDE0011); `using` da entidade, da porta e de `DomainErrors` são explícitos (namespaces irmãos: o C# não importa sozinho).

### Rules gerais (dotnet-conventions.md)
- **CONV-020** falha esperada é `Result`, nunca exceção; exceção só para bug. **CONV-069** `null` não representa erro de negócio.
- **CONV-067** `ArgumentNullException.ThrowIfNull(request)` na primeira linha do `ExecuteAsync`: guard clause contra bug do chamador, não fluxo de negócio.
- **CONV-029** validação de input em validator separado, nunca inline no use case. **CONV-038** entrada validada antes da lógica de negócio.
- **CONV-064** tudo `sealed` (exceto tipo abstrato). **CONV-066** primary constructor para a injeção. **CONV-063** identificadores em inglês.
- **CONV-044/074** `cancellationToken` propagado, nomeado, sem default.
- **CONV-088** `await` só quando o resultado é usado no próprio método ou há mais de uma chamada em sequência; método que só repassa uma chamada retorna a `Task` direto. *Aqui:* o `ExecuteAsync` sempre processa depois do `await`, então usa `async`/`await`.
- **CONV-089** corpo em bloco em todo método; nenhum `=>` (expression-bodied). **CONV-090** parâmetro de lambda com nome descritivo do papel.
- **CONV-003** sem `!` (null-forgiving).
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha o caminho da pasta — com o `RootNamespace` do `.csproj` de cada projeto.
- **CONV-048/049/050/051/052/053** testes: xUnit + Moq + Shouldly, `Method_Scenario_ExpectedResult`, AAA, ao menos um teste passando por use case, mock só da porta (objeto real para o mapper), asserção sobre tipo e `Code` do erro.
- **CONV-087** nenhum pacote novo sem confirmação (Mapster, FluentValidation, Pagination e Result já são stack decidida).

### Pré-condições
Existem, antes de começar:
- a porta `I{Aggregate}Repository` em `{ApplicationProjectDir}/Abstractions/Repositories/{AggregateFolder}/`, com o método que o padrão exige (ver resource);
- a entidade em `{DomainProjectDir}/{AggregateFolder}/{Aggregate}.cs` e, no GetById, o arquivo `Domain/Common/DomainErrors.cs`;
- o projeto de testes da Application, com xUnit, Moq e Shouldly;
- na Application, os pacotes `Mapster`, `FluentValidation`, `JacksonVeroneze.NET.Pagination` e `JacksonVeroneze.NET.Result`.

Esta skill não cria porta, entidade, `DomainErrors.cs`, projeto de teste, nem qualquer outro
artefato fora dos descritos em "O que gera": se um pré-requisito estiver ausente, ela para e
relata o que falta e onde era esperado — sem apontar como resolver. Ela também não registra DI:
ao terminar, avise que o registro de `IMapper`/`TypeAdapterConfig`, dos `IRegister` (explícito,
sem scanning) e do Validator não foi feito.

### Inputs
1. **Aggregate** — entidade, PascalCase, singular (`Account`). **AggregateFolder** — pasta do agregado, plural (`Accounts`), a mesma onde a entidade já está no Domain. **Operation** — derivada do pedido conforme o resource (`Get{Aggregate}ById` / `Get{AggregateFolder}Paged`).
2. **Request** — campo(s) de busca ou filtros.
3. **Campos do `{Aggregate}Response`** — já desempacotados dos value objects (só se o response ainda não existe).
4. **Paginado:** campos ordenáveis (`AllowedOrderBy`) e ordenação default.

`RootNamespace` dos projetos, `EntityNamespace`, `IdType` e os demais valores do resource são
resolvidos pelo Fluxo, não perguntados. São placeholders: nunca copie o valor de um exemplo.

## Fluxo (ReAct)
1. **Localizar os `.csproj`** da Application, do Domain e do projeto de testes da Application, e o arquivo da entidade.
2. **Escolher o padrão** pela tabela de Resources e ler o resource inteiro. Nenhum padrão atende: pare e pergunte.
3. **Resolver identificação.** Nunca use o namespace dos exemplos.
   - `ApplicationRootNamespace` e `ApplicationTestsRootNamespace`, cada um do seu `.csproj`. Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace`. Fallback: `<RootNamespace>`; senão `<AssemblyName>`; senão o nome do `.csproj` sem extensão.
   - `EntityNamespace` e `IdType`: leia o arquivo da entidade; o namespace é o da linha `namespace` (não presuma `.Entities` nem `.{Aggregate}`), o tipo é o da propriedade `Id`.
   - Os demais valores que o resource pedir (`DomainErrorsNamespace`, `SortDirectionNamespace`).
   - Declare, num bloco só, antes de escrever qualquer coisa: `Aggregate=`, `AggregateFolder=`, `Operation=`, `IdType=`, `EntityNamespace=`, `ApplicationRootNamespace=`, `ApplicationTestsRootNamespace=`, os valores do resource, e o path final de cada arquivo do slice e dos testes.
4. **Checar existência.** Se `Features/{AggregateFolder}/{Operation}/` já tem algum dos arquivos do slice, ou algum dos arquivos de teste já existe, pare aqui — não sobrescreva, relate.
5. **Checar usings globais** da Application e do projeto de testes (`JacksonVeroneze.NET.Result`, `MapsterMapper`, `Mapster`, `JacksonVeroneze.NET.Pagination.Offset`, `FluentValidation`): se já são `global using`, não repita o `using` (`IDE0005` é erro).
6. **Executar `prerequisites.md`** (verifica; cria só o que falta).
7. **Conferir a porta** e os demais itens que o resource pede (ex.: `DomainErrors`, `{Aggregate}PagedFilter`).
8. **Modelar** (CoT) e **escrever** o slice e os testes pelos templates e cenários do resource.
9. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT) — comum
- É leitura pura? Sem mutação nem transação: só consulta e projeção.
- Qual padrão atende o pedido? Nenhum: pare e pergunte.
- O Request carrega o mínimo para localizar ou filtrar. A forma de saída é `{Aggregate}Response` (Common, reusado).
- Algum tipo de transporte ou infra apareceu na assinatura? Se sim, está errado.
- Antes de criar qualquer tipo comum: ele já existe? (`prerequisites.md`.)

## Anti-patterns comuns (recusar)
- MediatR/`IRequestHandler`; use case sem `IUseCase<,>` ou sem interface; `HandleAsync`; `Request` sem `IBaseRequest`.
- Injetar `DbContext`, `IQueryable`, `IEfCoreRepository` ou tipo de transporte (CONV-030/072).
- Exceção ou `null` para falha esperada; classe de erro própria; logger no use case (CONV-020/027).
- Mapear à mão no use case, ou mapeamento por convenção (`NewConfig` sem `.Map` por membro) (CONV-031).
- Mutar estado; `Result<T>` solto (sempre `Result.Result<T>`); omitir `ThrowIfNull(request)` no use case e `ThrowIfNull(config)` no mapper.
- `if` sem chaves; omitir `using` da entidade, da porta ou de `DomainErrors`; `async`/`await` em método que só repassa uma chamada (CONV-088).
- Nome de operação com a ordem invertida (`GetByIdAccount`, `GetPagedAccounts`) (CONV-016).
- Copiar namespace de exemplo, deixar placeholder literal, ou duplicar "Application" no namespace (o `RootNamespace` já o contém).
- Duplicar ou sobrescrever tipo já existente (`prerequisites.md`) ou arquivo da pasta da operação.
- Criar porta, entidade, `DomainErrors.cs` ou qualquer outro artefato fora do escopo, em vez de parar e relatar.

## Checklist + Harness
Checklist (comum; o resource acrescenta os itens do padrão):
- [ ] `prerequisites.md` executado e resource do padrão lido; nada duplicado.
- [ ] Slice e testes nos paths e namespaces de "O que gera", com o `RootNamespace` de cada projeto; nenhum namespace de exemplo (CONV-013).
- [ ] Operação nomeada `Get{Aggregate}ById` ou `Get{AggregateFolder}Paged`, e os demais artefatos derivados dela (CONV-016/017/018).
- [ ] Use case `sealed`, implementa `I{Operation}UseCase`; `ExecuteAsync` com `ThrowIfNull(request)`; sem logger (CONV-064/067/027).
- [ ] `Request : IBaseRequest`; `Request` e `Response` são `record`; campos um por linha (CONV-017/028).
- [ ] Sem transporte/infra na assinatura (CONV-072/030); projeção via `IMapper` com `IRegister` explícito (CONV-031).
- [ ] `using` explícito (ou `global using` confirmado) para entidade, porta e `DomainErrors`.
- [ ] `cancellationToken` sem default (CONV-074); `if` com chaves (IDE0011); nenhum `=>` em método (CONV-089); nenhum pacote novo (CONV-087).
- [ ] Nenhum pré-requisito ausente foi criado por esta skill — o que faltava foi relatado, não gerado.
- [ ] Ao terminar, avisado que o registro de DI (`IMapper`, `IRegister`, Validator) não foi feito.

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Application.csproj>` sem warning. Com CONV-002 cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Application.csproj> --verify-no-changes` sem diferença, e o mesmo para o projeto de testes.
3. Testes de unidade **verdes**, conforme os cenários do resource: mock só da porta (Moq), `IMapper` **real** com os `IRegister` aplicados explicitamente e `Compile()`; critério de conclusão do slice (CONV-048/051/052/053).
4. Grep na Application por termos de infra/transporte (`DbContext`, `HttpContext`, `IQueryable`, `IEfCoreRepository`) — deve dar vazio.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, etc.)
em vez de reprovar por conteúdo do arquivo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare o use case
como concluído.
