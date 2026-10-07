---
name: migrate-to-dotnet10
description: 'Migra uma solution .NET 8 para .NET 10, subindo a versão em todos os locais definidos: TargetFramework e LangVersion (Directory.Build.props e .csproj), SDK do global.json, tags das imagens .NET do Dockerfile e pacotes para versões estáveis do .NET 10; lista os demais arquivos que citam a versão sem alterá-los. Use sempre que o usuário pedir para migrar, atualizar ou subir uma API/solution de .NET 8 (net8.0) para .NET 10 (net10.0), mesmo sem citar os arquivos. Não use para padronizar arquivos da solution, nem para corrigir código quebrado pela migração.'
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git rev-parse *)
  - Bash(dotnet --version)
  - Bash(dotnet --list-sdks)
  - Bash(dotnet sln * list)
  - Bash(dotnet restore *)
  - Bash(dotnet list *)
  - Bash(dotnet package search *)
---

# Migrar solution .NET 8 para .NET 10

Leva a solution de `net8.0` para `net10.0` subindo a versão do .NET em cada local listado na
seção "Onde a versão sobe". As regras de cada arquivo estão na seção dele, em "Arquivos"; o Fluxo
só dá a ordem. Esta skill altera arquivos de configuração, de projeto e de container; não altera
código-fonte.

Em conflito entre o conteúdo de uma seção e os Exemplos, a seção vence — os exemplos são reforço
didático, não a fonte primária.

## O que gera
Antes de qualquer alteração, produz o relatório de plano e espera a aprovação do usuário. Depois,
em `{SolutionDir}` (diretório do arquivo `.sln`/`.slnx`, esperado em `app/src`):
- **Cria, se ausente:** `global.json`.
- **Edita:** o `Directory.Build.props` existente (só `TargetFramework` e `LangVersion`), cada `.csproj` (remove `TargetFramework` e `LangVersion`), o `global.json` existente (só `sdk.version`), cada `Dockerfile` (só a versão nas imagens .NET) e as versões de pacote (nos `.csproj`, ou em `Directory.Packages.props` quando existir).

Nada além disso: não altera `.cs`, as demais propriedades do `Directory.Build.props`, o restante do
`Dockerfile`, pipeline de CI, `docker-compose`, `appsettings` nem `launchSettings`, não move arquivo
e não adiciona pacote novo. Se um pré-requisito faltar, esta skill para (ver Pré-condições) em vez
de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** solution .NET 8 (`net8.0`) cujos projetos são SDK-style e devem passar a `net10.0`.
- **NÃO usar:** projeto que não é SDK-style. Solution sem arquivo `.sln`/`.slnx`; solution de teste ponta a ponta (`E2E`). Padronização de arquivos e propriedades da solution. Ajuste de código por breaking change e ajuste de pipeline: ficam fora; se o build quebrar por isso, a skill relata e para.

## Contrato

### Regras desta skill
- **Local — qual solution.** Procura-se em `app/src`. Solution cujo nome de arquivo, ou de qualquer pasta do caminho, contém `E2E` (sem diferenciar maiúscula) é ignorada, junto com a pasta dela.
- **Local — aprovação.** A skill só escreve, cria ou instala depois de o usuário aprovar o relatório de plano (Gate de aprovação).
- **Local — onde a versão sobe.** Só se altera a versão do .NET nos locais da tabela abaixo. Todo outro arquivo que cite a versão é apenas relatado (seção "Outros locais").

### Onde a versão sobe
| Local | O que sobe | De | Para |
|---|---|---|---|
| `Directory.Build.props` | `TargetFramework` | qualquer valor | `net10.0` |
| `Directory.Build.props` | `LangVersion` | qualquer valor, ou ausente | `14` |
| `.csproj` | `TargetFramework` e `LangVersion` | declarados no projeto | removidos (o `Directory.Build.props` define) |
| `global.json` | `sdk.version` | `8.0.x` (ou ausente o arquivo) | versão estável do SDK 10 instalado |
| `Dockerfile` | tag das imagens `mcr.microsoft.com/dotnet/{sdk,aspnet,runtime,runtime-deps}` e `ARG` de versão que alimenta o `FROM` | `8.0...` | `10.0...` (tabela da seção `Dockerfile`) |
| Pacotes da família Microsoft | `PackageReference`/`PackageVersion` | `8.x` | maior estável da major 10 |
| Pacotes de terceiros | `PackageReference`/`PackageVersion` | versão atual | maior estável da major atual (regra da seção Pacotes) |

### Rules gerais (dotnet-conventions.md)
- **CONV-001** o `.csproj` não repete as propriedades do `Directory.Build.props`. *Local desta skill:* o arquivo fica em `{SolutionDir}` e a lista de propriedades é `TargetFramework` e `LangVersion`.
- **CONV-058** com Central Package Management, versão de pacote só em `Directory.Packages.props`; o `.csproj` não fixa versão.
- **CONV-087** nenhum pacote novo: só se mudam versões de pacotes que já existem.

### Pré-condições
- `app/src` existe e, descartadas as solutions `E2E`, contém exatamente um arquivo `.sln`/`.slnx` (ou o caminho foi informado).
- `{SolutionDir}/Directory.Build.props` existe.
- O SDK do .NET 10 está instalado e não é preview (`dotnet --list-sdks` lista `10.0.x` sem sufixo de prerelease).
- Todo `.csproj` da solution é SDK-style e usa `TargetFramework` (singular). `TargetFrameworks` (multi-target), em qualquer projeto ou no `Directory.Build.props`: pare e relate onde.

Se alguma falhar, esta skill para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Solution** (opcional) — caminho do `.sln`/`.slnx`. Omitido: procurar em `app/src` (Fluxo, passo 1).

Não há outro input.

## Fluxo (ReAct)

**Fase 0 — Identificação e plano (somente leitura)**
1. **Localizar a solution.** Sem caminho informado, procure `.sln`/`.slnx` recursivamente em `{RepoRoot}/app/src` (`{RepoRoot}` é a raiz do repositório git; sem git, o diretório atual). Descarte as solutions `E2E`. Restando exatamente uma, ela é `{Solution}` e o diretório dela é `{SolutionDir}`; zero ou mais de uma: pare e pergunte. As descartadas, e a pasta de cada uma, ficam fora de todas as buscas e entram no relatório. Liste os projetos com `dotnet sln {Solution} list`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Levantar.** Execute o "Levantar" de cada seção de "Arquivos", na mesma ordem do passo 6. O restore grava em `obj`; isso não conta como alteração.
4. **Calcular o plano.** Aplique no papel o "Executar" de cada seção.
5. **Apresentar o relatório de plano** no formato de `report.md` (seção "Relatório de plano") e parar. A visão geral vem primeiro: a tabela "Onde a versão sobe" preenchida com os valores reais, arquivos a criar e pacotes a atualizar.

**Gate de aprovação**
- Nada é criado, editado nem instalado antes da aprovação explícita do usuário ("aprovo", "pode executar"). Pergunta, ajuste ou comentário não é aprovação: responda e reapresente o relatório.
- Aprovação parcial (o usuário exclui linhas): execute só o aprovado. Linha excluída de `TargetFramework`/`LangVersion` deixa o valor no `.csproj`, que prevalece sobre o `Directory.Build.props`.
- Divergência durante a execução em relação ao relatório aprovado (arquivo novo, valor diferente, pacote sem versão): pare e reapresente o relatório atualizado.
- Se a ferramenta oferecer modo plan (ex.: `EnterPlanMode`/`ExitPlanMode`), use-o para apresentar o relatório. Ele não substitui este gate.

**Fase 1 — Versão do .NET (após a aprovação)**
6. Execute o "Executar" de cada seção de "Arquivos", nesta ordem: `Directory.Build.props`, `.csproj`, `global.json`, `Dockerfile`, Pacotes. A seção "Outros locais" não tem "Executar".

**Fase 2 — Verificação**
7. Verificar pelo Checklist + Harness. Falha por erro de build ou de teste causado pela migração: pare e relate os primeiros erros; não edite código-fonte.

## Arquivos

### `Directory.Build.props`
- **Local:** `{SolutionDir}/Directory.Build.props`. Existe em outro diretório além de `{SolutionDir}` (subdiretório ou ancestral até `{RepoRoot}`): pare e relate.
- **Levantar:** leia `TargetFramework` e `LangVersion` do arquivo (declarados ou não, com ou sem `Condition`).
- **Executar:** ajuste `TargetFramework` para `net10.0` e `LangVersion` para `14` (acrescente os ausentes no primeiro `PropertyGroup` sem `Condition`), preserve todo o resto e relate o que mudou. Propriedade condicional no arquivo: pare e relate.

### `.csproj` (cada projeto da solution)
- **Local:** onde já está.
- **Levantar:** leia `TargetFramework` e `LangVersion` (declarados ou não, com ou sem `Condition`).
- **Executar:** remova `TargetFramework` e `LangVersion`, qualquer que seja o valor. `TargetFramework` com valor diferente de `net8.0` (ex.: `netstandard2.0`) é alerta em linha própria, que o usuário pode excluir. Propriedade com `Condition` (própria ou do `PropertyGroup`): não remova; relate. `PropertyGroup` que ficar vazio é removido. Preserve indentação e o restante do arquivo.

### `global.json`
- **Local:** `{SolutionDir}/global.json`. Existe só em outro diretório: pare e relate.
- **Levantar:** se existir, leia `sdk.version`, `sdk.rollForward` e `sdk.allowPrerelease`. Leia a versão estável mais alta do SDK 10 em `dotnet --list-sdks`: é o `{Sdk10}`.
- **Ausente:** execute `dotnet new globaljson` dentro de `{SolutionDir}` e confira que o `sdk.version` gerado é `{Sdk10}`, sem sufixo de prerelease.
- **Existente:** altere só `sdk.version` para `{Sdk10}`; preserve `rollForward`, `allowPrerelease` e o restante. `sdk.version` já na major 10 estável: nada a fazer. `allowPrerelease` `true`: não altere e relate.
- **Alerta:** o SDK fixado é o instalado nesta máquina; quem tiver SDK mais antigo na mesma major terá erro de resolução, a menos que o `rollForward` permita.

### `Dockerfile`
- **Local:** todo arquivo chamado `Dockerfile`, `Dockerfile.*` ou `*.Dockerfile` na árvore de `{SolutionDir}` e nos diretórios ancestrais até `{RepoRoot}` (ignorando `bin`, `obj`, `.git`, `node_modules` e as pastas das solutions descartadas). Nenhum encontrado: relate, não crie.
- **Levantar:** leia cada `FROM` (inclusive com `--platform` e `AS`) cuja imagem seja `mcr.microsoft.com/dotnet/sdk`, `aspnet`, `runtime` ou `runtime-deps`, e cada `ARG` cujo valor padrão alimente esse `FROM` (`FROM ...:${ARG}`).
- **Executar:** troque só a parte da versão da tag, conforme a tabela. O resto do arquivo não é tocado.

| Tag atual | Tag nova |
|---|---|
| `8.0`, `8.0.<patch>` | `10.0` |
| `8.0-alpine` | `10.0-alpine` |
| `8.0-noble`, `8.0-noble-chiseled` | `10.0-noble`, `10.0-noble-chiseled` |
| `ARG` com valor `8.0...` que alimenta o `FROM` | mesmo mapeamento acima, no valor do `ARG` |
| qualquer outra: sufixo `-slim`, `-bookworm*`, `-bullseye*`, `-jammy*`, `-alpine<versão>`, `-azurelinux*`, digest `@sha256`, imagem `nightly` | não altere a linha; relate como alerta |

- **Alertas fixos:** (a) as imagens .NET 10 não são mais Debian; a tag sem variante (`10.0`) passa a ser Ubuntu 24.04, então o sistema operacional base muda em relação ao `8.0`; (b) `COPY` com caminho relativo, `ENTRYPOINT` e `USER` não são avaliados; (c) a existência da tag nova só é confirmada no Harness.

### Pacotes (`PackageReference`, `PackageVersion`)
- **Local:** cada `.csproj` e, se existir, `Directory.Packages.props` (CONV-058).
- **Levantar:** `dotnet list {Solution} package --outdated` (sem `--include-prerelease`). Para a família Microsoft, liste as versões com `dotnet package search {id} --exact-match --format json` e escolha a maior estável de major 10.
- **Regras:** só pacote direto. Família Microsoft atrelada ao runtime (`Microsoft.AspNetCore.*`, `Microsoft.Extensions.*`, `Microsoft.EntityFrameworkCore.*` e `System.*` publicado com a versão do runtime): maior versão estável da major 10, nunca major 11. Os demais pacotes da Microsoft e os de terceiros: maior versão estável dentro da major atual; a major só sobe quando a versão atual não restaura nem compila em `net10.0`, e cada subida é relatada. Versão prerelease (qualquer sufixo) nunca é instalada. Pacote novo nunca é adicionado (CONV-087).
- **Executar:** com `Directory.Packages.props`, altere só o `PackageVersion`; sem ele, use `dotnet add {csproj} package {id} --version {versao}`. Um pacote por vez, anotando versão anterior e nova. Sem versão estável compatível: mantenha a atual e relate (id, versão, motivo).

| Pacote | Versão alvo |
|---|---|
| Família Microsoft atrelada ao runtime | maior versão estável de major 10 |
| Terceiro, ou outro pacote da Microsoft | maior versão estável dentro da major atual |
| Terceiro que não restaura nem compila em `net10.0` | menor major estável que compila; subida relatada |
| Sem versão estável compatível | manter a atual e relatar |

### Outros locais que citam a versão (somente relato)
- **Local:** `.github/workflows/*`, `azure-pipelines*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `docker-compose*`, `.devcontainer/*`, e qualquer `.csproj`/`.props`/`.targets` com condição em `$(TargetFramework)`. Fora das pastas das solutions descartadas.
- **Levantar:** procure por `net8.0`, `8.0.x`, `dotnet-version`, `dotnet/sdk:8`, `dotnet/aspnet:8`, `dotnet/runtime:8`.
- **Executar:** nada. Cada ocorrência entra no relatório como alerta (arquivo, linha, trecho). Não se altera.

## Raciocínio antes de escrever (CoT)
- Algum projeto é multi-target, tem propriedade condicional ou não é SDK-style? Se sim, pare.
- Algum `TargetFramework` não é `net8.0`? Vira alerta em linha própria, que o usuário pode excluir.
- Cada tag de imagem do `Dockerfile` está na tabela? Se não estiver, a linha fica como está e vira alerta.
- O `global.json` existente tem `allowPrerelease`? A versão fixada é a do SDK instalado.
- O pacote é da família Microsoft ou de terceiros? A versão candidata é estável? Há Central Package Management?
- Algum outro arquivo cita a versão do .NET? Relate, não altere.

## Exemplos (certo/errado)
Leia `examples.md` antes da Fase 1: `Directory.Build.props` e `.csproj` antes e depois, `global.json`
ausente e existente, `Dockerfile` (tags da tabela e linhas que viram alerta), escolha de versões de
pacote e os outros locais relatados.

## Anti-patterns (recusar)
- Escrever, criar ou instalar qualquer coisa antes da aprovação do relatório; tratar pergunta ou comentário como aprovação.
- Considerar a solution `E2E`, ou procurar arquivos dentro da pasta dela.
- Alterar a versão do .NET em local fora da tabela "Onde a versão sobe"; editar pipeline, `docker-compose` ou `.devcontainer`.
- Deixar `TargetFramework` ou `LangVersion` no `.csproj` (CONV-001); sobrescrever o `Directory.Build.props` ou mexer em outra propriedade dele.
- Migrar projeto multi-target, ou remover propriedade condicional, sem parar e relatar.
- Recriar o `global.json` existente (perde `rollForward` e demais chaves), ou aceitar `sdk.version` que não seja 10.x estável.
- No `Dockerfile`: alterar qualquer linha além da versão da tag; trocar sufixo de variante por conta própria; trocar tag com digest; ajustar `COPY`, `ENTRYPOINT` ou `USER`; criar `Dockerfile` ausente.
- Instalar pacote prerelease, pacote da família Microsoft com major 11, ou pacote novo (CONV-087).
- Fixar versão no `.csproj` quando há `Directory.Packages.props` (CONV-058); subir a major de terceiro sem necessidade comprovada pelo build.
- Corrigir código-fonte para fazer o build passar; mover ou criar `.editorconfig`, `.dockerignore` ou `nuget.config`.
- Placeholder (`{SolutionDir}`, `{Sdk10}`, `{id}`...) deixado literal.

## Checklist + Harness

Checklist:
- [ ] Fase 0 sem nenhuma escrita; relatório de plano apresentado no formato de `report.md`; execução só depois da aprovação explícita.
- [ ] Solution escolhida em `app/src`, com as `E2E` descartadas e listadas no relatório.
- [ ] `Directory.Build.props` com `TargetFramework` `net10.0` e `LangVersion` `14`; demais propriedades intactas (CONV-001).
- [ ] Nenhum `.csproj` repete `TargetFramework` ou `LangVersion`; alertas e propriedades condicionais estão no relatório final.
- [ ] `global.json` em `{SolutionDir}` com `sdk.version` `{Sdk10}`; `rollForward` e demais chaves preservadas.
- [ ] Cada `Dockerfile` alterado mudou só a versão nas tags da tabela; as linhas fora da tabela estão como alerta; o alerta de mudança de sistema operacional está no relatório.
- [ ] Nenhum `PackageReference` prerelease; nenhum pacote da família Microsoft fora da major 10; nenhum pacote novo (CONV-087).
- [ ] Com `Directory.Packages.props`, nenhuma versão no `.csproj` (CONV-058).
- [ ] Cada local da tabela "Onde a versão sobe" aparece no relatório final com valor anterior e novo; cada pacote atualizado ou mantido também.
- [ ] Os outros locais que citam a versão estão listados como alerta e não foram alterados.
- [ ] Nenhum `.cs`, pipeline, `docker-compose` ou `appsettings` foi alterado; nenhum arquivo foi movido.
- [ ] Relatório final apresentado em tabelas.

Harness (gate — só conclui quando passam):
1. `dotnet restore {Solution}` sem erro.
2. Para cada projeto, `dotnet msbuild {csproj} -getProperty:TargetFramework,LangVersion` devolve `net10.0` e `14` (exceto linhas excluídas pelo usuário); `dotnet --version`, executado em `{SolutionDir}`, devolve o `{Sdk10}`.
3. `dotnet build {Solution}` sem erro. Warnings novos entram no relatório final; não são corrigidos aqui.
4. `dotnet test {Solution} --no-build` verde, quando a solution tem projeto de teste.
5. `dotnet list {Solution} package` não mostra versão prerelease nem pacote da família Microsoft fora da major 10; `--deprecated` e `--vulnerable`: só relatar.
6. Dockerfile alterado: nenhuma tag `8.0...` restante em imagem .NET fora dos alertas. Com Docker disponível, `docker manifest inspect {imagem}:{tag}` confirma cada tag nova; sem Docker ou sem rede, a tag fica como "não verificada" no relatório.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, feed
indisponível) em vez de reprovar por conteúdo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a migração
como concluída.

Relatório final: ao concluir (ou ao parar), apresente as tabelas da seção "Relatório final" de
`report.md`: onde a versão subiu (valor anterior e novo), o que foi feito por linha, arquivos
editados, pacotes atualizados e mantidos, resultado do Harness e os alertas.
