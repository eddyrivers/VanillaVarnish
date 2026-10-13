local _, VV = ...
local ns = VV.Nameplates
local WHITE = "Interface\\Buttons\\WHITE8x8"
local labels = {main = "MAIN", offhand = "OFF", ranged = "RANGE"}
local function Texture(parent, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(WHITE)
    texture:SetRoundLayoutToNearestPixel(true)
    return texture
end
local function NewBar(parent, index)
    local bar = CreateFrame("Frame", nil, parent)
    bar:EnableMouse(false)
    bar:SetRoundLayoutToNearestPixel(true)
    bar.index, bar.borderRows, bar.fillRows = index, {}, {}
    -- Invisible rectangle anchors the moving spark; visible fill uses rounded rows.
    bar.fill = Texture(bar, "BACKGROUND")
    bar.fill:SetAlpha(0)
    bar.sparkFrame = CreateFrame("Frame", nil, bar)
    bar.sparkFrame:EnableMouse(false)
    bar.spark = bar.sparkFrame:CreateTexture(nil, "OVERLAY")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("ui-castingbar-pip") then
        bar.spark:SetAtlas("ui-castingbar-pip")
    else bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark") end
    bar.spark:SetAllPoints()
    bar.spark:SetBlendMode("ADD")
    bar.sparkAnim = bar.spark:CreateAnimationGroup()
    bar.sparkAnim:SetLooping("REPEAT")
    for order, values in ipairs({{0.55, 1, 0.09}, {1, 0.7, 0.13}, {0.7, 0.95, 0.07}, {0.95, 0.55, 0.17}}) do
        local alpha = bar.sparkAnim:CreateAnimation("Alpha")
        alpha:SetOrder(order)
        alpha:SetFromAlpha(values[1]); alpha:SetToAlpha(values[2]); alpha:SetDuration(values[3])
    end
    bar.labelFrame = CreateFrame("Frame", nil, bar)
    bar.labelFrame:SetAllPoints(bar)
    bar.labelFrame:SetFrameLevel(bar.sparkFrame:GetFrameLevel() + 1)
    bar.labelFrame:EnableMouse(false)
    -- SetText requires an initialized font, before StyleStack chooses the user's font.
    bar.label = bar.labelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetText(labels[ns.order[index]])
    -- Eight copies make the black outline exactly one screen pixel at any scale.
    bar.labelOutline = {}
    for i = 1, 8 do
        local outline = bar.labelFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        outline:SetText(labels[ns.order[index]])
        outline:SetTextColor(0, 0, 0, 1)
        bar.labelOutline[i] = outline
    end
    bar:SetScript("OnHide", function() bar.sparkAnim:Stop(); bar.sparkFrame:Hide() end)
    bar:Hide()
    return bar
end
function ns.CreateStack(parent)
    local stack = CreateFrame("Frame", nil, parent)
    -- Native target/combat nameplates animate their scale. Keep timer sizes
    -- and spacing at the user's UI scale instead of inheriting that animation.
    stack:SetIgnoreParentScale(true)
    stack.uiScale = UIParent:GetEffectiveScale()
    stack:SetScale(stack.uiScale)
    stack:EnableMouse(false)
    stack:SetRoundLayoutToNearestPixel(true)
    stack:SetFrameLevel(parent:GetFrameLevel() + 10)
    stack.bars = {}
    for index, key in ipairs(ns.order) do stack.bars[key] = NewBar(stack, index) end
    stack:SetScript("OnHide", function()
        for _, bar in pairs(stack.bars) do bar.sparkAnim:Stop(); bar.sparkFrame:Hide() end
    end)
    stack:Hide()
    return stack
end
-- Cross-section of a rounded rectangle. Insetting a circle by 1px reduces its
-- radius by 1px. The fill's 2px inset removes the 1px stroke plus the 1px gap.
function ns.RoundedInset(width, height, radius, y)
    radius = math.max(0, math.min(radius, width / 2, height / 2))
    local distance = math.max(radius - y, y - (height - radius), 0)
    return radius - math.sqrt(math.max(0, radius * radius - distance * distance))
end
local function Place(texture, bar, x, y, width, height)
    texture:SetShown(width > 0)
    if width <= 0 then return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
    texture:SetSize(width, height)
end
local function Border(bar, pixel, db)
    local _, r, g, b = ns.ParseColor(db.borderColor)
    local alpha = db.borderColor == "transparent" and 0 or db.borderAlpha
    local count = math.floor(bar.barHeight / pixel + 0.5)
    for i = 1, count do
        local row = bar.borderRows[i]
        if not row then row = {Texture(bar, "OVERLAY"), Texture(bar, "OVERLAY")}; bar.borderRows[i] = row end
        local y = (i - 1) * pixel
        local h = math.min(pixel, bar.barHeight - y)
        local mid = y + h / 2
        local outer = ns.RoundedInset(bar.barWidth, bar.barHeight, bar.radius, mid)
        if mid < pixel or mid > bar.barHeight - pixel then
            Place(row[1], bar, outer, y, bar.barWidth - 2 * outer, h)
            row[2]:Hide()
        else
            local inner = pixel + ns.RoundedInset(bar.barWidth - 2 * pixel, bar.barHeight - 2 * pixel,
                math.max(0, bar.radius - pixel), mid - pixel)
            Place(row[1], bar, outer, y, inner - outer, h)
            Place(row[2], bar, bar.barWidth - inner, y, inner - outer, h)
        end
        for _, texture in ipairs(row) do texture:SetVertexColor(r, g, b, alpha) end
    end
    for i = count + 1, #bar.borderRows do for _, texture in ipairs(bar.borderRows[i]) do texture:Hide() end end
end
function ns.StyleStack(stack)
    local pixel = PixelUtil.GetPixelToUIUnitFactor() / stack:GetEffectiveScale()
    if stack.styleVersion == ns.styleVersion and stack.pixel == pixel then return end
    local db = ns.db
    local function Snap(value) return math.floor(value / pixel + 0.5) * pixel end
    stack.pixel = pixel
    stack.barWidth, stack.barHeight = math.max(5 * pixel, Snap(db.width)), math.max(5 * pixel, Snap(db.height))
    stack.gap, stack.xOffset, stack.yOffset = Snap(db.gap), Snap(db.x), Snap(db.y)
    stack.totalWidth = stack.barWidth
    stack.layout = db.layout
    stack:SetWidth(stack.totalWidth)
    -- Divide physical pixels across three bars, keeping the full span.
    -- Tiny rows reduce the gap to leave room for each bar's border and fill.
    if stack.layout == "row" then
        local widthPixels = math.max(15, math.floor(stack.totalWidth / pixel + 0.5))
        local gapPixels = math.min(math.floor(stack.gap / pixel + 0.5), math.floor((widthPixels - 15) / 2))
        stack.totalWidth, stack.gap = widthPixels * pixel, gapPixels * pixel
        stack:SetWidth(stack.totalWidth)
        stack.barWidth = math.floor((widthPixels - 2 * gapPixels) / 3) * pixel
    end
    local offsets = {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
    for index, key in ipairs(ns.order) do
        local bar, config = stack.bars[key], db.bars[key]
        local width = stack.barWidth
        if stack.layout == "row" and index == 3 then width = stack.totalWidth - 2 * (width + stack.gap) end
        bar:SetSize(width, stack.barHeight)
        bar.barWidth, bar.barHeight = width, stack.barHeight
        bar.inset, bar.pixel = 2 * pixel, pixel
        bar.radius = math.min(db.borderRadius * pixel, bar.barHeight / 2, bar.barWidth / 2)
        bar.fillRadius = math.max(0, bar.radius - bar.inset)
        bar.innerWidth, bar.innerHeight = bar.barWidth - 2 * bar.inset, bar.barHeight - 2 * bar.inset
        bar.fill:ClearAllPoints()
        bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", bar.inset, -bar.inset)
        bar.fill:SetHeight(bar.innerHeight)
        -- Keep the native spark art tall enough to extend past the bar.
        local sparkHeight = math.max(db.sparkSize * pixel, bar.barHeight + 4 * pixel)
        bar.sparkFrame:SetSize(db.sparkSize * pixel, sparkHeight)
        bar.sparkFrame:ClearAllPoints()
        bar.sparkFrame:SetPoint("CENTER", bar.fill, "RIGHT", 0, 0)
        bar.sparkFrame:SetAlpha(db.sparkAlpha * config.alpha)
        bar.spark:SetVertexColor(1, 1, 0.85)
        bar.effect, bar.effectOpacity = config.effect, db.effectAlpha * config.alpha
        local _, r, g, b = ns.ParseColor(config.color)
        bar.color = {r, g, b}
        Border(bar, pixel, db)
        local _, lr, lg, lb = ns.ParseColor(config.labelColor)
        bar.label:SetTextColor(lr, lg, lb, config.labelColor == "transparent" and 0 or 1)
        local labelInset = 5 * pixel
        local function Font(text, x, y)
            if text:SetFont(ns.fontPaths[config.labelFont], config.labelSize * pixel, "") == false then
                text:SetFont(ns.fontPaths.arial, config.labelSize * pixel, "")
            end
            text:ClearAllPoints()
            -- Move the text region itself rather than relying on justification
            -- inside an implicitly sized, doubly anchored FontString. Reanchor
            -- on each style change so cached text layouts update immediately.
            local point = config.labelAlign
            local inset = point == "LEFT" and labelInset or point == "RIGHT" and -labelInset or 0
            text:SetPoint(point, bar, point, inset + x, y)
            text:SetText(labels[key])
            text:SetWordWrap(false)
            text:SetWidth(0) -- Measure without the previous font/size's width constraint.
            text:SetWidth(math.max(pixel, math.min(bar.barWidth - 2 * labelInset, text:GetStringWidth())))
            -- A 14px font needs a taller text box than the default 10-unit bar.
            text:SetHeight(math.max(bar.barHeight, (config.labelSize + 2) * pixel))
            text:SetJustifyH(config.labelAlign)
            text:SetJustifyV("MIDDLE")
        end
        Font(bar.label, 0, 0)
        for i, text in ipairs(bar.labelOutline) do Font(text, offsets[i][1] * pixel, offsets[i][2] * pixel) end
        bar.labelFrame:SetShown(config.labelEnabled and config.labelColor ~= "transparent")
        -- Reserve decorative bounds even while a spark is momentarily empty,
        -- so swing progress never changes the vertical layout.
        local padding = 0
        if db.spark and db.sparkAlpha > 0 and config.alpha > 0 then
            padding = math.max(padding, (sparkHeight - bar.barHeight) / 2)
        end
        if config.labelEnabled and config.labelColor ~= "transparent" then
            local textHeight = math.max(bar.barHeight, (config.labelSize + 2) * pixel)
            padding = math.max(padding, (textHeight - bar.barHeight) / 2 + pixel)
        end
        bar.visualPadding = math.ceil(padding / pixel) * pixel
    end
    stack.styleVersion = ns.styleVersion
end
local function ReadRegion(region, method)
    if not region or not region[method] then return end
    local ok, value = pcall(region[method], region)
    if ok then return ns.Known(value) end
end
local function Geometry(region, method)
    return ns.Number(ReadRegion(region, method), -100000, 100000)
end

-- Native cast containers include below-bar spell icons/text in their height.
-- Include any visible artwork outside that container, using readable geometry
-- only. Public setup dimensions supply a fallback for restricted coordinates.
function ns.CastClearance(frame, anchor, stack)
    if not frame then return 0 end
    local container = frame.CastBarsContainer
    local cast = container and container.castBar or frame.castBar
    if not cast then return 0 end
    local setup = NamePlateSetupOptions or {}
    local spacing = ns.Number(setup.castBarToHealthBarSpacing, 0, 2000) or 2
    local anchorScale = Geometry(anchor, "GetEffectiveScale") or 1
    local scale = Geometry(stack, "GetEffectiveScale") or anchorScale
    if scale <= 0 then return 0 end
    local castScale = Geometry(cast, "GetEffectiveScale") or scale
    local height = Geometry(cast, "GetHeight") or ns.Number(setup.castBarHeight, 0, 2000) or 0
    local span = container and Geometry(container, "GetHeight") or height
    local ratio = castScale / scale
    local clearance = (container and spacing + math.max(0, span or height)
        or ns.Number(frame.castDepth, 0, 2000) or spacing + height) * ratio
    local healthBottom = Geometry(anchor, "GetBottom")
    for _, region in pairs({cast, cast.Border or cast.border, cast.Spark or cast.spark,
        cast.CastTargetNameText, cast.Icon or cast.icon, cast.Text or cast.text, cast.BorderShield}) do
        -- Native cast artwork can return a secret visibility boolean in combat.
        -- Discard it before comparison and reserve space when visibility is
        -- unknown; only a readable false can exclude artwork from clearance.
        if region and ReadRegion(region, "IsShown") ~= false then
            local bottom = Geometry(region, "GetBottom")
            local regionScale = Geometry(region, "GetEffectiveScale") or castScale
            if healthBottom and bottom then
                clearance = math.max(clearance, (healthBottom * anchorScale - bottom * regionScale) / scale)
            else
                local regionHeight = Geometry(region, "GetHeight") or 0
                local extra = math.max(0, (regionHeight * regionScale / castScale - (span or height)) / 2)
                if region == cast.CastTargetNameText and setup.useClassicCastBar then
                    extra = math.max(extra, Geometry(region, "GetStringHeight")
                        or ns.Number(setup.castBarFontHeight, 0, 2000) or 0)
                end
                clearance = math.max(clearance, (spacing + (span or height) + extra) * ratio)
            end
        end
    end
    return clearance
end

function ns.LayoutStack(stack, shown, anchor, clearance)
    local uiScale = UIParent:GetEffectiveScale()
    if stack.uiScale ~= uiScale then stack:SetScale(uiScale); stack.uiScale = uiScale end
    ns.StyleStack(stack)
    -- Combat can alternate readable and restricted cast geometry. Retain the
    -- placement for this anchor/style during combat rather than oscillating
    -- between live coordinates and the dimension fallback every poll.
    local inCombat = ns.Known(InCombatLockdown()) == true or ns.Known(UnitAffectingCombat("player")) == true
    if not inCombat or stack.clearanceAnchor ~= anchor or stack.clearanceStyle ~= stack.styleVersion
        or stack.clearancePixel ~= stack.pixel or stack.clearanceUnit ~= stack.unitToken then
        stack.clearance = clearance or 0
        stack.clearanceAnchor, stack.clearanceStyle = anchor, stack.styleVersion
        stack.clearancePixel = stack.pixel
        stack.clearanceUnit = stack.unitToken
    end
    clearance = stack.clearance
    local first, padding
    for _, key in ipairs(ns.order) do
        if stack.layout == "row" and ns.db.bars[key].enabled then
            padding = math.max(padding or 0, stack.bars[key].visualPadding)
        end
        if shown[key] then
            first = first or stack.bars[key]
            padding = math.max(padding or 0, stack.bars[key].visualPadding)
        end
    end
    local offsetY = stack.yOffset
    if first and offsetY >= 0 then
        local minimum = (clearance or 0) + (stack.layout == "row" and padding or first.visualPadding) + 2 * stack.pixel
        offsetY = math.max(offsetY, math.ceil(minimum / stack.pixel) * stack.pixel)
    end
    if stack.anchor ~= anchor or stack.offset ~= offsetY or stack.x ~= stack.xOffset then
        stack:ClearAllPoints()
        stack:SetPoint("TOP", anchor, "BOTTOM", stack.xOffset, -offsetY)
        stack.anchor, stack.offset, stack.x = anchor, offsetY, stack.xOffset
    end
    local previous, bottom, right = nil, 0, 0
    for _, key in ipairs(ns.order) do
        local bar = stack.bars[key]
        if shown[key] then
            -- The setting measures the gap between the bar borders. Decorative
            -- spark/text bounds must not silently add to the requested gap.
            local row = stack.layout == "row"
            local offset = not row and previous and bottom + stack.gap or 0
            local x = row and previous and right + stack.gap or 0
            if bar.offset ~= offset or bar.offsetX ~= x then
                bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", stack, "TOPLEFT", x, -offset)
                bar.offset, bar.offsetX = offset, x
            end
            bar:Show()
            previous, bottom = bar, offset + stack.barHeight
            right = x + bar.barWidth
        else bar:Hide() end
    end
    stack:SetHeight(math.max(stack.pixel, bottom))
    stack:SetShown(previous ~= nil)
end
function ns.PulseStrength(value)
    if value <= 0.5 then return value * 0.7 end
    if value <= 0.9 then return 0.35 + (value - 0.5) * 0.875 end
    return 0.7 + (value - 0.9) * 3
end
local function RenderBar(bar, key, value)
    local config, db = ns.db.bars[key], ns.db
    local width = bar.innerWidth * value
    bar.fill:SetShown(value > 0)
    if value > 0 then bar.fill:SetWidth(width) end
    local radius = math.min(bar.fillRadius, width / 2)
    local r, g, b = unpack(bar.color)
    -- The swing's fill is the animation clock: highlight builds continuously
    -- to its maximum at full, then resets with the next swing. Keep the additive
    -- pale gold tint without a separate flashing or dimming cycle.
    local opacity = bar.effect == "pulse" and bar.effectOpacity * ns.PulseStrength(value) or 0
    bar.pulseOpacity = opacity
    local count = math.floor(bar.innerHeight / bar.pixel + 0.5)
    for i = 1, count do
        local row = bar.fillRows[i]
        if not row then
            row = {Texture(bar, "ARTWORK"), Texture(bar, "OVERLAY")}
            row[2]:SetBlendMode("ADD")
            bar.fillRows[i] = row
        end
        local y = (i - 1) * bar.pixel
        local h = math.min(bar.pixel, bar.innerHeight - y)
        local inset = ns.RoundedInset(width, bar.innerHeight, radius, y + h / 2)
        local span = math.max(0, width - 2 * inset)
        for _, texture in ipairs(row) do Place(texture, bar, bar.inset + inset, bar.inset + y, span, h) end
        local delta = db.gradientRight - db.gradientLeft
        local left = (db.gradientLeft + delta * (width > 0 and inset / width or 0)) * config.alpha
        local right = (db.gradientLeft + delta * (width > 0 and (width - inset) / width or 1)) * config.alpha
        row[1]:SetGradient("HORIZONTAL", CreateColor(r, g, b, left), CreateColor(r, g, b, right))
        if span > 0 then
            row[2]:SetVertexColor(1, 0.96, 0.82, opacity)
            row[2]:SetShown(opacity > 0)
        end
    end
    for i = count + 1, #bar.fillRows do for _, texture in ipairs(bar.fillRows[i]) do texture:Hide() end end
    local spark = value > 0 and db.spark and db.sparkAlpha > 0 and config.alpha > 0
    bar.sparkFrame:SetShown(spark)
    if spark then
        if not bar.sparkAnim:IsPlaying() then bar.sparkAnim:Play() end
    elseif bar.sparkAnim:IsPlaying() then bar.sparkAnim:Stop() end
end
function ns.RenderStack(stack, now, progress)
    for _, key in ipairs(ns.order) do
        local bar = stack.bars[key]
        if bar:IsShown() then RenderBar(bar, key, math.max(0, math.min(1, progress(key, now)))) end
    end
end
