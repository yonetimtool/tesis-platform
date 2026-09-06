"""DUKKAN modulu — dukkan.yonetiyor.com'un backend'i.

===========================================================================
SINIR KURALI (bu paketin TEK kurali)
===========================================================================
Bu paketteki HICBIR modul, `kopru.py` DISINDA, Yonetiyor'un ic yapisini
ithal EDEMEZ. Yasak olanlar:

    app.models        (Yonetiyor tablolari)
    app.db            (app_rw engine'i)
    app.routers.*     (Yonetiyor uclari)
    app.deps          (Yonetiyor bagimliliklari)

Yonetiyor'dan gereken her sey `kopru.py`den gecer — tek dosya, yalniz
okuma, her fonksiyonu ne dondurdugunu belgelemis.

Bu kural `tests/test_dukkan_kopru_siniri.py` tarafindan AST ile olculur.
Bir `import` kurali delerse test kirmizi yanar.

Ikinci ve bagimsiz bir savunma katmani veritabaninda: Dukkan'in kendi
engine'i `dukkan_app` roluyle baglanir ve o rolun `public` semasinda
hicbir yetkisi yoktur (`tests/test_dukkan_sinir.py`). Yani bir import
kurali delse bile veri erisimi yine reddedilir.
"""
