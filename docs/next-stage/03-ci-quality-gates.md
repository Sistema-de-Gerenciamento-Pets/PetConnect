# 03 — CI/CD e Quality Gates

> Workflows criados e **verificados rodando de verdade no GitHub Actions**
> (não só escritos — cada resultado abaixo foi observado via `gh run watch`
> contra uma execução real).

---

## Status atual

| Gate | Repositório | Estado |
|---|---|---|
| `dart format` (lib+test) | PetConnect | ✅ **PASS** (verificado no Actions) |
| `flutter analyze` | PetConnect | ✅ **PASS** (verificado no Actions) |
| `flutter test` (unit/widget) | PetConnect | ✅ **PASS** — 25 testes (verificado no Actions) |
| Backend build (`mvn test`, compila) | PetConnect-API | ✅ **PASS** (verificado no Actions) |
| Backend testes | PetConnect-API | ✅ **PASS** — 72 testes (verificado no Actions) |
| Security tests (rate limit, isolamento por tutor, auth) | PetConnect-API | ✅ **PASS** — fazem parte dos 72 (`PublicEndpointRateLimitFilterTest`, `*ControllerTest` com casos `semTokenRetorna401`, `naoAcessaXDeOutroTutor`) |
| Auth E2E (`auth_flow_test.dart`) | PetConnect | 🔴 **BLOCKED** — diagnóstico completo abaixo |

---

## Workflows criados

- `PetConnect/.github/workflows/ci.yml` — job `flutter`.
- `PetConnect-API/.github/workflows/ci.yml` — job `backend`.

Ambos disparam em `push` (qualquer branch) e `pull_request`, com
`concurrency` pra cancelar execuções redundantes do mesmo branch.

### O que cada um faz

**Flutter** (`ubuntu-latest`):
```
checkout → subosito/flutter-action@v2 (Flutter 3.47.0, cache) →
flutter pub get → dart format --set-exit-if-changed lib test →
flutter analyze → flutter test test/core/ test/features/pet/
```

**Backend** (`ubuntu-latest`):
```
checkout → actions/setup-java@v5 (Temurin 21, cache maven) →
mvn -B test → upload-artifact (surefire-reports, sempre, mesmo se falhar)
```

Nenhum dos dois workflows usa dado real nem credencial de produção — o
Flutter só roda testes com repositórios falsos (`fake_*_repository.dart`);
o backend usa Mongo **embarcado** (flapdoodle), não aponta pra nenhum
Atlas/Mongo real.

### Achado real do primeiro run (não hipotético — apareceu rodando de verdade)

O primeiro push do workflow do Flutter **falhou** em `flutter analyze`:
`lib/firebase_options.dart` estava no `.gitignore` e nunca tinha sido
commitado — um checkout limpo (exatamente o que o CI faz) não compila,
porque `main.dart` e `auth_flow_test.dart` importam esse arquivo. Isto
não é um problema introduzido por esta etapa — é uma lacuna pré-existente
que só o CI (um ambiente que realmente faz checkout limpo) conseguiu
revelar; localmente o arquivo sempre existia (gerado uma vez pelo
FlutterFire CLI e nunca apagado do disco).

**Correção aplicada**: commitado `lib/firebase_options.dart`, removida a
entrada do `.gitignore`. Justificativa: o arquivo contém só API keys
client-side do Firebase (web/android/iOS), que **já são públicas por
design** — vão para o bundle/APK de qualquer app compilado, independente
de estarem ou não no repositório Git. A proteção real do projeto é via
Firestore Security Rules + verificação de ID Token no backend, nunca por
esconder essas chaves — isso já estava documentado em
`docs/seguranca.md` antes desta mudança, só nunca tinha sido aplicado ao
`.gitignore`. Confirmado manualmente que o arquivo não contém nenhuma
credencial de servidor (Admin SDK, API secret, etc.) antes de commitar.

---

## Auth E2E (`auth_flow_test.dart`) — diagnóstico completo do bloqueio

### O que já foi resolvido (sessões anteriores + esta)

1. O teste foi **reescrito** para não tocar infraestrutura de produção:
   Firebase Auth Emulator (não o projeto real) + API/Mongo reais via
   `USE_API_USUARIO=true` (não o Firestore).
2. Validado isoladamente, fora do harness de teste em navegador: o Auth
   Emulator sobe e responde; um token emitido por ele é aceito de ponta a
   ponta pela API real (`GET`/`DELETE /api/v1/me` via `curl`).
3. Tentado um contorno em container Linux nesta máquina de dev
   (`tool/web-test/Dockerfile`) — resolveu o travamento original (bug de
   loopback do Windows) mas achou um bloqueio diferente (SDK JS do
   Firebase preso em `setUpAll`, suspeita de IndexedDB/storage num Chrome
   `--no-sandbox` como root). Ver `docs/migration/handoff.md`, seção 3.

### O que falta pra rodar em CI — e por que não fiz agora

`flutter test --platform=chrome` em `ubuntu-latest` **não deveria** ter o
bug de loopback do Windows nem a peculiaridade do Chrome-em-container desta
máquina — é um ambiente limpo, é o caminho que a maioria dos projetos
Flutter usa pra isso. **Mas** o teste também precisa da **API Spring Boot
rodando** (`USE_API_USUARIO=true` bate em `http://localhost:8090/api/v1`),
e a API vive num **repositório privado separado**
(`PetConnect-API`) do repositório onde o CI do Flutter roda
(`PetConnect`).

Isso é um problema de **acesso entre repositórios**, não um problema
técnico do teste em si:

- O `GITHUB_TOKEN` automático de um workflow só tem acesso ao repositório
  onde ele roda. Ele **não pode** fazer checkout/pull de imagem de
  `PetConnect-API` (privado) de dentro do workflow de `PetConnect`.
- Pra resolver isso, existem 3 caminhos, todos exigindo uma **decisão do
  usuário** (por isso não escolhi nenhum sozinho — nenhum é puramente
  técnico):

| Opção | Como funciona | O que precisa ser decidido |
|---|---|---|
| **A. PAT (Personal Access Token) de leitura entre repos** | Criar um token com permissão só de leitura em `PetConnect-API`, salvar como secret (`API_REPO_PAT`) no repo `PetConnect`, e usar em `actions/checkout` com `repository: AleksGustavo/PetConnect-API` + `token: ${{ secrets.API_REPO_PAT }}` | Quem cria o token (idealmente uma conta de serviço, não uma conta pessoal), qual o escopo exato, e a responsabilidade de rotacioná-lo |
| **B. Imagem Docker publicada no GHCR** | O CI do backend builda e publica a imagem em `ghcr.io/.../petconnect-api`; o CI do Flutter só faz `docker pull` | Se o pacote/imagem fica **público** (mais simples, sem token) ou **privado** (precisa do mesmo tipo de token da opção A, só que pra `packages:read`) |
| **C. Monorepo** | Unificar os dois repositórios em um só, CI passa a ter acesso nativo a ambos | Mudança estrutural grande, fora do escopo de "não pular etapas" — desencorajado pelo próprio plano de execução ("não reconstruir o app") |

Além disso, mesmo resolvendo o acesso entre repos, a API **ainda precisa
de uma credencial do Firebase Admin SDK** pra inicializar
(`FIREBASE_SERVICE_ACCOUNT`) — path técnico plausível e de baixo risco:
gerar uma credencial **sintética** (par de chaves RSA gerado só pra CI,
não ligado a nenhuma conta Google real) só pra satisfazer o parsing do
SDK, já que em modo `FIREBASE_AUTH_EMULATOR_HOST` a verificação de token
não faz handshake real com o Google. Isto **não foi testado ainda** — é
uma hipótese técnica razoável, não um fato confirmado, e só vale a pena
tentar depois que a opção A/B/C acima for escolhida.

### Recomendação

**Opção A (PAT com escopo mínimo, só leitura, só neste repo)** é a mais
simples de configurar e a mais comum pra este cenário (dois repos do
mesmo dono, um privado). Ação necessária do usuário: gerar o token em
GitHub → Settings → Developer settings → Personal access tokens
(fine-grained, acesso restrito a `PetConnect-API`, permissão `Contents:
read` apenas) e me passar o nome do secret depois de configurado (não o
valor do token).

### Por que não decidi isso sozinho

O próprio prompt de execução lista como *stop condition* explícita:
"necessidade de API Secret que não existe localmente" — este caso se
qualifica (não existe hoje nenhum PAT/imagem publicada, e criar um dos
dois é uma decisão de superfície de acesso, não uma escolha
puramente técnica). Continuo com o restante das etapas independentes
enquanto isso não é decidido.
