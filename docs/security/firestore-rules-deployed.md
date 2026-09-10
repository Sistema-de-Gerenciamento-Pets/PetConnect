# Firestore Security Rules — deployadas hoje (R-02)

> Coladas pelo usuário do console em 2026-09-10. Projeto `pet-connect-c53f1`.
> Registradas aqui porque **não existem no repositório** (`firebase.json` não referencia `firestore.rules`).

## Conteúdo atual

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

## Recomendação

1. **Não endurecer agora de forma agressiva** — os 18 usuários reais ainda usam o app (versão antiga + a nova lê o mesmo banco). Mudança brusca quebra o app antigo.
2. **Endurecimento de baixo risco possível já:** trocar o catch-all `allow read;` por `allow read: if request.auth != null;` (remove a leitura anônima de `Usuarios`). Só a página pública do QR precisa de leitura anônima de pet — e isso passará a ser um endpoint do Spring (FASE 9), não o Firestore.
3. **`Localizacoes` `write: if true`** deve virar `if false` assim que o app antigo parar de escrever lá (a nova gravação de avistamento vai para a API). Confirmar se algo ainda escreve.
4. **Endurecimento final (FASE 11):** após FASES 3–5 validadas, `allow read, write: if false` nas coleções já migradas; manter só o essencial para o app antigo até a FASE 13.
5. Versionar as regras: criar `firestore.rules` no repo e referenciar em `firebase.json`, para nunca mais o conteúdo real ficar só no console.
