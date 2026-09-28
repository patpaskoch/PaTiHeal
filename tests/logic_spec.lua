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
        assert.equal(1, db.schema)
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

    it("does not touch an already migrated table", function()
        local db = { schema = 1, bindings = { ALT_LEFT = 331 }, locked = false, collapsed = false, language = "deDE" }
        assert.same({ schema = 1, bindings = { ALT_LEFT = 331 }, locked = false, collapsed = false, language = "deDE" },
            load().Migrate(db))
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
        local names = load().SpellNames({ LEFT = 331, RIGHT = 999 }, function(id) return id == 331 and "Heilende Welle" or nil end)
        assert.same({ LEFT = "Heilende Welle" }, names)
    end)
end)

describe("Logic.RestoreDefaults", function()
    it("clears bindings, lock and language but keeps the position", function()
        local db = load().RestoreDefaults({ x = 5, y = 6, locked = true, language = "koKR", bindings = { LEFT = 331 } })
        assert.same({}, db.bindings)
        assert.is_false(db.locked)
        assert.equal("auto", db.language)
        assert.equal(5, db.x)
    end)
end)
