# Genesis Error: nowy rdzeń gry (spec)

Data: 2026-10-06. Status: do akceptacji.
Zastępuje: `docs/CORE_LOOP.md`, `docs/vision.md`, `docs/DESIGN_PRINCIPLES.md`
oraz sekcje filozofii w `CLAUDE.md` (po akceptacji; patrz "Zmiany w dokumentach").

---

# 1. Zamiar

Gra strategiczna w stylu Plague Inc, z odwróconym celem: **stworzyć bujne życie**.
Dla gracza, który chce działać, rosnąć w siłę i reagować na kryzysy, a nie
tylko obserwować. Obecny prototyp ma dobrą symulację, ale gra nie wciąga:
brakuje ciągłej akcji, rosnącej siły, widocznej ekspansji, przeciwnika i zegara.

**Fabuła.** Ludzkość wątpi w sens istnienia boga i twierdzi, że byle gamoń
z boskimi mocami stworzyłby życie. Creator mianuje gracza tymczasowym
Praktykantem i daje mu pustą planetę oraz 200 lat. Gdy Praktykantowi idzie
dobrze, Creator przyspiesza kataklizmy.

**Platforma.** Godot 4.7.2, GDScript, wydanie na Steamie.

**Decyzje użytkownika (2026-10-06):**
- wszystkie dotychczasowe założenia i `CLAUDE.md` można zmienić,
- wzorem jest Plague Inc (perki, start, rozprzestrzenianie, kryzysy),
- **symulacja zostaje globalna** (bez regionów); rozprzestrzenianie opiera się
  na kontynentach i pojemności gatunków (rozdział 4),
- do nowej koncepcji bierzemy tylko to, co jest dla niej istotne.

---

# 2. Pętla gry

| Poziom | Co robi gracz | Wzór z Plague Inc |
|---|---|---|
| Sekundy | zbiera bąbelki na globusie i dostaje **Iskry Życia** | bąbelki DNA |
| 1-2 minuty | kupuje perki, używa boskich mocy, reaguje na ostrzeżenie o kryzysie | ewolucja, zdarzenia |
| 5 minut | wybiera kierunek (drzewko) i tempo wzrostu, bo szybki wzrost drażni Creatora | ukrycie kontra zabijanie |
| partia (15-25 min) | 200 lat: od pustej planety do Próby Ostatecznej | jedna rozgrywka |
| meta | Dziedzictwo odblokowuje planety, perki startowe, trudność | geny, scenariusze |

Skala czasu: 1 rok = 360 ticków, partia = 72 000 ticków. Cel 15-25 minut
oznacza średnio ok. 50-80 ticków na sekundę, więc dodajemy tempo x50
do listy x1/x5/x10/x25/x100.

---

# 3. Mechaniki

## 3.1 Start

Gracz wybiera **planetę** (scenariusz, rozdział 6) i **miejsce lądowania**.
Miejsce lądowania to dane: kontynent startowy oraz modyfikator startu
(np. komin hydrotermalny: bakterie startują z większą populacją;
płytkie morze: glony wcześniej). Brak regionów w symulacji: lądowanie
ustawia kontynent, od którego liczy się zasięg, i warunki początkowe.

## 3.2 Iskry Życia (waluta)

Źródła:
- **bąbelki** pojawiające się na globusie: Rozkwit (gatunek przekroczył
  próg populacji), Mutacja (rozdział 3.4), Odkrycie (pierwsze pojawienie się
  gatunku, pierwsze zasiedlenie kontynentu),
- pasywnie: mały dochód proporcjonalny do biomasy.

Bąbelek znika po 15 sekundach (w czasie rzeczywistym), więc gra
nagradza uwagę.

Cele pomiarowe (do sprawdzenia botem i testerami): 4-6 bąbelków na minutę,
pierwszy perk do 30 sekund od startu, ok. 20 kupionych perków w partii.

## 3.3 Drzewka perków

Perk ma koszt w Iskrach, wymagania (próg parametru planety albo inny perk),
skutek uboczny i można go cofnąć za część kosztu.

| Drzewko | Treść | Mechanizm w symulacji |
|---|---|---|
| **Środowisko** | boskie moce: lustra, pył, zasiew chmur, wody podziemne, wulkany | modyfikatory klimatu i atmosfery (dziś `InterventionSystem`) |
| **Życie** | cechy gatunków: odporność na suszę i mróz, szybszy wzrost, niższa palność | modyfikatory współczynników gatunku (`growth_scale`, `stress_scale`, `fire_rate`) |
| **Dyspersja** | zarodniki, nasiona na wietrze, przekroczenie oceanu | zwiększa zasięg gatunku (rozdział 4) |
| **Ekosystem** | rozkładacze, zapylacze, owady, płazy, ssaki | nowe gatunki-konsumenci (etap 5, osobna decyzja) |

Boskie moce z drzewka Środowisko zachowują cooldowny, bo w Plague Inc też
są ograniczone, a gracz kupuje dostęp, nie zasób.

## 3.4 Mutacje

Losowe zdarzenie z przyczyną w stanie planety (nie z samego rzutu kostką).
Co ok. 5 lat gry, przy warunku `change` biomasy lub tlenu powyżej progu,
losujemy (z `SeededRng`) jedną z 3 mutacji: bonus, ryzykowny bonus albo
neutralna ciekawostka. Mutacja pojawia się jako bąbelek do kliknięcia.

---

# 4. Rozprzestrzenianie bez regionów

Symulacja zostaje globalna. Zasięg życia modeluje **dostępna część planety**.

- **Kontynenty** (5-7, z numeru planety) stają się danymi rozgrywki:
  `id`, `area` (udział w lądzie), `neighbors` (sąsiedztwo i bariery:
  ocean, góry, pustynia).
- Każdy gatunek ma `reach` (0-1): suma `area` osiągniętych kontynentów.
  **Efektywna pojemność** = `capacity × reach`. Start: tylko kontynent
  lądowania.
- Perki dyspersji dodają kontynenty do zasięgu: zarodniki (mchy, glony,
  sąsiednie kontynenty), nasiona na ptakach (krzewy i drzewa),
  pływające nasiona (przez ocean). Zasięg rośnie tak, jak rośnie `reach`
  w modyfikatorze `biosphere.reach` (nowy cel modyfikatora).
- **Wizualizacja:** globus rysuje pokrycie `P / capacity` na osiągniętych
  kontynentach w kolejności odległości od lądowania. Mapa wypełnia się
  kolorem gatunków, jak zaraza w Plague Inc.
- Bąbelki pojawiają się w losowych miejscach osiągniętych kontynentów
  (kosmetycznie), a efekt jest globalny.

Konsekwencje: dyspersja ma prawdziwy efekt mechaniczny (pojemność, więc
biomasa i tlen), a symulacja nie wymaga przepisania na komórki.
Ograniczenie, które akceptujemy: skutki klimatu są globalne, więc nie ma
decyzji lokalnych ("susza tylko na kontynencie A"). Jeśli testy pokażą,
że tego brakuje, rozważamy regiony jako osobny etap.

---

# 5. Creator: przeciwnik, Próby, wygrana i porażka

## 5.1 Gniew Creatora

Widoczny miernik 0-100. **Wartość pochodna od stanu planety:** tempo wzrostu
biomasy w oknie (miara `change` z `EventCondition`, jak w obecnych
zdarzeniach). Im szybciej rośniesz, tym większy Gniew. Wolniejszy wzrost
obniża go z czasem. To odpowiednik wykrycia w Plague Inc.

## 5.2 Próby (kataklizmy)

Próba to **zdarzenie świata** z obecnego `EventSystem`:
warunek startu, faza Pending, Active, Cooldown, modyfikatory i `story`.
Dostosowanie: warunek zawiera Gniew (czyli `change` biomasy).

- **Faza Pending = zapowiedź.** Warunek musi trwać `for_ticks`
  (ok. 20-40 sekund przy tempie gry). Gracz widzi ostrzeżenie i może
  **odwrócić Próbę**, zwalniając wzrost albo kupując odpowiedni perk.
- **Eskalacja:** kolejne Próby mają wyższe progi biomasy i silniejsze
  modyfikatory. Idzie dobrze, więc Creator przyspiesza.
- Każda Próba ma przeciwdziałanie w drzewkach (np. epoka lodowa:
  lustra i perk mrozoodporności; katastrofa tlenowa: perk niszy beztlenowej;
  pożary: perk niepalności).

Katalog Prób v1: epoka lodowa, przegrzanie, susza, sezon pożarów
(wszystkie istnieją w `events.json`), katastrofa tlenowa, uderzenie
meteorytu (nowe).

## 5.3 Próba Ostateczna

Jedyny element skryptowany: w roku 200 (tick 72 000) Creator sprowadza
największy kataklizm (meteoryt plus zima wulkaniczna). Skryptowanie
jest uzasadnione terminem fabularnym.

## 5.4 Wskaźnik Życia i wynik

**Wskaźnik Życia (0-100):** suma po gatunkach `weight_i × min(1, P_i / próg_i)`
plus premia za liczbę gatunków żyjących jednocześnie.

- **Wygrana:** po Próbie Ostatecznej Wskaźnik Życia ≥ 60 i co najmniej
  4 gatunki żyją.
- **Porażka:** biomasa spada poniżej 2 na 5 lat gry albo po Próbie
  Ostatecznej Wskaźnik Życia < 60.
- Porażka kończy partię, ale daje Dziedzictwo (5.6).

## 5.5 Wiara ludzkości

Lekki element fabularny: nagłówki z reakcją ludzkości na kluczowe
wydarzenia i ekran końcowy z werdyktem ("Teza obroniona" lub "Creator miał
rację"). Nie wpływa na symulację.

## 5.6 Dziedzictwo

Po każdej partii punkty Dziedzictwa (za Wskaźnik Życia, liczbę Prób
przetrwanych, szybkość) odblokowują planety, startowe perki i poziomy
trudności (częstotliwość i siła Prób, zasób Iskier).

---

# 6. Scenariusze (planety)

Planeta to zestaw plików danych (`--climate`, `--atmosphere`, współczynniki
gatunków, lista kontynentów, katalog Prób). Pierwsze trzy:

1. **Pierwsza Zupa** (tutorial): ciepła, wilgotna, łagodne Próby.
2. **Czerwona Planeta** (Mars): zimna, mało CO₂; lustra i wulkany są kluczowe.
3. **Śnieżka**: zamarznięta, trzeba wywołać ocieplenie, zanim życie ruszy.

Archetypy osobowości (Harmonijna, Chaotyczna, Strażnik) stają się cechami
planet w scenariuszach.

---

# 7. Co zostaje, zmienia się i wylatuje

| Element obecnej gry | Decyzja |
|---|---|
| silnik symulacji: klimat, atmosfera, biosfera, `ModifierRegistry`, `EventSystem` | **zostaje** |
| 7 interwencji | **zmienia się** w drzewko Środowisko (koszt w Iskrach) |
| punkty decyzji z pauzą | **wylatuje** jako rdzeń; zostaje auto-pauza na Próbę |
| cele, gwiazdki, ambicje, `GoalTracker` | **wylatuje**; zastępuje je Wskaźnik Życia i Dziedzictwo |
| `HintAdvisor`, podpowiedzi | **upraszcza się**: podpowiedzi tylko w tutorialu |
| kronika | **zmienia się** w pasek wiadomości na żywo i głos Creatora |
| konsola (`play.sh`) | **wylatuje** jako pierwszy interfejs; zostaje `run_simulation.sh` jako narzędzie balansu |
| `DisplayScale` (jednostki ziemskie) | **zostaje**, bo gracz czyta wartości |
| `LifeZones` (kolory) | **zostaje** jako czytelność parametrów |
| narzędzia pomiarowe | **zostają** do balansu (rozdział 9) |
| golden trace i determinizm | **zostają jako narzędzie testowe**, nie jako cel |

---

# 8. Etapy (plan wysokiego poziomu)

Każdy etap kończy się **grywalną wersją** i pytaniem do testera.

- **Etap 0. Dokumenty:** nowy `CLAUDE.md`, `CORE_LOOP.md`, `vision.md`,
  `DESIGN_PRINCIPLES.md`, `plan_rozwoju.md` (rozdział 10).
- **Etap 1. Bąbelki, Iskry, sklep perków** w oknie, na obecnej planecie.
  10 pierwszych perków (6 ze Środowiska z obecnych interwencji, 4 z Życia).
  Drzewko Dyspersji pojawia się dopiero w etapie 2, bo bez zasięgu nic
  by nie robiło. Pytanie: czy tester klika bąbelki bez podpowiedzi?
- **Etap 2. Zasięg:** kontynenty jako dane, `reach`, drzewko Dyspersji,
  pokrycie na globusie. Pytanie: czy rozświetlanie mapy daje satysfakcję?
- **Etap 3. Creator:** Gniew, Próby z zapowiedzią, Próba Ostateczna,
  Wskaźnik Życia, wygrana i porażka. Pytanie: czy Próba jest czytelna
  i uczciwa?
- **Etap 4. Meta:** mutacje, Dziedzictwo, trzy scenariusze, wiara
  ludzkości, ekran końcowy.
- **Etap 5. Fauna:** gatunki-konsumenci (owady, płazy, ssaki). Wymaga nowego
  mechanizmu troficznego, więc osobna specyfikacja po etapie 4.
- **Etap 6. Steam:** GodotSteam (osiągnięcia, chmura zapisów), strona sklepu
  i trailer (strona sklepu możliwa już po etapie 3).

---

# 9. Kryteria sukcesu

Vertical slice (etapy 1-3):

- partia trwa 15-25 minut,
- tester klika bąbelki bez podpowiedzi (4-6 na minutę),
- bot grający według prostych zasad wygrywa 40-60% partii na poziomie
  normalnym (miara balansu; narzędzie wzorowane na `goal_bot.gd`),
- co najmniej 3 z 5 testerów zaczyna drugą partię bez zachęty,
- każda Próba jest zapowiedziana i ma co najmniej jedno przeciwdziałanie.

---

# 10. Zmiany w dokumentach

- `CLAUDE.md`: usunąć "planeta jest bohaterem, gracz katalizatorem",
  zakaz progresji i walut, "Console Simulation First", "Never reverse this
  order"; dodać wizję Praktykanta, pętlę z rozdziału 2 i kryteria
  z rozdziału 9.
- `CORE_LOOP.md` i `vision.md`: przepisać na pętlę bąbelki, perki,
  zapowiedź Próby, Dziedzictwo.
- `DESIGN_PRINCIPLES.md`: zastąpić zasadę "gracz nie jest ekonomią"
  zasadą "każdy perk ma cenę i skutek uboczny".
- Fun Detector zostaje, ale pyta: "czy gracz chce kliknąć jeszcze raz?".
- Pozostałe skille `genesis-*` (balans, determinizm, QA) zostają bez zmian.

---

# 11. Ryzyka

| Ryzyko | Ograniczenie |
|---|---|
| zasięg bez regionów wydaje się płytki | etap 2 jest testem; fallback: regiony jako osobny etap |
| Gniew oparty na `change` biomasy bywa zaszumiony | wygładzić oknem (500 ticków); zmierzyć `planet_report.gd` |
| gracz zawsze wygrywa dzięki jednej strategii | bot z różnymi strategiami, zasada "skutek uboczny perku" |
| Próba Ostateczna nie do przejścia albo trywialna | pomiar botem na 3 archetypach i wielu seedach |
| fauna wymaga nowego mechanizmu | wydzielona w etap 5, nie blokuje slice'a |
| zakres większy niż czas autora | każdy etap grywalny; strona Steam po etapie 3 |
