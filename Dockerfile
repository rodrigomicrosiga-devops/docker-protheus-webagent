# ==============================================================================
# ESTÁGIO 1: Builder (extração dos pacotes oficiais)
# ==============================================================================
FROM alpine:3.19 AS builder

RUN apk add --no-cache tar unzip

WORKDIR /tmp/build

# Todos os pacotes web-agent* do contexto entram em raw/ (tolerando caixa no nome). O formato é
# detectado pelo CONTEÚDO, não pela extensão: a TOTVS já entregou o instalador MSI da 1.1.2 como um
# arquivo MSI cru com extensão .ZIP (na 1.1.1 era um zip de verdade). Formato desconhecido ou
# erro de extração derruba o build (nada de `find -exec`, que devolve 0 mesmo quando o comando falha).
ARG WEBAGENT_VERSION
COPY ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[tT][aA][rR].[gG][zZ] ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[zZ][iI][pP] ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[dD][mM][gG] ./raw/

RUN set -e; mkdir -p webagent; \
    for f in raw/*; do \
      b="$(basename "$f")"; \
      magic="$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')"; \
      case "$magic" in \
        1f8b*)    tar -xzf "$f" -C webagent/ ;; \
        504b0304) unzip -oq "$f" -d webagent/ ;; \
        d0cf11e0) arch="$(echo "$b" | sed -E 's/.*_WINDOWS_(X64|X86)\..*/\1/' | tr 'A-Z' 'a-z')"; \
                  case "$arch" in x64|x86) ;; *) echo "ERRO: arquitetura do MSI não identificada em $b" >&2; exit 1 ;; esac; \
                  cp "$f" "webagent/web-agent-${WEBAGENT_VERSION}-windows-${arch}-release.msi" ;; \
        *)        case "$b" in *.[dD][mM][gG]) cp "$f" webagent/ ;; *) echo "ERRO: formato desconhecido: $b" >&2; exit 1 ;; esac ;; \
      esac; \
    done; \
    test -f "webagent/web-agent-${WEBAGENT_VERSION}-linux-x64-release.deb" || { echo "ERRO: .deb Linux x64 ausente" >&2; exit 1; }

# ==============================================================================
# ESTÁGIO 2: Runner (imagem enxuta de entrega)
# ==============================================================================
FROM alpine:3.19 AS runner
# Versão do pacote (ex.: 1.1.2): vem do construtor (build-arg), sem valor padrão
# para não rotular uma imagem com a versão errada.
ARG WEBAGENT_VERSION
RUN test -n "${WEBAGENT_VERSION}" || { echo "ERRO: passe --build-arg WEBAGENT_VERSION=<versão>" >&2; exit 1; }
ENV WEBAGENT_VERSION=${WEBAGENT_VERSION}
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>" \
      version="${WEBAGENT_VERSION}" \
      description="TOTVS Protheus SmartClient WebAgent (Windows/macOS/Linux) - Delivery Container"

# Usuário não-root: este container só extrai os instaladores pro volume
# compartilhado e fica em standby, não precisa de privilégio nenhum.
RUN addgroup -S webagent && adduser -S -G webagent webagent

WORKDIR /tmp

RUN mkdir -p /mnt/webagent_shared && chown -R webagent:webagent /mnt/webagent_shared

COPY --from=builder --chown=webagent:webagent /tmp/build/webagent /tmp/webagent

COPY --chown=webagent:webagent ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER webagent

# Confirma que pelo menos o pacote Linux (.deb) foi provisionado -- é a
# única build presente desde o primeiro release deste repo, serve de sinal
# mínimo de saúde. O entrypoint não falha (só avisa) se algum formato
# individual não estiver presente.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD test -f /mnt/webagent_shared/web-agent-${WEBAGENT_VERSION}-linux-x64-release.deb

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
