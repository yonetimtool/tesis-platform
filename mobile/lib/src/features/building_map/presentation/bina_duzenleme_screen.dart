import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../unit_tanimlari/data/unit_tanim_api.dart';
import '../../unit_tanimlari/domain/unit_tanim_models.dart';
import '../domain/bina_duzenleme_models.dart';
import 'daire_tipi_rengi.dart';
import 'bina_duzenleme_controller.dart';
import 'yapisal_arac_dialoglari.dart';
import '../../../core/theme/home_tokens.dart';
import '../../../core/ui/merkez_diyalog.dart';

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

/// Yapisal arac secimi.
///
/// DIZE DEGIL ENUM ve bu iki sebeple dogru:
///   1. Uc sabit dize zaten bir enum'un elle yazilmis haliydi.
///   2. `PopupMenuButton<String>` TIPI, depodaki genel test yardimcisinin
///      ("menudeki son oge Sil'dir") aradigi tiple CAKISIYORDU: bu menu
///      app bar'da ve agacta once geldigi icin yardimci onu seciyor,
///      dokunusu bosa gidiyordu. Enum ile tip ayrisiyor ve iki menu
///      birbirini gormuyor.
enum _YapisalArac { katSil, topluTip, siralama }

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
        title: Text(baslikBuyuk(_titleFor(readOnly), context.dilKodu)),
        actions: [
          // (P164) YAPISAL ARACLAR — webdeki uclunun mobil karsiligi.
          //
          // TEK MENUDE toplandi, uc ayri ikon degil: bunlar SEYREK ve
          // YIKICI islemlerdir; app bar'da uc dugme olarak durmalari,
          // sik kullanilan "yenile"nin yaninda yanlislikla basilma
          // riskini artirirdi.
          //
          // SALT-OKUMA ROLDE HIC CIZILMEZ: sunucu zaten 403 doner, ama
          // basilacak bir menu gostermek "yetkim var sandim" demektir.
          if (!readOnly)
            // (P166 §10) ETIKET APP BAR'A SIGMADI — GOVDEYE KONDU.
            //
            // ILK DENEME METNI BURAYA YAZMAKTI ve DAR EKRAN TESTI onu
            // dogru sekilde curuttu: 320dp'de app bar 43 piksel tasiyor
            // (Almanca/Fransizca basliklar daha da uzun). App bar zaten
            // baslik + geri + yenile tasiyor; dorduncu bir METIN oraya
            // sigmaz.
            //
            // Ikon BURADA KALIR (baglam ici kisayol), ETIKETLI GIRIS ise
            // govdenin ustune kondu — bkz. `_AraclarSeridi`. Gorunurluk
            // sorunu cozuluyor, tasma uretilmeden.
            PopupMenuButton<_YapisalArac>(
              key: const Key('yapisal-araclar-menu'),
              tooltip: context.l10n.binaYapisalAraclar,
              icon: const Icon(Icons.construction_outlined),
              onSelected: _yapisalArac,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _YapisalArac.katSil,
                  child: Text(context.l10n.binaKatSil),
                ),
                PopupMenuItem(
                  value: _YapisalArac.topluTip,
                  child: Text(context.l10n.binaTopluTip),
                ),
                PopupMenuItem(
                  value: _YapisalArac.siralama,
                  child: Text(context.l10n.binaSiralama),
                ),
              ],
            ),
          IconButton(
            tooltip: context.l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // (P166 §10) YAPISAL ARACLAR — ETIKETLI GIRIS.
          //
          // P163/P164'te kat silme, toplu daire ekleme, numara ile secme
          // ve siralama daire listesinden BURAYA tasindi; yani bu menu
          // artik DORT YETENEGIN TEK GIRISI. Adini ancak uzun basinca
          // soyleyen bir ikonun ardinda birakmak, tasima isini bosa
          // cikarirdi: kullanici araclari ne eski yerinde bulur ne yeni
          // yerinde gorur.
          //
          // SALT-OKUMA ROLDE CIZILMEZ (app bar menusuyle ayni kural).
          if (!readOnly)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextButton.icon(
                  onPressed: () => _yapisalAraclariAc(),
                  icon: const Icon(Icons.construction_outlined),
                  label: Text(context.l10n.binaYapisalAraclar),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _body(state, readOnly),
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(bool readOnly) {
    final l10n = context.l10n;
    if (_openBlock != null) {
      return _openBlock == _blocklessKey
          ? l10n.binaBlokAtanmamis
          : l10n.binaBlokEtiket(_openBlock!);
    }
    // Salt-okuma rollerinde baslik "Bina Yapisi" (duzenleme cagrismasi olmasin).
    return readOnly ? l10n.modulBinaYapisi : l10n.binaDuzenlemeBaslik;
  }

  Widget _body(BinaDuzenlemeState state, bool readOnly) {
    if (state.loading && state.bos) {
      return const Center(child: CircularProgressIndicator());
    }
    final hataMetni = akisHatasiCoz(
      context.l10n,
      state.hataKimligi,
      state.errorMessage,
    );
    if (hataMetni != null && state.bos) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(hataMetni)),
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
    final hataMetni = akisHatasiCoz(
      context.l10n,
      state.hataKimligi,
      state.errorMessage,
    );
    if (hataMetni == null || state.bos) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        hataMetni,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  /// (P166 §10) Govdedeki ETIKETLI giristen acilan arac listesi.
  ///
  /// MERKEZ DIYALOG (`merkezSayfaAc`), alt sayfa DEGIL: P22(a) kilidi
  /// "tum acilir pencereler ORTADAN acilsin" diyor ve `merkez_diyalog_test`
  /// `lib` icinde tek bir `showModalBottomSheet` cagrisina bile izin
  /// vermiyor. Ilk yazimim alt sayfaydi ve test onu DOGRU sekilde durdurdu.
  ///
  /// Acilir menu de degil: menu dokunulan noktanin yanindan acilir ve
  /// govdenin ortasindaki bir dugmede tuhaf durur. Diyalog ayrica her
  /// satira IKON sigdirir — ucu de yikici islem, ne yaptiklarini okumak
  /// SART.
  ///
  /// SECIM AYNI YERE GIDER (`_yapisalArac`): app bar menusu ve bu liste
  /// tek bir davranisi paylasir; ikisi ayrisirsa biri duzeltilip oteki
  /// unutulurdu.
  Future<void> _yapisalAraclariAc() async {
    final l10n = context.l10n;
    final secim = await merkezSayfaAc<_YapisalArac>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.layers_clear_outlined),
            title: Text(l10n.binaKatSil),
            onTap: () => Navigator.of(ctx).pop(_YapisalArac.katSil),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.binaTopluTip),
            onTap: () => Navigator.of(ctx).pop(_YapisalArac.topluTip),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert_outlined),
            title: Text(l10n.binaSiralama),
            onTap: () => Navigator.of(ctx).pop(_YapisalArac.siralama),
          ),
        ],
      ),
    );
    if (secim != null && mounted) await _yapisalArac(secim);
  }

  Future<void> _yapisalArac(_YapisalArac secim) async {
    await switch (secim) {
      _YapisalArac.katSil => showDialog<void>(
        context: context,
        builder: (_) => KatSilDialog(blok: _openBlock),
      ),
      _YapisalArac.topluTip => showDialog<void>(
        context: context,
        builder: (_) => TopluTipDialog(blok: _openBlock),
      ),
      _YapisalArac.siralama => showDialog<void>(
        context: context,
        builder: (_) => SiralamaDialog(blok: _openBlock),
      ),
    };
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
      final next = kats.isEmpty
          ? 1
          : (kats.reduce((a, b) => a > b ? a : b) + 1);
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
              ? context.l10n.binaSaltGoruntulemeAciklama
              : context.l10n.binaDuzenlemeAciklama,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                    : () => _manageBlock(
                        context,
                        ref,
                        state.blockByLabel(label)!,
                      ),
              ),
            if (showBlockless)
              _BlockTile(
                label: context.l10n.binaBlokAtanmamis,
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
    final Color tileFill = isDark
        ? accent.withValues(alpha: 0.22)
        : const Color(0xFFE8EAF6);
    final Color iconColor = isDark ? const Color(0xFF9FA8DA) : accent;
    final Color titleColor = isDark
        ? const Color(0xFFC5CAE9)
        : const Color(0xFF283593);
    return InkWell(
      onTap: onTap,
      onLongPress: onManage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // Yazi olcegiyle birlikte buyur (tur 27 — bkz. sema hucresi).
        width: MediaQuery.textScalerOf(context).scale(104),
        height: MediaQuery.textScalerOf(context).scale(104),
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
            // SABIT 104x104 kutucuk: her satir TEK SATIR olmak ZORUNDA.
            // `maxLines` verilmezse uzun ceviriler (ru/es) ikinci satira
            // sarar ve kutucuk 10 px tasar — tur 24'te 7 dilde surerken
            // yakalandi. `overflow` tek basina yetmez: sarmayi engelleyen
            // `maxLines`tir.
            Text(
              icon == null ? context.l10n.binaBlokEtiket(label) : label,
              style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              context.l10n.binaDaireSayisi(unitCount),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!registered)
              Text(
                context.l10n.binaKayitsiz,
                style: const TextStyle(fontSize: 10, color: Colors.orange),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
    final Color fill = isDark
        ? scheme.surfaceContainerHighest
        : Colors.blueGrey.shade50;
    final Color fg = isDark ? scheme.onSurfaceVariant : Colors.blueGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // Yazi olcegiyle birlikte buyur (tur 27 — bkz. sema hucresi).
        width: MediaQuery.textScalerOf(context).scale(104),
        height: MediaQuery.textScalerOf(context).scale(104),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blueGrey.shade300,
            width: 1.2,
            style: BorderStyle.solid,
          ),
          color: fill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: fg),
            const SizedBox(height: 4),
            Text(context.l10n.binaBlokTile, style: TextStyle(color: fg)),
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
    final units = _blockless
        ? state.blocklessUnits
        : state.unitsForBlock(label);

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
                    ? context.l10n.binaBloksuzDairelerSalt
                    : context.l10n.binaBlokYerlesimSalt(label))
              : (_blockless
                    ? context.l10n.binaBloksuzUyari
                    : context.l10n.binaBlokYerlesimYardim(label)),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                label: Text(context.l10n.binaKatEkle),
              ),
              OutlinedButton.icon(
                onPressed: () => _showBulkUnitForm(context, ref, blok: label),
                icon: const Icon(Icons.grid_view),
                label: Text(context.l10n.binaTopluDaireEkle),
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
                    ? context.l10n.binaBloktaDaireYok
                    : context.l10n.binaKatYokBos,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final kat in floors)
          _FloorRow(
            kat: kat,
            units: (units.where((u) => u.kat == kat).toList()..sort(_bySira)),
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
      final target = _blockless
          ? state.blocklessUnits
          : state.unitsForBlock(label);
      final onKat = target.where((u) => u.kat == kat).toList();
      final maxSira = onKat.fold<int>(
        0,
        (m, u) => (u.sira ?? 0) > m ? (u.sira ?? 0) : m,
      );
      siraSuggestion = maxSira + 1;
    }
    await merkezSayfaAc<void>(
      context,
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
                kat == null
                    ? context.l10n.binaKatYok
                    : context.l10n.binaKatEtiket('$kat'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Salt-okuma: daireye dokunmak duzenleme formu ACMAZ.
                  for (final u in units)
                    UnitCell(unit: u, onTap: readOnly ? null : () => onUnit(u)),
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
/// Daire hucresi — (P122) kapi no + tip etiketi + tipe bagli renk.
///
/// `@visibleForTesting` PUBLIC: en kucuk izgara boyutunda ve buyuk yazi
/// olceginde TASMADIGI olculebilsin diye. Ekranin tamami uzerinden test
/// etmek, olcmek istedigimiz seyi (tek hucrenin siniri) veri kurulumunun
/// altinda gomerdi.
@visibleForTesting
class UnitCell extends StatelessWidget {
  const UnitCell({super.key, required this.unit, required this.onTap});

  final EditorUnit unit;
  // null → salt-okuma (dokunma etkisiz; duzenleme formu acilmaz).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = unit.aktif;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // (P122) TIP RENGI YALNIZ AKTIF dairede: pasif daire her tipte ayni
    // soluk griyi tasimali, yoksa "pasif" durumu renk gurultusunde kaybolur.
    final color = active ? daireTipiRengi(unit.unitTipAd) : Colors.blueGrey;
    // Seffaf dolgu koyu zeminde kaybolmasin diye koyu modda tinti belirginlestir;
    // etiket rengini de aciga cek (koyu indigo/blueGrey koyu modda okunmaz).
    // Etiket rengi TIP RENGINDEN turer: koyu temada aciga, acik temada
    // koyuya cekilir — sabit indigo, turuncu/yesil bir hucrede okunmazdi.
    final Color labelColor = active
        ? (isDark
              ? Color.lerp(color, Colors.white, 0.62)!
              : Color.lerp(color, Colors.black, 0.35)!)
        : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey);
    final tipKisa = active ? daireTipiKisa(unit.unitTipAd) : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // ERISILEBILIRLIK: gorsel kisaltma ekran okuyucuya TAM adi vermeli;
      // "Dubleks…" diye okumak isitilebilir arayuzu bozardi.
      // `container` + `excludeSemantics` ZORUNLU: alt agactaki `Text`ler
      // kendi etiketlerini uretir ve disaridaki etiket onlarin YANINA
      // eklenir — ekran okuyucu "12, Dublek…, 12, Dubleks Bahce Kati" gibi
      // okur. Ilk yazimda tam bu oldu ve test yakaladi.
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: unit.unitTipAd == null || !active
            ? unit.no
            : '${unit.no}, ${unit.unitTipAd}',
        child: _hucreGovdesi(
          context,
          color,
          labelColor,
          tipKisa,
          scheme,
          isDark,
        ),
      ),
    );
  }

  Widget _hucreGovdesi(
    BuildContext context,
    Color color,
    Color labelColor,
    String tipKisa,
    ColorScheme scheme,
    bool isDark,
  ) {
    // (P122) YAZI OLCEGIYLE BUYU (tur 27 deseni — blok karosu da boyle).
    // Kapi numarasinin yanina tip etiketi eklemek kutuya IKINCI BIR SATIR
    // koymaktir; sabit 46 dp yukseklik, erisilebilirlik icin yaziyi
    // buyuten kullanicida TASIYORDU (1.6x ve 2.0x'te olculdu). Metni
    // `FittedBox` ile kucultmek yanlis cozum olurdu: kullanici yaziyi
    // BUYUK istedi, biz de kutuyu buyutuyoruz.
    final olcek = MediaQuery.textScalerOf(context);
    return Container(
      width: olcek.scale(58),
      height: olcek.scale(46),
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
          // (P122) TIP, SIRADAN ONCELIKLIDIR. Hucre 46 dp yuksektir; ucuncu
          // bir satir yazi olcegi buyuyen cihazda TASAR. Tip atanmissa
          // kullanici icin degerli olan odur ("12 · 2+1"); sira yalnizca
          // yerlesim ayrintisidir ve tip yokken gosterilir.
          if (tipKisa.isNotEmpty)
            Text(
              tipKisa,
              key: const Key('daire-tip-etiketi'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            )
          else if (unit.sira != null)
            Text(
              '#${unit.sira}',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
        ],
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
  await merkezSayfaAc<void>(
    context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _BlockForm(),
    ),
  );
}

Future<void> _manageBlock(
  BuildContext context,
  WidgetRef ref,
  BuildingBlock block,
) async {
  await merkezSayfaAc<void>(
    context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.l10n.binaBlokDuzenleBaslik(block.ad)),
            onTap: () {
              Navigator.of(ctx).pop();
              merkezSayfaAc<void>(
                context,
                builder: (c2) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(c2).viewInsets.bottom,
                  ),
                  child: _BlockForm(existing: block),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              context.l10n.binaBloguSil,
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: block.unitSayisi > 0
                ? Text(context.l10n.binaBloguSilAlt(block.unitSayisi))
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
  BuildContext context,
  WidgetRef ref,
  BuildingBlock block,
) async {
  final l10n = context.l10n;
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
        title: Text(l10n.binaBlokSilinsinMi(block.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  try {
    await ref
        .read(binaDuzenlemeControllerProvider.notifier)
        .deleteBlock(block.id, cascade: cascade);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cascade
              ? l10n.binaBlokVeDaireSilindi(block.ad, '$count')
              : l10n.binaBlokSilindi(block.ad),
        ),
      ),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.statusCode == 409
              ? e.message
              : l10n.binaBlokSilinemedi(apiHataMetni(l10n, e)),
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.binaBlokSilinemediGenel)),
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
    final l10n = context.l10n;
    final match = _ctrl.text.trim() == widget.block.ad;
    return AlertDialog(
      title: Text(l10n.binaBlokSilinsinMi(widget.block.ad)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.binaKaliciSilmeUyari('${widget.block.unitSayisi}')),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.binaOnayIcinBlokAdi,
              hintText: widget.block.ad,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          style: yikiciDugmeStili(context),
          onPressed: match ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.binaSilNDaire('${widget.block.unitSayisi}')),
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
  late final TextEditingController _ad = TextEditingController(
    text: widget.existing?.ad ?? '',
  );
  bool _busy = false;
  String? _error;

  /// `setState` yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      setState(() => _error = _l10n.binaBlokEtiketiGerekli);
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
            ? _l10n.binaBlokEtiketiZatenVar
            : apiHataMetni(_l10n, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _l10n.binaKaydedilemedi;
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
          Text(
            widget.existing != null
                ? context.l10n.binaBlokDuzenle
                : context.l10n.binaYeniBlok,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ad,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: InputDecoration(
              labelText: context.l10n.binaBlokEtiketi,
              hintText: 'A',
              helperText: context.l10n.binaBlokEtiketiYardim,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy
                        ? context.l10n.ortakKaydediliyor
                        : context.l10n.ortakKaydet,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(context.l10n.ortakIptal),
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
  late final TextEditingController _no = TextEditingController(
    text: widget.existing?.no ?? '',
  );
  late final TextEditingController _kat = TextEditingController(
    text: (widget.existing?.kat ?? widget.initialKat)?.toString() ?? '',
  );
  late final TextEditingController _sira = TextEditingController(
    text: (widget.existing?.sira ?? widget.initialSira)?.toString() ?? '',
  );
  bool _busy = false;
  String? _error;
  // (P26) Siniflandirma secimleri — mevcut daireden onceden dolar.
  late String? _tipId = widget.existing?.unitTipId;
  late String? _grupId = widget.existing?.unitGrupId;

  /// `setState` yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

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
      setState(() => _error = _l10n.binaDaireNoGerekli);
      return;
    }
    final katText = _kat.text.trim();
    final siraText = _sira.text.trim();
    final kat = katText.isEmpty ? null : int.tryParse(katText);
    final sira = siraText.isEmpty ? null : int.tryParse(siraText);
    if ((katText.isNotEmpty && kat == null) ||
        (siraText.isNotEmpty && sira == null)) {
      setState(() => _error = _l10n.binaKatSiraTamSayi);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = EditorUnitDraft(
      no: no,
      blok: widget.blok,
      kat: kat,
      sira: sira,
      unitTipId: _tipId,
      unitGrupId: _grupId,
    );
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
            ? _l10n.binaDaireNoZatenVar
            : apiHataMetni(_l10n, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _l10n.binaKaydedilemedi;
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
        _error = apiHataMetni(_l10n, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _l10n.binaSilinemedi;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blokLabel = widget.blok == null
        ? l10n.binaBloksuz
        : l10n.binaBlokEtiket(widget.blok!);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null
                ? l10n.binaDaireDuzenleBaslik(widget.existing!.no)
                : l10n.binaYeniDaire(blokLabel),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _no,
            maxLength: 50,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.binaDaireNo,
              hintText: l10n.ortakDaireNoIpucu,
              helperText: l10n.binaDaireNoYardim,
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
                  decoration: InputDecoration(
                    labelText: l10n.binaKat,
                    hintText: '1',
                    helperText: l10n.binaKatYardim,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sira,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.binaSira,
                    hintText: '1',
                    helperText: l10n.binaSiraYardim,
                  ),
                ),
              ),
            ],
          ),
          // (P26) TIP + GRUP secicileri. Liste BOSSA alan hic cizilmez:
          // henuz tanim kurmamis bir sitede bos bir acilir kutu, "bir sey
          // secmem mi gerekiyor" tereddudu yaratirdi.
          _TanimSecici(
            etiket: l10n.daireTipiSecici,
            secili: _tipId,
            secenekler: ref.watch(unitTipleriProvider).value ?? const [],
            onSec: _busy ? null : (v) => setState(() => _tipId = v),
          ),
          _TanimSecici(
            etiket: l10n.daireGrubuSecici,
            secili: _grupId,
            secenekler: ref.watch(unitGruplariProvider).value ?? const [],
            onSec: _busy ? null : (v) => setState(() => _grupId = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy
                        ? context.l10n.ortakKaydediliyor
                        : context.l10n.ortakKaydet,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.existing != null)
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(context.l10n.ortakSil),
                )
              else
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(context.l10n.ortakIptal),
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
  await merkezSayfaAc<void>(
    context,
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
  // (P164) BASLANGIC KATI EKSIKTI: alan hic gonderilmiyordu ve sunucu 1
  // varsayiyordu. Bodrumlu bir binada kat numaralari bir kaydirmayla
  // yaziliyordu — yani veri binanin kendisini anlatmiyordu. Bodrum ve
  // zemin GERCEK katlardir; negatif deger serbest.
  final _baslangicKat = TextEditingController(text: '1');
  bool _busy = false;
  String? _error;
  // (P26) Siniflandirma PARTININ TAMAMINA uygulanir — bir blok genelde tek
  // tiptir; daire basina secmek toplu olusturmanin amacini bozardi. Daire
  // basi istisnalar sonradan daire duzenlemeden degistirilir.
  String? _tipId;
  String? _grupId;

  /// `setState` yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _katSayisi.dispose();
    _katBasi.dispose();
    _baslangic.dispose();
    _baslangicKat.dispose();
    super.dispose();
  }

  int? get _kat => int.tryParse(_katSayisi.text.trim());
  int? get _mDaire => int.tryParse(_katBasi.text.trim());
  int? get _bas => int.tryParse(_baslangic.text.trim());

  /// Baslangic kati — BOS BIRAKILABILIR (sunucu 1 varsayar). `0` ve
  /// negatif degerler GECERLIDIR; `int.tryParse` ikisini de cozer.
  int? get _basKat => int.tryParse(_baslangicKat.text.trim());

  String get _no0 => widget.blok != null ? '${widget.blok}-' : '';

  /// Canli onizleme metni (gecersiz girdide bos).
  String get _onizleme {
    final k = _kat, m = _mDaire, b = _bas;
    if (k == null || m == null || b == null || k < 1 || m < 1 || b < 0) {
      return '';
    }
    final toplam = k * m;
    if (toplam > 500) return _l10n.binaEnFazla500('$toplam');
    final bitis = b + toplam - 1;
    return _l10n.binaTopluOnizleme(
      '$_no0$b',
      '$_no0$bitis',
      '$toplam',
      '$k',
      '$m',
    );
  }

  Future<void> _submit() async {
    final k = _kat, m = _mDaire, b = _bas;
    if (k == null || m == null || b == null || k < 1 || m < 1 || b < 0) {
      setState(() => _error = _l10n.binaTopluAlanlarGerekli);
      return;
    }
    if (k * m > 500) {
      setState(() => _error = _l10n.binaTekSeferde500);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(binaDuzenlemeControllerProvider.notifier)
          .bulkCreateUnits(
            blok: widget.blok,
            katSayisi: k,
            katBasiDaire: m,
            baslangicNo: b,
            baslangicKat: _basKat,
            unitTipId: _tipId,
            unitGrupId: _grupId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      final atl = res.atlanan.isEmpty
          ? ''
          : _l10n.binaAtlananEk('${res.atlanan.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.binaDaireEklendi('${res.olusturulanSayi}', atl)),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = apiHataMetni(_l10n, e));
    } catch (_) {
      if (mounted) setState(() => _error = _l10n.binaEklenemedi);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onizleme = _onizleme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.blok != null
                ? l10n.binaTopluBaslik(widget.blok!)
                : l10n.binaTopluBaslikBloksuz,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.binaTopluAciklama,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _katSayisi,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.binaKatSayisi,
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
                  decoration: InputDecoration(
                    labelText: l10n.binaKatBasinaDaire,
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
            decoration: InputDecoration(
              labelText: l10n.binaBaslangicNo,
              hintText: l10n.binaBaslangicNoIpucu,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baslangicKat,
            // EKSI ISARETI GEREKLI: bodrum katlari negatif. `number`
            // klavyesi bazi cihazlarda eksiyi gostermez; `signed: true`
            // onu acar.
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.binaBaslangicKat,
              hintText: l10n.binaBaslangicKatIpucu,
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
              child: Text(
                onizleme,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          // (P26) Siniflandirma PARTININ TAMAMINA uygulanir.
          _TanimSecici(
            etiket: context.l10n.daireTipiSecici,
            secili: _tipId,
            secenekler: ref.watch(unitTipleriProvider).value ?? const [],
            onSec: _busy ? null : (v) => setState(() => _tipId = v),
          ),
          _TanimSecici(
            etiket: context.l10n.daireGrubuSecici,
            secili: _grupId,
            secenekler: ref.watch(unitGruplariProvider).value ?? const [],
            onSec: _busy ? null : (v) => setState(() => _grupId = v),
          ),
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
              label: Text(l10n.binaDaireleriOlustur),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tip/grup acilir kutusu (P26).
///
/// Secenek YOKSA hic cizilmez: tanim kurmamis bir sitede bos bir acilir kutu
/// "bir sey secmem mi gerekiyor" tereddudu yaratirdi.
///
/// "Secilmedi" secenegi HER ZAMAN durur — siniflandirmayi KALDIRMAK
/// mumkun olmali (yanlis secilen tip geri alinabilsin).
class _TanimSecici extends StatelessWidget {
  const _TanimSecici({
    required this.etiket,
    required this.secili,
    required this.secenekler,
    required this.onSec,
  });

  final String etiket;
  final String? secili;
  final List<UnitTanim> secenekler;
  final ValueChanged<String?>? onSec;

  @override
  Widget build(BuildContext context) {
    if (secenekler.isEmpty) return const SizedBox.shrink();
    // Secili tanim silinmis olabilir: listede yoksa deger null'a duser,
    // yoksa DropdownButton "iki esleme yok" assertion'i atardi.
    final gecerli = secenekler.any((t) => t.id == secili) ? secili : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String?>(
        // Uzun tip adlari dar ekranda tasmasin (repo kurali).
        isExpanded: true,
        initialValue: gecerli,
        decoration: InputDecoration(labelText: etiket),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(context.l10n.daireTanimSecilmedi),
          ),
          for (final t in secenekler)
            DropdownMenuItem<String?>(
              value: t.id,
              child: Text(t.ad, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onSec,
      ),
    );
  }
}
