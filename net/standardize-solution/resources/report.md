# Relatórios (formato)

Dois relatórios, ambos em tabelas Markdown: o **relatório de plano**, apresentado no passo 5 do
Fluxo do `SKILL.md` antes de qualquer escrita, e o **relatório final**, apresentado ao concluir ou
ao parar. Grupo sem linhas aparece com "nenhum".

# Relatório de plano

Toda linha de ação tem um identificador (`A1`, `P1`, `S1`, `N1`...) para o usuário poder excluí-la na
aprovação. Ações possíveis: `criar`, `mover`, `editar`, `remover`, `acrescentar`, `atualizar`,
`manter`, `nada`, `parar`. Linha com `parar` não pode ser aprovada: ela descreve o bloqueio.

## 0. Visão geral
Vem primeiro. O usuário deve entender o que vai acontecer sem ler as tabelas seguintes.

| Categoria | Quantidade |
|---|---|
| Arquivos a criar | |
| Arquivos a mover | |
| Entradas da solution a atualizar | |
| Projetos a editar | |
| `AssemblyName` a remover | |
| Referências ao nome do assembly a ajustar | |
| Bloqueios e alertas | |

Arquivos a criar:

| Arquivo | Caminho final | Origem do conteúdo |
|---|---|---|
| `.editorconfig` | `{SolutionDir}/.editorconfig` | `resources/.editorconfig` |

Arquivos a mover:

| Arquivo | De | Para |
|---|---|---|
| `Dockerfile` | diretório de origem | `{SolutionDir}` |

Entradas da solution a atualizar:

| Arquivo da solution | Caminho hoje | Caminho depois |
|---|---|---|
| `Bank.sln` | `..\.editorconfig` | `.editorconfig` |

`AssemblyName` a remover:

| Projeto | Valor hoje | Nome do assembly depois | Alerta |
|---|---|---|---|
| `Billing.Api` | `Billing` | `Billing.Api` | valor diferente do nome do arquivo; o `Dockerfile` cita `Billing.dll` |
| `Billing.IntegrationTests` | `Billing.Tests` | `Billing.IntegrationTests` | valor diferente do nome do arquivo |

Referências ao nome do assembly a ajustar (`InternalsVisibleTo` e `entrypoint.sh`):

| Onde (`arquivo:linhas`) | Nome hoje | Nome depois |
|---|---|---|
| `Api.csproj:9-11` | `Billing.Tests` | `Billing.IntegrationTests` |
| `entrypoint.sh:3-4` | `Billing.dll` | `Billing.Api.dll` |

## 1. Identificação
| Item | Valor |
|---|---|
| Solution | caminho do `.sln`/`.slnx` escolhido |
| SolutionDir | diretório dela |
| RepoRoot | raiz do repositório |
| Solutions descartadas (`E2E`) | caminho de cada uma, ou "nenhuma" |
| Projetos | quantidade e lista |

## 2. Arquivos de raiz
Uma linha por arquivo: `Directory.Build.props`, `.editorconfig`, `.dockerignore`, `Dockerfile`,
`nuget.config`. O `entrypoint.sh` não entra aqui: ele é tratado na seção 7.

| Id | Arquivo | Onde existe hoje | Ação | Detalhe |
|---|---|---|---|---|
| A1 | `Dockerfile` | caminho, ou "não existe" | mover | de onde para `{SolutionDir}` |
| A2 | `.editorconfig` | "não existe" | criar | cópia de `resources/.editorconfig` |

## 3. Solution
Uma linha por entrada de arquivo da solution que muda de caminho.

| Id | Arquivo da solution | Entrada | Caminho hoje | Caminho depois | Ação | Detalhe |
|---|---|---|---|---|---|---|
| S1 | `Bank.sln` | Solution Items | `..\.editorconfig` | `.editorconfig` | atualizar | depende de A1 |

## 4. Directory.Build.props
| Id | Item | Valor hoje | Valor depois | Ação | Detalhe |
|---|---|---|---|---|---|
| D1 | `Nullable` | | | | |
| D2 | `ImplicitUsings` | | | | |

Cálculo de Nullable e ImplicitUsings:

| Propriedade | Valor efetivo por projeto (diretiva, ou herdado do `Directory.Build.props` existente, ou `disable`) | Situação (todos `disable`, todos `enable`, misto) | Valor no `Directory.Build.props` | Projetos que ficam com `disable` explícito |
|---|---|---|---|---|

## 5. Propriedades dos `.csproj`
Uma linha por projeto e propriedade removida, ajustada ou mantida: `Nullable`, `ImplicitUsings`,
`PublishAot`, `SatelliteResourceLanguages`, `AssemblyName`.

| Id | Projeto | Propriedade | Valor hoje | Valor depois | Ação | Detalhe |
|---|---|---|---|---|---|---|
| P1 | `Billing.Api` | `AssemblyName` | `Billing` | (nome do arquivo `.csproj`) | remover | listado na visão geral |
| P2 | `Billing.IntegrationTests` | `AssemblyName` | `Billing.Tests` | (nome do arquivo `.csproj`) | remover | listado na visão geral |

## 6. RootNamespace
| Id | Projeto | Valor hoje | Valor calculado | Arquivos `.cs` que sustentam o valor | Ação |
|---|---|---|---|---|---|

## 7. Referências ao nome do assembly
Uma linha por ocorrência de um `AssemblyName` removido: `InternalsVisibleTo` em qualquer `.csproj`
e `{Old}.dll` em `entrypoint.sh`. A coluna "Onde" usa `arquivo:linhas`. Ocorrência em `Dockerfile`,
`.cs` ou outro arquivo entra com ação `relatar` (e também na seção 8).

| Id | Onde | Tipo | Nome hoje | Nome depois | Ação | Depende de |
|---|---|---|---|---|---|---|
| N1 | `Api.csproj:9-11` | `InternalsVisibleTo` | `Billing.Tests` | `Billing.IntegrationTests` | editar | P2 |
| N2 | `entrypoint.sh:3-4` | `entrypoint.sh` | `Billing.dll` | `Billing.Api.dll` | editar | P1 |

## 8. Bloqueios e alertas
Tudo que faria a skill parar ou que o usuário precisa saber: propriedade condicional, valor fora
de `enable`/`disable`, `Directory.Build.props` em outro diretório, arquivo de raiz duplicado,
`PublishAot`, `SatelliteResourceLanguages` ou `AssemblyName` com valor diferente do esperado,
`RootNamespace` divergente, entrada duplicada na solution, outra solution (descartada) que
referencia arquivo movido, `.csproj` ou `Dockerfile` que cita arquivo movido, `Dockerfile`, `.cs`,
`.props`/`.targets` ou outro script que cita o nome antigo do assembly, `entrypoint.sh` que cita o
nome antigo sem `.dll`, mapa de nomes ambíguo (dois projetos com o mesmo nome antigo), `Dockerfile`
movido (`COPY` relativo).

| Id | Onde | Situação | Efeito |
|---|---|---|---|

## Fecho do relatório de plano
Termine com: quantidade de linhas por ação e a frase "Responda `aprovo` para executar tudo, ou
liste os identificadores a excluir." Não execute nada enquanto não houver resposta.

# Relatório final

Apresentado depois do Harness, ou ao parar (nesse caso, com o motivo da parada na tabela F1).
Os identificadores são os do relatório de plano.

## F1. O que foi feito, por linha do plano
| Id | Item | Ação planejada | Resultado | Observação |
|---|---|---|---|---|

`Resultado`: `feito`, `excluído pelo usuário`, `não executado` (parou antes) ou `parou aqui`.

## F2. Arquivos criados e movidos
| Arquivo | Ação | Caminho final | Origem do conteúdo (se criado) |
|---|---|---|---|

## F3. Solution
| Arquivo da solution | Entrada | Caminho anterior | Caminho novo |
|---|---|---|---|

## F4. Projetos editados
| Projeto | Propriedades removidas (com valor anterior) | `AssemblyName` removido (valor anterior e nome depois) | Diretivas mantidas ou acrescentadas | RootNamespace |
|---|---|---|---|---|

## F5. Referências ao nome do assembly
| Onde (`arquivo:linhas`) | Tipo | Nome anterior | Nome novo | Resultado |
|---|---|---|---|---|

`Resultado`: `feito` ou `excluído pelo usuário` (nesse caso, a referência ainda aponta para o nome
antigo e isso é uma pendência).

## F6. Harness
| Verificação | Resultado | Observação |
|---|---|---|

Verificações: comparação dos valores efetivos com a linha de base (as diferenças esperadas
aparecem aqui), `dotnet sln list` e caminhos da solution, `dotnet build`, `dotnet test`, busca do
nome antigo do assembly em `InternalsVisibleTo` e `entrypoint.sh`. Falha de
ambiente aparece como "Harness incompleto".

## F7. Fora do escopo e pendências
| Item | Situação |
|---|---|
| `TargetFramework` e `LangVersion` | não alterados |
| Conteúdo do `Dockerfile` (`COPY` relativo, `ENTRYPOINT`, se movido ou se o `AssemblyName` mudou) | não alterado |
| `[assembly: InternalsVisibleTo]` em `.cs`, `InternalsVisibleTo` em `.props`/`.targets`, outros scripts e `docker-compose` que citam o nome antigo | listados, não alterados |
| Solutions descartadas que referenciam arquivo movido | não alteradas |
| Pacotes | não alterados |
