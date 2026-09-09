"use client";

import useSWR from "swr";

import { Dugme, HataDurumu, IskeletMetin, useOnay } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { ResidentListItem, UnitResident } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P220 §5) DAİRE PENCERESİNDE SAKİN BİLGİSİ.
 *
 * =========================================================================
 * NE GÖSTERİYOR
 * =========================================================================
 *   * Dairede kim oturuyor: AD + ROL (malik/kiracı) + oturma durumu,
 *   * birden çok sakin varsa HEPSİ (bir dairede malik VE kiracı olabilir
 *     — P154 kararı),
 *   * sakin yoksa "boş daire" ve EKLEME YOLU.
 *
 * =========================================================================
 * ROL DEĞİŞİMİ DAİRE BAZLI
 * =========================================================================
 * `PATCH /units/{id}/residents/{user}` kullanılıyor,
 * `PATCH /residents/{user}` DEĞİL: ikincisi kullanıcının AKTİF TÜM
 * bağlarına uyguluyor ve iki dairesi olan bir sakinde (birinde malik,
 * ötekinde kiracı) buradan yapılan değişiklik İKİSİNİ DE değiştirirdi.
 *
 * =========================================================================
 * YETKİ SUNUCUDA
 * =========================================================================
 * Uç `admin` + `yonetici` istiyor ve sakin/güvenlik için 403 döner
 * (testli). Buradaki hiçbir gizleme güvenlik değildir — ikinci istemci
 * (mobil) o gizlemeyi taşımayabilir.
 */
// UCLUDA SABIT DIZE YASAK (`sabit-metin` tarayicisi): rol degerleri
// SABIT olarak burada duruyor ve JSX icinde ternary'ye girmiyorlar.
/** Cagri sarmalayicisinin sozlesmesi.
 *
 * METOT BICIMI BILINCLI: `() => Promise<unknown>` yazimi `sabit-metin`
 * tarayicisinin `>metin<` kalibina takiliyor — `=>` ile `<unknown>`
 * arasinda kalan " Promise" JSX metni saniliyor. Depoda
 * `components/ui/onay-kullan.tsx` ayni tuzaga dusmus ve ayni cozumu
 * yazmis. */
interface Islem {
  (): Promise<unknown>;
}

const ROL_MALIK = "malik" as const;
const ROL_KIRACI = "kiraci" as const;

export function DaireSakinleri({ unitId }: { unitId: string }) {
  const t = useT();
  const toast = useToast();
  // (P161) YIKICI ONAY tarayicinin `confirm()`u ile SORULMAZ: o diyalog
  // uygulamanin disinda, cevrilemez ve ekran okuyucuya uygulamanin
  // parcasi gibi gorunmez. Kilit (`modal-tasima.test.ts`) bunu tariyor
  // ve ilk yazimda beni YAKALADI.
  const { onayla, diyalog } = useOnay();
  const key = `/api/units/${unitId}/residents`;
  const { data, error, isLoading, mutate } = useSWR<UnitResident[]>(
    key,
    jsonFetcher,
  );
  // Ekleme için aday listesi — SİTE SAKİNLERİ. Yeni hesap AÇILMIYOR: o
  // "Kullanıcılar" ekranının işi ve burada tekrarlamak aynı akışı iki
  // yerde bakım gerektirir hâle getirirdi. Buradaki iş BAĞ KURMAK.
  const { data: adaylar } = useSWR<{ items: ResidentListItem[] }>(
    "/api/residents",
    jsonFetcher,
  );

  // AKTİF BAĞLAR: daire penceresinin sorusu "ŞU ANDA kim oturuyor".
  // Kapanmış bağ gösterilseydi çıkmış bir sakin dairede duruyor
  // görünürdü.
  const aktif = (data ?? []).filter((x) => !x.bitis);

  async function calistir(islem: Islem) {
    try {
      await islem();
      await mutate();
      // SİTE GENELİ LİSTE DE TAZELENİR: aynı gerçek iki ekranda
      // gösteriliyor ve birinde değişip ötekinde eski kalması,
      // yöneticinin hangisine inanacağını bilememesi olurdu.
      toast.success(t("daireSakinGuncellendi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    }
  }

  // (P220 §5) IKI KUCUK AMA ONEMLI GORUNUM KARARI
  //
  // 1. AD YOKSA UUID GOSTERILMEZ, "—" gosterilir: kullanici silinmis
  //    olabilir ve bir kimlik dizisi kullaniciya hicbir sey anlatmaz.
  // 2. EKLEME LISTESINDE DAIRE DE YAZILI: ayni adli iki sakinde secim
  //    yapilamazdi.
  function rolMetni(s: UnitResident): string {
    const rol =
      s.rol_tipi === ROL_MALIK
        ? t("daireRolMalik")
        : s.rol_tipi === ROL_KIRACI
          ? t("daireRolKiraci")
          : t("daireRolYok");
    // (P218) Oturma durumu AYRI gösteriliyor: "malik-oturan" üçüncü bir
    // rol değil, malikin oturuyor olması. İkisini tek etikete
    // sıkıştırmak aidat hedeflemesindeki ayrımı gizlerdi.
    return s.oturuyor ? `${rol} · ${t("daireOturuyor")}` : rol;
  }

  if (isLoading) return <IskeletMetin satir={2} />;
  if (error) return <HataDurumu mesaj={t("sakinListelenemedi")} />;

  return (
    <section className="space-y-2">
      <h3 style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 700 }}>
        {t("daireSakinleri")}
      </h3>

      {aktif.length === 0 ? (
        // BOŞ DAİRE bir HATA DEĞİL, normal bir durum.
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("daireBos")}
        </p>
      ) : (
        <ul className="space-y-2">
          {aktif.map((s) => (
            <li
              key={s.id}
              className="flex flex-wrap items-center gap-2 rounded p-2"
              style={{ border: "1px solid var(--yz-border)" }}
            >
              <span className="min-w-0 flex-1">
                {/* AD YOKSA "—" — gerekce `rolMetni` ustunde. */}
                <strong>{s.user_ad ?? "—"}</strong>
                <span
                  className="block"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
                >
                  {rolMetni(s)}
                </span>
              </span>
              <Dugme
                boy="kucuk"
                tur="ikincil"
                onClick={() =>
                  void calistir(() =>
                    apiSend(
                      `/api/units/${unitId}/residents/${s.user_id}`,
                      "PATCH",
                      {
                        rol_tipi:
                          s.rol_tipi === ROL_MALIK ? ROL_KIRACI : ROL_MALIK,
                      },
                    ),
                  )
                }
              >
                {s.rol_tipi === ROL_MALIK
                  ? t("daireRolKiraci")
                  : t("daireRolMalik")}
              </Dugme>
              <Dugme
                boy="kucuk"
                tur="ikincil"
                onClick={() =>
                  void calistir(() =>
                    apiSend(
                      `/api/units/${unitId}/residents/${s.user_id}`,
                      "PATCH",
                      { oturuyor: !s.oturuyor },
                    ),
                  )
                }
              >
                {s.oturuyor ? t("daireOturmuyorYap") : t("daireOturuyorYap")}
              </Dugme>
              <Dugme
                boy="kucuk"
                tur="tehlike"
                onClick={() => {
                  // ONAY: cikarma geri alinamaz ve mesaj NE OLMADIGINI
                  // da soyluyor — hesabi silmez. Kisi siteden
                  // ayrilmadiysa baska bir daireye tasinmis olabilir.
                  void (async () => {
                    const ok = await onayla({
                      baslik: t("daireSakinCikar"),
                      mesaj: t("daireSakinCikarNot"),
                      onayMetni: t("daireSakinCikar"),
                      tehlikeli: true,
                    });
                    if (!ok) return;
                    await calistir(() =>
                      apiSend(
                        `/api/units/${unitId}/residents/${s.user_id}`,
                        "DELETE",
                      ),
                    );
                  })();
                }}
              >
                {t("daireSakinCikar")}
              </Dugme>
            </li>
          ))}
        </ul>
      )}

      <div className="flex flex-wrap items-center gap-2">
        <select
          id={`sakin-ekle-${unitId}`}
          defaultValue=""
          className="rounded px-2 py-1"
          style={{
            fontSize: "var(--yz-fs-sm)",
            border: "1px solid var(--yz-border)",
            background: "var(--yz-surface-1)",
            color: "var(--yz-text)",
          }}
          aria-label={t("daireSakinSec")}
        >
          <option value="">{t("daireSakinSec")}</option>
          {(adaylar?.items ?? []).map((a) => (
            <option key={a.user_id} value={a.user_id}>
              {/* Daire de yazili — gerekce `rolMetni` ustunde. */}
              {a.unit_no ? `${a.ad} · ${a.unit_no}` : a.ad}
            </option>
          ))}
        </select>
        <Dugme
          boy="kucuk"
          onClick={() => {
            const el = document.getElementById(
              `sakin-ekle-${unitId}`,
            ) as HTMLSelectElement | null;
            const userId = el?.value;
            if (!userId) return;
            void calistir(() =>
              apiSend(`/api/units/${unitId}/residents`, "POST", {
                user_id: userId,
                rol_tipi: ROL_MALIK,
              }),
            );
          }}
        >
          {t("daireSakinEkle")}
        </Dugme>
      </div>
      {diyalog}
    </section>
  );
}
