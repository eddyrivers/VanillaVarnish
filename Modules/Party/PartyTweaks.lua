local _, VV = ...
local addon = VV.Party
-- WoW Forever: decorate Blizzard's frames without replacing their artwork,
-- unit buttons, event handlers, or secure mixin methods.
local ICON_SIZE, ICON_GAP, BUFFS_PER_ROW, MAX_BUFFS = 14, 2, 8, 16
local PLAYER_ICON_SIZE, AURA_SCAN_LIMIT = ICON_SIZE + 5, 40
local ROW_STEP = PLAYER_ICON_SIZE + ICON_GAP
local ROW_HEIGHT = PLAYER_ICON_SIZE * 2 + ICON_GAP
local COMBAT_HEIGHT = ICON_SIZE * 2 + ICON_GAP
-- Blizzard's DebuffTypeColor values (FrameXML/BuffFrame.lua). Prefer the
-- client's table when present, including any accessibility customization.
local debuffColors = {
    Magic = {r=0.20, g=0.60, b=1.00}, Curse = {r=0.60, g=0.00, b=1.00},
    Disease = {r=0.60, g=0.40, b=0}, Poison = {r=0, g=0.60, b=0},
}
local states, lastError = {}, nil
local driver = CreateFrame("Frame")
local ready, elapsed, auraElapsed = false, 0, 0
local refreshQueued = false
local queueRefresh
local colorRecords = setmetatable({}, {__mode="k"})
local desaturationRecords = setmetatable({}, {__mode="k"})
local debuffHooks = setmetatable({}, {__mode="k"})
local partyLayouts = setmetatable({}, {__mode="k"})
local compactLayouts = setmetatable({}, {__mode="k"})
local assignedRoles, rosterRolesPending = {}, false
local colorHealth
local popupSuppressed, previousPopupSetting

local function feature(key)
    return VV.IsModuleEnabled("party") and VV.db.party[key]
end

local function updateBuffPopup()
    if feature("buffs") then
        if not popupSuppressed then
            previousPopupSetting = HIDE_PARTY_MEMBER_BUFF_TOOLTIP
            popupSuppressed = true
        end
        HIDE_PARTY_MEMBER_BUFF_TOOLTIP = true
        if PartyMemberBuffTooltip then PartyMemberBuffTooltip:Hide() end
    elseif popupSuppressed then
        HIDE_PARTY_MEMBER_BUFF_TOOLTIP = previousPopupSetting
        popupSuppressed = false
    end
end

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function readable(value)
    if not secret(value) then return value end
end

local function attempt(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then lastError = tostring(result) end
    return ok, result
end

local function visible(member)
    local ok, value = attempt(member.IsVisible, member)
    if ok then return readable(value) end
end

local function auraField(aura, key)
    local ok, value = attempt(function() return aura[key] end)
    if ok then return readable(value) end
end

local function raidStyle()
    local manager = _G.EditModeManagerFrame
    if manager and manager.UseRaidStylePartyFrames then
        local ok, value = attempt(manager.UseRaidStylePartyFrames, manager)
        if ok and readable(value) ~= nil then return readable(value) == true end
    end
    if GetCVarBool then
        local ok, value = attempt(GetCVarBool, "useCompactPartyFrames")
        if ok and readable(value) == true then return true end
    end
    local compact = _G.CompactPartyFrame
    return compact and visible(compact) == true or false
end

local function hideIcon(icon)
    if GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
    icon.unit, icon.auraID, icon.auraIndex = nil, nil, nil
    icon:Hide()
end

local function clearRow(state)
    for _, icon in ipairs(state.icons) do hideIcon(icon) end
    if state.nativeBuffs then
        attempt(state.nativeBuffs.SetEnabled, state.nativeBuffs, false)
        state.nativeBuffs:Hide()
        attempt(state.nativeBuffs.SetUnit, state.nativeBuffs, "none")
        state.nativeBuffUnit = nil
    end
    state.row:Hide()
end

local function tooltip(icon)
    if not icon.unit then return end
    GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
    local ok
    if icon.auraID and GameTooltip.SetUnitBuffByAuraInstanceID then
        ok = attempt(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, icon.unit, icon.auraID)
    elseif icon.auraIndex and GameTooltip.SetUnitBuff then
        ok = attempt(GameTooltip.SetUnitBuff, GameTooltip, icon.unit, icon.auraIndex, "HELPFUL")
    end
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

local function createState(member)
    local row = CreateFrame("Frame", nil, member)
    row:SetSize(BUFFS_PER_ROW * ROW_STEP - ICON_GAP, ROW_HEIGHT)
    row:SetFrameLevel(member:GetFrameLevel() + 5)
    row:Hide()
    local state = { member = member, row = row, icons = {}, baseHeight = member:GetHeight() }
    for index = 1, MAX_BUFFS do
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", ((index - 1) % BUFFS_PER_ROW) * (ICON_SIZE + ICON_GAP),
            -math.floor((index - 1) / BUFFS_PER_ROW) * ROW_STEP)
        icon.border = icon:CreateTexture(nil, "BACKGROUND")
        icon.border:SetAllPoints()
        icon.border:SetColorTexture(0.08, 0.08, 0.08, 1)
        icon.borderStyle, icon.borderInset = "plain", 1
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetPoint("TOPLEFT", 1, -1)
        icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints(icon.texture)
        icon.cooldown:SetReverse(true)
        icon.cooldown:SetDrawEdge(false)
        icon.cooldown:SetHideCountdownNumbers(true)
        local cover = CreateFrame("Frame", nil, icon)
        cover:SetAllPoints(icon)
        cover:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)
        icon.count = cover:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        icon.count:SetPoint("BOTTOMRIGHT", 1, -1)
        icon:EnableMouse(true)
        -- Hover tooltips work; targeting and click-casting pass through.
        icon:SetMouseClickEnabled(false)
        icon:SetScript("OnEnter", tooltip)
        icon:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        icon:Hide()
        state.icons[index] = icon
    end
    states[member] = state
    return state
end

local function memberUnit(member)
    local unit = readable(member.displayedUnit) or readable(member.overrideUnit) or readable(member.unit)
        or readable(member.unitToken)
    if type(unit) == "string" then return unit end
end

-- Fade textures and aura children, never the secure unit button or its bars.
-- Remember native alpha writes (including the low-health portrait pulse) so
-- disabling range fading restores the current native appearance.
local fades = setmetatable({}, {__mode = "k"})
local function applyFade(widget, factor)
    if not widget or not widget.SetAlpha or not widget.GetAlpha then return end
    local fade = fades[widget]
    if not fade then
        if factor == 1 then return end
        local ok, alpha = attempt(widget.GetAlpha, widget)
        if not ok then return end
        fade = {alpha=alpha, factor=1}
        fades[widget] = fade
        if hooksecurefunc then
            hooksecurefunc(widget, "SetAlpha", function(_, alpha)
                if fade.setting then return end
                fade.alpha = alpha
                local value = readable(alpha)
                if fade.factor < 1 and type(value) == "number" then
                    fade.setting = true
                    attempt(widget.SetAlpha, widget, value * fade.factor)
                    fade.setting = nil
                end
            end)
        end
    end
    fade.factor = factor
    local alpha = readable(fade.alpha)
    if factor < 1 and type(alpha) ~= "number" then return end
    fade.setting = true
    if factor == 1 then attempt(widget.SetAlpha, widget, fade.alpha)
    else attempt(widget.SetAlpha, widget, alpha * factor) end
    fade.setting = nil
end

local function restoreRange(state)
    for widget in pairs(state.rangeWidgets or {}) do applyFade(widget, 1) end
    state.rangeWidgets = nil
end

local function updateRange(state)
    local ns, config = VV.Nameplates, VV.db.nameplates
    local unit = memberUnit(state.member)
    if state.compact or raidStyle() or not state.active or visible(state.member) == false
        or not feature("rangeFade") or type(config.friendly) ~= "string" or config.friendly == "" or not unit or not ns.SpellInRange
        or ns.SpellInRange(config.friendly, unit) ~= false then
        restoreRange(state)
        return
    end
    local opacity = readable(config.rangeOpacity)
    if type(opacity) ~= "number" or opacity ~= opacity or opacity < 0 or opacity > 1 then opacity = 0.5 end
    local widgets = {}
    local function fade(widget)
        if widget then widgets[widget] = true; applyFade(widget, opacity) end
    end
    fade(state.member.Portrait or state.member.portrait)
    fade(state.row)
    local pool = state.member.AuraFramePool
    if pool and pool.EnumerateActive then
        for icon in pool:EnumerateActive() do
            if readable(icon.isBuff) == true then fade(icon) end
        end
    end
    for widget in pairs(state.rangeWidgets or {}) do
        if not widgets[widget] then applyFade(widget, 1) end
    end
    state.rangeWidgets = widgets
end

local function restoreColor(state)
    if not state.tint then return end
    if InCombatLockdown() then return end
    local tint = state.tint
    tint.setting = true
    local desaturation = tint.desaturation
    if tint.texture and desaturation then
        desaturation.setting = true
        attempt(tint.texture.SetDesaturated, tint.texture, unpack(desaturation.value))
        desaturation.setting = nil
    end
    if tint.color then attempt(tint.bar.SetStatusBarColor, tint.bar, unpack(tint.color)) end
    tint.setting = nil
    if tint.state == state then tint.state = nil end
    if desaturation and desaturation.tint == tint then desaturation.tint = nil end
    state.tint = nil
    -- Native UpdateMember also rebinds units and rewrites health update state.
    -- Never run that routine from a cosmetic toggle, even via securecallfunction.
    -- Normal Blizzard events handle pooled-unit and artwork changes.
end

local function restoreHeight(state)
    if not state.layoutApplied or InCombatLockdown() then return false end
    state.member:SetHeight(state.baseHeight)
    state.layoutApplied = false
    return true
end

local function reapplyColor(tint)
    local state = tint and tint.state
    if state and state.active and state.tint == tint and feature("classColors") then
        attempt(colorHealth, state)
    end
end

colorHealth = function(state)
    if not feature("classColors") then restoreColor(state); return end
    local member, unit = state.member, memberUnit(state.member)
    if not unit then return end
    local _, class = UnitClass(unit)
    class = readable(class)
    if type(class) ~= "string" then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local container = member.HealthBarContainer
    local bar = container and container.HealthBar or member.healthBar or member.healthbar or member.HealthBar
    if bar and color then
        -- Do not read/compare health, percentages, or Blizzard's secret colors.
        local texture = bar:GetStatusBarTexture()
        if state.tint and (state.tint.bar ~= bar or state.tint.texture ~= texture) then
            restoreColor(state)
            if state.tint then return end -- Restoration waits for combat to end.
        end
        if not state.tint then
            -- Store display values without comparisons/arithmetic. Widget
            -- setters can consume secret color channels when restoring them.
            local tint = colorRecords[bar]
            if not tint then
                tint = {bar=bar}
                colorRecords[bar] = tint
                hooksecurefunc(bar, "SetStatusBarColor", function(_, ...)
                    if tint.setting then return end
                    tint.color = {...}
                    -- Native health changes can reset this bar on any frame.
                    -- Correct the display before returning, not on a timer.
                    reapplyColor(tint)
                end)
            end
            tint.color = bar.GetStatusBarColor and {bar:GetStatusBarColor()} or nil
            tint.texture, tint.desaturation = texture, nil
            state.tint = tint
            -- A wrapper records presence without branching on a secret boolean.
            if texture and texture.IsDesaturated then
                local record = desaturationRecords[texture]
                if not record then
                    record = {}
                    desaturationRecords[texture] = record
                    hooksecurefunc(texture, "SetDesaturated", function(_, ...)
                        if record.setting then return end
                        record.value = {...}
                        reapplyColor(record.tint)
                    end)
                end
                record.value = {texture:IsDesaturated()}
                record.tint = tint
                tint.desaturation = record
            end
        end
        local tint = state.tint
        tint.state = state
        tint.setting = true
        if tint.desaturation then tint.desaturation.setting = true end
        if texture then attempt(texture.SetDesaturated, texture, true) end
        attempt(bar.SetStatusBarColor, bar, color.r, color.g, color.b)
        if tint.desaturation then tint.desaturation.setting = nil end
        tint.setting = nil
    end
end

local function setAura(icon, unit, aura, index, instanceID)
    icon.unit = unit
    icon.auraID = instanceID or auraField(aura, "auraInstanceID")
    icon.auraIndex = index
    -- Textures and widget setters can consume secret display values directly.
    icon.texture:SetTexture(aura.icon)
    attempt(icon.count.SetText, icon.count, "")
    local count = auraField(aura, "applications")
    if type(count) == "number" then
        if count > 1 then attempt(icon.count.SetText, icon.count, count) end
    elseif icon.auraID and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, display = attempt(C_UnitAuras.GetAuraApplicationDisplayCount, unit, icon.auraID, 2)
        if ok then attempt(icon.count.SetText, icon.count, display) end
    end
    -- A refused cosmetic setter must not discard the buff texture too.
    attempt(icon.cooldown.Clear, icon.cooldown)
    local duration, expiration = auraField(aura, "duration"), auraField(aura, "expirationTime")
    if type(duration) == "number" and type(expiration) == "number" then
        if duration > 0 then attempt(icon.cooldown.SetCooldown, icon.cooldown, expiration - duration, duration) end
    elseif icon.auraID and C_UnitAuras.GetAuraDuration and icon.cooldown.SetCooldownFromDurationObject then
        local ok, object = attempt(C_UnitAuras.GetAuraDuration, unit, icon.auraID)
        if ok then attempt(icon.cooldown.SetCooldownFromDurationObject, icon.cooldown, object, true) end
    end
    icon:Show()
    if GameTooltip:IsOwned(icon) then tooltip(icon) end
end

local restNames
local function spellName(id)
    local api = C_Spell and C_Spell.GetSpellName
    if api then
        local ok, name = attempt(api, id)
        if ok and type(readable(name)) == "string" then return readable(name) end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = attempt(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then
            local name = auraField(info, "name")
            if type(name) == "string" then return name end
        end
    end
    if GetSpellInfo then
        local ok, name = attempt(GetSpellInfo, id)
        if ok and type(readable(name)) == "string" then return readable(name) end
    end
end

local function resting(aura)
    -- Food and Drink ranks share their localized aura names. Match active
    -- recovery effects, never lasting Well Fed bonuses or arbitrary names
    -- containing "food". Unknown/restricted names retain normal priority.
    if not restNames then
        restNames = {Food="food", Drink="drink"}
        for _, entry in ipairs({{433, "food"}, {430, "drink"}}) do
            local name = spellName(entry[1])
            if name then restNames[name] = entry[2] end
        end
    end
    local name = auraField(aura, "name")
    if type(name) ~= "string" then
        local id = auraField(aura, "spellId")
        if type(id) == "number" then name = spellName(id) end
    end
    return type(name) == "string" and restNames[name] or nil
end

local function instanceBuffs(unit)
    if not C_UnitAuras.GetUnitAuraInstanceIDs or not C_UnitAuras.GetAuraDataByAuraInstanceID then return end
    -- The instance list is separate from GetUnitAuras' conditionally secret
    -- contents. Only public IDs are passed back to aura APIs from addon code.
    local ok, result = attempt(function()
        local ids = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL", AURA_SCAN_LIMIT)
        if type(ids) ~= "table" then return end
        local auras, instances = {}, {}
        for index = 1, AURA_SCAN_LIMIT do
            local id = ids[index]
            if secret(id) then return end
            if id == nil then break end
            if type(id) ~= "number" or id <= 0 then return end
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
            if type(aura) == "table" then
                auras[index], instances[index] = aura, id
            elseif secret(aura) then return end
            -- A removed aura can disappear between enumeration and lookup.
        end
        return {auras=auras, ids=instances}
    end)
    if ok then return result end
end

local function prepareNativeBuffs(state)
    if not state.nativeBuffs and not state.nativeBuffsAttempted and not InCombatLockdown()
        and VV.IsModuleEnabled("party") and addon.NativeBuffsAvailable and addon.NativeBuffsAvailable() then
        state.nativeBuffsAttempted = true
        state.nativeBuffs, state.nativeBuffsError = addon.CreateNativeBuffs(state.row)
    end
end

local function castByPlayer(unit, aura, instanceID)
    local source = auraField(aura, "sourceUnit")
    if source == "player" then return true end
    if type(source) == "string" and UnitIsUnit then
        local ok, same = attempt(UnitIsUnit, source, "player")
        if ok and type(readable(same)) == "boolean" then return same end
    end
    -- Some readable auras have no caster unit token. Use the caster's exact
    -- identity when available, even for spells another party member can cast.
    if InCombatLockdown() or not C_UnitAuras.GetAuraCasterGUID or not UnitGUID then return false end
    local id = instanceID or auraField(aura, "auraInstanceID")
    if type(id) ~= "number" or id <= 0 then return false end
    local ok, caster = pcall(C_UnitAuras.GetAuraCasterGUID, unit, id)
    caster = ok and readable(caster)
    if type(caster) ~= "string" or caster == "" then return false end
    local playerOK, player = pcall(UnitGUID, "player")
    return playerOK and caster == readable(player)
end

local function styleBuffBorder(icon, own, drinking, pixel)
    local style = drinking and "drink" or own and "gold" or "plain"
    if icon.borderStyle ~= style then
        if drinking then icon.border:SetColorTexture(0.5, 0.9, 1, 1)
        elseif own then icon.border:SetColorTexture(1, 0.82, 0.25, 1)
        else icon.border:SetColorTexture(0.08, 0.08, 0.08, 1) end
        icon.borderStyle = style
    end
    local inset = (own or drinking) and pixel or 1
    if icon.borderInset ~= inset then
        icon.texture:ClearAllPoints()
        icon.texture:SetPoint("TOPLEFT", inset, -inset)
        icon.texture:SetPoint("BOTTOMRIGHT", -inset, inset)
        icon.borderInset = inset
    end
end

local function updateBuffs(state)
    state.buffCount, state.buffSource, state.buffReadFailed, state.buffHeight = 0, nil, false, 0
    if not feature("buffs") then state.buffStatus = "buffs disabled"; clearRow(state); return end
    if state.compact or raidStyle() then state.buffStatus = "raid-style party frames"; clearRow(state); return end
    local unit = memberUnit(state.member)
    if not state.active or visible(state.member) == false or not unit then
        state.buffStatus = not state.active and "inactive frame" or not unit and "no readable unit" or "hidden frame"
        clearRow(state)
        return
    end
    -- An unknown/restricted existence result cannot be used as a Lua condition.
    -- The aura APIs can still supply permitted display data for this unit token.
    if readable(UnitExists(unit)) == false then state.buffStatus = "unit unavailable"; clearRow(state); return end
    prepareNativeBuffs(state)
    if state.nativeBuffs then
        local container = state.nativeBuffs
        local ok = attempt(function()
            if state.nativeBuffUnit ~= unit then
                container:SetUnit(unit)
                state.nativeBuffUnit = unit
            end
            if InCombatLockdown() then
                for _, icon in ipairs(state.icons) do hideIcon(icon) end
                state.row:Show()
                container:Show()
                container:SetEnabled(true)
            else
                container:SetEnabled(false)
                container:Hide()
            end
        end)
        if InCombatLockdown() then
            state.buffSource = "native container"
            state.buffStatus = ok and "native combat buffs (up to 16)" or "native combat display refused"
            if not ok then clearRow(state) end
            return
        end
    end
    if not C_UnitAuras then state.buffStatus = "aura APIs unavailable"; clearRow(state); return end
    local list, indexed, instances
    local byInstance = instanceBuffs(unit)
    if byInstance then
        list, instances = byInstance.auras, byInstance.ids
        state.buffSource = "instances"
    end
    -- The list API exposes buffs in Forever even when the index API refuses.
    if not list and C_UnitAuras.GetUnitAuras then
        local ok, result = attempt(C_UnitAuras.GetUnitAuras, unit, "HELPFUL", AURA_SCAN_LIMIT)
        if ok and type(result) == "table" then
            -- The list can contain secret AuraData references. Attempt numeric
            -- indexing without comparing those references; if indexing itself
            -- is refused, use the independent indexed API below.
            local copied, values = attempt(function()
                local values = {}
                for index = 1, AURA_SCAN_LIMIT do values[index] = result[index] end
                return values
            end)
            if copied then list = values; state.buffSource = "list" end
        end
    end
    if not list and C_UnitAuras.GetAuraDataByIndex then
        list, indexed = {}, true
        state.buffSource = "index"
        for index = 1, AURA_SCAN_LIMIT do
            local ok, aura = attempt(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
            if not ok then state.buffReadFailed = true; break end
            if type(aura) ~= "table" then break end
            list[#list + 1] = aura
        end
    end
    if not list then state.buffStatus = "aura read unavailable/refused"; clearRow(state); return end
    -- Stable priority groups are built before applying the display limit:
    -- active food/drink, the player's buffs, then other buffs in native order.
    local recovery, ownBuffs, others = {}, {}, {}
    for index = 1, AURA_SCAN_LIMIT do
        local aura = list[index]
        if type(aura) == "table" then
            local instanceID = instances and instances[index]
            local own = castByPlayer(unit, aura, instanceID)
            local entry = {aura=aura, index=index, own=own, instanceID=instanceID, recovery=resting(aura)}
            local destination = entry.recovery and recovery or own and ownBuffs or others
            destination[#destination + 1] = entry
        end
    end
    local ordered = recovery
    for _, entry in ipairs(ownBuffs) do ordered[#ordered + 1] = entry end
    for _, entry in ipairs(others) do ordered[#ordered + 1] = entry end
    local rowHeights = {0, 0}
    for index = 1, MAX_BUFFS do
        local entry = ordered[index]
        if entry then
            entry.size = (entry.own or entry.recovery == "drink") and PLAYER_ICON_SIZE or ICON_SIZE
            local row = math.floor((index - 1) / BUFFS_PER_ROW) + 1
            rowHeights[row] = math.max(rowHeights[row], entry.size)
        end
    end
    state.buffHeight = rowHeights[1] + (rowHeights[2] > 0 and ICON_GAP + rowHeights[2] or 0)
    local received = 0
    local x = 0
    local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
        and PixelUtil.GetPixelToUIUnitFactor() / state.row:GetEffectiveScale() or 1
    for index, icon in ipairs(state.icons) do
        local entry = ordered[index]
        local aura = entry and entry.aura
        -- AuraData records may themselves be secret references in combat.
        -- Do not compare or filter them: attempt permitted field-to-widget
        -- display, retaining the guards on secret counts, IDs, and durations.
        if type(aura) == "table" then
            if (index - 1) % BUFFS_PER_ROW == 0 then x = 0 end
            received = received + 1
            local drinking = entry.recovery == "drink"
            local size = entry.size
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", state.row, "TOPLEFT", x, index > BUFFS_PER_ROW and -(rowHeights[1] + ICON_GAP) or 0)
            x = x + size + ICON_GAP
            if attempt(setAura, icon, unit, aura, indexed and entry.index or nil, entry.instanceID) then
                styleBuffBorder(icon, entry.own, drinking, pixel)
                state.buffCount = state.buffCount + 1
            else hideIcon(icon) end
        else
            hideIcon(icon)
        end
    end
    state.buffStatus = received == 0 and (state.buffReadFailed and "aura read refused" or "no buffs returned")
        or state.buffCount == 0 and "buff rendering refused"
        or (state.buffCount .. " buff icons displayed")
    state.row:Show()
end

local function layoutRow(state)
    if state.compact or raidStyle() or not feature("buffs") then return restoreHeight(state) end
    if InCombatLockdown() then return false end
    local member = state.member
    if not state.layoutApplied then state.baseHeight = member:GetHeight() end
    -- Follow the native bars: align horizontally with health, seven pixels
    -- below mana. Convert the left edges to the row's scale before comparing.
    state.row:ClearAllPoints()
    local container = member.HealthBarContainer
    local health = container and container.HealthBar or member.healthBar or member.healthbar or member.HealthBar
    local mana = member.ManaBar or member.manabar
    if health and mana then
        local healthLeft, manaLeft = readable(health:GetLeft()), readable(mana:GetLeft())
        local offset = 4
        if type(healthLeft) == "number" and type(manaLeft) == "number" then
            offset = (healthLeft * health:GetEffectiveScale() - manaLeft * mana:GetEffectiveScale())
                / state.row:GetEffectiveScale()
        end
        state.row:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", offset, -7)
    elseif health then
        state.row:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -7)
    else
        state.row:SetPoint("TOPLEFT", member, "TOPLEFT", 7, -(state.baseHeight + 2))
    end
    -- Keep room for all sixteen standard-size native combat buffs without
    -- reserving two enlarged rows when only a few personal buffs are present.
    -- Without a native container, the fallback can still show enlarged buffs
    -- during combat and needs the full reservation.
    local buffHeight = math.max(state.nativeBuffs and COMBAT_HEIGHT or ROW_HEIGHT, state.buffHeight or 0)
    if state.row:GetHeight() ~= buffHeight then state.row:SetHeight(buffHeight) end
    local height = state.baseHeight + buffHeight + 2
    if member.GetTop and state.row.GetTop then
        local top, rowTop = readable(member:GetTop()), readable(state.row:GetTop())
        local scale, rowScale = member:GetEffectiveScale(), state.row:GetEffectiveScale()
        if type(top) == "number" and type(rowTop) == "number" and scale > 0 then
            height = math.max(state.baseHeight, top - rowTop * rowScale / scale + buffHeight * rowScale / scale + 2)
        end
    end
    local changed = member:GetHeight() ~= height
    if changed then member:SetHeight(height) end
    state.layoutApplied = true
    return changed
end

local function points(frame)
    local result = {}
    for index = 1, frame:GetNumPoints() do result[index] = {frame:GetPoint(index)} end
    return result
end

local function samePoints(a, b)
    if #a ~= #b then return false end
    for index, point in ipairs(a) do
        for field = 1, 5 do if point[field] ~= b[index][field] then return false end end
    end
    return true
end

local function setPoints(frame, value)
    frame:ClearAllPoints()
    for _, point in ipairs(value) do frame:SetPoint(unpack(point, 1, 5)) end
end

local function growthAnchorHeight(party, anchor, height)
    local point, relative, relativePoint, x, y = unpack(anchor, 1, 5)
    local name = type(relative) == "string" and relative or relative and relative.GetName and relative:GetName()
    if not name or type(point) ~= "string" or type(relativePoint) ~= "string"
        or type(readable(x)) ~= "number" or type(readable(y)) ~= "number" then return height end
    -- Edit Mode saves offsets at scale 1 and reloads them rounded to tenths.
    -- Match in that coordinate space so rounding does not change the baseline.
    local scale = party.GetScale and party:GetScale() or 1
    x, y = x * scale, y * scale
    local key = ("%s:%s:%s"):format(point, name, relativePoint)
    local saved = VV.db.partyGrowthAnchor
    if type(saved) == "table" and type(saved.key) == "string"
        and type(saved.height) == "number" and saved.height >= 0 and saved.height < math.huge then
        local savedX, savedY
        if saved.key == key then
            savedX, savedY = saved.x, saved.y
        elseif saved.key:sub(1, #key + 1) == key .. ":" then
            -- Older records put the unscaled offsets in the key.
            local oldX, oldY = saved.key:sub(#key + 2):match("^(-?%d+%.%d+):(-?%d+%.%d+)$")
            if oldX then savedX, savedY = tonumber(oldX) * scale, tonumber(oldY) * scale end
        end
        if type(savedX) == "number" and type(savedY) == "number"
            and math.abs(savedX - x) <= 0.051 and math.abs(savedY - y) <= 0.051 then
            if saved.key == key then return saved.height end
            height = saved.height
        end
    end
    -- This is a character's Edit Mode position, separate from shared profiles.
    VV.db.partyGrowthAnchor = {key = key, x = x, y = y, height = height}
    return height
end

local function partyIsDragging(party)
    return party and party.IsEditModeDragging and party:IsEditModeDragging()
end

local function memberGUID(unit)
    if unit and UnitGUID then
        local ok, value = attempt(UnitGUID, unit)
        value = ok and readable(value)
        if type(value) == "string" and value ~= "" then return value end
    end
end

local function pruneAssignedRoles()
    if not rosterRolesPending or InCombatLockdown() then return end
    rosterRolesPending = false
    local current = {}
    for index = 0, 4 do
        local guid = memberGUID(index == 0 and "player" or "party" .. index)
        if guid then current[guid] = assignedRoles[guid] end
    end
    assignedRoles = current
end

local function memberRole(unit)
    if not unit then return end
    local role
    -- Match the native assigned-role icon before consulting the string API.
    if UnitGroupRolesAssignedEnum and Enum and Enum.LFGRole then
        local ok, value = attempt(UnitGroupRolesAssignedEnum, unit)
        value = ok and readable(value)
        if value ~= nil then
            role = value == Enum.LFGRole.Tank and "TANK" or value == Enum.LFGRole.Healer and "HEALER"
                or value == Enum.LFGRole.Damage and "DAMAGER" or nil
        end
    end
    if not role and UnitGroupRolesAssigned then
        local ok, value = attempt(UnitGroupRolesAssigned, unit)
        value = ok and readable(value)
        if value == "TANK" or value == "HEALER" or value == "DAMAGER" then role = value end
    end
    -- Zoning can temporarily hide a role. Remember only verified identities,
    -- never a frame or party slot that may now belong to somebody else.
    local guid = memberGUID(unit)
    if guid and role then assignedRoles[guid] = role end
    return role or guid and assignedRoles[guid] or nil
end

local function arrangeCompactParty(party, nativeLayout)
    party = party or _G.CompactPartyFrame
    if not party then return end
    pruneAssignedRoles()
    if nativeLayout and compactLayouts[party] then compactLayouts[party].native = nil end
    if InCombatLockdown() or partyIsDragging(_G.PartyFrame)
        or not party.memberUnitFrames or type(party.updateLayoutFunc) ~= "function" then return end
    local layout = compactLayouts[party]
    if not layout then
        layout = {}
        compactLayouts[party] = layout
        -- Never replace flowSortFunc or call native unit setup/refresh methods:
        -- addon execution there taints subsequent restricted health updates.
        -- This alias is the entry point used by native member and border layouts.
        hooksecurefunc(party, "updateLayoutFunc", function(self) arrangeCompactParty(self, true) end)
    end
    local mode = VV.db.party.rolePin
    local enabled = VV.IsModuleEnabled("party") and raidStyle() and (mode == "top" or mode == "bottom")
    if not enabled and not layout.applied then layout.native = nil; return end
    local frames, members = {}, {}
    for _, member in ipairs(party.memberUnitFrames) do
        frames[#frames + 1] = member
        if readable(member:IsShown()) == true then members[#members + 1] = member end
    end
    for _, pet in ipairs(party.petUnitFrames or {}) do frames[#frames + 1] = pet end
    if party.borderFrame then frames[#frames + 1] = party.borderFrame end
    if nativeLayout or not layout.native then
        layout.native = {}
        for _, frame in ipairs(frames) do layout.native[frame] = points(frame) end
    end
    local mapping = {}
    if enabled then
        local tanks, healers, others = {}, {}, {}
        for _, member in ipairs(members) do
            local role = memberRole(memberUnit(member))
            local group = role == "TANK" and tanks or role == "HEALER" and healers or others
            group[#group + 1] = member
        end
        local ordered = {}
        local groups = mode == "top" and {tanks, healers, others} or {others, tanks, healers}
        for _, group in ipairs(groups) do for _, member in ipairs(group) do ordered[#ordered + 1] = member end end
        for index, member in ipairs(members) do mapping[member] = ordered[index] end
    end
    local desired, changed = {}, false
    for _, frame in ipairs(frames) do
        local target, anchors = mapping[frame] or frame, {}
        for index, point in ipairs(layout.native[frame] or {}) do
            local relative = type(point[2]) == "string" and _G[point[2]] or point[2]
            anchors[index] = {point[1], mapping[relative] or point[2], point[3], point[4], point[5]}
        end
        desired[target] = anchors
        if not samePoints(points(target), anchors) then changed = true end
    end
    if changed then
        -- Clear the whole anchor graph before reconnecting it, preventing
        -- temporary cycles when swapping frames in Blizzard's chained layout.
        for _, frame in ipairs(frames) do frame:ClearAllPoints() end
        for _, frame in ipairs(frames) do
            for _, point in ipairs(desired[frame]) do frame:SetPoint(unpack(point, 1, 5)) end
        end
    end
    layout.applied = enabled
end

local function arrangeParty(party, nativeLayout)
    if InCombatLockdown() or not party.GetNumPoints or partyIsDragging(party) then return end
    pruneAssignedRoles()
    local layout = partyLayouts[party]
    if not layout then return end
    if party.IsInitialized and not party:IsInitialized() then return end
    local manager = _G.EditModeManagerFrame
    local editing = manager and manager.IsEditModeActive and manager:IsEditModeActive()
    local enabled = VV.IsModuleEnabled("party") and not raidStyle()
    if not enabled and not layout.applied then return end
    local members = {}
    for member in party.PartyMemberFramePool:EnumerateActive() do
        local index = readable(member.layoutIndex)
        if type(index) == "number" and readable(member:IsShown()) == true then members[#members + 1] = member end
    end
    table.sort(members, function(a, b) return a.layoutIndex < b.layoutIndex end)
    local current = points(party)
    -- Edit Mode can move the container after our last arrangement. Keep that
    -- new position as the restore point instead of snapping to an old layout.
    if not layout.anchor or not layout.appliedAnchor or not samePoints(current, layout.appliedAnchor) then
        layout.anchor, layout.anchorHeight = current, party:GetHeight()
    end
    if nativeLayout or not layout.height or not layout.applied then
        layout.height = party:GetHeight()
        layout.members = {}
        for _, member in ipairs(members) do layout.members[member] = points(member) end
    end
    if not enabled then
        for _, member in ipairs(members) do
            if layout.members[member] then setPoints(member, layout.members[member]) end
        end
        party:SetHeight(layout.height)
        if layout.appliedAnchor and not editing then setPoints(party, layout.anchor) end
        layout.appliedAnchor = nil
        if layout.background and party.Background then setPoints(party.Background, layout.background) end
        layout.applied = false
        return
    end
    local config = VV.db.party
    if config.rolePin == "top" or config.rolePin == "bottom" then
        -- Build physical top-to-bottom order, then convert back to the growth
        -- direction. Secure unit bindings and native layout indices stay put.
        local tanks, healers, others = {}, {}, {}
        for position = 1, #members do
            local member = members[config.growUp and #members + 1 - position or position]
            local role = memberRole(memberUnit(member))
            local group = role == "TANK" and tanks or role == "HEALER" and healers or others
            group[#group + 1] = member
        end
        local ordered = {}
        local groups = config.rolePin == "top" and {tanks, healers, others} or {others, tanks, healers}
        for _, group in ipairs(groups) do for _, member in ipairs(group) do ordered[#ordered + 1] = member end end
        for index = 1, #members do members[index] = ordered[config.growUp and #ordered + 1 - index or index] end
    end
    local gap = config.spacing or 4
    local top, bottom = party.topPadding or 0, party.bottomPadding or 0
    local left, height = party.leftPadding or 0, top + bottom
    for index, member in ipairs(members) do
        if index > 1 then height = height + gap end
        height = height + member:GetHeight()
        -- Native pets extend below the original portrait frame when extra
        -- buffs are disabled. Preserve that clearance without a blanket gap.
        if not feature("buffs") and member.PetFrame and readable(member.PetFrame:IsShown()) == true then height = height + 16 end
    end
    local anchor = layout.anchor[1]
    if not editing and config.growUp and #members > 0 and anchor and #layout.anchor == 1 then
        local point, relative, relativePoint, x, y = unpack(anchor, 1, 5)
        if type(point) == "string" and type(readable(y)) == "number" then
            local factor = point:find("TOP", 1, true) and 1 or point:find("BOTTOM", 1, true) and 0 or 0.5
            local bottomPoint = point:find("RIGHT", 1, true) and "BOTTOMRIGHT"
                or point:find("LEFT", 1, true) and "BOTTOMLEFT" or "BOTTOM"
            local referenceHeight = growthAnchorHeight(party, anchor, layout.anchorHeight)
            local grown = {{bottomPoint, relative, relativePoint, x, y - referenceHeight * factor}}
            if not samePoints(current, grown) then
                setPoints(party, grown)
                current = points(party)
            end
            layout.appliedAnchor = current
        end
    elseif not editing and not config.growUp and layout.appliedAnchor then
        setPoints(party, layout.anchor)
        layout.appliedAnchor = nil
    end
    height = math.max(1, height)
    if party:GetHeight() ~= height then party:SetHeight(height) end
    local offset = config.growUp and bottom or top
    for _, member in ipairs(members) do
        local petHeight = not feature("buffs") and member.PetFrame and readable(member.PetFrame:IsShown()) == true and 16 or 0
        member:ClearAllPoints()
        if config.growUp then
            member:SetPoint("BOTTOMLEFT", party, "BOTTOMLEFT", left, offset + petHeight)
        else
            member:SetPoint("TOPLEFT", party, "TOPLEFT", left, -offset)
        end
        offset = offset + member:GetHeight() + petHeight + gap
    end
    if party.Background then
        if not layout.background then layout.background = points(party.Background) end
        party.Background:ClearAllPoints()
        party.Background:SetPoint("TOPLEFT", party, "TOPLEFT", -5, 6)
        party.Background:SetPoint("BOTTOMLEFT", party, "BOTTOMLEFT", -5, -5)
    end
    layout.applied = true
end

local function installPartyLayout()
    local party = _G.PartyFrame
    if not party or not party.PartyMemberFramePool or not party.GetNumPoints
        or type(party.Layout) ~= "function" or partyLayouts[party] then return end
    partyLayouts[party] = {}
    hooksecurefunc(party, "Layout", function(self) arrangeParty(self, true) end)
    if party.OnDragStop then hooksecurefunc(party, "OnDragStop", queueRefresh) end
    if party.UpdatePartyMemberBackground then
        hooksecurefunc(party, "UpdatePartyMemberBackground", function(self)
            local layout = partyLayouts[self]
            if not InCombatLockdown() and self.Background then
                layout.background = points(self.Background)
                arrangeParty(self, false)
            end
        end)
    end
end

local function restoreDebuffs(state)
    if not state.debuffStyles or InCombatLockdown() then return end
    for icon, original in pairs(state.debuffStyles) do
        attempt(function()
            icon:SetSize(original.width, original.height)
            icon:ClearAllPoints()
            for _, point in ipairs(original.points) do icon:SetPoint(unpack(point)) end
            if original.color then icon.DebuffBorder:SetVertexColor(unpack(original.color)) end
        end)
    end
    state.debuffStyles = nil
end

local function updateDebuffs(state)
    local member = state.member
    if state.compact or raidStyle() or not state.active or visible(member) == false or not feature("buffs") then
        restoreDebuffs(state)
        return
    end
    -- Debuff geometry already waits for combat to end. Do not query the
    -- restricted aura reader when no decoration can be applied anyway.
    if InCombatLockdown() then return end
    local unit, pool = memberUnit(member), member.AuraFramePool
    if not unit or not pool or not pool.EnumerateActive or not C_UnitAuras then return end
    -- RAID is the client's capability filter for harmful auras the player can
    -- dispel; this follows learned spells rather than guessing from class.
    local dispellable = {}
    if C_UnitAuras.GetUnitAuras then
        local ok, list = attempt(C_UnitAuras.GetUnitAuras, unit, "HARMFUL|RAID", AURA_SCAN_LIMIT)
        if ok and type(list) == "table" then
            for index = 1, AURA_SCAN_LIMIT do
                local read, aura = attempt(function() return list[index] end)
                if read and type(aura) == "table" then
                    local id = auraField(aura, "auraInstanceID")
                    if type(id) == "number" then dispellable[id] = auraField(aura, "dispelName") end
                end
            end
        end
    end
    local icons, any = {}, false
    for icon in pool:EnumerateActive() do
        -- Native portrait frames can leave showBuffs/isBuff nil for debuffs.
        -- A restricted flag is still unknown and must not be interpreted.
        if not secret(icon.isBuff) and readable(icon.isBuff) ~= true and visible(icon) ~= false then
            local id = readable(icon.auraInstanceID)
            local kind = type(id) == "number" and dispellable[id] or nil
            local color = kind and ((DebuffTypeColor and DebuffTypeColor[kind]) or debuffColors[kind])
            local order = readable(icon.layoutIndex)
            icons[#icons + 1] = {icon=icon, color=color, order=type(order) == "number" and order or #icons + 1}
            any = any or color ~= nil
        end
    end
    if not any then restoreDebuffs(state); return end
    table.sort(icons, function(a, b) return a.order < b.order end)
    state.debuffStyles = state.debuffStyles or {}
    local previous
    for _, entry in ipairs(icons) do
        local icon, color = entry.icon, entry.color
        -- These are native aura children, not secure unit buttons. Do not
        -- replace Setup/UpdateMember or invoke native container layout code.
        attempt(function()
            local original = state.debuffStyles[icon]
            if not original then
                local width, height = readable(icon:GetWidth()), readable(icon:GetHeight())
                if type(width) ~= "number" or type(height) ~= "number" then return end
                original = {width=width, height=height, points={}}
                for index = 1, icon:GetNumPoints() do original.points[index] = {icon:GetPoint(index)} end
                if icon.DebuffBorder and icon.DebuffBorder.GetVertexColor then
                    original.color = {icon.DebuffBorder:GetVertexColor()}
                end
                state.debuffStyles[icon] = original
                if not debuffHooks[icon] then
                    debuffHooks[icon] = true
                    icon:HookScript("OnHide", function()
                        local saved = state.debuffStyles and state.debuffStyles[icon]
                        if not saved then return end
                        -- OnHide also runs when the parent disappears. Restore
                        -- the entire decoration here; the pool's resetter then
                        -- clears anchors before another aura acquires the frame.
                        attempt(icon.SetSize, icon, saved.width, saved.height)
                        attempt(function()
                            icon:ClearAllPoints()
                            for _, point in ipairs(saved.points) do icon:SetPoint(unpack(point)) end
                        end)
                        if saved.color and icon.DebuffBorder then
                            attempt(icon.DebuffBorder.SetVertexColor, icon.DebuffBorder, unpack(saved.color))
                        end
                        state.debuffStyles[icon] = nil
                    end)
                end
            end
            icon:SetSize(original.width * (color and 2 or 1), original.height * (color and 2 or 1))
            if previous then
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", previous, "TOPRIGHT", ICON_GAP, 0)
            end
            if icon.DebuffBorder then
                if color then icon.DebuffBorder:SetVertexColor(color.r, color.g, color.b, 1)
                elseif original.color then icon.DebuffBorder:SetVertexColor(unpack(original.color)) end
            end
        end)
        previous = icon
    end
end

local function visitMembers(callback)
    local party = _G.PartyFrame
    if party and party.PartyMemberFramePool then
        for member in party.PartyMemberFramePool:EnumerateActive() do callback(member) end
    else
        for index = 1, 4 do
            local member = _G["PartyMemberFrame" .. index]
            if member then callback(member) end
        end
    end
    local compact = _G.CompactPartyFrame
    if compact and compact.memberUnitFrames then
        for _, member in ipairs(compact.memberUnitFrames) do callback(member, true) end
    else
        for index = 1, 5 do
            local member = _G["CompactPartyFrameMember" .. index]
            if member then callback(member, true) end
        end
    end
end

local function refresh()
    updateBuffPopup()
    -- Resizing the moving frame or relaying out its children can shift the
    -- point Blizzard is dragging, even with Edit Mode snapping disabled.
    if partyIsDragging(_G.PartyFrame) then return end
    local layoutChanged = false
    for _, state in pairs(states) do state.active = false end
    visitMembers(function(member, compact)
        local state = states[member]
        if not state and VV.IsModuleEnabled("party") then
            if compact then
                state = {member=member, compact=true, buffStatus="raid-style party frames; native auras"}
                states[member] = state
            elseif not InCombatLockdown() then state = createState(member) end
        end
        if state then
            state.active = true
            if not compact then prepareNativeBuffs(state) end
            colorHealth(state)
            if not compact then
                updateBuffs(state)
                if layoutRow(state) then layoutChanged = true end
                updateDebuffs(state)
            end
            updateRange(state)
        end
    end)
    for _, state in pairs(states) do
        if not state.active then
            if state.row then clearRow(state) end
            if restoreHeight(state) then layoutChanged = true end
            restoreColor(state)
            restoreDebuffs(state)
            restoreRange(state)
        end
    end
    installPartyLayout()
    if layoutChanged and _G.PartyFrame and _G.PartyFrame.Layout then
        attempt(_G.PartyFrame.Layout, _G.PartyFrame)
    elseif _G.PartyFrame then
        arrangeParty(_G.PartyFrame, false)
    end
    arrangeCompactParty()
end

queueRefresh = function()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        refresh()
    end)
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
        if InCombatLockdown() or not ready or not VV.IsModuleEnabled("party") or not VV.db.party.growUp or raidStyle() then return end
        local party = _G.PartyFrame
        local layout = party and partyLayouts[party]
        if not layout then return end
        local current = points(party)
        if #current == 1 and (not layout.appliedAnchor or not samePoints(current, layout.appliedAnchor)) then
            growthAnchorHeight(party, current[1], party:GetHeight())
        end
    end, addon)
    EventRegistry:RegisterCallback("EditMode.Exit", queueRefresh, addon)
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "UNIT_AURA", "UNIT_CONNECTION", "UNIT_PET", "CVAR_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then ready = true end
    if not ready then return end
    if event == "GROUP_ROSTER_UPDATE" then rosterRolesPending = true end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        for _, state in pairs(states) do if state.row then updateBuffs(state) end end
        queueRefresh()
    elseif event == "UNIT_AURA" then
        if not feature("buffs") or partyIsDragging(_G.PartyFrame) then return end
        if secret(unit) then
            -- Refresh known units without inspecting the restricted event token.
            for _, state in pairs(states) do if state.row then updateBuffs(state); updateDebuffs(state); updateRange(state) end end
            queueRefresh()
            return
        end
        local relevant = false
        for _, state in pairs(states) do
            if state.row and memberUnit(state.member) == unit then
                relevant = true
                updateBuffs(state); updateDebuffs(state); updateRange(state)
            end
        end
        if relevant then queueRefresh() end
    else
        -- Run after Blizzard has processed this event and assigned pooled units.
        queueRefresh()
    end
end)
driver:SetScript("OnUpdate", function(_, delta)
    if not ready or not VV.IsModuleEnabled("party") then return end
    elapsed, auraElapsed = elapsed + delta, auraElapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    -- No assignments to Blizzard's secure methods/mixins. Reapply
    -- class colors after native health updates and discover newly pooled frames.
    if auraElapsed >= 1 then
        auraElapsed = 0
        refresh()
    else
        for _, state in pairs(states) do
            if state.active then
                if visible(state.member) ~= false then colorHealth(state) end
                updateRange(state)
            end
        end
    end
end)

local function Status()
    local count, pending = 0, 0
    visitMembers(function(member)
        if not states[member] and visible(member) ~= false then pending = pending + 1 end
    end)
    for _, state in pairs(states) do
        if state.active and visible(state.member) ~= false then count = count + 1 end
    end
    VV.Print(count .. " default party frames; up to " .. MAX_BUFFS .. " buffs per member.")
    print("Party module: " .. (VV.IsModuleEnabled("party") and "on" or "off")
        .. "; buffs: " .. (VV.db.party.buffs and "on" or "off")
        .. "; range fading: " .. (VV.db.party.rangeFade and "on" or "off")
        .. "; combat: " .. (InCombatLockdown() and "yes" or "no"))
    if VV.conflicts.party then print("Party module suppressed by loaded " .. VV.conflicts.party) end
    for _, state in pairs(states) do
        if state.active then
            print((memberUnit(state.member) or "unknown unit") .. ": " .. (state.buffStatus or "not updated")
                .. "; source: " .. (state.buffSource or "none")
                .. (state.row and ("; native combat renderer: " .. (state.nativeBuffs and "ready" or state.nativeBuffsError or "unavailable")) or "")
                .. "; layout: " .. (state.compact and "native raid-style" or state.layoutApplied and "ready" or "no extra row"))
        end
    end
    if pending > 0 then
        print(pending .. " party frames awaiting buff-row initialization"
            .. (InCombatLockdown() and "; leave combat to prepare their protected layout." or "; waiting for refresh."))
    elseif count == 0 then
        print("Join a party and use portrait-style party frames in Edit Mode. A unit-frame replacement can hide them.")
    end
    if lastError then print("Last client API error: " .. lastError) end
end

function addon.SetOption(key, value)
    if key == "rolePin" then
        if value ~= "off" and value ~= "top" and value ~= "bottom" then return false end
    elseif key == "spacing" then
        if type(value) ~= "number" or value ~= value or value < 0 or value > 40 then return false end
        value = math.floor(value + 0.5)
    elseif (key ~= "buffs" and key ~= "classColors" and key ~= "rangeFade" and key ~= "growUp") or type(value) ~= "boolean" then return false end
    VV.db.party[key] = value
    refresh()
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true
end

function addon.HandleSlash(message)
    local key, mode = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if key == "options" or key == "settings" then VV.OpenOptions("party"); return end
    key = ({buffs = "buffs", colors = "classColors", classcolors = "classColors", range = "rangeFade"})[key] or key
    if key == "spacing" then addon.SetOption("spacing", tonumber(mode))
    elseif key == "grow" and (mode == "up" or mode == "down") then addon.SetOption("growUp", mode == "up")
    elseif key == "roles" then addon.SetOption("rolePin", mode) end
    if (key == "buffs" or key == "classColors" or key == "rangeFade") and (mode == "on" or mode == "off" or mode == "toggle") then
        addon.SetOption(key, mode == "on" or mode == "toggle" and not VV.db.party[key])
    end
    if key == "help" then
        VV.Print("/vv party range on | off | toggle fades portraits and buffs using the friendly spell and range opacity.")
        VV.Print("/vv party spacing <0-40>; /vv party grow up | down adjusts portrait-style member layout.")
        VV.Print("/vv party roles off | top | bottom pins tanks before healers at the chosen edge.")
    end
    Status()
end

addon.RefreshModule = refresh
