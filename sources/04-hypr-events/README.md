# 04 Hyprland window events
Zero-dependency: listens on Hyprland's event socket for new windows / title changes from the
`teams-for-linux` class. Every Teams title is logged to stderr — run it over a day, see what Teams
puts in the title when a meeting starts, then set `HYPR_TITLE_PATTERN` in config.env.
Weakest option (titles are locale-dependent and Teams may not change them at all), but free to try.
