# Caydırıcı entegrasyonu — protokol notu (P37)

> **Ürün sınırı webhook'tur.** Bu belge donanım sürücüsü yazmak için değil,
> ileride biri "MQTT ekleyelim mi?" diye sorduğunda kararın *neden* böyle
> verildiğini ve hangi köprünün nereye oturacağını hatırlatmak için var.

## Bugün ne var

Eşik aşıldığında ürün **tek bir şey** yapar: yapılandırılmış entegrasyona
**HMAC imzalı JSON** POST eder. Entegrasyon yoksa **manuel mod** çalışır
(yöneticiye bildirim gider, anonsu o yapar).

```
POST <endpoint_url>
Content-Type: application/json
X-Yonetio-Timestamp: 1785000000
X-Yonetio-Signature: sha256=<hex>

{"daire":"B-12","metin":"...","tip":"gurultu_uyarisi","zaman":"2026-07-31T21:00:00+00:00"}
```

- İmza: `HMAC-SHA256(secret, "<timestamp>.<body-bytes>")` — GitHub/Stripe
  deseni. **Zaman damgası imzaya girer**: yalnızca gövdeyi imzalamak, ele
  geçirilmiş bir isteğin sonsuza dek yeniden oynatılabilmesi demekti.
- Alıcı, damganın **5 dakikadan** eski olmadığını da doğrulamalıdır
  (`gurultu.IMZA_PENCERESI_SN`).
- Gövde **deterministik** üretilir (sıralı anahtar, boşluksuz) ki alıcı
  yeniden serileştirip aynı imzayı hesaplayabilsin.
- Sır yoksa **imza başlığı da gönderilmez**: boş bir sırla imza üretmek,
  alıcının doğruladığını sanıp aslında hiçbir şey doğrulamaması olurdu.
- Hedef **SSRF kapısından** geçer — caydırıcı, iç ağa istek atmak için
  kullanılamaz. Başarısız gönderim `unit_uyari` satırında `basarisiz` olarak
  durur ve **katlanan aralıklarla** (1, 5, 25 dk) en fazla 3 kez yeniden
  denenir; tükenirse **manuel moda düşer** — sistem sessizce pes etmez, iş
  bir insana devredilir.

## Neden sürücü yazmıyoruz

Akıllı ev/anons dünyası tek bir standartta buluşmuyor: aynı sitede Sonos,
KNX kabini, bir IP megafon ve bir Home Assistant kurulumu yan yana olabilir.
Her biri için sürücü yazmak, **ürünü donanım envanterine bağlamak** ve her
firmware güncellemesinde bakım borcu üretmek demekti. Webhook sınırı bu
işi, zaten site içinde çalışan ve o donanımı **zaten tanıyan** bir köprüye
bırakır.

## Aday köprüler (ileride, gerekirse)

| Protokol | Nereye oturur | Not |
|---|---|---|
| **MQTT** | Köprü webhook'u dinler → `site/anons` konusuna publish eder | Home Assistant / Zigbee2MQTT kurulumlarında en kısa yol; QoS 1 yeterli |
| **KNX/IP** | Köprü webhook → KNXnet/IP router (grup adresi) | Anons hattı KNX'te ise; ham KNX telegramı ürünün işi değil |
| **SIP/paging** | Köprü webhook → SIP INVITE + TTS | IP megafon santralleri; ses üretimi köprüde |
| **Home Assistant** | Doğrudan: HA'nın webhook trigger'ı | Ek köprü gerekmez, bugün de çalışır |

Hepsinde ortak desen aynı: **ürün → HTTP → köprü → protokol**. Ürün tarafında
değişecek tek şey `endpoint_url` ve sırdır.

## Köprü yazacak olana asgari sözleşme

1. `X-Yonetio-Signature` doğrula (yukarıdaki formül), doğrulamadan **işleme**.
2. `X-Yonetio-Timestamp` tazeliğini kontrol et (≤ 5 dk).
3. 2xx dön. **2xx dönmezsen ürün yeniden dener** — bu yüzden köprünün kendisi
   idempotent olmalı ya da tekrarları tolere etmelidir.
4. Uzun süren işi (TTS üretimi, anons kuyruğu) **yanıttan sonra** yap: ürün
   isteği kısa tutar ve zaman aşımını başarısızlık sayar.

İlgili: `backend/app/gurultu.py`, `backend/app/gurultu_akisi.py`,
`docs/MASTER-PLAN.md` → P37.
