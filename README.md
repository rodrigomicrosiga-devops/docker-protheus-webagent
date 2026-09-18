# docker-protheus-webagent

Imagem de **entrega (sidecar)** dos instaladores do TOTVS SmartClient WebAgent — hoje só a build
Linux x64 (`.deb`/`.rpm`).

## O que é o WebAgent (e por que ele não roda aqui)

O WebAgent é um utilitário **client-side** — instalado na estação do próprio usuário final, nunca
no servidor. É o que dá ao SmartClient HTML (rodando no navegador, sandboxed) acesso a coisas que
o navegador sozinho não permite: leitura/gravação de arquivo local, integração com Microsoft
Office, integração com DLLs/SOs/Dylibs locais. Documentação oficial:
[TDN — WebApp/WebAgent](https://tdn.totvs.com/display/tec/2.+WebApp+-+WebAgent).

Este repositório não executa o WebAgent — só entrega o **instalador** pro navegador do usuário
baixar, através do próprio AppServer/WebApp.

## Por que um repo separado, não embutido no `appserver-core`

Mesmo padrão de `docker-protheus-webapp`/`docker-protheus-printer`: **atualização
zero-downtime** — trocar a versão do WebAgent não exige rebuildar nem reiniciar o AppServer
principal, só substituir este sidecar. E evita o problema que motivou a decisão original: incluir
o instalador de cada sistema operacional (Windows x86/x64, macOS, Linux deb/rpm) dentro da mesma
imagem do AppServer deixaria essa imagem desproporcionalmente pesada pra algo que o servidor nem
executa — só entrega.

## Como o AppServer consome isto

O `appserver.ini` tem uma seção `[WEBAGENT]` que aceita **caminho relativo ao diretório de
trabalho do AppServer** (confirmado na documentação oficial — não é URL, é caminho de arquivo
que o próprio AppServer lê e serve pro navegador):

```ini
[WEBAGENT]
VERSION=1.1.1
Linux_x64_deb=webagent/web-agent-1.1.1-linux-x64-release.deb
Linux_x64_rpm=webagent/web-agent-1.1.1-linux-x64-release.rpm
```

O `entrypoint.sh` do `docker-protheus-appserver` copia os arquivos deste volume
(`/tmp/webagent_shared`, montado somente-leitura, mesmo mecanismo já usado pra `webapp.so` e pro
`printer`) para `webagent/` dentro do diretório de trabalho do AppServer antes de gerar o `.ini` —
ver `docker-protheus-appserver/entrypoint.sh`.

## Fonte do artefato

Pacote oficial `P12_SMARTCLIENT_WEB-AGENT_<versão>_LINUX_X64.TAR.GZ`, baixado da Central de
Downloads TOTVS. Contém os dois formatos Linux dentro do mesmo `.tar.gz`
(`web-agent-<versão>-linux-x64-release.deb` e `.rpm`) — não precisa de download separado por
formato.

Assim como `advpl`/`tlpp` do `docker-protheus-includes`, é atualizado manualmente pelo usuário
sempre que a TOTVS libera uma versão nova — sem cadência fixa.

## Versionamento — por quê não acompanha a release do Protheus

Mesmo raciocínio do `docker-protheus-includes`: o WebAgent tem ciclo de release próprio,
independente da release do Protheus. Tag semver simples aqui (`1.1.1`, acompanhando a versão do
próprio WebAgent — não `PROTHEUS_RELEASE`), bump manual a cada atualização do pacote.

## Repositório público — por quê

Diferente de `docker-protheus-rpo`/`-system`/`-systemload`/`-includes` (conteúdo proprietário
ligado ao dicionário/licença do cliente), o WebAgent é um binário redistribuível genérico — a
mesma "receita" que qualquer instalação Protheus usa, sem dado de cliente embutido. Mesma
categoria de `webapp`/`printer`/`dbaccess`: público.

## Adicionando outro sistema operacional

A estrutura já está pronta pra crescer sem redesenho:

1. Baixar o pacote do SO novo (Windows x86/x64 ou macOS Universal) da Central de Downloads.
2. Colocar o `.tar.gz`/`.zip` na raiz deste repositório (mesmo padrão do Linux — descoberto
   dinamicamente pelo CI, não precisa editar o workflow).
3. Ajustar o `Dockerfile` se o formato de extração for diferente (Windows/macOS costumam vir como
   `.zip`, não `.tar.gz` — o builder atual só lida com `tar`).
4. O `entrypoint.sh` já copia **qualquer arquivo** presente em `/tmp/webagent/` sem precisar de
   nome fixo — não exige mudança.
5. Adicionar a chave correspondente em `[WEBAGENT]` no `appserver.ini`
   (`Windows_x86`/`Windows_x64`/`Darwin_universal`) — mudança em
   `docker-protheus-appserver/entrypoint.sh`, fora deste repo.

## Rastreabilidade de Build

Toda imagem publicada carrega o label `org.opencontainers.image.revision` com o SHA do commit
que originou o build, seguindo a convenção padronizada em toda a frota.
