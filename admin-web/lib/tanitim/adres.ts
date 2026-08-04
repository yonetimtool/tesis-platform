// (P127) TANITIM SITESININ KANONIK ADRESLERI — TEK YER.
//
// PUNYCODE (`xn--`) BILINCLI: alan adi Turkce harf tasiyor ama arama
// motorlari ve HTTP yigini adresi ASCII'ye normalize eder. `canonical` ile
// `hreflang`i unicode yazmak, ayni sayfayi IKI FARKLI KOKEN gibi
// gosterebilirdi; ayrica `infra/alan-adi-denetimi.py` yapilandirmada
// unicode konak birakmayi zaten reddediyor — kod da ayni dili konussun.
//
// UC ADRES DE BURADA: kok (tanitim), app (tesis calisma alani), panel
// (platform). Tanitim sayfasindaki giris baglantilari buraya bakar; ayri
// ayri yazilsalardi biri degistiginde otekiler sessizce eskirdi.
export const TANITIM_KOKEN = "https://xn--ynetiyor-n4a.com";
export const APP_GIRIS = "https://app.xn--ynetiyor-n4a.com/login";
export const PANEL_GIRIS = "https://panel.xn--ynetiyor-n4a.com/login";
