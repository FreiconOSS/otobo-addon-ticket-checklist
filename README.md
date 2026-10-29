# TicketChecklist

<!-- section:overview -->
Adds a checklist to OTOBO tickets: a list of tasks, each with a state, and optionally a
responsible agent, a priority, a start date and a due date.

A typical case: every onboarding ticket needs the same eight steps — account, mailbox,
laptop, badge, phone, and so on. An administrator stores them once as a checklist
*template*. When the ticket is created (by an agent, by mail, by a process or by the
Generic Agent), the template is put on the ticket; the agents tick the steps off in the
ticket zoom, the people responsible for a step are notified when it is due, and the
ticket shows at a glance whether anything is still open.

This package is a port of **TicketChecklist 10.1.3 by Perl-Services.de** (Renée Bäcker) to
OTOBO 11, maintained by Freicon GmbH & Co. KG under the same license, AGPL-3.0. See
[License and origin](#license-and-origin).

<!-- section:flow -->
## What happens

```
agent opens "Checklist" in the ticket menu ─┐
template chosen in ticket create (phone/email)├─▶ items stored on the ticket (ps_ticketchecklist)
mail header X-OTRS-TicketChecklist*          │        │
Generic Agent / process transition action ───┘        ▼
                                             event TicketChecklistItem*  ──▶ history, change note,
                                                      │                     dynamic fields, conditions
                                                      ▼
                                       widget in the ticket zoom (sidebar), dashboards,
                                       "My todos", customer portal (if allowed), PDF print

daemon, every 10 minutes:
    due date reached / near   ──▶ notification to owner / responsible
    start date reached        ──▶ item state "waiting" → "open", notification
```

### The parts

- **Checklist mask** (ticket menu *Checklist*, `AgentTicketChecklist`) — add, edit, sort and
  delete items, or load a template. Two looks: *Standard* and *Slim*
  (`TicketChecklist::Theme`).
- **Widget in the ticket zoom** — the items of the ticket in the sidebar. Owner and
  responsible change the state right there.
- **Templates** (*Admin → Checklist templates*) — named lists of items with responsible,
  priority, due date offset, start date offset and comment. A template can be restricted to
  groups, and can carry *conditions and actions* (e.g. "when item X is *done*, set the
  ticket state to *closed successful*"). Templates can be exported and imported as JSON.
- **States** (*Admin → Checklist states*) — the item states with their colour. Installed:
  `open`, `done`, `rejected`, `waiting`, `in progress`.
- **Notifications** (*Admin → Checklist notifications*) — the texts sent when an item is
  due, reached its start date, or changed. Agents switch them on and off in their personal
  preferences (group *Checklist notifications*).
- **Overviews** — main menu *Tickets → Search Checklist Tickets* (tickets with open items)
  and *Tickets → My Checklist Todos* (items the agent is responsible for); two dashboard widgets with the same
  content; checklist items in the dashboard events calendar.
- **Export** — XLS, iCal and PDF of the checklist: icons in the widget (see
  `TicketChecklist::ShowExportIcons`) and the ticket menu entry *Print Checklist*. The
  ticket PDF with the checklist on top is the menu entry `210-PrintChecklist`, shipped
  disabled; with `ChecklistSelectArticle` the agent picks the articles for it.
- **Customer portal** — with `TicketChecklist::Feature::CustomerVisibility` an agent can show
  the checklist of a ticket to the customer. Per queue default: `Queues::CustomerVisibility`.

### Ways to put a checklist on a ticket

| Way | How |
|---|---|
| Agent | Ticket menu *Checklist*, items by hand or *load template*. |
| Ticket create | With `TicketChecklist::ShowChecklistInTicketCreate` the phone and email ticket masks show a template selection. |
| Mail | Header `X-OTRS-TicketChecklistID: <template id>` or `X-OTRS-TicketChecklistName: <template name>` on a new ticket; `X-OTRS-FollowUp-TicketChecklistID` / `-Name` on a follow-up. |
| Mail, change items | `X-OTRS-TicketChecklistItem-<n>: <item title>` plus `X-OTRS-TicketChecklistItem-<n>-Status`, `-StatusID`, `-DueDate`, `-ResponsibleID`, `-PriorityID` (n = 1…20). Changes the item with that title on the ticket the mail belongs to. |
| Generic Agent | Module `Kernel::System::GenericAgent::AddChecklistToTicket`, parameter `TemplateID`. Module `Kernel::System::GenericAgent::ChangeChecklistItems`, parameters `Item_1` (item title) with `Status_1`, `DueDate_1`, `Responsible_1` (login), `Priority_1` (name); `Item_2` … the same. |
| Process | Transition action `AddChecklist` (config `TemplateID`) and `ChangeChecklistItems` (same `Item_<n>` keys as the Generic Agent module). |

The install adds the mail headers to `PostmasterX-Header`. They keep the old `X-OTRS-`
prefix of the original addon, so existing mail rules and sending systems keep working.

<!-- section:configuration -->
## Configuration

All settings are in the system configuration under **Core → TicketChecklist** (and its
sub groups), plus the usual registration groups. Defaults below are the shipped values.

### General — `Core::TicketChecklist`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::DefaultState` | `open` | State of a new item. |
| `TicketChecklist::DefaultPriority` | `3 normal` | Priority of a new item (ticket priorities are used). Also the fallback when an item is saved without a priority. |
| `TicketChecklist::PrioritySource` | `DefaultPriority` | Where the default priority of a new item comes from: the setting above, or the ticket's priority. |
| `TicketChecklist::OpenStates` | `open` | States that count as "open" (overviews, dynamic field `TicketHasOpenTodos`). |
| `TicketChecklist::WaitingStates` | `waiting` | States of items that wait for their start date. |
| `TicketChecklist::HiddenStates` | *(empty, disabled)* | Items in these states are not shown in the zoom widget. |
| `TicketChecklist::ClosedState` | `done` | State the items get when the ticket is closed (event `1032-CloseChecklistItems`, disabled by default). |
| `TicketChecklist::Theme` | `Standard` | Look of the checklist mask: `Standard` or `Slim`. |
| `TicketChecklist::DetailsInWidget` | `Link` | How item details are shown in the widget: link, mouse-over, or not at all. |
| `TicketChecklist::Widget::ShowResponsibleFullname` | 0 | Show the responsible's full name instead of the login in the widget. |
| `TicketChecklist::ReloadChecklist` | 0 | Reload the widget after an item was changed. |
| `TicketChecklist::ReloadTicketZoom` | 0 | Reload the whole ticket zoom after an item was changed. |
| `TicketChecklist::AllUsersForResponsibles` | 1 | All agents can be chosen as responsible. Off: only agents with `ro` on the ticket's queue. |
| `TicketChecklist::AllAgentsStatusChange` | 0 | Every agent can change the state of every item. Off: only the ticket owner and the item's responsible. |
| `TicketChecklist::RWGroups` | *(empty, disabled)* | Only members of these groups (with `rw`) can edit the checklist. |
| `TicketChecklist::HardDeleteItems` | 1 | On: an item removed in the mask is deleted at once. Off: it is deleted when the checklist is saved. |
| `TicketChecklist::ConfirmDeleteItems` | 0 | Ask before an item is removed. |
| `TicketChecklist::KeepEntriesOnTemplateChange` | 0 | Loading a template adds its items instead of replacing the existing ones. |
| `TicketChecklist::ShowChecklistInTicketCreate` | 0 | Template selection in the phone and email ticket masks. |
| `TicketChecklist::AllowMultiChecklistsInTicketCreate` | 0 | Shows "Add items to existing checklist" next to that selection. |
| `TicketChecklist::OverrideExistingTemplatesOnImport` | 1 | A template import replaces templates with the same name. |
| `TicketChecklist::ShowExportIcons` | `TicketZoom` 1, `Dashboard (MyTodos)` 0 | Where the XLS/iCal/PDF icons are shown. |
| `TicketChecklist::PrintItemComment` | 0 | Print the item comment in the ticket PDF. |
| `TicketChecklist::PastDueDatesAllowed` | 1 | Off: a due date in the past is refused. |
| `TicketChecklist::DueDateYearsInPast` | 0 | Years in the past offered in the date selections. |
| `TicketChecklist::DynamicFieldHasOpenTodos` | `TicketHasOpenTodos` | Dynamic field that records whether the ticket has open items. |
| `TicketChecklist::Condition::MultiState` | 0 | A condition of a template can name several states (or-ed). |
| `TicketChecklist::AllowTicketsAsItems` | 0 | A ticket number can be entered as item title; the item then follows that ticket. |
| `TicketChecklist::LinkTickets` | 0 | With the option above: link that ticket to this one as child. |
| `TicketChecklist::TicketStateToItemState` | new/open/pending → `open`, merged/closed successful → `done`, … | Ticket state → item state, for tickets used as items. |
| `TicketChecklist::ItemStateToTicketState` | `open` → open, `done` → closed successful, `rejected` → closed unsuccessful | Item state → ticket state, for tickets used as items. |
| `TicketChecklist::Debug` | 0 | Debug output to the OTOBO log. |
| `Ticket::Frontend::HistoryTypes###212-Checklist` | | Shows the checklist history types in the ticket history. |

### Features — `Core::TicketChecklist::Features`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::Feature::DateStart` | 0 | Items get a start date. Before it they are in a waiting state; the daemon opens them. |
| `TicketChecklist::Feature::CustomerVisibility` | 0 | Agents can show the checklist of a ticket in the customer portal. |
| `TicketChecklist::Feature::FromTextarea` | 0 | Items can be entered as lines of a text area. |
| `Queues::CustomerVisibility` (in *CustomerVisibility*) | *(disabled)* `Misc` → 1 | Queues in which the checklist is visible to the customer by default. |

### Notifications — `Core::TicketChecklist::Notifications`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::DueDateBefore` | 60 | Minutes before the due date a notification is sent. |
| `TicketChecklist::NotificationTimes` | *(disabled)* `-60m`, `-5d` | Several points in time before the due date instead of the single one above. |
| `TicketChecklist::NotificationTimesSpan` | 10 | Minutes checked around each of those points — should equal the daemon interval. |
| `TicketChecklist::DateStartBefore` | 60 | Minutes before the start date a notification is sent. |
| `TicketChecklist::StartNotificationTimes` | *(disabled)* `-60m`, `-5d` | As `NotificationTimes`, for the start date. |
| `TicketChecklist::StartNotificationTimesSpan` | 10 | As `NotificationTimesSpan`, for the start date. |
| `TicketChecklist::NotificationQueueExclude` | *(disabled)* `Junk` | No checklist notifications for tickets in these queues. |
| `PreferencesGroups###ChecklistNotifications` | active | The agent preference to switch the notifications on and off. |

### Start date — `Core::TicketChecklist::StartDate`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::StartDate::NewState` | `open` | State an item gets when its start date is reached. |

### Change notes — `Core::TicketChecklist::ChangeNote`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::ShowChangeNotes` | 0 | Agents can add a note when they change an item in the mask. |
| `TicketChecklist::ShowChangeNotesWidget` | 0 | The same when the state is changed in the widget. |
| `TicketChecklist::ChangeNoteAsArticle` | 0 | The note becomes an article of the ticket. |
| `TicketChecklist::ChangeNoteArticle###Type` | `note-internal` | Article type of that article. |
| `TicketChecklist::ChangeNoteArticle###Subject` | `TODO changed` | Subject of that article. |
| `TicketChecklist::ChangeNoteAsNotification` | 1 | The note is part of the change notification. |
| `TicketChecklist::SaveChangeNote` | 0 | The note is stored at the item. |
| `TicketChecklist::EditChangeNote` | 0 | A stored note can be edited. |
| `TicketChecklist::ChangeNoteDialogRows` / `…Cols` | 10 / 40 | Size of the note field. |
| `TicketChecklist::ChangeNote::ASCII2HTML` | 0 | Show the note with line breaks and HTML escaping. |
| `TicketChecklist::ChangeNote::URLAutolink` | 0 | Turn URLs in the note into links (needs the option above). |

### Comments — `Core::TicketChecklist::Comment`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::Comment::ASCII2HTML` | 0 | Show the item comment with line breaks and HTML escaping. |
| `TicketChecklist::Comment::URLAutolink` | 0 | Turn URLs in the comment into links (needs the option above). |

### Responsible — `Core::TicketChecklist::Responsible`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::ResponsibleAutocomplete` | 0 | Replace the responsible dropdown with an autocomplete field. |
| `TicketChecklist::ResponsibleAutocompleteModule` | `Agent` | Source of that field: `Agent`, `LDAP`, `Groups`, `Roles`. |

The `LDAP` source reads its connection from the hash `TicketChecklist::ResponsibleLDAP`,
which is **not** a system configuration setting and has no default. Put it into
`Kernel/Config.pm`, in the same shape as an LDAP customer user backend:

```perl
$Self->{'TicketChecklist::ResponsibleLDAP'} = {
    Params => {
        Host   => 'ldap.example.com',
        BaseDN => 'ou=people,dc=example,dc=com',
        SSCOPE => 'sub',
        UserDN => '',            # empty = anonymous bind
        UserPw => '',
        AlwaysFilter => '',      # e.g. '(objectclass=user)'
        Die    => 0,
        Params => { port => 389, timeout => 120, async => 0, version => 3 },
    },
    UserKey             => 'uid',
    UserListFields      => [ 'cn', 'mail' ],
    UserSearchFields    => [ 'uid', 'cn', 'mail' ],
    UserSearchPrefix    => '',
    UserSearchSuffix    => '*',
    UserSearchListLimit => 250,
    UserNameFields      => [ 'givenname', 'sn' ],
    CacheTTL            => 0,
    Map => [ ... ],          # as in a customer user LDAP backend
};
```

Release 10.1.3 shipped `Kernel/Config/Files/ZZZChecklist.pm` with an example of this hash
pointing at a public university host. That file is gone; the upgrade removes it.

### Calendar — `Core::TicketChecklist::Calendar`

| Setting | Default | Meaning |
|---|---|---|
| `TicketChecklist::Calendar::Color` | `#cdcdcd` | Colour of the checklist entries in the dashboard events calendar. |
| `TicketChecklist::Calendar::TitleFormat` | `#[% Data.TicketNumber %] - [% Data.Title %]` | Title of an entry. |
| `TicketChecklist::Calendar::InfoFormat` | `[% Data.TicketNumber %] - [% Data.Title %]` | Mouse-over text of an entry. |

### Events — `Core::Event::Ticket`, `Core::Event::TicketChecklist`

Ticket events (`Ticket::EventModulePost###…`):

| Key | Default | What it does |
|---|---|---|
| `1031-MergeTicketChecklists` | on | Moves the items of a merged ticket to the target ticket. |
| `1032-CloseChecklistItems` | **off** | Sets all items to `TicketChecklist::ClosedState` when the ticket is closed. |
| `1033-UpdateChecklistItems` | on | Keeps items that stand for a ticket in step with that ticket. |
| `1037-SetTicketChecklists` | on | Puts the template chosen in the ticket create mask on the new ticket. |

Checklist events (`TicketChecklist::EventModule###…`), all on: `001-Notifications`,
`002-TicketHistory`, `003-ChangeNote`, `004-SetHasOpenTodos`, `005-ConditionAction`
(conditions and actions of the template), `006-SetHasChecklist`,
`007-SetDefaultCustomerVisibility`, `011-SetTicketState`, `012-ForeignTickets`,
`020-RemoveTicketInfoFlags`.

### Daemon — `Daemon::SchedulerCronTaskManager::Task`

| Task | Schedule | Console command |
|---|---|---|
| `ChecklistNotifications` | `*/10 * * * *` | `Maint::Ticket::ChecklistNotifications` — due date notifications |
| `ChecklistStartDateNotifications` | `*/10 * * * *` | `Maint::Ticket::ChecklistStartDateNotifications` — start date notifications |
| `ChecklistSetStartDateStatus` | `*/10 * * * *` | `Maint::Ticket::ChecklistSetStartDateStatus` — waiting → `StartDate::NewState` |
| `ChecklistClearPreferences` | `*/10 0 * * 0` | `Maint::Ticket::ChecklistClearPreferences` — resets the agents' preference for which tickets all items are shown |

### Registration

These settings only register the parts above in OTOBO; change them to move or switch off a
menu entry or widget.

| Setting | Default | Purpose |
|---|---|---|
| `Frontend::Module###AgentTicketChecklist`, `…ChecklistIDSet`, `…ChecklistTemplates`, `…ChangeChecklistStatus`, `…ChecklistResponsibleSearch`, `…ChecklistCustomerVisibility`, `…ChecklistCalendarAJAX`, `…PrintChecklist`, `AgentChecklistExport`, `AgentChecklistTickets`, `AgentChecklistMyTodo` | on | Agent modules. |
| `Frontend::Module###AdminTicketChecklistStates`, `…Templates`, `…Notifications` and `Frontend::NavigationModule###…` | on | Admin modules and their tiles in the admin overview. |
| `Frontend::Navigation###AgentChecklistTickets###002-TicketChecklist`, `###AgentChecklistMyTodo###002-TicketChecklist` | on | Main menu entries *Search Checklist Tickets* and *My Checklist Todos*. All other `Frontend::Navigation###…###002-TicketChecklist` entries are shipped disabled. |
| `Ticket::Frontend::MenuModule###212-Checklist`, `###213-ChecklistPrint` | on | Ticket menu *Checklist* and *Print checklist*. |
| `Ticket::Frontend::MenuModule###210-PrintChecklist` | off | Ticket menu *Print*: ticket PDF with the checklist in front of the articles. |
| `Ticket::Frontend::AgentTicketZoom###Widgets###002-TicketChecklist` | on | Widget in the ticket zoom. |
| `DashboardBackend###0991-ChecklistItems`, `###0992-ChecklistTicket` | on | Dashboard widgets. |
| `Frontend::Output::FilterElementPost###OutputFilterTicketChecklistDropdown` | on | Template selection in the ticket create masks. |
| `Frontend::Output::FilterElementPost###TicketChecklistCalendar` | on | Items in the dashboard events calendar. |
| `Frontend::Output::FilterElementPost###CustomerTicketChecklist` | on | Checklist in the customer ticket zoom. |
| `Frontend::Output::FilterElementPost###ChecklistSelectArticle` | off | Checkboxes in the article list to choose the articles for the ticket PDF. |
| `Frontend::Template::GenerateBlockHooks###132-TicketChecklist` | on | Block hooks the output filters need. |
| `Loader::Module::…###00x-TicketChecklist`, `Loader::Agent::CommonCSS###100001-TicketChecklist`, `Loader::Customer::CommonCSS###100001-TicketChecklist` | on | JavaScript and CSS. |
| `PostMaster::PostFilterModule###015-TicketChecklist`, `###016-TicketChecklistItem` | on | The mail headers above. |
| `Stats::DynamicObjectRegistration###TicketChecklistStatusFilter` | on | Ticket statistic filtered by item state. |
| `AutoloadPerlPackages###2000-TicketChecklist` | on | Removes the checklist of a ticket when the ticket is deleted. |

<!-- section:example -->
## Example: onboarding

1. *Admin → Checklist templates → Add*: name *Onboarding*, items *Create account*
   (responsible: IT, due +1 day), *Order laptop* (due +3 days), *Badge* (start +5 days,
   due +7 days). Group: *users*.
2. Enable `TicketChecklist::ShowChecklistInTicketCreate` and, for the start date,
   `TicketChecklist::Feature::DateStart`.
3. Create a phone ticket and choose *Onboarding* in the checklist field. The ticket zoom
   shows the three items; *Badge* is `waiting`.
4. The IT agent gets a notification one hour before *Create account* is due
   (`TicketChecklist::DueDateBefore`), sets it to `done` in the widget.
5. Five days later the daemon sets *Badge* to `open` and notifies its responsible.
6. *Tickets → Search Checklist Tickets* lists the ticket until all items are done; the dynamic
   field `TicketHasOpenTodos` can be used in searches, ACLs and the Generic Agent.

The same template can come by mail (`X-OTRS-TicketChecklistName: Onboarding`) or from a
process (transition action `AddChecklist` with the template's ID).

<!-- section:stored-value -->
## Data

| Table | Content |
|---|---|
| `ps_ticketchecklist` | Items: ticket, title, position, state, priority, responsible, start and due date, comment, change note. |
| `ps_ticketchecklist_status` | Item states and colours. |
| `ps_checklist_template`, `ps_checklist_tmpl_grp` | Templates and their groups (foreign key to `groups_table`). |
| `ps_checklist_notify` | Notification texts per event and language. |
| `ps_checklist_ticket_info` | Per ticket: whether the checklist is visible in the customer portal. |

Dynamic fields created on install (ticket, internal): `TicketHasOpenTodos`,
`TicketHasChecklist`, `TicketChecklistTemplates` (templates used on the ticket),
`TicketChecklistConditionActions` (conditions and actions taken over from the templates).

Times are stored in OTOBO time (`OTOBOTimeZone`) and shown in the agent's time zone.

<!-- section:errors -->
## When something is wrong

| Log message | Cause |
|---|---|
| `Need TicketChecklist::ResponsibleLDAP->Params->Host in Kernel/Config.pm` (also `BaseDN`, `SSCOPE`, `UserKey`) | `ResponsibleAutocompleteModule` is `LDAP`, but the hash `TicketChecklist::ResponsibleLDAP` is missing or incomplete. |
| `Can't connect to <host>: …` / `First bind failed! …` / `Search failed! …` | LDAP host not reachable, wrong bind user, wrong base DN. |
| `Need UserID!` | A Generic Agent job or transition action was configured without the parameter. |
| `Need TemplateID!` | Generic Agent module or transition action `AddChecklist` without `TemplateID`. |
| `Templatename already exists` | Template saved under a name in use. On import, see `OverrideExistingTemplatesOnImport`. |
| `Import: Can' find user/queue/state/priority …` | The imported template names something that does not exist on this system; the value is left out. |
| `Could not find notification for <event> (<language>)` (debug only) | No notification text for that event in the agent's language, so none is sent. Add one in *Admin → Checklist notifications* if it should be. Installed are German texts for *responsible changed*, *state changed* and *due date near*. |
| `State name alread in use` | A state with that name exists. |

No notifications at all: check that the daemon runs (`bin/otobo.Daemon.pl status`), that the
agent has not switched them off in the preferences, and that the ticket's queue is not in
`TicketChecklist::NotificationQueueExclude`.

<!-- section:limits -->
## Things to know

- **Upgrade from 10.1.3.** Install the package over the old one. The upgrade moves the files
  out of `Custom/`, points the template group key at `groups_table`, and removes the old
  setting `Ticket::CustomModule###10001-TicketChecklist`. Templates, items and states stay.
- The mail headers keep the `X-OTRS-` prefix of the original.
- Up to 20 items per mail can be changed with `X-OTRS-TicketChecklistItem-<n>`.
- The item title is the key for changing items by mail, Generic Agent and process — two items
  with the same title on one ticket: only the first one is changed.
- Priorities, responsibles, due dates, notifications, overviews, sorting and templates — sold
  as *Pro* features of the original on feature-addons.de — are part of this package.
- There is no customer-side editing; the customer only sees the list.

<!-- section:requirements -->
## Requirements

- OTOBO 11.0.x or 11.1.x (one package for both)
- Perl module `Net::LDAP`, only for the `LDAP` responsible source (an optional module of
  OTOBO, see `bin/otobo.CheckModules.pl`).
- No other packages.

<!-- section:technical -->
## Technical overview

| Path | Content |
|---|---|
| `Kernel/System/PerlServices/TicketChecklist*.pm` | Core API: items, states, templates, notifications, ticket info. |
| `Kernel/System/PerlServices/TicketChecklist/Event/` | Checklist event handlers. |
| `Kernel/System/PerlServices/TicketChecklist/ConditionAction/` | Actions of template conditions. |
| `Kernel/System/PerlServices/TicketChecklist/Autocomplete/` | Responsible sources Agent, LDAP, Groups, Roles. |
| `Kernel/System/Ticket/Event/` | Ticket event handlers (merge, close, create, update). |
| `Kernel/System/PostMaster/Filter/` | Mail header filters. |
| `Kernel/System/GenericAgent/`, `Kernel/System/ProcessManagement/TransitionAction/` | Generic Agent modules and transition actions. |
| `Kernel/System/Console/Command/Maint/Ticket/Checklist*.pm` | Daemon tasks. |
| `Kernel/System/Stats/` | Statistics. |
| `Kernel/Autoload/TicketChecklist.pm` | Wraps `Kernel::System::Ticket::TicketDelete`. |
| `Kernel/Modules/`, `Kernel/Output/HTML/` | Agent, admin and customer frontend, dashboard, output filters. |
| `Kernel/Output/PDF/TicketChecklist.pm` | Ticket PDF with checklist (subclass of `Kernel::Output::PDF::Ticket`). |
| `var/httpd/htdocs/js/PS.*.js` | JavaScript. |
| `var/packagesetup/TicketChecklist.pm` | Install/upgrade code: dynamic fields, mail headers, clean-up. |
| `var/doc/TicketChecklist/COPYING` | License text, shipped with the package. |

No OTOBO core file is overridden.

### Tests

```bash
cd /opt/otobo
bin/otobo.Console.pl Dev::UnitTest::Run --test TicketChecklist/OTOBO11
```

`scripts/test/TicketChecklist/OTOBO11.t` covers what changed for OTOBO 11: the group foreign
key, the time windows of the daemon jobs (with a frozen clock), the date selection in the
agent's time zone, the ticket PDF with and without article selection, and the clean-up on
ticket delete.

### Build

The OPM is built by the workflow `.github/workflows/build.yml` with
`freiconoss/action-opm-build` when a tag is pushed; the version comes from the tag.

<!-- section:background -->
## License and origin

TicketChecklist was written by Renée Bäcker, Perl-Services.de, and published under the GNU
Affero General Public License v3.0. This repository starts with the unchanged release
10.1.3 (first commit), followed by the changes for OTOBO 11 by Freicon GmbH & Co. KG
(October 2026): time handling on `Kernel::System::DateTime`, the renamed `groups_table`,
the ticket PDF on the OTOBO 11 PDF backend, the autoload wrapper instead of
`Ticket::CustomModule`, files out of `Custom/`, the system configuration navigation,
the removal of the LDAP example configuration, and a few fixes found on the way (the
*Print Checklist* menu entry pointed at a module that does not exist; the zoom widget
checked the permission without a ticket id; notifications looked up a responsible for
items that have none; a missing notification text was logged as an error).
Every changed file carries a modification notice with the date.

The whole work stays under AGPL-3.0; the full text is in [`LICENSE`](LICENSE) and is shipped
in the package as `var/doc/TicketChecklist/COPYING`. If you run a modified version for users
over a network, AGPL §13 requires that you offer them its source code.

Contributors to the original: Denny Bresch (translations, HTML), Balázs Úr (Hungarian
translation).
