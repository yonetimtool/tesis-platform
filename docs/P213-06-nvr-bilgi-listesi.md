# P213 §6 — NVR/DVR bağlantısı için siteden istenecek bilgiler

Bu liste, geçmiş kayıt izlemeyi bir sitede **açabilmek** için gereken
asgari bilgidir. Marka bilinmiyorsa **önce Bölüm 0**'ı doldurtun; tek
başına `şablon` sağlayıcısıyla çalışmaya yeter.

---

## 0. Her markada gereken (marka bilinmese bile)

| Bilgi | Örnek | Neden gerekli |
|---|---|---|
| Kayıt cihazının **yerel adresi** | `192.168.1.64` | Bağlantının hedefi |
| **RTSP portu** | `554` | Oynatma bu porttan gider |
| **HTTP/HTTPS portu** | `80` / `443` | Kayıt **arama**sı bu porttan gider (yalnız 554 açıksa arama çalışmaz, oynatma çalışır) |
| Sunucumuzdan **erişim yolu** | port yönlendirme / VPN | Cihaz özel ağda; erişim yoksa hiçbir yöntem çalışmaz |
| **Salt-okunur kullanıcı** adı ve parolası | `izleme` | Yönetici hesabını vermeyin — bu hesap yalnız izlemeli |
| **Kanal numarası** | Hikvision `101`, Dahua `1` | Hangi kameranın kaydı |
| Cihazın **saat dilimi** ve saatinin doğru olup olmadığı | `UTC+3`, doğru | Saati kayan cihazda "14:00" başka bir anı gösterir |
| **Saklama süresi** | 15 / 30 gün | Kullanıcıya "ne kadar geriye gidebilirsiniz" demek için |

> **Güvenlik uyarısı — sitenin bilmesi gereken:** NVR'ı doğrudan internete
> açmak riskli. Bu cihazların güvenlik geçmişi kötü ve varsayılan
> parolalarla tarayan botlar var. Tercih sırası: **(1) site-to-site VPN,
> (2) yalnız bizim sunucumuzun IP'sine kısıtlı port yönlendirme,
> (3) açık port** — üçüncüsü son çare.

---

## 1. Hikvision (ve Hikvision tabanlı OEM'ler)

| Ek bilgi | Örnek | Not |
|---|---|---|
| Kanal/track kimliği | `101` | Kalıp: `<kanal><akış>` — kanal 1 ana akış = `101`, kanal 2 = `201`, alt akış = `102` |
| ISAPI açık mı | evet/hayır | Arama bu API'yi kullanır (`/ISAPI/ContentMgmt/search`) |
| Kullanıcı seviyesi | Operatör | "Uzaktan oynatma" izni açık olmalı |

Sağlayıcı seçimi: **`hikvision`**.

---

## 2. Dahua (ve Dahua tabanlı OEM'ler)

| Ek bilgi | Örnek | Not |
|---|---|---|
| Kanal numarası | `1` | Hikvision'dan farklı: düz sayı |
| CGI erişimi açık mı | evet/hayır | Arama `mediaFileFind.cgi` kullanır |
| Kullanıcı seviyesi | Operatör | "Playback" izni açık olmalı |

Sağlayıcı seçimi: **`dahua`**.

---

## 3. Marka bilinmiyor / arama portu kapalı → `şablon`

Bu durumda tek bir şey gerekir: cihazın **oynatma RTSP adres kalıbı**.
Kalıba şu yer tutucuları yazın, sunucu doldurur:

```
{bas} {bit}            → 20260905T140000Z   (UTC)
{bas_tarih} {bit_tarih} → 2026-09-05
{bas_saat}  {bit_saat}  → 14:00:00
{bas_unix}  {bit_unix}  → 1789041600
{kanal}                 → kanal alanına yazdığınız değer
```

Örnekler:

```
Hikvision : rtsp://10.0.0.2:554/Streaming/tracks/{kanal}?starttime={bas}&endtime={bit}
Dahua     : rtsp://10.0.0.3:554/cam/playback?channel={kanal}&starttime={bas_tarih}_{bas_saat}
```

**Sınırı açıkça söyleyin:** `şablon` ile "hangi saatlerde kayıt var"
**bilinmez**. Kullanıcı saati kendi seçer; o aralıkta kayıt yoksa oynatıcı
boş kalır. Arama portu açıldığında marka sağlayıcısına geçilir ve zaman
şeridi görünür hale gelir.

---

## 4. ONVIF (bu turda YOK)

ONVIF **Profile G** (Recording Search + Replay) standart yol olurdu ama
sahada güvenilmez: Profile **S** (canlı) neredeyse her cihazda var,
**G** çoğunda eksik ya da hatalı uygulanmış. İki satıcı adaptörü gerçek
cihazda doğrulandıktan **sonra** eklenecek. Site "ONVIF destekliyor"
diyorsa bu tek başına geçmiş kayıt desteği anlamına **gelmez** — Profile
G'yi ayrıca sorun.

---

## 5. Bilgiler geldikten sonra ne oluyor

1. Kameralar sayfasında ilgili kamerada **Geçmiş kayıt** açılır
   (varsayılan **kapalı**).
2. Sağlayıcı, adres, kanal ve salt-okunur kimlik girilir. **Parola
   şifreli saklanır ve hiçbir yanıtta geri dönmez.**
3. Erişim: **yönetici** ve **güvenlik amiri**. Amir olmayan güvenlik
   görevlisi geçmiş kayda erişemez (kapı sunucuda).
4. Her arama ve her izleme **denetim kaydına** yazılır (kim, hangi
   kamera, hangi zaman aralığı) — KVKK açısından geriye dönük gözetimin
   izlenebilir olması gerekir.
