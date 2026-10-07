# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com o Template canônico, o Template vence.

## Framework e LangVersion
Estado antes: `Directory.Build.props` com `Nullable` e `ImplicitUsings`; `Api.csproj` e
`Domain.csproj` com `<TargetFramework>net8.0</TargetFramework>`.

Errado — sem contexto: `TargetFramework` repetido no `.csproj` e `Directory.Build.props`
reescrito do zero, perdendo as outras propriedades:
```xml
<!-- Directory.Build.props -->
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>

<!-- Domain.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
```

Certo — com contexto (depois da skill):
```xml
<!-- Directory.Build.props: só as duas linhas entram; o resto fica como estava -->
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <LangVersion>14</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>

<!-- Domain.csproj: sem TargetFramework nem LangVersion -->
<Project Sdk="Microsoft.NET.Sdk">
</Project>
```

Diferença: o `.csproj` não repete o que o `Directory.Build.props` define (CONV-001); as propriedades
que a skill não gerencia permanecem; o `PropertyGroup` que ficou vazio foi removido.

## Escolha de versão de pacote
| Pacote | Versão hoje | Candidata | Decisão |
|---|---|---|---|
| `Microsoft.AspNetCore.OpenApi` | `8.0.8` | `10.0.x` estável | certo: atualizar para a maior `10.0.x` estável |
| `Microsoft.AspNetCore.OpenApi` | `8.0.8` | `11.0.0-preview.1` | errado: prerelease e major 11 |
| `FluentValidation` | `11.9.0` | `11.x` estável | certo: atualizar dentro da major atual |
| `FluentValidation` | `11.9.0` | próxima major | errado: sem necessidade comprovada pelo build; só sobe se a versão atual não compilar em `net10.0`, e a subida é relatada |
| Pacote sem versão estável compatível | `2.3.0` | nenhuma | certo: manter `2.3.0` e relatar o motivo |
