/**
 * (P160 / Asama 5) NOKTA DURUMU — TEK TANIM.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA
 * =========================================================================
 * Ayni kural iki sayfada kullaniliyor (`/checkpoints` ve `/patrol-plans`).
 * Iki kopya tutmak, birinin duzeltilip digerinin unutulmasi demekti —
 * depoda bunun bedeli daha once olculdu (P53, numaralandirma haritalari).
 *
 * =========================================================================
 * DURUM SUNUCUDAN TURETILIR, UYDURULMAZ
 * =========================================================================
 * Panelin elinde iki gercek kaynak var ve UCUNCU bir kaynak icat
 * edilmiyor:
 *
 *   1. `GET /scans?tarih=...` — bugun HANGI nokta okutuldu.
 *      Bu olmadan "okutuldu" denemez; alarm yalniz SORUNLU durumlar icin
 *      uretilir, basarili okutma icin alarm YOKTUR.
 *   2. `GET /dashboard/live` -> `alarm_gruplari[].olaylar[].checkpoint_id`
 *      — sunucunun kendi hesapladigi gecikme/eksiklik.
 *
 * ONCELIK SIRASI VE GEREKCESI:
 *   * ATLANDI en agir: sunucu `eksik_checkpoint` diyorsa pencere kapandi
 *     ve nokta okutulmadi. Bu, "bekliyor"dan farkli bir CUMLEDIR.
 *   * GECIKTI ikinci: `gecikmis_okutma` — nokta hala okutulabilir ama
 *     zamaninda okutulmadi.
 *   * OKUTULDU ucuncu: taramada gorunuyor.
 *   * BEKLIYOR varsayilan — "henuz bir sey soyleyemiyoruz".
 *
 * ALARM OKUTMAYI EZER cunku alarm SONRADAN uretilir: bir nokta dun
 * okutulmus ama bugunku turda atlanmis olabilir. Tersini yapmak
 * (okutma alarmi ezsin) atlanmis bir noktayi yesil gostermek olurdu.
 */
import type { AlarmGrubu } from "./types";

export type NoktaDurumu = "okutuldu" | "gecikti" | "atlandi" | "bekliyor";

/** `AlarmTip` degerleri — ucun sozlesmesi (schemas.py `AlarmTip`). */
const TIP_ATLANDI = "eksik_checkpoint";
const TIP_GECIKTI = "gecikmis_okutma";

export interface DurumKaynagi {
  /** Bugun okutulan nokta kimlikleri (`GET /scans`). */
  okutulanIdler: Set<string>;
  /** Pano alarm gruplari (`GET /dashboard/live`). */
  alarmGruplari: AlarmGrubu[];
}

/**
 * Alarm gruplarindan `checkpoint_id -> tip` haritasi.
 *
 * Bir nokta iki gruba birden dusebilir (once gecikti, sonra eksik
 * sayildi); AGIR OLAN kazanir.
 */
export function alarmHaritasi(gruplar: AlarmGrubu[]): Map<string, string> {
  const harita = new Map<string, string>();
  for (const g of gruplar) {
    if (g.tip !== TIP_ATLANDI && g.tip !== TIP_GECIKTI) continue;
    for (const o of g.olaylar) {
      if (!o.checkpoint_id) continue;
      const mevcut = harita.get(o.checkpoint_id);
      // `atlandi` daha agir: bir kez yazildiysa `gecikti` ezmez.
      if (mevcut === TIP_ATLANDI) continue;
      harita.set(o.checkpoint_id, g.tip);
    }
  }
  return harita;
}

/** Tek noktanin durumu — oncelik sirasi dosya basindaki gerekcede. */
export function noktaDurumu(
  checkpointId: string,
  kaynak: DurumKaynagi,
  alarmlar?: Map<string, string>,
): NoktaDurumu {
  const harita = alarmlar ?? alarmHaritasi(kaynak.alarmGruplari);
  const alarm = harita.get(checkpointId);
  if (alarm === TIP_ATLANDI) return "atlandi";
  if (alarm === TIP_GECIKTI) return "gecikti";
  if (kaynak.okutulanIdler.has(checkpointId)) return "okutuldu";
  return "bekliyor";
}
