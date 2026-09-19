import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../data/kurulum_api.dart';
import 'ilk_giris_turu.dart';
import '../domain/kurulum_models.dart';

/// (P166 §8.2) KURULUM SIHIRBAZI — MOBIL.
///
/// =========================================================================
/// NEDEN VAR
/// =========================================================================
/// Sihirbaz P154'ten beri YALNIZ WEB'deydi. Brief'in kisiti acik: "web ve
/// mobil davranisi ayni olacak" — ve mobilde site kuran bir yonetici
/// nereden baslayacagini hicbir yerde goremiyordu.
///
/// =========================================================================
/// ADIMLAR VE ILERLEME SUNUCUDAN GELIR
/// =========================================================================
/// `GET /kurulum` web ile AYNI UCTUR. Adimlarin listesi, hangisinin
/// tamamlandigi ve ilerleme yuzdesi burada YENIDEN HESAPLANMAZ; hesaplansa
/// ayni tesis icin web ve mobil farkli sayilar gosterebilirdi.
///
/// =========================================================================
/// KENDI FORMLARINI CIZMEZ — VAR OLAN EKRANLARA YOLLAR
/// =========================================================================
/// Web'deki karar aynen gecerli: sekiz adimin ekranlari zaten var. Sihirbaz
/// icinde ikinci bir "blok ekle" formu yazmak, ayni dogrulamayi iki yerde
/// tutmak ve biri degistiginde otekini unutmak olurdu.
///
/// =========================================================================
/// CIKMAZ YOK — VE BIR ADIM ACIKCA ISARETLI
/// =========================================================================
/// `aidat` adiminin MOBILDE EKRANI YOK ve ucu (`POST /dues/assessments`)
/// zaten YALNIZ ADMIN'e acik (`rol-matrisi.txt`: yonetici RED). O adim
/// icin calismayan bir dugme cizmek yerine NEDENI yaziliyor. Kullaniciyi
/// yapamayacagi bir ise yollamamak, bu turun ana kuralidir.

/// Adim kodu -> (baslik, aciklama, gidilecek rota). Rota `null` ise adim
/// bu yuzeyden TAMAMLANAMAZ ve neden yazilir.
class _Hedef {
  const _Hedef(this.baslik, this.aciklama, this.rota);
  final String Function(AppLocalizations) baslik;
  final String Function(AppLocalizations) aciklama;
  final String? rota;
}

final Map<String, _Hedef> _hedefler = {
  'blok': _Hedef(
    (l) => l.kurulumBlok,
    (l) => l.kurulumBlokAlt,
    AppRoutes.binaDuzenleme,
  ),
  'daire': _Hedef(
    (l) => l.kurulumDaire,
    (l) => l.kurulumDaireAlt,
    AppRoutes.binaDuzenleme,
  ),
  'daire_tipi': _Hedef(
    (l) => l.kurulumDaireTipi,
    (l) => l.kurulumDaireTipiAlt,
    AppRoutes.daireTanimlari,
  ),
  'sakin': _Hedef(
    (l) => l.kurulumSakin,
    (l) => l.kurulumSakinAlt,
    AppRoutes.sakinler,
  ),
  'personel': _Hedef(
    (l) => l.kurulumPersonel,
    (l) => l.kurulumPersonelAlt,
    AppRoutes.personel,
  ),
  'gorev_alani': _Hedef(
    (l) => l.kurulumGorevAlani,
    (l) => l.kurulumGorevAlaniAlt,
    AppRoutes.taskCategories,
  ),
  'nfc_noktasi': _Hedef(
    (l) => l.kurulumNfc,
    (l) => l.kurulumNfcAlt,
    AppRoutes.checkpoints,
  ),
  // (P233 §1) KONUM — mobilde tesis ayarlari ekrani YOK (yonetim isi,
  // web yuzeyinde). Rota `null`: adim GORUNUR ama dokunulamaz; gizlemek,
  // mobilden bakan yoneticiye kurulumu TAMAM gostermek olurdu.
  'konum': _Hedef((l) => l.kurulumKonum, (l) => l.kurulumKonumAlt, null),
  // Bkz. sinif notu: mobilde ekrani yok + uc admin'e kilitli.
  'aidat': _Hedef((l) => l.kurulumAidat, (l) => l.kurulumAidatAlt, null),
};

class KurulumScreen extends ConsumerStatefulWidget {
  const KurulumScreen({super.key});

  @override
  ConsumerState<KurulumScreen> createState() => _KurulumScreenState();
}

class _KurulumScreenState extends ConsumerState<KurulumScreen> {
  /// Atlama istegi surerken hangi adim bekliyor — o satirin dugmesi kapanir.
  String? _bekleyen;
  String? _hata;

  Future<void> _atla(String kod, {required bool atla}) async {
    setState(() {
      _bekleyen = kod;
      _hata = null;
    });
    try {
      await ref.read(kurulumApiProvider).atla(kod, atla: atla);
      // Sunucu guncel durumu donuyor ama saglayiciyi tazelemek daha
      // dogru: ekranin TEK kaynagi kalir ve hatirlatici da ayni kaydi
      // okur (iki yerde iki farkli sayi olmaz).
      ref.invalidate(kurulumDurumProvider);
    } on ApiException catch (e) {
      // HATA SESSIZ KALMAZ: ekranda kalir, snackbar gibi kaybolmaz.
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _bekleyen = null);
    }
  }

  /// Baslik BU satirin onune mi gelir: `i` asgari-olmayan, bitmemis ve
  /// atlanmamis ILK adim mi. Baslik listede BIR KEZ cikar.
  bool _sonraBasligiBurada(List<KurulumAdim> adimlar, int i) {
    bool sonra(KurulumAdim a) => !a.asgari && !a.tamam && !a.atlandi;
    if (!sonra(adimlar[i])) return false;
    return !adimlar.take(i).any(sonra);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durum = ref.watch(kurulumDurumProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kurulumBaslik),
        actions: [
          // (P243 §6d) TANITIM TURUNU TEKRAR AC — "bir kez gosterilir"
          // ile "bir daha asla ulasilamaz" ayni sey degil. Yeri sihirbaz,
          // cunku "bana bastan anlat" isteyen kullanici buraya bakar.
          IconButton(
            onPressed: () => turuGoster(context, ref),
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.turTekrarAc,
          ),
        ],
      ),
      body: durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Hata(
          mesaj: e is ApiException ? e.message : l10n.kurulumHata,
          yenile: () => ref.invalidate(kurulumDurumProvider),
          tekrarEtiketi: l10n.ortakTekrarDene,
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(kurulumDurumProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.kurulumAlt, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              // (P243 §6a/§6f) YUZDE CUBUGU KALKTI, yerine ASGARI KART.
              //
              // OLCULEN KUSUR: 19 adimin 7'si "zorunlu"ydu (kasa,
              // gelir-gider tanimi ve aidat dahil) ve ilerleme cubugu
              // "%16" diyordu. Yeni bir yonetici, DUYURU YAPABILMEK icin
              // once muhasebe kurmasi gerektigini saniyordu. Cubuk,
              // yapilmamis her seyi bir borc gibi gosteriyordu.
              //
              // ESKI SUNUCU (`asgari_toplam == 0`) kart cizilmez: "0/0
              // hazır" anlamsiz bir sayac olurdu.
              if (d.asgariToplam > 0 && !d.calisir) _AsgariKart(durum: d, l10n: l10n),
              if (_hata != null) ...[
                const SizedBox(height: 12),
                Text(
                  _hata!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < d.adimlar.length; i++) ...[
                // (P243 §6b) "SUNLARI DA YAPABILIRSINIZ" BASLIGI — ilk
                // asgari-olmayan bitmemis adimin ONUNDE. Baslik bilincli
                // olarak sitem etmiyor: bu adimlar eksik degil, HENUZ
                // ACILMAMIS yeteneklerdir.
                if (_sonraBasligiBurada(d.adimlar, i))
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.kurulumSonraBaslik,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          l10n.kurulumSonraAlt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                _AdimKarti(
                  sira: i + 1,
                  adim: d.adimlar[i],
                  hedef: _hedefler[d.adimlar[i].kod],
                  bekliyor: _bekleyen == d.adimlar[i].kod,
                  onAtla: (atla) => _atla(d.adimlar[i].kod, atla: atla),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({
    required this.mesaj,
    required this.yenile,
    required this.tekrarEtiketi,
  });
  final String mesaj;
  final VoidCallback yenile;
  final String tekrarEtiketi;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mesaj, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: yenile, child: Text(tekrarEtiketi)),
        ],
      ),
    ),
  );
}

/// (P243 §6a) BASLAMAK ICIN GEREKENLER — sihirbazin ilk sozu.
///
/// Yuzde yerine "0/2 hazır": iki adimlik bir sayac bir sitem degil, bir
/// yol tarifidir. Tesis calisir duruma gelince kart HIC cizilmez.
class _AsgariKart extends StatelessWidget {
  const _AsgariKart({required this.durum, required this.l10n});
  final KurulumDurum durum;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tamam = durum.asgariToplam - durum.asgariEksikler.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.kurulumAsgariBaslik,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  l10n.kurulumAsgariSayac(tamam, durum.asgariToplam),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.kurulumAsgariAlt,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final kod in durum.asgariEksikler)
              if (_hedefler[kod] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '• ${_hedefler[kod]!.baslik(l10n)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AdimKarti extends StatelessWidget {
  const _AdimKarti({
    required this.sira,
    required this.adim,
    required this.hedef,
    required this.bekliyor,
    required this.onAtla,
  });

  final int sira;
  final KurulumAdim adim;
  final _Hedef? hedef;
  final bool bekliyor;
  final void Function(bool atla) onAtla;

  @override
  Widget build(BuildContext context) {
    final h = hedef;
    if (h == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final renkler = Theme.of(context).colorScheme;
    final durumMetni = adim.tamam
        ? l10n.kurulumAdimTamam(adim.sayi)
        : adim.atlandi
        ? l10n.kurulumAdimAtlandi
        : l10n.kurulumAdimBekliyor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SAYI DA ROZET DE ANLAM TASIR: yalniz renk kullanmak,
                // renk ayirt edemeyen kullanici icin bilgiyi silerdi.
                CircleAvatar(
                  radius: 14,
                  backgroundColor: adim.tamam
                      ? renkler.primaryContainer
                      : renkler.surfaceContainerHighest,
                  child: adim.tamam
                      ? Icon(Icons.check, size: 16, color: renkler.onPrimaryContainer)
                      : Text('$sira', style: Theme.of(context).textTheme.labelMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.baslik(l10n),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        durumMetni,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        h.aciklama(l10n),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (h.rota == null)
              // CIKMAZ YERINE ACIKLAMA: calismayacak bir dugme cizmek,
              // kullaniciyi denemeye ve basarisiz olmaya zorlamakti.
              Text(
                l10n.kurulumAdimWebde,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: renkler.onSurfaceVariant,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ATLAMA yalniz BITMEMIS adimda anlamli.
                  if (!adim.tamam)
                    TextButton(
                      onPressed: bekliyor ? null : () => onAtla(!adim.atlandi),
                      child: Text(
                        adim.atlandi
                            ? l10n.kurulumAtlamayiGeriAl
                            : l10n.kurulumAtla,
                      ),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => context.push(h.rota!),
                    child: Text(
                      adim.tamam ? l10n.kurulumGoruntule : l10n.kurulumGit,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
