# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com o Template canônico, o Template vence.

Estado antes, solution com três projetos, todos `net8.0`:
- `Domain.csproj`: `Nullable` `enable`, `ImplicitUsings` `enable`.
- `Application.csproj`: `Nullable` `enable`, `ImplicitUsings` ausente.
- `Infrastructure.csproj`: `Nullable` ausente, `ImplicitUsings` `enable`.

Cálculo: `Nullable` é misto (`enable`, `enable`, `disable`) e `ImplicitUsings` é misto (`enable`,
`disable`, `enable`), então o `Directory.Build.props` fica com `enable` nos dois. A `Application`
precisa de `ImplicitUsings` `disable` explícito, e a `Infrastructure` precisa de `Nullable`
`disable` explícito.

Errado — sem contexto: `TargetFramework` mantido, diretivas repetidas, `Application` sem a
diretiva explícita (herdaria `enable` e mudaria de comportamento), `RootNamespace` ausente:
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
    <RootNamespace>Bank.Application</RootNamespace>
    <ImplicitUsings>disable</ImplicitUsings>
  </PropertyGroup>
</Project>
```
O `Domain.csproj` fica só com `RootNamespace`. O `Infrastructure.csproj` fica com `RootNamespace` e
`<Nullable>disable</Nullable>`.

Diferença: `TargetFramework` e `Nullable` saem porque o `Directory.Build.props` os define (CONV-001);
a diretiva `disable` só permanece onde o projeto divergia do valor global; `RootNamespace` vem do
namespace declarado nos `.cs` do projeto; nenhum pacote novo apareceu.