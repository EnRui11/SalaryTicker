# SalaryTicker

<!-- language-bar -->
**English** · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

A macOS menu bar app that shows what you have earned so far today, ticking every second.

<img src="docs/panel.png" width="360" alt="The panel: today's earnings, the rates behind them, month to date, and two savings goals with the dates they will be paid for.">

It sits in the menu bar as a number and a small progress ring. Click it for the day's detail, the month so far, and how close you are to whatever you are saving for.

- **Ticks by the second** against your real schedule — hours, unpaid lunch, working days.
- **Knows about leave.** Public holidays, paid leave and unpaid leave land in different places, and unpaid leave only touches your basic, not your allowance.
- **Prices things in work.** A goal is shown in working days and in the date the schedule says it will be paid for, not just in money.
- **Nine languages**, any currency symbol, any IANA time zone.
- **No account, no network, no telemetry.** Everything is computed on your Mac from settings you typed.

## Install

Requires **macOS 14 or later** and a Swift 6 toolchain. Built and tested against Swift 6.3; earlier Swift 6 releases are untested.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
./Packaging/build_app.sh install
```

That builds a release binary, generates the app icon from source, assembles `SalaryTicker.app`, ad-hoc signs it, copies it into `/Applications` and launches it. Drop the `install` argument to build into the working directory without installing.

There is nothing to un-quarantine: you compiled the binary yourself, so it never carries the download flag Gatekeeper looks for. The signature is ad-hoc, which is enough for a locally built app and gives the login item a stable identity.

To update, pull and run the same command — it replaces the installed copy and relaunches. Your settings live outside the bundle and are not touched.

To uninstall: quit from the panel, delete `/Applications/SalaryTicker.app`, and if you want the settings gone too, `defaults delete com.steve.salaryticker`.

## First run

The menu bar shows `Set salary` until the schedule makes sense. Open **Settings** from the panel and fill in three things:

1. **Salary tab** — your basic salary, and any fixed allowance beside it.
2. **Hours tab** — clock-in, clock-off, and the unpaid lunch break.
3. **Salary tab, Workdays** — which weekdays you work, and which of those are half days.

<img src="docs/settings.png" width="420" alt="The Salary tab: basic salary, allowance, the month's workday count, the derived hourly rate, and the month grid for marking leave.">

That is enough to start. Everything else is optional.

## Setting it up

### Basic salary and allowance

Two fields, because a payslip has at least two lines and leave treats them differently:

- **Basic salary** is the part unpaid leave comes out of.
- **Allowance** is a fixed monthly sum — transport, phone — paid in full whether or not you took leave without pay.

If you have no allowance, leave it at zero and nothing changes. If you do, splitting them correctly is what stops a day of unpaid leave from costing more than it really does.

### Working days, holidays and leave

Pick your weekdays, and mark any of them as a **half day** (a Saturday morning, say) — it counts as half everywhere.

Click a date in the month grid to cycle it: **workday → paid holiday → unpaid leave → workday**. The arrows either side of the title page between months, and the title itself is the way back to today, so next year's public holidays can go in before they arrive.

The two kinds of leave land in different places, and the difference is the point:

|                  | What it does                                                                                                                                                                                  |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Paid** holiday | Costs you nothing. The same salary now covers fewer working days, so every day you *do* work is worth a little more. Nothing ticks on the holiday itself — its share rides on the other days. |
| **Unpaid** leave | Costs one day of **basic** salary. Your allowance still arrives in full.                                                                                                                      |

One consequence worth knowing: marking a day that has **already passed** as a paid holiday makes month-to-date drop, because that day's share now has to be earned on the days still ahead. By the end of the month it lands back on your salary.

### Overtime

Off by default. Turned on, it keeps counting past clock-off at a rate multiplier you set.

It is **capped** — four hours by default, and never past midnight — because the app has no idea when you actually left. Without a ceiling, a Mac left running overnight would invent a full evening of pay.

### Goals

Add the things you are saving for. Each one shows what it costs in **working days** and the date the schedule says it will be paid for. Pin the ones you want in the panel; the rest stay in Settings.

The date **holds still while you work.** What you earn and what the clock does advance together, so following your schedule keeps the promise rather than moving it. The only thing that shifts it is changing the schedule underneath — marking leave, dropping a workday, shortening the hours.

### The menu bar

| Option                          | What it does                                                                           |
| ------------------------------- | -------------------------------------------------------------------------------------- |
| Progress ring                   | A small ring beside the number, filling through the day                                |
| Currency symbol                 | Show or hide it, to buy back a character of width                                      |
| Icon only outside working hours | Collapses the item when the number is not moving — evenings, weekends, before clock-in |
| **Hide amount**                 | Takes the money out of the menu bar until you ask for it back, whatever the clock says |

**Hide amount** is also the first item in the panel, one click from the menu bar, for when a call is starting or someone is reading over your shoulder. It never hides *everything* — the ring stays, or there would be nothing left to click to bring the number back.

### Launch at login

Needs the app to be running from `/Applications`. What you asked for is what is stored: the app registers itself at startup when the toggle is on, and never unregisters, because macOS lists menu bar apps as login items merely for having run once and its answer cannot be trusted either way.

## How the number is worked out

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Both divisors are counted against the **real calendar month**, so a fully worked month adds up to exactly your salary and the daily rate shifts a little month to month — August 2026 has 21 working days, September has 22, February 2027 has 20.

Paid hours per day come from clock-in, clock-off and the lunch break. There is no separate "hours per day" field, so the two can never contradict each other.

### It cannot drift

Every refresh recomputes from `(settings, now)` and **accumulates nothing**. Closing the lid, sleeping, quitting and relaunching, changing the system clock, flying across time zones — none of it can make the number wrong, because there is no running total to go wrong.

The timer only says "time to redraw". It does not count, and it slows to a 20-second nap whenever the number is frozen, which is most evenings and every weekend.

### There is no pause button, on purpose

The count saturates at both ends of the paid window: an instant before the working day is worth zero, one after it is worth a full day. So the number **stops on its own after clock-off and resets on its own at midnight** — no timer to stop, no state to reset.

A manual pause did exist briefly. It was the only accumulated state in the app and the source of both of its worst bugs: a pause left running overnight charged more than a whole working day and zeroed the next one, and a pause started after clock-off made the settled daily total tick *backwards*. Deleting the feature deleted the entire class of bug.

## Known limits

- **No overnight shifts.** Clock-off must be later than clock-in; otherwise the app says "Setup incomplete" rather than showing a wrong number.
- **No bonus.** Only a fixed monthly allowance is modelled. An occasional or year-end payment would have to be amortised into a per-second figure to appear here, and that flatters the number rather than describing it.
- **No tax, EPF or SOCSO.** Every figure is gross.
- **No history.** Month-to-date is derived from this month's schedule, not from a record of what was actually worked. Editing your salary or hours re-prices the days already behind you in the current month.
- **One schedule.** A pattern that is not weekly — alternating Saturdays, a rotating shift — cannot be expressed except by marking the exceptions by hand.

## Development

```bash
swift build          # build
swift test           # 210 tests
./Packaging/build_app.sh    # assemble the .app without installing
```

Feature-first Clean Architecture, one SwiftPM target per layer, so the dependency direction is enforced by the compiler rather than by discipline. The design decisions, the money model's invariants, and the bugs that shaped them are written up in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

MIT — see [LICENSE](LICENSE).
