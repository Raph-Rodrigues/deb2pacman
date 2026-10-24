# Maintainer: Raph-Rodrigues <raph.edits06l@gmail.com>
pkgname=deb2pacman
pkgver=1.0.0
pkgrel=1
pkgdesc="Conversor de pacotes Debian (.deb) para Arch Linux (.pkg.tar.zst) escrito em Lua"
arch=('any')
url="https://github.com/Raph-Rodrigues/deb2pacman"
license=('MIT')
depends=('lua' 'binutils' 'libarchive' 'zstd')
source=("${pkgname}-${pkgver}.lua::https://raw.githubusercontent.com/Raph-Rodrigues/deb2pacman/refs/heads/main/main.lua")
sha256sums=('SKIP') # Em produção, substitua SKIP pelo hash real gerado com 'updpkgsums'

package() {
  # Cria o diretório /usr/bin dentro do pacote
  install -d "$pkgdir/usr/bin"

  # Instala o script renomeando-o sem a extensão .lua e com permissão 755 (executável)
  install -m755 "${srcdir}/${pkgname}-${pkgver}.lua" "$pkgdir/usr/bin/$pkgname"
}
