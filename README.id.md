<h1 align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk">
    <img src="logo.svg" alt="ArmbianDesk" width="128" height="128" />
    <br />
    ArmbianDesk
  </a>
</h1>

<p align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/releases/latest"><img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/anggawahyudikp/ArmbianDesk?sort=semver"></a>
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/anggawahyudikp/ArmbianDesk/ci.yml?branch=main"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/anggawahyudikp/ArmbianDesk" alt="MIT License" /></a>
</p>

<p align="center">
Toolkit desktop browser ringan &amp; pembuat flashdisk USB bootable untuk STB Armbian ARM64.
</p>

<p align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/releases/latest">Unduh v0.1.0</a> ·
  <a href="README.md">English</a> ·
  <a href="docs/IMAGE_BUILDER.md">Image Builder</a> ·
  <a href="docs/INSTALL.md">Instalasi</a> ·
  <a href="docs/HARDWARE.md">Matriks Hardware</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/hero-light.png">
    <img alt="Tampilan sesi desktop ArmbianDesk dan pembuat image USB bootable" src="docs/images/hero-light.png" width="880">
  </picture>
</p>

<p align="center">
Ubah STB/SBC ARM64 ber-RAM ~1 GB (seperti ZTE B860H S905X) menjadi desktop X11 berfokus browser yang responsif —<br/>
pasang di Armbian yang sudah berjalan atau buat langsung file <code>.img</code> flashdisk USB bootable dari nol.
</p>

---

<h2 align="center">Dua Profil untuk RAM 1 GB.</h2>

<p align="center">
Sesuaikan bobot desktop dengan kapasitas RAM perangkat Anda —<br/>
mulai dari sesi Openbox super-ringan hingga tata letak panel atas dan dock bawah.
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/profiles-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/profiles-light.png">
    <img alt="Perbandingan profil minimal dan desktop" src="docs/images/profiles-light.png" width="880">
  </picture>
</p>

- **`minimal`** *(default)* — `openbox`, wallpaper SVG statis (`feh`), jam digital (`xclock`), launcher Browser & Files, tanpa compositor maupun dock.
- **`desktop`** *(opt-in)* — `xfwm4 --compositor=off`, satu top bar fungsional `xfce4-panel`, satu dock bawah `plank` (*intelligent auto-hide*, tanpa animasi zoom/suara startup), serta fallback otomatis ke `minimal` bila `xfwm4` gagal.

---

<h2 align="center">Flashdisk Bootable dalam Satu Perintah.</h2>

<p align="center">
Bangun image ARM64 dua-partisi (<code>ARMBIAN_BOOT</code> FAT32 + <code>ARMBIAN_ROOT</code> ext4) lengkap dengan<br/>
<code>debootstrap</code>, kernel &amp; <code>u-boot.ext</code> donor, U-Boot autoscript, <code>zram</code> + <code>earlyoom</code>, dan ArmbianDesk siap pakai.
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/usb-pipeline-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/usb-pipeline-light.png">
    <img alt="Alur 3 langkah membangun dan menulis image USB bootable" src="docs/images/usb-pipeline-light.png" width="880">
  </picture>
</p>

```bash
# 1. Cek rencana build (dry-run tanpa root)
./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/ke/armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --dry-run

# 2. Build image .img (memerlukan sudo, debootstrap, qemu-user-static, u-boot-tools)
HASH="$(openssl passwd -6)"
sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser --password-hash "$HASH" \
  --boot-source-image /path/ke/armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --compress

# 3. Tulis aman ke flashdisk USB /dev/sdX + verifikasi SHA-256 readback
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```

> **Catatan STB Android Bawaan:** Pada revisi tertentu ZTE B860H, U-Boot bawaan memerlukan aktivasi USB-first-boot terlebih dahulu. Baca [docs/HARDWARE.md](docs/HARDWARE.md) dan modul opsional [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md) sebelum mengubah variabel U-Boot eMMC.

---

<h2 align="center">Aman &amp; Terisolasi Sejak Awal.</h2>

| Jaminan | Mekanisme di ArmbianDesk |
| --- | --- |
| **Sandbox Browser Utuh** | Chromium berjalan sebagai user non-root tanpa `--no-sandbox`; isolasi situs OS tetap aktif. |
| **Konfigurasi Data-Only** | [`armbiandesk.conf`](config/armbiandesk.conf.example) divalidasi parser whitelist ketat (`lib/config.sh`), tidak pernah di-`source` atau `eval`. |
| **Backup &amp; Rollback Atomik** | `install` membuat manifest `0600`, otomatis rollback jika gagal di tengah jalan, dan menjaga profil browser saat `uninstall`. |
| **Proteksi Flash USB** | `armbiandesk-image flash` menolak disk non-removable (`RM != 1`) dan partisi sistem yang sedang ter-mount. |

---

## Mulai Sekarang

Sudah boot ke Armbian ARM64 X11? [Unduh ArmbianDesk v0.1.0](https://github.com/anggawahyudikp/ArmbianDesk/releases/latest) atau pasang langsung dari repository:

```bash
./bin/armbiandesk install --user USER --profile minimal --dry-run
sudo ./bin/armbiandesk install --user USER --profile minimal
```

Tambahkan `--enable-autologin` bila ingin autologin LightDM melalui drop-in terpisah, atau ubah profil kapan saja dengan `sudo armbiandesk profile set desktop`.

## Dokumentasi &amp; Kontribusi

- Panduan lengkap: [Image Builder](docs/IMAGE_BUILDER.md) · [Instalasi](docs/INSTALL.md) · [Uninstall & Restore](docs/UNINSTALL.md) · [Matriks Hardware](docs/HARDWARE.md) · [Laporan Uji](TEST_REPORT.md)
- Dirilis dengan [Lisensi MIT](LICENSE). Lihat [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) untuk daftar paket pihak ketiga. Laporan bug, hasil uji revisi hardware, dan pull request sangat diterima.
