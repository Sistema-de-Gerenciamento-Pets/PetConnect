# 05 — Revisão de Segurança

---

## Correção crítica aplicada nesta etapa: posse no `DELETE /api/v1/uploads`

**Antes**: qualquer usuário autenticado podia excluir qualquer arquivo do
Cloudinary da conta do projeto, só enviando a URL — sem checar se era dele.

**Depois**: cada assinatura de upload (`POST /api/v1/uploads/signature`)
inclui `folder = users/<tutorId>` nos parâmetros **assinados**. O Cloudinary
recusa o upload se o app enviar um `folder` diferente do assinado — então a
posse fica garantida estruturalmente, sem precisar de uma tabela própria de
"quem subiu o quê". Na exclusão, o backend só chama o Cloudinary se o
`public_id` da URL estiver dentro da pasta do tutor autenticado; caso
contrário, `404` (sem distinguir "não existe" de "é de outro tutor" — mesma
postura do resto da API).

Commits: `PetConnect-API#ae4d453` ([PR #2](https://github.com/AleksGustavo/PetConnect-API/pull/2)) + `PetConnect#4c94182`.
Testes: 2 novos casos de segurança, 74/74 passando (backend) + 25/25 (app).

### Testes de posse cobertos

| Cenário | Resultado |
|---|---|
| Dono exclui seu próprio arquivo | 204, chama o Cloudinary |
| Outro tutor tenta excluir arquivo de dentro da pasta do primeiro | 404, **não** chama o Cloudinary |
| Usuário não autenticado | 401 (filtro global, já coberto) |
| URL fora do padrão do Cloudinary | 400 |
| Arquivo sem pasta (upload de antes deste endurecimento) | 404, **não** chama o Cloudinary |

### Limitação residual (aceita conscientemente)

Uploads feitos **antes** desta mudança (nenhum em produção real ainda,
pela FASE 10 nunca ter sido usada com credencial real) não têm pasta —
ficam permanentemente não-excluíveis por este endpoint. Como não há
volume real hoje (round-trip nunca testado contra o Cloudinary de
verdade — ver seção "Cloudinary" abaixo), isso não afeta nenhum usuário.

---

## Auditoria geral (seção 8.1 do plano de execução)

| Item | Estado | Nota |
|---|---|---|
| Secrets fora do Git | ✅ | Verificado no baseline (`01-baseline-audit.md`) — `.gitignore` cobre `.env*`/chaves, `git grep` limpo |
| Logs sem token/senha | ✅ | Verificado (`02-infrastructure-decision.md`, seção "deploy prep") — só 1 log com `exception.getMessage()`, nunca o token |
| Firebase token | ✅ | Verificado via Admin SDK (`verifyIdToken`), filtro dedicado, `shouldNotFilter` correto pras rotas públicas |
| CORS | ✅ | Parametrizado por env var, sem wildcard hardcoded |
| Rate limiting | ✅ | FASE 11 — 30 leituras/10 escritas por minuto nos endpoints públicos, verificado ao vivo |
| Mass assignment | ✅ | Todos os `Create*Request`/`Update*Request` são DTOs próprios com Bean Validation — nenhum endpoint faz bind direto na entidade de domínio |
| Validação de DTO | ✅ | `@Valid` + `@NotBlank`/etc. em todos os requests; `400` com `VALIDATION_ERROR` no handler global |
| Exposição de stack trace | ✅ | `include-stacktrace: never`, `include-message: never` |
| Enum/status manipulável | ✅ | `AppointmentStatus` (e equivalentes) são enums Java — o Jackson rejeita valor fora do enum com 400, não aceita string arbitrária |
| IDOR/BOLA | ✅ (upload agora incluído) | Todo endpoint de sub-recurso do pet passa por `petService.get(tutorId, petId)` antes de qualquer operação — 404 se não for do tutor. Testado explicitamente em cada `*ControllerTest` (`naoAcessaXDeOutroTutor`) |
| Upload — MIME/tipo | ⚠️ **não validado no backend** | A assinatura não restringe tipo de arquivo — o Cloudinary aceita qualquer coisa enviada. Risco baixo (só usuários autenticados podem assinar), mas vale registrar como melhoria futura (`resource_type` já é auto-detectado, poderia ser restrito a `image` explicitamente). |
| Upload — tamanho de arquivo | ⚠️ **não validado no backend** | Mesma situação — hoje só o client (Flutter) valida 5MB antes de enviar (`docs/seguranca.md`), o que um cliente diferente do app oficial poderia ignorar. Baixo risco (custo vai para a conta Cloudinary do projeto, não expõe dado), registrado como melhoria futura. |
| Nomes de arquivo | ✅ | O Cloudinary gera o `public_id` final — o nome enviado pelo cliente (`filename:`) não é usado como identificador, só como metadado |
| URLs externas | ✅ | `CloudinaryUrlParser` só aceita o padrão exato `res.cloudinary.com/.../upload/v{n}/...` — não segue redirecionamentos nem aceita host arbitrário |
| Exclusão em cascata | ✅ | Centralizada em `PetService.delete()` (pets → vaccines/appointments/medicalrecords/locations); `UserService.deleteAccount` delega pra lá, não duplica lógica |
| Endpoint público do pet (`GET /public/pets/{publicId}`) | ✅ | DTO mínimo, nunca `tutorId`/e-mail; testado que pet `ARCHIVED` ou inexistente → 404 |
| Endpoint público de avistamento (`POST .../sightings`) | ✅ | Rate limit dedicado (mais restrito, 10/min); sempre usa `Instant.now()` no servidor (não aceita data do cliente, ao contrário do endpoint autenticado) — evita backdating anônimo |

Nenhum pentest destrutivo foi feito contra produção (não há produção
hospedada ainda — tudo roda local/Docker).

---

## Cloudinary (seção 9 do plano de execução)

Auditoria do código de assinatura: `CloudinarySigner` usa SHA-1 dos
parâmetros em ordem alfabética + `api_secret` no fim, exatamente como a
documentação oficial do Cloudinary especifica — vetores de referência
conferidos contra uma implementação Node.js antes de virarem teste
(`CloudinarySignerTest`, já existia da FASE 10). `timestamp` é gerado no
servidor (não confia em valor do cliente). `folder` passou a ser assinado
nesta etapa (ver correção acima).

**✅ RESOLVIDO em 2026-09-12** — o usuário configurou
`CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` reais no Render. Round-trip
completo testado contra a conta de produção real:

```
STATUS: PASS — testado de ponta a ponta contra a conta real
```

1. `POST /uploads/signature` → 200, com `folder` correto (`users/<tutorId>/`).
2. Upload direto de uma imagem real pro Cloudinary → 200, dentro da pasta certa.
3. `GET` na `secure_url` → 200, imagem confirmada de verdade no Cloudinary.
4. `DELETE /uploads` → 204.
5. `GET` na mesma URL, ~15s depois → **404**, `desc=miss` (foi na origem,
   não serviu do cache) — confirma que excluiu e invalidou o CDN.

**Achado real no processo, corrigido antes de fechar**: a primeira
tentativa de exclusão retornou `result: ok` do Cloudinary, mas a URL
antiga continuou respondendo `200` do cache da CDN (Cloudflare,
`Cache-Control: immutable, max-age=2592000` — 30 dias) — `destroy()` não
pedia `invalidate=true`. Risco real: uma foto "excluída" continuava
acessível pela URL antiga por até 30 dias. Corrigido em
`CloudinaryHttpClient.destroy()`, testado (74/74) e confirmado ao vivo
(passo 5 acima). Nenhum teste automatizado mockado teria pego isso — só
apareceu testando contra o Cloudinary de verdade.

---

## App Check / CAPTCHA (seção 8.2 — só avaliação, não implementado)

| | App Check | CAPTCHA (endpoint público) |
|---|---|---|
| Ameaça mitigada | Bots automatizados chamando a API fora do app oficial | Scraping/spam em massa no endpoint de avistamento público |
| Custo | Grátis (Firebase) | Grátis (reCAPTCHA) até um volume alto |
| Impacto UX | Nenhum perceptível (roda em background, native attestation) | Fricção real — usuário que achou um pet precisa resolver um desafio antes de reportar |
| Compatibilidade Flutter/Web | Suportado (`firebase_app_check` package) | Precisa de widget web específico; mobile usa reCAPTCHA Enterprise/v3 (menos fricção, mas mais setup) |
| Impacto no endpoint público | Exigiria que a **página pública do QR** (que ainda não existe, FASE 9) também tivesse App Check configurado — mais uma peça pra construir junto | Só afeta o formulário de avistamento, não a leitura |
| Recomendação | **Adicionar depois que a página pública existir de verdade** — hoje o rate limiting já cobre o risco imediato (volume baixo de uso real) | **Não adicionar agora** — fricção alta pra um problema (spam) que rate limiting já mitiga; reavaliar só se abuso real for observado |

Nenhum dos dois foi implementado nesta etapa — decisão consciente de não
adicionar infraestrutura/fricção de produto sem um problema real
observado ainda.
