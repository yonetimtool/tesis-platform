/// (P247 §1) VARDIYA DONGUSU — mobil: ata + onizle + kaydet + geri al.
///
/// =========================================================================
/// MOBILDE NE VAR, NE YOK — GEREKCELI
/// =========================================================================
/// VAR: kayitli donguyu secip ekibe baslangic tarihi + kaydirma ile atamak,
/// kaydetmeden once ONIZLEME (gun gun kim calisiyor, KIMSESIZ saatler
/// kirmizi ve saat araligiyla), kaydetmek, ekibin dongusunu geri almak.
/// Sahadaki iki standart dongu (2-2-2 ve 12/36 iki hafta) HAZIR sablon
/// olarak buradan da kaydedilebilir.
///
/// YOK (yalniz web): SERBEST dongu tanimi (dilim saatleri + adim bloklari
/// editoru) ve kisi bazinda "sonlandir". Tanim bir kez yapilir ve 6 dilim
/// x 84 gunluk bir blok editoru telefonda hata uretir; atama ise sahada
/// tekrar tekrar yapilan istir. Sunucu kurallari (cakisma, izin, taslak,
/// parti) iki yuzeyde de AYNI uctan gecer.
///
/// `kuru=true` ile onizleme ve kaydetme AYNI uca gider (P207 K1.4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../staff/data/staff_api.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';

/// Hazir donguler — web'deki `HAZIR_BLOK` ile ayni adim dizileri.
const List<List<int>> hazir222 = [
  [1],
  [1],
  [0],
  [0],
  [],
  [],
];
final List<List<int>> hazir1236 = [
  for (var i = 0; i < 14; i++) i.isEven ? [1] : <int>[],
  for (var i = 0; i < 14; i++) i.isEven ? [0] : <int>[],
];

/// Onizlemede listelenen gun sayisi (ufkun tamami telefonda okunmaz).
const int onizlemeGun = 14;

const _atanabilir = {
  'security',
  'guvenlik_amiri',
  'tesis_gorevlisi',
  'yonetici',
};

final _personelProvider = FutureProvider.autoDispose<List<StaffMember>>(
  (ref) => ref.watch(staffApiProvider).tumPersonel(),
);

/// Onizleme gun satiri: "03.10  Ahmet: Gece · Ayse: izinli".
///
/// Ayrac ve tarih bicimi CEVRILECEK METIN DEGIL (noktalama); ayri bir
/// fonksiyonda duruyor ki cizim katmanindaki sabit-metin denetimi ic ice
/// dize enterpolasyonunu yanlis okumasin.
String _gunSatiri(
  String tarih,
  List<VardiyaDonguSatiri> satirlar,
  Map<String, String> ad,
  AppLocalizations l10n,
) {
  final kisiler = satirlar.where((x) => x.tarih == tarih).map((x) {
    final durum = switch (x.durum) {
      'izinli' => l10n.donguIzinli,
      'cakisma' => l10n.donguCakisma,
      _ => x.dilim,
    };
    return '${ad[x.userId] ?? '?'}: $durum';
  });
  return '${tarih.substring(8, 10)}.${tarih.substring(5, 7)}  ${kisiler.join(' · ')}';
}

class DonguAtaDialogu extends ConsumerStatefulWidget {
  const DonguAtaDialogu({super.key, this.bugun});

  /// Testte sabit tarih; uretimde bugun.
  final DateTime? bugun;

  @override
  ConsumerState<DonguAtaDialogu> createState() => _DonguAtaDialoguState();
}

class _DonguAtaDialoguState extends ConsumerState<DonguAtaDialogu> {
  List<VardiyaKalibi> _kaliplar = const [];
  List<VardiyaDonguAtama> _atamalar = const [];
  String? _kalipId;
  final List<String> _kisiler = [];
  late DateTime _baslangic;
  final _kaydirmaCtrl = TextEditingController(text: '0');
  VardiyaDonguSonuc? _sonuc;
  String? _hata;
  bool _bekliyor = false;
  bool _degisti = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bugun ?? DateTime.now();
    // Varsayilan: gelecek pazartesi — dongu genelde hafta basinda baslar.
    _baslangic = DateTime(
      b.year,
      b.month,
      b.day,
    ).add(Duration(days: 8 - b.weekday));
    _yukle();
  }

  @override
  void dispose() {
    _kaydirmaCtrl.dispose();
    super.dispose();
  }

  VardiyaPlaniApi get _api => ref.read(vardiyaPlaniApiProvider);

  Future<void> _yukle() async {
    try {
      final k = await _api.kaliplar();
      final a = await _api.donguAtamalari();
      if (!mounted) return;
      setState(() {
        _kaliplar = k.where((x) => x.donguMu).toList();
        _atamalar = a.where((x) => x.durum == 'aktif').toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    }
  }

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await is_();
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  Future<void> _hazirKaydet(
    String ad,
    List<List<int>> adimlar,
  ) => _calistir(() async {
    final l10n = context.l10n;
    final k = await _api.donguKalibiOlustur(
      ad: ad,
      dilimler: [
        VardiyaDilim(ad: l10n.donguGunduz, baslangic: '08:00', bitis: '20:00'),
        VardiyaDilim(ad: l10n.donguGece, baslangic: '20:00', bitis: '08:00'),
      ],
      adimlar: adimlar,
    );
    await _yukle();
    if (!mounted) return;
    setState(() {
      // Liste yenilemesi yarisirsa yeni kalip yine secilebilir olsun.
      if (!_kaliplar.any((x) => x.id == k.id)) _kaliplar = [..._kaliplar, k];
      _kalipId = k.id;
    });
  });

  int get _kaydirma => int.tryParse(_kaydirmaCtrl.text.trim()) ?? 0;

  Future<void> _gonder({required bool kuru, bool atla = false}) =>
      _calistir(() async {
        final s = await _api.donguUygula(
          kalipId: _kalipId!,
          baslangic: _baslangic,
          kisiler: List.of(_kisiler),
          kaydirma: _kaydirma,
          kuru: kuru,
          cakisanlariAtla: atla,
        );
        if (!mounted) return;
        setState(() => _sonuc = s);
        if (s.uygulandi) {
          _degisti = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.donguUygulandi(s.eklenen))),
          );
          await _yukle();
        }
      });

  Future<void> _geriAl(String partiId) => _calistir(() async {
    final n = await _api.partiGeriAl(partiId);
    _degisti = true;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.donguGeriAlindi(n))));
    await _yukle();
  });

  String _t(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personel = ref.watch(_personelProvider);
    final hata = Theme.of(context).colorScheme.error;
    final ad = {
      for (final p in personel.asData?.value ?? const <StaffMember>[])
        p.id: p.ad,
    };

    return AlertDialog(
      title: Text(l10n.donguBaslik),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_hata!, style: TextStyle(color: hata)),
                ),
              // DIS ANAHTAR SABIT (test/erisim), IC ANAHTAR SECIME BAGLI:
              // `initialValue` yalniz ilk cizimde okunur; hazir sablon
              // kaydedilince secimin ekranda da degismesi icin alan
              // yeniden kurulur.
              KeyedSubtree(
                key: const Key('dongu-kalip'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dongu-kalip-$_kalipId'),
                  initialValue: _kalipId,
                  // Uzun dongu adi ("2 hafta gece 12/36 ...") dar ekranda
                  // tasiyordu (testte olculdu): satir kisaltilir.
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.donguKalip),
                  items: [
                    for (final k in _kaliplar)
                      DropdownMenuItem(
                        value: k.id,
                        child: Text(k.ad, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _kalipId = v;
                    _sonuc = null;
                  }),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: const Key('dongu-hazir-222'),
                    onPressed: _bekliyor
                        ? null
                        : () => _hazirKaydet(l10n.donguHazir222, hazir222),
                    child: Text(l10n.donguHazir222),
                  ),
                  TextButton(
                    key: const Key('dongu-hazir-1236'),
                    onPressed: _bekliyor
                        ? null
                        : () => _hazirKaydet(l10n.donguHazir1236, hazir1236),
                    child: Text(l10n.donguHazir1236),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.donguKisiler,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              personel.when(
                data: (liste) => Column(
                  children: [
                    for (final p in liste.where(
                      (x) => _atanabilir.contains(x.role),
                    ))
                      CheckboxListTile(
                        key: Key('dongu-kisi-${p.id}'),
                        dense: true,
                        value: _kisiler.contains(p.id),
                        title: Text(p.ad),
                        subtitle: _kisiler.contains(p.id)
                            ? Text(
                                l10n.donguOfset(
                                  _kisiler.indexOf(p.id) * _kaydirma,
                                ),
                              )
                            : null,
                        onChanged: (v) => setState(() {
                          v == true
                              ? _kisiler.add(p.id)
                              : _kisiler.remove(p.id);
                          _sonuc = null;
                        }),
                      ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
              ),
              ListTile(
                key: const Key('dongu-baslangic'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.donguBaslangic),
                trailing: Text(_t(_baslangic)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _baslangic,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 31),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() {
                      _baslangic = d;
                      _sonuc = null;
                    });
                  }
                },
              ),
              TextField(
                key: const Key('dongu-kaydirma'),
                controller: _kaydirmaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.donguKaydirma,
                  helperText: l10n.donguKaydirmaIpucu,
                  helperMaxLines: 3,
                ),
                onChanged: (_) => setState(() => _sonuc = null),
              ),
              if (_sonuc != null) ..._onizleme(context, _sonuc!, ad),
              const Divider(height: 24),
              Text(
                l10n.donguEtkinler,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (_atamalar.isEmpty) Text(l10n.donguEtkinYok),
              for (final parti in {for (final a in _atamalar) a.partiId})
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _atamalar.firstWhere((a) => a.partiId == parti).kalipAd,
                  ),
                  subtitle: Text(
                    _atamalar
                        .where((a) => a.partiId == parti)
                        .map((a) => a.ad)
                        .join(', '),
                  ),
                  trailing: TextButton(
                    key: Key('dongu-geri-al-$parti'),
                    onPressed: _bekliyor ? null : () => _geriAl(parti),
                    child: Text(l10n.donguGeriAl),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_degisti),
          child: Text(l10n.ortakKapat),
        ),
        TextButton(
          key: const Key('dongu-onizle'),
          onPressed: (_bekliyor || _kalipId == null || _kisiler.isEmpty)
              ? null
              : () => _gonder(kuru: true),
          child: Text(l10n.donguOnizle),
        ),
        if (_sonuc != null && !_sonuc!.uygulandi && _sonuc!.cakisan > 0)
          TextButton(
            key: const Key('dongu-cakisan-haric'),
            onPressed: _bekliyor
                ? null
                : () => _gonder(kuru: false, atla: true),
            child: Text(l10n.donguCakisanHaric),
          ),
        FilledButton(
          key: const Key('dongu-uygula'),
          onPressed: (_bekliyor || _sonuc == null || _sonuc!.uygulandi)
              ? null
              : () => _gonder(kuru: false),
          child: Text(l10n.donguUygula),
        ),
      ],
    );
  }

  List<Widget> _onizleme(
    BuildContext context,
    VardiyaDonguSonuc s,
    Map<String, String> ad,
  ) {
    final l10n = context.l10n;
    final hata = Theme.of(context).colorScheme.error;
    final gunler = s.kapsama.take(onizlemeGun).toList();
    return [
      const SizedBox(height: 12),
      Text(
        l10n.donguOzet(
          s.uygulandi ? s.eklenen : s.eklenecek,
          s.cakisan,
          s.izinli,
          s.bosGunler.length,
        ),
        key: const Key('dongu-ozet'),
      ),
      Text(
        l10n.donguUfuk(s.bitis),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      for (final g in gunler)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_gunSatiri(g.tarih, s.satirlar, ad, l10n)),
              if (g.bosDakika > 0)
                Container(
                  key: Key('dongu-bosluk-${g.tarih}'),
                  color: hata.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${l10n.donguBosluk}: ${g.bosluklar.join(', ')}',
                    style: TextStyle(color: hata, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}
