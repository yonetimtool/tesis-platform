import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/kvkk_api.dart';
import '../domain/kvkk_models.dart';
import '../../../core/widgets/zengin_govde.dart';

/// (P168 §5) YASAL METINLER — sakinin okuma ve ONAY GECMISI ekrani.
///
/// =========================================================================
/// NEDEN AYRI BIR EKRAN, NEDEN MEVCUT `kvkk_metin_screen` DEGIL
/// =========================================================================
/// `KvkkMetinScreen` TEK metni (aydinlatma) gosterir ve ONAY KAPISININ
/// parcasidir — "neyi onayladim" sorusunu yanitlar. Brief ise bes metnin
/// tamamina erisim ve ONAY GECMISI istiyor.
///
/// O ekrani genisletmek, onay kapisinin akisina bir sekme cubugu sokmak
/// olurdu: kapiya takilan kullanici onaylamasi gereken metni ararken bes
/// sekme arasinda dolasirdi.
///
/// =========================================================================
/// ONAY BURADA ALINMAZ
/// =========================================================================
/// Bu ekran SALT OKUMADIR. Onay, kapinin kendi ekranindan alinir
/// (`KvkkOnayScreen`): iki ayri yerde onay almak, "hangi ekranda ne
/// onayladim" sorusunu dogurur ve kaydirma kapisi (`kaydirma_kapisi`)
/// gibi bilincli surtunmeleri atlatan ikinci bir yol acardi.
///
/// Gosterilen sey: metnin kendisi + KULLANICININ hangi surumu onayladigi.
class YasalMetinlerScreen extends ConsumerStatefulWidget {
  const YasalMetinlerScreen({super.key});

  @override
  ConsumerState<YasalMetinlerScreen> createState() =>
      _YasalMetinlerScreenState();
}

class _YasalMetinlerScreenState extends ConsumerState<YasalMetinlerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: KvkkTur.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _turAdi(BuildContext context, KvkkTur tur) {
    final l10n = context.l10n;
    return switch (tur) {
      KvkkTur.aydinlatma => l10n.kvkkTurAydinlatma,
      KvkkTur.acikRiza => l10n.kvkkTurAcikRiza,
      KvkkTur.gizlilik => l10n.kvkkTurGizlilik,
      KvkkTur.kullanimKosullari => l10n.kvkkTurKullanim,
      KvkkTur.cerez => l10n.kvkkTurCerez,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kvkkYasalMetinler),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: [
            for (final tur in KvkkTur.values) Tab(text: _turAdi(context, tur)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [for (final tur in KvkkTur.values) _Metin(tur: tur)],
      ),
    );
  }
}

class _Metin extends ConsumerWidget {
  const _Metin({required this.tur});

  final KvkkTur tur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final metin = ref.watch(kvkkTurMetinProvider(tur));
    final durum = ref.watch(kvkkTurDurumProvider(tur));

    return metin.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        // METIN YAYINLANMAMIS OLABILIR (404) ve bu bir HATA DEGIL:
        // tesis o metni henuz yayinlamamistir. Kirmizi bir hata
        // gostermek, kullaniciya uygulamanin bozuk oldugunu soylerdi.
        final yok = e is ApiException && e.statusCode == 404;
        return _Bos(
          mesaj: yok
              ? l10n.kvkkMetinYayinlanmamis
              : (e is ApiException
                  ? apiHataMetni(l10n, e)
                  : akisHataMetni(l10n, AkisHatasi.beklenmeyen)),
        );
      },
      data: (m) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(m.baslik, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          // SURUM HER ZAMAN GORUNUR: "hangi metni okuyorum" sorusu,
          // onay gecmisiyle karsilastirilabilir olmali.
          Text(
            l10n.kvkkSurumEtiketi(m.surum),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // ONAY GECMISI — brief'in acik istegi.
          durum.maybeWhen(
            data: (d) => _OnayOzeti(durum: d),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),
          // (P171) ZENGIN METIN OLARAK CIZILIR.
          //
          // ONCEDEN duz yazi ciziliyordu ve gerekcesi dogruydu: govde
          // temizlenmemisti, HTML'i yorumlamak yoneticinin yazdigi
          // isaretlemeyi CALISTIRMAK olurdu. Ama bedeli, kullanicinin
          // metnin ORTASINDA ham `<h2>`/`<li>` etiketleri gormesiydi.
          //
          // Kosul artik saglandi: sunucu govdeyi YAZMA ANINDA beyaz
          // listeyle temizliyor (`backend/app/temizleme.py`) ve mevcut
          // satirlar onarim gocuyle (0066) temizlendi.
          ZenginGovde(m.govde),
        ],
      ),
    );
  }
}

class _OnayOzeti extends StatelessWidget {
  const _OnayOzeti({required this.durum});

  final KvkkDurum durum;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onaylanan = durum.onayladigiSurum;
    // ONAY YOKSA "onaylanmadi" DENIR, bos birakilmaz: bos bir alan
    // kullaniciya onayladigini dusundurebilirdi.
    final metin = onaylanan == null
        ? l10n.kvkkOnaylanmadi
        : l10n.kvkkOnayladiginizSurum(onaylanan);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          onaylanan == null ? Icons.info_outline : Icons.verified_outlined,
        ),
        title: Text(metin),
        subtitle: durum.onayGerekli
            ? Text(l10n.kvkkYenidenOnayBekleniyor)
            : null,
      ),
    );
  }
}

class _Bos extends StatelessWidget {
  const _Bos({required this.mesaj});

  final String mesaj;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(mesaj, textAlign: TextAlign.center),
      ),
    );
  }
}
