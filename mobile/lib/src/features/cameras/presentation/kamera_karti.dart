import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../../home/presentation/widgets/home_card.dart';
import '../domain/camera_models.dart';
import 'kamera_karesi.dart';

/// Kamera karti — ONAYLANMIS ana ekran dilinde: 16:10 gri yer tutucu + ortada
/// yari saydam oynat butonu, altinda ad, konum ve durum satiri.
///
/// TEK kart iki yerde kullanilir: ana ekranin "Canlı Kamera" seridi (sabit
/// genislik) ve Kameralar ekranindaki 2'li izgara (genislik disaridan). Kart
/// icinde VIDEO OYNATILMAZ — kare yer tutucudur, dokunma disariya birakilir.
///
/// `oynatilabilir=false` (RTSP): oynat butonu YERINE ustu cizili kamera
/// ikonu + "Oynatılamıyor" rozeti; dokunma oynatici degil bilgi karti acar
/// (cagiran katman karar verir).
class KameraKarti extends StatefulWidget {
  const KameraKarti({
    super.key,
    required this.kamera,
    required this.onTap,
    this.width,
    this.nesil,
    this.gorselYapici,
  });

  final Camera kamera;
  final VoidCallback onTap;

  /// Serit icin sabit genislik; izgarada null (hucre genisligi kullanilir).
  final double? width;

  /// (P121) Kare tazeleme nesli. `null` ise kare CEKILMEZ — ana ekran
  /// seridi bilerek boyle: serit kaydirilarak gecilen bir bolumdur ve
  /// orada periyodik istek atmak, ana ekrani her acan kullaniciya bedel
  /// yuklerdi. Kare YALNIZ Kameralar izgarasinda tazelenir.
  final int? nesil;

  /// TESTTE gorsel uretimini degistirir (bkz. [KameraKaresi]).
  @visibleForTesting
  final Widget Function(String adres)? gorselYapici;

  @override
  State<KameraKarti> createState() => _KameraKartiState();
}

class _KameraKartiState extends State<KameraKarti> {
  /// Ekranda GERCEKTEN tazelenen bir kare var mi (rozet karari).
  bool _kareAkiyor = false;

  @override
  Widget build(BuildContext context) {
    final kamera = widget.kamera;
    final nesil = widget.nesil;
    final s = HomeSurface.of(context);
    final oynar = kamera.oynatilabilir;
    final yerTutucu = Container(
      color: s.placeholder,
      child: Center(
        child: oynar
            ? const _OynatButonu()
            : Icon(Icons.videocam_off_outlined, color: s.muted, size: 26),
      ),
    );
    return HomeCard(
      width: widget.width,
      padding: const EdgeInsets.all(8),
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: nesil == null
                  ? yerTutucu
                  : KameraKaresi(
                      kamera: kamera,
                      nesil: nesil,
                      yerTutucu: yerTutucu,
                      gorselYapici: widget.gorselYapici,
                      onKareDurumu: (akiyor) {
                        if (mounted && akiyor != _kareAkiyor) {
                          setState(() => _kareAkiyor = akiyor);
                        }
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kamera.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.cardTitle.copyWith(color: s.heading),
          ),
          if (kamera.konum != null && kamera.konum!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              kamera.konum!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.rowSub.copyWith(color: s.muted),
            ),
          ],
          const SizedBox(height: 3),
          // ROZET UC HALI AYIRIR ve hicbirinde YALAN SOYLEMEZ:
          //
          //  * kare ADRESI VAR ve kareler AKIYOR -> yesil "Canlı". Ekranda
          //    gercekten SU ANIN goruntusu var.
          //  * kare adresi var ama AKMIYOR -> soluk "Görüntü alınamıyor".
          //    Ekranda bayat bir kare durabilir; ona "canlı" demek, guvenlik
          //    gorevlisi icin "su an boyle" ile "en son boyleydi" arasindaki
          //    farki silmek olurdu — bu ekranin tek isi o fark.
          //  * kare adresi YOK (bugunku durum; Frigate P17'de dolduracak)
          //    -> DAVRANIS DEGISMEZ: eskisi gibi yesil "Canlı", cunku burada
          //    "canlı" YAYININ canliligini anlatir, karonun degil.
          if (kamera.kareCekilebilir && nesil != null)
            _DurumSatiri(
              metin: _kareAkiyor
                  ? context.l10n.kameraCanli
                  : context.l10n.kameraKareYok,
              renk: _kareAkiyor ? HomeTokens.green : s.muted,
              nokta: _kareAkiyor,
            )
          else if (oynar)
            Row(
              children: [
                const HomeDot(color: HomeTokens.online, size: 7),
                const SizedBox(width: 5),
                // DAR KARTA DAYANIKLI (P25c): serit karti artik ekrandan
                // hesaplanir ve dar telefonda ~83 dp'ye duser. Cipsiz `Text`
                // dogal genisligini isterdi ve "• Canlı" satiri TASARDI —
                // Arapca/Rusca gibi uzun cevirilerde daha da erken.
                Flexible(
                  child: Text(
                    context.l10n.kameraCanli,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.rowSub.copyWith(color: HomeTokens.green),
                  ),
                ),
              ],
            )
          else
            // Sunucu RTSP'yi oynatilamaz isaretledi — kart LISTEDE KALIR,
            // yalniz beklenti dogru kurulur (sessizce kaybolmaz).
            Text(
              context.l10n.kameraOynatilamiyor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.rowSub.copyWith(color: s.muted),
            ),
        ],
      ),
    );
  }
}

/// Yari saydam siyah daire + beyaz ucgen — yer tutucunun oynat butonu.
class _OynatButonu extends StatelessWidget {
  const _OynatButonu();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0x8C000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
    );
  }
}

/// Kamera dokunmasinin TEK kurali: oynatilabilir → oynatici, degilse bilgi
/// karti. Ana ekran seridi ve Kameralar izgarasi ayni fonksiyonu cagirir.
typedef KameraAcici = void Function(Camera kamera);


/// Karo durum satiri — nokta + metin (dar kartta tasmaz).
class _DurumSatiri extends StatelessWidget {
  const _DurumSatiri({
    required this.metin,
    required this.renk,
    required this.nokta,
  });

  final String metin;
  final Color renk;
  final bool nokta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (nokta) ...[
          const HomeDot(color: HomeTokens.online, size: 7),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            metin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.rowSub.copyWith(color: renk),
          ),
        ),
      ],
    );
  }
}
