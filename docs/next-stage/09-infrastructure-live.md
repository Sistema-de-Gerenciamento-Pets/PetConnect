# 09 — Infraestrutura em Produção (real, não mais matriz de decisão)

> Complementa `02-infrastructure-decision.md` (que era só a matriz
> comparativa, nada criado ainda). Este documento registra o que **existe
> de verdade** a partir de 2026-09-11.

---

## MongoDB Atlas

- Cluster **M0 (grátis)**, provider AWS, região `sa-east-1` (São Paulo).
- Usuário de banco: `petconnect-api`.
- Network Access: liberado de qualquer IP (`0.0.0.0/0`) — necessário
  porque o Render (Parte 2) não tem IP de saída fixo no tier gratuito;
  o acesso continua exigindo usuário+senha. Reavaliar se trocar de
  hospedagem para algo com IP fixo.
- Testado: conexão, leitura e escrita confirmadas via `mongosh` antes de
  usar em produção; depois, confirmado de ponta a ponta criando e
  apagando um pet real através da API.

## API (Render)

- URL: **`https://petconnect-api-rxr9.onrender.com`**
- Plano: **Free** — limitação conhecida: o serviço "dorme" após ~15min
  sem tráfego; a primeira requisição depois disso pode levar até ~2min
  (o primeiro start observado levou 115s, mais lento que o normal por
  causa do CPU compartilhado do tier gratuito + inicialização do
  Firebase Admin SDK).
- Variáveis de ambiente configuradas: `APP_ENV=prod`, `MONGODB_URI`
  (Atlas), `CORS_ALLOWED_ORIGINS`, `FIREBASE_PROJECT_ID`,
  `FIREBASE_SERVICE_ACCOUNT` (JSON em base64 — o código já aceitava esse
  formato desde a FASE 2, então não precisou de "secret file" do Render).
- **Cloudinary ainda não configurado** (`CLOUDINARY_API_KEY`/`_SECRET`)
  — continua `BLOCKED_BY_SECRET`, ver `05-security-review.md`.
- Testado: `/api/v1/ping`, `/actuator/health`, e um pet real
  criado/lido/apagado pela API — confirma a cadeia Render → MongoDB
  Atlas funcionando.

## Página pública do QR (Firebase Hosting)

- URL: **`https://pet-connect-c53f1.web.app/pet/{publicId}`** — bate
  exatamente com o que `pet_qr_code.dart` já gerava desde antes desta
  etapa (nenhuma mudança de código no app foi necessária).
- Fonte: `PetConnect/public/index.html` — página estática, sem
  framework/build, JS puro. Roteamento client-side (lê
  `window.location.pathname`), com rewrite geral no `firebase.json`
  pra `/index.html`.
- Mostra: nome, espécie, status (traduzidos pra PT-BR), foto (ou
  placeholder), contato do tutor (se o tutor optou por exibir). Nunca
  mostra `tutorId`/e-mail — mesma garantia do endpoint (`DTO` mínimo).
- Formulário de avistamento anônimo: descrição opcional, contato de
  quem achou (opcional), geolocalização do navegador (opcional, pede
  permissão, funciona sem ela também).
- **Achado real durante a configuração**: o primeiro teste após ligar
  o CORS no Render voltou **403 Forbidden genérico** (sem o corpo JSON
  padrão da API) em vez do 404 esperado — o Spring Security CORS
  processor rejeita ativamente requisições com `Origin` não permitido,
  diferente de só omitir o header. A causa real era só o deploy do
  Render ainda não ter terminado de reiniciar com a variável nova —
  confirmado esperando ~30s e testando de novo. Documentado aqui porque
  é fácil confundir isso com um bug de configuração.
- **Verificado de ponta a ponta com um pet real**, pela interface de
  verdade (não só `curl`): página renderizou os dados corretos, o
  formulário foi preenchido e enviado pelo navegador, resposta "Obrigado!
  O tutor foi avisado." confirmada, console do navegador sem erro. Pet
  e conta de teste apagados depois.

## O que ainda falta (não bloqueante, registrado para não esquecer)

1. Restringir o Network Access do Atlas se a hospedagem da API mudar
   para algo com IP fixo (hoje é `0.0.0.0/0` por necessidade do Render).
2. Configurar `CLOUDINARY_API_KEY`/`_SECRET` no Render quando o usuário
   tiver a credencial real (`BLOCKED_BY_SECRET`).
3. Considerar trocar o tier do Render se o cold-start de ~2min incomodar
   em uso real (ver matriz de opções em `02-infrastructure-decision.md`).
4. RF19 (regenerar QR code) continua não implementado — não é bug desta
   etapa, é um requisito nunca entregue, registrado no backlog.
