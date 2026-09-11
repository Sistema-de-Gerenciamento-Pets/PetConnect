# 01 — Auditoria de Baseline

> Gerado em 2026-09-11 12:17 (horário local da máquina de desenvolvimento),
> antes de qualquer alteração desta etapa. Registra o estado real dos dois
> repositórios — não "corrige" nada, só documenta.

---

## Repositório: PetConnect (Flutter)

| Item | Valor |
|---|---|
| Branch | `feature/backend-spring-mongodb-migration` |
| Working tree | limpo (nada não commitado) |
| Último commit | `4a7122b` — chore(test): contorno em container pra flutter test --platform=chrome (parcial) |
| Remote | `origin` → `https://github.com/AleksGustavo/PetConnect.git` (aviso do GitHub: repo movido para `Sistema-de-Gerenciamento-Pets/PetConnect`, push pelo remote antigo ainda funciona via redirect) |
| Flutter | 3.47.0 (stable) |
| Dart | 3.13.0 |
| Maven Wrapper / workflows CI | não se aplica (é o repo Flutter) |
| `.github/workflows/` | **não existe** |

### Comandos executados

```bash
git status              # limpo
git branch --show-current
git log -5 --oneline
flutter --version
flutter pub get         # OK — "Got dependencies!"
flutter analyze         # OK — "No issues found!"
dart format --output=none --set-exit-if-changed lib test
flutter test test/core/ test/features/pet/
```

### Resultados

- **`flutter pub get`**: ok. 53 pacotes têm versão mais nova disponível mas
  incompatível com as constraints atuais do `pubspec.yaml` — normal, não é
  um problema por si só (ver seção 17, auditoria de dependências).
- **`flutter analyze`**: **0 issues**.
- **`dart format --set-exit-if-changed lib test`**: **61 de 92 arquivos
  precisariam de reformatação** para passar num gate estrito de formatação.
  Isso é uma dívida de estilo acumulada ao longo das fases anteriores (o
  código funciona e passa em `analyze`, só não está com a formatação
  canônica do `dart format`). **Não corrigido nesta etapa de baseline** —
  decisão registrada na seção de CI (aplicar `dart format` de uma vez é uma
  mudança grande e "barulhenta" no diff; ver `03-ci-quality-gates.md` para
  a decisão tomada).
- **Rodando `dart format` na raiz do repo (sem escopo)**: falha com
  `PathNotFoundException` — o formatter tenta varrer `build/` (artefatos de
  build do Android/Firestore, caminho quebrado/muito longo). **Sempre
  escopar `dart format`/`flutter analyze` a `lib` e `test`**, nunca rodar na
  raiz do repo — isto será refletido no workflow de CI.
- **`flutter test test/core/ test/features/pet/`**: **25/25 passando**, ~34s.
- **`test/features/auth/auth_flow_test.dart`**: **não incluído** na suíte
  acima de propósito — depende de infraestrutura externa (Auth Emulator +
  API rodando) e ainda não passa nesta máquina (ver `03-ci-quality-gates.md`
  e `docs/migration/handoff.md`, seção 3, para o diagnóstico completo do
  bloqueio).

---

## Repositório: PetConnect-API (Spring Boot)

| Item | Valor |
|---|---|
| Branch | `main` |
| Working tree | limpo, sincronizado com `origin/main` |
| Último commit | `abf5093` — chore(config): suporte opcional a FIREBASE_AUTH_EMULATOR_HOST (FASE 12) |
| Remote | `origin` → `https://github.com/AleksGustavo/PetConnect-API.git` (privado) |
| Java | 21.0.6 (Oracle) |
| Maven | 3.9.10 (instalação global — **sem Maven Wrapper no repo**) |
| Spring Boot | 3.4.2 |
| Docker | 29.7.2 |
| Docker Compose | v5.4.0 |
| `.github/workflows/` | **não existe** |

### Comandos executados

```bash
git status              # limpo
git branch --show-current
git log -5 --oneline
java -version
mvn -version
mvn -q -B test
```

### Resultados

- **`mvn -q -B test`**: **72/72 testes passando**, todas as 13 classes de
  teste verdes (Mongo embarcado via flapdoodle, sem depender de instância
  externa). Tempo total: ~1min.
- Nenhum warning de compilação relevante além do já conhecido "Standard
  Commons Logging discovery" (ruído inofensivo do classpath, não é erro).

### Segredos e configuração

- `.env.example` presente, **sem valores reais** — só o formato esperado
  (`FIREBASE_SA_PATH=...`).
- `.gitignore` cobre `.env`, `.env.*` (exceto `.env.example`) e
  `*serviceAccountKey*.json`.
- `git grep` por padrões de chave/token (`AIzaSy...`, `BEGIN PRIVATE KEY`)
  não encontrou nada nos arquivos versionados de nenhum dos dois repos
  (checagem já feita na sessão anterior, revalidada agora pela ausência de
  qualquer arquivo de credencial rastreado).
- **Sem Maven Wrapper (`mvnw`/`mvnw.cmd`)** — o CI vai precisar configurar
  Java+Maven via action (`actions/setup-java` com `cache: maven`), não pode
  assumir `./mvnw`.

---

## Ambiente de desenvolvimento (armadilhas já conhecidas, herdadas de sessões anteriores)

Estas não são novidades desta auditoria — já estavam documentadas em
`docs/migration/handoff.md`, seção 3, e são repetidas aqui porque afetam
diretamente o desenho do CI (seção C):

1. Esta máquina Windows tem um bug de loopback (`Unable to establish
   loopback connection`) que impede o Tomcat de subir direto e o Firestore
   Emulator (Java) de rodar. A API roda em Docker por causa disso.
2. `flutter test --platform=chrome` também não funciona direto nesta
   máquina, nem totalmente via o contorno em container Linux já criado
   (`tool/web-test/Dockerfile`) — trava em `setUpAll` por um motivo ainda
   não diagnosticado a fundo (suspeita: SDK JS do Firebase Auth vs. Chrome
   `--no-sandbox` como root).
3. **Nenhuma dessas duas limitações é esperada em CI** (GitHub Actions
   `ubuntu-latest` é um ambiente limpo, sem essas particularidades de rede
   do Windows) — por isso CI é o próximo passo natural, não mais um
   contorno local.

---

## Conclusão do baseline

Não há nada quebrado que precise de correção emergencial antes de seguir.
O estado é: **código funcional, testado localmente, sem CI, com uma dívida
de formatação conhecida e um teste (auth flow) ainda não confirmado em
execução real.** Prossegue para a Etapa B (infraestrutura) e Etapa C
(CI/CD) sem bloqueios.
