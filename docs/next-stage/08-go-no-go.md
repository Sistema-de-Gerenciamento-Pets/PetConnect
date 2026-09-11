# 08 — Go/No-Go para Observação Controlada

## Decisão: **GO_WITH_RESTRICTIONS**

---

## Avaliação por dimensão

| Dimensão | Estado | Peso na decisão |
|---|---|---|
| Testes automatizados | ✅ 74 backend + 25 Flutter, **verificados rodando de verdade no GitHub Actions** (não só localmente) | Favorável |
| Segurança | ✅ Correção crítica de posse no upload aplicada e testada; auditoria geral sem achado P0 | Favorável |
| Dados | ✅ Migração já rodada com dados reais (11 usuários, 21 pets, 64 localizações), idempotente, auditada | Favorável |
| Infraestrutura | ✅ **Ao vivo desde 2026-09-11** — MongoDB Atlas, API no Render, página do QR no Firebase Hosting, tudo testado de ponta a ponta com um pet real (ver `09-infrastructure-live.md`) | Favorável |
| UX | ⚠️ 1 achado P1 corrigido (acessibilidade); P2/P3 no backlog, nenhum P0 | Favorável, sem bloqueio |
| Erros conhecidos | ⚠️ `auth_flow_test.dart` ainda não roda em nenhum ambiente (bloqueado por acesso entre repos — decisão pendente do usuário) | Restrição |
| Upload/Cloudinary | 🔴 Round-trip real **nunca testado** — falta a API secret real (`BLOCKED_BY_SECRET`) | Restrição forte |
| Autenticação | ✅ Inalterada, Firebase Auth continua sendo a fonte de identidade em qualquer flag | Favorável |
| Validação em device físico | 🔴 **Não executada** — checklist pronto (34 casos), zero linhas preenchidas ainda | Restrição forte |
| Rollback | ✅ Flags desligam feature a feature; Firestore continua como fallback; nenhuma Rule destrutiva foi aplicada | Favorável |

---

## Por que não é `GO` pleno

Por instrução explícita do plano de execução: **"Se device físico ainda
não foi testado, NÃO declare liberação plena para produção."** — o
checklist existe, mas nenhuma linha foi preenchida (eu não posso operar
o device do usuário). Some a isso o round-trip do Cloudinary nunca
testado contra a conta real, e a auth E2E ainda sem confirmação de
execução — três lacunas de **confirmação real de comportamento**, não
de código.

## Por que não é `NO_GO`

Nada encontrado nesta etapa aponta um problema estrutural ou de
segurança que impeça avançar. Pelo contrário: a correção de segurança
mais importante pendente (posse no upload) foi corrigida e testada; o
CI passou de verdade; a matriz de paridade não achou nenhuma regressão
funcional real (a suspeita inicial em RF20-A foi verificada e descartada).
As restrições são todas de **confirmação pendente**, não de defeito
confirmado.

## Restrições para a observação controlada

1. ~~Não abrir a página pública do QR pro público real~~ — **superado**:
   página no ar, testada de ponta a ponta com um pet real pela interface
   de verdade (não só API). Pode ser usada.
2. **Não usar upload de imagem em produção** até o round-trip real do
   Cloudinary ser testado com a secret de verdade (`BLOCKED_BY_SECRET`)
   — continua pendente.
3. **Rodar o `device-validation-checklist.md` antes de considerar
   qualquer flag "pronta para todo mundo"** — mesmo com os testes
   automatizados verdes, nenhuma tela do **app** foi confirmada
   visualmente ainda (a página web pública já foi, é uma peça
   diferente).
4. Manter o Firestore ativo como fallback — **não bloquear
   `Usuarios`/`Pets`** nem prosseguir para a FASE 13 (ambos
   explicitamente fora do escopo desta etapa).
5. Resolver a decisão de acesso entre repositórios (PAT/imagem
   publicada/monorepo) antes de considerar `auth_flow_test.dart`
   "coberto por CI" — hoje ele está escrito e logicamente validado, mas
   não confirmado rodando de ponta a ponta em nenhum ambiente.

## Condição para reavaliar como `GO` pleno

Quando: (a) pelo menos a Rodada 1 e 2 do `device-validation-checklist.md`
estiverem preenchidas com `PASS` (no app — a página pública já está
validada), e (b) o round-trip do Cloudinary for confirmado com a secret
real, e (c) a decisão de acesso entre repos for tomada (mesmo que a
solução ainda não esteja implementada, só decidida) — reavaliar esta
decisão.
