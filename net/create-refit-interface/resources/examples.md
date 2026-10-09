# Exemplo (certo/errado)

Exemplo de apoio do `SKILL.md`. Em conflito com o Template canônico, o Template vence. Os namespaces
são valores resolvidos ilustrativos; use sempre os do `.csproj` do repositório.

## Pedido
- Diretório da interface: `app/src/Bank.Infrastructure/Integrations/Cotacao`
- Nome: `ICotacaoApi`
- Diretório dos models: `app/src/Bank.Infrastructure/Integrations/Cotacao/Models`
- Método 1: `GET /cotacoes?ativo=PETR4`, retorno `coleção`, contrato `CotacaoResponse: ativo:string, preco:decimal, data:DateTimeOffset`
- Método 2: `GET /cotacoes/{id}`, retorno `item`, contrato `CotacaoResponse` (campos já informados)

## Certo
`.../Cotacao/ICotacaoApi.cs`:
```csharp
using Bank.Infrastructure.Integrations.Cotacao.Models;
using Refit;

namespace Bank.Infrastructure.Integrations.Cotacao;

internal interface ICotacaoApi
{
    [Get("/cotacoes")]
    Task<IReadOnlyList<CotacaoResponse>> GetCotacoesAsync(
        string ativo,
        CancellationToken cancellationToken);

    [Get("/cotacoes/{id}")]
    Task<CotacaoResponse> GetCotacoesByIdAsync(
        string id,
        CancellationToken cancellationToken);
}
```

`.../Cotacao/Models/CotacaoResponse.cs`:
```csharp
using System.Text.Json.Serialization;

namespace Bank.Infrastructure.Integrations.Cotacao.Models;

internal sealed record CotacaoResponse
{
    [JsonPropertyName("ativo")]
    public required string Ativo { get; init; }

    [JsonPropertyName("preco")]
    public required decimal Preco { get; init; }

    [JsonPropertyName("data")]
    public required DateTimeOffset Data { get; init; }
}
```

## Pedido incompleto
"Crie a ICotacaoApi com GET /cotacoes, retornando CotacaoResponse." Faltam o diretório da interface,
o diretório dos models, item ou coleção e os campos.

Certo — a skill não escreve nada e pede só isso.
Errado — assumir `Models/`, supor que o retorno é uma lista ou inventar os campos.

## Errado
```csharp
public interface ICotacaoApi                                   // public sem necessidade (CONV-065)
{
    [Get("/cotacoes?ativo=PETR4")]                             // query fixa na rota; o valor era só exemplo
    Task<ApiResponse<List<Cotacao>>> Get(string ativo);        // sem Async, sem cancellationToken, ApiResponse
}

public class Cotacao                                           // class mutável, sem sealed (CONV-064/068)
{
    public string Ativo { get; set; }                          // sem JsonPropertyName
    public double Preco { get; set; }                          // double para dinheiro (CONV-059)
}
```
