---
name: migrate-to-dotnet10
description: 'Migra uma solution .NET 8 para .NET 10: passa TargetFramework para net10.0 e LangVersion para 14 no Directory.Build.props (removendo-os dos .csproj), fixa o SDK 10 no global.json e atualiza os pacotes para versões estáveis do .NET 10. Use sempre que o usuário pedir para migrar, atualizar ou subir uma API/solution de .NET 8 (net8.0) para .NET 10 (net10.0), mesmo sem citar os arquivos. Não use para padronizar arquivos da solution, nem para corrigir código quebrado pela migração.'
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

Leva a solution de `net8.0` para `net10.0`: framework e `LangVersion` no `Directory.Build.props`,
SDK no `global.json` e pacotes. Esta skill altera arquivos de configuração e de projeto; não
altera código-fonte.

Em conflito entre o Template canônico e os Exemplos, o Template vence — os exemplos são reforço
didático, não a fonte primária.

## O que gera
Antes de qualquer alteração, produz o relatório de plano e espera a aprovação do usuário. Depois,
em `{SolutionDir}` (diretório do arquivo `.sln`/`.slnx`, esperado em `app/src`):
- **Cria, se ausente:** `global.json`.
- **Edita:** o `Directory.Build.props` existente (só `TargetFramework` e `LangVersion`), cada `.csproj` (remove `TargetFramework` e `LangVersion`) e as versões de pacote (nos `.csproj`, ou em `Directory.Packages.props` quando existir).

Nada além disso: não altera `.cs`, as demais propriedades do `Directory.Build.props`, o conteúdo
do `Dockerfile`, pipeline de CI, `appsettings` nem `launchSettings`, não move arquivo e não
adiciona pacote novo. Se um pré-requisito faltar, esta skill para (ver Pré-condições) em vez de
criá-lo.

## Escopo (quando usar / NÃO usar)
- **Usar:** solution .NET 8 (`net8.0`) cujos projetos são SDK-style e devem passar a `net10.0`.
- **NÃO usar:** projeto que não é SDK-style. Solution sem arquivo `.sln`/`.slnx`; solution de teste ponta a ponta (`E2E`). Padronização de arquivos e propriedades da solution. Ajuste de código por breaking change, troca de imagem base do Docker ou ajuste de pipeline: ficam fora; se o build quebrar por isso, a skill relata e para.

## Contrato

### Regras desta skill
- **Local — fonte da verdade.** `{SolutionDir}/Directory.Build.props` define `TargetFramework` (`net10.0`) e `LangVersion` (`14`) para todos os projetos. O `.csproj` não repete essas propriedades.
- **Local — pacotes.** Só `PackageReference` direto (e `PackageVersion`, com Central Package Management). Pacote da família Microsoft atrelada ao runtime vai para a maior versão estável da major 10, nunca para major 11. Pacote de terceiros vai para a maior versão estável dentro da major atual; a major só sobe quando a versão atual não restaura nem compila em `net10.0`, e cada subida é relatada. Versão prerelease (`-preview`, `-rc`, `-alpha`, `-beta`, qualquer sufixo) nunca é instalada.
- **Local — família Microsoft atrelada ao runtime:** `Microsoft.AspNetCore.*`, `Microsoft.Extensions.*`, `Microsoft.EntityFrameworkCore.*` e `System.*` publicado com a versão do runtime. Os demais pacotes da Microsoft seguem a regra de terceiros.
- **Local — qual solution.** Procura-se em `app/src`. Solution cujo nome de arquivo, ou de qualquer pasta do caminho, contém `E2E` (sem diferenciar maiúscula) é ignorada, junto com a pasta dela.
- **Local — aprovação.** A skill só escreve, cria ou instala depois de o usuário aprovar o relatório de plano (Gate de aprovação).

### Rules gerais (dotnet-conventions.md)
- **CONV-001** o `.csproj` não repete as propriedades do `Directory.Build.props`. *Local desta skill:* o arquivo fica em `{SolutionDir}` e a lista de propriedades é a da regra local acima.
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
1. **Localizar a solution.** Sem caminho informado, procure `.sln`/`.slnx` recursivamente em `{RepoRoot}/app/src` (`{RepoRoot}` é a raiz do repositório git; sem git, o diretório atual). Descarte as solutions `E2E`. Restando exatamente uma, ela é `{Solution}` e o diretório dela é `{SolutionDir}`; zero ou mais de uma: pare e pergunte. As descartadas, e a pasta de cada uma, ficam fora de todas as buscas seguintes e entram no relatório. Liste os projetos com `dotnet sln {Solution} list`.
2. **Checar as Pré-condições.** Falhou alguma: pare e relate.
3. **Coletar o estado.** Para cada `.csproj`, leia `TargetFramework` e `LangVersion` (declarados ou não, com ou sem `Condition`). Leia os mesmos valores do `Directory.Build.props`. Procure por **nome**, na árvore de `{SolutionDir}` e nos diretórios ancestrais até `{RepoRoot}` (ignorando `bin`, `obj`, `.git`, `node_modules` e as pastas das solutions descartadas): `global.json`, `Directory.Packages.props`. Levante os pacotes com `dotnet list {Solution} package --outdated` (sem `--include-prerelease`) e, para a família Microsoft, as versões com `dotnet package search {id} --exact-match --format json`. O restore grava em `obj`; isso não conta como alteração.
4. **Calcular o plano.** Ação em cada `.csproj` (remover `TargetFramework`/`LangVersion`), no `Directory.Build.props` e no `global.json`, e a versão alvo de cada pacote (passos 9 e 10), aplicando no papel as regras das Fases 1 e 2.
5. **Apresentar o relatório de plano** no formato de `report.md` (seção "Relatório de plano") e parar. A visão geral vem primeiro: arquivos a criar, arquivos a editar e pacotes a atualizar.

**Gate de aprovação**
- Nada é criado, editado nem instalado antes da aprovação explícita do usuário ("aprovo", "pode executar"). Pergunta, ajuste ou comentário não é aprovação: responda e reapresente o relatório.
- Aprovação parcial (o usuário exclui linhas): execute só o aprovado. Linha excluída de `TargetFramework`/`LangVersion` deixa o valor no `.csproj`, que prevalece sobre o `Directory.Build.props`.
- Divergência durante a execução em relação ao relatório aprovado (arquivo novo, valor diferente, pacote sem versão): pare e reapresente o relatório atualizado.
- Se a ferramenta oferecer modo plan (ex.: `EnterPlanMode`/`ExitPlanMode`), use-o para apresentar o relatório. Ele não substitui este gate.

**Fase 1 — Framework e SDK (após a aprovação)**
6. **`Directory.Build.props`.** Existe em outro diretório além de `{SolutionDir}` (subdiretório ou ancestral até `{RepoRoot}`): pare e relate. Em `{SolutionDir}`, ajuste só `TargetFramework` para `net10.0` e `LangVersion` para `14` (acrescente os ausentes no primeiro `PropertyGroup` sem `Condition`), preserve todo o resto e relate o que mudou. Propriedade condicional no arquivo: pare e relate.
7. **Cada `.csproj`.** Remova `TargetFramework` e `LangVersion`, qualquer que seja o valor. `TargetFramework` com valor diferente de `net8.0` (ex.: `netstandard2.0`) é alerta no relatório, em linha própria. Propriedade com `Condition` (própria ou do `PropertyGroup`): não remova; relate. `PropertyGroup` que ficar vazio é removido. Preserve indentação e o restante do arquivo.
8. **`global.json`.** Não existe em `{SolutionDir}`: execute `dotnet new globaljson` dentro de `{SolutionDir}` e confira que o `sdk.version` gerado é `10.x` sem sufixo de prerelease. Existe e a major do `sdk.version` não é 10, ou existe só em outro diretório: pare e relate.

**Fase 2 — Pacotes (após a aprovação)**
9. **Atualizar** como no relatório aprovado. Com `Directory.Packages.props`, altere só o `PackageVersion` (CONV-058); sem ele, use `dotnet add {csproj} package {id} --version {versao}`. Um pacote por vez, anotando versão anterior e nova. Família Microsoft: maior estável de major 10.
10. **Pacote sem versão estável compatível:** mantenha a versão atual e relate (id, versão atual, motivo). Não use prerelease, não use major 11.

**Fase 3 — Verificação**
11. Verificar pelo Checklist + Harness. Falha por erro de build ou de teste causado pela migração: pare e relate os primeiros erros; não edite código-fonte.

## Raciocínio antes de escrever (CoT)
- Algum projeto é multi-target, tem propriedade condicional ou não é SDK-style? Se sim, pare.
- Algum `TargetFramework` não é `net8.0`? Vira alerta em linha própria, que o usuário pode excluir.
- O pacote é da família Microsoft ou de terceiros? A versão candidata é estável? Há Central Package Management?
- Terceiro com versão atual que não compila em `net10.0`: o que a subida de major traria? Relate, não decida sozinho.
- A mudança é de arquivo de projeto ou de código? Código fica fora.

## Template canônico
`Directory.Build.props` (`{SolutionDir}/Directory.Build.props`): as duas linhas entram no primeiro
`PropertyGroup` sem `Condition`; as demais propriedades do arquivo não são tocadas.

```xml
<TargetFramework>net10.0</TargetFramework>
<LangVersion>14</LangVersion>
```

Regra de versão de pacote (vale por pacote):

| Pacote | Versão alvo |
|---|---|
| Família Microsoft atrelada ao runtime | maior versão estável de major 10 |
| Terceiro | maior versão estável dentro da major atual |
| Terceiro que não restaura nem compila em `net10.0` | menor major estável que compila; subida relatada |
| Sem versão estável compatível | manter a atual e relatar |

## Exemplos (certo/errado)
Leia `examples.md` antes da Fase 1: ele mostra o `Directory.Build.props` e o `.csproj` antes e
depois, e a escolha de versões de pacote, certa e errada.

## Anti-patterns (recusar)
- Escrever, criar ou instalar qualquer coisa antes da aprovação do relatório; tratar pergunta ou comentário como aprovação.
- Considerar a solution `E2E`, ou procurar arquivos dentro da pasta dela.
- Deixar `TargetFramework` ou `LangVersion` no `.csproj` (CONV-001); sobrescrever o `Directory.Build.props` ou mexer em outra propriedade dele.
- Migrar projeto multi-target, ou remover propriedade condicional, sem parar e relatar.
- Rodar `dotnet new globaljson` com `global.json` já existente, ou aceitar `sdk.version` que não seja 10.x estável.
- Instalar pacote prerelease, pacote da família Microsoft com major 11, ou pacote novo (CONV-087).
- Fixar versão no `.csproj` quando há `Directory.Packages.props` (CONV-058).
- Subir a major de pacote de terceiros sem necessidade comprovada pelo build.
- Corrigir código-fonte, imagem base do Docker ou pipeline para fazer o build passar.
- Mover, criar ou editar `Dockerfile`, `.dockerignore`, `nuget.config`, `.editorconfig` ou `BannedSymbols.txt`.
- Placeholder (`{SolutionDir}`, `{id}`...) deixado literal.

## Checklist + Harness

Checklist:
- [ ] Fase 0 sem nenhuma escrita; relatório de plano apresentado no formato de `report.md`; execução só depois da aprovação explícita.
- [ ] Solution escolhida em `app/src`, com as `E2E` descartadas e listadas no relatório.
- [ ] `Directory.Build.props` com `TargetFramework` `net10.0` e `LangVersion` `14`; demais propriedades intactas (CONV-001).
- [ ] Nenhum `.csproj` repete `TargetFramework` ou `LangVersion`; alertas e propriedades condicionais estão no relatório final.
- [ ] `global.json` presente em `{SolutionDir}` com `sdk.version` `10.x` estável.
- [ ] Nenhum `PackageReference` prerelease; nenhum pacote da família Microsoft fora da major 10; nenhum pacote novo (CONV-087).
- [ ] Com `Directory.Packages.props`, nenhuma versão no `.csproj` (CONV-058).
- [ ] Cada pacote atualizado (id, projeto, versão anterior, nova) e cada pacote mantido (id, versão, motivo) está no relatório final.
- [ ] Nenhum `.cs`, outra propriedade, Dockerfile, pipeline ou `appsettings` foi alterado; nenhum arquivo foi movido.
- [ ] Relatório final apresentado em tabelas.

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
`report.md`: o que foi feito por linha, arquivos editados, projetos editados, pacotes atualizados e
mantidos, resultado do Harness e o que ficou fora do escopo.
