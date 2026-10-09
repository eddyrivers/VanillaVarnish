local _, VV = ...
local addon = VV.Party
-- WoW Forever: decorate Blizzard's frames without replacing their artwork,
-- unit buttons, event handlers, or secure mixin methods.
local ICON_SIZE, ICON_GAP, MAX_BUFFS = 14, 2, 8
local PLAYER_ICON_SIZE, AURA_SCAN_LIMIT = ICON_SIZE + 5, 40
local EXTRA_HEIGHT = PLAYER_ICON_SIZE + 2
-- Blizzard's DebuffTypeColor values (FrameXML/BuffFrame.lua). Prefer the
-- client's table when present, including any accessibility customization.
local debuffColors = {
    Magic = {r=0.20, g=0.60, b=1.00}, Curse = {r=0.60, g=0.00, b=1.00},
    Disease = {r=0.60, g=0.40, b=0}, Poison = {r=0, g=0.60, b=0},
}
local states, lastError = {}, nil
local driver = CreateFrame("Frame")
local ready, elapsed, auraElapsed = false, 0, 0

local function feature(key)
    return VV.IsModuleEnabled("party") and VV.db.party[key]
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
    row:SetSize(MAX_BUFFS * (PLAYER_ICON_SIZE + ICON_GAP) - ICON_GAP, PLAYER_ICON_SIZE)
    row:SetFrameLevel(member:GetFrameLevel() + 5)
    row:Hide()
    local state = { member = member, row = row, icons = {}, baseHeight = member:GetHeight() }
    for index = 1, MAX_BUFFS do
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)
        icon.border = icon:CreateTexture(nil, "BACKGROUND")
        icon.border:SetAllPoints()
        icon.border:SetColorTexture(0.08, 0.08, 0.08, 1)
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

local function restoreColor(state)
    if not state.tint then return end
    if InCombatLockdown() then return end
    local tint = state.tint
    if tint.texture and tint.desaturation then
        attempt(tint.texture.SetDesaturated, tint.texture, unpack(tint.desaturation))
    end
    if tint.color then attempt(tint.bar.SetStatusBarColor, tint.bar, unpack(tint.color)) end
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

local function colorHealth(state)
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
        if not state.tint then
            -- Store display values without comparisons/arithmetic. Widget
            -- setters can consume secret color channels when restoring them.
            state.tint = { bar = bar, texture = texture }
            if bar.GetStatusBarColor then state.tint.color = { bar:GetStatusBarColor() } end
            -- A wrapper records presence without branching on a secret boolean.
            if texture and texture.IsDesaturated then state.tint.desaturation = { texture:IsDesaturated() } end
        end
        if texture then attempt(texture.SetDesaturated, texture, true) end
        attempt(bar.SetStatusBarColor, bar, color.r, color.g, color.b)
    end
end

local function setAura(icon, unit, aura, index)
    icon.unit = unit
    icon.auraID = auraField(aura, "auraInstanceID")
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

local function updateBuffs(state)
    state.buffCount, state.buffSource, state.buffReadFailed = 0, nil, false
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
    if not C_UnitAuras then state.buffStatus = "aura APIs unavailable"; clearRow(state); return end
    local list, indexed
    -- The list API exposes buffs in Forever even when the index API refuses.
    if C_UnitAuras.GetUnitAuras then
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
    -- Stable partition before limiting the row: a player's buff beyond the
    -- first eight still belongs at the front. Restricted ownership stays in
    -- native order and continues to display through the widget-only path.
    local ordered, others = {}, {}
    for index = 1, AURA_SCAN_LIMIT do
        local aura = list[index]
        if type(aura) == "table" then
            local source = auraField(aura, "sourceUnit")
            local own = source == "player"
            if not own and type(source) == "string" and UnitIsUnit then
                local ok, value = attempt(UnitIsUnit, source, "player")
                own = ok and readable(value) == true
            end
            local entry = {aura=aura, index=index, own=own}
            local destination = own and ordered or others
            destination[#destination + 1] = entry
        end
    end
    for _, entry in ipairs(others) do ordered[#ordered + 1] = entry end
    local received = 0
    local x = 0
    for index, icon in ipairs(state.icons) do
        local entry = ordered[index]
        local aura = entry and entry.aura
        -- AuraData records may themselves be secret references in combat.
        -- Do not compare or filter them: attempt permitted field-to-widget
        -- display, retaining the guards on secret counts, IDs, and durations.
        if type(aura) == "table" then
            received = received + 1
            local size = entry.own and PLAYER_ICON_SIZE or ICON_SIZE
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", state.row, "TOPLEFT", x, 0)
            x = x + size + ICON_GAP
            if attempt(setAura, icon, unit, aura, indexed and entry.index or nil) then
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
    local height = state.baseHeight + EXTRA_HEIGHT
    local changed = member:GetHeight() ~= height
    if changed then member:SetHeight(height) end
    state.layoutApplied = true
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
    return changed
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
            if not compact and layoutRow(state) then layoutChanged = true end
            colorHealth(state)
            if not compact then updateBuffs(state); updateDebuffs(state) end
        end
    end)
    for _, state in pairs(states) do
        if not state.active then
            if state.row then clearRow(state) end
            if restoreHeight(state) then layoutChanged = true end
            restoreColor(state)
            restoreDebuffs(state)
        end
    end
    if layoutChanged and _G.PartyFrame and _G.PartyFrame.Layout then
        attempt(_G.PartyFrame.Layout, _G.PartyFrame)
    end
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
    "PLAYER_REGEN_ENABLED", "UNIT_AURA", "UNIT_CONNECTION", "UNIT_PET", "CVAR_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then ready = true end
    if not ready then return end
    if event == "UNIT_AURA" then
        if not feature("buffs") then return end
        if secret(unit) then
            -- Refresh known units without inspecting the restricted event token.
            for _, state in pairs(states) do if state.row then updateBuffs(state); updateDebuffs(state) end end
            C_Timer.After(0, refresh)
            return
        end
        for _, state in pairs(states) do
            if state.row and memberUnit(state.member) == unit then updateBuffs(state); updateDebuffs(state) end
        end
        C_Timer.After(0, refresh)
    else
        -- Run after Blizzard has processed this event and assigned pooled units.
        C_Timer.After(0, refresh)
    end
end)
driver:SetScript("OnUpdate", function(_, delta)
    if not ready or not VV.IsModuleEnabled("party") then return end
    elapsed, auraElapsed = elapsed + delta, auraElapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    -- No hooks or assignments to Blizzard's secure methods/mixins. Reapply
    -- class colors after native health updates and discover newly pooled frames.
    if auraElapsed >= 1 then
        auraElapsed = 0
        refresh()
    else
        for _, state in pairs(states) do
            if state.active and visible(state.member) ~= false then colorHealth(state) end
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
        .. "; combat: " .. (InCombatLockdown() and "yes" or "no"))
    if VV.conflicts.party then print("Party module suppressed by loaded " .. VV.conflicts.party) end
    for _, state in pairs(states) do
        if state.active then
            print((memberUnit(state.member) or "unknown unit") .. ": " .. (state.buffStatus or "not updated")
                .. "; source: " .. (state.buffSource or "none")
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
    if key ~= "buffs" and key ~= "classColors" or type(value) ~= "boolean" then return false end
    VV.db.party[key] = value
    refresh()
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true
end

function addon.HandleSlash(message)
    local key, mode = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if key == "options" or key == "settings" then VV.OpenOptions("party"); return end
    key = ({buffs = "buffs", colors = "classColors", classcolors = "classColors"})[key] or key
    if (key == "buffs" or key == "classColors") and (mode == "on" or mode == "off" or mode == "toggle") then
        addon.SetOption(key, mode == "on" or mode == "toggle" and not VV.db.party[key])
    end
    Status()
end

addon.RefreshModule = refresh
if not VV.IsLegacyLoaded("PartyTweaks") then
    SLASH_PARTYTWEAKS1 = "/partytweaks"
    SLASH_PARTYTWEAKS2 = "/pt"
    SlashCmdList.PARTYTWEAKS = addon.HandleSlash
end
