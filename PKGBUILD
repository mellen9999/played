# Maintainer: heatsync <mellen@heatsync.org>
pkgname=played-git
_pkgname=played
pkgver=0.1.0.r0.gHEAD
pkgrel=1
pkgdesc="auto-archive music you actually listen to (>=80% played, MPRIS-driven)"
arch=('any')
url="https://github.com/mellen9999/played"
license=('MIT')
depends=('bash' 'playerctl' 'yt-dlp' 'ffmpeg' 'util-linux')
makedepends=('git')
optdepends=(
  'libnotify: desktop notifications on save (planned, v0.2)'
  'rsgain: ReplayGain R128 normalization (planned, v0.2)'
)
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("$_pkgname::git+$url.git")
sha256sums=('SKIP')

pkgver() {
  cd "$_pkgname"
  printf "0.1.0.r%s.g%s" \
    "$(git rev-list --count HEAD)" \
    "$(git rev-parse --short HEAD)"
}

package() {
  cd "$_pkgname"
  make PREFIX=/usr DESTDIR="$pkgdir" install
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
