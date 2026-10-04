# Biosfera

Wersja: 2.0

Dotyczy BiosphereSystem (zaimplementowany).
Architektura: `docs/architecture.md`. Klimat i atmosfera: `docs/climate.md`.

---

# Cel

Powstanie i ewolucja życia w skali całej planety, z emergentnymi zachowaniami:
sukcesją, natlenieniem, cyklami lasów i pożarów. Najważniejszy system rozgrywki.

Nigdy nie symulujemy pojedynczych organizmów. Symulujemy populacje.

Kryteria: łatwy balans, wysoka różnorodność, niska złożoność obliczeniowa.

---

# Pliki

- `godot/simulation/biosphere/biosphere_system.gd`
- `godot/simulation/biosphere/species_data.gd`, `species_catalog.gd`
- `godot/simulation/biosphere/biosphere_config.gd`
- `godot/resources/biosphere/species.json` (gatunki)
- `godot/resources/biosphere/biosphere.json` (pożary, fotooddychanie, wymieranie, szum)

Nowy gatunek to nowy wpis w `species.json`, bez zmian w kodzie.

---

# Model

Każdy gatunek to jedna liczba P w skali 0..100: jaką część dostępnego
środowiska zajmuje. Populacje są stanem wewnętrznym BiosphereSystem
(decyzja: nie są parametrami planety), zapisywanym przez SaveSystem (krok 8).
Planeta widzi biomasę: ważoną sumę populacji (BiosphereSystem jest jej właścicielem).

| Siła | Mechanizm | Efekt emergentny |
|---|---|---|
| wzrost | logistyczny, mnożony przez przydatność środowiska | gatunki rosną tam, gdzie warunki im sprzyjają |
| śmiertelność | bazowa + stresowa + pożary | zlodowacenia i susze zabijają, las płonie |
| konkurencja | warstwy: wyższe rośliny zacieniają niższe | współistnienie zamiast "zwycięzca bierze wszystko" |
| sukcesja | gatunek powstaje z poprzednika i potrzebuje gleby (biomasy) | bakterie → glony → mech → krzew → drzewo |

Sprzężenia ze środowiskiem (delty do parametrów innych właścicieli):

```text
 fotosynteza ──(+O₂, −CO₂)──► ATMOSFERA ──► mniej CO₂ → chłodniej (KLIMAT)
 oddychanie  ──(−O₂, +CO₂)──►
 transpiracja ─(+wilgotność)─► KLIMAT ──► więcej chmur i deszczu
 biomasa ──(ciemna roślinność)──► KLIMAT ──► cieplej
 wysoki tlen ──► POŻARY (spalają rośliny, zużywają O₂)     ← termostat tlenowy
 wysoki tlen ──► FOTOODDYCHANIE (hamuje fotosyntezę)       ← ogranicznik tlenu
 tlen > 12  ──► bakterie beztlenowe kurczą się do niszy    ← katastrofa tlenowa
```

Złożoność: O(S·L) na tick (S gatunków, L warstw). Koszt ~115 µs na tick przy 5 gatunkach.

---

# Wzory

Dla gatunku i, tylko operacje z `SimMath`:

```
przydatność_i = temp_i · woda_i · co2_i · tlen_i · gleba_i
  temp_i  = smoothstep(t_min−t_margin, t_min, T) · (1 − smoothstep(t_max, t_max+t_margin, T))
  woda_i  = smoothstep(water_min−water_margin, water_min, H lub P)      (pole "water")
  co2_i   = smoothstep(0, co2_need, CO₂)                                (1, gdy co2_need = 0)
  tlen_i  = smoothstep(o2_need/2, o2_need, O₂)                          (1, gdy o2_need = 0)
  gleba_i = smoothstep(biomass_need/2, biomass_need, B)                 (1, gdy biomass_need = 0)

nisza_i     = o2_refuge + (1 − o2_refuge) · (1 − smoothstep(o2_max, 2·o2_max, O₂))   (1, gdy o2_max = 0)
pojemność_i = capacity_i · nisza_i · (1 − shade_i · Σ_{wyższe warstwy lądowe} P_j / 100)
wzrost_i    = growth_i · przydatność_i · szum · P_i · (1 − P_i / pojemność_i)
pożar       = fire_rate · smoothstep(fire_o2_low, fire_o2_high, O₂)
              · (1 − fire_wet_damping · smoothstep(fire_humidity_low, fire_humidity_high, H))
śmierć_i    = (base_mortality_i + stress_mortality_i · (1 − przydatność_i) + pożar · flammable_i) · P_i
zasiew_i    = seed_i · przydatność_i · P_poprzednika / 100           (bez poprzednika: · 1)
P_i'        = clamp(P_i + wzrost_i − śmierć_i + zasiew_i, 0, 100);  P_i' < extinction_threshold i maleje → 0

foto_i      = przydatność_i · (1 − smoothstep(photorespiration_low, photorespiration_high, O₂)) · P_i/100
ΔO₂  += oxygen_i · foto_i − respiration_i · P_i/100 − spalone_i · fire_o2
ΔCO₂ += −co2_uptake_i · foto_i + respiration_i · P_i/100 + spalone_i · fire_co2
ΔH   += transpiration_i · przydatność_i · P_i/100
ΔB    = Σ weight_i · (P_i' − P_i)      (+ korekta "census", gdy biomasa planety odbiegła od sumy)
spalone_i = pożar · flammable_i · P_i · weight_i
```

Wszystkie gatunki czytają populacje z poprzedniego ticka, więc wynik nie zależy
od kolejności gatunków w pliku.

---

# Gatunki

| Gatunek | Zużywa | Produkuje | Potrzebuje | Gdy zniknie | Gdy zdominuje |
|---|---|---|---|---|---|
| bakterie | trochę O₂ | glebę (pierwsza biomasa) | wilgoć ≥ 5; beztlenowe: przy O₂ > 12 kurczą się do niszy (15% pojemności) | glony nie mają z czego powstać | — (sufit 60) |
| glony | CO₂ | główne źródło O₂ | wilgotność ≥ 20, 10–45° | tlen przestaje rosnąć | spadek CO₂ i ochłodzenie |
| mech | CO₂ | O₂, wilgoć, glebę | wilgotność ≥ 22, 5–35°, biomasa ≥ 3 | brak drogi do krzewów | wilgotny, chłodny świat |
| krzew | CO₂ | O₂, wilgoć, biomasę | opady ≥ 5, tlen ≥ 12, biomasa ≥ 12 | brak drogi do drzew | paliwo dla pożarów |
| drzewo | CO₂ | dużo O₂ i wilgoci | opady ≥ 8, tlen ≥ 18, biomasa ≥ 20, 20–45° | spadek tlenu i wilgoci | cień nad krzewami i mchem, wielkie pożary |

Walidacja `species.json`: wymagane pola, nieznane pola są błędem, unikalne id,
źródło wody to `humidity` albo `precipitation`, poprzednik istnieje, sukcesja
bez cykli, `t_min < t_max`, suma `weight` ≤ 1 (biomasa mieści się w skali).

---

# Zdarzenia

BiosphereSystem zgłasza fakty przez `emit_event` (kontrakt `SimulationSystem`):

| Zdarzenie | Kiedy | Dane |
|---|---|---|
| `species_emerged` | populacja przekracza `established_population` (1) | species, population |
| `species_extinct` | zadomowiona populacja spada do 0 | species |

W logu: `[Tick 7214] EVENT species_emerged from biosphere {"population":1.0004,"species":"tree"}`.

Przyczyny delt nazywają gatunek: `algae_photosynthesis`, `tree_respiration`,
`moss_transpiration`, `shrub_wildfire`, `moss_growth`, `tree_dieback`, `census`.

---

# Balans

`planet_report.gd` (8 seedów × 40 000 ticków, klimat + atmosfera + biosfera):

| Miara | Wynik |
|---|---|
| natlenienie (O₂ > 15) | tick 6457–10 174 |
| pierwsze drzewa | tick 8396–12 004 |
| tlen | 2,2–43,3 (nigdy 100) |
| CO₂ | 24–94 |
| maks. biomasa | 43,7–45,9 (kotwica 50 = "lasy i krzewy") |
| czas z lasem (drzewa > 10) | 8–36% |
| gatunków > 5 jednocześnie | średnio 2,9–3,5 (zakres 1–5) |
| wymierania | 8–16 na przebieg |
| temperatura | średnio 30–34, 9–20% czasu w lodzie |

Historia strojenia (prototyp w Pythonie przed implementacją):

1. reguła wymierania zabijała każdy zarodek (poprawiona: wymiera tylko populacja malejąca)
2. fotosynteza wyciągała CO₂ tak mocno, że planeta zamarzała; pochłanianie CO₂ zmniejszone o połowę, oddychanie zwraca całe CO₂
3. po nasyceniu skorupy tlen uciekał do 100; dodane pożary zależne od tlenu i fotooddychanie
4. bakterie beztlenowe: najpierw wymierały na zawsze, decyzją projektową przeżywają w niszy (`o2_refuge`)
5. atmosfera: `crust_capacity` 0,05 → 0,1 (natlenienie około 3× szybciej)

---

# Przykłady z symulacji (seed 42, konsola)

```text
[Tick 130]   EVENT species_emerged ... bacteria
[Tick 332]   EVENT species_emerged ... algae
[Tick 905]   EVENT species_emerged ... moss
[Tick 4740]  EVENT species_emerged ... shrub
[Tick 7214]  EVENT species_emerged ... tree
[Tick 7966]  EVENT species_extinct ... tree        pierwszy las ginie
[Tick 10585] EVENT species_emerged ... tree        i wraca
[Tick 15000] oxygen 23.202 -> 23.209 [... biosphere:algae_photosynthesis +0.050, biosphere:moss_photosynthesis +0.027, ...]
```

---

# Testy

- `tests/unit/species_catalog_test.gd`: walidacja danych, przydatność, nisza beztlenowa
- `tests/unit/biosphere_config_test.gd`
- `tests/unit/biosphere_system_test.gd`: powstawanie, poprzednik, wzrost logistyczny,
  śmierć stresowa, cień, biomasa = suma, korekta census, fotosynteza, fotooddychanie,
  oddychanie, transpiracja, pożary, nisza, zdarzenia, determinizm
- `tests/integration/biosphere_behavior_test.gd`: jeden długi przebieg całej planety
  (kolejność sukcesji, natlenienie po nasyceniu skorupy, drzewa po natlenieniu,
  przetrwanie bakterii, limit tlenu)
- `tests/simulation/life_balance_test.gd`: 3 seedy × 20 000 ticków

---

# Ograniczenia

- populacje i stan RNG nie przetrwają zapisu gry do czasu SaveSystem (krok 8)
- złoty ślad nadal używa testowej dynamiki; determinizm biosfery sprawdzają testy
  "ten sam seed → te same populacje"
- testy biosfery są najdłuższe w zestawie (~40 s); tick całej planety ~0,4 ms
- mutacje (nowe gatunki) przyjdą z EventSystem (krok 7)

---

# Reguły wspólne

- biosfera nie przechowuje kopii parametrów planety
- nie zapisuje stanu bezpośrednio, tylko zwraca delty
- losowość tylko z własnego strumienia SeededRng
- efekty zależą od współczynników z danych
