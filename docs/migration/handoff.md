# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 8.

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
| 8 — Feature **Histórico Médico** | ✅ verificada e2e (flag `USE_API_HISTORICO`, default off) |
| **9 — QR + página pública** | ⏭️ **próxima** — tem uma dependência externa a resolver antes (ver seção 5) |
| 10–13 | pendentes (ver seção 6) |

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

## 4. FASES 4–8 — o que ficou pronto (molde para as próximas)

- **Backend**: módulos `user/` (`/api/v1/me`), `pet/` (`/api/v1/pets`), `vaccine/` (`/api/v1/pets/{petId}/vaccines`), `appointment/` (`/api/v1/pets/{petId}/appointments`), `medicalrecord/` (`/api/v1/pets/{petId}/medical-records`). `PetService.get(tutorId, petId)` é a checagem de posse reutilizável; os 3 últimos módulos a injetam. `PetService.delete` cascateia em **todos** eles (locations, vaccines, appointments, medical_records).
- **App**: `lib/core/` (`ApiClient`, `ApiException`, `AppConfig`, `br_date.dart` com `brToIso`/`isoToBr`); `Api{Usuario,Pet,Vacina,Consulta,HistoricoMedico}Repository`; providers condicionais pelas flags `USE_API_USUARIO`/`USE_API_PETS`/`USE_API_VACINAS`/`USE_API_CONSULTAS`/`USE_API_HISTORICO`.
- **Padrões estabelecidos** (copiar na FASE 9):
  - Repositório de API: `watch*` = `Stream.fromFuture` (emissão única); tela invalida o provider após mutar; listas com pull-to-refresh (inclusive no estado vazio).
  - Mapeamento `dd/MM/yyyy` ↔ ISO (`brToIso`/`isoToBr`) e rótulos PT ↔ enums (mapas estáticos no repositório). Horário `HH:mm` ↔ `HH:mm:ss` (`LocalTime` do Jackson) — ver `ApiConsultaRepository._horaParaApi/_horaDaApi`.
  - Backend: sub-recurso do pet → `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`, `service.list/create/update(me.userId(), petId, ...)` sempre começando por `petService.get(tutorId, petId)` (404 se não for do tutor) + `ownedOr404(petId, subId)`. DTO com Bean Validation. Cascata do sub-recurso em `PetService.delete`. Nem todo sub-recurso precisa de `DELETE` (consultas não têm — cancelar é status).
  - `GlobalExceptionHandler` já cobre `HttpRequestMethodNotSupportedException`→405 e `NoHandlerFoundException`/`NoResourceFoundException`→404 (rota/verbo não mapeado não vira mais 500).
  - Teste de controller: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier`, users/pets salvos direto no repo, `com.jayway.jsonpath.JsonPath.read` para pegar ids.
  - e2e: script no scratchpad (molde `e2e-fase6.js`) — token real de um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3` tem 3 pets), CRUD, 404 cross-tenant, limpeza.
- **Pendente do usuário:** rodar no device com as flags ligadas e comparar com elas off (Firestore).

---

## 5. FASE 9 — QR + página pública (RF17–19, RF31) (passo a passo)

Diferente das fases 6–8, esta **não** é só "mais um sub-recurso" — tem uma peça pública (sem
login) e uma dependência externa real. **Ler 5.0 antes de codar.**

### 5.0 Dependência externa a resolver com o usuário primeiro

A página pública do QR precisa de uma **URL/domínio publicamente acessível** —
`pet_qr_code.dart` hoje aponta pra `https://pet-connect-c53f1.web.app/pet/{id}`, que **não
existe** (nunca foi provisionado). Sem isso:

- dá pra construir e testar os **endpoints da API** normalmente (via `curl`/scripts, como
  nas fases anteriores — eles não precisam de domínio, só de HTTP);
- mas a **página web pública** em si (o que abre quando alguém escaneia o QR) só pode ser
  testada de verdade com um domínio real, e o app só pode gerar um QR "correto" quando
  soubermos qual URL usar.

Perguntar ao usuário antes de ir longe demais:
1. Vai hospedar a API (e a página pública) em algum lugar acessível de fora (Render/Railway/Fly/Koyeb, como já ficou registrado como decisão da FASE 1), ou por enquanto fica só local?
2. Se só local por ora: tudo bem construir os endpoints (`GET /api/v1/public/pets/{publicId}`, `POST /api/v1/public/pets/{publicId}/sightings`) e testá-los via script/e2e, deixando a geração do QR com a URL real pra quando existir hospedagem — **não travar a fase por isso**.

### 5.1 Backend — endpoints públicos (sem autenticação)

1. `SecurityConfig.PUBLIC_PATHS` — acrescentar `/api/v1/public/**`.
2. `location/web/PublicPetController` sob `/api/v1/public/pets/{publicId}`:
   - `GET` — **sem `@AuthenticationPrincipal`**. Resolve o pet via `PetRepository.findByPublicId` (já existe, criado na FASE 3). Devolve um DTO **mínimo**: `name`, `photoUrl`, `species`, `status`, `publicContactPhone` — nunca `tutorId`, e-mail, telefone pessoal, etc. Pet inexistente ou `status=ARCHIVED` → 404.
   - `POST /sightings` — **sem auth**. Corpo: `latitude?`, `longitude?`, `description?`, `reporterContact?`. Cria um doc em `locations` com `petId` resolvido, `source=PUBLIC_QR`, `legacyImport=false`. **Rate limit básico** (ex.: Bucket4j ou um filtro simples por IP — decidir o quanto vale investir agora vs. depois) pra não virar vetor de spam, já que é escrita sem login.
3. `location/web/LocationController` sob `/api/v1/pets/{petId}/locations` (**autenticado**, RF32): `GET` (tutor vê os avistamentos do próprio pet — inclui os 64 migrados + os novos scans), `POST` (RF31/32, tutor registra manualmente, `source=TUTOR`). Molde `vaccine`/`appointment`.
4. Cascata: `PetService` **já** injeta `LocationRepository` e cascateia em `delete()` desde a FASE 3 — nada a mudar aí.
5. Testes: endpoints públicos sem token → 200/201 (não 401!); pet arquivado/inexistente → 404; DTO público não vaza `tutorId`; `LocationController` autenticado com escopo por tutor (404 cross-tenant, molde de sempre).

### 5.2 App — QR real + relato anônimo (RF31)

1. `pet_qr_code.dart`: trocar `publicPetUrl` pra usar `pet.publicId` (vem da API — `ApiPetRepository` já expõe via `qrCodeId`, ver FASE 5) e o domínio real definido em 5.0. Regenerar QR (RF19) = o backend já suporta trocar `publicId`? **Hoje não** — `publicId` é fixo no `Pet`. Se RF19 (regenerar) for exigido nesta fase, adicionar `POST /api/v1/pets/{id}/qr-code/regenerate` (novo `publicId`) — avaliar se entra agora ou fica pra depois.
2. Nova tela pública (fora do fluxo autenticado) OU página web separada — **decidir**: (a) uma rota Flutter Web simples, se o app rodar em web; (b) uma paginazinha HTML/Thymeleaf servida pelo próprio backend em `/p/{publicId}` (o que o plano mestre original previa). (b) é mais simples de hospedar junto da API.
3. `LocalizacaoRepository` (RF31/32, hoje sem lat/lng) → `ApiLocalizacaoRepository` contra `/api/v1/pets/{petId}/locations`. Ganha de brinde os dados migrados (65 avistamentos históricos) aparecendo pra quem já tinha pet antes da migração.

### 5.3 Fechar
- `flutter analyze` limpo, `mvn -B test` verde.
- **e2e** (sem token, ao contrário do molde das fases 6–8): `curl`/script batendo em `/api/v1/public/pets/{publicId}` sem `Authorization` → 200; `POST /sightings` sem auth → 201; pet arquivado/inexistente → 404.
- Commit, marcar FASE 9 no plano mestre e aqui.

---

---

## 6. FASE 10+ (resumo — detalhe no plano mestre)

| Fase | Essência | Migração de dados? |
|---|---|---|
| 9 — QR + página pública (RF17–19) | `GET /api/v1/public/pets/{publicId}` sem auth + `POST .../sightings` → `locations`; página web; app usa `publicId` — ver seção 5 | `publicId` já existe |
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
