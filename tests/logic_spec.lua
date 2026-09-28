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
