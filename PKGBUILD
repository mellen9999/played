# Maintainer: heatsync <mellen@heatsync.org>
pkgname=played-git
_pkgname=played
pkgver=0.2.2.r0.gHEAD
pkgrel=1
pkgdesc="auto-archive music you actually listen to (>=80% played, MPRIS-driven)"
arch=('any')
url="https://github.com/mellen9999/played"
license=('MIT')
depends=('bash' 'playerctl' 'yt-dlp' 'ffmpeg' 'util-linux' 'python' 'python-mutagen')
makedepends=('git')
optdepends=(
  'libnotify: desktop notifications on save (planned, v0.3)'
  'rsgain: ReplayGain R128 normalization (planned, v0.3)'
  'chromaprint: AcoustID fingerprint verification (planned, v0.3)'
)
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("$_pkgname::git+$url.git")
sha256sums=('SKIP')

pkgver() {
  cd "$_pkgname"
  # use latest annotated tag → e.g. 0.2.1.r5.g1482fea (5 commits past v0.2.1)
  git describe --long --tags 2>/dev/null | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}

package() {
  cd "$_pkgname"
  make PREFIX=/usr DESTDIR="$pkgdir" install
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
