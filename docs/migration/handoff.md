# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 5.

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
| **6 — Feature Vacinas** | ⏭️ **próxima** |
| 7–13 | pendentes (ver seção 6) |

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

## 4. FASES 4 e 5 — o que ficou pronto (molde para as próximas)

- **Backend `user/`**: `MeController` (`GET`/`PATCH`/`DELETE /api/v1/me`), `UserService` (provisiona no 1º acesso, `update`, `deleteAccount` com cascata).
- **Backend `pet/`**: `PetController` (`GET` lista + `GET/POST/PATCH/DELETE /{id}`), `PetService` (`ownedOr404` — posse por `tutorId`), `PetResponse`/`CreatePetRequest`/`UpdatePetRequest`.
- **App**: `ApiClient`/`ApiException`/`AppConfig` (`lib/core/`), `ApiUsuarioRepository`, `ApiPetRepository`, providers condicionais pelas flags `USE_API_USUARIO`/`USE_API_PETS`.
- **Padrões estabelecidos** (copiar nas fases 6–8):
  - Repositório de API: `watch*` = `Stream.fromFuture` (emissão única); tela invalida o provider após mutar; Home tem pull-to-refresh.
  - Mapeamento `dd/MM/yyyy` ↔ ISO e rótulos PT ↔ enums (mapas estáticos no repositório).
  - Backend: DTO de request com Bean Validation; `ownedOr404`; 404 (não 403) para recurso de outro tutor; `@DeleteMapping` → 204 + cascata.
  - Teste de controller: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier`, usuários salvos direto no repo, `JsonPath.read` para pegar ids.
- **Pendente do usuário:** rodar no device com `USE_API_USUARIO=true USE_API_PETS=true` e comparar com as flags off (Firestore).

---

## 5. FASE 6 — Feature **Vacinas** (passo a passo)

Carteira de vacina de um pet. **Sem migração de dados** (subcoleção `Pets/*/vacinas` vazia). Molde: módulo `pet` + `ApiPetRepository`.

### 5.1 Backend — módulo `vaccine`
1. `vaccine/domain/Vaccine` (`@Document("vaccines")`): `id`, `petId` (indexado), `name`, `appliedAt` (Date), `nextDoseAt` (Date, opcional), `veterinarian`, `notes`, timestamps. (Campos extras do schema-alvo — `manufacturer`/`batch`/`dose`/`clinic`/`proofUrl` — podem ficar para depois.)
2. `vaccine/infrastructure/VaccineRepository` — `findByPetIdOrderByAppliedAtDesc(petId)`, `deleteByPetId(petId)`, `deleteByPetIdIn(...)`.
3. `vaccine/application/VaccineService` — **toda** operação recebe o `tutorId` do token e valida que o `petId` pertence a ele (reusar `PetService.get(tutorId, petId)` como checagem de posse; pode-se extrair um `PetOwnership` component ou injetar `PetService`). 404 se o pet não é do tutor ou a vacina não é do pet.
4. `vaccine/web/VaccineController` sob **`/api/v1/pets/{petId}/vaccines`**: `GET` (lista), `POST` (201), `PATCH /{vaccineId}`, `DELETE /{vaccineId}` (204). DTOs `VaccineResponse` / `SaveVaccineRequest` (Bean Validation: `name` `@NotBlank`, `appliedAt` `@NotNull`).
5. **Cascata:** em `PetService.delete`, além de `locations`, chamar `vaccines.deleteByPetIdIn(...)`. Atualizar `PetControllerTest` e `UserService.deleteAccount` (a exclusão de conta já apaga pets → e agora as vacinas).
6. `VaccineControllerTest`: CRUD, escopo (vacina de pet de outro tutor → 404), 400 sem `name`/`appliedAt`.

### 5.2 App — `ApiVacinaRepository`
1. Ver a interface atual: `lib/features/pet/domain/vacina_repository.dart` (`watchVacinas(petId)`, `createVacina`, `updateVacina`, `deleteVacina`). Model `Vacina` em `domain/vacina.dart` — datas `dd/MM/yyyy`.
2. `lib/features/pet/data/api_vacina_repository.dart` implementando a interface via `/api/v1/pets/{petId}/vaccines`. `watchVacinas` = emissão única; converter datas.
3. Regra de alerta (`vacina_alerta.dart`) **fica no app** — não precisa do backend.

### 5.3 App — providers + telas
- `vacina_providers.dart`: `vacinaRepositoryProvider` alterna Api ↔ Firebase por `AppConfig.useApiForVacinas` (adicionar a flag em `app_config.dart`).
- Telas `vacina_list_screen` / `vacina_form_screen`: após mutar, `ref.invalidate(vacinasProvider(petId))`; pull-to-refresh na lista.

### 5.4 Fechar
- `flutter analyze` limpo, `flutter test test/core/ test/features/pet/` verde, `mvn -B test` verde.
- **e2e** (script no scratchpad, molde `e2e-fase5.js`): criar vacina para um pet migrado, listar, editar, excluir; vacina de pet alheio → 404.
- Commit, marcar FASE 6 no plano mestre e aqui. `USE_API_VACINAS` default off.

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
