# Plano de migração — Firestore → Spring Boot API + MongoDB

> Etapa obrigatória 04. Plano **faseado e incremental**. Firebase Auth e Cloudinary permanecem.
> Regra de ouro: a cada fase, o app continua funcionando. Firestore só é removido na **FASE 13**, quando tudo estiver validado em produção.
> Ao encontrar ambiguidade que possa causar **perda de dados** ou **quebra estrutural**, a fase para e o problema é levado ao usuário antes de prosseguir.

## Estratégia geral

1. **Repository pattern já existe** no Flutter (interfaces em `domain/`). A migração troca a *implementação* (`Firebase*Repository` → `Api*Repository`), feature por feature, atrás de um **feature flag / config de ambiente**.
2. Durante a transição, um mesmo dado pode ser lido do Firestore e escrito no Mongo (ou vice-versa) conforme a fase — nunca os dois como fonte de verdade ao mesmo tempo para a mesma feature.
3. Ordem de features (spec): **Auth → Tutor → Pets → Vacinas → Consultas → Histórico Médico → QR Code → Settings**.
4. Cada feature migrada: implementar → testar (unit + widget com fake + manual contra staging) → comparar comportamento com a versão Firestore → corrigir → documentar → só então avançar.

---

## FASE 0 — Backup e auditoria (pré-requisito, sem código de app)

**Objetivo:** ter uma cópia íntegra e um retrato dos dados antes de tocar em qualquer coisa.

- [x] **Backup dos dados** via `tools/firestore-backup/` (script Node + Admin SDK, **somente leitura, sem Blaze**). O `gcloud firestore export` foi descartado porque exige conta de faturamento. O script salva um JSON por coleção/subcoleção em `output/<timestamp>/` — essa pasta É o backup pré-migração e deve ser guardada em local seguro. **Substitui o bloqueio R-01.**
- [ ] Usuário roda o script e cola o `report.md` gerado no chat.
- [ ] Usuário cola as **Firestore Security Rules** atualmente deployadas (Console → Firestore → aba Regras). Não bloqueia FASE 0/1; **bloqueia a FASE 11** — R-02.
- [x] Relatório de qualidade de dados (etapa 50): gerado automaticamente pelo script — contagem por coleção, `dataNascimento` vazio/inválido, `dono` não-nulo / `dono != userId`, docs sem `sobrenome`/`vacinado`, valores distintos de `genero`/`especie`/`porte`, `userId` órfão, estruturas inesperadas.
- [ ] Documentos 01–04 (este conjunto) revisados e aprovados pelo usuário.

**Decisões tomadas nesta fase (lado seguro / reversível):**

| Item | Decisão | Motivo |
|---|---|---|
| `usuarioID` (B) | preservar como `legacyUsuarioId` em `users` | custo zero, evita perda de dado; descarta-se depois se o relatório confirmar que está sempre ausente/sem uso |
| `Pets.dono` (C) | **descartar** | o export confirma: `dono` é null/`""`/`==userId` em 100% dos casos, nunca aponta outro usuário |
| `Localizacoes` raiz (D) | ~~não migrar~~ → **MIGRAR** para `locations` (`source: PUBLIC_QR`) | 95 docs reais com GPS = última localização de scan do QR (exibida no mapa). Migram ~65 ligadas a pet válido; órfãs/teste são filtradas (ver abaixo) |
| Subcoleções de `Pets` | **nada a migrar** | `vacinas`/`historicoMedico`/`consultas`/`localizacoes` têm **0 documentos** no Firestore — nascem vazias no Mongo. As FASES 6–8 passam a ser só "expor a API + trocar o repositório no app" |
| Imagens no Firebase Storage | `photoUrl: null` + `migrationWarnings:["storage-image-lost"]` | ✅ confirmado: bucket **desativado** (billing `402 closed`). ~28 imagens perdidas, irrecuperáveis. Só sobrevivem URLs Cloudinary (2 usuários, 3 pets). Usuários re-enviam pelo app depois |
| Dados de teste | **filtrar na importação** (não migrar) | ✅ confirmado pelo usuário. Exclusão: 7 usuários de teste (por docId), 3 pets (2 órfãos + 1 de usuário excluído), ~30 `Localizacoes` do pet apagado `9CUlOu8…`. Lista completa em [`firestore-data-report.md`](../database/firestore-data-report.md). "Marcola" e "registro" ficam (borderline) até veto do usuário |
| Firestore Rules (E) | conhecidas e versionar como `firestore.rules` | ✅ coladas. Banco inteiro legível sem login; `Localizacoes` com escrita pública. Endurecimento faseado — ver FASE 11 e [`firestore-rules-deployed.md`](../security/firestore-rules-deployed.md) |
| Backend (F) | **repositório separado** `PetConnect-API` | não mistura toolchain Dart e Java; CI independente; Flutter não se move |
| Hospedagem (G) | **MongoDB Atlas M0** (grátis, 512 MB, sem cartão) para dev+staging; backend em host free (Render / Railway / Fly.io / Koyeb) | sem faturamento, igual à restrição do Firebase |
| Página pública QR (H) | fica na **FASE 9**, depois da migração de dados das entidades centrais | não é pré-requisito de nenhuma fase anterior |

**Rollback:** nada foi alterado.

---

## FASE 1 — Esqueleto do backend Spring (sem tocar no app) — ✅ CONCLUÍDA

Repo: **https://github.com/AleksGustavo/PetConnect-API** (privado) · pasta local `../PetConnect-API` · Spring Boot 3.4.2 / Java 21.

- [x] Projeto Spring Boot (Web, Security, Validation, Data MongoDB, Actuator, OpenAPI). **Repositório separado** `PetConnect-API` (Flutter não se moveu).
- [x] Monólito modular: `shared` (config/security/error) + módulos `user`/`pet`/`vaccine`/`appointment`/`medicalrecord`/`location`.
- [x] `application-{dev,staging,prod}.yml` + env vars. Nenhum segredo no repo (`.gitignore` bloqueia `*serviceAccountKey*`/`*firebase*adminsdk*`).
- [x] Formato de erro único `{ timestamp, status, code, message }` — `ApiError`/`GlobalExceptionHandler`, sem stack trace.
- [x] `/api/v1` como prefixo; Swagger em `/swagger-ui.html`; `GET /api/v1/ping` público.
- [x] `/actuator/health`. Teste de context load com MongoDB embarcado (flapdoodle) — verde.
- [ ] CI do backend (GitHub Actions) — pendente.
- [ ] MongoDB Atlas M0 (staging) — só na FASE 3; dev usa Mongo local/Docker.

**Rollback:** apagar o repo backend. App intacto.

---

## FASE 2 — Autenticação e autorização (backend) — ✅ CONCLUÍDA

- [x] Firebase Admin SDK (`FirebaseConfig`/`FirebaseProperties`) — credencial via `FIREBASE_SERVICE_ACCOUNT` (caminho ou base64), nunca no repo. Sem credencial: sobe e responde 401 nas rotas protegidas.
- [x] `FirebaseTokenAuthenticationFilter`: `Authorization: Bearer <Firebase ID Token>` → `verifyIdToken` → provisiona/carrega `users` no Mongo (1º acesso) → `SecurityContext` com principal `AuthenticatedUser` (`firebaseUid` + `roles`). 401 no formato `ApiError`.
- [x] `GET /api/v1/me` + `PATCH /api/v1/me` (DTOs + Bean Validation). Documento `users` com `firebaseUid` único, `roles`, timestamps, `legacyUsuarioId`.
- [x] Regra reforçada: controller usa sempre o `firebaseUid` do token, nunca id vindo do corpo.
- [x] `MeControllerTest` (6): sem token/inválido → 401; 1º acesso provisiona; acessos repetidos não duplicam; `PATCH` atualiza; payload inválido → 400. `FirebaseTokenVerifier` mockado (não precisa de credencial real no CI).
- [x] **Teste end-to-end com ID token real do Firebase** (chave de serviço dedicada): `GET /me` sem token → 401 · com token → 200 e provisiona · 2ª vez → mesmo id · `PATCH` → 200 · token inválido → 401.
- [x] Ajuste de infra: `firebase-admin` abre um NIO `Selector` na init → falha nesta máquina (bloqueio de loopback AF_UNIX, mesma raiz do erro do APK). Corrigido com `NetHttpTransport`. O **Tomcat** também bate nisso → a API roda em **container Linux** (`docker compose`, host **8090**), não via `mvn spring-boot:run`.

**Rollback:** app ainda não chama o backend; desligar o serviço.

---

## FASE 3 — Migração de dados: `users` + `pets` + `locations` — ✅ CONCLUÍDA (rodada real)

Motor: `com.petconnect.api.migration` no `PetConnect-API` (`LegacyMigrationService` + `MigrationRunner` no perfil `migration`). Regras de conversão: [`firestore-data-report.md`](../database/firestore-data-report.md).

**Resultado da execução real (2026-09-10) contra `firestore_backup.json`:**

| Coleção | Total Firestore | Migrados | Excluídos | Com aviso |
|---|---|---|---|---|
| `users` | 18 | **11** | 7 (contas de teste) | 8 |
| `pets` | 24 | **21** | 3 (`98fXt7…` dono teste, `SYOrB00…` e `rkgJ9H…` órfãos) | 12 |
| `locations` | 95 | **64** | 31 (30 do pet apagado `9CUlOu8…` + 1 coordenada na Irlanda) | 0 |

Avisos: `storage-image-lost` ×18 · `weight-unparseable` ×1 · `species-unmapped` ×1 · `size-unmapped` ×1 · `name-looks-like-email` ×1 · `placeholder-image` ×1.
Verificado no Mongo: 0 pets sem `tutorId`, 0 locations sem `petId`, 2 usuários com foto (só as do Cloudinary sobreviveram). `migration_audit`: 96 MIGRATED + 41 SKIPPED.

- [x] Runner lê `firestore_backup.json` (caminho por parâmetro, **não** versionado) e grava `users`/`pets`/`locations`.
- [x] users: normaliza `foto`/`imagemUrl`/`photoURL`, `usuarioID`/`uid`→`legacyUsuarioId`, `genero`→enum, datas inválidas→`null`+aviso, `roles=["TUTOR"]`.
- [x] pets: `tutorId` via `userId`/`userID`; `peso` heterogêneo→`weightKg`; `especie`/`porte`→enum (lixo→`OTHER`/`null`+aviso); datas dd/MM/yyyy·ISO·inválida; `publicId` **determinístico** (`UUID.nameUUIDFromBytes`); `status="ACTIVE"`; descarta `dono`/`id`/`datadenascimento`.
- [x] locations: `timestamp`→`reportedAt`, `latitude`/`longitude`, `telefone`→`reporterContact`, `nomePet`/`nomeTutor`→`legacy*`, `source="PUBLIC_QR"`.
- [x] Storage: toda URL `firebasestorage…` → `photoUrl: null` + `storage-image-lost`.
- [x] Filtro de teste aplicado (7 usuários + 3 pets + 31 locations), lista registrada no relatório.
- [x] `legacyImport: true` + `migrationWarnings[]` em todo doc; `migration_audit` por registro com snapshot cru.
- [x] Idempotente: cada execução limpa `legacyImport=true` + auditoria e reprocessa.
- [x] Relatório JSON salvo ao lado do export + resumo no log.
- [x] Testes: `LegacyMigrationServiceTest` (6) com export sintético cobrindo cada regra.
- [ ] Validação cruzada amostral manual `firestore_backup.json` ↔ Mongo — pendente (conferir alguns registros a olho).

**Rollback:** `db.users.drop()` / `db.pets.drop()` / `db.locations.drop()` (ou remover só `{legacyImport:true}`). Firestore permanece fonte de verdade. Sem impacto no app.

---

## FASE 4 — Feature **Tutor** no app via API — ✅ CONCLUÍDA

- [x] `ApiUsuarioRepository implements UsuarioRepository` (`lib/features/usuario/data/`) usando `ApiClient` (`lib/core/network/`) — prefixo `/api/v1`, `Authorization: Bearer <Firebase ID Token>`, envelope de erro → `ApiException`.
- [x] `GET /me` · `PATCH /me` · `DELETE /me` no backend. `DELETE`: cascata de pets + localizações, soft-delete de `users` (`deletedAt`), remoção do usuário no Firebase Auth via Admin SDK. `resolve()` recusa (401) conta já excluída mesmo com token válido.
- [x] Feature flag `AppConfig.useApiForUsuario` (`--dart-define=USE_API_USUARIO=true`, default **off**). `usuarioRepositoryProvider` alterna Api ↔ Firebase.
- [x] `signIn/signUp/sendPasswordReset/signOut` continuam no Firebase Auth. No `signUp`: cria no Auth → `GET /me` (provisiona no Mongo) → `PATCH /me` com nome/telefone.
- [x] Mapeamento `dd/MM/yyyy` ↔ ISO `yyyy-MM-dd`; `genero` Homem/Mulher/Outro ↔ `MALE/FEMALE/OTHER`.
- [x] `editar_perfil_screen` invalida `currentUsuarioProvider` após salvar (fonte via API é emissão única).
- [x] Testes: `test/core/api_client_test.dart` (6) + backend `MeControllerTest` (7). `flutter analyze` limpo, suíte de pets ok.
- [x] **Verificado end-to-end** (token real do Firebase): `GET` provisiona, `PATCH` atualiza, `DELETE` faz cascata (0 pets / 0 locations / user soft-deleted) + remove do Auth, `GET` seguinte → 401. Dados migrados intactos (11/21/64).
- [ ] Teste no device com a flag ligada apontando para a API (ver `handoff.md`) — pendente do usuário.

**Rollback:** flag `USE_API_USUARIO=false` (default) → volta ao `FirebaseUsuarioRepository`.

---

## FASE 5 — Feature **Pets** no app via API — ✅ CONCLUÍDA

- [x] `GET/POST/PATCH/DELETE /api/v1/pets` + `GET /api/v1/pets/{id}` (`pet/web/PetController` + `pet/application/PetService`). Lista escopada ao tutor do token; pet de outro tutor → **404** (não vaza existência). `DELETE` faz cascata de `locations`.
- [x] `ApiPetRepository` (`lib/features/pet/data/`): `watch*` = emissão única; mapeia `peso "12kg"` ↔ `weightKg` number, `dd/MM/yyyy` ↔ ISO, `especie`/`genero`/`porte` texto ↔ enums; `qrCodeId` ← `publicId` da API.
- [x] `status` do pet exposto no DTO (aceito em `POST`/`PATCH`; default `ACTIVE`). UI do app ainda não tem seletor — decidir se entra no `pet_form`.
- [x] Feature flag `AppConfig.useApiForPets` (`--dart-define=USE_API_PETS=true`, default off). Home: **pull-to-refresh**. `pet_form`/`pet_detail` invalidam `petsProvider`/`petProvider(id)` após mutação.
- [x] Testes: backend `PetControllerTest` (7); app `flutter analyze` limpo + 23 testes Dart. **Verificado e2e:** `GET /pets` do tutor migrado → 3 pets (Felícia/Maevis/Nymeria); `POST/GET/PATCH/DELETE` ok com cascata; migrados intactos; cross-tenant → 404.
- [ ] Teste no device com a flag — pendente do usuário.

**Rollback:** `USE_API_PETS=false` (default).

---

## FASE 6 — feature **Vacinas**

> **Sem migração de dados** — `Pets/*/vacinas` está vazio no Firestore. Só API + troca de repositório no app.

- [ ] `GET/POST/PATCH/DELETE /api/v1/pets/{petId}/vaccines`.
- [ ] `ApiVacinaRepository` + flag `useApiForVacinas`. Alerta de próxima dose: manter regra no app (ou expor `alertStatus` no DTO).
- [ ] Testar; comparar; corrigir.

**Rollback:** flag off + `db.vaccines.drop()`.

---

## FASE 7 — feature **Consultas**

> **Sem migração de dados** — `Pets/*/consultas` está vazio. Só API + troca de repositório.

- [ ] `GET/POST/PATCH /api/v1/pets/{petId}/appointments` (cancelar/realizar = `PATCH status`).
- [ ] `ApiConsultaRepository` + flag. Enum do app pode continuar com 3 estados; DTO aceita o enum de 7 mas migração só usa 3.
- [ ] Testar; comparar; corrigir.

**Rollback:** flag off + drop.

---

## FASE 8 — feature **Histórico Médico**

> **Sem migração de dados** — `Pets/*/historicoMedico` está vazio. Só API + troca de repositório.

- [ ] `GET/POST/PATCH/DELETE /api/v1/pets/{petId}/medical-records`.
- [ ] Upload de anexo: **por enquanto continua unsigned direto do app pro Cloudinary**; a API só guarda a URL. (Upload assinado = FASE 10.)
- [ ] `ApiHistoricoMedicoRepository` + flag. `novoId` do client deixa de ser necessário (id vem da API na criação; anexos podem subir e a URL ser enviada no POST).
- [ ] Testar; comparar; corrigir.

**Rollback:** flag off + drop.

---

## FASE 9 — **QR Code** + página pública (RF17–RF19)

- [ ] `GET /api/v1/public/pets/{publicId}` — endpoint **sem autenticação**, retorna DTO mínimo (nome, foto, espécie, `status`, telefone de contato público) — nada sensível.
- [ ] `POST /api/v1/public/pets/{publicId}/sightings` — relato anônimo de avistamento (RF31), rate-limited, grava `locations` com `source="PUBLIC_QR"`.
- [ ] Página web pública (Spring MVC/Thymeleaf ou app estático) em `https://<dominio>/p/{publicId}`.
- [ ] Flutter: `publicPetUrl(pet)` passa a usar `pet.publicId` e o domínio real; QR regenerável (RF19) troca `publicId`.
- [ ] Migração: garantir `publicId` em todos os pets (feito na FASE 3).

**Rollback:** remover rotas públicas; QR volta a apontar para URL antiga (que já não funcionava).

---

## FASE 10 — Upload/exclusão de imagem assinados via backend

- [ ] `POST /api/v1/uploads/signature` (ou proxy `POST /api/v1/uploads`) — backend assina requisição Cloudinary com API secret (env var).
- [ ] `delete` deixa de ser no-op: `DELETE` via backend remove do Cloudinary.
- [ ] `CloudinaryAnexoRepository` → `ApiAnexoRepository`. `cloudinary_config.dart` deixa de conter preset no app (fica só no backend).
- [ ] Exclusão de conta/pet/histórico passa a limpar imagens órfãs.

**Rollback:** manter `CloudinaryAnexoRepository` unsigned enquanto o endpoint novo não estabiliza.

---

## FASE 11 — Endurecer segurança e Firestore Rules

Regras deployadas hoje e análise: [`../security/firestore-rules-deployed.md`](../security/firestore-rules-deployed.md).
Situação atual: **banco inteiro legível sem login** (catch-all `allow read`), `Localizacoes` com **escrita pública**.

- [ ] **Cedo (após FASE 3, baixo risco):** criar `firestore.rules` no repo + referenciar em `firebase.json`; trocar catch-all `allow read;` → `allow read: if request.auth != null;` (corta leitura anônima de PII). Testar o app antigo.
- [ ] **Assim que a nova gravação de avistamento estiver na API:** `Localizacoes` → `write: if false`.
- [ ] **FASE 11 propriamente (após FASES 3–5 validadas):** `allow read, write: if false` nas coleções já migradas; manter só o mínimo para o app antigo até a FASE 13.
- [ ] Rate limiting, CORS, headers de segurança no backend.
- [ ] Revisão: nenhum segredo no repo (app ou backend); `git log` limpo de credenciais novas.
- [ ] App Check / reforço de auth se aplicável.

**Rollback:** reverter `firestore.rules` para o conteúdo registrado em `firestore-rules-deployed.md`.

---

## FASE 12 — Feature **Settings** + validação total + testes

- [ ] Migrar quaisquer preferências restantes; revisar todas as telas de configurações contra a API.
- [ ] Reescrever `auth_flow_test.dart` contra emulador/mng do backend (R-11).
- [ ] Testes de integração end-to-end por feature (staging).
- [ ] Período de observação em produção com **flags ligadas** e Firestore ainda presente como rede de segurança (somente leitura).
- [ ] Checklist de paridade funcional RF01–RF32 assinado.

**Rollback:** flags desligam feature a feature.

---

## FASE 13 — Remover Firestore (só quando seguro)

- [ ] Confirmado: 100% das features rodando via API em produção por período acordado, sem regressão.
- [ ] Export final do Firestore arquivado.
- [ ] Remover `cloud_firestore` do `pubspec.yaml`; apagar `firebase_*_repository.dart` e `firestoreProvider`.
- [ ] Remover flags de migração (código passa a usar só `Api*Repository`).
- [ ] `firebase_auth` **permanece**.
- [ ] Desativar/limpar coleções do Firestore (após janela de retenção).
- [ ] Atualizar toda a documentação (`docs/architecture/*`, README).

**Rollback:** só via restore do export arquivado + reverter o commit de remoção. A partir daqui o rollback é caro — por isso a fase só ocorre com aprovação explícita.

---

## Mapa flag → feature

| Flag (`--dart-define` / config) | Feature | Fase |
|---|---|---|
| `useApiForUsuario` | Tutor/perfil | 4 |
| `useApiForPets` | Pets | 5 |
| `useApiForVacinas` | Vacinas | 6 |
| `useApiForConsultas` | Consultas | 7 |
| `useApiForHistorico` | Histórico médico | 8 |
| `useApiForQr` | Página pública QR | 9 |
| `useApiForAnexos` | Upload de imagem | 10 |

Todas default `false` até a respectiva fase ser validada. Remoção das flags: FASE 13.

---

## Pontos que PARAM a migração — situação

| Ref | Assunto | Situação |
|---|---|---|
| A | Dados reais do Firestore | ✅ export real recebido (`firestore_backup.json`) e analisado em [`firestore-data-report.md`](../database/firestore-data-report.md) |
| B | `usuarioID` | ✅ decidido: preservar como `legacyUsuarioId` |
| C | `Pets.dono` | ✅ decidido: **descartar** (nunca aponta outro usuário) |
| D | `Localizacoes` raiz | ✅ decidido: **migrar** ~65 válidas (`source: PUBLIC_QR`); teste/órfãs filtradas |
| E | Firestore Rules deployadas | ✅ conhecidas e analisadas; endurecimento faseado (FASE 11) |
| — | Imagens Firebase Storage | ✅ perdidas (bucket desativado) → `photoUrl: null` |
| — | Dados de teste | ✅ filtrados na importação (lista fechada; Marcola/"registro" borderline) |
| F | Backend: repo vs subpasta | ✅ decidido: repositório separado `PetConnect-API` |
| G | Hospedagem MongoDB + backend | ✅ decidido: Atlas M0 grátis + host free (Render/Railway/Fly/Koyeb) |
| H | Página pública do QR (RF17–19) | ✅ decidido: permanece na FASE 9 |
