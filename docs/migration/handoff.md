# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 6.

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
| **7 — Feature Consultas** | ⏭️ **próxima** |
| 8–13 | pendentes (ver seção 6) |

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

## 4. FASES 4–6 — o que ficou pronto (molde para as próximas)

- **Backend**: módulos `user/` (`/api/v1/me`), `pet/` (`/api/v1/pets`), `vaccine/` (`/api/v1/pets/{petId}/vaccines`). `PetService.get(tutorId, petId)` é a checagem de posse reutilizável; `VaccineService` a injeta.
- **App**: `lib/core/` (`ApiClient`, `ApiException`, `AppConfig`, `br_date.dart` com `brToIso`/`isoToBr`); `Api{Usuario,Pet,Vacina}Repository`; providers condicionais pelas flags `USE_API_USUARIO`/`USE_API_PETS`/`USE_API_VACINAS`.
- **Padrões estabelecidos** (copiar nas fases 7–8):
  - Repositório de API: `watch*` = `Stream.fromFuture` (emissão única); tela invalida o provider após mutar; listas com pull-to-refresh.
  - Mapeamento `dd/MM/yyyy` ↔ ISO (`brToIso`/`isoToBr`) e rótulos PT ↔ enums (mapas estáticos no repositório).
  - Backend: sub-recurso do pet → `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`, `service.list/create/update/delete(me.userId(), petId, ...)` sempre começando por `petService.get(tutorId, petId)` (404 se não for do tutor) + `ownedOr404(petId, subId)`. DTO com Bean Validation. `@DeleteMapping` → 204. Cascata do sub-recurso em `PetService.delete`.
  - Teste de controller: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier`, users/pets salvos direto no repo, `com.jayway.jsonpath.JsonPath.read` para pegar ids.
  - e2e: script no scratchpad (molde `e2e-fase6.js`) — token real de um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3` tem 3 pets), CRUD, 404 cross-tenant, limpeza.
- **Pendente do usuário:** rodar no device com as flags ligadas e comparar com elas off (Firestore).

---

## 5. FASE 7 — Feature **Consultas** (passo a passo)

Consultas veterinárias de um pet. **Sem migração de dados** (`Pets/*/consultas` vazia). Molde: módulo `vaccine`.

### 5.1 Backend — módulo `appointment`
1. `appointment/domain/Appointment` (`@Document("appointments")`): `id`, `petId` (indexado), `scheduledDate` (LocalDate), `scheduledTime` (LocalTime, **nullable** — o app tem "horário opcional"), `veterinarian`, `reason`, `status` (enum), timestamps.
2. `appointment/domain/AppointmentStatus` — enum **completo** de 7 (`REQUESTED`, `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLATION_REQUESTED`, `CANCELLED`, `REJECTED`). O app só usa 3 (ver mapeamento abaixo); o enum já fica pronto para o fluxo clínica↔tutor futuro.
3. `AppointmentRepository` — `findByPetIdOrderByScheduledDateAscScheduledTimeAsc(petId)`, `deleteByPetId(petId)`.
4. `AppointmentService` — molde `VaccineService` (posse via `PetService.get`). **Sem `delete`** na interface do app (cancelar = `status`), mas pode expor `DELETE` no backend por consistência/testes; o `ApiConsultaRepository` só usa `PATCH`.
5. `AppointmentController` sob `/api/v1/pets/{petId}/appointments`: `GET`, `POST` (201), `PATCH /{appointmentId}`. DTO `AppointmentRequest` (`scheduledDate` `@NotNull`, `veterinarian` `@NotBlank`, `reason` `@NotBlank`, `scheduledTime`/`status` opcionais). `AppointmentResponse` devolve `status` como string.
6. Cascata: `PetService.delete` → `appointments.deleteByPetId(petId)`. Atualizar `PetService` + testes.
7. `AppointmentControllerTest`: CRUD, ordem, 404 cross-tenant, 400 sem obrigatórios, cascata.

**Mapeamento de status app ↔ API** (mesma tabela da migração):

| App (`ConsultaStatus`) | API |
|---|---|
| `agendada` | `CONFIRMED` |
| `realizada` | `COMPLETED` |
| `cancelada` | `CANCELLED` |

Qualquer outro valor da API que o app receber → tratar como `agendada` (fallback já existe em `ConsultaStatus.fromValue`).

### 5.2 App — `ApiConsultaRepository`
1. Interface `lib/features/pet/domain/consulta_repository.dart`: `watchConsultas(petId)`, `createConsulta`, `updateConsulta` (**não há `delete`**). Model `Consulta`: `data` (dd/MM/yyyy), `horario` (`HH:mm?`), `veterinario`, `motivo`, `status` (enum).
2. `lib/features/pet/data/api_consulta_repository.dart` via `/api/v1/pets/{petId}/appointments`. `data` ↔ `scheduledDate` (ISO), `horario` ↔ `scheduledTime` (`"HH:mm"` ou `HH:mm:ss` — normalizar), `motivo` ↔ `reason`, `veterinario` ↔ `veterinarian`, `status` ↔ enum via mapa.
3. Regras de alerta (`consulta_alerta.dart`) **ficam no app**.

### 5.3 App — providers + telas
- `consulta_providers.dart`: flag `AppConfig.useApiForConsultas` (`USE_API_CONSULTAS` — adicionar em `app_config.dart`).
- Telas `consulta_list_screen` / `consulta_form_screen`: `ref.invalidate(consultasProvider(petId))` após mutar; pull-to-refresh na lista.

### 5.4 Fechar
- `flutter analyze` limpo, `flutter test test/core/ test/features/pet/` verde, `mvn -B test` verde.
- **e2e** (molde `e2e-fase6.js`): agendar/listar/editar/cancelar (via status) num pet migrado; 404 cross-tenant.
- Commit, marcar FASE 7 no plano mestre e aqui. `USE_API_CONSULTAS` default off.

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
