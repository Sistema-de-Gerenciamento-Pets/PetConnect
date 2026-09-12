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

## FASE 6 — feature **Vacinas** — ✅ CONCLUÍDA

> **Sem migração de dados** — `Pets/*/vacinas` estava vazio no Firestore.

- [x] Backend módulo `vaccine`: `GET/POST/PATCH/DELETE /api/v1/pets/{petId}/vaccines` (`VaccineController`/`VaccineService`). Posse via `PetService.get` → pet/vacina de outro tutor → **404**. Lista em ordem cronológica.
- [x] Cascata: `PetService.delete` apaga as vacinas do pet. `UserService.deleteAccount` refatorado para chamar `PetService.delete` por pet (cascata única).
- [x] App `ApiVacinaRepository` (`lib/features/pet/data/`) + flag `AppConfig.useApiForVacinas` (`USE_API_VACINAS`). `brToIso`/`isoToBr` extraídos para `core/utils/br_date.dart` (compartilhados). Regra de alerta de próxima dose continua **no app**.
- [x] `vacina_list_screen`: pull-to-refresh + invalidate; `vacina_form_screen`: invalidate.
- [x] Testes: `VaccineControllerTest` (6); `flutter analyze` limpo + 23 Dart. **Verificado e2e** num pet migrado: `GET/POST/PATCH/DELETE`, ordem cronológica, 404 cross-tenant.
- [ ] Teste no device — pendente do usuário.

**Rollback:** `USE_API_VACINAS=false` (default) + `db.vaccines.drop()`.

---

## FASE 7 — feature **Consultas** — ✅ CONCLUÍDA

> **Sem migração de dados** — `Pets/*/consultas` estava vazio.

- [x] Backend módulo `appointment`: `GET/POST/PATCH /api/v1/pets/{petId}/appointments` (sem `DELETE` — cancelar/realizar = `PATCH status`, como já é a interface do app). Posse via `PetService.get`. `AppointmentStatus` com os 7 estados do schema-alvo; o app usa só `CONFIRMED`/`COMPLETED`/`CANCELLED`.
- [x] Cascata em `PetService.delete`. `GlobalExceptionHandler` ganhou handlers de 405/404 para rota/método não mapeados (gap encontrado testando o "sem DELETE").
- [x] App `ApiConsultaRepository` + flag `AppConfig.useApiForConsultas` (`USE_API_CONSULTAS`). Mapeia `HH:mm` ↔ `HH:mm:ss`, `dd/MM/yyyy` ↔ ISO, status PT ↔ enum de 7 (fallback `agendada`).
- [x] `consulta_list_screen`: pull-to-refresh + invalidate ao marcar realizada/cancelar; `consulta_form_screen`: invalidate ao salvar.
- [x] Testes: `AppointmentControllerTest` (8); `flutter analyze` limpo + 23 Dart. **Verificado e2e** num pet migrado: ordem cronológica, status default `CONFIRMED`, `PATCH` de status, edição sem status preserva o atual, 404 cross-tenant.
- [ ] Teste no device — pendente do usuário.

**Rollback:** `USE_API_CONSULTAS=false` (default) + `db.appointments.drop()`.

---

## FASE 8 — feature **Histórico Médico** — ✅ CONCLUÍDA

> **Sem migração de dados** — `Pets/*/historicoMedico` estava vazio.

- [x] Backend módulo `medicalrecord`: `GET/POST/PATCH/DELETE /api/v1/pets/{petId}/medical-records`. `origin` (enum `TUTOR`/`CLINIC`/`VETERINARIAN`/`IMPORT`, default `TUTOR`).
- [x] Upload de anexo: continua unsigned direto do app pro Cloudinary (upload assinado fica pra FASE 10); a API só guarda as URLs.
- [x] `ApiHistoricoMedicoRepository` + flag `USE_API_HISTORICO`. **`novoId` foi mantido** (ao contrário do que a versão anterior deste plano cogitava) — o app continua gerando o id **antes** de existir o registro (os anexos sobem pro Cloudinary usando esse id no path); agora é um id local (16 bytes aleatórios em hex, sem rede) enviado no `POST`, e o backend o usa como `_id` do Mongo quando presente (id duplicado → 409; `PATCH` ignora o campo `id` do corpo, usa o da URL).
- [x] Cascata em `PetService.delete`.
- [x] Testes: `MedicalRecordControllerTest` (9); `flutter analyze` limpo + 23 Dart. **Verificado e2e**: `POST` com id pré-gerado persiste com esse id, duplicata → 409, `PATCH` preserva o id, `DELETE`, 404 cross-tenant.
- [ ] Teste no device — pendente do usuário.

**Rollback:** `USE_API_HISTORICO=false` (default) + `db.medical_records.drop()`.

---

## FASE 9 — **QR Code** + página pública (RF17–RF19) — ✅ FECHADA (2026-09-11)

Infraestrutura real no ar: MongoDB Atlas (M0), API no Render, página no Firebase Hosting — decisões e passo a passo em `docs/next-stage/02-infrastructure-decision.md`.

- [x] `GET /api/v1/public/pets/{publicId}` — **sem autenticação**, DTO mínimo (`name`, `species`, `status`, `photoUrl`, `publicContactPhone`) — nunca `tutorId`/e-mail. Pet `ARCHIVED` ou `publicId` inexistente → 404.
- [x] `POST /api/v1/public/pets/{publicId}/sightings` — relato anônimo (RF31), sem autenticação, grava `locations` com `source="PUBLIC_QR"`. Rate limiting adicionado na FASE 11 (10 escritas/min por IP).
- [x] `GET/POST /api/v1/pets/{petId}/locations` (autenticado, RF32) — tutor vê o histórico completo (migrado + novo) e pode registrar avistamento manual com data passada.
- [x] `SecurityConfig`/`FirebaseTokenAuthenticationFilter`: `/api/v1/public/**` liberado e nunca tenta validar token (um Bearer inválido não pode bloquear rota pública).
- [x] Testes: `PublicPetControllerTest` (6), `LocationControllerTest` (5). **Verificado e2e sem nenhum token**: resumo público, 404 em id inexistente/arquivado, relato anônimo grava com `source=PUBLIC_QR`, tutor vê os avistamentos migrados + novos, cross-tenant → 404.
- [x] **Página web pública** (`PetConnect/public/index.html`, estática, sem build) em `https://pet-connect-c53f1.web.app/pet/{publicId}` — bate exatamente com `publicPetUrl()` do app. Deploy via `firebase deploy --only hosting`.
- [x] `publicPetUrl(pet)` já usava `pet.qrCodeId` (= `publicId` da API quando `USE_API_PETS`/`USE_API_LOCALIZACAO` ligadas) — nenhuma mudança necessária no app, só confirmado que bate.
- [x] `CORS_ALLOWED_ORIGINS` no Render inclui o domínio do Hosting — sem isso o navegador bloqueia a chamada (achado real: o primeiro teste voltou 403 genérico do Spring Security CORS, não um 404 da aplicação — diagnosticado e corrigido).
- [x] **Verificado de ponta a ponta com um pet real** (criado via API, apagado depois): página renderiza nome/espécie/status/contato corretamente; formulário de avistamento anônimo enviado **pela interface de verdade** (não só via curl) — resposta "Obrigado! O tutor foi avisado." confirmada, sem erro no console do navegador.
- [ ] QR regenerável (RF19 — trocar `publicId`) — **nunca foi implementado, nem no legado nem na API** (não é regressão desta fase; ver `docs/validation/rf01-rf32-parity.md`). Backlog, fora do escopo desta migração.
- [x] Migração: `publicId` já garantido em todos os pets desde a FASE 3.

**Rollback:** remover `/api/v1/public/**` do `SecurityConfig`; `db.locations.deleteMany({legacyImport:false})` para limpar dados de teste; `firebase hosting:disable` pra tirar a página do ar sem afetar Auth/Firestore.

---

## FASE 10 — Upload/exclusão de imagem assinados via backend — ✅ FECHADA (2026-09-12)

- [x] `POST /api/v1/uploads/signature` (assinatura — abordagem A do handoff) — backend assina com a API secret (env var `CLOUDINARY_API_SECRET`, `CloudinaryProperties`). Guardado: 503 `UPLOAD_NOT_CONFIGURED` enquanto a credencial não estiver setada (verificado — não derruba a API).
- [x] `delete` deixa de ser no-op: `DELETE /api/v1/uploads {url}` assina e chama `destroy` no Cloudinary, extraindo `resourceType`/`publicId` da própria URL (`CloudinaryUrlParser`). Idempotente (loga e engole falha).
- [x] `CloudinaryAnexoRepository` → `ApiAnexoRepository` (flag `USE_API_UPLOAD`, default off). `cloudinary_config.dart` no app mantém cloud name/preset (preset só é usado quando a flag está off).
- [ ] Exclusão de conta/pet/histórico passa a chamar `delete()` nos anexos de fato (hoje o app já tenta, mas o repositório era no-op) — **conferir que os call sites usam o `anexoRepositoryProvider` certo** quando a flag estiver ligada.
- [x] Testes: `CloudinarySignerTest` (4, vetores conferidos com Node), `CloudinaryUrlParserTest` (4), `UploadControllerTest` (7 — 5 originais + 2 de posse de upload). App: `api_anexo_repository_test.dart` (2). Suíte backend 74/74.
- [x] **Verificado parcialmente e2e**: sem token → 401; com token mas sem `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` configurados → 503 gracioso nos dois endpoints (não crasha, não vaza stack trace).
- [x] **Round-trip real contra o Cloudinary — feito e confirmado (2026-09-12)**, contra a conta de produção real (Render + credencial real do usuário): assinatura → upload de uma imagem de verdade (dentro da pasta `users/<tutorId>/`) → confirmado acessível → excluído via API → **confirmado que a URL para de responder (404) em ~15s**, não só que o Cloudinary "achava" que tinha apagado.
- [x] **Achado real no processo, corrigido**: a primeira tentativa de exclusão confirmou o `result: ok` do Cloudinary, mas a URL antiga continuava servível pela CDN (Cloudflare) por até 30 dias (`Cache-Control: immutable, max-age=2592000`) — a chamada de `destroy` não pedia `invalidate=true`. Corrigido em `CloudinaryHttpClient`, testado e confirmado que agora a invalidação de fato acontece (~15s de propagação). Risco real de privacidade que existia desde a implementação original da FASE 10, nunca detectável só com testes mockados.

**Nota de segurança residual — ✅ RESOLVIDA na etapa seguinte** (ver `docs/next-stage/05-security-review.md`): a posse do arquivo agora é garantida por uma pasta assinada por tutor (`users/<tutorId>/...`) nos parâmetros da assinatura do Cloudinary — sem precisar de tabela própria de "quem subiu o quê". `DELETE /api/v1/uploads` de um arquivo fora da pasta do tutor autenticado responde 404. Testado (`UploadControllerTest`, 2 casos novos).

**Rollback:** flag `USE_API_UPLOAD=false` (default) → volta ao `CloudinaryAnexoRepository` unsigned.

---

## FASE 11 — Endurecer segurança e Firestore Rules — ✅ FECHADA (2026-09-11)

Regras e histórico: [`../security/firestore-rules-deployed.md`](../security/firestore-rules-deployed.md) + `firestore.rules` na raiz do repo (fonte da verdade a partir de agora).

- [x] **Passo 1 (2026-09-11, deployado e verificado):** `firestore.rules` criado no repo + referenciado em `firebase.json`; catch-all, `Pets` e `Localizacoes` passaram a exigir `request.auth != null` (fechou só o acesso **sem login nenhum** — nada que já exigia auth mudou). Confirmado com o usuário: nenhum fluxo público real ainda escrevia em `Localizacoes`, então a escrita também foi fechada (não só a leitura). Verificado via REST: anônimo → 403 em `Pets`/`Localizacoes`; autenticado → 200 continua normal.
- [x] **Passo 2 (2026-09-11, deployado e verificado):** `Localizacoes` → `write: if false` de vez. Achado e corrigido durante a verificação: blocos `match` do Firestore se somam por OR (não por especificidade), então o `if false` sozinho não bloqueava nada — o catch-all ainda concedia escrita por cima. Corrigido excluindo `Localizacoes` explicitamente do catch-all via `request.path[3] != 'Localizacoes'` (uma primeira tentativa com `document.size()`, tipo `path`, gerou erro de tipo silencioso que teria derrubado a escrita de TODAS as coleções — pego no teste real antes de virar produção). Detalhe completo em [`firestore-rules-deployed.md`](../security/firestore-rules-deployed.md).
- [x] **Rate limiting nos endpoints públicos (2026-09-11):** `/api/v1/public/**` (FASE 9) — 30 leituras/min e 10 escritas/min por IP, janela deslizante em memória, 429 `RATE_LIMITED` no envelope padrão. Ver `PetConnect-API/src/main/java/com/petconnect/api/shared/web/{RateLimiter,PublicEndpointRateLimitFilter}.java` e `RateLimitProperties.java`. Testado com 4 testes dedicados + verificado ao vivo contra o container Docker (33 requisições seguidas → 30 passam, resto 429).
- [x] Revisão de segredos: nenhum `.env`/service-account/chave commitada em nenhum dos dois repos (`.gitignore` cobre `.env*`, `*serviceAccountKey*.json`; `git grep` por padrões de chave/token não achou nada nos arquivos versionados).
- [ ] **Endurecimento final — deliberadamente NÃO feito:** `allow read, write: if false` em `Usuarios`/`Pets`. Gated em uso real validado das FASES 4–10 (não só e2e) — os 18 usuários reais ainda rodam o app antigo (flags `USE_API_*` off por padrão), que lê essas coleções direto do Firestore. Fechar agora quebraria o app pra eles. Só fazer depois de uso real validado com as flags ligadas, ou na FASE 13.
- [ ] App Check / reforço de auth se aplicável — avaliar quando o endurecimento final acima for feito.

**Rollback:** `git revert` no(s) commit(s) que mudaram `firestore.rules` + `firebase deploy --only firestore:rules` de novo (o "Conteúdo anterior" de cada passo está documentado em `firestore-rules-deployed.md`). Rate limiting: reverter o commit do backend + rebuild do container — não afeta dados, só volta a não ter limite.

---

## FASE 12 — Feature **Settings** + validação total + testes — 🚧 EM ANDAMENTO

- [x] **Migrar preferências/telas de configurações (2026-09-11):** nada pendente — `ConfiguracoesScreen`/`EditarPerfilScreen` já passam 100% por `usuarioRepositoryProvider` desde a FASE 4 (flag `USE_API_USUARIO`); `grep` confirma que nenhum outro arquivo fora dos `Firebase*Repository` (mantidos de propósito até a FASE 13) importa `cloud_firestore`. Não havia preferências "soltas" (tema, notificações etc.) fora do que já foi migrado feature a feature.
- [x] **Reescrever `auth_flow_test.dart` contra emulador/mng do backend — R-11 (2026-09-11):** agora aponta pro **Firebase Auth Emulator** (não produção) + a API/Mongo reais (`USE_API_USUARIO=true`) — não toca Firestore Emulator (Java, mesmo bug de loopback do Tomcat) nem cria nada em produção. Peças validadas isoladamente: Auth Emulator sozinho funciona nesta máquina; um token emitido por ele foi aceito de ponta a ponta pela API real via curl (`GET`/`DELETE /api/v1/me`). **Não verificado rodando de fato**: `flutter test --platform=chrome` falha direto nesta máquina (mesma família do bug de loopback documentado no `handoff.md`). Tentado o contorno via container Linux (`tool/web-test/Dockerfile`) — chegou mais longe (compila, abre o Chrome, achou e corrigiu um problema real de sandbox) mas esbarrou num novo bloqueio (`setUpAll` trava 12min sem erro). Falta confirmar em CI (mais provável de funcionar que insistir no contorno local).
- [ ] Testes de integração end-to-end por feature (staging) — sem staging ainda (depende de hospedagem, item já listado nas pendências).
- [ ] Período de observação em produção com **flags ligadas** — depende do usuário rodar o app novo de verdade por um tempo; não é algo que eu possa fazer sozinho.
- [ ] Checklist de paridade funcional RF01–RF32 assinado — posso montar o checklist mapeando RF → implementação/teste, mas o "assinado" é uma decisão do usuário após uso real.

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
