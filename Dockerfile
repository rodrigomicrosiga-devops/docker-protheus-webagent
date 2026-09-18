# ==============================================================================
# ESTÁGIO 1: Builder (extração do pacote oficial)
# ==============================================================================
FROM alpine:3.19 AS builder

RUN apk add --no-cache tar

WORKDIR /tmp/build

# Suporte dinâmico: copia o instalador com tolerância de caixa no nome (mesmo
# padrão de docker-protheus-webapp) -- hoje só existe a build Linux x64
# (P12_SMARTCLIENT_WEB-AGENT_<versão>_LINUX_X64.TAR.GZ), preparado pra crescer
# sem redesenhar quando Windows/macOS entrarem.
COPY ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[tT][aA][rR].[gG][zZ] ./webagent.tar.gz

RUN mkdir -p webagent && tar -xzf webagent.tar.gz -C webagent/

# ==============================================================================
# ESTÁGIO 2: Runner (imagem enxuta de entrega)
# ==============================================================================
FROM alpine:3.19 AS runner
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>" \
      version="1.1.1" \
      description="TOTVS Protheus SmartClient WebAgent (Linux x64) - Delivery Container"

# Usuário não-root: este container só extrai os instaladores pro volume
# compartilhado e fica em standby, não precisa de privilégio nenhum.
RUN addgroup -S webagent && adduser -S -G webagent webagent

WORKDIR /tmp

RUN mkdir -p /mnt/webagent_shared && chown -R webagent:webagent /mnt/webagent_shared

COPY --from=builder --chown=webagent:webagent /tmp/build/webagent /tmp/webagent

COPY --chown=webagent:webagent ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER webagent

# Confirma que pelo menos o pacote .deb foi provisionado -- o entrypoint não
# falha (só avisa) se algum formato individual não estiver presente.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD test -f /mnt/webagent_shared/web-agent-1.1.1-linux-x64-release.deb

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
