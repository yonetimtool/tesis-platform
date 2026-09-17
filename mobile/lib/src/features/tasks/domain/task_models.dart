/// Gorev modulunun domain modelleri — `contracts/openapi.yaml`'daki Task /
/// TaskCompletion / TaskCompletionCreate / PresignRequest / PresignResponse
/// semalarina uyar.
///
/// SOZLESME NOTLARI (§11 bulgulari KAPANDI — README §11):
///   * "Gorevlerim" SUNUCUDA suzulur: `GET /tasks?atanan_user_id=me`
///     (istemcideki "bana atananlar one" siralamasi kaldirildi; kalan tek
///     istemci isi tarih sirasi — [sortTasksByPlan]).
///   * `task.foto_zorunlu` geldi: true iken `foto_key`'siz completion 422 —
///     mobil erken uyari verir, backend mesaji da yakalanir.
///   * `POST /tasks/{id}/completions` Idempotency-Key header ZORUNLU
///     (yoksa 400); `nfc_tag_uid` normalize (strip+upper) karsilastirilir,
///     eslesmezse 422 `invalid_reference`.
library;

/// Talepten (complaint→is emri) gelen gorevin kompakt talep ozeti (TicketSummary
/// semasi). Atanan saha personeline baglam gosterir.
class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.baslik,
    required this.durum,
    this.kategoriAd,
    this.unitLabel,
  });

  final String id;
  final String baslik; // kisa aciklama
  final String durum; // acik | is_emri | cozuldu | reddedildi
  final String? kategoriAd; // null -> l10n.gorevKategoriDiger
  final String? unitLabel; // talebi acanin dairesi (varsa)

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
    id: json['id'] as String,
    baslik: json['baslik'] as String? ?? '',
    durum: json['durum'] as String? ?? '',
    kategoriAd: json['kategori_ad'] as String?,
    unitLabel: json['unit_label'] as String?,
  );
}

/// `GET /tasks` ogesi (Task semasi).
/// (P229 §3) Gorev LISTESINDE gosterilen tamamlama ozeti.
///
/// OLCULEN KUSUR: `Task` tamamlama hakkinda hicbir sey tasimiyordu.
/// Sunucu kaydediyordu ama liste "tamamlandi mi" sorusunu
/// yanitlayamiyordu; detay ekrani ise yalniz KENDI POST yanitini
/// ciziyor, ekran kapaninca unutuyordu.
class TaskTamamlamaOzet {
  const TaskTamamlamaOzet({
    required this.id,
    required this.tamamlayanUserId,
    required this.tamamlanmaZamani,
    this.tamamlayanAd,
    this.fotoVar = false,
    this.notlar,
  });

  final String id;
  final String tamamlayanUserId;

  /// KIM tamamladi. Id yeterli degildi: saha rolu kullanici listesini
  /// goremiyor (403), yani adi kendisi cozemezdi.
  final String? tamamlayanAd;
  final DateTime tamamlanmaZamani;
  final bool fotoVar;
  final String? notlar;

  factory TaskTamamlamaOzet.fromJson(Map<String, dynamic> json) =>
      TaskTamamlamaOzet(
        id: json['id'] as String,
        tamamlayanUserId: json['tamamlayan_user_id'] as String,
        tamamlayanAd: json['tamamlayan_ad'] as String?,
        tamamlanmaZamani:
            DateTime.parse(json['tamamlanma_zamani'] as String).toUtc(),
        fotoVar: json['foto_var'] as bool? ?? false,
        notlar: json['notlar'] as String?,
      );
}

/// (P230 §4) Gorev durumu — SUNUCUDA turetilir.
enum TaskDurum {
  atandi('atandi'),
  baslandi('baslandi'),
  tamamlandi('tamamlandi'),
  gecikti('gecikti');

  const TaskDurum(this.wire);

  final String wire;

  /// BILINMEYEN DEGER `atandi`YA DUSER, HATA ATMAZ: sunucu ileride yeni
  /// bir durum eklerse eski istemci listeyi cizemez hale GELMEMELI.
  static TaskDurum coz(String? v) => TaskDurum.values.firstWhere(
    (e) => e.wire == v,
    orElse: () => TaskDurum.atandi,
  );
}

class Task {
  const Task({
    required this.id,
    required this.ad,
    required this.aktif,
    this.fotoZorunlu = false,
    this.aciklama,
    this.atananUserId,
    this.checkpointId,
    this.kategoriId,
    this.periyotDakika,
    this.sonrakiPlanlanan,
    this.ticketId,
    this.oncelik,
    this.ticket,
    this.tamamlandi = false,
    this.sonTamamlama,
    this.sonTarih,
    this.baslamaZamani,
    this.olusturanAd,
    this.atananAd,
    this.durum = TaskDurum.atandi,
    this.gecikmeGun,
    this.adimToplam = 0,
    this.adimTamam = 0,
    this.adimSirali = false,
    this.adimlar,
  });

  final String id;
  final String ad;
  final String? aciklama;

  /// Gorevin atandigi kullanici (yoksa havuz gorevi).
  final String? atananUserId;

  /// Gorev TIPI = yonetici-tanimli kategori (task_category);
  /// null = kategorisiz (ekran l10n.gorevKategoriDiger yazar).
  /// Sabit tip enum'u kaldirildi; ad, kategori listesinden cozulur.
  final String? kategoriId;

  /// Gorevin NFC dogrulama noktasi. Doluysa tamamlama akisinda "etiketi
  /// okutun" adimi gosterilir; okunan UID backend'de bu checkpoint'in
  /// etiketiyle eslesmek zorundadir (422 doner eslesmezse).
  final String? checkpointId;

  final int? periyotDakika;

  /// Bir sonraki planlanan an (UTC) — listede tarih olarak gosterilir.
  final DateTime? sonrakiPlanlanan;

  final bool aktif;

  /// true → completion `foto_key` olmadan kabul edilmez (backend 422).
  /// Detay ekrani rozet gosterir ve gonderim oncesi erken uyari verir.
  final bool fotoZorunlu;

  /// Ticketing: gorev bir TALEPTEN geldiyse dolu. [ticketId] bagli talebin id'si;
  /// [oncelik] 'dusuk'|'orta'|'yuksek'; [ticket] kompakt talep ozeti (baglam).
  final String? ticketId;
  final String? oncelik;
  final TicketSummary? ticket;

  /// (P229 §3) En az bir tamamlamasi var mi + EN YENI tamamlama ozeti.
  /// Periyodik gorev defalarca tamamlanir; gosterilmesi gereken ilki
  /// degil SONUNCUSUDUR.
  final bool tamamlandi;
  final TaskTamamlamaOzet? sonTamamlama;

  /// (P230 §4) TAKIP ALANLARI.
  ///
  /// `durum` SUNUCUDA turetilir ve istemci onu TEKRAR HESAPLAMAZ: iki
  /// istemcinin ayni gorevi farkli durumda gostermesi, "gecikti" uyarisini
  /// guvenilmez yapardi.
  final DateTime? sonTarih;
  final DateTime? baslamaZamani;
  final String? olusturanAd;
  final String? atananAd;
  final TaskDurum durum;

  /// Gun cinsinden gecikme; `sonTarih` yoksa null (SIFIR DEGIL — sifir
  /// "bugun son gun" demektir).
  final int? gecikmeGun;

  /// (P237 §2) ALT ADIM ILERLEMESI — LISTEDE de gelir.
  ///
  /// Iki sayi listede tasinir cunku "hangi gorev ne kadar ilerledi"
  /// sorusu icin her goreve tek tek girmek gerekmemeli. Adimlarin
  /// KENDISI yalniz AYRINTIDA (`GET /tasks/{id}`) gelir; listede null.
  final int adimToplam;
  final int adimTamam;
  final bool adimSirali;
  final List<TaskStep>? adimlar;

  /// Gorev bir talepten mi geldi? (chip/rozet gorunurlugu).
  bool get fromTicket => ticketId != null;

  bool isAssignedTo(String? userId) => userId != null && atananUserId == userId;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    ad: json['ad'] as String? ?? '',
    aciklama: json['aciklama'] as String?,
    atananUserId: json['atanan_user_id'] as String?,
    checkpointId: json['checkpoint_id'] as String?,
    kategoriId: json['kategori_id'] as String?,
    periyotDakika: (json['periyot_dakika'] as num?)?.toInt(),
    sonrakiPlanlanan: json['sonraki_planlanan'] == null
        ? null
        : DateTime.parse(json['sonraki_planlanan'] as String).toUtc(),
    aktif: json['aktif'] as bool? ?? true,
    fotoZorunlu: json['foto_zorunlu'] as bool? ?? false,
    ticketId: json['ticket_id'] as String?,
    oncelik: json['oncelik'] as String?,
    ticket: json['ticket'] == null
        ? null
        : TicketSummary.fromJson(json['ticket'] as Map<String, dynamic>),
    tamamlandi: json['tamamlandi'] as bool? ?? false,
    sonTamamlama: json['son_tamamlama'] == null
        ? null
        : TaskTamamlamaOzet.fromJson(
            json['son_tamamlama'] as Map<String, dynamic>),
    sonTarih: json['son_tarih'] == null
        ? null
        : DateTime.parse(json['son_tarih'] as String).toUtc(),
    baslamaZamani: json['baslama_zamani'] == null
        ? null
        : DateTime.parse(json['baslama_zamani'] as String).toUtc(),
    olusturanAd: json['olusturan_ad'] as String?,
    atananAd: json['atanan_ad'] as String?,
    durum: TaskDurum.coz(json['durum'] as String?),
    gecikmeGun: (json['gecikme_gun'] as num?)?.toInt(),
    adimToplam: (json['adim_toplam'] as num?)?.toInt() ?? 0,
    adimTamam: (json['adim_tamam'] as num?)?.toInt() ?? 0,
    adimSirali: json['adim_sirali'] as bool? ?? false,
    adimlar: (json['adimlar'] as List<dynamic>?)
        ?.map((e) => TaskStep.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// (P237 §2) GOREVIN ALT ADIMI — "A blok", "B blok", "C blok".
///
/// Her adim KENDI tamamlayanini, zamanini ve FOTOGRAFINI tasir; gorev
/// tamamlamasindan (tek kapanis kaydi) farki budur.
class TaskStep {
  const TaskStep({
    required this.id,
    required this.taskId,
    required this.sira,
    required this.ad,
    required this.fotoZorunlu,
    this.tamamlandi = false,
    this.tamamlayanUserId,
    this.tamamlayanAd,
    this.tamamlanmaZamani,
    this.fotoKey,
    this.fotoUrl,
    this.notlar,
  });

  final String id;
  final String taskId;
  final int sira;
  final String ad;

  /// Gorevden MIRAS; adim SIKILASTIRABILIR, gevsetemez (sunucu zorlar).
  final bool fotoZorunlu;
  final bool tamamlandi;
  final String? tamamlayanUserId;
  final String? tamamlayanAd;
  final DateTime? tamamlanmaZamani;
  final String? fotoKey;
  final String? fotoUrl;
  final String? notlar;

  factory TaskStep.fromJson(Map<String, dynamic> json) => TaskStep(
    id: json['id'] as String,
    taskId: json['task_id'] as String? ?? '',
    sira: (json['sira'] as num?)?.toInt() ?? 0,
    ad: json['ad'] as String? ?? '',
    fotoZorunlu: json['foto_zorunlu'] as bool? ?? false,
    tamamlandi: json['tamamlandi'] as bool? ?? false,
    tamamlayanUserId: json['tamamlayan_user_id'] as String?,
    tamamlayanAd: json['tamamlayan_ad'] as String?,
    tamamlanmaZamani: json['tamamlanma_zamani'] == null
        ? null
        : DateTime.parse(json['tamamlanma_zamani'] as String).toUtc(),
    fotoKey: json['foto_key'] as String?,
    fotoUrl: json['foto_url'] as String?,
    notlar: json['notlar'] as String?,
  );
}

/// `POST /tasks/{id}/completions` istek govdesi (TaskCompletionCreate) +
/// Idempotency-Key ureticisi.
///
/// Anahtar, akis BASLATILDIGI anda sabitlenen (taskId, tamamlanma_zamani)
/// ciftinden deterministik turetilir (scan desenindeki gibi): ag hatasi
/// sonrasi ayni taslagin tekrar gonderimi backend'de AYNI kaydi dondurur
/// (200 idempotent tekrar). NFC/foto/not sonradan eklense de anahtar
/// DEGISMEZ — copyWith yalnizca kanit alanlarini gunceller.
class TaskCompletionDraft {
  const TaskCompletionDraft({
    required this.taskId,
    required this.tamamlanmaZamani,
    this.nfcTagUid,
    this.fotoKey,
    this.notlar,
    this.gpsLat,
    this.gpsLng,
  });

  final String taskId;

  /// Akisin baslatildigi an (UTC) — anahtarin parcasi, degistirilemez.
  final DateTime tamamlanmaZamani;

  final String? nfcTagUid;
  final String? fotoKey;
  final String? notlar;
  final double? gpsLat;
  final double? gpsLng;

  String get idempotencyKey =>
      'task-completion|$taskId|${tamamlanmaZamani.toUtc().toIso8601String()}';

  TaskCompletionDraft copyWith({
    Object? nfcTagUid = _sentinel,
    Object? fotoKey = _sentinel,
    Object? notlar = _sentinel,
  }) => TaskCompletionDraft(
    taskId: taskId,
    tamamlanmaZamani: tamamlanmaZamani,
    nfcTagUid: nfcTagUid == _sentinel ? this.nfcTagUid : nfcTagUid as String?,
    fotoKey: fotoKey == _sentinel ? this.fotoKey : fotoKey as String?,
    notlar: notlar == _sentinel ? this.notlar : notlar as String?,
    gpsLat: gpsLat,
    gpsLng: gpsLng,
  );

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'tamamlanma_zamani': tamamlanmaZamani.toUtc().toIso8601String(),
    if (nfcTagUid != null) 'nfc_tag_uid': nfcTagUid,
    if (fotoKey != null) 'foto_key': fotoKey,
    if (notlar != null) 'notlar': notlar,
    if (gpsLat != null) 'gps_lat': gpsLat,
    if (gpsLng != null) 'gps_lng': gpsLng,
  };
}

/// `POST/GET /tasks/{id}/completions` yaniti (TaskCompletion semasi).
class TaskCompletion {
  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.tamamlayanUserId,
    required this.tamamlanmaZamani,
    this.tamamlayanAd,
    this.nfcTagUid,
    this.fotoKey,
    this.fotoUrl,
    this.notlar,
  });

  final String id;
  final String taskId;
  final String tamamlayanUserId;

  /// KIM tamamladi (P229 §3) — saha rolu id'den adi cozemez.
  final String? tamamlayanAd;
  final DateTime tamamlanmaZamani;
  final String? nfcTagUid;
  final String? fotoKey;
  final String? fotoUrl;
  final String? notlar;

  factory TaskCompletion.fromJson(Map<String, dynamic> json) => TaskCompletion(
    id: json['id'] as String,
    taskId: json['task_id'] as String,
    tamamlayanUserId: json['tamamlayan_user_id'] as String,
    tamamlayanAd: json['tamamlayan_ad'] as String?,
    tamamlanmaZamani: DateTime.parse(
      json['tamamlanma_zamani'] as String,
    ).toUtc(),
    nfcTagUid: json['nfc_tag_uid'] as String?,
    fotoKey: json['foto_key'] as String?,
    fotoUrl: json['foto_url'] as String?,
    notlar: json['notlar'] as String?,
  );
}

/// Tamamlama gonderim sonucu: yanit + yeni kayit mi (201) yoksa idempotent
/// tekrar mi (200) — kullaniciya "kaydedildi" / "zaten kayitliydi" ayrimi.
class TaskCompletionResult {
  const TaskCompletionResult({
    required this.completion,
    required this.wasDuplicate,
  });

  final TaskCompletion completion;

  /// true → backend ayni Idempotency-Key ile mevcut kaydi dondurdu (200).
  final bool wasDuplicate;
}

/// `POST /uploads/presign` yaniti (PresignResponse semasi).
class PresignTicket {
  const PresignTicket({
    required this.fotoKey,
    required this.uploadUrl,
    required this.expiresIn,
  });

  /// Completion'da gonderilecek obje anahtari (tenant ile namespace'li).
  final String fotoKey;

  /// Presigned PUT URL — dosya dogrudan buraya PUT edilir (kisa omurlu).
  final String uploadUrl;

  final int expiresIn;

  factory PresignTicket.fromJson(Map<String, dynamic> json) => PresignTicket(
    fotoKey: json['foto_key'] as String,
    uploadUrl: json['upload_url'] as String,
    expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
  );
}

/// Liste sirasi: `sonraki_planlanan` ASC (plansizlar sona), esitlikte ad.
/// "Bana atananlar one" mantigi KALDIRILDI — suzme artik sunucuda
/// (`?atanan_user_id=me`, §11 #1 kapandi).
List<Task> sortTasksByPlan(List<Task> tasks) {
  return [...tasks]..sort((a, b) {
    if (a.sonrakiPlanlanan == null && b.sonrakiPlanlanan == null) {
      return a.ad.compareTo(b.ad);
    }
    if (a.sonrakiPlanlanan == null) return 1;
    if (b.sonrakiPlanlanan == null) return -1;
    final cmp = a.sonrakiPlanlanan!.compareTo(b.sonrakiPlanlanan!);
    return cmp != 0 ? cmp : a.ad.compareTo(b.ad);
  });
}

/// `POST /tasks` / `PATCH /tasks/{id}` govdesi — yonetim formu (admin +
/// yonetici; auth.md §4). TAM-GOVDE semantigi: null alanlar da gonderilir,
/// boylece PATCH'te atama/aciklama TEMIZLENEBILIR (backend TaskUpdate
/// exclude_unset — gonderilen null alani null yapar).
///
/// KISIT (backend zorlar): yonetici `atanan_user_id`'yi yalniz
/// security/tesis_gorevlisi kullanicilara verebilir (aksi 422) — form zaten
/// yalnizca saha personelini listeler.
class TaskDraft {
  const TaskDraft({
    required this.ad,
    this.aciklama,
    this.atananUserId,
    this.kategoriId,
    this.checkpointId,
    this.periyotDakika,
    this.sonTarih,
    this.fotoZorunlu = false,
    this.aktif = true,
    this.adimlar = const [],
    this.adimSirali = false,
  });

  final String ad;
  final String? aciklama;
  final String? atananUserId;

  /// Gorev tipi = kategori; null = kategorisiz (l10n.gorevKategoriDiger).
  final String? kategoriId;

  /// Bagli NFC kontrol noktasi; doluysa gorev NFC-dogrulamalidir (tamamlarken
  /// etiket okutulur). null = NFC gerektirmez.
  final String? checkpointId;
  final int? periyotDakika;

  /// (P239 §4) SON TARIH — gecikme bundan hesaplanir. `sonraki_planlanan`
  /// DEGIL: o yalniz periyodik gorevlerde dolu ve "bir sonraki tekrar"
  /// demek.
  final DateTime? sonTarih;
  final bool fotoZorunlu;
  final bool aktif;

  /// (P237 §2) ALT ADIM ADLARI — yalniz OLUSTURMADA gonderilir.
  ///
  /// Duzenlemede gonderilseydi mevcut adimlar (TAMAMLANMISLAR DAHIL)
  /// ezilirdi; duzenleme ayrinti ekranindaki tek tek ekleme/silme
  /// akisindan gecer ve orada her islem denetim kaydina yazilir.
  final List<String> adimlar;
  final bool adimSirali;

  Map<String, dynamic> toJson() => {
    'ad': ad,
    'aciklama': aciklama,
    'atanan_user_id': atananUserId,
    'kategori_id': kategoriId,
    'checkpoint_id': checkpointId,
    'periyot_dakika': periyotDakika,
    // TAM-GOVDE: null da GONDERILIR — PATCH'te alani TEMIZLEMEK
    // (son tarihi kaldirmak) baska turlu mumkun olmazdi.
    'son_tarih': sonTarih?.toUtc().toIso8601String(),
    'foto_zorunlu': fotoZorunlu,
    'aktif': aktif,
    'adim_sirali': adimSirali,
    if (adimlar.isNotEmpty)
      'adimlar': [
        for (var i = 0; i < adimlar.length; i++)
          {'ad': adimlar[i], 'sira': i},
      ],
  };

  /// Duzenleme formunu mevcut gorevle doldurmak icin.
  factory TaskDraft.fromTask(Task task) => TaskDraft(
    ad: task.ad,
    aciklama: task.aciklama,
    atananUserId: task.atananUserId,
    kategoriId: task.kategoriId,
    checkpointId: task.checkpointId,
    periyotDakika: task.periyotDakika,
    sonTarih: task.sonTarih,
    fotoZorunlu: task.fotoZorunlu,
    aktif: task.aktif,
    adimSirali: task.adimSirali,
  );
}

/// Atama secicisindeki kullanici (`GET /users` ogesinden).
class AssignableUser {
  const AssignableUser({
    required this.id,
    required this.ad,
    required this.role,
  });

  final String id;
  final String ad;
  final String role;
}

/// Gorev atanabilir saha rolleri (auth.md §4: yonetici yalniz bunlara atar;
/// panel SAHA_ROLLERI ile ayni kume).
const sahaRolleri = {'security', 'tesis_gorevlisi'};

/// `GET /users` item listesinden atanabilir personel — SAF fonksiyon
/// (birim testli): yalniz AKTIF + saha rolundeki kullanicilar, ada gore.
List<AssignableUser> assignableFromUsersJson(List<dynamic> items) {
  final out = <AssignableUser>[
    for (final item in items)
      if (item is Map &&
          item['is_active'] == true &&
          sahaRolleri.contains(item['role']) &&
          item['id'] is String)
        AssignableUser(
          id: item['id'] as String,
          ad: item['ad'] as String? ?? '',
          role: item['role'] as String,
        ),
  ]..sort((a, b) => a.ad.compareTo(b.ad));
  return out;
}
