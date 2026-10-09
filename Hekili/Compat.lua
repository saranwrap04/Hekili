-- Compat.lua
-- WoW 3.3.5a (AzerothCore) compatibility layer for the Wrath Classic version of Hekili.
--
-- Every Hekili file runs in its own environment (setfenv at the top of each file):
-- a global is looked up in the table below first, then in _G. Global writes still go
-- to _G. So the 3.3.5 versions of the API calls are only seen by Hekili, never by
-- other addons.

local addon, ns = ...

local _G = _G
local type, select, tonumber, tostring, pairs, ipairs, next = type, select, tonumber, tostring, pairs, ipairs, next
local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local strmatch, strfind, strlower, format = string.match, string.find, string.lower, string.format
local tinsert, tremove, wipe = table.insert, table.remove, wipe

local O = setmetatable( {}, { __index = _G } )
local env = setmetatable( {}, { __index = O, __newindex = _G } )
O._G = env

ns.CompatEnv = env

-- Texture paths follow the addon's folder name.
ns.AddonPath = "Interface\\AddOns\\" .. addon .. "\\"

-- The real 3.3.5 functions.
local Real = {
    GetSpellInfo = _G.GetSpellInfo,
    UnitAura = _G.UnitAura,
    UnitBuff = _G.UnitBuff,
    UnitDebuff = _G.UnitDebuff,
    UnitCastingInfo = _G.UnitCastingInfo,
    UnitChannelInfo = _G.UnitChannelInfo,
    UnitClass = _G.UnitClass,
    UnitPower = _G.UnitPower,
    UnitPowerMax = _G.UnitPowerMax,
    GetSpellCooldown = _G.GetSpellCooldown,
    GetSpellTexture = _G.GetSpellTexture,
    GetSpellLink = _G.GetSpellLink,
    GetShapeshiftFormInfo = _G.GetShapeshiftFormInfo,
    GetWeaponEnchantInfo = _G.GetWeaponEnchantInfo,
    GetNetStats = _G.GetNetStats,
    IsSpellKnown = _G.IsSpellKnown,
    CreateFrame = _G.CreateFrame,
}

-- Calls f and returns its results, or nothing if it raised an error.
local function SafeReturn( ok, ... )
    if ok then return ... end
end
local function SafeCall( f, ... )
    return SafeReturn( pcall( f, ... ) )
end

local noop = function() end
local function Stub()
    return setmetatable( {}, { __index = function() return noop end } )
end


---------------------------------------------------------------------------
-- Lua / FrameXML helpers that 3.3.5 does not have
---------------------------------------------------------------------------
O.Round = function( v ) if v < 0 then return ceil( v - 0.5 ) end return floor( v + 0.5 ) end
O.Clamp = function( v, lo, hi ) if v > hi then return hi elseif v < lo then return lo end return v end
O.tInvert = function( t ) local r = {} for k, v in pairs( t ) do r[ v ] = k end return r end
O.CopyTable = function( t )
    local function copy( s )
        local r = {}
        for k, v in pairs( s ) do r[ k ] = type( v ) == "table" and copy( v ) or v end
        return r
    end
    return copy( t )
end
O.Mixin = function( obj, ... )
    for i = 1, select( "#", ... ) do
        local m = select( i, ... )
        if type( m ) == "table" then for k, v in pairs( m ) do obj[ k ] = v end end
    end
    return obj
end
O.CreateFromMixins = function( ... ) return O.Mixin( {}, ... ) end

-- RegisterEvent with an event 3.3.5 does not have is made harmless.
local function SafeRegisterEvent( frame, event )
    local ok = pcall( frame.__RealRegisterEvent, frame, event )
    return ok
end

O.CreateFrame = function( frameType, name, parent, template, id )
    -- Backdrops are native on every frame in 3.3.5: "BackdropTemplate" is dropped from the template list.
    if template then
        local kept = {}
        for t in template:gmatch( "[^,%s]+" ) do
            if t ~= "BackdropTemplate" then kept[ #kept + 1 ] = t end
        end
        template = #kept > 0 and table.concat( kept, ", " ) or nil
    end
    local f = Real.CreateFrame( frameType, name, parent, template, id )
    if f and f.RegisterEvent and not f.__RealRegisterEvent then
        f.__RealRegisterEvent = f.RegisterEvent
        f.RegisterEvent = SafeRegisterEvent
    end
    return f
end


if not _G.UIDropDownMenu_AddSeparator then
    O.UIDropDownMenu_AddSeparator = function( level )
        UIDropDownMenu_AddButton( { text = "", disabled = true, notCheckable = true, isTitle = true }, level )
    end
end

O.Enum = {
    PowerType = {
        HealthCost = -2, None = -1, Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5,
        RunicPower = 6, SoulShards = 7, LunarPower = 8, HolyPower = 9, Alternate = 10, Maelstrom = 11,
        Chi = 12, Insanity = 13, Obsolete = 14, Obsolete2 = 15, ArcaneCharges = 16, Fury = 17, Pain = 18,
        Essence = 19, RuneBlood = 20, RuneFrost = 21, RuneUnholy = 22,
    },
    ItemSlotFilterTypeMeta = { MaxValue = 19 },
}


---------------------------------------------------------------------------
-- Timers (C_Timer)
---------------------------------------------------------------------------
do
    local timers = {}
    local frame = Real.CreateFrame( "Frame" )
    frame:Hide()

    frame:SetScript( "OnUpdate", function( self, elapsed )
        local now = GetTime()
        local i = 1
        while i <= #timers do
            local t = timers[ i ]
            if t.cancelled then
                tremove( timers, i )
            elseif now >= t.at then
                if t.iterations then t.iterations = t.iterations - 1 end
                if t.iterations and t.iterations <= 0 or not t.repeating then
                    tremove( timers, i )
                    t.done = true
                else
                    t.at = now + t.delay
                    i = i + 1
                end
                local ok, err = pcall( t.func, t )
                if not ok then geterrorhandler()( err ) end
            else
                i = i + 1
            end
        end
        if #timers == 0 then self:Hide() end
    end )

    local TimerObject = {}
    TimerObject.__index = TimerObject
    function TimerObject:Cancel() self.cancelled = true end
    function TimerObject:IsCancelled() return self.cancelled end

    local function NewTimer( delay, func, repeating, iterations )
        local t = setmetatable( { delay = max( delay or 0, 0 ), func = func, repeating = repeating, iterations = iterations }, TimerObject )
        t.at = GetTime() + t.delay
        tinsert( timers, t )
        frame:Show()
        return t
    end

    O.C_Timer = {
        After = function( delay, func ) NewTimer( delay, function() func() end ) end,
        NewTimer = function( delay, func ) return NewTimer( delay, func ) end,
        NewTicker = function( delay, func, iterations ) return NewTimer( delay, func, true, iterations ) end,
    }
end


---------------------------------------------------------------------------
-- Groups, classes
---------------------------------------------------------------------------
O.IsInRaid = function() return GetNumRaidMembers() > 0 end
O.IsInGroup = function() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end
O.GetNumSubgroupMembers = function() return GetNumPartyMembers() end
O.GetNumGroupMembers = function()
    local r = GetNumRaidMembers()
    if r > 0 then return r end
    local p = GetNumPartyMembers()
    return p > 0 and ( p + 1 ) or 0
end

local CLASS_IDS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}
local CLASS_FILES = {}
for k, v in pairs( CLASS_IDS ) do CLASS_FILES[ v ] = k end

O.UnitClass = function( unit )
    local name, file = Real.UnitClass( unit )
    return name, file, file and CLASS_IDS[ file ]
end
O.UnitClassBase = function( unit )
    local _, file = Real.UnitClass( unit )
    return file, file and CLASS_IDS[ file ]
end
O.GetNumClasses = function() return 11 end
O.GetClassInfo = function( id )
    local file = CLASS_FILES[ id ]
    if not file then return nil end
    return ( LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[ file ] ) or file, file, id
end

O.UnitEffectiveLevel = function( unit ) return UnitLevel( unit ) end
O.UnitGetTotalAbsorbs = function() return 0 end
O.UnitGetIncomingHeals = _G.UnitGetIncomingHeals or function() return 0 end
O.UnitPhaseReason = function() return nil end
O.UnitWeaponAttackPower = function() return 0 end
O.UnitStagger = function() return 0 end
O.UnitIsTrivial = _G.UnitIsTrivial or function() return false end
O.HasVehicleActionBar = _G.HasVehicleActionBar or function() return UnitHasVehicleUI and UnitHasVehicleUI( "player" ) or false end
O.HasOverrideActionBar = _G.HasOverrideActionBar or function() return false end
O.IsInJailersTower = function() return false end

-- Combo points are power type 4 in Classic; in 3.3.5 type 4 is pet happiness.
O.UnitPower = function( unit, powerType, ... )
    if powerType == 4 and ( unit == "player" or unit == nil ) then
        return GetComboPoints( "player", "target" ) or 0
    end
    return Real.UnitPower( unit, powerType, ... )
end
O.UnitPowerMax = function( unit, powerType, ... )
    if powerType == 4 and ( unit == "player" or unit == nil ) then return 5 end
    return Real.UnitPowerMax( unit, powerType, ... )
end

-- 3.3.5: bandwidthIn, bandwidthOut, latency. Classic: + latencyWorld.
O.GetNetStats = function()
    local a, b, latency = Real.GetNetStats()
    return a, b, latency, latency
end


---------------------------------------------------------------------------
-- Haste (3.3.5 only has the ratings; the common haste buffs are added on top)
---------------------------------------------------------------------------
do
    -- Matched by buff name (the client's own language), so every rank and source counts.
    local SPELL_HASTE = {
        { 2825, 30, "bl" }, { 32182, 30, "bl" },   -- Bloodlust, Heroism
        { 12472, 20 },                               -- Icy Veins
        { 26297, 20 },                               -- Berserking
        { 10060, 20 },                               -- Power Infusion
        { 3738, 5 },                                 -- Wrath of Air Totem
        { 48396, 3, "3" }, { 53648, 3, "3" },        -- Improved Moonkin Form, Swift Retribution
    }
    local MELEE_HASTE = {
        { 2825, 30, "bl" }, { 32182, 30, "bl" },   -- Bloodlust, Heroism
        { 8512, 20, "wf" }, { 55610, 20, "wf" },   -- Windfury Totem, Improved Icy Talons
        { 26297, 20 },                               -- Berserking
        { 13877, 20 },                               -- Blade Flurry
        { 48396, 3, "3" }, { 53648, 3, "3" },        -- Improved Moonkin Form, Swift Retribution
    }

    local function ByName( list )
        local t = {}
        for _, e in ipairs( list ) do
            local name = Real.GetSpellInfo( e[1] )
            if name then t[ name ] = { e[2], e[3] or name } end
        end
        return t
    end
    local spellByName, meleeByName

    local seen = {}
    local function BuffHaste( byName )
        wipe( seen )
        local mult = 1
        for i = 1, 40 do
            local name = Real.UnitAura( "player", i, "HELPFUL" )
            if not name then break end
            local e = byName[ name ]
            -- Buffs in the same group (Bloodlust / Heroism...) do not stack.
            if e and not seen[ e[2] ] then
                seen[ e[2] ] = true
                mult = mult * ( 1 + e[1] / 100 )
            end
        end
        return mult
    end

    O.UnitSpellHaste = function()
        spellByName = spellByName or ByName( SPELL_HASTE )
        return ( ( 1 + GetCombatRatingBonus( CR_HASTE_SPELL ) / 100 ) * BuffHaste( spellByName ) - 1 ) * 100
    end
    O.GetMeleeHaste = function()
        meleeByName = meleeByName or ByName( MELEE_HASTE )
        return ( ( 1 + GetCombatRatingBonus( CR_HASTE_MELEE ) / 100 ) * BuffHaste( meleeByName ) - 1 ) * 100
    end
    O.GetRangedHaste = function()
        return GetCombatRatingBonus( CR_HASTE_RANGED )
    end
    O.GetHaste = O.UnitSpellHaste
end

O.GetMasteryEffect = function() return 0 end
O.GetMastery = function() return 0 end
O.GetVersatilityBonus = function() return 0 end
O.CR_VERSATILITY_DAMAGE_DONE = _G.CR_VERSATILITY_DAMAGE_DONE or 29
O.CR_VERSATILITY_DAMAGE_TAKEN = _G.CR_VERSATILITY_DAMAGE_TAKEN or 31
O.CR_MASTERY = _G.CR_MASTERY or 26
O.GetPowerRegenForPowerType = function( powerType )
    if powerType == 0 then
        local base, casting = GetManaRegen()
        return base, casting
    end
    if GetPowerRegen then return GetPowerRegen() end
    return 0, 0
end


---------------------------------------------------------------------------
-- Spells: spellbook scan (spell ID <-> book slot, name -> spell ID)
---------------------------------------------------------------------------
local bookSlot = {}      -- spellID -> slot
local bookType = {}      -- spellID -> "spell" / "pet"
local nameToID = {}      -- spell name -> spell ID (highest rank in the book)
local seenNameToID = {}  -- spell name -> a spell ID seen through GetSpellInfo
local Known              -- spell ID -> known by the player (defined below)

local function ScanBook( book, first, last )
    for i = first, last do
        local name = GetSpellName( i, book )
        if not name then break end
        local link = Real.GetSpellLink( i, book )
        local id = link and tonumber( strmatch( link, "spell:(%d+)" ) )
        if id then
            bookSlot[ id ] = i
            bookType[ id ] = book
            nameToID[ name ] = id
        end
    end
end

local function ScanSpellbook()
    wipe( bookSlot )
    wipe( bookType )
    wipe( nameToID )
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo( tab )
        if offset and numSpells then ScanBook( "spell", offset + 1, offset + numSpells ) end
    end
    local numPet = HasPetSpells()
    if numPet and numPet > 0 then ScanBook( "pet", 1, numPet ) end
end

local function NameToID( name )
    if not name then return nil end
    return nameToID[ name ] or seenNameToID[ name ]
end

do
    local f = Real.CreateFrame( "Frame" )
    f:RegisterEvent( "PLAYER_LOGIN" )
    f:RegisterEvent( "SPELLS_CHANGED" )
    f:RegisterEvent( "LEARNED_SPELL_IN_TAB" )
    f:RegisterEvent( "PET_BAR_UPDATE" )
    f:RegisterEvent( "UNIT_PET" )
    f:SetScript( "OnEvent", ScanSpellbook )
end

-- Classic order: name, rank, icon, castTime, minRange, maxRange, spellID.
-- 3.3.5 order:   name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange.
-- (Called for every ability on every update: no pcall or string work on the common path.)
O.GetSpellInfo = function( spell, book )
    if spell == nil then return nil end

    if book then
        -- A spellbook slot: an invalid slot is an error in 3.3.5; the ID comes from the slot's link.
        local name, rank, icon, _, _, _, castTime, minRange, maxRange = SafeCall( Real.GetSpellInfo, spell, book )
        if not name then return nil end
        local link = Real.GetSpellLink( spell, book )
        local id = link and tonumber( strmatch( link, "spell:(%d+)" ) ) or NameToID( name )
        return name, rank, icon, castTime, minRange, maxRange, id
    end

    local name, rank, icon, _, _, _, castTime, minRange, maxRange = Real.GetSpellInfo( spell )
    if not name then return nil end

    local id
    if type( spell ) == "number" then
        id = spell
        if not seenNameToID[ name ] then seenNameToID[ name ] = id end
    else
        id = NameToID( name )
    end
    return name, rank, icon, castTime, minRange, maxRange, id
end

-- Spell ID -> what the 3.3.5 functions take (a name, or a book slot + book).
local function SpellArg( spell )
    if type( spell ) ~= "number" then return spell end
    local slot = bookSlot[ spell ]
    if slot then return slot, bookType[ spell ] end
    return ( Real.GetSpellInfo( spell ) )
end

local function WrapSpellCall( fname, byName )
    local real = _G[ fname ]
    if not real then return end
    O[ fname ] = function( spell, a, ... )
        if spell == nil then return nil end -- 3.3.5 errors on a missing spell
        if type( spell ) == "number" and ( a == nil or ( a ~= "spell" and a ~= "pet" and a ~= BOOKTYPE_SPELL and a ~= BOOKTYPE_PET ) ) then
            local arg, book
            if byName then arg = Real.GetSpellInfo( spell ) else arg, book = SpellArg( spell ) end
            if arg == nil then return nil end
            if book then return real( arg, book, a, ... ) end
            return real( arg, a, ... )
        end
        -- Called by the addon with its own slot + book type: guard against a stale slot.
        if type( spell ) == "number" then return SafeCall( real, spell, a, ... ) end
        return real( spell, a, ... )
    end
end

-- These take a spellbook slot + book type, or a name.
for _, f in ipairs( { "IsUsableSpell", "IsCurrentSpell", "GetSpellCount", "SpellHasRange",
                      "IsHarmfulSpell", "IsHelpfulSpell", "IsSpellInRange" } ) do
    WrapSpellCall( f )
end
-- These only take a name.
for _, f in ipairs( { "IsAutoRepeatSpell", "IsAttackSpell", "IsConsumableSpell" } ) do
    WrapSpellCall( f, true )
end

-- GetSpellCooldown( 61304 ) is the global cooldown in later clients. 3.3.5 has no such
-- spell, so the first known spell of the class's list is read instead: spells with no
-- cooldown of their own, so their cooldown is the global cooldown.
local GCD_SPELLS = {
    WARRIOR = { 6673, 772 },             -- Battle Shout, Rend
    PALADIN = { 635, 19740 },            -- Holy Light, Blessing of Might
    HUNTER = { 1978, 1130, 13165 },      -- Serpent Sting, Hunter's Mark, Aspect of the Hawk
    ROGUE = { 1752 },                    -- Sinister Strike
    PRIEST = { 1243, 585 },              -- Power Word: Fortitude, Smite
    DEATHKNIGHT = { 47541 },             -- Death Coil
    SHAMAN = { 403, 331 },               -- Lightning Bolt, Healing Wave
    MAGE = { 1459, 133 },                -- Arcane Intellect, Fireball
    WARLOCK = { 686, 687 },              -- Shadow Bolt, Demon Skin
    DRUID = { 1126, 5176 },              -- Mark of the Wild, Wrath
}

local function GCDCooldown()
    local _, file = Real.UnitClass( "player" )
    for _, id in ipairs( GCD_SPELLS[ file ] or {} ) do
        local arg, bk = SpellArg( id )
        if arg and ( bk or Known( id ) ) then
            local start, duration, enabled = Real.GetSpellCooldown( arg, bk )
            if start and ( duration or 0 ) <= 1.5 then return start, duration, enabled end
            return 0, 0, 1
        end
    end
    return 0, 0, 1
end

O.GetSpellCooldown = function( spell, book )
    if spell == nil then return 0, 0, 1 end
    if spell == 61304 and not book then return GCDCooldown() end

    local start, duration, enabled
    if type( spell ) == "number" and not book then
        local arg, bk = SpellArg( spell )
        if arg ~= nil then start, duration, enabled = Real.GetSpellCooldown( arg, bk ) end
    elseif book then
        start, duration, enabled = SafeCall( Real.GetSpellCooldown, spell, book )
    else
        start, duration, enabled = Real.GetSpellCooldown( spell )
    end
    -- Classic returns 0, 0 for a spell it cannot find; 3.3.5 returns nothing.
    if not start then return 0, 0, 1 end
    return start, duration, enabled
end

O.GetSpellTexture = function( spell, book )
    if spell == nil then return nil end
    if type( spell ) == "number" and not book then
        return ( select( 3, Real.GetSpellInfo( spell ) ) )
    end
    return SafeCall( Real.GetSpellTexture, spell, book )
end

O.GetSpellLink = function( spell, book )
    if spell == nil then return nil end
    local link = SafeCall( Real.GetSpellLink, spell, book )
    if link then return link end
    if type( spell ) == "number" and not book then
        local name = Real.GetSpellInfo( spell )
        if name then return format( "|cff71d5ff|Hspell:%d|h[%s]|h|r", spell, name ) end
    end
end

O.GetSpellDescription = function() return "" end
O.GetSpellSubtext = function( spell ) return ( select( 2, Real.GetSpellInfo( spell ) ) ) end
O.GetSpellCharges = function() return nil end
O.GetSpellBaseCooldown = function() return nil end
O.SpellIsSelfBuff = _G.SpellIsSelfBuff or function() return false end
O.GetSpellPowerCost = function( spell )
    local name, _, _, cost, _, powerType = Real.GetSpellInfo( spell )
    if not name or not cost or cost == 0 then return {} end
    return { { type = powerType, cost = cost, minCost = cost, costPercent = 0, costPerSec = 0 } }
end

O.IsPassiveSpell = function( spell, book )
    if spell == nil then return false end
    if type( spell ) == "number" and not book then
        local slot = bookSlot[ spell ]
        if not slot then return false end
        return _G.IsPassiveSpell( slot, bookType[ spell ] )
    end
    return SafeCall( _G.IsPassiveSpell, spell, book )
end

Known = function( id )
    if not id then return false end
    if bookSlot[ id ] then return true end
    if Real.IsSpellKnown then return Real.IsSpellKnown( id ) and true or false end
    return false
end
O.IsPlayerSpell = Known
O.IsSpellKnown = function( id, isPet )
    if isPet then return Real.IsSpellKnown and Real.IsSpellKnown( id, true ) or false end
    return Known( id )
end
O.IsSpellKnownOrOverridesKnown = Known

O.FindSpellBookSlotBySpellID = function( id ) return bookSlot[ id ] end
O.GetSpellBookItemName = function( slot, book )
    local name, rank = GetSpellName( slot, book )
    if not name then return nil end
    local link = Real.GetSpellLink( slot, book )
    return name, rank, link and tonumber( strmatch( link, "spell:(%d+)" ) )
end
O.GetSpellBookItemInfo = function( slot, book )
    local _, _, id = O.GetSpellBookItemName( slot, book )
    if not id then return nil end
    return "SPELL", id
end

O.IsSpellOverlayed = function() return false end

-- 3.3.5 has 4 totem slots and errors on any other number (Classic accepts 5).
O.GetTotemInfo = function( slot )
    slot = tonumber( slot )
    if not slot or slot < 1 or slot > 4 then return false, "", 0, 0, "" end
    return GetTotemInfo( slot )
end
O.GetTotemTimeLeft = function( slot )
    slot = tonumber( slot )
    if not slot or slot < 1 or slot > 4 then return 0 end
    return GetTotemTimeLeft( slot )
end

-- 3.3.5: spellType, spellbook slot, subType, spellID. Classic: spellType, spellID, subType.
O.GetActionInfo = function( slot )
    local actionType, id, subType, spellID = GetActionInfo( slot )
    if actionType == "spell" then
        if type( spellID ) ~= "number" then
            local link = id and Real.GetSpellLink( id, subType or "spell" )
            spellID = link and tonumber( strmatch( link, "spell:(%d+)" ) )
        end
        return actionType, spellID or id, subType, spellID
    end
    return actionType, id, subType, spellID
end

-- 3.3.5: spellName, rank. Classic: spellID.
O.GetMacroSpell = function( macro )
    local name = GetMacroSpell( macro )
    return name and NameToID( name ) or nil
end

-- 3.3.5: spellName, rank. Classic: spellName, spellID.
O.GetItemSpell = function( item )
    local name = GetItemSpell( item )
    if not name then return nil end
    return name, NameToID( name )
end

-- Shapeshift forms. Wrath Classic: icon, name, active, castable, spellID. 3.3.5: the same without spellID.
O.GetShapeshiftFormInfo = function( index )
    local icon, name, active, castable = Real.GetShapeshiftFormInfo( index )
    if not icon then return nil end
    return icon, name, active, castable, NameToID( name )
end


---------------------------------------------------------------------------
-- Auras. Classic order:
--   name, icon, count, debuffType, duration, expirationTime, source, isStealable,
--   nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod
-- 3.3.5 order:
--   name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
---------------------------------------------------------------------------
local function Convert( name, _, icon, count, debuffType, duration, expirationTime, caster, isStealable, _, spellId )
    if not name then return nil end
    local byPlayer = caster == "player" or caster == "pet" or caster == "vehicle"
    return name, icon, count or 0, debuffType, duration or 0, expirationTime or 0, caster, isStealable, false,
        spellId, byPlayer, false, byPlayer, false, 1
end

O.UnitAura = function( unit, index, filter, ... )
    if type( index ) ~= "number" then return Convert( Real.UnitAura( unit, index, filter, ... ) ) end
    return Convert( Real.UnitAura( unit, index, filter ) )
end
O.UnitBuff = function( unit, index, filter, ... )
    if type( index ) ~= "number" then return Convert( Real.UnitBuff( unit, index, filter, ... ) ) end
    return Convert( Real.UnitBuff( unit, index, filter ) )
end
O.UnitDebuff = function( unit, index, filter, ... )
    if type( index ) ~= "number" then return Convert( Real.UnitDebuff( unit, index, filter, ... ) ) end
    return Convert( Real.UnitDebuff( unit, index, filter ) )
end

local AURA_FILTERS = { "HELPFUL", "HARMFUL" }
O.GetPlayerAuraBySpellID = function( id )
    for _, filter in ipairs( AURA_FILTERS ) do
        for i = 1, 40 do
            local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, consolidate, spellId = Real.UnitAura( "player", i, filter )
            if not name then break end
            if spellId == id then
                return Convert( name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, consolidate, spellId )
            end
        end
    end
end



---------------------------------------------------------------------------
-- Casting. Classic: name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId
--          3.3.5:   name, rank, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
---------------------------------------------------------------------------
O.UnitCastingInfo = function( unit )
    local name, rank, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = Real.UnitCastingInfo( unit )
    if not name then return nil end
    return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, NameToID( name )
end

-- Classic: name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellId
-- 3.3.5:   name, rank, text, texture, startTime, endTime, isTradeSkill, notInterruptible
O.UnitChannelInfo = function( unit )
    local name, rank, text, texture, startTime, endTime, isTradeSkill, notInterruptible = Real.UnitChannelInfo( unit )
    if not name then return nil end
    return name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, NameToID( name )
end


---------------------------------------------------------------------------
-- Weapon enchants (poisons, shaman imbues). 3.3.5 gives no enchant IDs, so the
-- weapon tooltip is read and the imbue is mapped to one of its Classic enchant IDs.
---------------------------------------------------------------------------
do
    local tip = Real.CreateFrame( "GameTooltip", "HekiliCompatScanTooltip", nil, "GameTooltipTemplate" )
    tip:SetOwner( WorldFrame, "ANCHOR_NONE" )

    local IMBUES = {
        { "Windfury", 283 }, { "Flametongue", 5 }, { "Frostbrand", 2 }, { "Rockbiter", 3023 }, { "Earthliving", 3345 },
        { "Instant Poison", 323 }, { "Deadly Poison", 2630 }, { "Wound Poison", 703 }, { "Crippling Poison", 22 },
        { "Mind%-numbing Poison", 35 }, { "Anesthetic Poison", 2640 },
    }

    local function EnchantID( slot )
        tip:ClearLines()
        tip:SetOwner( WorldFrame, "ANCHOR_NONE" )
        tip:SetInventoryItem( "player", slot )
        for i = 1, tip:NumLines() do
            local line = _G[ "HekiliCompatScanTooltipTextLeft" .. i ]
            local text = line and line:GetText()
            if text and strfind( text, "%(%d+ [a-z]+%)" ) then
                for _, imbue in ipairs( IMBUES ) do
                    if strfind( text, imbue[1] ) then return imbue[2] end
                end
            end
        end
        return nil
    end

    -- Classic: hasMH, mhExpiration, mhCharges, mhEnchantID, hasOH, ohExpiration, ohCharges, ohEnchantID
    -- The tooltip is read again at most once a second, or when an enchant appears or goes.
    local lastScan, lastMH, lastOH, mhID, ohID = 0, nil, nil, nil, nil

    O.GetWeaponEnchantInfo = function()
        local hasMH, mhExp, mhCharges, hasOH, ohExp, ohCharges = Real.GetWeaponEnchantInfo()
        local now = GetTime()
        if now - lastScan > 1 or hasMH ~= lastMH or hasOH ~= lastOH then
            lastScan, lastMH, lastOH = now, hasMH, hasOH
            mhID = hasMH and EnchantID( 16 ) or nil
            ohID = hasOH and EnchantID( 17 ) or nil
        end
        return hasMH, mhExp, mhCharges, hasMH and mhID or nil, hasOH, ohExp, ohCharges, hasOH and ohID or nil
    end
end


---------------------------------------------------------------------------
-- Items (ItemMixin / C_Container)
---------------------------------------------------------------------------
do
    local tip = Real.CreateFrame( "GameTooltip", "HekiliCompatItemTooltip", nil, "GameTooltipTemplate" )
    local waiting = {}
    local frame = Real.CreateFrame( "Frame" )
    frame:Hide()
    local elapsedTotal, tries = 0, 0

    frame:SetScript( "OnUpdate", function( self, elapsed )
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.5 then return end
        elapsedTotal = 0
        tries = tries + 1
        for item, callbacks in pairs( waiting ) do
            if GetItemInfo( item.itemID ) or tries > 20 then
                waiting[ item ] = nil
                for _, cb in ipairs( callbacks ) do
                    local ok, err = pcall( cb, GetItemInfo( item.itemID ) ~= nil )
                    if not ok then geterrorhandler()( err ) end
                end
            end
        end
        if not next( waiting ) then tries = 0; self:Hide() end
    end )

    local Item = {}
    Item.__index = Item

    function Item:CreateFromItemID( id ) return setmetatable( { itemID = id }, Item ) end
    function Item:GetItemID() return self.itemID end
    -- Items above 56806 are from later clients: 3.3.5 does not know them, so they are not asked for.
    function Item:IsItemEmpty() return not self.itemID or self.itemID > 56806 end
    function Item:IsItemDataCached() return GetItemInfo( self.itemID ) ~= nil end
    function Item:GetItemName() return ( GetItemInfo( self.itemID ) ) end
    function Item:GetItemLink() return ( select( 2, GetItemInfo( self.itemID ) ) ) end
    function Item:GetItemQuality() return ( select( 3, GetItemInfo( self.itemID ) ) ) end
    function Item:GetItemIcon() return GetItemIcon and GetItemIcon( self.itemID ) or select( 10, GetItemInfo( self.itemID ) ) end
    function Item:ContinueOnItemLoad( cb )
        if self:IsItemEmpty() then return end
        if GetItemInfo( self.itemID ) then cb( true ) return end
        tip:SetOwner( WorldFrame, "ANCHOR_NONE" )
        tip:SetHyperlink( "item:" .. self.itemID )
        tip:Hide()
        waiting[ self ] = waiting[ self ] or {}
        tinsert( waiting[ self ], cb )
        frame:Show()
    end
    Item.ContinueWithCancelOnItemLoad = Item.ContinueOnItemLoad

    O.Item = Item
    O.ItemLocation = { CreateEmpty = function() return {} end, CreateFromEquipmentSlot = function( _, slot ) return { slot = slot } end }

    O.C_Container = {
        GetItemCooldown = GetItemCooldown,
        GetContainerNumSlots = GetContainerNumSlots,
        GetContainerItemID = GetContainerItemID or function( bag, slot )
            local link = GetContainerItemLink( bag, slot )
            return link and tonumber( strmatch( link, "item:(%d+)" ) )
        end,
        GetContainerItemLink = GetContainerItemLink,
    }
    O.C_Item = {
        GetItemInfo = GetItemInfo,
        GetItemIconByID = function( id ) return GetItemIcon and GetItemIcon( id ) or select( 10, GetItemInfo( id ) ) end,
        IsItemDataCachedByID = function( id ) return GetItemInfo( id ) ~= nil end,
        RequestLoadItemDataByID = function( id ) tip:SetOwner( WorldFrame, "ANCHOR_NONE" ); tip:SetHyperlink( "item:" .. id ); tip:Hide() end,
    }
    O.GetItemIcon = _G.GetItemIcon or function( id ) return select( 10, GetItemInfo( id ) ) end
    O.GetItemInfoInstant = function( item )
        local id = type( item ) == "number" and item or tonumber( strmatch( tostring( item ), "item:(%d+)" ) or "" )
        local _, _, _, _, _, itemType, subType, _, equipLoc, icon = GetItemInfo( item )
        return id, itemType, subType, equipLoc, icon
    end
end


---------------------------------------------------------------------------
-- Other C_ namespaces
---------------------------------------------------------------------------
O.C_AddOns = { GetAddOnMetadata = GetAddOnMetadata, IsAddOnLoaded = IsAddOnLoaded, LoadAddOn = LoadAddOn }
O.C_Spell = {
    IsSpellDataCached = function() return true end,
    RequestLoadSpellData = noop,
    GetSpellInfo = function( id ) return O.GetSpellInfo( id ) end,
}
O.C_Texture = { GetAtlasInfo = function() return nil end }
O.C_PlayerInfo = { IsPlayerInChromieTime = function() return false end }
O.C_PetBattles = { IsInBattle = function() return false end }
O.C_PvP = { IsWarModeDesired = function() return false end, IsWarModeActive = function() return false end }
O.C_NamePlate = { GetNamePlateForUnit = function() return nil end, GetNamePlates = function() return {} end }
O.C_LossOfControl = { GetActiveLossOfControlDataCount = function() return 0 end, GetActiveLossOfControlData = noop }
-- Class colours with the ColorMixin methods later clients have.
do
    local ColorMethods = {
        GetRGB = function( c ) return c.r, c.g, c.b end,
        GetRGBA = function( c ) return c.r, c.g, c.b, c.a or 1 end,
        GenerateHexColor = function( c ) return format( "ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255 ) end,
        GenerateHexColorMarkup = function( c ) return format( "|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255 ) end,
        WrapTextInColorCode = function( c, text ) return format( "|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text ) end,
    }
    ColorMethods.__index = ColorMethods
    local cache = {}
    O.RAID_CLASS_COLORS = setmetatable( {}, {
        __index = function( t, k )
            local c = _G.RAID_CLASS_COLORS[ k ]
            if not c then return nil end
            local w = cache[ k ]
            if not w then
                w = setmetatable( { r = c.r, g = c.g, b = c.b, a = 1, colorStr = c.colorStr }, ColorMethods )
                cache[ k ] = w
            end
            return w
        end,
    } )
    O.CreateColor = function( r, g, b, a ) return setmetatable( { r = r, g = g, b = b, a = a or 1 }, ColorMethods ) end
end
O.C_ClassColor = { GetClassColor = function( file ) return O.RAID_CLASS_COLORS[ file ] end }
for _, name in ipairs( { "C_Traits", "C_ClassTalents", "C_AzeriteItem", "C_AzeriteEmpoweredItem", "C_AzeriteEssence",
                         "C_Soulbinds", "C_SpecializationInfo", "C_Covenants", "C_UnitAuras", "C_CVar", "C_Map" } ) do
    if not _G[ name ] then O[ name ] = Stub() end
end
O.C_CVar.GetCVar = GetCVar
O.C_CVar.SetCVar = SetCVar

O.GetActiveLossOfControlDataCount = function() return 0 end
O.GetActiveLossOfControlData = noop
O.GetPvpTalentInfoByID = noop
O.GetTalentInfoByID = noop
O.GetSpecializationMasterySpells = noop
O.GetSpecializationInfoByID = function( id )
    local file = CLASS_FILES[ id ]
    if not file then return nil end
    local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[ file ] or file
    return id, name, "", "Interface\\Icons\\INV_Misc_QuestionMark", "DAMAGER", file
end
O.BATTLE_PET_NAME_4 = _G.BATTLE_PET_NAME_4 or "Undead"
O.BEST = _G.BEST or "Best"
O.SPELL_MAX_CHARGES = _G.SPELL_MAX_CHARGES or "Max %d charges"
O.CAPACITANCE_SHIPMENT_COOLDOWN = _G.CAPACITANCE_SHIPMENT_COOLDOWN or "%s"


---------------------------------------------------------------------------
-- Combat log: 3.3.5 passes the arguments with the event and has no hideCaster
-- or raid flags. Translated to the Classic order and kept for CombatLogGetCurrentEventInfo().
---------------------------------------------------------------------------
do
    local cleu, n = {}, 0

    local function Store( ... )
        n = select( "#", ... )
        for i = 1, n do cleu[ i ] = ( select( i, ... ) ) end
        return ...
    end

    local ZERO_GUID = "0x0000000000000000"

    -- 3.3.5 does not say which hand a melee swing came from: the hand whose next
    -- swing was due closest to now is taken.
    local mhLast, ohLast = 0, 0
    local function IsOffHand()
        local mh, oh = UnitAttackSpeed( "player" )
        local t = GetTime()
        if not oh or oh == 0 then mhLast = t return false end
        if abs( t - ( ohLast + oh ) ) < abs( t - ( mhLast + ( mh or 2 ) ) ) then
            ohLast = t
            return true
        end
        mhLast = t
        return false
    end

    local MISSED_WITH_HAND = { SPELL_MISSED = true, SPELL_PERIODIC_MISSED = true, RANGE_MISSED = true, DAMAGE_SHIELD_MISSED = true }

    function ns.TranslateCLEU( timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ... )
        if sourceGUID == ZERO_GUID then sourceGUID = "" end
        if destGUID == ZERO_GUID then destGUID = "" end

        if subevent == "SWING_DAMAGE" then
            -- amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing (+ isOffHand in Classic)
            local a1, a2, a3, a4, a5, a6, a7, a8, a9 = ...
            local offhand = sourceGUID == UnitGUID( "player" ) and IsOffHand() or false
            return Store( timestamp, subevent, false, sourceGUID, sourceName, sourceFlags, 0, destGUID, destName, destFlags, 0, a1, a2, a3, a4, a5, a6, a7, a8, a9, offhand )
        elseif subevent == "SWING_MISSED" then
            -- missType, amountMissed -> missType, isOffHand, amountMissed
            local missType, amount = ...
            local offhand = sourceGUID == UnitGUID( "player" ) and IsOffHand() or false
            return Store( timestamp, subevent, false, sourceGUID, sourceName, sourceFlags, 0, destGUID, destName, destFlags, 0, missType, offhand, amount )
        elseif MISSED_WITH_HAND[ subevent ] then
            -- spellID, spellName, school, missType, amountMissed -> ..., missType, isOffHand, amountMissed
            local id, name, school, missType, amount = ...
            return Store( timestamp, subevent, false, sourceGUID, sourceName, sourceFlags, 0, destGUID, destName, destFlags, 0, id, name, school, missType, false, amount )
        end

        return Store( timestamp, subevent, false, sourceGUID, sourceName, sourceFlags, 0, destGUID, destName, destFlags, 0, ... )
    end

    -- Same order, without touching the stored event or the swing tracking (for listeners
    -- other than the main event handler).
    function ns.TranslateCLEUPure( timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ... )
        if sourceGUID == ZERO_GUID then sourceGUID = "" end
        if destGUID == ZERO_GUID then destGUID = "" end
        return timestamp, subevent, false, sourceGUID, sourceName, sourceFlags, 0, destGUID, destName, destFlags, 0, ...
    end

    O.CombatLogGetCurrentEventInfo = function()
        return unpack( cleu, 1, n )
    end
end


---------------------------------------------------------------------------
-- Events with other arguments (or other names) in 3.3.5
---------------------------------------------------------------------------
do
    local loginSeen = false
    local translate = {}

    -- Classic: isInitialLogin, isReloadingUi. 3.3.5: none. The first one is treated as a login.
    translate.PLAYER_ENTERING_WORLD = function( ... )
        if select( "#", ... ) > 0 then return ... end
        local first = not loginSeen
        loginSeen = true
        return first, false
    end

    translate.COMBAT_LOG_EVENT_UNFILTERED = ns.TranslateCLEU

    -- Classic: unit, castGUID, spellID. 3.3.5: unit, spellName, rank, lineID (, spellID on some cores).
    local function SpellcastArgs( unit, spellName, rank, lineID, spellID )
        if type( spellID ) ~= "number" then spellID = NameToID( spellName ) end
        return unit, tostring( lineID or "" ), spellID
    end
    for _, e in ipairs( { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
                          "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
                          "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_FAILED_QUIET" } ) do
        translate[ e ] = SpellcastArgs
    end

    -- Classic: unit, target, castGUID, spellID. 3.3.5: unit, spellName, rank, target (, lineID).
    translate.UNIT_SPELLCAST_SENT = function( unit, spellName, rank, target, lineID )
        return unit, target, tostring( lineID or "" ), NameToID( spellName )
    end

    function ns.TranslateEventArgs( event, ... )
        local t = translate[ event ]
        if t then return t( ... ) end
        return ...
    end

    -- UNIT_POWER_UPDATE / UNIT_POWER_FREQUENT do not exist in 3.3.5.
    ns.POWER_EVENTS = {
        UNIT_MANA = "MANA", UNIT_RAGE = "RAGE", UNIT_FOCUS = "FOCUS", UNIT_ENERGY = "ENERGY",
        UNIT_RUNIC_POWER = "RUNIC_POWER", UNIT_COMBO_POINTS = "COMBO_POINTS",
    }
    ns.EVENT_ALIASES = {
        UNIT_POWER_UPDATE = { "UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_COMBO_POINTS" },
        UNIT_POWER_FREQUENT = { "UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_COMBO_POINTS" },
    }
end


---------------------------------------------------------------------------
-- Textures: Classic uses file IDs (numbers); 3.3.5 needs paths.
---------------------------------------------------------------------------
do
    local ICONS = {
        [132089]="ability_ambush", [132090]="ability_backstab", [132091]="ability_bullrush",
        [132092]="ability_cheapshot", [132099]="ability_creature_disease_02", [132109]="ability_criticalstrike",
        [132110]="ability_defend", [132111]="ability_devour", [132112]="ability_druid_aquaticform",
        [132114]="ability_druid_bash", [132115]="ability_druid_catform",
        [132117]="ability_druid_challangingroar", [132118]="ability_druid_cower", [132120]="ability_druid_dash",
        [132121]="ability_druid_demoralizingroar", [132122]="ability_druid_disembowel",
        [132126]="ability_druid_enrage", [132127]="ability_druid_ferociousbite",
        [132128]="ability_druid_flightform", [132129]="ability_druid_forceofnature",
        [132131]="ability_druid_lacerate", [132132]="ability_druid_lunarguidance",
        [132134]="ability_druid_mangle.tga", [132135]="ability_druid_mangle2", [132136]="ability_druid_maul",
        [132140]="ability_druid_rake", [132141]="ability_druid_ravage", [132142]="ability_druid_supriseattack",
        [132144]="ability_druid_travelform", [132150]="ability_eyeoftheowl", [132152]="ability_ghoulfrenzy",
        [132153]="ability_golemstormbolt", [132154]="ability_golemthunderclap", [132155]="ability_gouge",
        [132157]="ability_hunter_aimedshot", [132159]="ability_hunter_aspectofthemonkey",
        [132160]="ability_hunter_aspectoftheviper", [132161]="ability_hunter_beastcall",
        [132163]="ability_hunter_beastsoothe", [132164]="ability_hunter_beasttaming",
        [132165]="ability_hunter_beasttraining", [132169]="ability_hunter_criticalshot",
        [132172]="ability_hunter_eagleeye", [132176]="ability_hunter_killcommand",
        [132179]="ability_hunter_mendpet", [132180]="ability_hunter_misdirection",
        [132182]="ability_hunter_pet_bat", [132188]="ability_hunter_pet_dragonhawk",
        [132204]="ability_hunter_quickshot", [132205]="ability_hunter_rapidkilling",
        [132206]="ability_hunter_readiness", [132208]="ability_hunter_runningshot",
        [132211]="ability_hunter_snaketrap", [132212]="ability_hunter_snipershot",
        [132213]="ability_hunter_steadyshot", [132215]="ability_hunter_swiftstrike",
        [132218]="ability_impalingbolt", [132219]="ability_kick", [132222]="ability_marksmanship",
        [132223]="ability_meleedamage", [132242]="ability_mount_jungletiger",
        [132252]="ability_mount_pinktiger", [132267]="ability_mount_whitetiger",
        [132270]="ability_physical_taunt", [132275]="ability_racial_avatar", [132276]="ability_racial_bearform",
        [132277]="ability_racial_bloodrage", [132282]="ability_rogue_ambush",
        [132287]="ability_rogue_disembowel", [132289]="ability_rogue_distract",
        [132292]="ability_rogue_eviscerate", [132293]="ability_rogue_feigndeath",
        [132294]="ability_rogue_feint", [132297]="ability_rogue_garrote", [132298]="ability_rogue_kidneyshot",
        [132302]="ability_rogue_rupture", [132303]="ability_rogue_shadowstep",
        [132304]="ability_rogue_shadowstrikes", [132306]="ability_rogue_slicedice",
        [132307]="ability_rogue_sprint", [132309]="ability_rogue_trip", [132310]="ability_sap",
        [132314]="ability_shaman_stormstrike", [132315]="ability_shaman_watershield",
        [132316]="ability_shockwave", [132320]="ability_stealth", [132323]="ability_theblackarrow",
        [132325]="ability_thunderbolt", [132326]="ability_thunderclap", [132328]="ability_tracking",
        [132329]="ability_trueshot", [132330]="ability_upgrademoonglaive", [132331]="ability_vanish",
        [132332]="ability_warlock_avoidance", [132333]="ability_warrior_battleshout",
        [132336]="ability_warrior_challange", [132337]="ability_warrior_charge",
        [132338]="ability_warrior_cleave", [132340]="ability_warrior_decisivestrike",
        [132341]="ability_warrior_defensivestance", [132342]="ability_warrior_devastate",
        [132343]="ability_warrior_disarm", [132345]="ability_warrior_focusedrage",
        [132347]="ability_warrior_innerrage", [132349]="ability_warrior_offensivestance",
        [132350]="ability_warrior_punishingblow", [132351]="ability_warrior_rallyingcry",
        [132353]="ability_warrior_revenge", [132354]="ability_warrior_riposte",
        [132355]="ability_warrior_savageblow", [132357]="ability_warrior_shieldbash",
        [132361]="ability_warrior_shieldreflection", [132362]="ability_warrior_shieldwall",
        [132363]="ability_warrior_sunder", [132365]="ability_warrior_victoryrush",
        [132366]="ability_warrior_warcry", [132368]="ability_warstomp", [132369]="ability_whirlwind",
        [132386]="inv_ammo_firetar", [132388]="inv_armor_helm_plate_naxxramas_raidwarrior_c_01",
        [132443]="inv_axe_55", [132444]="inv_axe_56", [132452]="inv_axe_65", [132453]="inv_axe_66",
        [132599]="inv_box_petcarrier_01", [132728]="inv_chest_leather_13", [132938]="inv_gauntlets_04",
        [133282]="inv_jewelry_amulet_07", [133462]="inv_letter_06", [133642]="inv_misc_bag_10_green",
        [134131]="inv_misc_gem_sapphire_01", [134153]="inv_misc_head_dragon_01",
        [134206]="inv_misc_herb_felblossom", [134209]="inv_misc_herb_flamecap", [134228]="inv_misc_horn_02",
        [134296]="inv_misc_monsterclaw_03", [134400]="inv_misc_questionmark",
        [134914]="inv_relics_idolofrejuvenation", [134951]="inv_shield_05", [134952]="inv_shield_06",
        [135068]="inv_shoulder_37", [135125]="inv_spear_02", [135127]="inv_spear_04", [135130]="inv_spear_07",
        [135152]="inv_staff_15", [135230]="inv_stone_04", [135277]="inv_sword_07", [135291]="inv_sword_11",
        [135358]="inv_sword_48", [135372]="inv_sword_62", [135428]="inv_throwingknife_04",
        [135430]="inv_throwingknife_06", [135675]="inv_weapon_shortblade_40", [135728]="spell_arcane_arcane01",
        [135736]="spell_arcane_blink", [135739]="spell_arcane_massdispel", [135753]="spell_arcane_starfire",
        [135766]="spell_arcane_teleportundercity", [135770]="spell_deathknight_bloodpresence",
        [135771]="spell_deathknight_classicon", [135772]="spell_deathknight_deathstrike",
        [135773]="spell_deathknight_frostpresence", [135775]="spell_deathknight_unholypresence",
        [135789]="spell_fire_burnout", [135790]="spell_fire_elemental_totem", [135807]="spell_fire_fireball",
        [135808]="spell_fire_fireball02", [135810]="spell_fire_firebolt02", [135813]="spell_fire_flameshock",
        [135814]="spell_fire_flametounge", [135815]="spell_fire_flare", [135817]="spell_fire_immolation",
        [135818]="spell_fire_incinerate", [135824]="spell_fire_sealoffire", [135825]="spell_fire_searingtotem",
        [135826]="spell_fire_selfdestruct", [135827]="spell_fire_soulburn", [135829]="spell_fire_totemofwrath",
        [135832]="spell_fireresistancetotem_01", [135833]="spell_frost_arcticwinds",
        [135834]="spell_frost_chainsofice", [135837]="spell_frost_chillingbolt",
        [135840]="spell_frost_freezingbreath", [135845]="spell_frost_frostbolt",
        [135846]="spell_frost_frostbolt02", [135847]="spell_frost_frostbrand",
        [135849]="spell_frost_frostshock", [135860]="spell_frost_stun",
        [135861]="spell_frost_summonwaterelemental", [135863]="spell_frost_windwalkon",
        [135865]="spell_frost_wizardmark", [135866]="spell_frostresistancetotem_01",
        [135871]="spell_holy_ashestoashes", [135872]="spell_holy_auramastery",
        [135873]="spell_holy_auraoflight", [135874]="spell_holy_avengersshield",
        [135875]="spell_holy_avenginewrath", [135880]="spell_holy_blessingofprotection",
        [135883]="spell_holy_blindingheal", [135884]="spell_holy_championsbond",
        [135887]="spell_holy_circleofrenewal", [135890]="spell_holy_crusaderaura",
        [135891]="spell_holy_crusaderstrike", [135893]="spell_holy_devotionaura",
        [135894]="spell_holy_dispelmagic", [135895]="spell_holy_divineillumination",
        [135896]="spell_holy_divineintervention", [135898]="spell_holy_divinespirit",
        [135902]="spell_holy_excorcism", [135903]="spell_holy_excorcism_02",
        [135906]="spell_holy_fistofjustice", [135907]="spell_holy_flashheal",
        [135908]="spell_holy_greaterblessingofkings", [135912]="spell_holy_greaterblessingofwisdom",
        [135913]="spell_holy_greaterheal", [135915]="spell_holy_heal", [135917]="spell_holy_healingaura",
        [135920]="spell_holy_holybolt", [135922]="spell_holy_holynova", [135924]="spell_holy_holysmite",
        [135926]="spell_holy_innerfire", [135928]="spell_holy_layonhands", [135929]="spell_holy_lesserheal",
        [135932]="spell_holy_magicalsentry", [135933]="spell_holy_mindsooth", [135934]="spell_holy_mindvision",
        [135935]="spell_holy_nullifydisease", [135936]="spell_holy_painsupression",
        [135939]="spell_holy_powerinfusion", [135940]="spell_holy_powerwordshield",
        [135941]="spell_holy_prayeroffortitude", [135942]="spell_holy_prayerofhealing",
        [135943]="spell_holy_prayerofhealing02", [135944]="spell_holy_prayerofmendingtga",
        [135945]="spell_holy_prayerofshadowprotection", [135946]="spell_holy_prayerofspirit",
        [135949]="spell_holy_purify", [135952]="spell_holy_removecurse", [135953]="spell_holy_renew",
        [135954]="spell_holy_restoration", [135955]="spell_holy_resurrection",
        [135959]="spell_holy_righteousfury", [135960]="spell_holy_righteousnessaura",
        [135962]="spell_holy_sealoffury", [135963]="spell_holy_sealofmight",
        [135964]="spell_holy_sealofprotection", [135966]="spell_holy_sealofsacrifice",
        [135967]="spell_holy_sealofsalvation", [135968]="spell_holy_sealofvalor",
        [135969]="spell_holy_sealofvengeance", [135970]="spell_holy_sealofwisdom",
        [135971]="spell_holy_sealofwrath", [135972]="spell_holy_searinglight",
        [135974]="spell_holy_senseundead", [135978]="spell_holy_stoicism",
        [135980]="spell_holy_summonlightwell", [135982]="spell_holy_symbolofhope",
        [135983]="spell_holy_turnundead", [135984]="spell_holy_unyieldingfaith",
        [135987]="spell_holy_wordfortitude", [135988]="spell_ice_lament",
        [135993]="spell_magic_greaterblessingofkings", [135994]="spell_magic_lesserinvisibilty",
        [135995]="spell_magic_magearmor", [136006]="spell_nature_abolishmagic",
        [136009]="spell_nature_ancestralguardian", [136010]="spell_nature_astralrecal",
        [136012]="spell_nature_bloodlust", [136015]="spell_nature_chainlightning",
        [136018]="spell_nature_cyclone", [136019]="spell_nature_diseasecleansingtotem",
        [136020]="spell_nature_drowsy", [136022]="spell_nature_earthbind",
        [136023]="spell_nature_earthbindtotem", [136024]="spell_nature_earthelemental_totem",
        [136026]="spell_nature_earthshock", [136033]="spell_nature_faeriefire",
        [136034]="spell_nature_farsight", [136036]="spell_nature_forceofnature",
        [136038]="spell_nature_giftofthewild", [136039]="spell_nature_groundingtotem",
        [136040]="spell_nature_guardianward", [136041]="spell_nature_healingtouch",
        [136042]="spell_nature_healingwavegreater", [136043]="spell_nature_healingwavelesser",
        [136045]="spell_nature_insectswarm", [136048]="spell_nature_lightning",
        [136051]="spell_nature_lightningshield", [136052]="spell_nature_magicimmunity",
        [136053]="spell_nature_manaregentotem", [136061]="spell_nature_natureresistancetotem",
        [136063]="spell_nature_natureswrath", [136066]="spell_nature_nullifydisease",
        [136067]="spell_nature_nullifypoison", [136068]="spell_nature_nullifypoison_02",
        [136074]="spell_nature_protectionformnature", [136075]="spell_nature_purge",
        [136076]="spell_nature_ravenform", [136077]="spell_nature_regenerate",
        [136078]="spell_nature_regeneration", [136080]="spell_nature_reincarnation",
        [136081]="spell_nature_rejuvenation", [136082]="spell_nature_removecurse",
        [136085]="spell_nature_resistnature", [136086]="spell_nature_rockbiter",
        [136088]="spell_nature_shamanrage", [136089]="spell_nature_skinofearth", [136090]="spell_nature_sleep",
        [136091]="spell_nature_slow", [136092]="spell_nature_slowingtotem", [136095]="spell_nature_spiritwolf",
        [136096]="spell_nature_starfall", [136097]="spell_nature_stoneclawtotem",
        [136098]="spell_nature_stoneskintotem", [136100]="spell_nature_stranglevines",
        [136102]="spell_nature_strengthofearthtotem02", [136104]="spell_nature_thorns",
        [136105]="spell_nature_thunderclap", [136106]="spell_nature_timestop",
        [136107]="spell_nature_tranquility", [136108]="spell_nature_tremortotem",
        [136114]="spell_nature_windfury", [136115]="spell_nature_wispheal",
        [136118]="spell_shadow_abominationexplosion", [136119]="spell_shadow_animatedead",
        [136120]="spell_shadow_antimagicshell", [136121]="spell_shadow_antishadow",
        [136122]="spell_shadow_auraofdarkness", [136126]="spell_shadow_burningspirit",
        [136129]="spell_shadow_charm", [136130]="spell_shadow_chilltouch", [136135]="spell_shadow_cripple",
        [136136]="spell_shadow_curse", [136138]="spell_shadow_curseofmannoroth",
        [136139]="spell_shadow_curseofsargeras", [136140]="spell_shadow_curseoftounges",
        [136141]="spell_shadow_darkritual", [136142]="spell_shadow_darksummoning",
        [136143]="spell_shadow_deadofnight", [136144]="spell_shadow_deathanddecay",
        [136145]="spell_shadow_deathcoil", [136146]="spell_shadow_deathpact",
        [136147]="spell_shadow_deathscream", [136148]="spell_shadow_demonbreath",
        [136149]="spell_shadow_demonicfortitude", [136153]="spell_shadow_detectlesserinvisibility",
        [136154]="spell_shadow_enslavedemon", [136155]="spell_shadow_evileye",
        [136156]="spell_shadow_felarmour", [136160]="spell_shadow_gathershadows",
        [136162]="spell_shadow_grimward", [136163]="spell_shadow_haunting",
        [136164]="spell_shadow_impphaseshift", [136168]="spell_shadow_lifedrain",
        [136169]="spell_shadow_lifedrain02", [136170]="spell_shadow_manaburn",
        [136172]="spell_shadow_metamorphosis", [136175]="spell_shadow_mindsteal",
        [136177]="spell_shadow_nethercloak", [136181]="spell_shadow_painspike",
        [136182]="spell_shadow_plaguecloud", [136183]="spell_shadow_possession",
        [136184]="spell_shadow_psychicscream", [136185]="spell_shadow_ragingscream",
        [136186]="spell_shadow_rainoffire", [136187]="spell_shadow_raisedead",
        [136189]="spell_shadow_ritualofsacrifice", [136191]="spell_shadow_scourgebuild",
        [136192]="spell_shadow_sealofkings", [136193]="spell_shadow_seedofdestruction",
        [136194]="spell_shadow_shadesofdarkness", [136197]="spell_shadow_shadowbolt",
        [136199]="spell_shadow_shadowfiend", [136200]="spell_shadow_shadowform",
        [136201]="spell_shadow_shadowfury", [136205]="spell_shadow_shadowward",
        [136206]="spell_shadow_shadowworddominate", [136207]="spell_shadow_shadowwordpain",
        [136208]="spell_shadow_siphonmana", [136210]="spell_shadow_soulgem",
        [136213]="spell_shadow_soulleech_2", [136214]="spell_shadow_soulleech_3",
        [136216]="spell_shadow_summonfelguard", [136217]="spell_shadow_summonfelhunter",
        [136218]="spell_shadow_summonimp", [136219]="spell_shadow_summoninfernal",
        [136220]="spell_shadow_summonsuccubus", [136221]="spell_shadow_summonvoidwalker",
        [136223]="spell_shadow_twilight", [136224]="spell_shadow_unholyfrenzy",
        [136228]="spell_shadow_unstableaffliction_3", [136230]="spell_shadow_unsummonbuilding",
        [136231]="spell_shadow_vampiricaura", [236149]="ability_druid_berserk",
        [236153]="ability_druid_flourish", [236162]="ability_druid_nourish", [236167]="ability_druid_skinteeth",
        [236168]="ability_druid_starfall", [236169]="ability_druid_tigersroar",
        [236170]="ability_druid_typhoon", [236171]="ability_heroicleap", [236174]="ability_hunter_assassinate2",
        [236176]="ability_hunter_chimerashot2", [236178]="ability_hunter_explosiveshot",
        [236189]="ability_hunter_masterscall", [236247]="ability_paladin_beaconoflight",
        [236249]="ability_paladin_blessedmending", [236250]="ability_paladin_divinestorm",
        [236253]="ability_paladin_hammeroftherighteous", [236255]="ability_paladin_judgementblue",
        [236258]="ability_paladin_judgementred", [236265]="ability_paladin_shieldofvengeance",
        [236272]="ability_rogue_dismantle", [236273]="ability_rogue_fanofknives",
        [236276]="ability_rogue_hungerforblood", [236277]="ability_rogue_murderspree",
        [236279]="ability_rogue_shadowdance", [236283]="ability_rogue_tricksofthetrade",
        [236288]="ability_shaman_cleansespirit", [236289]="ability_shaman_lavalash",
        [236291]="ability_warlock_chaosbolt", [236292]="ability_warlock_demonicempowerment",
        [236298]="ability_warlock_haunt", [236302]="ability_warlock_shadowflame",
        [236303]="ability_warrior_bladestorm", [236312]="ability_warrior_shockwave",
        [236318]="ability_warrior_vigilance", [237510]="spell_deathknight_antimagiczone",
        [237511]="spell_deathknight_armyofthedead", [237512]="spell_deathknight_bladedarmor",
        [237513]="spell_deathknight_bloodboil", [237515]="spell_deathknight_bloodtap",
        [237517]="spell_deathknight_butcher2", [237518]="spell_deathknight_darkconviction",
        [237519]="spell_deathknight_empowerruneblade", [237520]="spell_deathknight_empowerruneblade2",
        [237525]="spell_deathknight_iceboundfortitude", [237526]="spell_deathknight_icetouch",
        [237527]="spell_deathknight_mindfreeze", [237528]="spell_deathknight_pathoffrost",
        [237529]="spell_deathknight_runetap", [237530]="spell_deathknight_scourgestrike",
        [237532]="spell_deathknight_strangulate", [237537]="spell_holy_aspiration",
        [237540]="spell_holy_divinehymn", [237542]="spell_holy_guardianspirit", [237545]="spell_holy_penance",
        [237558]="spell_shadow_demonform", [237559]="spell_shadow_demoniccirclesummon",
        [237560]="spell_shadow_demoniccircleteleport", [237563]="spell_shadow_dispersion",
        [237565]="spell_shadow_mindshear", [237568]="spell_shadow_psychichorrors",
        [237575]="spell_shaman_earthlivingweapon", [237577]="spell_shaman_feralspirit",
        [237579]="spell_shaman_hex", [237582]="spell_shaman_lavaburst", [237589]="spell_shaman_thunderstorm",
        [252995]="spell_nature_riptide", [252997]="spell_shadow_devouringplague",
        [253400]="spell_holy_powerwordbarrier", [310730]="spell_shaman_dropall_01",
        [310731]="spell_shaman_dropall_02", [310732]="spell_shaman_dropall_03",
        [310733]="spell_shaman_totemrecall", [311430]="ability_warrior_shatteringthrow",
        [538745]="warlock_ healthstone", [1357805]="sha_spell_fire_bluepyroblast_nightmare",
        [2115322]="inv_eng_unstabletemporaltimeshifter", [4352492]="ability_warlock_incubus",
    }
    local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

    -- spellID: when given, the spell's own icon is preferred (always present in the 3.3.5 files).
    function ns.Texture( tex, spellID, orNil )
        if type( tex ) ~= "number" then return tex end
        if spellID and type( spellID ) == "number" and spellID > 0 then
            local icon = select( 3, Real.GetSpellInfo( spellID ) )
            if icon then return icon end
        end
        local name = ICONS[ tex ]
        if name then return "Interface\\Icons\\" .. name end
        if orNil then return nil end
        return QUESTION
    end

    -- Does a texture path (3.3.5) show the same icon as a Classic file ID?
    function ns.SameTexture( tex, fileID )
        if tex == fileID then return true end
        if type( tex ) ~= "string" then return false end
        local name = ICONS[ fileID ]
        if not name then return false end
        local file = strlower( strmatch( tex, "([^\\/]+)$" ) or tex ):gsub( "%.blp$", "" )
        return file == strlower( name )
    end
end


---------------------------------------------------------------------------
-- NPC ID from a 3.3.5 GUID ("0xF130005C4F000123": creature entry in hex digits 7-10 after 0x).
---------------------------------------------------------------------------
function ns.NPCIDFromGUID( guid )
    if type( guid ) ~= "string" then return nil end
    local retail = strmatch( guid, "(%d+)-%x-$" )
    if retail then return tonumber( retail ) end
    local kind = strmatch( guid, "^0x(%x%x%x)" )
    if kind == "F13" or kind == "F15" or kind == "F11" then
        return tonumber( guid:sub( 9, 12 ), 16 )
    end
    return nil
end

-- The pet's creature ID. 3.3.5 pet GUIDs hold the pet number, not the creature ID,
-- so the pet family is used instead (English client names, as the game reports them).
do
    local FAMILY_NPC = {
        Imp = 416, Voidwalker = 1860, Felhunter = 417, Succubus = 1863, Felguard = 17252, Ghoul = 26125,
    }
    function ns.PetNPCID()
        local guid = UnitGUID( "pet" )
        if not guid then return nil end
        local id = ns.NPCIDFromGUID( guid )
        if id then return id end
        local family = UnitCreatureFamily( "pet" )
        return family and FAMILY_NPC[ family ] or nil
    end
end
