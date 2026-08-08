-- ════════════════════════════════════════════════════════════════════════════════
-- [flux]targetselector.lua  —  PURE Selektions-Lib (0 % Userscript)
-- _VERSION 1.0.0  ·  Nachfolger von inspire-targetselector-final.lua
-- ════════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════════
-- Utilities
-- ════════════════════════════════════════════════════════════════════════════════

-- fluxprint: drop-in for print, but output only when Developer Mode is on.
local function fluxprint(...)
	local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Developer Mode")
	if ok and w and w:Get() then
		print(...)
	end
end


-- ════════════════════════════════════════════════════════════════════════════════
-- Auto Update
-- ════════════════════════════════════════════════════════════════════════════════

local _VERSION  = "1.0.0"
local FILE_NAME = "[flux]targetselector.lua"
local ROOT      = "https://raw.githubusercontent.com/si7ziTV/Umbrella-Scripts/main"
local MANIFEST  = "flux_versions.json"
local PUBLIC    = { "[flux].lua", "[flux]targetselector.lua", "[flux]aimbot.lua" }
local json      = require("assets.JSON")
local SCRIPTS   = Engine.GetCheatDirectory() .. "/scripts/"


-- ────────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────────────────────────────────────

-- remote > local? (semver core, suffix ignored)
local function newer(a, b)
	local function p(v)
		local M, m, n = tostring(v):match("(%d+)%.(%d+)%.(%d+)")
		return { M and tonumber(M) or 0, m and tonumber(m) or 0, n and tonumber(n) or 0 }
	end

	local ra, rb = p(a), p(b)

	for i = 1, 3 do
		if ra[i] ~= rb[i] then
			return ra[i] > rb[i]
		end
	end

	return false
end

-- HTTP GET; cb receives body or nil.
local function get(url, cb)
	HTTP.Request(
		"GET",
		url,
		{ headers = { ["User-Agent"] = "Umbrella/1.0" } },
		function(r)
			cb(r and r.code == 200 and r.response or nil)
		end,
		"flux_" .. FILE_NAME
	)
end

-- Writes the file only if the body starts with "--" (a Lua file, not an HTML error page).
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


-- ────────────────────────────────────────────────────────────────────────────────
-- Update Logic
-- ────────────────────────────────────────────────────────────────────────────────

-- Updater: pulls missing sibling files first (unthrottled), then self-updates
-- when the manifest reports a newer _VERSION.
local function run()
	local miss = {}

	for _, n in ipairs(PUBLIC) do
		if n ~= FILE_NAME then
			local f = io.open(SCRIPTS .. n, "r")
			if f then
				f:close()
			else
				miss[#miss + 1] = n
			end
		end
	end

	if #miss > 0 then
		get(ROOT .. "/" .. MANIFEST, function(body)
			local ok, m = pcall(function()
				return json:decode(body)
			end)

			if not ok or type(m) ~= "table" then
				return
			end

			local fetch = {}

			for _, n in ipairs(miss) do
				if type(m[n]) == "table" and m[n].url then
					fetch[#fetch + 1] = n
				end
			end

			if #fetch == 0 then
				return
			end

			local left, done = #fetch, 0

			for _, n in ipairs(fetch) do
				get(m[n].url, function(b)
					if save(n, b) then
						done = done + 1
						fluxprint("[flux] " .. FILE_NAME .. ": nachgeladen " .. n)
					end

					left = left - 1

					if left <= 0 and done > 0 then
						Engine.ReloadScriptSystem()
					end
				end)
			end
		end)

		return
	end

	get(ROOT .. "/" .. MANIFEST, function(body)
		local ok, m = pcall(function()
			return json:decode(body)
		end)

		if not ok or type(m) ~= "table" then
			return
		end

		local me = m[FILE_NAME]

		-- Only reload if the download actually declares the new _VERSION —
		-- guards against a forgotten _VERSION bump (which would otherwise loop).
		if me and me.url and newer(me.version, _VERSION) then
			fluxprint("[flux] " .. FILE_NAME .. ": Update " .. _VERSION .. " -> " .. tostring(me.version))

			get(me.url, function(b)
				if b and b:match('_VERSION%s*=%s*"' .. me.version .. '"') and save(FILE_NAME, b) then
					Engine.ReloadScriptSystem()
				end
			end)
		end
	end)
end

fluxprint("[flux] " .. FILE_NAME .. " v" .. _VERSION .. " geladen")

pcall(run)


-- ════════════════════════════════════════════════════════════════════════════════
-- Target Selection
-- ════════════════════════════════════════════════════════════════════════════════
-- TODO (v1.0.1): PURE selection library (no Menu/Render calls). Expose _G.targeting (T):
--                enumerate, passes, do_select, acquire, gap_to, resolve_aim_bone, vis_check.
