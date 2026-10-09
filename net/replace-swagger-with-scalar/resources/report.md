# Relatório (formato)

Uma tabela só, usada duas vezes: no plano (passo 4, antes de escrever, com `Resultado` = `planejado`)
e ao concluir ou parar (com `Resultado` preenchido). Cada linha tem um id para o usuário poder
excluí-la na aprovação.

| Id | Item | Antes | Depois | Resultado |
|---|---|---|---|---|
| 1 | Pacote | `Swashbuckle.AspNetCore 6.9.0` | removido | planejado |
| 2 | Pacote | — | `Microsoft.AspNetCore.OpenApi 10.0.1` em `Billing.Infrastructure` | planejado |
| 3 | Pacote | — | `Scalar.AspNetCore 2.17.14` em `Billing.Infrastructure` | planejado |
| 4 | Arquivo e classe | `Extensions/SwaggerExtensions.cs` | `Extensions/OpenApiExtensions.cs` | planejado |
| 5 | Método | `AddSwagger` | `AddOpenApiDocumentation` | planejado |
| 6 | Método | `UseSwagger` | `UseOpenApiDocumentation` | planejado |
| 7 | Chamador | `Billing.Api/Program.cs:9` | `AddOpenApiDocumentation()` | planejado |
| 8 | `launchUrl` | `swagger` | `scalar` | planejado |

`Resultado`: `planejado`, `feito`, `excluído pelo usuário`, `não executado` ou `parou aqui`.

Abaixo da tabela, em uma linha cada:
- **Não portado:** cada configuração da lambda do `AddSwaggerGen` (ex.: `SwaggerDoc`, esquema Bearer).
- **Alertas:** documento OpenAPI 3.1, URLs que mudam, documentação só em Development, e cada outro arquivo que cita `/swagger` (`arquivo:linha`).
- **Harness** (só no relatório final): `passou` ou o motivo da falha; "não verificado" para a abertura de `/scalar`.

No plano, termine com: "Responda `aprovo` para executar tudo, ou liste os ids a excluir." Não
execute nada enquanto não houver resposta.