import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Site sakini listesi ogesi (`GET /residents`). Telefon KVKK geregi YOK.
class ResidentMember {
  const ResidentMember({
    required this.userId,
    required this.ad,
    this.unitNo,
    this.blok,
    required this.isActive,
  });

  final String userId;
  final String ad;
  final String? unitNo;

  /// (P220 §4) AKTIF DAIRELERIN BLOK ADLARI — gruplama icin.
  ///
  /// `unitNo`dan CIKARILAMAZ: blok `unit.blok` sutunudur, daire
  /// numarasinin bir parcasi degil (P193'te ikisi BILEREK ayrildi).
  /// `A-12` numarali daire `B` blogunda olabilir.
  ///
  /// `null` = aktif daire bagi yok. O sakin listeden GIZLENMIYOR;
  /// "Blok atanmamis" grubunda gorunuyor — gizlemek, siteden ayrilmis
  /// ama hesabi duran bir sakini BULUNAMAZ yapardi ve istegin gerekcesi
  /// tam olarak onu bulup silmek.
  final String? blok;
  final bool isActive;

  factory ResidentMember.fromJson(Map<String, dynamic> json) => ResidentMember(
    userId: json['user_id'] as String,
    ad: json['ad'] as String,
    unitNo: json['unit_no'] as String?,
    blok: json['blok'] as String?,
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

/// Site sakini yonetimi ince istemcisi (yonetici/admin) — listele/ekle/cikar.
class ResidentsApi {
  ResidentsApi(this._dio);

  final Dio _dio;

  /// (P220 §4) `q`: ad + daire no + BLOK aramasi (sunucuda, en az 2
  /// karakter). `blok`: tek bloga daraltma (TAM eslesme).
  ///
  /// IKISI AYRI: `q=A` metin arar ("A-12" dairesindekiler de gelir),
  /// `blok=A` yalniz A blogunu getirir. Tek parametreye sigdirmak,
  /// blogu daraltmak isteyen yoneticiye baska blogun dairelerini
  /// gostermek olurdu.
  Future<List<ResidentMember>> getResidents({String? q, String? blok}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/residents',
        queryParameters: {
          if (q != null && q.trim().length >= 2) 'q': q.trim(),
          if (blok != null && blok.isNotEmpty) 'blok': blok,
        },
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(ResidentMember.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yeni sakin: daire + PAROLASIZ hesap. Sunucu otomatik bir davet gonderir;
  /// kisi daveti (Tesis ID) ile kendi kaydini tamamlar — yonetici hicbir kod
  /// iletmez. (P154 / Asama 5) TELEFON + DAIRE NO — govdede baska alan YOK.
  ///
  /// `ad` ve `password` GONDERILMIYOR (parametreleri de kaldirildi):
  /// sunucu ad verilmediginde daireden turetilen gecici bir ad yazar ve
  /// parolayi kullanicinin KENDI kayit akisi belirler. Gerekce
  /// `_AddResidentSheetState` basliginda.
  /// (P220 §4) `blok` EKLENDI ve AYRI GONDERILIYOR.
  ///
  /// Sunucu blogu YALNIZ YENI ACILAN daireye isliyor (mevcut dairenin
  /// blogunu degistirmek bir tasima islemidir ve buranin isi degil).
  /// Daire numarasindan blok TURETILMIYOR: `A-12` numarali bir daire
  /// `B` blogunda olabilir ve tahmin etmek yanlis blokta bir daire
  /// acardi.
  Future<void> addResident({
    required String telefon,
    required String unitNo,
    String? blok,
  }) async {
    final data = <String, dynamic>{
      'telefon': telefon,
      'unit_no': unitNo,
      if (blok != null && blok.trim().isNotEmpty) 'blok': blok.trim(),
    };
    try {
      await _dio.post<Map<String, dynamic>>('/residents', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakini duzenle (P23b) — OLUSTURMADAKI TUM ALANLAR.
  ///
  /// Bos birakilan alan GONDERILMEZ (degismez). Iki istisna:
  ///   * [emailTemizle] true ise `email: null` ACIKCA gonderilir (sunucu
  ///     alani temizler) — "bos birakmak" ile "silmek" ayri seylerdir.
  ///   * [rolTipi] verilirse kullanicinin AKTIF daire baglarinin HEPSINE
  ///     uygulanir; aktif bagi yoksa sunucu 422 doner.
  Future<void> updateResident(
    String userId, {
    String? ad,
    String? telefon,
    String? email,
    bool emailTemizle = false,
    String? rolTipi,
    // (P218) Dairede OTURUYOR mu — mulkiyetten ayri. `null` =
    // degistirme; sunucu kiraci icin `true` varsayar.
    bool? oturuyor,
  }) async {
    final data = <String, dynamic>{};
    if (ad != null && ad.isNotEmpty) data['ad'] = ad;
    if (telefon != null && telefon.isNotEmpty) data['telefon'] = telefon;
    if (emailTemizle) {
      data['email'] = null;
    } else if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (rolTipi != null && rolTipi.isNotEmpty) data['rol_tipi'] = rolTipi;
    if (oturuyor != null) data['oturuyor'] = oturuyor;
    try {
      await _dio.patch<void>('/residents/$userId', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakini SIL (akilli) — telefon her durumda serbest kalir. Donus: tamamen
  /// silindi mi (true) yoksa pasiflestirildi mi (false, gecmisi var).
  Future<bool> removeResident(String userId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/residents/$userId');
      return (res.data?['deleted'] as bool?) ?? true;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final residentsApiProvider = Provider<ResidentsApi>(
  (ref) => ResidentsApi(ref.watch(dioProvider)),
);

/// (P220 §4) SAKIN LISTESI SUZGECI — arama + blok daraltma.
class SakinSuzgeci {
  const SakinSuzgeci({this.arama = '', this.blok});

  final String arama;

  /// `null` = tum bloklar. Dolu ise YALNIZ o blok.
  final String? blok;

  bool get aramaGecerli => arama.trim().length >= 2;

  SakinSuzgeci kopya({String? arama, String? blok, bool blogTemizle = false}) =>
      SakinSuzgeci(
        arama: arama ?? this.arama,
        blok: blogTemizle ? null : (blok ?? this.blok),
      );

  @override
  bool operator ==(Object other) =>
      other is SakinSuzgeci && other.arama == arama && other.blok == blok;

  @override
  int get hashCode => Object.hash(arama, blok);
}

class SakinSuzgeciController extends Notifier<SakinSuzgeci> {
  @override
  SakinSuzgeci build() => const SakinSuzgeci();

  void ara(String metin) => state = state.kopya(arama: metin);

  /// `null` verilirse blok daraltmasi KALKAR.
  void blokSec(String? blok) => state = blok == null
      ? state.kopya(blogTemizle: true)
      : state.kopya(blok: blok);
}

final sakinSuzgeciProvider =
    NotifierProvider<SakinSuzgeciController, SakinSuzgeci>(
  SakinSuzgeciController.new,
);

final residentsProvider = FutureProvider.autoDispose<List<ResidentMember>>(
  (ref) {
    final s = ref.watch(sakinSuzgeciProvider);
    return ref.watch(residentsApiProvider).getResidents(
          q: s.aramaGecerli ? s.arama : null,
          blok: s.blok,
        );
  },
);

/// (P220 §4) BLOKLARA GORE GRUPLANMIS liste.
///
/// GRUPLAMA ISTEMCIDE ve bu bilincli: sunucu duz liste donuyor ve o
/// liste zaten sayfalanmiyor (site sakini sayisi binlerce degil). Sunucu
/// tarafinda gruplamak, ayni veriyi iki bicimde donduren ikinci bir uc
/// demekti.
///
/// SIRA: bloklar alfabetik, "blok atanmamis" EN SONDA. Sakinler zaten
/// sunucudan ada gore sirali geliyor.
typedef SakinBlogu = ({String? blok, List<ResidentMember> sakinler});

List<SakinBlogu> bloklaraGore(List<ResidentMember> liste) {
  final gruplar = <String?, List<ResidentMember>>{};
  for (final m in liste) {
    gruplar.putIfAbsent(m.blok, () => []).add(m);
  }
  final adli = gruplar.keys.whereType<String>().toList()..sort();
  return [
    for (final b in adli) (blok: b, sakinler: gruplar[b]!),
    // BLOKSUZLAR EN SONDA ve GIZLENMIYOR: siteden ayrilmis ama hesabi
    // duran sakin burada gorunur ve istegin gerekcesi tam olarak onu
    // bulup silmek.
    if (gruplar.containsKey(null)) (blok: null, sakinler: gruplar[null]!),
  ];
}
