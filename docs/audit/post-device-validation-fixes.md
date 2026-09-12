# Auditoria — correções pós-validação física (Etapa 0)

> Fonte: `petconnect_correcoes_pos_validacao_claude.md` (2026-09-12), seção 5.
> Feita **antes** de qualquer alteração de código, como exigido.

## Estado do repositório no início

- Branch usada como base: `feature/backend-spring-mongodb-migration`
  (é nela que todo o trabalho recente foi mesclado — `main` está
  desatualizada, ver `docs/migration/handoff.md`).
- Working tree limpo, sem alterações locais pendentes.
- PR aberta: [#46 — moderniza o perfil do pet com navegação por
  cards](https://github.com/TecnoDreamer/PetConnect/pull/46), ainda não
  mesclada nem revisada. As features desta rodada são independentes dela
  (branches próprias, partindo da mesma base).

## Estrutura de login e sessão

- `lib/features/auth/presentation/screens/login_screen.dart` — já tem
  loading, erro, prevenção de double-submit (`onPressed: submitting ?
  null : onSubmit`) e teclado de e-mail correto. UX já adequada, sem
  necessidade de retrabalho nesta feature.
- `lib/features/auth/presentation/screens/splash_screen.dart` —
  decide entre `/home` e `/login` lendo `authStateChangesProvider.future`
  (primeira emissão de `FirebaseAuth.authStateChanges()`).
- `lib/routing/app_router.dart` (`appRouterProvider`) — o `redirect`
  do GoRouter lê `auth.currentUser` (getter síncrono) a cada navegação,
  mas explicitamente pula essa checagem na rota `/` (splash), pra não
  atropelar a decisão que ela mesma toma.
- `lib/features/usuario/presentation/providers/auth_providers.dart` —
  `firebaseAuthProvider` expõe `FirebaseAuth.instance` direto;
  `authStateChangesProvider` e `currentUsuarioProvider` derivam dele.

## Causa raiz do problema de login

`FirebaseAuth` persiste a sessão localmente por padrão (comportamento
documentado do SDK, e também da decisão de produto original — RF06,
comentário em `splash_screen.dart` fala em "referência comum para splash
screens"). Reabrindo o app, `auth.currentUser` já vem preenchido com o
usuário salvo **antes mesmo** da splash rodar, e ela navega direto para
`/home` — não é um bug de implementação, é o comportamento padrão do
Firebase fazendo exatamente o que deveria, só que a decisão de produto
mudou (agora se quer sempre pedir login de novo).

## Perfil do pet, configurações e imagens

- `lib/features/pet/domain/pet.dart` — só tem um campo de foto (`foto`),
  sem separação entre avatar e capa.
- `lib/features/pet/presentation/screens/pet_detail_screen.dart` (já
  redesenhado na PR #46) — o card "Configurações" em
  `pet_secondary_actions.dart` navega para `/configuracoes`, a tela
  **global** do tutor (`configuracoes_screen.dart`) — não existe hoje
  nenhuma tela de configurações por pet, nem rota que carregue o
  `petId` além do padrão `/pet/:id`.
- `lib/core/widgets/avatar_picker.dart` — componente de avatar circular
  com botão de câmera, reaproveitado hoje por pet e tutor; não existe
  nenhum componente de imagem "capa" (retangular, `BoxFit.cover` em área
  maior) nem visualizador fullscreen em lugar nenhum do app.
- Nenhuma tela do app abre uma imagem em tela cheia hoje — nem a foto do
  pet, nem a do tutor.

## Tema

- `lib/core/theme/app_theme.dart` — só existe `AppTheme.light()`. Sem
  `ThemeMode`, sem tokens de tema escuro, sem persistência de preferência
  de tema em lugar nenhum do app.

## Testes existentes

- `test/core/`, `test/features/pet/` — 42 testes, rodando no CI.
- `test/features/auth/auth_flow_test.dart` — e2e completo (cadastro →
  Home → logout → login → senha errada), mas **não roda no CI** (precisa
  do Auth Emulator + API + Mongo de pé) e nunca foi executado com sucesso
  nesta máquina (bug de loopback do Windows, ver `handoff.md` seção 3).
  Não existe nenhum teste, no repositório inteiro, para
  `app_router.dart`/`splash_screen.dart` — `FirebaseAuth`/`User` são
  classes concretas do SDK, sem uma interface própria no projeto, então
  nunca foram testadas isoladamente (nem antes desta auditoria).

## CI/CD existente

- `.github/workflows/ci.yml` — roda `dart format`, `flutter analyze` e
  `flutter test test/core/ test/features/pet/` a cada push/PR. Não inclui
  `test/features/auth/` (justamente pelo `auth_flow_test.dart` citado
  acima precisar de infraestrutura externa que o CI não tem hoje —
  rastreado separadamente na issue
  [TecnoDreamer/PetConnect#27](https://github.com/TecnoDreamer/PetConnect/issues/27)).
- Nenhum workflow de backend nesta auditoria (nenhuma das 5 features
  desta rodada altera a API, então não deveria ser necessário).

## Mapa de problemas → correção

| Problema | Causa provável | Arquivos envolvidos | Risco | Feature/branch |
|---|---|---|---|---|
| App reaberto não pede login | `FirebaseAuth` persiste sessão por padrão; nada força novo login a cada abertura | `splash_screen.dart`, `auth_providers.dart`, `main.dart` | Baixo/médio — mexe no fluxo mais crítico do app; precisa não quebrar cadastro/recuperação de senha | Feature 1 — `fix/login-inicial-obrigatorio` |
| Perfil do pet sem capa | Nunca foi implementado — só existe avatar (`pet.foto`) | `pet.dart`, `pet_profile_header.dart`, `pet_avatar.dart`, backend (`Pet` document/DTO) se precisar de campo novo | Médio — pode exigir migração de dado e mudança de contrato da API | Feature 2 — `feat/perfil-pet-capa-avatar` |
| "Configurações" do pet abre configurações do tutor | O card era um atalho de conveniência pra tela global, nunca existiu uma tela por pet | `pet_secondary_actions.dart`, `app_router.dart`, nova tela `configuracoes_pet_screen.dart` | Baixo — troca de destino de navegação + tela nova, sem tocar em dado | Feature 3 — `feat/configuracoes-pet` |
| Fotos não abrem em tela cheia | Nunca foi implementado | `pet_avatar.dart`, `avatar_picker.dart`, novo viewer | Baixo — feature aditiva, não muda fluxo existente | Feature 4 — `feat/visualizacao-imagens` |
| Sem tema claro/escuro | Nunca foi implementado — só existe `AppTheme.light()` | `app_theme.dart`, `app.dart`, `configuracoes_screen.dart`, nova preferência persistida | Médio — toca em toda a árvore de widgets (retema global) | Feature 5 — `feat/tema-aplicacao` |

## Ordem de execução

Conforme a seção 4 do documento-fonte: Feature 1 → 2 → 3 → 4 → 5, uma PR
por vez, aguardando revisão/aceite antes de iniciar a próxima. Este
documento cobre a auditoria completa; a partir daqui, cada feature tem seu
próprio ciclo de descoberta → implementação → testes → PR.
