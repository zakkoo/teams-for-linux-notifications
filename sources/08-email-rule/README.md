# 08 Outlook rule → IMAP mailbox
Outlook Web → Settings → Mail → Rules: "If message is a meeting invitation → Forward to <some mailbox you
can read over IMAP>" (a personal mailbox with an app password works; O365 itself no longer allows IMAP basic auth).
Set `IMAP_HOST/IMAP_USER/IMAP_PASS` in config.env. Invites are parsed from the `.ics` attachment, so recurring
meetings keep firing from one forwarded mail. Updates/cancellations that arrive later override only if the UID matches.
