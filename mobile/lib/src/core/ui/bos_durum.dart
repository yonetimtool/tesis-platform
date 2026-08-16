import 'package:flutter/material.dart';

/// (P166 §10) BOS DURUM — ikon + aciklama + CAGRI DUGMESI.
///
/// =========================================================================
/// NEDEN ORTAK BIR BILESEN
/// =========================================================================
/// Depoda bes ayri `_Empty` / `_EmptyState` sinifi vardi ve besi de AYNI
/// seyi ciziyordu: ortada bir ikon, altinda gri bir cumle. Besinde de
/// EKSIK OLAN ayniydi — bir sonraki adim. Kullanici "Henuz kontrol noktasi
/// yok" cumlesini okuyor ve orada kaliyordu; ekleme yolu ya sag ustteki
/// etiketsiz bir ikondu ya da ekranin dibindeki bir dugme.
///
/// Ayni bosluk bes yerde ayri ayri doldurulsaydi altincida yine
/// unutulurdu.
///
/// =========================================================================
/// NEDEN CAGRI DUGMESI, "sag ustteki ikonu buyut" DEGIL
/// =========================================================================
/// Bos durum, kullanicinin ekranda BAKTIGI yerdir: liste yok, gozu ortaya
/// duser. Eylemi oraya koymak onu ARAMAYA gerek birakmaz. Sag ust kose ise
/// gozun EN SON gittigi yerdir ve orada bir ikon, adini ancak uzun basinca
/// soyler — yani cogu kullanici ozelligin VARLIGINI ogrenmez.
///
/// DUGME KOSULLUDUR: yetkisi olmayan kullaniciya "Ekle" gostermek, ona
/// 403 ile bitecek bir yol acmakti. `eylem` verilmezse yalniz aciklama
/// cizilir.
class BosDurum extends StatelessWidget {
  const BosDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    this.aciklama,
    this.eylemEtiketi,
    this.onEylem,
    this.eylemIkonu,
  });

  final IconData ikon;

  /// Ne olmadigini soyleyen kisa cumle ("Henuz kontrol noktasi yok").
  final String baslik;

  /// Istege bagli ikinci satir — NE ISE YARADIGINI anlatir. Bos bir liste
  /// karsisindaki kullanici cogu zaman ozelligin NE OLDUGUNU da bilmiyor.
  final String? aciklama;

  final String? eylemEtiketi;
  final VoidCallback? onEylem;
  final IconData? eylemIkonu;

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;
    final dugmeVar = onEylem != null && eylemEtiketi != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: renkler.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (aciklama != null) ...[
              const SizedBox(height: 6),
              Text(
                aciklama!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: renkler.onSurfaceVariant),
              ),
            ],
            if (dugmeVar) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onEylem,
                icon: Icon(eylemIkonu ?? Icons.add),
                label: Text(eylemEtiketi!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
