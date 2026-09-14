-- Workspace layout -- the two-screen desktop.
--
-- Workspaces 1-5 belong to the AOC (left), 6-10 to the Dell (right), so
-- SUPER + <n> always lands on a predictable screen.
--
-- persistent keeps them alive even while empty, which is what makes all ten
-- numbers show up in waybar (and stay clickable) instead of appearing only
-- once something is open on them.
for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = i <= 5 and "DP-2" or "DP-1",
        persistent = true,
    })
end
