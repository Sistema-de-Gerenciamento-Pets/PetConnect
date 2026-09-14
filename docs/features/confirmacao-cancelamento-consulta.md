# Confirmação ao cancelar consulta

> Branch: `fix/confirmacao-cancelamento-consulta`. Prioridade 1 de
> `petconnect_roadmap_prioridades_claude.md`.

## Objetivo

Evitar cancelamento acidental de uma consulta agendada (RF29) — antes,
tocar em "Cancelar" no card da consulta chamava a API na hora, sem
nenhuma confirmação nem chance de desfazer.

## Diagnóstico (antes de implementar)

- `ConsultaTile.onCancelar` (`consulta_tile.dart`) era um `VoidCallback`
  ligado direto ao botão "Cancelar" — um toque, mesmo sem querer,
  cancelava a consulta.
- `ConsultaListScreen` (`consulta_list_screen.dart`) já construía a
  chamada real (`updateConsulta` + `invalidate`), só faltava um passo de
  confirmação antes dela.
- Nenhum feedback de loading ou erro existia nesse fluxo — se
  `updateConsulta` falhasse, o app simplesmente não fazia nada
  visivelmente (erro engolido pelo `.then()` sem `.catchError`).
- Padrão de diálogo de confirmação já existia no app (`_confirmarExclusao`
  em `pet_settings_screen.dart`, "Sair da conta" na Home) — reaproveitado
  aqui, não reinventado.

## O que mudou

- `ConsultaTile` virou `StatefulWidget` — o estado de "cancelando" é
  local a cada card, não do tipo `ConsultaListScreen` inteira.
- `onCancelar` mudou de `VoidCallback?` para `Future<void> Function()?`:
  quem chama (`ConsultaListScreen`) continua só descrevendo *como*
  cancelar (chamar o repositório + invalidar o provider); *quando*
  chamar isso agora é decisão do próprio tile, depois de confirmação.
- Ao tocar em "Cancelar", abre um `AlertDialog`:
  - título "Cancelar consulta";
  - texto explicando a consequência, citando data/horário e veterinário
    da consulta específica;
  - "Voltar" (não cancela nada) e "Sim, cancelar" (cor de erro,
    confirma).
- Durante a chamada real ao repositório, o botão "Cancelar" mostra um
  spinner pequeno no lugar do ícone e fica desabilitado — impede duplo
  toque enquanto a operação está em andamento.
- Se `updateConsulta` falhar, mostra um `SnackBar` com mensagem amigável
  ("Não foi possível cancelar a consulta. Tente novamente.") — a
  consulta permanece agendada, nada muda silenciosamente.
- "Marcar realizada" **não foi alterado** — fora do escopo deste
  documento (não é uma ação destrutiva da mesma forma; reverter significa
  só editar a consulta de novo).

## Arquivos afetados

- [`consulta_tile.dart`](../../lib/features/pet/presentation/widgets/consulta_tile.dart) — reescrito.
- `consulta_list_screen.dart` — **sem mudança de código** (o tipo do
  callback já era compatível por inferência; só precisou do novo tipo em
  `ConsultaTile`).
- [`fake_consulta_repository.dart`](../../test/features/pet/fake_consulta_repository.dart) — ganhou `erroAoAtualizar` e
  `aguardarAntesDeAtualizar` (opcionais) pra simular erro/loading nos
  testes, sem afetar o uso existente em outros testes.

## Acessibilidade

- Diálogo de confirmação usa `AlertDialog` padrão do Flutter — título,
  conteúdo e ações já totalmente acessíveis por padrão (mesmo componente
  usado em "Excluir perfil do pet"/"Sair da conta").
- Botão "Sim, cancelar" nunca depende só de cor — o texto já deixa a
  ação clara.
- `SnackBar` de erro é anunciado automaticamente por leitores de tela
  (comportamento padrão do Flutter).

## Segurança

Nenhuma mudança de autorização ou regra de dados — a chamada ao backend
continua sendo exatamente a mesma (`updateConsulta` com
`status: cancelada`), só passa a acontecer depois de confirmação
explícita do usuário.

## Testes

- `flutter analyze` — sem apontamentos.
- `flutter test test/core/ test/features/pet/ test/features/auth/
  test/features/usuario/ --exclude-tags=e2e` — ver relatório da PR pro
  número exato.
- `consulta_management_test.dart` (existente) — atualizado: agora
  confirma o diálogo antes de checar que a consulta foi pra
  "Canceladas".
- Novo `consulta_cancelamento_test.dart` (5 testes): tocar em "Cancelar"
  não cancela sozinho (abre o diálogo); "Voltar" fecha sem cancelar;
  "Sim, cancelar" confirma e move pra "Canceladas"; indicador de
  carregamento aparece e o botão fica desabilitado durante a chamada
  (via um `Completer` controlado no fake, evitando duplo cancelamento);
  erro ao cancelar mostra o aviso e mantém a consulta agendada.

## Critérios de aceite (seção 6 do roadmap)

- [x] evita cancelamento acidental — exige confirmação explícita.
- [x] exibe modal de confirmação.
- [x] explica a consequência (cita data/veterinário da consulta).
- [x] oferece confirmar/voltar.
- [x] loading (spinner no botão durante a chamada).
- [x] prevenção de double tap (botão desabilitado durante a chamada).
- [x] feedback de sucesso (some da seção "Futuras", aparece em
      "Canceladas") e de erro (`SnackBar`).
- [x] testes (unitário/widget cobrindo os 5 cenários acima).

## Rollback

Reverter o merge. Nenhum dado persistido muda de formato — o campo
`status` da consulta continua sendo `agendada`/`realizada`/`cancelada`,
como sempre foi.

## Validação manual

Ver `docs/validation/confirmacao-cancelamento-consulta.md`.
