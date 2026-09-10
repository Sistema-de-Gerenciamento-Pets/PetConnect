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

## FASE 1 — Esqueleto do backend Spring (sem tocar no app)

- [ ] Criar projeto Spring Boot (Web, Security, Validation, Data MongoDB, Actuator, OpenAPI). Local: **repositório separado** `PetConnect-API` (recomendado) ou subpasta `backend/` — **decisão do usuário, ambiguidade F**. Não mover o Flutter.
- [ ] Estrutura Monólito Modular: módulos `user`, `pet`, `vaccine`, `appointment`, `medicalrecord`, `location`, `shared` (config, security, error).
- [ ] `application-{dev,staging,prod}.yml` + variáveis de ambiente. **Nenhum segredo no repo.**
- [ ] Formato de erro único `{ timestamp, status, code, message }` — sem stack trace pro cliente.
- [ ] `/api/v1` como prefixo; Swagger em `/swagger-ui`.
- [ ] Healthcheck (`/actuator/health`) e CI do backend.
- [ ] MongoDB provisionado (Atlas free tier dev + instância staging) — **decisão do usuário, ambiguidade G**.

**Rollback:** apagar o projeto/repo backend. App intacto.

---

## FASE 2 — Autenticação e autorização (backend)

- [ ] Firebase Admin SDK no backend (credencial via env var / Secret Manager — **nunca** no repo).
- [ ] Filtro Spring Security: `Authorization: Bearer <Firebase ID Token>` → verifica com Admin SDK → carrega/cria `users` no Mongo (provisionamento no 1º acesso) → popula `SecurityContext` com `firebaseUid` + `roles`.
- [ ] Endpoint `GET /api/v1/me` (perfil do usuário logado) — primeira rota real.
- [ ] Regra: **nunca confiar só no ID enviado pelo app** — toda operação valida posse (`tutorId == usuário logado`) no servidor.
- [ ] Testes: token válido/expirado/ausente, usuário novo, usuário existente.

**Rollback:** app ainda não chama o backend; desligar o serviço.

---

## FASE 3 — Migração de dados: `users` + `pets` + `locations` (script)

> É **toda** a carga real: 18 usuários, 24 pets, 95 avistamentos. Não há mais nada
> (subcoleções vazias). Regras de conversão campo a campo: [`firestore-data-report.md`](../database/firestore-data-report.md).

- [ ] Script de migração (Java/Spring `CommandLineRunner` ou standalone) lê `firestore_backup.json` e grava `users`, `pets`, `locations` no Mongo.
- [ ] **users:** normaliza `foto`/`imagemUrl`/`photoURL`, `usuarioID`/`uid`→`legacyUsuarioId`, `genero` Homem/Mulher/Outro→enum, datas inválidas→`null`+aviso, `roles=["TUTOR"]`.
- [ ] **pets:** resolve `tutorId` via `userId`/`userID`; `peso` heterogêneo→`weightKg`; `especie`/`porte` lixo→`OTHER`/`null`+aviso; `dataNascimento` (dd/MM/yyyy | ISO | inválida); gera `publicId`; `status="ACTIVE"`; descarta `dono`/`id`/`datadenascimento`.
- [ ] **locations:** só as ~65 ligadas a pet válido; `timestamp`→`reportedAt`; `latitude`/`longitude` direto; `telefone`→`reporterContact`; `nomePet`/`nomeTutor`→`legacyPetName`/`legacyTutorName`; `source="PUBLIC_QR"`.
- [ ] **Imagens do Storage:** toda URL `firebasestorage…` → `photoUrl: null` + `migrationWarnings:["storage-image-lost"]` (bucket desativado, irrecuperável). URLs Cloudinary passam direto.
- [ ] **Filtro de teste:** excluir da importação os 7 usuários + 3 pets + ~30 locations da lista em [`firestore-data-report.md`](../database/firestore-data-report.md). Registrar a lista excluída no relatório.
- [ ] Todo doc importado recebe `legacyImport: true` + `migrationWarnings: [...]`.
- [ ] Grava `migration_audit` por documento (com `warnings` e snapshot cru).
- [ ] Idempotente: chave natural = `firebaseUid` (users) / `legacyFirestoreId` (pets, locations).
- [ ] Relatório: migrados / com warning / falhos + lista dos candidatos a limpeza.
- [ ] Validação manual: amostragem cruzada `firestore_backup.json` ↔ Mongo.

**Rollback:** `db.users.drop()` / `db.pets.drop()` / `db.locations.drop()`. Firestore permanece fonte de verdade. Sem impacto no app.

---

## FASE 4 — Feature **Tutor** no app via API

- [ ] `ApiUsuarioRepository implements UsuarioRepository` usando `http` + base URL por ambiente + interceptor que anexa o Firebase ID Token.
- [ ] Endpoints: `GET /me`, `PATCH /me`, `DELETE /me` (soft delete + cascata no servidor).
- [ ] Feature flag `useApiForUsuario` (config/`--dart-define`) alterna `firebaseUsuarioRepositoryProvider` ↔ `apiUsuarioRepositoryProvider`.
- [ ] `signIn/signUp/sendPasswordReset/signOut` **continuam no Firebase Auth** — só o *perfil* (doc do usuário) passa a vir da API. No `signUp`, após criar no Auth, chamar `GET /me` (provisiona no Mongo).
- [ ] Telas afetadas: cadastro, home (saudação), configurações, editar-perfil.
- [ ] Testar contra staging; comparar com versão Firestore; corrigir.
- [ ] `currentUsuarioProvider` passa a combinar `authStateChanges` (Firebase) + `GET /me` (API) em vez do doc Firestore.

**Rollback:** flag `useApiForUsuario=false` → volta ao `FirebaseUsuarioRepository`.

---

## FASE 5 — Feature **Pets** no app via API

- [ ] `GET/POST/PATCH/DELETE /api/v1/pets` + `GET /api/v1/pets/{id}`. Lista sempre escopada ao tutor logado no servidor.
- [ ] `ApiPetRepository`. Streams viram: carrega ao abrir + `pull-to-refresh` + re-fetch ao voltar pra tela (R-04). Avaliar tela a tela.
- [ ] `status` do pet exposto e editável (novo campo).
- [ ] Feature flag `useApiForPets`. Telas: home (lista), pet_detail, pet_form.
- [ ] Testar; comparar; corrigir.

**Rollback:** `useApiForPets=false`.

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
