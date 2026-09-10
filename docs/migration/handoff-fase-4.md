# Handoff — continuar a migração a partir da FASE 4

> Documento para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-10, ao final da FASE 3.

---

## 1. Onde estamos

| Fase | Estado |
|---|---|
| 0 — Backup + auditoria + decisões | ✅ concluída |
| 1 — Esqueleto do backend Spring | ✅ concluída |
| 2 — Autenticação Firebase + `/api/v1/me` | ✅ concluída, **verificada end-to-end com token real** |
| 3 — Migração de dados (`users`/`pets`/`locations`) | ✅ concluída (rodada real: 11 users, 21 pets, 64 locations no Mongo) |
| **4 — Feature Tutor no app via API** | ⏭️ **próxima** |
| 5–13 | pendentes (ver seção 5) |

**Repositórios**
- App Flutter: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect` — `github.com/AleksGustavo/PetConnect`, branch de trabalho `feature/backend-spring-mongodb-migration`.
- Backend: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect-API` — `github.com/AleksGustavo/PetConnect-API` (privado), branch `main`.

**Documentos da migração** (no repo do app, `docs/`)
- `audit/current-state.md` · `database/firestore-current-schema.md` · `database/firestore-data-report.md` · `database/mongodb-target-schema.md` · `migration/firestore-to-spring-mongodb.md` (plano mestre, fase a fase) · `security/firestore-rules-deployed.md`.

---

## 2. Como subir o ambiente

Pré-requisito: **Docker** (a API **não** sobe via `mvn spring-boot:run` nesta máquina — ver seção 3, "loopback").

```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API"

# .env já existe (não versionado) apontando para o JSON do Firebase.
# Se sumir, recrie a partir de .env.example com:
#   FIREBASE_SA_PATH=C:/Users/Aleksander/Documents/pet-connect-c53f1-firebase-adminsdk-t8ctg-326661da99.json

docker compose up -d --build        # sobe mongo (27018) + api (8090)
docker compose logs -f api          # acompanhar
curl http://localhost:8090/api/v1/ping
```

| Serviço | Endereço |
|---|---|
| API | `http://localhost:8090` (container expõe 8080) |
| Swagger | `http://localhost:8090/swagger-ui.html` |
| MongoDB | `mongodb://localhost:27018/petconnect` (container `petconnect-mongo`) |

**Rodar os testes do backend** (fora do container, precisa JDK 21 + Maven; usa Mongo embarcado):
```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API" && mvn -q -B test
```

**Re-rodar a migração de dados** (idempotente — limpa `legacyImport=true` e reprocessa):
```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API"
MONGODB_URI="mongodb://localhost:27018/petconnect" \
  mvn -q -B spring-boot:run -Dspring-boot.run.profiles=dev,migration \
  "-Dspring-boot.run.arguments=--petconnect.migration.source=C:/Users/Aleksander/Documents/backup-firestore/firestore_backup.json"
```
(o perfil `migration` desliga o web server, então roda direto sem Docker.)

**Inspecionar o Mongo:**
```bash
docker exec -it petconnect-mongo mongosh "mongodb://localhost:27017/petconnect"
# db.users.countDocuments()  ->  11
# db.pets.countDocuments()   ->  21
# db.locations.countDocuments() -> 64
# db.migration_audit.aggregate([{$group:{_id:"$outcome",n:{$sum:1}}}])
```

---

## 3. Fatos e armadilhas importantes

- **Loopback / NIO Selector:** nesta máquina, `Selector.open()` falha (`Unable to establish loopback connection`, AF_UNIX). Isso quebra (a) a init do `firebase-admin` (contornado com `NetHttpTransport` no `FirebaseConfig`) e (b) o start do Tomcat (contornado rodando a API em **container Linux**). É a mesma raiz do erro de build do APK que ficou pendente. **Não tentar `mvn spring-boot:run` sem o perfil `migration`.**
- **Portas:** 8080 e 27017 do host costumam estar ocupadas por outros projetos do usuário → API em **8090**, Mongo em **27018**.
- **Firebase Storage está morto** (billing encerrado): as ~18 imagens legadas de users/pets viraram `photoUrl: null` + `migrationWarnings: ["storage-image-lost"]`. Só sobreviveram 2 fotos de usuário e 3 de pet (URLs Cloudinary). Upload novo já é Cloudinary (preset unsigned no app).
- **Credenciais:** o JSON do Firebase fica em `C:\Users\Aleksander\Documents\pet-connect-c53f1-firebase-adminsdk-t8ctg-326661da99.json` (fora dos repos). O `.gitignore` do backend bloqueia `*firebase*adminsdk*.json`, `*serviceAccountKey*.json`, `.env`, `application-local.yml`. **Nunca commitar.**
- **Firestore Rules atuais** são permissivas (banco todo legível sem login, `Localizacoes` com escrita pública) — ver `docs/security/firestore-rules-deployed.md`. Endurecer só na FASE 11 (não quebrar o app antigo que os 18 usuários usam).
- **`firebase_options.dart`** do app é gitignored. Web API key (para trocar custom token → ID token em testes e2e): `AIzaSyARaspdC-wNqVESmfVuJqPCg9wAbomoQrc`.
- **Chave canônica de usuário:** `firebaseUid`. `usuarioID`/`uid` legados → `users.legacyUsuarioId`. `Pets.dono` foi descartado.
- **`publicId` do pet** é determinístico (`UUID.nameUUIDFromBytes("pet:" + legacyFirestoreId)`) — re-rodar a migração não troca o QR.
- **Contas borderline mantidas:** "Marcola" (`VW9SSk…`) e "registro" (`4nMLz8…`). Se o usuário mandar remover, adicionar os docIds em `LegacyMigrationService.EXCLUDED_USER_IDS` e re-rodar.

---

## 4. FASE 4 — Feature **Tutor** no app via API (passo a passo)

Objetivo: a tela de perfil/configurações do app passa a ler/gravar o tutor pela API
(`GET`/`PATCH /api/v1/me`), atrás de um feature flag. **Login/cadastro/reset continuam
no Firebase Auth** — só o *documento de perfil* deixa de vir do Firestore.

### 4.1 Backend — nada novo a fazer
`GET`/`PATCH /api/v1/me` já existem e estão testados (`user/web/MeController.java`).
Se precisar de `DELETE /api/v1/me` (exclusão de conta, RF09) — ver 4.6.

### 4.2 Flutter — camada de rede
1. Criar `lib/core/network/api_client.dart`:
   - base URL por ambiente via `--dart-define=API_BASE_URL=...` (default dev: `http://10.0.2.2:8090` no emulador Android, `http://localhost:8090` no desktop/web).
   - `Dio` **ou** `http` (o projeto já usa `http` 1.6.0 — manter). Um wrapper com um interceptor que:
     - pega `await FirebaseAuth.instance.currentUser?.getIdToken()` e põe `Authorization: Bearer <token>`;
     - trata o envelope de erro `{timestamp,status,code,message}` → lança uma exceção tipada (`ApiException`) com `code`.
2. Criar `lib/core/config/app_config.dart` com as flags:
   - `useApiForUsuario` (bool, `--dart-define=USE_API_USUARIO=true`).

### 4.3 Flutter — `ApiUsuarioRepository`
1. `lib/features/usuario/data/api_usuario_repository.dart` implementando `UsuarioRepository`:
   - `watchUsuario(uid)` → não há stream na API. Opções: (a) `Stream.fromFuture(_getMe())` + um `Ref.invalidate` no pull-to-refresh; (b) trocar o tipo do repositório para `Future<Usuario>` numa refatoração menor. **Recomendado:** manter a assinatura, implementar como `Stream` de uma emissão só + expor um `refresh()`.
   - `signIn` / `signUp` / `sendPasswordReset` / `signOut` → **delegam para `FirebaseAuth`** (reaproveitar o código do `FirebaseUsuarioRepository`, ou compor: `ApiUsuarioRepository` recebe um `FirebaseAuth` e só sobrescreve o que toca no perfil).
     - No `signUp`: depois de `createUserWithEmailAndPassword`, chamar `GET /api/v1/me` uma vez (isso **provisiona** o `users` no Mongo). Passar `nome`/`telefone` num `PATCH /me` em seguida (a API hoje não recebe esses campos no provisionamento — o `displayName` do token vira `firstName`).
   - `updateUsuario({...})` → `PATCH /api/v1/me` com `{firstName,lastName,phone,birthDate,gender,photoUrl}`. Converter a data do formato de UI (`dd/MM/yyyy`) para ISO `yyyy-MM-dd` no envio; converter de volta na leitura.
   - `deleteAccount()` → ver 4.6.
2. Mapear `Usuario` (domínio do app) ↔ `UserResponse` (JSON da API). Campos:
   `id`←`firebaseUid` (ou `id`), `nome`←`firstName`, `sobrenome`←`lastName`, `email`, `telefone`←`phone`, `dataNascimento`← ISO→`dd/MM/yyyy`, `genero`←`gender` (MALE/FEMALE/OTHER/UNDISCLOSED → rótulos PT), `foto`←`photoUrl`.

### 4.4 Flutter — trocar o provider
Em `lib/features/usuario/presentation/providers/auth_providers.dart`:
- `usuarioRepositoryProvider` passa a devolver `ApiUsuarioRepository(...)` quando `AppConfig.useApiForUsuario`, senão o `FirebaseUsuarioRepository` atual.
- `currentUsuarioProvider` passa a combinar `authStateChanges` (Firebase) + `GET /me` (API) no lugar do doc do Firestore.

### 4.5 Testar e comparar
- Emulador Android → `--dart-define=API_BASE_URL=http://10.0.2.2:8090 --dart-define=USE_API_USUARIO=true`.
- Fluxos: cadastro novo (confirma que criou em `db.users`), editar perfil (nome/telefone/nascimento/gênero/foto), abrir Configurações, sair e entrar de novo.
- Comparar com a versão Firestore (flag desligada): mesmo comportamento visível.
- Atualizar os testes de widget que usam `FakeUsuarioRepository` (as assinaturas não mudam).

### 4.6 Exclusão de conta (RF09) — decidir nesta fase
Hoje `FirebaseUsuarioRepository.deleteAccount()` faz cascata manual (e incompleta) no Firestore + apaga o user do Auth. Na API:
- adicionar `DELETE /api/v1/me` no backend → soft delete (`users.deletedAt`) + cascata (`pets`, e futuramente vacinas/consultas/etc.) + apagar o user do Firebase Auth via Admin SDK.
- **Atenção:** o Admin SDK aqui usa `NetHttpTransport` (ok), mas confirmar que `auth.deleteUser` funciona no container.

### 4.7 Fechar a fase
- `flutter analyze` limpo, testes verdes.
- Commit na branch `feature/backend-spring-mongodb-migration`, PR, marcar FASE 4 no plano mestre.
- Flag `USE_API_USUARIO` fica **desligada** por padrão até a validação completa.

---

## 5. FASE 5 em diante (resumo — detalhe no plano mestre)

| Fase | Essência | Migração de dados? |
|---|---|---|
| 5 — Pets | `GET/POST/PATCH/DELETE /api/v1/pets` + `ApiPetRepository` + flag. Streams → carrega-ao-abrir + pull-to-refresh. Expor o novo campo `status`. | dados já migrados (21 pets) |
| 6 — Vacinas | só API + repositório no app | **não** (subcoleção vazia) |
| 7 — Consultas | idem; enum de status de 3→7 no backend, app pode manter 3 | **não** |
| 8 — Histórico médico | idem; upload de anexo segue unsigned no Cloudinary por ora | **não** |
| 9 — QR + página pública (RF17–19) | `GET /api/v1/public/pets/{publicId}` sem auth + `POST .../sightings` (grava `locations`); página web; app usa `publicId` real | `publicId` já existe |
| 10 — Upload assinado | backend assina Cloudinary (API secret em env) + `delete` deixa de ser no-op | — |
| 11 — Endurecer Firestore Rules | versionar `firestore.rules`; cortar leitura anônima; `Localizacoes write:false`; `read,write:false` nas coleções migradas | — |
| 12 — Settings + validação total | reescrever `auth_flow_test.dart`; e2e por feature; observação em prod | — |
| 13 — Remover Firestore | tirar `cloud_firestore`, apagar `firebase_*_repository.dart`, remover flags. `firebase_auth` **fica**. | export final arquivado |

---

## 6. Decisões / pendências abertas

- **CI:** não há GitHub Actions no `PetConnect-API` ainda. Sugerido: workflow que roda `mvn -B test` (Mongo embarcado já resolve).
- **Hospedagem staging:** MongoDB Atlas M0 + host free (Render/Railway/Fly/Koyeb) — só necessário quando for testar fora do localhost / publicar. Ainda não feito.
- **Ambiente que o app aponta:** enquanto for dev local no emulador, `http://10.0.2.2:8090`. Definir a URL de staging quando existir.
- **Contas borderline** "Marcola" e "registro": confirmar com o usuário se remove.
- **Validação amostral manual** da migração (FASE 3): conferir a olho ~5 registros Firestore↔Mongo. Feito 1 spot-check (Nymeria/Aleksander OK).
- **`auth_flow_test.dart`** ainda bate no Firebase real e está fora do CI — reescrever na FASE 12.
- **Erro do build do APK** (loopback) segue sem solução no lado Windows; não bloqueia a migração, mas o mesmo firewall/AV é a causa de a API precisar de container.
