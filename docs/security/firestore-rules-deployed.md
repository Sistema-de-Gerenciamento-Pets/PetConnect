# Firestore Security Rules — histórico (R-02)

> Projeto `pet-connect-c53f1`. A partir de 2026-09-11 as regras **vivem em
> `firestore.rules`** na raiz do repo (referenciado por `firebase.json`) —
> este arquivo passa a ser só o histórico/análise, não a fonte da verdade.

## ✅ 2026-09-11 — FASE 11, passo 1: leitura/escrita anônima fechada

Deploy feito (`firebase deploy --only firestore:rules`) e **verificado**:
`GET Pets`/`Localizacoes` sem token → `403 PERMISSION_DENIED` (antes: 200,
aberto); com um ID Token real → `200` continua normal (não quebrou nada que
já exigia login). Nada que já dependia de `request.auth != null` mudou de
comportamento — só o acesso **sem login nenhum** deixou de funcionar.

Confirmado com o usuário antes do deploy: não existe mais nenhum fluxo
público real (página/Cloud Function) escrevendo em `Localizacoes` — os 95
registros eram só histórico de scans de QR de uma versão antiga, já
migrados pro MongoDB. Por isso a escrita pública dessa coleção também foi
fechada, não só a leitura (rollback: `git revert` no commit que mudou
`firestore.rules` + re-deploy).

O texto exato de antes e depois está no histórico do git de `firestore.rules`
(e reproduzido nas seções abaixo, para quem não tiver acesso ao repo).

## Conteúdo anterior ao endurecimento (deployado até 2026-09-11)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /Usuarios/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.uid;
      allow update: if request.auth != null && request.auth.uid == resource.data.uid;
      allow delete: if request.auth != null && request.auth.uid == resource.data.uid;
    }

    match /Pets/{petId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }

    match /Localizacoes/{docId} {
      allow read, write: if true;
    }

    match /{document=**} {
      allow read;
      allow write: if request.auth != null;
    }
  }
}
```

## Análise

| Regra | Efeito real | Risco |
|---|---|---|
| Catch-all `/{document=**}` → `allow read;` | **Todo documento do banco é legível sem autenticação.** Inclui `Usuarios` (e-mail, telefone, foto, data de nascimento de todos). O bloco `Usuarios` tenta exigir `auth`, mas o catch-all concede leitura antes disso — no Firestore, **basta uma regra conceder**. | 🔴 Vazamento de PII de 18 usuários |
| `Pets` → `allow read: if true;` | Qualquer pessoa na internet lê **todos** os pets, incluindo o `userId` (Auth UID) do dono. | 🟠 Exposição de dados + UIDs |
| `Localizacoes` → `allow read, write: if true;` | Qualquer pessoa lê, **cria, altera e apaga** os 95 registros de GPS. Explica o lixo na coleção (coordenada na Irlanda, duplicatas). | 🔴 Escrita pública irrestrita |
| `Usuarios` create/update/delete → `... == data.uid` | Só o doc da "Gabrielly" tem campo `uid`. Nos outros 17, `resource.data.uid` é `undefined` → condição falsa → **update/delete negados**. Perfis antigos provavelmente só eram alterados por caminho administrativo/versão antiga. | 🟡 Inconsistência (fail-closed) |
| `Pets` update/delete → `... == resource.data.userId` | Correto para os docs que têm `userId` (23 de 24). O pet com `userID` (maiúsculo) fica sem dono válido. | 🟡 |

## Recomendação (situação após o passo 1)

1. ~~Endurecimento de baixo risco~~ ✅ feito em 2026-09-11 (catch-all + `Pets` + `Localizacoes` exigem login agora).
2. ~~Versionar as regras~~ ✅ `firestore.rules` no repo, referenciado em `firebase.json`.
3. **Próximo passo (ainda não feito):** `Localizacoes` → `write: if false` de vez (hoje só exige login; como não há mais uso real, pode ir direto pra bloqueado). Avaliar junto com o restante do endurecimento final.
4. **Endurecimento final (resto da FASE 11):** após uso real nas FASES 4–10 validado (não só e2e), `allow read, write: if false` nas coleções que já têm equivalente 100% funcional na API (`Usuarios`, `Pets`); manter só o essencial pro app antigo até a FASE 13.
5. Rate limiting/CORS/headers de segurança no backend — ainda não feito (fora do escopo do Firestore, mas parte do objetivo original da FASE 11).
