local _, VV = ...
local ns = VV.Nameplates
local panels, controls = {}, {}
local UI = ns.UI
ns.OpenSettingsCategory = VV.OpenSettingsCategory

function ns.RefreshFeatureOptions()
    UI.RefreshControls(controls)
end

local function Heading(panel, title, text)
    UI.Label(panel, title, 16, -16, "GameFontNormalLarge")
    local intro = UI.Label(panel, text, 16, -44, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -44)
    intro:SetJustifyH("LEFT")
end

local function FeatureCheck(panel, id, title, y, field, tip)
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    holder:SetSize(480, 28)
    controls[id] = UI.Check(holder, "feature." .. id, title, 0,
        function() return ns.tweaksDB[field] end,
        function(value) ns.SetFeature(field, value) end, tip)
end

local function SpellBox(panel, kind, title, y)
    UI.Label(panel, title, 16, y - 5)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(270, 28)
    box:SetPoint("TOPLEFT", panel, "TOPLEFT", 180, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(256)
    local function Refresh()
        if not box:HasFocus() then box:SetText(ns.tweaksDB[kind] or "") end
    end
    local function Commit()
        local text = box:GetText():gsub("|c%x%x%x%x%x%x%x%x|Hspell:(%d+).-|h.-|h|r", "%1")
            :gsub("|Hspell:(%d+).-|h.-|h", "%1")
        ns.SetRangeSpell(kind, text:match("^%s*$") and "off" or text)
        box:ClearFocus(); Refresh()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEscapePressed", function() box:ClearFocus(); Refresh() end)
    local apply = UI.Button(panel, "Apply", 72, Commit)
    apply:SetPoint("LEFT", box, "RIGHT", 12, 0)
    controls[kind] = {box = box, button = apply, Refresh = Refresh}
end

function ns.RegisterFeatureOptions()
    if ns.nameplateCategory then return end
    local root = CreateFrame("Frame", nil, UIParent)
    root:Hide()
    Heading(root, "Nameplates", "Enable Nameplates on the VanillaVarnish main page, then choose the features below.")
    FeatureCheck(root, "rangeEnabled", "Range check", -86, "rangeEnabled",
        "Fade out-of-range plates using your chosen damage and friendly spells.")
    FeatureCheck(root, "markers", "Quest icons", -126, "markers",
        "Show loot, kill, and other icons for incomplete quest objectives.")
    FeatureCheck(root, "swingsEnabled", "Swing timers", -166, "swingsEnabled",
        "Show your main-hand, off-hand, and ranged swing timers beneath your target nameplate.")
    VV.RegisterOptions()
    ns.rootCategory = VV.rootCategory
    ns.nameplateCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, root, "Nameplates")
    Settings.RegisterAddOnCategory(ns.nameplateCategory)
    panels.main = root

    local range = CreateFrame("Frame", nil, UIParent)
    range:Hide()
    Heading(range, "Range check", "Choose the opacity of out-of-range plates. Unknown results keep normal opacity.")
    SpellBox(range, "damage", "Damage spell", -90)
    SpellBox(range, "friendly", "Friendly spell", -134)
    UI.Label(range, "Enter a spell name, ID, or spell link, then click Apply or press Enter.\nMelee abilities check melee reach. Clear the field to disable that spell.",
        16, -188, "GameFontHighlightSmall")
    local opacityHolder = CreateFrame("Frame", nil, range)
    opacityHolder:SetPoint("TOPLEFT", range, "TOPLEFT", 16, -248)
    opacityHolder:SetPoint("TOPRIGHT", range, "TOPRIGHT", -16, -248)
    opacityHolder:SetHeight(40)
    controls.rangeOpacity = UI.Slider(opacityHolder, "feature.rangeOpacity", "Out-of-range opacity", 0, 0, 1, 0.01, true,
        function() return ns.tweaksDB.rangeOpacity end, ns.SetRangeOpacity,
        "Percent of the nameplate's normal opacity when out of range. 0% hides it; 100% keeps normal opacity. Default: 50%.")
    panels.rangeEnabled = range
    ns.rangeCategory = Settings.RegisterCanvasLayoutSubcategory(ns.rootCategory, range, "Range check")
    Settings.RegisterAddOnCategory(ns.rangeCategory)

    local quests = CreateFrame("Frame", nil, UIParent)
    quests:Hide()
    Heading(quests, "Quest icons", "Small white icons beside names identify incomplete loot, kill, and other quest objectives.")
    FeatureCheck(quests, "questieFallback", "Use Questie as an optional fallback", -90, "questieFallback",
        "Add Questie's objective tooltip data to the native icons. Item drops use QuestieDB automatically when available.")
    local hint = UI.Label(quests, "Item drops (including cooking ingredients) use QuestieDB automatically when enabled.\nQuestie's own icons can be disabled to avoid duplicates.",
        16, -144, "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", quests, "TOPRIGHT", -16, -144)
    hint:SetJustifyH("LEFT")
    panels.markers = quests
    ns.questCategory = Settings.RegisterCanvasLayoutSubcategory(ns.rootCategory, quests, "Quest icons")
    Settings.RegisterAddOnCategory(ns.questCategory)
    for _, panel in pairs(panels) do panel:SetScript("OnShow", ns.RefreshFeatureOptions) end
    ns.featurePanels, ns.featureControls = panels, controls
    ns.RefreshFeatureOptions()
end

function ns.OpenOptions(page)
    if not ns.nameplateCategory then ns.RegisterOptions() end
    if page == "swingsEnabled" or page == "swings" then ns.OpenSwingOptions(); return end
    local category = page == "rangeEnabled" and ns.rangeCategory
        or page == "markers" and ns.questCategory or ns.nameplateCategory
    ns.OpenSettingsCategory(category)
end
