import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev/duyuru foto
// akisiyla ayni saglayici (testlerde tek noktadan override edilir).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../../tasks/domain/task_category_models.dart' show TaskCategory;
import '../data/complaint_api.dart';
import '../domain/complaint_models.dart';

/// Talep listesinin durumu.
class ComplaintsState {
  const ComplaintsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.canCreate = false,
    this.canRespond = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Sunucu sirasi: created_at DESC (en yeni onde). Acan roller icin sunucu
  /// zaten YALNIZ kendi actiklarini doner.
  final List<Complaint> items;

  /// Acan rol mu (security/tesis_gorevlisi/resident) — "Yeni talep" FAB'i.
  /// Yalniz UX kapisi; gercek yetki backend RBAC'ta.
  final bool canCreate;

  /// Rol admin/yonetici mi — donustur/coz/reddet eylemleri (Task 13).
  final bool canRespond;

  final DateTime? refreshedAt;

  ComplaintsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Complaint>? items,
    bool? canCreate,
    bool? canRespond,
    DateTime? refreshedAt,
  }) {
    return ComplaintsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canCreate: canCreate ?? this.canCreate,
      canRespond: canRespond ?? this.canRespond,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Talep listesi controller'i. Talep acma basarili olunca listeyi tazeler;
/// hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException yukari
/// firlatilir).
class ComplaintsController extends Notifier<ComplaintsState> {
  bool _refreshing = false;

  @override
  ComplaintsState build() {
    Future.microtask(refresh);
    return const ComplaintsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(complaintApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canCreate: role.canCreateComplaint,
        canRespond: role.canRespondComplaints,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> create(ComplaintDraft draft) async {
    await ref.read(complaintApiProvider).create(draft);
    await refresh();
  }

  /// Talebi is emrine donustur (admin + yonetici). Basari sonrasi listeyi
  /// tazeler (durum acik -> is_emri; yeni timeline satiri gorunur). Hata
  /// ([ApiException]) EYLEMI acan sheet'e yukari firlatilir (orada gosterilir).
  Future<void> convert(String id, ComplaintConvertDraft draft) async {
    await ref.read(complaintApiProvider).convert(id, draft);
    await refresh();
  }

  /// Talebi dogrudan coz (admin + yonetici). Basari sonrasi tazeler.
  Future<void> resolve(String id, ComplaintResolveDraft draft) async {
    await ref.read(complaintApiProvider).resolve(id, draft);
    await refresh();
  }

  /// Talebi reddet (admin + yonetici; `sebep` zorunlu). Basari sonrasi tazeler.
  Future<void> decline(String id, ComplaintDeclineDraft draft) async {
    await ref.read(complaintApiProvider).decline(id, draft);
    await refresh();
  }
}

final complaintsControllerProvider =
    NotifierProvider<ComplaintsController, ComplaintsState>(
  ComplaintsController.new,
);

/// Talep acma formundaki TEK fotograf yuvasi (en fazla 3 yuva). [fotoKey]
/// dolu ise yukleme tamamlanmistir; null iken [busy] yukleme siriyor,
/// [error] ise yukleme basarisiz (Tekrar yukle ile denenir) demektir.
class PhotoSlot {
  const PhotoSlot({
    required this.id,
    required this.path,
    this.busy = false,
    this.fotoKey,
    this.error,
  });

  /// Yuva kimligi — liste indeksinden BAGIMSIZ (yukleme sirasinda silme/
  /// yeniden siralama olsa da dogru yuva guncellenir).
  final int id;

  /// Secilen fotonun cihaz yolu (onizleme).
  final String path;
  final bool busy;

  /// Presign akisindan alinan obje anahtari (yukleme bitince dolar).
  final String? fotoKey;
  final String? error;

  PhotoSlot copyWith({
    bool? busy,
    Object? fotoKey = _sentinel,
    Object? error = _sentinel,
  }) {
    return PhotoSlot(
      id: id,
      path: path,
      busy: busy ?? this.busy,
      fotoKey: fotoKey == _sentinel ? this.fotoKey : fotoKey as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Talep acma formunun durumu — foto yuvalari (<=3) + kategori listesi +
/// secilen kategori. Form her acildiginda [complaintFormControllerProvider]
/// autoDispose ile sifirlanir.
class ComplaintFormState {
  const ComplaintFormState({
    this.photos = const [],
    this.categories = const [],
    this.categoriesLoading = true,
    this.categoriesError,
    this.kategoriId,
  });

  final List<PhotoSlot> photos;
  final List<TaskCategory> categories;
  final bool categoriesLoading;
  final String? categoriesError;

  /// Secilen talep kategorisi (task_category); null = "Diğer".
  final String? kategoriId;

  /// 3 yuva dolduysa daha fazla eklenemez ("Ekle" karosu pasif).
  bool get canAddPhoto => photos.length < 3;

  /// Herhangi bir yuva yukleniyor mu — Ekle/Gonder pasiflemesi.
  bool get uploading => photos.any((p) => p.busy);

  /// Secilip henuz yuklenmemis (busy VEYA hatali) yuva var mi — gonderim
  /// bunun bitmesini bekler (eski `_fotoBekliyor` semantigi).
  bool get uploadPending => photos.any((p) => p.fotoKey == null);

  /// Talep acmada gonderilecek obje anahtarlari (tamamlanan yuvalar).
  List<String> get fotoKeys => [
        for (final p in photos)
          if (p.fotoKey != null) p.fotoKey!,
      ];

  ComplaintFormState copyWith({
    List<PhotoSlot>? photos,
    List<TaskCategory>? categories,
    bool? categoriesLoading,
    Object? categoriesError = _sentinel,
    Object? kategoriId = _sentinel,
  }) {
    return ComplaintFormState(
      photos: photos ?? this.photos,
      categories: categories ?? this.categories,
      categoriesLoading: categoriesLoading ?? this.categoriesLoading,
      categoriesError: categoriesError == _sentinel
          ? this.categoriesError
          : categoriesError as String?,
      kategoriId:
          kategoriId == _sentinel ? this.kategoriId : kategoriId as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Talep acma formu controller'i: kategori listesini acilista yukler, en
/// fazla 3 foto yuvasini yonetir (sec → presign → PUT → foto_key). Tekil
/// foto yukleme mantigi gorev/duyuru akisiyla ayni; burada 3'e kadar bir
/// listeye GENELLESTIRILDI.
class ComplaintFormController extends Notifier<ComplaintFormState> {
  int _nextId = 0;

  @override
  ComplaintFormState build() {
    Future.microtask(_loadCategories);
    return const ComplaintFormState(categoriesLoading: true);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(complaintApiProvider).listTaskCategories();
      if (!ref.mounted) return;
      state = state.copyWith(
        categoriesLoading: false,
        // Pasif kategoriye yeni talep yazilmaz — yalniz aktifler secilebilir.
        categories: cats.where((c) => c.aktif).toList(growable: false),
        categoriesError: null,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(categoriesLoading: false, categoriesError: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        categoriesLoading: false,
        categoriesError: 'Kategoriler yüklenemedi.',
      );
    }
  }

  void setKategori(String? id) => state = state.copyWith(kategoriId: id);

  /// Kamera/galeriden foto secip yeni bir yuva olusturur ve yukler. 3 yuva
  /// doluysa hicbir sey yapmaz. Secim/okuma hatasinda kullaniciya
  /// gosterilecek mesaji doner (null = hata yok).
  Future<String?> addPhoto(ImageSource source) async {
    if (!state.canAddPhoto) return null;
    final XFile? file;
    try {
      file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Talep gorseli icin cozunurluk/kalite dusurulur (yukleme boyutu).
            maxWidth: 1600,
            imageQuality: 80,
          );
    } catch (e) {
      return 'Fotoğraf alınamadı: $e';
    }
    if (file == null || !ref.mounted) return null;
    final id = _nextId++;
    state = state.copyWith(
      photos: [...state.photos, PhotoSlot(id: id, path: file.path, busy: true)],
    );
    await _upload(id, file);
    return null;
  }

  Future<void> retry(int id) async {
    PhotoSlot? slot;
    for (final p in state.photos) {
      if (p.id == id) {
        slot = p;
        break;
      }
    }
    if (slot == null || slot.busy) return;
    _patch(id, (s) => s.copyWith(busy: true, error: null));
    await _upload(id, XFile(slot.path));
  }

  void remove(int id) => state = state.copyWith(
        photos: [
          for (final p in state.photos)
            if (p.id != id) p,
        ],
      );

  Future<void> _upload(int id, XFile file) async {
    final api = ref.read(complaintApiProvider);
    try {
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      final bytes = await file.readAsBytes();
      await api.uploadPhoto(
        ticket: ticket,
        bytes: bytes,
        contentType: contentType,
      );
      if (!ref.mounted) return;
      _patch(id, (s) => s.copyWith(busy: false, fotoKey: ticket.fotoKey, error: null));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      _patch(
        id,
        (s) => s.copyWith(
          busy: false,
          error: e.kind == ApiErrorKind.network
              ? 'Fotoğraf yüklemek için internet bağlantısı gerekli '
                  '(yükleme adresi kısa ömürlü). Bağlantı gelince '
                  '"Tekrar yükle" ile deneyin.'
              : e.message,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      _patch(id, (s) => s.copyWith(busy: false, error: 'Fotoğraf yüklenemedi.'));
    }
  }

  void _patch(int id, PhotoSlot Function(PhotoSlot) transform) {
    state = state.copyWith(
      photos: [
        for (final p in state.photos) p.id == id ? transform(p) : p,
      ],
    );
  }
}

final complaintFormControllerProvider =
    NotifierProvider.autoDispose<ComplaintFormController, ComplaintFormState>(
  ComplaintFormController.new,
);

/// image_picker mimeType vermezse uzantidan tahmin (gorev akisiyla ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}
