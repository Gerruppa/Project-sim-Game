# Klimat i atmosfera

Wersja: 3.0

Dotyczy ClimateSystem i AtmosphereSystem (oba zaimplementowane).
Architektura: `docs/architecture.md`.

---

# Cel

Wiarygodna, ale uproszczona symulacja klimatu jako system gry:

1. łatwe balansowanie (wszystkie współczynniki w danych),
2. czytelne efekty dla gracza (każda zmiana ma nazwaną przyczynę),
3. realistyczne reakcje (sprzężenia zwrotne, punkty przełomowe, sezony).

To nie jest symulacja naukowa.

---

# ClimateSystem

Pliki:

- `godot/simulation/climate/climate_system.gd`
- `godot/simulation/climate/climate_config.gd`
- `godot/resources/climate/climate.json`

Jest właścicielem dynamiki: temperatury, wilgotności, zachmurzenia i opadów.
Nie dotyka tlenu (AtmosphereSystem) ani biomasy (BiosphereSystem).

## Wejścia i wyjścia

| | |
|---|---|
| Wejścia | snapshot: temperatura T, wilgotność H, zachmurzenie C, opady P, biomasa B; tick (sezon); `climate.json`; strumień `SeededRng("climate")` |
| Wyjścia | delty dla T, H, C, P, każda z przyczyną |
| Stan wewnętrzny | `drift` (dryf klimatu); trafi do SaveSystem razem ze stanem RNG |

## Zależności

```text
              ┌──────────── sezon (fala trójkątna) + dryf klimatu (RNG, wolny)
              ▼
        ┌─────────────┐   ciepło → parowanie    ┌───────────┐
        │ TEMPERATURA │ ──────────────────────► │ WILGOTNOŚĆ│
        └─────────────┘ ◄────────────────────── └───────────┘
          ▲  ▲   ▲      para wodna = efekt cieplarniany (+)   │ wilgotność względna
          │  │   │                                            ▼
          │  │   └── albedo chmur (−) ◄──────────────── ┌─────────────┐
          │  │                                          │ ZACHMURZENIE│
          │  └── albedo lodu (+, tylko gdy zimno)       └─────────────┘
          │                                                    │
          └── albedo roślin (biomasa przyciemnia, ociepla)     ▼
                                                        ┌─────────────┐
                    wilgotność ◄── opady usuwają wodę ──│   OPADY     │
                                                        └─────────────┘
```

| Sprzężenie | Typ | Ograniczenie |
|---|---|---|
| lód → jasna planeta → zimniej → więcej lodu | dodatnie | równowaga radiacyjna, miękka podłoga |
| ciepło → parowanie → para wodna → cieplej | dodatnie | chmury, opady |
| wilgoć → chmury → odbicie światła → chłodniej | ujemne | — |
| chmury → opady → mniej wilgoci | ujemne | — |
| temperatura wraca do `base_temperature` | ujemne | — |

## Wzory

Skala 0..100, krok = 1 tick, tylko operacje z `SimMath`.

Temperatura:

```
lód(T)  = 1 − smoothstep(ice_full, ice_free, T)
cel_T   = base_temperature
        + season_amplitude · fala(tick)
        + dryf
        − ice_strength · lód(T)
        − cloud_albedo · (C − cloud_ref) / 100
        + vegetation_albedo · B / 100
        + greenhouse · (H − greenhouse_ref) / 100
ΔT      = thermal_response · (cel_T − T)
```

Każdy składnik to osobna delta z własną przyczyną. Miękka podłoga:
każdy składnik ochładzający jest mnożony przez `smoothstep(0, cold_floor, T)`,
więc przy bardzo niskiej temperaturze ochładzanie wygasa
(zimna planeta wypromieniowuje mało ciepła). Clamp do 0 jest tylko
zabezpieczeniem, nie mechanizmem.

Woda:

```
pojemność(T) = lerp(capacity_cold, capacity_warm, T/100)
rh           = clamp(H / pojemność, 0, 1)
parowanie    = evaporation_rate · water_availability · smoothstep(evap_cold, evap_warm, T) · (1 − rh)
ΔH           = parowanie − P · rain_efficiency
cel_C        = 100 · smoothstep(cloud_rh_low, cloud_rh_high, rh)
ΔC           = cloud_response · (cel_C − C)
cel_P        = 100 · smoothstep(rain_cloud_low, rain_cloud_high, C) · rh
ΔP           = precipitation_response · (cel_P − P)
```

Sezon i dryf:

```
fala(tick) = 1 − 4 · |(tick mod season_period_ticks) / season_period_ticks − 0.5|   (−1 zima, +1 lato)
dryf      ← clamp(dryf · (1 − drift_reversion) + rng(−drift_noise, drift_noise), ±drift_limit)
```

## Przyczyny w logach

| Parametr | Przyczyny |
|---|---|
| temperatura | `radiative_balance`, `season`, `climate_drift`, `ice_albedo`, `cloud_albedo`, `vegetation_albedo`, `greenhouse` |
| wilgotność | `evaporation`, `rainfall` (T ≥ `snow_temperature`) lub `snowfall` |
| zachmurzenie | `condensation`, `dissipation` |
| opady | `rain_forming`, `rain_easing` |

Delty równe zero są pomijane.

## Współczynniki (`climate.json`)

| Klucz | Wartość | Znaczenie |
|---|---|---|
| `base_temperature` | 37 | równowaga radiacyjna bez sprzężeń |
| `thermal_response` | 0.03 | jak szybko temperatura dąży do celu |
| `season_period_ticks` | 360 | długość roku (6 min przy x1); edytowalna, inny charakter planety |
| `season_amplitude` | 6 | siła sezonów |
| `drift_reversion`, `drift_noise`, `drift_limit` | 0.004, 0.5, 12 | wolne wahania klimatu |
| `ice_strength` | 22 | siła sprzężenia lód-albedo; od 22 w górę planeta ma dwa stabilne stany |
| `ice_full`, `ice_free` | 14, 30 | pełne zlodowacenie / brak lodu |
| `cloud_albedo`, `cloud_ref` | 12, 40 | chłodzenie przez chmury powyżej poziomu odniesienia |
| `vegetation_albedo` | 4 | ocieplenie przez ciemną roślinność |
| `greenhouse`, `greenhouse_ref` | 18, 40 | efekt cieplarniany pary wodnej |
| `water_availability` | 1.0 | dostępność wody; zastąpi ją parametr `ocean_level` |
| `evaporation_rate`, `evap_cold`, `evap_warm` | 1.2, 0, 60 | parowanie i jego zależność od temperatury |
| `capacity_cold`, `capacity_warm` | 25, 100 | ile pary mieści zimne / ciepłe powietrze |
| `cloud_rh_low`, `cloud_rh_high`, `cloud_response` | 0.35, 0.95, 0.08 | tworzenie chmur |
| `rain_cloud_low`, `rain_cloud_high`, `precipitation_response` | 35, 85, 0.25 | tworzenie opadów |
| `rain_efficiency` | 0.03 | ile wilgoci usuwają opady |
| `snow_temperature` | 20 | poniżej opady są śniegiem (przyczyna w logu) |
| `cold_floor` | 8 | szerokość miękkiej podłogi temperatury |

Walidacja (`ClimateConfig`): każdy klucz wymagany, nieznane klucze są błędem,
zakresy sprawdzane, szybkości reakcji ≤ 1 (relaksacja nigdy nie przestrzeliwuje
celu), progi uporządkowane (`ice_full < ice_free` itd.), rok jako liczba całkowita ≥ 2.

Inny charakter planety: osobny plik i `run_simulation.sh --climate <plik>`.

## Balans

Pomiar narzędziem `simulation/tests/tools/planet_report.gd --climate-only`
(8 seedów × 20 000 ticków, sam klimat, bez atmosfery i biosfery):

| Miara | Wynik |
|---|---|
| temperatura | 5.4–47.9, średnio 24–31 |
| czas w zlodowaceniu (T < 16) | 14–40% |
| zmiany reżimu ciepło ↔ lód | 9–15 na 18 000 ticków |
| ticki na granicy 0 | 0 |
| wilgotność / zachmurzenie / opady | 17–40 / 30–52 / 0–16 |

Dwa stabilne stany (bistabilność): bez dryfu i sezonów zamarznięta planeta
zostaje zamarznięta, a ciepła zostaje ciepła. Sam klimat wychodzi ze
zlodowacenia tylko dzięki dryfowi i sezonom. Z AtmosphereSystem zlodowacenie
kończy też cykl węglowy (sekcja niżej).

Planeta bez oceanu i biosfery jest sucha: opady do około 16 ("rzadkie deszcze").
Więcej wilgoci przyniesie transpiracja biosfery.

Historia strojenia: `ice_strength` 20 dawało tylko przejściowe ochłodzenia
(planeta sama wracała do ciepła po ~230 tickach), więc podniesiono do 22.
To z kolei powodowało dotykanie granicy 0 na niektórych seedach,
co rozwiązała miękka podłoga (`cold_floor`).

## Testy

- `tests/unit/climate_config_test.gd`, `tests/unit/climate_system_test.gd`:
  znak i obecność każdej przyczyny, sezon, miękka podłoga, determinizm, dryf
- `tests/integration/climate_behavior_test.gd`: reakcje łańcuchowe,
  bistabilność, widoczne sezony, edytowalny rok
- `tests/simulation/climate_balance_test.gd`: 8 seedów, kryteria balansu z tabeli

## Ograniczenia

- dryf i stan RNG nie przetrwają zapisu gry do czasu SaveSystem (krok 8)
- transpiracja należy do BiosphereSystem (tabela właścicieli w architekturze)
- złoty ślad nadal używa testowej dynamiki, nie ClimateSystem;
  determinizm klimatu sprawdza `climate_balance_test` (ten sam seed → ten sam hash)

---

# AtmosphereSystem

Pliki:

- `godot/simulation/atmosphere/atmosphere_system.gd`
- `godot/simulation/atmosphere/atmosphere_config.gd`
- `godot/resources/atmosphere/atmosphere.json`

Jest właścicielem dynamiki: tlenu, CO₂ i utlenienia skorupy (`crust_oxidation`).
Dokłada wkład `co2_greenhouse` do temperatury (pozwala na to tabela właścicieli).
Nie losuje i nie ma stanu wewnętrznego: czysta funkcja snapshotu, nic do zapisu.

## Wejścia i wyjścia

| | |
|---|---|
| Wejścia | snapshot: temperatura, wilgotność, opady, tlen, CO₂, skorupa; `atmosphere.json` |
| Wyjścia | delty dla tlenu, CO₂, skorupy oraz wkład do temperatury, każda z przyczyną |
| Nie dotyka | wilgotności, chmur, opadów (ClimateSystem), biomasy |

## Procesy

```text
           WULKANY ──(+CO₂)──►  ┌─────┐  ──(efekt cieplarniany)──► TEMPERATURA
                                │ CO₂ │                                │
  ciepło + deszcz ──► WIETRZENIE SKAŁ ──(−CO₂)◄────────────────────────┘

  para wodna ──(UV, fotoliza)──► ┌──────┐ ──► utlenia SKORUPĘ (słabnie, gdy się nasyca)
  [biosfera: fotosynteza] ─────► │ TLEN │ ──► gazy wulkaniczne zużywają tlen
                                 └──────┘
```

| Proces | Sprzężenie | Efekt w grze |
|---|---|---|
| termostat węglowy: wulkany +CO₂, wietrzenie (ciepło i deszcz) −CO₂ | ujemne, wolne (~1500 ticków) | długoterminowa stabilizacja klimatu |
| pod lodem nie ma deszczu ani wietrzenia, wulkany działają dalej | narasta aż do odwilży | zlodowacenie samo się kończy |
| świeża skorupa pochłania tlen, aż się utleni | próg przełomowy | "Wielkie Natlenienie" po pojawieniu się życia |

## Wzory

```
wulkany     = volcanic_co2                                                    → +CO₂     "volcanic_outgassing"
wietrzenie  = weathering_rate · CO₂/100 · smoothstep(weathering_cold, weathering_warm, T)
              · (weathering_dry + weathering_wet · P/100)                     → −CO₂     "silicate_weathering"
cieplarnia  = co2_greenhouse · (CO₂ − co2_ref) / 100                          → ±T       "co2_greenhouse"
fotoliza    = photolysis_rate · H/100                                         → +O₂      "photolysis"
skorupa     = crust_oxidation_rate · O₂/100 · (1 − skorupa/100)               → −O₂      "crust_oxidation"
              (to samo · crust_capacity                                        → +skorupa "crust_oxidation")
gazy        = volcanic_gas_sink · O₂/100                                      → −O₂      "volcanic_gases"
```

`co2_ref` = 40 = wartość startowa CO₂, więc przy starcie atmosfera nie zmienia
wyważonego klimatu, tylko dodaje nowe sprzężenie.

## Współczynniki (`atmosphere.json`)

| Klucz | Wartość | Znaczenie |
|---|---|---|
| `co2_greenhouse`, `co2_ref` | 0.3, 40 | siła efektu cieplarnianego CO₂ względem poziomu odniesienia |
| `volcanic_co2` | 0.03 | stała aktywność wulkanów (zastąpi ją parametr `geological_activity`) |
| `weathering_rate` | 0.5 | siła wietrzenia skał |
| `weathering_cold`, `weathering_warm` | 10, 50 | poniżej nie ma wietrzenia, powyżej jest pełne |
| `weathering_dry`, `weathering_wet` | 0.2, 1.0 | wietrzenie bez deszczu / wzmocnienie przez opady |
| `photolysis_rate` | 0.004 | tlen z rozkładu pary wodnej przez UV |
| `crust_oxidation_rate`, `crust_capacity` | 0.5, 0.05 | pochłanianie tlenu przez skorupę i tempo jej nasycania |
| `volcanic_gas_sink` | 0.02 | tlen zużywany przez gazy wulkaniczne |

Walidacja jak w klimacie (wspólny `CoefficientLoader`): wymagane klucze,
nieznane klucze są błędem, zakresy, `weathering_cold < weathering_warm`.
Inny charakter planety: `run_simulation.sh --atmosphere <plik>`.

## Balans

`planet_report.gd` (8 seedów × 20 000 ticków, klimat i atmosfera):

| Miara | Sam klimat | Klimat i atmosfera |
|---|---|---|
| najdłuższe zlodowacenie | 919–2328 ticków | 588–1589 |
| czas w lodzie | 17–35% | 16–28% |
| CO₂ | stałe 40 | 26–88 |
| tlen bez życia | 2,00 | ≤ 0,28 |
| utlenienie skorupy | 0 | ≤ 1,3 |
| ticki na granicy 0 | 0 | 0 |

Kluczowe zachowania (testy integracyjne):

- bez dryfu i sezonów zamarznięta planeta bez atmosfery zostaje zamarznięta,
  a z atmosferą rozmarza dzięki CO₂ z wulkanów
- ciepła, deszczowa planeta obniża CO₂ (termostat)
- przy tym samym producencie tlenu planeta z utlenioną skorupą ma ponad
  dwa razy więcej tlenu niż planeta ze świeżą skorupą
- planeta bez życia traci tlen (atmosfera sprzed życia)

## Testy

- `tests/unit/atmosphere_config_test.gd`, `tests/unit/atmosphere_system_test.gd`
- `tests/unit/coefficient_loader_test.gd`
- `tests/integration/atmosphere_behavior_test.gd`
- `tests/simulation/planet_balance_test.gd` (6 seedów, oba systemy)

## Ryzyka i wymagania dla następnych kroków

- **Tlen może uciec do 100** przy silnym producencie (prototyp: 0,2/tick).
  BiosphereSystem musi dodać pochłaniacze: oddychanie i pożary przy wysokim
  tlenie ("więcej tlenu = większe ryzyko pożarów"). Zapisane w `docs/biosphere.md`.
- Przy chłodnym pliku `--climate` CO₂ może dojść do 100; clamp będzie zgłoszony
  jako nasycenie w logu.
- Wkład `co2_greenhouse` nie podlega miękkiej podłodze klimatu; w chłodzie CO₂
  rośnie, więc wkład jest dodatni (test balansu pilnuje temperatury przy 0).

## Rozwój

| Krok `CLAUDE.md` | Co dołączy do atmosfery |
|---|---|
| 5. Biosphere | fotosynteza (+O₂, −CO₂), oddychanie, pożary; Wielkie Natlenienie |
| 7. Events | "odwilż wulkaniczna", "Wielkie Natlenienie", "zima wulkaniczna" |
| później | `pressure` (z sumy gazów), `geological_activity` (zmienne wulkany), ozon i promieniowanie UV |

## Zdarzenia (planowane, od EventSystem)

- OxygenChanged
- PressureChanged
- AtmosphereCrisis

---

# Reguły wspólne

- systemy nie znają się nawzajem
- czytają stan z końca poprzedniego ticka
- nie zapisują stanu bezpośrednio, tylko zwracają delty
- wartości zawsze w zakresach z ParameterDefs
- wszystkie współczynniki są w danych i (od ModifierRegistry) podlegają modyfikatorom

# Kompromisy projektowe

- więcej wilgoci = cieplej (para wodna), ale też więcej chmur (chłodniej)
- więcej roślin = cieplej (ciemniejsza powierzchnia)
- głębokie zlodowacenie = sucho (brak parowania), co samo utrudnia wyjście
