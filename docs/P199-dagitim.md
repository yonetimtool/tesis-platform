# P199 — Dağıtım notu

## 1. Göç var (0090)

```
alembic upgrade head
```

`tenant.kurulum_otomasyon_karari` sütunu eklenir (boolean, varsayılan
`false`). Veri dönüştürmez, satır kilitlemez — `ADD COLUMN` + sabit
varsayılan, büyük tablolarda da anlıktır.

**Geri alma:** `alembic downgrade 0089_eposta_zorunlu` sütunu düşürür.
Kaybolan tek şey "yönetici otomasyon tercihlerini kaydetti mi" bayrağı;
yeniden sorularak elde edilir. Dev'de geri alma → yeniden uygulama
çalıştırıldı.

## 2. Mevcut tesislerde ne görünür

Bütün tesisler otomasyon adımını **"sorulmadı"** durumunda görür — bu
doğru: kimseye sorulmamıştı. Adım **isteğe bağlı**, dolayısıyla
"Çalışır kurulum için eksikler" listesine düşmez.

**Dikkat edilecek tek nokta:** `gelir_gider_tanimi` adımı **zorunlu**.
Gelir/gider tanımı olmayan mevcut bir tesis, sihirbazda "eksik" olarak
görünmeye başlar. Bu bir gerileme değil, ölçülmüş bir gerçeğin görünür
hâle gelmesi: o tesis bugün de toplu aidat yazamıyor.

## 3. Yeniden başlatılacaklar

* `api` (yeni adımlar + iki PATCH ucunda bayrak yazımı)
* `admin-web` (yeni sözlük anahtarları + özet kartının yeni bölümü)

Worker/beat davranışı değişmedi.

## 4. Dağıtım sonrası bakılacak

`/kurulum` sayfasında:
* adım sayısı **18**, zorunlu sayaç **x/7**,
* **Finansal İşlemler → Otomasyon** ekranında hatırlatma kartını
  kaydedin (kapalı bırakarak da olur) → otomasyon adımı yeşile dönmeli,
* bir isteğe bağlı adımı **Atla** deyin → özetin altında **"Sonraya
  bıraktıklarınız"** bölümü, adımın neyi engellediğiyle birlikte
  çıkmalı.
