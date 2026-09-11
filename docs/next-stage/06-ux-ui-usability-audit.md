# 06 — Auditoria de UX/UI, Usabilidade, Acessibilidade e Performance

> Auditoria feita por leitura de código das 17 telas (não há sessão visual
> no device física nesta etapa — isso é o `device-validation-checklist.md`).
> Identidade visual **preservada**: nenhuma correção aqui altera cores,
> tipografia ou layout — só comportamento (confirmação, feedback,
> acessibilidade).

---

## 11.1 Consistência visual

Não identifiquei componentes duplicados relevantes — os widgets de lista
(`consulta_tile.dart`, `historico_tile.dart`, `localizacao_tile.dart`,
`vacina_tile.dart`, `pet_card.dart`) já seguem um padrão visual comum
(estabelecido nas fases anteriores da migração, junto com
pull-to-refresh). Cores centralizadas em `AppColors`, sem hex hardcoded
espalhado pelas telas (verificado por `grep -c "Color(0x" lib/features`
— 0 ocorrências fora de `core/theme/`).

## 11.2 e 11.7 — Usabilidade e ações destrutivas

| Ação | Confirmação | Feedback pós-ação | Proteção duplo-toque | Achado |
|---|---|---|---|---|
| Excluir pet | ✅ `showDialog` | ✅ (sai da lista, `ref.invalidate`) | N/A (ação única) | — |
| Excluir vacina | ✅ `showDialog` | ✅ | N/A | — |
| Excluir entrada de histórico | ✅ `showDialog` | ✅ | N/A | — |
| Excluir conta (RF09) | ✅ `showDialog`, texto explica a consequência (cascata) | ✅ (redireciona ao login) | ✅ (`_excluindo` desabilita o botão) | — |
| Sair da conta | ✅ `showDialog` | ✅ | N/A | — |
| **Cancelar consulta** | ❌ **sem confirmação** — `onCancelar` chama a ação direto no toque do botão (`consulta_tile.dart:84`) | ✅ (muda status na lista) | ❌ | **P2** — cancelamento é reversível (dá pra reagendar), mas um toque acidental cancela sem aviso. Diferente do padrão de excluir (que sempre confirma) |
| Marcar consulta como realizada | ❌ sem confirmação (mesmo padrão de cancelar) | ✅ | ❌ | **P3** — menor risco que cancelar (não desmarca um compromisso futuro) |
| Remover anexo (antes de salvar) | ❌ sem confirmação | ✅ (remove da lista local) | N/A | **P3** — baixo risco: o anexo já enviado pro Cloudinary é removido, mas nada "importante" se perde (o registro em si não foi salvo ainda) |

Formulários (login, cadastro, pet, vacina, consulta, histórico,
localização, editar perfil): **9 telas de formulário conferidas**, todas
com flag de `_submitting`/`_enviando` desabilitando o botão de salvar
durante a requisição — proteção contra double-submit **presente em
100% dos formulários**, incluindo login (`submitting ? null : onSubmit`).

## 11.3 Performance percebida

- Navegação local (abrir tela estática, trocar de aba) não depende de
  rede — confirmado: providers Riverpod só disparam request quando a
  tela que os usa é montada, não há chamada de rede no `initState` de
  telas de navegação pura.
- **16 de 17 telas** têm estado de loading explícito (`.when(loading:
  ...)` do `AsyncValue` ou `CircularProgressIndicator`); a 17ª é a
  splash, que não busca dados (não se aplica).
- Pull-to-refresh (`RefreshIndicator` + `AlwaysScrollableScrollPhysics`)
  presente em todas as listas — padrão estabelecido nas fases 4-10 da
  migração, confirmado.
- Imagens: usa `cached_network_image` (confirmado no `pubspec.yaml` e em
  `pet_card.dart`) — cache automático, evita re-fetch a cada rebuild.
- Rebuilds Riverpod: providers de leitura são `StreamProvider`/
  `Provider` simples por feature (não há um "god provider" observado que
  re-renderizaria telas não relacionadas).

## 11.4 Acessibilidade

| Item | Estado | Achado |
|---|---|---|
| `Semantics` explícito | ❌ **0 ocorrências em todo o código** (`grep -rc "Semantics(" lib`) | Não é necessariamente um problema — muitos widgets Flutter (`Text`, `ElevatedButton` com `child: Text(...)`) já expõem semântica automática via seus próprios widgets. Mas nenhum ajuste manual foi feito pra casos que precisariam (ex.: ícones sem texto ao lado) |
| `tooltip` em `IconButton` | ⚠️ **corrigido nesta auditoria** | 2 botões de "mostrar/ocultar senha" (login e cadastro) não tinham `tooltip` — um leitor de tela leria só "botão", sem contexto. **Corrigido** (mudança segura, só adiciona um atributo, não altera layout): `login_screen.dart`, `cadastro_screen.dart`. Os outros `IconButton`s do app (editar/excluir em `historico_tile.dart`, `vacina_tile.dart`, e o de `historico_form_screen.dart`) já tinham `tooltip`. |
| Contraste de cores | `NOT_TESTED` | Precisaria de inspeção visual (calculadora de contraste sobre as cores reais renderizadas) — fora do que dá pra confirmar só lendo código. Recomendo checar `AppColors.textMuted` sobre `AppColors.background` no device real. |
| Tamanho mínimo de toque | `NOT_TESTED` | Mesma limitação — depende de medição visual/no device. |
| Erros que não dependem só de cor | ✅ | Mensagens de erro em formulários usam texto (`Text(_error!)`), não só cor vermelha — confirmado em `cadastro_screen.dart`, `editar_perfil_screen.dart`, etc. |
| Texto escalável | `NOT_TESTED` | Não há uso de tamanho de fonte fixo em `sp`/hardcoded que impediria escala do sistema, mas não testei com "texto grande" ativado no device. |

## 11.5 Estados obrigatórios por tela

Confirmado por amostragem (`consulta_list_screen.dart`,
`historico_list_screen.dart`, `localizacao_list_screen.dart`,
`vacina_list_screen.dart`, `home_screen.dart`): todas têm `loading`,
`success`, `empty` (texto "nenhum.../ainda não...") e `error`
(`AsyncValue.error` renderizado com mensagem, não crash). `offline/timeout`
depende do comportamento do `ApiException.isNetwork` — existe a
distinção no `ApiClient`/`ApiException` (confirmado no código), mas não
confirmei que toda tela usa essa distinção pra mostrar uma mensagem
diferente de "erro genérico" — **not tested a fundo**, seria um bom item
pro `device-validation-checklist.md` (testar com Wi-Fi desligado).

## 11.6 Formulários

Todos os 8 formulários (login, cadastro, pet, vacina, consulta,
histórico, localização, editar perfil) usam `Form` + `TextFormField`
com `validator`, teclado apropriado (`keyboardType: TextInputType.phone`
no telefone, `.emailAddress` no e-mail, confirmado em `cadastro_screen.dart`),
e botão de salvar desabilitado durante o envio. Seleção de data usa
`showDatePicker` nativo (confirmado em `localizacao_form_screen.dart`,
`vacina_form_screen.dart`).

---

## Classificação dos achados

| Prioridade | Achado | Ação |
|---|---|---|
| P1 | Botões de mostrar/ocultar senha sem `tooltip` (acessibilidade) | ✅ **Corrigido nesta etapa** (mudança segura e trivial) |
| P2 | Cancelar consulta sem confirmação (diferente do padrão do resto do app) | 📋 Backlog — pedir confirmação do usuário sobre se quer alinhar ao padrão de "excluir" (com `showDialog`) antes de implementar, já que é uma mudança de comportamento visível, não só cosmética |
| P3 | Marcar consulta como realizada / remover anexo antes de salvar, sem confirmação | 📋 Backlog — risco baixo, não prioritário |
| — | Contraste, tamanho de toque, texto escalável | 📋 Precisa de teste visual real no device (`device-validation-checklist.md`) — não é algo que leitura de código resolve com confiança |

Nenhum achado **P0** (bloqueante/risco crítico) foi encontrado nas 17
telas.
