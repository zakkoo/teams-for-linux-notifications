# 05 Azure CLI → Graph
`az rest` against `/me/calendarView`, once a minute. The first run tries
`az login --scope https://graph.microsoft.com/Calendars.Read`; if the tenant demands admin consent
for Azure CLI you'll see AADSTS65001 / Unauthorized and this option is dead — delete it.
(A plain `az rest` already returned Unauthorized on this machine without that scope.)
