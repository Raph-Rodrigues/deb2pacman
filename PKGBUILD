# Maintainer: Raph-Rodrigues <raph.edits06l@gmail.com>
pkgname=deb2pacman
pkgver=1.0.4
pkgrel=1
pkgdesc="Conversor de pacotes Debian (.deb) para Arch Linux (.pkg.tar.zst) escrito em Lua"
arch=('any')
url="https://github.com/Raph-Rodrigues/deb2pacman"
license=('MIT')
depends=('lua' 'binutils' 'libarchive' 'zstd' 'xz')

# Mantém todos os artefatos do makepkg dentro de ./build.
# $startdir é definido pelo makepkg antes de carregar este arquivo.
_startdir="${startdir:-$PWD}"
BUILDDIR="$_startdir/build"
PKGDEST="$_startdir/build"
SRCDEST="$_startdir/build/sources"
SRCPKGDEST="$_startdir/build"
LOGDEST="$_startdir/build/logs"

mkdir -p "$BUILDDIR" "$SRCDEST" "$LOGDEST"

# O código é baixado da tag correspondente à versão atual.
# Crie a tag com ./bump-version.sh antes de gerar o pacote.
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('SKIP') # O workflow de release executa 'updpkgsums' automaticamente

package() {
  local src="$srcdir/${pkgname}-${pkgver}"

  install -d "$pkgdir/usr/lib/$pkgname" "$pkgdir/usr/bin"

  # Instala o programa principal e todos os módulos Lua usados por ele
  install -m644 "$src"/*.lua "$pkgdir/usr/lib/$pkgname/"

  # Pequeno launcher para que o 'require' encontre os módulos em /usr/lib
  cat > "$pkgdir/usr/bin/$pkgname" <<'EOF'
#!/bin/sh
exec lua /usr/lib/deb2pacman/main.lua "$@"
EOF
  chmod 755 "$pkgdir/usr/bin/$pkgname"

  install -Dm644 "$src/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
