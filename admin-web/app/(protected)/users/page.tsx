"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  AramaAlani,
  Dugme,
  Girinti,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type RozetDurumu,
  type SayfaBoyu,
  type TabloDurumu,
} from "@/components/ui";
import { ParolaAlani } from "@/components/ParolaAlani";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { ROLE_OPTIONS as ROLES, rolAdi } from "@/lib/roles";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";
import type { UserDetail, UserListResponse, UserRole, UserRow } from "@/lib/types";

/**
 * (P160 / Asama 6) KULLANICILAR — yeni tasarim diline tasindi.
 *
 * =========================================================================
 * NE DEGISTI, NE DEGISMEDI
 * =========================================================================
 * DEGISMEYEN (kilitli kural 2): butun veri mantigi birebir korundu —
 * suzgecler (rol · durum · arama), sunucudan gelen ACILABILIR ROL kumesi,
 * duzenlenen kaydin rolunun listede tutulmasi, denetciye ozel gorev
 * penceresi, telefon normalizasyonu, parolanin opsiyonelligi, gecici kod
 * uyarisi, aktiflestir/pasiflestir ve toplu yukleme bagi.
 *
 * DEGISEN (sunum):
 *   * Form SAYFA USTUNDE ALAN ACMA yerine MODAL'da (brief).
 *   * Tablo `VeriTablosu`: siralama, kolon gorunurlugu ve SAYFA BASINA
 *     KAYIT SECIMI (10/25/50/100) BEDAVA geldi — eskiden sabit 20'ydi.
 *   * Iskelet yukleme durumu (eskiden duz "Yukleniyor..." metniydi).
 *   * Rol ve durum rozetleri: renkli DOLGU yerine kenar+metin.
 *
 * =========================================================================
 * SUNUCU TARAFLI SAYFALAMA
 * =========================================================================
 * Uc `limit`/`offset` + `meta.total` ile calisiyor, yani tablo kendi
 * dilimlemez (`sunucuTarafli`). Aksi halde 5000 kullanicili bir tesiste
 * TUM listeyi cekmek gerekirdi.
 */

/** Sayfa boyu artik kullanici secimli; bu yalniz ILK degerdir. */
const ILK_BOY: SayfaBoyu = 25;

/** Rol -> rozet durumu. Renk SINYALDIR; ad zaten metinde yazili. */
const ROL_DURUMU: Record<string, RozetDurumu> = {
  admin: "kritik",
  yonetici: "uyari",
  denetci: "bilgi",
};

const VARSAYILAN_ROL: UserRole = "security";
const ROL_DENETCI = "denetci";

interface FormState {
  ad: string;
  email: string;
  telefon: string;
  aranabilir: boolean;
  role: UserRole;
  password: string;
  // (P128) Gorev penceresi — YALNIZ `denetci` rolunde gosterilir.
  gorevBaslangic: string;
  gorevBitis: string;
}
const EMPTY: FormState = {
  ad: "",
  email: "",
  telefon: "",
  aranabilir: false,
  role: VARSAYILAN_ROL,
  password: "",
  gorevBaslangic: "",
  gorevBitis: "",
};

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

export default function UsersPage() {
  const t = useT();
  const toast = useToast();

  const [durum, setDurum] = useState<TabloDurumu>({
    sayfa: 1,
    boy: ILK_BOY,
    siraKolon: null,
    siraYonu: "artan",
  });
  const [role, setRole] = useState<string>("");
  const [aktif, setAktif] = useState<string>("");
  const [q, setQ] = useState("");

  const qs = new URLSearchParams({
    limit: String(durum.boy),
    offset: String((durum.sayfa - 1) * durum.boy),
  });
  if (role) qs.set("role", role);
  if (aktif) qs.set("is_active", aktif);
  if (q.trim()) qs.set("q", q.trim());
  const { data, error, isLoading, mutate } = useSWR<UserListResponse>(
    `/api/users?${qs.toString()}`,
    jsonFetcher,
  );

  // (P130) ACILIR LISTE SUNUCUDAN. Eskiden `ROLE_OPTIONS`in tamami
  // cizilirdi: bir site yoneticisi "Platform Admin"i SECEBILIYOR ve
  // kaydedince 403 aliyordu — sunucu dogru davraniyordu, arayuz yanlis soz
  // veriyordu. Liste artik cagiranin GERCEKTEN acabildigi kumedir.
  const { data: acilabilir } = useSWR<{ roller: UserRole[] }>(
    "/api/users/acilabilir-roller",
    jsonFetcher,
  );
  // `undefined` = HENUZ BILINMIYOR (bos kumeyle ayni sey degil): liste
  // gelene kadar secenek cizmek, gelince degisen bir form demek olurdu.
  const acilabilirRoller = acilabilir?.roller;
  const formRolleri = useMemo(
    () => (acilabilirRoller ? ROLES.filter((r) => acilabilirRoller.includes(r.value)) : []),
    [acilabilirRoller],
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // DUZENLENEN KAYDIN ROLU LISTEDE YOKSA YINE GORUNUR. Aksi halde select
  // sessizce ilk secenege duser ve kaydet, kullanicinin DOKUNMADIGI bir
  // alani degistirmek isterdi (sunucu 403 verirdi ama sebep gorunmezdi).
  const mevcutRol = ROLES.find((r) => r.value === form.role);
  const rolSecenekleri =
    mevcutRol && !formRolleri.some((r) => r.value === form.role)
      ? [mevcutRol, ...formRolleri]
      : formRolleri;

  /** Suzgec degisince ILK SAYFAYA don — 7. sayfada suzmek bos ekran verirdi. */
  function suzgec(next: { role?: string; aktif?: string; q?: string }) {
    if (next.role !== undefined) setRole(next.role);
    if (next.aktif !== undefined) setAktif(next.aktif);
    if (next.q !== undefined) setQ(next.q);
    setDurum((d) => ({ ...d, sayfa: 1 }));
  }

  function openNew() {
    setEditingId(null);
    // Varsayilan rol de acilabilir kumeden secilir; sabit "security"
    // birakmak, o rolu acamayan bir cagirana pesinen gecersiz bir form
    // vermek olurdu.
    setForm({ ...EMPTY, role: formRolleri[0]?.value ?? EMPTY.role });
    setFormErr(null);
    setOpen(true);
  }

  async function openEdit(u: UserRow) {
    setEditingId(u.id);
    // Numara listede DONMEZ (KVKK); tek-kayit detayindan cekilir.
    setForm({
      ad: u.ad,
      email: u.email,
      telefon: "",
      aranabilir: u.aranabilir ?? false,
      role: (u.role as UserRole) ?? VARSAYILAN_ROL,
      password: "",
      gorevBaslangic: u.gorev_baslangic ?? "",
      gorevBitis: u.gorev_bitis ?? "",
    });
    setFormErr(null);
    setOpen(true);
    try {
      const d = await jsonFetcher<UserDetail>(`/api/users/${u.id}`);
      setForm((f) => ({
        ...f,
        telefon: d.telefon ?? "",
        aranabilir: d.aranabilir ?? false,
      }));
    } catch {
      // Detay cekilemezse form yine acik kalir (telefon bos); kaydetmeye engel yok.
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        // PATCH: parola yalniz doluysa gonderilir (bossa degismez).
        const body: Record<string, unknown> = {
          ad: form.ad,
          email: form.email || null,
          telefon: telefonNormalle(form.telefon) || null,
          aranabilir: form.aranabilir,
          role: form.role,
          // BOS = "pencere yok" (acik null); alani hic gondermemek
          // "degistirme" demek olurdu ve gorev IPTALI yapilamazdi.
          gorev_baslangic: form.gorevBaslangic || null,
          gorev_bitis: form.gorevBitis || null,
        };
        if (form.password) body.password = form.password;
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
      } else {
        // Telefon = global benzersiz giris anahtari (zorunlu). E-posta opsiyonel.
        // Parola bossa backend TEK SEFERLIK gecici kod uretir (temp_code).
        const body: Record<string, unknown> = {
          ad: form.ad,
          telefon: telefonNormalle(form.telefon),
          aranabilir: form.aranabilir,
          role: form.role,
        };
        if (form.gorevBaslangic) body.gorev_baslangic = form.gorevBaslangic;
        if (form.gorevBitis) body.gorev_bitis = form.gorevBitis;
        if (form.email) body.email = form.email;
        if (form.password) body.password = form.password;
        const created = await apiSend<{ temp_code?: string | null }>(
          "/api/users",
          "POST",
          body,
        );
        if (created?.temp_code) {
          window.alert(t("kullaniciGeciciKod", { kod: created.temp_code }));
        }
      }
      setOpen(false);
      mutate();
      toast.success(editingId ? t("kullaniciGuncellendi") : t("kullaniciOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(
        /email|e-posta|telefon|zaten kayitli|conflict/i.test(m)
          ? t("kullaniciZatenKayitli")
          : m,
      );
    } finally {
      setSaving(false);
    }
  }

  async function setActive(u: UserRow, active: boolean) {
    try {
      await apiSend(`/api/users/${u.id}`, "PATCH", { is_active: active });
      mutate();
      toast.success(active ? t("kullaniciAktiflestirildi") : t("kullaniciPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  const kolonlar: Kolon<UserRow>[] = useMemo(
    () => [
      {
        id: "ad",
        baslik: t("ortakAd"),
        hucre: (u) => u.ad,
        // Siralama SUNUCU TARAFLI kipte istemcide yapilmaz; uc bugun
        // `sort` parametresi almiyor, bu yuzden kolonlar siralanabilir
        // ISARETLENMEDI. Yanlis calisan bir ok gostermektense hic
        // gostermemek dogru.
        gizlenebilir: false,
      },
      { id: "email", baslik: t("girisEposta"), hucre: (u) => u.email },
      {
        id: "aranabilir",
        baslik: t("kullaniciAranabilir"),
        hucre: (u) => (u.aranabilir ? t("ortakEvet") : "—"),
        darEkrandaGizle: true,
      },
      {
        id: "rol",
        baslik: t("ortakRol"),
        hucre: (u) => (
          <Rozet durum={ROL_DURUMU[u.role] ?? DURUM_NOTR} nokta>
            {rolAdi(t, u.role)}
          </Rozet>
        ),
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (u) => (
          <Rozet durum={u.is_active ? DURUM_OLUMLU : DURUM_NOTR}>
            {u.is_active ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (u) => (
          <div className="flex justify-end gap-2">
            <Dugme boy="kucuk" onClick={() => void openEdit(u)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme
              boy="kucuk"
              onClick={() => void setActive(u, !u.is_active)}
            >
              {u.is_active ? t("ortakPasiflestir") : t("ortakAktiflestir")}
            </Dugme>
          </div>
        ),
      },
    ],
    // `t` disindaki bagimliliklar kararli; `openEdit`/`setActive` her
    // cizimde yeniden kurulsa da kolon tanimi yalniz metin tasiyor.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukKullanicilar")}
        </h1>
        <div className="flex flex-wrap gap-2">
          {/* (P154 / Asama 5) EXCEL ILE TOPLU SAKIN YUKLEME — brief:
              "Asama 8'deki import framework'u kullanacak, AYRI YUKLEME
              KODU YAZMA". Bu yuzden burada bir yukleme formu YOK,
              catiya yonlendirme var. */}
          <Link href="/ice-aktarim?tur=kisi">
            <Dugme boy="kucuk">{t("kullaniciTopluYukle")}</Dugme>
          </Link>
          <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
            {t("kullaniciYeni")}
          </Dugme>
        </div>
      </div>

      {/* HATA DURUMU: liste cekilemezse BOS TABLO degil, sebep + tekrar. */}
      {error ? (
        <HataDurumu mesaj={error.message} onTekrar={() => void mutate()} />
      ) : (
        <VeriTablosu<UserRow>
          kolonlar={kolonlar}
          satirlar={data?.items ?? []}
          satirId={(u) => u.id}
          yukleniyor={isLoading && !data}
          bosBaslik={t("kullaniciYok")}
          bosAciklama={t("kullaniciYokAlt")}
          sunucuTarafli
          toplam={data?.meta.total ?? 0}
          durum={durum}
          onDurumDegisti={setDurum}
          araclar={
            <div className="flex flex-wrap items-end gap-3">
              <div className="w-44">
                <AlanSarmal etiket={t("ortakRol")}>
                  {(b) => (
                    <Secim
                      {...b}
                      value={role}
                      onChange={(e) => suzgec({ role: e.target.value })}
                    >
                      <option value="">{t("ortakTumu")}</option>
                      {ROLES.map((r) => (
                        <option key={r.value} value={r.value}>
                          {t(r.anahtar)}
                        </option>
                      ))}
                    </Secim>
                  )}
                </AlanSarmal>
              </div>
              <div className="w-44">
                <AlanSarmal etiket={t("ortakDurum")}>
                  {(b) => (
                    <Secim
                      {...b}
                      value={aktif}
                      onChange={(e) => suzgec({ aktif: e.target.value })}
                    >
                      <option value="">{t("ortakTumu")}</option>
                      <option value="true">{t("ortakAktif")}</option>
                      <option value="false">{t("ortakPasif")}</option>
                    </Secim>
                  )}
                </AlanSarmal>
              </div>
              <div className="min-w-[220px] grow">
                <AramaAlani
                  deger={q}
                  onDegisim={(v) => suzgec({ q: v })}
                  etiket={t("kullaniciArama")}
                  yerTutucu={t("kullaniciAramaIpucu")}
                  temizleEtiketi={t("ortakKapat")}
                />
              </div>
            </div>
          }
        />
      )}

      {/* FORM ARTIK MODALDA (brief: "sayfa ustunde alan acma deseni
          kaldirilacak"). Odak tuzagi, ESC ve kapanista odagin geri
          donmesi `Modal`da. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("kullaniciDuzenle") : t("kullaniciYeni")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="kullanici-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        {/* `form` ID ile alttaki dugmeye baglandi: eylemler modalin
            SABIT altinda duruyor ve govdeyle birlikte kaymiyor. */}
        <form id="kullanici-form" onSubmit={save} className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("ortakAd")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            )}
          </AlanSarmal>

          <AlanSarmal
            etiket={t("kullaniciEpostaOpsiyonel")}
            ipucu={t("kullaniciEpostaIpucu")}
          >
            {(b) => (
              <Alan
                {...b}
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            )}
          </AlanSarmal>

          <AlanSarmal
            etiket={t("kullaniciTelefon")}
            ipucu={t("kullaniciTelefonIpucu")}
            zorunlu
          >
            {(b) => (
              <Alan
                {...b}
                value={telefonGiris(form.telefon)}
                // (P123) TEK bicimlendirici — bkz. lib/telefon.ts.
                onChange={(e) =>
                  setForm({ ...form, telefon: telefonGiris(e.target.value) })
                }
                placeholder={t("kullaniciTelefonOrnek")}
                required
              />
            )}
          </AlanSarmal>

          <AlanSarmal
            etiket={t("kullaniciAranabilir")}
            ipucu={t("kullaniciAranabilirIpucu")}
          >
            {(b) => (
              <label
                className="flex h-11 items-center gap-2"
                style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
              >
                <input
                  {...b}
                  type="checkbox"
                  checked={form.aranabilir}
                  onChange={(e) => setForm({ ...form, aranabilir: e.target.checked })}
                />
                {t("kullaniciAranabilirOnay")}
              </label>
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("ortakRol")}>
            {(b) => (
              <Secim
                {...b}
                value={form.role}
                disabled={acilabilirRoller === undefined}
                onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}
              >
                {rolSecenekleri.map((r) => (
                  <option key={r.value} value={r.value}>
                    {t(r.anahtar)}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>

          {form.role === ROL_DENETCI ? (
            // (P128) YALNIZ DENETCIDE GORUNUR: gorev penceresi bugun
            // baska bir rolde anlam tasimiyor ve her role gostermek,
            // doldurulunca hicbir sey yapmayan bir alan demekti.
            <>
              <AlanSarmal
                etiket={t("kullaniciGorevBaslangic")}
                ipucu={t("kullaniciGorevIpucu")}
              >
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    value={form.gorevBaslangic}
                    onChange={(e) =>
                      setForm({ ...form, gorevBaslangic: e.target.value })
                    }
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("kullaniciGorevBitis")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    value={form.gorevBitis}
                    onChange={(e) => setForm({ ...form, gorevBitis: e.target.value })}
                  />
                )}
              </AlanSarmal>
            </>
          ) : null}

          <AlanSarmal
            etiket={editingId ? t("kullaniciYeniParola") : t("kullaniciParolaOpsiyonel")}
            ipucu={editingId ? t("kullaniciEnAz8") : t("kullaniciParolaBosYeni")}
          >
            {(b) => (
              // `ParolaAlani` ORTAK ILKEL ve `style` KABUL ETMIYOR
              // (bilincli: gorunumu cagirandan almiyor). Yeni yuzeye
              // uydurmak icin GIRINTILI kapsayiciya konuyor; girdi
              // saydam kaliyor. Bilesenin kendisine dokunulmadi —
              // alti sayfa daha onu kullaniyor.
              <Girinti className="flex items-center px-1">
                <ParolaAlani
                  {...b}
                  className="h-11 w-full bg-transparent px-2 outline-none"
                    value={form.password}
                  onChange={(v) => setForm({ ...form, password: v })}
                  minLength={8}
                  placeholder={
                    editingId
                      ? t("kullaniciParolaBosDuzenle")
                      : t("kullaniciParolaBosKisa")
                  }
                />
              </Girinti>
            )}
          </AlanSarmal>

          {formErr && (
            <p
              role="alert"
              className="sm:col-span-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formErr}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
