# Jak grać w Genesis Error (prototyp w konsoli)

Genesis Error to gra o prowadzeniu ewolucji żywej planety. Nie budujesz
niczego: obserwujesz, jak planeta żyje, stawiasz hipotezy i od czasu do czasu
delikatnie (albo mniej delikatnie) w nią ingerujesz. Nagrodą jest
zrozumienie, dlaczego planeta zachowuje się tak, a nie inaczej.

Na tym etapie gra działa w konsoli. Planeta toczy się sama i zatrzymuje się
w **punktach decyzji** (np. „wymarły mchy”). Wtedy czytasz, co się stało,
wybierasz akcję i puszczasz planetę dalej.

---

## 1. Uruchomienie

### Wymagania

- Windows z **Git Bash** (skrypty gry są w bashu)
- **Godot 4.7.2** w wersji konsolowej (już zainstalowany):
  `C:\Users\jkapk\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`

### Pierwsze uruchomienie

Otwórz Git Bash i wpisz:

```bash
cd /d/PythonProject_game
export GODOT_BIN="C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
./godot/run_simulation.sh --until decision --story
```

`export GODOT_BIN=...` trzeba wpisać w każdym nowym oknie Git Bash. Żeby
nie powtarzać tego za każdym razem, dopisz tę linię raz do pliku `~/.bashrc`:

```bash
echo 'export GODOT_BIN="C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"' >> ~/.bashrc
```

---

## 2. Pętla gry

Cała gra to powtarzanie dwóch komend:

```bash
# start nowej planety: graj do pierwszego punktu decyzji
./godot/run_simulation.sh --until decision --story

# odpowiedź na punkt decyzji: wczytaj, zrób akcję, graj do następnego
./godot/run_simulation.sh --load decision.json --act <akcja> --until decision --story
```

Nie musisz nic robić. Pominięcie `--act` puszcza planetę dalej bez ingerencji:

```bash
./godot/run_simulation.sh --load decision.json --until decision --story
```

### Przykładowa rozgrywka (seed 13, prawdziwy przebieg)

**Runda 1.** Start planety o numerze 13:

```text
$ ./godot/run_simulation.sh --seed 13 --until decision --story
# Kronika planety | seed 13
[Tick 1] Planeta budzi się. Niespokojna, wulkaniczna i płonąca: silne wahania klimatu, więcej CO₂ i pożarów. Życie ma trudniej.
[Tick 130] Pojawiają się bakterie.
=== Punkt decyzji: tick 130 ===
```

Planeta jest chaotyczna. Pojawiło się pierwsze życie. Gracz próbuje lekko
ją ogrzać.

**Runda 2.**

```text
$ ./godot/run_simulation.sh --load decision.json --act mirrors_warm:weak --until decision --story
[Tick 131] Gracz rozkłada lustra orbitalne (lekko): planeta dostaje więcej światła.
[Tick 333] Pojawiają się glony.
=== Punkt decyzji: tick 333 ===
```

Pojawiły się glony. Gracz chce przyspieszyć sukcesję i zasiewa mchy.

**Runda 3.**

```text
$ ./godot/run_simulation.sh --load decision.json --act seed_species:moss --until decision --story
[Tick 334] Gracz zasiewa mchy.
[Tick 334] Pojawiają się mchy.
[Tick 528] Wymierają mchy: brakuje tlenu.
=== Punkt decyzji: tick 528 ===
Planeta (skala 0-100): Temperatura 42.7, Wilgotność 36.6, Tlen 1.7, Biomasa 7.4, ...
Gatunki (populacja 0-100): bacteria 52.2, algae 47.7, moss 0.0 (wymarłe), shrub 0.0, tree 0.0
```

Mchy zginęły, bo w powietrzu jest dopiero 1,7 tlenu, a mchy potrzebują go
więcej. Lekcja: najpierw glony muszą natlenić planetę. Teraz mchy są
**wymarłe** i same prawie nie wrócą, więc jeśli gracz ich chce, musi je
kiedyś zasiać ponownie, gdy tlenu będzie więcej.

---

## 3. Jak czytać punkt decyzji

```text
=== Punkt decyzji: tick 528 ===
[Tick 528] Wymierają mchy: brakuje tlenu.                       <- co się stało i dlaczego
Planeta (skala 0-100): Temperatura 42.7, Wilgotność 36.6, ...   <- stan planety teraz
Zapis: D:/PythonProject_game/saves/decision.json                <- tu jest zapisana gra
Interwencje:
  seed_species:<species>                   Zasiew gatunku           gotowe
  mirrors_warm[:weak|medium|strong]        Lustra orbitalne         od ticku 1631   <- jeszcze się ładuje
  ...
Gatunki (populacja 0-100): bacteria 52.2, algae 47.7, moss 0.0 (wymarłe), ...
Dalej: ./godot/run_simulation.sh --load decision.json --act <interwencja> --until decision --story
```

- **gotowe**: akcję można użyć teraz
- **od ticku N**: akcja się odnawia (cooldown); komenda z nią zostanie odrzucona
- **(wymarłe)**: gatunek zniknął i sam prawie nie wróci

Punkt decyzji wypada przy: **początku zdarzenia** (np. suszy),
**wymarciu gatunku**, **pojawieniu się gatunku**. Przez pierwsze 100 ticków
po każdej Twojej akcji planeta się nie zatrzymuje, żebyś zdążył zobaczyć
skutki.

---

## 4. Akcje gracza

Akcję dodajesz opcją `--act`. Można podać kilka naraz:
`--act seed_species:algae --act aquifer_release`.

| Komenda | Nazwa | Co robi | Trwa | Odnowienie |
|---|---|---|---|---|
| `seed_species:<gatunek>` | Zasiew gatunku | dodaje 5 punktów populacji gatunku (przywraca wymarłe) | od razu | 300 |
| `cull_species:<gatunek>` | Przerzedzenie | zostawia 10% populacji; poniżej progu gatunek wymiera | od razu | 300 |
| `mirrors_warm[:poziom]` | Lustra orbitalne | ogrzewa planetę: +2 / +4 / +8 do temperatury, do której dąży klimat | 500 | 1500 (wspólne z pyłem) |
| `mirrors_cool[:poziom]` | Pył orbitalny | ochładza: −2 / −4 / −8 | 500 | 1500 (wspólne z lustrami) |
| `cloud_seeding` | Zasiew chmur | deszcz pada nawet z rzadkich chmur | 300 | 900 |
| `aquifer_release` | Wody podziemne | ląd paruje 2,5 raza mocniej, rośnie wilgotność | 300 | 900 |
| `volcanic_awakening` | Przebudzenie wulkanów | wulkany wydzielają 3 razy więcej CO₂ | 400 | 2000 |

Czasy podane są w tickach.

**Gatunki** (do `seed_species` i `cull_species`): `bacteria` (bakterie),
`algae` (glony), `moss` (mchy), `shrub` (krzewy), `tree` (drzewa).

**Poziomy siły** luster i pyłu: `weak` (lekko), `medium` (umiarkowanie),
`strong` (z pełną mocą, domyślny). Przykład: `--act mirrors_cool:weak`.

### Co wiadomo o akcjach (z pomiarów na wielu planetach)

- **Wody podziemne** to dobra odpowiedź na **suszę**. W innych kryzysach
  potrafią zaszkodzić.
- **Zasiew chmur w suszy szkodzi**: deszcz wyciąga wodę z powietrza, a mchy
  i glony żyją z wilgotności powietrza. Pomaga krzewom i drzewom, które żyją
  z opadów.
- **Lekkie lustra** częściej pomagają, niż szkodzą. Pełna moc to ryzyko.
  Ochłodzenie o 8 potrafi wywołać epokę lodową (lód odbija światło
  i wzmacnia chłód nawet trzykrotnie).
- **Zasiew wymarłego gatunku** opłaca się, gdy przyczyna wymarcia minęła.
  Mchy wracają prawie zawsze, krzewy i drzewa często giną ponownie.
- **Zasiew drzew za wcześnie** zawsze się nie udaje: drzewa potrzebują dużo
  tlenu i gleby.
- **Wulkany** ocieplają planetę na długo (CO₂ zostaje w atmosferze).

---

## 5. Mechaniki planety

### Parametry (skala 0-100)

| Parametr | Start | Co znaczy |
|---|---|---|
| Temperatura | 30 | 0 zamarznięta, 50 optimum, 100 wrząca |
| Wilgotność | 15 | woda w powietrzu; z niej żyją bakterie, glony, mchy |
| Tlen | 2 | wytwarzany przez życie; powyżej ok. 22 zaczynają się pożary |
| Biomasa | 0 | suma życia na planecie |
| Zachmurzenie | 10 | chmury ochładzają i dają deszcz |
| Opady | 0 | deszcz; z niego żyją krzewy i drzewa |
| Dwutlenek węgla | 40 | efekt cieplarniany i pokarm roślin |
| Utlenienie skorupy | 0 | dopóki skorupa jest świeża, pochłania tlen |

Jeden **tick** to jeden krok symulacji. Rok ma 360 ticków (pory roku).

### Gatunki i sukcesja

Gatunki pojawiają się po kolei: każdy (oprócz bakterii) potrzebuje
poprzednika, z którego „wyrasta”.

| Gatunek | Temperatura | Woda | Potrzebuje | Wyrasta z |
|---|---|---|---|---|
| bakterie | 5-70 | wilgotność ≥ 5 | nic; giną przy dużej ilości tlenu (zostają w niszach) | samo |
| glony | 10-45 | wilgotność ≥ 20 | CO₂ | bakterii |
| mchy | 5-35 | wilgotność ≥ 22 | CO₂, trochę tlenu, trochę gleby (biomasy) | glonów |
| krzewy | 15-45 | opady ≥ 5 | tlen ≥ 12, gleba ≥ 12 | mchów |
| drzewa | 20-45 | opady ≥ 8 | tlen ≥ 18, gleba ≥ 20 | krzewów |

Wyższe rośliny zacieniają niższe (krzewy i drzewa dławią mchy). Krzewy
i drzewa łatwo płoną.

### Wymieranie

Kronika zawsze podaje przyczynę: za gorąco, za zimno, brakuje wody,
brakuje CO₂, brakuje tlenu, za mało gleby, pożary, cień wyższych roślin,
nadmiar tlenu, naturalne obumieranie albo ręka gracza.

**Wymieranie jest prawie trwałe**: wymarły gatunek odradza się sam z siłą
tylko 1% dawnej. Może to trwać tysiące ticków albo nie nastąpić wcale.
Możesz go przywrócić zasiewem („Wracają mchy.”). Bez mchów nie pojawią się
krzewy, a bez krzewów drzewa.

### Zdarzenia

- **Susza**: gdy jest ciepło (powyżej 22), a wilgotność spada wyraźnie
  poniżej swojej normy. Mniej wody, rośliny rosną wolniej (×0,6), pożarów
  jest dwa razy więcej. Mija, gdy wilgotność wróci do normy (najpóźniej po
  400 tickach).
- **Planeta leczy się** (tylko Strażnik): gdy biomasa spadnie o ponad 30%
  od szczytu, życie przez pewien czas rośnie szybciej i lepiej znosi stres.

### Charakter planety

Każda planeta losuje charakter z numeru seed (albo ustawiasz go opcją
`--personality`):

| Charakter | Opis |
|---|---|
| `harmonious` (Harmonijna) | łagodna i bujna: spokojniejszy klimat, szybszy wzrost, rzadsze pożary |
| `chaotic` (Chaotyczna) | niespokojna, wulkaniczna i płonąca: wahania klimatu, więcej CO₂ i pożarów |
| `guardian` (Strażnik) | klimat szybciej wraca do normy, życie lepiej znosi stres, planeta leczy rany |

### Klimat w skrócie

- **Termostat węglowy**: wulkany dodają CO₂, wietrzenie skał go zabiera
  (szybciej, gdy jest ciepło i mokro). Dlatego planeta po ociepleniu powoli
  wraca.
- **Lód**: gdy robi się zimno, lód odbija światło i chłodzi jeszcze
  bardziej. Tak zaczynają się epoki lodowe.
- **Obieg wody**: parowanie, chmury i deszcz same się równoważą. Dlatego
  wilgotność trudno ruszyć.
- **Tlen**: najpierw pochłania go świeża skorupa planety. Dopiero gdy się
  utleni, tlen gromadzi się w powietrzu. Przy wysokim tlenie płoną lasy.

---

## 6. Wszystkie opcje

| Opcja | Znaczenie |
|---|---|
| `--until decision` | zatrzymaj w pierwszym punkcie decyzji i zapisz grę |
| `--story` | pokazuj kronikę (zdania) zamiast pełnego logu technicznego |
| `--act AKCJA` | wykonaj akcję na starcie przebiegu (można kilka razy) |
| `--load PLIK` | wczytaj zapis (np. `decision.json`) |
| `--save PLIK` | zapisz grę pod własną nazwą (na końcu lub w punkcie decyzji) |
| `--seed N` | numer planety (każdy numer to inna planeta) |
| `--personality NAZWA` | `harmonious`, `chaotic`, `guardian`, `random`, `none` |
| `--ticks N` | limit ticków przebiegu (domyślnie 3600) |
| `--autosave N` | autozapis co N ticków (0 = wyłączony) |
| `--quiet` | nic nie wypisuj w trakcie |

`--load` bierze seed i charakter z zapisu, więc nie łączy się z `--seed`
ani `--personality`.

### Eksperyment „co, jeśli…”

`decision.json` jest nadpisywany przy każdym punkcie decyzji. Żeby
sprawdzić dwie różne odpowiedzi na ten sam kryzys, zachowaj kopię:

```bash
cp saves/decision.json saves/kryzys.json
./godot/run_simulation.sh --load kryzys.json --act aquifer_release --until decision --story
./godot/run_simulation.sh --load kryzys.json --act cloud_seeding --until decision --story
```

Ten sam zapis z tą samą akcją zawsze daje ten sam wynik (symulacja jest
deterministyczna), więc różnice wynikają wyłącznie z Twojej decyzji.

---

## 7. Pliki

| Gdzie | Co |
|---|---|
| `saves/decision.json` | ostatni punkt decyzji |
| `saves/<przebieg>.autosave.json` | autozapis co 1000 ticków |
| `logs/simulation_runs/<przebieg>.chronicle.txt` | kronika całego przebiegu |
| `logs/simulation_runs/<przebieg>.log` | pełny log: każda zmiana każdego parametru z przyczyną |
| `logs/simulation_runs/<przebieg>.jsonl` | to samo dla narzędzi (JSON Lines) |

---

## 8. Gdy coś nie działa

| Objaw | Rozwiązanie |
|---|---|
| `GODOT_BIN is not set` | wpisz `export GODOT_BIN=...` (rozdział 1) |
| `save file not found` | najpierw zagraj bez `--load` albo sprawdź nazwę w `saves/` |
| `... is not ready: available from tick N` | akcja się odnawia, wybierz inną albo poczekaj |
| `--load takes seed and personality from the save` | usuń `--seed` / `--personality` przy `--load` |
| `No decision point within 3600 ticks.` | planeta była spokojna; zwiększ limit, np. `--ticks 20000` |
| kod wyjścia 1, „halted” | błąd symulacji: zachowaj log z `logs/simulation_runs/` |

---

## 9. Ograniczenia prototypu

- brak grafiki: planetę poznajesz z kroniki i liczb
- akcja zawsze zaczyna działać w następnym ticku po punkcie decyzji
- nie ma celów ani wygranej: grasz, żeby zrozumieć planetę („ciekawe, co
  się stanie, jeśli…”)
