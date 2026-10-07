# Relatórios (formato)

Dois relatórios, ambos em tabelas Markdown: o **relatório de plano**, apresentado no passo 5 do
Fluxo do `SKILL.md` antes de qualquer escrita, e o **relatório final**, apresentado ao concluir ou
ao parar. Grupo sem linhas aparece com "nenhum".

# Relatório de plano

Toda linha de ação tem um identificador (`A1`, `P1`, `K1`...) para o usuário poder excluí-la na
aprovação. Ações possíveis: `criar`, `editar`, `remover`, `atualizar`, `manter`, `nada`, `parar`.
Linha com `parar` não pode ser aprovada: ela descreve o bloqueio.

## 0. Visão geral
Vem primeiro. O usuário deve entender o que vai acontecer sem ler as tabelas seguintes.

| Categoria | Quantidade |
|---|---|
| Arquivos a criar | |
| Arquivos a editar | |
| Projetos a editar | |
| Pacotes a atualizar | |
| Pacotes mantidos | |
| Bloqueios e alertas | |

Arquivos a criar:

| Arquivo | Caminho final |
|---|---|
| `global.json` | `{SolutionDir}/global.json` |

Arquivos a editar:

| Arquivo | O que muda |
|---|---|
| `Directory.Build.props` | `TargetFramework` e `LangVersion` |

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

## 2. Arquivos de configuração
Uma linha por arquivo: `Directory.Build.props`, `global.json`, `Directory.Packages.props`.

| Id | Arquivo | Onde existe hoje | Ação | Detalhe |
|---|---|---|---|---|
| A1 | `global.json` | "não existe" | criar | `dotnet new globaljson`; SDK esperado `10.x` |

## 3. TargetFramework e LangVersion por projeto
Uma linha por projeto e propriedade.

| Id | Projeto | Propriedade | Valor hoje | Valor no `Directory.Build.props` | Ação | Detalhe |
|---|---|---|---|---|---|---|
| P1 | `Domain` | `TargetFramework` | `net8.0` | `net10.0` | remover | |

## 4. Pacotes
Uma linha por pacote e projeto (ou por `PackageVersion`, com Central Package Management).

| Id | Projeto ou arquivo | Pacote | Versão hoje | Família (Microsoft ou terceiro) | Versão alvo | Ação | Motivo |
|---|---|---|---|---|---|---|---|
| K1 | `Api` | `Microsoft.AspNetCore.OpenApi` | `8.0.x` | Microsoft | `10.0.x` | atualizar | |

## 5. Bloqueios e alertas
Tudo que faria a skill parar ou que o usuário precisa saber: multi-target, propriedade condicional,
`TargetFramework` diferente de `net8.0`, `Directory.Build.props` ou `global.json` em outro
diretório, `global.json` com SDK que não é 10, pacote sem versão estável compatível, subida de
major de terceiro.

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

## F2. Arquivos criados e editados
| Arquivo | Ação | O que mudou |
|---|---|---|

## F3. Projetos editados
| Projeto | Propriedades removidas (com valor anterior) | Observação |
|---|---|---|

## F4. Pacotes atualizados
| Pacote | Projeto ou arquivo | Versão anterior | Versão nova |
|---|---|---|---|

## F5. Pacotes mantidos
| Pacote | Versão | Motivo |
|---|---|---|

## F6. Harness
| Comando | Resultado | Observação (warnings novos, falhas, pacotes deprecated ou vulneráveis) |
|---|---|---|

Comandos: `dotnet restore`, `dotnet build`, `dotnet test`, `dotnet list package` (prerelease e
major), `dotnet list package --deprecated` e `--vulnerable`. Falha de ambiente aparece como
"Harness incompleto".

## F7. Fora do escopo e pendências
| Item | Situação |
|---|---|
| Dockerfile (imagem base) | não alterado |
| Pipeline de CI (versão do SDK) | não alterado |
| Código-fonte (breaking changes) | não alterado |
