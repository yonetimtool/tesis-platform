/// (P121) IZGARA KAROSUNUN DURAĞAN KARESİ — oynatıcı açmadan canlı görüntü.
///
/// NEDEN VİDEO DEĞİL: bir ızgarada N video oynatıcıyı otomatik oynatmak
/// pil/ısı/bant genişliği açısından pahalıdır ve iOS eşzamanlı `AVPlayer`
/// sayısını **sınırlar** — altıncı-yedinci karo sessizce siyah kalırdı.
///
/// NEDEN HLS'TEN KARE YAKALANMIYOR (ölçüldü, yol REDDEDİLDİ):
///   1. **Bant genişliği.** HLS'te kare seviyesinde erişim yoktur; en küçük
///      birim bir PARÇADIR. Tohumlanan yayında ölçüldü: ilk parça
///      **1.87 MiB / 10 sn**. Altı kamerayı 8 sn'de bir tazelemek ≈ **4 GiB
///      /saat** eder — yani kaçındığımız şeyden (videoyu sürekli oynatmak)
///      daha pahalıdır. "Ucuz küçük resim" fikri burada çöküyor.
///   2. **Teknik olarak da mümkün değil.** `video_player` kareyi bir
///      `Texture` katmanına verir (`avfoundation_video_player.dart:307`
///      → `Texture(textureId: …)`); dış doku motor tarafından
///      birleştirilir ve `RepaintBoundary.toImage()` ile **yakalanamaz**
///      (paket bir `toImage`/anlık görüntü API'si de sunmuyor — arandı,
///      yok). Yani yol yalnız pahalı değil, kapalı.
/// Bu yüzden kare kaynağı sırası: (a) `snapshot_url`, (c) yer tutucu.
/// Ortadaki (b) şıkkı ölçüm sonucu düştü.
///
/// ÖNBELLEK BÜYÜMESİ ELE ALINDI: her tazelemede adres değişir (`?_k=nesil`),
/// yani her kare Flutter'ın `ImageCache`inde YENİ bir girdidir. Önlem
/// alınmasa altı karo × dakikada 7,5 tazeleme ≈ **dakikada 45 görüntü**
/// biriktirirdi. Yeni kare yüklenince ÖNCEKİ sağlayıcı `evict` edilir.
library;

import 'package:flutter/material.dart';

import '../../../core/ui/gorsel_cozme.dart';
import '../domain/camera_models.dart';

/// Kameranın anlık kare adresine tazeleme damgası ekler.
///
/// Var olan sorgu dizesi KORUNUR (`?` mi `&` mi doğru seçilir): Frigate
/// benzeri geçitlerde adres zaten `?h=480` gibi parametre taşıyabilir ve
/// körlemesine `?` eklemek adresi bozardı.
String kareAdresi(String temel, int nesil) {
  final ayrac = temel.contains('?') ? '&' : '?';
  // `${ayrac}` süslü parantezle: `$ayrac_k` Dart'ta `ayrac_k` ADINDA bir
  // değişken arar ve derlenmez.
  return '$temel${ayrac}_k=$nesil';
}

/// Karonun görsel alanı: kare varsa görüntü, yoksa yer tutucu.
class KameraKaresi extends StatefulWidget {
  const KameraKaresi({
    super.key,
    required this.kamera,
    required this.nesil,
    required this.yerTutucu,
    this.onKareDurumu,
    this.gorselYapici,
  });

  final Camera kamera;

  /// [KareTazeleme]'den gelen nesil sayısı; her artışta yeni kare çekilir.
  final int nesil;

  /// Kare yokken/yüklenemezken gösterilecek görsel (mevcut davranış).
  final Widget yerTutucu;

  /// Kareler GERÇEKTEN tazeleniyor mu — "CANLI" rozeti buna bakar.
  ///
  /// Geri çağrı kullanılıyor, `GlobalKey` ile durum okunmuyor: kamera
  /// kimliğine göre anahtar tutan bir statik harita, kamera silinince
  /// sızıntı bırakır ve aynı kartın iki yerde çizilmesini imkânsız kılardı
  /// (kart hem ana ekran şeridinde hem ızgarada kullanılıyor).
  final ValueChanged<bool>? onKareDurumu;

  /// TESTTE değiştirilebilir: widget testinde ağ yoktur, `Image.network`
  /// asla yüklenmez. Üretimde null → [Image.network].
  @visibleForTesting
  final Widget Function(String adres)? gorselYapici;

  @override
  State<KameraKaresi> createState() => KameraKaresiState();
}

@visibleForTesting
class KameraKaresiState extends State<KameraKaresi> {
  /// En son BAŞARIYLA yüklenmiş kare — yeni kare gelene kadar ekranda kalır
  /// ve tazeleme düşerse (kamera anlık erişilemez) ekran boşalmaz.
  /// Kaynak sırasının (c) şıkkı: "önbellekteki son kare".
  ImageProvider<Object>? _sonKare;

  /// Ekranda gerçekten bir kare var mı? "CANLI" rozeti buna bakar —
  /// adres tanımlı olması yetmez, kare GERÇEKTEN gelmiş olmalı.
  @visibleForTesting
  bool get kareVar => _sonKare != null;

  ImageProvider<Object>? _onceki;

  /// TESTTE "kare geldi" sinyali (üretimde `frameBuilder` çağırır).
  @visibleForTesting
  void kareGeldiTest() => _kareGeldi(_saglayici(64));

  @override
  void didUpdateWidget(covariant KameraKaresi oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kamera değiştiyse (liste yeniden sıralandı) son kare artık yanlış
    // kameraya ait olur — bırakmak, bir kameranın görüntüsünü başka bir
    // kameranın karosunda göstermek olurdu.
    if (oldWidget.kamera.id != widget.kamera.id) {
      _onceki?.evict();
      _onceki = null;
      _sonKare = null;
    }
  }

  @override
  void dispose() {
    // Ekrandan çıkarken önbelleği bırak: aksi halde her ziyaret kalıcı
    // olarak birkaç megabayt bırakırdı.
    _onceki?.evict();
    _sonKare?.evict();
    super.dispose();
  }

  void _kareGeldi(ImageProvider<Object> saglayici) {
    // ÖNCEKİNİ AT: adres her tazelemede değiştiği için her kare önbellekte
    // YENİ bir girdidir; temizlenmezse ızgara dakikada onlarca görüntü
    // biriktirir.
    if (!identical(_onceki, saglayici)) {
      _onceki?.evict();
      _onceki = saglayici;
    }
    if (_sonKare != saglayici) {
      // Çizim sırasında `setState` çağırmamak için kare sonrasına bırakılır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _sonKare = saglayici);
        widget.onKareDurumu?.call(true);
      });
    }
  }

  /// Kare sağlayıcısı — HER ZAMAN çözme sınırıyla sarılı.
  ///
  /// Sınır olmasa 4000x3000'lik bir kamera karesi ekranda 180 dp görünse de
  /// bellekte ~48 MB RGBA tutardı; ızgarada altı karo × 8 sn'de bir tazeleme
  /// ile bu, dakikalar içinde yüzlerce megabayta çıkar. Depodaki
  /// `gorsel_cozme_denetimi_test.dart` kilidi bu kuralı zorunlu tutuyor ve
  /// ilk yazımda tam da bunu yakaladı.
  ImageProvider<Object> _saglayici(double genislikDp) => ResizeImage(
        NetworkImage(kareAdresi(widget.kamera.snapshotUrl!, widget.nesil)),
        // YALNIZ GENİŞLİK: karo 16:10'dur, kareyi kareye sıkıştırmak
        // görüntüyü bozardı (`sinirliGorsel` kare varsayar).
        width: cozmeSiniri(context, genislikDp),
        allowUpscaling: false,
      );

  @override
  Widget build(BuildContext context) {
    final k = widget.kamera;
    if (!k.kareCekilebilir) return widget.yerTutucu;

    final adres = kareAdresi(k.snapshotUrl!, widget.nesil);
    if (widget.gorselYapici != null) {
      // TEST YOLU. Kare BEKLEMEDE sayılır; "geldi" demeyi test
      // [kareGeldiTest] ile kendisi yapar.
      //
      // Önceki hâli kareyi kendiliğinden "geldi" işaretliyordu ve bu,
      // kamera değişince önceki karenin bırakılmasını ölçen testi
      // SESSİZCE geçirtiyordu (mutasyonla yakalandı): sahte yol yeni
      // adresi zaten çiziyordu, bayrak da hemen geri doluyordu. Bir test
      // çiftinin, ölçtüğü şeyi kendiliğinden doğru yapması en pahalı
      // test hatasıdır.
      return widget.gorselYapici!(adres);
    }

    // Karonun GERÇEK genişliğinden sınır üret: şeritte ~150 dp, ızgarada
    // ~180 dp. Sabit bir sayı yazmak, ekran büyüdükçe bulanık kare
    // gösterirdi.
    return LayoutBuilder(builder: (context, kisit) {
      final saglayici = _saglayici(
        kisit.maxWidth.isFinite && kisit.maxWidth > 0 ? kisit.maxWidth : 200,
      );
      return Image(
      image: saglayici,
      fit: BoxFit.cover,
      // ÖNCEKİ KARE EKRANDA KALIR: yeni kare yüklenirken karo boşalmaz
      // (yanıp sönen bir ızgara "canlı" değil, bozuk görünür).
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) {
        if (frame != null) _kareGeldi(saglayici);
        // İlk kare henüz yoksa yer tutucu; sonrasında gaplessPlayback
        // önceki kareyi tutar.
        return frame == null && _sonKare == null ? widget.yerTutucu : child;
      },
      errorBuilder: (context, hata, iz) {
        // Kamera anlık erişilemez: SON KARE korunur, yoksa yer tutucu.
        // Hata metni GÖSTERİLMEZ — ızgarada altı karonun altısında hata
        // cümlesi, ekranı okunmaz yapardı; kullanıcı karoya dokununca
        // oynatıcıdaki gerçek hatayı görür.
        //
        // ROZET DÜŞER: ekranda bayat bir kare dururken "CANLI" demek,
        // kullanıcıyı yanlış bilgilendirmektir — güvenlik görevlisi için
        // "şu an böyle" ile "en son böyleydi" arasındaki fark her şeydir.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onKareDurumu?.call(false);
        });
        final son = _sonKare;
        if (son == null) return widget.yerTutucu;
        return Image(image: son, fit: BoxFit.cover);
      },
      );
    });
  }
}
