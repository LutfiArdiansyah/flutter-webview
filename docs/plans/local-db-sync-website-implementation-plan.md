# Rencana Implementasi: Database Lokal & Sinkronisasi Website (Local Database & Website Sync)

## Background / Context
Aplikasi WebSpace saat ini mengambil daftar website langsung dari URL remote (`AppConstants.jsonUrl`) menggunakan `UrlLoaderService` setiap kali aplikasi diluncurkan. Jika perangkat tidak memiliki akses internet saat startup, aplikasi akan langsung menampilkan layar error dan tidak dapat masuk ke menu pemilihan website. 

Untuk meningkatkan keandalan (*reliability*), kecepatan *load* (*perceived performance*), dan fleksibilitas aplikasi, diperlukan penyimpanan data lokal (*local database*). Saat aplikasi dibuka pertama kali, aplikasi akan mengunduh daftar website dari URL dan menyimpannya di database lokal. Pada pembukaan berikutnya, aplikasi cukup memuat data dari database lokal secara instan. Selain itu, pengguna diberikan kemampuan untuk menambahkan, mengubah, dan menghapus website kustom mereka secara lokal tanpa memengaruhi atau mengubah daftar website default yang disinkronkan secara online.

---

## Objective
1. Mengintegrasikan pustaka database lokal (SQLite) ke dalam proyek.
2. Memperluas model data `WebsiteConfig` untuk membedakan website bawaan (*default*) dengan website kustom (*custom*).
3. Mengubah alur inisialisasi aplikasi agar memprioritaskan pemuatan dari database lokal.
4. Membuat antarmuka pengguna (UI/UX) pada popup pemilihan website untuk mendukung:
   - Penambahan website kustom (*Add*).
   - Pengubahan website kustom (*Edit*).
   - Penghapusan website kustom (*Delete*).
   - Sinkronisasi manual daftar website default dari remote URL (*Sync Online*).
5. Merestrukturisasi tata letak tombol dialog pemilihan website agar tetap rapi, modern, dan ramah navigasi TV/D-Pad.

---

## Scope
- Penambahan dependensi database `sqflite` dan `path` di [pubspec.yaml](file:///c:/Users/lutfi/Downloads/anime_webview_app/pubspec.yaml).
- Implementasi `DatabaseService` sebagai layer data lokal (CRUD & Sync).
- Pembaruan model [webview_config.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/models/webview_config.dart) agar kompatibel dengan SQLite.
- Modifikasi logika startup di [webview_screen.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/screens/webview_screen.dart):
  - Muat dari lokal. Jika kosong, otomatis lakukan sinkronisasi pertama kali.
- Modifikasi UI dialog pilihan website di [webview_screen.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/screens/webview_screen.dart):
  - Header dialog: Menyertakan tombol *Sync Online* dan *Tambah Website*.
  - List item website: Menampilkan tombol *Edit* & *Delete* hanya jika item tersebut adalah kustom (`isCustom == true`).
  - Membuat modal dialog formulir untuk tambah/edit website kustom lengkap dengan validasi URL dan penanganan fokus D-Pad TV.

---

## Out of Scope
- Sinkronisasi atau pencadangan website kustom pengguna ke server online/cloud (seluruh operasi modifikasi user bersifat murni lokal di penyimpanan perangkat).
- Mengubah skema logging error yang sudah ada (tetap menggunakan `ErrorLoggerService`).

---

## Current Implementation Analysis
- **Pemuatan Data**: `WebViewScreenState._loadWebsites()` langsung memanggil `_urlLoaderService.fetchWebsites()` secara asinkron.
- **Model Data**: `WebsiteConfig` saat ini hanya menampung fields `websiteName`, `webviewUrl`, dan `version`. Tidak ada identitas unik (`id`) atau flag `isCustom` untuk melacak asal data.
- **Popup UI**: Menampilkan daftar website bawaan dalam bentuk list dialog sederhana. Penempatan tombol aksi saat ini berada di footer bar bawah dialog (Batal, Masuk, Keluar). Jika ditambahkan tombol Sync dan Tambah di area footer, UI akan menjadi terlalu padat dan tidak seimbang.

---

## Proposed Solution

### 1. Database SQLite
Gunakan `sqflite` untuk menyimpan daftar website. Kita akan membuat tabel bernama `websites` dengan skema sebagai berikut:
```sql
CREATE TABLE websites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  website_name TEXT NOT NULL,
  webview_url TEXT NOT NULL,
  version TEXT,
  is_custom INTEGER NOT NULL DEFAULT 0
);
```

### 2. Penyesuaian Model Data
Tambahkan properti `id` (Nullable integer) dan `isCustom` (Boolean) pada kelas `WebsiteConfig`.
- Jika data berasal dari remote URL, default `isCustom` bernilai `false` (diwakili integer `0` di SQLite).
- Jika ditambahkan manual oleh user, `isCustom` bernilai `true` (diwakili integer `1` di SQLite).

### 3. Pembaruan Inisialisasi & Logika Sync Online
- **Startup**: Cek data di DB lokal. Jika ada data, langsung gunakan. Jika kosong, panggil fungsi Sync Online otomatis.
- **Manual Sync**: Ketika tombol *Sync Online* ditekan:
  1. Ambil data terbaru dari URL.
  2. Buka SQLite Transaction.
  3. Hapus semua data di tabel `websites` yang memiliki flag `is_custom = 0`.
  4. Sisipkan semua item website hasil unduhan dengan flag `is_custom = 0`.
  5. Commit Transaction.
  6. Muat ulang daftar website dari database lokal ke UI state.
  *(Dengan cara ini, website kustom pengguna dengan `is_custom = 1` akan aman dan tidak terhapus selama sinkronisasi).*

### 4. Perbaikan UI/UX Popup Dialog Pemilihan Website
- **Restrukturisasi Tombol Aksi**:
  - Untuk menjaga kebersihan footer dialog, pindahkan aksi operasional seperti **Sync Online** (`Icons.sync`) dan **Tambah Website** (`Icons.add`) ke area **Header Dialog** (di sebelah kanan judul "Pilih Website").
  - Gunakan `IconButton` yang mendukung visual hover, focus, dan splash effect agar konsisten dengan tema premium gelap WebSpace.
- **Aksi Pada List Item**:
  - Jika item adalah website kustom, tampilkan tombol kecil Edit (`Icons.edit_outlined`) dan Delete (`Icons.delete_outline`) di ujung kanan item tersebut.
  - Bungkus item interaktif dengan tata letak `Row` di mana list utama memakai `InkWell` (untuk memilih website) dan tombol aksi diletakkan di luarnya untuk mencegah *event bubbling* (tidak memicu pemilihan website secara tidak sengaja saat tombol edit/delete diklik).
- **Formulir Tambah / Edit Website**:
  - Gunakan dialog modal terpisah dengan gaya glassmorphic gelap, memiliki input field `Nama Website` dan `URL Website` yang tervalidasi menggunakan `FormState`.

---

## Affected Files / Modules

| File / Folder | Aksi | Deskripsi Perubahan |
| --- | --- | --- |
| [pubspec.yaml](file:///c:/Users/lutfi/Downloads/anime_webview_app/pubspec.yaml) | `MODIFY` | Menambahkan library `sqflite: ^2.3.0` dan `path: ^1.9.0`. |
| [lib/models/webview_config.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/models/webview_config.dart) | `MODIFY` | Menambahkan field `id` dan `isCustom`, serta helper method `fromMap` dan `toMap`. |
| [lib/services/database_service.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/services/database_service.dart) | `NEW` | Kelas singleton pengelola SQLite (Open DB, Create Table, Query CRUD, Transaction Sync). |
| [lib/screens/webview_screen.dart](file:///c:/Users/lutfi/Downloads/anime_webview_app/lib/screens/webview_screen.dart) | `MODIFY` | Integrasi UI baru, pembaruan inisialisasi state, dialog formulir tambah/edit, dan penanganan event klik/focus. |

---

## Data Model / Database Impact

### Skema Tabel `websites`
```sql
CREATE TABLE websites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  website_name TEXT NOT NULL,
  webview_url TEXT NOT NULL,
  version TEXT,
  is_custom INTEGER NOT NULL DEFAULT 0
);
```

### Pemetaan Objek Model
Model `WebsiteConfig` diperbarui dengan penambahan:
- `int? id`
- `bool isCustom`
- `factory WebsiteConfig.fromMap(Map<String, dynamic> map)`
- `Map<String, dynamic> toMap()`

---

## API / Contract Impact
Tidak ada perubahan pada struktur JSON API remote. Respons dari remote URL tetap dibaca seperti biasa oleh `UrlLoaderService` dan diparsing menjadi objek `WebsiteConfig` (dengan `isCustom = false` secara default).

---

## UI / UX Impact
1. **Header Dialog Pemilihan Website**:
   - Layout Header berubah dari `Row` biasa menjadi Row dengan `Spacer` lalu dua `IconButton` (Sync & Add).
   - Menghasilkan tampilan yang ringkas dan profesional.
2. **List Item Website**:
   - Untuk website kustom, item akan sedikit lebih lebar ke kanan atau menggeser teks sedikit guna memberi ruang bagi tombol Edit & Hapus.
   - Sesuai panduan `AGENTS.md`, jarak dan visual hierarchy tetap menggunakan kelipatan 8pt grid.
3. **Dialog Tambah/Edit Website**:
   - Dialog overlay gelap blur (`BackdropFilter`) dengan input field yang fokusnya responsif.

---

## Security Considerations
- **SQL Injection Prevention**: Menggunakan parameterized query yang aman bawaan `sqflite` (tidak merangkai string SQL secara manual).
- **URL Validation**: Menggunakan metode `_isValidUrl()` yang diperluas untuk memastikan pengguna tidak memasukkan URL dengan skema berbahaya (seperti `javascript:` atau file path lokal `file://`). Hanya mengizinkan `http://` dan `https://`.

---

## Performance Considerations
- Semua pembacaan dan penulisan database SQLite dijalankan secara asinkron (*non-blocking UI*).
- Bulk insert daftar website dari online menggunakan database transaction untuk mempercepat eksekusi (menghindari overhead commit berulang).
- SQLite Database instance dibuat singleton sehingga meminimalkan pembukaan koneksi file database berkali-kali.

---

## Step-by-step Implementation Plan

### Fase 1: Konfigurasi Dependensi & Pembaruan Model
1. Tambahkan dependensi `sqflite` dan `path` pada `pubspec.yaml` lalu jalankan perintah `flutter pub get`.
2. Edit file `lib/models/webview_config.dart`:
   - Tambahkan property `id` dan `isCustom`.
   - Update konstruktor default.
   - Update factory `fromJson` agar menetapkan `isCustom = false`.
   - Buat fungsi `fromMap` dan `toMap`.

### Fase 2: Implementasi Database Service
1. Buat file baru `lib/services/database_service.dart`.
2. Implementasikan kelas singleton `DatabaseService`.
3. Tulis logika inisialisasi database dan pembuatan tabel `websites`.
4. Tulis fungsi query CRUD dasar:
   - `Future<List<WebsiteConfig>> getWebsites()`
   - `Future<int> insertWebsite(WebsiteConfig config)`
   - `Future<int> updateWebsite(WebsiteConfig config)`
   - `Future<int> deleteWebsite(int id)`
5. Tulis fungsi sinkronisasi atomik `Future<void> syncDefaultWebsites(List<WebsiteConfig> remoteWebsites)` menggunakan transaksi SQLite.

### Fase 3: Integrasi Logika Startup & Alur Sinkronisasi
1. Edit file `lib/screens/webview_screen.dart`.
2. Ganti pemanggilan `UrlLoaderService` langsung di `_loadWebsites()` menjadi:
   - Panggil `DatabaseService.getWebsites()`.
   - Jika hasilnya kosong, panggil alur `_syncWebsites()` (fetch online, save ke DB lokal, lalu get kembali).
   - Jika hasilnya ada data, tetapkan ke variabel state `_websites`.

### Fase 4: Desain Ulang & Penyelarasan UI Dialog
1. Perbarui layout header dialog di `_showWebsiteSelectionDialog` untuk menyertakan tombol Sync Online dan Tambah Website.
2. Buat widget dialog formulir `_showAddEditWebsiteDialog(WebsiteConfig? existingWebsite)` untuk tambah/edit data kustom.
3. Modifikasi widget `_DialogWebsiteItem`:
   - Tambahkan parameter callback `onEdit` dan `onDelete`.
   - Modifikasi layout untuk menyisipkan tombol Edit & Delete jika item kustom.
   - Pastikan navigasi fokus TV (D-pad) dapat berpindah ke tombol aksi secara logis.
4. Tambahkan indikator loading overlay yang halus selama sinkronisasi sedang berjalan guna mencegah input ganda dari pengguna.

---

## Testing Plan

### Skenario Verifikasi Manual
1. **Fresh Install / Skenario Pertama Kali Buka**:
   - Hapus data aplikasi / install ulang.
   - Buka aplikasi dengan koneksi internet aktif.
   - Pastikan aplikasi otomatis melakukan fetch online dan menyimpan datanya ke DB lokal. Dialog pemilihan website harus muncul setelahnya.
2. **Kondisi Offline (Startup Kedua)**:
   - Matikan koneksi internet, lalu jalankan aplikasi.
   - Aplikasi harus langsung memuat daftar website dari DB lokal tanpa menampilkan layar error timeout atau kegagalan koneksi.
3. **Operasi Tambah Website Kustom**:
   - Klik tombol tambah (+), masukkan Nama dan URL yang valid. Simpan.
   - Pastikan item baru muncul di list dan memiliki flag kustom (tombol Edit & Hapus terlihat).
4. **Operasi Edit & Delete Website Kustom**:
   - Ubah nama website kustom, simpan, pastikan nama terupdate.
   - Hapus website kustom, pastikan hilang dari list dan database.
5. **Operasi Sync Online**:
   - Jalankan Sync Online secara manual menggunakan tombol sync.
   - Pastikan default website terupdate dengan data terbaru dari URL remote, tetapi website kustom buatan pengguna tetap aman tidak terhapus.
6. **Uji Navigasi TV (D-Pad)**:
   - Gunakan keyboard / emulator TV controller untuk menguji fokus tombol-tombol baru di header dan tombol edit/delete pada list item.

---

## Rollback Plan
Jika terdapat isu kritis (seperti inkonsistensi DB atau crash startup di device tertentu):
1. Kembalikan perubahan kode di `lib/screens/webview_screen.dart` dan `lib/models/webview_config.dart` ke repositori commit terakhir.
2. Hapus file `lib/services/database_service.dart`.
3. Jalankan `git checkout pubspec.yaml` untuk menghapus pustaka `sqflite` dan `path`.
4. Jalankan `flutter pub get`.

---

## Risk & Mitigation
- **Risiko**: Pengguna pertama kali membuka aplikasi tanpa koneksi internet sama sekali sehingga inisialisasi lokal DB kosong.
  - *Mitigasi*: Menangkap error kegagalan koneksi dengan anggun, menampilkan pesan informatif di layar error dengan tombol "Coba Lagi" yang akan memicu ulang sinkronisasi database lokal.
- **Risiko**: Masalah penulisan database konkuren jika pengguna menekan tombol sync berulang kali dengan cepat.
  - *Mitigasi*: Menonaktifkan tombol sync (disabled state) atau menampilkan loading indicator modal selama operasi database asinkron berjalan.

---

## Acceptance Criteria
- Aplikasi memuat daftar website secara offline setelah inisialisasi pertama berhasil.
- Pengguna hanya bisa mengedit dan menghapus website yang ditambahkan secara lokal (`isCustom = true`).
- Website bawaan dari URL remote tidak memiliki opsi edit/delete di UI.
- Klik tombol "Sync Online" memperbarui daftar website bawaan sesuai data URL terbaru tanpa merusak/menghapus website kustom buatan pengguna.
- Tombol Sync dan Tambah diletakkan di header popup dialog dengan rapi dan tidak mengganggu footer.
- Formulir tambah/edit mendeteksi jika URL yang dimasukkan tidak valid.

---

## Open Questions
- Apakah perlu membatasi jumlah maksimum website kustom yang dapat ditambahkan oleh pengguna untuk menghemat ruang memori? *(Asumsi: Tidak perlu karena data teks SQLite sangat kecil, namun kita bisa membatasi panjang teks nama website maksimal 50 karakter agar UI tidak pecah).*
- Apakah URL website kustom harus unik (mencegah duplikasi URL)? *(Asumsi: Diperbolehkan duplikasi URL jika pengguna ingin memberi nama yang berbeda, validasi difokuskan pada format URL).*
