# Architecture and implementation notes

Everything here is about how SalaryTicker is built. For what it does and how to
install it, see the [README](../README.md).

## Layers

Feature-first Clean Architecture. **Each layer is its own SwiftPM target**, so the
dependency direction is enforced by the compiler rather than by discipline: Domain cannot
import Data, Application cannot import SwiftUI, and Presentation reaches the outside world
only through Application.

```
Sources/
  Domain/                     pure business rules, no dependencies
    Entities/                 Earnings, WorkStatus, MonthOverview
    ValueObjects/             TimeOfDay, SalaryConfig, AppLanguage, DayKey
    Services/                 EarningsCalculator
    Repositories/             SettingsRepository, LoginItemService, TimeSource (protocols only)
  Application/
    UseCases/                 CalculateEarnings, Load/SaveSettings, SetLaunchAtLogin
  Data/
    DTOs/                     SalaryConfigDTO (Codable, tolerant decoding)
    Mappers/                  DTO ↔ domain
    DataSources/Local/        UserDefaultsStore
    Repositories/             UserDefaultsSettingsRepository
  Shared/                     domain-neutral reusable pieces
    Localization/             Strings
    Formatting/               money, durations, status text
  Core/
    System/                   SMAppServiceLoginItem
    DI/                       AppContainer (composition root)
  Presentation/
    State/                    TickerViewModel — its own library target, see below
    App/ Pages/ Components/ Debug/    executable target
Tests/
  DomainTests/ ApplicationTests/ DataTests/ SharedTests/ PresentationTests/
Packaging/                    Info.plist + build script
```

Module names carry a `Salary` prefix (`SalaryDomain`, `SalaryData`, …) because bare `Data`
and `Core` would shadow Foundation types and system modules. The folders keep the plain
layer names.

### Why the view model is a target of its own

An executable target cannot be imported by tests, and the view model is the only part of
the app that keeps state between ticks: caches of the month sweep and of each goal's
history, all keyed on which day it is. Nothing else needs a clock — the calculators take
`now` as an argument, which is what makes them so easy to test — but a cache keyed on
"today" is wrong for exactly one moment a day, at an hour nobody is watching.

So `TickerViewModel` takes a `TimeSource`, and `PresentationTests` moves the day underneath
a single live instance: the ticker starts over, the month total absorbs yesterday, the grid
moves its marker, the goals keep counting, and the daily rate changes as August's 21
working days give way to September's 22. The same tests cover the clicks — paging the
month, marking leave, adding and removing goals — which are otherwise unreachable without
accessibility permissions.

## Localization

Nine languages: English (default), 简体中文, 日本語, 한국어, Español, Français, Deutsch,
Português, Bahasa Melayu.

`Strings` is one entry per string with all nine translations as labelled arguments:

```swift
public var earnedToday: String {
    t(en: "Earned today", zh: "今日已赚", ja: "本日の収入", ko: "오늘 번 금액",
      es: "Ganado hoy", fr: "Gagné aujourd'hui", de: "Heute verdient",
      pt: "Ganho hoje", ms: "Pendapatan hari ini")
}
```

No bundle, no `.strings` files, no build phase — and the compiler enforces completeness:
adding a language to `AppLanguage` breaks `t` until every string is translated, so a
half-localized build cannot ship.

The selected language also drives `Locale`, so both `DatePicker` and the amounts follow it:
`$1,234.50` in English, `1.234,50 $` in German — grouping, decimal separator and symbol
placement all move. A nine-language UI wrapped around English-formatted numbers is the kind
of mismatch you feel without being able to name it.

Source code, comments and this README are English only. The string table is the single
exception, which is the point of having one.

## Tests

```bash
swift test
```

156 tests across four targets. The interesting ones live at the boundaries: before work,
lunch, after clock-off, weekends, midnight rollover, first and last day of the month,
daylight saving in both directions, zones with DST gaps, zones chosen explicitly, upgrading
a config saved by an older build, and divide-by-zero / NaN.

These are **mutation tested** — reverting the implementation makes them fail, so they are
load-bearing rather than decorative:

| Test | Symptom when reverted |
|---|---|
| `daylightSavingFallBackNeverPaysMoreThanAFullDay` | 16.7% overpay on the 25-hour day |
| `theSameInstantMeansDifferentThingsInDifferentTimeZones` | the `calendar` argument is ignored |
| `aCountdownNeverExceedsTheLengthOfTheShift` | "24h 0m until clock-off" on a 90-minute shift |
| `resolvedIsMonotonicAcrossEveryMinuteOfATransitionDay` | start lands after end; the whole day pays nothing |
| `aConfigSavedBeforeTheLanguageSettingExistedStillLoads` | adding a field silently resets every setting |
| `launchingWithTheIntentOffNeverTouchesTheSystem` | startup silently strips a background entry nobody asked to remove |
| `aSwitchedOffToggleBehavesExactlyAsIfTheFeatureDidNotExist` | overtime pays out even with its switch off |
| `paidLeaveLeavesTheDivisorSoTheWorkingDaysPayMore` | a paid holiday stops raising the rate of the days you work |
| `unpaidLeaveStaysInTheDivisorSoTheMonthComesUpShort` | unpaid leave costs nothing instead of a day's pay |
| `aMonthWithNoWorkingDaysLeftDoesNotDivideByZero` | an all-holiday month divides by zero |
| `aGoalWorthWholeDaysLandsOnTheLastOfThemRatherThanTheDayAfter` | round-numbered goals slip a day, or a weekend |

### A note on `TimeOfDay.resolved`

`Calendar.date(bySettingHour:)` is not trustworthy on a daylight saving transition day.
Asked for a wall-clock time the gap swallowed, it may return the next day, return nil, or —
worst, because it looks correct — return a same-day instant whose clock reads something
else: in Pacific/Chatham it answers 03:04 with **04:00**, which is later than its answer for
03:54.

So every candidate is read back and verified. Without that check `resolved` is not
monotonic, `workStart` can land after `workEnd`, and a real shift pays nothing all day.
Only an exhaustive sweep of every IANA zone across a year surfaced it.

### A note on overtime

Overtime is strictly opt-in: with the switch off, the calculation is byte-identical to a
build without the feature — the multiplier and cap are inert until it is turned on.

The app has no idea when you actually left your desk — it only knows the schedule you gave
it. So overtime accrues from clock-off, stops at a configurable cap (4 hours by default),
and never crosses midnight. Without the cap, a Mac left running overnight would invent a
full evening of pay.

### A note on launch at login

`SMAppService.mainApp.status` cannot be trusted on its own. macOS records menu bar apps in
Background Task Management merely for having run, and reports that as `.enabled` even when
nothing ever called `register()` — so a toggle bound to the system status shows "on" for an
app that will not actually start at login.

The stored intent is the source of truth. At launch the app reconciles the system to it in
one direction only: it registers when the intent is on, and never unregisters, because
"the user never asked for auto-start" is not the same as "the user wants the entry macOS
made on its own taken away".

## Hidden diagnostics

```bash
/Applications/SalaryTicker.app/Contents/MacOS/SalaryTicker --login-status
/Applications/SalaryTicker.app/Contents/MacOS/SalaryTicker --render-shots ~/Desktop/shots
```

`--render-shots` uses `NSHostingView.cacheDisplay` to render every panel and settings state
to PNGs offscreen — no screen recording or accessibility permission needed. Useful for
checking a UI change, and for spotting a translation that overflows its row.

## Why the ring is in the menu bar and not on the app icon

The obvious place for a live progress indicator looks like the app icon, and it is the one
place it cannot go. The app is `LSUIElement`, so it has no Dock tile for
`applicationIconImage` to update, and rewriting the bundle's own `.icns` at runtime would
break its code signature to change a Finder window nobody is looking at.

The status item is already visible and already redrawing every second, so that is where the
ring lives: empty before the day starts and on days off, filling through the day, complete
once you have clocked off.

It is drawn to a **template image** rather than left as SwiftUI shapes — `MenuBarExtra`'s
label only reliably renders `Text` and `Image`, and a bare `Circle` silently renders as
nothing — and wrapped in an `Equatable` view so SwiftUI skips it on the ticks where the
percentage has not moved. Without that skip the ring roughly doubled idle CPU; with it the
ring costs about a tenth of a percent.

## The icon

Drawn in SwiftUI and generated from source rather than kept as a binary blob:

```bash
./Packaging/build_app.sh            # copies Packaging/AppIcon.icns into the bundle
SalaryTicker --render-appicon out.iconset && iconutil -c icns out.iconset
```

A milled gold coin struck with a `$`, inside the same progress arc the panel draws. It was
picked by rendering every candidate at **32 points** and throwing away the ones that died
there — a banknote lost its clock hand, a clock dial lost its ticks, and a cat collapsed
into a generic four-legged blob. Only shapes that survive Finder's list view are icons; the
rest are illustrations.

