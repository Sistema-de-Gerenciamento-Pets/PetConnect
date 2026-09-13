# Validação manual — configurações e mídia do perfil do pet

> Branch: `fix/configuracoes-e-visual-pet`. Fonte:
> `prompt_correcao_configuracoes_perfil_pet.md` (2026-09-13) — o mesmo
> problema relatado no vídeo enviado.

## Como testar

Atualizar o app no celular com o código desta branch e abrir o perfil de
pelo menos dois pets diferentes (ex.: Felícia e Aleks).

## Checklist

- [ ] Configurações da Felícia abrem a Felícia (título "Configurações de
      Felícia")
- [ ] Configurações do Aleks abrem o Aleks (título "Configurações de
      Aleks")
- [ ] Nenhuma configuração do tutor aparece ali (sem "Sair da conta",
      "Excluir conta" ou dados de e-mail/senha do tutor)
- [ ] "Editar perfil" abre o formulário do pet correto
- [ ] "Excluir" está somente nas configurações (não mais na tela
      principal do perfil)
- [ ] "Editar" não aparece mais como botão no fim da tela principal do
      perfil
- [ ] "Excluir" não aparece mais na tela principal do perfil
- [ ] Avatar do pet abre a visualização fullscreen
- [ ] Zoom (pinça) funciona no fullscreen
- [ ] Back (gesto ou botão do Android) fecha o visualizador
- [ ] Pet sem foto: tocar no avatar não faz nada (nem quebra)
- [ ] Capa aparece no cabeçalho do perfil (quando cadastrada)
- [ ] Pet sem capa mostra o gradiente de fallback, nunca uma área quebrada
      ou uma foto errada
- [ ] "Alterar"/"Adicionar capa" nas configurações do pet abre a galeria e
      envia a foto
- [ ] "Remover" capa funciona e volta pro fallback
- [ ] Navegação mantém o pet selecionado o tempo todo (Home → Pet →
      Configurações → Editar → Voltar → Configurações → Voltar → Perfil
      do mesmo pet)
- [ ] Sem overflow em nenhuma tela (nenhuma faixa preta/amarela)
- [ ] Nenhum `null` visível em nenhum campo

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar, não mesclar a PR até corrigir.

> **Status: validado fisicamente pelo tutor (2026-09-13).** Checklist
> acima confirmado — "Testei, deu tudo certo" — e as duas PRs
> (TecnoDreamer/PetConnect#54, AleksGustavo/PetConnect-API#14) mescladas.

---

## Atualização 2026-09-13 — avatar maior + reposicionar a capa

Branch: `feat/ajuste-avatar-e-posicao-capa`.

- [ ] Avatar do perfil está visivelmente maior que antes
- [ ] Continua sem overflow em nenhuma largura de tela
- [ ] Configurações do Pet mostra "Ajustar posição" quando há capa
      cadastrada
- [ ] "Ajustar posição" **não** aparece quando o pet não tem capa
- [ ] Arrastar a foto no editor move a área visível pra cima/baixo, sem
      nunca deixar espaço vazio
- [ ] "SALVAR" aplica a nova posição e ela aparece correta no perfil
      depois de voltar
- [ ] Sair do editor sem tocar em "SALVAR" mantém a posição anterior
- [ ] Enviar uma foto de capa nova já abre o editor de posição em
      seguida
- [ ] A posição escolhida persiste depois de fechar e reabrir o app
