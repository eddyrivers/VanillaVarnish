local ns, vv = NST_TEST_NS, VV_TEST_NS
local checks = 0
local function check(value, message) assert(value, message); checks=checks+1 end
local function holder(plate)
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == plate and frame.bar and frame.bar.template == "NamePlateCastingBarTemplate" then return frame end
    end
end
local Object = Mock.Object
function Object:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
function Object:SetFontObject(font) self.font=font end
local casting, channel
function UnitCastingInfo(unit)
    check(unit == nil or unit == "player", "Extra bar never queries the target's casts")
    if unit == "player" and casting then return unpack(casting) end
end
function UnitChannelInfo(unit)
    check(unit == nil or unit == "player", "Extra bar never queries the target's channels")
    if unit == "player" and channel then return unpack(channel) end
end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local target = Mock.Plate("nameplate1")
Mock.plates.target = target
Mock.units.target, Mock.units.nameplate1 = true, true
local enemyCast = CreateFrame("Frame", nil, target.UnitFrame)
target.UnitFrame.CastBarsContainer = {castBar=enemyCast}
local enemyScript = function() end
enemyCast:SetScript("OnEvent", enemyScript)
Mock.Event("PLAYER_TARGET_CHANGED")
check(not ns.tweaksDB.playerCastBarEnabled and not holder(target), "Optional player cast bar defaults off")
SlashCmdList.VANILLAVARNISH("nameplates cast on")
local frame = assert(holder(target))
local bar = frame.bar
check(bar.unit == "player" and bar.showTradeSkills and bar.showShield == false, "Native cast engine is bound to the player's spells")
check(bar.eventUnits.UNIT_SPELLCAST_START == "player", "Native player event binding")
check(frame.points[1][2] == target.UnitFrame.HealthBarsContainer and frame.points[1][4] == 20 and frame.points[1][5] == -90,
    "Placement uses target health anchor and positive-down offsets")
check(enemyCast.scripts.OnEvent == enemyScript and not enemyCast.unit, "Target's original cast bar remains untouched")
SlashCmdList.VANILLAVARNISH("nameplates cast x -15")
SlashCmdList.VANILLAVARNISH("nameplates cast y 75")
SlashCmdList.VANILLAVARNISH("nameplates cast width 260")
check(ns.PlayerCastBar.db.x == -15 and ns.PlayerCastBar.db.y == 75 and ns.PlayerCastBar.db.width == 260, "Slash settings persist")
check(frame.points[1][4] == -15 and frame.points[1][5] == -75, "Offset updates apply immediately")
check(not ns.PlayerCastBar.SetValue("height", 20) and not ns.PlayerCastBar.SetValue("width", 0)
    and not ns.PlayerCastBar.SetValue("x", 0/0), "Height cannot override style; invalid inputs are rejected")
local saved = ns.PlayerCastBar.db
ns.PlayerCastBar.InitDB()
check(ns.PlayerCastBar.db == saved and saved.width == 260, "Existing options survive reinitialization")

if CastingBarMixin then
    for style = 0, 6 do
        for size = 1, 5 do
            Mock.ApplyNameplateStyle(style, size)
            ns.RefreshPlayerCastBar()
            local o = NamePlateSetupOptions
            check(bar:GetHeight() == o.castBarHeight and bar.classicStyleCastBar == o.useClassicCastBar,
                "Every native style/size keeps cast bar height and artwork")
            check(bar.Icon:GetHeight() == o.castIconHeight and bar.Text.fontSize == o.castBarFontHeight,
                "Native cast icon and font sizing")
        end
    end
    Mock.ApplyNameplateStyle(0, 2); ns.RefreshPlayerCastBar()
    casting = {"Healing Touch", "Healing Touch", 123, GetTime()*1000, (GetTime()+3)*1000, false, "cast-guid", false, 5185}
    Mock.Event("UNIT_SPELLCAST_START", "target")
    check(not bar.casting, "Target cast events are ignored")
    Mock.Event("UNIT_SPELLCAST_START", "player")
    check(bar:IsShown() and bar.casting and bar.Text:GetText() == "Healing Touch" and bar.Icon.texture == 123,
        "Actual native engine displays player's cast and spell icon")
    bar:OnUpdate(0.5)
    check(bar.value >= 0.5 and bar.maxValue == 3, "Native progress advances")
    casting[5] = (GetTime()+4)*1000
    Mock.Event("UNIT_SPELLCAST_DELAYED", "player")
    check(bar.maxValue == 4, "Native delayed casts update duration")
    Mock.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-guid")
    check(not bar.casting and bar.barType == "interrupted", "Native interruption handling is retained")
    casting = nil
    channel = {"Tranquility", "Tranquility", 321, GetTime()*1000, (GetTime()+5)*1000, false, false, 740}
    Mock.Event("UNIT_SPELLCAST_CHANNEL_START", "player")
    check(bar.channeling and bar.Text:GetText() == "Tranquility", "Native player channels display")
    bar:OnUpdate(1)
    check(bar.value == 4, "Native channel progress counts down")
    channel = nil
    Mock.Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "channel-guid", 740)
    check(not bar.channeling, "Native channel stop is retained")
end

local second = Mock.Plate("nameplate2")
if CastingBarMixin then
    casting = {"Healing Touch", "Healing Touch", 123, (GetTime()-1)*1000, (GetTime()+2)*1000, false, "new-guid", false, 5185}
end
Mock.plates.target = second
Mock.Event("PLAYER_TARGET_CHANGED")
local replacement = assert(holder(second))
check(not frame:IsShown() and bar.unit == nil and not bar.events.UNIT_SPELLCAST_START,
    "Changing targets detaches old pooled plate and native cast events")
check(replacement.bar.unit == "player", "New target still shows player's casts")
if CastingBarMixin then
    check(replacement.bar.casting and replacement.bar.value == 1, "Changing targets resumes the player's in-progress cast")
end
Mock.combat, Mock.lockdown = true, true
ns.PlayerCastBar.SetValue("x", 12)
check(replacement.points[1][4] == 12, "Only addon placement changes during combat")
vv.SetModuleEnabled("nameplates", false)
check(not replacement:IsShown() and replacement.bar.unit == nil, "Master switch detaches the extra bar")
vv.SetModuleEnabled("nameplates", true)
check(replacement.bar.unit == "player" and saved.x == 12, "Re-enable preserves placement")
second:Hide(); Mock.Tick(0.11)
check(not replacement:IsShown() and replacement.bar.unit == nil, "Offscreen/hidden target clears the cast source")
second:Show(); Mock.Tick(0.11)
check(replacement.bar.unit == "player", "Visible plate reconnects")
second.forbidden = true; Mock.Tick(0.11)
check(replacement.bar.unit == nil, "Forbidden target plate is untouched")
second.forbidden = false; Mock.Tick(0.11)
Mock.plates.target = nil
Mock.plates.softenemy = target
Mock.units.softenemy = true
Mock.Event("PLAYER_TARGET_CHANGED")
check(not replacement:IsShown() and bar.unit == nil, "Hard target without a plate never borrows another soft target")
Mock.units.target = {secret=true}
Mock.Event("PLAYER_TARGET_CHANGED")
check(bar.unit == nil, "Unknown hard-target existence never borrows a soft target")
Mock.units.target = false
Mock.Event("PLAYER_SOFT_ENEMY_CHANGED")
check(bar.unit == "player", "Soft enemy fallback matches swing timers when no hard target exists")
ns.SetFeature("playerCastBarEnabled", false)
check(bar.unit == nil and not frame:IsShown(), "Feature switch unbinds native event source")
Mock.combat, Mock.lockdown = false, false
ns.PlayerCastBar.Reset()
check(saved.width == 200 and saved.x == 20 and saved.y == 90 and not ns.tweaksDB.playerCastBarEnabled,
    "Reset restores placement and leaves feature switch unchanged")
ns.PlayerCastBar.OpenOptions()
check(ns.PlayerCastBar.optionsPanel:IsShown(), "Cast settings page opens through /vv")
local controls = ns.PlayerCastBar.optionControls
controls.enabled.button:SetChecked(true)
controls.enabled.button.scripts.OnClick(controls.enabled.button)
check(ns.tweaksDB.playerCastBarEnabled and ns.PlayerCastBar.previewNameplate,
    "Settings toggle enables extra bar and native preview")
ns.PlayerCastBar.optionsPanel:Hide()
ns.SetFeature("playerCastBarEnabled", false)
VV_PLAYER_CAST_CHECKS = checks
