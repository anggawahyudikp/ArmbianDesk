# Cara Membuat Flashdisk Bootable Terdeteksi di STB (ZTE B860H / Amlogic)

Berbeda dengan PC/laptop yang punya BIOS/UEFI untuk otomatis membaca flashdisk, **STB Android TV Box tidak selalu otomatis boot dari USB** saat pertama kali dicolok. Berhasil atau tidaknya tergantung pengaturan bootloader U-Boot di eMMC bawaan STB.

Ikuti metode di bawah secara berurutan — berhenti begitu STB sudah mau masuk ke ArmbianDesk.

---

## Cek Cepat Sebelum Mulai

1. **Coba semua port USB di STB.** U-Boot bawaan Amlogic (`usb start 0`) sering hanya memeriksa **USB Port 0** (biasanya port paling dekat ke belakang/sudut board) dan mengabaikan port kedua atau USB hub.
2. **Pastikan isi flashdisk valid.** Setelah diflash memakai Raspberry Pi Imager / balenaEtcher, partisi FAT32 `ARMBIANBOOT` harus berisi `Image`, `uInitrd`, `u-boot.ext`, `aml_autoscript`, `s905_autoscript`, `dtb/`, dan `extlinux/`.
3. **Colokkan flashdisk langsung ke STB** (hindari USB hub tanpa daya tambahan).

---

## Metode 1 — STB Pernah Dipakai Armbian / Sudah Unlock USB Boot

Jika STB Anda sebelumnya pernah bisa boot Armbian, CoreELEC, atau OS USB lainnya:
1. Matikan STB, colok flashdisk ArmbianDesk ke **Port USB 0**.
2. Nyalakan STB seperti biasa — U-Boot di eMMC sudah punya perintah pencarian USB otomatis.

Jika masih masuk ke Android bawaan, lanjut ke **Metode 2**.

---

## Metode 2 — Tombol Reset ("Toothpick") atau `adb reboot update`

Pada banyak STB B860H / Amlogic bawaan pabrik, U-Boot baru mengecek `aml_autoscript` di flashdisk USB ketika masuk **mode update/recovery**:

### Cara 2A: Tombol Reset / Lubang AV (Tanpa PC)
1. Cabut adaptor listrik STB.
2. Colok flashdisk ArmbianDesk ke **Port USB 0**.
3. Masukkan tusuk gigi / peniti SIM ke lubang kecil **RESET / AV** sampai terasa tombol di dalam tertekan, lalu **tahan**.
4. Sambil menahan tombol, colokkan adaptor listrik STB selama **5–10 detik**, lalu lepaskan tombol.

### Cara 2B: Lewat ADB dari Android
1. Nyalakan Android bawaan STB, aktifkan **USB Debugging (ADB)** di *Settings → Developer options*.
2. Hubungkan PC ke IP STB (`adb connect <IP_STB>:5555`) atau lewat kabel USB-A ke USB-A (`adb devices`).
3. Colok flashdisk ArmbianDesk ke **Port USB 0**, lalu jalankan:
   ```bash
   adb reboot update
   ```

> **Catatan Penting ArmbianDesk `v0.1.0`:** Demi keamanan, [`aml_autoscript.cmd`](../share/boot/aml_autoscript.cmd) bawaan ArmbianDesk **sengaja tidak mengubah memori eMMC (`saveenv`) secara otomatis**. Jika Cara 2 hanya memicu satu kali atau STB Android bawaan langsung masuk Android saat boot normal, lanjut ke **Metode 3**.

---

## Metode 3 — Aktifkan USB-First Boot Permanen di B860H Terkunci (ADB + Root)

> **PERINGATAN RISIKO:**
> Langkah ini mengubah partisi konfigurasi U-Boot (`/dev/block/env`, ukuran 64 KiB). Revisi hardware yang sama-sama bernama "ZTE B860H" (`v1`, `v2`, `v2.1`, `v5`) bisa memiliki layout yang berbeda. **Wajib simpan backup asli `b860h-env-backup.bin` di PC dan verifikasi baca-ulang (`cmp`) sebelum reboot.**

Jika Metode 1 dan 2 tetap masuk ke Android bawaan, artinya variabel `switch_bootmode` di `/dev/block/env` melewati pemeriksaan USB saat `normal` / `cold_boot`. Gunakan helper resmi ArmbianDesk untuk mengaktifkannya dengan aman:

### 1. Backup partisi U-Boot env 64 KiB asli dari STB ke PC
```bash
adb connect <IP_STB>:5555
adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-backup.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-backup.bin"'
adb pull /data/local/tmp/b860h-env-backup.bin ./b860h-env-backup.bin
```
Simpan file `b860h-env-backup.bin` di folder aman untuk cadangan rollback.

### 2. Cek & patch file backup secara lokal (`dry-run` dulu)
Bisa dijalankan di Linux, macOS, atau Windows (butuh Python 3):
```bash
# Dry-run: mengecek CRC32 dan menampilkan perubahan Old -> New tanpa menulis file
python3 tools/b860h-usb-prep/b860h-usb-first-boot.py \
  --input ./b860h-env-backup.bin \
  --output ./b860h-env-patched.bin
```
Jika muncul error `CRC mismatch` atau `switch_bootmode missing`, **hentikan** — berarti STB Anda memakai layout env U-Boot yang berbeda.

Jika hasil preview valid, tulis file patch-nya:
```bash
python3 tools/b860h-usb-prep/b860h-usb-first-boot.py \
  --input ./b860h-env-backup.bin \
  --output ./b860h-env-patched.bin \
  --write
```

### 3. Tulis ke STB lalu wajib verifikasi byte per byte (`cmp`) sebelum reboot
```bash
adb push ./b860h-env-patched.bin /data/local/tmp/b860h-env-patched.bin
adb shell 'su -c "dd if=/data/local/tmp/b860h-env-patched.bin of=/dev/block/env bs=65536 count=1; sync"'
adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-readback.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-readback.bin"'
adb pull /data/local/tmp/b860h-env-readback.bin ./b860h-env-readback.bin
cmp ./b860h-env-patched.bin ./b860h-env-readback.bin && echo "VERIFY OK — aman reboot"
```
**Jangan reboot jika `cmp` gagal.** Kembalikan `b860h-env-backup.bin` jika hasil readback tidak identik.

### 4. Reboot dengan flashdisk ArmbianDesk terpasang di Port USB 0
```bash
adb reboot
```
Setelah itu:
- **Flashdisk terpasang:** U-Boot menjalankan `usb start 0` → `recovery_from_udisk` → otomatis masuk ke **ArmbianDesk**.
- **Flashdisk dicabut:** STB otomatis kembali boot ke **Android bawaan** di eMMC.
- **Ingin mengembalikan persis ke awal:** Tulis balik `./b860h-env-backup.bin` ke `/dev/block/env` dengan cara `dd` + `cmp` yang sama.
