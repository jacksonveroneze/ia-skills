# Exemplos (certo/errado)

Exemplos de apoio da skill `SKILL.md`. Em conflito com a seção do arquivo, a seção vence. As
versões de SDK e de pacote são ilustrativas: valem as que a skill levanta na máquina e no feed.

## Directory.Build.props e .csproj
Estado antes: `Directory.Build.props` com `Nullable` e `ImplicitUsings`; `Api.csproj` e
`Domain.csproj` com `<TargetFramework>net8.0</TargetFramework>`.

Errado — `TargetFramework` repetido no `.csproj` e `Directory.Build.props` reescrito do zero,
perdendo as outras propriedades:
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

Certo — depois da skill:
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
O `PropertyGroup` que ficou vazio no `.csproj` foi removido. Um projeto com
`<TargetFramework>netstandard2.0</TargetFramework>` aparece como alerta em linha própria; se o
usuário excluir a linha, o `.csproj` mantém o valor dele.

## global.json
Estado antes, existente:
```json
{
  "sdk": {
    "version": "8.0.404",
    "rollForward": "latestFeature"
  }
}
```

Certo — só `sdk.version` muda, para o SDK 10 estável instalado:
```json
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "latestFeature"
  }
}
```

Errado — rodar `dotnet new globaljson` por cima: o arquivo é regerado e o `rollForward` se perde.

Estado antes, ausente: a skill roda `dotnet new globaljson` em `{SolutionDir}` e confere que a
versão gerada é a do SDK 10 estável, sem sufixo de prerelease.

## Dockerfile
Estado antes:
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Api.dll"]
```

Certo — só a versão nas duas tags muda:
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Api.dll"]
```
Alerta fixo no relatório: a tag `10.0` é Ubuntu 24.04, e a `8.0` era Debian.

Outras linhas, e o que a skill faz:

| Linha antes | Depois | Motivo |
|---|---|---|
| `FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine` | `FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine` | variante `alpine` está na tabela |
| `FROM mcr.microsoft.com/dotnet/aspnet:8.0-noble-chiseled` | `FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled` | variante `noble-chiseled` está na tabela |
| `ARG DOTNET_VERSION=8.0` e `FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}` | `ARG DOTNET_VERSION=10.0`; o `FROM` não muda | o `ARG` alimenta o `FROM` |
| `FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim` | igual | variante fora da tabela: alerta |
| `FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled` | igual | variante fora da tabela: alerta |
| `FROM mcr.microsoft.com/dotnet/aspnet@sha256:...` | igual | digest: alerta |
| `FROM node:20 AS web` | igual | não é imagem .NET |

Errado — trocar `8.0-bookworm-slim` por `10.0-bookworm-slim` por conta própria (as imagens .NET 10
não são Debian, então a tag pode não existir), ou ajustar o `ENTRYPOINT`, o `COPY` ou o `USER`.

## Escolha de versão de pacote
| Pacote | Versão hoje | Candidata | Decisão |
|---|---|---|---|
| `Microsoft.AspNetCore.OpenApi` | `8.0.8` | `10.0.x` estável | certo: atualizar para a maior `10.0.x` estável |
| `Microsoft.AspNetCore.OpenApi` | `8.0.8` | `11.0.0-preview.1` | errado: prerelease e major 11 |
| `FluentValidation` | `11.9.0` | `11.x` estável | certo: atualizar dentro da major atual |
| `FluentValidation` | `11.9.0` | próxima major | errado: sem necessidade comprovada pelo build; só sobe se a versão atual não compilar em `net10.0`, e a subida é relatada |
| Pacote sem versão estável compatível | `2.3.0` | nenhuma | certo: manter `2.3.0` e relatar o motivo |

## Outros locais que citam a versão
Estado antes: `.github/workflows/ci.yml` com `dotnet-version: 8.0.x` na linha 18 e
`docker-compose.yml` com `image: mcr.microsoft.com/dotnet/aspnet:8.0` na linha 7.

Certo — os dois arquivos não são alterados e entram no relatório:

| Id | Arquivo | Linha | Trecho |
|---|---|---|---|
| O1 | `.github/workflows/ci.yml` | 18 | `dotnet-version: 8.0.x` |
| O2 | `docker-compose.yml` | 7 | `image: mcr.microsoft.com/dotnet/aspnet:8.0` |

Errado — atualizar o pipeline ou o `docker-compose` junto: eles não estão na tabela "Onde a versão sobe".
