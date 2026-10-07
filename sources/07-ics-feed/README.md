# 07 Published ICS feed
Outlook Web → Settings → Calendar → Shared calendars → *Publish a calendar* → Calendar, "Can view all details"
→ Publish → copy the **ICS** link into `config.env` as `ICS_URL`. If the section is missing, the tenant
disabled publishing: delete this option.

Caveat: Microsoft refreshes published feeds lazily (often hours), so same-day invites may be missed.
Recurrence handling is minimal (daily/weekly, interval 1); see `alert/ics.py`.
