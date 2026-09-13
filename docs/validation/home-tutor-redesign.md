# Validação manual — redesign da Home do tutor

> Branch: `feat/redesign-home-tutor`. Fonte:
> `prompt_redesign_home_tutor_petconnect.md` (2026-09-13).

## Como testar

Atualizar o app no celular com o código desta branch. Testar com pelo
menos: um tutor com foto e outro sem foto; um pet com vacina cadastrada e
outro sem nenhuma; ao menos um pet "Macho" e um "Fêmea"; e, se possível,
um pet com nome bem longo.

## Checklist

### Cabeçalho

- [ ] Foto do tutor aparece (ou o ícone padrão, se não houver foto)
- [ ] Saudação usa o primeiro nome real do tutor ("Olá, {nome}!")
- [ ] Botão "⋮" (não mais engrenagem) abre Configurações do tutor
- [ ] Nome muito longo não quebra o layout do cabeçalho (usa reticências)

### Título + "Adicionar pet"

- [ ] "Meus Pets" e o botão "+ Adicionar pet" aparecem na mesma linha
- [ ] Tocar em "Adicionar pet" abre o cadastro de um novo pet, como antes
- [ ] O antigo card verde grande de CTA não aparece mais

### Fundo da página

- [ ] Não existe mais um "card branco" com sombra envolvendo tudo — o
      fundo da página aparece diretamente atrás do cabeçalho e da lista
- [ ] Rodapé continua visualmente distinto do fundo da página

### Cards de pet

- [ ] Todos os cards têm o mesmo fundo (branco/neutro) — sem cor de fundo
      diferente por pet
- [ ] O pequeno badge de pata sobre a foto continua colorido (cor cíclica
      por pet)
- [ ] Nome, espécie e idade aparecem corretamente
- [ ] Badge de gênero aparece com ícone (♂/♀) e o texto ("Macho"/"Fêmea")
- [ ] Tocar em qualquer parte do card (não só no chevron) abre o perfil
      do pet certo

### Badge "Vacina pendente"

- [ ] Pet **sem nenhuma vacina cadastrada** mostra o badge "Vacina
      pendente"
- [ ] Pet **com pelo menos uma vacina cadastrada** não mostra o badge
- [ ] Cadastrar a primeira vacina de um pet e voltar pra Home: o badge
      some (puxar pra atualizar, se não sumir sozinho)
- [ ] Excluir a única vacina de um pet e voltar pra Home: o badge volta a
      aparecer
- [ ] O badge nunca aparece "piscando" incorretamente durante o
      carregamento inicial da tela

### Estados gerais (devem continuar funcionando como antes)

- [ ] Sem pets cadastrados: mensagem de lista vazia menciona "Adicionar
      pet"
- [ ] Erro ao carregar dados do tutor: mensagem amigável, tela não quebra
- [ ] Erro ao carregar pets: mensagem amigável, tela não quebra
- [ ] Puxar pra atualizar (pull-to-refresh) funciona
- [ ] Tema Padrão/Claro/Escuro continuam funcionando na Home

### Responsividade

- [ ] Sem overflow em nenhum aparelho testado, mesmo com nome de pet
      longo e os dois badges (gênero + vacina pendente) juntos
- [ ] Fonte do sistema ampliada não quebra o cabeçalho nem os cards

## Fora do escopo desta validação (esperado)

- "Vacina pendente" só significa **ausência total de vacinas
  cadastradas** — não existe "dose atrasada"/calendário vacinal vencido
  nesta versão. Um pet com vacinas cadastradas, mesmo que desatualizadas,
  **não** deve mostrar o badge.
- Nenhuma tela além da Home foi alterada por este documento (perfil do
  pet, configurações, tema, QR, vacinas/consultas/histórico seguem
  exatamente como estavam).

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar, não mesclar a PR até corrigir.
