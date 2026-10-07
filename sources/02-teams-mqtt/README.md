# 02 Teams for Linux → MQTT
Teams for Linux (≥2.20) can publish `meeting-started` pulses and dump your calendar (via the
Graph token the Teams web app already holds — no app registration) over MQTT. No broker is
installed on this machine, so `start` *is* the broker: a ~100-line stdlib one that only serves Teams.

Setup:
1. Merge `config.json` here into `~/.config/teams-for-linux/config.json` (create it if missing).
2. `./start`, then restart Teams for Linux. You should see `connected: teams-for-linux` on stderr.
3. Every 5 min it asks Teams for today's calendar and alerts `LEAD_MINUTES` before each event;
   `meeting-started` alerts immediately when Teams shows its "Meeting started" banner (English UI only).

If you'd rather run mosquitto, install it yourself, replace `start` with a `mosquitto_sub -t 'teams/#'` loop.
