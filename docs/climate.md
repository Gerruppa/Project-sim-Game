# Klimat i atmosfera

Wersja: 2.0

Dotyczy ClimateSystem (zaimplementowany) i AtmosphereSystem (planowany).
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

Pomiar narzędziem `simulation/tests/tools/climate_report.gd`
(8 seedów × 20 000 ticków, bez biosfery):

| Miara | Wynik |
|---|---|
| temperatura | 5.4–47.9, średnio 24–31 |
| czas w zlodowaceniu (T < 16) | 14–40% |
| zmiany reżimu ciepło ↔ lód | 9–15 na 18 000 ticków |
| ticki na granicy 0 | 0 |
| wilgotność / zachmurzenie / opady | 17–40 / 30–52 / 0–16 |

Dwa stabilne stany (bistabilność): bez dryfu i sezonów zamarznięta planeta
zostaje zamarznięta, a ciepła zostaje ciepła. Wyjście ze zlodowacenia wymaga
dryfu, sezonu, a w przyszłości biosfery lub interwencji gracza.

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

# AtmosphereSystem (planowany)

## Odpowiedzialność

- regulacja tlenu
- stabilność atmosfery
- ciśnienie (przyszłość)

Jest właścicielem dynamiki tlenu.

## Wejścia

- snapshot (tlen, biomasa, temperatura)
- efektywne współczynniki

## Wyjścia

Delty dla tlenu (przyszłość: ciśnienie, CO₂).

## Zdarzenia

- OxygenChanged
- PressureChanged
- AtmosphereCrisis

## Zależności

- biomasa i gatunki → tlen (strumień produkcji z BiosphereSystem)
- tlen → rozwój życia (przez BiosphereSystem)
- temperatura → zanik i rozpuszczanie gazów

Biosfera nie ma własnej kopii tlenu.
Gatunek zwraca strumień produkcji jako deltę z przyczyną.
Regulację i zanik wykonuje AtmosphereSystem.

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
