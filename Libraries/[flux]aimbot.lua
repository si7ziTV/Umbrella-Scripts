-- ════════════════════════════════════════════════════════════════════════════════
-- [flux]aimbot.lua — _VERSION 1.0.2
-- ════════════════════════════════════════════════════════════════════════════════

-- 1.0.0		release flux auto-update skeleton ([flux].lua + libs + manifest)
-- 1.0.1		added Deadlock-native update stack (http.request, utils.reload_scripts, package.path dir detection), jsDelivr CDN fallback, lifecycle prints, debugprint
-- 1.0.2		updater simplified to self-only (standalone-library safe: no longer pulls sibling
--			files); aimbot logic (magnet/legitbot/psilent) deferred to a later phase

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
-- Auto Update (self-only)
-- ════════════════════════════════════════════════════════════════════════════════
-- Library file, not an entry point: never pulls sibling files. Keeps only ITSELF current
-- against the manifest, so it self-updates inside flux AND standalone (someone using just
-- this lib in their own project gets its updates without [flux].lua or other flux files
-- appearing). [flux].lua (the entry) is responsible for downloading it initially.

local _VERSION  = "1.0.2"
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

-- "1.0.1" → 10001, "2.0.0" → 20000. Arithmetic compare instead of table+loop.
local function newer(a, b)
	local function n(v)
		local x, y, z = tostring(v):match("(%d+)%.(%d+)%.(%d+)")
		return (tonumber(x) or 0) * 10000 + (tonumber(y) or 0) * 100 + (tonumber(z) or 0)
	end
	return n(a) > n(b)
end

-- HTTP GET with jsDelivr fallback. cb receives body or nil.
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

-- Fetches + decodes the manifest. cb receives the table or nil.
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
-- Update Logic (self-only)
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
			print(TAG .. " v" .. _VERSION .. " loaded — up to date (last updated " .. date .. ")")
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
-- Aimbot (logic deferred)
-- ════════════════════════════════════════════════════════════════════════════════
-- Magnet (warp), Legitbot (humanized pull) and PSilent move in with a later phase. The
-- menu settings they will read (per-channel FOV/render/color, presets, hitchance) already
-- live in [flux]menu.lua; this lib will consume them via the flux_menu (FM) handle once its
-- logic lands.
