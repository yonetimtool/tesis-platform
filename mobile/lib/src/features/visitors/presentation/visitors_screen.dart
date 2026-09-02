import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/error/api_exception.dart';
import '../../call/presentation/call_button.dart';
import '../data/visitor_api.dart';
import '../domain/visitor_models.dart';
import '../../../core/ui/merkez_diyalog.dart';
import 'visitors_controller.dart';

/// "Ziyaretciler" — kapi ZIYARETCI KAYDI (LOG-ONLY, auth.md §4 UX aynasi):
///   * security: "Yeni ziyaretci" FAB'i (ad + daire no + hedef sakin + not) +
///     tenant'in tum kayit gecmisi.
///   * resident: KENDINE hedeflenen ziyaretci kayitlari — BILGILENDIRME
///     (kaydedildi bilgisi). Onay/red YOKTUR.
///   * admin/yonetici: tek-seferlik izinle daire kayitlari (salt izleme).
///
/// [initialVisitorId] push tiklamasindan gelir (?visitor_id=...): liste
/// yuklendiginde ilgili kaydin detayi BIR KEZ otomatik acilir; kayit listede
/// yoksa (yetki disi/silinmis) sessizce listede kalinir.
class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key, this.initialVisitorId});

  final String? initialVisitorId;

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(VisitorsState state) {
    if (_initialHandled || widget.initialVisitorId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Visitor? hedef;
    for (final v in state.items) {
      if (v.id == widget.initialVisitorId) {
        hedef = v;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final v = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showDetail(context, v, canRegister: state.canRegister);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsControllerProvider);
    final controller = ref.read(visitorsControllerProvider.notifier);
    ref.listen(visitorsControllerProvider, (_, next) => _maybeOpenInitial(next));
    _maybeOpenInitial(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(context.l10n.modulZiyaretciler,
            context.dilKodu)),
        actions: [
          IconButton(
            tooltip: context.l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canRegister
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.l10n.ziyaretYeni),
              onPressed: () => _openForm(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await _showVisitorForm(context);
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ziyaretKaydedildi)),
      );
    }
  }
}

/// Ziyaretci formunu alt sayfada acar (yeni veya [existing] duzenleme).
/// Kaydedildiyse true doner.
Future<bool> _showVisitorForm(BuildContext context, {Visitor? existing}) async {
  final saved = await merkezSayfaAc<bool>(
    context,
    builder: (_) => VisitorForm(existing: existing),
  );
  return saved == true;
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final VisitorsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final hata = akisHatasiCoz(
      context.l10n,
      state.hataKimligi,
      state.errorMessage,
    );
    if (hata != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            hata,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              state.canRegister
                  ? context.l10n.ziyaretYokGuvenlik
                  : context.l10n.ziyaretYokSakin,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _VisitorCard(
        visitor: state.items[i],
        canRegister: state.canRegister,
      ),
    );
  }
}

class _VisitorCard extends ConsumerWidget {
  const _VisitorCard({required this.visitor, required this.canRegister});

  final Visitor visitor;
  final bool canRegister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = visitor;
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, v, canRegister: canRegister),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.ziyaretciAd,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.karDaireTarih(
                  v.unitNo ?? '-',
                  tarihSaatBicimi(v.createdAt, dil),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (v.targetResidentAd != null) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.ziyaretBildirilenSakin(v.targetResidentAd!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (v.notlar != null && v.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(v.notlar!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir. Log-only:
/// onay/red YOK; yalniz kayit bilgisi + rol-bazli arama (rıza kapısıyla).
void _showDetail(
  BuildContext context,
  Visitor v, {
  required bool canRegister,
}) {
  merkezSayfaAc<void>(
    context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final dil = sheetContext.dilKodu;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    v.ziyaretciAd,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.karDaire(v.unitNo ?? '-')),
            const SizedBox(height: 4),
            Text('${l10n.karKayit(tarihSaatBicimi(v.createdAt, dil))}'
                '${v.kaydedenAd != null ? l10n.karAdEki(v.kaydedenAd!) : ''}'),
            if (v.notlar != null && v.notlar!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.karNot(v.notlar!)),
            ],
            // Rol-bazli arama (C1a): güvenlik → HEDEF sakini arar; sakin →
            // kaydı açan GÜVENLİĞİ arar. Buton yalnız aranabilir (rıza) ise
            // etkinleşir; numara ekranda gösterilmez (/call-target kapısı).
            if (canRegister && v.targetResidentUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              CallButton(
                  userId: v.targetResidentUserId,
                  label: l10n.ziyaretSakiniAra),
            ],
            if (!canRegister && v.kaydedenUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              CallButton(
                  userId: v.kaydedenUserId, label: l10n.ziyaretGuvenligiAra),
            ],
            // Guvenlik kaydi duzenler (ad/daire/hedef/not).
            if (canRegister) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.ziyaretBilgileriDuzenle),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    final saved =
                        await _showVisitorForm(context, existing: v);
                    if (saved && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(l10n.ziyaretGuncellendi)),
                      );
                    }
                  },
                ),
              ),
            ],
            ],
          ),
        ),
      );
    },
  );
}

/// Ziyaretci formu (yalniz guvenlik): ad + daire + hedef sakin + not.
/// [existing] null → yeni kayit; dolu → o kaydi DUZENLE.
///
/// (P203 §3) SINIF DISA ACILDI (`@visibleForTesting`): daire secimi
/// artik bir ARAMA AKISIDIR (gecikmeli istek, sonuc listesi, secimle
/// dolan hedef secicisi) ve bu akis ancak formun KENDISI cizilerek
/// olculebilir. Ekranin tamamini cizmek, olculmek istenen seyin
/// yanina ziyaretci listesini ve rol kapisini da katmakti.
@visibleForTesting
class VisitorForm extends ConsumerStatefulWidget {
  const VisitorForm({this.existing, super.key});

  final Visitor? existing;

  @override
  ConsumerState<VisitorForm> createState() => _VisitorFormState();
}

class _VisitorFormState extends ConsumerState<VisitorForm> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _unitNo = TextEditingController();
  final _notlar = TextEditingController();
  bool _busy = false;
  String? _hata;

  /// Hedef sakin secicisi (tek hedef modeli): once daire sakinleri cekilir.
  List<UnitResidentBrief>? _residents;
  bool _loadingResidents = false;
  String? _residentsError;
  String? _targetId;

  bool get _isEdit => widget.existing != null;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _ad.text = e.ziyaretciAd;
      _unitNo.text = e.unitNo ?? '';
      _notlar.text = e.notlar ?? '';
      _targetId = e.targetResidentUserId;
      // Mevcut dairenin sakinlerini getir ki hedef acilir-menusu dolsun
      // (secili hedef korunur).
      if ((e.unitNo ?? '').isNotEmpty) {
        Future.microtask(() => _loadResidents(keepTarget: e.targetResidentUserId));
      }
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _aramaZamanlayici?.cancel();
    _unitNo.dispose();
    _notlar.dispose();
    super.dispose();
  }

  /// (P203 §3) Arama sonuclari. `null` = henuz aranmadi.
  List<DaireArama>? _sonuclar;

  /// Aramayi GECIKTIREN zamanlayici. Her tusta istek atmak, dokuz
  /// harflik bir isim icin dokuz istek demekti.
  Timer? _aramaZamanlayici;

  /// (P203 §3) Arama kutusu degisti — GECIKMELI ara.
  void _aramaDegisti(String deger) {
    _aramaZamanlayici?.cancel();
    // Secim yapilmis bir daireyi kullanici DEGISTIRIYORSA eski hedef
    // artik gecerli degil: sessizce durmasi, yanlis sakine bildirim
    // gonderilmesi demekti.
    setState(() {
      _targetId = null;
      _residents = null;
    });
    if (deger.trim().length < 2) {
      setState(() => _sonuclar = null);
      return;
    }
    _aramaZamanlayici = Timer(const Duration(milliseconds: 350), () {
      unawaited(_ara(deger.trim()));
    });
  }

  Future<void> _ara(String q) async {
    setState(() {
      _loadingResidents = true;
      _residentsError = null;
    });
    try {
      final liste = await ref.read(visitorApiProvider).daireAra(q);
      if (!mounted) return;
      setState(() => _sonuclar = liste);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _residentsError = apiHataMetni(_l10n, e));
    } finally {
      if (mounted) setState(() => _loadingResidents = false);
    }
  }

  /// Listeden bir daire secildi: numara alana yazilir, sakinler AYNI
  /// yanittan doldurulur (ikinci cagri YOK).
  void _daireSec(DaireArama d) {
    setState(() {
      _unitNo.text = d.no;
      _sonuclar = null;
      _residents = d.sakinler;
      _residentsError =
          d.sakinler.isEmpty ? _l10n.ziyaretciDaireSakinYok : null;
      // TEK SAKIN VARSA otomatik secilir — gorevliye anlamsiz bir
      // secim yaptirmayiz (mevcut davranisin aynisi).
      _targetId = d.sakinler.length == 1 ? d.sakinler.first.userId : null;
    });
  }

  /// Girilen daire NO'su icin AKTIF sakinleri getir (hedef secicisini doldur).
  /// [keepTarget] verilirse (duzenleme on-yuklemesi) o hedef korunur.
  Future<void> _loadResidents({String? keepTarget}) async {
    final unitNo = _unitNo.text.trim();
    if (unitNo.isEmpty) {
      setState(() => _residentsError = _l10n.ziyaretOnceDaireNo);
      return;
    }
    setState(() {
      _loadingResidents = true;
      _residentsError = null;
      _residents = null;
      _targetId = keepTarget;
    });
    try {
      final list =
          await ref.read(visitorApiProvider).fetchUnitResidents(unitNo);
      if (!mounted) return;
      setState(() {
        _residents = list;
        if (list.isEmpty) {
          _residentsError = context.l10n.ziyaretciDaireSakinYok;
        } else if (keepTarget != null &&
            list.any((r) => r.userId == keepTarget)) {
          _targetId = keepTarget; // duzenlemede mevcut hedef korunur
        } else if (list.length == 1) {
          _targetId = list.first.userId; // tek sakin -> otomatik secili
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _residentsError = apiHataMetni(_l10n, e));
    } finally {
      if (mounted) setState(() => _loadingResidents = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_targetId == null) {
      setState(() => _hata = _l10n.ziyaretSakiniSecin);
      return;
    }
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      final notlar =
          _notlar.text.trim().isEmpty ? null : _notlar.text.trim();
      final ctrl = ref.read(visitorsControllerProvider.notifier);
      if (_isEdit) {
        await ctrl.update(
          widget.existing!.id,
          ziyaretciAd: _ad.text.trim(),
          unitNo: _unitNo.text.trim(),
          targetResidentUserId: _targetId!,
          notlar: notlar,
        );
      } else {
        await ctrl.register(
          VisitorDraft(
            ziyaretciAd: _ad.text.trim(),
            unitNo: _unitNo.text.trim(),
            targetResidentUserId: _targetId!,
            notlar: notlar,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 422 invalid_reference: daire yok / hedef o dairenin sakini degil.
      if (mounted) setState(() => _hata = apiHataMetni(_l10n, e));
    } catch (_) {
      if (mounted) {
        setState(() => _hata = _l10n.karGonderilemedi);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Klavye acilinca form yukari itilsin.
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? l10n.ziyaretDuzenleBaslik : l10n.ziyaretYeni,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _isEdit ? l10n.ziyaretDuzenleAlt : l10n.ziyaretYeniAlt,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ad,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.ziyaretAdAlan,
                border: const OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.ziyaretAdGerekli
                  : null,
            ),
            const SizedBox(height: 8),
            // (P203 §3) DAIRE SECIMI — ARANABILIR, ELLE YAZILMAZ.
            //
            // Eskiden serbest metin + "Sakinleri getir" dugmesiydi.
            // Kapidaki gorevli cogu zaman daire numarasini DEGIL ISMI
            // biliyor; numarayi tahmin etmek sessiz bir kusur
            // uretiyordu (yanlis daire -> bildirim BASKA sakine).
            //
            // Alan hem NUMARAYA hem SAKIN ADINA gore arar. Secim
            // yapilinca sakinler AYNI YANITTAN dolar — ikinci bir
            // cagri ve ikinci bir bekleme yok.
            TextFormField(
              key: const Key('ziyaret-daire-ara'),
              controller: _unitNo,
              decoration: InputDecoration(
                labelText: l10n.ziyaretDaireAra,
                helperText: l10n.ziyaretDaireAraIpucu,
                border: const OutlineInputBorder(),
                suffixIcon: _loadingResidents
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
              ),
              maxLength: 50,
              onChanged: _aramaDegisti,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.karDaireNoGerekli
                  : null,
            ),
            // ARAMA SONUCLARI — secilince kapanir.
            if (_sonuclar != null && _sonuclar!.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    for (final d in _sonuclar!)
                      ListTile(
                        key: Key('ziyaret-daire-${d.no}'),
                        dense: true,
                        title: Text(d.gorunenAd),
                        // SAKIN ADLARI GORUNUR: gorevli dogru daireyi
                        // ISIMDEN tanir — ozelligin varlik sebebi.
                        subtitle: d.sakinler.isEmpty
                            ? Text(l10n.ziyaretciDaireSakinYok)
                            : Text(d.sakinler.map((s) => s.ad).join(', ')),
                        onTap: () => _daireSec(d),
                      ),
                  ],
                ),
              ),
            // Hedef sakin secicisi — daire sakinleri cekilince gorunur.
            if (_residentsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _residentsError!,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            if (_residents != null && _residents!.isNotEmpty)
              DropdownButtonFormField<String>(
                // Uzun ceviri + dar ekran: `isExpanded` olmazsa ic Row tasar
                // (tur 26 dersi — README §15 dropdown kalibi).
                isExpanded: true,
                initialValue: _targetId,
                decoration: InputDecoration(
                  labelText: l10n.ziyaretBildirilecekSakin,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final r in _residents!)
                    DropdownMenuItem(value: r.userId, child: Text(r.ad)),
                ],
                onChanged: (v) => setState(() => _targetId = v),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notlar,
              decoration: InputDecoration(
                labelText: l10n.ortakNotOpsiyonel,
                border: const OutlineInputBorder(),
              ),
              maxLength: 1000,
              maxLines: 2,
            ),
            if (_hata != null) ...[
              const SizedBox(height: 8),
              Text(_hata!, style: const TextStyle(color: Colors.red)),
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
                    : Icon(_isEdit ? Icons.save_outlined : Icons.person_add_alt_1),
                label: Text(_isEdit
                    ? l10n.ortakGuncelle
                    : l10n.ziyaretKaydetVeBildir),
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
