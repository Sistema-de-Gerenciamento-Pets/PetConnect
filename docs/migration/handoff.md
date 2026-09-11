# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, ao final da FASE 9 (parcial — ver abaixo).

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
| 9 — QR + página pública | ✅ **parcial** — API pública verificada e2e (flag `USE_API_LOCALIZACAO` p/ o lado autenticado); página web e QR com URL real ficam pra quando houver hospedagem (usuário escolheu "só local por enquanto") |
| **10 — Upload assinado (Cloudinary)** | ⏭️ **próxima** — precisa de uma credencial nova (ver seção 5) |
| 11–13 | pendentes (ver seção 6) |

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

## 4. FASES 4–9 — o que ficou pronto (molde para as próximas)

- **Backend**: módulos `user/` (`/api/v1/me`), `pet/` (`/api/v1/pets`), `vaccine/`, `appointment/`, `medicalrecord/` (sub-recursos do pet), `location/` (sub-recurso autenticado **e** os 2 endpoints públicos). `PetService.get(tutorId, petId)` é a checagem de posse reutilizável. `PetService.delete` cascateia em **todos**: locations, vaccines, appointments, medical_records.
- **App**: `lib/core/` (`ApiClient`, `ApiException`, `AppConfig`, `br_date.dart` com `brToIso`/`isoToBr`); `Api{Usuario,Pet,Vacina,Consulta,HistoricoMedico,Localizacao}Repository`; providers condicionais pelas flags `USE_API_USUARIO`/`USE_API_PETS`/`USE_API_VACINAS`/`USE_API_CONSULTAS`/`USE_API_HISTORICO`/`USE_API_LOCALIZACAO`.
- **Padrões estabelecidos** (copiar na FASE 10):
  - Repositório de API: `watch*` = `Stream.fromFuture` (emissão única); tela invalida o provider após mutar; listas com pull-to-refresh (inclusive no estado vazio).
  - Mapeamento `dd/MM/yyyy` ↔ ISO (`brToIso`/`isoToBr`) e rótulos PT ↔ enums (mapas estáticos no repositório). Horário `HH:mm` ↔ `HH:mm:ss` (`LocalTime` do Jackson).
  - Backend: sub-recurso do pet → `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`, `service.list/create/update(me.userId(), petId, ...)` sempre começando por `petService.get(tutorId, petId)` (404 se não for do tutor) + `ownedOr404(petId, subId)`. DTO com Bean Validation. Cascata em `PetService.delete`. Nem todo sub-recurso precisa de `DELETE` (consultas não têm).
  - Endpoint **público** (sem auth): path sob `/api/v1/public/**`, acrescentado tanto em `SecurityConfig.PUBLIC_PATHS` quanto em `FirebaseTokenAuthenticationFilter.shouldNotFilter` (senão um Bearer inválido enviado por engano derruba a rota pública com 401 antes de chegar no controller). DTO de resposta público é sempre um subconjunto mínimo — nunca `tutorId`/e-mail/telefone pessoal.
  - Campo opcional "data escolhida pelo usuário, senão agora": `LocalDate` opcional no request; serviço faz `req.data() == null ? Instant.now() : req.data().atStartOfDay(ZoneOffset.UTC).toInstant()`. **Só para o lado autenticado** — o endpoint público sempre usa "agora" (evita abuso de backdating anônimo).
  - `GlobalExceptionHandler` cobre `HttpRequestMethodNotSupportedException`→405 e `NoHandlerFoundException`/`NoResourceFoundException`→404.
  - Teste de controller: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier` (rotas autenticadas) ou nenhum mock (rotas públicas — não enviar `Authorization`), users/pets salvos direto no repo, `com.jayway.jsonpath.JsonPath.read` para pegar ids.
  - e2e: script no scratchpad (molde `e2e-fase9.js`) — token real de um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3`; o pet "Felícia" tem 5 avistamentos migrados, bom pra testar listagem), CRUD, 404 cross-tenant, limpeza.
- **Pendente do usuário:** rodar no device com as flags ligadas e comparar com elas off (Firestore); decidir hospedagem para fechar a FASE 9 (página pública + URL real do QR).

---

## 5. FASE 9 — o que falta (não bloqueia a FASE 10)

Decisão do usuário: **"só local por enquanto"**. A API pública está pronta e testada (ver
seção 4). Quando houver hospedagem, falta:

1. Escolher o domínio/host (Render/Railway/Fly/Koyeb ou outro).
2. Página web pública em `https://<domínio>/p/{publicId}` — servir do próprio backend
   (Spring MVC/Thymeleaf, ou um HTML estático simples) é mais fácil de hospedar junto da API
   do que separar em outro serviço.
3. `pet_qr_code.dart` (app): trocar `publicPetUrl` pra usar `pet.publicId` (já vem da API,
   ver `ApiPetRepository` — exposto como `qrCodeId`) + o domínio real.
4. Avaliar se RF19 (regenerar QR) entra junto — hoje `publicId` é fixo no `Pet`; regenerar
   exigiria um `POST /api/v1/pets/{id}/qr-code/regenerate`.
5. Rate limiting nos 2 endpoints públicos antes de expor de verdade (hoje sem proteção —
   aceitável enquanto só local/testes).

---

## 6. FASE 10 — Upload assinado (Cloudinary) (passo a passo)

Hoje o app sobe imagens direto pro Cloudinary com um **upload preset unsigned** (`cloud name`
+ `preset` — não são segredos, é o modelo do Cloudinary pra apps sem backend). O problema é só
um: **`AnexoRepository.delete()` é um no-op documentado** — apagar de verdade no Cloudinary
exige uma requisição **assinada** com a **API secret** da conta, que não pode ficar no app
(seria extraída do APK). Isso deixa arquivo órfão toda vez que uma foto é trocada/removida.

### 6.0 Precisa de uma credencial nova

A **Cloudinary API secret** (diferente do cloud name/preset, que já estão em
`lib/core/config/cloudinary_config.dart` e não são sensíveis). Pegar em
https://console.cloudinary.com → Dashboard → "API Secret" (botão "reveal"). É segredo de
verdade — só vai pro backend, via env var (`.env`/`compose.yaml`, mesmo padrão da chave do
Firebase), **nunca** no app nem no git.

### 6.1 Backend — módulo `upload` (ou dentro de `shared`)

Duas abordagens, escolher uma:

- **A — assinatura (recomendada, menos tráfego no servidor):** `POST /api/v1/uploads/signature`
  (autenticado) devolve `{signature, timestamp, apiKey, cloudName}` calculados com a API
  secret; o app sobe o arquivo **direto pro Cloudinary** como já faz, só que assinado em vez
  de unsigned. `DELETE /api/v1/uploads?publicId=...` (ou recebendo a URL e extraindo o
  `public_id`) assina e chama `https://api.cloudinary.com/v1_1/{cloud}/image/destroy`.
- **B — proxy total:** `POST /api/v1/uploads` recebe o arquivo (multipart) e o backend repassa
  pro Cloudinary. Mais simples de auditar/limitar, mas duplica o tráfego do arquivo.

Detalhe técnico da assinatura Cloudinary: SHA1 de `paramName1=value1&paramName2=value2...timestamp=...&{api_secret}` (parâmetros em ordem alfabética, sem o `api_secret` no meio, só concatenado no fim). Testar contra a doc oficial antes de confiar de olho.

### 6.2 App — `ApiAnexoRepository` (ou ajustar `CloudinaryAnexoRepository`)

1. `upload()`: pedir a assinatura em `/api/v1/uploads/signature` antes do multipart pro
   Cloudinary (troca o `upload_preset` unsigned pelos parâmetros assinados).
2. `delete()`: deixa de ser no-op — chama `DELETE /api/v1/uploads` no backend.
3. Flag `USE_API_UPLOAD_ASSINADO` (ou reaproveitar sem flag, já que é transparente pra UI —
   decidir se vale a pena o feature flag aqui ou se troca direto, já que não muda
   comportamento visível pro usuário).
4. `cloudinary_config.dart` no app perde razão de ter o preset **unsigned** — mantém só o que
   ainda for necessário (cloud name, se o app precisar montar URLs de exibição).

### 6.3 Fechar
- Exclusão de conta/pet/histórico passa a limpar imagens órfãs de verdade (chamar `delete()`
  no lugar onde hoje é no-op).
- `flutter analyze` limpo, `mvn -B test` verde.
- e2e: assinar, subir um arquivo de teste, confirmar no Cloudinary (dashboard ou API) que
  existe, chamar `delete`, confirmar que sumiu.
- Commit, marcar FASE 10 no plano mestre e aqui.

---

## 8. FASE 11+ (resumo — detalhe no plano mestre)

| Fase | Essência | Migração de dados? |
|---|---|---|
| 11 — Endurecer Firestore Rules | versionar `firestore.rules`; cortar leitura anônima; `read,write:false` nas coleções migradas | — |
| 12 — Settings + validação total | reescrever `auth_flow_test.dart`; e2e por feature | — |
| 13 — Remover Firestore | tirar `cloud_firestore`, apagar `firebase_*_repository.dart`, remover flags. `firebase_auth` fica. | export final arquivado |

---

## 9. Pendências abertas

- **FASE 9:** página pública + URL real do QR — precisa de hospedagem (ver seção 5).
- **Rate limiting** nos endpoints públicos (`/api/v1/public/**`) — antes de expor de verdade.
- **CI do backend:** não há GitHub Actions ainda. Sugerido: workflow `mvn -B test`.
- **Hospedagem staging:** MongoDB Atlas M0 + host free — só quando for testar fora do localhost.
- **Validação amostral manual** da FASE 3: 1 spot-check feito (Nymeria/Aleksander OK); conferir mais alguns.
- **Contas borderline** "Marcola"/"registro": confirmar remoção com o usuário.
- **`auth_flow_test.dart`** ainda bate no Firebase real, fora do CI — reescrever na FASE 12.
- **APK de release** (loopback) segue sem solução no Windows; não bloqueia a migração.
- **FASE 4 no device**: validação final do usuário pendente.
