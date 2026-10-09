---
name: replace-swagger-with-scalar
description: 'Substitui o Swagger (Swashbuckle) pela geração nativa de OpenAPI do ASP.NET Core com a interface Scalar numa solution .NET 10. Localiza o projeto Infrastructure, remove os pacotes do Swashbuckle, renomeia a classe SwaggerExtensions para OpenApiExtensions e seus métodos (e os chamadores), adiciona Microsoft.AspNetCore.OpenApi e Scalar.AspNetCore e ajusta o launchUrl. Use sempre que o usuário pedir para remover, trocar ou migrar o Swagger, o Swashbuckle ou o Swagger UI por OpenAPI ou Scalar, mesmo sem citar os pacotes. Não use para mudar a versão do .NET, padronizar arquivos da solution, nem para portar filtros e anotações do Swashbuckle.'
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git rev-parse *)
  - Bash(git mv *)
  - Bash(dotnet --list-sdks)
  - Bash(dotnet sln * list)
  - Bash(dotnet msbuild * -getProperty:*)
  - Bash(dotnet list *)
  - Bash(dotnet package search *)
  - Bash(dotnet add * package *)
  - Bash(dotnet remove * package *)
---

# Substituir Swagger por OpenAPI nativo e Scalar

Troca a documentação baseada em Swashbuckle pelo documento OpenAPI do ASP.NET Core e pela interface
Scalar, reaproveitando a classe de extensão que já registra o Swagger. As regras de cada arquivo estão
em "Arquivos"; o Fluxo só dá a ordem. Em conflito entre uma seção e os Exemplos, a seção vence.

## O que gera
Antes de qualquer alteração, produz o relatório de plano e espera a aprovação do usuário. Depois,
no projeto `{InfraProject}` (o `*.Infrastructure`) e nos chamadores, troca o antigo pelo novo:

| Antigo | Novo |
|---|---|
| Pacotes `Swashbuckle.AspNetCore*` | removidos |
| (nenhum) | `Microsoft.AspNetCore.OpenApi` (major 10) e `Scalar.AspNetCore`, no `{InfraProject}` |
| `Extensions/SwaggerExtensions.cs`, classe `SwaggerExtensions` | `Extensions/OpenApiExtensions.cs`, classe `OpenApiExtensions` |
| Método que chama `AddSwaggerGen` | `AddOpenApiDocumentation`, com `services.AddOpenApi()` |
| Método que chama `UseSwagger`/`UseSwaggerUI` | `UseOpenApiDocumentation(WebApplication)`, com `MapOpenApi` e `MapScalarApiReference` sob `IsDevelopment()` |
| Chamadores dos nomes antigos | chamam os nomes novos |
| `launchUrl` `swagger` | `scalar` |
| URLs `/swagger` e `/swagger/v1/swagger.json` | `/scalar` e `/openapi/v1.json` |

Nada além disso: não cria transformer, não porta a configuração da lambda do `AddSwaggerGen` (título,
segurança, comentários XML: vai para o relatório), não configura título, versão ou autenticação, e
só relata os outros arquivos que citam o Swagger (CI, `Dockerfile`, `docker-compose`, `appsettings`).

## Escopo (quando usar / NÃO usar)
- **Usar:** solution `net10.0` com um projeto `*.Infrastructure` cuja classe `SwaggerExtensions` registra o Swashbuckle.
- **NÃO usar:** projeto que não é SDK-style; solution sem `.sln`/`.slnx` ou `E2E`; mudança de versão do .NET; padronização de arquivos; portar filtro ou anotação do Swashbuckle (a skill para).

## Contrato

### Regras desta skill
- **Local — qual solution.** Procura-se em `app/src`. Solution cujo nome de arquivo, ou de qualquer pasta do caminho, contém `E2E` (sem diferenciar maiúscula) é ignorada, junto com a pasta dela.
- **Local — aprovação.** Nada é escrito, renomeado ou instalado antes de o usuário aprovar o relatório de plano.
- **Local — nomes fixos.** Os métodos novos são `AddOpenApiDocumentation` e `UseOpenApiDocumentation`; não usam `AddOpenApi`/`MapOpenApi`, para não colidir com os métodos do framework.
- **Local — só em Development.** A guarda `IsDevelopment()` fica dentro de `UseOpenApiDocumentation`: o documento descreve toda a superfície da API.
- **Local — pacotes novos.** Só os dois da tabela: `Microsoft.AspNetCore.OpenApi` na maior estável da major 10 e `Scalar.AspNetCore` na maior estável. Prerelease nunca.

### Rules gerais (dotnet-conventions.md)
- **CONV-087** pacote novo só com confirmação. *Local desta skill:* os dois pacotes acima são a stack decidida; nenhum outro entra.
- **CONV-058** com Central Package Management, versão só em `Directory.Packages.props`. *Local desta skill:* sem ele, a versão fica no `.csproj`.
- **CONV-098** extensão nova usa bloco `extension`. *Local desta skill:* a classe `OpenApiExtensions` é escrita assim.
- **CONV-002** analyzers como erro. *Local desta skill:* `using` sem uso quebra o build, então a skill os remove.

### Pré-condições
- `app/src` existe e, descartadas as solutions `E2E`, contém exatamente um `.sln`/`.slnx` (ou o caminho foi informado).
- Todo `.csproj` é SDK-style e o MSBuild o avalia sem erro.
- Existe exatamente um projeto com nome terminado em `.Infrastructure` (`{InfraProject}`), `net10.0`, com `Extensions/SwaggerExtensions.cs`. A classe só tem dois métodos, cada um só com o parâmetro `this`: um que chama `AddSwaggerGen` e um que chama `UseSwagger`/`UseSwaggerUI`.
- Nenhum outro `.cs` usa o namespace `Swashbuckle.` nem `Microsoft.OpenApi.Models`.
- O SDK 10 estável está instalado (`dotnet --list-sdks`) e `dotnet package search` devolve versão estável dos dois pacotes.

Se alguma falhar, esta skill para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Solution** (opcional) — caminho do `.sln`/`.slnx`. Omitido: procurar em `app/src`.

## Fluxo (ReAct)

**Fase 0 — Plano (somente leitura)**
1. **Localizar a solution** em `{RepoRoot}/app/src` (`{RepoRoot}` é a raiz do repositório git; sem git, o diretório atual), descartando as `E2E`. Exatamente uma é `{Solution}`; zero ou mais de uma: pare e pergunte. Liste os projetos com `dotnet sln {Solution} list` e identifique o `{InfraProject}`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Levantar e calcular** o "Levantar" e o "Executar" de cada seção de "Arquivos", no papel.
4. **Apresentar o relatório de plano** no formato de `report.md` e parar.

**Gate de aprovação**
- Nada é escrito antes da aprovação explícita ("aprovo", "pode executar"). Pergunta ou comentário não é aprovação: responda e reapresente o relatório.
- Aprovação parcial: execute só o aprovado. Linha excluída da troca da classe e dos chamadores mantém o pacote Swashbuckle; linha excluída da adição de um pacote exclui a troca que depende dele.
- Divergência durante a execução em relação ao plano aprovado: pare e reapresente o relatório.

**Fase 1 — Substituição (após a aprovação)**
5. Execute o "Executar" de cada seção de "Arquivos", nesta ordem: Pacotes, Classe de extensão, Chamadores, `launchSettings.json`.

**Fase 2 — Verificação**
6. Verificar pelo Checklist + Harness. Falha causada pela substituição: pare e relate; não edite outro código-fonte.

## Arquivos

### Pacotes
- **Levantar:** `dotnet list {Solution} package` (ids iniciados por `Swashbuckle.AspNetCore` e se os dois novos já existem) e `dotnet package search {id} --exact-match --format json` para as versões. Pacote de terceiros com `Swashbuckle` no id fora desse prefixo: só relatado.
- **Executar:** remova os pacotes Swashbuckle de todo `.csproj` (`dotnet remove {csproj} package {id}`; com `Directory.Packages.props`, tire também o `PackageVersion` se ninguém mais o usar). Adicione os dois no `{InfraProject}` (`dotnet add {csproj} package {id} --version {versao}`); com `Directory.Packages.props`, confira que a versão foi para ele. Já referenciado: mantenha. Um por vez.
- **Não faz:** não adiciona outro pacote, não sobe versão existente e não adiciona referência ao framework: se o build não resolver `WebApplication` no `{InfraProject}`, pare e relate.

### Classe de extensão (`{ExtFile}`)
- **Local:** `{InfraProject}/Extensions/SwaggerExtensions.cs`.
- **Executar:** renomeie o arquivo e a classe para `OpenApiExtensions` (`git mv` sob git, senão `mv`; CONV-012); o namespace não muda. Reescreva a classe como no exemplo de `examples.md`: o método de serviços vira `AddOpenApiDocumentation` e o de pipeline vira `UseOpenApiDocumentation`, agora sobre `WebApplication`. Troque os `using` (entra `Scalar.AspNetCore`; saem `Swashbuckle` e `Microsoft.OpenApi.Models`). Cada configuração da lambda do `AddSwaggerGen` é relatada como "não portada".
- **Alertas fixos:** (a) o documento passa a ser OpenAPI 3.1, padrão do .NET 10, e consumidor que só aceita 3.0 pode quebrar; (b) as URLs mudam; (c) a documentação passa a existir só em Development, mesmo que o chamador não tenha guarda; (d) os endpoints novos seguem as convenções de autorização do app.

### Chamadores
Em todo `.cs` da solution (host, testes), troque cada ocorrência dos nomes antigos pelos novos, mapeando pelo papel do método: `SwaggerExtensions` para `OpenApiExtensions`, o método de serviços para `AddOpenApiDocumentation` e o de pipeline para `UseOpenApiDocumentation`. Troca em passada única; nenhuma outra parte da linha ou do arquivo é alterada. Cada troca entra no plano com `arquivo:linha`.

### `launchSettings.json`
Em cada `Properties/launchSettings.json`, troque `launchUrl` de `swagger` (ou iniciado por `swagger/`) para `scalar`, no lugar, preservando a formatação. Outro valor: não altera; relate.

### Outros locais que citam o Swagger
Somente relato. Busque `swagger` e `Swashbuckle` (sem diferenciar maiúscula) em `appsettings*`, `Dockerfile*`, `docker-compose*`, pipelines, `*.http` e documentação, fora de `bin`, `obj`, `.git` e das pastas das solutions descartadas. Cada ocorrência vira alerta.

## Raciocínio antes de escrever (CoT)
- Qual é o `{InfraProject}` e a classe só tem os dois métodos esperados? Quem chama cada um, inclusive testes?
- O que a lambda configura e não será portado? Os pacotes novos já existem? Há `Directory.Packages.props`?

## Template canônico
A classe `OpenApiExtensions` é a do exemplo em `examples.md`; só os nomes de projeto e de namespace mudam.

## Exemplos (certo/errado)
Leia `examples.md` antes da Fase 1: a classe de extensão antes e depois, com um chamador.

## Anti-patterns (recusar)
- Escrever, renomear ou instalar antes da aprovação do plano.
- Renomear a classe e deixar chamador, `using` ou pacote do Swashbuckle → atualize todos os chamadores e remova o que está no plano.
- Chamar os métodos novos de `AddOpenApi`/`MapOpenApi` → use os nomes fixos.
- Mapear os endpoints fora de `IsDevelopment()` → deixe a guarda dentro de `UseOpenApiDocumentation`.
- Portar a configuração do `AddSwaggerGen` ou criar transformer → relate o trecho.
- Adicionar pacote além dos dois, instalar prerelease ou fixar versão no `.csproj` com `Directory.Packages.props` (CONV-087, CONV-058).
- Editar `Dockerfile`, pipeline ou `appsettings` que citam `/swagger` → relate.
- Corrigir código-fonte para o build passar; deixar placeholder (`{InfraProject}`, `{versao}`) literal.

## Checklist + Harness

Checklist:
- [ ] Fase 0 sem escrita; execução só após a aprovação explícita.
- [ ] Nenhum pacote, chamada, `using` ou nome do Swashbuckle restante; os dois pacotes novos no `{InfraProject}`, estáveis, o OpenApi na major 10.
- [ ] `OpenApiExtensions.cs` igual ao exemplo; todos os chamadores atualizados; `launchUrl` trocado.
- [ ] Configuração não portada e outros locais listados como alerta; relatório final no formato de `report.md`.

Harness (gate — só conclui quando passam):
1. `dotnet restore {Solution}` e `dotnet build {Solution}` sem erro; `dotnet test {Solution} --no-build` verde, quando há teste. Warnings novos entram no relatório.
2. `dotnet list {Solution} package` sem `Swashbuckle.AspNetCore*`.
3. Buscar `SwaggerExtensions`, `AddSwaggerGen`, `UseSwagger` e `Swashbuckle` nos `.cs` e `.csproj`: nenhuma ocorrência (exceto linha excluída pelo usuário, que vira pendência).

A skill não executa a API: abrir `/scalar` e `/openapi/v1.json` fica como "não verificado". Falha de
ambiente (timeout, feed indisponível): tente de novo uma vez e, se persistir, reporte "Harness
incompleto" e pare.