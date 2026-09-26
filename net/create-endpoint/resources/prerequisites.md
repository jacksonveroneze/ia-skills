# Pré-requisitos comuns dos endpoints (verificar; se não existir, criar)

Executar **antes** de qualquer padrão de endpoint (`get-by-id.md`, `get-paged.md` e os próximos).
Independe da operação: serve para todo endpoint da Api.

## Procedimento
1. Resolver `{ApiRootNamespace}` (passo 2 do Fluxo do `SKILL.md`).
2. Para cada tipo abaixo, procurar **pelo nome** na Api (ex.: Grep `static class ResultTranslator`), não pelo caminho.
   - **Existe** → não criar, editar nem duplicar; usar o namespace onde já está. Divergência que importa (assinatura, membros, tipo de retorno) → pare e reporte, não sobrescreva. Modificadores e formatação **não** são divergência.
   - **Não existe** → criar **somente** o que está marcado "criar" (Bloco A e B). Os do Bloco A.2 nunca se criam: faltando um, pare e reporte.
   - Um tipo por arquivo (CONV-012), namespace espelhando a pasta (CONV-013).
3. Ordem: A.2 (verificar), A, B. Ao terminar, informar o que foi criado e o que foi reaproveitado.

## Bloco A.2 — helpers que já devem existir na Api (só verificar)
| Tipo | Uso | Faltando |
|---|---|---|
| `RouteGroupBuilderFactory.Factory(app, resource, version)` → `RouteGroupBuilder` | cria o grupo `/{resource}` versionado | pare e reporte |
| `RouteNames` (constantes de nome de rota) | `WithName` e Location do Created | ver `get-by-id.md` (só ele acrescenta constante) |
| `AuthorizationPolicies.{AggregateFolder}Read` | `RequireAuthorization` | pare e pergunte (a policy também precisa estar registrada; não invente) |
| `AddDefaultResponseEndpoints(this RouteHandlerBuilder)` | respostas padrão (400/401/403/404/500) | pare e reporte |
| `LocationBuilder.ForNamedRoute(linkGenerator, context, routeName, id)` | usado pelo `ResultTranslator` | pare e reporte (o Bloco A não compila sem ele) |

## Bloco A — comum a todos os endpoints (Api, uma vez por solution)
```csharp
// Endpoints/Extensions/ResultTranslator.cs
// usings: Microsoft.AspNetCore.Mvc (ProblemDetails), namespace da lib Result e do LocationBuilder — resolver, ou global using
namespace {ApiRootNamespace}.Endpoints.Extensions;

internal static class ResultTranslator
{
    public static IResult ToIResult(this Result.Result result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return result.IsSuccess
            ? Results.NoContent()
            : CreateProblemDetailsResult(result);
    }

    extension<T>(Result<T> result)
    {
        public IResult ToIResult()
        {
            ArgumentNullException.ThrowIfNull(result);

            if (!result.IsSuccess)
            {
                return CreateProblemDetailsResult(result);
            }

            return result.Value is null
                ? Results.NoContent()
                : Results.Ok((object?)result.Value);
        }

        private IResult ToCreatedResult(Uri? locationUri = null)
        {
            ArgumentNullException.ThrowIfNull(result);

            if (result.IsFailure)
            {
                return CreateProblemDetailsResult(result);
            }

            return locationUri is not null
                ? Results.Created(locationUri, (object?)result.Value)
                : Results.StatusCode(StatusCodes.Status201Created);
        }

        public IResult ToCreatedResultFromRoute(LinkGenerator linkGenerator,
            HttpContext context,
            string routeName,
            object id)
        {
            ArgumentNullException.ThrowIfNull(result);

            if (!result.IsSuccess)
            {
                return result.ToCreatedResult();
            }

            Uri uri = LocationBuilder.ForNamedRoute(
                linkGenerator, context, routeName, id);

            return result.ToCreatedResult(uri);
        }
    }

    private static IResult CreateProblemDetailsResult(Result.Result result)
    {
        int statusCode = MapStatusCode(result.Type);

        ProblemDetails problem = new()
        {
            Status = statusCode,
            Title = GetTitle(result.Type),
            Detail = "One or more validation errors occurred.",
            Extensions =
            {
                ["errors"] = result.ToDictionaryByTarget,
            },
        };

        return Results.Problem(
            title: problem.Title,
            detail: problem.Detail,
            statusCode: problem.Status,
            extensions: problem.Extensions);
    }

    private static int MapStatusCode(ResultType resultType)
    {
        return resultType switch
        {
            ResultType.Success => StatusCodes.Status200OK,
            ResultType.Invalid => StatusCodes.Status400BadRequest,
            ResultType.Conflict => StatusCodes.Status409Conflict,
            ResultType.NotFound => StatusCodes.Status404NotFound,
            ResultType.RuleViolation => StatusCodes.Status422UnprocessableEntity,
            _ => StatusCodes.Status500InternalServerError,
        };
    }

    private static string GetTitle(ResultType resultType)
    {
        return resultType switch
        {
            ResultType.Invalid => "Invalid Request",
            ResultType.Conflict => "Conflict Detected",
            ResultType.NotFound => "Resource Not Found",
            ResultType.RuleViolation => "Business Rule Violation",
            ResultType.Error => "Internal Server Error",
            _ => "Operation Failed",
        };
    }
}
```
Mapeamento resultante: `Invalid` 400, `NotFound` 404, `Conflict` 409, `RuleViolation` 422, demais 500. Um `Result` de sucesso sem valor vira 204.

## Bloco B — por feature (independe de GetById ou GetPaged)
`{resource}` = `{AggregateFolder}` em kebab-case minúsculo (`Profiles` → `profiles`).

**`RouteMappings`** — se não existe em `Endpoints/{AggregateFolder}/v1/`, criar; se existe, **só acrescentar** o `.Add{...}()` do endpoint novo à cadeia (na ordem em que forem criados), sem duplicar:
```csharp
// Endpoints/{AggregateFolder}/v1/RouteMappings.cs
namespace {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1;

internal static class RouteMappings
{
    private const string Resource = "{resource}";
    private const int Version = 1;

    public static WebApplication Add{AggregateFolder}Endpoints(
        this WebApplication app)
    {
        RouteGroupBuilder builder = RouteGroupBuilderFactory
            .Factory(app, Resource, Version);

        builder.AddGetPaged()
            .AddGetById();

        return app;
    }
}
```
**`Program.cs`** — garantir `app.Add{AggregateFolder}Endpoints();` (uma vez) junto das demais chamadas `app.Add*Endpoints();`; sem nenhuma, antes de `app.Run()`. Acrescentar `using {ApiRootNamespace}.Endpoints.{AggregateFolder}.v1;` se não houver `global using`. Nova versão da API (`v2`) → pare e pergunte.

## Anti-patterns
- Recriar `ResultTranslator`/`RouteMappings` existentes, ou sobrescrever um existente cujo formato diverge.
- Inventar um helper ausente do Bloco A.2 (ou uma policy) em vez de reportar.
- Dois `Add{AggregateFolder}Endpoints()` no `Program.cs`, ou o mesmo `.AddX()` duas vezes na cadeia.
- `Resource`/`Version` fora do `RouteMappings`; `Resource` copiado de exemplo.

## Checklist
- [ ] Todos os tipos foram procurados por nome antes de qualquer criação; só se criou o que faltava.
- [ ] Faltando helper do A.2, a skill parou e reportou (nada foi inventado).
- [ ] `RouteMappings` da feature existe, com o `.Add{...}()` do novo endpoint na cadeia (uma vez).
- [ ] `Program.cs` chama `app.Add{AggregateFolder}Endpoints()` uma única vez, com o `using` correto.
- [ ] Resumo final: criado, reaproveitado e o que foi acrescentado à cadeia.
