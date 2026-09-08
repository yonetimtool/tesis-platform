# DUKKAN — 08 · Sanal POS sağlayıcı karşılaştırması

> **Seçimi sen yapacaksın.** Bu belge karar vermek için değil, karar
> vermeni kolaylaştırmak için. Kod **hiçbirine bağlı değil**: sağlayıcı
> soyutlaması (`app/odeme.py`) yazıldı, seçim tek satır env
> (`ODEME_SAGLAYICI=`).

> **DÜRÜSTLÜK NOTU — ölçmediğim şey:** Aşağıdaki komisyon oranları ve
> ücretler **kesin fiyat değildir.** Türkiye'de sanal POS komisyonu
> neredeyse her zaman **pazarlığa** ve şu üç şeye bağlıdır: aylık işlem
> hacmi, sektör (MCC), ve taksit yapıp yapmadığın. Sağlayıcıların
> web sitesindeki "başlangıç" oranları listedeki en iyi durumdur ve
> genelde yüksek hacim varsayar.
>
> **Bu yüzden: üçünden de yazılı teklif al.** Aşağıdaki tablo, teklif
> isterken neyi soracağını bilmen için.

---

## 1. Özet tablo

| | **iyzico** | **PayTR** | **Param** | **Sipay** |
|---|---|---|---|---|
| Tekrarlayan ödeme (recurring) | **Var** — "Abonelik" ürünü + saklı kart ile kendi planını kurma | **Var** — "Tekrarlayan Ödeme" / saklı kart | **Var** — saklı kart (Param Kart / tokenizasyon) | **Var** — saklı kart + abonelik |
| Kart saklama (tokenizasyon) | **Olgun** — `cardUserKey` + `cardToken`, en iyi belgelenmiş olanı | Var | Var | Var |
| Alt üye işyeri gerektirir mi | **Hayır** (doğrudan satışta gerekmez) | Hayır | Hayır | Hayır |
| Dokümantasyon | **En iyi** — örnekli, sürümlü, sandbox ile birebir | Orta — çalışıyor ama örnekler dağınık | Orta | Orta-zayıf |
| Test/sandbox ortamı | **Çok iyi** — gerçek akışın aynısı | İyi | İyi | Değişken |
| Resmî Python SDK | Var (`iyzipay`) | Yok (düz HTTP) | Yok (düz HTTP/SOAP izleri) | Yok (düz HTTP) |
| Entegrasyon zorluğu (bizim akış için) | **Düşük** | Orta | Orta | Orta |
| Komisyon | Pazarlık; liste oranı genelde **en yüksek** üçlü içinde | Pazarlık; genelde **iyzico'dan düşük** | Pazarlık; rekabetçi | Pazarlık; agresif fiyat verebiliyor |
| Ödeme günü (valör) | Standart | Standart, "hızlı ödeme" seçeneği pazarlanıyor | Standart | Standart |
| Bilinirlik / güven algısı | Yüksek (kullanıcı ödeme sayfasında markayı tanır) | Yüksek | Orta | Orta |

---

## 2. Bizim akış için gerçekten önemli olan üç şey

Bizim ihtiyacımız **dar**: işletme → platform, tek ürün (reklam), TL,
taksit yok, iade nadir. Bu dar ihtiyaçta sağlayıcılar arasındaki fark,
komisyon dışında **üç yerde** ortaya çıkıyor:

### 2.1 Kart saklama akışının netliği

Tekrarlayan ödeme istiyorsan (ki istiyorsun), sağlayıcı sana bir
**token** vermeli ve o token'la ilk işlemden bağımsız çekim
yapabilmelisin. Üçü de yapıyor; farkı **belgelemede**.

iyzico'da bu iki kavramla net: `cardUserKey` (kullanıcı) + `cardToken`
(kart). İkisini de biz saklıyoruz, **kart numarası hiç bize gelmiyor**.
Diğerlerinde de var ama akışı doğru kurmak daha çok deneme gerektiriyor.

### 2.2 3D Secure zorunluluğu ve tekrarlayan ödemede muafiyet

Türkiye'de kartlı işlemlerde 3DS pratikte zorunlu. **Ama tekrarlayan
ödemede** ilk işlemde 3DS yapıp sonraki çekimleri 3DS'siz yapabilme
(MIT — merchant initiated transaction) desteği sağlayıcıya ve bankaya
göre değişiyor.

**Teklif isterken bunu açıkça sor:** *"İlk işlemde 3DS ile alınan onay,
sonraki tekrarlayan çekimlerde 3DS'siz kullanılabiliyor mu? Hangi
bankalarda kısıt var?"* Cevap "hayır" ise abonelik pratikte
kullanılamaz — kullanıcı her ay 3DS ekranına düşer.

### 2.3 Başarısız çekimde ne oluyor

Tekrarlayan ödemede kart limiti dolabilir, kart yenilenebilir. Sor:
*"Başarısız çekimde otomatik yeniden deneme var mı? Kaç kez, hangi
aralıkla? Kart güncelleme (account updater) hizmeti var mı?"*

Bu olmadan başarısız çekimi **biz** yönetmek zorundayız (kod buna
hazır: `abonelik.durum='odeme_basarisiz'` + bildirim).

---

## 3. Değerlendirmem

**Entegrasyon kolaylığı ve belgeleme öncelikse: iyzico.** Resmî Python
SDK'sı var, sandbox gerçek akışın aynısı, kart saklama en net
belgelenmiş olanı. Bizim gibi tek üründe hızlı çalışır hâle gelmek
istiyorsan en az sürprizli yol bu.

**Komisyon öncelikse: PayTR ve Sipay'den teklif al.** İkisi de
iyzico'nun altında kalabiliyor. Sipay özellikle yeni müşteride agresif
fiyat verebiliyor; karşılığında dokümantasyon zayıf ve entegrasyonda
daha çok destek yazışması gerekiyor.

**Param**, ikisinin arasında: fiyat rekabetçi, belgeleme orta.

**Somut öneri:** aylık hacim düşükken (ilk aylarda birkaç bin TL reklam
geliri) komisyon farkının mutlak değeri **küçük** — ayda 5.000 TL ciroda
%0,5 fark ayda 25 TL. Aynı dönemde entegrasyon ve destek yazışmasına
harcanacak zaman **çok daha pahalı**. Bu yüzden başlangıç için
**iyzico** mantıklı; hacim büyüdüğünde (aylık 50.000 TL üstü) komisyon
pazarlığı anlamlı hâle gelir ve **sağlayıcı değiştirmek kodda tek satır**
olacak şekilde yazıldı.

> Bu bir tercih, ölçüm değil. Teklifler geldiğinde sayılar bu
> değerlendirmeyi değiştirebilir.

---

## 4. Teklif isterken sor (kopyala-yapıştır)

1. **Komisyon oranı:** tek çekim, TL, taksitsiz. Aylık hacim
   kademelerine göre oran nedir?
2. **Sabit ücretler:** kurulum, aylık sabit, işlem başına sabit kuruş
   var mı?
3. **Tekrarlayan ödeme:** saklı kartla, kullanıcı olmadan çekim
   yapabiliyor muyum? İlk işlemdeki 3DS onayı sonraki çekimlerde
   geçerli mi (MIT)? Hangi bankalarda kısıt var?
4. **Başarısız çekim:** otomatik yeniden deneme var mı? Kart güncelleme
   (account updater) hizmeti veriyor musunuz?
5. **İade:** kısmi iade var mı? İade edilen işlemin komisyonu geri
   veriliyor mu? *(Genelde verilmiyor — sözleşmemizi buna göre
   yazmalıyız.)*
6. **Valör:** para hesabıma kaç günde geçiyor?
7. **Ters ibraz (chargeback):** süreç nasıl işliyor, bize ne düşüyor?
8. **Test ortamı:** sandbox gerçek akışın aynısı mı? Tekrarlayan ödeme
   sandbox'ta denenebiliyor mu?
9. **Sözleşme:** asgari taahhüt süresi ya da asgari hacim var mı?
10. **Teknik:** REST mi, Python örneği veriyor musunuz, webhook
    (bildirim) desteği var mı?

---

## 5. Seçim yapıldığında ne olacak

Kod tarafında yapılacak iş **bir sınıf**:

```python
class IyzicoOdemeSaglayici(OdemeSaglayici):
    ad = "iyzico"
    def odeme_baslat(...) -> OdemeSonucu: ...
    def kart_sakla(...) -> KartSonucu: ...
    def sakli_kartla_cek(...) -> OdemeSonucu: ...
    def iade(...) -> OdemeSonucu: ...
```

Geri kalan her şey (reklam yayına alma, abonelik döngüsü, fatura
alanları, bildirimler) sağlayıcıdan **habersiz** yazıldı ve testleri
sahte bir sağlayıcıyla koşuyor.

`.env`: `ODEME_SAGLAYICI=iyzico` + kimlik bilgileri. Başka hiçbir
değişiklik yok.
