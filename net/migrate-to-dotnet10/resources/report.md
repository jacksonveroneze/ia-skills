# Relatórios (formato)

Dois relatórios, ambos em tabelas Markdown: o **relatório de plano**, apresentado no passo 5 do
Fluxo do `SKILL.md` antes de qualquer escrita, e o **relatório final**, apresentado ao concluir ou
ao parar. Grupo sem linhas aparece com "nenhum".

# Relatório de plano

Toda linha de ação tem um identificador (`A1`, `P1`, `G1`, `F1`, `K1`, `O1`...) para o usuário
poder excluí-la na aprovação. Ações possíveis: `criar`, `editar`, `remover`, `atualizar`, `manter`,
`relatar`, `nada`, `parar`. Linha com `parar` não pode ser aprovada: ela descreve o bloqueio.

## 0. Visão geral
Vem primeiro. O usuário deve entender o que vai acontecer sem ler as tabelas seguintes.

| Categoria | Quantidade |
|---|---|
| Locais onde a versão do .NET sobe | |
| Arquivos a criar | |
| Arquivos a editar | |
| Pacotes a atualizar | |
| Pacotes mantidos | |
| Outros locais que citam a versão (só relato) | |
| Bloqueios e alertas | |

Onde a versão sobe (uma linha por local e item, com os valores reais levantados):

| Local | Item | De | Para | Ids |
|---|---|---|---|---|
| `Directory.Build.props` | `TargetFramework` | `net8.0` | `net10.0` | A1 |
| `Directory.Build.props` | `LangVersion` | ausente | `14` | A1 |
| `Domain.csproj` | `TargetFramework` | `net8.0` | removido | P1 |
| `global.json` | `sdk.version` | `8.0.404` | `10.0.100` | G1 |
| `Dockerfile` | `FROM ...aspnet` | `8.0` | `10.0` | F1 |
| `Api.csproj` | `Microsoft.AspNetCore.OpenApi` | `8.0.8` | `10.0.x` | K1 |

Arquivos a criar:

| Arquivo | Caminho final |
|---|---|
| `global.json` | `{SolutionDir}/global.json` |

Pacotes a atualizar (um por pacote, consolidando os projetos):

| Pacote | De | Para | Projetos |
|---|---|---|---|
| `Microsoft.AspNetCore.OpenApi` | `8.0.x` | `10.0.x` | `Api` |

## 1. Identificação
| Item | Valor |
|---|---|
| Solution | caminho do `.sln`/`.slnx` escolhido |
| SolutionDir | diretório dela |
| RepoRoot | raiz do repositório |
| SDK em uso | saída de `dotnet --version` e a verificação de preview |
| Solutions descartadas (`E2E`) | caminho de cada uma, ou "nenhuma" |
| Projetos | quantidade e lista |

## 2. Directory.Build.props
| Id | Item | Valor hoje | Valor depois | Ação | Detalhe |
|---|---|---|---|---|---|
| A1 | `TargetFramework` | `net8.0` | `net10.0` | editar | |
| A1 | `LangVersion` | ausente | `14` | editar | |

## 3. TargetFramework e LangVersion por projeto
Uma linha por projeto e propriedade.

| Id | Projeto | Propriedade | Valor hoje | Valor no `Directory.Build.props` | Ação | Detalhe |
|---|---|---|---|---|---|---|
| P1 | `Domain` | `TargetFramework` | `net8.0` | `net10.0` | remover | |

## 4. global.json
| Id | Onde existe hoje | `sdk.version` hoje | `sdk.version` depois (`{Sdk10}`) | `rollForward` | `allowPrerelease` | Ação |
|---|---|---|---|---|---|---|
| G1 | caminho, ou "não existe" | | | preservado | | editar ou criar |

## 5. Dockerfile
Uma linha por `FROM` e por `ARG` que alimenta um `FROM`.

| Id | Dockerfile | Linha | Imagem | Tag hoje | Tag nova | Ação | Detalhe |
|---|---|---|---|---|---|---|---|
| F1 | caminho | 1 | `aspnet` | `8.0` | `10.0` | editar | sistema operacional base muda de Debian para Ubuntu 24.04 |
| F2 | caminho | 5 | `aspnet` | `8.0-bookworm-slim` | (igual) | relatar | variante fora da tabela |

## 6. Pacotes
Uma linha por pacote e projeto (ou por `PackageVersion`, com Central Package Management).

| Id | Projeto ou arquivo | Pacote | Versão hoje | Família (Microsoft ou terceiro) | Versão alvo | Ação | Motivo |
|---|---|---|---|---|---|---|---|
| K1 | `Api` | `Microsoft.AspNetCore.OpenApi` | `8.0.x` | Microsoft | `10.0.x` | atualizar | |

## 7. Outros locais que citam a versão (somente relato)
| Id | Arquivo | Linha | Trecho |
|---|---|---|---|
| O1 | `.github/workflows/ci.yml` | 18 | `dotnet-version: 8.0.x` |

## 8. Bloqueios e alertas
Tudo que faria a skill parar ou que o usuário precisa saber: multi-target, propriedade condicional,
`TargetFramework` diferente de `net8.0`, `Directory.Build.props` ou `global.json` em outro
diretório, `allowPrerelease` `true`, tag de `Dockerfile` fora da tabela, mudança de sistema
operacional da imagem, pacote sem versão estável compatível, subida de major de terceiro.

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

## F2. Onde a versão subiu
| Local | Item | Valor anterior | Valor novo | Resultado |
|---|---|---|---|---|

## F3. Arquivos criados e editados
| Arquivo | Ação | O que mudou |
|---|---|---|

## F4. Projetos editados
| Projeto | Propriedades removidas (com valor anterior) | Observação |
|---|---|---|

## F5. Dockerfile
| Dockerfile | Linha | Tag anterior | Tag nova | Verificada (`docker manifest inspect`) |
|---|---|---|---|---|

Linhas relatadas e não alteradas aparecem com "não alterada" e o motivo. Tag sem Docker ou sem
rede aparece como "não verificada".

## F6. Pacotes atualizados
| Pacote | Projeto ou arquivo | Versão anterior | Versão nova |
|---|---|---|---|

## F7. Pacotes mantidos
| Pacote | Versão | Motivo |
|---|---|---|

## F8. Harness
| Comando | Resultado | Observação (warnings novos, falhas, pacotes deprecated ou vulneráveis) |
|---|---|---|

Comandos: `dotnet restore`, avaliação de `TargetFramework`/`LangVersion` e `dotnet --version`,
`dotnet build`, `dotnet test`, `dotnet list package`, verificação das tags do `Dockerfile`. Falha
de ambiente aparece como "Harness incompleto".

## F9. Alertas, outros locais e fora do escopo
| Item | Situação |
|---|---|
| Outros locais que citam a versão (pipeline, `docker-compose`, `.devcontainer`) | listados, não alterados |
| Sistema operacional das imagens (Debian para Ubuntu 24.04) | alerta |
| `COPY`, `ENTRYPOINT`, `USER` do `Dockerfile` | não avaliados |
| Código-fonte (breaking changes) | não alterado |
