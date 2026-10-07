---
name: standardize-solution
description: 'Padroniza uma solution .NET existente sem mudar versão de framework nem pacotes: cria ou ajusta o Directory.Build.props (Nullable, ImplicitUsings, PublishAot, SatelliteResourceLanguages), remove essas propriedades dos .csproj, acrescenta RootNamespace, move Dockerfile, .dockerignore, nuget.config e .editorconfig para a pasta da solution e cria o BannedSymbols.txt. Use sempre que o usuário pedir para padronizar, organizar ou uniformizar os arquivos e projetos de uma solution .NET, mesmo sem citar os arquivos. Não use para migrar a versão do .NET nem para atualizar pacotes.'
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git rev-parse *)
  - Bash(dotnet sln * list)
  - Bash(dotnet msbuild * -getProperty:*)
---

# Padronizar solution .NET

Uniformiza os arquivos de raiz e de projeto da solution sem mudar o comportamento dos projetos: o
valor efetivo de `Nullable` e de `ImplicitUsings` de cada projeto continua o mesmo depois da
skill. Não altera versão de framework, `LangVersion` nem pacotes.

Em conflito entre o Template canônico e os Exemplos, o Template vence — os exemplos são reforço
didático, não a fonte primária.

## O que gera
Antes de qualquer alteração, produz o relatório de plano e espera a aprovação do usuário. Depois,
em `{SolutionDir}` (diretório do arquivo `.sln`/`.slnx`, esperado em `app/src`):
- **Cria, se ausente:** `Directory.Build.props`, `BannedSymbols.txt`.
- **Move para `{SolutionDir}`, se estiver em outro diretório:** `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`.
- **Edita:** o `Directory.Build.props` existente (só as quatro propriedades gerenciadas) e cada `.csproj` (remove essas propriedades, ajusta `Nullable`/`ImplicitUsings`, acrescenta `RootNamespace`).

Nada além disso: não altera `.cs`, `TargetFramework`, `LangVersion`, `global.json`, pacotes, o
conteúdo do `Dockerfile`, pipeline de CI, `appsettings` nem `launchSettings`. Se um pré-requisito
faltar, esta skill para (ver Pré-condições) em vez de criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** solution com projetos SDK-style, em qualquer versão de framework, cujos arquivos e propriedades precisam seguir o padrão.
- **NÃO usar:** projeto que não é SDK-style. Solution sem arquivo `.sln`/`.slnx`; solution de teste ponta a ponta (`E2E`). Mudança de versão do .NET ou de pacote.

## Contrato

### Regras desta skill
- **Local — fonte da verdade.** `{SolutionDir}/Directory.Build.props` define `Nullable`, `ImplicitUsings`, `PublishAot` e `SatelliteResourceLanguages` para todos os projetos. O `.csproj` não repete essas propriedades.
- **Local — Nullable e ImplicitUsings.** O valor efetivo de um projeto é o que o MSBuild avalia para ele (`dotnet msbuild {csproj} -getProperty:Nullable,ImplicitUsings`), o que já inclui o valor herdado do `Directory.Build.props` existente; resultado vazio conta como `disable`. Em `ImplicitUsings`, `true` e `false` valem como `enable` e `disable`. O valor do `Directory.Build.props` sai da tabela do Template canônico. Valor que não seja `enable` nem `disable`, ou diretiva condicional: pare e relate.
- **Local — qual solution.** Procura-se em `app/src`. Solution cujo nome de arquivo, ou de qualquer pasta do caminho, contém `E2E` (sem diferenciar maiúscula) é ignorada, junto com a pasta dela.
- **Local — aprovação.** A skill só escreve, cria ou move depois de o usuário aprovar o relatório de plano (Gate de aprovação).

### Rules gerais (dotnet-conventions.md)
- **CONV-001** o `.csproj` não repete as propriedades do `Directory.Build.props`. *Local desta skill:* o arquivo fica em `{SolutionDir}`, a lista de propriedades é a da regra local acima, e `TargetFramework` e `LangVersion` não são tocados.

### Pré-condições
- `app/src` existe e, descartadas as solutions `E2E`, contém exatamente um arquivo `.sln`/`.slnx` (ou o caminho foi informado).
- Todo `.csproj` da solution é SDK-style e o MSBuild o avalia sem erro.

Se alguma falhar, esta skill para e relata o que falta e onde era esperado — sem apontar como resolver.

### Inputs
1. **Solution** (opcional) — caminho do `.sln`/`.slnx`. Omitido: procurar em `app/src` (Fluxo, passo 1).

Não há outro input. Nullable, ImplicitUsings e RootNamespace são calculados a partir dos projetos.

## Fluxo (ReAct)

**Fase 0 — Identificação e plano (somente leitura)**
1. **Localizar a solution.** Sem caminho informado, procure `.sln`/`.slnx` recursivamente em `{RepoRoot}/app/src` (`{RepoRoot}` é a raiz do repositório git; sem git, o diretório atual). Descarte as solutions `E2E`. Restando exatamente uma, ela é `{Solution}` e o diretório dela é `{SolutionDir}`; zero ou mais de uma: pare e pergunte. As descartadas, e a pasta de cada uma, ficam fora de todas as buscas seguintes e entram no relatório. Liste os projetos com `dotnet sln {Solution} list`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Coletar o estado.** Para cada `.csproj`, leia no XML as propriedades gerenciadas e `RootNamespace` (declaradas ou não, com ou sem `Condition`) e avalie o valor efetivo com `dotnet msbuild {csproj} -getProperty:Nullable,ImplicitUsings,PublishAot,SatelliteResourceLanguages,TargetFramework,LangVersion`: esse resultado é a linha de base do Harness. Procure por **nome**, na árvore de `{SolutionDir}` e nos diretórios ancestrais até `{RepoRoot}` (ignorando `bin`, `obj`, `.git`, `node_modules` e as pastas das solutions descartadas): `Directory.Build.props`, `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`, `BannedSymbols.txt`.
4. **Calcular o plano.** Valor de `Nullable` e de `ImplicitUsings` (tabela do Template canônico), `RootNamespace` de cada projeto (passo 9) e a ação de cada arquivo (criar, mover, editar, nada, parar), aplicando no papel as regras da Fase 1.
5. **Apresentar o relatório de plano** no formato de `report.md` (seção "Relatório de plano") e parar. A visão geral vem primeiro: arquivos a criar, arquivos a mover e projetos a editar.

**Gate de aprovação**
- Nada é criado, movido ou editado antes da aprovação explícita do usuário ("aprovo", "pode executar"). Pergunta, ajuste ou comentário não é aprovação: responda e reapresente o relatório.
- Aprovação parcial (o usuário exclui linhas): execute só o aprovado.
- Divergência durante a execução em relação ao relatório aprovado (arquivo novo, valor diferente): pare e reapresente o relatório atualizado.
- Se a ferramenta oferecer modo plan (ex.: `EnterPlanMode`/`ExitPlanMode`), use-o para apresentar o relatório. Ele não substitui este gate.

**Fase 1 — Padronização (após a aprovação)**
6. **`Directory.Build.props`.**
   - Existe em outro diretório (subdiretório de `{SolutionDir}` ou ancestral até `{RepoRoot}`): pare e relate; não crie duplicata nem mova.
   - Não existe: crie em `{SolutionDir}` com o Template canônico.
   - Existe em `{SolutionDir}`: não sobrescreva. Ajuste só as quatro propriedades gerenciadas para os valores do Template (acrescente as ausentes), preserve todo o resto (inclusive `TargetFramework` e `LangVersion`, se houver), e relate o que mudou.
7. **Cada `.csproj`.**
   - Remova `PublishAot` e `SatelliteResourceLanguages`, qualquer que seja o valor; valor diferente do global entra no relatório final (`projeto: propriedade, valor anterior`).
   - `Nullable` e `ImplicitUsings` seguem a tabela.
   - Propriedade com `Condition` (própria ou do `PropertyGroup`): não remova; relate.
   - `PropertyGroup` que ficar vazio é removido. Preserve indentação e o restante do arquivo.
8. **Arquivos de raiz.**
   - `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig`: já em `{SolutionDir}` e em nenhum outro lugar, nada a fazer. Em exatamente um outro diretório, mova para `{SolutionDir}` (`git mv` se estiver sob git, senão `mv`). Em `{SolutionDir}` e também em outro lugar, ou em mais de um outro diretório, pare e relate. Não encontrado: relate a ausência, não crie.
   - `BannedSymbols.txt`: não existe: crie em `{SolutionDir}` com o conteúdo do Template canônico. Existe: não altere.
9. **`RootNamespace`.** Para cada projeto sem `RootNamespace`:
   - Leia os `namespace` declarados nos `.cs` do projeto (ignorando `bin`/`obj` e arquivos gerados) e calcule o maior prefixo, por segmento, comum a todos eles.
   - Acrescente `<RootNamespace>{prefixo}</RootNamespace>` no primeiro `PropertyGroup` do `.csproj`; sem nenhum, crie um.
   - Sem `.cs` com namespace, ou sem prefixo comum: não acrescente; relate o projeto.
   - Já existe `RootNamespace`: não altere; se divergir do calculado, relate os dois valores.

**Fase 2 — Verificação**
10. Verificar pelo Checklist + Harness. Falha causada pela padronização: pare e relate; não edite código-fonte.

## Raciocínio antes de escrever (CoT)
- Qual o valor efetivo de `Nullable` e de `ImplicitUsings` em cada projeto, já contando o herdado do `Directory.Build.props` existente? Todos iguais, ou misto?
- No caso misto, quais projetos precisam receber a diretiva explícita para não herdar `enable` e mudar de comportamento?
- Alguma propriedade é condicional, ou tem valor fora de `enable`/`disable`? Se sim, pare.
- Há `PublishAot` ou `SatelliteResourceLanguages` com valor diferente do global em algum projeto? Vai para o relatório como linha própria.
- O prefixo de namespace calculado é o da raiz do projeto ou de uma subpasta (poucos arquivos)? Relate o valor e quantos arquivos o sustentam.

## Template canônico

`Directory.Build.props` (`{SolutionDir}/Directory.Build.props`). `{Nullable}` e `{ImplicitUsings}` são
placeholders: substitua pelo valor calculado na tabela abaixo, nunca deixe literal.

```xml
<?xml version="1.0" encoding="utf-8"?>

<Project>
    <PropertyGroup>
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
| Todos com valor efetivo `disable` | `disable` | remover a diretiva, se houver |
| Todos com valor efetivo `enable` | `enable` | remover a diretiva, se houver |
| Misto | `enable` | projeto de valor efetivo `enable`: remover a diretiva, se houver; projeto de valor efetivo `disable`: manter ou acrescentar `disable` explícito |

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
Leia `examples.md` antes da Fase 1: ele mostra o caso misto de `Nullable`/`ImplicitUsings`, o caso
de diretiva ausente com `Directory.Build.props` existente e o `.csproj` resultante.

## Anti-patterns (recusar)
- Escrever, criar ou mover qualquer coisa antes da aprovação do relatório; tratar pergunta ou comentário como aprovação.
- Considerar a solution `E2E`, ou procurar arquivos de raiz dentro da pasta dela.
- Sobrescrever um `Directory.Build.props` existente em vez de ajustar só as quatro propriedades gerenciadas.
- Criar `Directory.Build.props` em `{SolutionDir}` quando já existe outro em subdiretório ou ancestral (duas fontes da verdade).
- Tocar em `TargetFramework`, `LangVersion`, `global.json` ou pacotes.
- Deixar `PublishAot` ou `SatelliteResourceLanguages` no `.csproj`; repetir `Nullable`/`ImplicitUsings` com o mesmo valor do global (CONV-001).
- Remover `Nullable`/`ImplicitUsings` de um projeto de valor efetivo `disable` no caso misto, sem deixar `disable` explícito.
- Tratar diretiva ausente como `disable` quando o `Directory.Build.props` existente já define a propriedade.
- Remover propriedade condicional sem parar e relatar.
- Criar `nuget.config`, `.editorconfig`, `Dockerfile` ou `.dockerignore` que não existiam; alterar o conteúdo deles. Sobrescrever `BannedSymbols.txt` existente.
- `RootNamespace` copiado dos exemplos, ou placeholder (`{Nullable}`, `{RootNamespace}`...) deixado literal.

## Checklist + Harness

Checklist:
- [ ] Fase 0 sem nenhuma escrita; relatório de plano apresentado no formato de `report.md`; execução só depois da aprovação explícita.
- [ ] Solution escolhida em `app/src`, com as `E2E` descartadas e listadas no relatório.
- [ ] `Directory.Build.props` único, em `{SolutionDir}`, com as quatro propriedades e os valores calculados pela tabela (CONV-001).
- [ ] Nenhum `.csproj` repete as propriedades gerenciadas; `disable` explícito só onde o projeto diverge do global; valores removidos que diferiam estão no relatório final.
- [ ] Todo `.csproj` tem `RootNamespace` (ou o motivo de não ter está no relatório final).
- [ ] `Dockerfile`, `.dockerignore`, `nuget.config` e `.editorconfig` estão em `{SolutionDir}` (ou a ausência/ambiguidade foi relatada), sem conteúdo alterado.
- [ ] `BannedSymbols.txt` presente em `{SolutionDir}`, conteúdo conforme o Template.
- [ ] Nenhum `.cs`, `TargetFramework`, `LangVersion`, `global.json`, pacote, Dockerfile (conteúdo), pipeline ou `appsettings` foi alterado.
- [ ] Relatório final apresentado em tabelas.

Harness (gate — só conclui quando passam):
1. Reavaliar cada projeto com `dotnet msbuild {csproj} -getProperty:...` e comparar com a linha de base: `Nullable` e `ImplicitUsings` iguais (vazio e `disable` equivalem; `true` e `enable` equivalem); `TargetFramework` e `LangVersion` idênticos; `PublishAot` e `SatelliteResourceLanguages` iguais aos do `Directory.Build.props`.
2. `dotnet build {Solution}` sem erro. Warnings novos entram no relatório final; não são corrigidos aqui.
3. `dotnet test {Solution} --no-build` verde, quando a solution tem projeto de teste.

Se algum comando falhar por erro de ambiente/ferramenta (timeout, processo que não inicia, feed
indisponível) em vez de reprovar por conteúdo, não trate como passo concluído: tente de novo uma
vez e, se persistir, reporte ao usuário como Harness incompleto e pare — não declare a padronização
como concluída.

Relatório final: ao concluir (ou ao parar), apresente as tabelas da seção "Relatório final" de
`report.md`: o que foi feito por linha, arquivos criados e movidos, projetos editados, resultado do
Harness e o que ficou fora do escopo.
