import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/src/core/girdi_siniri.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../../../routing/push_yonlendirme.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/arama_api.dart';
import '../../../core/ui/bos_durum.dart';

/// (P230 §3) MOBIL GENEL ARAMA.
///
/// =========================================================================
/// NEDEN GEREKLI
/// =========================================================================
/// Web'de ustte bir arama kutusu var ve kullanici "bulamadigi bir yere
/// oradan gidebiliyor"; mobilde YOKTU. Menuyu ezbere bilmeyen kullanici
/// icin tek yol ekran ekran gezmekti.
///
/// =========================================================================
/// HEDEF ROTALARI — KAYNAK BASINA
/// =========================================================================
/// Sunucu 17 kaynak dondurebiliyor ama mobilde hepsinin EKRANI YOK.
/// Ekrani olmayan kaynak sonuc listesinde GOSTERILIR ama dokunma
/// kapatilir: sonucu gizlemek "kayit yok" izlenimi verirdi ki bu YANLIS
/// olurdu — kayit var, mobilde gosterilecek ekran yok.
const _hedef = <String, String>{
  'kisi': AppRoutes.sakinler,
  'daire': AppRoutes.daireTanimlari,
  'blok': AppRoutes.binaDuzenleme,
  'gorev': AppRoutes.tasks,
  'duyuru': AppRoutes.announcements,
  'talep': AppRoutes.complaints,
  'demirbas': AppRoutes.assets,
  'etkinlik': AppRoutes.etkinlik,
  'kamera': AppRoutes.kameralar,
  'nokta': AppRoutes.checkpoints,
  'plan': AppRoutes.patrolPlans,
  'vardiya': AppRoutes.vardiyaPlani,
};

/// (P247 §2) Sonucun hedefi AKTIF ROLE gore suzulur. Sunucu sonuclari rol
/// kapisindan gecirir (sakin modunda yalniz sakin kaynaklari) ama hedef
/// tablosu yonetim ekranlarini gosteriyordu: sakinin KENDI talebi
/// `complaints`e (onun menusunde yok) goturuluyordu — P217'nin push icin
/// duzelttigi kusurun aynisi. Erisilemeyen hedefte dokunma kapanir.
String? aramaHedefi(String kaynak, UserRole? rol) {
  final ham = kaynak == 'talep' && rol == UserRole.resident
      ? AppRoutes.sikayetlerim
      : _hedef[kaynak];
  if (ham == null || rol == null) return ham;
  return rotaErisilebilir(ham, rol) ? ham : null;
}

/// TUSLAMA BASINA ISTEK ATILMAZ: her harf bir tam metin taramasi demekti
/// (17 kaynak x LIKE). Web'deki gecikmeyle AYNI deger.
const _gecikme = Duration(milliseconds: 300);

class AramaScreen extends ConsumerStatefulWidget {
  const AramaScreen({super.key});

  @override
  ConsumerState<AramaScreen> createState() => _AramaScreenState();
}

class _AramaScreenState extends ConsumerState<AramaScreen> {
  final _ctrl = TextEditingController();
  Timer? _zamanlayici;
  CancelToken? _iptal;
  List<AramaVurusu>? _sonuc;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _iptal?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _degisti(String v) {
    _zamanlayici?.cancel();
    // SUNUCU EN AZ IKI KARAKTER ISTIYOR (tek harf butun tesisi tarar ve
    // kullaniciya da bir sey anlatmaz). Istemci de ayni esigi uygular ki
    // her tek harfte bosuna bir 422 almayalim.
    if (v.trim().length < 2) {
      setState(() {
        _sonuc = null;
        _hata = null;
        _yukleniyor = false;
      });
      return;
    }
    _zamanlayici = Timer(_gecikme, () => _ara(v.trim()));
  }

  Future<void> _ara(String q) async {
    // ONCEKI ISTEK IPTAL EDILIR: yavas bir yanit, sonradan yazilan daha
    // dar bir aramanin sonucunu EZEBILIRDI (yaris kosulu).
    _iptal?.cancel();
    final iptal = CancelToken();
    _iptal = iptal;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final v = await ref.read(aramaApiProvider).ara(q, iptal: iptal);
      if (!mounted || iptal.isCancelled) return;
      setState(() {
        _sonuc = v;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hata = context.l10n.aramaBasarisiz;
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aramaBaslik)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('arama-alani'),
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.arama), // sunucu: GET /arama ?q
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.aramaIpucu,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _degisti,
            ),
          ),
          if (_yukleniyor) const LinearProgressIndicator(),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_hata!, key: const Key('arama-hata')),
            ),
          Expanded(child: _govde(l10n)),
        ],
      ),
    );
  }

  Widget _govde(dynamic l10n) {
    final sonuc = _sonuc;
    if (sonuc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.aramaEnAzIkiHarf, textAlign: TextAlign.center),
        ),
      );
    }
    if (sonuc.isEmpty) {
      // "BULUNAMADI" ACIKCA SOYLENIR: bos bir liste, kullaniciya
      // aramanin CALISMADIGI izlenimi verirdi.
      return BosDurum(
        key: const Key('arama-bos'),
        ikon: Icons.search_off_outlined,
        baslik: l10n.aramaSonucYok,
        aciklama: l10n.aramaSonucYokAlt,
      );
    }
    return ListView.separated(
      itemCount: sonuc.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final v = sonuc[i];
        final rota = aramaHedefi(
          v.kaynak,
          ref.read(currentUserRoleProvider).value,
        );
        return ListTile(
          key: Key('arama-sonuc-${v.id}'),
          title: Text(v.baslik),
          subtitle: Text(
            [aramaKaynakAdi(l10n, v.kaynak), if (v.ayrinti != null) v.ayrinti!]
                .join(' · '),
          ),
          trailing: rota == null ? null : const Icon(Icons.chevron_right),
          enabled: rota != null,
          onTap: rota == null ? null : () => context.push(rota),
        );
      },
    );
  }
}

/// Kaynak kimligi -> gorunen ad. Sunucu KIMLIK doner, metin DEGIL
/// (cevrilebilirlik: aynı sonuç yedi dilde farklı yazılır).
String aramaKaynakAdi(dynamic l10n, String kaynak) => switch (kaynak) {
  'kisi' => l10n.aramaKaynakKisi as String,
  'daire' => l10n.aramaKaynakDaire as String,
  'blok' => l10n.aramaKaynakBlok as String,
  'firma' => l10n.aramaKaynakFirma as String,
  'gorev' => l10n.aramaKaynakGorev as String,
  'duyuru' => l10n.aramaKaynakDuyuru as String,
  'talep' => l10n.aramaKaynakTalep as String,
  'finans' => l10n.aramaKaynakFinans as String,
  'demirbas' => l10n.aramaKaynakDemirbas as String,
  'etkinlik' => l10n.aramaKaynakEtkinlik as String,
  'arac' => l10n.aramaKaynakArac as String,
  'nokta' => l10n.aramaKaynakNokta as String,
  'kamera' => l10n.aramaKaynakKamera as String,
  'plan' => l10n.aramaKaynakPlan as String,
  'vardiya' => l10n.aramaKaynakVardiya as String,
  'icra' => l10n.aramaKaynakIcra as String,
  'sayac' => l10n.aramaKaynakSayac as String,
  _ => kaynak,
};
