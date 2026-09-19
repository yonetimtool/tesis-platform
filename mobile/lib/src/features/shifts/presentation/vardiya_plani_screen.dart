/// (P203 §4) VARDIYA PLANI — mobil.
///
/// ===========================================================================
/// MOBILDE NEDEN GEREKLI
/// ===========================================================================
/// Saha rolleri (`security`, `tesis_gorevlisi`) WEB'DE HICBIR SAYFA
/// GORMEZ — P129 karari, urunleri mobil uygulamadir. Yani "bu hafta ne
/// zaman calisiyorum" ve "siradaki vardiyada kim var" sorularini
/// yanitlayabilecekleri TEK yer burasi.
///
/// GUNLUK LISTE, HAFTALIK TABLO DEGIL: yedi gun x vardiya izgarasi bir
/// telefon ekranina sigmaz ve yatay kaydirma, en cok ihtiyac duyulan
/// bilgiyi (BUGUN) gorunmez yapardi. Gunler ALT ALTA, bugun en ustte.
///
/// ===========================================================================
/// (P205 §2) NEDEN MOBILDE ZAMAN CIZELGESI YOK
/// ===========================================================================
/// Web'e kisi x saat cizelgesi geldi; mobile AYNISI GETIRILMEDI ve bu
/// bir eksiklik degil, KARAR. 360 dp genisliginde bir ekranda 24 saatlik
/// eksen ancak 15 px/saat'e sigar: bloklarin ustundeki saat metni
/// okunmaz, dokunma hedefleri 44 dp'nin altina duser ve satiri gormek
/// icin surekli yatay kaydirmak gerekir. Sahadaki soru zaten "bugun kim
/// var, sirada kim var"dir — LISTE bunu tek bakista yanitlar.
///
/// EKRAN YINE DE CIZELGE UCUNU KULLANIR (`/vardiya-plani/cizelge`):
/// izgara ucu yalniz SABLONA bagli slotlari donuyor ve web'den serbest
/// saatle eklenen vardiyalar sahada GORUNMEZDI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/gun_takvimi.dart';
import 'izin_formu.dart';
import '../../../routing/app_router.dart';
import '../../../core/ui/merkez_diyalog.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../staff/data/staff_api.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';

/// Bu haftanin PAZARTESISI (TR takvimi).
DateTime _haftaBasi(DateTime t) =>
    DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1));

final vardiyaCizelgeProvider = FutureProvider<VardiyaCizelge>((ref) async {
  return ref.read(vardiyaPlaniApiProvider).cizelge(_haftaBasi(DateTime.now()));
});

/// Gun -> o gune ait bloklar (kisisiyle birlikte). Cizelge KISI bazli
/// gelir; sahada sorulan soru GUN bazlidir, o yuzden burada cevrilir.
Map<String, List<({VardiyaCizelgeKisi kisi, VardiyaBlok blok})>> _gunlereBol(
  VardiyaCizelge c,
) {
  final harita = <String, List<({VardiyaCizelgeKisi kisi, VardiyaBlok blok})>>{};
  for (final k in c.personel) {
    for (final b in k.bloklar) {
      harita.putIfAbsent(b.tarih, () => []).add((kisi: k, blok: b));
    }
  }
  for (final liste in harita.values) {
    liste.sort((a, b) => a.blok.baslar.compareTo(b.blok.baslar));
  }
  return harita;
}

/// (P205 §2.4) Vardiya atanabilecek kisiler.
///
/// `fieldStaffProvider` KULLANILMADI: o yalniz `security` +
/// `tesis_gorevlisi` doner. Vardiya guvenlik amirine de yazilabilir ve
/// listede olmayan bir kisiyi ekranda aramak, yoneticiyi web'e
/// gondermek olurdu.
final vardiyaPersonelProvider =
    FutureProvider.autoDispose<List<StaffMember>>((ref) async {
  final hepsi = await ref.watch(staffApiProvider).tumPersonel();
  return hepsi;
});

final vardiyaSimdiProvider = FutureProvider<VardiyaSimdi>((ref) async {
  return ref.read(vardiyaPlaniApiProvider).simdi();
});

/// (P241 §2) Yayin bekleyen satir sayisi — YALNIZ yonetim cagirir.
///
/// Saha rolu bu ucu cagirsaydi 403 alirdi; ekranda gorunmeyen bir
/// sayinin hatasini gostermek gurultu olurdu.
final vardiyaYayinOzetiProvider =
    FutureProvider.autoDispose<({int bekleyen, int taslak, int degisen})>(
  (ref) async {
    return ref
        .read(vardiyaPlaniApiProvider)
        .yayinOzeti(_haftaBasi(DateTime.now()));
  },
);

class VardiyaPlaniScreen extends ConsumerWidget {
  const VardiyaPlaniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cizelge = ref.watch(vardiyaCizelgeProvider);
    final simdi = ref.watch(vardiyaSimdiProvider);
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final yonetici = rol == UserRole.admin || rol == UserRole.yonetici;

    final yayin = yonetici ? ref.watch(vardiyaYayinOzetiProvider) : null;
    final bekleyen = yayin?.asData?.value.bekleyen ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vardiyaPlaniBaslik),
        actions: [
          if (yonetici)
            // (P237 §1 kurali) BASKA EKRANA GOTURMUYOR, YERINDE IS
            // YAPIYOR: metinli dugme sart degil, ama SAYI tasidigi icin
            // yine de METINLI — "Yayinla (3)" bir tooltip'in
            // anlatamayacagi bir bilgi.
            TextButton(
              key: const Key('vardiya-yayinla'),
              onPressed: bekleyen == 0
                  ? null
                  : () => _yayinla(context, ref),
              child: Text(l10n.vardiyaYayinlaSayili(bekleyen)),
            ),
          if (yonetici)
            // (P237 §1 KURALI) BASKA EKRANA GOTUREN eylem ADINI
            // GORUNUR TASIR: tooltip uzun basmayi gerektirir ve
            // kullanici simgenin ne oldugunu ONCEDEN bilmek zorunda
            // kalirdi.
            TextButton.icon(
              key: const Key('vardiya-sablonlar'),
              icon: const Icon(Icons.schedule_outlined),
              label: Text(l10n.vardiyaSablonlari),
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.vardiyalar),
            ),
          if (yonetici)
            IconButton(
              key: const Key('vardiya-izin-ac'),
              icon: const Icon(Icons.beach_access_outlined),
              tooltip: l10n.vardiyaIzinEkle,
              onPressed: () => _izinEkle(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vardiyaCizelgeProvider);
          ref.invalidate(vardiyaSimdiProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------------- 4.2 ANLIK DURUM ----------------
            simdi.when(
              data: (d) => Card(
                key: const Key('vardiya-simdi'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.vardiyaSuAnGorevde,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        d.gorevdekiVardiya == null
                            ? l10n.vardiyaSuAnKimseYok
                            : '${d.gorevdekiVardiya!.shiftAd} '
                                '${d.gorevdekiVardiya!.saatAraligi}\n'
                                '${d.gorevdekiler.map((k) => k.ad).join(', ')}',
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.vardiyaSiradaki,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        d.sonrakiVardiya == null
                            ? l10n.vardiyaSiradakiYok
                            : '${d.sonrakiVardiya!.shiftAd} '
                                '${d.sonrakiVardiya!.saatAraligi}\n'
                                '${d.sonrakiler.map((k) => k.ad).join(', ')}',
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              // ANLIK DURUM DUSERSE HAFTA YINE CIZILIR: kart bir
              // KOLAYLIKTIR, ekranin tamamini kirmasi orantisiz olurdu.
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ------------- (P205 §2) GUN GUN VARDIYALAR -------------
            cizelge.when(
              data: (c) {
                final gunler = _gunlereBol(c);
                if (gunler.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.vardiyaKayitYok),
                  );
                }
                final siraliGunler = gunler.keys.toList()..sort();
                return Column(
                  children: [
                    for (final g in siraliGunler)
                      Card(
                        key: Key('vardiya-gun-$g'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                g,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            // (P241 §2) O GUN IZINLI OLANLAR — vardiya
                            // satiri DEGIL, ayri bir satir. Ayni listeye
                            // koymak, izinli kisiyi "calisiyor" gibi
                            // gosterirdi.
                            for (final k in c.personel)
                              if (k.izinler.any((iz) => iz.kapsar(g)))
                                ListTile(
                                  key: Key('vardiya-izinli-${k.userId}-$g'),
                                  dense: true,
                                  leading:
                                      const Icon(Icons.beach_access_outlined),
                                  title: Text(k.ad),
                                  subtitle: Text(l10n.vardiyaIzinli),
                                ),
                            for (final s in gunler[g]!)
                              ListTile(
                                key: Key('vardiya-blok-${s.blok.planId}'),
                                dense: true,
                                leading: Icon(
                                  // GECE ASIRI vardiya AYRI IKON: saat
                                  // araligi tek basina ("22:00–05:00")
                                  // "bitis baslangictan kucuk" diye
                                  // yanlis okunabiliyor.
                                  s.blok.geceAsiyor
                                      ? Icons.nightlight_outlined
                                      : Icons.schedule_outlined,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(child: Text(s.kisi.ad)),
                                    // (P241 §2) TASLAK ISARETI — YAZIYLA.
                                    // Renk tek basina anlam tasimamali;
                                    // sahada gunes altinda renk farki
                                    // zaten kayboluyor.
                                    if (s.blok.taslak) ...[
                                      const SizedBox(width: 6),
                                      Chip(
                                        key: Key(
                                            'vardiya-taslak-${s.blok.planId}'),
                                        label: Text(l10n.vardiyaTaslak),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                    if (s.blok.shiftAd != null) s.blok.shiftAd!,
                                    s.blok.saatAraligi,
                                    // ROL ETIKETI ve LOKASYON (§2).
                                    if (s.blok.vardiyaRolu != null)
                                      s.blok.vardiyaRolu!,
                                    if (s.blok.yer != null) s.blok.yer!,
                                    // MOLA DUSULMUS CALISMA SURESI —
                                    // sunucudan; istemci hesaplamaz.
                                    if (s.blok.molaDakika > 0)
                                      l10n.vardiyaCalismaSaati(
                                          s.blok.calismaSaat),
                                  ].join('  ·  '),
                                ),
                                // BASIT DEGISIKLIK: yalniz YONETICI ve
                                // yalniz CIKARMA. Cikarma acil durumun
                                // ta kendisi (hastalik/izin) ve sahada
                                // gerekir.
                                trailing: yonetici
                                    ? IconButton(
                                        key: Key(
                                            'vardiya-cikar-${s.blok.planId}'),
                                        icon: const Icon(
                                            Icons.person_remove_outlined),
                                        tooltip: l10n.vardiyaCikar,
                                        onPressed: () => _cikarSor(
                                          context,
                                          ref,
                                          s.kisi.ad,
                                          s.blok.planId,
                                        ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata,
                ),
              ),
            ),
          ],
        ),
      ),
      // (§2.4) HIZLI EKLEME — YALNIZ YONETICI. Sahadaki gorevlinin
      // vardiya yazma yetkisi YOK (sunucu da reddeder); dugmeyi
      // gostermek, reddedilecek bir eylemi davet etmek olurdu.
      floatingActionButton: yonetici
          ? FloatingActionButton.extended(
              key: const Key('vardiya-yeni'),
              onPressed: () => _hizliEkle(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.vardiyaYeni),
            )
          : null,
    );
  }

  /// (§2.4) MOBILDE HIZLI EKLEME — tek kisi, tarih araligi, saatler.
  Future<void> _hizliEkle(BuildContext context, WidgetRef ref) async {
    final eklendi = await showDialog<bool>(
      context: context,
      builder: (c) => const _HizliEkleDialogu(),
    );
    if (eklendi == true) {
      ref.invalidate(vardiyaCizelgeProvider);
      ref.invalidate(vardiyaSimdiProvider);
    }
  }

  /// (P241 §2) Donemdeki taslak/degismis satirlari yayinla.
  Future<void> _yayinla(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final n = await ref
          .read(vardiyaPlaniApiProvider)
          .yayinla(_haftaBasi(DateTime.now()));
      ref.invalidate(vardiyaYayinOzetiProvider);
      ref.invalidate(vardiyaCizelgeProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vardiyaYayinlandiMesaj(n))),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  /// (P241 §2) Izin ekleme — yonetim icin DOGRUDAN onayli.
  Future<void> _izinEkle(BuildContext context, WidgetRef ref) async {
    final eklendi = await merkezSayfaAc<bool>(
      context,
      builder: (_) => const IzinFormu(),
    );
    if (eklendi == true) {
      ref.invalidate(vardiyaCizelgeProvider);
    }
  }

  Future<void> _cikarSor(
    BuildContext context,
    WidgetRef ref,
    String ad,
    String planId,
  ) async {
    final l10n = context.l10n;
    // SEBEP DIALOGU KENDI DENETLEYICISINE SAHIP.
    //
    // Once denetleyiciyi BURADA acip `showDialog` donunce `dispose`
    // etmistim; `denetleyici_atma_test` sizintiyi hakli olarak
    // yakalamisti ama ilk duzeltmem YENI bir kusur uretti: dialog
    // KAPANMA ANIMASYONU sirasinda hâlâ agacta ve denetleyiciyi
    // kullaniyor — "A TextEditingController was used after being
    // disposed" atti (kendi testim gosterdi).
    //
    // Dogru cozum: denetleyiciyi dialogun KENDISI sahiplensin ve
    // `State.dispose`ta atsin. Yasam dongusu boylece widget'in
    // yasam dongusuyle AYNI olur.
    final sebep = await showDialog<String>(
      context: context,
      builder: (c) => _CikarSebepDialogu(ad: ad),
    );
    if (sebep == null) return;
    try {
      await ref.read(vardiyaPlaniApiProvider).cikar(planId, sebep: sebep);
      ref.invalidate(vardiyaCizelgeProvider);
      ref.invalidate(vardiyaSimdiProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}

/// (P203 §4) Cikarma sebebi dialogu — denetleyiciyi KENDISI sahiplenir.
class _CikarSebepDialogu extends StatefulWidget {
  const _CikarSebepDialogu({required this.ad});

  final String ad;

  @override
  State<_CikarSebepDialogu> createState() => _CikarSebepDialoguState();
}

class _CikarSebepDialoguState extends State<_CikarSebepDialogu> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.ad),
      // SEBEP SORULUR: gun ici degisiklik denetime yaziliyor ve "neden"
      // bos kalirsa kayit sonradan hicbir soruyu yanitlayamaz.
      content: TextField(
        key: const Key('vardiya-cikar-sebep'),
        controller: _ctrl,
        decoration: InputDecoration(labelText: l10n.vardiyaCikarSebep),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('vardiya-cikar-onayla'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: Text(l10n.vardiyaCikar),
        ),
      ],
    );
  }
}

/// (P205 §2.4) MOBIL HIZLI VARDIYA EKLEME.
///
/// ===========================================================================
/// CAKISAN GUNLER SESSIZCE ATLANMAZ
/// ===========================================================================
/// Sunucu once HICBIR SEY YAZMADAN `uygulandi=false` doner ve cakisan
/// gunleri listeler; dialog bunlari YAZAR ve iki secenek sunar. Sessizce
/// atlamak, yoneticinin "yedi gun ekledim" sanip bes gun eklemesi
/// demekti — eksigi ancak sahada fark ederdi.
class _HizliEkleDialogu extends ConsumerStatefulWidget {
  const _HizliEkleDialogu();

  @override
  ConsumerState<_HizliEkleDialogu> createState() => _HizliEkleDialoguState();
}

class _HizliEkleDialoguState extends ConsumerState<_HizliEkleDialogu> {
  String? _userId;
  late DateTime _bas = DateTime.now();
  late DateTime _son = DateTime.now();

  /// (P229 §2) TAKVIMDEN secilen gunler (`yyyy-MM-dd`).
  ///
  /// BOSSA ARALIK KIPI: eski davranis (bas/son tarih) aynen calisir.
  /// Iki kipi AYNI dialogda tutmak bilincli — ayri bir "toplu ekle"
  /// ekrani, cakisma akisini (P205) IKINCI KEZ yazmak demekti.
  Set<String> _seciliGunler = {};
  TimeOfDay _basSaat = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _sonSaat = const TimeOfDay(hour: 16, minute: 0);
  /// (P232) BIRIKEN GRUPLAR — "pazartesi gunduz, sali-carsamba gece".
  ///
  /// Onceden farkli gune farkli saat yazmanin tek yolu diyalogu
  /// DEFALARCA acmakti: her seferinde ayri bir parti, ayri onizleme,
  /// ayri catisma kontrolu ve geri alirken AYRI BIR ISTEK.
  final List<VardiyaGunGrubu> _gruplar = [];
  final _notCtrl = TextEditingController();
  // (P241 §2) MOLA / ROL / LOKASYON denetleyicileri.
  final _molaCtrl = TextEditingController();
  final _rolCtrl = TextEditingController();
  final _alanCtrl = TextEditingController();
  /// Sunucudan gelen YASAL mola onerisi (4857 md. 68).
  int? _molaOnerisi;
  List<String>? _cakisanlar;
  /// (P232) Onizleme sonucu — kaydetmeden once kac vardiya olusacagi.
  VardiyaKalipSonuc? _onizleme;
  String? _hata;
  bool _bekliyor = false;

  @override
  void dispose() {
    // HER DENETLEYICI AYRI SATIRDA: `denetleyici_atma_test` dongu
    // icindeki `dispose` cagrilarini TANIMIYOR (P240 §2'de olculdu).
    _notCtrl.dispose();
    _molaCtrl.dispose();
    _rolCtrl.dispose();
    _alanCtrl.dispose();
    super.dispose();
  }

  /// Saat degisince YASAL ONERIYI SUNUCUDAN sor.
  ///
  /// Kademeleri istemcide yazmak, kanunu iki yuzeye kopyalamak ve
  /// birini guncelleyip otekini unutmak demekti.
  Future<void> _molaOneriGetir() async {
    try {
      final n = await ref
          .read(vardiyaPlaniApiProvider)
          .molaOnerisi(_s(_basSaat), _s(_sonSaat));
      if (mounted) setState(() => _molaOnerisi = n);
    } on ApiException {
      // ONERI BIR KOLAYLIKTIR: alinamamasi formu kirmamali.
    }
  }

  String _g(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _s(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Ekrandaki (gunler + saat) ikilisini gruba cevirir.
  VardiyaGunGrubu _buGrup() => VardiyaGunGrubu(
    gunler: (_seciliGunler.toList()..sort()),
    dilimler: [
      VardiyaDilim(
        // AD GEREKLI: sunucu sonuc satirlarinda dilimi adiyla
        // raporluyor; adsiz dilim "hangi vardiya" sorusunu
        // yanitlanamaz kilardi.
        ad: '${_s(_basSaat)}-${_s(_sonSaat)}',
        baslangic: _s(_basSaat),
        bitis: _s(_sonSaat),
      ),
    ],
    atamalar: {0: [?_userId]},
  );

  void _grubaEkle() {
    if (_userId == null || _seciliGunler.isEmpty) return;
    setState(() {
      _gruplar.add(_buGrup());
      // Sonraki grup BOS baslar: yoksa kullanici ayni gunleri ikinci
      // gruba da yazar ve kendi kendine cakisma uretirdi.
      _seciliGunler = {};
    });
  }

  /// (P232) COK GRUPLU gonderim — onizleme ve uygulama AYNI yol.
  Future<void> _gruplariGonder({required bool kuru, required bool atla}) async {
    final l10n = context.l10n;
    // Ekranda kurulmakta olan grup da dahil: kullanicinin "ekle"ye
    // basmayi unutmasi, son grubun SESSIZCE kaybolmasi demekti.
    final hepsi = [
      ..._gruplar,
      if (_userId != null && _seciliGunler.isNotEmpty) _buGrup(),
    ];
    if (hepsi.isEmpty) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(vardiyaPlaniApiProvider).kalipUygula(
        gruplar: hepsi,
        kuru: kuru,
        cakisanlariAtla: atla,
      );
      if (!mounted) return;
      if (kuru || !sonuc.uygulandi) {
        setState(() {
          _bekliyor = false;
          _onizleme = sonuc;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(l10n, e);
        _bekliyor = false;
      });
    }
  }

  Future<void> _gonder({required bool atla}) async {
    final l10n = context.l10n;
    if (_userId == null) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(vardiyaPlaniApiProvider).topluEkle(
            userId: _userId!,
            baslangic: _bas,
            bitis: _son,
            baslangicSaat: _s(_basSaat),
            bitisSaat: _s(_sonSaat),
            not: _notCtrl.text.trim().isEmpty ? null : _notCtrl.text.trim(),
            cakisanlariAtla: atla,
            gunler: _seciliGunler.isEmpty
                ? null
                : (_seciliGunler.toList()..sort()),
            // (P241 §2) MOLA / ROL / LOKASYON — web ile AYNI alanlar,
            // ayni uc. Mobilde eksik birakmak, ayni plani iki yuzeyde
            // farkli ayrintiyla tutmak olurdu.
            molaDakika: int.tryParse(_molaCtrl.text.trim()),
            vardiyaRolu:
                _rolCtrl.text.trim().isEmpty ? null : _rolCtrl.text.trim(),
            alan: _alanCtrl.text.trim().isEmpty ? null : _alanCtrl.text.trim(),
          );
      if (!mounted) return;
      if (!sonuc.uygulandi) {
        // KARAR KULLANICININ: hangi gunlerde cakisma oldugunu GORUR.
        setState(() {
          _cakisanlar = sonuc.cakisanGunler;
          _bekliyor = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(l10n, e);
        _bekliyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personel = ref.watch(vardiyaPersonelProvider);

    return AlertDialog(
      title: Text(l10n.vardiyaYeni),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _hata!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            personel.when(
              data: (liste) => DropdownButtonFormField<String>(
                key: const Key('vardiya-ekle-kisi'),
                initialValue: _userId,
                decoration: InputDecoration(labelText: l10n.vardiyaPersonel),
                items: [
                  for (final p in liste)
                    DropdownMenuItem(value: p.id, child: Text(p.ad)),
                ],
                onChanged: (v) => setState(() => _userId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
            ),
            const SizedBox(height: 8),
            // ================================================================
            // (P229 §2) IKI KIP, TEK DIALOG
            // ================================================================
            // Takvimden gun secilmisse ARALIK ALANLARI GIZLENIR. Ikisini
            // birden gostermek, hangisinin gecerli oldugunu belirsiz
            // birakirdi: kullanici araligi 1-7 birakip takvimden 3 gun
            // secer ve kac vardiya olusacagini BILEMEZDI.
            GunTakvimi(
              key: const Key('vardiya-ekle-takvim'),
              ay: _bas,
              secili: _seciliGunler,
              enErken: DateTime.now().subtract(const Duration(days: 365)),
              enGec: DateTime.now().add(const Duration(days: 365)),
              onDegisti: (y) => setState(() => _seciliGunler = y),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.vardiyaSeciliGun(_seciliGunler.length),
                    key: const Key('vardiya-ekle-secim-sayisi'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_seciliGunler.isNotEmpty)
                  TextButton(
                    key: const Key('vardiya-ekle-secimi-temizle'),
                    onPressed: () => setState(() => _seciliGunler = {}),
                    child: Text(l10n.vardiyaSecimiTemizle),
                  ),
              ],
            ),
            Text(
              l10n.vardiyaTakvimIpucu,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_seciliGunler.isEmpty) ...[
            ListTile(
              key: const Key('vardiya-ekle-bas-tarih'),
              dense: true,
              title: Text(l10n.vardiyaBaslangicTarihi),
              subtitle: Text(_g(_bas)),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _bas,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d == null) return;
                setState(() {
                  _bas = d;
                  // BITIS BASLANGICI TAKIP EDER: ters aralik sunucuda
                  // 422 aliyor ve kullaniciya bunu HATA olarak
                  // gostermek, onun yapmadigi bir hatayi ona yuklemek
                  // olurdu.
                  if (_son.isBefore(d)) _son = d;
                });
              },
            ),
            ListTile(
              key: const Key('vardiya-ekle-son-tarih'),
              dense: true,
              title: Text(l10n.vardiyaBitisTarihi),
              subtitle: Text(_g(_son)),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _son,
                  firstDate: _bas,
                  lastDate: _bas.add(const Duration(days: 30)),
                );
                if (d != null) setState(() => _son = d);
              },
            ),
            ],
            ListTile(
              key: const Key('vardiya-ekle-bas-saat'),
              dense: true,
              title: Text(l10n.vardiyaBaslangicSaati),
              subtitle: Text(_s(_basSaat)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () async {
                final v = await showTimePicker(
                    context: context, initialTime: _basSaat);
                if (v != null) {
                  setState(() => _basSaat = v);
                  await _molaOneriGetir();
                }
              },
            ),
            ListTile(
              key: const Key('vardiya-ekle-son-saat'),
              dense: true,
              title: Text(l10n.vardiyaBitisSaati),
              subtitle: Text(_s(_sonSaat)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () async {
                final v = await showTimePicker(
                    context: context, initialTime: _sonSaat);
                if (v != null) {
                  setState(() => _sonSaat = v);
                  await _molaOneriGetir();
                }
              },
            ),
            // ---------------- (P241 §2) MOLA / ROL / LOKASYON ----------
            TextField(
              key: const Key('vardiya-ekle-mola'),
              controller: _molaCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.vardiyaMolaDakika,
                helperText: _molaOnerisi == null
                    ? l10n.vardiyaMolaDuser
                    : l10n.vardiyaMolaOnerisi(_molaOnerisi!),
                helperMaxLines: 2,
              ),
            ),
            TextField(
              key: const Key('vardiya-ekle-rol'),
              controller: _rolCtrl,
              decoration: InputDecoration(labelText: l10n.vardiyaRolEtiketi),
            ),
            TextField(
              key: const Key('vardiya-ekle-lokasyon'),
              controller: _alanCtrl,
              decoration: InputDecoration(labelText: l10n.vardiyaLokasyon),
            ),
            TextField(
              key: const Key('vardiya-ekle-not'),
              controller: _notCtrl,
              decoration: InputDecoration(labelText: l10n.vardiyaNot),
            ),
            const SizedBox(height: 8),
            // IKI DAVRANIS ONCEDEN SOYLENIR: aralik HER GUN icin kayit
            // acar ve bitis saati baslangictan kucukse vardiya ERTESI
            // GUNE tasar. Denedikten sonra ogrenmek, yanlislikla on
            // dort kayit acmak demekti.
            Text(
              l10n.vardiyaEkleBilgi,
              key: const Key('vardiya-ekle-bilgi'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_cakisanlar != null && _cakisanlar!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.vardiyaCakisanGunler(_cakisanlar!.length),
                key: const Key('vardiya-cakisma-uyarisi'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Text(_cakisanlar!.join(', ')),
            ],
            // (P232) BIRIKEN GRUPLAR.
            if (_gruplar.isNotEmpty) ...[
              const Divider(),
              for (var i = 0; i < _gruplar.length; i++)
                ListTile(
                  key: Key('vardiya-grup-$i'),
                  dense: true,
                  title: Text(
                    l10n.vardiyaGrupOzeti(
                      _gruplar[i].gunler.length,
                      _gruplar[i].dilimler.first.ad,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.ortakSil,
                    onPressed: () => setState(() => _gruplar.removeAt(i)),
                  ),
                ),
            ],
            if (_onizleme != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  key: const Key('vardiya-onizleme'),
                  l10n.vardiyaOnizlemeSonuc(
                    _onizleme!.eklenecek,
                    _onizleme!.cakisan,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('vardiya-gruba-ekle'),
                  onPressed: (_userId == null || _seciliGunler.isEmpty)
                      ? null
                      : _grubaEkle,
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.vardiyaGrubaEkle),
                ),
                OutlinedButton.icon(
                  key: const Key('vardiya-onizle'),
                  onPressed: _bekliyor
                      ? null
                      : () => _gruplariGonder(kuru: true, atla: false),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.vardiyaOnizle),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.ortakVazgec),
        ),
        if (_cakisanlar != null && _cakisanlar!.isNotEmpty)
          FilledButton(
            key: const Key('vardiya-cakisan-haric'),
            onPressed: _bekliyor ? null : () => _gonder(atla: true),
            child: Text(l10n.vardiyaCakisanHaric),
          )
        else
          FilledButton(
            key: const Key('vardiya-ekle-gonder'),
            // GRUP VARSA COK GRUPLU YOL: tek istek, tek parti. Tekil yol
            // KALDIRILMADI — tek gun + tek saat en sik yapilan is ve
            // onu grup kurmaya zorlamak gereksiz bir adim olurdu.
            onPressed: (_bekliyor || (_userId == null && _gruplar.isEmpty))
                ? null
                : () => _gruplar.isEmpty
                    ? _gonder(atla: false)
                    : _gruplariGonder(kuru: false, atla: false),
            child: Text(l10n.vardiyaEkleGonder),
          ),
      ],
    );
  }
}
