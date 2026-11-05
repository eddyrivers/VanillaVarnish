local _, VV = ...
local addon = VV.Party
local SIZE, GAP, PER_ROW, LIMIT = 19, 2, 8, 16

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

local function InitializeButton(button)
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
    local count = cover:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 1, -1)
    button:SetApplicationCount(count)
end

function addon.CreateNativeBuffs(parent)
    if InCombatLockdown() or not addon.NativeBuffsAvailable() then return end
    local container
    local ok, err = pcall(function()
        -- Forever can put the same combat aura in both PLAYER and !PLAYER
        -- groups. Keep one live list and use the larger size for all its icons.
        container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        container:SetEnabled(false)
        container:Hide()
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        container:SetFrameLevel(parent:GetFrameLevel() + 1)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutMaximumLineSize(PER_ROW * SIZE + (PER_ROW - 1) * GAP)
        container:AddAuraGroup("buffs", "HELPFUL", {
            maxFrameCount = LIMIT,
            sortMethod = AuraContainerSortMethod.Default,
            initializeFrame = InitializeButton,
            layout = {elementWidth=SIZE, elementHeight=SIZE, elementSpacing=GAP, lineSpacing=GAP},
        })
    end)
    if ok then return container end
    if container then
        pcall(container.SetEnabled, container, false)
        pcall(container.Hide, container)
    end
    return nil, tostring(err)
end
