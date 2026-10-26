#!/usr/bin/env bash

# Encerra o script se houver erros
set -euo pipefail

echo ":: Iniciando a instalação do deb2pacman..."

# Verifica se o script está rodando como root (necessário para pacman e /usr/local)
if [ "$EUID" -ne 0 ]; then
  echo "Erro: Por favor, execute como root (use sudo)."
  exit 1
fi

echo "-> Instalando dependências..."
pacman -S --needed --noconfirm lua binutils libarchive zstd xz

INSTALL_DIR="/usr/local/lib/deb2pacman"
BIN_PATH="/usr/local/bin/deb2pacman"
FILES=(main.lua utils.lua logger.lua extractor.lua builder.lua translator.lua)
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
LOCAL_DIR=""

if [ -n "$SCRIPT_SOURCE" ] && [ -f "$SCRIPT_SOURCE" ]; then
  LOCAL_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
fi

install -d "$INSTALL_DIR"

if [ -n "$LOCAL_DIR" ] && [ -f "$LOCAL_DIR/main.lua" ]; then
  echo "-> Instalando arquivos locais de $LOCAL_DIR..."
  for file in "${FILES[@]}"; do
    install -m644 "$LOCAL_DIR/$file" "$INSTALL_DIR/$file"
  done
else
  echo "-> Baixando deb2pacman..."
  BASE_URL="https://raw.githubusercontent.com/Raph-Rodrigues/deb2pacman/refs/heads/main"

  for file in "${FILES[@]}"; do
    curl -fsSL "$BASE_URL/$file" -o "$INSTALL_DIR/$file"
  done
fi

echo "-> Criando executável..."
cat > "$BIN_PATH" <<'EOF'
#!/bin/sh
exec lua /usr/local/lib/deb2pacman/main.lua "$@"
EOF
chmod +x "$BIN_PATH"

echo "=> Instalação concluída com sucesso! Digite 'deb2pacman -h' para testar."
