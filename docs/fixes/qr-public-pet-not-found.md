# Correção — QR Code público retornando "pet não encontrado"

## Sintoma

Escanear o QR code de qualquer pet (legado ou recém-criado) abria a página
pública (`pet-connect-c53f1.web.app`) normalmente, mas ela sempre
retornava:

> "Não encontramos esse pet. O QR code pode ter sido desativado pelo tutor."

Reportado com 4 pets reais: Felícia, Mavis (na verdade "Maevis" — nome
levemente diferente do lembrado), Nymeria (todos legados/migrados) e Aleks
(criado no app depois da migração original).

## Causa raiz

Duas causas compostas, ambas confirmadas com dados reais (consulta direta
ao Firestore, ao Mongo local e ao Atlas) — não foi corrigido por tentativa
e erro:

### 1. O app codifica o ID errado no QR (afeta todo pet, sempre)

`lib/features/pet/domain/pet_qr_code.dart`:
```dart
String publicPetUrl(Pet pet) {
  final id = pet.qrCodeId ?? pet.id;   // ANTES
  return 'https://pet-connect-c53f1.web.app/pet/$id';
}
```

`Pet.qrCodeId` só é preenchido por `ApiPetRepository` (`qrCodeId:
m['publicId']`), usado apenas quando a flag `USE_API_PETS=true`. No modo
legado (Firestore direto — **ainda o padrão hoje**, os 18 usuários reais
usam o app assim), `FirebasePetRepository` nunca populou esse campo (não
existe nos documentos Firestore), então `qrCodeId` é sempre `null` e o
código caía no fallback `pet.id` — **o ID do documento Firestore**, nunca
o `publicId` do Mongo que o endpoint público (`GET
/api/v1/public/pets/{publicId}`) sabe buscar
(`petRepository.findByPublicId`, sem nenhum fallback por
`legacyFirestoreId`).

Confirmado com dados reais:

| Pet | ID no QR (Firestore) | `publicId` real no Mongo |
|---|---|---|
| Nymeria | `G58iMXlRw7jbach4qZMX` | `7cd148f7-07b3-3505-b721-4e256d24cdef` |
| Aleks | `GDjlbLE2PbatnjwoH5Ch` | `ecd2daf7-1279-3785-ac70-d06dfd03ee18` (só depois da migração corrigida, ver causa 2) |

### 2. O banco de produção (Atlas) estava vazio

A API publicada no Render está ligada ao MongoDB Atlas — mas a migração
de dados (`LegacyMigrationService`) só tinha sido executada contra o
Mongo **local** (Docker, usado durante o desenvolvimento). O Atlas tinha
**0 pets** antes desta correção. Mesmo se a causa 1 não existisse, nenhum
pet legado seria encontrado pela API real.

## Impacto

Todos os QR codes gerados pelo app estavam quebrados para qualquer
pessoa que os escaneasse (achador de pet perdido) — o caso de uso
principal do recurso (RF17-19).

## Pets afetados

Todos — não é um caso isolado. Qualquer pet, legado ou novo, gerava um QR
não-funcional enquanto o app rodasse com `USE_API_PETS=false` (o padrão).

## Fluxo afetado

```
App (modo Firestore) → gera QR com Firestore doc ID
                     → página pública → GET /api/v1/public/pets/{docId}
                     → Mongo (Atlas) não tem esse id como publicId → 404
```

## Arquivos modificados

- `PetConnect/lib/core/utils/legacy_public_id.dart` (novo) — réplica em
  Dart do algoritmo `java.util.UUID.nameUUIDFromBytes` usado pelo backend.
- `PetConnect/lib/features/pet/domain/pet_qr_code.dart` — usa
  `legacyPublicIdFor(pet.id)` como fallback em vez de `pet.id` bruto.
- `PetConnect/pubspec.yaml` — `crypto` promovido de dependência
  transitiva para direta.
- `PetConnect/test/core/utils/legacy_public_id_test.dart` (novo).
- `PetConnect/test/features/pet/pet_qr_code_test.dart` — atualizado pro
  novo comportamento.
- Nenhum arquivo do backend foi alterado — o endpoint público sempre
  funcionou corretamente dado um `publicId` válido (confirmado pelos
  testes de `PublicPetControllerTest`, que continuam passando sem
  mudança).

## Correção

1. **App**: `publicPetUrl()` agora calcula o mesmo `publicId`
   determinístico que a migração gera/persiste, em vez de usar o ID do
   Firestore diretamente. Isso corrige o QR **mesmo sem ligar nenhuma
   feature flag** — mas só funciona pra pets que já foram (ou serão)
   migrados pro Mongo.
2. **Dados**: rodada uma nova migração (idempotente, mesmo mecanismo já
   usado em fases anteriores) contra o **MongoDB Atlas** (não mais só o
   Mongo local), a partir de um backup fresco do Firestore — trouxe os 22
   pets atuais (21 anteriores + Aleks, criado depois da migração
   original) pro banco de produção.

## Testes

- `legacy_public_id_test.dart`: 5 testes, incluindo 3 vetores **reais**
  (não inventados) — Nymeria, Felícia e Aleks, conferidos diretamente no
  MongoDB antes de escrever o teste.
- `pet_qr_code_test.dart`: atualizado para o novo comportamento (2
  testes).
- Backend: nenhuma mudança de código — `PublicPetControllerTest` (6
  testes) já cobria pet encontrado, `publicId` inexistente, pet
  arquivado, e isolamento de dado do tutor; continuam passando sem
  alteração.
- `flutter analyze`: limpo. 30/30 testes Flutter passando.

## Riscos

- A migração roda por `legacyFirestoreId` — pets criados no Firestore
  **depois** desta correção continuarão precisando de uma nova rodada de
  migração pra aparecer no Mongo (o QR já vai apontar pro `publicId`
  certo, calculado localmente, mas o endpoint só encontra depois que a
  migração rodar). Isso é uma limitação conhecida e não nova — é a mesma
  dívida de "migração periódica" já registrada em
  `docs/migration/handoff.md`.
- Nenhum dado foi apagado ou sobrescrito — a migração é idempotente
  (reexecutar não duplica nem corrompe registros existentes).

## Rollback

- App: reverter o commit do `fix/qr-code-pet-publico` — volta ao
  comportamento antigo (quebrado, mas sem risco novo).
- Dados: a migração só adiciona/atualiza documentos com
  `legacyFirestoreId` correspondente — não há necessidade de rollback de
  dados (nada foi removido do Atlas).

## Validação física

Ver `docs/validation/qr-public-page-fix.md`.
