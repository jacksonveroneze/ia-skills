---
name: create-refit-interface
description: 'Cria a interface Refit (.NET/C#) para chamadas HTTP a uma API externa, com um ou mais métodos, e os records dos contratos de retorno. Só segue com todos os dados informados, o diretório da interface, o nome, o diretório dos models e, por método, a rota e o retorno (item ou coleção, com os campos). Use sempre que o usuário pedir uma interface Refit, um client Refit, um cliente HTTP tipado ou a integração com uma API externa a partir de rotas, mesmo sem citar Refit. Não use para porta ou adaptador da Application, nem para registro de DI ou HttpClient.'
---

# Criar interface Refit (.NET)

Gera a interface Refit e os records de retorno conforme a `dotnet-conventions.md`. Em conflito entre
o Template canônico e os Exemplos, o Template vence.

## O que gera
- `{InterfaceDir}/I{Name}Api.cs`: a interface, com um método por rota informada.
- `{ModelDir}/{Model}.cs`: um record por contrato de retorno.

O namespace de cada arquivo é o `RootNamespace` do `.csproj` mais próximo acima da pasta mais o
caminho relativo da pasta (CONV-013). Pastas ausentes são criadas. Nada além disso: sem porta nem
adaptador, sem registro de DI ou `HttpClient` (nem base address), sem teste, sem pacote, sem o tipo
do corpo de requisição. Pré-requisito ausente: a skill para e relata o que falta e onde era esperado.

## Escopo (quando usar / NÃO usar)
- **Usar:** interface Refit com métodos GET, POST, PUT, PATCH ou DELETE para uma API externa.
- **NÃO usar:** autenticação, handler, retry; interface que já existe (a skill não acrescenta método).

## Contrato

### Rules desta skill
- **Local (dados obrigatórios):** a skill só começa com todos os dados do Inputs. Faltando ou inválido, pede só o que falta e não escreve nada; nunca infere nem usa valor de exemplo.
- **Local (nomes externos):** nome da interface, parâmetros e campos ficam como o usuário informou, mesmo em português; exceção local, o CONV-063 não a prevê.
- **Local (propriedades do record):** declaradas no corpo, sem construtor posicional, como `{ get; init; }` com `required` quando o tipo não é anulável. Toda propriedade leva `[JsonPropertyName("campo")]`, mesmo quando igual ao nome da propriedade.
- **Local (retorno):** `Task<{Model}>`, `Task<IReadOnlyList<{Model}>>` ou `Task`. Erro HTTP chega como `ApiException` e é tratado por quem chama; sem `ApiResponse<T>`, `HttpResponseMessage` nem `Result`.
- **Local (formatação):** cada parâmetro do método em sua própria linha, indentado; atributo do campo na linha acima da propriedade, com uma linha em branco entre propriedades.

### Rules gerais (dotnet-conventions.md)
- **CONV-014** `Async` no fim do nome. **CONV-044** `CancellationToken` em toda chamada. **CONV-074** chamado `cancellationToken`, sem default.
- **CONV-064** `sealed`. **CONV-065** modificador mais restritivo (`internal`). **CONV-068** `record` para dado imutável.
- **CONV-059** dinheiro é `decimal`. **CONV-071** `System.Text.Json`; `Newtonsoft.Json` é proibido.
- **CONV-011/012/013** file-scoped namespace, um tipo por arquivo, namespace espelha a pasta.
- **CONV-087** pacote novo só com confirmação; a skill não adiciona pacote.

### Pré-condições
Todos os dados informados e válidos. Há um `.csproj` acima de cada diretório e o do diretório da
interface referencia o pacote `Refit`. Nenhum dos arquivos existe.

### Inputs (todos obrigatórios)
1. **Diretório da interface** e 2. **Nome** (`ICotacaoApi`: começa com `I`, termina em `Api`; `{Name}` é o meio).
3. **Diretório dos models** — sempre informado, mesmo se igual ao da interface.
4. **Métodos** (um ou mais), cada um com:
   - **Rota** — `GET /cotacoes?ativo=PETR4`: verbo, caminho iniciado por `/`, query se houver. Corpo: `body:Ns.Tipo` (tipo existente, nome completo).
   - **Retorno** — `item`, `coleção` ou `nenhum`, e, exceto em `nenhum`, o contrato `Nome: campo:tipo, ...` (ao menos um campo). Contrato repetido em outro método: informe os campos uma vez.

Inválido: diretório fora de projeto, nome fora do padrão, verbo fora dos cinco, rota sem `/`, retorno
sem item/coleção, contrato sem nome ou campo sem tipo.

| Entrada | Vira |
|---|---|
| `GET /cotacoes` | `[Get("/cotacoes")]` e `GetCotacoesAsync` (verbo + último segmento fixo; `{id}` acrescenta `ById`) |
| `?ativo=PETR4` | parâmetro `string ativo` (valor é só exemplo; tipo explícito: `ativo:int`) |
| `{id}` no caminho | parâmetro `string id` (tipo explícito: `id:Guid`) |
| `body:Ns.Tipo` | `[Body] Ns.Tipo body`, antes do `cancellationToken` |
| `item` / `coleção` / `nenhum` | `Task<M>` / `Task<IReadOnlyList<M>>` / `Task` |
| `campo:tipo` | propriedade `Campo` com `[JsonPropertyName("campo")]` no corpo do record |

## Fluxo (ReAct)
1. **Conferir os dados.** Faltando ou inválido algum: pare e peça só o que falta, antes de qualquer outro passo.
2. **Declarar**, num bloco só, antes de escrever: diretórios, `Name=`, `Namespace=` da interface e dos models (`dotnet msbuild <csproj> -getProperty:RootNamespace`; fallback `<RootNamespace>`, `<AssemblyName>`, nome do `.csproj`; nunca o dos exemplos), cada método (nome, verbo, caminho, parâmetros, retorno) e os paths. Nome de método repetido: pare e peça outro.
3. **Checar existência** da interface e dos models; existindo, pare e relate qual. **Conferir o `Refit`** no `.csproj`; ausente: pare e relate.
4. **Checar `global using`** de `Refit`, `System.Text.Json.Serialization` e do namespace dos models (`IDE0005` é erro).
5. **Escrever** pelo Template canônico e **verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Todos os dados foram informados, sem nada inferido, inclusive item/coleção e o diretório dos models?
- Campo monetário em `double`/`float`? Use `decimal` e relate (CONV-059).

## Template canônico
Placeholders recebem os valores do passo 2; nunca copie literalmente.
```csharp
// {InterfaceDir}/I{Name}Api.cs
// using Refit;                // só se não houver global using
// using {ModelNamespace};     // só se o namespace dos models diferir e não for global

namespace {Namespace};

internal interface I{Name}Api
{
    [{Verb}("{Path}")]
    Task<{Return}> {MethodName}Async(
        {ParamType} {paramName},
        CancellationToken cancellationToken);

    // um bloco por método, separados por linha em branco
}
```
```csharp
// {ModelDir}/{Model}.cs
// using System.Text.Json.Serialization;    // só se não houver global using

namespace {ModelNamespace};

internal sealed record {Model}
{
    [JsonPropertyName("{field}")]
    public required {FieldType} {Field} { get; init; }

    [JsonPropertyName("{field}")]
    public {NullableFieldType}? {Field} { get; init; }    // tipo anulável: sem required
}
```
`{Path}` é o caminho sem a query; `{Field}` é `{field}` em PascalCase; repita o bloco por campo.

## Exemplos (certo/errado)
Leia `examples.md` antes de escrever: `ICotacaoApi` com dois métodos e um pedido incompleto.

## Anti-patterns (recusar)
- Começar sem todos os dados, inferir o que falta (diretório, item ou coleção, campos) ou usar valor de exemplo → peça só o que falta.
- Propriedade sem `JsonPropertyName`, ou record com construtor posicional → propriedades no corpo, cada uma com `[JsonPropertyName("campo")]`.
- Registrar o client, `AddRefitClient`, base address; criar o tipo do corpo → fora do escopo.
- `Newtonsoft` ou `Refit.Newtonsoft.Json` (CONV-071) → System.Text.Json.
- `CancellationToken` ausente ou com `= default` (CONV-044/074) → `cancellationToken` por último.
- `double`/`float` para dinheiro (CONV-059); `class` mutável, sem `sealed` ou `public` sem necessidade (CONV-064/065/068) → `decimal`; `internal sealed record`.
- Retornar `HttpResponseMessage`, `ApiResponse<T>` ou `Result`; sobrescrever arquivo existente; adicionar pacote (CONV-087); parâmetros na mesma linha; placeholder literal.

## Checklist + Harness

Checklist:
- [ ] Todos os dados informados antes de qualquer escrita; nada inferido.
- [ ] Arquivos nos diretórios e namespaces de "O que gera"; interface com um método por rota, nomes terminados em `Async`, `cancellationToken` por último e sem default (CONV-011/012/013/014/044/074).
- [ ] Retorno conforme item, coleção ou nenhum; `[Get]`/`[Post]`... sem a query.
- [ ] Toda propriedade no corpo do record (sem construtor posicional), com `JsonPropertyName`, `{ get; init; }` e `required` quando não anulável; `internal sealed record`; `decimal` para dinheiro; nenhum `using` duplicado, pacote, registro de DI ou placeholder.

Harness (gate — só conclui quando passam):
1. `dotnet build` do `.csproj` de cada diretório sem warning (o gerador do Refit só roda no build, então o build também prova a interface).
2. `dotnet format <csproj> --verify-no-changes` sem diferença.

Falha de ambiente/ferramenta (timeout, processo que não inicia) em vez de reprovação por conteúdo:
tente de novo uma vez e, se persistir, reporte "Harness incompleto" e pare — não declare a criação
como concluída.

Ao concluir (ou parar), apresente o relatório no formato de `report.md`.
