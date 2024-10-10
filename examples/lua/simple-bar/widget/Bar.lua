local astal = require("astal")
local App = astal.App
local Widget = astal.Widget
local Variable = astal.Variable
local Gdk = astal.Gdk
local GLib = astal.GLib
local bind = astal.bind
local Mpris = astal.require("AstalMpris")
local Battery = astal.require("AstalBattery")
local Wp = astal.require("AstalWp")
local Network = astal.require("AstalNetwork")
local Tray = astal.require("AstalTray")
local Hyprland = astal.require("AstalHyprland")
local map = require("lib").map

local function SysTray()
	local tray = Tray.get_default()

	return Widget.Box({
		bind(tray, "items"):as(function(items)
			return map(items, function(item)
				if item.icon_theme_path ~= nil then
					App:add_icons(item.icon_theme_path)
				end

				local menu = item:create_menu()

				return Widget.Button({
					tooltip_markup = bind(item, "tooltip_markup"),
					on_destroy = function()
						if menu ~= nil then
							menu:destroy()
						end
					end,
					on_click_release = function(self)
						if menu ~= nil then
							menu:popup_at_widget(self, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, nil)
						end
					end,
					Widget.Icon({
						g_icon = bind(item, "gicon"),
					}),
				})
			end)
		end),
	})
end

local function FocusedClient()
	local hypr = Hyprland.get_default()
	local focused = bind(hypr, "focused-client")

	return Widget.Box({
		class_name = "Focused",
		visible = focused,
		focused:as(function(client)
			return client and Widget.Label({
				label = bind(client, "title"):as(tostring),
			})
		end),
	})
end

local function Wifi()
	local wifi = Network.get_default().wifi

	return Widget.Icon({
		tooltip_text = bind(wifi, "ssid"):as(tostring),
		class_name = "Wifi",
		icon = bind(wifi, "icon-name"),
	})
end

local function AudioSlider()
	local speaker = Wp.get_default().audio.default_speaker

	return Widget.Box({
		class_name = "AudioSlider",
		css = "min-width: 140px;",
		Widget.Icon({
			icon = bind(speaker, "volume-icon"),
		}),
		Widget.Slider({
			hexpand = true,
			on_dragged = function(self)
				speaker.volume = self.value
			end,
			value = bind(speaker, "volume"),
		}),
	})
end

local function BatteryLevel()
	local bat = Battery.get_default()

	return Widget.Box({
		class_name = "Battery",
		visible = bind(bat, "is-present"),
		Widget.Icon({
			icon = bind(bat, "battery-icon-name"),
		}),
		Widget.Label({
			label = bind(bat, "percentage"):as(function(p)
				return tostring(math.floor(p * 100)) .. " %"
			end),
		}),
	})
end

local function Media()
	local player = Mpris.Player.new("spotify")

	return Widget.Box({
		class_name = "Media",
		visible = bind(player, "available"),
		Widget.Box({
			class_name = "Cover",
			valign = "CENTER",
			css = bind(player, "cover-art"):as(function(cover)
				return "background-image: url('" .. (cover or "") .. "');"
			end),
		}),
		Widget.Label({
			label = bind(player, "metadata"):as(function()
				return (player.title or "") .. " - " .. (player.artist or "")
			end),
		}),
	})
end

local function Workspaces()
	local hypr = Hyprland.get_default()

	return Widget.Box({
		class_name = "Workspaces",
		bind(hypr, "workspaces"):as(function(wss)
			table.sort(wss, function(a, b)
				return a.id < b.id
			end)

			return map(wss, function(ws)
				return Widget.Button({
					class_name = bind(hypr, "focused-workspace"):as(function(fw)
						return fw == ws and "focused" or ""
					end),
					on_clicked = function()
						ws:focus()
					end,
					label = bind(ws, "id"):as(function(v)
						return type(v) == "number" and string.format("%.0f", v) or v
					end),
				})
			end)
		end),
	})
end

local function Time(format)
	local time = Variable(""):poll(1000, function()
		return GLib.DateTime.new_now_local():format(format)
	end)

	return Widget.Label({
		class_name = "Time",
		on_destroy = function()
			time:drop()
		end,
		label = time(),
	})
end

return function(gdkmonitor)
	return Widget.Window({
		class_name = "Bar",
		gdkmonitor = gdkmonitor,
		anchor = astal.Astal.WindowAnchor.TOP + astal.Astal.WindowAnchor.LEFT + astal.Astal.WindowAnchor.RIGHT,
		exclusivity = "EXCLUSIVE",

		Widget.CenterBox({
			Widget.Box({
				halign = "START",
				Workspaces(),
				FocusedClient(),
			}),
			Widget.Box({
				Media(),
			}),
			Widget.Box({
				halign = "END",
				Wifi(),
				AudioSlider(),
				BatteryLevel(),
				SysTray(),
				Time("%H:%M - %A %e."),
			}),
		}),
	})
end
