"use client";

/**
 * TARAYICI TARAFI API ISTEMCISI.
 *
 * =========================================================================
 * JETON `localStorage`DA — ve bunun sinirlarini biliyoruz
 * =========================================================================
 * Dukkan jetonu 30 gun yasiyor (kimlik.py: pazar yeri seyrek kullanilir;
 * her ziyarette OTP istemek kullaniciyi akisin basinda kaybetmek olurdu).
 *
 * `localStorage` XSS'e aciktir. httpOnly cerez daha guvenli olurdu ama
 * bu turda kurulmadi ve bunu SOYLEMEK, sessizce "guvenli" varsaymaktan
 * iyidir. Panelin sundugu yuzey dar (isletme profili) ve para/odeme YOK;
 * risk kabul edilebilir gorunuyor. Odeme geldiginde (V2) jeton tasima
 * yontemi YENIDEN degerlendirilmeli — bu, kararlar belgesine yazili bir
 * acik madde.
 */
const ANAHTAR = "dukkan.jeton";

export function jetonAl(): string | null {
  try {
    return localStorage.getItem(ANAHTAR);
  } catch {
    return null;
  }
}

export function jetonYaz(j: string): void {
  try {
    localStorage.setItem(ANAHTAR, j);
  } catch {
    /* gizli sekme / depolama kapali: oturum yalniz bu sayfa icin yasar */
  }
}

export function jetonSil(): void {
  try {
    localStorage.removeItem(ANAHTAR);
  } catch {
    /* yoksay */
  }
}

export class ApiHatasi extends Error {
  kod: string;
  durum: number;
  constructor(durum: number, kod: string, mesaj: string) {
    super(mesaj);
    this.kod = kod;
    this.durum = durum;
  }
}

/**
 * BFF'e istek atar. Hata govdesi OLDUGU GIBI yukselir.
 *
 * Backend `basvuru_eksik:kategori,hizmet_alani` gibi EYLEME DONUK hata
 * kodlari donuyor; bunlari "bir hata olustu"ya cevirmek kullaniciyi ne
 * yapacagini bilmez halde birakirdi (P175'te olculen kusur).
 */
export async function api<T>(
  yol: string,
  secenek: { metot?: string; govde?: unknown } = {},
): Promise<T> {
  const jeton = jetonAl();
  const yanit = await fetch(`/api${yol}`, {
    method: secenek.metot ?? "GET",
    headers: {
      ...(secenek.govde ? { "content-type": "application/json" } : {}),
      ...(jeton ? { authorization: `Bearer ${jeton}` } : {}),
    },
    body: secenek.govde ? JSON.stringify(secenek.govde) : undefined,
  });

  const metin = await yanit.text();
  const veri = metin ? JSON.parse(metin) : null;
  if (!yanit.ok) {
    const h = veri?.error ?? {};
    throw new ApiHatasi(
      yanit.status,
      h.code ?? "bilinmeyen",
      h.message ?? "İşlem tamamlanamadı.",
    );
  }
  return veri as T;
}

/** Backend'in eyleme donuk hata kodunu KULLANICI METNINE cevirir. */
export function hataMetni(h: unknown): string {
  if (!(h instanceof ApiHatasi)) return "Beklenmeyen bir hata oluştu.";
  const k = h.kod;
  if (k.startsWith("basvuru_eksik:")) {
    const eksik = k.split(":")[1].split(",");
    const ad: Record<string, string> = {
      kategori: "en az bir hizmet kategorisi",
      hizmet_alani: "en az bir hizmet bölgesi",
      telefon_dogrulama: "işletme telefonu doğrulaması",
    };
    return `Başvuru için eksik: ${eksik.map((e) => ad[e] ?? e).join(", ")}.`;
  }
  if (k.startsWith("kategori_bulunamadi:")) {
    return `Şu kategoriler bulunamadı: ${k.split(":")[1]}`;
  }
  const sozluk: Record<string, string> = {
    // --- SMS GONDERIM (503) ---
    // Kullanici NE OLDUGUNU ve NE YAPACAGINI anlamali. "Bir hata olustu"
    // demek, gelmeyecek bir kodu beklemesine yol acardi.
    //
    // Uc ucunu de AYRI yaziyoruz cunku kullanicinin yapacagi sey farkli:
    //   baslik_yok    -> beklemekten baska sey yok, alternatif kanal sun
    //   basarisiz     -> tekrar denemek MANTIKLI (gecici)
    //   saglayici_yok -> yapilandirma eksik; tekrar denemek ise yaramaz
    sms_baslik_yok:
      "SMS gönderimi henüz açılmadı. Onay sürecimiz sürüyor; " +
      "bu arada bize ulaşarak hesabınızı açtırabilirsiniz.",
    sms_basarisiz:
      "Kod gönderilemedi. Birkaç dakika sonra tekrar deneyin.",
    sms_saglayici_yok:
      "SMS servisi şu anda kullanılamıyor. Lütfen bizimle iletişime geçin.",
    kod_hatali: "Kod hatalı.",
    kod_suresi_doldu: "Kodun süresi doldu, yeni kod isteyin.",
    kod_kullanilmis: "Bu kod zaten kullanıldı.",
    kod_bulunamadi: "Önce kod isteyin.",
    cok_fazla_deneme: "Çok fazla hatalı deneme. Yeni kod isteyin.",
    kod_istegi_cok_sik: "Çok sık kod istendi. Bir süre sonra tekrar deneyin.",
    telefon_bicimi_gecersiz: "Telefon numarası geçersiz.",
    telefon_gerekli: "Yönetiyor hesabınızda telefon kayıtlı değil. Telefonla giriş yapın.",
    kimlik_gerekli: "Oturum açmanız gerekiyor.",
    jeton_suresi_doldu: "Oturumunuzun süresi doldu, tekrar giriş yapın.",
    isletme_size_ait_degil: "Bu işletme size ait değil.",
    isletme_zaten_onayli: "İşletme zaten onaylı.",
    isletme_askida: "İşletme askıya alınmış.",
    telefon_dogrulanmamis: "İşletme telefonu doğrulanmamış.",
    gerekce_zorunlu: "Gerekçe yazmanız gerekiyor.",
    guncellenecek_alan_yok: "Değiştirilen bir alan yok.",
    mahalle_bulunamadi: "Seçilen mahalle bulunamadı.",
    vergi_no_bicimi_gecersiz: "Vergi/TC numarası 10 veya 11 hane olmalı.",
    backend_erisilemedi: "Servise ulaşılamadı. Bağlantınızı kontrol edin.",
  };
  return sozluk[k] ?? h.message;
}
