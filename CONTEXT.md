# Accrue

Accrue helps a worker see a calming real-time estimate of compensation accrued during the workday.

## Language

**Accrued Amount**:
The estimated gross compensation accumulated during an **Accrual Period**.
_Avoid_: Earned Today, live earnings, income

**Accrual Period**:
The time range used to calculate an **Accrued Amount**.
_Avoid_: Window, range, timeframe

**Work Start**:
The point inside an **Accrual Period** when compensation begins accruing.
_Avoid_: Clock-in, start counting

**Working Hours**:
The scheduled span inside an **Accrual Period** when the **Accrued Amount** normally increases.
_Avoid_: Business hours, office hours

**Working Day**:
A configured day of the week when **Working Hours** can accrue compensation.
_Avoid_: Business day, weekday

**Pay Rule**:
The compensation rule used to calculate accrual for a span of time.
_Avoid_: Salary setting, rate config

**Currency**:
The monetary unit used to display and interpret a **Pay Rule** and **Accrued Amount**.
_Avoid_: Exchange rate, locale

**Local Time**:
The current system time used to evaluate **Working Hours** and **Day Accrual**.
_Avoid_: Fixed timezone, work timezone

**Hourly Rate**:
A **Pay Rule** expressed as compensation per hour.
_Avoid_: Wage

**Annual Salary**:
A **Pay Rule** expressed as compensation per year.
_Avoid_: Yearly wage

**Monthly Salary**:
A **Pay Rule** expressed as compensation per month.
_Avoid_: Monthly rate

**Salary Assumption**:
A default value used to convert an **Annual Salary** or **Monthly Salary** into an **Hourly Rate**.
_Avoid_: Payroll config, salary formula

**Activation Setup**:
The minimum information needed before an **Accrued Amount** can start updating.
_Avoid_: Onboarding, initial config

**Period Reset**:
The moment an **Accrued Amount** returns to zero for a new **Accrual Period**.
_Avoid_: Clear, rollover

**Day Accrual**:
An **Accrual Period** that starts accruing at that day's **Work Start** and resets at the next **Work Start**.
_Avoid_: Today, calendar day

**Calm Mode**:
A display mode that shows only the **Accrued Amount**.
_Avoid_: Simple mode, basic mode

**Rate Mode**:
A display mode that shows the **Accrued Amount** with the live rate.
_Avoid_: Detailed mode, speed mode

**Menu Bar Presence**:
The always-available menu bar entry that shows the **Accrued Amount**.
_Avoid_: Dock app, main window

**Popover Panel**:
A temporary panel for checking status and changing common settings.
_Avoid_: Dashboard, main app

**Waiting State**:
The state before **Work Start** on a **Working Day**.
_Avoid_: Before work

**Rest State**:
The state on a day that is not a **Working Day**.
_Avoid_: Non-working day, weekend

**Stealth Mode**:
A display mode that hides compensation amounts while preserving a rewarding money-related presence.
_Avoid_: Hide Amount, privacy mode

**Product Analytics**:
Non-compensation usage data collected to understand product behavior.
_Avoid_: User data, salary analytics

**Anonymous Install**:
A local app installation used for **Product Analytics** without a signed-in account.
_Avoid_: Anonymous user, device identity

**Optional Account**:
A signed-in account used for optional sync and continuity.
_Avoid_: Required login, user profile

**Account Sync**:
Optional synchronization of Accrue data across installs signed into the same **Optional Account**.
_Avoid_: Device sync, iPhone sync

## Relationships

- An **Accrued Amount** belongs to exactly one **Accrual Period**
- The v1 **Accrual Period** is **Day Accrual**
- An **Accrued Amount** starts increasing at **Work Start** and returns to zero at **Period Reset**
- A **Day Accrual** keeps its final amount after work ends until the next **Work Start**
- An **Accrued Amount** increases during **Working Hours** on **Working Days**
- An **Accrued Amount** is calculated from configuration and current time, not stored
- An **Accrued Amount** includes elapsed **Working Hours** even when Accrue was not running
- **Currency** is a display and input unit, not an exchange-rate conversion
- **Currency** formatting follows the system formatter for the selected currency and locale
- **Working Hours** and **Day Accrual** are evaluated in **Local Time**
- **Working Hours** use a **Pay Rule**
- A **Pay Rule** can be an **Hourly Rate**, **Monthly Salary**, or **Annual Salary**
- An **Annual Salary** or **Monthly Salary** uses **Salary Assumptions** to derive an **Hourly Rate**
- **Activation Setup** includes currency and **Pay Rule**
- **Activation Setup** excludes device preferences such as launch at login
- **Calm Mode** is the default display mode
- **Rate Mode** is optional
- **Menu Bar Presence** is the primary way users interact with Accrue
- **Popover Panel** supports quick status checks and common low-stress settings
- **Product Analytics** never includes **Pay Rule**, **Accrued Amount**, or exact **Working Hours**
- **Anonymous Install** is the normal v1 identity
- **Optional Account** is not required to use Accrue
- **Account Sync** happens between installs under the same **Optional Account**
- **Waiting State** uses a menu bar icon instead of a zero amount
- **Rest State** uses a menu bar icon instead of a zero amount
- After **Working Hours**, **Menu Bar Presence** shows the final **Accrued Amount**
- **Stealth Mode** hides exact amounts without making Accrue feel inactive
- **Stealth Mode** takes precedence over **Calm Mode** and **Rate Mode** in **Menu Bar Presence**
- The default **Working Hours** are 9:00 to 17:00
- The default **Working Days** are Monday through Friday

## Example dialogue

> **Dev:** "Should the menu bar show **Earned Today**?"
> **Domain expert:** "No. It should show the **Accrued Amount** for the selected **Accrual Period**."
> **Dev:** "If the selected **Accrual Period** is today, does it count from midnight?"
> **Domain expert:** "No. It starts from **Work Start**, such as 9am, and resets at **Period Reset**."
> **Dev:** "Does **Day Accrual** reset at midnight?"
> **Domain expert:** "No. It resets when the next **Work Start** begins."
> **Dev:** "Does the amount increase overnight?"
> **Domain expert:** "No. It only increases during **Working Hours** on **Working Days**."
> **Dev:** "What should the user enter for normal compensation?"
> **Domain expert:** "They can enter an **Hourly Rate**, **Monthly Salary**, or **Annual Salary**."
> **Dev:** "Does a salaried user need to configure every detail before the amount works?"
> **Domain expert:** "No. **Salary Assumptions** provide defaults and can be changed only when needed."
> **Dev:** "What are the default **Working Hours**?"
> **Domain expert:** "9:00 to 17:00."
> **Dev:** "Does a weekly amount increase over the weekend?"
> **Domain expert:** "No. It increases during **Working Hours** on **Working Days**."
> **Dev:** "If the app opens at 13:00, does the amount start from zero?"
> **Domain expert:** "No. It includes the elapsed **Working Hours** for the current **Day Accrual**."
> **Dev:** "What has to be collected before the menu bar amount can run?"
> **Domain expert:** "**Activation Setup** only needs currency and **Pay Rule**; **Working Hours** use defaults unless changed."
> **Dev:** "Should the menu bar always show the live rate?"
> **Domain expert:** "No. **Calm Mode** is the default, and **Rate Mode** is optional."
> **Dev:** "Should Accrue behave like a normal Dock app?"
> **Domain expert:** "No. **Menu Bar Presence** is primary, but reopening the app should show settings."
> **Dev:** "Is the popover the main experience?"
> **Domain expert:** "No. The **Menu Bar Presence** is primary; the **Popover Panel** is temporary."
> **Dev:** "Should the menu bar show $0 before work starts?"
> **Domain expert:** "No. **Waiting State** uses an icon until **Work Start**."
> **Dev:** "Should the menu bar hide the amount after work ends?"
> **Domain expert:** "No. It shows the final **Accrued Amount**."
> **Dev:** "Should amount hiding feel like privacy panic?"
> **Domain expert:** "No. **Stealth Mode** keeps the product feeling rewarding while hiding exact amounts."
> **Dev:** "If **Rate Mode** and **Stealth Mode** are both enabled, what wins?"
> **Domain expert:** "**Stealth Mode** wins for **Menu Bar Presence**."
> **Dev:** "Can product analysis include salary or accrued amounts?"
> **Domain expert:** "No. **Product Analytics** excludes compensation values and exact schedule details."
> **Dev:** "Does every person need an account?"
> **Domain expert:** "No. Most use happens through an **Anonymous Install**; an **Optional Account** is for sync."
> **Dev:** "Is sync specifically Mac-to-iPhone?"
> **Domain expert:** "No. **Account Sync** connects installs under the same **Optional Account**."

## Flagged ambiguities

- "live earnings" was used to mean money accumulated today, this week, this month, this year, or a custom range; resolved: use **Accrued Amount** for the amount and **Accrual Period** for the selected time range.
- "period selection" was narrowed for v1; resolved: v1 uses **Day Accrual** only.
- "today" was ambiguous between a calendar day and a working day; resolved: the amount starts at **Work Start**, not necessarily midnight.
- "reset" was ambiguous between midnight reset and next-start reset; resolved: **Day Accrual** resets at the next **Work Start**.
- "salary input" was ambiguous between hourly and yearly compensation; resolved: support **Hourly Rate**, **Monthly Salary**, and **Annual Salary**.
- "status bar display" was ambiguous between amount-only and amount-with-rate; resolved: default to **Calm Mode** and offer **Rate Mode**.
- "analytics" was ambiguous between behavior data and compensation data; resolved: **Product Analytics** excludes salary, accrued amounts, and exact schedules.
- "user" was ambiguous between an installation and a signed-in person; resolved: use **Anonymous Install** for normal v1 usage and **Optional Account** for sync.
- "sync" was ambiguous between device pairing and account continuity; resolved: use **Account Sync** across installs signed into the same **Optional Account**.
