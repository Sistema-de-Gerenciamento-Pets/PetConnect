# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 4.

---

## 1. Onde estamos

| Fase | Estado |
|---|---|
| 0 — Backup + auditoria + decisões | ✅ |
| 1 — Esqueleto do backend Spring | ✅ |
| 2 — Auth Firebase + `/api/v1/me` | ✅ verificada e2e |
| 3 — Migração de dados (`users`/`pets`/`locations`) | ✅ rodada real: 11 users, 21 pets, 64 locations |
| 4 — Feature **Tutor** no app via API | ✅ verificada e2e (flag `USE_API_USUARIO`, default off) |
| **5 — Feature Pets no app via API** | ⏭️ **próxima** |
| 6–13 | pendentes (ver seção 5) |

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

## 4. FASE 4 — o que ficou pronto (referência para a FASE 5)

- Backend `user/`: `MeController` (`GET`/`PATCH`/`DELETE /api/v1/me`), `UserService` (provisiona no 1º acesso, `update`, `deleteAccount` com cascata), `UserResponse`/`UpdateMeRequest`.
- App: `ApiClient`, `ApiException`, `AppConfig`, `ApiUsuarioRepository`, `apiClientProvider`, provider condicional pela flag.
- Padrão de mapeamento data/enum PT↔API estabelecido no `ApiUsuarioRepository`.
- **Pendente do usuário:** rodar no device com `USE_API_USUARIO=true` e validar cadastro/edição/exclusão contra a versão Firestore (flag off).

---

## 5. FASE 5 — Feature **Pets** no app via API (passo a passo)

### 5.1 Backend — módulo `pet` (hoje só tem o domínio da migração)
Criar, seguindo o molde do módulo `user`:
1. `pet/web/PetController` sob `/api/v1/pets`:
   - `GET /api/v1/pets` → lista os pets **do tutor logado** (`principal.userId()` → `pets.findByTutorId`). Nunca aceitar `tutorId` do cliente.
   - `GET /api/v1/pets/{id}` → 1 pet; 404 se não for do tutor.
   - `POST /api/v1/pets` → cria (`tutorId` = logado, `publicId` novo, `status=ACTIVE`).
   - `PATCH /api/v1/pets/{id}` → atualiza campos.
   - `DELETE /api/v1/pets/{id}` → apaga o pet + cascata de `locations` (e, no futuro, vacinas/consultas/histórico).
2. `pet/web/PetResponse` (DTO) + `pet/web/CreatePetRequest` / `UpdatePetRequest` com Bean Validation.
3. `pet/application/PetService` — regra de posse (`tutorId == logado`) em toda operação de `{id}`; lançar `ApiException.notFound`/`forbidden`.
4. Testes `PetControllerTest` (molde do `MeControllerTest`): CRUD, escopo por tutor, 404 em pet de outro, payload inválido → 400.

**Campos** (ver `docs/database/mongodb-target-schema.md`): `name`, `species` (DOG/CAT/OTHER), `breed`, `color`, `gender` (MALE/FEMALE/UNKNOWN), `size` (SMALL/MEDIUM/LARGE), `weightKg` (number), `birthDate` (ISO), `status` (ACTIVE/LOST/FOUND/DECEASED/ARCHIVED), `vaccinatedFlag`, `publicContactPhone`, `photoUrl`. Expor `publicId` (read-only).

### 5.2 App — `ApiPetRepository`
1. `lib/features/pet/data/api_pet_repository.dart` implementando `PetRepository` (interface atual: `watchPets(userId)`, `watchPet(id)`, `createPet→String`, `updatePet`, `deletePet`):
   - `watchPets` / `watchPet` → `Stream.fromFuture` (emissão única).
   - `createPet` → `POST /pets`, devolve o `id` do body.
   - `updatePet` / `deletePet` → `PATCH`/`DELETE /pets/{id}`.
   - Mapear `Pet` (domínio do app) ↔ `PetResponse`. O `Pet` do app usa `peso` como String (`"12kg"`) e datas `dd/MM/yyyy`; a API usa `weightKg` number e ISO — converter nos dois sentidos. `especie`/`porte`/`genero` texto livre ↔ enums (reusar a ideia dos mapas do `ApiUsuarioRepository`; cuidado que os valores de UI do pet podem diferir dos do usuário — conferir as telas `pet_form_screen`).
2. Reusar `apiClientProvider`.

### 5.3 App — providers + telas
- `lib/features/pet/presentation/providers/pet_providers.dart`: `petRepositoryProvider` alterna `ApiPetRepository` ↔ `FirebasePetRepository` por `AppConfig.useApiForPets`.
- `petsProvider` / `petProvider.family` continuam `StreamProvider`; após criar/editar/excluir, as telas devem `ref.invalidate(petsProvider)` (e `petProvider(id)`).
- Adicionar **pull-to-refresh** na lista da Home (`RefreshIndicator` → `ref.invalidate(petsProvider)`).
- Campo `status` do pet: por ora pode ficar fora da UI (default ACTIVE) ou expor um seletor simples no `pet_form` — decidir com o usuário.

### 5.4 Testar e comparar
- `--dart-define=API_BASE_URL=… --dart-define=USE_API_USUARIO=true --dart-define=USE_API_PETS=true`.
- Fluxos: listar pets (deve bater com o que está no Mongo — os 21 migrados aparecem para os tutores correspondentes), criar/editar/excluir, abrir detalhe.
- Comparar com a flag off (Firestore).
- Atualizar `test/features/pet/*` que usam `FakePetRepository` (assinaturas não mudam; só garantir que os widget tests continuam verdes).

### 5.5 Fechar
- `flutter analyze` limpo, testes verdes, `mvn test` verde.
- Commit na branch, marcar FASE 5 no plano mestre e aqui.
- `USE_API_PETS` default **off**.

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
