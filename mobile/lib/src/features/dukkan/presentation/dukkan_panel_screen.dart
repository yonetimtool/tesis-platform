import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/dukkan_api.dart';
import 'dukkan_hata_govdesi.dart';
import '../data/dukkan_oturum.dart';

/// (DUKKAN F6-ek) ISLETME PANELI — MOBIL.
///
/// ===========================================================================
/// NEDEN VAR: BILDIRIMIN VARACAGI YER
/// ===========================================================================
/// Arz tarafinin dort bildirimi (`dukkan_yeni_talep`, `dukkan_is_verildi`,
/// `dukkan_isletme_onaylandi/reddedildi/askiya_alindi`) web'de
/// `/panel/{isletme_id}`e gidiyor. Mobilde bu ekran olmasaydi dordunun de
/// hedefi `null` olurdu: "yeni talep var" bildirimi gelir, dokunulur,
/// HICBIR SEY OLMAZDI. P211'de olculen kusurun aynisi.
///
/// ===========================================================================
/// UYARLAMA, KOPYA DEGIL
/// ===========================================================================
/// Web panelinde ALTI is var: profil duzenleme, hizmet alani secimi,
/// belge yukleme, telefon dogrulama, yorum daveti, gelen talepler.
/// Mobilde YALNIZ SONUNCUSU + durum var. Sebep: ilk besi masa basi,
/// tek seferlik kurulum isleri; gelen talebe teklif vermek ise SAHADA,
/// dakikalar icinde yapilmasi gereken is. Mobilin kazandirdigi sey o.
///
/// Eksik olanlar SESSIZCE atlanmiyor: ekranin altinda "digerleri
/// dukkan.yonetiyor.com'da" satiri var. Kullanicinin aramasina yol
/// acmak, eksigi soylememekten kotudur.
class DukkanPanelScreen extends ConsumerWidget {
  const DukkanPanelScreen({this.isletmeId, super.key});

  /// Push'tan gelindiyse dolu: O ISLETME dogrudan acilir. Bos ise
  /// kullanicinin isletme listesi gosterilir (birden fazla olabilir).
  final String? isletmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final liste = ref.watch(dukkanIsletmelerimProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanPanelBaslik)),
      body: liste.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (h, _) => DukkanHataGovdesi(
          hata: h,
          onYenile: () => ref.invalidate(dukkanIsletmelerimProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.dukkanIsletmenYok, textAlign: TextAlign.center),
              ),
            );
          }
          // PUSH'TAN GELINDIYSE O ISLETME. Bulunamazsa listeye dusuyoruz
          // (isletme silinmis/devredilmis olabilir) — hata ekrani
          // gostermek, kullaniciyi calisir durumdaki panelinden ederdi.
          final secili = isletmeId == null
              ? null
              : items.where((x) => x.id == isletmeId).firstOrNull;
          if (secili != null) return _IsletmeGovdesi(isletme: secili);
          if (items.length == 1) return _IsletmeGovdesi(isletme: items.first);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final x in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(x.ad),
                    subtitle: Text(_durumMetni(t, x)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(x.ad)),
                          body: _IsletmeGovdesi(isletme: x),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _durumMetni(AppLocalizations t, DukkanBenimIsletme x) => switch (x.durum) {
      'onayli' => t.dukkanDurumOnayli,
      'beklemede' => t.dukkanDurumBeklemede,
      // RED VE ASKI SEBEBI GOSTERILIYOR: "reddedildi" deyip sebebi
      // saklamak, kullaniciyi destege yazmaya mecbur birakirdi.
      'reddedildi' => x.redSebebi?.isNotEmpty == true
          ? '${t.dukkanDurumReddedildi}: ${x.redSebebi}'
          : t.dukkanDurumReddedildi,
      'askida' => x.askiSebebi?.isNotEmpty == true
          ? '${t.dukkanDurumAskida}: ${x.askiSebebi}'
          : t.dukkanDurumAskida,
      _ => t.dukkanDurumTaslak,
    };

class _IsletmeGovdesi extends ConsumerStatefulWidget {
  const _IsletmeGovdesi({required this.isletme});

  final DukkanBenimIsletme isletme;

  @override
  ConsumerState<_IsletmeGovdesi> createState() => _IsletmeGovdesiState();
}

class _IsletmeGovdesiState extends ConsumerState<_IsletmeGovdesi> {
  // DENETLEYICILER ALANDA, YEREL DEGIL: yerel olusturulsalardi her
  // teklif penceresinde bir tanesi daha dogar ve HICBIRI atilmazdi
  // (`denetleyici_atma_test.dart` bunu olcuyor). Alanda tutulup
  // `dispose`ta atiliyorlar.
  final _tutarKtrl = TextEditingController();
  final _mesajKtrl = TextEditingController();

  @override
  void dispose() {
    _tutarKtrl.dispose();
    _mesajKtrl.dispose();
    super.dispose();
  }

  Future<void> _teklifVer(DukkanGelenTalep talep) async {
    final t = AppLocalizations.of(context);
    // ONCEKI TEKLIFTEN KALAN METIN TEMIZLENIYOR: alan omurlu oldugu icin
    // ikinci talebe birincinin tutari on-dolu gelirdi.
    _tutarKtrl.clear();
    _mesajKtrl.clear();
    // MERKEZ DIYALOG: tum acilir pencereler ORTADAN acilir (P22a kilidi).
    final gonder = await merkezSayfaAc<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.dukkanTeklifVer,
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _tutarKtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.dukkanTeklifTutar,
                // BOS BIRAKMAK BIR SECENEK, EKSIK VERI DEGIL: usta
                // fiyati yerinde gormeden veremeyebilir. Ipucu bunu
                // soyluyor ki kullanici 0 yazmasin.
                helperText: t.dukkanTeklifTutarIpucu,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mesajKtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: t.dukkanTeklifMesaj),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.dukkanTeklifGonder),
            ),
          ],
        ),
      ),
    );
    if (gonder != true || !mounted) return;

    // KURUSA CEVIRME: kullanici LIRA yazar, sunucu KURUS bekler. Ham
    // sayiyi gondermek yuz kat dusuk teklif olurdu.
    final lira = double.tryParse(_tutarKtrl.text.trim().replaceAll(',', '.'));
    try {
      final jeton = await ref.read(dukkanOturumProvider).jetonAl();
      await ref.read(dukkanApiProvider).teklifVer(
            talepId: talep.id,
            isletmeId: widget.isletme.id,
            jeton: jeton,
            tutarKurus: lira == null ? null : (lira * 100).round(),
            mesaj: _mesajKtrl.text.trim(),
          );
      ref.invalidate(dukkanGelenTaleplerProvider(widget.isletme.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.dukkanTeklifGonderildi)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.dukkanTeklifHatasi)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isl = widget.isletme;
    final talepler = ref.watch(dukkanGelenTaleplerProvider(isl.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(isl.ad, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(_durumMetni(t, isl),
            style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 24),
        Text(t.dukkanGelenTalepler,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // ONAYSIZ ISLETMEDE LISTE HIC CEKILMIYOR: sunucu zaten 403
        // doner. Istegi atip hata gostermek yerine SEBEBI onceden
        // soylemek, kullaniciya yapacagi seyi anlatir.
        if (!isl.teklifVerebilir)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(t.dukkanOnaysizTeklifYok),
          )
        else
          talepler.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(t.dukkanListeAlinamadi),
            data: (items) {
              if (items.isEmpty) return Text(t.dukkanGelenTalepYok);
              return Column(
                children: [
                  for (final x in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x.baslik.isEmpty ? x.kategori : x.baslik,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('${x.mahalle} · ${x.ilce}',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Text(x.aciklama,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 10),
                            // ZATEN TEKLIF VERILMISSE DUGME YOK: sunucu
                            // ikinciyi 409 keser; kapali bir dugmeyi
                            // gostermek "neden calismiyor" sorusu uretir.
                            if (x.benimTeklifim != null)
                              Text(t.dukkanTeklifVerildi,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary))
                            else
                              FilledButton(
                                onPressed: () => _teklifVer(x),
                                child: Text(t.dukkanTeklifVer),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const Divider(height: 32),
        // (F8) REKLAM DURUMU — satin alma DEGIL.
        //
        // Bildirimler ("reklamin bitiyor", "odeme alinamadi") buraya
        // geliyor; varilacak yer olmasaydi bildirim islevsiz kalirdi
        // (P211/F6-ek dersi).
        Text(t.dukkanReklamBaslik,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref.watch(dukkanReklamlarimProvider(isl.id)).when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(t.dukkanListeAlinamadi),
              data: (items) {
                if (items.isEmpty) return Text(t.dukkanReklamYok);
                return Column(
                  children: [
                    for (final r in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          r.yayinda
                              ? Icons.campaign
                              : Icons.campaign_outlined,
                          color: r.yayinda
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text('${r.kategori} · ${r.bolge ?? "—"}'),
                        // BITISE KALAN GUN GORUNUR: "yayinda" demek
                        // yetmez, isletme yenileme kararini o sayiyla
                        // verir (ve otomatik yenileme YOK).
                        subtitle: Text(
                          r.yayinda && (r.kalanGun ?? 0) >= 0
                              ? t.dukkanReklamKalanGun(r.kalanGun ?? 0)
                              : t.dukkanReklamBitti,
                        ),
                      ),
                  ],
                );
              },
            ),
        const SizedBox(height: 12),
        // EKSIK OLANI SOYLE: kullanici profilini duzenlemeyi ya da
        // reklam satin almayi burada arayip bulamazsa, ekranin bozuk
        // oldugunu dusunur.
        Text(t.dukkanPanelWebNotu,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
