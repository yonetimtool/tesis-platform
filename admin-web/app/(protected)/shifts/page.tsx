import { redirect } from "next/navigation";

/**
 * (P232 §A) `/shifts` → `/vardiya-plani` YONLENDIRMESI.
 *
 * =========================================================================
 * NEDEN SAYFA SILINMEDI, YONLENDIRMEYE DONUSTU
 * =========================================================================
 * Rotayi tamamen kaldirmak, yer imi ve eski baglantilari 404'e
 * dusururdu. Kullanicinin "vardiya" diye kaydettigi adres calismaya
 * devam etmeli — yalnizca artik DOGRU ekrani acmali.
 *
 * =========================================================================
 * SABLON KAVRAMI KALDIRILMADI
 * =========================================================================
 * Olculdu: `Shift` gercekten kullaniliyor — saat araligi + GUN TIPI +
 * VARSAYILAN KADRO tasiyor ve `/vardiya-plani`daki "Haftayi doldur"
 * dugmesi tam olarak onu tuketiyor. Kaldirmak o ozelligi de oldururdu.
 *
 * Asil kusur baskaydi: web'de sablon TANIMLANABILIYOR ama KADRO
 * ATANAMIYORDU (yalniz mobilde), yani ozelligin yarisi eksikti ve sayfa
 * BOS gorunuyordu. Sablon yonetimi artik kullanildigi yerde —
 * `/vardiya-plani` icindeki "Vardiya sablonlari" bolumunde.
 */
export default function ShiftsYonlendirme() {
  redirect("/vardiya-plani");
}
