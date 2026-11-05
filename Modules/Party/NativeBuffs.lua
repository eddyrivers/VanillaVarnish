local _, VV = ...
local addon = VV.Party
local SIZE, GAP, ROW_STEP, PER_ROW, LIMIT = 14, 2, 21, 8, 16

function addon.NativeBuffsAvailable()
    return type(AuraContainerSortMethod) == "table" and type(CustomAuraContainerGroupDefaultOptions) == "table"
end

function addon.CreateBuffGlow(parent, relative)
    local glow = CreateFrame("Frame", nil, parent)
    glow:SetAllPoints(relative)
    glow:SetFrameLevel(parent:GetFrameLevel() + 1)
    for offset = 1, 2 do
        for _, edge in ipairs({{"TOPLEFT", "TOPRIGHT", -offset, offset, offset, offset},
            {"BOTTOMLEFT", "BOTTOMRIGHT", -offset, -offset, offset, -offset},
            {"TOPLEFT", "BOTTOMLEFT", -offset, offset, -offset, -offset},
            {"TOPRIGHT", "BOTTOMRIGHT", offset, offset, offset, -offset}}) do
            local texture = glow:CreateTexture(nil, "OVERLAY")
            texture:SetColorTexture(1, 0.82, 0.25, offset == 1 and 0.7 or 0.2)
            texture:SetBlendMode("ADD")
            texture:SetSize(1, 1)
            texture:SetPoint(edge[1], glow, edge[1], edge[3], edge[4])
            texture:SetPoint(edge[2], glow, edge[2], edge[5], edge[6])
        end
    end
    return glow
end

local function InitializeButton(button, own)
    -- This callback only builds presentation. The native container owns aura
    -- assignment, restricted data, updates, visibility, and tooltip scripts.
    button:SetSize(SIZE, SIZE)
    button:EnableMouse(true)
    button:SetMouseClickEnabled(false)
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
    button:SetHideTooltipInCombat(false)
    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.08, 0.08, 0.08, 1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetIcon(icon)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetReverse(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    button:SetDurationCooldown(cooldown)
    local cover = CreateFrame("Frame", nil, button)
    cover:SetAllPoints(button)
    cover:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    if own then addon.CreateBuffGlow(cover, button) end
    local count = cover:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 1, -1)
    button:SetApplicationCount(count)
end

function addon.CreateNativeBuffs(parent)
    if InCombatLockdown() or not addon.NativeBuffsAvailable() then return end
    local container, viewport
    local ok, err = pcall(function()
        -- Two native groups identify ownership without addon aura reads. The
        -- viewport displays only the first two rows, including their glows;
        -- the native flow packs other buffs immediately after the player's.
        viewport = CreateFrame("Frame", nil, parent)
        viewport:SetPoint("TOPLEFT", parent, "TOPLEFT", -2, 2)
        viewport:SetSize(PER_ROW * SIZE + (PER_ROW - 1) * GAP + 4, ROW_STEP + SIZE + 4)
        viewport:SetClipsChildren(true)
        container = CreateFrame("AuraContainer", nil, viewport, "CustomAuraContainerTemplate")
        container:SetEnabled(false)
        container:Hide()
        container:SetPoint("TOPLEFT", viewport, "TOPLEFT", 2, -2)
        container:SetFrameLevel(parent:GetFrameLevel() + 1)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutMaximumLineSize(PER_ROW * SIZE + (PER_ROW - 1) * GAP)
        for _, group in ipairs({{"ownBuffs", "HELPFUL|PLAYER", true}, {"buffs", "HELPFUL|!PLAYER", false}}) do
            local own = group[3]
            container:AddAuraGroup(group[1], group[2], {
                maxFrameCount = LIMIT,
                sortMethod = AuraContainerSortMethod.Default,
                initializeFrame = function(button) InitializeButton(button, own) end,
                layout = {elementWidth=SIZE, elementHeight=SIZE, elementSpacing=GAP, lineSpacing=ROW_STEP - SIZE,
                    groupSpacing=GAP, groupLineSpacing=ROW_STEP - SIZE, forceNewLine=false, layoutIndex=own and 1 or 2},
            })
        end
    end)
    if ok then return container end
    if container then
        pcall(container.SetEnabled, container, false)
        pcall(container.Hide, container)
    end
    if viewport then viewport:Hide() end
    return nil, tostring(err)
end
