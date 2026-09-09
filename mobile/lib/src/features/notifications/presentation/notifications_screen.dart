import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../home/presentation/widgets/activity_row.dart';
import '../data/notifications_controller.dart';
import '../domain/notification_models.dart';
import 'bildirim_rotasi.dart';

const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);
const _navy = Color(0xFF0E3C91);

/// Bildirimler inbox'i (yonetici + guvenlik; RBAC sakin/tesis gorevlisine
/// kapali). Liste en-yeni-ustte; okunmamis satirda "Yeni" rozeti.
///
/// DOKUNMA (P22b): okundu isaretler VE bildirimin isaret ettigi ekrani ACAR.
/// Eskiden dokunma yalnizca okundu isaretliyordu, okunmus satirda ise HICBIR
/// SEY yapmiyordu (olu dokunma). Okunmus satirda PATCH yine uretilmez —
/// yalniz yonlendirme yapilir.
/// (P220 §2) SECIM MODU: "Sec" DUGMESI + UZUN BASMA KISAYOLU.
///
/// ===========================================================================
/// NEDEN YALNIZ UZUN BASMA DEGIL
/// ===========================================================================
/// Uzun basma Android'in liste coklu-secim gelenegidir ve varsayilan
/// listeyi temiz birakir. Ama TEK BASINA yanlis olurdu:
///
///   * KESFEDILEMEZ. Bu uygulamanin kullanicilari site yoneticileri ve
///     guvenlik gorevlileri; "uzun bas" hicbir yerde YAZMIYOR. Web'de
///     toplu islem seridi GORUNUYOR, mobilde gizli olsaydi ozellik
///     ikinci yuzeyde fiilen YOK sayilirdi.
///   * ERISILEBILIRLIK. Uzun basma, motor gucluk yasayan kullanicida ve
///     ekran okuyucuda zayif calisir; gorunur bir dugme ikisinde de
///     calisir.
///
/// Bu yuzden IKISI BIRDEN: baslikta gorunur "Sec" dugmesi (birincil,
/// kesfedilebilir) ve uzun basma (bilenler icin kisayol). Ikisi ayni
/// modu aciyor.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  bool _secimModu = false;
  final Set<String> _secili = {};
  bool _islemde = false;
  final _aramaKtrl = TextEditingController();

  /// (P220 §3) ARAMA GECIKMESI — web ile AYNI (300 ms).
  ///
  /// Her tusa basista sunucuya gitmek iki soruna yol acardi: gereksiz
  /// yuk ("kargo" yazmak bes istek) ve TITREYEN LISTE (her yanitta
  /// yeniden cizim, kullanici yazarken ekran altinda kayiyor).
  ///
  /// Web'de `useGecikmeli` ayni isi ayni sureyle yapiyor; iki yuzeyin
  /// farkli davranmasi, ayni ozelligin birinde akici otekinde takilarak
  /// calismasi olurdu.
  Timer? _aramaZamanlayici;

  @override
  void dispose() {
    _aramaZamanlayici?.cancel();
    _aramaKtrl.dispose();
    super.dispose();
  }

  void _aramaDegisti(String v) {
    _secimiKapat();
    _aramaZamanlayici?.cancel();
    _aramaZamanlayici = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(bildirimSuzgeciProvider.notifier).ara(v);
    });
  }

  void _secimiKapat() {
    setState(() {
      _secimModu = false;
      _secili.clear();
    });
  }

  void _secimiAc(String? ilkId) {
    setState(() {
      _secimModu = true;
      if (ilkId != null) _secili.add(ilkId);
    });
  }

  void _tekiliDegistir(String id) {
    setState(() {
      if (!_secili.remove(id)) _secili.add(id);
    });
  }

  /// Ortak toplu-islem sarmali: cagir, secimi kapat, sonucu SOYLE.
  ///
  /// SONUC SAYISI GOSTERILIYOR: "islem tamam" demek, hicbir satir
  /// etkilenmediginde de ayni seyi soylerdi (P217 dersi — "Kaydedildi"
  /// yazip sifir kayit uretmek).
  Future<void> _topluCalistir(
    Future<int> Function() islem,
    String Function(int) mesaj,
  ) async {
    setState(() => _islemde = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await islem();
      _secimiKapat();
      messenger.showSnackBar(SnackBar(content: Text(mesaj(n))));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.bildirimTopluBasarisiz)),
      );
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  /// Silme ONAY ISTER — web'de istemiyor ve fark BILINCLI.
  ///
  /// DAVRANIS AYNI: sunucuda yumusak silme, arayuzden GERI ALINAMAZ
  /// (web'de de oyle; geri yukleme ucu yok). Degisen sey AFFORDANS:
  /// dokunmatik ekranda yanlislikla basma olasiligi fareyle tiklamaya
  /// gore cok daha yuksek ve secili satirlar ekranda gorunmuyor
  /// olabilir. Onay, geri alinamaz bir islemin onune konan tek koruma.
  Future<void> _silOnayla() async {
    final t = context.l10n;
    final onay = await merkezSayfaAc<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.bildirimSilOnayBaslik(_secili.length),
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t.bildirimSilOnayMetin),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t.ortakVazgec),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t.ortakSil),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (onay != true) return;
    final idler = _secili.toList();
    await _topluCalistir(
      () => ref.read(notificationsProvider.notifier).topluSil(idler),
      (n) => context.l10n.bildirimSilindiSayi(n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(notificationsProvider);
    final suzgec = ref.watch(bildirimSuzgeciProvider);
    final items = async.value ?? const <AppNotification>[];
    final tumuSecili =
        items.isNotEmpty && items.every((n) => _secili.contains(n.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(_secimModu
            ? t.bildirimSeciliSayi(_secili.length)
            : t.sekmeBildirimler),
        leading: _secimModu
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: t.ortakVazgec,
                onPressed: _secimiKapat,
              )
            : null,
        actions: _secimModu
            ? [
                IconButton(
                  tooltip: tumuSecili
                      ? t.bildirimSecimiTemizle
                      : t.bildirimTumunuSec,
                  icon: Icon(tumuSecili
                      ? Icons.deselect
                      : Icons.select_all),
                  onPressed: () => setState(() {
                    if (tumuSecili) {
                      _secili.clear();
                    } else {
                      _secili
                        ..clear()
                        ..addAll(items.map((n) => n.id));
                    }
                  }),
                ),
              ]
            : [
                // GORUNUR GIRIS: uzun basma tek basina kesfedilemezdi.
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () => _secimiAc(null),
                    child: Text(t.bildirimSec),
                  ),
                // TUMUNU OKUNDU yalniz OKUNMAMIS sekmesinde anlamli.
                if (!suzgec.okundu && items.isNotEmpty)
                  IconButton(
                    tooltip: t.bildirimTumunuOkundu,
                    icon: const Icon(Icons.done_all),
                    onPressed: _islemde
                        ? null
                        : () => _topluCalistir(
                              () => ref
                                  .read(notificationsProvider.notifier)
                                  .tumunuOkundu(),
                              (n) => t.bildirimOkunduSayi(n),
                            ),
                  ),
              ],
      ),
      body: Column(
        children: [
          // (P220 §3) IKI SEKME — varsayilan OKUNMAMIS.
          _Sekmeler(
            okundu: suzgec.okundu,
            onDegis: (v) {
              _secimiKapat();
              ref.read(bildirimSuzgeciProvider.notifier).sekme(v);
            },
          ),
          // (P220 §3) ARAMA — HER IKI SEKMEDE.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _aramaKtrl,
              onChanged: _aramaDegisti,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: t.bildirimAraIpucu,
                // ASGARI UZUNLUK SOYLENIYOR: tek harf yazip sonuc
                // gelmeyince kullanici aramanin bozuk oldugunu sanardi.
                helperText: suzgec.arama.trim().isNotEmpty &&
                        !suzgec.aramaGecerli
                    ? t.bildirimAraAsgari
                    : null,
                suffixIcon: suzgec.arama.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          // TEMIZLEME GECIKMESIZ: kullanici acikca
                          // "hepsini goster" diyor, beklemesi anlamsiz.
                          _aramaZamanlayici?.cancel();
                          _aramaKtrl.clear();
                          ref.read(bildirimSuzgeciProvider.notifier).ara('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              data: (items) => items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          suzgec.aramaGecerli
                              ? t.bildirimAramaSonucYok
                              : t.bildirimYok,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(notificationsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _NotificationRow(
                          bildirim: items[i],
                          secimModu: _secimModu,
                          secili: _secili.contains(items[i].id),
                          onSecimDegis: () => _tekiliDegistir(items[i].id),
                          onUzunBas: () => _secimiAc(items[i].id),
                        ),
                      ),
                    ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.l10n.bildirimYuklenemedi('$e'),
                      textAlign: TextAlign.center),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      // TOPLU EYLEM SERIDI: yalniz secim modunda ve seçim VARKEN.
      bottomNavigationBar: _secimModu && _secili.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _islemde
                            ? null
                            : () {
                                final idler = _secili.toList();
                                _topluCalistir(
                                  () => ref
                                      .read(notificationsProvider.notifier)
                                      .topluOkundu(idler),
                                  (n) => t.bildirimOkunduSayi(n),
                                );
                              },
                        icon: const Icon(Icons.done),
                        label: Text(t.bildirimSeciliOkundu),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: _red),
                        onPressed: _islemde ? null : _silOnayla,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(t.bildirimSeciliSil),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// Iki sekme: OKUNMAMIS (varsayilan) / OKUNMUS.
class _Sekmeler extends StatelessWidget {
  const _Sekmeler({required this.okundu, required this.onDegis});

  final bool okundu;
  final ValueChanged<bool> onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(t.bildirimOkunmamis)),
          ButtonSegment(value: true, label: Text(t.bildirimOkunmus)),
        ],
        selected: {okundu},
        onSelectionChanged: (s) => onDegis(s.first),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({
    required this.bildirim,
    this.secimModu = false,
    this.secili = false,
    this.onSecimDegis,
    this.onUzunBas,
  });

  final AppNotification bildirim;

  /// (P220 §2) Secim modunda satir DAVRANISI DEGISIR: dokunma artik
  /// bildirimi acmaz, secer. Ayni dokunusun iki farkli sonucu olmasi
  /// karisik gorunebilir ama alternatifi (secim modunda da acmak)
  /// kullanicinin secim yaparken ekrandan cikmasi olurdu.
  final bool secimModu;
  final bool secili;
  final VoidCallback? onSecimDegis;
  final VoidCallback? onUzunBas;

  /// Alarm tipleri kirmizi, gecikmeler amber, geri kalan navy.
  Color get _accent => switch (bildirim.tip) {
        'kacirilan_tur' || 'eksik_checkpoint' => _red,
        'gecikmis_okutma' => _amber,
        _ => _navy,
      };

  IconData get _icon => switch (bildirim.tip) {
        'kacirilan_tur' => Icons.directions_walk,
        'eksik_checkpoint' || 'gecikmis_okutma' => Icons.location_on_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = bildirim.createdAt?.toLocal();
    final zaman = t == null
        ? ''
        : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        if (secimModu)
          Checkbox(
            value: secili,
            onChanged: (_) => onSecimDegis?.call(),
            // Ekran okuyucu icin: satirin kendisi de dokunulabilir ama
            // kutunun ne oldugu ADIYLA soylenmeli.
            semanticLabel: bildirim.mesaj,
          ),
        Expanded(
          child: ActivityRow(
            icon: _icon,
            title: bildirim.mesaj,
            subtitle: bildirim.tip.replaceAll('_', ' '),
            time: zaman,
            accent: _accent,
            // UZUN BASMA = SECIM MODU KISAYOLU. Gorunur "Sec" dugmesi
            // birincil giris; bu, bilenler icin ikinci yol.
            //
            // `ActivityRow`un KENDI `InkWell`ine veriliyor: sarmalayici
            // bir `GestureDetector` klavyeyle ULASILAMAZ olurdu ve
            // `klavye_kaynak_denetimi_test.dart` ilk yazimda tam bunu
            // yakaladi.
            onLongPress: secimModu ? null : onUzunBas,
            onTap: () {
              if (secimModu) {
                onSecimDegis?.call();
                return;
              }
              // Okunmamissa okundu isaretle (iyimser); okunmusa PATCH YOK.
              if (!bildirim.okundu) {
                ref
                    .read(notificationsProvider.notifier)
                    .markRead(bildirim.id);
              }
              // Hedefi olan bildirim ilgili ekrani acar; hedefi yoksa
              // dokunma yalnizca okundu isaretlemis olur.
              final rota = bildirimRotasi(bildirim);
              if (rota != null) context.push(rota);
            },
          ),
        ),
        if (!bildirim.okundu)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.l10n.cipYeni,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _accent, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
