/// (P139.3) ANA EKRAN IZGARASI — varsayilan kume + KULLANICI TERCIHI.
///
/// IKI KARAR BURADA, TEK KAYNAKTA:
///   1. Hangi karolar VARSAYILAN olarak gorunur (Kerem'in listesi),
///   2. Kullanicinin kendi sectigi kume neyle SINIRLI.
///
/// GORUNURLUK UYDURULMAZ: secilebilir kume `homeMenuForRole`den gelir —
/// yani kullanici KENDI rolunun zaten gorebildigi disinda hicbir karoyu
/// ana ekrana koyamaz. Bu, "izin hatasina goturen karo olmasin" sartinin
/// yapisal karsiligidir: kural UI'da degil izin katmaninda durur, burasi
/// yalnizca ONU okur.
///
/// TERCIH BOZULURSA URUN BOZULMAZ: kayitli kume her okumada rolun izinli
/// kumesiyle KESISTIRILIR. Rol degisirse, bir ekran kaldirilirsa ya da
/// depolama bozulursa gecersiz girisler DUSER; kume tamamen bosalirsa
/// varsayilana donulur. Kullanici hicbir kosulda bos bir ana ekranla
/// karsilasmaz.
library;

import '../../auth/domain/user_role.dart';
import 'home_menu.dart';

/// Izgarada ayni anda gosterilecek EN COK karo.
///
/// Neden sinir: ana ekran "sik kullanilan, hizli erisim" icindir. Sinirsiz
/// birakmak onu ikinci bir menuye cevirir ve karolarin hizli-erisim anlami
/// kaybolur — kuyrugu zaten "Tum Moduller" tasiyor.
const int izgaraEnCokKaro = 6;

/// VARSAYILAN IZGARA (Kerem'in listesi).
///
/// Istenen liste yedi kalemdi: Duyurular · Sikayetler · Otopark ·
/// Gorev takibi · Vardiya · Oneriler · Rezervasyon. "Sikayetler" ve
/// "Oneriler" AYNI ekrandir (`HomeMenuEntry.complaints` — auth.md §4'te
/// tek kanal: "Sikayet/Oneri"), bu yuzden tek karo kaldi ve liste alti
/// kaleme indi. (`sikayetHaritasi` FARKLI bir ekrandir — bina semasi —
/// ve varsayilana girmez.)
const List<HomeMenuEntry> _varsayilanIzgara = [
  HomeMenuEntry.announcements,
  HomeMenuEntry.complaints,
  HomeMenuEntry.otopark,
  HomeMenuEntry.taskTracking,
  HomeMenuEntry.vardiyalar,
  HomeMenuEntry.rezervasyon,
];

/// Saha rollerinin gorev karosu YONETIM gorunumu DEGILDIR.
///
/// `taskTracking` gorev olusturma/atamadir ve YALNIZ yoneticidedir (A4
/// matrisi); saha personeli "Gorevlerim"i kullanir. Varsayilani ayni
/// birakmak, saha kullanicisina izin hatasi ureten bir karo gostermek
/// olurdu — tam da onlenmesi istenen sey.
const Map<HomeMenuEntry, HomeMenuEntry> _rolKarsiliklari = {
  HomeMenuEntry.taskTracking: HomeMenuEntry.tasks,
};

/// Rolun ana ekranda SECEBILECEGI karolar — izin katmanindan turer.
List<HomeMenuEntry> izgaraSecenekleri(UserRole rol) => homeMenuForRole(rol);

/// Rolun VARSAYILAN izgarasi: istenen kume, izinle kesistirilmis.
///
/// Bir kalem o rolde yoksa once ROL KARSILIGI denenir (bkz.
/// [_rolKarsiliklari]); o da yoksa kalem duser. Sonuc bosalirsa rolun
/// izinli kumesinin ilk [izgaraEnCokKaro] kalemi kullanilir — bos ana
/// ekran hicbir rolde olusmaz.
List<HomeMenuEntry> varsayilanIzgara(UserRole rol) {
  final izinli = izgaraSecenekleri(rol).toSet();
  final sonuc = <HomeMenuEntry>[];
  for (final k in _varsayilanIzgara) {
    if (izinli.contains(k)) {
      sonuc.add(k);
      continue;
    }
    final karsilik = _rolKarsiliklari[k];
    if (karsilik != null && izinli.contains(karsilik)) sonuc.add(karsilik);
  }
  if (sonuc.isEmpty) {
    return izgaraSecenekleri(rol).take(izgaraEnCokKaro).toList();
  }
  return sonuc.take(izgaraEnCokKaro).toList();
}

/// Kayitli tercihi rolle KESISTIREREK cizilecek kumeyi verir.
///
/// [kayitli] `null` ise (kullanici hic secim yapmamis) varsayilan doner.
/// Gecersiz/izinsiz girisler DUSER; kume bosalirsa varsayilana donulur.
List<HomeMenuEntry> izgarayiCoz(UserRole rol, List<HomeMenuEntry>? kayitli) {
  if (kayitli == null) return varsayilanIzgara(rol);
  final izinli = izgaraSecenekleri(rol).toSet();
  final gorunur = <HomeMenuEntry>[];
  for (final k in kayitli) {
    // Yinelenen secim tek karo olur: ayni hedefe iki karo, duzeltilmek
    // istenen sikayetin ta kendisiydi.
    if (izinli.contains(k) && !gorunur.contains(k)) gorunur.add(k);
  }
  if (gorunur.isEmpty) return varsayilanIzgara(rol);
  return gorunur.take(izgaraEnCokKaro).toList();
}

/// Depolama bicimi: enum ADLARI (indeks DEGIL).
///
/// Indeks yazmak, enum'a ortadan bir giris eklendiginde kayitli tercihleri
/// SESSIZCE baska ekranlara kaydirirdi.
List<String> izgarayiYaz(List<HomeMenuEntry> kume) =>
    kume.map((e) => e.name).toList();

/// Depolamadan okur; taninmayan ad DUSER (uygulama surumu geriye gitmis
/// ya da ekran kaldirilmis olabilir).
List<HomeMenuEntry> izgarayiOku(List<String> adlar) {
  final harita = {for (final e in HomeMenuEntry.values) e.name: e};
  return [
    for (final a in adlar)
      if (harita[a] != null) harita[a]!,
  ];
}
