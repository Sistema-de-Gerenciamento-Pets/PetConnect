# Validação física — correção do QR code público

> Preencher depois de atualizar o app no celular com a correção
> (`fix/qr-code-pet-publico`). Já verificado via API direta (`curl`) pelos
> 3 pets abaixo — falta a confirmação escaneando de verdade.

## Pré-requisito

Reinstalar/atualizar o app no celular com o código da branch
`fix/qr-code-pet-publico` (ou depois que ela for mesclada). Sem isso, o
QR continua sendo gerado com o código antigo.

## Pet antigo 1 — Felícia

| Item | Esperado | Resultado |
|---|---|---|
| QR abre | Sim | |
| URL correta | `.../pet/120be11d-c25d-3a9e-a018-659f3da8fcff` | |
| Pet encontrado | Sim | |
| Nome correto | Felícia | |
| Foto correta | | |
| Dados públicos corretos (espécie, status) | Gato, Ativo | |
| Nenhum dado privado vazado | Sem tutorId/e-mail | |

**Confirmado via API direta** (`curl`, antes da validação física):
`GET /api/v1/public/pets/120be11d-c25d-3a9e-a018-659f3da8fcff` → `200`,
`{"name":"Felícia","species":"CAT","status":"ACTIVE",...}`.

## Pet antigo 2 — Nymeria (Mavis/Maevis é o mesmo padrão, mesma migração)

| Item | Esperado | Resultado |
|---|---|---|
| QR abre | Sim | |
| URL correta | `.../pet/7cd148f7-07b3-3505-b721-4e256d24cdef` | |
| Pet encontrado | Sim | |
| Nome correto | Nymeria | |
| Foto correta | | |
| Dados públicos corretos | Cachorro, Ativo | |
| Nenhum dado privado vazado | | |

**Confirmado via API direta**: `200`, dados corretos.

## Pet novo — Aleks

| Item | Esperado | Resultado |
|---|---|---|
| QR abre | Sim | |
| URL correta | `.../pet/ecd2daf7-1279-3785-ac70-d06dfd03ee18` | |
| Pet encontrado | Sim | |
| Nome correto | Aleks | |
| Foto correta | | |
| Dados públicos corretos | Cachorro, Ativo | |
| Nenhum dado privado vazado | | |

**Confirmado via API direta**: `200`, dados corretos.

## Teste adicional — pet criado depois desta correção

1. Cadastrar um pet novo no app (com a correção instalada).
2. Abrir o QR code dele.
3. Escanear.
4. **Esperado**: `404` — "Não encontramos esse pet" (mensagem correta,
   não é um erro). Isso é esperado até uma nova rodada de migração
   incluir esse pet (limitação conhecida, ver
   `docs/fixes/qr-public-pet-not-found.md`, seção "Riscos"). Confirma
   que a página distingue certo "não encontrado" de erro de servidor.

## Como reportar

Preencher a coluna "Resultado" com o que aconteceu de fato ao escanear
cada QR no celular, e marcar aqui: `PASS` / `FAIL` / `BLOCKED`.
