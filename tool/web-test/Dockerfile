# Contorno pro bug de loopback do Windows nesta máquina de dev (ver
# docs/migration/handoff.md, seção 3): `flutter test --platform=chrome` roda
# aqui dentro (Linux), mesmo padrão já usado pra API/Mongo. Fora dessa
# máquina específica (CI Linux, outro dev em Mac/Linux) isto não deveria ser
# necessário — `flutter test --platform=chrome` direto já funciona.
#
# STATUS (2026-09-11): resolve o travamento original e chega a compilar +
# abrir o Chrome (achou e corrigiu um bug real de sandbox no caminho — ver
# comentário abaixo), mas ainda NÃO consegue rodar auth_flow_test.dart até o
# fim: `setUpAll` trava ~12min sem erro (suspeita não confirmada: SDK JS do
# Firebase Auth preso em algo de IndexedDB/storage num Chrome --no-sandbox
# como root). Detalhe completo em docs/migration/handoff.md, seção 3. Se for
# debugar mais: rodar sem --dart-define nenhum é um bom próximo passo (isola
# se o problema é o Firebase em si ou especificamente o useAuthEmulator).
#
# Build (uma vez, ~5-10min por baixar o SDK do Flutter + Chrome):
#   docker build -t petconnect-web-test -f tool/web-test/Dockerfile tool/web-test
#
# Uso (da raiz do repo do app; ajuste os dart-defines conforme o teste).
# --add-host é necessário pro container enxergar serviços rodando no HOST
# (API, Auth Emulator). No Git Bash no Windows, prefixe com MSYS_NO_PATHCONV=1
# (senão `/app` vira um caminho do Windows sem querer):
#   MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD":/app -w /app \
#     --add-host=host.docker.internal:host-gateway \
#     petconnect-web-test bash -c "flutter pub get && flutter test --platform=chrome \
#       --dart-define=USE_API_USUARIO=true \
#       --dart-define=API_BASE_URL=http://host.docker.internal:8090 \
#       --dart-define=AUTH_EMULATOR_HOST=host.docker.internal \
#       test/features/auth/auth_flow_test.dart"
FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.47.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git unzip xz-utils zip ca-certificates gnupg \
        libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Chrome estável — o Dart test runner o inicia sozinho (não precisa de
# chromedriver separado; flutter_tools fala com ele via DevTools Protocol).
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Wrapper que força --no-sandbox: o sandbox do Chrome precisa de privilégios
# de namespace que o container não tem por padrão — sem isto o processo do
# Chrome sobe mas trava sem erro nenhum (visto na prática: CPU/memória
# zerados, nunca conecta no test runner). --disable-dev-shm-usage evita
# depender do /dev/shm pequeno padrão do Docker (64MB, Chrome quer mais).
RUN printf '#!/bin/sh\nexec /usr/bin/google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"\n' \
        > /usr/local/bin/chrome-no-sandbox \
    && chmod +x /usr/local/bin/chrome-no-sandbox
ENV CHROME_EXECUTABLE=/usr/local/bin/chrome-no-sandbox

# SDK na mesma versão do projeto (pubspec.yaml / `flutter --version` no host)
# — evita resolução de deps diferente da que já está no pubspec.lock.
RUN git clone --branch ${FLUTTER_VERSION} --depth 1 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app
