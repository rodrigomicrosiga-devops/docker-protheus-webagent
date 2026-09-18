# docker-protheus-webagent

Imagem de **entrega (sidecar)** dos instaladores do TOTVS SmartClient WebAgent — Windows
(x86/x64), macOS (Universal) e Linux (`.deb`/`.rpm`).

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
executa — só entrega. Com todos os 5 instaladores hoje entregues por este sidecar, a imagem do
`appserver-core` continua exatamente do tamanho que sempre foi.

## Como o AppServer consome isto

O `appserver.ini` tem uma seção `[WEBAGENT]` que aceita **caminho relativo ao diretório de
trabalho do AppServer** (confirmado na documentação oficial — não é URL, é caminho de arquivo
que o próprio AppServer lê e serve pro navegador):

```ini
[WEBAGENT]
VERSION=1.1.1
Windows_x86=webagent/web-agent-1.1.1-windows-x86-release.setup.exe
Windows_x64=webagent/web-agent-1.1.1-windows-x64-release.setup.exe
Darwin_universal=webagent/26-07-02-P12_SMARTCLIENT_WEB-AGENT_1.1.1_MAC-UNIVERSAL.DMG
Linux_x64_deb=webagent/web-agent-1.1.1-linux-x64-release.deb
Linux_x64_rpm=webagent/web-agent-1.1.1-linux-x64-release.rpm
```

O `entrypoint.sh` do `docker-protheus-appserver` copia os arquivos deste volume
(`/tmp/webagent_shared`, montado somente-leitura, mesmo mecanismo já usado pra `webapp.so` e pro
`printer`) para `webagent/` dentro do diretório de trabalho do AppServer antes de gerar o `.ini`,
**detectando dinamicamente** quais arquivos existem (nunca fixa nome/versão) — ver
`docker-protheus-appserver/entrypoint.sh`.

## Fonte dos artefatos

Pacotes oficiais da Central de Downloads TOTVS, versão `1.1.1`:

| Arquivo (Central de Downloads) | Conteúdo | Formato |
|---|---|---|
| `P12_SMARTCLIENT_WEB-AGENT_1.1.1_LINUX_X64.TAR.GZ` | `.deb` + `.rpm` (os dois no mesmo pacote) | `.tar.gz` |
| `P12_SMARTCLIENT_WEB-AGENT_1.1.1_WINDOWS_X64.ZIP` | `web-agent-1.1.1-windows-x64-release.setup.exe` | `.zip` |
| `P12_SMARTCLIENT_WEB-AGENT_1.1.1_WINDOWS_X86.ZIP` | `web-agent-1.1.1-windows-x86-release.setup.exe` | `.zip` |
| `P12_SMARTCLIENT_WEB-AGENT_1.1.1_MAC-UNIVERSAL.DMG` | instalador universal (Intel + Apple Silicon) | `.dmg` direto |
| `P12_SMARTCLIENT_WEB-AGENT_1.1.1_MAC_X64.DMG` | build x64-only (legado/alternativo) | `.dmg` direto |

Também existem `P12_INSTALADOR_WEB-AGENT_MSI_1.1.1_WINDOWS_{X64,X86}.ZIP` — pacotes `.msi`, um
**fluxo de distribuição diferente** (instalação remota via GPO de Active Directory, não o botão de
download do navegador). Este sidecar entrega os `.msi` no volume compartilhado também (caso um
admin precise deles pra GPO), mas **não** ficam referenciados em `[WEBAGENT]` — não existe chave
documentada pra essa variante, e o fluxo de auto-download do WebApp não usa MSI.

`Darwin_universal` prefere o build `MAC-UNIVERSAL` quando mais de um `.dmg` está presente (único
com chave documentada em `[WEBAGENT]`) — o `MAC_X64.DMG` fica disponível no volume mas sem
referência no `.ini`.

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

## Adicionando uma versão nova ou outro SO no futuro

A estrutura já está pronta pra crescer sem redesenho — todos os formatos que a Central de
Downloads TOTVS usa hoje (`.tar.gz`, `.zip`, `.dmg`) já são tratados dinamicamente pelo builder do
`Dockerfile` (`find -iname`, não nome fixo):

1. Baixar o(s) pacote(s) novo(s) da Central de Downloads.
2. Colocar na raiz deste repositório (descoberto dinamicamente pelo CI e pelo `Dockerfile`, não
   precisa editar nenhum dos dois pra um formato já suportado).
3. Se a TOTVS introduzir um formato de arquivo novo (não `.tar.gz`/`.zip`/`.dmg`), ajustar o
   estágio builder do `Dockerfile`.
4. O `entrypoint.sh` deste repo já copia **qualquer arquivo** presente em `/tmp/webagent/` sem
   precisar de nome fixo — não exige mudança.
5. `docker-protheus-appserver/entrypoint.sh` já detecta dinamicamente Windows x86/x64 (pelo nome
   do arquivo, não a extensão — `.exe` sozinho é ambíguo) e macOS (preferindo `universal`) — só
   precisa de mudança lá se a TOTVS introduzir uma arquitetura nova sem paralelo hoje (ex.: ARM
   nativo do Windows).

## Rastreabilidade de Build

Toda imagem publicada carrega o label `org.opencontainers.image.revision` com o SHA do commit
que originou o build, seguindo a convenção padronizada em toda a frota.
