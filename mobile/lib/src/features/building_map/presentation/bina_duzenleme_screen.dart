import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/tr_upper.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../domain/bina_duzenleme_models.dart';
import 'bina_duzenleme_controller.dart';

/// "Bina Düzenleme" (D-viz Rev-2) — yonetim GORSEL olarak binayi kurar:
/// blok ekle → blok kutucugu belirir → icine gir → kat + daire ekle. Daireler
/// katina yerlesir, ayni kattakiler yan yana (Sikayet Haritasi semasini yansitir).
/// Blok-suz siteler: mod anahtariyla duz numaralandirma (blok=null).
///
/// Mevcut CRUD uclarini kullanir (yeni backend YOK): /blocks + /units + layout.
/// Yazma admin+yonetici (backend RBAC zorlar). Blok silme, daire varsa 409 doner
/// — mesaj acikca gosterilir.
///
/// SALT-OKUMA: security + tesis_gorevlisi ayni ekrani GORUR ama TUM duzenleme
/// eylemleri (blok/kat/daire ekle-duzenle-sil, yerlesim) gizlenir/kapalidir —
/// yalniz mevcut yapiyi referans olarak gorurler. Backend zaten yazmalarini
/// 403 ile reddeder; bu istemci kapisi UX aynasidir.
class BinaDuzenlemeScreen extends ConsumerStatefulWidget {
  const BinaDuzenlemeScreen({super.key});

  @override
  ConsumerState<BinaDuzenlemeScreen> createState() =>
      _BinaDuzenlemeScreenState();
}

/// Blok-suz kova icin sentinel etiket (gercek blok etiketi min 1 karakter).
const String _blocklessKey = '';

class _BinaDuzenlemeScreenState extends ConsumerState<BinaDuzenlemeScreen> {
  /// Acik blok: null = kutucuk listesi; '' = bloksuz kova; aksi = o blok.
  /// Bloklu ve bloksuz (blok=null) daireler AYNI akista: kutucuk listesi + bir
  /// "Bloksuz" kovasi (mod anahtari yok).
  String? _openBlock;

  /// Onizlemede daire eklenmeden gorunen bos katlar (yerel; daire eklenince
  /// kalicilasir). Acik blok degisince sifirlanir.
  final Set<int> _pendingFloors = {};

  void _openBlockTile(String label) {
    setState(() {
      _openBlock = label;
      _pendingFloors.clear();
    });
  }

  void _closeBlock() {
    setState(() {
      _openBlock = null;
      _pendingFloors.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(binaDuzenlemeControllerProvider);
    final controller = ref.read(binaDuzenlemeControllerProvider.notifier);
    final drilledIn = _openBlock != null;
    // SALT-OKUMA: yazma yalniz admin+yonetici; diger roller (security/
    // tesis_gorevlisi) duzenleme eylemlerini gormez. Rol cozulene kadar
    // (null) guvenli taraf: salt-okuma kabul et.
    final role = ref.watch(currentUserRoleProvider).value;
    final readOnly = !(role == UserRole.admin || role == UserRole.yonetici);

    return Scaffold(
      appBar: AppBar(
        leading: drilledIn ? BackButton(onPressed: _closeBlock) : null,
        title: Text(trUpper(_titleFor(readOnly))),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _body(state, readOnly),
      ),
    );
  }

  String _titleFor(bool readOnly) {
    if (_openBlock != null) {
      return _openBlock == _blocklessKey
          ? 'Blok atanmamış'
          : 'Blok $_openBlock';
    }
    // Salt-okuma rollerinde baslik "Bina Yapisi" (duzenleme cagrismasi olmasin).
    return readOnly ? 'Bina Yapısı' : 'Bina Düzenleme';
  }

  Widget _body(BinaDuzenlemeState state, bool readOnly) {
    if (state.loading && state.bos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.bos) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.errorMessage!)),
        ],
      );
    }

    // Bir bloga (veya bloksuz kovaya) girildi → kat plani.
    if (_openBlock != null) {
      return _BlockDetail(
        key: ValueKey('block-$_openBlock'),
        label: _openBlock!,
        state: state,
        pendingFloors: _pendingFloors,
        onAddFloor: _addFloor,
        errorBanner: _errorBanner(state),
        readOnly: readOnly,
      );
    }

    // Ust seviye: blok kutucuklari (+ gerekliyse Bloksuz kovasi).
    return _BlockList(
      state: state,
      errorBanner: _errorBanner(state),
      onOpen: _openBlockTile,
      readOnly: readOnly,
    );
  }

  Widget? _errorBanner(BinaDuzenlemeState state) {
    if (state.errorMessage == null || state.bos) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        state.errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  void _addFloor() {
    setState(() {
      // Var olan en ust katin ustune yeni bos kat ekle (yoksa 1'den basla).
      final state = ref.read(binaDuzenlemeControllerProvider);
      final units = _openBlock == _blocklessKey
          ? state.blocklessUnits
          : state.unitsForBlock(_openBlock!);
      final kats = <int>{
        for (final u in units)
          if (u.kat != null) u.kat!,
        ..._pendingFloors,
      };
      final next = kats.isEmpty ? 1 : (kats.reduce((a, b) => a > b ? a : b) + 1);
      _pendingFloors.add(next);
    });
  }
}

// ---------------------------------------------------------------------------
// Kutucuk listesi (ust seviye).
// ---------------------------------------------------------------------------

class _BlockList extends ConsumerWidget {
  const _BlockList({
    required this.state,
    required this.errorBanner,
    required this.onOpen,
    required this.readOnly,
  });

  final BinaDuzenlemeState state;
  final Widget? errorBanner;
  final void Function(String label) onOpen;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = state.blockLabels;
    // "Blok atanmamış" kova: YALNIZ mevcut bloksuz daireler varken gorunur
    // (goruntuleme + duzenle/sil). Yeni daire buradan EKLENEMEZ — her yeni daire
    // bir bloga baglanir (canli-site kurali).
    final showBlockless = state.blocklessUnits.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ?errorBanner,
        Text(
          readOnly
              ? 'Bina yapısı (salt görüntüleme). Blok kutucuğuna dokunup '
                  'kat ve daire yerleşimini görebilirsiniz.'
              : 'Blok ekleyin, kutucuğa dokunup içine kat ve daire yerleştirin. '
                  'Her daire bir bloğa bağlanır. Şikayet Haritası bu yapıyı yansıtır.',
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final label in labels)
              _BlockTile(
                label: label,
                unitCount: state.unitsForBlock(label).length,
                registered: state.blockByLabel(label) != null,
                onTap: () => onOpen(label),
                // Salt-okuma: blok yonet (duzenle/sil) kapali.
                onManage: readOnly || state.blockByLabel(label) == null
                    ? null
                    : () => _manageBlock(context, ref, state.blockByLabel(label)!),
              ),
            if (showBlockless)
              _BlockTile(
                label: 'Blok atanmamış',
                unitCount: state.blocklessUnits.length,
                registered: true,
                icon: Icons.tag,
                onTap: () => onOpen(_blocklessKey),
              ),
            // Salt-okuma: "Blok ekle" kutusu gizli.
            if (!readOnly) _AddTile(onTap: () => _addBlock(context, ref)),
          ],
        ),
      ],
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.label,
    required this.unitCount,
    required this.registered,
    required this.onTap,
    this.onManage,
    this.icon,
  });

  final String label;
  final int unitCount;
  final bool registered;
  final VoidCallback onTap;
  final VoidCallback? onManage;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    const accent = Color(0xFF3949AB);
    final Color tileFill =
        isDark ? accent.withValues(alpha: 0.22) : const Color(0xFFE8EAF6);
    final Color iconColor = isDark ? const Color(0xFF9FA8DA) : accent;
    final Color titleColor =
        isDark ? const Color(0xFFC5CAE9) : const Color(0xFF283593);
    return InkWell(
      onTap: onTap,
      onLongPress: onManage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: tileFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 1.2),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.domain, color: iconColor),
            const SizedBox(height: 4),
            Text(
              icon == null ? 'Blok $label' : label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text('$unitCount daire',
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
            if (!registered)
              const Text('kayıtsız',
                  style: TextStyle(fontSize: 10, color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final Color fill =
        isDark ? scheme.surfaceContainerHighest : Colors.blueGrey.shade50;
    final Color fg = isDark ? scheme.onSurfaceVariant : Colors.blueGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade300, width: 1.2, style: BorderStyle.solid),
          color: fill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: fg),
            const SizedBox(height: 4),
            Text('Blok', style: TextStyle(color: fg)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blok detayi (kat plani + kat/daire ekleme). label='' → bloksuz kova.
// ---------------------------------------------------------------------------

class _BlockDetail extends ConsumerWidget {
  const _BlockDetail({
    super.key,
    required this.label,
    required this.state,
    required this.pendingFloors,
    required this.onAddFloor,
    required this.readOnly,
    this.errorBanner,
  });

  final String label;
  final BinaDuzenlemeState state;
  final Set<int> pendingFloors;
  final VoidCallback onAddFloor;
  final bool readOnly;
  final Widget? errorBanner;

  bool get _blockless => label == _blocklessKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units =
        _blockless ? state.blocklessUnits : state.unitsForBlock(label);

    // Kat gruplama: daire katlari + bekleyen bos katlar; UST KAT YUKARIDA.
    final floorSet = <int>{
      for (final u in units)
        if (u.kat != null) u.kat!,
      ...pendingFloors,
    };
    final floors = floorSet.toList()..sort((a, b) => b.compareTo(a));
    final katsizUnits = units.where((u) => u.kat == null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ?errorBanner,
        Text(
          readOnly
              ? (_blockless
                  ? 'Bloğa atanmamış daireler (salt görüntüleme).'
                  : 'Blok $label — kat ve daire yerleşimi (salt görüntüleme).')
              : (_blockless
                  ? 'Bu daireler bir bloğa atanmamış (eski kayıtlar). Görüntülenir, düzenlenip silinebilir; yeni daire için bir blok seçin/oluşturun.'
                  : 'Blok $label — kat ekleyip her katın "+" düğmesiyle daire ekleyin. Aynı kattakiler yan yana dizilir.'),
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        // "Kat ekle" + "Toplu daire ekle": salt-okumada ve bloksuz kovada gizli
        // (bloksuz kovaya yeni daire eklenmez).
        if (!readOnly && !_blockless) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddFloor,
                icon: const Icon(Icons.add),
                label: const Text('Kat ekle'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showBulkUnitForm(
                  context,
                  ref,
                  blok: label,
                ),
                icon: const Icon(Icons.grid_view),
                label: const Text('Toplu daire ekle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (floors.isEmpty && katsizUnits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                  readOnly
                      ? 'Bu blokta henüz daire yok.'
                      : 'Henüz kat yok. "Kat ekle" ile başlayın, sonra kattaki "+" ile daire ekleyin.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ),
          ),
        for (final kat in floors)
          _FloorRow(
            kat: kat,
            units: (units.where((u) => u.kat == kat).toList()
              ..sort(_bySira)),
            readOnly: readOnly,
            canAdd: !readOnly && !_blockless,
            onAddUnit: () => _openUnitForm(context, ref, kat: kat),
            onUnit: (u) => _openUnitForm(context, ref, existing: u),
          ),
        if (katsizUnits.isNotEmpty)
          _FloorRow(
            kat: null,
            units: katsizUnits..sort(_bySira),
            readOnly: readOnly,
            canAdd: !readOnly && !_blockless,
            onAddUnit: () => _openUnitForm(context, ref),
            onUnit: (u) => _openUnitForm(context, ref, existing: u),
          ),
      ],
    );
  }

  static int _bySira(EditorUnit a, EditorUnit b) {
    final sa = a.sira ?? 1 << 30;
    final sb = b.sira ?? 1 << 30;
    if (sa != sb) return sa.compareTo(sb);
    return a.no.compareTo(b.no);
  }

  /// Yeni/duzenleme daire formu. [kat] verilirse yeni daire o kata; [existing]
  /// verilirse duzenleme. Bloksuz kova → blok=null.
  Future<void> _openUnitForm(
    BuildContext context,
    WidgetRef ref, {
    int? kat,
    EditorUnit? existing,
  }) async {
    final blok = _blockless ? null : label;
    // Yeni daire icin sira onerisi: bu blok+kattaki en yuksek sira + 1.
    int? siraSuggestion;
    if (existing == null) {
      final target = _blockless ? state.blocklessUnits : state.unitsForBlock(label);
      final onKat = target.where((u) => u.kat == kat).toList();
      final maxSira = onKat.fold<int>(
          0, (m, u) => (u.sira ?? 0) > m ? (u.sira ?? 0) : m);
      siraSuggestion = maxSira + 1;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _UnitForm(
          blok: blok,
          initialKat: existing?.kat ?? kat,
          initialSira: existing?.sira ?? siraSuggestion,
          existing: existing,
        ),
      ),
    );
  }
}

class _FloorRow extends StatelessWidget {
  const _FloorRow({
    required this.kat,
    required this.units,
    required this.onAddUnit,
    required this.onUnit,
    required this.readOnly,
    required this.canAdd,
  });

  final int? kat;
  final List<EditorUnit> units;
  final VoidCallback onAddUnit;
  final void Function(EditorUnit) onUnit;
  final bool readOnly;
  // Yeni daire hucresi ("+") gorunur mu? (bloksuz kovada false — ekleme kapali.)
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(
                kat == null ? 'Kat yok' : 'Kat $kat',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Salt-okuma: daireye dokunmak duzenleme formu ACMAZ.
                  for (final u in units)
                    _UnitCell(unit: u, onTap: readOnly ? null : () => onUnit(u)),
                  // "daire ekle" hucresi: salt-okumada ve bloksuz kovada gizli.
                  if (canAdd) _AddUnitCell(onTap: onAddUnit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sikayet Haritasi hucre stilini yansitir (58x46, yuvarlak, etiket).
class _UnitCell extends StatelessWidget {
  const _UnitCell({required this.unit, required this.onTap});

  final EditorUnit unit;
  // null → salt-okuma (dokunma etkisiz; duzenleme formu acilmaz).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = unit.aktif;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final color = active ? const Color(0xFF3949AB) : Colors.blueGrey;
    // Seffaf dolgu koyu zeminde kaybolmasin diye koyu modda tinti belirginlestir;
    // etiket rengini de aciga cek (koyu indigo/blueGrey koyu modda okunmaz).
    final Color labelColor = active
        ? (isDark ? const Color(0xFFC5CAE9) : const Color(0xFF283593))
        : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 58,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.28 : 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unit.no,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (unit.sira != null)
              Text('#${unit.sira}',
                  style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AddUnitCell extends StatelessWidget {
  const _AddUnitCell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 58,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade300, width: 1.2),
          color: Colors.blueGrey.shade50,
        ),
        child: const Icon(Icons.add, size: 20, color: Colors.blueGrey),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blok ekle/duzenle/sil.
// ---------------------------------------------------------------------------

Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _BlockForm(),
    ),
  );
}

Future<void> _manageBlock(
    BuildContext context, WidgetRef ref, BuildingBlock block) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text('Blok ${block.ad} — düzenle'),
            onTap: () {
              Navigator.of(ctx).pop();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (c2) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(c2).viewInsets.bottom),
                  child: _BlockForm(existing: block),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Bloğu sil', style: TextStyle(color: Colors.red)),
            subtitle: block.unitSayisi > 0
                ? Text('${block.unitSayisi} daire ile birlikte silinir (onay gerekir)')
                : null,
            onTap: () async {
              Navigator.of(ctx).pop();
              await _deleteBlock(context, ref, block);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _deleteBlock(
    BuildContext context, WidgetRef ref, BuildingBlock block) async {
  final messenger = ScaffoldMessenger.of(context);
  final count = block.unitSayisi;
  bool cascade = false;

  if (count > 0) {
    // Yikici: daireleri + bagli kayitlari siler. Sert onay: blok adini yazdir.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CascadeDeleteDialog(block: block),
    );
    if (confirmed != true) return;
    cascade = true;
  } else {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Blok ${block.ad} silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  try {
    await ref
        .read(binaDuzenlemeControllerProvider.notifier)
        .deleteBlock(block.id, cascade: cascade);
    messenger.showSnackBar(SnackBar(
      content: Text(cascade
          ? 'Blok ${block.ad} ve $count daire silindi.'
          : 'Blok ${block.ad} silindi.'),
    ));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.statusCode == 409
          ? e.message
          : 'Blok silinemedi: ${e.message}'),
    ));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Blok silinemedi. Lütfen tekrar deneyin.')),
    );
  }
}

/// Yikici blok silme onayi — kullanici blok adini AYNEN yazana dek "Sil" pasif.
class _CascadeDeleteDialog extends StatefulWidget {
  const _CascadeDeleteDialog({required this.block});

  final BuildingBlock block;

  @override
  State<_CascadeDeleteDialog> createState() => _CascadeDeleteDialogState();
}

class _CascadeDeleteDialogState extends State<_CascadeDeleteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = _ctrl.text.trim() == widget.block.ad;
    return AlertDialog(
      title: Text('Blok ${widget.block.ad} silinsin mi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu blok ve içindeki ${widget.block.unitSayisi} daire; aidat, '
            'ziyaretçi, kargo, rezervasyon ve şikayet kayıtlarıyla birlikte '
            'KALICI olarak silinecek. Bu işlem geri alınamaz.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Onaylamak için blok adını yazın',
              hintText: widget.block.ad,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: match ? () => Navigator.of(context).pop(true) : null,
          child: Text('Sil (${widget.block.unitSayisi} daire)'),
        ),
      ],
    );
  }
}

class _BlockForm extends ConsumerStatefulWidget {
  const _BlockForm({this.existing});

  final BuildingBlock? existing;

  @override
  ConsumerState<_BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends ConsumerState<_BlockForm> {
  late final TextEditingController _ad =
      TextEditingController(text: widget.existing?.ad ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      setState(() => _error = 'Blok etiketi gerekli (örn. A, B1).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = BlockDraft(ad: ad);
    final controller = ref.read(binaDuzenlemeControllerProvider.notifier);
    try {
      if (widget.existing != null) {
        await controller.updateBlock(widget.existing!.id, draft);
      } else {
        await controller.createBlock(draft);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 409
            ? 'Bu blok etiketi zaten kayıtlı.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing != null ? 'Blok düzenle' : 'Yeni blok',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _ad,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Blok etiketi',
              hintText: 'A',
              helperText: 'Kısa alfanumerik (örn. A, B1) — tire yok',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daire ekle/duzenle/sil.
// ---------------------------------------------------------------------------

class _UnitForm extends ConsumerStatefulWidget {
  const _UnitForm({
    required this.blok,
    this.initialKat,
    this.initialSira,
    this.existing,
  });

  /// null → bloksuz (blok gonderilmez); aksi halde bu blok.
  final String? blok;
  final int? initialKat;
  final int? initialSira;
  final EditorUnit? existing;

  @override
  ConsumerState<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends ConsumerState<_UnitForm> {
  late final TextEditingController _no =
      TextEditingController(text: widget.existing?.no ?? '');
  late final TextEditingController _kat = TextEditingController(
      text: (widget.existing?.kat ?? widget.initialKat)?.toString() ?? '');
  late final TextEditingController _sira = TextEditingController(
      text: (widget.existing?.sira ?? widget.initialSira)?.toString() ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _no.dispose();
    _kat.dispose();
    _sira.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final no = _no.text.trim();
    if (no.isEmpty) {
      setState(() => _error = 'Daire no gerekli (örn. A-12, 12).');
      return;
    }
    final katText = _kat.text.trim();
    final siraText = _sira.text.trim();
    final kat = katText.isEmpty ? null : int.tryParse(katText);
    final sira = siraText.isEmpty ? null : int.tryParse(siraText);
    if ((katText.isNotEmpty && kat == null) ||
        (siraText.isNotEmpty && sira == null)) {
      setState(() => _error = 'Kat ve sıra tam sayı olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = EditorUnitDraft(no: no, blok: widget.blok, kat: kat, sira: sira);
    final controller = ref.read(binaDuzenlemeControllerProvider.notifier);
    try {
      if (widget.existing != null) {
        await controller.updateUnit(widget.existing!.id, draft);
      } else {
        await controller.createUnit(draft);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 409
            ? 'Bu daire no zaten kayıtlı.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _delete() async {
    if (_busy || widget.existing == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(binaDuzenlemeControllerProvider.notifier)
          .deleteUnit(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Silinemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blokLabel = widget.blok == null ? 'Bloksuz' : 'Blok ${widget.blok}';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null
                ? 'Daire ${widget.existing!.no} — düzenle'
                : 'Yeni daire · $blokLabel',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _no,
            maxLength: 50,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Daire no',
              hintText: 'A-12',
              helperText: 'Alfanumerik + tire (örn. A-12, B3, 12)',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kat,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kat',
                    hintText: '1',
                    helperText: '0 = zemin',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sira,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Sıra',
                    hintText: '1',
                    helperText: 'Kattaki konum',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.existing != null)
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Sil'),
                )
              else
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toplu daire ekleme (Parca B): blok + kat sayisi + kat basi daire + baslangic
// no -> sunucu ardisik uretir (kat kat). Canli onizleme; var olan no atlanir.
// ---------------------------------------------------------------------------
Future<void> _showBulkUnitForm(
  BuildContext context,
  WidgetRef ref, {
  required String? blok,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _BulkUnitForm(blok: blok),
    ),
  );
}

class _BulkUnitForm extends ConsumerStatefulWidget {
  const _BulkUnitForm({required this.blok});

  final String? blok;

  @override
  ConsumerState<_BulkUnitForm> createState() => _BulkUnitFormState();
}

class _BulkUnitFormState extends ConsumerState<_BulkUnitForm> {
  final _katSayisi = TextEditingController();
  final _katBasi = TextEditingController();
  final _baslangic = TextEditingController(text: '1');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _katSayisi.dispose();
    _katBasi.dispose();
    _baslangic.dispose();
    super.dispose();
  }

  int? get _kat => int.tryParse(_katSayisi.text.trim());
  int? get _mDaire => int.tryParse(_katBasi.text.trim());
  int? get _bas => int.tryParse(_baslangic.text.trim());

  String get _no0 => widget.blok != null ? '${widget.blok}-' : '';

  /// Canli onizleme metni (gecersiz girdide bos).
  String get _onizleme {
    final k = _kat, m = _mDaire, b = _bas;
    if (k == null || m == null || b == null || k < 1 || m < 1 || b < 0) {
      return '';
    }
    final toplam = k * m;
    if (toplam > 500) return 'En fazla 500 daire (şu an $toplam).';
    final bitis = b + toplam - 1;
    return '$_no0$b … $_no0$bitis  ($toplam daire, $k kat × $m)';
  }

  Future<void> _submit() async {
    final k = _kat, m = _mDaire, b = _bas;
    if (k == null || m == null || b == null || k < 1 || m < 1 || b < 0) {
      setState(() => _error = 'Kat sayısı, kat başına daire ve başlangıç no gerekli.');
      return;
    }
    if (k * m > 500) {
      setState(() => _error = 'Tek seferde en fazla 500 daire.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(binaDuzenlemeControllerProvider.notifier).bulkCreateUnits(
                blok: widget.blok,
                katSayisi: k,
                katBasiDaire: m,
                baslangicNo: b,
              );
      if (!mounted) return;
      Navigator.of(context).pop();
      final atl = res.atlanan.isEmpty
          ? ''
          : ' (${res.atlanan.length} zaten vardı, atlandı)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${res.olusturulanSayi} daire eklendi ✓$atl')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Eklenemedi. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onizleme = _onizleme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.blok != null
                ? 'Toplu daire ekle — Blok ${widget.blok}'
                : 'Toplu daire ekle — Bloksuz',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Numaralar başlangıçtan itibaren ardışık, kat kat dolar. Var olan '
            'daire no\'ları atlanır.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _katSayisi,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Kat sayısı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _katBasi,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Kat başına daire',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baslangic,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Başlangıç no',
              hintText: 'örn. 101',
              border: OutlineInputBorder(),
            ),
          ),
          if (onizleme.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(onizleme,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.grid_view),
              label: const Text('Daireleri oluştur'),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
