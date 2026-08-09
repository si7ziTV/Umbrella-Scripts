-- ════════════════════════════════════════════════════════════════════════════════
-- [flux]aimbot.lua — _VERSION 1.0.0
-- ════════════════════════════════════════════════════════════════════════════════

-- 1.0.0		release flux auto-update skeleton

-- ════════════════════════════════════════════════════════════════════════════════
-- Utilities
-- ════════════════════════════════════════════════════════════════════════════════

local function debugprint(...)
	local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Developer Mode")
	if ok and w and w:Get() then
		print(...)
	end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- Auto Update
-- ════════════════════════════════════════════════════════════════════════════════

local _VERSION  = "1.0.0"
local FILE_NAME = "[flux]aimbot.lua"
local TAG       = "flux-aimbot"
local ROOT      = "https://raw.githubusercontent.com/si7ziTV/Umbrella-Scripts/main"
local MANIFEST  = "flux_versions.json"
local json      = require("assets.JSON")

local SCRIPTS = ""
for entry in (package.path or ""):gmatch("[^;]+") do
	local dir = entry:gsub("%?.-$", "")
	local f = dir ~= "" and io.open(dir .. FILE_NAME, "r") or nil
	if f then
		f:close()
		SCRIPTS = dir
		break
	end
end

-- ────────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────────────────────────────────────

local function newer(a, b)
	local function n(v)
		local x, y, z = tostring(v):match("(%d+)%.(%d+)%.(%d+)")
		return (tonumber(x) or 0) * 10000 + (tonumber(y) or 0) * 100 + (tonumber(z) or 0)
	end
	return n(a) > n(b)
end

local function fetch(url, cb)
	debugprint("[flux-dbg] GET " .. url:sub(1, 120))
	local function req(u, is_fb)
		http.request(u):get():user_agent("Umbrella/1.0"):timeout(10):send(function(s, b, ok)
			if ok and s == 200 then
				cb(b)
			elseif not is_fb then
				debugprint("[flux-dbg] → jsDelivr")
				req(url:gsub("raw%.githubusercontent%.com", "cdn.jsdelivr.net/gh"):gsub("Umbrella%-Scripts/main", "Umbrella%-Scripts@main"), true)
			else
				cb(nil)
			end
		end)
	end
	req(url, false)
end

local function save(name, body)
	if not body or body:sub(1, 2) ~= "--" then
		return false
	end
	local f = io.open(SCRIPTS .. name, "w")
	if not f then
		return false
	end
	f:write(body)
	f:close()
	return true
end

local function manifest(cb)
	fetch(ROOT .. "/" .. MANIFEST, function(body)
		if not body then
			cb(nil)
			return
		end
		local ok, m = pcall(function() return json:decode(body) end)
		cb(ok and type(m) == "table" and m or nil)
	end)
end

-- ────────────────────────────────────────────────────────────────────────────────
-- Update Logic
-- ────────────────────────────────────────────────────────────────────────────────

local function run()
	manifest(function(m)
		if not m then
			print(TAG .. " ✗ manifest unreachable")
			return
		end
		local me = m[FILE_NAME]
		if not (me and me.url) then
			return
		end
		local date = me.last_updated and me.last_updated:sub(1, 10) or "?"
		if not newer(me.version, _VERSION) then
			debugprint(TAG .. " v" .. _VERSION .. " loaded — up to date (last updated " .. date .. ")")
			return
		end
		local vu = tostring(me.version)
		print(TAG .. " v" .. _VERSION .. " loaded — Update: " .. _VERSION .. " → " .. vu .. " (" .. date .. ") — downloading…")
		fetch(me.url, function(b)
			if b and b:match('_VERSION%s*=%s*"' .. vu .. '"') and save(FILE_NAME, b) then
				print(TAG .. " ✓ Update " .. vu .. " installed — reloading scripts")
				utils.reload_scripts()
			else
				print(TAG .. " ✗ Update " .. vu .. " failed to install")
			end
		end)
	end)
end

pcall(run)

-- ════════════════════════════════════════════════════════════════════════════════