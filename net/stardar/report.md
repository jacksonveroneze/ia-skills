# Relatórios (formato)

Dois relatórios, ambos em tabelas Markdown: o **relatório de plano**, apresentado no passo 5 do
Fluxo do `SKILL.md` antes de qualquer escrita, e o **relatório final**, apresentado ao concluir ou
ao parar. Grupo sem linhas aparece com "nenhum".

# Relatório de plano

Toda linha de ação tem um identificador (`A1`, `P1`, `R1`...) para o usuário poder excluí-la na
aprovação. Ações possíveis: `criar`, `mover`, `editar`, `remover`, `acrescentar`, `manter`, `nada`,
`parar`. Linha com `parar` não pode ser aprovada: ela descreve o bloqueio.

## 0. Visão geral
Vem primeiro. O usuário deve entender o que vai acontecer sem ler as tabelas seguintes.

| Categoria | Quantidade |
|---|---|
| Arquivos a criar | |
| Arquivos a mover | |
| Projetos a editar | |
| Bloqueios e alertas | |

Arquivos a criar:

| Arquivo | Caminho final |
|---|---|
| `Directory.Build.props` | `{SolutionDir}/Directory.Build.props` |

Arquivos a mover:

| Arquivo | De | Para |
|---|---|---|
| `Dockerfile` | diretório de origem | `{SolutionDir}` |

## 1. Identificação
| Item | Valor |
|---|---|
| Solution | caminho do `.sln`/`.slnx` escolhido |
| SolutionDir | diretório dela |
| RepoRoot | raiz do repositório |
| Solutions descartadas (`E2E`) | caminho de cada uma, ou "nenhuma" |
| Projetos | quantidade e lista |

## 2. Arquivos de raiz
Uma linha por arquivo: `Directory.Build.props`, `Dockerfile`, `.dockerignore`, `nuget.config`,
`.editorconfig`, `BannedSymbols.txt`.

| Id | Arquivo | Onde existe hoje | Ação | Detalhe |
|---|---|---|---|---|
| A1 | `Dockerfile` | caminho, ou "não existe" | mover | de onde para `{SolutionDir}` |

## 3. Propriedades gerenciadas por projeto
Uma linha por projeto e propriedade (`Nullable`, `ImplicitUsings`, `PublishAot`,
`SatelliteResourceLanguages`) que será removida, ajustada ou mantida.

| Id | Projeto | Propriedade | Valor hoje | Valor no `Directory.Build.props` | Ação | Detalhe |
|---|---|---|---|---|---|---|
| P1 | `Domain` | `PublishAot` | `true` | `false` | remover | valor diferente do global |

## 4. Nullable e ImplicitUsings (cálculo)
| Propriedade | Valor efetivo por projeto (diretiva, ou herdado do `Directory.Build.props` existente, ou `disable`) | Situação (todos `disable`, todos `enable`, misto) | Valor no `Directory.Build.props` | Projetos que ficam com `disable` explícito |
|---|---|---|---|---|

## 5. RootNamespace
| Id | Projeto | Valor hoje | Valor calculado | Arquivos `.cs` que sustentam o valor | Ação |
|---|---|---|---|---|---|

## 6. Bloqueios e alertas
Tudo que faria a skill parar ou que o usuário precisa saber: propriedade condicional, valor fora
de `enable`/`disable`, `Directory.Build.props` em outro diretório, arquivo de raiz duplicado,
`PublishAot` ou `SatelliteResourceLanguages` com valor diferente do global, `RootNamespace`
divergente.

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
| Arquivo | Ação | Caminho final |
|---|---|---|

## F3. Projetos editados
| Projeto | Propriedades removidas (com valor anterior) | Diretivas mantidas ou acrescentadas | RootNamespace |
|---|---|---|---|

## F4. Harness
| Verificação | Resultado | Observação |
|---|---|---|

Verificações: comparação dos valores efetivos com a linha de base, `dotnet build`, `dotnet test`.
Falha de ambiente aparece como "Harness incompleto".

## F5. Fora do escopo e pendências
| Item | Situação |
|---|---|
| `TargetFramework` e `LangVersion` | não alterados |
| Conteúdo do `Dockerfile` (`COPY` com caminho relativo, se movido) | não alterado |
| Pacotes | não alterados |
