'use strict';

/*
 * Backup + auditoria do Firestore do PetConnect — FASE 0 da migração.
 *
 * SOMENTE LEITURA. Não apaga nem escreve nada no Firestore.
 * Não requer plano Blaze: usa o Admin SDK, que lê pela cota gratuita.
 *
 * Uso:
 *   1. Coloque o serviceAccountKey.json nesta pasta (ver README.md).
 *   2. npm install
 *   3. npm run backup
 *
 * Saída: output/<timestamp>/  com um JSON por coleção/subcoleção,
 *        _manifest.json e report.md (relatório de qualidade de dados).
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(KEY_PATH)) {
  console.error('\n[erro] Falta o arquivo serviceAccountKey.json nesta pasta.');
  console.error('Firebase Console > Configuracoes do projeto > Contas de servico >');
  console.error('  "Gerar nova chave privada" > salve o JSON como:');
  console.error('  ' + KEY_PATH + '\n');
  process.exit(1);
}

const serviceAccount = require(KEY_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const outDir = path.join(__dirname, 'output', stamp);
fs.mkdirSync(outDir, { recursive: true });

const manifest = {
  generatedAt: new Date().toISOString(),
  projectId: serviceAccount.project_id,
  collections: {},
};

/** Converte tipos do Firestore (Timestamp, GeoPoint, Ref) para JSON simples. */
function plain(value) {
  if (value === null || value === undefined) return value;
  if (typeof value !== 'object') return value;
  if (typeof value.toDate === 'function' && value._seconds !== undefined) {
    return { __type: 'timestamp', iso: value.toDate().toISOString() };
  }
  if (value._latitude !== undefined && value._longitude !== undefined) {
    return { __type: 'geopoint', lat: value._latitude, lng: value._longitude };
  }
  if (value.path && value.firestore && typeof value.path === 'string') {
    return { __type: 'ref', path: value.path };
  }
  if (Array.isArray(value)) return value.map(plain);
  const out = {};
  for (const [k, v] of Object.entries(value)) out[k] = plain(v);
  return out;
}

function writeJson(name, data) {
  fs.writeFileSync(path.join(outDir, name + '.json'), JSON.stringify(data, null, 2), 'utf8');
}

/** buckets: label -> array de docs. Subcoleções agregadas por nome. */
const buckets = {};

async function walk(collRef, label) {
  const snap = await collRef.get();
  if (!buckets[label]) buckets[label] = [];
  for (const doc of snap.docs) {
    buckets[label].push({ _id: doc.id, _path: doc.ref.path, ...plain(doc.data()) });
    const subs = await doc.ref.listCollections();
    for (const sub of subs) {
      await walk(sub, `${label}/*/${sub.id}`);
    }
  }
}

// ----------------------------------------------------------------------------
// Relatório de qualidade de dados
// ----------------------------------------------------------------------------

function isValidBrDate(s) {
  if (typeof s !== 'string') return false;
  const m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (!m) return false;
  const d = +m[1], mo = +m[2], y = +m[3];
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 1900 || y > 2100) return false;
  const dt = new Date(y, mo - 1, d);
  return dt.getFullYear() === y && dt.getMonth() === mo - 1 && dt.getDate() === d;
}

function tally(arr, fn) {
  const m = {};
  for (const x of arr) {
    const k = fn(x);
    m[k] = (m[k] || 0) + 1;
  }
  return m;
}

function distinctKeys(arr) {
  return [...new Set(arr.flatMap((d) => Object.keys(d)))].filter((k) => k !== '_id' && k !== '_path').sort();
}

function dateLine(arr, field, required) {
  const missing = arr.filter((d) => d[field] === undefined || d[field] === null || d[field] === '').length;
  const invalid = arr.filter((d) => d[field] && !isValidBrDate(d[field])).length;
  return `  - \`${field}\`: ${missing} ausente/vazio${required ? ' **(obrigatório!)**' : ''}, ${invalid} com formato != dd/MM/yyyy`;
}

function buildReport() {
  const L = [];
  const P = (s) => L.push(s);

  const users = buckets['Usuarios'] || [];
  const pets = buckets['Pets'] || [];
  const userIds = new Set(users.map((u) => u._id));
  const petIds = new Set(pets.map((p) => p._id));

  P('# Relatório de auditoria de dados — Firestore');
  P('');
  P(`> Gerado em ${manifest.generatedAt} · projeto \`${manifest.projectId}\``);
  P('> Somente leitura — nenhum dado foi alterado.');
  P('');

  P('## Contagem por coleção');
  P('');
  P('| Coleção | Documentos |');
  P('|---|---|');
  for (const [k, v] of Object.entries(manifest.collections)) P(`| \`${k}\` | ${v} |`);
  P('');

  // coleções / subcoleções fora do esperado
  const knownRoots = ['Usuarios', 'Pets', 'Localizacoes'];
  const knownSubs = ['Pets/*/vacinas', 'Pets/*/historicoMedico', 'Pets/*/consultas', 'Pets/*/localizacoes'];
  const unexpectedRoots = Object.keys(manifest.collections).filter((k) => !k.includes('/') && !knownRoots.includes(k));
  const unexpectedSubs = Object.keys(manifest.collections).filter((k) => k.includes('/*/') && !knownSubs.includes(k));
  P('## Estruturas inesperadas');
  P('');
  P(`- Coleções raiz não previstas: ${unexpectedRoots.length ? '`' + unexpectedRoots.join('`, `') + '`' : 'nenhuma'}`);
  P(`- Subcoleções não previstas: ${unexpectedSubs.length ? '`' + unexpectedSubs.join('`, `') + '`' : 'nenhuma'}`);
  P('');

  // Usuarios
  P('## Usuarios');
  P('');
  P(`- Total: ${users.length}`);
  P(`- Sem campo \`sobrenome\`: ${users.filter((u) => u.sobrenome === undefined).length} · \`sobrenome\` vazio: ${users.filter((u) => u.sobrenome === '').length}`);
  P(`- Sem \`usuarioID\`: ${users.filter((u) => !u.usuarioID).length}`);
  P(`- \`foto\` nula/ausente: ${users.filter((u) => !u.foto).length}`);
  P(dateLine(users, 'dataNascimento', false));
  P(`- Valores de \`genero\`: \`${JSON.stringify(tally(users, (u) => u.genero ?? '(ausente)'))}\``);
  P(`- Chaves de campo distintas: \`${JSON.stringify(distinctKeys(users))}\``);
  const usersLegacySchema = users.filter((u) => u.sobrenome === undefined);
  if (usersLegacySchema.length) P(`- ⚠️ ${usersLegacySchema.length} doc(s) parecem ter schema pré-\`sobrenome\``);
  P('');

  // Pets
  P('## Pets');
  P('');
  P(`- Total: ${pets.length}`);
  P(`- Sem \`vacinado\`: ${pets.filter((p) => p.vacinado === undefined).length}`);
  P(`- \`dono\` não-nulo: ${pets.filter((p) => p.dono != null).length} · \`dono\` != \`userId\` (ambos presentes): ${pets.filter((p) => p.dono != null && p.userId != null && p.dono !== p.userId).length}`);
  P(`- \`userId\` órfão (sem Usuario correspondente no dump): ${pets.filter((p) => !userIds.has(p.userId)).length}`);
  P(`- \`qrCodeId\` nulo/ausente: ${pets.filter((p) => !p.qrCodeId).length}`);
  P(`- \`telefone\` nulo/ausente: ${pets.filter((p) => !p.telefone).length}`);
  P(`- \`peso\` que não casa \`^[\\d.,]+ ?kg?$\`: ${pets.filter((p) => p.peso && !/^\s*[\d.,]+\s*kg?\s*$/i.test(String(p.peso))).length}`);
  P(dateLine(pets, 'dataNascimento', false));
  P(`- Valores de \`especie\`: \`${JSON.stringify(tally(pets, (p) => p.especie ?? '(ausente)'))}\``);
  P(`- Valores de \`porte\`: \`${JSON.stringify(tally(pets, (p) => p.porte ?? '(ausente)'))}\``);
  P(`- Valores de \`genero\`: \`${JSON.stringify(tally(pets, (p) => p.genero ?? '(ausente)'))}\``);
  P(`- Chaves de campo distintas: \`${JSON.stringify(distinctKeys(pets))}\``);
  P('');

  // Subcoleções de Pets
  const subDefs = [
    ['Pets/*/vacinas', [['dataAplicacao', true], ['proximaDose', false]]],
    ['Pets/*/historicoMedico', [['data', true]]],
    ['Pets/*/consultas', [['data', true]]],
    ['Pets/*/localizacoes', [['data', true]]],
  ];
  for (const [label, dateFields] of subDefs) {
    const arr = buckets[label] || [];
    P(`## ${label}`);
    P('');
    P(`- Total: ${arr.length}`);
    const orphan = arr.filter((d) => {
      const m = String(d._path).match(/^Pets\/([^/]+)\//);
      return m && !petIds.has(m[1]);
    }).length;
    P(`- Docs cujo pet-pai não está no dump: ${orphan}`);
    for (const [f, req] of dateFields) P(dateLine(arr, f, req));
    if (label.endsWith('consultas')) {
      P(`- Valores de \`status\`: \`${JSON.stringify(tally(arr, (d) => d.status ?? '(ausente)'))}\``);
      const badH = arr.filter((d) => d.horario && !/^\d{2}:\d{2}$/.test(String(d.horario))).length;
      P(`- \`horario\` fora de HH:mm (quando presente): ${badH}`);
    }
    if (label.endsWith('historicoMedico')) {
      const semAnexo = arr.filter((d) => !Array.isArray(d.anexos) || d.anexos.length === 0).length;
      P(`- Sem anexos: ${semAnexo}`);
    }
    P(`- Chaves de campo distintas: \`${JSON.stringify(distinctKeys(arr))}\``);
    P('');
  }

  // Localizacoes raiz
  const locRoot = buckets['Localizacoes'] || [];
  P('## Localizacoes (coleção raiz — órfã no app atual)');
  P('');
  P(`- Total: ${locRoot.length}`);
  if (locRoot.length) {
    P(`- Chaves de campo distintas: \`${JSON.stringify(distinctKeys(locRoot))}\``);
    const refPet = locRoot.filter((d) => Object.values(d).some((v) => typeof v === 'string' && petIds.has(v))).length;
    const refUser = locRoot.filter((d) => Object.values(d).some((v) => typeof v === 'string' && userIds.has(v))).length;
    P(`- Docs com algum valor batendo em um petId conhecido: ${refPet}`);
    P(`- Docs com algum valor batendo em um userId conhecido: ${refUser}`);
    P('- Amostra (até 3 docs):');
    P('');
    P('```json');
    P(JSON.stringify(locRoot.slice(0, 3), null, 2));
    P('```');
  } else {
    P('- Coleção vazia ou inexistente → pode ser ignorada na migração.');
  }
  P('');

  P('## Leitura rápida para as decisões da migração');
  P('');
  P('- **usuarioID**: se "sem usuarioID" ≈ total, o campo praticamente não existe → descartar é seguro.');
  P('- **dono**: se "dono != userId" = 0, o campo é 100% redundante → descartar é seguro.');
  P('- **Localizacoes raiz**: se total = 0 ou nenhum doc referencia pet/user → ignorar.');
  P('- **datas inválidas > 0**: cada uma vira `null` no Mongo + entra no relatório de migração.');
  P('- **userId órfão > 0**: pets sem dono real — decidir se migram como arquivados ou ficam de fora.');

  return L.join('\n') + '\n';
}

// ----------------------------------------------------------------------------

(async () => {
  console.log('Backup do Firestore ->', outDir);
  const roots = await db.listCollections();
  console.log('Coleções raiz:', roots.map((c) => c.id).join(', ') || '(nenhuma)');

  for (const c of roots) {
    await walk(c, c.id);
  }

  for (const [label, docs] of Object.entries(buckets)) {
    const fileName = label.replace(/\/\*\//g, '__').replace(/\//g, '__');
    writeJson(fileName, docs);
    manifest.collections[label] = docs.length;
    console.log(`  ${label}: ${docs.length} doc(s)`);
  }

  writeJson('_manifest', manifest);
  fs.writeFileSync(path.join(outDir, 'report.md'), buildReport(), 'utf8');

  console.log('\nOK. Arquivos em:', outDir);
  console.log('Abra report.md e cole o conteúdo aqui no chat.');
  process.exit(0);
})().catch((err) => {
  console.error('\n[falha]', err);
  process.exit(1);
});
