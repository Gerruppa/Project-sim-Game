# Iskry, bąbelki i perki (Etap 0 + Etap 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nowe dokumenty rdzenia gry oraz pierwsza grywalna pętla na żywo: bąbelki na globusie dają Iskry Życia, Iskry kupują perki (6 odblokowań boskich mocy i 4 cechy życia), bez pauzy na punktach decyzji.

**Architecture:** Stan gracza (saldo Iskier, kupione perki) żyje w nowym `PerkSystem` (ModifierProvider w `simulation/perks/`), więc działa przez polecenia `grant`/`buy`/`refund`, modyfikatory i zapis jak istniejące interwencje. Bąbelki są warstwą gry (`game/BubbleField`, czas rzeczywisty, poza determinizmem), a kliknięcie zamienia się w polecenie `grant`. Okno dostaje tryb `live` (bez pauz na punktach decyzji), nakładkę bąbelków na globus i panel perków.

**Tech Stack:** Godot 4.7.2 stable, GDScript (typowany), gdUnit4, JSON w `godot/resources/`.

**Spec:** `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md` (rozdziały 2, 3.1-3.3, 8 Etap 0-1, 9, 10). Kolejne plany: Etap 2 (zasięg), Etap 3 (Creator), Etap 4 (meta). Konsola i punkty decyzji zostają do planu Etapu 3, gdy auto-pauza na Próbę je zastąpi.

## Global Constraints

- Godot 4.7.2 stable; `untyped_declaration` jest błędem: każdy `var`, parametr i zwrot ma typ.
- `simulation/` używa tylko `SimMath` i `SeededRng`, bez sygnałów Godota, bez `PlanetState` (tylko `PlanetSnapshot`); wymusza to `architecture_rules_test.gd`. `game/` i `ui/` mogą używać `RandomNumberGenerator` i sygnałów.
- 1 rok = 360 ticków; partia = 72 000 ticków; okno oferuje tempo x5/x10/x25/x50/x100, domyślnie x25.
- Bąbelek znika po 15 sekundach czasu rzeczywistego (pauza go nie starzeje).
- Cele pomiarowe: 4-6 bąbelków na minutę, pierwszy perk do 30 sekund od startu.
- Perk ma koszt w Iskrach, wymagania (inne perki), skutek uboczny i da się go cofnąć za część kosztu.
- Teksty dla gracza po polsku, identyfikatory po angielsku.
- Pliki `.gd` edytować narzędziem Edit (LF, nie CRLF); commitować wygenerowane `*.gd.uid`.
- **Commit i push tylko na prośbę użytkownika** (zasada projektu). Krok "Commit" znaczy: przygotuj komunikat (zakończony `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`) i zapytaj użytkownika.
- Testy: `GODOT_BIN="C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" ./godot/run_tests.sh -a res://simulation/tests/<poziom>/<plik>.gd`; pełny zestaw bez `-a` (ok. 3 min). Wynik zgłaszać jako linię `N test cases | E errors | F failures` i kod wyjścia (0 = sukces).

## Odstępstwa od specyfikacji (świadome)

1. Wymagania perków w Etapie 1 to tylko inne perki. Progi parametrów planety dochodzą z drzewkiem Ekosystem (Etap 5).
2. `seed_species` jest darmowe od startu (pierwsze narzędzie Praktykanta). Pozostałe 6 interwencji odblokowują perki. Zasada: każda interwencja jest darmowa albo odblokowana przez perk.
3. Blokada interwencji perkami działa tylko w trybie `live` (konsola i `--act` zostają bez zmian).
4. Zapowiedzi kataklizmów, Gniew i Próby nie wchodzą do tego planu.

## Review Focus

Wejścia i warunki, których spec nie opisuje, a które najpewniej ugryzą gracza. Każda linia ma test w zadaniu, które posiada kod.

1. **Dwa zakupy w jednym ticku przy saldzie na jeden** — drugi odrzucony, saldo nigdy ujemne (Task 3).
2. **Podwójne kliknięcie tego samego bąbelka** — Iskry naliczone raz (Task 4, Task 5).
3. **Wczytanie zapisu po zakupie** — saldo i modyfikatory perków odtworzone, kamienie milowe "Rozkwitu" nie rodzą bąbelków drugi raz (Task 3, Task 5).
4. **Cofnięcie perka, którego wymaga inny kupiony perk** — odmowa; cofnięcie zdejmuje jego modyfikatory i zwraca część kosztu (Task 3).
5. **Pauza i bąbelki** — spauzowana gra nie starzeje bąbelków; bąbelek po drugiej stronie globusa nie jest klikalny (Task 4, Task 6).
6. **`grant` z kwotą ≤ 0, NaN albo > 100** — odrzucone (Task 3).

---

### Task 1: Dokumenty nowego rdzenia (Etap 0)

**Files:**
- Modify: `CLAUDE.md`, `docs/CORE_LOOP.md`, `docs/vision.md`, `docs/DESIGN_PRINCIPLES.md`, `docs/plan_rozwoju.md`
- Modify: `.claude/skills/genesis-fun-detector/SKILL.md`, `.claude/skills/genesis-feature-gate/SKILL.md`
- Test: weryfikacja `grep` (dokumenty nie mają testów jednostkowych)

**Interfaces:**
- Consumes: spec (rozdziały 1, 2, 10) jako źródło treści.
- Produces: zasady, do których odwołują się pozostałe zadania i kolejne plany (pętla na żywo, perk z ceną i skutkiem ubocznym, Fun Detector pytający "czy gracz chce kliknąć jeszcze raz?").

- [ ] **Step 1: Zapisz wzorzec do wyszukania starych zasad**

Uruchom i zapisz wynik (lista plików i linii do przepisania):
`grep -rniE "Console Simulation First|Never reverse this order|player is a catalyst|Bad Progression|Failure is not game over|technology trees|progression systems" CLAUDE.md docs .claude/skills`

- [ ] **Step 2: Przepisz `CLAUDE.md`**

Zachowaj sekcje techniczne bez zmian: Architecture Rules, Single Source of Truth, Event Bus Rule, Tick System, Testing Philosophy, Code Style, Logging Rules. Zastąp: Project Vision (gracz jest Praktykantem Creatora; cel: bujne życie w 200 lat; wzór: Plague Inc), Development Philosophy (kolejność: 1. grywalna pętla na mapie, 2. czytelność decyzji i kryzysów, 3. silnik symulacji, 4. oprawa), Current Project Goal (Etapy 0-4 ze specyfikacji, link do niej), Fun Detector (pytanie: "czy gracz chce kliknąć jeszcze raz?"; miary: kliknięcia bąbelków na minutę, drugie podejście bez zachęty), Core Design Principles (usuń "planet is the protagonist" i zakaz progresji; dodaj "każdy perk ma cenę i skutek uboczny", "każda Próba jest zapowiedziana i ma przeciwdziałanie"). Usuń "System Priority" (historyczne) i "Simulation First Rule". W File Structure dopisz `simulation/perks/`, `ui/` (BubbleLayer, PerkPanel).

- [ ] **Step 3: Przepisz `docs/CORE_LOOP.md` i `docs/vision.md`**

`CORE_LOOP.md`: pętla na czterech poziomach (tabela z rozdziału 2 specyfikacji), nagroda = wzrost siły i ekspansja, porażka = Dziedzictwo, test "30 minut" zastąp testem "15-25 minut, drugie podejście". `vision.md`: fabuła Praktykanta i Creatora, platforma Steam, link do specyfikacji.

- [ ] **Step 4: Przepisz `docs/DESIGN_PRINCIPLES.md`**

Zamień zasadę "gracz nie jest ekonomią" na "każdy perk ma cenę i skutek uboczny"; usuń listy "Bad progression". Zachowaj zasady techniczne (dane ponad kodem, determinizm jako narzędzie testowe).

- [ ] **Step 5: Zaktualizuj `docs/plan_rozwoju.md` i skille**

`plan_rozwoju.md`: dopisz na górze "Nowy rdzeń od 2026-10-06" ze skrótem etapów 0-6 i odnośnikami do specyfikacji oraz tego planu; stare etapy A-E oznacz jako "zastąpione". W obu skillach zamień odwołania do starego testu pięciu pytań i do "planeta jest bohaterem" na nowe zasady z kroku 2.

- [ ] **Step 6: Zweryfikuj**

Uruchom ponownie polecenie z kroku 1. Oczekiwane: brak trafień poza `docs/superpowers/` i historycznymi sekcjami oznaczonymi "zastąpione".

- [ ] **Step 7: Commit (po zgodzie użytkownika)**

```bash
git add CLAUDE.md docs .claude/skills
git commit -m "docs: rewrite core loop and principles for the Plague Inc-style game"
```

---

### Task 2: Katalog perków

**Files:**
- Create: `godot/simulation/perks/perk_def.gd`, `godot/simulation/perks/perk_catalog.gd`, `godot/resources/perks/perks.json`
- Test: `godot/simulation/tests/unit/perk_catalog_test.gd`, `godot/simulation/tests/support/perk_fixtures.gd`

**Interfaces:**
- Consumes: `Modifier.check_data(modifier, label, specs, result)`, `CoefficientLoader.read_json(path, label) -> SimResult`, `SimResult`, `InterventionCatalog.ids()`.
- Produces:
  - `class_name PerkDef extends RefCounted`: `id: StringName`, `name: String`, `help: String`, `tree: StringName` (`&"environment"` albo `&"life"`), `cost: int`, `requires: Array[StringName]`, `modifiers: Array[Dictionary]`, `unlocks: Array[StringName]`, `side_effect: String`, `story: Dictionary[String, String]` (klucze `bought`, `refunded`), `func source() -> StringName` (`perk:<id>`).
  - `class_name PerkCatalog extends RefCounted`: `const DEFAULT_PATH := "res://resources/perks/perks.json"`, `const TREES: Array[StringName]`, `var refund_ratio: float`, `var income_per_biomass_tick: float`, `var free_interventions: Array[StringName]`, `static func load_json(path: String, specs: Dictionary, intervention_ids: Array[StringName]) -> SimResult`, `static func from_data(data: Dictionary, specs: Dictionary, intervention_ids: Array[StringName]) -> SimResult`, `func get_def(id: StringName) -> PerkDef`, `func ids() -> Array[StringName]`, `func defs() -> Array[PerkDef]`.
  - `perk_fixtures.gd`: `static func perk(id: String, overrides: Dictionary = {}) -> Dictionary`, `static func parse(perks: Array, extra: Dictionary = {}) -> SimResult`, `static func project_catalog() -> PerkCatalog` (ładuje prawdziwe dane ze specyfikacjami z `personality_fixtures.gd` i identyfikatorami interwencji z `intervention_fixtures.gd`).

- [ ] **Step 1: Write the failing tests** w `perk_catalog_test.gd` (nazwy i asercje):
  - `test_project_data_is_valid`: `project_catalog()` ładuje się; `ids().size() == 10`; `refund_ratio == 0.7`; `free_interventions == [&"seed_species"]`.
  - `test_every_intervention_is_free_or_unlocked`: dla wszystkich 7 id z `InterventionCatalog` brak błędu; po usunięciu perka `perk_cull` z danych `parse` zwraca błąd zawierający `cull_species`.
  - `test_rejects_unknown_requirement`, `test_rejects_requirement_cycle` (A wymaga B, B wymaga A): błędy zawierają id perków.
  - `test_rejects_bad_modifier_target` (`biosphere.nope`): błąd z `has no coefficient 'nope'`.
  - `test_rejects_duplicate_id`, `test_rejects_unknown_tree`, `test_rejects_zero_cost`, `test_rejects_empty_side_effect`, `test_rejects_perk_without_effect` (ani modyfikatorów, ani odblokowań), `test_rejects_refund_ratio_outside_0_1`.
  - `test_reports_all_errors_at_once`: dwa błędy w jednym wywołaniu dają `errors.size() >= 2`.

- [ ] **Step 2: Run to verify fail**

`./godot/run_tests.sh -a res://simulation/tests/unit/perk_catalog_test.gd`. Oczekiwane: błąd ładowania (brak `PerkCatalog`).

- [ ] **Step 3: Implement `PerkDef`, `PerkCatalog` and `resources/perks/perks.json`**

Parser wzorowany na `InterventionCatalog` (wszystkie błędy naraz, nieznane klucze są błędem, `story` wymaga `bought` i `refunded`). Cykl wymagań wykryj przez DFS po `requires`. Dane (koszt w Iskrach):

| id | tree | nazwa | koszt | requires | efekt | skutek uboczny |
|---|---|---|---|---|---|---|
| `perk_hardy` | life | Wytrzymałość | 4 | — | `biosphere.stress_scale` ×0.8, `biosphere.growth_scale` ×0.95 | Wytrzymałe gatunki rosną wolniej (−5% wzrostu). |
| `perk_fast_growth` | life | Szybki wzrost | 12 | `perk_hardy` | `growth_scale` ×1.2, `stress_scale` ×1.1 | Szybko rosnące gatunki są wrażliwsze na stres (+10%). |
| `perk_fire_resistance` | life | Odporność na ogień | 10 | `perk_hardy` | `biosphere.fire_rate` ×0.6, `growth_scale` ×0.97 | Gęstsze drewno rośnie wolniej (−3% wzrostu). |
| `perk_regrowth` | life | Odbudowa | 8 | — | `biosphere.recolonization` add +0.02, `stress_scale` ×1.05 | Ciągłe odnawianie zwiększa stres o 5%. |
| `perk_mirrors_warm` | environment | Lustra orbitalne | 8 | — | odblokowuje `mirrors_warm` | Zbyt mocne ogrzanie przegrzewa życie. |
| `perk_mirrors_cool` | environment | Pył orbitalny | 8 | — | odblokowuje `mirrors_cool` | Zbyt mocny pył wywołuje epokę lodową. |
| `perk_cloud_seeding` | environment | Zasiew chmur | 10 | — | odblokowuje `cloud_seeding` | Deszcz wysusza powietrze: mchy i glony cierpią. |
| `perk_aquifer` | environment | Wody podziemne | 10 | — | odblokowuje `aquifer_release` | Więcej chmur ochładza planetę. |
| `perk_volcanic` | environment | Przebudzenie wulkanów | 14 | `perk_mirrors_warm` | odblokowuje `volcanic_awakening` | CO₂ zostaje w atmosferze na długo. |
| `perk_cull` | environment | Przerzedzanie | 6 | — | odblokowuje `cull_species` | Mniej roślin to mniej tlenu. |

Pola `help` i `story` (kupno: jedno zdanie w stylu Creatora, np. "Creator unosi brew: Praktykant nauczył się wytrzymałości."; cofnięcie: "Praktykant zapomina: …") napisz po polsku. Górny poziom danych: `"perks_version": 1`, `"refund_ratio": 0.7`, `"income_per_biomass_tick": 0.00001`, `"free_interventions": ["seed_species"]`.

- [ ] **Step 4: Run to verify pass** (to samo polecenie). Oczekiwane: wszystkie testy zielone.

- [ ] **Step 5: Commit (po zgodzie)**

```bash
git add godot/simulation/perks godot/resources/perks godot/simulation/tests
git commit -m "feat: perk catalog with ten perks and validated data"
```

---

### Task 3: PerkSystem (Iskry, zakupy, modyfikatory) i podpięcie do planety

**Files:**
- Create: `godot/simulation/perks/perk_system.gd`
- Modify: `godot/game/simulation_runner.gd:200-235` (`build_planet`: rejestracja systemu, odciski danych)
- Test: `godot/simulation/tests/unit/perk_system_test.gd`, `godot/simulation/tests/integration/perk_behavior_test.gd`

**Interfaces:**
- Consumes: `PerkCatalog`/`PerkDef` (Task 2), `ModifierProvider.provide_modifiers/restore_modifiers`, `ModifierRegistry.add/remove_source/has_target`, `Modifier.new(target, operation, value, source, Modifier.PERMANENT)`, `ExactCodec.floats_to_text/floats_from_text`, `Param.BIOMASS`, `PlanetSnapshot.get_value(StringName) -> float`, `SimCommand` (`tick`, `action`, `args`).
- Produces:
  - `class_name PerkSystem extends ModifierProvider`: `const ID := &"perks"`, `const FORMAT := "perks_state"`, `const ACTION_GRANT := &"grant"`, `ACTION_BUY := &"buy"`, `ACTION_REFUND := &"refund"`, `const BOUGHT_EVENT := &"perk_bought"`, `REFUNDED_EVENT := &"perk_refunded"`, `REJECTED_EVENT := &"perk_rejected"`, `GRANTED_EVENT := &"sparks_granted"`.
  - `func _init(catalog: PerkCatalog) -> void`, `catalog() -> PerkCatalog`, `sparks() -> float`, `owns(perk_id: StringName) -> bool`, `owned() -> Array[StringName]` (w kolejności zakupu), `unlocks(intervention_id: StringName) -> bool` (wolna albo odblokowana przez kupiony perk), `unlocking_perk(intervention_id: StringName) -> PerkDef` (null dla wolnych), `missing_requirements(perk_id: StringName) -> Array[StringName]`.
  - Polecenia: `grant {amount: float 0 < x ≤ 100, source: String opcjonalny}`, `buy {perk: String}`, `refund {perk: String}`.

- [ ] **Step 1: Write the failing unit tests** w `perk_system_test.gd` (system budowany z `perk_fixtures`, polecenia wywoływane przez `validate_command`/`apply_command`):
  - `test_grant_adds_sparks_and_emits_event`; `test_grant_rejects_zero_negative_nan_and_over_100`.
  - `test_buy_needs_enough_sparks` (komunikat zawiera brakującą liczbę Iskier), `test_buy_needs_requirements` (komunikat zawiera nazwę brakującego perka), `test_cannot_buy_owned_perk`.
  - `test_buy_spends_sparks_and_registers_permanent_modifiers`: po zakupie `perk_hardy` i jednym `provide_modifiers` rejestr zawiera `biosphere.stress_scale` ×0.8 ze źródłem `perk:perk_hardy` i `expires_at == Modifier.PERMANENT`.
  - `test_two_buys_in_one_tick_cannot_overspend` (saldo 4, dwa polecenia `buy` na koszt 4: drugie daje zdarzenie `perk_rejected`, `sparks() == 0.0`).
  - `test_refund_returns_floor_of_ratio_and_removes_modifiers` (koszt 10 → +7; `remove_source` działa po kolejnym `provide_modifiers`); `test_refund_refused_while_another_owned_perk_requires_it`.
  - `test_unlocks_follow_ownership`: `unlocks(&"seed_species")` zawsze true; `unlocks(&"cull_species")` false przed zakupem `perk_cull`, true po.
  - `test_income_accrues_from_biomass`: biomasa 50 w snapshocie, 1000 wywołań `provide_modifiers` daje `sparks() == 50 × 1000 × income_per_biomass_tick` (równość przybliżona).
  - `test_save_and_load_roundtrip_is_exact`: saldo (z ułamkiem) i lista kupionych odtworzone bit w bit; `restore_modifiers` rejestruje modyfikatory kupionych perków.
  - `test_load_rejects_unknown_perk_and_bad_format`.

- [ ] **Step 2: Run to verify fail** (`-a res://simulation/tests/unit/perk_system_test.gd`): brak `PerkSystem`.

- [ ] **Step 3: Implement `PerkSystem`**

Wzorzec: `InterventionSystem` (kolejka `_to_register`, rejestracja w `provide_modifiers`, `restore_modifiers` czyści źródło i rejestruje od nowa). Dochód naliczaj w `provide_modifiers` ze snapshotu poprzedniego ticka. `apply_command` ponownie sprawdza saldo i wymagania (polecenie z kolejki mogło spotkać nowy stan) i emituje `perk_rejected` zamiast zmieniać stan. Saldo zapisuj przez `ExactCodec.floats_to_text`. Zdarzenia noszą `story` z definicji perka.

- [ ] **Step 4: Podepnij do planety** w `SimulationRunner.build_planet`: wczytaj `PerkCatalog.load_json(PerkCatalog.DEFAULT_PATH, specs, interventions.value.ids())`, błędy dołącz do `failed`, zarejestruj `PerkSystem.new(perks.value)` po `InterventionSystem`, dodaj `"perks": PerkCatalog.DEFAULT_PATH` do `fingerprints`.

- [ ] **Step 5: Integration test** `perk_behavior_test.gd` (prawdziwa planeta z `SimulationRunner.build_planet`, seed 42, wzorem `intervention_behavior_test.gd`):
  - `test_each_modifier_perk_changes_the_planet`: dla `perk_hardy`, `perk_fast_growth`, `perk_fire_resistance`, `perk_regrowth` (z `grant` 100 Iskier i wymaganiami): po 3000 tickach biomasa albo populacja któregoś gatunku różni się od przebiegu bez perka (jeśli `perk_regrowth` nie daje różnicy w 3000 tickach, mierz w 6000).
  - `test_save_load_continuity_with_a_perk`: kup `perk_hardy`, zapisz (`SaveSystem`), wczytaj do świeżej planety, dociągnij oba przebiegi o 500 ticków, snapshoty i `sparks()` identyczne.
  - `test_unlocking_perk_does_not_change_the_simulation`: zakup `perk_cull` nie zmienia stanu planety względem przebiegu bez zakupu (tylko saldo).

- [ ] **Step 6: Run unit + integration + architecture + determinism tests**, potem pełny zestaw. Testy wyliczające zarejestrowane systemy (`grep -rn "InterventionSystem.ID" godot/simulation/tests`) zaktualizuj o `PerkSystem.ID`. Oczekiwane: pełny zestaw zielony, kod wyjścia 0.

- [ ] **Step 7: Commit (po zgodzie)**

```bash
git add godot/simulation godot/game/simulation_runner.gd godot/resources
git commit -m "feat: PerkSystem holds Sparks and perks, wired into the planet"
```

---

### Task 4: BubbleField (bąbelki w warstwie gry)

**Files:**
- Create: `godot/game/bubble_field.gd`, `godot/resources/bubbles/bubbles.json`
- Test: `godot/simulation/tests/unit/bubble_field_test.gd`

**Interfaces:**
- Consumes: `RunObserver.attach(bus: EventBus)`, `EventBus.subscribe_all(callable)`, `SimEvent` (`type`, `tick`, `data`), `SimEvent.TICK_APPLIED`, `SimResult`, `CoefficientLoader.read_json`.
- Produces: `class_name BubbleField extends RunObserver`:
  - `const DEFAULT_PATH := "res://resources/bubbles/bubbles.json"`.
  - `static func load_json(path: String, seed_value: int, species: Array[String], population_of: Callable) -> SimResult` oraz `static func from_data(data: Dictionary, seed_value: int, species: Array[String], population_of: Callable) -> SimResult` (`population_of.call(species_id: String) -> float`).
  - `func on_event(event: SimEvent) -> void`, `func on_tick(tick: int) -> void`, `func attach(bus: EventBus) -> void` (subskrybuje `on_event`; `TICK_APPLIED` wywołuje `on_tick`).
  - `func update(seconds: float) -> void` (starzenie i wygasanie), `func bubbles() -> Array[Dictionary]` (kopie: `id: int`, `kind: String` (`ambient`/`discovery`/`bloom`), `value: int`, `lat: float` (−80..80), `lon: float` (−180..180), `age: float`), `func collect(id: int) -> int` (wartość albo 0, gdy bąbelka nie ma), `func lifetime() -> float`, `func save_state() -> Dictionary`, `func load_state(data: Dictionary) -> void`.
- Dane: `"lifetime_seconds": 15`, `"max_visible": 8`, `"ambient": {"every_ticks": 600, "value": 1}`, `"discovery": {"value": 4}`, `"bloom": {"value": 3, "thresholds": [20, 40, 60]}`.

- [ ] **Step 1: Write the failing tests** (`bubble_field_test.gd`, populacje podawane przez `Callable` z testu):
  - `test_ambient_bubble_every_600_ticks`: `on_tick(600)`, `on_tick(1200)` → 2 bąbelki `ambient` o wartości 1; `on_tick(900)` nic nie dodaje.
  - `test_species_emerged_spawns_a_discovery_bubble_worth_4`.
  - `test_bloom_spawns_once_per_threshold`: populacja mchów 25 → jeden `bloom` (próg 20); ponowne `on_tick` bez zmiany nic; 45 → kolejny (próg 40); spadek do 10 i powrót do 25 nie rodzi trzeciego.
  - `test_collect_returns_value_once`: pierwsze `collect(id)` = 4, drugie = 0 (podwójne kliknięcie).
  - `test_bubble_expires_after_lifetime_seconds`: `update(14.9)` bąbelek żyje, `update(0.2)` znika; `update(0.0)` niczego nie starzeje.
  - `test_max_visible_drops_the_oldest`.
  - `test_positions_are_deterministic_for_a_seed_and_within_range`.
  - `test_save_state_keeps_bloom_milestones_not_bubbles`: po `load_state` bloom nie powtarza się dla już osiągniętego progu, a lista bąbelków jest pusta.
  - `test_rejects_bad_data` (próg poza 0-100, `every_ticks` ≤ 0).

- [ ] **Step 2: Run to verify fail**, **Step 3: Implement** (pozycje z `RandomNumberGenerator` zasianego `seed_value + id`; identyfikatory rosnące od 1), **Step 4: Run to verify pass**.

- [ ] **Step 5: Commit (po zgodzie)**

```bash
git add godot/game/bubble_field.gd godot/resources/bubbles godot/simulation/tests
git commit -m "feat: BubbleField spawns collectible Spark bubbles"
```

---

### Task 5: GameSession: ekonomia, blokada akcji, tryb live

**Files:**
- Modify: `godot/game/game_session.gd` (`create`, `round_over`, `step`, `save`, `actions`, `submit`; nowe metody poniżej)
- Modify: `godot/resources/simulation/sim_config.json` (`speed_multipliers` dostaje `50`)
- Test: `godot/simulation/tests/integration/game_session_economy_test.gd`

**Interfaces:**
- Consumes: `PerkSystem` (Task 3), `BubbleField` (Task 4), istniejące `GameSession.hand()`, `manager.submit(target, action, args)`.
- Produces w `GameSession`:
  - `var live := false`, `var bubbles: BubbleField`, `const AUTOSAVE_TICKS := 1000`.
  - `func perks() -> PerkSystem`, `func sparks() -> int` (`floori`).
  - `func perk_rows() -> Array[Dictionary]`: `id: String`, `name`, `help`, `tree: String`, `cost: int`, `owned: bool`, `affordable: bool`, `available: bool` (wymagania spełnione), `missing: Array[String]` (nazwy), `side_effect: String`, `refund: int`.
  - `func buy_perk(id: String) -> SimResult` i `func refund_perk(id: String) -> SimResult` (wartość: nazwa perka; polecenie idzie przez `manager.submit(PerkSystem.ID, ...)`).
  - `func collect_bubble(id: int) -> SimResult` (wartość: liczba Iskier; wywołuje `bubbles.collect`, potem `submit(grant)`; błąd "Bąbelek już zniknął." gdy 0).
  - `func update_bubbles(seconds: float) -> void`.
  - `actions()` zyskuje pola `unlocked: bool` i `unlock_perk: String` (nazwa perka albo ""); w trybie `live` `submit()` odmawia zablokowanej akcji komunikatem `"<akcja> wymaga perka „<perk>”."`.
  - W trybie `live`: `round_over()` jest prawdziwe tylko gdy `manager.is_halted()`; `step()` zapisuje grę, gdy tick przekroczy kolejną wielokrotność `AUTOSAVE_TICKS`; `save()` dopisuje `extras["bubbles"] = bubbles.save_state()`, a `create` je wczytuje.

- [ ] **Step 1: Write the failing tests** (`game_session_economy_test.gd`; sesja przez `GameSession.create({... "live": true, "file_logs": false, "save": "user://..."}, ...)` wzorem `game_session_test.gd`):
  - `test_perk_rows_describe_cost_requirements_and_refund`: `perk_fast_growth` na starcie ma `available == false`, `missing == ["Wytrzymałość"]`; `perk_hardy` ma `cost == 4`, `refund == 2` (po zakupie).
  - `test_collect_bubble_grants_sparks_next_tick`: po `bubbles` z bąbelkiem Odkrycia (wymuś `on_event` albo graj do pierwszego gatunku) `collect_bubble(id)` zwraca 4, po `step(2)` `sparks() == 4`; drugie `collect_bubble` z tym samym id kończy się błędem, saldo bez zmian (podwójne kliknięcie).
  - `test_locked_action_is_refused_in_live_mode_only`: `submit("mirrors_warm", {})` kończy się błędem z "Lustra orbitalne"; w sesji bez `live` ta sama akcja przechodzi; `seed_species` przechodzi zawsze.
  - `test_buying_the_perk_unlocks_the_action`: `grant` 8, `buy_perk("perk_mirrors_warm")`, `step(3)`, potem `submit("mirrors_warm", {})` OK.
  - `test_live_round_never_ends_at_a_decision_point`: `step(5000)` w trybie live, `round_over()` false, `decision_point() == null`.
  - `test_live_autosaves_every_1000_ticks`: po `step(1100)` plik zapisu istnieje.
  - `test_load_keeps_sparks_perks_and_bloom_milestones`: zapis po zakupie i dojściu mchów do progu Rozkwitu; wczytanie; saldo, `perk_rows()[...].owned` i brak nowego bąbelka Rozkwitu dla tego progu.
  - `test_buy_without_sparks_fails_at_submit_with_the_missing_amount`.

- [ ] **Step 2: Run to verify fail**, **Step 3: Implement** (flagę `live` czytaj z `options.get("live", false)`; `BubbleField` buduj w `create` z `population_of` opartym na `BiosphereSystem.population`, subskrybuj przez `manager.attach_log(bubbles)`), dodaj `50` do `speed_multipliers`. **Step 4: Run to verify pass** oraz istniejące `game_session_test.gd`, `play_session_test.gd`, `goal_tracker_test.gd`, `decision_point_test.gd` (muszą zostać zielone: tryb domyślny bez zmian).

- [ ] **Step 5: Commit (po zgodzie)**

```bash
git add godot/game godot/resources/simulation godot/simulation/tests
git commit -m "feat: GameSession economy, perk gating and live mode"
```

---

### Task 6: PlanetView.screen_point i BubbleLayer

**Files:**
- Modify: `godot/ui/planet_view.gd` (nowa metoda po `distance()`)
- Create: `godot/ui/bubble_layer.gd`
- Test: `godot/simulation/tests/integration/bubble_layer_test.gd`

**Interfaces:**
- Consumes: `PlanetView` (`_camera`, `_pivot`, `turn(by: Vector2)`), `BubbleField.bubbles()`.
- Produces:
  - `PlanetView.func screen_point(lat_deg: float, lon_deg: float) -> Variant`: `Vector2` we współrzędnych kontenera albo `null`, gdy punkt jest po stronie odwróconej od kamery (iloczyn skalarny normalnej powierzchni i kierunku do kamery ≤ 0.05).
  - `class_name BubbleLayer extends Control`: `signal bubble_pressed(id: int)`, `func setup(planet: PlanetView, field: BubbleField) -> void`, `func refresh() -> void` (synchronizuje przyciski z `field.bubbles()`, ustawia pozycje przez `screen_point`, chowa niewidoczne), `func visible_bubble_ids() -> Array[int]`, `func press(id: int) -> void` (dla testów: emituje `bubble_pressed`). Przycisk ma 44 px, tekst `+<wartość>`, kolor zależny od `kind`; warstwa ma `mouse_filter = IGNORE`, przyciski `STOP`.

- [ ] **Step 1: Write the failing tests** (`bubble_layer_test.gd`, `PlanetView` dodany do drzewa, `size` ustawione na 800×600):
  - `test_a_point_on_the_visible_side_has_a_screen_position`: dla `lat 0` i `lon` z 0..330 co 30 przynajmniej jeden zwraca `Vector2` wewnątrz kontenera.
  - `test_the_same_point_is_hidden_after_turning_the_globe_half_way`: wybierz widoczny `lon`, `turn(Vector2(PI, 0.0))`, `screen_point` zwraca `null`.
  - `test_layer_shows_a_button_per_visible_bubble_and_hides_far_side_ones`.
  - `test_pressing_a_bubble_emits_its_id`.
  - `test_expired_bubble_loses_its_button` (po `field.update(16.0)` i `refresh()`).

- [ ] **Step 2: Run to verify fail**, **Step 3: Implement** (pozycja świata = `_pivot.global_transform.basis * wektor_jednostkowy(lat, lon)`, rzut `_camera.unproject_position`), **Step 4: Run to verify pass**.

- [ ] **Step 5: Commit (po zgodzie)**

```bash
git add godot/ui godot/simulation/tests
git commit -m "feat: clickable Spark bubbles over the globe"
```

---

### Task 7: PerkPanel i gra na żywo w oknie

**Files:**
- Create: `godot/ui/perk_panel.gd`
- Modify: `godot/ui/game_view.gd` (stałe `SPEEDS`/`DEFAULT_SPEED` ~18-19, `open_game` ~97, `_process` ~188, `_build_center`/`_build_right`, `_refresh` ~402-452, `act` ~325)
- Modify: `godot/simulation/tests/integration/game_view_test.gd` (otwieranie z `options["live"] = false`, asercje tempa)
- Test: `godot/simulation/tests/integration/game_view_live_test.gd`

**Interfaces:**
- Consumes: `GameSession` (Task 5), `BubbleLayer` (Task 6), `PerkPanel`.
- Produces:
  - `class_name PerkPanel extends VBoxContainer`: `signal buy_requested(perk_id: String)`, `signal refund_requested(perk_id: String)`, `func refresh(rows: Array[Dictionary], sparks: int) -> void` (nagłówki "Środowisko" i "Życie"; wiersz: nazwa, koszt, przycisk Kup aktywny tylko gdy `available and affordable and not owned`; dla kupionych przycisk "Cofnij (+<refund>)"; podpowiedź = `help` + skutek uboczny), `func row_text(perk_id: String) -> String`, `func buy_button(perk_id: String) -> Button`.
  - `GameView`: `SPEEDS = [5, 10, 25, 50, 100]`, `DEFAULT_SPEED = 25`; `func collect_bubble(id: int) -> SimResult`, `func buy_perk(id: String) -> SimResult`, `func sparks_text() -> String` (`"Iskry: N"`); `open_game` ustawia `options["live"] = options.get("live", true)`; w trybie live akcje są dozwolone także podczas biegu (`allowed = session.tick() > 0 and (session.live or _at_decision or not _running)`), zablokowane akcje mają wyłączony przycisk i tekst `"<nazwa> (wymaga: <perk>)"`; `_process` dodatkowo wywołuje `session.update_bubbles(delta)` tylko gdy gra biegnie oraz `_bubbles.refresh()`.
  - Nowy wstęp w trybie live: stała `LIVE_INTRO` (3-4 zdania po polsku: Creator, teza ludzkości, 200 lat, Praktykant) zamiast `session.advisor.intro`.

- [ ] **Step 1: Zaktualizuj istniejący `game_view_test.gd`**: `_open` ustawia `options["live"] = false`; asercje tempa zmień na `[5, 10, 25, 50, 100]` i domyślne 25 tylko w nowym teście live, bo legacy `set_speed` korzysta z `DEFAULT_SPEED`; sprawdź, które asercje tego pliku zależą od 10 (`test_speeds_follow_the_buttons`, `test_window_offers_watching_speeds_only`) i dostosuj do nowych stałych.

- [ ] **Step 2: Write the failing live tests** (`game_view_live_test.gd`, układ jak w `game_view_test.gd`, ticki przez `view.advance`):
  - `test_live_game_does_not_stop_at_decision_points`: po `start()` i `advance(2000)` `at_decision()` jest false.
  - `test_collecting_a_bubble_raises_the_sparks_label`: graj, aż `session.bubbles.bubbles()` będzie niepuste (limit 20 000 ticków), `collect_bubble(id)`, `advance(2)`, `sparks_text()` zawiera `Iskry: ` z liczbą ≥ 1.
  - `test_first_perk_is_affordable_before_tick_600_for_a_perfect_player`: zbieraj każdy bąbelek, aż `session.sparks() >= 4`; `buy_perk("perk_hardy")` OK; `session.tick() <= 600` (seed 13; jeśli dane seedu 13 odkrywają bakterie później, użyj `--seed 42`, w którym bakterie pojawiają się w ticku 130).
  - `test_locked_action_button_names_the_perk`: `action_text("mirrors_warm")` zawiera "wymaga" i "Lustra orbitalne"; po zakupie perka tekst bez "wymaga".
  - `test_actions_are_allowed_while_the_planet_runs_in_live_mode`: `view.act("seed_species")` poza pauzą kończy się sukcesem.
  - `test_pausing_does_not_age_bubbles`: pauza, `_process(20.0)` (wywołanie przez `view._process(20.0)`), bąbelki wciąż są.
  - `test_default_speed_is_x25_and_x50_is_offered`.
  - `test_live_intro_names_the_creator`: `decision_text()` zawiera "Creator".

- [ ] **Step 3: Run to verify fail**, **Step 4: Implement** (`PerkPanel` jako pierwsze dziecko kolumny budowanej w `_build_right`; `BubbleLayer` jako dziecko `PlanetView` w `_build_center`, pełny prostokąt; etykieta Iskier w pasku górnym obok `_info`; sygnały panelu podłącz do `buy_perk`/`GameSession.refund_perk` z wpisem do kroniki "Zrobione: …").

- [ ] **Step 5: Run the view tests, then the full suite.** Oczekiwane: pełny zestaw zielony. Uruchom okno ręcznie (`./godot/play_window.sh`): zagraj 2 minuty i sprawdź: bąbelki są klikalne i znikają po 15 s, pierwszy perk kupiony w ok. 30 s, odblokowana moc działa podczas biegu bez pauzy.

- [ ] **Step 6: Commit (po zgodzie)**

```bash
git add godot/ui godot/simulation/tests
git commit -m "feat: live play with Spark bubbles and the perk shop in the window"
```

---

### Task 8: Pomiar ekonomii i dokumentacja Etapu 1

**Files:**
- Create: `godot/simulation/tests/simulation/perk_economy_test.gd`, `docs/perks.md`
- Modify: `docs/plan_rozwoju.md` (stan po Etapie 1)

**Interfaces:**
- Consumes: `GameSession`, `BubbleField`, `PerkSystem` z poprzednich zadań.
- Produces: pomiar, do którego odwołują się plany Etapów 2-3 przy strojeniu kosztów.

- [ ] **Step 1: Write the economy test.** Doskonały gracz (bot w teście): przy każdym ticku zbiera wszystkie bąbelki i kupuje najtańszy dostępny perk. Seedy 13 i 42, 30 000 ticków każdy, tryb live bez plików logów. Asercje: `first_purchase_tick <= 600`; wszystkie 10 perków kupione przed tickiem 30 000; suma przyznanych Iskier w 30 000 ticków mieści się w 80-260; liczba wygenerowanych bąbelków na 1000 ticków mieści się w 1,3-4,0. Przeliczenie: tempo x25 to 1,5 tysiąca ticków na minutę, a x50 to 3 tysiące, więc cel 4-6 bąbelków na minutę odpowiada 2,7-4,0 na 1000 ticków przy x25 i 1,3-2,0 przy x50. Test drukuje zmierzone wartości oraz wynikające z nich bąbelki na minutę przy x25 i x50; jeśli przy x25 wychodzi poniżej 4, skróć `ambient.every_ticks` w `bubbles.json`.

- [ ] **Step 2: Run it** (`-a res://simulation/tests/simulation/perk_economy_test.gd`). Jeśli granice nie są spełnione, popraw wartości w `perks.json`/`bubbles.json` (koszty, `every_ticks`), nie asercje; zapisz zmierzone liczby.

- [ ] **Step 3: Napisz `docs/perks.md`**: lista 10 perków z kosztami i skutkami ubocznymi, wzór dochodu, parametry bąbelków, zmierzone liczby z kroku 2, ograniczenia Etapu 1 (odstępstwa 1-3 z góry planu).

- [ ] **Step 4: Zaktualizuj `docs/plan_rozwoju.md`**: stan po Etapie 1 (co działa, gdzie to uruchomić, wyniki pomiaru) i wskazanie następnego planu (Etap 2: zasięg).

- [ ] **Step 5: Pełny zestaw testów.** Oczekiwane: `N test cases | 0 errors | 0 failures`, kod wyjścia 0.

- [ ] **Step 6: Commit (po zgodzie)**

```bash
git add docs godot/simulation/tests
git commit -m "docs: measure the Spark economy and document the perk shop"
```

---

## Self-review

- **Pokrycie specyfikacji:** 2 (pętla: bąbelki, perki, tempo x50 → Task 5/7), 3.1 (wybór planety i lądowania: poza tym planem, patrz niżej), 3.2 (Iskry, bąbelki, cele pomiarowe → Task 4/8), 3.3 (drzewka Środowisko i Życie, koszt/wymagania/skutek uboczny/cofnięcie → Task 2/3), 8 Etap 0-1 (Task 1, 2-8), 9 (pomiary → Task 8), 10 (dokumenty → Task 1). **Luka świadoma:** wybór planety i miejsca lądowania (3.1) jest w planie Etapu 2, bo lądowanie ustawia kontynent startowy, a kontynenty powstają w Etapie 2; Etap 1 używa istniejącego ekranu nowej gry (numer planety i charakter). Mutacje (3.4), drzewko Dyspersja, Ekosystem, Creator i meta są w planach kolejnych etapów.
- **Spójność typów:** `PerkSystem.ID`, `ACTION_GRANT/BUY/REFUND`, `sparks() -> float`, `perk_rows()` (pola jak w Task 5) i `BubbleField.collect(id: int) -> int` używane tak samo w Task 3, 5, 6, 7.
- **Proporcje:** plan ma zadania z sygnaturami, nazwami testów i wartościami ze specyfikacji; ciała funkcji nie są przepisane.
