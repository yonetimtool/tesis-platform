# P205 — Çok yönlü giriş + vardiya zaman çizelgesi

**Tarih:** 2026-09-02

---

# 0. Uygulamadan ÖNCE yapılan iki ölçüm

Sen P204'te "ölçemediklerini uygulamadan önce doğrula" dedin. İkisini de
yaptım ve **ikisi de analizimi düzeltti.**

## 0.1 P204 tablosunda YANLIŞ olan üç satır

| İşlev | P204'te yazdığım | ÖLÇÜLEN gerçek |
|---|---|---|
| **Davet gönderme** | "mobilde yok, küçük iş" | **Kısmen VAR.** `residents_api.dart` / `staff_screen.dart`: mobilde sakin veya personel eklerken sunucu **otomatik davet gönderiyor**. Eksik olan şey davet **listesi + yeniden gönderme** (`/davetler`). |
| **Gider/gelir kaydı** | "mobilde yok, küçük iş" | **VAR.** `budget_api.dart` `POST /budget/entries` çağırıyor ve o uç **`FinansalHareket` yazıyor** (tek defter). Yani mobilde gelir/gider kaydı zaten yapılabiliyor. Eksik olan: fiş fotoğrafı ve onay akışı. |
| **Bütçe** | "salt okunur" | **Yazma var:** `POST /budget/categories` + `POST /budget/entries`. |

**Sonuç:** P204'ün öncelik listesindeki **3 (davet)** ve **4 (gider
kaydı)** maddeleri baştan yazılacak işler değil, **tamamlanacak** işler.
Bunu ölçmeden başlasaydım var olan bir şeyi yeniden yazıyor olacaktım —
uyarın yerindeydi.

## 0.2 SSO ile giren çok tesisli yönetici — ÖLÇÜLDÜ, hata YOK

Ölçüm (`pg_indexes` + `pg_proc`):

```
uq_oauth_kimlik_subject       UNIQUE (saglayici, subject)   ← PLATFORM GENELİNDE
uq_oauth_kimlik_user_saglayici UNIQUE (user_id, saglayici)

tenant_id_by_oauth: SELECT tenant_id FROM oauth_kimlik
                    WHERE saglayici = ? AND subject = ?
```

`(saglayici, subject)` **platform genelinde tekil**. Yani bir Google
hesabı tüm platformda **tek bir `app_user` satırına** bağlanabilir ve
`tenant_id_by_oauth` **belirsiz olamaz**.

**Cevap:** SSO ile giren çok tesisli yönetici, **kimliğini bağladığı
tesise** düşüyor. Rastgele değil, deterministik. **Ayrı bir hata yok.**

Gerçek sınır şu: aynı Google hesabını **ikinci** bir tesise
bağlayamıyor. Ama P203 §2'den beri uygulama içinden geçiş var, yani
bağlı olduğu tesise girip ötekine geçiyor.

**Karar:** SSO girişinden sonra da — parola girişinde olduğu gibi —
üyelik listesi >1 ise **tesis seçimi gösterilecek**. Böylece üç giriş
yolu (parola / kod / SSO) aynı davranışı gösterir.
