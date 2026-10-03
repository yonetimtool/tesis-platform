import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/kisi_adi.dart';
import '../../../core/ui/ad_soyad_alanlari.dart';
import '../../../core/ui/bos_durum.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/staff_api.dart';
import '../../kisiler/data/kisi_api.dart';
import '../../kisiler/presentation/kisi_islemleri.dart';
import '../../kisiler/presentation/kisi_suzgec.dart';
import 'calisma_bilgileri.dart';
import 'personel_detay_screen.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/ui/gorsel_cozme.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/eposta_alani_widget.dart';
import '../../../core/ui/telefon_alani_widget.dart';

/// Saha Personeli (Ozellik 3) — yonetici/admin: guvenlik + tesis gorevlisi
/// hesaplarini listeler ve ekler. yonetici backend'de YALNIZ saha personeli
/// acabilir; parola bossa hesap PAROLASIZ acilir ve otomatik davet gonderilir.
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key, this.gomulu = false});

  /// (P251 §8) Kisiler ekraninin SEKMESI olarak cizilir: ust cubugu
  /// Kisiler verir, bu ekran yalniz govdeyi (ve kendi "Ekle" dugmesini).
  final bool gomulu;

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  // (P253 Asama 1) ARAMA VE DURUM SUZGECI (web Kisiler listesi ikizi).
  // Liste tek sayfa (200) geliyor; suzme istemcide — sunucuya her harfte
  // istek atmak dar hatlarda listeyi titretirdi.
  final _ara = TextEditingController();
  KisiDurumSuzgeci _durum = KisiDurumSuzgeci.tumu;

  bool get gomulu => widget.gomulu;

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(fieldStaffProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: gomulu
          ? null
          : AppBar(
              title: Text(baslikBuyuk(l10n.modulPersonel, context.dilKodu)),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.personelEkle),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          // Sunucu metni varsa o gosterilir (SERVER-LOCALIZED siniri).
          message: e is ApiException ? apiHataMetni(l10n, e) : l10n.personelListelenemedi,
          onRetry: () => ref.invalidate(fieldStaffProvider),
        ),
        data: (tumListe) => tumListe.isEmpty
            // (P166 §10) Bos durumda cagri dugmesi: liste yokken goz
            // ekranin ortasindadir, ekranin dibindeki FAB'de degil.
                // (P239 §6) BOS DURUMDA CAGRI DUGMESI KALDIRILDI.
                //
                // FAB zaten sag altta duruyor ve liste dolunca da orada
                // kaliyor. Ikisi birlikteyken kullanici AYNI eylemi iki
                // yerde goruyor; liste dolunca ortadaki kayboluyor ve
                // "dugme nereye gitti" sorusu doguyor. Aciklama metni
                // KALIR — ne oldugunu ve nereden ekleneceğini soyler.
            ? BosDurum(
                ikon: Icons.groups_outlined,
                baslik: l10n.personelYok,
                aciklama: l10n.personelYokAlt,
              )
            : Column(
                children: [
                  KisiSuzgecSeridi(
                    ara: _ara,
                    durum: _durum,
                    onDegisti: (d) => setState(() => _durum = d),
                    onAra: () => setState(() {}),
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      final list = kisiSuz(tumListe, _ara.text, _durum,
                          ad: (s) => s.ad, aktif: (s) => s.isActive);
                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(fieldStaffProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _StaffTile(member: list[i]),
                        ),
                      );
                    }),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {

    final created = await merkezSayfaAc<String?>(
      context,
      builder: (_) => const _AddStaffSheet(),
    );
    if (created != null) {
      ref.invalidate(fieldStaffProvider);
    }
  }
}

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final roleLabel = rolAdi(l10n, UserRole.fromClaim(member.role));
    // (P252 §1) Ucret YALNIZ yonetime (admin/yonetici): amir listeyi gorur
    // ama "Calisma bilgileri" eylemi ona cizilmez (sunucu da 403 doner).
    final yonetim =
        ref.watch(currentUserRoleProvider).value?.maasGorebilir ?? false;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: member.avatarUrl != null
              ? sinirliGorsel(context, NetworkImage(member.avatarUrl!), 40)
              : null,
          child: member.avatarUrl == null
              ? Icon(
                  switch (member.role) {
                    'security' => Icons.shield_outlined,
                    // (P248 §1) Amir de bu listede (yonetici icin).
                    'guvenlik_amiri' => Icons.local_police_outlined,
                    _ => Icons.cleaning_services_outlined,
                  },
                )
              : null,
        ),
        title: Text(member.ad),
        subtitle: Text(roleLabel),
        // (P252 §3) Satira dokunma KISI DETAYINI acar — yalniz yonetim
        // (ucret ve odeme gecmisi). Amire dokunma bagli degil.
        onTap: yonetim
            ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PersonelDetayScreen(kisi: member),
                ))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!member.isActive)
              Chip(
                label: Text(l10n.devriyePasif),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            PopupMenuButton<String>(
              key: Key('personel-islemler-${member.id}'),
              onSelected: (v) async {
                if (v == 'edit') _edit(context, ref);
                if (v == 'toggle') _toggle(context, ref);
                if (v == 'calisma') _calisma(context);
                // (P253 Asama 1) Tanilama karti ve sil (web ile ayni uclar).
                if (v == 'kart') {
                  await kisiKartiAc(context, id: member.id);
                  ref.invalidate(fieldStaffProvider);
                } else if (v == 'sil' &&
                    await kisiSilOnayli(context, ref, id: member.id, ad: member.ad)) {
                  ref.invalidate(fieldStaffProvider);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(
                  key: Key('personel-kart-${member.id}'),
                  value: 'kart',
                  child: Text(l10n.kisTanilama),
                ),
                if (yonetim)
                  PopupMenuItem(
                    key: Key('calisma-${member.id}'),
                    value: 'calisma',
                    child: Text(l10n.calismaDugme),
                  ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(member.isActive
                      ? l10n.personelPasiflestir
                      : l10n.personelAktiflestir),
                ),
                PopupMenuItem(
                  key: Key('personel-sil-${member.id}'),
                  value: 'sil',
                  child: Text(l10n.ortakSil),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await merkezSayfaAc<String?>(
      context,
      builder: (_) => _AddStaffSheet(existing: member),
    );
    if (saved != null) ref.invalidate(fieldStaffProvider);
  }

  Future<void> _calisma(BuildContext context) async {
    await merkezSayfaAc<String?>(
      context,
      builder: (_) => CalismaSayfasi(kisi: member),
    );
  }

  /// (P253 Asama 1) Pasiflestirme KISI ADIYLA onay ister (ortak yardimci).
  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (await kisiAktiflikDegistir(context, ref,
        id: member.id, ad: member.ad, aktif: !member.isActive)) {
      ref.invalidate(fieldStaffProvider);
    }
  }
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet({this.existing});

  /// null → yeni personel; dolu → o personeli DUZENLE (ad/rol; telefon
  /// opsiyonel — bos ise degismez). Parola alani HIC yok (ne eklemede ne
  /// duzenlemede); parolayi kisi kendi kayit akisinda belirler.
  final StaffMember? existing;

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  // (P250 §1) Soyad ayri ve zorunlu.
  final _soyadCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  // (P206 §4.2) E-POSTA ZORUNLU (P197): davet, dogrulama kodu ve parola
  // sifirlama YALNIZ buradan gidiyor — e-postasiz acilan hesap
  // sahiplenilemez. Alan YOKKEN sunucu 422 doruyordu ve mobil personel
  // ekleme FIILEN CALISMIYORDU.
  final _epostaCtrl = TextEditingController();
  String _role = 'security';
  bool _submitting = false;
  // (P252 §1) Calisma bilgileri — yalniz EKLEMEDE ve yalniz yonetime.
  final _calisma = CalismaDegeri();

  bool get _calismaBolumu =>
      !_isEdit &&
      (ref.watch(currentUserRoleProvider).value?.maasGorebilir ?? false);

  // Profil fotografi (P3) — yonetici saha personeli fotosunu yukler.
  Uint8List? _onizleme; // yeni secilen foto (memory onizleme)
  String? _fotoKey; // presign sonrasi yuklendi
  String? _mevcutUrl; // duzenlemede mevcut avatar (network onizleme)
  bool _fotoYukleniyor = false;

  bool get _isEdit => widget.existing != null;

  /// (P253 Asama 1) ROL SECENEKLERI SUNUCUDAN (`GET /users/acilabilir-roller`,
  /// web ile ayni). Sunucu cevabi gelene kadar (ya da hata) eski yerel kural.
  /// Duzenlenen kaydin MEVCUT rolu her zaman cizilir — aksi halde secili
  /// deger segmentlerde bulunmazdi.
  bool _rolSecilebilir(String rol) {
    if (widget.existing?.role == rol) return true;
    final sunucu = ref.watch(acilabilirRollerProvider).value;
    // BOS kume "hicbir rol" demektir ve o kullanici bu formu zaten acamaz;
    // bos/eksik yanitta yerel kurala dusulur (formu kilitlemek yerine).
    if (sunucu != null && sunucu.isNotEmpty) return sunucu.contains(rol);
    return rol != 'guvenlik_amiri' ||
        (ref.watch(currentUserRoleProvider).value?.amirAtayabilir ?? false);
  }

  bool get _amirSecilebilir => _rolSecilebilir('guvenlik_amiri');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      // (P250 §1) Eski kayitta soyad bilinmez: son kelime ONERILIR.
      final parca = adAyir(e.ad, e.soyad);
      _adCtrl.text = parca.ad;
      _soyadCtrl.text = parca.soyad;
      _role = e.role;
      _mevcutUrl = e.avatarUrl;
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _fotoSec(ImageSource source) async {
    if (_fotoYukleniyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;
    setState(() => _fotoYukleniyor = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: 800,
            imageQuality: 80,
          );
      if (file == null) {
        if (mounted) setState(() => _fotoYukleniyor = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final api = ref.read(staffApiProvider);
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(contentType: contentType);
      await api.uploadPhoto(
          ticket: ticket, bytes: bytes, contentType: contentType);
      if (!mounted) return;
      setState(() {
        _onizleme = bytes;
        _fotoKey = ticket.fotoKey;
        _fotoYukleniyor = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _fotoYukleniyor = false);
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _fotoYukleniyor = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gorevFotoAlinamadi('$e'))),
      );
    }
  }

  void _fotoSecMenu() {
    merkezSayfaAc<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheetContext.l10n.gorevKamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _fotoSec(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheetContext.l10n.ortakGaleri),
              onTap: () {
                Navigator.pop(sheetContext);
                _fotoSec(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _phoneCtrl.dispose();
    _epostaCtrl.dispose();
    _calisma.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    Map<String, dynamic>? calisma;
    if (_calismaBolumu) {
      final (govde, hata) = _calisma.govde(l10n);
      if (hata != null) {
        messenger.showSnackBar(SnackBar(content: Text(hata)));
        return;
      }
      calisma = govde;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(staffApiProvider);
      if (_isEdit) {
        await api.updateStaff(
              widget.existing!.id,
              ad: adBicimle(_adCtrl.text),
              soyad: soyadBicimle(_soyadCtrl.text),
              role: _role,
              telefon: telefonNormalle(_phoneCtrl.text),
            );
        // Yeni foto secildiyse ata (yalniz yonetici; sunucu zorlar).
        if (_fotoKey != null) {
          await api.setStaffAvatar(widget.existing!.id, _fotoKey);
        }
        if (!mounted) return;
        navigator.pop('ok');
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.personelGuncellendi)),
        );
        return;
      }
      final createdId = await api.addStaff(
            ad: adBicimle(_adCtrl.text),
            soyad: soyadBicimle(_soyadCtrl.text),
            telefon: telefonNormalle(_phoneCtrl.text),
            email: _epostaCtrl.text.trim(),
            role: _role,
            calisma: calisma,
          );
      // Personel olustuktan sonra foto secildiyse avatarini ata.
      if (_fotoKey != null) {
        await api.setStaffAvatar(createdId, _fotoKey);
      }
      if (!mounted) return;
      navigator.pop('ok');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.personelEklendi)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // (P250 §1) Ad + soyad iki alan oldu: kucuk ekranda / diyalogda govde
    // KAYDIRILIR (yoksa form tasar).
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? l10n.personelDuzenle : l10n.personelEkle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Profil fotografi (P3) — yonetici saha personeli fotosunu yukler.
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _onizleme != null
                      ? MemoryImage(_onizleme!)
                      : (_mevcutUrl != null
                          ? sinirliGorsel(
                              context, NetworkImage(_mevcutUrl!), 56)
                          : null),
                  child: (_onizleme == null && _mevcutUrl == null)
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _fotoYukleniyor || _submitting ? null : _fotoSecMenu,
                  icon: _fotoYukleniyor
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(l10n.personelFoto),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              // Rol adlari TEK KAYNAKTAN (rolAdi) — segment etiketi de.
              segments: [
                if (_rolSecilebilir('security') || !_rolSecilebilir('tesis_gorevlisi'))
                ButtonSegment(
                    value: 'security',
                    label: Text(rolAdi(l10n, UserRole.security)),
                    icon: const Icon(Icons.shield_outlined)),
                // (P248 §1) GUVENLIK AMIRI — yonetici DOGRUDAN ekler ya da
                // bir guvenlik gorevlisini amir yapar / amiri guvenlige
                // dusurur. Yalniz amir ATAYABILEN role (sunucu kumesinin
                // aynasi) ya da duzenlenen kayit zaten amirse cizilir —
                // aksi halde secili deger segmentlerde bulunmazdi.
                if (_amirSecilebilir)
                  ButtonSegment(
                      value: 'guvenlik_amiri',
                      label: Text(rolAdi(l10n, UserRole.guvenlikAmiri)),
                      icon: const Icon(Icons.local_police_outlined)),
                if (_rolSecilebilir('tesis_gorevlisi'))
                ButtonSegment(
                    value: 'tesis_gorevlisi',
                    label: Text(rolAdi(l10n, UserRole.tesisGorevlisi)),
                    icon: const Icon(Icons.cleaning_services_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 12),
            AdSoyadAlanlari(
              adKtrl: _adCtrl,
              soyadKtrl: _soyadCtrl,
              etkin: !_submitting,
              adSinir: 150, // sunucu: UserCreate.ad
              anahtarOneki: 'personel',
            ),
            const SizedBox(height: 12),
            TelefonAlani(
              ktrl: _phoneCtrl,
              etiket:
                  _isEdit ? l10n.personelTelefonOpsiyonel : l10n.ortakCepTelefonu,
              ipucu: l10n.ortakTelefonIpucu,
              etkin: !_submitting,
              // (P212-ek §2) TELEFON OPSIYONEL: platform genelinde benzersiz
              // oldugu icin zorunlu tutmak, ayni kisinin IKINCI bir tesise
              // ancak UYDURMA numarayla eklenmesi demekti. Bicim denetimi
              // duruyor: doldurulduysa gecerli olmali.
              zorunlu: false,
            ),
            const SizedBox(height: 12),
            // DUZENLEMEDE DEGISTIRILMEZ: e-posta degisikligi ayri bir
            // akistir (dogrulama + eski adrese bildirim, P184) ve onu
            // buradan sessizce yapmak, hesabi baska birine devretmenin
            // kolay yolu olurdu.
            //
            // (P233 §4) YEREL REGEX KALDIRILDI: `^[^@\s]+@[^@\s]+\.[^@\s]+$`
            // bicimi goruyordu ama UZUNLUK sinirlarini (yerel 64 / toplam
            // 254) bilmiyordu — sunucunun reddettigi adres burada gecerli
            // gorunuyordu.
            EpostaAlani(
              alanAnahtari: const Key('personel-eposta'),
              ktrl: _epostaCtrl,
              etiket: l10n.personelEposta,
              ipucu: l10n.personelEpostaYardim,
              etkin: !_submitting && !_isEdit,
              zorunlu: !_isEdit,
            ),
            // Parola alani KALDIRILDI (P186-ek2): hesap parolasiz acilir ve
            // davet gonderilir; parolayi kisi kendi kayit akisinda belirler.
            if (_calismaBolumu) ...[
              const Divider(height: 32),
              CalismaAlanlari(deger: _calisma, etkin: !_submitting),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(_isEdit ? l10n.ortakGuncelle : l10n.ortakEkle),
            ),
          ],
        ),
      ),
    );
  }
}

/// image_picker mimeType vermezse uzantidan tahmin (announcements ile ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(context.l10n.ortakTekrarDene),
            ),
          ],
        ),
      ),
    );
  }
}
