---
name: create-mapper
description: 'Cria o mapeamento de uma feature (.NET/C#, camada Application) com Mapster via IRegister, convertendo entidade em Response de forma explícita. Use sempre que precisar mapear entidade para o DTO de saída de um use case, ou quando o usuário pedir um mapper, mapping ou conversão de entidade para response. Não use AutoMapper nem mapeie na direção contrária (Request para entidade).'
---

# Criar Mapper (.NET / Mapster IRegister)

Gera o mapeamento entidade→Response de **uma feature** conforme a `dotnet-conventions`.
Esta skill é a fábrica; a rule é o contrato. Cite os CONV pelo ID.

## O que gera
Um arquivo: `src/Application/Features/{Aggregate}/{Operation}/{Operation}Mapping.cs`,
uma classe `sealed` que implementa `IRegister` e configura o mapeamento da feature.

## Escopo (quando usar / NÃO usar)
- **Usar:** converter a entidade do agregado no `Response` **daquela** feature.
- **NÃO usar:** AutoMapper. Mapear `Request`→entidade (isso é factory de domínio). Um mapper único global.

## Contrato

### Rules enforçadas (CONV)
- **CONV-031** Mapster com `IRegister` **por feature**; mapeamento **explícito**, todo membro declarado; config falha em membro de destino não mapeado.
- **CONV-042** registro **explícito** — o `IRegister` é aplicado por construção no DI, nunca por `Scan()`.
- **CONV-064** `sealed`. **CONV-063** inglês.

### Pré-condições
Existem a entidade e o `{Operation}Response`. O `TypeAdapterConfig` compartilhado tem
`RequireDestinationMemberSource(true)` (configurado em `register-dependencies`), o que faz um
membro sem origem **quebrar** o build/teste.

### Inputs
1. **Operation** e **Aggregate** (localizam o slice e os tipos).
2. **Correspondência de membros** — como cada campo do Response sai da entidade (desempacotando VOs).
3. **RootNamespace** — resolvido por ReAct.

## Fluxo (ReAct)
1. **Resolver RootNamespace**.
2. **Ler entidade e Response** e casar os membros um a um.
3. **Detectar VOs** no caminho (ex.: `Balance.Amount`, `Balance.Currency`) — desempacotar explicitamente.
4. **Escrever** o `IRegister`.
5. **Verificar** pelo Checklist + Harness (mapear um exemplar não pode deixar membro sem origem).

## Raciocínio antes de escrever (CoT)
- Cada membro do Response tem **origem declarada**? Nenhum por convenção implícita (CONV-031).
- Há VO no caminho? Desempacote (`src.Balance.Amount`) — não mapeie o VO inteiro para primitivo.
- O mapeamento é **só desta feature**? Não reutilize um `IRegister` para vários Responses.
- A direção é entidade→Response? O inverso não existe aqui.

## Template canônico
```csharp
namespace {RootNamespace}.Application.Features.{Aggregate}.{Operation};

public sealed class {Operation}Mapping : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<{Aggregate}, {Operation}Response>()
            .Map(dest => dest.{Member}, src => src.{Path});
        // uma linha .Map por membro cuja origem não é trivial/homônima
    }
}
```

## Exemplos (few-shot ❌/✅)

❌ Sem contexto — AutoMapper com mapeamento por convenção implícita:
```csharp
public class AccountProfile : Profile                     // AutoMapper (CONV-031 exige Mapster)
{
    public AccountProfile()
        => CreateMap<Account, GetAccountByIdResponse>();   // convenção implícita, VO não tratado
}
```
✅ Com contexto — Mapster `IRegister`, membros explícitos, VO desempacotado:
```csharp
namespace Bank.Application.Features.Accounts.GetAccountById;

public sealed class GetAccountByIdMapping : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<Account, GetAccountByIdResponse>()
            .Map(dest => dest.AccountId, src => src.Id)
            .Map(dest => dest.Balance,   src => src.Balance.Amount)
            .Map(dest => dest.Currency,  src => src.Balance.Currency);
    }
}
```
Diferença: Mapster em vez de AutoMapper (CONV-031); cada membro do Response declarado, incluindo
o desempacote do VO `Money` (`Balance.Amount`/`Balance.Currency`); com
`RequireDestinationMemberSource` ligado, um membro novo sem `.Map` quebra o build.

## Anti-patterns (recusar)
- AutoMapper (`Profile`/`CreateMap`).
- Mapeamento por convenção implícita sem declarar membros.
- Um `IRegister` cobrindo vários Responses/features.
- Mapear o VO inteiro para um primitivo sem desempacotar.
- Descobrir o `IRegister` por `TypeAdapterConfig.Scan(...)` (scanning — CONV-042).
- Fazer o mapeamento no corpo do use case.

## Checklist + Harness
Checklist (CONV):
- [ ] `sealed class {Operation}Mapping : IRegister` no slice da feature (CONV-031/064).
- [ ] Um `NewConfig` entidade→Response; todo membro do Response com origem declarada (CONV-031).
- [ ] VOs desempacotados explicitamente. Sem AutoMapper, sem convenção implícita.
- [ ] Registrado por construção em `register-dependencies`, não por `Scan()` (CONV-042).
- [ ] RootNamespace do repo.

Harness (gate):
- `dotnet build` de `Application` limpo (CONV-002).
- Teste de mapeamento: mapear um exemplar e assertar todos os membros preenchidos; com
  `RequireDestinationMemberSource(true)`, membro sem origem falha (CONV-031).
