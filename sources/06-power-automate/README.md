# 06 Power Automate → ntfy
Server-side: works even when Teams and the browser are closed.

Flow (make.powerautomate.com → Create → Automated cloud flow):
1. Trigger: **Office 365 Outlook – When an upcoming event is starting soon (V3)**.
   Calendar: Calendar. Look-ahead time: 2 (minutes).
2. Action, pick one:
   - **HTTP** (premium connector): POST `https://ntfy.sh/<NTFY_TOPIC>`, headers
     `Title: @{triggerOutputs()?['body/subject']}`, `Click: @{triggerOutputs()?['body/webLink']}`,
     body: `Starts @{formatDateTime(triggerOutputs()?['body/start'],'HH:mm')}`.
   - **Send an email (V2)** (standard, no premium): To `ntfy-<NTFY_TOPIC>@ntfy.sh`,
     Subject = event Subject, Body = Web link. ntfy turns the mail into a message (title = subject).
3. Put the same topic in `config.env` as `NTFY_TOPIC`, then `./start`.

Privacy: meeting subjects transit ntfy.sh. Use a long random topic, or self-host ntfy and set `NTFY_SERVER`.
