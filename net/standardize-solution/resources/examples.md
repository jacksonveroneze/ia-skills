# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com a seção do arquivo, a seção vence.

## Directory.Build.props novo
Estado antes: sem `Directory.Build.props` em `{SolutionDir}`; os projetos têm `Nullable` e
`ImplicitUsings` em `enable`.

Certo — cópia de `resources/Directory.Build.props`, com `Nullable` e `ImplicitUsings` ajustados
(aqui, `enable`):
```xml
<?xml version="1.0" encoding="utf-8"?>

<Project>
    <PropertyGroup>
        <Nullable>enable</Nullable>
        <ImplicitUsings>enable</ImplicitUsings>
        <PublishAot>false</PublishAot>
        <SatelliteResourceLanguages>pt-BR</SatelliteResourceLanguages>
        <NoWarn>
            $(NoWarn)
        </NoWarn>
        <NoError>
            $(NoError);
        </NoError>
    </PropertyGroup>
</Project>
```

Errado — acrescentar `TargetFramework`, `LangVersion` ou qualquer item que não esteja no resource.

## Caso misto, sem `Directory.Build.props` existente
Estado antes, três projetos:
- `Domain.csproj`: `Nullable` `enable`, `ImplicitUsings` `enable`.
- `Application.csproj`: `Nullable` `enable`, `ImplicitUsings` ausente.
- `Infrastructure.csproj`: `Nullable` ausente, `ImplicitUsings` `enable`.

Cálculo: `Nullable` é misto (`enable`, `enable`, `disable`) e `ImplicitUsings` é misto (`enable`,
`disable`, `enable`), então o `Directory.Build.props` fica com `enable` nos dois. A `Application`
precisa de `ImplicitUsings` `disable` explícito, e a `Infrastructure` precisa de `Nullable`
`disable` explícito.

Errado — `Application` sem a diretiva explícita (herdaria `enable` e mudaria de comportamento):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
```

Certo — `Application.csproj` depois da skill (`TargetFramework` não é tocado):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>Bank.Application</RootNamespace>
    <ImplicitUsings>disable</ImplicitUsings>
  </PropertyGroup>
</Project>
```
O `Infrastructure.csproj` fica com `TargetFramework`, `RootNamespace` e `<Nullable>disable</Nullable>`.

## Diretiva ausente com `Directory.Build.props` existente
Estado antes: o `Directory.Build.props` já tem `<ImplicitUsings>enable</ImplicitUsings>`; o
`Domain.csproj` não declara `ImplicitUsings`; o `Application.csproj` declara `disable`.

Cálculo: o `Domain` herda `enable` do arquivo existente, então o valor efetivo dele é `enable`
(não `disable`). Com `enable` e `disable`, o caso é misto: o `Directory.Build.props` fica com
`enable`, o `Domain` não recebe diretiva nenhuma e o `Application` mantém `disable`.

Errado — o `Domain` tratado como `disable` por não ter a diretiva: ele ganharia
`<ImplicitUsings>disable</ImplicitUsings>` e mudaria de comportamento.

## AssemblyName, InternalsVisibleTo e entrypoint.sh
Estado antes:
- `Billing.Api.csproj` com `<AssemblyName>Billing</AssemblyName>`.
- `Billing.IntegrationTests.csproj` com `<AssemblyName>Billing.Tests</AssemblyName>`.
- `Billing.Api.csproj`, linhas 9-11:
  ```xml
  <ItemGroup>
    <InternalsVisibleTo Include="Billing.Tests" />
  </ItemGroup>
  ```
- `entrypoint.sh`, linhas 3-4: `exec dotnet Billing.dll "$@"`.
- `Dockerfile`: `ENTRYPOINT ["dotnet", "Billing.dll"]`.

Mapa de nomes: `Billing` para `Billing.Api` e `Billing.Tests` para `Billing.IntegrationTests`.

Certo — a skill remove os dois `AssemblyName`, troca o `InternalsVisibleTo` (que está num projeto
diferente do que perdeu o `AssemblyName`) e o `entrypoint.sh`, e lista tudo no plano:

| Projeto | Valor hoje | Nome do assembly depois | Alerta |
|---|---|---|---|
| `Billing.Api` | `Billing` | `Billing.Api` | valor diferente do nome do arquivo; o `Dockerfile` cita `Billing.dll` |
| `Billing.IntegrationTests` | `Billing.Tests` | `Billing.IntegrationTests` | valor diferente do nome do arquivo |

| Id | Onde | Hoje | Depois | Ação |
|---|---|---|---|---|
| N1 | `Billing.Api.csproj:10` | `InternalsVisibleTo Include="Billing.Tests"` | `Include="Billing.IntegrationTests"` | editar |
| N2 | `entrypoint.sh:3-4` | `dotnet Billing.dll` | `dotnet Billing.Api.dll` | editar |

Depois da execução:
```xml
<ItemGroup>
  <InternalsVisibleTo Include="Billing.IntegrationTests" />
</ItemGroup>
```
`exec dotnet Billing.Api.dll "$@"`, com o fim de linha e a permissão de execução do arquivo
originais. O `Dockerfile` não é alterado: o `ENTRYPOINT` aparece como alerta.

Valor com sufixo — só a parte do nome muda:
`Include="Billing.Tests, PublicKey=0024..."` vira `Include="Billing.IntegrationTests, PublicKey=0024..."`.

Errado — remover o `AssemblyName` e deixar `Billing.Tests` no `InternalsVisibleTo` (os testes
deixam de enxergar os tipos `internal`); deixar `Billing.dll` no `entrypoint.sh` (o contêiner
não sobe); recriar o `entrypoint.sh` com outro fim de linha ou sem a permissão de execução; ajustar o
`ENTRYPOINT` do `Dockerfile` ou um `[assembly: InternalsVisibleTo]` de `.cs`; remover o
`AssemblyName` sem listá-lo no plano.

## Atualizar a solution quando um arquivo é movido
Estado antes: `.editorconfig` em `app/.editorconfig`; solution em `app/src/Bank.sln` (ou
`Bank.slnx`) com o arquivo listado em "Solution Items". O `.editorconfig` vai para `app/src`.

`.sln`, antes e depois (os dois lados de `caminho = caminho` mudam):
```text
ProjectSection(SolutionItems) = preProject
    ..\.editorconfig = ..\.editorconfig
EndProjectSection
```
```text
ProjectSection(SolutionItems) = preProject
    .editorconfig = .editorconfig
EndProjectSection
```

`.slnx`, antes e depois:
```xml
<File Path="../.editorconfig" />
```
```xml
<File Path=".editorconfig" />
```

Errado — mover o arquivo e deixar a solution apontando para `..\.editorconfig`: o arquivo some do
"Solution Items" ou aparece quebrado na IDE. Também errado: acrescentar à solution um arquivo que
ela não listava.
