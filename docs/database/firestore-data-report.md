# Relatório de qualidade dos dados — Firestore (FASE 0)

> Baseado no export real `firestore_backup.json` (gerado pelo usuário via Admin SDK, somente leitura, 2026-09-10).
> Projeto `pet-connect-c53f1`. Backup guardado fora do repositório em `C:\Users\Aleksander\Documents\backup-firestore\`.

## Resumo executivo

| Coleção | Documentos | Subcoleções |
|---|---|---|
| `Usuarios` | **18** | nenhuma |
| `Pets` | **24** | **nenhuma** |
| `Localizacoes` (raiz) | **95** | nenhuma |

**Descobertas que mudam o plano:**

1. **Não existe NENHUMA subcoleção no Firestore.** `Pets/{id}/vacinas`, `historicoMedico`, `consultas`, `localizacoes` — **zero documentos**. O app Feature-First atual (construído nesta série de PRs) nunca teve seus dados exercitados em produção. Os dados reais são todos de uma **versão anterior** do app.
2. **A coleção raiz `Localizacoes` é dado real e valioso** — 95 registros de avistamento com **GPS (lat/long)**, telefone, nome do pet, nome do tutor e timestamp ISO. É o histórico da funcionalidade "pet perdido" da versão antiga. A decisão anterior "não migrar" (item D) **está revista** — ver `firestore-to-spring-mongodb.md`.
3. **Schema drift severo** em `Usuarios` e `Pets`: 3–4 gerações de campos convivendo (`dataNascimento`↔`datadenascimento`, `foto`↔`imagemUrl`↔`photoURL`, `userId`↔`userID`↔`dono`, `usuarioID`↔`uid`).
4. **~28 imagens estão no Firebase Storage** (URLs `firebasestorage.googleapis.com`). Storage agora exige plano Blaze — **é preciso verificar se essas URLs ainda abrem**. Se não abrirem, essas imagens já foram perdidas, independente da migração.

---

## Usuarios (18 docs)

Doc ID = Firebase Auth UID (confirmado).

### Chaves de campo encontradas (nº de docs que têm cada uma)

`telefone` 18 · `nome` 18 · `foto` 17 · `genero` 17 · `dataNascimento` 17 · `email` 17 · `usuarioID` 16 · `sobrenome` **2** · `uid` 1 · `photoURL` 1 · `dataCadastro` 1 · `userId` 1 · `imagemUrl` 2 · `imagemUrlUsuario` 1 · `imagemUrlPet` 1

### Problemas

| Problema | Qtde | Detalhe |
|---|---|---|
| `dataNascimento` inválida | 7 | `"1/1/1"` ×5, `"13/32/321"`, `"12/12/13"` — contas de teste |
| Sem `sobrenome` | 16 | só "Mayara Rocha" (`""`) e "Aleksander" (`"Gustavo"`) têm |
| `genero` fora do padrão novo | todos | valores reais: `Homem` (9), `Mulher` (4), `Outro` (4), ausente (1). **Não** é "Masculino/Feminino" |
| Foto no Firebase Storage | 15 | URLs `firebasestorage...` — checar se ainda resolvem |
| Foto no Cloudinary | 2 | Mayara, Aleksander (contas usadas no app novo) |
| Doc "Marcola" (`VW9SSk…`) | 1 | schema mais antigo: **sem** `email`, `dataNascimento`, `genero`, `usuarioID`; tem `imagemUrl`, `imagemUrlUsuario`, `imagemUrlPet` |
| Doc "Gabrielly" (`NhN0Gm…`) | 1 | schema variante: `uid`, `photoURL: null`, `dataCadastro`; **sem** `usuarioID` nem `foto` |
| `nome` que é um e-mail | 1 | `Ks8scv…` → `nome = "esaurafael4@gmail.com"` |
| `usuarioID` == docId | 1 | "Mayara" — nos outros 15 é um UUID distinto |
| Contas claramente de teste | ~7 | "t", "tes", "pizza" (email `testepodeapagar@g.com`), "gays", "gayzao", "rgsdgsdf", "test" |

### `usuarioID`

É um UUID diferente do docId em 15 de 18 docs, **mas não é usado como chave estrangeira em lugar nenhum** dos dados (Pets referenciam `userId` = Auth UID; Localizacoes referenciam `petId` + nome do tutor como string). É um identificador morto. → migrar como `legacyUsuarioId` (custo zero), descartar depois (decisão B mantida).

---

## Pets (24 docs)

Doc ID = auto. `userId` = Firebase Auth UID do dono.

### Chaves de campo encontradas

`cor` 24 · `genero` 24 · `raca` 24 · `nome` 24 · `porte` 24 · `peso` 24 · `dataNascimento` 23 · `userId` 23 · `telefone` 20 · `dono` 20 · `especie` **14** · `datadenascimento` **8** · `qrCodeId` 7 · `foto` 7 · `vacinado` 7 · `imagemUrl` 15 · `id` 3 · `createdAt` 3 · `imageUrl` 1 · `userID` 1

### Problemas

| Problema | Qtde | Detalhe |
|---|---|---|
| `especie` ausente ou lixo | 15 | ausente (10), `""` (1), `"guff"` (1), `"gay"` (1); válidos: `Gato`/`gato` (9), `Cachorro` (3) |
| `peso` heterogêneo | 24 | strings numéricas (`"8"`, `"25"`, `"48"`), com unidade (`"4kg"`, `"10 KG"`), lixo (`"byi"`), vazio (`""` ×2), `null` (×2), **números** (`7.4`, `5`) |
| `dataNascimento` formato misto | 23 | `""` (×5), `dd/MM/yyyy` (maioria), **ISO** `"2020-08-14"`, `"2017-04-15"` (2), `null` (1) |
| Campo duplicado `datadenascimento` | 8 | mesmo valor que `dataNascimento` — resíduo de versão antiga |
| `porte` fora do padrão | 6 | `pequeno`/`medio` minúsculo (4), `"ta"`, `"gik"` (lixo) |
| Foto no Firebase Storage | 13 | URLs `firebasestorage...` |
| Foto placeholder | 1 | `placehold.co` (pet "Fred") |
| Campo `foto` (Cloudinary) | 3 | pets das contas novas |
| `userID` (D maiúsculo) + `imageUrl` | 1 | pet "teste2" — schema antigo divergente |
| Campo `id` redundante (== docId) | 3 | |
| Pets órfãos (dono sem `Usuarios`) | **2** | `SYOrB00…` "teste2" (dono `CTfqh4o…`), `rkgJ9H…` "Branca" (dono `LNBB9FA…`) |

### `dono` — confirmado redundante

Dos 20 docs com o campo: `null` em 17, `""` em 1, **igual a `userId` em 2, e nunca diferente de `userId`**. → **descartar** (nem manter como legado). Decisão C confirmada e reforçada.

---

## Localizacoes (raiz) — 95 docs

**Schema 100% uniforme** (todos os 95 docs têm exatamente estes campos):

| Campo | Tipo | Exemplo |
|---|---|---|
| `latitude` | number | `-22.1742642` |
| `longitude` | number | `-47.3938307` |
| `telefone` | string | `"19992280266"` (alguns com espaço: `"19 997744036"`) |
| `petId` | string | → `Pets` doc id |
| `nomePet` | string | `"Negão"` |
| `nomeTutor` | string | `"Alan Jones"` |
| `timestamp` | string ISO 8601 | `"2024-12-04T23:04:12.964Z"` |

### Análise

| Item | Valor |
|---|---|
| Total | 95 |
| Período | 2024-12-04 → 2025-08-14 |
| `petId` que **existe** em `Pets` | 65 registros (11 pets) |
| `petId` **órfão** (pet apagado) | **30 registros**, todos do pet `9CUlOu8nNKJa7OgHTzB2` ("Nymeria", tutor "Aleksander") — pet recriado depois com outro id |
| Coordenada claramente de teste | 1 (lat 53.27 / lng -9.05 → Galway, Irlanda; pet "Amora") |
| Pares lat/long exatamente duplicados | 13 (testes repetidos no mesmo ponto) |

Esta coleção é o **único registro histórico de uso da funcionalidade de pet perdido**. Tem GPS real — que o modelo `Localizacao` do app atual (texto livre, sem lat/long) nem captura.

---

## Firebase Storage — imagens legadas

URLs `https://firebasestorage.googleapis.com/v0/b/pet-connect-c53f1.appspot.com/...` aparecem em:

- **15 fotos de usuário** (campo `foto` ou `imagemUrl`)
- **13 fotos de pet** (campo `imagemUrl`)

O Storage passou a exigir plano Blaze. **Ação necessária do usuário:** abrir 1 ou 2 dessas URLs no navegador e dizer se a imagem carrega.

- Se **carregam** → o script de migração baixa cada uma e re-envia ao Cloudinary, gravando a nova URL.
- Se **dão erro/404** → essas imagens já se perderam; a migração grava `photoUrl: null` + aviso, e o usuário re-sobe manualmente as que quiser.

---

## Contas / registros candidatos a descarte (NÃO serão apagados sem sua ordem)

| Origem | Itens |
|---|---|
| Usuarios de teste | `t`, `tes`, `pizza`/`testepodeapagar@g.com`, `gays`, `gayzao`, `rgsdgsdf`, `test` (~7) |
| Pets órfãos/teste | `teste2` (`SYOrB00…`), `Branca` (`rkgJ9H…`); + pets `guff`/`gay`/`ghhfhh`/`jao` de contas de teste |
| Localizacoes de teste | 30 do pet apagado `9CUlOu8…`, 1 na Irlanda, 13 duplicadas |

**Recomendação:** migrar **tudo**, marcando cada doc importado com `legacyImport: true` e uma lista `migrationWarnings`. Nada é apagado. Depois da migração validada, você decide o que remover pelo app/console. Rollback trivial.

---

## O que cada problema vira na migração (sem necessidade de decisão sua)

| Origem | Regra na migração |
|---|---|
| `datadenascimento` | ignorado se `dataNascimento` existe; senão usado como fallback |
| `foto` / `imagemUrl` / `photoURL` | precedência: `foto` (Cloudinary) → `imagemUrl` → `photoURL`; Storage → re-upload (ver acima) |
| `userId` / `userID` | normalizado para `tutorId` (resolve o `users._id` a partir do Auth UID) |
| `usuarioID` / `uid` | vira `legacyUsuarioId` |
| `dono` | descartado |
| `id` (redundante em Pets) | descartado |
| `peso` string/num/unidade | extrai número; `"byi"`/vazio/null → `weightKg: null` + aviso |
| `especie` ausente/lixo | `gato→CAT`, `cachorro→DOG`, resto → `OTHER` + aviso |
| `porte` minúsculo/lixo | normaliza case; lixo → `null` + aviso |
| `genero` Homem/Mulher/Outro | `MALE`/`FEMALE`/`OTHER` (users) e `MALE`/`FEMALE`/`UNKNOWN` (pets) |
| `dataNascimento` `dd/MM/yyyy` | → `Date` |
| `dataNascimento` ISO | → `Date` (já serve) |
| `dataNascimento` inválida (`1/1/1` etc.) | → `null` + aviso |
| `createdAt` ISO (quando existe) | usado como `createdAt`; senão data da migração |
| `Localizacoes.timestamp` | → `reportedAt` (Date) |
| `Localizacoes` órfã | `petId: null` + `legacyPetId`, `legacyPetName`, `legacyTutorName` preservados |

---

## Decisões que precisam de você

1. **`Localizacoes` (item D, revisto):** migrar as 95 para `locations`? Recomendo **sim**, vinculando as 65 ao pet e mantendo as 30 órfãs com referência textual. Confirmar.
2. **Imagens do Storage:** abrir uma URL `firebasestorage…` e dizer se carrega.
3. **App novo já foi publicado?** O APK/loja que os usuários usam hoje é este código Feature-First ou a versão antiga? (Os dados dizem que é a antiga.)
4. **Dados de teste:** ok migrar tudo com `legacyImport`/`migrationWarnings` e você limpa depois? Ou já filtro as ~7 contas de teste e 2 pets órfãos na importação?
5. **Firestore Rules:** colar o conteúdo atual (Console → Firestore → aba Regras).
