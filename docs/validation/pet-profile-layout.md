# Validação manual — novo layout do perfil do pet

> Branch: `feature/perfil-pet-layout`. Fonte:
> `prompt_claude_perfil_pet_layout.md` (2026-09-12).
>
> Testes automatizados (`flutter analyze`, `flutter test`) já passam — ver
> relatório da PR. Este checklist cobre o que só dá pra confirmar num
> aparelho real: aparência, toque, fontes do sistema, rede real.

## Como testar

Atualizar o app no celular com o código desta branch (mesmo processo já
usado para a correção do QR code: `flutter run` conectado ao aparelho, ou
instalar o build gerado a partir dela) e abrir o perfil de qualquer pet
já cadastrado.

## Checklist

- [ ] Foto correta (ou o ícone de fallback, se o pet não tiver foto)
- [ ] Nome correto
- [ ] Dados básicos corretos (espécie/raça, idade, gênero, peso, vacinado)
- [ ] Sem campos `null`/vazios visíveis — o que não existe simplesmente não aparece
- [ ] Carteira de Vacinas abre (e mostra o aviso quando há dose pendente)
- [ ] Agenda de Consultas abre (e mostra o aviso quando há consulta próxima)
- [ ] Histórico Médico abre
- [ ] QR Code abre (no modal, sem sair da tela do perfil)
- [ ] Localização (avistamentos) abre
- [ ] Configurações abre
- [ ] Back funciona em todos os casos acima e volta pro mesmo pet
- [ ] Editar funciona
- [ ] Excluir funciona (com a confirmação de sempre)
- [ ] Scroll funciona, sem travar
- [ ] Sem overflow (nenhuma faixa preto/amarelo) em nenhum ponto da tela
- [ ] Com fonte do sistema ampliada (Configurações do Android/iOS), a tela
      continua legível e sem overflow
- [ ] Pet sem foto cadastrada mostra o fallback corretamente
- [ ] Com internet lenta, aparece o indicador de carregamento da foto (não
      trava a tela)
- [ ] Rotação de tela, se o app já suportar (caso contrário, N/A)

## Como reportar

Marcar cada item como `[x]` (passou) ou anotar `FALHOU: <o que aconteceu>`
ao lado. Se algo falhar, não mesclar a PR até corrigir.
