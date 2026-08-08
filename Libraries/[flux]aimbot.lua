-- ════════════════════════════════════════════════════════════════════════════════
-- [flux]aimbot.lua — _VERSION 1.0.1
-- ════════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════════
-- Utilities
-- ════════════════════════════════════════════════════════════════════════════════

local function debugprint(...)
	local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Developer Mode")
	if ok and w and w:Get() then print(...) end
end


-- ════════════════════════════════════════════════════════════════════════════════
-- Auto Update
-- ════════════════════════════════════════════════════════════════════════════════

local _VERSION  = "1.0.1"
local FILE_NAME = "[flux]aimbot.lua"
local TAG       = "flux-aimbot"
local ROOT      = "https://raw.githubusercontent.com/si7ziTV/Umbrella-Scripts/main"
local MANIFEST  = "flux_versions.json"
local PUBLIC    = { "[flux].lua", "[flux]targetselector.lua", "[flux]aimbot.lua" }
local json      = require("assets.JSON")

local SCRIPTS = ""
for entry in (package.path or ""):gmatch("[^;]+") do
	local dir = entry:gsub("%?.-$", "")
	local f = dir ~= "" and io.open(dir .. FILE_NAME, "r") or nil
	if f then f:close() SCRIPTS = dir break end
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
	if not body or body:sub(1, 2) ~= "--" then return false end
	local f = io.open(SCRIPTS .. name, "w")
	if not f then return false end
	f:write(body)
	f:close()
	return true
end

-- Fetches + decodes the manifest. cb receives the table or nil.
local function manifest(cb)
	fetch(ROOT .. "/" .. MANIFEST, function(body)
		if not body then cb(nil) return end
		local ok, m = pcall(function() return json:decode(body) end)
		cb(ok and type(m) == "table" and m or nil)
	end)
end


-- ────────────────────────────────────────────────────────────────────────────────
-- Update Logic
-- ────────────────────────────────────────────────────────────────────────────────

local function run()
	local miss = {}
	for _, n in ipairs(PUBLIC) do
		if n ~= FILE_NAME then
			local f = io.open(SCRIPTS .. n, "r")
			if f then f:close() else miss[#miss + 1] = n end
		end
	end

	if #miss > 0 then
		print(TAG .. " v" .. _VERSION .. " loaded — downloading " .. #miss .. " missing file(s)…")
	end

	-- One manifest fetch serves both branches: bootstrap missing files, else self-update.
	manifest(function(m)
		if not m then print(TAG .. " ✗ manifest unreachable") return end

		if #miss > 0 then
			local downloads = {}
			for _, n in ipairs(miss) do
				if type(m[n]) == "table" and m[n].url then downloads[#downloads + 1] = n end
			end
			if #downloads == 0 then return end

			local left, done = #downloads, 0
			for i, n in ipairs(downloads) do
				print(TAG .. "   ↓ " .. n .. "   (" .. i .. "/" .. #downloads .. ")")
				fetch(m[n].url, function(b)
					if save(n, b) then
						done = done + 1
						print(TAG .. "   ✓ " .. n .. "   (" .. done .. "/" .. #downloads .. " ok)")
					else
						print(TAG .. "   ✗ " .. n .. "   (failed)")
					end
					left = left - 1
					if left <= 0 and done > 0 then utils.reload_scripts() end
				end)
			end
			return
		end

		local me = m[FILE_NAME]
		if not (me and me.url) then return end

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
