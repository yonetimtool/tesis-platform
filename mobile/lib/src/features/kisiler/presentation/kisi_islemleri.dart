import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../data/kisi_api.dart';

/// (P253 Asama 1) KISI ISLEMLERI — Kisiler'in uc sekmesinin (sakin,
/// personel, yonetici) ORTAK eylemleri. Web `kullanici-listesi.tsx` ile
/// ayni uclar: tanilama karti (`GET /users/{id}`), aktif/pasif ve
/// "Aranabilir" (`PATCH /users/{id}`), sil (`DELETE /users/{id}`).
///
/// Yikici her eylem KISININ ADINI tasiyan bir onaydan gecer.

/// Tanilama kartini merkez pencerede acar (kart icinde "Aranabilir"
/// degisebilir; cagiran kapaninca listesini tazeler).
Future<void> kisiKartiAc(BuildContext context, {required String id}) =>
    merkezSayfaAc<void>(context, builder: (_) => KisiKarti(id: id));

/// Aktif/pasif. PASIFLESTIRME onay ister (kisi adi yazili); aktiflestirme
/// geri donustur, sormaz. Degistiyse `true`.
Future<bool> kisiAktiflikDegistir(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String ad,
  required bool aktif,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!aktif) {
    final onay = await _onay(
      context,
      baslik: l10n.kisPasifBaslik,
      govde: l10n.kisPasifOnay(ad),
      dugme: l10n.personelPasiflestir,
      anahtar: 'kisi-pasif-onay',
    );
    if (!onay) return false;
  }
  try {
    await ref.read(kisiApiProvider).guncelle(id, aktif: aktif);
    messenger.showSnackBar(
      SnackBar(content: Text(aktif ? l10n.personelAktiflestirildi : l10n.personelPasiflestirildi)),
    );
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    return false;
  }
}

/// Sil — sunucu akilli siler (gecmisi varsa anonimlestirir). Onay metni
/// bunu ACIKCA soyler: "Pasiflestir" ayri ve geri alinabilir bir eylemdir.
Future<bool> kisiSilOnayli(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String ad,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final onay = await _onay(
    context,
    baslik: l10n.kisSilBaslik,
    govde: l10n.kisSilOnay(ad),
    dugme: l10n.ortakSil,
    anahtar: 'kisi-sil-onay',
  );
  if (!onay) return false;
  try {
    final silindi = await ref.read(kisiApiProvider).sil(id);
    messenger.showSnackBar(
      SnackBar(content: Text(silindi ? l10n.kisSilindi(ad) : l10n.kisAnonimlestirildi(ad))),
    );
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    return false;
  }
}

Future<bool> _onay(
  BuildContext context, {
  required String baslik,
  required String govde,
  required String dugme,
  required String anahtar,
}) async {
  final l10n = context.l10n;
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(baslik),
      content: Text(govde),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.ortakVazgec)),
        FilledButton(
          key: Key(anahtar),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(dugme),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}

/// (P253 Asama 1) KISI TANILAMA KARTI — "bildirim gitmiyor" sorusunun uc
/// olasi cevabi (kanal kapali, e-posta dogrulanmamis, cihaz yok) + kayit
/// durumu + odeme kodu. Tek yazilabilir alan "Aranabilir" (riza bayragi;
/// web duzenleme formundaki kutu).
class KisiKarti extends ConsumerStatefulWidget {
  const KisiKarti({super.key, required this.id});

  final String id;

  @override
  ConsumerState<KisiKarti> createState() => _KisiKartiState();
}

class _KisiKartiState extends ConsumerState<KisiKarti> {
  bool _mesgul = false;

  Future<void> _aranabilir(bool deger) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mesgul = true);
    try {
      await ref.read(kisiApiProvider).guncelle(widget.id, aranabilir: deger);
      ref.invalidate(kisiDetayProvider(widget.id));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    String acikKapali(bool? v) => (v ?? false) ? l10n.kisAcik : l10n.kisKapali;
    Widget satir(String etiket, String deger, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(etiket, style: TextStyle(color: ikincil)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              deger,
              key: key,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return ref
        .watch(kisiDetayProvider(widget.id))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakYuklenemedi),
          ),
          // Govde KENDI kaydirmasini tasir (merkez pencere dis kaydirma
          // eklemez — `merkez_diyalog.dart` kural 3).
          data: (k) => SingleChildScrollView(
            child: Padding(
              key: const Key('kisi-karti'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(k.ad, style: Theme.of(context).textTheme.titleMedium),
                  Text(rolAdi(l10n, UserRole.fromClaim(k.role)), style: TextStyle(color: ikincil)),
                  const SizedBox(height: 12),
                  satir(l10n.ortakDurum, k.isActive ? l10n.ortakAktif : l10n.ortakPasif),
                  if (k.email != null) satir(l10n.kisEposta, k.email!),
                  if (k.telefon != null) satir(l10n.ortakCepTelefonu, k.telefon!),
                  satir(l10n.kisKayitTamamlandi, acikKapali(k.kayitTamamlandi)),
                  const Divider(height: 24),
                  Text(l10n.kisTanilama, style: const TextStyle(fontWeight: FontWeight.w600)),
                  satir(l10n.kisTanilamaEposta, acikKapali(k.bildirimEposta)),
                  satir(l10n.kisTanilamaSms, acikKapali(k.bildirimSms)),
                  satir(l10n.kisTanilamaMobil, acikKapali(k.bildirimMobil)),
                  satir(l10n.kisTanilamaDogrulandi, acikKapali(k.epostaDogrulandi)),
                  satir(
                    l10n.kisTanilamaCihaz,
                    '${k.mobilCihazSayisi}',
                    key: const Key('kisi-cihaz-sayisi'),
                  ),
                  if (k.mobilCihazsiz)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.kisTanilamaCihazYok,
                        key: const Key('kisi-cihazsiz'),
                        style: TextStyle(color: ikincil, fontSize: 12),
                      ),
                    ),
                  if (k.odemeKodu != null) satir(l10n.kisOdemeKodu, k.odemeKodu!),
                  const Divider(height: 24),
                  SwitchListTile(
                    key: const Key('kisi-aranabilir'),
                    contentPadding: EdgeInsets.zero,
                    value: k.aranabilir,
                    onChanged: _mesgul ? null : _aranabilir,
                    title: Text(l10n.kisAranabilir),
                    subtitle: Text(l10n.kisAranabilirIpucu),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
