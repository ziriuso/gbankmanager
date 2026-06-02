local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.modules.slash = ns.modules.slash or {}

local slash = ns.modules.slash

local function trim(value)
    if type(_G.strtrim) == "function" then
        return _G.strtrim(value)
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_command(rawMessage)
    local trimmed = trim(rawMessage or "")
    if trimmed == "" then
        return "", ""
    end

    local command, rest = string.match(trimmed, "^(%S+)%s*(.*)$")
    return string.lower(command or ""), rest or ""
end

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
        return
    end

    if type(_G.print) == "function" then
        _G.print(message)
    end
end

local ATLAS_SAMPLER_CANDIDATES = {
    "Professions-Icon-Quality-12-Tier1-Inv",
    "Professions-Icon-Quality-12-Tier2-Inv",
    "Professions-Icon-Quality-1-Inv",
    "Professions-Icon-Quality-2-Inv",
    "Professions-Icon-Quality-Tier1-Inv",
    "Professions-Icon-Quality-Tier2-Inv",
    "Professions-Icon-Quality-1",
    "Professions-Icon-Quality-2",
    "Professions-ChatIcon-Quality-Tier1",
    "Professions-ChatIcon-Quality-Tier2",
    "Professions-ChatIcon-Quality-12-Tier1",
    "Professions-ChatIcon-Quality-12-Tier2",
    "Interface-Crafting-ReagentQuality-1-Med",
    "Interface-Crafting-ReagentQuality-2-Med",
}

local function safe_set_text(region, value)
    if region and type(region.SetText) == "function" then
        region:SetText(tostring(value or ""))
    end
end

local function safe_set_atlas(texture, atlasName, useAtlasSize)
    if type(texture) ~= "table" or type(texture.SetAtlas) ~= "function" then
        return false
    end

    local ok = pcall(function()
        texture:SetAtlas(atlasName, useAtlasSize == true)
    end)
    texture.atlas = atlasName
    texture.useAtlasSize = useAtlasSize == true
    texture.atlasWasSet = ok == true
    return ok == true
end

local function atlas_info_text(atlasName)
    local textureApi = _G.C_Texture
    if type(textureApi) ~= "table" or type(textureApi.GetAtlasInfo) ~= "function" then
        return "metadata unavailable"
    end

    local ok, info = pcall(textureApi.GetAtlasInfo, atlasName)
    if not ok or type(info) ~= "table" then
        return "metadata unavailable"
    end

    local width = info.width or info.fileWidth
    local height = info.height or info.fileHeight
    if width and height then
        return string.format("%sx%s", tostring(width), tostring(height))
    end

    return "metadata available"
end

local function append_line(lines, text)
    lines[#lines + 1] = tostring(text or "")
end

local function value_text(value)
    if value == nil then
        return "nil"
    end

    local text = tostring(value)
    if text == "" then
        return "<empty>"
    end

    return text
end

local function row_matches_item(row, itemID)
    if type(row) ~= "table" then
        return false
    end
    if not itemID then
        return true
    end

    return tonumber(row.itemID) == tonumber(itemID)
end

local function compact_row_fields(row)
    row = type(row) == "table" and row or {}
    local keys = {
        "itemID",
        "itemName",
        "itemDisplayText",
        "itemDisplayTextIconAtlas",
        "tierIconAtlas",
        "itemTierIconAtlas",
        "craftedQuality",
        "craftedQualityIcon",
        "craftedQualityDisplayAtlas",
        "craftedQualityPreferredAtlas",
        "craftedQualityMax",
        "craftedQualityFamilySize",
        "quality",
        "itemTierValue",
    }
    local fields = {}

    for _, key in ipairs(keys) do
        if row[key] ~= nil and tostring(row[key] or "") ~= "" then
            fields[#fields + 1] = string.format("%s=%s", key, value_text(row[key]))
        end
    end

    return table.concat(fields, " ")
end

local function visible_icon_lines(lines, mainFrame, itemID)
    local visibleMatches = 0
    for visibleIndex, rowFrame in ipairs((mainFrame or {}).tableRows or {}) do
        local row = rowFrame and rowFrame.rowData
        if row_matches_item(row, itemID) then
            visibleMatches = visibleMatches + 1
            append_line(lines, string.format("visible[%d].rowData=%s", visibleIndex, compact_row_fields(row)))
            for colIndex, key in ipairs((mainFrame or {}).tableColumnKeys or {}) do
                local icon = rowFrame.columnIcons and rowFrame.columnIcons[colIndex] or nil
                local column = rowFrame.columns and rowFrame.columns[colIndex] or nil
                local atlas = icon and icon.atlas or nil
                local shown = icon and type(icon.IsShown) == "function" and icon:IsShown() or false
                local text = column and type(column.GetText) == "function" and column:GetText() or ""
                append_line(lines, string.format(
                    "visible[%d].col%d.key=%s atlas=%s shown=%s text=%s",
                    visibleIndex,
                    colIndex,
                    value_text(key),
                    value_text(atlas),
                    tostring(shown == true),
                    value_text(text)
                ))
            end
        end
    end

    if visibleMatches == 0 then
        append_line(lines, "visible=<no matching visible row; scroll/filter may hide it>")
    end
end

local function collect_render_debug(mainFrame, itemID)
    local lines = {}
    if type(mainFrame) ~= "table" then
        append_line(lines, "render debug unavailable: mainFrame missing")
        return lines
    end

    append_line(lines, string.format(
        "render debug itemID=%s activeView=%s renderer=%s rowsData=%d visibleRows=%d",
        value_text(itemID),
        value_text(mainFrame.activeView),
        type(mainFrame.RefreshVisibleTableRows) == "function" and "shared-table" or "unknown",
        #(mainFrame.tableRowsData or {}),
        #(mainFrame.tableRows or {})
    ))

    local columnParts = {}
    for index, key in ipairs(mainFrame.tableColumnKeys or {}) do
        columnParts[#columnParts + 1] = string.format("%d:%s", index, value_text(key))
    end
    append_line(lines, "columns=" .. table.concat(columnParts, ","))

    local dataMatches = 0
    for index, row in ipairs(mainFrame.tableRowsData or {}) do
        if row_matches_item(row, itemID) then
            dataMatches = dataMatches + 1
            append_line(lines, string.format("data[%d].%s", index, compact_row_fields(row)))
        end
    end
    if dataMatches == 0 then
        append_line(lines, "data=<no matching tableRowsData row>")
    end

    visible_icon_lines(lines, mainFrame, itemID)
    return lines
end

local function collect_request_debug(mainFrame, itemID)
    local lines = {}
    if type(mainFrame) ~= "table" then
        append_line(lines, "request debug unavailable: mainFrame missing")
        return lines
    end

    local selector = mainFrame.requestCreateSearchSelector
    append_line(lines, string.format(
        "request debug itemID=%s modalShown=%s selector=%s",
        value_text(itemID),
        tostring(mainFrame.requestWizardModal and type(mainFrame.requestWizardModal.IsShown) == "function" and mainFrame.requestWizardModal:IsShown() == true),
        type(selector) == "table" and "requestCreateSearchSelector" or "missing"
    ))

    if type(selector) ~= "table" then
        return lines
    end

    local selected = selector.selectedItem
    if row_matches_item(selected, itemID) then
        append_line(lines, "selected." .. compact_row_fields(selected))
        local selectedIcon = selector.selectedItemQualityIcon
        append_line(lines, string.format(
            "selected.qualityAtlas=%s shown=%s text=%s",
            value_text(selectedIcon and selectedIcon.atlas or nil),
            tostring(selectedIcon and type(selectedIcon.IsShown) == "function" and selectedIcon:IsShown() == true),
            value_text(selector.selectedItemNameText and type(selector.selectedItemNameText.GetText) == "function" and selector.selectedItemNameText:GetText() or "")
        ))
    elseif selected ~= nil then
        append_line(lines, "selected=<different item>")
    else
        append_line(lines, "selected=nil")
    end

    local visibleMatches = 0
    for index, row in ipairs(selector.resultRows or {}) do
        local item = row and row.resolvedItem
        if row_matches_item(item, itemID) then
            visibleMatches = visibleMatches + 1
            append_line(lines, string.format("result[%d].%s", index, compact_row_fields(item)))
            append_line(lines, string.format(
                "result[%d].qualityAtlas=%s shown=%s text=%s",
                index,
                value_text(row.qualityIcon and row.qualityIcon.atlas or nil),
                tostring(row.qualityIcon and type(row.qualityIcon.IsShown) == "function" and row.qualityIcon:IsShown() == true),
                value_text(row.itemText and type(row.itemText.GetText) == "function" and row.itemText:GetText() or "")
            ))
        end
    end

    if visibleMatches == 0 then
        append_line(lines, "result=<no matching visible request selector row; query/scroll may hide it>")
    end

    return lines
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    return pcall(fn, ...)
end

local function collect_ledger_debug(scanner)
    local lines = {}
    scanner = type(scanner) == "table" and scanner or {}
    append_line(lines, string.format(
        "ledger debug state scanInProgress=%s ledgerScanInProgress=%s pendingAfterInventory=%s pendingAuto=%s guildBankOpen=%s passiveActive=%s waitingForTab=%s ledgerTargets=%d",
        tostring(scanner.scanInProgress == true),
        tostring(scanner.ledgerScanInProgress == true),
        tostring(scanner.pendingLedgerScanAfterInventory == true),
        tostring(scanner.pendingLedgerAutoScan == true),
        tostring(scanner.guildBankOpen == true),
        tostring(scanner.passiveLedgerRefreshActive == true),
        value_text(scanner.waitingForTab),
        #(scanner.ledgerTargets or {})
    ))

    local tabCount = 0
    local okTabs, tabsResult = safe_call(_G.GetNumGuildBankTabs)
    if okTabs then
        tabCount = tonumber(tabsResult or 0) or 0
    end

    local moneyLogQueryId = (tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1
    append_line(lines, string.format("ledger debug tabs count=%d moneyQueryId=%d", tabCount, moneyLogQueryId))

    for tabIndex = 1, tabCount do
        local tabName = "Tab " .. tostring(tabIndex)
        local isViewable = false
        local okInfo, name, _, viewable = safe_call(_G.GetGuildBankTabInfo, tabIndex)
        if okInfo then
            tabName = tostring(name or tabName)
            isViewable = viewable == true
        end

        local itemCount = 0
        local okItemCount, itemCountResult = safe_call(_G.GetNumGuildBankTransactions, tabIndex)
        if okItemCount then
            itemCount = tonumber(itemCountResult or 0) or 0
        end

        append_line(lines, string.format(
            "itemLog tab=%d name=%s viewable=%s count=%d",
            tabIndex,
            tabName,
            tostring(isViewable),
            itemCount
        ))

        local sampleCount = math.min(itemCount, 3)
        for index = 1, sampleCount do
            local okRow, actionType, who, itemLink, count, tabOne, tabTwo, year, month, day, hour =
                safe_call(_G.GetGuildBankTransaction, tabIndex, index)
            if okRow then
                append_line(lines, string.format(
                    "item[%d:%d] type=%s who=%s item=%s qty=%s tabs=%s/%s age=%s/%s/%s/%s",
                    tabIndex,
                    index,
                    value_text(actionType),
                    value_text(who),
                    value_text(itemLink),
                    value_text(count),
                    value_text(tabOne),
                    value_text(tabTwo),
                    value_text(year),
                    value_text(month),
                    value_text(day),
                    value_text(hour)
                ))
            end
        end
    end

    local moneyCount = 0
    local okMoneyCount, moneyCountResult = safe_call(_G.GetNumGuildBankMoneyTransactions)
    if okMoneyCount then
        moneyCount = tonumber(moneyCountResult or 0) or 0
    end
    append_line(lines, string.format("moneyLog queryId=%d count=%d", moneyLogQueryId, moneyCount))

    local sampleMoneyCount = math.min(moneyCount, 3)
    for index = 1, sampleMoneyCount do
        local okMoneyRow, actionType, who, amount, year, month, day, hour =
            safe_call(_G.GetGuildBankMoneyTransaction, index)
        if okMoneyRow then
            append_line(lines, string.format(
                "money[%d] type=%s who=%s amount=%s age=%s/%s/%s/%s",
                index,
                value_text(actionType),
                value_text(who),
                value_text(amount),
                value_text(year),
                value_text(month),
                value_text(day),
                value_text(hour)
            ))
        end
    end

    return lines
end

local function collect_sync_debug(db, context)
    local lines = {}
    local permissions = ns.modules.auth or ns.modules.permissions or {}
    local peerState = ns.modules.syncPeerState or {}
    local syncState = (ns.state or {})
    local store = ns.modules.store or ns.data.store
    db = type(db) == "table" and db or {}
    context = type(context) == "table" and context or {}

    local root = syncState.dbRoot
    local activeGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if activeGuildKey == "" or (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(activeGuildKey)) then
        activeGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    end
    if activeGuildKey == "" or (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(activeGuildKey)) then
        activeGuildKey = tostring(context.guildName or "Unknown")
    end

    append_line(lines, string.format(
        "sync debug local name=%s characterKey=%s guild=%s activeGuildKey=%s",
        value_text(context.name),
        value_text(context.characterKey),
        value_text(context.guildName),
        value_text(activeGuildKey)
    ))

    local lastMessage = type(syncState.lastSyncMessage) == "table" and syncState.lastSyncMessage or {}
    local lastPayload = type(lastMessage.payload) == "table" and lastMessage.payload or {}
    local lastActorContext = type(lastPayload.actorContext) == "table" and lastPayload.actorContext or {}
    append_line(lines, string.format(
        "lastMessage type=%s sender=%s distribution=%s guildKey=%s actorName=%s actorCharacterKey=%s",
        value_text(lastMessage.type),
        value_text(lastMessage.sender),
        value_text(lastMessage.distribution),
        value_text(lastPayload.guildKey),
        value_text(lastActorContext.name),
        value_text(lastActorContext.characterKey)
    ))

    local lastDecision = type(syncState.lastSyncDecision) == "table" and syncState.lastSyncDecision or {}
    append_line(lines, string.format(
        "lastDecision accepted=%s category=%s reason=%s sender=%s distribution=%s messageType=%s guildKey=%s actorName=%s actorCharacterKey=%s peerCharacterKey=%s",
        tostring(lastDecision.accepted == true),
        value_text(lastDecision.category),
        value_text(lastDecision.reason),
        value_text(lastDecision.sender),
        value_text(lastDecision.distribution),
        value_text(lastDecision.messageType),
        value_text(lastDecision.guildKey),
        value_text(lastDecision.actorName),
        value_text(lastDecision.actorCharacterKey),
        value_text(lastDecision.peerCharacterKey)
    ))

    local peers = {}
    if type(peerState.GetPeers) == "function" then
        peers = peerState.GetPeers(db, activeGuildKey)
    else
        peers = ((((db or {}).syncState or {}).peers or {})[activeGuildKey] or {})
    end

    local peerKeys = {}
    for index, entry in ipairs(peers or {}) do
        local displayCharacterKey = type(permissions.DisplayCharacterKey) == "function"
            and permissions.DisplayCharacterKey(entry.characterKey)
            or tostring(entry.characterKey or "")
        peerKeys[#peerKeys + 1] = tostring(entry.characterKey or "")
        append_line(lines, string.format(
            "peer[%d].characterKey=%s display=%s lastSeen=%s lastSynchronizedAt=%s lastMessageType=%s version=%s",
            index,
            value_text(entry.characterKey),
            value_text(displayCharacterKey),
            value_text(entry.lastSeen),
            value_text(entry.lastSynchronizedAt),
            value_text(entry.lastMessageType),
            value_text(entry.version)
        ))
    end
    append_line(lines, "peerKeys=" .. table.concat(peerKeys, ","))

    return lines
end

local function create_or_reset_atlas_sampler()
    if type(_G.CreateFrame) ~= "function" then
        push_chat_line("GBankManager: Atlas sampler requires the WoW UI frame API.")
        return nil
    end

    local frame = slash.atlasSamplerFrame
    if type(frame) ~= "table" then
        frame = _G.CreateFrame("Frame", "GBankManagerAtlasSamplerFrame", _G.UIParent, "BackdropTemplate")
        slash.atlasSamplerFrame = frame
        if type(frame.SetSize) == "function" then
            frame:SetSize(700, 470)
        end
        if type(frame.SetPoint) == "function" then
            frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
        end
        if type(frame.SetFrameStrata) == "function" then
            frame:SetFrameStrata("DIALOG")
        end
        if type(frame.SetToplevel) == "function" then
            frame:SetToplevel(true)
        end
        if type(frame.SetMovable) == "function" then
            frame:SetMovable(true)
        end
        if type(frame.EnableMouse) == "function" then
            frame:EnableMouse(true)
        end
        if type(frame.RegisterForDrag) == "function" then
            frame:RegisterForDrag("LeftButton")
        end
        if type(frame.SetScript) == "function" then
            frame:SetScript("OnDragStart", frame.StartMoving)
            frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        end
        if type(frame.SetBackdrop) == "function" then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
        end
        if type(frame.SetBackdropColor) == "function" then
            frame:SetBackdropColor(0.04, 0.05, 0.06, 0.96)
        end
        if type(frame.SetBackdropBorderColor) == "function" then
            frame:SetBackdropBorderColor(0.8, 0.62, 0.12, 0.85)
        end

        frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
        safe_set_text(frame.titleText, "GBankManager Crafted-Quality Atlas Sampler")

        frame.hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.hintText:SetPoint("TOPLEFT", frame.titleText, "BOTTOMLEFT", 0, -8)
        frame.hintText:SetWidth(650)
        frame.hintText:SetWordWrap(true)
        safe_set_text(frame.hintText, "Compare the fixed-size and atlas-size previews. Tell Codex which labels show the single silver diamond and gold pentagon.")

        frame.closeButton = _G.CreateFrame("Button", nil, frame, "BackdropTemplate")
        frame.closeButton:SetSize(72, 24)
        frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -12)
        frame.closeButton.labelText = frame.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.closeButton.labelText:SetPoint("CENTER", frame.closeButton, "CENTER", 0, 0)
        safe_set_text(frame.closeButton.labelText, "Close")
        frame.closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    frame.rows = frame.rows or {}
    for index, atlasName in ipairs(ATLAS_SAMPLER_CANDIDATES) do
        local row = frame.rows[index]
        if type(row) ~= "table" then
            row = _G.CreateFrame("Frame", nil, frame, "BackdropTemplate")
            row:SetSize(660, 24)
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -(70 + ((index - 1) * 27)))
            row.fixedIcon = row:CreateTexture(nil, "ARTWORK")
            row.fixedIcon:SetSize(18, 18)
            row.fixedIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.atlasSizedIcon = row:CreateTexture(nil, "ARTWORK")
            row.atlasSizedIcon:SetSize(22, 22)
            row.atlasSizedIcon:SetPoint("LEFT", row.fixedIcon, "RIGHT", 14, 0)
            row.labelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.labelText:SetPoint("LEFT", row.atlasSizedIcon, "RIGHT", 14, 0)
            row.metadataText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.metadataText:SetPoint("LEFT", row, "LEFT", 430, 0)
            frame.rows[index] = row
        end

        row.atlasName = atlasName
        safe_set_atlas(row.fixedIcon, atlasName, false)
        safe_set_atlas(row.atlasSizedIcon, atlasName, true)
        safe_set_text(row.labelText, atlasName)
        safe_set_text(row.metadataText, atlas_info_text(atlasName))
        if type(row.Show) == "function" then
            row:Show()
        end
    end

    for index = #ATLAS_SAMPLER_CANDIDATES + 1, #frame.rows do
        if type(frame.rows[index]) == "table" and type(frame.rows[index].Hide) == "function" then
            frame.rows[index]:Hide()
        end
    end

    if type(frame.Show) == "function" then
        frame:Show()
    end
    push_chat_line("GBankManager: Atlas sampler opened. After /reload, run /gbm debug atlas and report the labels for the single silver diamond and gold pentagon.")
    return frame
end

local function open_request_wizard(mainFrame)
    if not mainFrame or type(mainFrame.OpenRequestWizard) ~= "function" then
        return
    end

    mainFrame:OpenRequestWizard()
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, function()
            if mainFrame.activeView == "REQUESTS" and type(mainFrame.OpenRequestWizard) == "function" then
                mainFrame:OpenRequestWizard()
            end
        end)
    end
end

local function maybe_open_onboarding(mainFrame, accessProfile, reason)
    if type(mainFrame) ~= "table" or type(mainFrame.OpenOnboarding) ~= "function" then
        return false
    end

    local onboarding = ns.modules.onboarding
    if type(onboarding) ~= "table" or type(onboarding.GetFlowForAccessProfile) ~= "function" then
        return false
    end

    local flowKey = onboarding.GetFlowForAccessProfile(accessProfile)
    if flowKey == nil or type(onboarding.ShouldAutoOpen) ~= "function" then
        return false
    end

    local store = ns.modules.store or ns.data.store
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    if onboarding.ShouldAutoOpen(db, flowKey) ~= true then
        return false
    end

    mainFrame:OpenOnboarding(flowKey, {
        auto = true,
        reason = reason,
    })
    return true
end

local function open_access_ui(mainFrame, accessProfile, requestOnlyOpensWizard, reason)
    if not mainFrame then
        return
    end

    if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
        mainFrame:ShowBlockedAccess("Access blocked")
        return
    end

    if maybe_open_onboarding(mainFrame, accessProfile, reason) then
        return
    end

    if accessProfile == "full_shell" and type(mainFrame.ShowDashboard) == "function" then
        mainFrame:ShowDashboard()
        return
    end

    if type(mainFrame.ShowRequestOnly) == "function" then
        mainFrame:ShowRequestOnly()
        if requestOnlyOpensWizard then
            open_request_wizard(mainFrame)
        end
    end
end

local function open_accessible_ui(reason, requestOnlyOpensWizard)
    local mainFrame = ns.modules.mainFrame
    if type(mainFrame) ~= "table" then
        return
    end

    local auth = ns.modules.auth or ns.modules.permissions
    local store = ns.modules.store or ns.data.store
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    local context = auth and type(auth.GetLivePlayerContext) == "function" and auth.GetLivePlayerContext(db) or {}
    local policy = store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or db.auth
    local accessProfile = auth and type(auth.GetEffectiveAccessProfile) == "function" and auth.GetEffectiveAccessProfile(context, policy) or "full_shell"

    open_access_ui(mainFrame, accessProfile, requestOnlyOpensWizard == true, reason)
end

local function show_help()
    push_chat_line("GBankManager commands:")
    push_chat_line("/gbm - Open the UI you have access to.")
    push_chat_line("/gbm help - Show player-facing commands.")
    push_chat_line("/gbm ui - Open the main addon UI.")
    push_chat_line("/gbm request - Open the request workflow.")
    push_chat_line("/gbm scan - Scan the guild bank and ledger.")
    push_chat_line("/gbm sync [requests/minimums/ledger/all] - Trigger manual sync actions.")
end

local function resolve_crafted_quality_module(existing)
    if type(existing) == "table" and type(existing.DescribeItemResolution) == "function" then
        return existing
    end

    local namespace = _G.GBankManagerNamespace
    local liveModule = namespace and namespace.modules and namespace.modules.craftedQuality or ns.modules.craftedQuality
    if type(liveModule) == "table" and type(liveModule.DescribeItemResolution) == "function" then
        ns.modules.craftedQuality = liveModule
        return liveModule
    end

    if type(_G.dofile) == "function" then
        local loaded = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
        if type(loaded) == "table" and type(loaded.DescribeItemResolution) == "function" then
            ns.modules.craftedQuality = loaded
            return loaded
        end
    end

    return existing
end

_G.SLASH_GBANKMANAGER1 = "/gbm"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.GBANKMANAGER = function(msg)
    local scanner = ns.modules.scanner
    local mainFrame = ns.modules.mainFrame
    local auth = ns.modules.auth or ns.modules.permissions
    local craftedQuality = ns.modules.craftedQuality
    local liveSmoke = ns.modules.liveSmoke
    local inGameUnit = ns.modules.inGameUnit
    local manualActions = ns.modules.syncManualActions
    local store = ns.modules.store or ns.data.store
    local command, remainder = split_command(msg)
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    local context = auth and type(auth.GetLivePlayerContext) == "function" and auth.GetLivePlayerContext(db) or {}
    local policy = store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or db.auth
    local accessProfile = auth and type(auth.GetEffectiveAccessProfile) == "function" and auth.GetEffectiveAccessProfile(context, policy) or "full_shell"

    if command == "help" then
        show_help()
        return "help"
    elseif command == "debug" then
        local subcommand, payload = split_command(remainder)
        if subcommand == "quality" then
            craftedQuality = resolve_crafted_quality_module(craftedQuality)
            local itemID = tonumber(trim(payload or ""))
            if not itemID then
                push_chat_line("GBankManager: Usage: /gbm debug quality <itemID>")
                return "debug_quality_usage"
            end

            if type(craftedQuality) ~= "table" or type(craftedQuality.DescribeItemResolution) ~= "function" then
                push_chat_line("GBankManager: Crafted-quality debug is unavailable right now.")
                return "debug_quality_unavailable"
            end

            local lines = craftedQuality.DescribeItemResolution(itemID, "", 0, 0, "reagent")
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        elseif subcommand == "atlas" then
            return create_or_reset_atlas_sampler()
        elseif subcommand == "render" then
            local itemID = tonumber(trim(payload or ""))
            if not itemID then
                push_chat_line("GBankManager: Usage: /gbm debug render <itemID>")
                return "debug_render_usage"
            end

            local lines = collect_render_debug(mainFrame, itemID)
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        elseif subcommand == "request" then
            local itemID = tonumber(trim(payload or ""))
            if not itemID then
                push_chat_line("GBankManager: Usage: /gbm debug request <itemID>")
                return "debug_request_usage"
            end

            local lines = collect_request_debug(mainFrame, itemID)
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        elseif subcommand == "ledger" then
            local lines = collect_ledger_debug(scanner)
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        elseif subcommand == "sync" then
            local lines = collect_sync_debug(db, context)
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        end
    elseif command == "test" then
        local subcommand = split_command(remainder)
        if subcommand == "smoke" then
            if type(liveSmoke) == "table" and type(liveSmoke.Run) == "function" then
                return liveSmoke.Run()
            end

            push_chat_line("GBankManager smoke test unavailable.")
            return "smoke_test_unavailable"
        elseif subcommand == "unit" then
            if type(inGameUnit) == "table" and type(inGameUnit.Run) == "function" then
                return inGameUnit.Run()
            end

            push_chat_line("GBankManager in-game unit test unavailable.")
            return "unit_test_unavailable"
        end

        push_chat_line("GBankManager unknown test command.")
        return "unknown_test_command"
    elseif command == "sync" then
        local action = trim(remainder or "")
        if action == "" and type(manualActions) == "table" and type(manualActions.ResolveDefaultAction) == "function" then
            action = manualActions.ResolveDefaultAction(accessProfile)
        end

        if type(manualActions) ~= "table" or type(manualActions.Run) ~= "function" then
            push_chat_line("GBankManager: Manual sync is unavailable right now.")
            return "sync_unavailable"
        end

        local result = manualActions.Run(db, {
            action = action,
            accessProfile = accessProfile,
        })
        if type(result) == "table" and tostring(result.message or "") ~= "" then
            push_chat_line(string.format("GBankManager: %s", tostring(result.message)))
        end
        return result
    elseif command == "ui" and mainFrame then
        open_accessible_ui("slash_ui", false)
    elseif command == "request" and mainFrame then
        if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
            mainFrame:ShowBlockedAccess("Access blocked")
        elseif accessProfile == "full_shell" then
            if type(mainFrame.ShowDashboard) == "function" then
                mainFrame:ShowDashboard()
            end
            if type(mainFrame.SelectView) == "function" then
                mainFrame:SelectView("REQUESTS")
            end
            open_request_wizard(mainFrame)
        elseif type(mainFrame.ShowRequestOnly) == "function" then
            mainFrame:ShowRequestOnly()
            open_request_wizard(mainFrame)
        end
    elseif command == "scan" and type(scanner) == "table" then
        scanner.BeginScan()
    elseif command == "" and mainFrame then
        open_accessible_ui("slash_default", false)
    elseif command ~= "" then
        show_help()
        return "unknown_command"
    end
end

slash.command = _G.SlashCmdList.GBANKMANAGER
slash.alias = _G.SLASH_GBANKMANAGER1
slash.OpenAccessibleUI = open_accessible_ui
slash.StartScan = slash.command

ns.modules.slash = slash

return slash
