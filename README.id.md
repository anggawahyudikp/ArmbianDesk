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
Ubah STB / TV Box ARM64 1 GB menjadi desktop browser yang ringan — cukup pakai flashdisk USB.
</p>

<p align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/releases/download/v0.1.0/armbiandesk-b860h-minimal.img.xz">Unduh File Bootable</a> ·
  <a href="#mulai-dalam-3-langkah">Panduan 3 Langkah</a> ·
  <a href="README.md">English</a> ·
  <a href="docs/HARDWARE.md">Matriks Hardware</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/hero-light.png">
    <img alt="Tampilan desktop ArmbianDesk dan image USB bootable" src="docs/images/hero-light.png" width="880">
  </picture>
</p>

<p align="center">
Tidak perlu setup Linux manual. Tinggal unduh file bootable <code>.img.xz</code> yang sudah jadi,<br/>
tulis ke flashdisk USB pakai <b>Raspberry Pi Imager</b> atau <b>balenaEtcher</b>, colok ke STB, lalu nyalakan.
</p>

---

## Mulai dalam 3 Langkah

### Langkah 1 — Unduh File Bootable

Unduh image siap flash untuk **TV Box Amlogic S905X (`p212` / B860H 1 GB RAM)**:

- **File Bootable:** [`armbiandesk-b860h-minimal.img.xz`](https://github.com/anggawahyudikp/ArmbianDesk/releases/download/v0.1.0/armbiandesk-b860h-minimal.img.xz) *(ukuran unduhan 561 MB → diekstrak 3.5 GB, berisi Debian 12 `bookworm` ARM64, Chromium, Openbox, `zram`, dan `earlyoom`)*
- **Checksum:** [`armbiandesk-b860h-minimal.img.xz.sha256`](https://github.com/anggawahyudikp/ArmbianDesk/releases/download/v0.1.0/armbiandesk-b860h-minimal.img.xz.sha256)

> **Catatan Uji Coba:** File `.img.xz` ini sudah terverifikasi build, isi partisi `ARMBIANBOOT`/`ARMBIAN_ROOT`, script boot, dan checksum SHA-256, **namun belum dites *cold-boot* langsung di STB fisik**. Akun bawaan adalah user `deskuser` dengan password sementara `deskuser` — segera jalankan `passwd` setelah boot pertama untuk menggantinya.

### Langkah 2 — Tulis ke Flashdisk USB

1. Colokkan flashdisk USB (**minimal 4 GB**; seluruh isi flashdisk akan terhapus) ke komputer Windows, macOS, atau Linux Anda.
2. Tulis langsung file **`armbiandesk-b860h-minimal.img.xz`** (tidak perlu diekstrak manual):
   - **Raspberry Pi Imager:** *Choose OS → Use custom → pilih file `.img.xz` → Choose Storage → pilih flashdisk Anda → Next*.
   - **balenaEtcher:** *Flash from file → pilih `.img.xz` → Select target → Flash!*
   - **Terminal Linux (opsional):**
     ```bash
     xz -dk armbiandesk-b860h-minimal.img.xz
     sudo ./bin/armbiandesk-image flash --image ./armbiandesk-b860h-minimal.img --device /dev/sdX
     ```

### Langkah 3 — Colok ke STB & Boot

1. Cabut flashdisk dari PC, colokkan ke port USB STB, pasang kabel HDMI + mouse/keyboard, lalu nyalakan STB (atau tekan tombol reset di lubang AV bila firmware STB butuh pemicu boot USB).
2. ArmbianDesk otomatis masuk ke desktop sebagai `deskuser` dan membuka Chromium.
3. Buka terminal lalu jalankan `passwd` untuk mengganti password bawaan (`deskuser`).

> **Catatan STB Android Bawaan (B860H):** Sebagian revisi firmware B860H mengabaikan USB kecuali fitur USB-first boot diaktifkan dulu. Baca [docs/HARDWARE.md](docs/HARDWARE.md) dan [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md) sebelum mengubah variabel U-Boot eMMC.

---

<h2 align="center">Dua Profil untuk RAM 1 GB.</h2>

<p align="center">
Default super-ringan agar RAM 1 GB tetap lega, atau aktifkan tata letak panel atas + dock bawah kapan saja.
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/profiles-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/profiles-light.png">
    <img alt="Perbandingan profil minimal dan desktop" src="docs/images/profiles-light.png" width="880">
  </picture>
</p>

- **`minimal`** *(aktif bawaan di image)* — `openbox`, wallpaper SVG statis (`feh`), jam ringan (`xclock`), launcher Browser & Files, tanpa compositor maupun dock.
- **`desktop`** *(opsional)* — ubah kapan saja setelah paket XFCE/Plank terpasang (`sudo armbiandesk profile set desktop` — aktif pada login berikutnya) untuk memakai `xfwm4 --compositor=off`, satu top bar `xfce4-panel`, dan satu dock bawah `plank` auto-hide.

---

<h2 align="center">Aman &amp; Terisolasi Sejak Awal.</h2>

| Jaminan | Mekanisme di ArmbianDesk |
| --- | --- |
| **Sandbox Browser Utuh** | Chromium berjalan sebagai user non-root (`deskuser`) tanpa `--no-sandbox`; isolasi situs OS tetap aktif. |
| **Perlindungan RAM 1 GB** | `zram-tools` (`lz4`, 100%) + `earlyoom` menjaga perangkat tetap responsif saat browsing. |
| **Konfigurasi Data-Only** | `/etc/armbiandesk/armbiandesk.conf` divalidasi parser whitelist ketat (`lib/config.sh`), tidak pernah dijalankan sebagai shell. |
| **Proteksi Flash USB** | `armbiandesk-image flash` menolak disk internal (`RM != 1`) dan partisi aktif, lalu mengecek ulang SHA-256. |

---

<details>
<summary><b>Khusus Developer / Pengguna Lanjut: Build Image Sendiri atau Pasang di Armbian Lama</b></summary>

<br/>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/usb-pipeline-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/usb-pipeline-light.png">
    <img alt="Alur 3 langkah membangun image USB bootable" src="docs/images/usb-pipeline-light.png" width="840">
  </picture>
</p>

- **Buat file `.img` kustom dari nol** (`debootstrap` Debian/Ubuntu + `--dtb` / `--start-url` / `--profile` khusus): baca [docs/IMAGE_BUILDER.md](docs/IMAGE_BUILDER.md).
- **Pasang di sistem Armbian ARM64 X11 yang sudah berjalan**: baca [docs/INSTALL.md](docs/INSTALL.md).
- **Uninstall atau restore backup**: baca [docs/UNINSTALL.md](docs/UNINSTALL.md).

</details>

## Dokumentasi &amp; Lisensi

- **Panduan:** [Matriks Hardware](docs/HARDWARE.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Image Builder](docs/IMAGE_BUILDER.md) · [Privasi](docs/PRIVACY.md) · [Laporan Uji](TEST_REPORT.md)
- **Kontribusi:** Laporan bug, hasil uji boot berbagai revisi STB, dan pull request sangat diterima. Lihat [CONTRIBUTING.md](CONTRIBUTING.md) dan [SECURITY.md](SECURITY.md).
- **Lisensi:** Skrip, template, dan aset asli ArmbianDesk dirilis di bawah [Lisensi MIT](LICENSE). File image bootable yang dirilis turut menyertakan paket Debian `bookworm`, kernel Linux, dan U-Boot dengan lisensi upstream masing-masing (GPL-2.0 / GPL-2.0+ / BSD) — lihat detail sumber kode di [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
