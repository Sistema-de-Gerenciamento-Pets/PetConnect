# Checklist de Validação em Dispositivo Físico

> Não executado por mim (não posso operar o celular do usuário) — pronto
> pra execução humana. Preenche as colunas "Resultado obtido",
> "PASS/FAIL/BLOCKED" e "Evidência" (screenshot/print) conforme for testando.
>
> **Ordem progressiva das flags** (confirmada contra o código —
> `lib/core/config/app_config.dart` não tem dependência declarada entre
> flags, mas a ordem abaixo segue a dependência *funcional* real: pets
> precisa existir antes de vacina/consulta/histórico/localização
> conseguirem ser exercitados de ponta a ponta):
>
> 1. `USE_API_USUARIO`
> 2. `USE_API_PETS`
> 3. `USE_API_VACINAS`
> 4. `USE_API_CONSULTAS`
> 5. `USE_API_HISTORICO`
> 6. `USE_API_LOCALIZACAO`
> 7. `USE_API_UPLOAD`
>
> Ative uma a mais por vez (mantendo as anteriores ligadas), não todas de
> uma vez — assim, se algo falhar, fica óbvio qual flag causou.
>
> **Comando base** (ajuste o IP/flags por rodada):
> ```bash
> adb reverse tcp:8090 tcp:8090   # celular por USB
> flutter run --dart-define=API_BASE_URL=http://localhost:8090 \
>   --dart-define=USE_API_USUARIO=true   # ... acumule as próximas flags aqui
> ```

---

## Rodada 1 — `USE_API_USUARIO`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV01 | Cadastro | Fluxo principal | App deslogado | Cadastrar novo tutor | Login efetuado, Home abre | | | | |
| DV02 | Login | Fluxo principal | Conta já existe | Logar com e-mail/senha | Home abre | | | | |
| DV03 | Perfil | Edição | Logado | Editar nome/telefone/data nasc. | Salva e reflete na tela de configurações | | | | |
| DV04 | Perfil | Erro | Logado, sem internet | Tentar editar perfil | Mensagem de erro clara, não trava a tela | | | | |
| DV05 | Sessão | Persistência | Logado | Fechar e reabrir o app | Continua logado, sem pedir login de novo | | | | |
| DV06 | Logout | Fluxo principal | Logado | Configurações → Sair | Volta pro login | | | | |
| DV07 | Conta | Exclusão | Logado, conta de teste | Configurações → Excluir conta → confirmar | Conta some, volta pro login, dados relacionados removidos | | | | |
| DV08 | Rede | Timeout/token expirado | Logado, token expirado (esperar ele expirar ou forçar) | Abrir qualquer tela que chama a API | Erro tratado (não crasha, não mostra stack trace) | | | | |

## Rodada 2 — + `USE_API_PETS`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV09 | Pets | Criar | Logado | Cadastrar um pet novo (nome, espécie, foto) | Aparece na Home imediatamente | | | | |
| DV10 | Pets | Listar | 2+ pets cadastrados | Abrir a Home | Todos os pets aparecem | | | | |
| DV11 | Pets | Editar | Pet existe | Editar nome/foto do pet | Alterações refletidas na lista e no detalhe | | | | |
| DV12 | Pets | Excluir | Pet existe | Excluir pet, confirmar diálogo | Pet some da lista, sem confirmação = não exclui | | | | |
| DV13 | Pets | Vazio | Nenhum pet cadastrado (conta nova) | Abrir a Home | Estado vazio claro (não tela branca/erro) | | | | |
| DV14 | Pets | Pull-to-refresh | Lista de pets aberta | Arrastar pra baixo | Recarrega, indicador visual aparece e desaparece | | | | |
| DV15 | QR Code | Geração | Pet existe | Abrir detalhe do pet | QR code exibido, único por pet | | | | |
| DV16 | QR Code | Escaneamento | QR code de um pet | Escanear com outro dispositivo, deslogado | (Depende da FASE 9 — página pública ainda não hospedada; ver nota) | | BLOCKED | | Página pública do QR ainda não existe (FASE 9) |

## Rodada 3 — + `USE_API_VACINAS`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV17 | Vacinas | Registrar | Pet existe | Adicionar vacina (nome, data, próxima dose) | Aparece na lista, ordenada por data | | | | |
| DV18 | Vacinas | Editar/excluir | Vacina existe | Editar e depois excluir | Reflete corretamente nos dois casos | | | | |
| DV19 | Vacinas | Alerta de vencimento | Vacina com próxima dose no passado | Abrir perfil do pet | Indicador visual de alerta | | | | |
| DV20 | Vacinas | Vazio | Pet sem vacinas | Abrir lista de vacinas | Estado vazio claro | | | | |

## Rodada 4 — + `USE_API_CONSULTAS`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV21 | Consultas | Agendar | Pet existe | Agendar consulta (data/hora, motivo) | Aparece como "futura" | | | | |
| DV22 | Consultas | Cancelar | Consulta futura existe | Cancelar | Status muda pra "cancelada", não conta como pendente | | | | |
| DV23 | Consultas | Marcar como realizada | Consulta futura existe | Marcar como realizada | Status atualiza, sai da lista de futuras | | | | |
| DV24 | Consultas | Duplo toque | Formulário de consulta preenchido | Tocar "Salvar" duas vezes rápido | Não cria duas consultas duplicadas | | | | |

## Rodada 5 — + `USE_API_HISTORICO`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV25 | Histórico | Registrar | Pet existe | Adicionar entrada (data, descrição) | Aparece na lista, ordenada por data | | | | |
| DV26 | Histórico | Editar/excluir | Entrada existe | Editar e depois excluir | Reflete corretamente | | | | |
| DV27 | Histórico | Anexo | Formulário aberto | Subir um anexo, depois remover antes de salvar | Anexo removido da tela; não deveria aparecer no registro salvo | | | | |

## Rodada 6 — + `USE_API_LOCALIZACAO`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV28 | Localização | Registrar avistamento (autenticado) | Pet existe | Adicionar avistamento com data passada | Aparece na lista do pet | | | | |
| DV29 | Localização | Listar | Avistamentos existem | Abrir lista | Ordenados corretamente | | | | |
| DV30 | Localização | Avistamento público (QR) | — | (Depende da FASE 9 — página pública) | | | BLOCKED | | Página pública do QR ainda não existe |

## Rodada 7 — + `USE_API_UPLOAD`

| ID | Feature | Cenário | Pré-condição | Passos | Resultado esperado | Resultado obtido | Status | Evidência | Bug relacionado |
|---|---|---|---|---|---|---|---|---|---|
| DV31 | Upload | Foto de perfil | Logado | Trocar foto do tutor | Nova foto salva e exibida | | BLOCKED | | Round-trip real do Cloudinary não testado — falta `CLOUDINARY_API_SECRET` (ver `05-security-review.md`) |
| DV32 | Upload | Foto de pet | Pet existe | Trocar foto do pet | Nova foto salva e exibida | | BLOCKED | | idem |
| DV33 | Upload | Anexo de histórico | Formulário de histórico aberto | Subir e depois excluir um anexo | Some da lista e do Cloudinary | | BLOCKED | | idem |
| DV34 | Upload | Posse do arquivo | Duas contas de teste | Conta A sobe um arquivo; confirmar (via código/log, não pela UI) que a conta B não conseguiria excluí-lo | 404 pra conta B | | | | Ver `05-security-review.md` — testado automatizado, falta confirmar no device real |

---

## Verificações transversais (repetir em cada rodada)

- [ ] Fechar e reabrir o app não perde o estado da sessão.
- [ ] Nenhuma escrita indevida acontece no Firestore com a flag ligada
      (checar no console do Firebase que a coleção correspondente não
      recebeu novo documento).
- [ ] Testar com Wi-Fi desligado no meio de uma operação — mensagem de
      erro clara, sem crash.
- [ ] Rotação de tela (se aplicável)/orientação não perde dados do
      formulário em andamento.

## Como reportar um resultado

Para cada linha testada, preencher:
- **Resultado obtido**: o que de fato aconteceu.
- **Status**: `PASS` / `FAIL` / `BLOCKED` (não deu pra testar) /
  `NOT_APPLICABLE`.
- **Evidência**: descrição do print/vídeo (nome do arquivo, se salvar um).
- **Bug relacionado**: link/referência se abrir um issue.
