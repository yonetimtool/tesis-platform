import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
// Atanabilir personel (aktif security/tesis_gorevlisi) listesi gorev
// atama akisiyla AYNI kaynaktan gelir — kopya yok.
import '../../tasks/data/task_api.dart';
import '../../tasks/domain/task_models.dart' show AssignableUser;
import '../../tasks/domain/task_category_models.dart' show TaskCategory;
import '../data/complaint_api.dart' show complaintApiProvider;
import '../domain/complaint_models.dart';
import '../domain/talep_hata.dart';
import 'talep_hata_metni.dart';
import 'complaints_controller.dart';
import '../../../core/theme/home_tokens.dart';

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
    ref.listen(
      complaintsControllerProvider,
      (_, next) => _maybeOpenInitial(next),
    );
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    // Sekme ayrimi durum bazli. "Açık" bilinmeyen durumu da toplar (ileriye
    // uyum: yeni bir sunucu durumu kaybolmasin). Durum degisince kayit
    // sekme degistirir (refresh sonrasi otomatik).
    final acik = state.items
        .where(
          (c) => c.durum == TalepDurum.acik || c.durum == TalepDurum.unknown,
        )
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
          title: Text(
            baslikBuyuk(context.l10n.kartTalepAriza, context.dilKodu),
          ),
          actions: [
            IconButton(
              tooltip: context.l10n.ortakYenile,
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            // Dort sekme dar ekranda sigmaz — kaydirilabilir.
            isScrollable: true,
            tabs: [
              Tab(text: context.l10n.talepSekmeAcik('${acik.length}')),
              Tab(text: context.l10n.talepSekmeIsEmri('${isEmri.length}')),
              Tab(text: context.l10n.talepSekmeCozulen('${cozulen.length}')),
              Tab(
                text: context.l10n.talepSekmeReddedilen('${reddedilen.length}'),
              ),
            ],
          ),
        ),
        floatingActionButton: state.canCreate
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(context.l10n.talepYeni),
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
                    ? context.l10n.talepAcikYokSakin
                    : context.l10n.talepAcikYok,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: isEmri,
                emptyText: context.l10n.talepIsEmriYok,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: cozulen,
                emptyText: context.l10n.talepCozulenYok,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: reddedilen,
                emptyText: context.l10n.talepReddedilenYok,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.talepIletildi)));
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
    final hataMetni = akisHatasiCoz(
      context.l10n,
      state.hataKimligi,
      state.errorMessage,
    );
    if (hataMetni != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            hataMetni,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(emptyText, textAlign: TextAlign.center))],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _ComplaintCard(complaint: items[i], canRespond: state.canRespond),
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

/// Durum rozetinin AKTIF DILDEKI etiketi (enum METIN TASIMAZ; `default` dali
/// yok — yeni durum eklenince derleyici ceviriyi zorlar).
String _durumLabel(AppLocalizations l10n, TalepDurum d) => switch (d) {
  TalepDurum.acik => l10n.talepDurumAcik,
  TalepDurum.isEmri => l10n.talepDurumIsEmri,
  TalepDurum.cozuldu => l10n.talepDurumCozuldu,
  TalepDurum.reddedildi => l10n.talepDurumReddedildi,
  TalepDurum.unknown => l10n.devriyeDurumBilinmiyor,
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
        _durumLabel(context.l10n, durum),
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
                      '${canRespond ? '${c.acanAd ?? context.l10n.talepAcanSakin} · ' : ''}'
                      '${tarihSaatBicimi(c.createdAt, context.dilKodu, ayirici: '')}',
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
/// acilis) ayni yoldan cagrilir. Yonetici (canRespond) + durum==acik iken
/// altta donustur/coz/reddet eylem cubugu ([_YoneticiActionBar]) gosterilir.
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

/// Detay sheet'i: baslik + durum + meta + mesaj + kategori + foto galerisi
/// (buyutulebilir) + dikey durum timeline'i (gecmis[]) + bagli is emri
/// durumu. Yonetici (canRespond) + durum==acik iken altta donustur/coz/reddet
/// eylem cubugu ([_YoneticiActionBar]).
class _ComplaintDetail extends StatelessWidget {
  const _ComplaintDetail({required this.complaint, required this.canRespond});

  final Complaint complaint;

  /// admin/yonetici mi — eylem cubugunun gorunurlugunu belirler.
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
              '${canRespond ? '${c.acanAd ?? context.l10n.talepAcanSakin} · ' : ''}'
              '${tarihSaatBicimi(c.createdAt, context.dilKodu, ayirici: '')}',
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
                baslikBuyuk(context.l10n.talepDurumGecmisi, context.dilKodu),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _StatusTimeline(gecmis: c.gecmis),
            ],
            // Yonetici eylemleri YALNIZ acik talepte anlamli (durum makinesi:
            // convert/decline yalniz acik'ten; resolve acik VEYA is_emri'den).
            // Non-acik durumlarda eylem cubugu hic cizilmez (backend zaten 422
            // invalid_transition ile korur; UX bunu onceden gizler).
            if (canRespond && c.durum == TalepDurum.acik) ...[
              const Divider(height: 24),
              _YoneticiActionBar(complaint: c),
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
    // Klavyeyle de acilabilmeli (tur 33).
    // Fotograf ekran okuyucuda ADSIZDI (tur 34): "resim, dugme" diye
    // okunuyordu. Etiket DOKUNULABILIR dugumle birlesmeli —
    // `MergeSemantics` olmadan ayri bir alt dugumde kalir.
    return MergeSemantics(
      child: Semantics(
        label: context.l10n.ortakFotografiBuyut,
        child: InkWell(
          onTap: () => _openFullScreen(context),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              // Etiketsiz gorsel ekran okuyucuda HIC duyurulmaz (tur 34).
              semanticLabel: context.l10n.ortakFotograf,
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
                child: Row(
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.talepGorselYuklenemedi),
                  ],
                ),
              ),
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
                // Etiketsiz gorsel ekran okuyucuda HIC duyurulmaz (tur 34).
                semanticLabel: context.l10n.ortakFotograf,
                errorBuilder: (_, _, _) => Text(
                  context.l10n.talepGorselYuklenemedi,
                  style: const TextStyle(color: Colors.white),
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
      'acik' => (context.l10n.talepIsEmriAtandi, Colors.blue),
      'tamamlandi' => (context.l10n.talepIsEmriTamamlandi, Colors.green),
      _ => (context.l10n.talepIsEmriDurumBilinmiyor, Colors.grey),
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
                context.l10n.talepIsEmri,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: okunurVurgu(context, color),
                fontWeight: FontWeight.w600,
              ),
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
          _TimelineNode(row: gecmis[i], isLast: i == gecmis.length - 1),
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
    final rolLabel = rolAdi(context.l10n, UserRole.fromClaim(row.actorRole));
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
                        _durumLabel(context.l10n, row.durum),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tarihSaatBicimi(
                          row.createdAt,
                          context.dilKodu,
                          ayirici: '',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Text(rolLabel, style: Theme.of(context).textTheme.bodySmall),
                  if (row.sebep != null && row.sebep!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      row.sebep!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
  /// `setState`/async yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

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
              title: Text(context.l10n.gorevKamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.gorevGaleridenSec),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final ayrinti = await _form.addPhoto(source);
    if (ayrinti != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            talepHataMetni(_l10n, TalepAkisHatasi.fotoAlinamadi, ayrinti),
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final formState = ref.read(complaintFormControllerProvider);
    if (formState.uploadPending) {
      setState(() {
        _error = _l10n.gorevFotoHenuzYuklenmedi;
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
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
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
                context.l10n.talepYeniBaslik,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baslikCtrl,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: context.l10n.talepBaslikAlan,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.talepBaslikZorunlu
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mesajCtrl,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: context.l10n.talepAciklamaAlan,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.talepAciklamaZorunlu
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
                  label: Text(
                    _saving
                        ? context.l10n.gorevGonderiliyor
                        : context.l10n.talepGonder,
                  ),
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
        Text(context.l10n.talepKategoriOpsiyonel),
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
        else if (talepHatasiCoz(
              context.l10n,
              state.categoriesHata,
              state.categoriesError,
            )
            case final kategoriHata?)
          Text(
            kategoriHata,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          )
        else if (state.categories.isEmpty)
          Text(
            context.l10n.talepKategoriYok,
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
        Text(context.l10n.talepGorseller),
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
          // Yuva hatasi METIN gostermez (yalniz yeniden-dene kaplamasi) —
          // bu yuzden kimligi cozmeye gerek yok, VARLIGI yeterli.
          if ((slot.hata != null || slot.error != null) && !slot.busy)
            Positioned.fill(
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(8),
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
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
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
        // Kutu YAZI OLCEGIYLE buyur: 96x96 sabitken 2.0x olcekte icerik
        // 30 px tasiyordu (tur 38). Ust sinir izgarayi bozmayacak kadar.
        width: MediaQuery.textScalerOf(context).scale(96).clamp(96.0, 150.0),
        height: MediaQuery.textScalerOf(context).scale(96).clamp(96.0, 150.0),
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
              Flexible(
                child: Text(
                  context.l10n.ortakEkle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yonetici eylem cubugu (detay sheet'inin altinda; yalniz canRespond +
/// durum==acik iken cizilir). Uc eylem: "İş Emrine Dönüştür" (birincil),
/// "Çöz", "Reddet". Her biri kendi bottom-sheet'ini acar; islem basarili
/// olursa detay sheet'i KAPANIR (elimizdeki [complaint] kopyasi bayatladi —
/// guncel hali tazelenmis listededir) ve bir SnackBar gosterilir.
class _YoneticiActionBar extends ConsumerWidget {
  const _YoneticiActionBar({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          baslikBuyuk(context.l10n.talepYoneticiIslemleri, context.dilKodu),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _open(
            context,
            Text(context.l10n.talepIsEmrineDonusturuldu),
            (_) => _ConvertSheet(complaint: complaint),
          ),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: Text(context.l10n.talepIsEmrineDonusturBuyuk),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _open(
                  context,
                  Text(context.l10n.talepCozuldu),
                  (_) => _ResolveSheet(complaint: complaint),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(context.l10n.talepCoz),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _open(
                  context,
                  Text(context.l10n.talepReddedildiBildirim),
                  (_) => _DeclineSheet(complaint: complaint),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(context.l10n.talepReddet),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Ortak akis: eylem sheet'ini ac, `true` donerse detay sheet'ini kapat +
  /// SnackBar. Messenger pop'tan ONCE yakalanir (pop sonrasi bu context'in
  /// alt-agaci soker).
  Future<void> _open(
    BuildContext context,
    Widget successMessage,
    WidgetBuilder builder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: builder,
    );
    if (ok != true) return;
    navigator.pop(); // detay sheet'ini kapat (durum degisti, kopya bayat)
    messenger.showSnackBar(SnackBar(content: successMessage));
  }
}

/// "İş Emrine Dönüştür" sheet'i — kategori (talepten on-dolu, degistirilebilir),
/// oncelik (SegmentedButton dusuk|orta|yuksek), atanan personel (ZORUNLU;
/// aktif security/tesis_gorevlisi) + opsiyonel not. Gonderim
/// [ComplaintsController.convert] uzerinden; basari `true` ile kapanir.
class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  /// `setState`/async yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  final _notCtrl = TextEditingController();
  TalepOncelik _oncelik = TalepOncelik.orta;
  late String? _kategoriId = widget.complaint.kategoriId;
  String? _atananUserId;

  /// Atanabilir personel (bir kez yuklenir); null → yukleniyor.
  List<AssignableUser>? _personel;
  String? _personelError;

  /// Aktif gorev kategorileri (talep kategorisiyle ayni kaynak); null → yukleniyor.
  List<TaskCategory>? _kategoriler;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPersonel();
    _loadKategoriler();
  }

  @override
  void dispose() {
    _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPersonel() async {
    try {
      final users = await ref.read(taskApiProvider).fetchAssignableUsers();
      if (!mounted) return;
      setState(() => _personel = users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _personel = const [];
        _personelError = apiHataMetni(_l10n, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _personel = const [];
        _personelError = _l10n.talepPersonelAlinamadiKisa;
      });
    }
  }

  Future<void> _loadKategoriler() async {
    try {
      final cats = await ref.read(complaintApiProvider).listTaskCategories();
      if (!mounted) return;
      final aktifler = cats.where((c) => c.aktif).toList(growable: false);
      setState(() {
        // On-dolu kategori pasiflestiyse/silindiyse listede olmayabilir —
        // secimi koru ama secenege "(silinmiş)" olarak ekle.
        if (_kategoriId != null && !aktifler.any((k) => k.id == _kategoriId)) {
          _kategoriler = [
            ...aktifler,
            // Ad BOS: "silinmis" etiketi cizim aninda cozulur.
            TaskCategory(id: _kategoriId!, ad: '', aktif: false),
          ];
        } else {
          _kategoriler = aktifler;
        }
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _kategoriler = const []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _kategoriler = const []);
    }
  }

  Future<void> _submit() async {
    final atanan = _atananUserId;
    if (atanan == null) return; // buton zaten pasif; savunmaci
    setState(() {
      _saving = true;
      _error = null;
    });
    final not = _notCtrl.text.trim();
    final draft = ComplaintConvertDraft(
      atananUserId: atanan,
      oncelik: _oncelik,
      kategoriId: _kategoriId,
      not_: not.isEmpty ? null : not,
    );
    try {
      await ref
          .read(complaintsControllerProvider.notifier)
          .convert(widget.complaint.id, draft);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _personel == null || _kategoriler == null;
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
            Text(
              context.l10n.talepIsEmrineDonustur,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Kategori — talepten on-dolu, degistirilebilir; "Diğer" = null.
              DropdownButtonFormField<String?>(
                initialValue: _kategoriler!.any((k) => k.id == _kategoriId)
                    ? _kategoriId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.butKategori,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.gorevKategoriDiger),
                  ),
                  for (final k in _kategoriler!)
                    DropdownMenuItem<String?>(
                      value: k.id,
                      child: Text(k.ad, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _kategoriId = v),
              ),
              const SizedBox(height: 16),
              Text(context.l10n.gorevOncelik),
              const SizedBox(height: 4),
              SegmentedButton<TalepOncelik>(
                segments: [
                  ButtonSegment(
                    value: TalepOncelik.dusuk,
                    label: Text(context.l10n.gorevOncelikDusuk),
                  ),
                  ButtonSegment(
                    value: TalepOncelik.orta,
                    label: Text(context.l10n.gorevOncelikOrta),
                  ),
                  ButtonSegment(
                    value: TalepOncelik.yuksek,
                    label: Text(context.l10n.gorevOncelikYuksek),
                  ),
                ],
                selected: {_oncelik},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _oncelik = s.first),
              ),
              const SizedBox(height: 16),
              // Atanan — ZORUNLU (convert atanansiz 422). Yalniz aktif
              // security/tesis_gorevlisi listelenir.
              DropdownButtonFormField<String?>(
                initialValue: _atananUserId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.gorevAtananPersonel,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final u in _personel!)
                    DropdownMenuItem<String?>(
                      value: u.id,
                      child: Text(
                        u.role.isEmpty
                            ? u.ad
                            : '${u.ad} '
                                  '(${rolAdi(context.l10n, UserRole.fromClaim(u.role))})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _atananUserId = v),
              ),
              if (_personelError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.l10n.gorevPersonelAlinamadi(_personelError!),
                    style: const TextStyle(color: Colors.orange),
                  ),
                )
              else if (_personel!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.l10n.talepAtanabilirPersonelYok,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _notCtrl,
                minLines: 2,
                maxLines: 4,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: context.l10n.ortakNotOpsiyonel,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Atanan secilene kadar pasif (convert atanan ZORUNLU).
                  onPressed: (_saving || _atananUserId == null)
                      ? null
                      : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(
                    _saving
                        ? context.l10n.talepDonusturuluyor
                        : context.l10n.talepDonustur,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Reddet" sheet'i — `sebep` ZORUNLU; buton sebep bosken pasif. Gonderim
/// [ComplaintsController.decline] uzerinden.
class _DeclineSheet extends ConsumerStatefulWidget {
  const _DeclineSheet({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends ConsumerState<_DeclineSheet> {
  /// `setState`/async yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  final _sebepCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _sebepCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sebep = _sebepCtrl.text.trim();
    if (sebep.isEmpty) return; // buton zaten pasif; savunmaci
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(complaintsControllerProvider.notifier)
          .decline(widget.complaint.id, ComplaintDeclineDraft(sebep: sebep));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              context.l10n.talepRedBaslik,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.talepRetSebebiNot,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sebepCtrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              enabled: !_saving,
              // Sebep degisince buton aktifligi guncellenmeli.
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.talepRetSebebi,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: yikiciDugmeStili(context),
                // Sebep bosken pasif.
                onPressed: (_saving || _sebepCtrl.text.trim().isEmpty)
                    ? null
                    : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(
                  _saving
                      ? context.l10n.talepReddediliyor
                      : context.l10n.talepReddet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Çöz" sheet'i — cozum notu OPSIYONEL. Gonderim
/// [ComplaintsController.resolve] uzerinden.
class _ResolveSheet extends ConsumerStatefulWidget {
  const _ResolveSheet({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends ConsumerState<_ResolveSheet> {
  /// `setState`/async yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  final _notCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final not = _notCtrl.text.trim();
    try {
      await ref
          .read(complaintsControllerProvider.notifier)
          .resolve(
            widget.complaint.id,
            ComplaintResolveDraft(cozumNotu: not.isEmpty ? null : not),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              context.l10n.talepCozBaslik,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.talepCozNot,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notCtrl,
              minLines: 2,
              maxLines: 4,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: context.l10n.talepCozumNotu,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
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
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _saving
                      ? context.l10n.ortakKaydediliyor
                      : context.l10n.talepCoz,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
