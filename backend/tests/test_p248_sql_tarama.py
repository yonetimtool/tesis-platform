"""(P248 §3b) HAM SQL TARAMASI — sorgu METNINE deger birlestirme KILIDI.

===========================================================================
NEDEN
===========================================================================
SQL enjeksiyonuna dogru savunma PARAMETRELI sorgudur (`:ad` baglama
degiskeni). "1=1", "OR", "--" gibi kaliplari yasaklamak hem atlatilir hem
masum metni bozar ("Or-Tek Ltd" ya da "1=1 kampanyasi" diye bir duyuru).
Bu yuzden kalip suzgeci YOK; bunun yerine sorgu METNININ nasil kuruldugu
denetlenir.

===========================================================================
NE TARANIR
===========================================================================
`app/` altindaki her `text(...)`, `exec_driver_sql(...)`, `.execute(...)`
ve `literal_column(...)` cagrisi. Ilk argumani
  * f-string,
  * `.format(...)` cagrisi,
  * `+` / `%` ile kurulan ifade,
  * ya da AYNI fonksiyonda yukaridakilerden biriyle atanmis bir DEGISKEN
ise "dinamik SQL" sayilir ve ICINE KONAN HER IFADE (f-string alani,
format argumani) raporlanir.

Dinamik SQL'in kendisi yasak DEGIL: tablo/kolon adi ve ORDER BY gibi
TANIMLAYICILAR baglama degiskeni olamaz. Kural: araya giren her ifade
kodda SABIT bir beyaz listeden gelmeli (sozluk anahtari, sabit parca
listesi, `:param` iceren kosul parcasi). Asagidaki `IZINLI` her birini
dosya + fonksiyon + ifade metniyle ve GEREKCESIYLE listeler. Yeni bir
dinamik SQL ifadesi eklenirse test KIRMIZI olur ve inceleme ister.

Kapsam disi: `migrations/` (istek girdisi almaz; DDL sabitlerle kurulur).
"""
from __future__ import annotations

import ast
from pathlib import Path

APP = Path(__file__).resolve().parents[1] / "app"

HEDEF_CAGRILAR = {"text", "exec_driver_sql", "execute", "literal_column",
                  "executemany"}

#: (dosya, fonksiyon, araya giren ifade) -> gerekce.
#: Ifade metni `ast.unparse` ciktisidir.
IZINLI: dict[tuple[str, str, str], str] = {
    ('bakim_hatirlatma_isi.py', 'tum_tenantlar_icin', 'KADEME_DAMGA[kademe]'):
        'kolon adi sabit sozlukten; kademe kod ici sabit',
    ('ceviri_api.py', 'ceviri_isaretle_ve_kuyrukla', 't.ceviri_tablo'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_api.py', 'ceviri_isaretle_ve_kuyrukla', 't.fk_kolon'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_api.py', 'ceviriler_getir', 't.ceviri_tablo'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_api.py', 'ceviriler_getir', 't.fk_kolon'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_ceviriler_oku', 't.ceviri_tablo'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_ceviriler_oku', 't.fk_kolon'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_kaynak_oku', 'kolonlar'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_kaynak_oku', 't.kaynak_tablo'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_yaz', 't.ceviri_tablo'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('ceviri_service.py', '_yaz', 't.fk_kolon'):
        'ceviri.py KAYITLAR sabit tablosu (CeviriKaydi); istek girdisi degil',
    ('dukkan/arama.py', 'isletme_ara', 'nere'):
        "sabit kosul parcalari (' AND '); degerler :param",
    ('dukkan/arama.py', 'isletme_ara', 'sira'):
        'ORDER BY sabit sozlukten; anahtar Query pattern ^(puan|yeni|ad)$',
    ('dukkan/arama.py', 'isletme_profil', '_GORUNUR'):
        'modul sabiti (gorunurluk kosulu)',
    ('dukkan/arama.py', 'seo_sayfa', '_GORUNUR'):
        'modul sabiti (gorunurluk kosulu)',
    ('dukkan/arama.py', 'sitemap_sayfalar', '_GORUNUR'):
        'modul sabiti (gorunurluk kosulu)',
    ('dukkan/bildirim_uclar.py', 'tercih_yaz', 'alanlar'):
        'anahtarlar Tercih semasinin ALAN ADLARI (model_dump); deger :param',
    ('dukkan/bildirim_uclar.py', 'tercih_yaz', 'k'):
        'anahtarlar Tercih semasinin ALAN ADLARI (model_dump); deger :param',
    ('dukkan/bildirim_uclar.py', 'tercih_yaz', 'set_ifadesi'):
        "'k = :k' parcalari; k sema alan adi",
    ('dukkan/isletme.py', 'isletme_guncelle', "', '.join(set_parcalari)"):
        "'k = :k' parcalari; k IsletmeGuncelle alan adi + sabit parcalar",
    ('dukkan/odeme_akisi.py', 'reklam_satin_al_odemeli', 'sutun'):
        'KAPSAM_SUTUNU sabit sozlugu',
    ('dukkan/reklam.py', '_bolge_isletme_sayisi', '_GORUNUR'):
        'modul sabiti',
    ('dukkan/reklam.py', '_bolge_isletme_sayisi', 'nere'):
        'sabit sozlukten kosul; deger :b',
    ('dukkan/reklam.py', '_dolu_slot', 'sutun'):
        'KAPSAM_SUTUNU sabit sozlugu',
    ('dukkan/reklam.py', 'beklemeye_gir', 'sutun'):
        'KAPSAM_SUTUNU sabit sozlugu',
    ('dukkan/reklam.py', 'reklam_ac', 'sutun'):
        'KAPSAM_SUTUNU sabit sozlugu',
    ('dukkan/reklam.py', 'sponsorlu_isletmeler', "' AND '.join(kosullar)"):
        'sabit kosul parcalari; degerler :param',
    ('dukkan/uclar.py', 'mahalleler', "''"):
        'bos filtre',
    ('dukkan/uclar.py', 'mahalleler', '"AND (ad ILIKE :q ESCAPE \'\\\\\' OR slug LIKE :qs ESCAPE \'\\\\\')"'):
        'sabit kosul; degerler :q/:qs (P248: like_kalip ile kacisli)',
    ('entegrasyon_kontrol_isi.py', '_cihaz_sonucu_yaz', 'tablo'):
        '_CIHAZ_TABLOLARI sabit listesi',
    ('routers/activity.py', 'list_activity', '_DAL_SIRA_DESC'):
        'modul sabiti (ORDER BY)',
    ('routers/activity.py', 'list_activity', 'dal_kosul'):
        'sabit imlec kosulu; degerler :cz/:cid',
    ('routers/activity.py', 'list_activity', 'kosul'):
        'sabit imlec kosulu; degerler :cz/:cid',
    ('routers/activity.py', 'list_activity', 'p.strip()'):
        '_ROL_KAYNAKLARI sabit SQL parcalari',
    ('routers/activity.py', 'list_activity', 'parcalar'):
        '_ROL_KAYNAKLARI[user.role] sabit sozluk',
    ('routers/activity.py', 'list_activity', 'union_sql'):
        'yukaridaki sabit parcalarin UNION ALL birlesimi',
    ('routers/patrol_windows.py', 'list_patrol_windows', 'where'):
        "sabit kosul parcalari (' AND '); degerler :param",
    ('routers/task_completions.py', 'list_task_completions', 'where'):
        "sabit kosul parcalari (' AND '); degerler :param",
    ('routers/tenants.py', 'list_tenants', 'kaynak'):
        'sabit FROM public.list_all_tenants(:arsivli, :q, :qs, :kurulum)',
    ('scheduler/notify.py', '_fetch_device_tokens', '_KANAL_KOSULU'):
        'modul sabiti',
    ('scheduler/notify.py', '_fetch_device_tokens_for_users', '_KANAL_KOSULU'):
        'modul sabiti',
    ('scheduler/notify.py', '_hedef_yok_nedeni', "' OR '.join(kosul)"):
        'sabit kosul parcalari; degerler %s',
}


def _dinamik_mi(dugum: ast.AST) -> list[ast.AST] | None:
    """Dugum dinamik SQL ise araya giren ifadeleri dondurur, degilse None."""
    if isinstance(dugum, ast.JoinedStr):
        return [v.value for v in dugum.values if isinstance(v, ast.FormattedValue)]
    if isinstance(dugum, ast.Call) and isinstance(dugum.func, ast.Attribute) \
            and dugum.func.attr == "format":
        return list(dugum.args) + [k.value for k in dugum.keywords]
    if isinstance(dugum, ast.Call) and isinstance(dugum.func, ast.Attribute) \
            and dugum.func.attr == "join" and dugum.args:
        # ", ".join(f"{k} = :{k}" for k in alanlar) — ic f-string'in
        # alanlari ve dongunun KAYNAGI raporlanir.
        ic = dugum.args[0]
        if isinstance(ic, (ast.GeneratorExp, ast.ListComp)):
            alt = _dinamik_mi(ic.elt)
            if alt is not None:
                return alt + [g.iter for g in ic.generators]
        return None
    if isinstance(dugum, ast.BinOp) and isinstance(dugum.op, (ast.Add, ast.Mod)):
        # Iki sabit dizenin birlesimi (satir kirma) dinamik degildir.
        parcalar = []
        for yan in (dugum.left, dugum.right):
            if isinstance(yan, ast.Constant) and isinstance(yan.value, str):
                continue
            ic = _dinamik_mi(yan)
            parcalar += ic if ic is not None else [yan]
        return parcalar or None
    return None


def _fonksiyonlar(agac: ast.AST):
    for d in ast.walk(agac):
        if isinstance(d, (ast.FunctionDef, ast.AsyncFunctionDef)):
            yield d


def tara() -> list[tuple[str, str, str]]:
    bulgular: list[tuple[str, str, str]] = []
    for yol in sorted(APP.rglob("*.py")):
        goreli = yol.relative_to(APP).as_posix()
        agac = ast.parse(yol.read_text(encoding="utf-8"))
        for fn in _fonksiyonlar(agac):
            # Ayni fonksiyonda dinamik olarak kurulan degiskenler.
            dinamik_ad: dict[str, list[ast.AST]] = {}
            for d in ast.walk(fn):
                if isinstance(d, ast.Assign) and len(d.targets) == 1 \
                        and isinstance(d.targets[0], ast.Name):
                    ic = _dinamik_mi(d.value)
                    if ic is not None:
                        dinamik_ad.setdefault(d.targets[0].id, []).extend(ic)
                elif isinstance(d, ast.AugAssign) and isinstance(d.target, ast.Name) \
                        and isinstance(d.op, ast.Add):
                    ic = _dinamik_mi(d.value)
                    dinamik_ad.setdefault(d.target.id, []).extend(
                        ic if ic is not None else [d.value])
            for d in ast.walk(fn):
                if not isinstance(d, ast.Call) or not d.args:
                    continue
                ad = d.func.attr if isinstance(d.func, ast.Attribute) else (
                    d.func.id if isinstance(d.func, ast.Name) else "")
                if ad not in HEDEF_CAGRILAR:
                    continue
                ilk = d.args[0]
                ic = _dinamik_mi(ilk)
                if ic is None and isinstance(ilk, ast.Call):
                    # execute(text(f"...")) — ic cagri ayrica taranir.
                    continue
                if ic is None and isinstance(ilk, ast.Name):
                    ic = dinamik_ad.get(ilk.id)
                # Araya giren bir DEGISKEN de dinamik kurulmussa onun
                # parcalari da raporlanir (iki kademe yeter: union_sql ->
                # dal f-string'i).
                kuyruk = list(ic or [])
                gorulen: set[str] = set()
                while kuyruk:
                    ifade = kuyruk.pop()
                    metin = ast.unparse(ifade)
                    bulgular.append((goreli, fn.name, metin))
                    if isinstance(ifade, ast.Name) and ifade.id in dinamik_ad \
                            and ifade.id not in gorulen:
                        gorulen.add(ifade.id)
                        kuyruk += dinamik_ad[ifade.id]
    # Ic ice fonksiyonlar ayni bulguyu iki kez uretebilir.
    return sorted(set(bulgular))


def test_DINAMIK_SQL_YALNIZ_BEYAZ_LISTEDEN():
    bulunan = set(tara())
    yeni = sorted(bulunan - set(IZINLI))
    assert not yeni, (
        "SORGU METNINE BIRLESTIRILEN, beyaz listede olmayan ifade(ler):\n  "
        + "\n  ".join(f"{d} :: {f}() :: {i}" for d, f, i in yeni)
        + "\nDeger ise :param ile bagla; tanimlayici ise sabit listeden gelsin "
        "ve IZINLI'ye gerekcesiyle ekle."
    )


def test_IZINLI_LISTE_BAYAT_DEGIL():
    """Artik olmayan bir istisna, listede sessizce yer tutmasin."""
    bayat = sorted(set(IZINLI) - set(tara()))
    assert not bayat, f"IZINLI'de olup kodda bulunmayan: {bayat}"


def test_TARAYICI_KENDISI_CALISIYOR():
    """Tarayici bir f-string SQL'i gercekten yakaliyor mu (sahte ornek)."""
    ornek = ast.parse(
        "async def f(db, ad):\n"
        "    await db.execute(text(f\"SELECT * FROM t WHERE ad = '{ad}'\"))\n"
        "    s = 'SELECT 1 WHERE x = ' + ad\n"
        "    await db.execute(text(s))\n"
    )
    fn = next(_fonksiyonlar(ornek))
    yakalanan = []
    for d in ast.walk(fn):
        if isinstance(d, ast.Call) and getattr(d.func, "id", "") == "text":
            ic = _dinamik_mi(d.args[0])
            if ic:
                yakalanan += [ast.unparse(i) for i in ic]
    assert "ad" in yakalanan


# =========================================================================== #
# (P248 §3b) LIKE / ILIKE JOKER KACISI
# =========================================================================== #
# Olculen kusur: `/users?q=%`, `/users?q=_`, `/dukkan/isletme-ara?q=%` ve
# mahalle aramasi TUM kayitlari donduruyordu. Ortak yardimci:
# `app.tr_arama.like_kacis / like_icerir / tr_kalip` + `LIKE_KACIS`.
#
# KURALLAR (AST + metin taramasi):
#   1. `.like(x)` / `.ilike(x)` — x sabit dize degilse `escape=` ZORUNLU.
#   2. `%` ile baslayan/biten bir f-string'e giren her ifade `like_kacis`
#      ya da `like_icerir` ciktisindan gelmeli (ayni fonksiyonda atanmis
#      degisken de olur).
#   3. Ham SQL dizesinde `LIKE :param` / `ILIKE :param` — `ESCAPE` ile.
#   4. Bosaltan katlayici (slugla/_ascii_katla) ciktisi `like_icerir`e
#      degil `like_icerir_bos_degilse`ye verilir (canli olculen kusur:
#      `/tenants?q=%` ve `/dukkan/isletme-ara?q=%` her seyi donduruyordu).

_KACIS_FONKSIYONLARI = {"like_kacis", "like_icerir", "like_icerir_bos_degilse", "tr_kalip"}

#: Alfanumerik olmayani SILEN katlayicilar: `%`/`_` gibi bir sorguyu BOS
#: dizeye indirir ve `%%` her seyi esler. Ciktilari yalniz
#: `like_icerir_bos_degilse` ile kaliba girer (kural 4).
_BOSALTAN_KATLAYICILAR = {"slugla", "_ascii_katla", "slugify_tenant"}


def _kok_ad(ifade: ast.AST) -> str | None:
    while True:
        if isinstance(ifade, ast.Name):
            return ifade.id
        if isinstance(ifade, ast.Call):
            ifade = ifade.func
        elif isinstance(ifade, ast.Attribute):
            ifade = ifade.value
        else:
            return None


def _kacisli_cagri(ifade: ast.AST) -> bool:
    return isinstance(ifade, ast.Call) and getattr(
        ifade.func, "id", getattr(ifade.func, "attr", "")) in _KACIS_FONKSIYONLARI


def like_tara() -> list[str]:
    bulgular: list[str] = []
    for yol in sorted(APP.rglob("*.py")):
        goreli = yol.relative_to(APP).as_posix()
        kaynak = yol.read_text(encoding="utf-8")
        agac = ast.parse(kaynak)
        for fn in _fonksiyonlar(agac):
            kacisli_ad = {
                d.targets[0].id for d in ast.walk(fn)
                if isinstance(d, ast.Assign) and len(d.targets) == 1
                and isinstance(d.targets[0], ast.Name) and _kacisli_cagri(d.value)
            }
            for d in ast.walk(fn):
                # Kural 1
                if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute) \
                        and d.func.attr in ("like", "ilike") and d.args \
                        and not isinstance(d.args[0], ast.Constant) \
                        and not any(k.arg == "escape" for k in d.keywords):
                    bulgular.append(f"{goreli}:{d.lineno} {fn.name}: escape= yok")
                # Kural 4
                if isinstance(d, ast.Call) and getattr(d.func, "id", "") == "like_icerir" \
                        and d.args and isinstance(d.args[0], ast.Call) \
                        and getattr(d.args[0].func, "id", getattr(d.args[0].func, "attr", "")) \
                        in _BOSALTAN_KATLAYICILAR:
                    bulgular.append(
                        f"{goreli}:{d.lineno} {fn.name}: bosaltan katlayici "
                        "like_icerir'e verilmis (like_icerir_bos_degilse kullan)")
                # Kural 2
                if isinstance(d, ast.JoinedStr) and d.values:
                    ilk, son = d.values[0], d.values[-1]
                    yuzde = (isinstance(ilk, ast.Constant) and str(ilk.value).startswith("%")) \
                        or (isinstance(son, ast.Constant) and str(son.value).endswith("%"))
                    if not yuzde:
                        continue
                    for v in d.values:
                        if not isinstance(v, ast.FormattedValue):
                            continue
                        if _kacisli_cagri(v.value) or _kok_ad(v.value) in kacisli_ad:
                            continue
                        bulgular.append(
                            f"{goreli}:{d.lineno} {fn.name}: kacissiz LIKE kalibi "
                            f"{ast.unparse(v.value)!r}")
        # Kural 3 (dosya geneli, sabit dizeler)
        for d in ast.walk(agac):
            if isinstance(d, ast.Constant) and isinstance(d.value, str):
                for m in _LIKE_PARAM.finditer(d.value):
                    if "ESCAPE" not in d.value[m.end():m.end() + 20].upper():
                        bulgular.append(
                            f"{goreli}:{d.lineno}: ham SQL {m.group(0)!r} ESCAPE'siz")
    return bulgular


import re as _re  # noqa: E402

_LIKE_PARAM = _re.compile(r"\bI?LIKE\s+:[a-z_]+", _re.IGNORECASE)


def test_LIKE_JOKERLERI_KACISLI():
    bulgular = like_tara()
    assert not bulgular, (
        "LIKE/ILIKE joker kacisi eksik (like_icerir/like_kacis + escape=LIKE_KACIS "
        "ya da ham SQL'de ESCAPE '\\\\'):\n  " + "\n  ".join(bulgular))


def test_like_kacis_birim():
    from app.tr_arama import like_icerir, like_kacis, tr_kalip

    assert like_kacis("%") == "\\%"
    assert like_kacis("_") == "\\_"
    assert like_kacis("a\\b") == "a\\\\b"
    assert like_icerir("50%_x") == "%50\\%\\_x%"
    # SQL metni degismez — deger baglama degiskeni olarak gider.
    assert like_icerir("' OR 1=1 --") == "%' OR 1=1 --%"
    assert tr_kalip("İ%") == "%i\\%%"
    from app.tr_arama import like_icerir_bos_degilse

    assert like_icerir_bos_degilse("") is None
    assert like_icerir_bos_degilse("ab") == "%ab%"
