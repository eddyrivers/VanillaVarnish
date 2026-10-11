-- Minimal XML-template contract when native sources are not supplied. Native
-- runs use the real CastingBarMixin instead, including its complete event path.
if not NamePlateCastingBarMixin then
    NamePlateCastingBarMixin = {}
    NamePlateSetupOptions = {castBarHeight=10, castIconHeight=12, castIconWidth=12,
        castBarFontHeight=10, horizontalScale=1, verticalScale=1,
        spellNameInsideCastBar=false, useClassicCastBar=false, castBarBorderWidth=128,
        insetWidth=12, hideIconWhenNotInterruptible=true, castBarBorderHeight=16,
        castBarShieldWidth=10, castBarShieldHeight=12}
    local original = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local frame = original(kind, name, parent)
        frame.template = template
        if template == "NamePlateCastingBarTemplate" then
            for _, key in ipairs({"Spark", "Text", "CastTargetNameText"}) do frame[key] = Mock.New(frame) end
            function frame:SetNameTextShown(value) self.Text:SetShown(value) end
            function frame:SetIconShown(value) self.showIcon=value end
            function frame:SetTargetNameTextShown(value) self.CastTargetNameText:SetShown(value) end
            function frame:SetHighlightImportantCasts(value) self.highlightImportantCasts=value end
            function frame:SetHighlightWhenCastTarget(value) self.highlightWhenCastTarget=value end
            function frame:ApplyStyleAndAnchoring(options) self.options=VV_TEST_NS.Copy(options) end
            function frame:UpdateBarFillTexture() end
            function frame:SetUnit(unit, trade, shield)
                self.unit, self.showTradeSkills, self.showShield = unit, trade, shield
                if unit then self:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
                else self:UnregisterEvent("UNIT_SPELLCAST_START"); self:Hide() end
            end
            function frame:SimulateCast(data) self.Text:SetText(data.spellName); self:Show() end
            function frame:StopAnims() end
        end
        return frame
    end
    function Mock.Object:SetTextHeight(height) self.fontSize=height end
end
