# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com o Template canônico, o Template vence.

## Caso misto, sem `Directory.Build.props` existente
Estado antes, solution com três projetos, sem `Directory.Build.props`:
- `Domain.csproj`: `Nullable` `enable`, `ImplicitUsings` `enable`.
- `Application.csproj`: `Nullable` `enable`, `ImplicitUsings` ausente.
- `Infrastructure.csproj`: `Nullable` ausente, `ImplicitUsings` `enable`.

Cálculo: `Nullable` é misto (`enable`, `enable`, `disable`) e `ImplicitUsings` é misto (`enable`,
`disable`, `enable`), então o `Directory.Build.props` fica com `enable` nos dois. A `Application`
precisa de `ImplicitUsings` `disable` explícito, e a `Infrastructure` precisa de `Nullable`
`disable` explícito.

Errado — sem contexto: diretivas repetidas, `Application` sem a diretiva explícita (herdaria
`enable` e mudaria de comportamento), `RootNamespace` ausente:
```xml
<!-- Application.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
```

Certo — com contexto (`Application.csproj`, depois da skill):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>Bank.Application</RootNamespace>
    <ImplicitUsings>disable</ImplicitUsings>
  </PropertyGroup>
</Project>
```
O `Domain.csproj` fica com `TargetFramework` e `RootNamespace`. O `Infrastructure.csproj` fica com
`TargetFramework`, `RootNamespace` e `<Nullable>disable</Nullable>`.

Diferença: `Nullable` sai do `Application` porque o `Directory.Build.props` o define (CONV-001); a
diretiva `disable` só permanece onde o projeto divergia do valor global; `TargetFramework` não é
tocado por esta skill; `RootNamespace` vem do namespace declarado nos `.cs` do projeto.

## Diretiva ausente com `Directory.Build.props` existente
Estado antes: o `Directory.Build.props` já tem `<ImplicitUsings>enable</ImplicitUsings>`; o
`Domain.csproj` não declara `ImplicitUsings`; o `Application.csproj` declara `disable`.

Cálculo: o `Domain` herda `enable` do arquivo existente, então o valor efetivo dele é `enable`
(não `disable`). Com `enable` e `disable`, o caso é misto: o `Directory.Build.props` fica com
`enable`, o `Domain` não recebe diretiva nenhuma e o `Application` mantém `disable`.

Errado — o `Domain` tratado como `disable` por não ter a diretiva: ele ganharia
`<ImplicitUsings>disable</ImplicitUsings>` e mudaria de comportamento.
