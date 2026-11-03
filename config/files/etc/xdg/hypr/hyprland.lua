-- Hyperblue system-wide defaults, copied to the user's config on first setup.
-- https://docs.noctalia.dev/noctalia/v5.4.1/compositor-settings/hyprland/

hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
end)

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("systemctl --user start xdg-desktop-portal-hyprland.service")
end)

hl.config({
  misc = { disable_hyprland_logo = true },
  input = { kb_layout = "gb" },
})

local mainMod = "SUPER"
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("Thunar"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(mainMod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
end

for i = 1, 5 do
  hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

local media = {
  XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
  XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
  XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  XF86AudioPlay = "playerctl play-pause",
  XF86AudioNext = "playerctl next",
  XF86AudioPrev = "playerctl previous",
  XF86MonBrightnessUp = "brightnessctl -q set 5%+",
  XF86MonBrightnessDown = "brightnessctl -q set 5%-",
}
for key, command in pairs(media) do
  hl.bind(key, hl.dsp.exec_cmd(command), { locked = true, repeating = true })
end
