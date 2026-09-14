# Validação manual — confirmação ao cancelar consulta

> Branch: `fix/confirmacao-cancelamento-consulta`.

## Como testar

Atualizar o app no celular com o código desta branch. Precisa de pelo
menos uma consulta agendada (RF27) pra testar — crie uma se necessário.

## Checklist

- [ ] Tocar em "Cancelar" no card de uma consulta agendada abre um
      diálogo, **sem cancelar nada ainda**
- [ ] O diálogo menciona a data (e veterinário, se houver) da consulta
      certa — não uma mensagem genérica
- [ ] Tocar em "Voltar" fecha o diálogo e a consulta continua em
      "Futuras", normalmente
- [ ] Tocar em "Sim, cancelar" move a consulta pra seção "Canceladas"
- [ ] Durante a confirmação, aparece um indicador de carregamento
      rápido (pode não dar tempo de ver num aparelho rápido — tudo bem)
- [ ] Tocar duas vezes rápido em "Sim, cancelar" não causa erro nem
      duplica nada
- [ ] Se desligar a internet e tentar cancelar, aparece um aviso
      ("Não foi possível cancelar...") e a consulta continua agendada
- [ ] "Marcar realizada" continua funcionando exatamente como antes
      (sem confirmação — fora do escopo desta mudança)

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar, não mesclar a PR até corrigir.
