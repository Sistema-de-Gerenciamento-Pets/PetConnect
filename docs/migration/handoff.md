# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, no meio da FASE 11 (passo 1 deployado e verificado em produção).

---

## 1. Onde estamos

| Fase | Estado |
|---|---|
| 0 — Backup + auditoria + decisões | ✅ |
| 1 — Esqueleto do backend Spring | ✅ |
| 2 — Auth Firebase + `/api/v1/me` | ✅ verificada e2e |
| 3 — Migração de dados (`users`/`pets`/`locations`) | ✅ rodada real: 11 users, 21 pets, 64 locations |
| 4 — Feature **Tutor** via API | ✅ verificada e2e (flag `USE_API_USUARIO`) |
| 5 — Feature **Pets** via API | ✅ verificada e2e (flag `USE_API_PETS`) |
| 6 — Feature **Vacinas** | ✅ verificada e2e (flag `USE_API_VACINAS`) |
| 7 — Feature **Consultas** | ✅ verificada e2e (flag `USE_API_CONSULTAS`) |
| 8 — Feature **Histórico Médico** | ✅ verificada e2e (flag `USE_API_HISTORICO`) |
| 9 — QR + página pública | ✅ **parcial** — API pública ok (flag `USE_API_LOCALIZACAO` no lado autenticado); página web + URL real do QR pendentes de hospedagem (usuário: "só local por enquanto") |
| 10 — Upload assinado (Cloudinary) | ✅ **código pronto e testado** (flag `USE_API_UPLOAD`); round-trip real pendente da API Secret do usuário |
| **11 — Endurecer Firestore Rules** | 🚧 **em andamento** — passo 1 deployado e verificado (ver seção 5) |
| 12–13 | pendentes (ver seção 6) |

Todas as flags default **off** — sem `--dart-define`, o app roda 100% Firebase, como sempre.

**Repositórios**
- App Flutter: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect` — `github.com/AleksGustavo/PetConnect`, branch `feature/backend-spring-mongodb-migration`.
- Backend: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect-API` — `github.com/AleksGustavo/PetConnect-API` (privado), branch `main`.

**Docs da migração** (repo do app, `docs/`): `audit/current-state.md` · `database/{firestore-current-schema,firestore-data-report,mongodb-target-schema}.md` · `migration/firestore-to-spring-mongodb.md` (plano mestre, fonte da verdade fase a fase) · `security/firestore-rules-deployed.md` · este `handoff.md`.

---

## 2. Como subir o ambiente

Pré-requisito: **Docker** (a API não sobe via `mvn spring-boot:run` direto nesta máquina — ver seção 3).

```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API"
docker compose up -d --build        # mongo (27018) + api (8090)
docker compose logs -f api
curl http://localhost:8090/api/v1/ping
```

Depois de mudar código do backend: `docker compose up -d --build api` (se o build falhar por
tropeço de download do Maven, é transiente — repetir).

| Serviço | Endereço |
|---|---|
| API | `http://localhost:8090` (Swagger em `/swagger-ui.html`) |
| MongoDB | `mongodb://localhost:27018/petconnect` |

**Rodar o app com a API:**
```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect"
adb reverse tcp:8090 tcp:8090   # celular por USB
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8090 \
  --dart-define=USE_API_USUARIO=true --dart-define=USE_API_PETS=true \
  --dart-define=USE_API_VACINAS=true --dart-define=USE_API_CONSULTAS=true \
  --dart-define=USE_API_HISTORICO=true --dart-define=USE_API_LOCALIZACAO=true \
  --dart-define=USE_API_UPLOAD=true
```
- Emulador Android: `--dart-define=API_BASE_URL=http://10.0.2.2:8090` (sem `adb reverse`).
- Sem nenhum `--dart-define`: 100% Firebase.

**Testes**
```bash
# backend (JDK 21 + Maven, Mongo embarcado): 68 testes
cd "…/PetConnect-API" && mvn -q -B test
# app: flutter analyze + 25 testes
cd "…/PetConnect"     && flutter analyze && flutter test test/core/ test/features/pet/
```

**Re-rodar a migração** (idempotente):
```bash
cd "…/PetConnect-API"
MONGODB_URI="mongodb://localhost:27018/petconnect" \
  mvn -q -B spring-boot:run -Dspring-boot.run.profiles=dev,migration \
  "-Dspring-boot.run.arguments=--petconnect.migration.source=C:/Users/Aleksander/Documents/backup-firestore/firestore_backup.json"
```

**e2e contra a API real** (padrão usado em todas as fases — molde em
`C:\Users\ALEKSA~1\AppData\Local\Temp\claude\...\scratchpad\e2e-fase*.js`, que não sobrevive
entre sessões — recriar quando precisar): script Node usando `firebase-admin` (o mesmo
`node_modules` de `C:\Users\Aleksander\Documents\backup-firestore\`) pra mintar um custom token
de um uid, trocar por ID token real via `identitytoolkit.googleapis.com`, e bater na API com
`fetch`. Rodar sempre **de dentro** da pasta com `node_modules` (copiar o script pra lá
temporariamente e apagar depois).

---

## 3. Fatos e armadilhas

- **Loopback / NIO Selector:** nesta máquina `Selector.open()` falha (`Unable to establish loopback connection`, AF_UNIX). Quebra (a) init do `firebase-admin` — contornado com `NetHttpTransport` no `FirebaseConfig` — e (b) start do Tomcat — contornado rodando a API em **container Linux** (`CloudinaryHttpClient` também usa `SimpleClientHttpRequestFactory` por cautela, embora dentro do container isso não seja necessário). `flutter run` para device **funciona** (só o APK de release e servidor Java direto no Windows são afetados).
- **Portas:** 8080/27017 do host costumam estar ocupadas → API em **8090**, Mongo em **27018**.
- **Firebase Storage morto** (billing encerrado): 18 imagens legadas viraram `photoUrl: null` + aviso `storage-image-lost`. Só sobrevivem URLs Cloudinary (2 users, 3 pets).
- **Credencial Firebase:** `C:\Users\Aleksander\Documents\pet-connect-c53f1-firebase-adminsdk-t8ctg-326661da99.json` (fora dos repos). Montada read-only no container via `.env` (`FIREBASE_SA_PATH`).
- **Credencial Cloudinary (nova, FASE 10):** falta `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` — pegar em https://console.cloudinary.com → Dashboard. Adicionar no `.env`/`compose.yaml` do backend (mesmo padrão da chave do Firebase — nunca no git). Sem isso, `/api/v1/uploads/**` responde 503 `UPLOAD_NOT_CONFIGURED` (verificado, não quebra o resto da API).
- **Firestore Rules atuais** são permissivas (banco todo legível sem login, `Localizacoes` com escrita pública) — texto completo em `docs/security/firestore-rules-deployed.md`. Endurecer é a FASE 11 (seção 5).
- **Web API key** (trocar custom token → ID token em e2e): `AIzaSyARaspdC-wNqVESmfVuJqPCg9wAbomoQrc`.
- **Feature flags** (`lib/core/config/app_config.dart`): `USE_API_USUARIO`, `USE_API_PETS`, `USE_API_VACINAS`, `USE_API_CONSULTAS`, `USE_API_HISTORICO`, `USE_API_LOCALIZACAO`, `USE_API_UPLOAD` — todas default `false`. Mais `API_BASE_URL`.
- **`publicId` do pet** é determinístico na migração (`UUID.nameUUIDFromBytes("pet:" + legacyFirestoreId)`) — não muda entre re-execuções da migração.
- **Contas borderline mantidas:** "Marcola" (`VW9SSk…`) e "registro" (`4nMLz8…`). Remover = adicionar em `LegacyMigrationService.EXCLUDED_USER_IDS` e re-rodar a migração.
- **Nota de segurança residual (FASE 10):** `DELETE /api/v1/uploads` não verifica posse do arquivo — qualquer usuário autenticado pode pedir a exclusão de qualquer URL Cloudinary da conta. Antes disso ninguém conseguia excluir nada; agora exige pelo menos login. Uma tabela de "quem subiu o quê" resolveria de vez — não implementada (escopo maior que o da fase).

---

## 4. Padrões estabelecidos (copiar nas próximas fases)

- **Repositório de API** (app): `watch*` = `Stream.fromFuture` (a API não tem stream); a tela invalida o provider (`ref.invalidate(xProvider(id))`) depois de criar/editar/excluir; listas com pull-to-refresh (`RefreshIndicator` + `AlwaysScrollableScrollPhysics`, inclusive no estado vazio).
- **Mapeamento**: `dd/MM/yyyy` ↔ ISO via `brToIso`/`isoToBr` (`lib/core/utils/br_date.dart`); `HH:mm` ↔ `HH:mm:ss` (`LocalTime` do Jackson); rótulos PT ↔ enum via `Map` estático no repositório.
- **Backend, sub-recurso do pet**: `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`; todo método do `Service` começa chamando `petService.get(tutorId, petId)` (404 se o pet não é do tutor) + um `ownedOr404(petId, subId)` próprio pro sub-recurso. DTO de request com Bean Validation. `@DeleteMapping` → 204. Cascata em `PetService.delete` (nem todo sub-recurso tem `DELETE` próprio — ex.: consultas, cancelar é status).
- **Endpoint público** (sem auth): path sob `/api/v1/public/**`; entra em **dois** lugares — `SecurityConfig.PUBLIC_PATHS` **e** `FirebaseTokenAuthenticationFilter.shouldNotFilter` (senão um `Bearer` inválido enviado por engano derruba a rota com 401 antes do controller). Resposta é sempre um DTO mínimo — nunca `tutorId`/e-mail/telefone pessoal.
- **Módulo sem entidade própria** (ex.: `upload/`): só `web/`+`application/`, sem `domain/`+`infrastructure/`. Chamada de saída de verdade (Cloudinary, etc.) isolada atrás de uma interface (`CloudinaryClient`) pra poder mockar em teste de controller.
- **Segredo novo → `503` gracioso**: uma feature que depende de credencial externa ainda não configurada nunca deve 500 nem vazar detalhe — `props.isConfigured()` + `ApiException` com um código específico (`UPLOAD_NOT_CONFIGURED`) e HTTP `503`.
- **`GlobalExceptionHandler`** cobre `HttpRequestMethodNotSupportedException`→405, `NoHandlerFoundException`/`NoResourceFoundException`→404, além do `ApiException`/validação/auth já cobertos desde a FASE 2.
- **Teste de controller**: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier` (rotas autenticadas — omitir em rotas públicas) + `@MockitoBean` de qualquer client externo (`CloudinaryClient`); usuários/pets salvos direto no repositório no `@BeforeEach`; `com.jayway.jsonpath.JsonPath.read(body, "$.id")` pra pegar ids de uma resposta.
- **Teste unitário puro** (sem `@SpringBootTest`, mais rápido) para lógica sem I/O — ex. `CloudinarySignerTest`/`CloudinaryUrlParserTest`. Vetores de referência conferidos rodando a mesma conta num script Node (`crypto.createHash`) antes de hard-codar no teste Java.
- **e2e**: sempre contra a API rodando de verdade (container), nunca só os testes automatizados — pegar um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3`, pet "Felícia" tem 5 avistamentos migrados) ou criar um usuário de teste efêmero, e sempre limpar no final.

---

## 5. FASE 11 — Endurecer Firestore Rules (em andamento)

Diferente das fases anteriores, esta mexe no **Firestore**, não no backend novo — é a fase
onde o risco de quebrar o app antigo (que os 18 usuários reais ainda usam) é real. Por isso:
antes de cada mudança, parei e confirmei com o usuário; depois de deployar, verifiquei via
REST (anônimo vs. autenticado) em vez de só confiar que "deve ter funcionado".

### 5.1 Passo 1 — ✅ feito e verificado (2026-09-11)
- `firestore.rules` criado na raiz do repo do app + referenciado em `firebase.json` (antes só
  existia como texto colado no console/chat).
- Catch-all, `Pets` e `Localizacoes` passaram a exigir `request.auth != null` — fechou só o
  acesso **sem nenhum login**; nada que já exigia auth mudou de comportamento.
- **Antes de mexer em `Localizacoes` write**, perguntei ao usuário se ainda havia algum fluxo
  público real (página/Cloud Function) escrevendo lá — confirmado que não, então já fechei a
  escrita também (não só a leitura).
- Deploy: `firebase deploy --only firestore:rules --project pet-connect-c53f1` (CLI já estava
  autenticado nesta máquina). **Só rodei depois de confirmação explícita do usuário** — é uma
  mudança em produção, diferente de tudo que veio antes (containers/testes locais).
- Verificação pós-deploy (script no scratchpad, sem precisar do app): `GET` anônimo em
  `Pets`/`Localizacoes` → `403 PERMISSION_DENIED` (antes: 200); com um ID Token real → `200`
  continua igual (leitura do próprio `Usuarios`, query em `Pets`).
- Histórico completo (regra antiga vs. nova, análise) em `docs/security/firestore-rules-deployed.md`.

### 5.2 O que falta (nenhuma urgência — sem uso real dependendo disso)
1. `Localizacoes` → `write: if false` de vez (hoje só exige login; como não há mais uso real,
   dá pra travar de vez sem pedir confirmação de novo — é uma continuação do que já foi
   decidido, não uma decisão nova).
2. **Só depois que as FASES 4–10 estiverem validadas em uso real** (não só e2e — alguém de
   verdade usando o app com as flags ligadas por um tempo): `allow read, write: if false` em
   `Usuarios`/`Pets` (as coleções que já têm equivalente 100% funcional na API).
3. Rate limiting/CORS/headers de segurança no backend — ainda **nada** disso existe, nem nos
   endpoints públicos da FASE 9 (que hoje aceitam qualquer volume de requisição anônima).
4. Checklist final: nenhum segredo no repo (app ou backend) — `git log` de ambos limpo.

### 5.3 Lição pra próxima vez que mexer em regras de produção
Sempre: (a) confirmar com o usuário a suposição de que "nada real depende disso" antes de
restringir algo que hoje é público — não presumir; (b) pedir confirmação explícita antes do
`firebase deploy` em si, separada da confirmação de "seguir com a fase"; (c) verificar
depois via requisição real (autenticada e anônima), não só "deployou sem erro".

---

## 6. FASES 12-13 (resumo — detalhe no plano mestre)

| Fase | Essência |
|---|---|
| 12 — Settings + validação total | reescrever `auth_flow_test.dart` (hoje bate no Firebase real, fora do CI); e2e por feature; período de observação com as flags ligadas em uso real antes de seguir |
| 13 — Remover Firestore | só depois de tudo validado em produção por um tempo: tirar `cloud_firestore` do `pubspec.yaml`, apagar `firebase_*_repository.dart` e as flags (tudo passa a usar só `Api*Repository`). `firebase_auth` **fica** (é a fonte de identidade pra sempre). |

---

## 7. Pendências abertas

- **FASE 9:** página pública + URL real do QR — precisa de hospedagem (domínio/host).
- **FASE 10:** `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` reais — sem isso o round-trip de upload assinado não foi testado contra o Cloudinary de verdade (só o código + os 503 graciosos).
- **FASE 11:** `Localizacoes.write` ainda exige só login (não `if false` de vez); endurecimento final (`Usuarios`/`Pets` → `if false`) espera uso real validado; rate limiting nos endpoints públicos ainda não existe.
- **CI do backend:** não há GitHub Actions ainda. Sugerido: workflow `mvn -B test`.
- **Hospedagem staging:** MongoDB Atlas M0 + host free — só quando for testar fora do localhost.
- **Validação amostral manual** da FASE 3: 1 spot-check feito (Nymeria/Aleksander OK); conferir mais alguns.
- **Contas borderline** "Marcola"/"registro": confirmar remoção com o usuário.
- **`auth_flow_test.dart`** ainda bate no Firebase real, fora do CI — reescrever na FASE 12.
- **APK de release** (loopback) segue sem solução no Windows; não bloqueia a migração (`flutter run` pra device funciona).
- **Validação no device**: nenhuma das flags foi testada de verdade no celular do usuário ainda — só e2e via script contra a API. Vale rodar com todas ligadas numa sessão e comparar com o Firestore.
