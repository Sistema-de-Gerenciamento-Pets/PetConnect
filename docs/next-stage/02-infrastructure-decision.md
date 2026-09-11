# 02 — Decisão de Infraestrutura

> Matriz comparativa para subsidiar a decisão humana. **Nenhum recurso pago
> foi criado.** Nada aqui é reversível/irreversível por si só — é só
> análise. A escolha final, criação de conta e eventual custo são decisões
> do usuário (STOP CONDITION do plano de execução).

---

## 5.1 MongoDB gerenciado

| Opção | Custo inicial | Free tier | Região BR/latência | Integração | Observação |
|---|---|---|---|---|---|
| **MongoDB Atlas** (recomendado) | Grátis pra começar | **M0** — 512MB, cluster compartilhado, sem cartão pra criar | Tem região `sa-east-1` (São Paulo, via AWS) — boa latência pro Brasil | Nativa (é o dono do driver que o projeto já usa via Spring Data MongoDB) | Migração do Mongo local pro Atlas é só trocar a `MONGODB_URI` — zero mudança de código. Upgrade de M0 pra tier pago é 1 clique quando/se precisar de mais que 512MB. |
| Railway (Mongo como plugin) | Cobra por uso desde o início (sem free tier permanente pra banco) | Trial com crédito limitado | Não garante região específica | Simples de configurar junto com o deploy da API | Só faz sentido se já for hospedar a API lá também (ver 5.2) — como banco isolado, Atlas é melhor. |
| Mongo auto-hospedado em VPS | Custo do VPS (~$5-6/mês nas opções mais baratas) | — | Depende do provedor do VPS escolhido | Exige você administrar backup/segurança do banco | Mais trabalho operacional, sem vantagem clara pra este projeto no estágio atual. |

**Recomendação**: **MongoDB Atlas, tier M0 (grátis)** para começar a validar
em staging/produção inicial. 512MB é confortável pro volume atual (21 pets,
11 usuários reais migrados — ordens de grandeza abaixo do limite). Migrar
pra um tier pago só quando o volume real justificar.

**Ação necessária do usuário**: criar conta no Atlas, criar o cluster M0
(gratuito, não pede cartão), copiar a connection string e configurar como
secret no ambiente de hospedagem escolhido — não é uma ação que eu deva
fazer sozinho (é uma conta pessoal/de e-mail do usuário).

---

## 5.2 Hospedagem da API (Spring Boot em Docker)

| Opção | Custo inicial | Free tier | Docker | Java 21 | HTTPS | GitHub integration | Observação |
|---|---|---|---|---|---|---|---|
| **Railway** | Free trial com crédito (~$5), depois pay-as-you-go | Trial, não permanente | ✅ nativo (`Dockerfile` já pronto no repo) | ✅ | ✅ automático | ✅ deploy automático em push | Mais simples de configurar pra um dev solo; o `Dockerfile` do projeto já funciona sem alteração. |
| **Render** | Free tier permanente pra web services (com sleep após inatividade) | ✅ (com "cold start" após 15min sem tráfego) | ✅ | ✅ | ✅ automático | ✅ | Free tier "dorme" — não ideal pra uma API que precisa responder rápido sempre, mas ótimo pra validar/staging sem custo algum. |
| **Fly.io** | Free tier bem pequeno hoje (mudou nos últimos anos) | Limitado | ✅ nativo | ✅ | ✅ automático | via CLI, não é push direto | Boa opção técnica, curva de configuração um pouco maior (usa `fly.toml`, não só `Dockerfile`). |
| **VPS próprio** (DigitalOcean, Hetzner, etc.) | ~$4-6/mês | — | Você configura | Você configura | Você configura (Let's Encrypt) | Você configura | Controle total, mas todo o trabalho de operação (deploy, TLS, restart, logs) fica manual, a não ser que você monte CI/CD próprio pra isso também. |
| **Google Cloud Run** | Pay-per-use, tem free tier generoso (2M requisições/mês) | ✅ | ✅ (roda a partir do `Dockerfile`) | ✅ | ✅ automático | via `gcloud` CLI ou GitHub Action | Escala a zero quando sem tráfego (sem custo parado);é o mesmo ecossistema do Firebase já usado no projeto. Boa opção técnica se o usuário já tem conta GCP (o Firebase do projeto já é GCP). |

**Recomendação**: para **staging/validação** (o que o projeto precisa
agora): **Render free tier** ou **Google Cloud Run** (ambos sem custo pra
começar). Para produção "de verdade" mais adiante, com tráfego constante,
**Railway** ou **Cloud Run pago** evitam o cold-start do Render free.

**Bloqueio**: qualquer uma dessas opções exige **criar conta e,
dependendo da escolha, cartão de crédito cadastrado** (mesmo em tiers
gratuitos, alguns provedores pedem cartão como verificação). Isso é uma
decisão do usuário — não vou criar a conta.

### O que já está pronto, independente da escolha (verificado nesta auditoria, não só assumido)

- `Dockerfile` já existe e builda a API corretamente (usado localmente
  há várias fases) — build multi-stage (Maven → JRE), sem credencial
  embutida na imagem.
- `application-prod.yml` já existe como perfil separado: `MONGODB_URI` e
  `CORS_ALLOWED_ORIGINS` são **obrigatórios** (sem valor default) — a API
  falha rápido no startup se não configurados, em vez de subir com um
  default de dev por engano.
- CORS já é parametrizado via `CORS_ALLOWED_ORIGINS` (env var).
- Nenhuma URL `localhost` hardcoded em nenhum profile — tudo via
  `${VAR:default}` no `application.yml`.
- `include-stacktrace: never` e `include-message: never` no
  `server.error` — nenhum stack trace vaza pra fora em erro 500.
- Actuator expõe só `health`/`info` (não `env`, `beans`, etc., que
  vazariam configuração).
- `git grep` por `log\.(info|debug|warn|error)` cruzado com
  token/senha/authorization/secret: **1 ocorrência**, e é segura — loga só
  `exception.getMessage()` de uma falha de verificação de token (ex.:
  "Token inválido ou expirado."), nunca o token em si.
- Firebase Admin SDK: credencial vem de arquivo/variável de ambiente
  (`FIREBASE_SERVICE_ACCOUNT`), nunca hardcoded; sem credencial, o bean
  fica `null` e a API sobe mesmo assim (rotas autenticadas respondem 401
  em vez da aplicação inteira falhar ao subir).

---

## 5.3 Domínio + hospedagem da página pública do QR code

Hoje, o link do QR aponta pro Mongo `publicId` do pet (não o `_id` interno
— já é seguro/não-sequencial, ver `PetController`/`PublicPetController`),
mas **não existe ainda uma página web pública de verdade** — a FASE 9 do
plano mestre implementou o **endpoint da API** (`GET
/api/v1/public/pets/{publicId}`), mas a decisão de hospedagem da página em
si (HTML que consome esse endpoint) foi conscientemente adiada ("só local
por enquanto", decisão registrada no handoff.md).

| Opção | Custo | Observação |
|---|---|---|
| **Vercel / Netlify** (página estática simples que chama a API) | Grátis pro volume esperado | Mais rápido de montar — só precisa de uma página HTML/JS simples consumindo o endpoint público já pronto. |
| **Firebase Hosting** | Grátis pro volume esperado | Já é o mesmo projeto Firebase usado pra Auth — reaproveita a mesma conta/CLI já configurada (`firebase.json` já existe no repo). |
| Servir a página pela própria API Spring (endpoint que retorna HTML) | Sem custo extra além da hospedagem da API | Mais simples de operar (um serviço a menos), mas mistura responsabilidade de "API JSON" com "servir HTML" — evitar se possível. |

**Recomendação**: **Firebase Hosting** — reaproveita a infraestrutura
Firebase já paga/configurada (mesmo projeto do Auth), sem custo adicional,
sem conta nova.

**Bloqueio**: falta decidir/registrar um **domínio** (mesmo que seja o
subdomínio gratuito `*.web.app`/`*.firebaseapp.com` do próprio Firebase
Hosting, que não exige comprar nada) e efetivamente **construir a página**
(hoje só o backend dela existe). Ambos ficam como pendência explícita —
não vou fixar um domínio fictício no código.

---

## 5.4 Credencial real do Cloudinary

Já coberto em detalhe em `05-security-review.md`/`06-cloudinary-audit.md`
(ver Etapa F). Resumo: falta `CLOUDINARY_API_SECRET` real para testar o
round-trip de upload assinado — não posso gerar isso, é uma credencial da
conta Cloudinary do usuário (console.cloudinary.com → Dashboard).

---

## 5.5 Resumo das decisões pendentes (aguardando o usuário)

| Decisão | Recomendação desta análise | Bloqueio |
|---|---|---|
| MongoDB gerenciado | Atlas M0 (grátis) | Criar conta Atlas |
| Hospedagem da API | Render (validação) → Railway/Cloud Run (produção) | Criar conta + cartão (mesmo em free tier, alguns provedores pedem) |
| Página pública do QR | Firebase Hosting | Construir a página (não existe ainda) + confirmar domínio (pode usar o gratuito do Firebase) |
| Cloudinary API Secret | — | Pegar no console Cloudinary do usuário |

Nenhuma dessas é bloqueante para o resto desta etapa (CI, segurança,
testes, UX) — todas podem prosseguir em paralelo, rodando localmente/em
Docker como já acontece hoje.
