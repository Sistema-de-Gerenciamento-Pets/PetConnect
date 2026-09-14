# Redesign da Home do tutor ("Meus Pets")

> Branch: `feat/redesign-home-tutor`. Fonte:
> `prompt_redesign_home_tutor_petconnect.md` (2026-09-13). Referência
> visual: print da nova Home (cabeçalho + lista de cards de pet), no mesmo
> espírito estrutural usado no pedido anterior (print do app Inter).

## Objetivo

Reorganizar visualmente a Home do tutor pra ficar mais limpa e direta —
sem o "card mestre" branco flutuando sobre o fundo, cabeçalho com acesso
mais discreto às configurações, e cards de pet mais informativos (agora
também sinalizando ausência de vacinas cadastradas) — **sem alterar
nenhuma regra de negócio, navegação ou dado** já existente.

## Auditoria (antes de implementar)

1. **Arquivo/estrutura atual**: `home_screen.dart` — um `Container` branco
   com sombra ("card mestre") envolvendo cabeçalho, CTA de adicionar pet,
   título "Meus Pets" e a lista, tudo sobre o fundo `colors.homeBackdrop`.
2. **`PetCard`**: já existia (`pet_card.dart`), com fundo colorido cíclico
   por pet (`petCardBackgrounds[colorIndex]`) — o redesign pede fundo
   branco/uniforme (`cardBackground`), com o destaque colorido só no badge
   de pata.
3. **Providers envolvidos**: `currentUsuarioProvider` (dados do tutor),
   `petsProvider` (lista de pets do tutor), e — novo pra esta tela —
   `vacinasProvider(petId)` (`StreamProvider.family`, já existia pra uso no
   perfil do pet).
4. **Modelo `Pet`**: sem campo de "tem vacina" — precisa ser derivado a
   partir da lista de vacinas de cada pet, não existe agregado pronto no
   backend.
5. **Cálculo de idade**: `idadeEmAnos()` (`core/utils/br_date.dart`), já
   usado no perfil do pet — reaproveitado aqui, não recriado.
6. **Fluxo "Adicionar pet"**: `context.push('/pet/novo')`, inalterado —
   só muda a aparência do botão (de card grande para pílula ao lado do
   título).
7. **Rota de configurações do tutor**: `context.push('/configuracoes')`,
   inalterada — só muda o ícone que a aciona (engrenagem → "⋮").
8. **Concorrência de dados**: cada `PetCard` agora observa seu próprio
   `vacinasProvider(pet.id)` — ver "Performance e N+1" abaixo.

## O que mudou visualmente

- **Fundo direto**: removido o `Container` branco com `BoxShadow` que
  envolvia tudo — o fundo da página (`colors.homeBackdrop`) aparece
  diretamente atrás do cabeçalho, título e lista.
- **Cabeçalho**: avatar do tutor + "Olá, {primeiro nome}!" + subtítulo,
  como antes; o botão de configurações trocou o ícone de engrenagem
  (`Icons.settings_outlined`) por reticências verticais (`Icons.more_vert`,
  com `Tooltip`/rótulo "Configurações") — mesmo destino
  (`/configuracoes`), só o ícone mudou.
- **Título + CTA na mesma linha**: "Meus Pets" (`Expanded`, com
  `TextOverflow.ellipsis`) e o novo botão em formato de pílula
  "+ Adicionar pet" dividem uma única `Row`, substituindo o antigo card
  verde grande de call-to-action.
- **Cards de pet uniformes**: fundo branco/`cardBackground` em todos os
  cards (antes cada pet tinha uma cor de fundo cíclica própria) — o
  destaque colorido cíclico (`petCardAccents`) continua existindo, só que
  agora só no pequeno badge de pata sobre a foto.
- **Badge de gênero**: pílula com ícone (♂/♀) + texto ("Macho"/"Fêmea").
  "Macho" reaproveita o azul cíclico já usado em outros cards do app
  (`petCardAccents`/`petCardBackgrounds[3]`); "Fêmea" usa um par de tons
  de rosa novo na paleta (não havia nenhum tom de rosa reutilizável antes
  desta tela) — `AppPalette.genderFemaleForeground`/
  `genderFemaleBackground`.
- **Badge "Vacina pendente"** (novo, ver seção própria abaixo).
- **Rodapé**: antes usava `colors.homeBackdrop` pra se destacar do card
  branco de fundo; como agora o próprio fundo da página é
  `homeBackdrop`, o rodapé passou a usar `colors.surface`.

## Regra do badge "Vacina pendente"

Aparece **somente quando o pet não tem nenhuma vacina cadastrada**
(`vacinas.isEmpty`, depois que a consulta a `vacinasProvider(pet.id)`
resolve com sucesso).

**Importante**: "Vacina pendente" nesta versão significa ausência total de
vacinas cadastradas e não representa avaliação clínica do calendário
vacinal. Não existe, nesta etapa, o conceito de "dose atrasada"/"reforço
vencido" — isso depende de uma regra de calendário vacinal que ainda não
foi implementada (fica como melhoria futura, fora do escopo deste
documento).

Por segurança, o badge **nunca aparece** enquanto o status ainda não é
conhecido com certeza:

- **Carregando** (`vacinasProvider` em `AsyncLoading`): não mostra o
  badge (nem "pendente" nem "em dia") — declarar pendência sem
  confirmação seria pior que não mostrar nada.
- **Erro** (`vacinasProvider` em `AsyncError`): mesmo comportamento —
  não classifica como "sem vacina".
- Só com a lista carregada e vazia é que o badge aparece.

## Componentes novos

- `PetGenderBadge` (`features/pet/presentation/widgets/pet_gender_badge.dart`)
  — badge de gênero reutilizável, resolve cor por `context.colors`, nunca
  depende só de cor (ícone + texto sempre presentes).
- `VaccinePendingBadge`
  (`features/pet/presentation/widgets/vaccine_pending_badge.dart`) —
  widget "burro" de propósito: recebe `visible: bool` já calculado pelo
  chamador (`PetCard`, que já observa `vacinasProvider`), em vez de buscar
  os próprios dados. Mantém a lógica de loading/erro num único lugar (o
  card) e deixa o badge trivialmente testável isolado.

## `PetCard` (adaptado, não recriado)

Continua sendo `PetCard` (não virou uma classe nova) — é o mesmo
componente, num único ponto de uso (`home_screen.dart`), só que agora:

- é um `ConsumerWidget` (precisa de `ref.watch(vacinasProvider(pet.id))`);
- fundo uniforme (`colors.cardBackground`), sem cor cíclica de fundo;
- `Semantics` combinado por card, incluindo a pendência de vacina quando
  aplicável (`"Rex, cachorro, 3 anos, macho. Nenhuma vacina cadastrada."`);
- badges de gênero e vacina pendente ficam num `Wrap` (não `Row`) —
  em telas estreitas, o segundo badge quebra pra linha de baixo em vez de
  estourar.

## Performance e N+1 (limitação aceita e documentada)

Cada `PetCard` observa `vacinasProvider(pet.id)` — um
`StreamProvider.family` sem endpoint agregado no backend (não existe hoje
um "status de vacina por pet" em lote). Isso significa uma requisição por
pet visível na Home.

Isto é uma **limitação conhecida e aceita nesta etapa**, não um descuido:
o documento-fonte autoriza explicitamente reaproveitar a arquitetura
existente em vez de desenhar um novo endpoint de backend só pra esta
tela, dado que o número de pets por tutor tende a ser pequeno na prática.
O Riverpod já deduplica automaticamente múltiplos `watch` do mesmo
`(provider, family-arg)` — não há chamadas duplicadas entre o card e
qualquer outro widget que eventualmente observe o mesmo pet.

Se o número de pets por tutor crescer a ponto de isso pesar, a melhoria
natural é um endpoint de backend que devolva o status de vacina de todos
os pets de um tutor numa única chamada — fica como ideia registrada para
uma iteração futura, não implementada aqui.

## Navegação (inalterada)

- Tocar em qualquer lugar do card → `/pet/{id}` (perfil do pet).
- Tocar em "Adicionar pet" → `/pet/novo`.
- Tocar no "⋮" do cabeçalho → `/configuracoes`.
- Puxar pra atualizar (`RefreshIndicator`) → reinvalida `petsProvider`.

## Estados preservados

Loading/erro do tutor, loading/erro da lista de pets, lista vazia (com a
mensagem atualizada pra citar "Adicionar pet", o novo nome do botão) e
pull-to-refresh — todos os comportamentos e condições de disparo
existentes antes do redesign continuam exatamente iguais.

## Acessibilidade

- Avatar do tutor com `Semantics` própria ("Foto de {nome}"/"Foto do
  tutor").
- Botão "Adicionar pet" com `Semantics(button: true, label: 'Adicionar
  pet')`.
- Botão "⋮" com `Tooltip` "Configurações".
- Badges nunca dependem só de cor (ícone + texto sempre presentes).
- `Semantics` do card inclui a pendência de vacina no mesmo rótulo, sem
  exigir navegação extra pra descobrir.

## Segurança

Nenhuma mudança de autorização, rota ou regra de dados — só apresentação.
Nenhum dado novo é enviado ao backend; o único dado novo *lido* é a lista
de vacinas por pet, que já existe e já é usada no perfil do pet (mesmo
provider, mesmo endpoint).

## Testes

- `flutter analyze` — sem apontamentos.
- `flutter test test/core/ test/features/pet/ test/features/auth/
  test/features/usuario/ --exclude-tags=e2e` — ver relatório da PR pro
  número exato.
- Novo: `test/features/usuario/home_screen_test.dart` — cabeçalho (foto/
  ícone padrão, saudação com nome real, "Olá!" genérico sem nome, menu
  "⋮" e navegação), "Adicionar pet" (posição na mesma linha do título,
  navegação), card de pet (foto/fallback, nome, espécie, gênero, chevron,
  navegação pro pet certo), badge de gênero, badge "Vacina pendente" (sem
  vacina mostra, com vacina não mostra, loading não mostra, erro não
  mostra), estados de erro/vazio, e responsividade em 320px com nome
  longo (achou e corrigiu um overflow real nos badges — ver "Correção" no
  changelog do commit).

## Rollback

Reverter o merge. Nenhum dado persistido é criado por esta mudança (só
leitura de vacinas já existente) — reverter não deixa nada órfão.

## Validação manual

Ver `docs/validation/home-tutor-redesign.md`.
