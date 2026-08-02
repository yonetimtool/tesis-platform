# Saha kutusu (site box) kurulum + işletim runbook'u — P18

> Bu belge **ajanın P18'deki payıdır**. Sahaya kurulum ve pilot koşum
> Kerem'indir (donanım + saha erişimi gerekir); burada yazılanların hiçbiri
> sahada **doğrulanmadı** — dayanağı `docs/frigate-poc.md`teki dev makine
> ölçümleridir ve nerede ekstrapolasyon yapıldığı açıkça yazılıdır.
>
> Bağlam: `docs/frigate-poc.md` (PoC bulguları, kaynak tüketimi ölçümü),
> `docs/anpr-kamera-kurulumu.md` (kamera tarafı, §6 kamera açısı),
> `docs/RUNBOOK-PROD.md` (sunucu tarafı — saha kutusu ONUN YERİNE GEÇMEZ).

---

## 0. Saha kutusu ne YAPAR, ne YAPMAZ

**Yapar:** kameraların RTSP akışını tek noktada toplar, tespit/LPR koşar ve
**yalnız olayları** merkeze (`POST /integrations/anpr/events`) gönderir.

**Yapmaz:** uygulama sunucusu değildir. Panel, API, veritabanı **merkezde**
kalır. Saha kutusunun düşmesi siteyi yönetilemez hâle getirmez — yalnız plaka
okuma durur.

**MİMARİ KARAR — NEDEN SAHADA İŞLENİYOR:** ham video merkeze taşınmıyor.
Tek kamera 1280×720 @ 5 fps bile sürekli bir yukarı-akış tüketir; 6 kamerayı
merkeze taşımak, site başına kalıcı bir yukarı bant genişliği taahhüdü
demekti. Saha kutusu videoyu **yerelde** tüketir, dışarı çıkan şey birkaç
yüz baytlık olay JSON'udur. Ayrıca KVKK açısından da doğru yön: görüntü
sitede kalır, merkeze **karar** çıkar.

---

## 1. Donanım seçimi (ölçüme dayalı boyutlandırma)

Dayanak, `docs/frigate-poc.md` §5'te **ölçülen** değerlerdir: tek kamera
1280×720 @ 5 fps tespitte `frigate` konteyneri **%17,1 CPU / 972 MiB RAM**,
CPU dedektörle **inference ≈ 10 ms/kare**.

| Kamera sayısı | Öneri | Dedektör |
|---|---|---|
| 1–2 | 4 çekirdek / 8 GB | CPU yeter |
| 3–4 | 8 çekirdek / 8–16 GB | CPU sınırda; Coral **isteğe bağlı** |
| 5–6 | 8 çekirdek / 16 GB | Coral **önerilir** |
| 7+ | 8+ çekirdek / 16 GB+ | Coral **gerekli**; ya da ikinci kutu |

**EKSTRAPOLASYON UYARISI:** 5–6 kamera rakamı tek kamera ölçümünden
çıkarılmıştır, sahada doğrulanmamıştır. Pilotta ilk iş `docker stats` ile
gerçek yükü ölçmektir (§6).

**Coral TPU'nun asıl kazancı hız değil, CPU'yu boşaltmaktır** — inference
GPU/TPU'ya gider. 10 ms'yi 8 ms'e indirmesi beklenmiyor; beklenen, CPU'nun
kod çözme (decode) işine kalmasıdır.

**Disk:** kayıt tutulacaksa ayrı bir SSD. Kaba hesap: kamera başına 5 fps
tespit + olay klibi ≈ günde 1–2 GB. 6 kamera × 14 gün ≈ **150–200 GB**.
`storage` bölümü **dolarsa Frigate yazmayı durdurur ve olay üretimi de
etkilenir** — disk doluluk alarmı §6'da.

**`shm_size` TUZAĞI (PoC'de ölçüldü):** tek kamerada bile `128mb` **sınırda**
çıktı (kullanım 21,4 MB, Frigate'in kendi hesabı `min_shm: 146 MB`). Kamera
başına büyütün; küçük bırakmak, yük altında kare düşmesi olarak görünür ve
"kamera bozuk" diye teşhis edilir.

---

## 2. Ağ

* Saha kutusu ile kameralar **aynı yerel ağda** olmalı; RTSP'yi internet
  üzerinden çekmek hem gecikme hem güvenlik sorunudur.
* Kutudan **dışarı** yalnız HTTPS (443) gerekir — olay gönderimi için.
  **Gelen** port açmayın: kutuya erişim VPN ya da ters tünelle olur (§5).
* Kameraların **eşzamanlı bağlantı limiti** düşüktür (ucuz IP kameralarda
  2–4). Frigate kameranın RTSP'sini doğrudan tüketmez, **kendi go2rtc
  restream'ini** tüketir (`preset-rtsp-restream`) — kaynağa **tek** bağlantı
  açılır. Bunu kapatmayın; kapatılırsa kamera "bazen bağlanmıyor" davranışına
  girer ve teşhisi zordur.
* Kameralara **statik IP** ya da DHCP rezervasyonu verin. IP değişirse akış
  sessizce durur.

---

## 3. Kurulum

Temel: `infra/frigate-poc/docker-compose.yml`. **Olduğu gibi sahaya
kurulmaz** — PoC yığını sentetik bir RTSP kaynağı (`kaynak` servisi) içerir;
sahada o servis **YOKTUR**, yerine gerçek kameralar gelir.

```bash
# 1) Docker + compose kurulu bir Linux (LTS) üzerinde:
sudo timedatectl set-timezone Europe/Istanbul   # olay zaman damgaları icin
sudo timedatectl set-ntp true                   # SAAT KAYMASI olaylari bozar

# 2) Yigin dizini
sudo mkdir -p /opt/yonetio-saha && cd /opt/yonetio-saha

# 3) infra/frigate-poc/ icerigi buraya kopyalanir; `kaynak` servisi SILINIR
#    ve config.yml'deki kameralar gercek RTSP adresleriyle degistirilir.

# 4) Ayarlar dosyasi (ASLA depoya girmez)
cat > .env <<'EOF'
ANPR_KEY=<tenant basina anahtar: PATCH /tenant/settings ile uretilir>
MERKEZ_URL=https://<sunucu>/integrations/anpr/events
EOF
chmod 600 .env

# 5) Kaldir
docker compose up -d
docker compose logs -f frigate       # ilk acilis: kamera baglantilarini izle
```

**`docker compose down -v` YASAKTIR** (plan kural 5) — `-v` kayıtları ve
yapılandırma birimlerini siler.

Kamera tarafı ayarları (yön, güven eşiği, kamera açısı) için
`docs/anpr-kamera-kurulumu.md`. Özellikle **§6 kamera açısı**: plaka bağımsız
bir nesne değil, **aracın özniteliğidir** — kamera aracın gövdesini görmeli,
plakaya zoom yapılmış kadraj LPR'yi çalışmaz hâle getirir.

---

## 4. Merkeze bağlanma ve doğrulama

Kutu merkeze **API anahtarıyla** konuşur (`X-ANPR-Key`, tenant başına);
kullanıcı oturumu **yoktur** — kamera kutusunun token yenileyecek bir
kullanıcısı olamaz.

Zinciri kurulumdan hemen sonra **elle** sınayın
(`docs/anpr-kamera-kurulumu.md` §7'deki `curl`): önce elle bir olay gönderin,
panelde göründüğünü doğrulayın; **ancak ondan sonra** kameralara bakın.
Tersini yapmak, "kamera mı yoksa ağ mı" sorusunu ayırt edilemez kılar.

**Anahtar sızarsa:** `PATCH /tenant/settings` ile yeni anahtar üretin ve
kutudaki `.env`i güncelleyin. Eski anahtar anında geçersizleşir.

---

## 5. Uzaktan güncelleme stratejisi

**KARAR: ÇEKME (pull), İTME (push) DEĞİL — ve OTOMATİK DEĞİL.**

Gerekçe: saha kutusuna **gelen** port açmak (SSH dâhil) her siteyi internete
bakan bir uç hâline getirirdi; site sayısı arttıkça bu, yönetilebilir bir
saldırı yüzeyi olmaktan çıkar. Kutu **kendisi** dışarı bağlanır.

* **Erişim:** kalıcı bir ters tünel (WireGuard ya da Tailscale sınıfı) —
  kutu merkeze bağlanır, merkez kutuya değil. Gelen port **yok**.
* **İmaj sabitlemesi:** `stable` etiketi **kullanılmaz**, sürüm **sabitlenir**
  (`frigate:0.17.2` gibi). `stable`, farklı sitelerde farklı sürümler demektir
  ve bir hata raporu "hangi sürüm" sorusunu cevaplayamaz hâle gelir.
* **Otomatik güncelleme YOK** (Watchtower vb. **önerilmez**). Gece yarısı
  kendiliğinden yükselen bir kutu, sabah "plaka okumuyor" olarak geri döner ve
  değişikliğin ne zaman olduğu bilinmez. Güncelleme **planlı** ve **tek
  sitede önce** yapılır.
* **Sıra:** tek pilot site → bir hafta gözlem (§6 ölçümleri) → kalan siteler.
* **Geri alma:** sabitlenmiş bir önceki sürüm etiketi + `docker compose up -d`.
  Yapılandırma dosyaları sürüm kontrolünde tutulmalı ki geri alma
  yapılandırmayı da kapsasın.
* **Yeniden başlatma:** compose servisleri `restart: unless-stopped`;
  elektrik kesintisi sonrası kutu kendiliğinden ayağa kalkmalı. Bunu
  **kurulumda** test edin (fişi çekin), sahada altı ay sonra değil.

---

## 6. İşletim: neye bakılır

Pilotun ilk haftası **ölçüm haftasıdır**; aşağıdakiler kayda geçmeden ikinci
site kurulmaz.

| Ne | Nasıl | Eşik / beklenen |
|---|---|---|
| CPU / RAM | `docker stats` | `frigate` sürekli %70 CPU üstündeyse kamera sayısı fazla ya da Coral gerekli |
| Kare düşmesi | Frigate arayüzü → kamera kartı | `skipped fps` sıfırdan belirgin büyükse `shm_size` ve CPU'ya bakın |
| Disk | `df -h` | %80 üstü: saklama süresini kısaltın |
| Olay akışı | Panelde ANPR listesi | Gün içinde **hiç** olay yoksa zincir kopuktur: önce §4'teki elle `curl` |
| Saat | `timedatectl` | NTP senkron değilse olay zaman damgaları kayar |
| Kamera bağlantısı | `docker compose logs frigate` | Tekrarlayan yeniden bağlanma: kamera bağlantı limiti ya da ağ |

**Yanlış pozitif/negatif ayarı:** güven eşiği `anpr_guven_esigi`
(`PATCH /tenant/settings`). Yükseltmek kaçırmayı, düşürmek yanlış okumayı
artırır — pilot verisiyle ayarlanır, baştan tahmin edilmez.

---

## 7. Bu belgede DOĞRULANMAMIŞ olanlar (dürüstçe)

* 5–6 kamera boyutlandırması **ekstrapolasyondur** (tek kamera ölçümünden).
* Coral TPU **hiç denenmedi** (donanım yok); kazancı mimari olarak
  açıklandı, ölçülmedi.
* Gerçek plaka okuma doğruluğu **ölçülmedi** — PoC'de sentetik yayın
  kullanıldı (`docs/frigate-poc.md` §4'teki dürüst kayıt).
* Ters tünel çözümü (WireGuard/Tailscale) **seçilmedi**, yalnız yönü
  (çekme, gelen port yok) kararlaştırıldı; ürün seçimi pilotta yapılacak.
