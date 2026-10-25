# Wizja gry

Genesis Error jest grą strategiczną w stylu Plague Inc z odwróconym celem:
gracz ma **stworzyć bujne życie**, a nie je zniszczyć.

Pełna specyfikacja: `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md`.
Pętla: `CORE_LOOP.md`. Zasady: `DESIGN_PRINCIPLES.md`.

---

# Fabuła

Ludzkość wątpi w sens istnienia boga i twierdzi, że byle gamoń
z boskimi mocami stworzyłby życie. Creator mianuje gracza tymczasowym
Praktykantem i daje mu pustą planetę oraz 200 lat. Gdy Praktykantowi idzie
dobrze, Creator przyspiesza kataklizmy (Próby).

Na końcu czeka Próba Ostateczna. Jeśli życie przetrwa, Praktykant
obroni tezę ("Teza obroniona"). Jeśli nie: "Creator miał rację".

---

# Platforma

Godot 4.7.2, GDScript, wydanie na Steamie (etap 6: GodotSteam,
osiągnięcia, chmura zapisów).

---

# Fantazja gracza

"Rozprzestrzeniam życie po planecie, wydaję Iskry na perki
i przetrwam Próby Creatora."

Gracz zbiera bąbelki, kupuje perki, widzi, jak mapa wypełnia się życiem,
i reaguje na zapowiedzi kryzysów.

---

# Pętla gry

| Poziom | Co robi gracz |
|---|---|
| sekundy | zbiera bąbelki na globusie i dostaje Iskry Życia |
| 1-2 minuty | kupuje perki, używa boskich mocy, reaguje na ostrzeżenie o Próbie |
| 5 minut | wybiera kierunek (drzewko) i tempo wzrostu, bo szybki wzrost drażni Creatora |
| partia (15-25 min) | 200 lat: od pustej planety do Próby Ostatecznej |
| meta | Dziedzictwo odblokowuje planety, perki startowe, trudność |

Szczegóły: `CORE_LOOP.md`.

---

# Obecny cel projektu

Przejście od gry w "obserwuj planetę" do pętli w stylu Plague Inc. Obecny prototyp ma dobrą symulację, ale gra nie wciąga:
brakowało ciągłej akcji, rosnącej siły, widocznej ekspansji, przeciwnika
i zegara.

Symulacja zostaje globalna (bez regionów). Zasięg życia modelują
kontynenty i pojemność gatunków.

Etapy (spec, rozdział 8):

0. dokumenty,
1. bąbelki, Iskry, sklep perków,
2. zasięg (kontynenty, drzewko Dyspersji),
3. Creator (Gniew, Próby, Wskaźnik Życia, wygrana i porażka),
4. meta (mutacje, Dziedzictwo, scenariusze),
5. fauna,
6. Steam.

Plan: `docs/superpowers/plans/2026-10-06-iskry-i-perki.md`.
Stan i historia: `docs/plan_rozwoju.md`.

---

# Priorytety

1. Grywalna pętla na mapie (bąbelki, perki, Próby)
2. Czytelność decyzji i kryzysów
3. Silnik symulacji
4. Oprawa

Każdy etap kończy się grywalną wersją i pytaniem do testera.

---

# Założenia projektowe

1. Każdy perk ma cenę i skutek uboczny.
2. Każda Próba jest zapowiedziana i ma przeciwdziałanie.
3. Wszystko wpływa na PlanetState.
4. Systemy ponad contentem.
5. Dane ponad kodem.

---

# Kryterium sukcesu

Gracz mówi:

"Jeszcze jeden perk, jeszcze jedna partia."

Vertical slice (etapy 1-3): partia trwa 15-25 minut, tester klika bąbelki
bez podpowiedzi (4-6 na minutę), bot wygrywa 40-60% partii na poziomie
normalnym, co najmniej 3 z 5 testerów zaczyna drugą partię bez zachęty,
każda Próba jest zapowiedziana i ma przeciwdziałanie.
