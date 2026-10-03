import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/kisi_adi.dart';
import '../../../core/ui/ad_soyad_alanlari.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/eposta_alani_widget.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_alani_widget.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../staff/data/staff_api.dart';
import 'kisi_islemleri.dart';
import 'kisi_suzgec.dart';

/// (P251 §8) KISILER › YONETICILER VE DENETCILER — mobilde yoktu.
///
/// Olcum tablosu: yonetici ve denetci hesabi mobilde HIC acilamiyordu
/// (yalniz web). Ayni `POST /users` ucu; hesap PAROLASIZ acilir ve davet
/// e-postasi gider (P186). Sunucu cagiranin acabilecegi rolleri zorlar
/// (`/users/acilabilir-roller`); yetkisiz rol 403 ile anlasilir doner.
class YoneticiListesi extends ConsumerStatefulWidget {
  const YoneticiListesi({super.key});

  @override
  ConsumerState<YoneticiListesi> createState() => _YoneticiListesiState();
}

class _YoneticiListesiState extends ConsumerState<YoneticiListesi> {
  // (P253 Asama 1) Arama + durum suzgeci ve satir eylemleri (tanilama,
  // aktif/pasif, sil) — web Kisiler listesiyle ayni uclar.
  final _ara = TextEditingController();
  KisiDurumSuzgeci _durum = KisiDurumSuzgeci.tumu;

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  Future<void> _eylem(String v, StaffMember k) async {
    final Future<bool> is_ = switch (v) {
      'kart' => kisiKartiAc(context, id: k.id).then((_) => true),
      'aktiflik' => kisiAktiflikDegistir(context, ref,
          id: k.id, ad: k.ad, aktif: !k.isActive),
      'sil' => kisiSilOnayli(context, ref, id: k.id, ad: k.ad),
      _ => Future.value(false),
    };
    if (await is_) ref.invalidate(yonetimListesiProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(yonetimListesiProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('yonetici-ekle'),
        onPressed: () async {
          final sonuc = await merkezSayfaAc<String?>(
            context,
            builder: (_) => const _YoneticiEkle(),
          );
          if (sonuc == 'ok') ref.invalidate(yonetimListesiProvider);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.yoneticiEkle),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (tumListe) => tumListe.isEmpty
            ? BosDurum(
                ikon: Icons.admin_panel_settings_outlined,
                baslik: l10n.yoneticiListeBos,
                aciklama: l10n.yoneticiListeBosAlt,
              )
            : Column(children: [
                KisiSuzgecSeridi(
                  ara: _ara,
                  durum: _durum,
                  onDegisti: (d) => setState(() => _durum = d),
                  onAra: () => setState(() {}),
                ),
                Expanded(child: Builder(builder: (context) {
              final list = kisiSuz(tumListe, _ara.text, _durum,
                  ad: (s) => s.ad, aktif: (s) => s.isActive);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(yonetimListesiProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final k = list[i];
                    return Card(
                      key: Key('yonetici-${k.id}'),
                      child: ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(k.ad),
                        subtitle: Text(rolAdi(l10n, UserRole.fromClaim(k.role))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!k.isActive)
                              Text(l10n.ortakPasif,
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.outline)),
                            PopupMenuButton<String>(
                              key: Key('yonetici-islemler-${k.id}'),
                              tooltip: l10n.ortakIslemler,
                              onSelected: (v) => _eylem(v, k),
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'kart', child: Text(l10n.kisTanilama)),
                                PopupMenuItem(
                                  value: 'aktiflik',
                                  child: Text(k.isActive
                                      ? l10n.personelPasiflestir
                                      : l10n.personelAktiflestir),
                                ),
                                PopupMenuItem(
                                  key: Key('yonetici-sil-${k.id}'),
                                  value: 'sil',
                                  child: Text(l10n.ortakSil),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
                })),
              ]),
      ),
    );
  }
}

class _YoneticiEkle extends ConsumerStatefulWidget {
  const _YoneticiEkle();

  @override
  ConsumerState<_YoneticiEkle> createState() => _YoneticiEkleState();
}

class _YoneticiEkleState extends ConsumerState<_YoneticiEkle> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _soyadCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _epostaCtrl = TextEditingController();
  String _rol = 'yonetici';
  bool _gonderiyor = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _telCtrl.dispose();
    _epostaCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _gonderiyor = true);
    try {
      await ref.read(staffApiProvider).addStaff(
            ad: adBicimle(_adCtrl.text),
            soyad: soyadBicimle(_soyadCtrl.text),
            telefon: telefonNormalle(_telCtrl.text),
            email: _epostaCtrl.text.trim(),
            role: _rol,
          );
      if (!mounted) return;
      navigator.pop('ok');
      messenger.showSnackBar(SnackBar(content: Text(l10n.yoneticiEklendi)));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
      setState(() => _gonderiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alt = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, alt + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.yoneticiEkle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              key: const Key('yonetici-rol'),
              segments: [
                ButtonSegment(
                    value: 'yonetici',
                    label: Text(rolAdi(l10n, UserRole.yonetici)),
                    icon: const Icon(Icons.manage_accounts_outlined)),
                ButtonSegment(
                    value: 'denetci',
                    label: Text(rolAdi(l10n, UserRole.denetci)),
                    icon: const Icon(Icons.fact_check_outlined)),
              ],
              selected: {_rol},
              onSelectionChanged:
                  _gonderiyor ? null : (s) => setState(() => _rol = s.first),
            ),
            const SizedBox(height: 12),
            AdSoyadAlanlari(
              adKtrl: _adCtrl,
              soyadKtrl: _soyadCtrl,
              etkin: !_gonderiyor,
              adSinir: 150,
              anahtarOneki: 'yonetici',
            ),
            const SizedBox(height: 12),
            TelefonAlani(
              ktrl: _telCtrl,
              etiket: l10n.personelTelefonOpsiyonel,
              ipucu: l10n.ortakTelefonIpucu,
              etkin: !_gonderiyor,
              zorunlu: false,
            ),
            const SizedBox(height: 12),
            EpostaAlani(
              alanAnahtari: const Key('yonetici-eposta'),
              ktrl: _epostaCtrl,
              etiket: l10n.personelEposta,
              ipucu: l10n.personelEpostaYardim,
              etkin: !_gonderiyor,
              zorunlu: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('yonetici-kaydet'),
              onPressed: _gonderiyor ? null : _kaydet,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _gonderiyor
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
