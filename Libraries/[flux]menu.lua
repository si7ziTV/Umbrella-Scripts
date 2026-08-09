-- ════════════════════════════════════════════════════════════════════════════════
-- [flux]menu.lua — _VERSION 1.0.0
-- ════════════════════════════════════════════════════════════════════════════════

-- 1.0.0		initial — flux menu data (SPEC + i18n/tips/hides catalogs) as a self-updating
--			data file, consumed by [flux].lua's menu engine. Pure data + a self-only
--			updater; no sibling-pull. [flux].lua reads flux_menu_data on on_scripts_loaded,
--			so hero/utility scripts may append pages to flux_menu_data.spec.pages first.

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
-- DATA file, not an entry point: never pulls sibling files. Keeps only ITSELF current
-- against the manifest, so it self-updates inside flux AND standalone. [flux].lua (the
-- entry) downloads it initially via its REQUIREMENTS list.

local _VERSION  = "1.0.0"
local FILE_NAME = "[flux]menu.lua"
local TAG       = "flux-menu"
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
-- Menu Data
-- ════════════════════════════════════════════════════════════════════════════════
-- THE single source of truth. The renderer in [flux].lua turns this into the menu 1:1.
-- Item-list constants stay plain strings (= stable keys for the i18n label maps).

flux_menu_data = {}
local LANGS = { "en", "ru" }
flux_menu_data.langs = LANGS
flux_menu_data.lang_widget = "lang"

-- ────────────────────────────────────────────────────────────────────────────────
-- Specification
-- ────────────────────────────────────────────────────────────────────────────────
-- THE single source of truth. Translators edit label/tooltip/hint (and may upgrade an
-- item list to { key=, label=i18n }); the renderer turns this table into the menu 1:1.
-- Shared item lists stay plain strings here (= stable keys), matching the skeleton.

local PRESET_NAMES = { "Ultra-Legit", "Legit", "Semi-Legit", "Rage" }
local TYPE_ITEMS   = { "Off", "Hold", "Toggle" }
local SELECT_ITEMS = { "None", "Default", "Combo", "Harass", "Clear", "Last Hit" }
local TARGET_ITEMS = { "Players", "XP Orbs", "Troopers", "Creeps", "Buildings", "Breakables", "Summons" }
local IGNORE_ITEMS = { "Invisible", "Invulnerable", "On Rail" }
local METHOD_ITEMS = { "Closest", "Lowest FOV", "Lowest HP" }
local BONE_ITEMS   = { "None", "Smart", "Head", "Chest", "Body" }
local PRIO_SLOT    = { "None", "Players", "XP Orbs", "Troopers", "Creeps", "Buildings", "Breakables" }

-- THE translation catalog. Key = the English string as written in SPEC (label, group
-- label, item, suffix); value = { ru= }. The English string itself is the fallback, so
-- partial translations are safe. (Add a language by giving every entry a new key, adding
-- the code to LANGS, and a name to the Language combo items.)
flux_menu_data.i18n = {
	-- Pages (tab names)
	["General"] = { ru = "Общие" },
	["Bind Config"] = { ru = "Настройка биндов" },
	["Advanced Settings"] = { ru = "Расширенные настройки" },
	-- Groups
	["Keybinds"]                    = { ru = "Назначения клавиш" },
	["Auto-Assist on Approach"]     = { ru = "Авто-помощь при сближении" },
	["Security"]                    = { ru = "Безопасность" },
	["Config"]                      = { ru = "Конфигурация" },
	["Target Selection"]            = { ru = "Выбор цели" },
	["Auto Fire"]                   = { ru = "Авто-огонь" },
	["Magnet"]                      = { ru = "Магнит" },
	["Legitbot"]                    = { ru = "Легитбот" },
	["PSilent"]                     = { ru = "PSilent" },
	["Preset"]                      = { ru = "Пресет" },
	-- Gear sub-panel names
	["Settings"]                    = { ru = "Настройки" },
	["FOV Settings"]                = { ru = "Настройки FOV" },
	-- General widgets
	["Enabled"]                     = { ru = "Включено" },
	["Default Bind"]                = { ru = "Назначение: По умолчанию" },
	["Combo Bind"]                  = { ru = "Назначение: Комбо" },
	["Harass Bind"]                 = { ru = "Назначение: Харасс" },
	["Clear Bind"]                  = { ru = "Назначение: Клир" },
	["Last Hit Bind"]               = { ru = "Назначение: Ластхит" },
	["Type"]                        = { ru = "Тип" },
	["FOV"]                         = { ru = "FOV" },
	["Render FOV"]                  = { ru = "Показывать FOV" },
	["FOV Color"]                   = { ru = "Цвет FOV" },
	["Max Headshot"]                = { ru = "Макс. хедшот" },
	["Detection Delay"] = { ru = "Задержка обнаружения" },
	["Distance Based FOV"]          = { ru = "FOV по дистанции" },
	["Scale"]                       = { ru = "Масштаб" },
	["Reference Distance"]          = { ru = "Опорная дистанция" },
	-- Bind Config widgets
	["Select Config to edit"]       = { ru = "Выбрать конфигурацию" },
	["Override Target Selector FOV"] = { ru = "Свой FOV выборщика" },
	["Targets"]                     = { ru = "Цели" },
	["Enemy Heroes"] = { ru = "Вражеские герои" },
	["Summons"] = { ru = "Призывы" },
	["Prioritize by type"]          = { ru = "Приоритет по типу" },
	["Priority"]                    = { ru = "Приоритет" },
	["Aim Bones"]                   = { ru = "Кости прицела" },
	["Aim Bones by Target"]         = { ru = "Кости по типу цели" },
	[" Bone"]                       = { ru = " — кость" },
	["Ignore"]                      = { ru = "Игнорировать" },
	["Target Method"]               = { ru = "Метод выбора" },
	["Lock Target"]                 = { ru = "Фиксировать цель" },
	["Backtrack"]                   = { ru = "Бэктрек" },
	["Only Lasthit Troopers"]       = { ru = "Только ластхит брокеров" },
	["Only if PSilent"]             = { ru = "Только при PSilent" },
	["Orb Fire Offset (ms)"]        = { ru = "Смещение орб-огня (мс)" },
	["Enable"]                      = { ru = "Включить" },
	["Hitchance"]                   = { ru = "Шанс попадания" },
	-- Advanced widgets
	["Select Preset to edit"]       = { ru = "Выбрать пресет" },
	["Strength"]                    = { ru = "Сила" },
	["Toward"]                      = { ru = "К цели" },
	["Away"]                        = { ru = "От цели" },
	["Funnel"]                      = { ru = "Воронка" },
	["FOV Inner"]                   = { ru = "Внутр. FOV" },
	["Deadzone"]                    = { ru = "Мёртвая зона" },
	["Boost Cap"]                   = { ru = "Лимит буста" },
	["Smooth Pitch"]                = { ru = "Сглаж. питча" },
	["Smooth Yaw"]                  = { ru = "Сглаж. рысканья" },
	["Easing"]                      = { ru = "Сглаживание" },
	["Ramp"]                        = { ru = "Нарастание" },
	["Floor"]                       = { ru = "Пол" },
	["Jitter"]                      = { ru = "Джиттер" },
	["Gate"]                        = { ru = "Гейт" },
	["Wobble"]                      = { ru = "Воббл" },
	-- Combo / MultiCombo items
	["Off"]                         = { ru = "Выкл" },
	["Hold"]                        = { ru = "Удерж" },
	["Toggle"]                      = { ru = "Переключ" },
	["None"]                        = { ru = "Нет" },
	["Default"]                     = { ru = "По умолч." },
	["Combo"]                       = { ru = "Комбо" },
	["Harass"]                      = { ru = "Харасс" },
	["Clear"]                       = { ru = "Клин" },
	["Last Hit"]                    = { ru = "Ластхит" },
	["Players"]                     = { ru = "Игроки" },
	["XP Orbs"]                     = { ru = "XP-сферы" },
	["Troopers"]                    = { ru = "Брокеры" },
	["Creeps"]                      = { ru = "Крипы" },
	["Buildings"]                   = { ru = "Здания" },
	["Breakables"]                  = { ru = "Разрушаемое" },
	["Ghoul"]        = { ru = "Гуль" },
	["Deadhead"]     = { ru = "Мёртвоголов" },
	["Mini Turret"]  = { ru = "Мини-турель" },
	["Invisible"]                   = { ru = "Невидимы" },
	["Invulnerable"]                = { ru = "Неуязвимы" },
	["On Rail"]                     = { ru = "На рельсах" },
	["Intent"]                      = { ru = "Намерение" },
	["Closest"]                     = { ru = "Ближайший" },
	["Lowest FOV"]                  = { ru = "Мин. FOV" },
	["Lowest HP"]                   = { ru = "Мин. HP" },
	["Smart"]                       = { ru = "Умная" },
	["Head"]                        = { ru = "Голова" },
	["Chest"]                       = { ru = "Грудь" },
	["Body"]                        = { ru = "Тело" },
	["Ultra-Legit"]                 = { ru = "Ультра-Легит" },
	["Legit"]                       = { ru = "Легит" },
	["Semi-Legit"]                  = { ru = "Полу-Легит" },
	["Rage"]                        = { ru = "Рейдж" },
	["Linear"]                      = { ru = "Линейный" },
	["Ease-Out"]                    = { ru = "Плавный" },
	["Smoothstep"]                  = { ru = "Смузстеп" },
}

-- Per-widget tooltips, keyed by widget id. Written for a layperson: explain what the
-- option does and how to think about it. build_widget applies TIPS[id] when the widget has
-- no inline tooltip; collection elements inherit TIPS[collection_id].
flux_menu_data.tips = {
	-- General
	lang = { en = "Menu language. Applied after a reload.", ru = "Язык меню. Применяется после релоада." },
	enabled = { en = "Master switch for the whole aim-assist.", ru = "Главный включатель всего эйм-ассиста." },
	advanced = { en = "Show the Advanced Settings tab. Needs a reload.", ru = "Показать вкладку расширенных настроек. Нужен релоад." },
	["default.bind"] = { en = "Hotkey for this aim mode (hold or toggle — see Type).", ru = "Клавиша этого режима прицела (удерж. или переключ. — см. Тип)." },
	["combo.bind"] = { en = "Hotkey for this aim mode (hold or toggle — see Type).", ru = "Клавиша этого режима прицела (удерж. или переключ. — см. Тип)." },
	["harass.bind"] = { en = "Hotkey for this aim mode (hold or toggle — see Type).", ru = "Клавиша этого режима прицела (удерж. или переключ. — см. Тип)." },
	["clear.bind"] = { en = "Hotkey for this aim mode (hold or toggle — see Type).", ru = "Клавиша этого режима прицела (удерж. или переключ. — см. Тип)." },
	["lasthit.bind"] = { en = "Hotkey for this aim mode (hold or toggle — see Type).", ru = "Клавиша этого режима прицела (удерж. или переключ. — см. Тип)." },
	["default.type"] = { en = "Off = unused. Hold = active while pressed. Toggle = press to flip on/off.", ru = "Выкл = не используется. Удерж. = активно при нажатии. Переключ. = нажал — вкл/выкл." },
	["combo.type"] = { en = "Off = unused. Hold = active while pressed. Toggle = press to flip on/off.", ru = "Выкл = не используется. Удерж. = активно при нажатии. Переключ. = нажал — вкл/выкл." },
	["harass.type"] = { en = "Off = unused. Hold = active while pressed. Toggle = press to flip on/off.", ru = "Выкл = не используется. Удерж. = активно при нажатии. Переключ. = нажал — вкл/выкл." },
	["clear.type"] = { en = "Off = unused. Hold = active while pressed. Toggle = press to flip on/off.", ru = "Выкл = не используется. Удерж. = активно при нажатии. Переключ. = нажал — вкл/выкл." },
	["lasthit.type"] = { en = "Off = unused. Hold = active while pressed. Toggle = press to flip on/off.", ru = "Выкл = не используется. Удерж. = активно при нажатии. Переключ. = нажал — вкл/выкл." },
	auto_approach = { en = "Aim automatically when an enemy enters range — no key needed.", ru = "Авто-прицел при появлении врага в радиусе — без нажатия." },
	approach_preset = { en = "Preset that drives the auto-assist strength.", ru = "Пресет, задающий силу авто-помощи." },
	fov = { en = "Field-of-view cone (degrees) in which auto-assist grabs a target.", ru = "Конус обзора (градусы), в котором авто-помощь ловит цель." },
	render_fov = { en = "Draw the FOV cone on screen.", ru = "Рисовать конус FOV на экране." },
	fov_color = { en = "Color of the drawn FOV cone.", ru = "Цвет рисуемого конуса FOV." },
	security = { en = "Master switch for the safety envelope (limits and clamping).", ru = "Главный включатель защитного контура (лимиты и клампинг)." },
	max_headshot = { en = "Highest headshot percentage the aim may use.", ru = "Максимальный процент хедшота, который может использовать прицел." },
	detection_delay = { en = "Delay (ms) before a detected target is actually aimed at — higher reads as more human, less snap. Cannot drop below 100 while Security is on.", ru = "Задержка (мс) перед тем, как замеченная цель становится целью прицела — выше = человечнее, меньше рывка. Пока Security включён — не ниже 100." },
	dist_fov = { en = "Shrink the FOV with distance so the physical reach stays constant.", ru = "Сужать FOV с дистанцией, чтобы реальный радиус оставался постоянным." },
	dist_fov_scale = { en = "Distance scaling strength. 1 = full, 0 = off.", ru = "Сила масштабирования по дистанции. 1 = полно, 0 = выкл." },
	dist_fov_ref = { en = "Distance (m) at which the FOV equals its base value.", ru = "Дистанция (м), на которой FOV равен базовому." },
	-- Bind Config
	select_config = { en = "Which hotkey's settings you are editing here.", ru = "Настройки какой клавиши вы сейчас редактируете." },
	ts_override = { en = "Use a dedicated target-selection FOV for this bind instead of the channel FOVs.", ru = "Использовать отдельный FOV выборщика для этого бинда вместо FOV каналов." },
	ts_fov = { en = "Field-of-view cone used to pick a target.", ru = "Конус обзора для выбора цели." },
	ts_render_fov = { en = "Draw the target-selection FOV cone on screen.", ru = "Рисовать конус FOV выборщика." },
	ts_fov_color = { en = "Color of the target-selection FOV cone.", ru = "Цвет конуса FOV выборщика." },
	targets = { en = "Entity types that may become a target.", ru = "Типы сущностей, которые могут стать целью." },
	prioritize = { en = "Rank target types by the priority slots below.", ru = "Ранжировать типы целей по слотам приоритета ниже." },
	priority = { en = "Nth-most-important target type. More slots appear as you pick more target types.", ru = "Тип цели N-й по важности. Новые слоты появляются по мере выбора типов целей." },
	bones_global = { en = "Body part the aim snaps to.", ru = "Часть тела, в которую целится прицел." },
	bones_by_target = { en = "Set the aim bone per target type (entries below).", ru = "Задать кость прицела для каждого типа цели (ниже)." },
	bones = { en = "Body part to aim at for this target type.", ru = "Часть тела для прицеливания по этому типу целей." },
	ignore = { en = "Skip targets that are invisible, invulnerable, or riding the rail.", ru = "Пропускать невидимых, неуязвимых или цели на рельсах." },
	method = { en = "How the best target is chosen: Intent, closest, lowest FOV, or lowest HP.", ru = "Как выбирается лучшая цель: Намерение, ближайший, мин. FOV или мин. HP." },
	lock = { en = "Keep the current target until it is no longer valid.", ru = "Держать текущую цель, пока она валидна." },
	backtrack = { en = "Planned. Aim at where the target was a moment ago.", ru = "Запланировано. Целиться туда, где цель была мгновение назад." },
	enemy_heroes = { en = "Enemy heroes in this match. Green = aim at them; toggle one off to skip it. Fills automatically when you enter a match.", ru = "Вражеские герои в этом матче. Зелёный = целиться; выключите героя, чтобы пропустить. Заполняется автоматически при входе в матч." },
	autofire = { en = "Entity types that get fired at automatically.", ru = "Типы сущностей, по которым ведётся авто-огонь." },
	af_lasthit = { en = "Only auto-fire to last-hit troopers.", ru = "Авто-огонь только для ластхита брокеров." },
	af_only_psilent = { en = "Only auto-fire while PSilent is active.", ru = "Авто-огонь только при активном PSilent." },
	af_orb_offset = { en = "Timing offset (ms) for orb fire.", ru = "Смещение тайминга (мс) для орб-огня." },
	mag_enable = { en = "Warp magnet — pulls the crosshair toward the target.", ru = "Варп-магнит — тянет прицел к цели." },
	mag_fov = { en = "Field-of-view cone in which the magnet acts.", ru = "Конус обзора, в котором действует магнит." },
	mag_render_fov = { en = "Draw the magnet FOV cone on screen.", ru = "Рисовать конус FOV магнита." },
	mag_fov_color = { en = "Color of the magnet FOV cone.", ru = "Цвет конуса FOV магнита." },
	mag_preset = { en = "Preset driving the magnet strength (edited under Advanced).", ru = "Пресет силы магнита (редакт. в Расширенных)." },
	leg_enable = { en = "Humanized aim pull that looks legitimate to spectators.", ru = "Очеловеченный подтяг прицела, легитный для наблюдателей." },
	leg_fov = { en = "Field-of-view cone in which the legitbot acts.", ru = "Конус обзора, в котором действует легитбот." },
	leg_render_fov = { en = "Draw the legitbot FOV cone on screen.", ru = "Рисовать конус FOV легитбота." },
	leg_fov_color = { en = "Color of the legitbot FOV cone.", ru = "Цвет конуса FOV легитбота." },
	leg_preset = { en = "Preset driving the legitbot smoothing (edited under Advanced).", ru = "Пресет сглаживания легитбота (редакт. в Расширенных)." },
	ps_enable = { en = "Silent aim — adjusts the shot server-side, invisible on your screen.", ru = "Сайлент-эйм — корректирует выстрел серверно, незаметно на вашем экране." },
	ps_fov = { en = "Field-of-view cone in which silent aim acts.", ru = "Конус обзора, в котором действует сайлент." },
	ps_render_fov = { en = "Draw the silent-aim FOV cone on screen.", ru = "Рисовать конус FOV сайлента." },
	ps_fov_color = { en = "Color of the silent-aim FOV cone.", ru = "Цвет конуса FOV сайлента." },
	ps_hitchance = { en = "Required hit chance (0-100%) for a silent shot to trigger.", ru = "Нужный шанс попадания (0-100%) для срабатывания сайлента." },
	-- Advanced
	ap_sel = { en = "Preset whose values you are editing below.", ru = "Пресет, значения которого вы редактируете." },
	strength = { en = "Overall magnet pull strength.", ru = "Общая сила тяги магнита." },
	toward = { en = "Pull component aimed at the target.", ru = "Компонент тяги к цели." },
	away = { en = "Pull component pushing away from the target (spacing).", ru = "Компонент тяги от цели (развод)." },
	funnel = { en = "Pull toward the aim line.", ru = "Тяга к линии прицела." },
	fov_inner = { en = "Inner radius (degrees) where the magnet is strongest.", ru = "Внутренний радиус (градусы), где магнит сильнее всего." },
	dead = { en = "Dead zone around the target — no pull applied (cuts jitter).", ru = "Мёртвая зона вокруг цели — без тяги (убирает дрожь)." },
	boost_cap = { en = "Upper limit on the magnet boost magnitude.", ru = "Верхний предел величины буста магнита." },
	leg_pitch = { en = "Vertical aim smoothing. 0 = instant, 100 = very smooth.", ru = "Сглаживание по вертикали. 0 = мгновенно, 100 = очень плавно." },
	leg_yaw = { en = "Horizontal aim smoothing. 0 = instant, 100 = very smooth.", ru = "Сглаживание по горизонтали. 0 = мгновенно, 100 = очень плавно." },
	leg_easing = { en = "Planned. Shape of the smoothing curve.", ru = "Запланировано. Форма кривой сглаживания." },
	leg_ramp = { en = "Planned. How fast smoothing ramps in.", ru = "Запланировано. Скорость нарастания сглаживания." },
	leg_floor = { en = "Planned. Minimum smoothing floor.", ru = "Запланировано. Минимальный порог сглаживания." },
	leg_jitter = { en = "Planned. Random jitter to mimic human aim.", ru = "Запланировано. Случайный джиттер под человеческий прицел." },
	leg_gate = { en = "Planned. Activation gate for the humanizer.", ru = "Запланировано. Порог активации очеловечивания." },
	leg_wobble = { en = "Planned. Slow wobble overlaid on the aim.", ru = "Запланировано. Медленное колебание поверх прицела." },
}

-- Hide-gates: a widget is hidden unless the gate widget's state matches. Keyed by widget id.
flux_menu_data.hides = {
	ts_fov = { id = "ts_override", value = true, mode = "lock" },
	mag_fov = { id = "mag_enable", value = true },
	mag_preset = { id = "mag_enable", value = true },
	leg_fov = { id = "leg_enable", value = true },
	leg_preset = { id = "leg_enable", value = true },
	ps_fov = { id = "ps_enable", value = true },
	ps_hitchance = { id = "ps_enable", value = true },
}

flux_menu_data.spec = {
	category = { "Flux", "", "Flux" },
	langs = LANGS,
	lang_widget = "lang",

	pages = {
		-- General
		{
			name = "General",
			groups = {
				{
					label = { en = "Language", ru = "Язык" },
					side = "FULL",
					widgets = {
						{
							id = "lang",
							type = "Combo",
							label = { en = "Language", ru = "Язык" },
							items = { "english", "Русский" },
							default = 0,
						},
					},
				},
				{
					label = "Keybinds",
					side = "LEFT",
					widgets = {
						{
							id = "enabled",
							type = "Switch",
							label = "Enabled",
							default = true,
							gear = {
								name = "Settings",
								widgets = {
									{
										id = "advanced",
										type = "Switch",
										label = "Advanced Settings",
										default = true,
									},
								},
							},
						},
						{
							id = "default.bind",
							type = "Bind",
							label = "Default Bind",
							key = "KEY_MOUSE1",
							gear = {
								name = "Settings",
								widgets = {
									{ id = "default.type", type = "Combo", label = "Type", items = TYPE_ITEMS, default = 1 },
								},
							},
						},
						{
							id = "combo.bind",
							type = "Bind",
							label = "Combo Bind",
							key = "KEY_MOUSE5",
							gear = {
								name = "Settings",
								widgets = {
									{ id = "combo.type", type = "Combo", label = "Type", items = TYPE_ITEMS, default = 1 },
								},
							},
						},
						{
							id = "harass.bind",
							type = "Bind",
							label = "Harass Bind",
							key = "KEY_NONE",
							gear = {
								name = "Settings",
								widgets = {
									{ id = "harass.type", type = "Combo", label = "Type", items = TYPE_ITEMS, default = 1 },
								},
							},
						},
						{
							id = "clear.bind",
							type = "Bind",
							label = "Clear Bind",
							key = "KEY_MOUSE4",
							gear = {
								name = "Settings",
								widgets = {
									{ id = "clear.type", type = "Combo", label = "Type", items = TYPE_ITEMS, default = 1 },
								},
							},
						},
						{
							id = "lasthit.bind",
							type = "Bind",
							label = "Last Hit Bind",
							key = "KEY_MOUSE3",
							gear = {
								name = "Settings",
								widgets = {
									{ id = "lasthit.type", type = "Combo", label = "Type", items = TYPE_ITEMS, default = 1 },
								},
							},
						},
					},
				},
				{
					label = "Auto-Assist on Approach",
					side = "RIGHT",
					widgets = {
						{ id = "auto_approach", type = "Switch", label = "Enabled", default = true },
						{ id = "approach_preset", type = "Combo", label = "Preset", items = PRESET_NAMES, default = 1 },
						{
							id = "fov",
							type = "Slider",
							label = "FOV",
							min = 0.0,
							max = 180.0,
							default = 10.0,
							fmt = "%.1f",
							gear = {
								name = "FOV Settings",
								widgets = {
									{ id = "render_fov", type = "Switch", label = "Render FOV", default = false },
									{ id = "fov_color", type = "ColorPicker", label = "FOV Color", color = { 255, 255, 255, 255 } },
								},
							},
						},
					},
				},
				{
					label = "Security",
					side = "RIGHT",
					widgets = {
						{ id = "security", type = "Switch", label = "Enabled", default = true },
						{
							id = "max_headshot",
							type = "Slider",
							label = "Max Headshot",
							min = 0,
							max = 100,
							default = 70,
							fmt = "%d%%",
							clamp = { when = { id = "security", value = true }, max = 40 },  -- Security envelope: cap headshot ≤ 40% while Security is on
						},
						{ id = "detection_delay", type = "Slider", label = "Detection Delay", min = 0, max = 250, default = 100, fmt = "%d", clamp = { when = { id = "security", value = true }, min = 100 } },
						{
							id = "dist_fov",
							type = "Switch",
							label = "Distance Based FOV",
							default = true,
							gear = {
								name = "Settings",
								widgets = {
									{ id = "dist_fov_scale", type = "Slider", label = "Scale", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
									{ id = "dist_fov_ref", type = "Slider", label = "Reference Distance", min = 1.0, max = 50.0, default = 10.0, fmt = "%.1f" },
								},
							},
						},
					},
				},
			},
		},

		-- Bind Config
		{
			name = "Bind Config",
			groups = {
				{
					label = "Config",
					side = "FULL",
					widgets = {
						{ id = "select_config", type = "Combo", label = "Select Config to edit", items = SELECT_ITEMS, default = 0 },
					},
				},
				{
					label = "Target Selection",
					side = "LEFT",
					widgets = {
						{ id = "ts_override", type = "Switch", label = "Override Target Selector FOV", default = false },
						{
							id = "ts_fov",
							type = "Slider",
							label = "FOV",
							min = 0.0,
							max = 360.0,
							default = 10.0,
							fmt = "%.1f",
							gear = {
								name = "FOV Settings",
								widgets = {
									{ id = "ts_render_fov", type = "Switch", label = "Render FOV", default = true },
									{ id = "ts_fov_color", type = "ColorPicker", label = "FOV Color", color = { 255, 255, 255, 255 } },
								},
							},
						},
						{
							id = "targets",
							type = "MultiCombo",
							label = "Targets",
							items = TARGET_ITEMS,
							default = {},
							gear = {
								name = "Settings",
								widgets = {
									{ id = "prioritize", type = "Switch", label = "Prioritize by type", default = true },
									{
										id = "priority",
										type = "collection",
										foreach = { count = 9 },
										template = { type = "Combo", items = PRIO_SLOT, default = 0, label = "Priority" },
									},
								},
							},
						},
						{
							id = "autofire",
							type = "MultiCombo",
							label = "Auto Fire",
							items = TARGET_ITEMS,
							default = {},
							gear = {
								name = "Settings",
								widgets = {
									{ id = "af_lasthit", type = "Switch", label = "Only Lasthit Troopers", default = false },
									{ id = "af_only_psilent", type = "Switch", label = "Only if PSilent", default = false },
									{ id = "af_orb_offset", type = "Slider", label = "Orb Fire Offset (ms)", min = -100, max = 100, default = 10, fmt = "%d" },
								},
							},
						},
						{
							id = "enemy_heroes",
							type = "MultiSelect",
							label = "Enemy Heroes",
							items = {},  -- ships empty; populated in-match by populate_pickers() below
							expanded = true,
						},
						{
							id = "bones_global",
							type = "Combo",
							label = "Aim Bones",
							items = BONE_ITEMS,
							default = 1,
							-- clamp = { when = { id = "max_headshot", op = "gt", value = 40 }, blacklist = { 2 }, fallback = 1 },  -- redirect off "Head" (idx 2) when headshot > 40% (uncomment to enforce)
							gear = {
								name = "Settings",
								widgets = {
									{ id = "bones_by_target", type = "Switch", label = "Aim Bones by Target", default = false },
									{
										id = "bones",
										type = "collection",
										policy = "membership",
										foreach = { from = "targets" },
										skip = { "XP Orbs", "Breakables" },
										template = { type = "Combo", items = BONE_ITEMS, default = 1, suffix = " Bone" },
										gate = { id = "bones_by_target", value = true },
									},
								},
							},
						},
						{ id = "ignore", type = "MultiCombo", label = "Ignore", items = IGNORE_ITEMS, default = {} },
						{ id = "method", type = "Combo", label = "Target Method", items = METHOD_ITEMS, default = 1 },
						{ id = "lock", type = "Switch", label = "Lock Target", default = false },
						{ id = "backtrack", type = "Switch", label = "Backtrack", default = false, northstar = true },
					},
				},
				{
					label = "Magnet",
					side = "RIGHT",
					widgets = {
						{ id = "mag_enable", type = "Switch", label = "Enable", default = false },
						{
							id = "mag_fov",
							type = "Slider",
							label = "FOV",
							min = 0.0,
							max = 360.0,
							default = 15.0,
							fmt = "%.1f",
							gear = {
								name = "FOV Settings",
								widgets = {
									{ id = "mag_render_fov", type = "Switch", label = "Render FOV", default = true },
									{ id = "mag_fov_color", type = "ColorPicker", label = "FOV Color", color = { 255, 255, 255, 255 } },
								},
							},
						},
						{ id = "mag_preset", type = "Combo", label = "Preset", items = PRESET_NAMES, default = 0 },
					},
				},
				{
					label = "Legitbot",
					side = "RIGHT",
					widgets = {
						{ id = "leg_enable", type = "Switch", label = "Enable", default = false },
						{
							id = "leg_fov",
							type = "Slider",
							label = "FOV",
							min = 0.0,
							max = 360.0,
							default = 5.0,
							fmt = "%.1f",
							gear = {
								name = "FOV Settings",
								widgets = {
									{ id = "leg_render_fov", type = "Switch", label = "Render FOV", default = true },
									{ id = "leg_fov_color", type = "ColorPicker", label = "FOV Color", color = { 255, 255, 255, 255 } },
								},
							},
						},
						{ id = "leg_preset", type = "Combo", label = "Preset", items = PRESET_NAMES, default = 0 },
					},
				},
				{
					label = "PSilent",
					side = "RIGHT",
					widgets = {
						{ id = "ps_enable", type = "Switch", label = "Enable", default = false },
						{
							id = "ps_fov",
							type = "Slider",
							label = "FOV",
							min = 0.0,
							max = 360.0,
							default = 1.5,
							fmt = "%.1f",
							gear = {
								name = "FOV Settings",
								widgets = {
									{ id = "ps_render_fov", type = "Switch", label = "Render FOV", default = true },
									{ id = "ps_fov_color", type = "ColorPicker", label = "FOV Color", color = { 255, 255, 255, 255 } },
								},
							},
						},
						{ id = "ps_hitchance", type = "Slider", label = "Hitchance", min = 0, max = 100, default = 100, fmt = "%d" },
					},
				},
			},
		},

		-- Advanced Settings (built only while the Advanced toggle is on)
		{
			name = "Advanced Settings",
			requires = { id = "advanced", value = true, mode = "build" },
			preset_editor = { selector = "ap_sel", store = "PV", presets = PRESET_NAMES },
			groups = {
				{
					label = "Preset",
					side = "FULL",
					widgets = {
						{ id = "ap_sel", type = "Combo", label = "Select Preset to edit", items = PRESET_NAMES, default = 0 },
					},
				},
				{
					label = "Magnet",
					side = "LEFT",
					widgets = {
						{ id = "strength",  pv = true, type = "Slider", label = "Strength",  min = 0.0,  max = 2.5,  default = 1.00, fmt = "%.2f" },
						{ id = "toward",    pv = true, type = "Slider", label = "Toward",    min = 0.0,  max = 3.0,  default = 0.60, fmt = "%.2f" },
						{ id = "away",      pv = true, type = "Slider", label = "Away",      min = 0.0,  max = 1.0,  default = 0.25, fmt = "%.2f" },
						{ id = "funnel",    pv = true, type = "Slider", label = "Funnel",    min = 0.0,  max = 1.0,  default = 0.45, fmt = "%.2f" },
						{ id = "fov_inner", pv = true, type = "Slider", label = "FOV Inner", min = 0.5,  max = 10.0, default = 2.0,  fmt = "%.1f" },
						{ id = "dead",      pv = true, type = "Slider", label = "Deadzone", min = 0.02, max = 1.0,  default = 0.12, fmt = "%.2f" },
						{ id = "boost_cap", pv = true, type = "Slider", label = "Boost Cap", min = 0.2,  max = 3.0,  default = 1.20, fmt = "%.2f" },
					},
				},
				{
					label = "Legitbot",
					side = "RIGHT",
					widgets = {
						{ id = "leg_pitch",  pv = true, type = "Slider", label = "Smooth Pitch", min = 0, max = 100, default = 50, fmt = "%d%%" },
						{ id = "leg_yaw",    pv = true, type = "Slider", label = "Smooth Yaw",   min = 0, max = 100, default = 50, fmt = "%d%%" },
						{ id = "leg_easing", pv = true, northstar = true, type = "Combo",  label = "Easing", items = { "Linear", "Ease-Out", "Smoothstep" }, default = 2 },
						{ id = "leg_ramp",   pv = true, northstar = true, type = "Slider", label = "Ramp",   min = 0.0, max = 1.0, default = 0.30, fmt = "%.2f" },
						{ id = "leg_floor",  pv = true, northstar = true, type = "Slider", label = "Floor",  min = 0,   max = 100, default = 10,   fmt = "%d%%" },
						{ id = "leg_jitter", pv = true, northstar = true, type = "Slider", label = "Jitter", min = 0.0, max = 1.0, default = 0.05, fmt = "%.2f" },
						{ id = "leg_gate",   pv = true, northstar = true, type = "Slider", label = "Gate",   min = 0.0, max = 1.0, default = 0.0,  fmt = "%.2f" },
						{ id = "leg_wobble", pv = true, northstar = true, type = "Slider", label = "Wobble", min = 0.0, max = 1.0, default = 0.0,  fmt = "%.2f" },
					},
				},
			},
		},
	},
}
