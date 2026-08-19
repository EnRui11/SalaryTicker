# SalaryTicker

<!-- language-bar -->
**English** · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

What you have earned so far today, ticking every second — in the Mac's menu bar, on the iPhone, on the Apple Watch, and on the Dynamic Island.

<img src="docs/panel.png" width="360" alt="The panel: today's earnings, the rates behind them, month to date, and two savings goals with the dates they will be paid for.">

It sits in the menu bar as a number and a small progress ring. Click it for the day's detail, the month so far, and how close you are to whatever you are saving for.

- **Ticks by the second** against your real schedule — hours, unpaid lunch, working days.
- **Knows about leave.** Public holidays, paid leave and unpaid leave land in different places, and unpaid leave only touches your basic, not your allowance.
- **Prices things in work.** A goal is shown in working days and in the date the schedule says it will be paid for, not just in money.
- **Nine languages**, any currency symbol, any IANA time zone.
- **No account, no network, no telemetry.** Everything is computed on your own machine from settings you typed.
- **Four screens, one calculation.** The Mac, the phone, the watch and the Dynamic Island all read the same domain code, so they cannot disagree about what a second is worth.

## Install

### The Mac app

Requires **macOS 26 or later** and a Swift 6 toolchain. Built and tested against Swift 6.3; earlier Swift 6 releases are untested.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
make install
```

That builds a release binary, generates the app icon from source, assembles `SalaryTicker.app`, ad-hoc signs it, copies it into `/Applications` and launches it. `make app` does the same without installing it.

There is nothing to un-quarantine: you compiled the binary yourself, so it never carries the download flag Gatekeeper looks for. The signature is ad-hoc, which is enough for a locally built app and gives the login item a stable identity.

To update, pull and run the same command — it replaces the installed copy and relaunches. Your settings live outside the bundle and are not touched.

To uninstall: quit from the panel, delete `/Applications/SalaryTicker.app`, and if you want the settings gone too, `defaults delete com.steve.salaryticker`.

### The iPhone and the Apple Watch

Requires **iOS 26 / watchOS 26**, Xcode 26, and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make run      # the phone, on the iOS Simulator
make watch    # the watch, on the paired watch simulator
```

Simulators only as it stands: every target is built with code signing off. Putting this on real hardware means adding an Apple ID in Xcode first, and a free account's provisioning profile expires after seven days — after which the app stops opening until you rebuild it.

On a real iPhone the watch app is not installed separately. It ships **inside** the phone app, so you install the phone app and then either leave Automatic App Install on, or open the iPhone's **Watch** app and tap Install beside SalaryTicker under Available Apps. Simulators have none of that machinery, which is why `make watch` puts it on the watch directly.

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

**Reorder them with the arrows beside each one, or by dragging.** A ringgit can only be spent once, so goals are funded from the top of the list down: a goal only starts filling once the ones above it are paid for, and its date includes the wait. Money already earned into a goal stays there — putting a new goal at the top does not claw back what an older one was paid with.

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

## On the phone and the watch

The same four numbers the panel shows, in the same order, because someone who uses both should not have to learn the app twice.

<img src="docs/phone.png" width="300" alt="The phone: today's earnings, the rates behind them, the month so far, and a goal with the date it will be paid for."> <img src="docs/watch.png" width="300" alt="The watch: today's earnings, the time left until clock-off, the month so far, and the first pinned goal.">

### Getting your settings across

Open **Settings → System → Send to phone** on the Mac and point the phone's camera at the QR code. Everything travels — salary, hours, working days, leave, goals — so the phone starts on your numbers instead of on the defaults.

Underneath, the code encodes a link. That is what makes the import testable at all: a simulator has no camera, but it can be handed a URL.

It holds your salary, which is why it is a picture and not a string you can copy. A code on a screen goes into a camera and nowhere else; the moment it became text in a share sheet it would have a chance of ending up somewhere it was never meant to be.

### The phone

One scrolling screen rather than the Mac's tabs, because a phone scrolls anyway and tabs would hide the thing you came to change behind a guess about which tab it lives in.

**Goals are added here**, from the main screen, and the sheet asks for the name and the price before it creates anything. Settings is where you rename, reprice, reorder and delete them.

### The watch

The watch app holds no settings of its own and gives you no way to type them — a watch cannot scan a QR code. It waits for the phone, which sends the newest settings every time one changes. So the phone app has to have been opened at least once, or the watch has nothing to show. There is a complication for the watch face as well.

### The Dynamic Island and the lock screen

Switched on under **Settings → Display → Dynamic Island**, and switched off there when you would rather not have your pay on the lock screen. iOS has its own switch for Live Activities; this one can only ever subtract from it.

What moves there moves with no code running. iOS animates the countdown to clock-off and the progress bar across a fixed range of dates, so both stay live and exact hours after the app was last open.

**The money does not**, and does not pretend to. Refreshing it needs the app in front or a push server, and this has neither — so it is shown as a figure with the time it was taken printed beside it. A ticker that has quietly stopped is worse than one that says when it stopped.

Touch and hold the island for the expanded view. A **tap opens the app**: iOS reserves the tap for that and offers no way to ask for anything else.

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
- **Simulators only on iOS.** Nothing here is signed for real hardware, and a free Apple account's profile lasts seven days, so a phone and a watch you actually carry would need re-deploying every week.

## Development

```bash
make                 # list every target
make test            # 276 tests
make install         # the Mac app, into /Applications
make run             # the iPhone app, on the simulator
make watch           # the watch app, on the paired watch simulator
```

Feature-first Clean Architecture, one SwiftPM target per layer, so the dependency direction is enforced by the compiler rather than by discipline. The design decisions, the money model's invariants, and the bugs that shaped them are written up in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

MIT — see [LICENSE](LICENSE).
