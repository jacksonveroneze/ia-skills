# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com a seção do arquivo, a seção vence.

## Directory.Build.props novo, com `BannedSymbols.txt`
Estado antes: sem `Directory.Build.props`; sem `BannedSymbols.txt` em `{SolutionDir}`; os projetos
têm `Nullable` e `ImplicitUsings` em `enable`. A linha de criação do `BannedSymbols.txt` está no
plano e foi aprovada, então o arquivo vai existir e o item `AdditionalFiles` permanece.

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

    <ItemGroup>
        <AdditionalFiles Include="$(MSBuildThisFileDirectory)BannedSymbols.txt" Link="Properties/BannedSymbols.txt"/>
    </ItemGroup>
</Project>
```

## Directory.Build.props novo, sem `BannedSymbols.txt`
Estado antes: igual ao anterior, mas o usuário excluiu a linha de criação do `BannedSymbols.txt`; o
arquivo não vai existir.

Errado — o item `AdditionalFiles` fica apontando para um arquivo que não existe.

Certo — o mesmo arquivo, sem o `ItemGroup`:
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

## AssemblyName
Estado antes: `Billing.Api.csproj` com `<AssemblyName>Billing</AssemblyName>`; o `Dockerfile` tem
`ENTRYPOINT ["dotnet", "Billing.dll"]`.

Certo — a skill remove o `AssemblyName` e lista nas tabelas de resumo:

| Projeto | Valor hoje | Nome do assembly depois | Alerta |
|---|---|---|---|
| `Billing.Api` | `Billing` | `Billing.Api` | valor diferente do nome do arquivo; o `Dockerfile` cita `Billing.dll` |

O `Dockerfile` não é alterado.

Errado — remover o `AssemblyName` sem listá-lo, ou ajustar o `ENTRYPOINT` do `Dockerfile`.

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
