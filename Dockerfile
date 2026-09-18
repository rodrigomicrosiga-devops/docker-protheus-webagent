# ==============================================================================
# ESTÁGIO 1: Builder (extração dos pacotes oficiais)
# ==============================================================================
FROM alpine:3.19 AS builder

RUN apk add --no-cache tar unzip

WORKDIR /tmp/build

# Suporte dinâmico: copia todos os pacotes com tolerância de caixa no nome
# (mesmo padrão de docker-protheus-webapp) -- três formatos de arquivo
# possíveis (Linux vem em .tar.gz, Windows em .zip, macOS em .dmg direto),
# pra cada SO/arquitetura que a Central de Downloads TOTVS oferece pra esta
# versão. Falta um pacote? Sem problema -- o `find` abaixo só processa o que
# existir de fato, e o entrypoint.sh já entrega qualquer arquivo presente
# sem exigir nome fixo.
COPY ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[tT][aA][rR].[gG][zZ] ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[zZ][iI][pP] ./*[wW][eE][bB]-[aA][gG][eE][nN][tT]*.[dD][mM][gG] ./raw/

RUN mkdir -p webagent && \
    find raw -iname '*.tar.gz' -exec sh -c 'tar -xzf "$1" -C webagent/' _ {} \; && \
    find raw -iname '*.zip' -exec sh -c 'unzip -oq "$1" -d webagent/' _ {} \; && \
    find raw -iname '*.dmg' -exec cp {} webagent/ \;

# ==============================================================================
# ESTÁGIO 2: Runner (imagem enxuta de entrega)
# ==============================================================================
FROM alpine:3.19 AS runner
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>" \
      version="1.1.1" \
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
    CMD test -f /mnt/webagent_shared/web-agent-1.1.1-linux-x64-release.deb

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
