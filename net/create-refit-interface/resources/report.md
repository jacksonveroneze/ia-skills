# Relatório (formato)

Apresentado ao concluir ou ao parar. Uma tabela, só o que foi feito, em uma linha por item.

| Item | Resultado |
|---|---|
| Interface | `.../Integrations/Cotacao/ICotacaoApi.cs` |
| Métodos | `GetCotacoesAsync` (`GET /cotacoes`, coleção); `GetCotacoesByIdAsync` (`GET /cotacoes/{id}`, item) |
| Models | `.../Cotacao/Models/CotacaoResponse.cs` (3 campos, todos com `JsonPropertyName`) |
| Ajustes | `preco` de `double` para `decimal` (CONV-059), se houve; senão "nenhum" |
| Harness | `dotnet build` e `dotnet format` passaram, ou o motivo ("Harness incompleto" em falha de ambiente) |

Ao parar, troque a tabela por uma linha: o que faltou e onde era esperado (dado não informado,
pacote `Refit` ausente ou arquivo já existente).
