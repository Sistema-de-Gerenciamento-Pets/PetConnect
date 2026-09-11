# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 7.

---

## 1. Onde estamos

| Fase | Estado |
|---|---|
| 0 — Backup + auditoria + decisões | ✅ |
| 1 — Esqueleto do backend Spring | ✅ |
| 2 — Auth Firebase + `/api/v1/me` | ✅ verificada e2e |
| 3 — Migração de dados (`users`/`pets`/`locations`) | ✅ rodada real: 11 users, 21 pets, 64 locations |
| 4 — Feature **Tutor** no app via API | ✅ verificada e2e (flag `USE_API_USUARIO`, default off) |
| 5 — Feature **Pets** no app via API | ✅ verificada e2e (flag `USE_API_PETS`, default off) |
| 6 — Feature **Vacinas** | ✅ verificada e2e (flag `USE_API_VACINAS`, default off) |
| 7 — Feature **Consultas** | ✅ verificada e2e (flag `USE_API_CONSULTAS`, default off) |
| **8 — Feature Histórico Médico** | ⏭️ **próxima** |
| 9–13 | pendentes (ver seção 6) |

**Repositórios**
- App Flutter: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect` — `github.com/AleksGustavo/PetConnect`, branch de trabalho `feature/backend-spring-mongodb-migration`.
- Backend: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect-API` — `github.com/AleksGustavo/PetConnect-API` (privado), branch `main`.

**Docs da migração** (repo do app, `docs/`): `audit/current-state.md` · `database/{firestore-current-schema,firestore-data-report,mongodb-target-schema}.md` · `migration/firestore-to-spring-mongodb.md` (plano mestre) · `security/firestore-rules-deployed.md` · este `handoff.md`.

---

## 2. Como subir o ambiente

Pré-requisito: **Docker** (a API não sobe via `mvn spring-boot:run` nesta máquina — ver seção 3).

```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API"
docker compose up -d --build        # mongo (27018) + api (8090)
docker compose logs -f api
curl http://localhost:8090/api/v1/ping
```

Depois de mudar código do backend: `docker compose up -d --build api`.

| Serviço | Endereço |
|---|---|
| API | `http://localhost:8090` (Swagger em `/swagger-ui.html`) |
| MongoDB | `mongodb://localhost:27018/petconnect` |

**Rodar o app com a API (FASE 4+):**
```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect"
# celular por USB: encaminha a porta do PC para o aparelho
adb reverse tcp:8090 tcp:8090
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8090 \
  --dart-define=USE_API_USUARIO=true
```
- Emulador Android: use `--dart-define=API_BASE_URL=http://10.0.2.2:8090` (sem `adb reverse`).
- Sem os `--dart-define`, o app roda 100% Firebase, como antes.

**Testes**
```bash
# backend (JDK 21 + Maven, Mongo embarcado): 14 testes
cd "…/PetConnect-API" && mvn -q -B test
# app: flutter analyze + flutter test test/core/ test/features/pet/
cd "…/PetConnect"     && flutter analyze && flutter test test/core/ test/features/pet/
```

**Re-rodar a migração** (idempotente):
```bash
cd "…/PetConnect-API"
MONGODB_URI="mongodb://localhost:27018/petconnect" \
  mvn -q -B spring-boot:run -Dspring-boot.run.profiles=dev,migration \
  "-Dspring-boot.run.arguments=--petconnect.migration.source=C:/Users/Aleksander/Documents/backup-firestore/firestore_backup.json"
```

---

## 3. Fatos e armadilhas

- **Loopback / NIO Selector:** nesta máquina `Selector.open()` falha (`Unable to establish loopback connection`, AF_UNIX). Quebra (a) init do `firebase-admin` — contornado com `NetHttpTransport` no `FirebaseConfig` — e (b) start do Tomcat — contornado rodando a API em **container Linux**. `flutter run` para device **funciona** (só o APK de release e o servidor Java no Windows são afetados).
- **Portas:** 8080/27017 do host costumam estar ocupadas → API em **8090**, Mongo em **27018**.
- **Firebase Storage morto** (billing encerrado): 18 imagens legadas viraram `photoUrl: null` + aviso `storage-image-lost`. Só sobrevivem URLs Cloudinary (2 users, 3 pets). Upload novo já é Cloudinary.
- **Credencial Firebase:** `C:\Users\Aleksander\Documents\pet-connect-c53f1-firebase-adminsdk-t8ctg-326661da99.json` (fora dos repos). Montada read-only no container via `.env` (`FIREBASE_SA_PATH`). `.gitignore` do backend bloqueia `*firebase*adminsdk*.json`, `.env`, `application-local.yml`.
- **Firestore Rules atuais** são permissivas (banco todo legível sem login) — endurecer só na FASE 11.
- **Web API key** (trocar custom token → ID token em e2e): `AIzaSyARaspdC-wNqVESmfVuJqPCg9wAbomoQrc`.
- **Feature flags** (`lib/core/config/app_config.dart`): `USE_API_USUARIO` (FASE 4, pronta), `USE_API_PETS` (FASE 5, a implementar), `API_BASE_URL`.
- **`ApiClient`** (`lib/core/network/`): já pronto e testado — reusar nos próximos repositórios de API.
- **Streams:** a API não entrega stream. O `ApiUsuarioRepository` implementa `watchUsuario` como `Stream.fromFuture` (emissão única) e as telas chamam `ref.invalidate(currentUsuarioProvider)` após editar. Mesmo padrão vale para pets.
- **`publicId` do pet** é determinístico na migração (`UUID.nameUUIDFromBytes("pet:" + legacyFirestoreId)`).
- **Contas borderline mantidas:** "Marcola" (`VW9SSk…`) e "registro" (`4nMLz8…`). Remover = adicionar em `LegacyMigrationService.EXCLUDED_USER_IDS` e re-rodar.

---

## 4. FASES 4–7 — o que ficou pronto (molde para as próximas)

- **Backend**: módulos `user/` (`/api/v1/me`), `pet/` (`/api/v1/pets`), `vaccine/` (`/api/v1/pets/{petId}/vaccines`), `appointment/` (`/api/v1/pets/{petId}/appointments`). `PetService.get(tutorId, petId)` é a checagem de posse reutilizável; `VaccineService`/`AppointmentService` a injetam.
- **App**: `lib/core/` (`ApiClient`, `ApiException`, `AppConfig`, `br_date.dart` com `brToIso`/`isoToBr`); `Api{Usuario,Pet,Vacina,Consulta}Repository`; providers condicionais pelas flags `USE_API_USUARIO`/`USE_API_PETS`/`USE_API_VACINAS`/`USE_API_CONSULTAS`.
- **Padrões estabelecidos** (copiar na FASE 8):
  - Repositório de API: `watch*` = `Stream.fromFuture` (emissão única); tela invalida o provider após mutar; listas com pull-to-refresh (inclusive no estado vazio).
  - Mapeamento `dd/MM/yyyy` ↔ ISO (`brToIso`/`isoToBr`) e rótulos PT ↔ enums (mapas estáticos no repositório). Horário `HH:mm` ↔ `HH:mm:ss` (`LocalTime` do Jackson) — ver `ApiConsultaRepository._horaParaApi/_horaDaApi`.
  - Backend: sub-recurso do pet → `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`, `service.list/create/update(me.userId(), petId, ...)` sempre começando por `petService.get(tutorId, petId)` (404 se não for do tutor) + `ownedOr404(petId, subId)`. DTO com Bean Validation. Cascata do sub-recurso em `PetService.delete`. Nem todo sub-recurso precisa de `DELETE` (consultas não têm — cancelar é status).
  - `GlobalExceptionHandler` já cobre `HttpRequestMethodNotSupportedException`→405 e `NoHandlerFoundException`/`NoResourceFoundException`→404 (rota/verbo não mapeado não vira mais 500).
  - Teste de controller: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier`, users/pets salvos direto no repo, `com.jayway.jsonpath.JsonPath.read` para pegar ids.
  - e2e: script no scratchpad (molde `e2e-fase6.js`) — token real de um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3` tem 3 pets), CRUD, 404 cross-tenant, limpeza.
- **Pendente do usuário:** rodar no device com as flags ligadas e comparar com elas off (Firestore).

---

## 5. FASE 8 — Feature **Histórico Médico** (passo a passo)

Histórico médico de um pet, com anexos (exames/laudos, RF24). **Sem migração de dados** (`Pets/*/historicoMedico` vazia). Molde: módulo `vaccine`, **mas com uma diferença estrutural importante** — ver 5.0.

### 5.0 A pegadinha do `novoId` — decidir antes de codar

A interface atual (`lib/features/pet/domain/historico_medico_repository.dart`) tem um método
que os outros repositórios não têm:

```dart
/// Gera um id novo sem gravar nada no Firestore — usado para já ter um
/// caminho estável no Storage antes de o registro existir, já que os
/// anexos (RF24) são enviados antes de o registro ser salvo.
String novoId(String petId);
```

O fluxo hoje: a tela pede um id ao repositório (`_historico(petId).doc().id`, gerado
localmente pelo SDK do Firestore, **sem rede**), sobe os anexos pro Cloudinary usando esse id
no path, e só then cria o registro com `set(id, ...)` (não `add`). Isso não existe nas
outras fases porque só o histórico médico tem anexo.

Com a API, o Mongo gera o `_id` no `save()` — não dá pra "reservar" um id antes de
existir o documento do mesmo jeito. Duas opções:

- **A (recomendada — menor mudança):** `ApiHistoricoMedicoRepository.novoId(petId)` passa a
  gerar um **UUID local** (pacote `uuid`, ou `DateTime.now().microsecondsSinceEpoch` +
  random — não precisa ser um ObjectId válido). O backend aceita um campo opcional
  `id` no `CreateHistoricoRequest`; se vier preenchido, usa **esse valor como `_id`** do
  documento Mongo (Mongo aceita `_id` string arbitrário) em vez de gerar um `ObjectId`.
  Assim o app continua com o mesmo fluxo (gera id → sobe anexo com o path baseado nele →
  cria o registro com esse id) e nada muda nas telas.
- **B (mais invasiva):** mudar o fluxo pra sempre criar o registro primeiro (sem anexos),
  pegar o id que a API devolve, então subir os anexos e fazer um `PATCH` incluindo as
  URLs. Evita `_id` client-side no backend, mas exige reescrever `historico_form_screen.dart`.

Fica com a **opção A** a menos que surja um motivo forte pra B.

### 5.1 Backend — módulo `medicalrecord`
1. `medicalrecord/domain/MedicalRecord` (`@Document("medical_records")`): `id`, `petId` (indexado), `recordedAt` (LocalDate), `description`, `veterinarian`, `attachments` (`List<String>`, URLs Cloudinary), `origin` (enum `TUTOR`/`CLINIC`/`VETERINARIAN`/`IMPORT`, default `TUTOR` — novo campo do schema-alvo, sem equivalente na UI atual), timestamps.
2. `MedicalRecordRepository` — `findByPetIdOrderByRecordedAtAsc(petId)`, `deleteByPetId(petId)`.
3. `MedicalRecordService` — molde `VaccineService`. `create` aceita o `id` opcional do request (ver 5.0) — se vier, `new MedicalRecord(); record.setId(req.id())` antes de `save` (Spring Data respeita um `id` já setado — faz upsert em vez de insert).
4. `MedicalRecordController` sob `/api/v1/pets/{petId}/medical-records`: `GET`, `POST` (201), `PATCH /{recordId}`, `DELETE /{recordId}` (204).
5. Cascata em `PetService.delete`.
6. `MedicalRecordControllerTest`: CRUD, `id` client-side respeitado, ordem, 404 cross-tenant, 400 sem obrigatórios, cascata.

**Upload dos anexos:** continua **direto do app pro Cloudinary** (preset unsigned, como hoje) — a API só guarda as URLs recebidas. Upload assinado via backend é a FASE 10, não esta.

### 5.2 App — `ApiHistoricoMedicoRepository`
1. Interface: `watchHistorico(petId)`, `novoId(petId)` (ver 5.0 — vira geração local), `createHistorico`, `updateHistorico`, `deleteHistorico`. Model `HistoricoMedico`: `data` (dd/MM/yyyy), `descricao`, `veterinario?`, `anexos: List<String>`.
2. `lib/features/pet/data/api_historico_medico_repository.dart` via `/api/v1/pets/{petId}/medical-records`, enviando `id` no `POST` (gerado por `novoId`). `data` ↔ `recordedAt` (ISO), `descricao` ↔ `description`, `veterinario` ↔ `veterinarian`, `anexos` ↔ `attachments`.
3. Upload de anexo continua pelo `anexoRepositoryProvider` (Cloudinary) — nada muda aí.

### 5.3 App — providers + telas
- `historico_medico_providers.dart`: flag `AppConfig.useApiForHistorico` (`USE_API_HISTORICO` — adicionar em `app_config.dart`).
- Telas `historico_list_screen` / `historico_form_screen`: `ref.invalidate(historicoMedicoProvider(petId))` após mutar; pull-to-refresh na lista.

### 5.4 Fechar
- `flutter analyze` limpo, `flutter test test/core/ test/features/pet/` verde, `mvn -B test` verde.
- **e2e** (molde `e2e-fase7.js`): criar registro com `id` pré-gerado (confirmar que persiste com esse id), listar, editar, anexar uma URL fake, excluir; 404 cross-tenant.
- Commit, marcar FASE 8 no plano mestre e aqui. `USE_API_HISTORICO` default off.

Depois da FASE 8, as fases 6–8 (vacinas/consultas/histórico) estarão todas na API — sobra só
QR/página pública (FASE 9) antes de mexer em upload assinado e nas Firestore Rules.

---

## 6. FASE 6+ (resumo — detalhe no plano mestre)

| Fase | Essência | Migração de dados? |
|---|---|---|
| 6 — Vacinas | só API + repositório no app | **não** (subcoleção vazia) |
| 7 — Consultas | idem; enum de status 3→7 no backend | **não** |
| 8 — Histórico médico | idem; anexo segue unsigned no Cloudinary | **não** |
| 9 — QR + página pública (RF17–19) | `GET /api/v1/public/pets/{publicId}` sem auth + `POST .../sightings` → `locations`; página web; app usa `publicId` | `publicId` já existe |
| 10 — Upload assinado | backend assina Cloudinary; `delete` deixa de ser no-op | — |
| 11 — Endurecer Firestore Rules | versionar `firestore.rules`; cortar leitura anônima; `read,write:false` nas coleções migradas | — |
| 12 — Settings + validação total | reescrever `auth_flow_test.dart`; e2e por feature | — |
| 13 — Remover Firestore | tirar `cloud_firestore`, apagar `firebase_*_repository.dart`, remover flags. `firebase_auth` fica. | export final arquivado |

---

## 7. Pendências abertas

- **CI do backend:** não há GitHub Actions ainda. Sugerido: workflow `mvn -B test`.
- **Hospedagem staging:** MongoDB Atlas M0 + host free — só quando for testar fora do localhost.
- **Validação amostral manual** da FASE 3: 1 spot-check feito (Nymeria/Aleksander OK); conferir mais alguns.
- **Contas borderline** "Marcola"/"registro": confirmar remoção com o usuário.
- **`auth_flow_test.dart`** ainda bate no Firebase real, fora do CI — reescrever na FASE 12.
- **APK de release** (loopback) segue sem solução no Windows; não bloqueia a migração.
- **FASE 4 no device**: validação final do usuário pendente.
