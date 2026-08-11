# SalaryTicker

<!-- language-bar -->
[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · **Bahasa Melayu**
<!-- language-bar -->

Aplikasi bar menu macOS yang menunjukkan berapa banyak yang anda sudah peroleh hari ini, berdetik setiap saat.

<img src="docs/panel.png" width="360" alt="Panel: pendapatan hari ini, kadar di sebaliknya, jumlah bulan ini, dan dua sasaran simpanan berserta tarikh ia akan siap dibayar.">

Ia berada di bar menu sebagai satu nombor dan satu gelang kemajuan kecil. Klik untuk melihat
butiran hari ini, jumlah bulan setakat ini, dan sejauh mana anda hampir mencapai apa sahaja yang sedang anda kumpul duit untuknya.

- **Berdetik setiap saat** mengikut jadual sebenar anda — waktu kerja, rehat makan tanpa gaji, hari kerja.
- **Faham tentang cuti.** Hari kelepasan am, cuti bergaji dan cuti tanpa gaji jatuh di tempat
  yang berlainan, dan cuti tanpa gaji hanya menyentuh gaji pokok anda, bukan elaun.
- **Meletakkan harga dalam bentuk kerja.** Satu sasaran ditunjukkan dalam hari kerja dan dalam tarikh yang jadual anda kata ia akan siap dibayar, bukan sekadar dalam wang.
- **Sembilan bahasa**, apa-apa simbol mata wang, apa-apa zon waktu IANA.
- **Tiada akaun, tiada rangkaian, tiada telemetri.** Semuanya dikira pada Mac anda daripada tetapan yang anda taip sendiri.

## Pemasangan

Memerlukan **macOS 14 atau lebih baharu** dan rantaian alat Swift 6. Dibina dan diuji dengan Swift
6.3; keluaran Swift 6 yang lebih awal belum diuji.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
./Packaging/build_app.sh install
```

Arahan itu membina binari keluaran, menjana ikon aplikasi daripada sumber, menghimpunkan
`SalaryTicker.app`, menandatanganinya secara ad-hoc, menyalinnya ke `/Applications` dan melancarkannya. Buang
hujah `install` untuk membina ke dalam direktori kerja tanpa memasangnya.

Tiada apa-apa yang perlu dinyahkuarantin: anda sendiri yang mengkompil binari itu, jadi ia tidak pernah membawa bendera muat turun yang dicari Gatekeeper. Tandatangannya ad-hoc, dan itu memadai untuk aplikasi yang dibina secara setempat serta memberi item log masuk satu identiti yang tetap.

Untuk mengemas kini, tarik (pull) dan jalankan arahan yang sama — ia menggantikan salinan yang dipasang dan melancarkannya semula.
Tetapan anda berada di luar bundel dan tidak disentuh.

Untuk menyahpasang: tekan Keluar dalam panel, padam `/Applications/SalaryTicker.app`, dan jika anda mahu tetapan turut hilang, `defaults delete com.steve.salaryticker`.

## Kali pertama dijalankan

Bar menu memaparkan `Tetapkan gaji` sehingga jadual anda masuk akal. Buka **Tetapan** dari panel dan isi tiga perkara:

1. **Tab Gaji** — gaji pokok anda, dan apa-apa elaun tetap di sebelahnya.
2. **Tab Waktu kerja** — waktu Masuk, waktu Balik, dan rehat makan tanpa gaji.
3. **Tab Gaji, Hari kerja** — hari mana dalam seminggu anda bekerja, dan antaranya yang mana setengah hari.

<img src="docs/settings.png" width="420" alt="Tab Gaji: gaji pokok, elaun, bilangan hari kerja bulan itu, kadar sejam yang terhasil, dan grid bulan untuk menanda cuti.">

Itu sudah cukup untuk bermula. Selebihnya tidak wajib.

## Menyediakannya

### Gaji pokok dan elaun

Dua medan, kerana slip gaji ada sekurang-kurangnya dua baris dan cuti melayan keduanya secara berbeza:

- **Gaji pokok** ialah bahagian yang cuti tanpa gaji ditolak daripadanya.
- **Elaun** ialah jumlah bulanan yang tetap — pengangkutan, telefon — dibayar penuh sama ada anda
  mengambil cuti tanpa gaji atau tidak.

Jika anda tiada elaun, biarkan ia sifar dan tiada apa-apa yang berubah. Jika ada, memisahkan
keduanya dengan betul itulah yang menghalang sehari cuti tanpa gaji daripada merugikan anda lebih daripada yang sebenarnya.

### Hari kerja, hari kelepasan dan cuti

Pilih hari kerja anda dalam seminggu, dan tandakan mana-mana antaranya sebagai **setengah hari** (pagi Sabtu, contohnya) — ia
dikira setengah di mana-mana.

Klik satu tarikh dalam grid bulan untuk mengitarnya: **hari kerja → cuti bergaji → cuti tanpa gaji →
hari kerja**. Anak panah di kiri kanan tajuk menyelak antara bulan, dan tajuk itu sendiri ialah
jalan kembali ke hari ini, jadi hari kelepasan am tahun depan boleh dimasukkan sebelum ia tiba.

Dua jenis cuti ini jatuh di tempat yang berlainan, dan perbezaan itulah intinya:

|                    | Apa yang dilakukannya                                                                                                                                                                              |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cuti **bergaji**   | Tidak merugikan anda. Gaji yang sama kini merangkumi lebih sedikit hari kerja, jadi setiap hari anda *memang* bekerja bernilai sedikit lebih tinggi. Tiada apa-apa berdetik pada hari cuti itu sendiri — bahagiannya menumpang pada hari-hari lain. |
| Cuti **tanpa gaji** | Merugikan anda sehari **gaji pokok**. Elaun anda tetap dibayar penuh.                                                                                                                              |

Satu akibat yang patut diketahui: menandakan hari yang **sudah berlalu** sebagai cuti bergaji akan menyebabkan jumlah Bulan ini turun, kerana bahagian hari itu kini perlu diperoleh pada hari-hari yang masih di hadapan. Menjelang hujung bulan, ia kembali kepada gaji anda.

### Kerja lebih masa

Dimatikan secara lalai. Apabila dihidupkan, ia terus mengira selepas waktu Balik pada pengganda kadar yang anda tetapkan.

Ia ada **had** — empat jam secara lalai, dan tidak pernah melepasi tengah malam — kerana aplikasi ini langsung tidak tahu bila anda sebenarnya balik. Tanpa siling, Mac yang dibiarkan hidup semalaman akan mereka-reka gaji satu petang penuh.

### Sasaran

Tambah perkara yang anda sedang kumpul duit untuknya. Setiap satu menunjukkan kosnya dalam **hari kerja** dan tarikh yang jadual anda kata ia akan siap dibayar. Tunjuk yang anda mahu dalam panel; selebihnya kekal dalam Tetapan.

Tarikh itu **tidak bergerak selagi anda bekerja.** Pendapatan anda dan pergerakan jam maju
seiring, jadi mengikut jadual anda mengotakan janji itu, bukan mengalihkannya. Satu-satunya perkara yang menggesernya ialah mengubah jadual di bawahnya — menanda cuti, membuang satu hari kerja, memendekkan waktu kerja.

### Bar menu

| Pilihan                          | Apa yang dilakukannya                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| Gelang kemajuan                  | Gelang kecil di sebelah nombor, terisi sepanjang hari                                      |
| Simbol mata wang                 | Tunjuk atau sembunyikannya, untuk menebus semula ruang selebar satu aksara                 |
| Ikon sahaja di luar waktu kerja  | Mengecilkan item itu apabila nombornya tidak bergerak — waktu petang, hujung minggu, sebelum waktu Masuk |
| **Sembunyikan jumlah**           | Mengeluarkan wang itu daripada bar menu sehingga anda memintanya kembali, apa pun kata jam |

**Sembunyikan jumlah** juga merupakan item pertama dalam panel, satu klik dari bar menu, untuk saat
panggilan hendak bermula atau ada orang membaca dari belakang bahu anda. Ia tidak pernah menyembunyikan *segala-galanya* —
gelang itu kekal, kalau tidak tiada apa-apa lagi yang boleh diklik untuk membawa nombor itu kembali.

### Lancar semasa log masuk

Memerlukan aplikasi berjalan dari `/Applications`. Apa yang anda minta, itulah yang disimpan: aplikasi mendaftarkan dirinya semasa dilancarkan apabila suisnya dihidupkan, dan tidak pernah membatalkan pendaftaran itu, kerana macOS menyenaraikan aplikasi bar menu sebagai item log masuk semata-mata kerana ia pernah dijalankan sekali, dan jawapannya tidak boleh dipercayai dalam kedua-dua keadaan.

## Bagaimana nombor itu dikira

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Kedua-dua pembahagi dikira terhadap **bulan kalendar sebenar**, jadi sebulan kerja penuh berjumlah tepat sama dengan gaji anda dan kadar hariannya beralih sedikit dari bulan ke bulan — Ogos 2026 ada 21 hari kerja, September ada 22, Februari 2027 ada 20.

Jam berbayar sehari terhasil daripada waktu Masuk, waktu Balik dan rehat makan. Tiada medan "jam sehari" yang berasingan, jadi kedua-duanya tidak mungkin bercanggah antara satu sama lain.

### Ia tidak boleh terpesong

Setiap kali disegar semula, ia mengira semula daripada `(settings, now)` dan **tidak mengumpul apa-apa**. Menutup skrin, tidur, keluar dan lancar semula, menukar jam sistem, terbang merentas zon
waktu — tiada satu pun daripadanya boleh menyebabkan nombor itu salah, kerana tiada jumlah terkumpul yang boleh menjadi salah.

Pemasa itu cuma berkata "masa untuk lukis semula". Ia tidak mengira, dan kadarnya perlahan menjadi tidur seketika 20 saat
setiap kali nombor itu beku, iaitu kebanyakan waktu petang dan setiap hujung minggu.

### Tiada butang jeda, dan itu disengajakan

Kiraan itu tepu di kedua-dua hujung tempoh berbayar: satu detik sebelum hari kerja bernilai sifar, satu detik selepasnya bernilai sehari penuh. Jadi nombor itu **berhenti dengan sendirinya selepas waktu Balik dan set semula dengan sendirinya pada tengah malam** — tiada pemasa untuk dihentikan, tiada keadaan untuk diset semula.

Jeda manual pernah wujud sekejap. Ia satu-satunya keadaan terkumpul dalam aplikasi ini dan
punca kedua-dua pepijat terburuknya: jeda yang dibiarkan berjalan semalaman mengenakan lebih daripada sehari kerja penuh dan menyifarkan hari berikutnya, manakala jeda yang dimulakan selepas waktu Balik menyebabkan jumlah harian yang sudah selesai berdetik *ke belakang*. Membuang ciri itu membuang seluruh kelas pepijat tersebut.

## Had yang diketahui

- **Tiada syif merentas malam.** Waktu Balik mesti lewat daripada waktu Masuk; jika tidak, aplikasi berkata
  "Tetapan tidak lengkap" dan bukannya menunjukkan nombor yang salah.
- **Tiada bonus.** Hanya elaun bulanan yang tetap dimodelkan. Bayaran sekali-sekala atau bayaran
  hujung tahun terpaksa diagihkan menjadi angka sesaat untuk muncul di sini, dan itu mencantikkan nombor itu, bukan menggambarkannya.
- **Tiada cukai, KWSP (EPF) atau PERKESO (SOCSO).** Setiap angka ialah angka kasar.
- **Tiada sejarah.** Jumlah Bulan ini diperoleh daripada jadual bulan ini, bukan daripada rekod apa yang sebenarnya dikerjakan. Mengubah gaji atau waktu kerja anda akan mengira semula harga hari-hari yang sudah berlalu dalam bulan semasa.
- **Satu jadual sahaja.** Corak yang bukan mingguan — Sabtu berselang-seli, syif berpusing — tidak boleh dinyatakan kecuali dengan menanda pengecualiannya secara manual.

## Pembangunan

```bash
swift build          # build
swift test           # 210 tests
./Packaging/build_app.sh    # assemble the .app without installing
```

Clean Architecture yang mengutamakan ciri, satu target SwiftPM bagi setiap lapisan, jadi arah kebergantungan dikuatkuasakan oleh pengkompil dan bukan oleh disiplin. Keputusan reka bentuk, invarian model wang, dan pepijat yang membentuknya dihuraikan dalam
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Lesen

MIT — lihat [LICENSE](LICENSE).
