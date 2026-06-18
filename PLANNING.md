# Planning Perubahan Anime WebView -> WebSpace

Dokumen ini berisi rencana perubahan untuk:
1. Mengganti semua nama aplikasi dari `Anime WebView` menjadi `WebSpace`.
2. Mengubah alur aplikasi dari single webview menjadi pemilihan website terlebih dahulu lewat popup/selection dialog.
3. Mengubah format data remote JSON dari 1 object menjadi list of websites.

---

## 1) Tujuan Perubahan

- Branding aplikasi berubah menjadi **WebSpace**.
- Aplikasi tidak lagi langsung membuka satu URL.
- Saat aplikasi dibuka, user melihat popup berisi daftar website yang tersedia.
- User memilih salah satu website lalu menekan tombol untuk masuk ke WebView.

---

## 2) Format Data Baru

### Format lama

```json
{
  "webview_url": "https://tv11.lk21official.cc",
  "version": "1.0"
}
```

### Format baru

```json
[
  {
    "webview_url": "https://tv11.lk21official.cc",
    "website_name": "LK21",
    "version": "1.0"
  }
]
```

### Catatan

- `website_name` akan dipakai sebagai label di selection popup.
- `webview_url` tetap dipakai untuk membuka WebView.
- `version` tetap bisa dipertahankan untuk kebutuhan kompatibilitas atau update log.

---

## 3) Rencana Implementasi

### Tahap A - Rename Branding

- Ganti semua teks `Anime WebView` menjadi `WebSpace`.
- Update title aplikasi di UI Flutter.
- Update label aplikasi native:
  - Android manifest
  - iOS `Info.plist`
  - teks di README dan dokumentasi lain
- Cek juga nama class, nama file, dan string lain yang masih memakai kata `Anime`.

### Tahap B - Update Model Data

- Ubah model dari single object menjadi list item website.
- Tambahkan field baru:
  - `websiteName`
  - `webviewUrl`
  - `version`
- Buat model utama untuk 1 item website, misalnya `WebsiteConfig`.
- Ubah parser JSON agar membaca `List<dynamic>` bukan `Map<String, dynamic>`.

### Tahap C - Update Service Loader

- Ubah service pengambil data remote agar mengembalikan daftar website.
- Validasi setiap item:
  - `webview_url` harus valid URL
  - `website_name` tidak boleh kosong
- Jika ada item yang tidak valid:
  - bisa di-skip, atau
  - gagal total dengan pesan error
- Tentukan behavior yang paling aman sebelum coding, agar UI tidak crash saat data rusak.

### Tahap D - Buat Popup Selection

- Saat aplikasi pertama kali dibuka, tampilkan popup atau dialog selection.
- Popup berisi:
  - list nama website
  - tombol aksi utama, misalnya `Open` / `Masuk`
  - tombol batal jika diperlukan
- User memilih satu website dari list.
- Setelah tombol ditekan:
  - WebView dibuka ke URL yang dipilih.

### Tahap E - Perbarui Flow App

- Startup flow baru:
  1. App dibuka
  2. Data website diambil dari remote JSON
  3. Popup selection ditampilkan
  4. User memilih website
  5. WebView load URL terpilih

- Jika request gagal:
  - tampilkan error state yang jelas
  - sediakan retry

### Tahap F - Penyesuaian UX

- Tentukan apakah pilihan terakhir perlu diingat.
- Tentukan default selection jika user belum memilih.
- Pastikan dialog mudah dipakai di Android phone dan Android TV.
- Jika app target TV, pastikan navigasi remote bisa memilih item dan menekan tombol aksi dengan nyaman.

---

## 4) File yang Kemungkinan Terdampak

- `lib/constants/app_constants.dart`
- `lib/models/webview_config.dart`
- `lib/services/url_loader_service.dart`
- `lib/screens/webview_screen.dart`
- `lib/app.dart`
- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle`
- `ios/Runner/Info.plist`
- `README.md`
- file dokumentasi lain yang masih menyebut `Anime WebView`

---

## 5) Urutan Kerja yang Disarankan

1. Rename branding ke `WebSpace`.
2. Update model dan parser JSON ke format list.
3. Ubah service loader supaya membaca banyak website.
4. Tambahkan popup selection sebelum WebView dibuka.
5. Rapikan error handling untuk data kosong atau JSON tidak valid.
6. Update dokumentasi dan teks bantuan.
7. Lakukan testing di device atau emulator.

---

## 6) Acceptance Criteria

Perubahan dianggap selesai jika:

- Tidak ada lagi nama aplikasi `Anime WebView` yang tersisa di UI utama.
- App tampil sebagai `WebSpace`.
- JSON remote berbentuk list dan bisa diparse dengan benar.
- Popup selection muncul saat app dibuka.
- User bisa memilih website dari daftar dan masuk ke WebView.
- Error handling tetap berjalan jika data remote gagal dimuat.

---

## 7) Testing Checklist

- Cek app title di Android.
- Cek app title di iOS.
- Cek parser JSON dengan data list.
- Cek popup selection muncul saat startup.
- Cek WebView membuka URL yang dipilih.
- Cek kondisi:
  - list kosong
  - URL tidak valid
  - jaringan putus
  - response JSON rusak

---

## 8) Catatan Tambahan

- Jika ingin konsisten penuh, nama class dan file yang masih mengandung `AnimeWebView` bisa diubah bertahap.
- Jika perubahan ini akan dipakai jangka panjang, pertimbangkan versi schema JSON supaya perubahan format di masa depan lebih mudah dikelola.
