# Schema atual — Cloud Firestore (`pet-connect-c53f1`)

> Etapa obrigatória 02. Levantado **a partir do código** (`lib/features/**/data/firebase_*_repository.dart` + `domain/*.dart`) e de `docs/modelo-dados-firestore.md`.
> ⚠️ Não foi possível inspecionar os dados reais (sem acesso ao console / export). Volumes, valores nulos reais e documentos legados são **desconhecidos** — ver R-01 na auditoria.

Legenda de origem: **base** = já existia antes deste ciclo de desenvolvimento · **app** = criado/escrito pelo app Flutter atual.

---

## Coleção `Usuarios`

- **Doc ID:** `firebaseUid` (o mesmo UID do Firebase Auth). Escrito em `signUp` logo após `createUserWithEmailAndPassword`.
- **Repositório:** `FirebaseUsuarioRepository` (`watchUsuario`, `updateUsuario`, `deleteAccount`).
- **Telas:** cadastro, home (saudação "Olá, {nome}"), configurações, editar-perfil.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string | sim | = Auth UID | app | chave canônica proposta: `firebaseUid` |
| `usuarioID` | string (uuid) | ? | — | base | 2º identificador, **uso não confirmado**; nunca lido como FK no código atual |
| `nome` | string | sim | — | base | primeiro nome / nome informado no cadastro |
| `sobrenome` | string | não (default `''`) | — | app | adicionado neste ciclo; docs antigos podem não ter |
| `email` | string | sim | espelha Auth | base | |
| `telefone` | string | não | — | base | livre, sem máscara persistida |
| `dataNascimento` | string `dd/MM/yyyy` | não (default `''`) | — | base | **não** é Timestamp; pode vir vazio |
| `genero` | string | não | — | base | valores livres ('Masculino'/'Feminino'/'Outro'/…) |
| `foto` | string (URL) \| null | não | Cloudinary | app | `secure_url` do Cloudinary; antes era Firebase Storage |

**Escritas:** `signUp` grava `{nome, sobrenome:'', email, telefone, dataNascimento, genero:'', foto:null, usuarioID?}`. `updateUsuario` faz `update` parcial de `{nome, sobrenome, telefone, dataNascimento, genero, foto?}`.

---

## Coleção `Pets`

- **Doc ID:** auto (`collection('Pets').add(...)`).
- **Repositório:** `FirebasePetRepository` — `watchPets` filtra `where('userId', isEqualTo: uid)`.
- **Telas:** home (lista), pet_detail, pet_form.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | — | app | proposta: `petId` |
| `userId` | string | sim | → `Usuarios` (doc id) | base | dono do pet; usado no filtro da lista |
| `nome` | string | sim | — | base | |
| `especie` | string | sim | — | base | livre ('Cachorro'/'Gato'/…) |
| `raca` | string | não | — | base | |
| `cor` | string | não | — | base | |
| `genero` | string | não | — | base | |
| `porte` | string | não | — | base | ('Pequeno'/'Médio'/'Grande') |
| `peso` | string | não | — | base | ex.: `"12kg"` — número + unidade juntos |
| `dataNascimento` | string `dd/MM/yyyy` | não (pode `''`) | — | base | |
| `vacinado` | bool | não (default `false`) | — | app | adicionado neste ciclo |
| `dono` | string \| null | não | ? | base | **redundante com `userId`**, observado `null`; propósito não confirmado |
| `telefone` | string \| null | não | — | base | contato público de fallback no QR |
| `foto` | string (URL) \| null | não | Cloudinary | app | |
| `qrCodeId` | string \| null | não | — | app | usado para regenerar o QR (RF19) sem trocar o doc id |

**Sem** `status`, `publicId`, `createdAt`, `updatedAt`, `especie/porte` como enum.

---

### Subcoleção `Pets/{petId}/vacinas`

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseVacinaRepository`.

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `nome` | string | sim | app | |
| `dataAplicacao` | string `dd/MM/yyyy` | sim | app | |
| `proximaDose` | string `dd/MM/yyyy` \| null | não | app | alimenta o alerta (janela 30 dias) |
| `veterinario` | string \| null | não | app | |
| `observacoes` | string \| null | não | app | |

---

### Subcoleção `Pets/{petId}/historicoMedico`

- **Doc ID:** **gerado no client** (`novoId` → `.doc(id).set(...)`), porque os anexos sobem antes do doc existir.
- **Repo:** `FirebaseHistoricoMedicoRepository`.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string (client) | sim | — | app | |
| `data` | string `dd/MM/yyyy` | sim | — | app | |
| `descricao` | string | sim | — | app | |
| `veterinario` | string \| null | não | — | app | |
| `anexos` | array\<string\> (URLs) | não (default `[]`) | Cloudinary | app | comentário no código diz "Firebase Storage" — **desatualizado** |

---

### Subcoleção `Pets/{petId}/consultas`

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseConsultaRepository` (sem delete — cancelar = mudar `status`).

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `data` | string `dd/MM/yyyy` | sim | app | |
| `horario` | string `HH:mm` \| null | não | app | |
| `veterinario` | string | sim | app | |
| `motivo` | string | sim | app | |
| `status` | string enum | sim | app | `agendada` \| `realizada` \| `cancelada` (via `ConsultaStatus.fromValue`) |

---

### Subcoleção `Pets/{petId}/localizacoes`

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseLocalizacaoRepository` (só `watch` + `create`).

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `data` | string `dd/MM/yyyy` | sim | app | |
| `descricao` | string | sim | app | texto livre — **sem** lat/long |
| `contatoReportante` | string \| null | não | app | quem relatou o avistamento |

---

## Coleção raiz `Localizacoes` (órfã)

- Aparece no console (mencionada em `docs/modelo-dados-firestore.md`) mas **o app atual nunca lê nem escreve nela** — a feature de localização usa a subcoleção `Pets/{petId}/localizacoes`.
- Schema real desconhecido. Decisão do usuário em sessão anterior: **não reconciliar** — a feature foi refeita do zero na subcoleção.
- **Pendência de migração:** decidir se `Localizacoes` raiz contém dados históricos a preservar ou pode ser ignorada/arquivada (ver ambiguidade D no chat).

---

## Regras de segurança (Firestore Rules)

**Não versionadas neste repositório.** `firebase.json` não referencia `firestore.rules`. O conteúdo real deployado é desconhecido — em sessões anteriores foram exibidas regras muito permissivas (rascunho em `docs/seguranca.md`), mas não há confirmação de que sejam as que estão no ar. **Risco R-02.** Necessário o usuário colar as regras atuais do console.

---

## Resumo de problemas de dados a tratar na migração

| # | Problema | Coleções afetadas |
|---|---|---|
| 1 | Datas como string `dd/MM/yyyy`, podendo estar vazias ou malformadas | todas |
| 2 | `peso` é string com unidade (`"12kg"`) — precisa separar valor + unidade | `Pets` |
| 3 | `dono` redundante e frequentemente `null` | `Pets` |
| 4 | `usuarioID` sem uso confirmado — manter ou descartar? | `Usuarios` |
| 5 | Ausência de `createdAt`/`updatedAt` | todas |
| 6 | Possíveis docs com schema pré-`sobrenome` / pré-`vacinado` | `Usuarios`, `Pets` |
| 7 | `genero`/`especie`/`porte` são texto livre — normalizar para enum/catálogo | `Usuarios`, `Pets` |
| 8 | Coleção raiz `Localizacoes` órfã | `Localizacoes` |
| 9 | `historicoMedico` com id de client vs `.add()` nas outras subcoleções | subcoleções de `Pets` |
| 10 | Exclusão de conta não apaga `consultas`/`localizacoes` → possíveis órfãos já no banco | subcoleções de `Pets` |
