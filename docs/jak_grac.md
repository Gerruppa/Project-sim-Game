# Jak grać w Genesis Error (prototyp w konsoli)

Genesis Error to gra o prowadzeniu ewolucji żywej planety. Nie budujesz
niczego: obserwujesz, jak planeta żyje, stawiasz hipotezy i od czasu do czasu
delikatnie (albo mniej delikatnie) w nią ingerujesz. Nagrodą jest
zrozumienie, dlaczego planeta zachowuje się tak, a nie inaczej.

Na tym etapie gra działa w konsoli. Planeta toczy się sama i zatrzymuje się
w **punktach decyzji** (np. „wymarły mchy”). Wtedy czytasz, co się stało,
dostajesz podpowiedź, wybierasz akcję z menu i puszczasz planetę dalej.

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
./godot/play_window.sh     # gra w oknie
./godot/play.sh            # albo w konsoli
```

To wszystko: gra pokaże wstęp, a potem będzie pytać, co robisz.

`export GODOT_BIN=...` trzeba wpisać w każdym nowym oknie Git Bash. Żeby
nie powtarzać tego za każdym razem, dopisz tę linię raz do pliku `~/.bashrc`:

```bash
echo 'export GODOT_BIN="C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"' >> ~/.bashrc
```

---

## 2. Gra w oknie (najwygodniej)

```bash
./godot/play_window.sh                 # nowa planeta w oknie
./godot/play_window.sh --seed 13       # konkretna planeta
./godot/play_window.sh --load decision.json
```

Okno pokazuje planetę na żywo:

- **rysunek planety**: kolor zależy od temperatury, przy zimnie rosną białe
  czapy lodowe, zielone plamy to życie (biomasa), białe kropki to chmury,
  niebieska poświata to tlen
- **wykres** temperatury, wilgotności, tlenu, biomasy i CO₂ w czasie
- **tabele** parametrów i gatunków z paskami i strzałkami zmian od
  ostatniej decyzji
- **kronika** planety (prawa kolumna) i **cel** z ambicjami (pod planetą)
- **panel decyzji** na dole: gra sama się zatrzymuje w punkcie decyzji,
  pokazuje, co się stało, i podpowiedź; akcje to przyciski (gatunek i siłę
  wybierasz z listy obok przycisku), **Dalej ▶** puszcza planetę dalej
- **x10 / x100 / x1000**: tempo (ticków na sekundę), **Pauza**: zatrzymaj
  w dowolnej chwili i działaj

Gra zapisuje się w każdym punkcie decyzji (`saves/decision.json`), tak samo
jak w konsoli; zapis z okna wczytasz też w konsoli i odwrotnie.

## 2a. Gra w konsoli z menu

```bash
./godot/play.sh                      # nowa planeta (charakter losowy)
./godot/play.sh --seed 13            # konkretna planeta (każdy numer to inna)
./godot/play.sh --load decision.json # wróć do zapisanej gry
./godot/play.sh --no-hints           # bez podpowiedzi (w grze przełączasz je klawiszem h)
./godot/play.sh --full-logs          # także pełne logi techniczne (duże)
```

W każdym punkcie decyzji gra pokazuje:

```text
=== Punkt decyzji: tick 333 (rok 1) ===
Co się stało:  Pojawiają się glony.
Planeta (zmiana od poprzedniej decyzji, 203 ticki temu):
  Temperatura            31.0   ↓ 9.5
  Wilgotność             30.8   ↓ 5.4
  Tlen                    0.5   ↓ 0.6
  Biomasa                 1.3   ↑ 1.3
  Zachmurzenie           47.2   ↓ 2.4
  Opady                   9.6   ↓ 2.4
  Dwutlenek węgla        37.4   ↓ 2.8
  Utlenienie skorupy      0.2   ↑ 0.1
Życie:
  bakterie        24   ↑ 23
  glony            1   nowe
  mchy             –
  krzewy           –
  drzewa           –

Podpowiedź:
 • Następny etap życia: mchy. Brakuje: tlenu (0.5, potrzeba ok. 2), gleby, czyli biomasy (1.3, potrzeba 3).

Co robisz?
 1) Zasiew gatunku             gotowe
 2) Przerzedzenie gatunku      gotowe
 3) Lustra orbitalne           gotowe
 4) Pył orbitalny              gotowe
 5) Zasiew chmur               gotowe
 6) Wody podziemne             gotowe
 7) Przebudzenie wulkanów      gotowe
 0) Czekaj, nic nie rób (albo Enter)
 ?) Wyjaśnij akcje   h) Ukryj podpowiedzi   q) Zapisz i wyjdź
>
```

- **strzałki** pokazują, co się zmieniło od poprzedniego punktu decyzji:
  `↑`/`↓` z wielkością zmiany, `=` gdy nic się nie zmieniło; gatunki mają
  statusy **nowe**, **wróciły** i **wymarły od ostatniej decyzji**. Tak
  widać skutki Twojej ostatniej akcji (na pierwszym ekranie strzałek nie ma)
- wpisz **numer akcji** i Enter; gra dopyta o gatunek (z informacją, czego
  mu brakuje) albo o siłę (Enter = domyślna)
- możesz zrobić **kilka akcji** w jednym punkcie decyzji; **Enter** albo
  **0** puszcza planetę dalej
- **?** wyjaśnia każdą akcję jednym zdaniem, **c** pokazuje cele,
  gwiazdki i ambicje, **h** ukrywa i pokazuje podpowiedzi, **q** zapisuje
  i kończy
- gra **zapisuje się sama** w każdym punkcie decyzji (`saves/decision.json`),
  więc możesz przerwać w dowolnej chwili (także zamykając okno)
- gdy przez 5000 ticków nic się nie dzieje, gra i tak się zatrzyma

**Podpowiedzi** mówią trzy rzeczy: dlaczego coś się stało (przyczyna
wymarcia), co może pomóc (na podstawie pomiarów na wielu planetach, np.
„w suszy pomagają wody podziemne”) i czego brakuje następnemu etapowi życia
(np. „mchom brakuje tlenu: 0.5, potrzeba ok. 2”). Podpowiedź to wskazówka,
nie przepis: planeta potrafi zaskoczyć.

### Cel gry, gwiazdki i ambicje

**Cel główny: Dojrzała planeta.** Wygrywasz, gdy wszystkie pięć etapów
życia (bakterie, glony, mchy, krzewy, drzewa) żyje jednocześnie przez
2 lata (720 ticków). Ekran pokazuje postęp:

```text
Cel:           Dojrzała planeta: etapy życia 3/5, brakuje: krzewy, drzewa
Ambicje:       1/7: Ogrodnik
```

Po wygranej gra mówi, w którym roku się udało i ile gwiazdek zdobyłeś,
i pozwala grać dalej (ambicje wciąż czekają).

**Gwiazdki** (za styl ogrodnika, każda osobno):

| Gwiazdka | Warunek |
|---|---|
| Bez strat | żaden gatunek nie wymarł |
| Szybko | wygrana przed rokiem 30 |
| Lekką ręką | od 1 do 5 akcji, a lustra i pył tylko lekko |

Bez żadnej akcji zdobędziesz najwyżej dwie gwiazdki (od tego jest
ambicja „Nie ruszaj”). Trzy gwiazdki to sztuka kilku dobrych, lekkich
decyzji bez straty gatunku.

**Ambicje** (dodatkowe osiągnięcia, lista pod klawiszem **c**):

| Ambicja | Warunek |
|---|---|
| Oddech planety | tlen powyżej 15 przed rokiem 13 |
| Pierwszy las | drzewa z populacją powyżej 10 |
| Przetrwać zimę | epoka lodowa minęła bez wymarcia, przy co najmniej 4 etapach życia |
| Po pożarze | po sezonie pożarów drzewa mają populację co najmniej 10 |
| Ogrodnik | przywróć zasiewem gatunek, który wymarł |
| Ujarzmić chaos | drzewa na planecie chaotycznej |
| Nie ruszaj | dojrzała planeta bez żadnej akcji |

Planety różnią się trudnością: łagodne i Strażnik często dojrzewają same,
na chaotycznej drzewa bez Twojej pomocy się nie pojawiają.

## 3. Gra komendami (dla zaawansowanych)

Ta sama gra bez menu, wygodna do eksperymentów i skryptów.
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

## 4. Jak czytać punkt decyzji (tryb komend)

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

Punkt decyzji wypada przy: **początku zdarzenia** (susza, epoka lodowa,
przegrzanie, sezon pożarów),
**wymarciu gatunku**, **pojawieniu się gatunku**. Przez pierwsze 100 ticków
po każdej Twojej akcji planeta się nie zatrzymuje, żebyś zdążył zobaczyć
skutki.

---

## 5. Akcje gracza

W grze z menu wybierasz akcje numerem. W trybie komend dodajesz je opcją `--act`. Można podać kilka naraz:
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

## 6. Mechaniki planety

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
- **Epoka lodowa**: gdy średnia temperatura spadnie poniżej 16. Rośliny
  rosną wolniej i gorzej znoszą zimno. Lekkie lustra pomagały w większości
  epok, mocne często szkodziły.
- **Przegrzanie**: gdy średnia temperatura przekroczy 40. Upał spowalnia
  wzrost. Pomagały lekki pył i wody podziemne.
- **Sezon pożarów**: gdy jest dużo tlenu, sucho i jest co palić. Rośliny
  zapalają się od byle iskry: płoną głównie drzewa, a krzewy zajmują ich
  miejsce. Żadna akcja nie pomagała wyraźnie.
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

## 7. Wszystkie opcje (tryb komend)

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

## 8. Pliki

| Gdzie | Co |
|---|---|
| `saves/decision.json` | ostatni punkt decyzji |
| `saves/<przebieg>.autosave.json` | autozapis co 1000 ticków |
| `logs/simulation_runs/<przebieg>.chronicle.txt` | kronika całego przebiegu |
| `logs/simulation_runs/<przebieg>.log` | pełny log: każda zmiana każdego parametru z przyczyną (tryb komend; w grze z menu tylko z `--full-logs`) |
| `logs/simulation_runs/<przebieg>.jsonl` | to samo dla narzędzi, JSON Lines (jak wyżej) |

Pełne logi są duże: długa gra to nawet 100 MB. Dlatego gra z menu
domyślnie zapisuje tylko kronikę. Stare logi możesz bezpiecznie usuwać.

---

## 9. Gdy coś nie działa

| Objaw | Rozwiązanie |
|---|---|
| `GODOT_BIN is not set` | wpisz `export GODOT_BIN=...` (rozdział 1) |
| gra z menu nie reaguje na wpisany numer | naciśnij Enter po numerze; wpisz `q`, żeby wyjść z zapisem |
| `save file not found` | najpierw zagraj bez `--load` albo sprawdź nazwę w `saves/` |
| `... is not ready: available from tick N` | akcja się odnawia, wybierz inną albo poczekaj |
| `--load takes seed and personality from the save` | usuń `--seed` / `--personality` przy `--load` |
| `No decision point within 3600 ticks.` | planeta była spokojna; zwiększ limit, np. `--ticks 20000` |
| kod wyjścia 1, „halted” | błąd symulacji: zachowaj log z `logs/simulation_runs/` |

---

## 10. Ograniczenia prototypu

- brak grafiki: planetę poznajesz z kroniki i liczb
- akcja zawsze zaczyna działać w następnym ticku po punkcie decyzji
- cele są proste (jeden cel główny, trzy gwiazdki, siedem ambicji); dalej
  najważniejsze jest zrozumienie planety („ciekawe, co się stanie, jeśli…”)
