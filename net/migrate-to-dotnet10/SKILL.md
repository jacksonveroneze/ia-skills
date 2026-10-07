---
name: migrate-to-dotnet10
description: 'Migra uma solution .NET 8 para .NET 10: padroniza os arquivos de raiz (Directory.Build.props, global.json, BannedSymbols.txt, Dockerfile, .dockerignore, nuget.config, .editorconfig), limpa os .csproj e atualiza os pacotes para versões estáveis do .NET 10. Use sempre que o usuário pedir para migrar, atualizar ou subir uma API/solution de .NET 8 (net8.0) para .NET 10 (net10.0), mesmo sem citar os arquivos. Não use para projeto que não é SDK-style, nem para corrigir código quebrado pela migração.'
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

Padroniza a solution e atualiza os pacotes para o .NET 10, na ordem: arquivos de raiz, projetos,
pacotes, verificação. Esta skill altera arquivos de configuração e de projeto; não altera
código-fonte.

Em conflito entre o Template canônico e os Exemplos, o Template vence — os exemplos são reforço
didático, não a fonte primária.

## O que gera
Antes de qualquer alteração, produz o relatório de plano e espera a aprovação do usuário. Depois,
em `{SolutionDir}` (diretório do arquivo `.sln`/`.slnx`, esperado em `app/src`):
- **Cria, se ausente:** `Directory.Build.props`, `global.json`, `BannedSymbols.txt`.
- **Move para `{SolutionDir}`, se estiver em outro diretório:** `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`.
- **Edita:** cada `.csproj` da solution (remove propriedades que o `Directory.Build.props` passa a definir, ajusta `Nullable`/`ImplicitUsings`, acrescenta `RootNamespace`) e as versões de pacote (nos `.csproj`, ou em `Directory.Packages.props` quando existir).

Nada além disso: não altera `.cs`, não altera o conteúdo do `Dockerfile`, pipeline de CI, `appsettings`
nem `launchSettings`, e não adiciona pacote novo. Se um pré-requisito faltar, esta skill para (ver
Pré-condições) em vez de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** solution .NET 8 (`net8.0`) cujos projetos são SDK-style e devem passar a `net10.0`.
- **NÃO usar:** projeto que não é SDK-style. Solution sem arquivo `.sln`/`.slnx`; solution de teste ponta a ponta (`E2E`). Ajuste de código por breaking change, troca de imagem base do Docker ou ajuste de pipeline: ficam fora; se o build quebrar por isso, a skill relata e para.

## Contrato

### Regras desta skill
- **Local — fonte da verdade.** `{SolutionDir}/Directory.Build.props` define `TargetFramework`, `LangVersion`, `Nullable`, `ImplicitUsings`, `PublishAot` e `SatelliteResourceLanguages` para todos os projetos. O `.csproj` não repete essas propriedades.
- **Local — Nullable e ImplicitUsings.** O valor efetivo de um projeto é o da diretiva no `.csproj`; diretiva ausente conta como `disable`. O valor do `Directory.Build.props` sai da tabela do Template canônico. Valor que não seja `enable` nem `disable` (ex.: `annotations`, ou diretiva condicional): pare e relate.
- **Local — pacotes.** Só `PackageReference` direto (e `PackageVersion`, com Central Package Management). Pacote da família Microsoft atrelada ao runtime vai para a maior versão estável da major 10, nunca para major 11. Pacote de terceiros vai para a maior versão estável dentro da major atual; a major só sobe quando a versão atual não restaura nem compila em `net10.0`, e cada subida é relatada. Versão prerelease (`-preview`, `-rc`, `-alpha`, `-beta`, qualquer sufixo) nunca é instalada.
- **Local — qual solution.** Procura-se em `app/src`. Solution cujo nome de arquivo, ou de qualquer pasta do caminho, contém `E2E` (sem diferenciar maiúscula) é ignorada, junto com a pasta dela.
- **Local — aprovação.** A skill só escreve, cria, move ou instala depois de o usuário aprovar o relatório de plano (Gate de aprovação).
- **Local — família Microsoft atrelada ao runtime:** `Microsoft.AspNetCore.*`, `Microsoft.Extensions.*`, `Microsoft.EntityFrameworkCore.*` e `System.*` publicado com a versão do runtime. Os demais pacotes da Microsoft seguem a regra de terceiros.

### Rules gerais (dotnet-conventions.md)
- **CONV-001** o `.csproj` não repete as propriedades do `Directory.Build.props`. *Local desta skill:* o arquivo fica em `{SolutionDir}` e a lista de propriedades é a da regra local acima.
- **CONV-058** com Central Package Management, versão de pacote só em `Directory.Packages.props`; o `.csproj` não fixa versão.
- **CONV-087** nenhum pacote novo: só se mudam versões de pacotes que já existem.

### Pré-condições
- `app/src` existe e, descartadas as solutions `E2E`, contém exatamente um arquivo `.sln`/`.slnx` (ou o caminho foi informado).
- O SDK do .NET 10 está instalado e não é preview (`dotnet --list-sdks` lista `10.0.x` sem sufixo de prerelease).
- Todo `.csproj` da solution é SDK-style e usa `TargetFramework` (singular). `TargetFrameworks` (multi-target): pare e relate qual projeto.

Se alguma falhar, esta skill para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Solution** (opcional) — caminho do `.sln`/`.slnx`. Omitido: procurar em `app/src` (Fluxo, passo 1).

Não há outro input. Valores que a skill calcula (Nullable, ImplicitUsings, RootNamespace) são derivados dos projetos.

## Fluxo (ReAct)

**Fase 0 — Identificação e plano (somente leitura)**
1. **Localizar a solution.** Sem caminho informado, procure `.sln`/`.slnx` recursivamente em `{RepoRoot}/app/src` (`{RepoRoot}` é a raiz do repositório git; sem git, o diretório atual). Descarte as solutions `E2E`. Restando exatamente uma, ela é `{Solution}` e o diretório dela é `{SolutionDir}`; zero ou mais de uma: pare e pergunte. As descartadas, e a pasta de cada uma, ficam fora de todas as buscas seguintes e entram no relatório. Liste os projetos com `dotnet sln {Solution} list`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Coletar o estado.** Para cada `.csproj`, leia `TargetFramework`, `LangVersion`, `Nullable`, `ImplicitUsings`, `PublishAot`, `SatelliteResourceLanguages` e `RootNamespace`. Procure por **nome**, na árvore de `{SolutionDir}` e nos diretórios ancestrais até `{RepoRoot}` (ignorando `bin`, `obj`, `.git`, `node_modules` e as pastas das solutions descartadas): `Directory.Build.props`, `Directory.Packages.props`, `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`, `global.json`, `BannedSymbols.txt`. Levante os pacotes com `dotnet list {Solution} package --outdated` (sem `--include-prerelease`) e, para a família Microsoft, as versões com `dotnet package search {id} --exact-match --format json`. O restore grava em `obj`; isso não conta como alteração.
4. **Calcular o plano.** Valor de `Nullable` e de `ImplicitUsings` (tabela do Template canônico), `RootNamespace` de cada projeto (passo 9), versão alvo de cada pacote (passos 10 e 11) e a ação de cada arquivo (criar, mover, editar, nada, parar), aplicando no papel as regras das Fases 1 e 2.
5. **Apresentar o relatório de plano** no formato de `report.md` (seção "Relatório de plano") e parar. A visão geral vem primeiro: arquivos a criar, arquivos a mover e pacotes a atualizar.

**Gate de aprovação**
- Nada é criado, movido, editado nem instalado antes da aprovação explícita do usuário ("aprovo", "pode executar"). Pergunta, ajuste ou comentário não é aprovação: responda e reapresente o relatório.
- Aprovação parcial (o usuário exclui linhas): execute só o aprovado.
- Divergência durante a execução em relação ao relatório aprovado (arquivo novo, valor diferente, pacote sem versão): pare e reapresente o relatório atualizado.
- Se a ferramenta oferecer modo plan (ex.: `EnterPlanMode`/`ExitPlanMode`), use-o para apresentar o relatório. Ele não substitui este gate.

**Fase 1 — Padronização (após a aprovação)**
6. **`Directory.Build.props`.**
   - Existe em outro diretório (subdiretório de `{SolutionDir}` ou ancestral até `{RepoRoot}`): pare e relate; não crie duplicata nem mova.
   - Não existe: crie em `{SolutionDir}` com o Template canônico.
   - Existe em `{SolutionDir}`: não sobrescreva. Ajuste só as seis propriedades gerenciadas para os valores do Template (acrescente as ausentes), preserve todo o resto, e relate o que mudou.
7. **Cada `.csproj`.**
   - Remova as seis propriedades gerenciadas, qualquer que seja o valor, exceto `Nullable` e `ImplicitUsings`, que seguem a tabela. Valor removido que era diferente do valor do `Directory.Build.props` entra no relatório final (`projeto: propriedade, valor anterior`).
   - Propriedade com `Condition` (própria ou do `PropertyGroup`): não remova; relate.
   - `PropertyGroup` que ficar vazio é removido. Preserve indentação e o restante do arquivo.
8. **Arquivos de raiz.**
   - `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`: já em `{SolutionDir}` e em nenhum outro lugar, nada a fazer. Em exatamente um outro diretório, mova para `{SolutionDir}` (`git mv` se estiver sob git, senão `mv`). Em `{SolutionDir}` e também em outro lugar, ou em mais de um outro diretório, pare e relate. Não encontrado: relate a ausência, não crie.
   - `global.json`: não existe em `{SolutionDir}`: execute `dotnet new globaljson` dentro de `{SolutionDir}` e confira que o `sdk.version` gerado é `10.x` sem sufixo de prerelease. Existe e a major do `sdk.version` não é 10, ou existe só em outro diretório: pare e relate.
   - `BannedSymbols.txt`: não existe: crie em `{SolutionDir}` com o conteúdo do Template canônico. Existe: não altere.
9. **`RootNamespace`.** Para cada projeto sem `RootNamespace`:
   - Leia os `namespace` declarados nos `.cs` do projeto (ignorando `bin`/`obj` e arquivos gerados) e calcule o maior prefixo, por segmento, comum a todos eles.
   - Acrescente `<RootNamespace>{prefixo}</RootNamespace>` no primeiro `PropertyGroup` do `.csproj`; sem nenhum, crie um.
   - Sem `.cs` com namespace, ou sem prefixo comum: não acrescente; relate o projeto.
   - Já existe `RootNamespace`: não altere; se divergir do calculado, relate os dois valores.

**Fase 2 — Pacotes (após a aprovação)**
10. **Atualizar** como no relatório aprovado. Com `Directory.Packages.props`, altere só o `PackageVersion` (CONV-058); sem ele, use `dotnet add {csproj} package {id} --version {versao}`. Um pacote por vez, anotando versão anterior e nova. Família Microsoft: maior estável de major 10.
11. **Pacote sem versão estável compatível:** mantenha a versão atual e relate (id, versão atual, motivo). Não use prerelease, não use major 11.

**Fase 3 — Verificação**
12. Verificar pelo Checklist + Harness. Falha por erro de build ou de teste causado pela migração: pare e relate os primeiros erros; não edite código-fonte.

## Raciocínio antes de escrever (CoT)
- Qual o valor efetivo de `Nullable` e de `ImplicitUsings` em cada projeto (ausente é `disable`)? Todos iguais, ou misto?
- No caso misto, quais projetos precisam receber a diretiva explícita para não herdar `enable` e mudar de comportamento?
- Algum projeto é multi-target, tem propriedade condicional ou não é SDK-style? Se sim, pare.
- O prefixo de namespace calculado é o da raiz do projeto ou de uma subpasta (poucos arquivos)? Relate o valor e quantos arquivos o sustentam.
- O pacote é da família Microsoft ou de terceiros? A versão candidata é estável? Há Central Package Management?
- A mudança é de arquivo de projeto ou de código? Código fica fora.

## Template canônico

`Directory.Build.props` (`{SolutionDir}/Directory.Build.props`). `{Nullable}` e `{ImplicitUsings}` são
placeholders: substitua pelo valor calculado na tabela abaixo, nunca deixe literal.

```xml
<?xml version="1.0" encoding="utf-8"?>

<Project>
    <PropertyGroup>
        <TargetFramework>net10.0</TargetFramework>
        <LangVersion>14</LangVersion>
        <Nullable>{Nullable}</Nullable>
        <ImplicitUsings>{ImplicitUsings}</ImplicitUsings>
        <PublishAot>false</PublishAot>
        <SatelliteResourceLanguages>pt-BR</SatelliteResourceLanguages>
    </PropertyGroup>
</Project>
```

Tabela de decisão (vale para `Nullable` e, separadamente, para `ImplicitUsings`):

| Situação nos projetos | Valor no `Directory.Build.props` | No `.csproj` |
|---|---|---|
| Todos `disable` ou ausentes | `disable` | remover a diretiva |
| Todos `enable` | `enable` | remover a diretiva |
| Misto | `enable` | projeto `enable`: remover; projeto `disable` ou ausente: manter ou acrescentar `disable` explícito |

`BannedSymbols.txt` (`{SolutionDir}/BannedSymbols.txt`), conteúdo literal:

```text
# https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.BannedApiAnalyzers/BannedApiAnalyzers.Help.md
P:System.DateTime.Now;Use System.DateTime.UtcNow instead
P:System.DateTimeOffset.Now;Use System.DateTimeOffset.UtcNow instead
P:System.DateTimeOffset.DateTime;Use System.DateTimeOffset.UtcDateTime instead
T:Newtonsoft.Json;Don't use Newtonsoft, use System.Text.Json
T:Newtonsoft.Json.JsonPropertyAttribute;Don't use Newtonsoft
```

`RootNamespace` no `.csproj`: `{RootNamespace}` é o prefixo calculado no passo 9, nunca copiado de exemplo.

```xml
<PropertyGroup>
    <RootNamespace>{RootNamespace}</RootNamespace>
</PropertyGroup>
```

## Exemplos (certo/errado)
Leia `examples.md` antes da Fase 1: ele mostra o caso misto de `Nullable`/`ImplicitUsings` e o
`.csproj` resultante, certo e errado.

## Anti-patterns (recusar)
- Sobrescrever um `Directory.Build.props` existente em vez de ajustar só as propriedades gerenciadas.
- Criar `Directory.Build.props` em `{SolutionDir}` quando já existe outro em subdiretório ou ancestral (duas fontes da verdade).
- Escrever, criar, mover ou instalar qualquer coisa antes da aprovação do relatório; tratar pergunta ou comentário como aprovação.
- Considerar a solution `E2E`, ou procurar arquivos de raiz dentro da pasta dela.
- Deixar `TargetFramework`, `LangVersion`, `PublishAot` ou `SatelliteResourceLanguages` no `.csproj`; repetir `Nullable`/`ImplicitUsings` com o mesmo valor do global (CONV-001).
- Remover `Nullable`/`ImplicitUsings` de um projeto `disable` ou ausente no caso misto, sem deixar `disable` explícito.
- Trocar `Nullable` por `enable` em todos os projetos sem seguir a tabela.
- Remover propriedade condicional, ou migrar projeto multi-target, sem parar e relatar.
- Rodar `dotnet new globaljson` com `global.json` já existente, ou aceitar `sdk.version` que não seja 10.x estável.
- Criar `nuget.config`, `.editorconfig`, `Dockerfile` ou `.dockerignore` que não existiam; alterar o conteúdo deles.
- Sobrescrever `BannedSymbols.txt` existente.
- Instalar pacote prerelease, pacote da família Microsoft com major 11, ou pacote novo (CONV-087).
- Fixar versão no `.csproj` quando há `Directory.Packages.props` (CONV-058).
- Subir a major de pacote de terceiros sem necessidade comprovada pelo build.
- Corrigir código-fonte, imagem base do Docker ou pipeline para fazer o build passar.
- `RootNamespace` copiado dos exemplos, ou placeholder (`{Nullable}`, `{RootNamespace}`...) deixado literal.

## Checklist + Harness

Checklist:
- [ ] Fase 0 sem nenhuma escrita; relatório de plano apresentado no formato de `report.md`; execução só depois da aprovação explícita.
- [ ] Relatório final apresentado em tabelas, com pacotes atualizados (id, projeto, versão anterior, nova).
- [ ] Solution escolhida em `app/src`, com as `E2E` descartadas e listadas no relatório.
- [ ] `Directory.Build.props` único, em `{SolutionDir}`, com as seis propriedades e os valores calculados pela tabela (CONV-001).
- [ ] Nenhum `.csproj` repete as propriedades gerenciadas; `disable` explícito só onde o projeto diverge do global; valores removidos que diferiam estão no relatório final.
- [ ] Todo `.csproj` tem `RootNamespace` (ou o motivo de não ter está no relatório final).
- [ ] `Dockerfile`, `.dockerignore`, `nuget.config` e `.editorconfig` estão em `{SolutionDir}` (ou a ausência/ambiguidade foi relatada), sem conteúdo alterado.
- [ ] `global.json` presente em `{SolutionDir}` com `sdk.version` `10.x` estável.
- [ ] `BannedSymbols.txt` presente em `{SolutionDir}`, conteúdo conforme o Template.
- [ ] Nenhum `PackageReference` prerelease; nenhum pacote da família Microsoft fora da major 10; nenhum pacote novo (CONV-087).
- [ ] Com `Directory.Packages.props`, nenhuma versão no `.csproj` (CONV-058).
- [ ] Cada pacote atualizado (id, versão anterior, nova) e cada pacote mantido (id, versão, motivo) está no relatório final.
- [ ] Nenhum `.cs`, Dockerfile (conteúdo), pipeline ou `appsettings` foi alterado.
- [ ] Nenhum pré-requisito ausente foi criado fora do que "O que gera" permite.

Harness (gate — só conclui quando passam):
1. `dotnet restore {Solution}` sem erro.
2. `dotnet build {Solution}` sem erro. Warnings novos entram no relatório final; não são corrigidos aqui.
3. `dotnet test {Solution} --no-build` verde, quando a solution tem projeto de teste.
4. `dotnet list {Solution} package` não mostra versão prerelease nem pacote da família Microsoft fora da major 10.
5. `dotnet list {Solution} package --deprecated` e `--vulnerable`: só relatar o que aparecer.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, feed
indisponível) em vez de reprovar por conteúdo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a migração
como concluída.

Relatório final: ao concluir (ou ao parar), apresente as tabelas da seção "Relatório final" de
`report.md`: o que foi feito por arquivo, projetos editados, pacotes atualizados e mantidos,
resultado do Harness e o que ficou fora do escopo (Dockerfile, pipeline, código).
