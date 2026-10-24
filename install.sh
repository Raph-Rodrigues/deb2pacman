#!/usr/bin/env bash

# Encerra o script se houver erros
set -e

echo ":: Iniciando a instalação do deb2pacman..."

# Verifica se o script está rodando como root (necessário para pacman e /usr/local/bin)
if [ "$EUID" -ne 0 ]; then
  echo "Erro: Por favor, execute como root (use sudo)."
  exit 1
fi

echo "-> Instalando dependências..."
pacman -S --needed --noconfirm lua binutils libarchive zstd

echo "-> Baixando deb2pacman..."
# Substitua a URL abaixo pelo link "Raw" real do seu repositório no GitHub/GitLab
SCRIPT_URL="https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPOSITORIO/main/deb2pacman.lua"
curl -sSL "$SCRIPT_URL" -o /usr/local/bin/deb2pacman

echo "-> Aplicando permissões de execução..."
chmod +x /usr/local/bin/deb2pacman

echo "=> Instalação concluída com sucesso! Digite 'deb2pacman -h' para testar."
