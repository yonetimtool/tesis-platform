/// (P253 Asama 2) Borclandirma ENUM'lari -> cevrilmis metin. Ham kod
/// ekrana basilmaz (web `borclandirmalar/page.tsx` ile ayni esleme).
library;

import '../../../core/i18n/l10n.dart';

String kalemTipiAdi(AppLocalizations l10n, String k) => switch (k) {
      'aidat' => l10n.brcKalemAidat,
      'demirbas' => l10n.brcKalemDemirbas,
      'olaganustu' => l10n.brcKalemOlaganustu,
      'sayac' => l10n.brcKalemSayac,
      'faiz' => l10n.brcKalemFaiz,
      _ => l10n.brcKalemDiger,
    };

String dagitimAdi(AppLocalizations l10n, String d) => switch (d) {
      'esit' => l10n.brcDagitimEsit,
      'arsa_payi' => l10n.brcDagitimArsaPayi,
      'metrekare' => l10n.brcDagitimMetrekare,
      _ => l10n.brcDagitimDaireBasina,
    };

/// Atlama nedeni sunucudan KOD olarak gelir; bilinmeyen kod icin genel metin.
String atlamaNedeniAdi(AppLocalizations l10n, String neden) => switch (neden) {
      'arsa_payi_girilmemis' => l10n.brcAtlamaArsaPayi,
      'metrekare_girilmemis' => l10n.brcAtlamaMetrekare,
      'tip_varsayilani_yok' => l10n.brcAtlamaTip,
      'benzersizlik_carpismasi' => l10n.brcAtlamaCarpisma,
      // (P253 §C-4) Toplu geri almada atlananlar.
      'odenmis' => l10n.brcAtlamaOdenmis,
      'zaten_ters_kayitli' => l10n.brcAtlamaZatenTersKayitli,
      _ => l10n.brcAtlamaTutar,
    };

String odemeYontemiAdi(AppLocalizations l10n, String y) => switch (y) {
      'havale' => l10n.brcYontemHavale,
      'kart' => l10n.brcYontemKart,
      'diger' => l10n.brcYontemDiger,
      _ => l10n.brcYontemElden,
    };

/// `YYYY-MM` — donem TARIHTEN turetilir (web ile ayni: Mart tahakkuku Mart
/// donemine yazilir; ikinci bir tarih alani sorulmaz).
String donemden(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}';

/// Hedef metni: "A-12 · Ahmet YILMAZ · Eylul aidati" (bos parcalar atlanir).
String hedefMetni(Iterable<String?> parcalar) =>
    parcalar.where((p) => p != null && p.trim().isNotEmpty).join(' · ');
