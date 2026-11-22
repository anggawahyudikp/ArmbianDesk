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
  <img src="https://img.shields.io/github/license/anggawahyudikp/ArmbianDesk" alt="MIT License" />
</p>

<p align="center">
Toolkit desktop ringan & pembuat flashdisk USB bootable untuk STB Armbian ARM64.
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/IMAGE_BUILDER.md">Image Builder</a> ·
  <a href="docs/INSTALL.md">Instalasi</a> ·
  <a href="docs/HARDWARE.md">Matriks Hardware</a>
</p>

---

**ArmbianDesk** mengubah STB/SBC Armbian ARM64 ber-RAM ~1 GB (seperti ZTE B860H S905X) menjadi desktop X11 berfokus browser yang ringan — **sekaligus menyediakan builder untuk langsung membuat image `.img` flashdisk USB bootable dari nol** (`debootstrap` + kernel/DTB/U-Boot + ArmbianDesk terpasang otomatis).

## Dua Profil untuk RAM 1 GB.

- **`minimal`** *(default)* — `openbox`, wallpaper SVG statis (`feh`), jam digital (`xclock`), launcher Browser & Files, tanpa compositor maupun dock.
- **`desktop`** *(opt-in)* — `xfwm4 --compositor=off`, satu top bar fungsional `xfce4-panel`, dan satu dock bawah `plank` (*intelligent auto-hide*, tanpa animasi zoom/suara startup), dengan fallback otomatis ke `minimal` bila `xfwm4` gagal.

## Buat Flashdisk Bootable dalam Satu Perintah.

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

> **Catatan STB Android Bawaan:** Pada revisi tertentu ZTE B860H, U-Boot bawaan memerlukan aktivasi USB-first-boot terlebih dahulu. Lihat [docs/HARDWARE.md](docs/HARDWARE.md) dan modul opsional [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md).

## Pasang di Armbian yang Sudah Boot

```bash
./bin/armbiandesk install --user USER --profile minimal --dry-run
sudo ./bin/armbiandesk install --user USER --profile minimal
```

Tambahkan `--enable-autologin` bila ingin autologin LightDM melalui drop-in terpisah, atau ubah profil kapan saja dengan `sudo armbiandesk profile set desktop`.

## Lisensi & Kontribusi

Dirilis dengan [Lisensi MIT](LICENSE). Lihat [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) untuk daftar paket pihak ketiga. Laporan bug, hasil uji revisi hardware, dan pull request sangat diterima.
