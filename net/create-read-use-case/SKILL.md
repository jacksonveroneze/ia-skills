---
name: create-read-use-case
description: 'Cria um caso de uso de leitura (.NET/C#, camada Application) — busca por id (GetById) ou listagem paginada (GetPaged): Request, Response, Validator (paginada), interface + UseCase e mapper Mapster, retornando Result, sem mutação. Use sempre que o usuário pedir uma consulta, query, busca, listagem, paginação ou um use case de leitura (ex. GetByIdAccount, GetPagedAccounts), mesmo sem usar o termo. Não use para escrita ou mutação (será create-write-use-case)'
---

# Criar Use Case de Leitura (.NET / Clean Architecture)

Gera um slice de leitura conforme a `dotnet-conventions.md` na raiz do projeto. Esta skill é a
fábrica; a rule é o contrato. Cite os CONV pelo ID. Aqui ficam as regras **comuns**; o que é
específico de cada operação está nos resources.

## Resources (leia o do padrão escolhido, inteiro, antes de escrever)
| Pedido | Resource |
|---|---|
| Sempre, antes de qualquer padrão: tipos base e response/mapper do agregado | `prerequisites.md` |
| Um registro pelo `Id` | `get-by-id.md` |
| Listar / paginar / filtrar / ordenar | `get-paged.md` |

Outro tipo de leitura (por e-mail/documento, agregação, cursor): **não há padrão** — pare e pergunte, não improvise.
Template canônico, exemplos ❌/✅, anti-patterns e checklist **específicos** ficam no resource.

## O que gera
Por operação, em `{ApplicationProjectDir}/Features/{AggregateFolder}/{Operation}/`: `Request`, `Response`,
`I{Operation}UseCase`, `{Operation}UseCase`, `{Operation}Mapper` (+ `{Operation}Validator` no paginado).
Compartilhados por agregado e tipos base: ver `prerequisites.md` e o resource. Nunca sobrescreva
arquivo existente.

## Escopo (quando usar / NÃO usar)
- **Usar:** operação de **leitura** (consulta/projeção), sem mutar estado.
- **NÃO usar:** muta/persiste → `create-write-use-case`.

## Vocabulário (placeholders usados em toda a skill e nos resources)
- `{Aggregate}` tipo singular (`Account`); `{AggregateFolder}` pasta plural (`Accounts`); `{Operation}` nome da operação (definido no resource).
- `{ApplicationRootNamespace}` resolvido do `.csproj` da Application; `{EntityNamespace}` namespace **declarado no arquivo da entidade** (não presuma `.Entities` nem `.{Aggregate}`). São placeholders: nunca copie o valor de um exemplo.

## Contrato

### Rules enforçadas (CONV) — comuns a todos os padrões
- **CONV-016/017** `{Operation}UseCase`; input `{Operation}Request`, output `{Operation}Response`.
- **CONV-085/019** retorna `Task<Result.Result<{Operation}Response>>` (sempre `Result` qualificado); falha esperada nunca é exceção. **CONV-069** `null` não representa erro de negócio.
- **CONV-028** `Request`/`Response` são `record` imutáveis; `Request : IBaseRequest`. **CONV-064** tudo `sealed`.
- Use case: classe `sealed` que implementa `I{Operation}UseCase : IUseCase<{Operation}Request, Result.Result<{Operation}Response>>` e expõe `ExecuteAsync` (nunca `HandleAsync`); primary ctor injeta `IMapper` e a porta (`repository`). **Sem logger.**
- **CONV-067/020** `ArgumentNullException.ThrowIfNull(request)` no início: guard clause contra bug do chamador, não fluxo de negócio.
- **CONV-072/030** agnóstico a transporte e infra: sem HTTP/MCP/gRPC/`HttpContext`, `DbContext`, `IQueryable`.
- **CONV-031** projeção por `IMapper` (Mapster) com `IRegister` **explícito** da feature: todo membro com `.Map`, sem convenção implícita; nunca mapear à mão no use case.
- **CONV-044/074** `cancellationToken` nomeado, sem default. Um parâmetro por linha, inclusive no primary ctor.
- **CONV-088** `async`/`await` só quando há processamento depois do `await` (aqui sempre há); não use em método que só repassa uma chamada. **CONV-089** corpo em bloco; **chaves em todo `if`** (IDE0011, §16).
- **CONV-013** namespace = `RootNamespace` do `.csproj` da Application + pasta. `using` da entidade, da porta e de `DomainErrors` são **explícitos** (namespaces irmãos; o C# não importa sozinho).
- **CONV-087** nenhum pacote novo sem confirmação (Mapster, FluentValidation, Pagination e Result já são stack decidida).

### Pré-condições
Porta `I{Aggregate}Repository` com o método exigido pelo padrão (`create-repository`; se faltar, estenda antes). Entidade no Domain (`create-entity`). O registro de `IMapper`/`TypeAdapterConfig` e dos `IRegister` (explícito, sem scanning — CONV-042) é de `register-dependencies`, que ainda não existe: avise ao terminar.

### Inputs
1. **Operation e Aggregate** — derivados do pedido conforme o resource (`GetById{Aggregate}` / `GetPaged{AggregateFolder}`).
2. **Request** — campo(s) de busca ou filtros. 3. **Campos do `{Aggregate}Response`** — já desempacotados dos VOs (só se o response ainda não existe).
4. **Paginado:** campos ordenáveis (`AllowedOrderBy`) e ordenação default.
5. **RootNamespace / `{EntityNamespace}`** — resolvidos por ReAct, não perguntados de cara.

## Fluxo (ReAct)
1. **Localizar o `.csproj` da Application** (e o arquivo da entidade no Domain).
2. **Resolver `{ApplicationRootNamespace}` e `{EntityNamespace}`.** Nunca use o namespace dos exemplos.
   - Preferencial: `dotnet msbuild <csproj> -getProperty:RootNamespace`. Fallback: `<RootNamespace>`; senão `<AssemblyName>`; senão o nome do `.csproj` sem extensão.
   - `{EntityNamespace}` = `namespace` declarado no arquivo da entidade.
   - Namespace do slice = `{ApplicationRootNamespace}.Features.{AggregateFolder}.{Operation}`; da porta = `{ApplicationRootNamespace}.Abstractions.{AggregateFolder}` (irmão: `using` explícito).
3. **Checar usings globais** da Application (`JacksonVeroneze.NET.Result`, `MapsterMapper`, `Mapster`, `JacksonVeroneze.NET.Pagination.Offset`, `FluentValidation`): se já são `global using`, não repita (`IDE0005`).
4. **Executar `prerequisites.md`** (verifica; cria só o que falta).
5. **Escolher o padrão** na tabela e ler o resource inteiro.
6. **Conferir a porta** e os demais itens que o resource pede (ex.: `DomainErrors`, `{Aggregate}PagedFilter`).
7. **Checar duplicidade**: se `Features/{AggregateFolder}/{Operation}/` já tem algum dos arquivos, não sobrescreva: relate.
8. **Modelar** (CoT) e **escrever** os arquivos pelo template do resource.
9. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT) — comum
- É leitura pura? Sem mutação nem transação: só consulta + projeção.
- Qual padrão atende o pedido? Nenhum → pare e pergunte.
- O Request carrega o mínimo para localizar/filtrar. A forma de saída é `{Aggregate}Response` (Common, reusado).
- Algum tipo de transporte ou infra apareceu na assinatura? Se sim, está errado.
- Antes de criar qualquer tipo comum: ele já existe? (`prerequisites.md`.)

## Anti-patterns comuns (recusar)
- MediatR/`IRequestHandler`; use case sem `IUseCase<,>`/sem interface; `HandleAsync`; `Request` sem `IBaseRequest`.
- Injetar `DbContext`, `IQueryable`, `IEfCoreRepository` ou tipo de transporte.
- Exceção ou `null` para falha esperada; classe de erro própria; logger no use case.
- Mapear à mão no use case, ou mapeamento por convenção (`NewConfig` sem `.Map` por membro).
- Mutar estado; `Result<T>` solto (sempre `Result.Result<T>`); omitir `ThrowIfNull(request)`/`(config)`.
- `if` sem chaves; omitir `using` da entidade, da porta ou de `DomainErrors`; `async`/`await` em método que só repassa uma chamada.
- Copiar namespace de exemplo, ou duplicar "Application" no namespace (o RootNamespace já o contém).
- Duplicar ou sobrescrever tipo já existente (`prerequisites.md`) ou arquivo da pasta da operação.

## Checklist + Harness
Checklist (comum; o resource acrescenta os itens do padrão):
- [ ] `prerequisites.md` executado e resource do padrão lido; nada duplicado.
- [ ] Arquivos em `Features/{AggregateFolder}/{Operation}/`, namespace com o `RootNamespace` da Application; nenhum namespace de exemplo (CONV-013).
- [ ] Use case `sealed`, implementa `I{Operation}UseCase`; `ExecuteAsync` com `ThrowIfNull(request)`; sem logger (CONV-064/067).
- [ ] `Request : IBaseRequest`, `Response` e `Request` são `record`, campos um por linha (CONV-017/028).
- [ ] Sem transporte/infra na assinatura (CONV-072/030); projeção via `IMapper` com `IRegister` explícito (CONV-031).
- [ ] `using` explícito (ou `global using` confirmado) para entidade, porta e `DomainErrors`.
- [ ] `cancellationToken` sem default (CONV-074); `if` com chaves (IDE0011); nenhum pacote novo (CONV-087).

Harness (gate — só conclui quando todos passam):
1. `dotnet build <Application.csproj>` sem warnings. Com CONV-002 cobre analyzers, `.editorconfig` (`IDE*`, inclusive `IDE0011` e `IDE0005`) e `BannedSymbols.txt`.
2. `dotnet format <Application.csproj> --verify-no-changes` sem diferenças.
3. Teste de unidade **verde**, conforme os cenários do resource: mock só da porta (Moq), `IMapper` **real** com os `IRegister` aplicados explicitamente e `Compile()`; critério de conclusão do slice (CONV-048/051/052/053).
4. Grep na Application por termos de infra/transporte (`DbContext`, `HttpContext`, `IQueryable`) — deve dar vazio.

Se qualquer comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, etc.) em vez de reprovar por conteúdo do arquivo, **não trate como passo concluído**: tente novamente uma vez e, se persistir, reporte como Harness incompleto e pare — não declare o use case concluído.