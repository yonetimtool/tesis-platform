/// (P253 Asama 1) VARDIYA — hafta gezinmesi, toplu islemler, blok duzenle.
///
/// ===========================================================================
/// GERI AL — NASIL
/// ===========================================================================
/// `haftayi-doldur` ve `haftadan-kopyala` yanitlari yeni satirlarin
/// kimligini TASIMIYOR ve partiye baglamiyor (web'de bu iki islemin geri
/// almasi yok). Mobil geri almayi ONCE/SONRA farkiyla kurar: islemden once
/// ve sonra haftanin cizelgesi okunur, yeni beliren `plan_id`ler "Geri al"
/// ile tek tek cikarilir (`DELETE /vardiya-plani/{id}` — web toplu silme
/// ile AYNI uc; satir silinmez, iptal isaretlenir).
///
/// SINIR — ONCEDEN SOYLENIR: kopyada "hedefi temizle" secilirse temizlenen
/// satirlar geri GELMEZ (onlari geri getiren bir uc yok); diyalog bunu
/// secim aninda yazar. Toplu cikarma da geri alinamaz; onay metni soyler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';

/// Bu haftanin PAZARTESISI (TR takvimi).
DateTime haftaBasi(DateTime t) =>
    DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1));

String tarihMetni(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "2026-10-05 – 2026-10-11" — noktalama, ceviri degil.
String haftaEtiketi(DateTime bas) =>
    '${tarihMetni(bas)} – ${tarihMetni(bas.add(const Duration(days: 6)))}';

/// Ekranda gosterilen haftanin pazartesisi.
class VardiyaHaftaNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => haftaBasi(DateTime.now());

  void onceki() => state = state.subtract(const Duration(days: 7));
  void sonraki() => state = state.add(const Duration(days: 7));
}

final vardiyaHaftaProvider =
    NotifierProvider<VardiyaHaftaNotifier, DateTime>(VardiyaHaftaNotifier.new);

Set<String> _planIdleri(VardiyaCizelge c) => {
      for (final k in c.personel)
        for (final b in k.bloklar) b.planId,
    };

/// Toplu islemi ONCE/SONRA farkiyla calistirir; yeni satir kimliklerini doner.
Future<List<String>> _farkla(
  VardiyaPlaniApi api,
  DateTime hafta,
  Future<void> Function() is_,
) async {
  final once = _planIdleri(await api.cizelge(hafta));
  await is_();
  final sonra = _planIdleri(await api.cizelge(hafta));
  return [for (final id in sonra) if (!once.contains(id)) id];
}

/// Yeni satirlari cikarir (geri al). Cikarilan sayi.
Future<int> _geriAl(VardiyaPlaniApi api, List<String> idler) async {
  var n = 0;
  for (final id in idler) {
    await api.cikar(id);
    n++;
  }
  return n;
}

void _bildir(
  BuildContext context,
  String metin, {
  List<String> geriAlinacak = const [],
  required VardiyaPlaniApi api,
  required VoidCallback tazele,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  messenger.showSnackBar(
    SnackBar(
      content: Text(metin),
      duration: const Duration(seconds: 8),
      action: geriAlinacak.isEmpty
          ? null
          : SnackBarAction(
              key: const Key('vardiya-geri-al'),
              label: l10n.vrdGeriAl,
              onPressed: () async {
                try {
                  final n = await _geriAl(api, geriAlinacak);
                  tazele();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.vrdGeriAlindi(n))),
                  );
                } on ApiException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(apiHataMetni(l10n, e))),
                  );
                }
              },
            ),
    ),
  );
}

/// Haftayi kadrodan doldur — sonuc + "Geri al".
Future<void> haftayiDoldur(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback tazele,
}) async {
  final api = ref.read(vardiyaPlaniApiProvider);
  final hafta = ref.read(vardiyaHaftaProvider);
  final l10n = context.l10n;
  try {
    final yeni = await _farkla(api, hafta, () => api.haftayiDoldur(hafta));
    tazele();
    if (!context.mounted) return;
    _bildir(context, l10n.vrdDolduruldu(yeni.length),
        geriAlinacak: yeni, api: api, tazele: tazele);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
  }
}

/// Baska bir haftadan bu haftaya kopyala — kaynak + "hedefi temizle" sorulur.
Future<void> haftadanKopyala(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback tazele,
}) async {
  final hedef = ref.read(vardiyaHaftaProvider);
  final secim = await showDialog<({DateTime kaynak, bool temizle})>(
    context: context,
    builder: (_) => KopyaDialogu(hedef: hedef),
  );
  if (secim == null || !context.mounted) return;
  final api = ref.read(vardiyaPlaniApiProvider);
  final l10n = context.l10n;
  try {
    late VardiyaKopyaSonuc sonuc;
    final yeni = await _farkla(api, hedef, () async {
      sonuc = await api.haftadanKopyala(
        kaynak: secim.kaynak,
        hedef: hedef,
        hedefiTemizle: secim.temizle,
      );
    });
    tazele();
    if (!context.mounted) return;
    _bildir(context, kopyaMetni(l10n, sonuc),
        geriAlinacak: yeni, api: api, tazele: tazele);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
  }
}

/// "5 vardiya kopyalandi, 2 atlandi — izinli, cakisma" (sessiz atlama yok).
String kopyaMetni(AppLocalizations l10n, VardiyaKopyaSonuc s) {
  final ana = l10n.vrdKopyaSonuc(s.eklenen, s.atlanan);
  if (s.sebepler.isEmpty) return ana;
  final sebep = s.sebepler
      .map((x) => x == 'izin' ? l10n.vrdSebepIzin : l10n.vrdSebepCakisma)
      .toSet()
      .join(', ');
  return '$ana — $sebep';
}

/// Kopya kaynagi secimi. Varsayilan: bir onceki hafta.
class KopyaDialogu extends StatefulWidget {
  const KopyaDialogu({super.key, required this.hedef});

  final DateTime hedef;

  @override
  State<KopyaDialogu> createState() => _KopyaDialoguState();
}

class _KopyaDialoguState extends State<KopyaDialogu> {
  late DateTime _kaynak = widget.hedef.subtract(const Duration(days: 7));
  bool _temizle = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.vrdHaftadanKopyala),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vrdKopyaHedef(haftaEtiketi(widget.hedef))),
          const SizedBox(height: 8),
          Text(l10n.vrdKopyaKaynak,
              style: Theme.of(context).textTheme.labelLarge),
          Row(
            children: [
              IconButton(
                key: const Key('vardiya-kopya-kaynak-onceki'),
                tooltip: l10n.vrdHaftaOnceki,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                    () => _kaynak = _kaynak.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Text(
                  haftaEtiketi(_kaynak),
                  key: const Key('vardiya-kopya-kaynak'),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const Key('vardiya-kopya-kaynak-sonraki'),
                tooltip: l10n.vrdHaftaSonraki,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                    () => _kaynak = _kaynak.add(const Duration(days: 7))),
              ),
            ],
          ),
          CheckboxListTile(
            key: const Key('vardiya-kopya-temizle'),
            contentPadding: EdgeInsets.zero,
            value: _temizle,
            title: Text(l10n.vrdHedefiTemizle),
            onChanged: (v) => setState(() => _temizle = v ?? false),
          ),
          // SINIR ONCEDEN: temizlenen satirlar geri alinamaz.
          if (_temizle)
            Text(
              l10n.vrdHedefiTemizleUyari,
              key: const Key('vardiya-kopya-temizle-uyari'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('vardiya-kopya-uygula'),
          // Ayni haftaya kopya sunucuda 422; dugme hic etkinlesmez.
          onPressed: _kaynak == widget.hedef
              ? null
              : () => Navigator.of(context)
                  .pop((kaynak: _kaynak, temizle: _temizle)),
          child: Text(l10n.vrdKopyala),
        ),
      ],
    );
  }
}

/// Blok duzenle — web `BlokAyrinti` ile AYNI alanlar: tarih, baslangic,
/// bitis. Donus: degistiyse true.
class BlokDuzenleDialogu extends ConsumerStatefulWidget {
  const BlokDuzenleDialogu({super.key, required this.ad, required this.blok});

  final String ad;
  final VardiyaBlok blok;

  @override
  ConsumerState<BlokDuzenleDialogu> createState() => _BlokDuzenleDialoguState();
}

class _BlokDuzenleDialoguState extends ConsumerState<BlokDuzenleDialogu> {
  late DateTime _tarih = DateTime.parse(widget.blok.tarih);
  late TimeOfDay _bas = TimeOfDay.fromDateTime(widget.blok.baslar);
  late TimeOfDay _son = TimeOfDay.fromDateTime(widget.blok.biter);
  String? _hata;
  bool _bekliyor = false;

  String _s(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _kaydet() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await ref.read(vardiyaPlaniApiProvider).guncelle(
            widget.blok.planId,
            tarih: _tarih,
            baslangicSaat: _s(_bas),
            bitisSaat: _s(_son),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bekliyor = false;
        _hata = apiHataMetni(context.l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.ad),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hata != null)
            Text(_hata!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ListTile(
            key: const Key('vardiya-duzenle-tarih'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vrdTarih),
            trailing: Text(tarihMetni(_tarih)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _tarih,
                firstDate: _tarih.subtract(const Duration(days: 366)),
                lastDate: _tarih.add(const Duration(days: 366)),
              );
              if (d != null) setState(() => _tarih = d);
            },
          ),
          ListTile(
            key: const Key('vardiya-duzenle-bas'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vardiyaBaslangicSaati),
            trailing: Text(_s(_bas)),
            onTap: () async {
              final v = await showTimePicker(context: context, initialTime: _bas);
              if (v != null) setState(() => _bas = v);
            },
          ),
          ListTile(
            key: const Key('vardiya-duzenle-son'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vardiyaBitisSaati),
            trailing: Text(_s(_son)),
            onTap: () async {
              final v = await showTimePicker(context: context, initialTime: _son);
              if (v != null) setState(() => _son = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('vardiya-duzenle-kaydet'),
          onPressed: _bekliyor ? null : _kaydet,
          child: Text(l10n.ortakKaydet),
        ),
      ],
    );
  }
}

/// Toplu cikarma onayi — sebep istege bagli (tekil cikarma ile ayni),
/// geri alinamayacagi ONCEDEN yazilir. Donus: vazgecildiyse null, aksi
/// halde (bos olabilir) sebep.
class TopluCikarDialogu extends StatefulWidget {
  const TopluCikarDialogu({super.key, required this.sayi});

  final int sayi;

  @override
  State<TopluCikarDialogu> createState() => _TopluCikarDialoguState();
}

class _TopluCikarDialoguState extends State<TopluCikarDialogu> {
  final _sebepCtrl = TextEditingController();

  @override
  void dispose() {
    _sebepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.vrdTopluCikar),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.vrdTopluCikarOnay(widget.sayi)),
          TextField(
            key: const Key('vardiya-toplu-sebep'),
            controller: _sebepCtrl,
            maxLength: 500, // sunucu: DELETE ?not_metni (500)
            decoration: InputDecoration(labelText: l10n.vardiyaCikarSebep),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('vardiya-toplu-onayla'),
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(_sebepCtrl.text.trim()),
          child: Text(l10n.vrdTopluCikar),
        ),
      ],
    );
  }
}
