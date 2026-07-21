import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/text/tr_upper.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/domain/user_role.dart';
import '../domain/complaint_models.dart';
import 'complaints_controller.dart';

/// "Talep / Arıza" (İş Emri) — yasayan/calisandan yonetime kanal (auth.md §4
/// kesin kurali, UX aynasi):
///   * acan roller (security/tesis_gorevlisi/resident): KENDI talepleri +
///     "Yeni talep" FAB'i; durumu okur, eylem yapamaz.
///   * admin/yonetici: tenant'taki TUM talepler; detayda donustur/coz/reddet
///     (Task 13), yeni talep ACAMAZ (FAB yok).
///
/// [initialComplaintId] push tiklamasindan gelir (?complaint_id=...): liste
/// yuklendiginde ilgili talebin detayi BIR KEZ otomatik acilir; kayit
/// listede yoksa (silinmis/yetki disi) sessizce listede kalinir.
class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key, this.initialComplaintId});

  final String? initialComplaintId;

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(ComplaintsState state) {
    if (_initialHandled || widget.initialComplaintId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Complaint? hedef;
    for (final c in state.items) {
      if (c.id == widget.initialComplaintId) {
        hedef = c;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final c = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showComplaintDetail(context, c, canRespond: state.canRespond);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(complaintsControllerProvider);
    final controller = ref.read(complaintsControllerProvider.notifier);
    ref.listen(complaintsControllerProvider, (_, next) => _maybeOpenInitial(next));
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    // Sekme ayrimi durum bazli. "Açık" bilinmeyen durumu da toplar (ileriye
    // uyum: yeni bir sunucu durumu kaybolmasin). Durum degisince kayit
    // sekme degistirir (refresh sonrasi otomatik).
    final acik = state.items
        .where((c) =>
            c.durum == TalepDurum.acik || c.durum == TalepDurum.unknown)
        .toList(growable: false);
    final isEmri = state.items
        .where((c) => c.durum == TalepDurum.isEmri)
        .toList(growable: false);
    final cozulen = state.items
        .where((c) => c.durum == TalepDurum.cozuldu)
        .toList(growable: false);
    final reddedilen = state.items
        .where((c) => c.durum == TalepDurum.reddedildi)
        .toList(growable: false);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trUpper('Talep / Arıza')),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            // Dort sekme dar ekranda sigmaz — kaydirilabilir.
            isScrollable: true,
            tabs: [
              Tab(text: 'Açık (${acik.length})'),
              Tab(text: 'İş Emri (${isEmri.length})'),
              Tab(text: 'Çözülen (${cozulen.length})'),
              Tab(text: 'Reddedilen (${reddedilen.length})'),
            ],
          ),
        ),
        floatingActionButton: state.canCreate
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Yeni talep'),
                onPressed: () => _openForm(context),
              )
            : null,
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: acik,
                emptyText: state.canCreate
                    ? 'Açık talebiniz yok. "Yeni talep" ile '
                        'talep/arızanızı iletebilirsiniz.'
                    : 'Açık talep yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: isEmri,
                emptyText: 'İş emrine dönüşen talep yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: cozulen,
                emptyText: 'Henüz çözülen talep yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: reddedilen,
                emptyText: 'Reddedilen talep yok.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComplaintForm(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talebiniz iletildi ✓')),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.items,
    required this.emptyText,
  });

  final ComplaintsState state;

  /// Bu sekmenin durum-suzgecli kayitlari.
  final List<Complaint> items;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Text(emptyText, textAlign: TextAlign.center)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      itemBuilder: (context, i) => _ComplaintCard(
        complaint: items[i],
        canRespond: state.canRespond,
      ),
    );
  }
}

/// Ticketing durum paleti (Task 11 brief): acik=amber, isEmri=blue,
/// cozuldu=green, reddedildi=red, unknown=grey.
Color _durumColor(TalepDurum d) => switch (d) {
      TalepDurum.acik => Colors.amber,
      TalepDurum.isEmri => Colors.blue,
      TalepDurum.cozuldu => Colors.green,
      TalepDurum.reddedildi => Colors.red,
      TalepDurum.unknown => Colors.grey,
    };

/// Durum rozetinin Turkce etiketi (model tel degerinin gorunum aynasi).
String _durumLabel(TalepDurum d) => switch (d) {
      TalepDurum.acik => 'Açık',
      TalepDurum.isEmri => 'İş Emri',
      TalepDurum.cozuldu => 'Çözüldü',
      TalepDurum.reddedildi => 'Reddedildi',
      TalepDurum.unknown => 'Bilinmiyor',
    };

/// Durum rozeti — [_durumColor] paletiyle renklenir.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final TalepDurum durum;

  @override
  Widget build(BuildContext context) {
    final color = _durumColor(durum);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _durumLabel(durum),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Opsiyonel talep kategorisi rozeti (kategori adi null ise HIC cizilmez).
class _KategoriChip extends StatelessWidget {
  const _KategoriChip({required this.ad});

  final String ad;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            ad,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends ConsumerWidget {
  const _ComplaintCard({required this.complaint, required this.canRespond});

  final Complaint complaint;
  final bool canRespond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = complaint;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showComplaintDetail(context, c, canRespond: canRespond),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.baslik,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _DurumChip(durum: c.durum),
                ],
              ),
              const SizedBox(height: 4),
              Text(c.mesaj, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (c.kategoriAd != null) ...[
                const SizedBox(height: 6),
                _KategoriChip(ad: c.kategoriAd!),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (c.fotograflar.isNotEmpty) ...[
                    const Icon(Icons.image_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${c.fotograflar.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      // Yonetim gorunumunde kim actigi onemli; acan zaten
                      // yalniz kendi taleplerini gorur.
                      '${canRespond ? '${c.acanAd ?? 'Sakin'} · ' : ''}'
                      '${_fmtDateTime(c.createdAt.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Talep detay sheet'i — kart dokunusundan ve push tiklamasindan (otomatik
/// acilis) ayni yoldan cagrilir.
///
/// TODO(Task 12): foto galerisi + durum gecis timeline'i (gecmis[]).
/// TODO(Task 13): yonetici donustur/coz/reddet eylem sheet'leri.
Future<void> _showComplaintDetail(
  BuildContext context,
  Complaint complaint, {
  required bool canRespond,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ComplaintDetail(complaint: complaint, canRespond: canRespond),
  );
}

/// Salt-okunur detay sheet'i: baslik + durum + meta + mesaj + kategori +
/// foto galerisi (buyutulebilir) + dikey durum timeline'i (gecmis[]) + bagli
/// is emri durumu. Yonetici donustur/coz/reddet eylemleri (Task 13) BURADA
/// DEGIL — bilerek stub birakildi.
class _ComplaintDetail extends StatelessWidget {
  const _ComplaintDetail({required this.complaint, required this.canRespond});

  final Complaint complaint;

  /// admin/yonetici mi — su an yalniz "eylemler yakinda" ipucu; gercek
  /// donustur/coz/reddet Task 13'te eklenecek.
  final bool canRespond;

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.baslik,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _DurumChip(durum: c.durum),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${canRespond ? '${c.acanAd ?? 'Sakin'} · ' : ''}'
              '${_fmtDateTime(c.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (c.kategoriAd != null) ...[
              const SizedBox(height: 8),
              _KategoriChip(ad: c.kategoriAd!),
            ],
            const SizedBox(height: 12),
            Text(c.mesaj),
            // Foto galerisi — sira alanina gore, buyutulebilir onizleme.
            _PhotoGallery(fotograflar: c.fotograflar),
            // Bagli is emri kaninca (durum == is_emri) canli ozet durum.
            if (c.durum == TalepDurum.isEmri)
              _LinkedWorkOrderCard(isEmriDurum: c.isEmriDurum),
            // Durum gecis timeline'i (gecmis[], created_at ASC).
            if (c.gecmis.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                trUpper('Durum geçmişi'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _StatusTimeline(gecmis: c.gecmis),
            ],
            // TODO(Task 13): admin/yonetici donustur/coz/reddet eylemleri.
            if (canRespond) ...[
              const Divider(height: 24),
              Text(
                'Yönetici işlemleri (dönüştür / çöz / reddet) yakında.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detay foto galerisi — [ComplaintPhoto.sira] sirasina gore dizilir; her
/// gorsel dokununca tam ekran [InteractiveViewer]'da acilir (duyuru foto
/// desenin aynasi). URL yoksa/gorsel yuklenemezse kirik-gorsel satiri.
class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.fotograflar});

  final List<ComplaintPhoto> fotograflar;

  @override
  Widget build(BuildContext context) {
    final fotolar = fotograflar.where((f) => f.fotoUrl != null).toList()
      ..sort((a, b) => a.sira.compareTo(b.sira));
    if (fotolar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final foto in fotolar) ...[
          const SizedBox(height: 8),
          _GalleryPhoto(url: foto.fotoUrl!),
        ],
      ],
    );
  }
}

/// Tek galeri gorseli: kartta onizleme; dokununca tam ekran (duyuru
/// `_AnnouncementPhoto` deseniyle ayni).
class _GalleryPhoto extends StatelessWidget {
  const _GalleryPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, _, _) => Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Row(
              children: [
                Icon(Icons.broken_image_outlined, size: 20),
                SizedBox(width: 8),
                Text('Görsel yüklenemedi'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const Text(
                  'Görsel yüklenemedi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bagli is emri (Task) canli ozet durum karti — durum == is_emri iken
/// gosterilir. `is_emri_durum`: 'acik' → "Atandı", 'tamamlandi' →
/// "Tamamlandı"; bilinmeyen/null → notr metin.
class _LinkedWorkOrderCard extends StatelessWidget {
  const _LinkedWorkOrderCard({required this.isEmriDurum});

  final String? isEmriDurum;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (isEmriDurum) {
      'acik' => ('Atandı', Colors.blue),
      'tamamlandi' => ('Tamamlandı', Colors.green),
      _ => ('Durum bilinmiyor', Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'İş emri',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dikey durum timeline'i — [ComplaintHistory] satirlarindan (created_at ASC,
/// backend sirasi korunur). Her dugum: renkli nokta + baglanti cizgisi + TR
/// durum etiketi, actor rolu, opsiyonel `sebep` ve yerel zaman damgasi. Yeni
/// paket YOK; basit Column/Row.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.gecmis});

  final List<ComplaintHistory> gecmis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < gecmis.length; i++)
          _TimelineNode(
            row: gecmis[i],
            isLast: i == gecmis.length - 1,
          ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.row, required this.isLast});

  final ComplaintHistory row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _durumColor(row.durum);
    final rolLabel = UserRole.fromClaim(row.actorRole).label;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nokta + baglanti cizgisi (son dugumde cizgi yok).
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _durumLabel(row.durum),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmtDateTime(row.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Text(
                    rolLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (row.sebep != null && row.sebep!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(row.sebep!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni talep formu (bottom sheet, acan roller: saha + sakin). Sunucu
/// sinirlari istemcide de uygulanir: baslik <= 200, mesaj <= 5000, bos deger
/// gonderilmez. En fazla 3 gorsel: cek/sec → presign → PUT → foto_key
/// (gorev/duyuru foto akisiyla ayni desen, [ComplaintFormController]).
class _ComplaintForm extends ConsumerStatefulWidget {
  const _ComplaintForm();

  @override
  ConsumerState<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends ConsumerState<_ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final _baslikCtrl = TextEditingController();
  final _mesajCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _baslikCtrl.dispose();
    _mesajCtrl.dispose();
    super.dispose();
  }

  ComplaintFormController get _form =>
      ref.read(complaintFormControllerProvider.notifier);

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final err = await _form.addPhoto(source);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final formState = ref.read(complaintFormControllerProvider);
    if (formState.uploadPending) {
      setState(() {
        _error = 'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin, '
            '"Tekrar yükle"yi deneyin veya fotoyu kaldırın.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = ComplaintDraft(
      baslik: _baslikCtrl.text.trim(),
      mesaj: _mesajCtrl.text.trim(),
      kategoriId: formState.kategoriId,
      fotoKeys: formState.fotoKeys,
    );
    try {
      await ref.read(complaintsControllerProvider.notifier).create(draft);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(complaintFormControllerProvider);
    return Padding(
      // Klavye acildiginda formun gorunur kalmasi icin.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        // Gorsel onizleme + klavye ile icerik uzayabilir — tasma yerine kaydir.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni talep / arıza',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baslikCtrl,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Başlık zorunludur' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mesajCtrl,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Açıklama zorunludur'
                    : null,
              ),
              const SizedBox(height: 8),
              _CategoryPicker(
                state: formState,
                saving: _saving,
                onSelect: _saving ? null : _form.setKategori,
              ),
              const SizedBox(height: 12),
              _PhotoRow(
                state: formState,
                saving: _saving,
                onAdd: _saving ? null : _pickPhoto,
                onRetry: _saving ? null : (id) => _form.retry(id),
                onRemove: _saving ? null : (id) => _form.remove(id),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'Gönderiliyor...' : 'Gönder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kategori secici (opsiyonel → null = "Diğer"). Yuklenirken kucuk gosterge,
/// hata olursa mesaj, bos ise gizli. Tekrar dokunmak secimi kaldirir.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.state,
    required this.saving,
    required this.onSelect,
  });

  final ComplaintFormState state;
  final bool saving;

  /// null-argümanla cagrilinca secim kalkar (kategori zorunlu degil).
  final void Function(String?)? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kategori (opsiyonel)'),
        const SizedBox(height: 4),
        if (state.categoriesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (state.categoriesError != null)
          Text(
            state.categoriesError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          )
        else if (state.categories.isEmpty)
          Text(
            'Tanımlı kategori yok; talep "Diğer" olarak açılır.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            children: [
              for (final k in state.categories)
                ChoiceChip(
                  label: Text(k.ad),
                  selected: state.kategoriId == k.id,
                  onSelected: (saving || onSelect == null)
                      ? null
                      : (selected) => onSelect!(selected ? k.id : null),
                ),
            ],
          ),
      ],
    );
  }
}

/// En fazla 3 foto thumbnail'i + "Ekle" karosu (3'te pasif). Her thumbnail:
/// yukleme sirasi (progress), hata (Tekrar yükle) veya tamamlandi (tik).
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.state,
    required this.saving,
    required this.onAdd,
    required this.onRetry,
    required this.onRemove,
  });

  final ComplaintFormState state;
  final bool saving;
  final VoidCallback? onAdd;
  final void Function(int id)? onRetry;
  final void Function(int id)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Görseller (opsiyonel, en fazla 3)'),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final slot in state.photos) ...[
                _PhotoThumb(
                  slot: slot,
                  onRetry: onRetry == null ? null : () => onRetry!(slot.id),
                  onRemove: onRemove == null ? null : () => onRemove!(slot.id),
                ),
                const SizedBox(width: 8),
              ],
              if (state.canAddPhoto)
                _AddPhotoTile(
                  onTap: (saving || state.uploading) ? null : onAdd,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.slot,
    required this.onRetry,
    required this.onRemove,
  });

  final PhotoSlot slot;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(slot.path),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          if (slot.busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          if (slot.error != null && !slot.busy)
            Positioned.fill(
              child: GestureDetector(
                onTap: onRetry,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.refresh, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (slot.fotoKey != null)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined),
              const SizedBox(height: 4),
              Text('Ekle', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
