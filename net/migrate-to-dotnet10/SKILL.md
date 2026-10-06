---
name: migrate-to-dotnet10
description: 'Migra uma solution .NET 8 para .NET 10: padroniza os arquivos de raiz (Directory.Build.props, global.json, BannedSymbols.txt, Dockerfile, .dockerignore, nuget.config, .editorconfig), limpa os .csproj e atualiza os pacotes para versões estáveis do .NET 10. Use sempre que o usuário pedir para migrar, atualizar ou subir uma API/solution de .NET 8 (net8.0) para .NET 10 (net10.0), mesmo sem citar os arquivos. Não use para projeto que não é SDK-style, nem para corrigir código quebrado pela migração.'
---

# Migrar solution .NET 8 para .NET 10

Padroniza a solution e atualiza os pacotes para o .NET 10, na ordem: arquivos de raiz, projetos,
pacotes, verificação. Esta skill altera arquivos de configuração e de projeto; não altera
código-fonte.

Em conflito entre o Template canônico e os Exemplos, o Template vence — os exemplos são reforço
didático, não a fonte primária.

## O que gera
Em `{SolutionDir}` (diretório do arquivo `.sln`/`.slnx`):
- **Cria, se ausente:** `Directory.Build.props`, `global.json`, `BannedSymbols.txt`.
- **Move para `{SolutionDir}`, se estiver em outro diretório:** `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`.
- **Edita:** cada `.csproj` da solution (remove propriedades que o `Directory.Build.props` passa a definir, ajusta `Nullable`/`ImplicitUsings`, acrescenta `RootNamespace`) e as versões de pacote (nos `.csproj`, ou em `Directory.Packages.props` quando existir).

Nada além disso: não altera `.cs`, não altera o conteúdo do `Dockerfile`, pipeline de CI, `appsettings`
nem `launchSettings`, e não adiciona pacote novo. Se um pré-requisito faltar, esta skill para (ver
Pré-condições) em vez de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** solution .NET 8 (`net8.0`) cujos projetos são SDK-style e devem passar a `net10.0`.
- **NÃO usar:** projeto que não é SDK-style. Solution sem arquivo `.sln`/`.slnx`. Ajuste de código por breaking change, troca de imagem base do Docker ou ajuste de pipeline: ficam fora; se o build quebrar por isso, a skill relata e para.

## Contrato

### Regras desta skill
- **Local — fonte da verdade.** `{SolutionDir}/Directory.Build.props` define `TargetFramework`, `LangVersion`, `Nullable`, `ImplicitUsings`, `PublishAot` e `SatelliteResourceLanguages` para todos os projetos. O `.csproj` não repete essas propriedades.
- **Local — Nullable e ImplicitUsings.** O valor efetivo de um projeto é o da diretiva no `.csproj`; diretiva ausente conta como `disable`. O valor do `Directory.Build.props` sai da tabela do Template canônico. Valor que não seja `enable` nem `disable` (ex.: `annotations`, ou diretiva condicional): pare e relate.
- **Local — pacotes.** Só `PackageReference` direto (e `PackageVersion`, com Central Package Management). Pacote da família Microsoft atrelada ao runtime vai para a maior versão estável da major 10, nunca para major 11. Pacote de terceiros vai para a maior versão estável dentro da major atual; a major só sobe quando a versão atual não restaura nem compila em `net10.0`, e cada subida é relatada. Versão prerelease (`-preview`, `-rc`, `-alpha`, `-beta`, qualquer sufixo) nunca é instalada.
- **Local — família Microsoft atrelada ao runtime:** `Microsoft.AspNetCore.*`, `Microsoft.Extensions.*`, `Microsoft.EntityFrameworkCore.*` e `System.*` publicado com a versão do runtime. Os demais pacotes da Microsoft seguem a regra de terceiros.

### Rules gerais (dotnet-conventions.md)
- **CONV-001** o `.csproj` não repete as propriedades do `Directory.Build.props`. *Local desta skill:* o arquivo fica em `{SolutionDir}` (não em `src/`) e a lista de propriedades é a da regra local acima.
- **CONV-058** com Central Package Management, versão de pacote só em `Directory.Packages.props`; o `.csproj` não fixa versão.
- **CONV-087** nenhum pacote novo: só se mudam versões de pacotes que já existem.

### Pré-condições
- Existe exatamente um arquivo `.sln`/`.slnx` no diretório de partida (ou o caminho foi informado).
- O SDK do .NET 10 está instalado e não é preview (`dotnet --list-sdks` lista `10.0.x` sem sufixo de prerelease).
- Todo `.csproj` da solution é SDK-style e usa `TargetFramework` (singular). `TargetFrameworks` (multi-target): pare e relate qual projeto.

Se alguma falhar, esta skill para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Solution** (opcional) — caminho do `.sln`/`.slnx`. Omitido: procurar a partir do diretório atual; mais de uma encontrada, pergunte qual.

Não há outro input. Valores que a skill calcula (Nullable, ImplicitUsings, RootNamespace) são derivados dos projetos.

## Fluxo (ReAct)

**Fase 0 — Identificação (fail-fast)**
1. **Localizar a solution.** `{Solution}` é o arquivo; `{SolutionDir}` é o diretório dele. Liste os projetos com `dotnet sln {Solution} list`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Coletar o estado.** Para cada `.csproj`, leia `TargetFramework`, `LangVersion`, `Nullable`, `ImplicitUsings`, `PublishAot`, `SatelliteResourceLanguages` e `RootNamespace`. Procure por **nome**, em toda a árvore de `{SolutionDir}` (ignorando `bin`, `obj`, `.git`, `node_modules`): `Directory.Build.props`, `Directory.Packages.props`, `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`, `global.json`, `BannedSymbols.txt`.
4. **Declarar, num bloco só, antes de escrever qualquer coisa:** `Solution=`, `SolutionDir=`, a lista de projetos, o SDK em uso, o valor calculado de `Nullable=` e de `ImplicitUsings=` (com a tabela do Template canônico), e a ação prevista para cada arquivo (criar, mover, editar, nada).

**Fase 1 — Padronização**
5. **`Directory.Build.props`.**
   - Existe fora de `{SolutionDir}` (ex.: `src/`): pare e relate; não crie duplicata nem mova.
   - Não existe: crie em `{SolutionDir}` com o Template canônico.
   - Existe em `{SolutionDir}`: não sobrescreva. Ajuste só as seis propriedades gerenciadas para os valores do Template (acrescente as ausentes), preserve todo o resto, e relate o que mudou.
6. **Cada `.csproj`.**
   - Remova as seis propriedades gerenciadas, qualquer que seja o valor, exceto `Nullable` e `ImplicitUsings`, que seguem a tabela. Valor removido que era diferente do valor do `Directory.Build.props` entra no resumo (`projeto: propriedade, valor anterior`).
   - Propriedade com `Condition` (própria ou do `PropertyGroup`): não remova; relate.
   - `PropertyGroup` que ficar vazio é removido. Preserve indentação e o restante do arquivo.
7. **Arquivos de raiz.**
   - `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`: já em `{SolutionDir}` e em nenhum outro lugar, nada a fazer. Em exatamente um outro diretório, mova para `{SolutionDir}` (`git mv` se estiver sob git, senão `mv`). Em `{SolutionDir}` e também em outro lugar, ou em mais de um outro diretório, pare e relate. Não encontrado: relate a ausência, não crie.
   - `global.json`: não existe em `{SolutionDir}`: execute `dotnet new globaljson` dentro de `{SolutionDir}` e confira que o `sdk.version` gerado é `10.x` sem sufixo de prerelease. Existe e a major do `sdk.version` não é 10, ou existe só em outro diretório: pare e relate.
   - `BannedSymbols.txt`: não existe: crie em `{SolutionDir}` com o conteúdo do Template canônico. Existe: não altere.
8. **`RootNamespace`.** Para cada projeto sem `RootNamespace`:
   - Leia os `namespace` declarados nos `.cs` do projeto (ignorando `bin`/`obj` e arquivos gerados) e calcule o maior prefixo, por segmento, comum a todos eles.
   - Acrescente `<RootNamespace>{prefixo}</RootNamespace>` no primeiro `PropertyGroup` do `.csproj`; sem nenhum, crie um.
   - Sem `.cs` com namespace, ou sem prefixo comum: não acrescente; relate o projeto.
   - Já existe `RootNamespace`: não altere; se divergir do calculado, relate os dois valores.

**Fase 2 — Pacotes**
9. **Levantar.** `dotnet list {Solution} package --outdated` (sem `--include-prerelease`). Para a família Microsoft, liste as versões com `dotnet package search {id} --exact-match --format json` e escolha a maior estável de major 10.
10. **Atualizar.** Com `Directory.Packages.props`, altere só o `PackageVersion` (CONV-058); sem ele, use `dotnet add {csproj} package {id} --version {versao}`. Um pacote por vez, anotando versão anterior e nova.
11. **Pacote sem versão estável compatível.** Mantenha a versão atual e relate (id, versão atual, motivo). Não use prerelease, não use major 11.

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

`RootNamespace` no `.csproj`: `{RootNamespace}` é o prefixo calculado no passo 8, nunca copiado de exemplo.

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
- Criar `Directory.Build.props` em `{SolutionDir}` quando já existe outro em subdiretório (duas fontes da verdade).
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
- [ ] Fase 0 declarada antes de qualquer escrita: solution, projetos, SDK, valores de `Nullable`/`ImplicitUsings`, ação por arquivo.
- [ ] `Directory.Build.props` único, em `{SolutionDir}`, com as seis propriedades e os valores calculados pela tabela (CONV-001).
- [ ] Nenhum `.csproj` repete as propriedades gerenciadas; `disable` explícito só onde o projeto diverge do global; valores removidos que diferiam estão no resumo.
- [ ] Todo `.csproj` tem `RootNamespace` (ou o motivo de não ter está no resumo).
- [ ] `Dockerfile`, `.dockerignore`, `nuget.config` e `.editorconfig` estão em `{SolutionDir}` (ou a ausência/ambiguidade foi relatada), sem conteúdo alterado.
- [ ] `global.json` presente em `{SolutionDir}` com `sdk.version` `10.x` estável.
- [ ] `BannedSymbols.txt` presente em `{SolutionDir}`, conteúdo conforme o Template.
- [ ] Nenhum `PackageReference` prerelease; nenhum pacote da família Microsoft fora da major 10; nenhum pacote novo (CONV-087).
- [ ] Com `Directory.Packages.props`, nenhuma versão no `.csproj` (CONV-058).
- [ ] Cada pacote atualizado (id, versão anterior, nova) e cada pacote mantido (id, versão, motivo) está no resumo.
- [ ] Nenhum `.cs`, Dockerfile (conteúdo), pipeline ou `appsettings` foi alterado.
- [ ] Nenhum pré-requisito ausente foi criado fora do que "O que gera" permite.

Harness (gate — só conclui quando passam):
1. `dotnet restore {Solution}` sem erro.
2. `dotnet build {Solution}` sem erro. Warnings novos entram no resumo; não são corrigidos aqui.
3. `dotnet test {Solution} --no-build` verde, quando a solution tem projeto de teste.
4. `dotnet list {Solution} package` não mostra versão prerelease nem pacote da família Microsoft fora da major 10.
5. `dotnet list {Solution} package --deprecated` e `--vulnerable`: só relatar o que aparecer.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, feed
indisponível) em vez de reprovar por conteúdo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a migração
como concluída.

Resumo final: o que foi criado, movido, editado e mantido; propriedades removidas com valor
diferente do global; `RootNamespace` calculado por projeto; pacotes atualizados e mantidos;
conteúdo que ficou fora do escopo (Dockerfile, pipeline, código).