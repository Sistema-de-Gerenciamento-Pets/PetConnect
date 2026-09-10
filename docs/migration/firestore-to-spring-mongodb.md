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

- [ ] Usuário executa **export completo do Firestore** (`gcloud firestore export gs://<bucket>` ou script Node com Admin SDK) e guarda em local seguro. **Bloqueante — R-01.**
- [ ] Usuário cola as **Firestore Security Rules** atualmente deployadas. **Bloqueante — R-02.**
- [ ] Relatório de qualidade de dados (etapa 50): contagem por coleção, % de `dataNascimento` vazio/inválido, `dono` não-nulo, docs sem `sobrenome`/`vacinado`, valores distintos de `genero`/`especie`/`porte`, docs órfãos.
- [ ] Confirmar destino do export (bucket) e retenção.
- [ ] Documentos 01–04 (este conjunto) revisados e aprovados pelo usuário.

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

## FASE 3 — Migração de dados: `users` + `pets` (script, ainda sem trocar o app)

- [ ] Script de migração (Java/Spring `CommandLineRunner` ou standalone) lê o export do Firestore e grava `users` e `pets` no Mongo.
- [ ] Converte datas, separa `peso`, gera `publicId`, mapeia enums, preenche `roles=["TUTOR"]`, `status="ACTIVE"`.
- [ ] Grava `migration_audit` por documento (com `warnings` e snapshot cru).
- [ ] Idempotente (reexecutável): chave natural = `firebaseUid` (users) / (`tutorId` + `nome` + origem) ou `legacyQrCodeId` (pets).
- [ ] Relatório: migrados / com warning / falhos.
- [ ] Validação manual: amostragem cruzada Firestore ↔ Mongo.

**Rollback:** `db.users.drop()` / `db.pets.drop()` (Firestore permanece fonte de verdade). Sem impacto no app.

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

## FASE 6 — Migração + feature **Vacinas**

- [ ] Script migra `Pets/{id}/vacinas` → `vaccines` (resolvendo `petId` do Mongo via `legacyQrCodeId`/auditoria).
- [ ] `GET/POST/PATCH/DELETE /api/v1/pets/{petId}/vaccines`.
- [ ] `ApiVacinaRepository` + flag `useApiForVacinas`. Alerta de próxima dose: manter regra no app (ou expor `alertStatus` no DTO).
- [ ] Testar; comparar; corrigir.

**Rollback:** flag off + `db.vaccines.drop()`.

---

## FASE 7 — Migração + feature **Consultas**

- [ ] Script migra `consultas` → `appointments` (combina `data`+`horario` em `scheduledAt`; mapeia 3 status).
- [ ] `GET/POST/PATCH /api/v1/pets/{petId}/appointments` (cancelar/realizar = `PATCH status`).
- [ ] `ApiConsultaRepository` + flag. Enum do app pode continuar com 3 estados; DTO aceita o enum de 7 mas migração só usa 3.
- [ ] Testar; comparar; corrigir.

**Rollback:** flag off + drop.

---

## FASE 8 — Migração + feature **Histórico Médico**

- [ ] Script migra `historicoMedico` → `medical_records` (guarda `legacyId`, seta `origin="TUTOR"`, mantém URLs de anexo do Cloudinary).
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

- [ ] Revisar/deployar Firestore Rules restritivas (a essa altura o Firestore só tem Auth + dados legados read-only): idealmente `allow read, write: if false` para coleções já migradas, mantendo só o necessário.
- [ ] Rate limiting, CORS, headers de segurança no backend.
- [ ] Revisão: nenhum segredo no repo (app ou backend); `git log` limpo de credenciais novas.
- [ ] App Check / reforço de auth se aplicável.

**Rollback:** reverter regras para o estado da FASE 0 (backup das rules).

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

## Pontos que PARAM a migração até decisão do usuário

| Ref | Assunto |
|---|---|
| A | Sem export/acesso aos dados reais do Firestore (FASE 0) |
| B | `usuarioID` — manter como `legacyUsuarioId` ou descartar? |
| C | `Pets.dono` — descartar ou preservar como `legacyDono`? |
| D | Coleção raiz `Localizacoes` — arquivar/ignorar ou migrar? |
| E | Firestore Rules deployadas — conteúdo real (FASE 0) |
| F | Backend: repo separado vs subpasta `backend/` |
| G | Hospedagem MongoDB + backend (Atlas free? provedor?) |
| H | Página pública do QR (RF17–19) entra agora na FASE 9 ou fica depois? |
