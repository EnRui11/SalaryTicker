# SalaryTicker

<!-- language-bar -->
[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt.md) · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

Eine macOS-Menüleisten-App, die im Sekundentakt zeigt, was du heute bisher verdient hast.

<img src="docs/panel.png" width="360" alt="Das Panel: der heutige Verdienst, die Sätze dahinter, der Monat bisher und zwei Sparziele mit dem Datum, an dem sie jeweils bezahlt sein werden.">

Sie sitzt als Zahl und kleiner Fortschrittsring in der Menüleiste. Ein Klick zeigt die Details des Tages, den bisherigen Monat und wie nah du dem bist, worauf du gerade sparst.

- **Tickt im Sekundentakt** nach deinem echten Zeitplan — Arbeitszeit, unbezahlte Mittagspause, Arbeitstage.
- **Kennt freie Tage.** Feiertage, bezahlter Urlaub und unbezahlter Urlaub landen an verschiedenen Stellen, und unbezahlter Urlaub geht nur vom Grundgehalt ab, nicht von den Zulagen.
- **Rechnet Preise in Arbeit um.** Ein Ziel wird in Arbeitstagen angezeigt und mit dem Datum, an dem es laut Zeitplan bezahlt ist — nicht nur in Geld.
- **Neun Sprachen**, jedes Währungssymbol, jede IANA-Zeitzone.
- **Kein Konto, kein Netzwerk, keine Telemetrie.** Alles wird auf deinem Mac aus den Einstellungen berechnet, die du eingetippt hast.

## Installation

Erfordert **macOS 26 oder neuer** und eine Swift-6-Toolchain. Gebaut und getestet mit Swift 6.3; frühere Swift-6-Versionen sind ungetestet.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
./Packaging/build_app.sh install
```

Das baut ein Release-Binary, erzeugt das App-Symbol aus den Quellen, setzt `SalaryTicker.app` zusammen, signiert sie ad hoc, kopiert sie nach `/Applications` und startet sie. Lässt du das Argument `install` weg, wird nur ins Arbeitsverzeichnis gebaut, ohne zu installieren.

Es gibt nichts aus der Quarantäne zu holen: Du hast das Binary selbst kompiliert, es trägt also nie das Download-Flag, nach dem Gatekeeper sucht. Die Signatur ist ad hoc, was für eine lokal gebaute App genügt und dem Anmeldeobjekt eine stabile Identität gibt.

Zum Aktualisieren pullst du und führst denselben Befehl aus — er ersetzt die installierte Kopie und startet sie neu. Deine Einstellungen liegen außerhalb des Bundles und bleiben unangetastet.

Zum Deinstallieren: im Panel beenden, `/Applications/SalaryTicker.app` löschen, und wenn auch die Einstellungen weg sollen, `defaults delete com.steve.salaryticker`.

## Erster Start

In der Menüleiste steht `Gehalt festlegen`, bis der Zeitplan Sinn ergibt. Öffne im Panel **Einstellungen** und fülle drei Dinge aus:

1. **Tab Gehalt** — dein Grundgehalt und daneben etwaige feste Zulagen.
2. **Tab Arbeitszeit** — Arbeitsbeginn, Arbeitsende und die unbezahlte Mittagspause.
3. **Tab Gehalt, Arbeitstage** — an welchen Wochentagen du arbeitest und welche davon halbe Tage sind.

<img src="docs/settings.png" width="420" alt="Der Tab Gehalt: Grundgehalt, Zulagen, die Zahl der Arbeitstage des Monats, der daraus abgeleitete Stundensatz und das Monatsraster zum Markieren freier Tage.">

Mehr braucht es zum Start nicht. Alles Weitere ist optional.

## Einrichtung

### Grundgehalt und Zulagen

Zwei Felder, weil eine Gehaltsabrechnung mindestens zwei Zeilen hat und freie Tage die beiden unterschiedlich behandeln:

- **Grundgehalt** ist der Teil, von dem unbezahlter Urlaub abgezogen wird.
- **Zulagen** sind ein fester Monatsbetrag — Fahrtkosten, Telefon —, der voll gezahlt wird, ob du unbezahlten Urlaub genommen hast oder nicht.

Hast du keine Zulagen, lass das Feld auf null, dann ändert sich nichts. Hast du welche, ist die saubere Trennung genau das, was verhindert, dass ein Tag unbezahlter Urlaub mehr kostet, als er wirklich kostet.

### Arbeitstage, Feiertage und Urlaub

Wähle deine Wochentage und markiere einzelne davon als **halben Tag** (etwa einen Samstagvormittag) — er zählt überall als halb.

Ein Klick auf ein Datum im Monatsraster schaltet weiter: **Arbeitstag → bezahlt frei → unbezahlt → Arbeitstag**. Die Pfeile links und rechts vom Titel blättern durch die Monate, und der Titel selbst führt zurück zu heute; so lassen sich die Feiertage des nächsten Jahres eintragen, bevor sie da sind.

Die beiden Arten freier Tage landen an verschiedenen Stellen, und genau dieser Unterschied ist der Punkt:

|                       | Was er bewirkt                                                                                                                                                                                             |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bezahlter** Feiertag | Kostet dich nichts. Dasselbe Gehalt deckt jetzt weniger Arbeitstage ab, also ist jeder Tag, den du *tatsächlich* arbeitest, etwas mehr wert. Am Feiertag selbst tickt nichts — sein Anteil verteilt sich auf die übrigen Tage. |
| **Unbezahlter** Urlaub | Kostet einen Tag **Grundgehalt**. Deine Zulagen kommen weiterhin in voller Höhe.                                                                                                                           |

Eine Folge, die man kennen sollte: Markierst du einen **bereits vergangenen** Tag als bezahlten Feiertag, sinkt der Wert für **Diesen Monat**, weil der Anteil dieses Tages nun an den noch kommenden Tagen verdient werden muss. Zum Monatsende landet er wieder bei deinem Gehalt.

### Überstunden

Standardmäßig aus. Eingeschaltet zählt die App über das Arbeitsende hinaus weiter, mit einem Zuschlagsfaktor, den du festlegst.

Die Überstunden sind **gedeckelt** — standardmäßig vier Stunden, und nie über Mitternacht hinaus —, weil die App nicht weiß, wann du tatsächlich gegangen bist. Ohne Obergrenze würde ein Mac, der über Nacht läuft, sich einen ganzen Abend Lohn ausdenken.

### Ziele

Trag ein, worauf du sparst. Jedes Ziel zeigt, was es in **Arbeitstagen** kostet, und das Datum, an dem es laut Zeitplan bezahlt ist. Was du im Panel sehen willst, heftest du dort an; der Rest bleibt in den Einstellungen.

**Sortiere sie mit den Pfeilen neben jedem Eintrag um, oder per Ziehen.** Ein Ringgit lässt sich nur einmal ausgeben, also werden Ziele von oben nach unten bedient: ein Ziel beginnt sich erst zu füllen, wenn die darüber bezahlt sind, und sein Datum enthält diese Wartezeit. Geld, das bereits in ein Ziel geflossen ist, bleibt dort — ein neues Ziel ganz oben holt sich nichts von einem älteren zurück, das schon bedient wurde.

Das Datum **bleibt stehen, solange du arbeitest.** Was du verdienst und was die Uhr tut, rücken gemeinsam vor; deinem Zeitplan zu folgen hält das Versprechen also, statt es zu verschieben. Verschieben lässt es sich nur, indem du den Zeitplan darunter änderst — freie Tage markieren, einen Arbeitstag streichen, die Arbeitszeit kürzen.

### Die Menüleiste

| Option                              | Was sie bewirkt                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------------------ |
| Fortschrittsring                    | Ein kleiner Ring neben der Zahl, der sich über den Tag füllt                                     |
| Währungssymbol                      | Ein- oder ausblenden, um ein Zeichen Breite zurückzugewinnen                                     |
| Außerhalb der Arbeitszeit nur Symbol | Klappt das Element ein, wenn sich die Zahl nicht bewegt — abends, am Wochenende, vor dem Arbeitsbeginn |
| **Betrag ausblenden**               | Nimmt das Geld aus der Menüleiste, bis du es zurückholst, ganz gleich, was die Uhr sagt          |

**Betrag ausblenden** ist auch der erste Eintrag im Panel, einen Klick von der Menüleiste entfernt, für den Moment, in dem ein Anruf beginnt oder jemand über deine Schulter mitliest. Es verbirgt nie *alles* — der Ring bleibt, sonst gäbe es nichts mehr anzuklicken, um die Zahl zurückzuholen.

### Beim Anmelden starten

Setzt voraus, dass die App aus `/Applications` läuft. Gespeichert wird, was du verlangt hast: Ist der Schalter an, registriert sich die App beim Start selbst und meldet sich nie wieder ab, denn macOS führt Menüleisten-Apps schon deshalb als Anmeldeobjekte, weil sie einmal gelaufen sind, und seiner Antwort ist in keine Richtung zu trauen.

## Wie die Zahl zustande kommt

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Beide Divisoren beziehen sich auf den **echten Kalendermonat**, ein voll gearbeiteter Monat ergibt also genau dein Gehalt, und der Tagessatz verschiebt sich von Monat zu Monat ein wenig — der August 2026 hat 21 Arbeitstage, der September 22, der Februar 2027 20.

Die bezahlten Stunden pro Tag ergeben sich aus Arbeitsbeginn, Arbeitsende und der Mittagspause. Es gibt kein eigenes Feld „Stunden pro Tag“, die beiden können sich also nie widersprechen.

### Sie kann nicht driften

Jede Aktualisierung rechnet aus `(settings, now)` neu und **akkumuliert nichts**. Deckel zuklappen, Ruhezustand, beenden und neu starten, die Systemuhr verstellen, über Zeitzonen hinwegfliegen — nichts davon kann die Zahl falsch machen, weil es keine laufende Summe gibt, die falsch werden könnte.

Der Timer sagt nur „Zeit zum Neuzeichnen“. Er zählt nicht, und er fällt in ein 20-Sekunden-Nickerchen, sobald die Zahl eingefroren ist, also an den meisten Abenden und an jedem Wochenende.

### Es gibt bewusst keine Pausentaste

Die Zählung läuft an beiden Enden des bezahlten Fensters in die Sättigung: ein Augenblick vor dem Arbeitstag ist null wert, einer danach einen ganzen Tag. Die Zahl **hält deshalb nach dem Arbeitsende von selbst an und setzt sich um Mitternacht von selbst zurück** — kein Timer, der zu stoppen wäre, kein Zustand, der zurückgesetzt werden müsste.

Eine manuelle Pause gab es kurzzeitig. Sie war der einzige akkumulierte Zustand der App und die Quelle ihrer beiden schlimmsten Bugs: eine über Nacht laufende Pause zog mehr als einen ganzen Arbeitstag ab und nullte den nächsten, und eine nach dem Arbeitsende gestartete Pause ließ die bereits feststehende Tagessumme *rückwärts* ticken. Die Funktion zu löschen löschte die ganze Fehlerklasse.

## Bekannte Grenzen

- **Keine Nachtschichten.** Das Arbeitsende muss nach dem Arbeitsbeginn liegen; sonst sagt die App „Einrichtung unvollständig“, statt eine falsche Zahl zu zeigen.
- **Kein Bonus.** Abgebildet werden nur feste monatliche Zulagen. Eine gelegentliche Zahlung oder ein Jahresbonus müsste auf einen Sekundenwert umgelegt werden, um hier aufzutauchen, und das schmeichelt der Zahl, statt sie zu beschreiben.
- **Keine Steuer, kein EPF, kein SOCSO.** Alle Beträge sind brutto.
- **Keine Historie.** Der Wert für **Diesen Monat** wird aus dem Zeitplan dieses Monats abgeleitet, nicht aus einer Aufzeichnung dessen, was tatsächlich gearbeitet wurde. Änderst du Gehalt oder Arbeitszeit, werden die bereits vergangenen Tage des laufenden Monats neu bepreist.
- **Nur ein Zeitplan.** Ein Muster, das nicht wöchentlich ist — jeder zweite Samstag, ein rotierender Schichtplan —, lässt sich nur ausdrücken, indem du die Ausnahmen von Hand markierst.

## Entwicklung

```bash
make                 # list every target
make test            # 268 tests
make install         # the Mac app, into /Applications
make run             # the iPhone app, on the simulator
```

Feature-first Clean Architecture, ein SwiftPM-Target pro Schicht, damit die Abhängigkeitsrichtung vom Compiler erzwungen wird und nicht von Disziplin. Die Entwurfsentscheidungen, die Invarianten des Geldmodells und die Bugs, die sie geprägt haben, stehen in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE).
