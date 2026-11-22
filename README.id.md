# ArmbianDesk (Bahasa Indonesia)

**ArmbianDesk** adalah toolkit desktop X11 ringan berfokus browser dan pembuat image **flashdisk USB bootable ARM64** untuk STB/SBC berbasis Armbian dengan RAM terbatas (~1 GB).

> **Catatan Ruang Lingkup:** Lapisan desktop inti (`armbiandesk`) berjalan di atas sistem Linux Armbian/Debian/Ubuntu ARM64 yang sudah boot. Untuk kebutuhan membuat **flashdisk bootable secara langsung**, tersedia `armbiandesk-image` yang membangun file `.img` dari nol (`debootstrap` rootfs ARM64 + kernel/DTB/U-Boot dari image donor atau tarball terverifikasi + ArmbianDesk terpasang otomatis) beserta utilitas flasher USB yang aman. Pada unit STB Android bawaan pabrik (seperti revisi tertentu ZTE B860H), boot dari USB mungkin memerlukan aktivasi USB-first-boot terlebih dahulu; lihat [docs/HARDWARE.md](docs/HARDWARE.md) dan [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md).

## Fitur Utama (v0.1.0)
- **Dua Profil Desktop**:
  - `minimal` *(default)*: Window manager `openbox`, wallpaper SVG statis (`feh`), jam digital ringan (`xclock`), launcher Browser & Files, tanpa compositor maupun dock.
  - `desktop` *(opt-in)*: `xfwm4 --compositor=off`, satu top bar fungsional `xfce4-panel`, dan satu dock bawah terpusat `plank` (*intelligent auto-hide*, tanpa animasi zoom/suara startup).
- **Pembuat Flashdisk Bootable Penuh (`armbiandesk-image`)**:
  - Membangun file `.img` partisi ganda (`ARMBIAN_BOOT` FAT32 + `ARMBIAN_ROOT` ext4) dari nol dengan `debootstrap`, `qemu-aarch64-static`, `extlinux.conf`, skrip U-Boot terkompilasi (`s905_autoscript`, `aml_autoscript`), `zram-tools`, `earlyoom`, dan ArmbianDesk siap pakai.
  - Penulis USB (`armbiandesk-image flash`) menolak disk non-removable/disk OS dan memverifikasi hasil tulis dengan SHA-256 readback.
- **Keamanan & Keandalan**:
  - Parser konfigurasi berbasis whitelist data murni (tidak pernah menjalankan `source`/`eval`).
  - Browser berjalan sebagai user biasa dengan sandbox & site isolation aktif (tanpa `--no-sandbox`).
  - Installer idempoten dengan `--dry-run`, `--destdir`/`--root`, backup atomik, rollback otomatis jika gagal di tengah jalan, dan deteksi konflik saat restore.

## Panduan Singkat

### 1. Membuat Image & Flashdisk Bootable
```bash
# Cek rencana build (dry-run tanpa akses root)
./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/ke/armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --dry-run

# Build image .img (memerlukan sudo, debootstrap, qemu-user-static, u-boot-tools)
sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/ke/armbian-s905x.img \
  --output ./out/armbiandesk-usb.img

# Tulis ke flashdisk /dev/sdX dan verifikasi SHA-256
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```

### 2. Memasang ke Armbian yang Sudah Boot
```bash
./bin/armbiandesk install --user USER --profile minimal --dry-run
sudo ./bin/armbiandesk install --user USER --profile minimal
# Opsional autologin via drop-in terpisah:
sudo ./bin/armbiandesk install --user USER --profile minimal --enable-autologin
```

Lihat [README.md](README.md) dan direktori [`docs/`](docs) untuk dokumentasi teknis lengkap.
