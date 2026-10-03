import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/liste_ekrani.dart';
import '../../../core/ui/olustur_paylas.dart';
import '../data/makbuz_api.dart';
import '../domain/makbuz_models.dart';

/// (P253 A1) MAKBUZLARIM — sakinin makbuz arsivi + PDF paylas.
///
/// Web sakin modundaki makbuz listesinin ikizi. PDF uygulamada
/// GOSTERILMEZ: telefona iner ve sistemin paylas menusune verilir
/// (kaydet, e-posta, mesaj — kullanicinin bildigi araclar).
class MakbuzlarScreen extends ConsumerWidget {
  const MakbuzlarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final api = ref.read(makbuzApiProvider);
    return ListeEkrani<Makbuz>(
      baslik: l10n.mkbBaslik,
      kimlik: (m) => m.id,
      sayfaBoyu: 50,
      bosMetin: (l) => l.mkbBos,
      yukle: (s) async {
        final (ogeler, toplam) = await api.liste(offset: s.offset, limit: s.limit);
        return ListeSayfasi(ogeler, toplam: toplam);
      },
      kart: (context, m, _) => ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(l10n.mkbBelge(m.belgeNo)),
        subtitle: Text(tarihBicimi(m.createdAt, context.dilKodu)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tlSonEkli(m.tutarKurus, context.dilKodu),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            // Dugmenin KENDI baglami: paylas menusunun cikis noktasi (iPad).
            Builder(builder: (context) => IconButton(
              key: Key('mkb-paylas-${m.id}'),
              tooltip: m.pdfUrl == null ? l10n.mkbPdfYok : l10n.mkbPaylas,
              icon: const Icon(Icons.ios_share),
              onPressed: m.pdfUrl == null
                  ? null
                  : () => olusturVePaylas(
                        context,
                        konu: l10n.mkbBelge(m.belgeNo),
                        olustur: () async => PaylasimDosyasi(
                          baytlar: await api.pdf(m.pdfUrl!),
                          dosyaAdi: 'makbuz-${m.belgeNo}.pdf',
                          mimeTuru: makbuzMimeTuru,
                        ),
                      ),
            )),
          ],
        ),
      ),
    );
  }
}
