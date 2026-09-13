# Validação manual — temas globais e menus de configurações

> Branch: `feat/tema-e-menus-configuracoes`. Fonte:
> `prompt_tema_e_menus_configuracoes_petconnect.md` (2026-09-13).

## Como testar

Atualizar o app no celular com o código desta branch. Testar os três
modos (Configurações → Tema do aplicativo) em: Home, perfil de um pet,
Configurações do Tutor, Configurações do Pet.

## Checklist

- [ ] Configurações do tutor seguem o novo estilo (ícone + título +
      chevron, sem subtítulo)
- [ ] Configurações do pet seguem o novo estilo
- [ ] Sem descrições nos itens de navegação (ex.: "Editar perfil" sem
      "Nome, telefone e foto" embaixo)
- [ ] Ícones consistentes entre as telas
- [ ] Chevron em todo item navegável
- [ ] Linha inteira clicável (não só o ícone/chevron)
- [ ] Tema Padrão funciona (visual igual ao de sempre)
- [ ] Tema Claro funciona
- [ ] Tema Escuro funciona (sem texto preto em fundo escuro, sem card
      branco estourado)
- [ ] Preferência de tema persiste depois de fechar e reabrir o app
- [ ] Perfil do tutor (Home) responde ao tema
- [ ] Perfil do pet responde ao tema (capa, avatar, cards, QR, menus)
- [ ] Visualizador de imagem (avatar/capa em tela cheia) continua
      funcionando em qualquer tema
- [ ] Dialogs (confirmação de excluir, sair) respondem ao tema
- [ ] Status bar legível nos três modos
- [ ] Sem overflow em nenhuma tela migrada
- [ ] Fonte do sistema ampliada não quebra os menus

## Fora do escopo desta validação (esperado)

Estas telas **não foram migradas** nesta etapa e devem continuar com a
aparência do modo Padrão, **mesmo com Claro/Escuro selecionado** — não é
falha, é o hardcode documentado em
`docs/features/theme-and-settings-menu.md`:

- Login, Cadastro, Esqueci minha senha, Splash
- Vacinas, Consultas, Histórico Médico, Localização (listas e formulários)

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar numa tela migrada, não mesclar a PR até corrigir.
