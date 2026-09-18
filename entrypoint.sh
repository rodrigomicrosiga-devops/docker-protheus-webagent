#!/bin/sh
set -e

echo "📦 [WebAgent Delivery] Inicializando provisionamento dos instaladores v1.1.1 (Linux x64)..."

TARGET_DIR="/mnt/webagent_shared"

# Limpeza cirúrgica sem tentar deletar a pasta presa pelo Kernel (evita
# "Device or resource busy") -- mesmo padrão de docker-protheus-webapp.
echo "🧹 Limpando resíduos antigos de forma segura..."
if [ -d "$TARGET_DIR" ]; then
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
fi

echo "📂 Provisionando instaladores do WebAgent na raiz do volume..."

# Copia todos os arquivos extraídos do pacote (hoje: o .deb e o .rpm do
# Linux x64) -- não assume um nome fixo, só que existam arquivos em
# /tmp/webagent/, pra já aceitar builds de outro SO no futuro sem editar
# este script.
COPIADO=false
for f in /tmp/webagent/*; do
    [ -f "$f" ] || continue
    cp "$f" "$TARGET_DIR/"
    COPIADO=true
done

if [ "$COPIADO" = "false" ]; then
    echo "⚠️  Aviso: nenhum instalador encontrado em /tmp/webagent/"
fi

echo "✅ Instaladores do WebAgent provisionados com sucesso no volume compartilhado!"
echo "💤 Mantendo container em standby para governança do volume."

exec tail -f /dev/null
