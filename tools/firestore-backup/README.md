# Backup + auditoria do Firestore (FASE 0)

Ferramenta de **uso único** para a migração Firestore → Spring/MongoDB.
**Somente leitura** — não altera nada no Firestore. **Não requer plano Blaze.**

## O que faz

1. Lê todas as coleções e subcoleções do Firestore do projeto `pet-connect-c53f1`.
2. Salva cada uma como JSON em `output/<timestamp>/` — este é o **backup**.
3. Gera `output/<timestamp>/report.md` com o **relatório de qualidade de dados**
   (contagens, campos nulos, datas inválidas, valores distintos de enum, órfãos,
   possíveis documentos com schema antigo).

## Pré-requisitos

- Node.js 18+ instalado (`node --version`).
- Uma **chave de conta de serviço** do Firebase (grátis, plano Spark serve).

## Como pegar a chave de conta de serviço

1. Abra o [Firebase Console](https://console.firebase.google.com/) → projeto **pet-connect-c53f1**.
2. Engrenagem (canto sup. esq.) → **Configurações do projeto**.
3. Aba **Contas de serviço**.
4. Botão **Gerar nova chave privada** → confirma → baixa um `.json`.
5. Renomeie/mova esse arquivo para:
   ```
   tools/firestore-backup/serviceAccountKey.json
   ```

> Esse arquivo é uma credencial de administrador. O `.gitignore` desta pasta já
> impede que ele seja commitado. **Não compartilhe e não coloque no git.**
> Depois da migração, revogue a chave no mesmo lugar (Contas de serviço → excluir).

## Rodar

Na pasta `tools/firestore-backup/`:

```bash
npm install
npm run backup
```

Ao final, o script imprime o caminho de `output/<timestamp>/`.
Abra o `report.md` gerado e **cole o conteúdo no chat** para seguirmos a migração.
Guarde a pasta `output/` inteira em local seguro (é o backup pré-migração).

## Segurança

- Nenhuma escrita/exclusão é feita no Firestore.
- `serviceAccountKey.json` e `output/` são ignorados pelo git.
- Se `npm install` reclamar de rede corporativa/proxy, rode de uma rede sem VPN.
