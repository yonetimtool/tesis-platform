import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/girdi_siniri.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/kisi_adi.dart';
import '../../../core/ui/ad_soyad_alanlari.dart';
import '../../../core/ui/bos_durum.dart';
import '../../odeme_kodlari/presentation/odeme_kodlari_screen.dart';
import '../../kisiler/presentation/kisi_islemleri.dart';
import '../data/residents_api.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/eposta_alani_widget.dart';
import '../../../core/ui/telefon_alani_widget.dart';

/// Site Sakinleri — yonetici/admin: sakinleri listeler, yeni tasinani ekler
/// (parolasiz hesap + otomatik davet), ayrilani cikarir (pasiflestir). Sakin
/// daveti (Tesis ID) ile kendi kaydini tamamlar.
/// (P220 §4) SAKINLER BLOKLARA GORE GRUPLU + BLOKTA ARAMA.
///
/// Gerekce (kullanicinin): "bir sakin siteden ayrildiginda yonetici onu
/// kolayca bulup hesabini silsin, yerine yeni sakini eklesin."
///
/// Duz bir liste o isi zorlastiriyordu: yonetici sakinin ADINI
/// bilmiyorsa (cogu zaman bilmiyor — "B blokta 4. kattaki") listeyi
/// tepeden tarayacakti. Gruplama ve blok aramasi o adimi kaldiriyor.
class ResidentsScreen extends ConsumerStatefulWidget {
  const ResidentsScreen({super.key, this.gomulu = false});

  /// (P251 §8) Kisiler ekraninin SEKMESI olarak cizilir: ust cubugu
  /// Kisiler verir, bu ekran yalniz govdeyi (ve kendi "Ekle" dugmesini).
  final bool gomulu;

  @override
  ConsumerState<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends ConsumerState<ResidentsScreen> {
  final _aramaKtrl = TextEditingController();

  /// Bildirim aramasiyla AYNI gecikme (300 ms) — iki ekranin farkli
  /// davranmasi, ayni jestin birinde akici otekinde takilarak calismasi
  /// olurdu.
  Timer? _zamanlayici;

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _aramaKtrl.dispose();
    super.dispose();
  }

  void _aramaDegisti(String v) {
    _zamanlayici?.cancel();
    _zamanlayici = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(sakinSuzgeciProvider.notifier).ara(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(residentsProvider);
    final suzgec = ref.watch(sakinSuzgeciProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: widget.gomulu
          ? null
          : AppBar(
              title: Text(baslikBuyuk(l10n.sakinBaslik, context.dilKodu)),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.sakinEkle),
      ),
      body: Column(
        children: [
          // (P250 §2) ODEME KODLARI — web'deki "Odeme kodlari" penceresinin
          // mobil karsiligi. UST CUBUKTA DEGIL: 2x yazi olceginde baslikla
          // birlikte tasiyordu (olculdu); liste satiri metni sarar.
          ListTile(
            key: const Key('sakin-odeme-kodlari'),
            dense: true,
            leading: const Icon(Icons.qr_code_2_outlined),
            title: Text(l10n.odemeKodlariBaslik),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OdemeKodlariScreen(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _aramaKtrl,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.arama), // sunucu: GET /residents ?q
              onChanged: _aramaDegisti,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                // ARAMA UC ALANI KAPSAR: ad, daire no, blok. Yoneticinin
                // elinde bu ucunden biri olur.
                hintText: l10n.sakinAraIpucu,
                helperText:
                    suzgec.arama.trim().isNotEmpty && !suzgec.aramaGecerli
                        ? l10n.sakinAraAsgari
                        : null,
                suffixIcon: suzgec.arama.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _zamanlayici?.cancel();
                          _aramaKtrl.clear();
                          ref.read(sakinSuzgeciProvider.notifier).ara('');
                        },
                      ),
              ),
            ),
          ),
          // BLOK DARALTMASI ACIKSA GORUNUR ve TEK DOKUNUSLA kalkar:
          // gizli bir suzgec, "sakinim listede yok" sorusunun en sik
          // sebebidir.
          if (suzgec.blok != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  label: Text(l10n.sakinBlokSuzgeci(suzgec.blok!)),
                  onDeleted: () =>
                      ref.read(sakinSuzgeciProvider.notifier).blokSec(null),
                ),
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                // Sunucu metni varsa o gosterilir (SERVER-LOCALIZED siniri);
                // yoksa yerellestirilmis genel metin.
                message: e is ApiException
                    ? apiHataMetni(l10n, e)
                    : l10n.sakinListelenemedi,
                onRetry: () => ref.invalidate(residentsProvider),
              ),
              data: (list) => list.isEmpty
                  ? (suzgec.aramaGecerli || suzgec.blok != null
                      // ARAMA SONUCU BOS ile SITE BOS AYRI: ikisine ayni
                      // "sakin yok" demek, yoneticiye siteyi bos
                      // gosterirdi.
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l10n.sakinAramaSonucYok,
                                textAlign: TextAlign.center),
                          ),
                        )
                      // (P166 §10) Bos durumda cagri dugmesi — bkz. personel.
                // (P239 §6) BOS DURUMDA CAGRI DUGMESI KALDIRILDI.
                //
                // FAB zaten sag altta duruyor ve liste dolunca da orada
                // kaliyor. Ikisi birlikteyken kullanici AYNI eylemi iki
                // yerde goruyor; liste dolunca ortadaki kayboluyor ve
                // "dugme nereye gitti" sorusu doguyor. Aciklama metni
                // KALIR — ne oldugunu ve nereden ekleneceğini soyler.
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            BosDurum(
                              ikon: Icons.home_outlined,
                              baslik: l10n.sakinYok,
                              aciklama: l10n.sakinYokAlt,
                            ),
                            // (P243 §3) TOPLU AKTARIM MOBILDE YOK —
                            // P204 karari. 200 satirlik bir onizlemeyi
                            // telefonda dogrulamak mumkun degil.
                            //
                            // SESSIZ BIRAKILMADI: yonetici elindeki
                            // listeyi nereden yukleyecegini bilmeli;
                            // yoksa tek tek eklemeye baslar.
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 8),
                              child: Text(
                                l10n.topluAktarimBilgisayardan,
                                key: const Key('sakin-toplu-aktarim-notu'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(residentsProvider),
                      child: _BloklaListe(gruplar: bloklaraGore(list)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final created = await merkezSayfaAc<String?>(
      context,
      builder: (_) => const _AddResidentSheet(),
    );
    if (created != null) ref.invalidate(residentsProvider);
  }
}

/// Bloklara gore gruplu liste — her blok bir baslik + sakinleri.
class _BloklaListe extends ConsumerWidget {
  const _BloklaListe({required this.gruplar});

  final List<SakinBlogu> gruplar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Duz bir `ListView` uzerinde baslik + satirlar: `ExpansionTile`
    // KULLANILMADI, cunku kapali bir grup "sakinim listede yok"
    // sorusunun ikinci sebebi olurdu.
    final ogeler = <Widget>[];
    for (final g in gruplar) {
      ogeler.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  g.blok ?? l10n.sakinBloksuz,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${g.sakinler.length}',
                  style: Theme.of(context).textTheme.bodySmall),
              if (g.blok != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  // `visualDensity: compact` KALDIRILDI: dokunma hedefini
                  // 40x40'a dusuruyordu ve erisilebilirlik kilidi
                  // ("Tappable objects should be at least 48x48")
                  // YAKALADI. Sıkısik gorunum ugruna dokunma hedefini
                  // kucultmek, motor gucluk yasayan kullanicida dugmeyi
                  // isabet ettirilemez yapar.
                  tooltip: l10n.sakinBlogaDaralt,
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  onPressed: () =>
                      ref.read(sakinSuzgeciProvider.notifier).blokSec(g.blok),
                ),
              ],
            ],
          ),
        ),
      );
      for (final m in g.sakinler) {
        ogeler.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ResidentTile(member: m, ref: ref),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: ogeler,
    );
  }
}

class _ResidentTile extends StatelessWidget {
  const _ResidentTile({required this.member, required this.ref});

  final ResidentMember member;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = member.unitNo?.isNotEmpty == true
        ? l10n.gorevDaireEtiket(member.unitNo!)
        : l10n.sakinDaireYok;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            member.isActive ? Icons.home_outlined : Icons.person_off_outlined,
          ),
        ),
        title: Text(member.ad),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!member.isActive)
              Chip(
                label: Text(l10n.devriyePasif),
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            PopupMenuButton<String>(
              tooltip: l10n.sakinIslemleri,
              key: Key('sakin-islemler-${member.userId}'),
              onSelected: (v) async {
                if (v == 'edit') _edit(context);
                if (v == 'delete') _confirmRemove(context);
                // (P253 Asama 1) Tanilama karti + aktif/pasif (web ile ayni).
                if (v == 'kart') {
                  await kisiKartiAc(context, id: member.userId);
                  ref.invalidate(residentsProvider);
                }
                if (v == 'aktiflik' &&
                    context.mounted &&
                    await kisiAktiflikDegistir(context, ref,
                        id: member.userId, ad: member.ad, aktif: !member.isActive)) {
                  ref.invalidate(residentsProvider);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(
                  key: Key('sakin-kart-${member.userId}'),
                  value: 'kart',
                  child: Text(l10n.kisTanilama),
                ),
                PopupMenuItem(
                  value: 'aktiflik',
                  child: Text(member.isActive
                      ? l10n.personelPasiflestir
                      : l10n.personelAktiflestir),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.ortakSil)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await merkezSayfaAc<bool>(
      context,
      builder: (_) => _EditResidentSheet(member: member),
    );
    if (changed == true) ref.invalidate(residentsProvider);
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Async bosluklardan ONCE yakala.
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sakinSilOnay),
        content: Text(l10n.sakinSilGovde(member.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final deleted = await ref
          .read(residentsApiProvider)
          .removeResident(member.userId);
      ref.invalidate(residentsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? l10n.sakinSilindi(member.ad)
                : l10n.sakinPasiflestirildi(member.ad),
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}

/// Sakin duzenle alt sayfasi (P23b) — OLUSTURMADAKI TUM ALANLAR.
///
/// Eskiden yalniz Ad + telefon vardi; e-posta ve ilişki tipi (kat maliki /
/// kiraci) olusturmada giriliyor ama BIR DAHA degistirilemiyordu. Kiraci
/// cikip malik oturmaya baslayinca kayit yanlis kaliyordu — ve bu, aidatin
/// KIME borclandirilacagini belirledigi icin (P28) muhasebeyi dogrudan
/// bozacak bir hataydi.
class _EditResidentSheet extends ConsumerStatefulWidget {
  const _EditResidentSheet({required this.member});

  final ResidentMember member;

  @override
  ConsumerState<_EditResidentSheet> createState() => _EditResidentSheetState();
}

class _EditResidentSheetState extends ConsumerState<_EditResidentSheet> {
  final _formKey = GlobalKey<FormState>();
  // (P250 §1) Ad ve soyad AYRI; eski kayitta soyad bilinmez, son kelime
  // ONERILIR (kayit ancak kaydedilince degisir).
  late final _parca = adAyir(widget.member.ad, widget.member.soyad);
  late final TextEditingController _adCtrl =
      TextEditingController(text: _parca.ad);
  late final TextEditingController _soyadCtrl =
      TextEditingController(text: _parca.soyad);
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  /// null = "degistirme" (gonderilmez).
  /// (P218) DAIREDEKI SIFAT — uc secenek, tek alan.
  ///
  /// Web'deki iki yuzeyle (kullanici ekleme, daire paneli) AYNI soruyu
  /// sorar. Onceden yalniz `malik|kiraci` vardi ve "malik ve oturan"
  /// hicbir yerde temsil edilemiyordu; oysa KMK md. 20 isletme giderini
  /// KULLANANA, bakim giderini MALIGE yukluyor ve oturan malik ikisinden
  /// de sorumlu.
  ///
  /// Degerler ARAYUZ kavramidir; sunucuya IKI ALAN gider.
  String? _sifat;

  /// Arayuz sifati -> (rol_tipi, oturuyor).
  static const _sifatVerisi = <String, (String, bool)>{
    'malik': ('malik', false),
    'kiraci': ('kiraci', true),
    'malik_oturan': ('malik', true),
  };
  bool _emailTemizle = false;
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref
          .read(residentsApiProvider)
          .updateResident(
            widget.member.userId,
            ad: adBicimle(_adCtrl.text),
            soyad: soyadBicimle(_soyadCtrl.text),
            telefon: telefonNormalle(_phoneCtrl.text),
            email: _emailCtrl.text.trim(),
            emailTemizle: _emailTemizle,
            rolTipi: _sifat == null ? null : _sifatVerisi[_sifat]!.$1,
            oturuyor: _sifat == null ? null : _sifatVerisi[_sifat]!.$2,
          );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sakinGuncellendi)));
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
            Text(
              l10n.sakinDuzenleBaslik,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AdSoyadAlanlari(
              adKtrl: _adCtrl,
              soyadKtrl: _soyadCtrl,
              etkin: !_submitting,
              adSinir: 150, // sunucu: ResidentUpdate.ad
              anahtarOneki: 'sakin-duzenle',
            ),
            const SizedBox(height: 12),
            TelefonAlani(
              ktrl: _phoneCtrl,
              etiket: l10n.sakinYeniTelefon,
              ipucu: l10n.ortakTelefonIpucu,
              etkin: !_submitting,
              // (P212-ek §2) EKLEMEDE OPSIYONEL — staff ile ayni gerekce.
              zorunlu: false,
            ),
            const SizedBox(height: 12),
            EpostaAlani(
              ktrl: _emailCtrl,
              etiket: l10n.sakinEposta,
              ipucu: l10n.sakinBosBirakDegismez,
              etkin: !_submitting && !_emailTemizle,
              // DUZENLEMEDE BOS = DEGISTIRME (asagidaki anahtar ACIKCA
              // siler). Bos degeri hata saymak, "degistirme" yolunu
              // kapatirdi.
              zorunlu: false,
            ),
            // "Bos birakmak" ile "SILMEK" ayri seylerdir: bos alan alani
            // degistirmez, bu anahtar ACIKCA null gonderir.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sakinEpostaTemizle),
              value: _emailTemizle,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _emailTemizle = v),
            ),
            const SizedBox(height: 4),
            // `isExpanded` ZORUNLU (§15 kalibi): uzun ceviri + prefixIcon
            // 320 dp'de tasirir.
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _sifat,
              decoration: InputDecoration(
                labelText: l10n.sakinRolTipi,
                helperText: l10n.sakinRolAlt,
                helperMaxLines: 3,
                prefixIcon: const Icon(Icons.key_outlined),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sakinRolDegisme),
                ),
                DropdownMenuItem(
                  value: 'malik',
                  child: Text(l10n.sakinRolMalik),
                ),
                DropdownMenuItem(
                  value: 'kiraci',
                  child: Text(l10n.sakinRolKiraci),
                ),
                // (P218) UCUNCU DURUM: hem malik hem kullanan.
                DropdownMenuItem(
                  value: 'malik_oturan',
                  child: Text(l10n.sakinRolMalikOturan),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _sifat = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l10n.ortakKaydet),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddResidentSheet extends ConsumerStatefulWidget {
  const _AddResidentSheet();

  @override
  ConsumerState<_AddResidentSheet> createState() => _AddResidentSheetState();
}

/// (P154 / Asama 5) MOBIL TEKLI EKLEME — telefon + daire no, BASKA ALAN YOK.
///
/// Brief: "MOBIL: 'Site sakini' sekmesinden TEKLI ekler; eklerken YALNIZ
/// TELEFON girer." Kerem daire no'nun kalmasini netlestirdi (sakinin hangi
/// daireye baglanacagi baska turlu bilinmiyor ve §3'un daire eslesmesi
/// buna dayaniyor).
///
/// KALKAN IKI ALAN VE NEDENLERI:
///  * AD SOYAD — (P250 §1 ile GERI ALINDI: ad ve soyad zorunlu, asagiya
///    bakin.)
///  * PAROLA — brief'te sakinin parolasini YONETICI belirlemiyor;
///    kullanici kendi kayit akisinda (rol -> tesis ID -> telefon ->
///    yontem) seciyor. Yoneticinin parola koymasi, o akisin "hesabi
///    SAHIPLENME" adimini bastan tuketirdi.
class _AddResidentSheetState extends ConsumerState<_AddResidentSheet> {
  final _formKey = GlobalKey<FormState>();
  // (P250 §1) AD + SOYAD GERI GELDI VE ZORUNLU. P154'te ad opsiyoneldi
  // ("yonetici adi cogu zaman bilmez") ve sunucu "A-12 sakini" yaziyordu.
  // P250 karari: yeni kullanici ad ve soyadla eklenir; web'deki kullanici
  // ekleme formuyla AYNI kural (parite).
  final _adCtrl = TextEditingController();
  final _soyadCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  // (E2E 2026-09) Davet e-postadan gider; sunucu e-postayi ZORUNLU tutar.
  final _emailCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  // (P220 §4) BLOK AYRI ALAN — daire numarasindan TURETILMIYOR.
  //
  // `A-12` numarali bir daire `B` blogunda olabilir: blok `unit.blok`
  // sutunudur, numaranin bir parcasi degil (P193'te ikisi BILEREK
  // ayrildi). Numaradan tahmin etmek, yanlis blokta bir daire acardi ve
  // o sakin bloklara gore gruplanmis listede YANLIS YERDE gorunurdu.
  final _blokCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _unitCtrl.dispose();
    _blokCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref
          .read(residentsApiProvider)
          .addResident(
            ad: adBicimle(_adCtrl.text),
            soyad: soyadBicimle(_soyadCtrl.text),
            telefon: telefonNormalle(_phoneCtrl.text),
            email: _emailCtrl.text,
            unitNo: _unitCtrl.text.trim(),
            blok: _blokCtrl.text,
          );
      if (!mounted) return;
      navigator.pop('ok');
      messenger.showSnackBar(SnackBar(content: Text(l10n.sakinEklendi)));
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
            Text(
              l10n.sakinEkle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AdSoyadAlanlari(
              adKtrl: _adCtrl,
              soyadKtrl: _soyadCtrl,
              etkin: !_submitting,
              adSinir: 150, // sunucu: ResidentCreate.ad
              anahtarOneki: 'sakin-ekle',
            ),
            const SizedBox(height: 12),
            TelefonAlani(
              ktrl: _phoneCtrl,
              etiket: l10n.ortakCepTelefonu,
              ipucu: l10n.ortakTelefonIpucu,
              etkin: !_submitting,
              zorunlu: true,
            ),
            const SizedBox(height: 12),
            EpostaAlani(
              ktrl: _emailCtrl,
              etiket: l10n.sakinEposta,
              etkin: !_submitting,
              zorunlu: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.daireNo), // sunucu: ResidentCreate.unit_no
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.binaDaireNo,
                hintText: l10n.ortakDaireNoIpucu,
                prefixIcon: const Icon(Icons.door_front_door_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.sakinDaireNoZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _blokCtrl,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.blok), // sunucu: ResidentCreate.blok
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.sakinBlokAlani,
                prefixIcon: const Icon(Icons.apartment_outlined),
                border: const OutlineInputBorder(),
                // NE YAPTIGI ACIKCA YAZILI: sunucu blogu yalniz YENI
                // acilan daireye isliyor. Bunu soylememek, mevcut bir
                // dairenin blogunu degistirdigini sanan yonetici
                // uretirdi.
                helperText: l10n.sakinBlokIpucu,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l10n.ortakEkle),
            ),
          ],
        ),
      ),
    );
  }
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
