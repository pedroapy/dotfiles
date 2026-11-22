-- ── Rosé Pine Moon Theme Colors ──────────────────
-- Reference: https://rosepinetheme.com/palette/ingredients/

local M = {}

M.hex = {
    base          = "232136",
    surface       = "2a273f",
    overlay       = "393552",
    muted         = "6e6a86",
    subtle        = "908caa",
    text          = "e0def4",
    love          = "eb6f92",
    gold          = "f6c177",
    rose          = "ea9a97",
    pine          = "3e8fb0",
    foam          = "9ccfd8",
    iris          = "c4a7e7",
    highlight_low = "2a283e",
    highlight_med = "44415a",
    highlight_high = "56526e",
}

-- rgb("iris") -> "rgb(c4a7e7)"
function M.rgb(name)
    return "rgb(" .. M.hex[name] .. ")"
end

-- rgba("iris", "ee") -> "rgba(c4a7e7ee)"
function M.rgba(name, alpha)
    return "rgba(" .. M.hex[name] .. alpha .. ")"
end

return M
