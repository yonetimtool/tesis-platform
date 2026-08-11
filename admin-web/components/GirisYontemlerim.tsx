"use client";

/**
 * (P154 / Asama 4) GIRIS YONTEMLERIM — profil sayfasinin bolumu.
 *
 * Brief: "kullanicinin sonradan yontem ekleyip cikarabilmesi".
 *
 * EKLEME `SosyalGiris` BILESENINI KULLANIR (`niyet="bagla"`): giris
 * ekranindakiyle ayni dugmeler, ayni saglayici listesi, ayni hata
 * davranisi. Ikinci bir dugme kumesi yazmak, saglayici eklendiginde
 * birini guncelleyip digerini unutmak demekti.
 *
 * SON YONTEM UYARISI SUNUCUDAN GELIR: burada "silinebilir mi" hesabi
 * YAPILMAZ. Yapsaydik kural iki yerde yasardi ve istemcideki kopya
 * (parola var mi, telefon var mi) sunucununkinden sapabilirdi. Istemci
 * dener, sunucu 409 doner, metni gosteririz.
 */
import useSWR from "swr";

import { ErrorBox, btnDanger, cardCls } from "@/components/form";
import { SosyalGiris, saglayiciEtiketi } from "@/components/SosyalGiris";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Baglanti = {
  saglayici: string;
  eposta: string | null;
  son_giris_at: string | null;
  created_at: string;
};

export function GirisYontemlerim() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Baglanti[] }>(
    "/api/auth/oauth/baglantilarim",
    jsonFetcher,
  );

  async function kaldir(saglayici: string) {
    try {
      await apiSend(`/api/auth/oauth/baglantilarim/${saglayici}`, "DELETE");
      toast.success(t("sosyalYontemKaldirildi"));
      void mutate();
    } catch (e) {
      // SUNUCU metni aynen gosterilir — "tek giris yonteminizi
      // kaldiramazsiniz" cumlesi katalogdan, kullanicinin dilinde gelir.
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const items = data?.items ?? [];

  return (
    <section className={`${cardCls} space-y-4 p-5`}>
      <h2 className="font-medium">{t("sosyalYontemlerBaslik")}</h2>
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : items.length === 0 ? (
        <p className="text-sm text-metin-muted">{t("sosyalYontemYok")}</p>
      ) : (
        <ul className="divide-y divide-slate-200">
          {items.map((b) => (
            <li
              key={b.saglayici}
              className="flex items-center justify-between gap-3 py-2.5"
            >
              <div className="min-w-0">
                <p className="text-sm font-medium">{saglayiciEtiketi(b.saglayici)}</p>
                {b.eposta ? (
                  <p className="truncate text-xs text-metin-muted">{b.eposta}</p>
                ) : null}
              </div>
              <button
                className={`${btnDanger} min-h-[44px]`}
                onClick={() => void kaldir(b.saglayici)}
              >
                {t("sosyalYontemKaldir")}
              </button>
            </li>
          ))}
        </ul>
      )}
      <SosyalGiris niyet="bagla" />
    </section>
  );
}
