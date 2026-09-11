# 07 — Dependências e Supply Chain

---

## Ação tomada: Dependabot habilitado nos dois repositórios

`vulnerability-alerts` estava **desabilitado** nos dois repos (confirmado
via `gh api .../vulnerability-alerts` → 404). Habilitado agora (→ 204) —
é a forma padrão do GitHub de monitorar CVEs conhecidas nas dependências
declaradas (`pubspec.yaml`, `pom.xml`) continuamente, sem exigir rodar
nenhuma ferramenta manual nem mudar código. Mudança reversível, sem
custo, sem impacto em nada além de passar a receber alertas por e-mail/na
aba Security do GitHub quando uma dependência tiver vulnerabilidade
conhecida publicada.

## Backend (Maven)

| Item | Estado |
|---|---|
| Spring Boot | 3.4.2 — versão atual da série 3.4.x (não é a mais recente da linha principal, mas dentro da janela de suporte) |
| Java | 21 (LTS) |
| Maven Wrapper | **Ausente** (achado no baseline) — recomendo adicionar (`mvn wrapper:wrapper`) pra builds reproduzíveis sem depender da versão do Maven instalada no runner/máquina de cada dev; não fiz isso nesta etapa por ser uma mudança de tooling, não uma correção — melhor pedir confirmação antes (baixo risco, mas é uma preferência, não um bug) |
| Dependências não utilizadas | Não auditado com ferramenta dedicada (`mvn dependency:analyze` não foi rodado) — fica como item pra próxima passada |

Nenhum upgrade de versão foi feito — só a configuração do Dependabot, que
agora vai sinalizar se algo precisar de atenção.

## Flutter (pub)

`flutter pub get` reportou **53 pacotes com versão mais nova disponível**,
mas incompatível com as constraints atuais do `pubspec.yaml` (resultado
do baseline, `01-baseline-audit.md`). Nenhum é uma versão *major* atrasada
a ponto de indicar abandono do pacote — a maioria é diferença de patch/minor
(ex.: `riverpod 2.6.1` vs. `3.4.3` disponível é a maior distância
encontrada, um major inteiro).

**Não fiz upgrade em massa** (proibido explicitamente pelo plano de
execução desta etapa). Se algum upgrade específico for desejado depois,
a análise caso a caso deve cobrir:
- `riverpod`/`flutter_riverpod` (2.x → 3.x): major, mudança de API
  conhecida entre essas versões — exigiria revisar todos os providers,
  risco alto pra fazer sem um motivo concreto agora.
- `go_router` (17.x → 18.x): major, mudança de API de rotas possível —
  mesma cautela.
- `cloud_firestore`/`firebase_*` (patch/minor): risco baixo, mas só vale
  a pena atualizar quando for tocar nesse código de novo (ex.: FASE 13,
  quando o Firestore for removido, isso deixa de importar).

Nenhum pacote crítico (`http`, `flutter_secure_storage`) está numa versão
com vulnerabilidade conhecida publicada até onde a auditoria manual
alcança — o Dependabot, agora habilitado, vai confirmar isso continuamente
de forma mais confiável do que uma checagem manual pontual.
