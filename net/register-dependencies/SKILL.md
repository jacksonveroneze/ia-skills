---
name: register-dependencies
description: 'Registra as dependências de uma feature na injeção de dependência (.NET/C#) de forma explícita — use cases, repositórios, config do Mapster e mapeamentos — nas extensions AddApplication e AddInfrastructure. Use sempre que um novo artefato precisar ser ligado no container, ou quando o usuário pedir para registrar serviços, wire de DI ou configurar a injeção. Nunca use assembly scanning.'
---

# Registrar Dependências (.NET / DI explícita)

Liga os artefatos de uma feature no container, de forma **explícita**, conforme a
`dotnet-conventions`. Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Edita (ou cria) as extensions de composição:
- `src/Application/DependencyInjection.cs` → `AddApplication`
- `src/Infrastructure/DependencyInjection.cs` → `AddInfrastructure`
E garante que `Program.cs` chama ambas.

## Escopo (quando usar / NÃO usar)
- **Usar:** registrar um artefato novo (use case, repositório, mapeamento, validator, provider).
- **NÃO usar:** criar o artefato em si (é a skill dele). Registrar por scanning (proibido).

## Contrato

### Rules enforçadas (CONV)
- **CONV-041** uma extension `Add{Layer}()` por projeto; `Program` compõe.
- **CONV-042** **proibido** assembly scanning — sem Scrutor, sem reflection, sem `TypeAdapterConfig.Scan()`. Todo registro explícito.
- **CONV-043** lifetime default: `Scoped` para use cases, repositórios, `DbContext`; `Singleton` para config sem estado (`TypeAdapterConfig`).
- **CONV-031** o `IRegister` de cada feature é aplicado **por construção** ao `TypeAdapterConfig`, com `RequireDestinationMemberSource(true)`.
- **CONV-060** `TimeProvider` registrado (Singleton). **CONV-063** inglês.

### Pré-condições
Os artefatos a registrar já existem. O `DbContext` existe na Infra (bootstrap). A connection
string vem de configuração (CONV-055), nunca hardcoded.

### Inputs
1. **Artefatos novos** — que use cases, repositórios, mapeamentos e validators registrar.
2. **Camada** — Application ou Infrastructure (ou ambas).
3. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Ler as extensions existentes**: se `Add{Layer}` já existe, **adicione as linhas**, não recrie.
3. **Casar cada artefato ao lifetime** correto (CoT).
4. **Aplicar cada `IRegister`** por construção ao `TypeAdapterConfig` (sem `Scan`).
5. **Conferir** `Program.cs` chama `AddApplication`/`AddInfrastructure`.
6. **Verificar** pelo Checklist + Harness.

## Raciocínio antes de escrever (CoT)
- Cada serviço tem uma **linha explícita**? Se pensou em `Scan`, pare — é proibido (CONV-042).
- Qual o **lifetime**? Use case/repositório/`DbContext` → `Scoped`; `TypeAdapterConfig`/`IMapper` → `Singleton`/config (CONV-043).
- O `IRegister` da feature foi **aplicado por construção** ao config? E `RequireDestinationMemberSource(true)` está ligado (CONV-031)?
- O registro está na **extension da camada**, não solto no `Program` (CONV-041)?

## Template canônico
```csharp
// Application/DependencyInjection.cs
namespace {RootNamespace}.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<{Operation}UseCase>();               // um por use case (CONV-043)

        var config = new TypeAdapterConfig();
        config.Default.RequireDestinationMemberSource(true);    // membro sem origem quebra (CONV-031)
        new {Operation}Mapping().Register(config);              // explícito, sem Scan (CONV-042)
        services.AddSingleton(config);
        services.AddScoped<IMapper>(sp => new Mapper(sp.GetRequiredService<TypeAdapterConfig>()));

        return services;
    }
}
```
```csharp
// Infrastructure/DependencyInjection.cs
namespace {RootNamespace}.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(o =>
            o.UseNpgsql(configuration.GetConnectionString("Bank")));
        services.AddScoped<I{Aggregate}Repository, {Aggregate}Repository>();  // explícito (CONV-042/043)
        services.AddSingleton(TimeProvider.System);                          // CONV-060
        return services;
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — assembly scanning (Scrutor + Mapster Scan):
```csharp
services.Scan(s => s.FromAssemblyOf<GetAccountByIdUseCase>()      // scanning proibido (CONV-042)
    .AddClasses().AsSelf().WithScopedLifetime());
TypeAdapterConfig.GlobalSettings.Scan(typeof(GetAccountByIdMapping).Assembly);  // scan (CONV-042)
services.AddScoped<IAccountRepository, AccountRepository>();
```
✅ Com contexto — tudo explícito, config por construção:
```csharp
services.AddScoped<GetAccountByIdUseCase>();

var config = new TypeAdapterConfig();
config.Default.RequireDestinationMemberSource(true);
new GetAccountByIdMapping().Register(config);
services.AddSingleton(config);
services.AddScoped<IMapper>(sp => new Mapper(sp.GetRequiredService<TypeAdapterConfig>()));

services.AddScoped<IAccountRepository, AccountRepository>();
services.AddSingleton(TimeProvider.System);
```
Diferença: cada serviço numa linha explícita, sem `Scan()`/Scrutor (CONV-042); lifetimes por
CONV-043; o `IRegister` aplicado por construção com `RequireDestinationMemberSource` (CONV-031);
`TimeProvider` como Singleton (CONV-060).

## Anti-patterns (recusar)
- `services.Scan(...)` (Scrutor) ou qualquer registro por reflection.
- `TypeAdapterConfig.GlobalSettings.Scan(...)` para achar `IRegister`.
- Registrar serviços soltos no `Program` em vez da extension da camada.
- Lifetime errado (ex.: `Singleton` para use case/repositório com estado por request).
- Connection string hardcoded no código (CONV-055).

## Checklist + Harness
Checklist (CONV):
- [ ] Registro na extension `Add{Layer}()`; `Program` chama ambas (CONV-041).
- [ ] Zero scanning/reflection; cada serviço numa linha explícita (CONV-042).
- [ ] Lifetimes corretos: use case/repo/`DbContext` `Scoped`; config `Singleton` (CONV-043).
- [ ] `IRegister` aplicado por construção; `RequireDestinationMemberSource(true)` ligado (CONV-031).
- [ ] `TimeProvider` registrado (CONV-060). Connection string via configuração (CONV-055).

Harness (gate):
- `dotnet build` limpo (CONV-002).
- App sobe com validação de container (`ValidateOnBuild`/`ValidateScopes`) sem dependência faltante.
- `BannedSymbols.txt` proíbe a API de scanning (Scrutor/`Scan`) — build falha se aparecer (§16/CONV-042).
