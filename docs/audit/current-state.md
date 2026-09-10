# Auditoria — Estado atual do projeto

> Etapa obrigatória 01 do plano de migração (Flutter + Firestore → Flutter + Spring Boot + MongoDB).
> Snapshot em 2026-09-10, branch `feature/backend-spring-mongodb-migration`, a partir do commit `8ac8a53`.
> **Nenhum código de app ou de banco foi alterado para produzir este documento.**

---

## 1. Estrutura Flutter

Raiz do repositório = projeto Flutter (não é monorepo). Um único módulo Dart.

```
lib/
├── main.dart                     # bootstrap: Firebase.initializeApp + ProviderScope
├── app.dart                      # MaterialApp.router, lê appRouterProvider
├── firebase_options.dart         # gerado por flutterfire — GITIGNORED (não versionado)
├── core/
│   ├── config/cloudinary_config.dart      # cloud name + upload preset (VERSIONADO)
│   ├── errors/auth_error_translator.dart   # códigos FirebaseAuthException → PT-BR
│   ├── theme/app_colors.dart, app_theme.dart
│   ├── utils/br_date.dart                   # parse/format dd/MM/yyyy, idadeEmAnos
│   ├── utils/upload_error.dart              # mensagem amigável de falha de upload
│   └── widgets/auth_header.dart, avatar_picker.dart
├── routing/app_router.dart        # GoRouter único + guard de rotas + splash
└── features/
    ├── auth/       → só presentation (telas). Lógica de auth vive em features/usuario.
    ├── usuario/    → tutor (perfil, sessão, configurações)
    └── pet/        → pet e tudo pendurado nele (vacina, histórico, consulta, localização, anexo, qr)
```

Camadas por feature: `data/` (implementações Firebase/Cloudinary), `domain/` (entidades + interfaces de repositório + regras puras), `presentation/` (providers Riverpod, screens, widgets).
Não há `usecases/`, `controllers/`, `states/`, `dtos/`, `datasources/` separados — a arquitetura foi mantida pragmática. Providers Riverpod fazem o papel de "controller/notifier"; a maioria é `StreamProvider` fino sobre o repositório.

## 2. Features implementadas

| Feature | Telas | Estado |
|---|---|---|
| `auth` | splash, login, cadastro, esqueci-senha | ✅ e-mail/senha completo |
| `usuario` | home, configurações, editar-perfil | ✅ perfil (RF08), exclusão de conta (RF09), logout |
| `pet` (base) | pet_form, pet_detail, pet_card | ✅ CRUD de pets (RF10–RF15) |
| `pet` → qr_code | pet_qr_code widget | ✅ geração no app (RF16); ⬜ página pública (RF17–RF19) |
| `pet` → vacina | vacina_list, vacina_form, vacina_tile | ✅ CRUD + alerta visual (RF20–RF23) |
| `pet` → histórico médico | historico_list, historico_form, historico_tile | ✅ CRUD + anexos Cloudinary (RF24–RF26) |
| `pet` → consulta | consulta_list, consulta_form, consulta_tile | ✅ agendar/listar/cancelar/realizar (RF27–RF30) |
| `pet` → localização | localizacao_list, localizacao_form, localizacao_tile | ✅ tutor registra/vê avistamentos (RF32); ⬜ relato anônimo via QR (RF31) |
| login social Google/Facebook | — | ⬜ dependências instaladas, **não implementado** (RF04-A/B) |

## 3. Repositórios (interfaces de domínio ↔ implementações)

Todas as interfaces vivem em `features/*/domain/*_repository.dart`. A UI só depende delas.

| Interface | Implementação atual | Backend por trás | Métodos |
|---|---|---|---|
| `UsuarioRepository` | `FirebaseUsuarioRepository` | Firebase Auth + Firestore `Usuarios` | watchUsuario, signIn, signUp, sendPasswordReset, signOut, updateUsuario, deleteAccount |
| `PetRepository` | `FirebasePetRepository` | Firestore `Pets` | watchPets(userId), watchPet(id), createPet, updatePet, deletePet |
| `VacinaRepository` | `FirebaseVacinaRepository` | Firestore `Pets/{id}/vacinas` | watchVacinas, createVacina, updateVacina, deleteVacina |
| `HistoricoMedicoRepository` | `FirebaseHistoricoMedicoRepository` | Firestore `Pets/{id}/historicoMedico` | watchHistorico, **novoId**, createHistorico, updateHistorico, deleteHistorico |
| `ConsultaRepository` | `FirebaseConsultaRepository` | Firestore `Pets/{id}/consultas` | watchConsultas, createConsulta, updateConsulta *(sem delete — cancelamento é status)* |
| `LocalizacaoRepository` | `FirebaseLocalizacaoRepository` | Firestore `Pets/{id}/localizacoes` | watchLocalizacoes, createLocalizacao |
| `AnexoRepository` | `CloudinaryAnexoRepository` | Cloudinary REST (upload unsigned) | upload(path, bytes, contentType) → URL; delete(url) *(no-op documentado)* |

**Padrão bom já estabelecido:** nenhuma `screen` ou `widget` importa `cloud_firestore`/`firebase_auth` diretamente — só os arquivos em `features/*/data/` e `features/usuario/presentation/providers/auth_providers.dart`. Fakes em memória existem para todos os repositórios (`test/features/pet/fake_*_repository.dart`).

**Ponto de atenção (dívida técnica leve):** os repositórios são todos `Stream`-based (`.snapshots()` do Firestore, tempo real). Uma API REST não entrega stream nativamente — ver seção "Riscos".

## 4. Models / entities

Não há separação `model` (data) vs `entity` (domain) — cada feature tem **uma** classe em `domain/` que serve para os dois papéis, com `fromMap(id, Map)` / `toMap()` acoplados ao formato Firestore.

| Classe | Arquivo | Campos |
|---|---|---|
| `Usuario` | `features/usuario/domain/usuario.dart` | id, usuarioID, nome, sobrenome, email, telefone, dataNascimento (str dd/MM/yyyy), genero, foto?; getter `nomeCompleto` |
| `Pet` | `features/pet/domain/pet.dart` | id, userId, nome, especie, raca, cor, genero, porte, peso (str), dataNascimento (str), vacinado (bool), dono?, telefone?, foto?, qrCodeId? |
| `Vacina` | `features/pet/domain/vacina.dart` | id, nome, dataAplicacao (str), proximaDose?, veterinario?, observacoes? |
| `HistoricoMedico` | `features/pet/domain/historico_medico.dart` | id, data (str), descricao, veterinario?, anexos: List\<String\> (URLs Cloudinary) |
| `Consulta` | `features/pet/domain/consulta.dart` | id, data (str), horario? (HH:mm), veterinario, motivo, status: enum `ConsultaStatus{agendada,realizada,cancelada}` |
| `Localizacao` | `features/pet/domain/localizacao.dart` | id, data (str), descricao, contatoReportante? |

Regras puras (testáveis sem Firebase): `vacina_alerta.dart` (`VacinaAlerta{nenhum,proxima,vencida}`, janela 30 dias), `consulta_alerta.dart` (`consultaEstaProxima`, janela 7 dias), `pet_qr_code.dart` (`publicPetUrl(pet)` → `https://pet-connect-c53f1.web.app/pet/{qrCodeId ?? id}` — **URL placeholder, host não existe**).

## 5. Providers Riverpod

`flutter_riverpod` 2.6.1 (API `Provider`/`StreamProvider`/`.family` — **não** usa code-gen `@riverpod`).

| Arquivo | Providers |
|---|---|
| `usuario/.../auth_providers.dart` | `firebaseAuthProvider`, `firestoreProvider`, `usuarioRepositoryProvider`, `authStateChangesProvider` (StreamProvider\<User?\>), `currentUsuarioProvider` (StreamProvider\<Usuario?\>) |
| `pet/.../pet_providers.dart` | `petRepositoryProvider`, `petsProvider` (lista do tutor logado), `petProvider.family(id)` |
| `pet/.../vacina_providers.dart` | `vacinaRepositoryProvider`, `vacinasProvider.family(petId)` |
| `pet/.../historico_medico_providers.dart` | `historicoMedicoRepositoryProvider`, `historicoMedicoProvider.family(petId)` |
| `pet/.../consulta_providers.dart` | `consultaRepositoryProvider`, `consultasProvider.family(petId)` |
| `pet/.../localizacao_providers.dart` | `localizacaoRepositoryProvider`, `localizacoesProvider.family(petId)` |
| `pet/.../anexo_providers.dart` | `anexoRepositoryProvider` (→ `CloudinaryAnexoRepository`) |

`firebaseAuthProvider` e `firestoreProvider` são os **dois únicos pontos de injeção do SDK Firebase** — trocá-los é o gargalo da migração de dados.

## 6. Rotas (`go_router` 17.5.0)

`GoRouter` **único**, criado uma vez (`appRouterProvider`), reavaliado via `refreshListenable` no stream de auth.

- `initialLocation: '/'` → `SplashScreen` (aguarda 1ª emissão de auth + 2,5s mín., depois `context.go('/home' | '/login')`).
- Rotas públicas (guard): `/login`, `/cadastro`, `/esqueci-senha`. `/` é tratada à parte (splash navega sozinha).
- `redirect`: sem sessão + rota não-pública → `/login`; com sessão + rota pública → `/home`.
- Rotas autenticadas: `/home`, `/configuracoes`, `/configuracoes/editar-perfil`, e a árvore `/pet/...` (novo, `:id`, editar, e por pet: `vacinas`, `historico`, `consultas`, `localizacao`, cada uma com `nova`/`editar`).
- **Não há rota pública de QR (`/p/{publicId}`)** — RF17 pendente.
- Deep links: não configurados (nem Android App Links nem esquema custom).

## 7. Firebase — uso atual

| Serviço | Uso | Onde |
|---|---|---|
| **Authentication** | e-mail/senha: signIn, signUp (createUser), sendPasswordResetEmail, signOut, currentUser, authStateChanges, user.delete() | `FirebaseUsuarioRepository`, `auth_providers.dart`, `app_router.dart` |
| **Cloud Firestore** | todas as leituras/escritas de dados (ver seção 8) | `firebase_*_repository.dart` (7 arquivos) |
| **Storage** | ❌ removido — substituído por Cloudinary |
| **Cloud Functions** | ❌ não existe pasta `functions/` |
| **Realtime Database** | ❌ não usado (mas `databaseURL` aparece no `firebase_options.dart` — provavelmente default do projeto) |
| **Cloud Messaging / App Check** | ❌ não usados (mencionados como "futuro" em `docs/seguranca.md`) |

- Projeto: **`pet-connect-c53f1`** (project number `304771768372`).
- `firebase.json` só tem config do plugin FlutterFire (Android + Dart), sem hosting/functions/firestore-rules.
- **Não há `firestore.rules` no repositório** — as regras deployadas não são conhecidas a partir do código (ver Riscos R-04).

## 8. Firestore — estrutura observada

Ver `docs/database/firestore-current-schema.md` (detalhamento completo). Resumo:

```
Usuarios/{firebaseUid}
  nome, sobrenome, email, telefone, dataNascimento(str), genero, foto?, usuarioID(uuid)

Pets/{autoId}
  userId, nome, especie, raca, cor, genero, porte, peso(str), dataNascimento(str),
  vacinado(bool), dono?, telefone?, foto?, qrCodeId?
  ├── vacinas/{autoId}          nome, dataAplicacao, proximaDose?, veterinario?, observacoes?
  ├── historicoMedico/{explicitId}  data, descricao, veterinario?, anexos:[url]
  ├── consultas/{autoId}        data, horario?, veterinario, motivo, status
  └── localizacoes/{autoId}     data, descricao, contatoReportante?

Localizacoes/{docId}   ← existe no console, campos NUNCA compartilhados, app NÃO usa
```

- Todas as datas são **string `dd/MM/yyyy`**, não `Timestamp`.
- Não há `createdAt`/`updatedAt` em lugar nenhum.
- `historicoMedico` usa id gerado no client (`novoId`) e `.set()`; as demais subcoleções usam `.add()` (id automático).

## 9. Cloudinary

- `CloudinaryAnexoRepository` → `POST https://api.cloudinary.com/v1_1/{cloudName}/auto/upload`, campo `upload_preset` (unsigned), multipart `file`. Retorna `secure_url`.
- Config em `lib/core/config/cloudinary_config.dart` — **VERSIONADO no git**. `cloudName = 'qgrx3f8s'`, `uploadPreset = 'w31vgrqr'`. Não é API secret (preset unsigned só permite upload), mas ainda assim está no cliente e no histórico do git (ver Riscos R-03).
- `delete(url)` é **no-op** — arquivos substituídos/removidos ficam órfãos no Cloudinary.
- Validação de tamanho (5 MB) feita no client antes do upload, nas telas `pet_form`, `editar_perfil`, `historico_form`.
- Paths usados: `pets/fotos/{...}`, `usuarios/fotos/{...}`, `historico/{...}` (montados nas telas).

## 10. Autenticação — fluxo atual

```
Flutter → FirebaseAuth.signInWithEmailAndPassword → sessão local persistida (RF06)
        → authStateChanges() alimenta o guard do go_router
        → currentUsuarioProvider casa o User com o doc Usuarios/{uid}
Firestore Security Rules = única barreira de autorização (server-side)
```

Não há backend próprio. Não há verificação de ID Token em lugar nenhum (não existe servidor para verificar). Autorização hoje é 100% Firestore Rules — cujo conteúdo real não está no repo.

## 11. Testes

`flutter_test` + fakes em memória. `flutter analyze` limpo. 17 testes:

| Arquivo | Tipo | Cobre |
|---|---|---|
| `auth_flow_test.dart` | integração (Firebase real, **fora do CI**) | cadastro→home→logout→login→senha errada |
| `pet_management_test.dart` | widget + fake | CRUD de pet via UI (CT09, CT11) |
| `pet_qr_code_test.dart` | unit | `publicPetUrl` (RF16/RF19) |
| `vacina_alerta_test.dart` | unit | janela de alerta de vacina (RF23) |
| `vacina_management_test.dart` | widget + fake | CRUD vacina + alerta (CT16, CT17) |
| `historico_medico_test.dart` | widget + fake | CRUD histórico (CT18) — upload de anexo **não** exercitado |
| `consulta_alerta_test.dart` | unit | `consultaEstaProxima` (RF30) |
| `consulta_management_test.dart` | widget + fake | agendar + cancelar (CT19, CT20) |
| `localizacao_management_test.dart` | widget + fake | registrar avistamento (RF32) |

Não há: repository tests contra Firestore/emulador, provider tests isolados, testes de segurança automatizados, integração end-to-end de upload.

## 12. Dependências (resolvidas — `pubspec.lock`)

SDK: Dart `>=3.12.0 <4.0.0`, Flutter `>=3.44.0`.

| Pacote | Versão | Papel |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | estado/DI |
| `go_router` | 17.5.0 | navegação |
| `firebase_core` | 4.13.0 | init |
| `firebase_auth` | 6.5.7 | autenticação (**mantida** na arquitetura alvo) |
| `cloud_firestore` | 6.8.0 | banco atual (**a ser substituído** por API) |
| `http` | 1.6.0 | Cloudinary hoje; cliente REST da API amanhã |
| `qr_flutter` | 4.1.0 | geração de QR no app |
| `image_picker` | 1.2.3 | escolher foto |
| `cached_network_image` | 3.4.1 | cache de imagens de rede |
| `intl` | 0.20.3 | formatação de data |
| `google_sign_in` | 7.2.0 | login social (**não implementado**) |
| `flutter_facebook_auth` | 7.2.0 | login social (**não implementado**) |
| `flutter_lints` | 4.0.0 (dev) | lints |

`analysis_options.yaml`: `package:flutter_lints/flutter.yaml` + `prefer_single_quotes`, `always_declare_return_types`, `avoid_print`.

## 13. Banco atual — o que sabemos e o que NÃO sabemos

**Sabemos** (do código + `docs/modelo-dados-firestore.md`): nomes de coleção, subcoleção, campos e tipos aproximados; que `Usuarios` já existia com `nome/email/telefone/dataNascimento/genero/usuarioID` e recebeu `sobrenome`; que `Pets` já existia e recebeu `vacinado`; que as 4 subcoleções foram criadas pelo app; que existe uma coleção raiz `Localizacoes` órfã.

**NÃO sabemos** (precisa acesso ao console / export do Firestore):
- Quantos documentos existem em cada coleção (volume real).
- Conteúdo real: quais registros têm `dataNascimento=""`, `dono=null`, `telefone=null`, `foto` inválida, etc.
- Se há documentos com o schema **antigo** (pré-`sobrenome`/`vacinado`).
- Campos que existem no banco mas o app ignora (ex.: algo dentro de `Localizacoes`, ou campos legados em `Usuarios`).
- **O conteúdo real das Firestore Security Rules deployadas.**
- Se `usuarioID` é usado em algum lugar (ex.: como FK em `Localizacoes`).

## 14. Riscos e dívida técnica

| ID | Risco / dívida | Severidade | Mitigação proposta |
|---|---|---|---|
| **R-01** | Sem acesso aos **dados reais** do Firestore nem à contagem de documentos → impossível fazer o relatório de qualidade de dados (etapa 50) e dimensionar a migração | 🔴 Alta | Usuário exporta o Firestore (`gcloud firestore export` ou script Node com Admin SDK) ou concede acesso; **não migrar nada antes disso** |
| **R-02** | **Firestore Security Rules deployadas desconhecidas** — em sessões anteriores o usuário mostrou regras muito permissivas (`Pets` com leitura pública, `Localizacoes` aberta, catch-all amplo). Se forem essas, qualquer pessoa lê/escreve dados hoje | 🔴 Alta | Usuário cola as regras atuais do console; documentar; endurecer **antes** de expor mais dados |
| **R-03** | `lib/core/config/cloudinary_config.dart` versionado com cloud name + preset. Preset unsigned → risco = upload não-autorizado / abuso de cota, não vazamento de dados. Ainda assim está no histórico do git | 🟡 Média | Mover upload para o backend (fluxo assinado) na FASE 10; enquanto isso, manter só preset unsigned e monitorar cota |
| **R-04** | Repositórios são **stream-based** (`.snapshots()`, tempo real). REST não tem stream → telas que hoje atualizam sozinhas (lista de pets, alertas) vão precisar de polling / pull-to-refresh / re-fetch on focus | 🟡 Média | Definir por tela: a maioria pode virar "carrega ao abrir + pull-to-refresh"; avaliar SSE/websocket só se houver caso real de tempo real |
| **R-05** | Datas como **string `dd/MM/yyyy`** em todo o banco. Migrar para ISO 8601 / `Date` exige parse + validação de cada registro; registros com `""` ou formato inválido quebram parse | 🟡 Média | Camada de migração converte e classifica; API sempre ISO 8601; Flutter continua exibindo `dd/MM/yyyy` via `intl` |
| **R-06** | Dois IDs de usuário (`docId`=firebaseUid vs `usuarioID`=uuid) sem uso confirmado do segundo; `Pets.dono` redundante com `userId` | 🟡 Média | Adotar `firebaseUid` como chave canônica; `usuarioID` e `dono` viram campos legados preservados-mas-não-usados até confirmação |
| **R-07** | `AnexoRepository.delete` é no-op → Cloudinary acumula arquivos órfãos; sem backend não dá pra assinar delete | 🟢 Baixa | Resolver junto com a FASE 10 (upload/delete assinado via Spring) |
| **R-08** | `historicoMedico` usa id gerado no client + `.set()`, as outras subcoleções usam `.add()`. Inconsistência de padrão de criação | 🟢 Baixa | Padronizar: backend gera todos os ids (ObjectId), Flutter nunca inventa id |
| **R-09** | Sem `createdAt`/`updatedAt` em nenhum documento → impossível auditar/ordenar por criação, paginar por cursor estável | 🟢 Baixa | MongoDB alvo inclui timestamps em todas as collections |
| **R-10** | Repo é Flutter-only na raiz; a estrutura alvo (`root/mobile` + `root/backend`) exigiria mover TODO o app Flutter — alto risco de quebrar caminhos, CI, IDE | 🟡 Média | **Não mover o Flutter.** Backend em repositório separado (recomendado) OU subpasta `backend/` sem mexer no resto |
| **R-11** | `auth_flow_test.dart` cria usuário real no Firebase a cada run e está fora do CI; ninguém roda de verdade | 🟢 Baixa | Reescrever contra emulador Firebase ou mock do backend na FASE 12 |
| **R-12** | RF17–RF19 (página pública do QR) nunca foi feito e depende de infra. `publicPetUrl` aponta para host inexistente | 🟡 Média | Vira endpoint do Spring (`GET /p/{publicId}`) — encaixa naturalmente na FASE 9 |
| **R-13** | Sem ambientes separados (dev/staging/prod). Um único projeto Firebase, credenciais no `.gitignore` mas geradas só localmente | 🟡 Média | Definir 3 ambientes no backend (`application-{env}.yml` + env vars) e, idealmente, projetos Firebase/DBs separados |

## 15. Funcionalidades — prontas / parciais / ausentes

**Prontas (mobile, contra Firestore):** cadastro/login/recuperação e-mail-senha, sessão persistida, logout, editar perfil do tutor, excluir conta, CRUD de pets, geração de QR no app, CRUD de carteira de vacina + alerta, CRUD de histórico médico + anexos (Cloudinary), agendar/listar/cancelar/realizar consultas + alerta, registrar/ver avistamentos de localização (lado tutor).

**Parciais:**
- QR code: geração ✅ / página pública (RF17–RF19) ❌.
- Localização: lado tutor ✅ / relato anônimo por quem achou o pet (RF31) ❌ (depende da página pública).
- Exclusão de conta (RF09): remove `Usuarios` + `Pets` + subcoleções `vacinas`/`historicoMedico`, mas **não** remove `consultas` nem `localizacoes` do pet, nem os arquivos no Cloudinary.

**Ausentes:**
- Login social Google/Facebook (RF04-A/B) — só dependências.
- Backend próprio (todo o objetivo desta migração).
- MongoDB.
- Verificação de Firebase ID Token no servidor.
- Autorização de fato no servidor (hoje só Firestore Rules, cujo conteúdo é desconhecido).
- Notificações push, App Check, política de privacidade / consentimentos (RF listados como "futuro").
- Status de pet além do booleano `vacinado` (o prompt pede enum `ACTIVE/LOST/FOUND/DECEASED/ARCHIVED`; hoje **não existe** campo `status` no `Pet`).
- Estados ricos de consulta (`REQUESTED/PENDING/CONFIRMED/COMPLETED/CANCELLATION_REQUESTED/CANCELLED/REJECTED` — hoje só `agendada/realizada/cancelada`).
- Origem do registro de histórico médico (`TUTOR/CLINIC/VETERINARIAN/IMPORT` — hoje inexistente).
- Campos de vacina do modelo-alvo (`fabricante`, `lote`, `dose`, `clinica`, `comprovanteUrl`, timestamps — hoje só `nome/dataAplicacao/proximaDose/veterinario/observacoes`).
- Domínio de compartilhamento/ERP (`Organization`, `SharingRequest`, `SharingConsent`).
- `.github/workflows` de CI (existe só `.github/modernize/` — artefato local do "App Modernization for Java", ignorado pelo git).

## 16. Inconsistências encontradas

1. `docs/modelo-dados-firestore.md` e comentários no código dizem "URLs do **Firebase Storage**" em `historico_medico.dart` e `anexo_repository.dart`, mas a implementação real é **Cloudinary** — comentários desatualizados.
2. `Consulta` não tem `deleteConsulta` na interface, mas `docs` e RF29 falam em "remover quando permitido" para vacina (essa tem delete) — comportamento divergente entre subcoleções, provavelmente intencional (consulta = histórico), mas não documentado como decisão.
3. `pet_qr_code.dart` gera URL para `pet-connect-c53f1.web.app` (Firebase Hosting) que **não está provisionado**.
4. `README.md` badge "Firebase — Auth | Firestore | Storage" — Storage não é mais usado.
5. Exclusão de conta não cobre `consultas`/`localizacoes` (ver seção 15).
