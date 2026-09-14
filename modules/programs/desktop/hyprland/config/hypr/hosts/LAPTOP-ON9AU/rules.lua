-- Workspace layout -- LAPTOP-ON9AU.
--
-- Workspaces 1-5 live on the ultrawide, 6-10 on the built-in panel, so
-- SUPER + <n> always lands on a predictable screen. Same split as the desktop
-- (hosts/desktop/rules.lua), and the same reason: the low numbers belong to
-- the big screen because that is where the work is.
--
-- Bound by the same desc: selectors monitors.lua uses -- workspace rules run
-- their monitor field through CMonitor::matchesStaticSelector, so `desc:` works
-- here exactly as it does in a monitor rule, and neither of these has a stable
-- connector name to bind to anyway.
--
-- UNDOCKED AND CLAMSHELL BOTH TAKE CARE OF THEMSELVES. A workspace bound to a
-- monitor that is not present opens on whatever is present, so undocked you get
-- all ten on the panel (as before), and with the lid shut you get all ten on
-- the ultrawide. Nothing here needs a host-of-a-host case.
local monitors = require("host").load("monitors")

-- Only 1-5 are persistent, i.e. only they show in waybar while empty.
--
-- That is the rule this file has always had, kept for the reason it was
-- written: ten permanently-lit numbers is most of a 16" bar gone to
-- workspaces nobody opened, and undocked the 16" bar is the only bar there is.
-- The five that are persistent are now the five on the ultrawide, which is
-- where there is room for them; 6-10 appear in the bar once something is on
-- them and disappear again after. SUPER + 6..0 work regardless -- see binds.lua.
for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = i <= 5 and monitors.ULTRAWIDE or monitors.PANEL,
        persistent = i <= 5,
    })
end
