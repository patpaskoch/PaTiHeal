-- PaTiHeal pure logic. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Logic.lua", {}).Logic
end

local function attributeMap(attributes)
    local map, seen = {}, {}
    for _, attribute in ipairs(attributes) do
        map[attribute.name] = attribute.value
        seen[#seen + 1] = attribute.name
    end
    return map, seen
end

describe("Logic.Migrate", function()
    it("creates defaults for a new character", function()
        local db = load().Migrate(nil)
        assert.same({}, db.bindings)
        assert.is_false(db.locked)
        assert.is_false(db.collapsed)
        assert.equal("auto", db.language)
        assert.equal(2, db.schema)
        assert.same({}, db.bindingRanks)
        assert.is_true(db.showDispels)
    end)

    it("moves the single 0.6.0 click binding and keeps position and lock", function()
        local db = load().Migrate({ x = 12, y = -40, locked = true, collapsed = true,
            clickSpellID = 331, clickButton = "RightButton", clickModifier = "ctrl-" })
        assert.same({ CTRL_RIGHT = 331 }, db.bindings)
        assert.is_nil(db.clickSpellID)
        assert.is_nil(db.clickButton)
        assert.is_nil(db.clickModifier)
        assert.equal(12, db.x)
        assert.equal(-40, db.y)
        assert.is_true(db.locked)
        assert.is_true(db.collapsed)
    end)

    it("treats a 0.6.0 save without button/modifier as a plain left click", function()
        assert.same({ LEFT = 8004 }, load().Migrate({ clickSpellID = 8004 }).bindings)
    end)

    it("upgrades schema 1 (0.7 development) without touching its settings", function()
        local db = load().Migrate({ schema = 1, bindings = { ALT_LEFT = 331 }, locked = false, collapsed = false, language = "deDE" })
        assert.equal(2, db.schema)
        assert.same({ ALT_LEFT = 331 }, db.bindings)
        assert.same({}, db.bindingRanks)
        assert.equal("deDE", db.language)
    end)

    it("keeps chosen ranks and a switched-off dispel display", function()
        local db = load().Migrate({ schema = 2, bindings = {}, bindingRanks = { LEFT = 3 }, showDispels = false })
        assert.is_false(db.showDispels)
        assert.same({ LEFT = 3 }, db.bindingRanks)
    end)
end)

describe("Logic.ClickAttributes", function()
    it("sets the chosen combinations and clears all others (FOLLOW_UPS F1)", function()
        local map, names = attributeMap(load().ClickAttributes({ LEFT = "Heilende Welle", SHIFT_RIGHT = "Springflut" }))
        assert.equal("spell", map["type1"])
        assert.equal("Heilende Welle", map["spell1"])
        assert.equal("spell", map["shift-type2"])
        assert.equal("Springflut", map["shift-spell2"])
        assert.is_nil(map["ctrl-type1"])
        assert.is_nil(map["ctrl-spell1"])
        -- Every combination and every 0.6.0 leftover is present in the list, so it gets reset.
        local all = {}
        for _, name in ipairs(names) do all[name] = true end
        for _, name in ipairs({ "type", "spell", "ctrl-spell", "type3", "spell3", "alt-type2", "alt-spell2" }) do
            assert.is_true(all[name], name .. " is not reset")
        end
    end)
end)

describe("Logic.SpellNames", function()
    it("keeps only spells the resolver can cast", function()
        local names = load().SpellNames({ LEFT = 331, RIGHT = 999 }, {}, function(id) return id == 331 and "Heilende Welle" or nil end)
        assert.same({ LEFT = "Heilende Welle" }, names)
    end)

    it("passes the chosen rank to the resolver", function()
        local names = load().SpellNames({ LEFT = 331 }, { LEFT = 3 }, function(_, rank) return "Heilende Welle(Rang " .. rank .. ")" end)
        assert.same({ LEFT = "Heilende Welle(Rang 3)" }, names)
    end)
end)

describe("Logic.RestoreDefaults", function()
    it("resets settings but keeps click bindings, ranks and the position", function()
        local db = load().RestoreDefaults({ x = 5, y = 6, locked = true, language = "koKR", bindings = { LEFT = 331 },
            bindingRanks = { LEFT = 2 }, showDispels = false })
        assert.same({ LEFT = 331 }, db.bindings)
        assert.same({ LEFT = 2 }, db.bindingRanks)
        assert.is_true(db.showDispels)
        assert.is_false(db.locked)
        assert.equal("auto", db.language)
        assert.equal(5, db.x)
    end)
end)

describe("Logic.HealthPercent", function()
    local never = function() return false end
    it("rounds to whole percent", function()
        local Logic = load()
        assert.equal("48%", Logic.HealthPercent(4812, 10000, never))
        assert.equal("100%", Logic.HealthPercent(100, 100, never))
        assert.equal("0%", Logic.HealthPercent(0, 100, never))
    end)

    it("never calculates with secret or unusable values", function()
        local Logic = load()
        local secret = {}
        local isSecret = function(value) return value == secret end
        assert.is_nil(Logic.HealthPercent(secret, 100, isSecret))
        assert.is_nil(Logic.HealthPercent(50, secret, isSecret))
        assert.is_nil(Logic.HealthPercent(50, 0, never))
        assert.is_nil(Logic.HealthPercent(nil, 100, never))
    end)
end)

describe("Logic.ValueOr and Logic.Flag (secret values)", function()
    local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })
    local function isSecret(value) return rawequal(value, SECRET) end

    it("passes a secret value through for the widget and replaces only a readable nil", function()
        local Logic = load()
        assert.is_true(rawequal(SECRET, Logic.ValueOr(SECRET, 0, isSecret)))
        assert.equal(0, Logic.ValueOr(nil, 0, isSecret))
        assert.equal(42, Logic.ValueOr(42, 0, isSecret))
    end)

    it("reads true/1 as yes, nil/false as no and a secret flag as unknown (nil)", function()
        local Logic = load()
        assert.is_true(Logic.Flag(true, isSecret))
        assert.is_true(Logic.Flag(1, isSecret))
        assert.is_false(Logic.Flag(nil, isSecret))
        assert.is_false(Logic.Flag(false, isSecret))
        assert.is_nil(Logic.Flag(SECRET, isSecret))
    end)
end)

describe("HoT & shield settings", function()
    it("get defaults on an existing schema-2 save without touching bindings, ranks or position", function()
        local db = load().Migrate({ schema = 2, x = 7, y = 8, collapsed = true, language = "deDE",
            bindings = { ALT_RIGHT = 51886, LEFT = 331 }, bindingRanks = { LEFT = 2 } })
        assert.same({}, db.hots)
        assert.equal("RIGHT", db.hotPosition)
        assert.is_true(db.showHotTimers)
        assert.is_true(db.showHotCharges)
        assert.same({ ALT_RIGHT = 51886, LEFT = 331 }, db.bindings)
        assert.same({ LEFT = 2 }, db.bindingRanks)
        assert.equal(7, db.x)
        assert.is_true(db.collapsed)
        assert.equal("deDE", db.language)
    end)

    it("keep saved choices, including false, and repair an unknown position", function()
        local Logic = load()
        local db = Logic.Migrate({ schema = 2, hots = { RIPTIDE = false }, hotPosition = "BELOW",
            showHotTimers = false, showHotCharges = false })
        assert.same({ RIPTIDE = false }, db.hots)
        assert.equal("BELOW", db.hotPosition)
        assert.is_false(db.showHotTimers)
        assert.is_false(db.showHotCharges)
        assert.equal("RIGHT", Logic.Migrate({ schema = 2, hotPosition = "LEFT" }).hotPosition)
    end)

    it("are reset by Restore Defaults, while bindings and the collapsed state stay", function()
        local db = load().RestoreDefaults({ collapsed = true, bindings = { ALT_RIGHT = 51886 }, bindingRanks = {},
            hots = { EARTH_SHIELD = false }, hotPosition = "BELOW", showHotTimers = false, showHotCharges = false })
        assert.same({}, db.hots)
        assert.equal("RIGHT", db.hotPosition)
        assert.is_true(db.showHotTimers)
        assert.is_true(db.showHotCharges)
        assert.same({ ALT_RIGHT = 51886 }, db.bindings)
        assert.is_true(db.collapsed)
    end)
end)

describe("Scale setting", function()
    it("defaults to 100 %, keeps a saved scale and is reset by Restore Defaults", function()
        local Logic = load()
        assert.equal(1, Logic.Migrate({ schema = 2, bindings = { LEFT = 331 } }).scale)
        assert.equal(1.25, Logic.Migrate({ schema = 2, scale = 1.25 }).scale)
        local db = Logic.RestoreDefaults({ scale = 0.8, bindings = { LEFT = 331 }, bindingRanks = {} })
        assert.equal(1, db.scale)
        assert.same({ LEFT = 331 }, db.bindings)
    end)
end)

describe("Logic.DispelAlerts (for the optional PaTiAlerts)", function()
    local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })
    local function isSecret(value) return rawequal(value, SECRET) end

    it("sends one INFO alert per member with a dispellable debuff, none for the others", function()
        local alerts = load().DispelAlerts({ { unit = "party1", name = "Tank", dispels = 1 },
            { unit = "party2", name = "Mage", dispels = 0 }, { unit = "party3", name = "Priest" } }, "can be dispelled", isSecret)
        assert.same({ { id = "dispel:party1", priority = "INFO", kind = "DISPELLABLE", name = "Tank",
            detail = "can be dispelled" } }, alerts)
    end)

    it("passes a secret name for display only and falls back to the unit without a name", function()
        local alerts = load().DispelAlerts({ { unit = "party1", name = SECRET, dispels = 2 }, { unit = "party2", dispels = 1 } },
            "x", isSecret)
        assert.is_true(rawequal(SECRET, alerts[1].name))
        assert.equal("party2", alerts[2].text)
    end)
end)
