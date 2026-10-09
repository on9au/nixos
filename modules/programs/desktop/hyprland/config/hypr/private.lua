-- Brave is the private browser. It lives on its own special workspace, out of
-- the workspace list and the bar, and is blacked out of screenshots,
-- recordings and screen shares unless capture is allowed for the session.
-- Its copies are kept out of cliphist by bin/cliphist-store.

local mod = "SUPER"

local function is_brave(class)
    -- brave-browser natively, Brave-browser under XWayland, brave-<id>-Default
    -- for installed web apps.
    return class:lower():find("^brave%-") ~= nil
end

hl.window_rule({
    name      = "brave-private-workspace",
    match     = { class = "^([Bb]rave-.*)$" },
    workspace = "special:private",
})

-- Toggling the rule re-applies it to open windows straight away. A config
-- reload re-creates it enabled, so protection never stays off by accident.
local no_capture = hl.window_rule({
    name            = "brave-no-capture",
    match           = { class = "^([Bb]rave-.*)$" },
    no_screen_share = true,
})

hl.bind(mod .. " + SHIFT + B", function()
    for _, w in ipairs(hl.get_windows()) do
        if is_brave(w.class) then
            hl.dispatch(hl.dsp.workspace.toggle_special("private"))
            return
        end
    end
    hl.exec_cmd("brave")
end, { desc = "show/hide Brave" })

hl.bind(mod .. " + CTRL + B", function()
    local protect = not no_capture:is_enabled()
    no_capture:set_enabled(protect)
    hl.notification.create({
        text    = protect and "Brave hidden from capture" or "Brave can be captured",
        timeout = 3000,
    })
end, { desc = "toggle Brave capture protection" })
