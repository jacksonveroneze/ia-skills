# Exemplo (certo/errado)

Exemplo de apoio do `SKILL.md`. Em conflito com a seção do arquivo, a seção vence. Nomes e versões
são ilustrativos. A classe "depois" é o modelo de `OpenApiExtensions`.

## Classe de extensão
Antes, `Billing.Infrastructure/Extensions/SwaggerExtensions.cs`:
```csharp
using Microsoft.OpenApi.Models;

namespace Billing.Infrastructure.Extensions;

public static class SwaggerExtensions
{
    public static IServiceCollection AddSwagger(this IServiceCollection services)
    {
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo { Title = "Billing API", Version = "v1" });
        });

        return services;
    }

    public static IApplicationBuilder UseSwagger(this IApplicationBuilder app)
    {
        app.UseSwagger();
        app.UseSwaggerUI();

        return app;
    }
}
```

Depois, `Billing.Infrastructure/Extensions/OpenApiExtensions.cs`:
```csharp
using Scalar.AspNetCore;

namespace Billing.Infrastructure.Extensions;

public static class OpenApiExtensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddOpenApiDocumentation()
        {
            services.AddOpenApi();

            return services;
        }
    }

    extension(WebApplication app)
    {
        public WebApplication UseOpenApiDocumentation()
        {
            if (app.Environment.IsDevelopment())
            {
                app.MapOpenApi();
                app.MapScalarApiReference();
            }

            return app;
        }
    }
}
```

Chamador, `Billing.Api/Program.cs`:
```csharp
builder.Services.AddSwagger();   // antes
app.UseSwagger();                // antes

builder.Services.AddOpenApiDocumentation();   // depois
app.UseOpenApiDocumentation();                // depois
```

No plano, o `SwaggerDoc` (título e versão) aparece como configuração não portada. Pacotes: sai
`Swashbuckle.AspNetCore` e entram `Microsoft.AspNetCore.OpenApi 10.0.1` e `Scalar.AspNetCore 2.17.14`
no `Billing.Infrastructure`. Com `Directory.Packages.props`, as versões ficam nele (CONV-058).

Errado — manter o arquivo `SwaggerExtensions.cs` ou a classe com o nome antigo; chamar os métodos de
`AddOpenApi` e `MapOpenApi`; deixar um chamador (ou teste) em `AddSwagger()`; mapear os endpoints
sem `IsDevelopment()`; manter a lambda do `AddSwaggerGen`; recriar o esquema Bearer num transformer.