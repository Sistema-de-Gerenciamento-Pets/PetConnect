# Configurações e mídia do perfil do pet

> Branch: `fix/configuracoes-e-visual-pet`. Fonte:
> `prompt_correcao_configuracoes_perfil_pet.md` (2026-09-13), reportado com
> vídeo de validação física.

## Problema original

Quatro problemas concretos, achados testando o app no aparelho:

1. o botão "Configurações" no perfil do pet abria a tela de **conta do
   tutor** (Editar perfil, Sair da conta, Excluir conta) — nada relacionado
   ao pet selecionado;
2. os botões "Editar" e "Excluir" ficavam expostos permanentemente no fim
   da tela principal do perfil, misturando visualização com administração;
3. tocar na foto do pet não fazia nada;
4. não existia foto de capa no cabeçalho do perfil.

## Causa

O card "Configurações" no perfil do pet era só um atalho de conveniência
para a tela global de configurações do tutor (`/configuracoes`) — nunca
existiu uma tela de configurações **do pet**. Os outros três pontos eram,
simplesmente, features nunca implementadas.

## Arquitetura

Nenhuma mudança de arquitetura, backend ou provider além do necessário
para o campo novo de capa (abaixo). Duas telas novas de apresentação:

- `PetSettingsScreen` — configurações de um pet específico.
- `FullscreenImageViewer` — visualizador de imagem reutilizável (avatar e
  capa).

## Rotas

Rota nova: `/pet/:id/configuracoes` → `PetSettingsScreen`. Segue o mesmo
padrão já usado por todas as outras sub-rotas do pet (`/pet/:id/vacinas`,
`/pet/:id/historico`, etc.) — o `petId` vem sempre do parâmetro da rota,
nunca de um estado global, então não há como misturar o contexto de dois
pets (ou do tutor) por engano.

O visualizador fullscreen **não** é uma rota do go_router: é empurrado
como uma rota comum do `Navigator` (`FullscreenImageViewer.open(...)`),
por ser uma visão efêmera sem necessidade de deep link.

## Componentes

- `PetSettingsScreen` (`presentation/screens/pet_settings_screen.dart`) —
  editar perfil (reaproveita o formulário existente), foto de capa
  (alterar/remover) e excluir o perfil do pet. Nenhuma opção do tutor.
- `PetCoverImage` (`presentation/widgets/pet_cover_image.dart`) — capa do
  cabeçalho; sem capa, mostra um gradiente do design system (nunca uma
  foto inventada).
- `PetAvatar` (atualizado) — agora clicável: com foto, abre o fullscreen;
  sem foto, o toque não faz nada e o `Semantics` avisa que não há foto.
- `FullscreenImageViewer` — zoom/pan via `InteractiveViewer` nativo (sem
  dependência nova), fundo escuro, back do Android de graça.
- `PetProfileHeader` (redesenhado) — capa ao fundo, avatar sobreposto e
  deslocado para a esquerda (não mais centralizado), nome e dados básicos.

## Modelo de dados

Não existia nenhum campo de capa em lugar nenhum da stack. Propagação
completa:

```text
MongoDB (Pet.coverPhotoUrl)
→ CreatePetRequest / UpdatePetRequest / PetResponse
→ PetService (create/update — null não altera, string vazia limpa)
→ Pet.capa (Flutter)
→ ApiPetRepository (mapeia coverPhotoUrl ↔ capa)
→ PetSettingsScreen (UI)
```

O Firestore legado não precisou de migração — é schemaless, e
`Pet.toMap()`/`fromMap()` já cobrem o campo novo genericamente. Pets sem
capa (100% deles, hoje) continuam funcionando normalmente.

## Capa — upload e remoção

Reaproveita 100% a infraestrutura de upload já existente
(`anexoRepositoryProvider`, o mesmo Cloudinary assinado usado para a foto
do pet e do tutor) — nenhum endpoint novo, nenhuma credencial nova no
Flutter. "Remover" limpa o campo (`capa: ''`, que o backend interpreta
como limpar — `null` significaria "não alterar") e tenta apagar o arquivo
antigo do Cloudinary (best-effort, não bloqueia a ação se falhar).

## Avatar / fullscreen

`PetAvatar` ganhou um `onTap` condicional: só abre o visualizador quando
há foto de verdade. `Semantics` cobre os dois casos ("Foto de Felícia.
Toque duas vezes para ampliar." / "Felícia não possui foto cadastrada.").

## Exclusão

Movida de "Excluir pet" (botão na tela principal) para "Excluir perfil do
pet" (só em Configurações), com o mesmo diálogo de confirmação de sempre
— texto ajustado para "Excluir o perfil de \<nome\>?" (seção 9.4 do
documento-fonte), sem prometer uma cascata de dados que hoje só existe no
caminho da API (o Firestore legado só apaga o documento do pet).

## Segurança

Nenhuma mudança de autorização — toda operação continua passando pelos
mesmos `PetRepository`/`PetService` já existentes, que já garantem posse
do pet (backend) ou dependem das regras do Firestore (legado). Nenhuma
credencial do Cloudinary no Flutter, como já era.

## Testes

- `flutter analyze` — sem apontamentos.
- `flutter test test/core/ test/features/pet/` — 53/53 passando.
- Backend: `mvn test` — 75/75 passando (inclui o campo `coverPhotoUrl`).
- Não testado automaticamente: o fluxo de **selecionar** uma foto de capa
  nova (`image_picker`, canal de plataforma indisponível em `flutter
  test` — mesma limitação já assumida em `historico_medico_test.dart`).
  A remoção de uma capa já existente não depende do picker e é testada.

## Rollback

Reverter o merge desta branch. O campo `coverPhotoUrl`/`capa` fica órfão
nos bancos (não usado por nenhuma tela), sem quebrar nada — nenhuma
migração precisa ser desfeita.

## Validação manual

Ver `docs/validation/pet-settings-profile-media.md`.
