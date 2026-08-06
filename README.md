# SalaryTicker

A macOS menu bar app that shows how much you have earned so far today, ticking every second.

```
$76.6468
```

## Install

```bash
./Packaging/build_app.sh install
```

Builds release, assembles `SalaryTicker.app`, ad-hoc signs it, copies it into
`/Applications` and launches it. Drop the `install` argument to build without installing.

## How the number is calculated

```
daily pay   = monthly salary ÷ workday equivalents in the current month
per second  = daily pay ÷ paid seconds per day
today       = paid seconds elapsed today × per second
this month  = completed workdays × daily pay + today
```

The divisor comes from the weekday selection, counted against the real calendar month, so a
fully worked month adds up to exactly the monthly salary and the daily rate shifts slightly
month to month. A weekday can be a **half day** (a Saturday morning, say) and counts as
half — the month still totals your salary.

**Holidays and leave** are marked per date by clicking the month grid: workday → paid
holiday → unpaid leave → workday. The two land in different places:

- A **paid** holiday leaves the divisor. The same salary now covers fewer working days, so
  every day you do work is worth a little more, and the month still totals your salary.
  Nothing ticks on the holiday itself — its share rides on the other days.
- **Unpaid** leave stays in the divisor and pays nothing, which is exactly how the month
  ends up one day's pay short.

The grid pages between months with the arrows either side of its title; the title itself is
the way back to the current month. Marking leave works on any month you can reach, so next
month's public holidays can go in before they arrive. The workday count and hourly rate above
the grid follow whichever month is on screen, so paging to September answers "what will a
day be worth then" rather than repeating this month. The menu bar keeps ticking against
today regardless.

One consequence worth knowing: marking a day that has already passed as a paid holiday
makes month-to-date drop, because that day's share now has to be earned on the days still
ahead. By the end of the month it lands back on your salary.

Paid hours per day are derived from clock-in, clock-off and the lunch break. There is no
separate "hours per day" field, so the two can never contradict each other.

### Why the number is still correct after a sleep

`EarningsCalculator` is a pure function: every refresh recomputes from
`(config, now)` and **accumulates nothing**. Closing the lid, sleeping, quitting and
relaunching, changing the system clock, flying across time zones — none of it can make the
number drift, because there is no running total to drift.

The timer only says "time to redraw". It does not count — and it slows to a 20-second nap
whenever the number is frozen, which is most evenings and every weekend.

### Why there is no pause button

`paidSecondsAccrued` saturates at both ends of the paid window: an instant before the
working day returns zero, one after it returns a full day. So the number **stops on its own
after clock-off and resets on its own at midnight** — no timer to stop, no state to reset.

A manual pause did exist briefly. It was the only accumulated state in the app, and the
source of both of its high-severity bugs: a pause left running overnight charged more than
a whole working day and zeroed the next one, and a pause started after clock-off made the
settled daily total tick *backwards*. Deleting the feature deleted the entire bug class.

## Settings

| Setting | Notes |
|---|---|
| Monthly salary | Gross, in whatever currency the symbol denotes |
| Clock in / clock off | Overnight shifts are not supported |
| Unpaid lunch break | Excluded from the paid daily total |
| Overtime | Keep counting after clock-off, with a rate multiplier and a cap |
| Workdays | Weekday selection, each full or half; drives the monthly divisor |
| Holidays / leave | Click a date in the grid: paid holiday or unpaid leave |
| Goals | Things you are saving for, priced in working days; tick one to pin it to the panel |
| Time zone | Follows this Mac by default; pick one if your hours belong elsewhere |
| Language | 9 languages, English by default |
| Currency symbol, decimals | Free text (defaults to `$`) and 0–6 places |
| Menu bar | Live progress ring; hide the currency symbol; collapse to an icon outside working hours |
| Launch at login | Requires the app to run from `/Applications` |

The Salary tab also draws the current month as a grid: solid squares are workdays already
behind you, outlined ones are still to come, today is ringed. Changing the weekday
selection redraws it, which is the quickest way to see what the change costs.

## Goals

A price is easier to judge as time than as money — "is this worth two and a bit days of my
life" lands differently from "$1,100". Each goal shows both: what it costs in working days,
and the date the schedule says it will be paid for.

The date **holds still while you work**. What you earn and what the clock does advance
together, so simply following your schedule keeps the promise rather than moving it; the
only thing that shifts it is changing the schedule underneath — marking leave, dropping a
workday, shortening the hours. Progress is derived from `(schedule, start date, now)` rather
than accumulated in a counter, for the same reason nothing else here accumulates.

Two parts of a projection are expensive — walking back over every day since saving started,
and walking forward to the date it lands on — and neither moves within a day. Left on the
tick they cost milliseconds *per goal per second*, and worse, they grow with the goal's age:
a goal set today costs a fraction of a millisecond, the same goal six months later costs
nine. They are computed once a day and the running total is patched on top, which makes the
per-tick cost flat at about 0.08 ms no matter how old or large the goal is.

## Architecture

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

## Known limits

- **No overnight shifts.** Clock-off must be later than clock-in; otherwise the app shows
  "Setup incomplete" rather than a wrong number.
- **No overtime, leave, or tax.** Everything is computed against an idealised working day.
- **No history.** Month-to-date is derived from the current month's workdays, not from a
  record of what was actually worked.

### Why the ring is in the menu bar and not on the app icon

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

## License

MIT — see [LICENSE](LICENSE).
