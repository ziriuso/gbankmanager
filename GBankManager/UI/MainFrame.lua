local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}
local mainTableController = ns.modules.mainTableController or {}
local mainRequestsController = ns.modules.mainRequestsController or {}
local mainExportsController = ns.modules.mainExportsController or {}
local mainMinimumsController = ns.modules.mainMinimumsController or {}
local bankLedger = ns.modules.bankLedger or {}

if type(_G.CreateFrame) ~= "function" then
    ns.modules.mainFrame = ns.modules.mainFrame or {}
    return ns.modules.mainFrame
end

local mainFrame = mainFrameShell.EnsureShell and mainFrameShell.EnsureShell(ns.modules.mainFrame) or ns.modules.mainFrame
local theme = mainFrameShell.GetTheme and mainFrameShell.GetTheme() or (ns.ui.theme or {})
local themeManager = ns.modules.themeManager or {}
local apply_panel_style = mainFrameShell.ApplyPanelStyle
local apply_surface_variant = mainFrameShell.ApplySurfaceVariant or apply_panel_style
local apply_button_variant = mainFrameShell.ApplyButtonVariant or apply_panel_style
local make_label = mainFrameShell.MakeLabel
local make_button = mainFrameShell.MakeButton
local make_checkbox = mainFrameShell.MakeCheckbox
local set_button_icon = mainFrameShell.SetButtonIcon
local make_input = mainFrameShell.MakeInput
local make_slider = mainFrameShell.MakeSlider
local make_slim_scroll_bar = mainFrameShell.MakeSlimScrollBar
local attach_scroll_behavior = mainFrameShell.AttachScrollBehavior
local create_page_overflow_viewport = mainFrameShell.CreatePageOverflowViewport
local set_frame_shown = mainFrameShell.SetFrameShown
local apply_frame_layer = mainFrameShell.ApplyFrameLayer
local bring_frame_to_front = mainFrameShell.BringFrameToFront
local set_surface_alpha = mainFrameShell.SetSurfaceAlpha
local minimapButton = ns.modules.minimapButton or {}

local function current_bank_ledger_view()
    local view = ns.modules.bankLedgerView or {}
    if view.GetColumns == nil and type(_G.dofile) == "function" then
        view = _G.dofile("GBankManager/UI/BankLedgerView.lua") or view
    end
    return view
end

local function parse_number(value)
    local parsed = tonumber(value)
    if not parsed then
        return nil
    end

    return math.floor(parsed)
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copy_list(list)
    local output = {}

    for index, value in ipairs(list or {}) do
        output[index] = value
    end

    return output
end

local function clone_table(value)
    if type(value) ~= "table" then
        return value
    end

    local cloned = {}
    for key, child in pairs(value) do
        cloned[key] = clone_table(child)
    end

    return cloned
end

local function stable_key_list(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function stable_serialize(value)
    local valueType = type(value)
    if valueType ~= "table" then
        return string.format("%s:%s", valueType, tostring(value))
    end

    local parts = { "{" }
    for _, key in ipairs(stable_key_list(value)) do
        parts[#parts + 1] = string.format("[%s]=%s;", tostring(key), stable_serialize(value[key]))
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

local function tables_deep_equal(left, right)
    return stable_serialize(left) == stable_serialize(right)
end

local function clone_export_template(template)
    template = template or {}

    return {
        delimiter = template.delimiter or "|",
        includeHeader = template.includeHeader ~= false,
        fields = (#(template.fields or {}) > 0) and copy_list(template.fields) or { "itemID", "itemName", "totalToBuy" },
    }
end

local function normalize_export_preset_name(presetName)
    if presetName == nil or presetName == "" or presetName == "Spreadsheet" or presetName == "Custom" then
        return "CSV"
    end

    return presetName
end

local function normalize_shopping_list_name(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return "GBankManager"
    end

    return value
end

local function title_case_words(value)
    local words = {}
    for part in tostring(value or ""):gmatch("[^_]+") do
        words[#words + 1] = part:gsub("^%l", string.upper)
    end

    return table.concat(words, " ")
end

local function capability_label(capability)
    if capability == "full_ui" then
        return "Full UI"
    end

    if capability == "auth_manage" then
        return "Auth Manage"
    end

    return title_case_words(capability)
end

local function chain_frame_script(frame, scriptName, callback)
    if type(frame) ~= "table" or type(frame.SetScript) ~= "function" or type(callback) ~= "function" then
        return
    end

    local previous = type(frame.GetScript) == "function" and frame:GetScript(scriptName) or nil
    frame:SetScript(scriptName, function(...)
        if previous then
            previous(...)
        end
        callback(...)
    end)
end

local function set_label_color(label, color)
    if label and type(label.SetTextColor) == "function" and type(color) == "table" then
        label:SetTextColor(unpack(color))
    end
end

local function color_with_alpha(color, alpha)
    local resolved = type(color) == "table" and { unpack(color) } or { 1, 1, 1, 1 }
    if alpha ~= nil then
        resolved[4] = alpha
    elseif resolved[4] == nil then
        resolved[4] = 1
    end
    return resolved
end

local function make_export_output_input(parent, width, height)
    local input = _G.CreateFrame("ScrollFrame", nil, parent, "BackdropTemplate")
    input:SetSize(width, height)
    input.lastCopiedText = nil
    input.highlightStart = nil
    input.highlightEnd = nil
    input.cursorPosition = 0
    input.multiLine = true
    if type(input.EnableMouse) == "function" then
        input:EnableMouse(true)
    end
    if type(input.SetBackdrop) == "function" then
        input:SetBackdrop(nil)
    end

    local editBox = _G.CreateFrame("EditBox", nil, input, "BackdropTemplate")
    input.EditBox = editBox
    editBox:SetPoint("TOPLEFT", input, "TOPLEFT", 0, 0)
    if type(editBox.SetWidth) == "function" then
        editBox:SetWidth(math.max(0, width - 12))
    end
    editBox:SetHeight(math.max(0, height))
    if type(editBox.SetAutoFocus) == "function" then
        editBox:SetAutoFocus(false)
    end
    if type(editBox.SetFontObject) == "function" then
        editBox:SetFontObject("GameFontHighlightSmall")
    end
    if type(editBox.SetTextColor) == "function" then
        editBox:SetTextColor(unpack((theme.colors or {}).accentStrong or { 1, 1, 1, 1 }))
    end
    if type(editBox.EnableMouse) == "function" then
        editBox:EnableMouse(true)
    end
    if type(editBox.SetTextInsets) == "function" then
        editBox:SetTextInsets(0, 0, 0, 0)
    end
    if type(editBox.SetMultiLine) == "function" then
        editBox:SetMultiLine(true)
    else
        function editBox:SetMultiLine(value)
            self.multiLine = value and true or false
        end
    end
    editBox:SetText("")
    input:SetScrollChild(editBox)

    if type(editBox.SetCursorPosition) ~= "function" then
        function editBox:SetCursorPosition(position)
            self.cursorPosition = tonumber(position) or 0
        end
    end

    if type(editBox.HighlightText) ~= "function" then
        function editBox:HighlightText(startIndex, endIndex)
            self.highlightStart = startIndex
            self.highlightEnd = endIndex
        end
    end

    if type(editBox.SetFocus) ~= "function" then
        function editBox:SetFocus()
            self.hasFocus = true
        end
    end

    if type(editBox.HasFocus) ~= "function" then
        function editBox:HasFocus()
            return self.hasFocus == true
        end
    end

    if type(editBox.ClearFocus) ~= "function" then
        function editBox:ClearFocus()
            self.hasFocus = false
        end
    end

    input:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)
    editBox:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)
    editBox:SetScript("OnEscapePressed", function()
        editBox:ClearFocus()
    end)

    function input:SetText(text)
        editBox:SetText(text or "")
    end

    function input:GetText()
        return editBox:GetText()
    end

    function input:SetFocus()
        editBox:SetFocus()
        self.hasFocus = true
    end

    function input:HasFocus()
        return editBox:HasFocus()
    end

    function input:ClearFocus()
        editBox:ClearFocus()
        self.hasFocus = false
    end

    function input:SetCursorPosition(position)
        local normalizedPosition = tonumber(position) or 0
        self.cursorPosition = normalizedPosition
        editBox:SetCursorPosition(normalizedPosition)
    end

    function input:HighlightText(startIndex, endIndex)
        self.highlightStart = startIndex
        self.highlightEnd = endIndex
        editBox:HighlightText(startIndex, endIndex)
    end

    function input:SetTextInsets(left, right, top, bottom)
        if type(editBox.SetTextInsets) == "function" then
            editBox:SetTextInsets(left, right, top, bottom)
        end
    end

    return input
end

local function uses_auctionator_controls(presetName)
    return normalize_export_preset_name(presetName) == "Auctionator"
end

local function uses_custom_export_controls(presetName)
    return normalize_export_preset_name(presetName) == "Custom"
end

local function count_lines(text)
    local lineCount = 1
    text = tostring(text or "")

    for _ in string.gmatch(text, "\n") do
        lineCount = lineCount + 1
    end

    return lineCount
end

local ABBREVIATED_TIMEZONES = {
    ["Eastern Daylight Time"] = "EDT",
    ["Eastern Standard Time"] = "EST",
    ["Central Daylight Time"] = "CDT",
    ["Central Standard Time"] = "CST",
    ["Mountain Daylight Time"] = "MDT",
    ["Mountain Standard Time"] = "MST",
    ["Pacific Daylight Time"] = "PDT",
    ["Pacific Standard Time"] = "PST",
}

local function format_timestamp(timestamp)
    if not timestamp or timestamp == 0 then
        return "No scan yet"
    end

    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) == "function" then
        local baseText = formatter("%Y-%m-%d %H:%M", timestamp)
        local zoneText = formatter("%Z", timestamp)
        zoneText = tostring(zoneText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        zoneText = ABBREVIATED_TIMEZONES[zoneText] or zoneText
        if zoneText ~= "" then
            return string.format("%s %s", baseText, zoneText)
        end
        return baseText
    end

    return tostring(timestamp)
end

local function display_character_key(characterKey)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.DisplayCharacterKey) == "function" then
        return auth.DisplayCharacterKey(characterKey)
    end

    return tostring(characterKey or "")
end

local function auth_metadata_text(policy)
    policy = policy or {}
    local updatedAt = format_timestamp(policy.updatedAt)
    local updatedBy = display_character_key(policy.updatedBy)
    if updatedBy == "" then
        updatedBy = tostring(policy.updatedByHash or "") ~= "" and ("#" .. tostring(policy.updatedByHash or "")) or "Unknown"
    end

    return string.format("Last Update: %s by %s", tostring(updatedAt), tostring(updatedBy))
end

local function build_about_stamp()
    local timestampProvider = type(_G.time) == "function" and _G.time or (type(os) == "table" and type(os.time) == "function" and os.time or nil)
    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    local buildTimestamp = type(timestampProvider) == "function" and timestampProvider() or 0

    if type(formatter) == "function" then
        return formatter("%Y-%m-%d-%H%M%S", buildTimestamp)
    end

    return tostring(buildTimestamp)
end

local ABOUT_BUILD_STAMP = build_about_stamp()
local ABOUT_VERSION = (function()
    local addonName = tostring((ns and ns.addonName) or "GBankManager")
    local getMetadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getMetadata) == "function" then
        local releaseTag = getMetadata(addonName, "X-Release-Tag")
        if tostring(releaseTag or "") ~= "" then
            return tostring(releaseTag)
        end
        local version = getMetadata(addonName, "Version")
        if tostring(version or "") ~= "" then
            return tostring(version)
        end
    end

    return "dev"
end)()

local function apply_table_row_style(rowFrame, rowIndex, isSelected)
    if not rowFrame then
        return
    end

    if isSelected then
        apply_surface_variant(rowFrame, "row-selected")
    else
        apply_surface_variant(rowFrame, rowIndex % 2 == 1 and "row" or "row-alt")
    end

    rowFrame.isSelected = isSelected and true or false
end

local function label_with_sort_marker(columnLayout, sortState)
    local label = (columnLayout and columnLayout.label) or ""
    if not columnLayout or columnLayout.sortable ~= true then
        return label
    end

    if not sortState or sortState.key ~= columnLayout.key then
        return label
    end

    if sortState.direction == "desc" then
        return label .. " v"
    end

    return label .. " ^"
end

local function current_db()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    local runtime = _G.GBankManagerDB or ns.state.db or {}
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function current_appearance_settings(db)
    db = db or current_db()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetAppearanceSettings) == "function" then
        return store.GetAppearanceSettings(db)
    end

    local ui = (db or {}).ui or {}
    ui.appearance = ui.appearance or {
        themePreset = "generic_wow",
        shellScale = 1,
        tableDensity = 1,
        shellOpacity = 0.96,
        modalOpacity = 1,
        showMinimapButton = true,
        minimapAngle = 315,
    }

    if ui.appearance.showMinimapButton == nil then
        ui.appearance.showMinimapButton = true
    end
    ui.appearance.minimapAngle = tonumber(ui.appearance.minimapAngle or 315) or 315

    return ui.appearance
end

local function current_auth_context(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetLivePlayerContext) == "function" then
        return auth.GetLivePlayerContext(db)
    end

    return {}
end

local function current_policy(db)
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetAuthPolicy) == "function" then
        return store.GetAuthPolicy(db)
    end

    return (db or {}).auth or {}
end

local function current_sync_guild_key(db)
    local store = ns.modules.store or ns.data.store
    local root = (ns.state or {}).dbRoot
    local rootGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if rootGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(rootGuildKey)) then
        return rootGuildKey
    end

    local dbGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    if dbGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(dbGuildKey)) then
        return dbGuildKey
    end

    local context = current_auth_context(db)
    return tostring(context.guildName or "Unknown")
end

local function build_sync_peer_rows(db)
    local syncPeerState = ns.modules.syncPeerState or {}
    if type(syncPeerState.GetPeers) ~= "function" then
        return {}
    end

    local rows = {}
    for _, entry in ipairs(syncPeerState.GetPeers(db, current_sync_guild_key(db)) or {}) do
        rows[#rows + 1] = {
            characterKey = tostring(entry.characterKey or ""),
            character = display_character_key(entry.characterKey or "Unknown"),
            lastSeen = format_timestamp(entry.lastSeen),
            lastSynchronized = format_timestamp(entry.lastSynchronizedAt),
            lastMessageType = tostring(entry.lastMessageType or ""),
            version = tostring(entry.version or ""),
        }
    end

    return rows
end

local function can_access(context, capability, policy)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.Can) == "function" then
        return auth.Can(context, capability, policy)
    end

    return true
end

local function actor_summary_text(context)
    local name = tostring((context or {}).name or "Unknown")
    local rankName = tostring((context or {}).guildRankName or "")
    if rankName ~= "" then
        return string.format("%s (%s)", name, rankName)
    end

    return name
end

local function current_access_profile(db)
    local auth = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = current_policy(db)
    if auth and type(auth.GetEffectiveAccessProfile) == "function" then
        return auth.GetEffectiveAccessProfile(context, policy), context
    end

    return "full_shell", context
end

local function request_only_shell(mainFrame)
    return mainFrame.requestOnlyMode == true
end

local function request_only_layout(mainFrame)
    return request_only_shell(mainFrame) and mainFrame.activeView == "REQUESTS"
end

local function request_only_view_allowed(viewKey)
    return viewKey == "REQUESTS" or viewKey == "OPTIONS" or viewKey == "ABOUT"
end

local function normalize_request_only_view(viewKey)
    local normalizedKey = tostring(viewKey or "REQUESTS")
    if request_only_view_allowed(normalizedKey) then
        return normalizedKey
    end

    return "REQUESTS"
end

local function request_only_options_tab_allowed(tabKey)
    return tabKey == "APPEARANCE" or tabKey == "SYNC" or tabKey == "LOGS_HISTORY"
end

local function normalize_request_only_options_tab(tabKey)
    local normalizedKey = tostring(tabKey or "APPEARANCE")
    if request_only_options_tab_allowed(normalizedKey) then
        return normalizedKey
    end

    return "APPEARANCE"
end

local function clamp_range(value, minValue, maxValue)
    value = tonumber(value or minValue) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

local function percent_text(value)
    return string.format("%d%%", math.floor(((tonumber(value or 0) or 0) * 100) + 0.5))
end

local function nearly_equal(left, right)
    return math.abs((tonumber(left or 0) or 0) - (tonumber(right or 0) or 0)) < 0.0001
end

local function nav_icon_texture_for(key)
    local icons = {
        DASHBOARD = "Interface\\ICONS\\icon_treasuremap",
        INVENTORY = "Interface\\ICONS\\item_bastion_paragonchest_01",
        MINIMUMS = "Interface\\ICONS\\inv_10_fishing_dragonislescoins_gold",
        REQUESTS = "Interface\\ICONS\\achievement_guildperk_gmail",
        EXPORTS = "Interface\\ICONS\\achievement_guildperk_fasttrack",
        HISTORY = "Interface\\ICONS\\inv_10_inscription2_book1_color2",
        BANK_LEDGER = "Interface\\ICONS\\inv_misc_stonetablet_04",
        OPTIONS = "Interface\\ICONS\\inv_10_engineering_manufacturedparts_gear_frost",
        ABOUT = "Interface\\ICONS\\inv_misc_scrollunrolled04b",
    }

    return icons[key] or "Interface\\ICONS\\INV_Misc_QuestionMark"
end

mainFrame.collapsedSidebar = mainFrame.collapsedSidebar and true or false

local function set_alpha(nextAlpha)
    mainFrame.currentAlpha = math.max(0.0, math.min(1.0, nextAlpha))
    if type(mainFrame.SetAlpha) == "function" then
        mainFrame:SetAlpha(1)
    end
    if type(mainFrame.ApplyShellOpacity) == "function" then
        mainFrame:ApplyShellOpacity(mainFrame.currentAlpha)
    end
end

local function view_label_for(key)
    if key == "REQUESTS" and mainFrame.requestOnlyMode == true then
        return "Requests"
    end

    for _, item in ipairs(mainFrame.navItems or {}) do
        if item.key == key then
            return item.label
        end
    end

    local normalized = string.lower(tostring(key or "Dashboard"))
    return normalized:gsub("^%l", string.upper)
end

mainFrame.viewTitle = mainFrame.viewTitle or make_label(mainFrame.content, "Dashboard", "GameFontHighlightLarge")
mainFrame.viewTitle:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 24, -24)
mainFrame.viewSubtitle = mainFrame.viewSubtitle or make_label(mainFrame.content, "Critical shortages, pending requests, and export readiness.", "GameFontHighlightSmall")
mainFrame.viewSubtitle:SetPoint("TOPLEFT", mainFrame.viewTitle, "BOTTOMLEFT", 0, -8)
mainFrame.tableViewportWidth = 772
mainFrame.tableViewportInnerWidth = 796
mainFrame.tableHeaderHeight = 34
mainFrame.tableFilterHeight = 28
mainFrame.tableRowHeight = 26
mainFrame.defaultTableViewportHeight = 364
mainFrame.tableViewportHeight = 364
mainFrame.tableVisibleCount = math.floor(mainFrame.tableViewportHeight / mainFrame.tableRowHeight)
mainFrame.selectedRequestId = mainFrame.selectedRequestId or nil
mainFrame.selectedMinimumKey = mainFrame.selectedMinimumKey or nil
mainFrame.selectedMinimumEnabled = mainFrame.selectedMinimumEnabled or false
if mainFrame.minimumShowAllRows == nil then
    mainFrame.minimumShowAllRows = true
end
mainFrame.minimumManualOnlyRows = mainFrame.minimumManualOnlyRows or false
mainFrame.exportSelectedPreset = normalize_export_preset_name(mainFrame.exportSelectedPreset)
mainFrame.exportCustomTemplate = mainFrame.exportCustomTemplate or clone_export_template()
mainFrame.exportShoppingListName = normalize_shopping_list_name(mainFrame.exportShoppingListName)
mainFrame.baseTableHeaderHeight = mainFrame.baseTableHeaderHeight or mainFrame.tableHeaderHeight
mainFrame.baseTableFilterHeight = mainFrame.baseTableFilterHeight or mainFrame.tableFilterHeight
mainFrame.baseTableRowHeight = mainFrame.baseTableRowHeight or mainFrame.tableRowHeight
mainFrame.baseShellWidth = mainFrame.baseShellWidth or (theme.spacing.frameWidth or 1040)
mainFrame.baseShellHeight = mainFrame.baseShellHeight or (theme.spacing.frameHeight or 640)
mainFrame.baseSidebarExpandedWidth = mainFrame.baseSidebarExpandedWidth or (theme.spacing.sidebarExpanded or 212)
mainFrame.baseSidebarCollapsedWidth = mainFrame.baseSidebarCollapsedWidth or (theme.spacing.sidebarCollapsed or 72)
mainFrame.baseTopBarHeight = mainFrame.baseTopBarHeight or (theme.spacing.topBarHeight or 64)
mainFrame.appearanceThemePreset = mainFrame.appearanceThemePreset or "default"
mainFrame.appearanceShellScale = mainFrame.appearanceShellScale or 1
mainFrame.appearanceTableDensity = mainFrame.appearanceTableDensity or 1
mainFrame.appearanceShellOpacity = mainFrame.appearanceShellOpacity or mainFrame.currentAlpha or 0.96
mainFrame.appearanceModalOpacity = mainFrame.appearanceModalOpacity or 1
mainFrame.modalFrames = mainFrame.modalFrames or {}
mainFrame.modalFrameMap = mainFrame.modalFrameMap or {}

function mainFrame:SyncModalFrameLayers()
    for _, entry in ipairs(self.modalFrames or {}) do
        if entry.frame then
            local frameLevel = (tonumber(self.frameLevel or 0) or 0) + (tonumber(entry.levelOffset or 20) or 20)
            if apply_frame_layer then
                apply_frame_layer(entry.frame, entry.strata or "FULLSCREEN_DIALOG", frameLevel)
            else
                entry.frame.frameStrata = entry.strata or "FULLSCREEN_DIALOG"
                entry.frame.frameLevel = frameLevel
            end
        end
    end
end

function mainFrame:RegisterModalFrame(frame, levelOffset, strata)
    if type(frame) ~= "table" then
        return frame
    end

    local entry = self.modalFrameMap[frame]
    if not entry then
        entry = {
            frame = frame,
        }
        table.insert(self.modalFrames, entry)
        self.modalFrameMap[frame] = entry
    end

    entry.levelOffset = tonumber(levelOffset or entry.levelOffset or 20) or 20
    entry.strata = strata or entry.strata or "FULLSCREEN_DIALOG"

    self:SyncModalFrameLayers()

    chain_frame_script(frame, "OnMouseDown", function()
        self:BringToFront(frame)
    end)
    chain_frame_script(frame, "OnShow", function()
        self:BringToFront(frame)
    end)

    return frame
end

function mainFrame:BringToFront(focusFrame)
    local nextLevel = bring_frame_to_front and bring_frame_to_front(self, self.frameStrata or "DIALOG") or (tonumber(self.frameLevel or 40) or 40)
    self.frameLevel = tonumber(nextLevel or self.frameLevel or 40) or 40
    self:SyncModalFrameLayers()

    local entry = focusFrame and self.modalFrameMap and self.modalFrameMap[focusFrame] or nil
    if entry and apply_frame_layer then
        apply_frame_layer(focusFrame, entry.strata or "FULLSCREEN_DIALOG", self.frameLevel + (entry.levelOffset or 20))
    end

    return self.frameLevel
end

chain_frame_script(mainFrame, "OnMouseDown", function(self)
    self:BringToFront()
end)

mainFrame.dashboardCards = mainFrame.dashboardCards or {}
local dashboardCardIcons = {
    "Interface\\ICONS\\INV_Misc_PocketWatch_01",
    "Interface\\ICONS\\INV_Letter_15",
    "Interface\\ICONS\\INV_Crate_03",
    "Interface\\ICONS\\Ability_Creature_Cursed_04",
}
for index = 1, 4 do
    local card = mainFrame.dashboardCards[index] or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    card:SetSize(192, 104)
    apply_panel_style(card, theme.colors.panel)

    card.iconTexture = card.iconTexture or card:CreateTexture()
    card.iconTexture:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -14)
    if type(card.iconTexture.SetSize) == "function" then
        card.iconTexture:SetSize(26, 26)
    end
    if type(card.iconTexture.SetTexture) == "function" then
        card.iconTexture:SetTexture(dashboardCardIcons[index])
    end
    card.iconTexture.texture = dashboardCardIcons[index]

    card.titleText = card.titleText or make_label(card, "", "GameFontHighlight")
    card.titleText:SetPoint("TOPLEFT", card.iconTexture, "TOPRIGHT", 10, 2)
    card.valueText = card.valueText or make_label(card, "", "GameFontNormal")
    card.valueText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -46)
    card.noteText = card.noteText or make_label(card, "", "GameFontHighlightSmall")
    card.noteText:SetPoint("TOPLEFT", card.valueText, "BOTTOMLEFT", 0, -6)
    card.linesText = card.linesText or make_label(card, "", "GameFontNormal")
    card.linesText:SetPoint("TOPLEFT", card.titleText, "BOTTOMLEFT", 0, -8)

    mainFrame.dashboardCards[index] = card
end

mainFrame.dashboardCards[1]:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.dashboardCards[2]:SetPoint("LEFT", mainFrame.dashboardCards[1], "RIGHT", 12, 0)
mainFrame.dashboardCards[3]:SetPoint("LEFT", mainFrame.dashboardCards[2], "RIGHT", 12, 0)
mainFrame.dashboardCards[4]:SetPoint("LEFT", mainFrame.dashboardCards[3], "RIGHT", 12, 0)

mainFrame.dashboardTopItemsPanel = mainFrame.dashboardTopItemsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.dashboardTopItemsPanel:SetPoint("TOPLEFT", mainFrame.dashboardCards[1], "BOTTOMLEFT", 0, -16)
mainFrame.dashboardTopItemsPanel:SetSize(352, 188)
apply_panel_style(mainFrame.dashboardTopItemsPanel, theme.colors.panel)

mainFrame.dashboardTopItemsTitle = mainFrame.dashboardTopItemsTitle or make_label(mainFrame.dashboardTopItemsPanel, "Top 10 Most Used", "GameFontHighlight")
mainFrame.dashboardTopItemsTitle:SetPoint("TOPLEFT", mainFrame.dashboardTopItemsPanel, "TOPLEFT", 16, -14)
mainFrame.dashboardTopItemsText = mainFrame.dashboardTopItemsText or make_label(mainFrame.dashboardTopItemsPanel, "", "GameFontNormal")
mainFrame.dashboardTopItemsText:SetPoint("TOPLEFT", mainFrame.dashboardTopItemsTitle, "BOTTOMLEFT", 0, -10)
if type(mainFrame.dashboardTopItemsText.SetWidth) == "function" then
    mainFrame.dashboardTopItemsText:SetWidth(320)
end

mainFrame.dashboardRecentActivityPanel = mainFrame.dashboardRecentActivityPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.dashboardRecentActivityPanel:SetPoint("TOPLEFT", mainFrame.dashboardTopItemsPanel, "TOPRIGHT", 16, 0)
mainFrame.dashboardRecentActivityPanel:SetPoint("TOPRIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.dashboardRecentActivityPanel:SetHeight(188)
apply_panel_style(mainFrame.dashboardRecentActivityPanel, theme.colors.panel)

mainFrame.dashboardRecentActivityTitle = mainFrame.dashboardRecentActivityTitle or make_label(mainFrame.dashboardRecentActivityPanel, "Recent Activity", "GameFontHighlight")
mainFrame.dashboardRecentActivityTitle:SetPoint("TOPLEFT", mainFrame.dashboardRecentActivityPanel, "TOPLEFT", 16, -14)
mainFrame.dashboardRecentActivityText = mainFrame.dashboardRecentActivityText or make_label(mainFrame.dashboardRecentActivityPanel, "", "GameFontNormal")
mainFrame.dashboardRecentActivityText:SetPoint("TOPLEFT", mainFrame.dashboardRecentActivityTitle, "BOTTOMLEFT", 0, -10)
if type(mainFrame.dashboardRecentActivityText.SetWidth) == "function" then
    mainFrame.dashboardRecentActivityText:SetWidth(420)
end

mainFrame.dashboardQuickActionsPanel = mainFrame.dashboardQuickActionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.dashboardQuickActionsPanel:SetPoint("TOPLEFT", mainFrame.dashboardTopItemsPanel, "BOTTOMLEFT", 0, -16)
mainFrame.dashboardQuickActionsPanel:SetPoint("TOPRIGHT", mainFrame.dashboardRecentActivityPanel, "BOTTOMRIGHT", 0, -16)
mainFrame.dashboardQuickActionsPanel:SetHeight(108)
apply_panel_style(mainFrame.dashboardQuickActionsPanel, theme.colors.panel)

mainFrame.dashboardQuickActionsTitle = mainFrame.dashboardQuickActionsTitle or make_label(mainFrame.dashboardQuickActionsPanel, "Quick Actions", "GameFontHighlight")
mainFrame.dashboardQuickActionsTitle:SetPoint("TOPLEFT", mainFrame.dashboardQuickActionsPanel, "TOPLEFT", 16, -14)

mainFrame.dashboardQuickActionButtons = mainFrame.dashboardQuickActionButtons or {}
local dashboardQuickActionLabels = {
    "Add Minimum",
    "Create Request",
    "Export Data",
}
local dashboardQuickActionIcons = {
    "Interface\\ICONS\\INV_Misc_Note_01",
    "Interface\\ICONS\\INV_Letter_15",
    "Interface\\ICONS\\INV_Scroll_03",
}
for index, label in ipairs(dashboardQuickActionLabels) do
    local button = mainFrame.dashboardQuickActionButtons[index] or make_button(mainFrame.dashboardQuickActionsPanel, 152, 54, label)
    button:SetSize(152, 54)
    if index == 1 then
        button:SetPoint("TOPLEFT", mainFrame.dashboardQuickActionsTitle, "BOTTOMLEFT", 0, -16)
    else
        button:SetPoint("LEFT", mainFrame.dashboardQuickActionButtons[index - 1], "RIGHT", 8, 0)
    end
    button.labelText:SetText(label)
    button.actionIcon = button.actionIcon or button:CreateTexture()
    if type(button.actionIcon.SetSize) == "function" then
        button.actionIcon:SetSize(18, 18)
    end
    if type(button.actionIcon.SetTexture) == "function" then
        button.actionIcon:SetTexture(dashboardQuickActionIcons[index])
    end
    button.actionIcon.texture = dashboardQuickActionIcons[index]
    if type(button.actionIcon.ClearAllPoints) == "function" then
        button.actionIcon:ClearAllPoints()
    end
    button.actionIcon:SetPoint("LEFT", button, "LEFT", 14, 0)
    if button.labelText and type(button.labelText.ClearAllPoints) == "function" then
        button.labelText:ClearAllPoints()
    end
    button.labelText:SetPoint("LEFT", button.actionIcon, "RIGHT", 10, 0)
    if type(button.labelText.SetJustifyH) == "function" then
        button.labelText:SetJustifyH("LEFT")
    end
    if type(button.labelText.SetJustifyV) == "function" then
        button.labelText:SetJustifyV("MIDDLE")
    end
    if type(button.labelText.SetWidth) == "function" then
        button.labelText:SetWidth(104)
    end
    if type(button.labelText.SetWordWrap) == "function" then
        button.labelText:SetWordWrap(true)
    end
    if type(button.labelText.SetMaxLines) == "function" then
        button.labelText:SetMaxLines(2)
    end
    mainFrame.dashboardQuickActionButtons[index] = button
end

mainFrame.dashboardQuickActionButtons[1]:SetScript("OnClick", function()
    mainFrame:SelectView("MINIMUMS")
    if type(mainFrame.OpenMinimumAddModal) == "function" then
        mainFrame:OpenMinimumAddModal()
    end
end)
mainFrame.dashboardQuickActionButtons[2]:SetScript("OnClick", function()
    mainFrame:SelectView("REQUESTS")
    if type(mainFrame.OpenRequestWizard) == "function" then
        mainFrame:OpenRequestWizard()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0, function()
                if mainFrame.activeView == "REQUESTS" and type(mainFrame.OpenRequestWizard) == "function" then
                    mainFrame:OpenRequestWizard()
                end
            end)
        end
    end
end)
mainFrame.dashboardQuickActionButtons[3]:SetScript("OnClick", function()
    mainFrame:SelectView("EXPORTS")
end)
for index = #dashboardQuickActionLabels + 1, #(mainFrame.dashboardQuickActionButtons or {}) do
    if mainFrame.dashboardQuickActionButtons[index] then
        mainFrame.dashboardQuickActionButtons[index]:Hide()
        mainFrame.dashboardQuickActionButtons[index] = nil
    end
end

local function relayout_dashboard_shell(frame)
    if type(frame) ~= "table" then
        return
    end

    local shellScale = tonumber(frame.appearanceShellScale or 1) or 1
    local cardWidth = math.max(172, math.floor(192 * shellScale + 0.5))
    local cardHeight = math.max(94, math.floor(104 * shellScale + 0.5))
    local cardGap = math.max(10, math.floor(12 * shellScale + 0.5))
    local sectionGap = math.max(14, math.floor(16 * shellScale + 0.5))
    local panelWidth = math.max(320, math.floor(352 * shellScale + 0.5))
    local panelHeight = math.max(170, math.floor(188 * shellScale + 0.5))
    local quickActionsHeight = math.max(100, math.floor(108 * shellScale + 0.5))
    local metricInset = math.max(12, math.floor(14 * shellScale + 0.5))
    local iconSize = math.max(24, math.floor(26 * shellScale + 0.5))

    for index, card in ipairs(frame.dashboardCards or {}) do
        card:SetSize(cardWidth, cardHeight)
        if type(card.ClearAllPoints) == "function" then
            card:ClearAllPoints()
        end

        if index == 1 then
            card:SetPoint("TOPLEFT", frame.viewSubtitle, "BOTTOMLEFT", 0, -math.max(20, math.floor(24 * shellScale + 0.5)))
        else
            card:SetPoint("LEFT", frame.dashboardCards[index - 1], "RIGHT", cardGap, 0)
        end

        if card.iconTexture then
            if type(card.iconTexture.ClearAllPoints) == "function" then
                card.iconTexture:ClearAllPoints()
            end
            card.iconTexture:SetPoint("TOPLEFT", card, "TOPLEFT", math.max(10, math.floor(12 * shellScale + 0.5)), -math.max(12, math.floor(14 * shellScale + 0.5)))
            if type(card.iconTexture.SetSize) == "function" then
                card.iconTexture:SetSize(iconSize, iconSize)
            end
        end

        if card.titleText then
            if type(card.titleText.ClearAllPoints) == "function" then
                card.titleText:ClearAllPoints()
            end
            card.titleText:SetPoint("TOPLEFT", card.iconTexture, "TOPRIGHT", math.max(8, math.floor(10 * shellScale + 0.5)), math.floor(2 * shellScale + 0.5))
        end

        if card.valueText then
            if type(card.valueText.ClearAllPoints) == "function" then
                card.valueText:ClearAllPoints()
            end
            card.valueText:SetPoint("TOPLEFT", card, "TOPLEFT", metricInset, -math.max(40, math.floor(46 * shellScale + 0.5)))
        end

        if card.noteText then
            if type(card.noteText.ClearAllPoints) == "function" then
                card.noteText:ClearAllPoints()
            end
            card.noteText:SetPoint("TOPLEFT", card.valueText, "BOTTOMLEFT", 0, -math.max(4, math.floor(6 * shellScale + 0.5)))
        end

        if card.linesText then
            if type(card.linesText.ClearAllPoints) == "function" then
                card.linesText:ClearAllPoints()
            end
            card.linesText:SetPoint("TOPLEFT", card.titleText, "BOTTOMLEFT", 0, -math.max(6, math.floor(8 * shellScale + 0.5)))
        end
    end

    frame.dashboardTopItemsPanel:SetSize(panelWidth, panelHeight)
    if type(frame.dashboardTopItemsPanel.ClearAllPoints) == "function" then
        frame.dashboardTopItemsPanel:ClearAllPoints()
    end
    frame.dashboardTopItemsPanel:SetPoint("TOPLEFT", frame.dashboardCards[1], "BOTTOMLEFT", 0, -sectionGap)

    if type(frame.dashboardTopItemsTitle.ClearAllPoints) == "function" then
        frame.dashboardTopItemsTitle:ClearAllPoints()
    end
    frame.dashboardTopItemsTitle:SetPoint("TOPLEFT", frame.dashboardTopItemsPanel, "TOPLEFT", metricInset, -math.max(12, math.floor(14 * shellScale + 0.5)))

    if type(frame.dashboardTopItemsText.ClearAllPoints) == "function" then
        frame.dashboardTopItemsText:ClearAllPoints()
    end
    frame.dashboardTopItemsText:SetPoint("TOPLEFT", frame.dashboardTopItemsTitle, "BOTTOMLEFT", 0, -math.max(8, math.floor(10 * shellScale + 0.5)))
    if type(frame.dashboardTopItemsText.SetWidth) == "function" then
        frame.dashboardTopItemsText:SetWidth(math.max(280, panelWidth - (metricInset * 2)))
    end

    if type(frame.dashboardRecentActivityPanel.ClearAllPoints) == "function" then
        frame.dashboardRecentActivityPanel:ClearAllPoints()
    end
    frame.dashboardRecentActivityPanel:SetPoint("TOPLEFT", frame.dashboardTopItemsPanel, "TOPRIGHT", sectionGap, 0)
    frame.dashboardRecentActivityPanel:SetPoint("TOPRIGHT", frame.content, "RIGHT", -24, 0)
    frame.dashboardRecentActivityPanel:SetHeight(panelHeight)

    if type(frame.dashboardRecentActivityTitle.ClearAllPoints) == "function" then
        frame.dashboardRecentActivityTitle:ClearAllPoints()
    end
    frame.dashboardRecentActivityTitle:SetPoint("TOPLEFT", frame.dashboardRecentActivityPanel, "TOPLEFT", metricInset, -math.max(12, math.floor(14 * shellScale + 0.5)))

    if type(frame.dashboardRecentActivityText.ClearAllPoints) == "function" then
        frame.dashboardRecentActivityText:ClearAllPoints()
    end
    frame.dashboardRecentActivityText:SetPoint("TOPLEFT", frame.dashboardRecentActivityTitle, "BOTTOMLEFT", 0, -math.max(8, math.floor(10 * shellScale + 0.5)))
    if type(frame.dashboardRecentActivityText.SetWidth) == "function" then
        frame.dashboardRecentActivityText:SetWidth(math.max(360, (frame.dashboardRecentActivityPanel:GetWidth() or 0) - (metricInset * 2)))
    end

    if type(frame.dashboardQuickActionsPanel.ClearAllPoints) == "function" then
        frame.dashboardQuickActionsPanel:ClearAllPoints()
    end
    frame.dashboardQuickActionsPanel:SetPoint("TOPLEFT", frame.dashboardTopItemsPanel, "BOTTOMLEFT", 0, -sectionGap)
    frame.dashboardQuickActionsPanel:SetPoint("TOPRIGHT", frame.dashboardRecentActivityPanel, "BOTTOMRIGHT", 0, -sectionGap)
    frame.dashboardQuickActionsPanel:SetHeight(quickActionsHeight)

    if type(frame.dashboardQuickActionsTitle.ClearAllPoints) == "function" then
        frame.dashboardQuickActionsTitle:ClearAllPoints()
    end
    frame.dashboardQuickActionsTitle:SetPoint("TOPLEFT", frame.dashboardQuickActionsPanel, "TOPLEFT", metricInset, -math.max(12, math.floor(14 * shellScale + 0.5)))
end

mainFrame.aboutPanel = mainFrame.aboutPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.aboutPanel:SetSize(420, 292)
mainFrame.aboutPanel:SetPoint("CENTER", mainFrame.content, "CENTER", 0, -8)
apply_surface_variant(mainFrame.aboutPanel, "panel-alt")
mainFrame.aboutPanel:Hide()

mainFrame.aboutCrestTexture = mainFrame.aboutCrestTexture or mainFrame.aboutPanel:CreateTexture()
mainFrame.aboutCrestTexture:SetPoint("TOP", mainFrame.aboutPanel, "TOP", 0, -24)
if type(mainFrame.aboutCrestTexture.SetSize) == "function" then
    mainFrame.aboutCrestTexture:SetSize(56, 56)
end
    if type(mainFrame.aboutCrestTexture.SetTexture) == "function" then
        mainFrame.aboutCrestTexture:SetTexture(mainFrameShell.GetThemeLogoTexture(mainFrame.appearanceThemePreset or "generic_wow"))
    end
    if type(mainFrame.aboutCrestTexture.SetTexCoord) == "function" then
        mainFrame.aboutCrestTexture:SetTexCoord(unpack(mainFrameShell.GetThemeLogoTexCoord(mainFrame.appearanceThemePreset or "generic_wow")))
    end
    mainFrame.aboutCrestTexture.texture = mainFrameShell.GetThemeLogoTexture(mainFrame.appearanceThemePreset or "generic_wow")

mainFrame.aboutNameText = mainFrame.aboutNameText or make_label(mainFrame.aboutPanel, "Guild Bank Manager", "GameFontHighlightLarge")
mainFrame.aboutNameText:SetPoint("TOP", mainFrame.aboutCrestTexture, "BOTTOM", 0, -12)

mainFrame.aboutVersionText = mainFrame.aboutVersionText or make_label(mainFrame.aboutPanel, "", "GameFontNormal")
mainFrame.aboutVersionText:SetPoint("TOP", mainFrame.aboutNameText, "BOTTOM", 0, -8)

mainFrame.aboutAuthorText = mainFrame.aboutAuthorText or make_label(mainFrame.aboutPanel, "", "GameFontNormal")
mainFrame.aboutAuthorText:SetPoint("TOP", mainFrame.aboutVersionText, "BOTTOM", 0, -8)

mainFrame.aboutGuildText = mainFrame.aboutGuildText or make_label(mainFrame.aboutPanel, "", "GameFontNormal")
mainFrame.aboutGuildText:SetPoint("TOP", mainFrame.aboutAuthorText, "BOTTOM", 0, -18)

mainFrame.aboutDescriptionText = mainFrame.aboutDescriptionText or make_label(mainFrame.aboutPanel, "Manage your guild's stock, requests, and exports with a polished WoW-native workflow.", "GameFontHighlightSmall")
mainFrame.aboutDescriptionText:SetPoint("TOP", mainFrame.aboutGuildText, "BOTTOM", 0, -18)
if type(mainFrame.aboutDescriptionText.SetWidth) == "function" then
    mainFrame.aboutDescriptionText:SetWidth(340)
end
if type(mainFrame.aboutDescriptionText.SetJustifyH) == "function" then
    mainFrame.aboutDescriptionText:SetJustifyH("CENTER")
end

mainFrame.aboutSlashHintText = mainFrame.aboutSlashHintText or make_label(mainFrame.aboutPanel, "/gbm help for slash commands", "GameFontHighlightSmall")
mainFrame.aboutSlashHintText:SetPoint("BOTTOM", mainFrame.aboutPanel, "BOTTOM", 0, 24)

mainFrame.historyDetailsModal = mainFrame.historyDetailsModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.historyDetailsModal:SetSize(520, 332)
mainFrame.historyDetailsModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.historyDetailsModal:EnableMouse(true)
apply_surface_variant(mainFrame.historyDetailsModal, "modal-sheet")
mainFrame.historyDetailsModal:Hide()
mainFrame:RegisterModalFrame(mainFrame.historyDetailsModal, 24, "FULLSCREEN_DIALOG")

mainFrame.historyDetailsTitle = mainFrame.historyDetailsTitle or make_label(mainFrame.historyDetailsModal, "History Details", "GameFontHighlight")
mainFrame.historyDetailsTitle:SetPoint("TOPLEFT", mainFrame.historyDetailsModal, "TOPLEFT", 16, -16)

local function place_history_detail_row(label, value, y)
    label:SetPoint("TOPLEFT", mainFrame.historyDetailsModal, "TOPLEFT", 24, y)
    value:SetPoint("TOPLEFT", mainFrame.historyDetailsModal, "TOPLEFT", 166, y)
end

mainFrame.historyDetailsWhenLabel = mainFrame.historyDetailsWhenLabel or make_label(mainFrame.historyDetailsModal, "When", "GameFontHighlightSmall")
mainFrame.historyDetailsWhenText = mainFrame.historyDetailsWhenText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsWhenLabel, mainFrame.historyDetailsWhenText, -58)

mainFrame.historyDetailsCategoryLabel = mainFrame.historyDetailsCategoryLabel or make_label(mainFrame.historyDetailsModal, "Category", "GameFontHighlightSmall")
mainFrame.historyDetailsCategoryText = mainFrame.historyDetailsCategoryText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsCategoryLabel, mainFrame.historyDetailsCategoryText, -84)

mainFrame.historyDetailsItemLabel = mainFrame.historyDetailsItemLabel or make_label(mainFrame.historyDetailsModal, "Item", "GameFontHighlightSmall")
mainFrame.historyDetailsItemText = mainFrame.historyDetailsItemText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsItemLabel, mainFrame.historyDetailsItemText, -110)

mainFrame.historyDetailsActionLabel = mainFrame.historyDetailsActionLabel or make_label(mainFrame.historyDetailsModal, "Action", "GameFontHighlightSmall")
mainFrame.historyDetailsActionText = mainFrame.historyDetailsActionText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsActionLabel, mainFrame.historyDetailsActionText, -136)

mainFrame.historyDetailsWhoLabel = mainFrame.historyDetailsWhoLabel or make_label(mainFrame.historyDetailsModal, "Who", "GameFontHighlightSmall")
mainFrame.historyDetailsWhoText = mainFrame.historyDetailsWhoText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsWhoLabel, mainFrame.historyDetailsWhoText, -162)

mainFrame.historyDetailsOldValueLabel = mainFrame.historyDetailsOldValueLabel or make_label(mainFrame.historyDetailsModal, "Old Value", "GameFontHighlightSmall")
mainFrame.historyDetailsOldValueText = mainFrame.historyDetailsOldValueText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsOldValueLabel, mainFrame.historyDetailsOldValueText, -204)
if type(mainFrame.historyDetailsOldValueText.SetWidth) == "function" then
    mainFrame.historyDetailsOldValueText:SetWidth(320)
end

mainFrame.historyDetailsNewValueLabel = mainFrame.historyDetailsNewValueLabel or make_label(mainFrame.historyDetailsModal, "New Value", "GameFontHighlightSmall")
mainFrame.historyDetailsNewValueText = mainFrame.historyDetailsNewValueText or make_label(mainFrame.historyDetailsModal, "", "GameFontNormal")
place_history_detail_row(mainFrame.historyDetailsNewValueLabel, mainFrame.historyDetailsNewValueText, -250)
if type(mainFrame.historyDetailsNewValueText.SetWidth) == "function" then
    mainFrame.historyDetailsNewValueText:SetWidth(320)
end

mainFrame.historyDetailsCloseButton = mainFrame.historyDetailsCloseButton or make_button(mainFrame.historyDetailsModal, 72, 28, "Close")
mainFrame.historyDetailsCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.historyDetailsModal, "BOTTOMRIGHT", -16, 16)
mainFrame.historyDetailsCloseButton:SetScript("OnClick", function()
    mainFrame.historyDetailsModal:Hide()
end)

function mainFrame:OpenHistoryDetailsModal(row)
    local details = row and row.details or nil
    if not details then
        return nil
    end

    self.historyDetailsWhenText:SetText(tostring(details.timestamp or "-"))
    self.historyDetailsCategoryText:SetText(tostring(details.category or "-"))
    self.historyDetailsItemText:SetText(tostring(details.itemName or "-"))
    self.historyDetailsActionText:SetText(tostring(details.action or "-"))
    self.historyDetailsWhoText:SetText(tostring(details.actor or "-"))
    self.historyDetailsOldValueText:SetText(tostring(details.oldValue or "-"))
    self.historyDetailsNewValueText:SetText(tostring(details.newValue or "-"))
    self.historyDetailsModal:Show()
    return self.historyDetailsModal
end

mainFrame.ledgerDedupePreviewModal = mainFrame.ledgerDedupePreviewModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.ledgerDedupePreviewModal:SetSize(476, 232)
mainFrame.ledgerDedupePreviewModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.ledgerDedupePreviewModal:EnableMouse(true)
apply_surface_variant(mainFrame.ledgerDedupePreviewModal, "modal-sheet")
mainFrame.ledgerDedupePreviewModal:Hide()
mainFrame:RegisterModalFrame(mainFrame.ledgerDedupePreviewModal, 24, "FULLSCREEN_DIALOG")

mainFrame.ledgerDedupePreviewTitle = mainFrame.ledgerDedupePreviewTitle or make_label(mainFrame.ledgerDedupePreviewModal, "Dedupe Ledger", "GameFontHighlight")
mainFrame.ledgerDedupePreviewTitle:SetPoint("TOPLEFT", mainFrame.ledgerDedupePreviewModal, "TOPLEFT", 16, -16)

mainFrame.ledgerDedupePreviewSummaryText = mainFrame.ledgerDedupePreviewSummaryText or make_label(mainFrame.ledgerDedupePreviewModal, "", "GameFontHighlightSmall")
mainFrame.ledgerDedupePreviewSummaryText:SetPoint("TOPLEFT", mainFrame.ledgerDedupePreviewTitle, "BOTTOMLEFT", 0, -18)
if type(mainFrame.ledgerDedupePreviewSummaryText.SetWidth) == "function" then
    mainFrame.ledgerDedupePreviewSummaryText:SetWidth(436)
end

mainFrame.ledgerDedupePreviewReviewButton = mainFrame.ledgerDedupePreviewReviewButton or make_button(mainFrame.ledgerDedupePreviewModal, 108, 28, "Review Rows")
mainFrame.ledgerDedupePreviewReviewButton:SetPoint("BOTTOMLEFT", mainFrame.ledgerDedupePreviewModal, "BOTTOMLEFT", 16, 16)

mainFrame.ledgerDedupePreviewApplyButton = mainFrame.ledgerDedupePreviewApplyButton or make_button(mainFrame.ledgerDedupePreviewModal, 92, 28, "Clean Up")
mainFrame.ledgerDedupePreviewApplyButton:SetPoint("BOTTOMRIGHT", mainFrame.ledgerDedupePreviewModal, "BOTTOMRIGHT", -96, 16)

mainFrame.ledgerDedupePreviewCancelButton = mainFrame.ledgerDedupePreviewCancelButton or make_button(mainFrame.ledgerDedupePreviewModal, 72, 28, "Cancel")
mainFrame.ledgerDedupePreviewCancelButton:SetPoint("LEFT", mainFrame.ledgerDedupePreviewApplyButton, "RIGHT", 8, 0)

mainFrame.ledgerDedupeReviewModal = mainFrame.ledgerDedupeReviewModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.ledgerDedupeReviewModal:SetSize(724, 436)
mainFrame.ledgerDedupeReviewModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.ledgerDedupeReviewModal:EnableMouse(true)
apply_surface_variant(mainFrame.ledgerDedupeReviewModal, "modal-sheet")
mainFrame.ledgerDedupeReviewModal:Hide()
mainFrame:RegisterModalFrame(mainFrame.ledgerDedupeReviewModal, 24, "FULLSCREEN_DIALOG")

mainFrame.ledgerDedupeReviewTitle = mainFrame.ledgerDedupeReviewTitle or make_label(mainFrame.ledgerDedupeReviewModal, "Ledger Dedupe Review", "GameFontHighlight")
mainFrame.ledgerDedupeReviewTitle:SetPoint("TOPLEFT", mainFrame.ledgerDedupeReviewModal, "TOPLEFT", 16, -16)

mainFrame.ledgerDedupeReviewHintText = mainFrame.ledgerDedupeReviewHintText or make_label(mainFrame.ledgerDedupeReviewModal, "Review the duplicate rows that will be removed. Item cleanup keeps the first same-minute row; money cleanup keeps a source-stable matching visible ledger row when available.", "GameFontHighlightSmall")
mainFrame.ledgerDedupeReviewHintText:SetPoint("TOPLEFT", mainFrame.ledgerDedupeReviewTitle, "BOTTOMLEFT", 0, -12)
if type(mainFrame.ledgerDedupeReviewHintText.SetWidth) == "function" then
    mainFrame.ledgerDedupeReviewHintText:SetWidth(684)
end

mainFrame.ledgerDedupeReviewOutput = mainFrame.ledgerDedupeReviewOutput or make_export_output_input(mainFrame.ledgerDedupeReviewModal, 684, 286)
mainFrame.ledgerDedupeReviewOutput:SetPoint("TOPLEFT", mainFrame.ledgerDedupeReviewHintText, "BOTTOMLEFT", 0, -14)
mainFrame.ledgerDedupeReviewOutput:SetTextInsets(4, 4, 4, 4)

mainFrame.ledgerDedupeReviewScrollBar = mainFrame.ledgerDedupeReviewScrollBar or make_slim_scroll_bar(mainFrame.ledgerDedupeReviewModal, 14)
if type(mainFrame.ledgerDedupeReviewScrollBar.ClearAllPoints) == "function" then
    mainFrame.ledgerDedupeReviewScrollBar:ClearAllPoints()
end
mainFrame.ledgerDedupeReviewScrollBar:SetPoint("TOPLEFT", mainFrame.ledgerDedupeReviewOutput, "TOPRIGHT", 4, 0)
mainFrame.ledgerDedupeReviewScrollBar:SetPoint("BOTTOMLEFT", mainFrame.ledgerDedupeReviewOutput, "BOTTOMRIGHT", 4, 0)
mainFrame.ledgerDedupeReviewScrollController = mainFrame.ledgerDedupeReviewScrollController
    or (type(attach_scroll_behavior) == "function" and attach_scroll_behavior(mainFrame.ledgerDedupeReviewOutput, mainFrame.ledgerDedupeReviewScrollBar, {
        wheelStep = 24,
    }))
set_frame_shown(mainFrame.ledgerDedupeReviewScrollBar, false)

mainFrame.ledgerDedupeReviewBackButton = mainFrame.ledgerDedupeReviewBackButton or make_button(mainFrame.ledgerDedupeReviewModal, 72, 28, "Back")
mainFrame.ledgerDedupeReviewBackButton:SetPoint("BOTTOMLEFT", mainFrame.ledgerDedupeReviewModal, "BOTTOMLEFT", 16, 16)

mainFrame.ledgerDedupeReviewApplyButton = mainFrame.ledgerDedupeReviewApplyButton or make_button(mainFrame.ledgerDedupeReviewModal, 92, 28, "Clean Up")
mainFrame.ledgerDedupeReviewApplyButton:SetPoint("BOTTOMRIGHT", mainFrame.ledgerDedupeReviewModal, "BOTTOMRIGHT", -96, 16)

mainFrame.ledgerDedupeReviewCancelButton = mainFrame.ledgerDedupeReviewCancelButton or make_button(mainFrame.ledgerDedupeReviewModal, 72, 28, "Cancel")
mainFrame.ledgerDedupeReviewCancelButton:SetPoint("LEFT", mainFrame.ledgerDedupeReviewApplyButton, "RIGHT", 8, 0)

mainFrame.bankLedgerMode = mainFrame.bankLedgerMode or "ITEM"
mainFrame.bankLedgerActionFilter = mainFrame.bankLedgerActionFilter or ""

mainFrame.bankLedgerPanel = mainFrame.bankLedgerPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.bankLedgerPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.bankLedgerPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.bankLedgerPanel:SetHeight(116)
apply_surface_variant(mainFrame.bankLedgerPanel, "panel-flat")
if type(mainFrame.bankLedgerPanel.SetBackdrop) == "function" then
    mainFrame.bankLedgerPanel:SetBackdrop(nil)
end
mainFrame.bankLedgerPanel:Hide()

mainFrame.inventoryPanel = mainFrame.inventoryPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.inventoryPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.inventoryPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.inventoryPanel:SetHeight(56)
apply_surface_variant(mainFrame.inventoryPanel, "panel-flat")
if type(mainFrame.inventoryPanel.SetBackdrop) == "function" then
    mainFrame.inventoryPanel:SetBackdrop(nil)
end
mainFrame.inventoryPanel:Hide()

mainFrame.inventoryExportButton = mainFrame.inventoryExportButton or make_button(mainFrame.inventoryPanel, 88, 24, "Export CSV")
mainFrame.inventoryExportButton:SetPoint("RIGHT", mainFrame.inventoryPanel, "RIGHT", -16, 0)

mainFrame.bankLedgerItemModeButton = mainFrame.bankLedgerItemModeButton or make_button(mainFrame.bankLedgerPanel, 84, 24, "Item Log")
mainFrame.bankLedgerItemModeButton:SetPoint("TOPLEFT", mainFrame.bankLedgerPanel, "TOPLEFT", 16, -14)

mainFrame.bankLedgerMoneyModeButton = mainFrame.bankLedgerMoneyModeButton or make_button(mainFrame.bankLedgerPanel, 92, 24, "Money Log")
mainFrame.bankLedgerMoneyModeButton:SetPoint("LEFT", mainFrame.bankLedgerItemModeButton, "RIGHT", 8, 0)

mainFrame.bankLedgerActionFilterTitle = mainFrame.bankLedgerActionFilterTitle or make_label(mainFrame.bankLedgerPanel, "Action", "GameFontHighlightSmall")
mainFrame.bankLedgerActionFilterTitle:SetPoint("LEFT", mainFrame.bankLedgerMoneyModeButton, "RIGHT", 20, 0)

mainFrame.bankLedgerActionFilterButton = mainFrame.bankLedgerActionFilterButton or make_button(mainFrame.bankLedgerPanel, 112, 24, "All Actions")
mainFrame.bankLedgerActionFilterButton:SetPoint("LEFT", mainFrame.bankLedgerActionFilterTitle, "RIGHT", 8, 0)

mainFrame.bankLedgerDateRangeTitle = mainFrame.bankLedgerDateRangeTitle or make_label(mainFrame.bankLedgerPanel, "Date Range", "GameFontHighlightSmall")
mainFrame.bankLedgerDateRangeTitle:SetPoint("LEFT", mainFrame.bankLedgerActionFilterButton, "RIGHT", 20, 0)

mainFrame.bankLedgerDateRangeButton = mainFrame.bankLedgerDateRangeButton or make_button(mainFrame.bankLedgerPanel, 108, 24, "All")
mainFrame.bankLedgerDateRangeButton:SetPoint("LEFT", mainFrame.bankLedgerDateRangeTitle, "RIGHT", 8, 0)

mainFrame.bankLedgerExportButton = mainFrame.bankLedgerExportButton or make_button(mainFrame.bankLedgerPanel, 88, 24, "Export CSV")
mainFrame.bankLedgerExportButton:SetPoint("RIGHT", mainFrame.bankLedgerPanel, "RIGHT", -16, 0)

mainFrame.bankLedgerSummaryPrimaryText = mainFrame.bankLedgerSummaryPrimaryText or make_label(mainFrame.bankLedgerPanel, "", "GameFontHighlightSmall")
mainFrame.bankLedgerSummaryPrimaryText:SetPoint("TOPLEFT", mainFrame.bankLedgerPanel, "TOPLEFT", 16, -52)
if type(mainFrame.bankLedgerSummaryPrimaryText.SetWidth) == "function" then
    mainFrame.bankLedgerSummaryPrimaryText:SetWidth(760)
end

mainFrame.bankLedgerSummarySecondaryText = mainFrame.bankLedgerSummarySecondaryText or make_label(mainFrame.bankLedgerPanel, "", "GameFontHighlightSmall")
mainFrame.bankLedgerSummarySecondaryText:SetPoint("TOPLEFT", mainFrame.bankLedgerSummaryPrimaryText, "BOTTOMLEFT", 0, -6)
if type(mainFrame.bankLedgerSummarySecondaryText.SetWidth) == "function" then
    mainFrame.bankLedgerSummarySecondaryText:SetWidth(760)
end

mainFrame.bankLedgerSummaryTertiaryText = mainFrame.bankLedgerSummaryTertiaryText or make_label(mainFrame.bankLedgerPanel, "", "GameFontHighlightSmall")
mainFrame.bankLedgerSummaryTertiaryText:SetPoint("TOPLEFT", mainFrame.bankLedgerSummarySecondaryText, "BOTTOMLEFT", 0, -6)
if type(mainFrame.bankLedgerSummaryTertiaryText.SetWidth) == "function" then
    mainFrame.bankLedgerSummaryTertiaryText:SetWidth(760)
end

mainTableController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    makeSlimScrollBar = make_slim_scroll_bar,
    createTableOverflowViewport = mainFrameShell.CreateTableOverflowViewport,
    attachScrollBehavior = mainFrameShell.AttachScrollBehavior,
    theme = theme,
    labelWithSortMarker = label_with_sort_marker,
    applyTableRowStyle = apply_table_row_style,
    usesInlineFilters = function(frame)
        return frame.activeView == "INVENTORY"
            or frame.activeView == "MINIMUMS"
            or frame.activeView == "HISTORY"
            or frame.activeView == "BANK_LEDGER"
            or (frame.activeView == "REQUESTS" and frame.requestOnlyMode ~= true)
    end,
    getActiveSortState = function(frame)
        return frame:GetActiveSortState()
    end,
    isSelectedTableRow = function(frame, row)
        return frame:IsSelectedTableRow(row)
    end,
    handleTableRowClick = function(frame, row)
        return frame:HandleTableRowClick(row)
    end,
    syncMinimumInlineRow = function(frame, rowFrame, row, rowIndex)
        return frame:SyncMinimumInlineRow(rowFrame, row, rowIndex)
    end,
    hideMinimumInlineRow = function(frame, rowFrame)
        return frame:HideMinimumInlineRow(rowFrame)
    end,
})

mainRequestsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    createItemSearchSelector = mainFrameShell.CreateItemSearchSelector,
    theme = theme,
    parseNumber = parse_number,
})

mainExportsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    makeExportOutputInput = make_export_output_input,
    theme = theme,
    setFrameShown = set_frame_shown,
    normalizeExportPresetName = normalize_export_preset_name,
    normalizeShoppingListName = normalize_shopping_list_name,
    cloneExportTemplate = clone_export_template,
    countLines = count_lines,
    currentDb = current_db,
})

mainMinimumsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    makeExportOutputInput = make_export_output_input,
    createItemSearchSelector = mainFrameShell.CreateItemSearchSelector,
    setButtonIcon = set_button_icon,
    parseNumber = parse_number,
    currentDb = current_db,
    applyTableRowStyle = apply_table_row_style,
    theme = theme,
})

mainFrame.contentBodyText = mainFrame.contentBodyText or make_label(mainFrame.content, "", "GameFontNormal")
mainFrame.contentBodyText:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)

mainFrame.minimumEmptyStateText = mainFrame.minimumEmptyStateText or make_label(mainFrame.content, "", "GameFontHighlightSmall")
mainFrame.minimumEmptyStateText:SetPoint("TOPLEFT", mainFrame.tableScrollFrame, "TOPLEFT", 12, -12)
mainFrame.minimumEmptyStateText:Hide()

mainFrame.optionsPanel = mainFrame.optionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.optionsPanel:SetPoint("BOTTOMRIGHT", mainFrame.content, "BOTTOMRIGHT", -24, 0)
apply_surface_variant(mainFrame.optionsPanel, "panel")
mainFrame.optionsPanel:Hide()

mainFrame.optionsTabBar = mainFrame.optionsTabBar or _G.CreateFrame("Frame", nil, mainFrame.optionsPanel, "BackdropTemplate")
mainFrame.optionsTabBar:SetPoint("TOPLEFT", mainFrame.optionsPanel, "TOPLEFT", 16, -14)
mainFrame.optionsTabBar:SetPoint("TOPRIGHT", mainFrame.optionsPanel, "TOPRIGHT", -44, -14)
mainFrame.optionsTabBar:SetHeight(30)
apply_surface_variant(mainFrame.optionsTabBar, "panel")

mainFrame.optionsScrollUpButton = nil
mainFrame.optionsScrollDownButton = nil
mainFrame.optionsScrollStatusText = nil
local optionsOverflow = create_page_overflow_viewport and create_page_overflow_viewport(mainFrame.optionsPanel, {
    viewportFrame = mainFrame.optionsViewportFrame,
    scrollFrame = mainFrame.optionsScrollFrame,
    scrollChild = mainFrame.optionsScrollChild,
    scrollBar = mainFrame.optionsScrollBar,
    controllerOptions = {
        wheelStep = 24,
    },
}) or nil
mainFrame.optionsViewportFrame = optionsOverflow and optionsOverflow.viewportFrame or mainFrame.optionsViewportFrame
mainFrame.optionsScrollFrame = optionsOverflow and optionsOverflow.scrollFrame or mainFrame.optionsScrollFrame
mainFrame.optionsScrollChild = optionsOverflow and optionsOverflow.scrollChild or mainFrame.optionsScrollChild
mainFrame.optionsScrollBar = optionsOverflow and optionsOverflow.scrollBar or (mainFrame.optionsScrollBar or make_slim_scroll_bar(mainFrame.optionsPanel, 14))
mainFrame.optionsScrollController = optionsOverflow and optionsOverflow.controller or mainFrame.optionsScrollController
if type(mainFrame.optionsViewportFrame.ClearAllPoints) == "function" then
    mainFrame.optionsViewportFrame:ClearAllPoints()
end
mainFrame.optionsViewportFrame:SetPoint("TOPLEFT", mainFrame.optionsTabBar, "BOTTOMLEFT", 0, -12)
mainFrame.optionsViewportFrame:SetPoint("BOTTOMRIGHT", mainFrame.optionsPanel, "BOTTOMRIGHT", -24, 16)

mainFrame.optionsTabButtons = mainFrame.optionsTabButtons or {}
mainFrame.optionsTabOrder = {
    { key = "APPEARANCE", label = "Appearance" },
    { key = "STOCK", label = "Stock Settings" },
    { key = "PERMISSIONS", label = "Permissions" },
    { key = "BLACKLIST", label = "Blacklist" },
    { key = "SYNC", label = "Sync" },
    { key = "LOGS_HISTORY", label = "Data" },
}
for index, item in ipairs(mainFrame.optionsTabOrder) do
    local buttonWidth = item.key == "STOCK" and 118 or (item.key == "LOGS_HISTORY" and 108 or (item.key == "SYNC" and 88 or 94))
    local button = mainFrame.optionsTabButtons[index] or make_button(mainFrame.optionsTabBar, buttonWidth, 24, item.label)
    button:SetWidth(buttonWidth)
    button.key = item.key
    button.labelText:SetText(item.label)
    if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
    end
    if index == 1 then
        button:SetPoint("TOPLEFT", mainFrame.optionsTabBar, "TOPLEFT", 0, 0)
    else
        button:SetPoint("LEFT", mainFrame.optionsTabButtons[index - 1], "RIGHT", 8, 0)
    end
    mainFrame.optionsTabButtons[index] = button
end
for index = #mainFrame.optionsTabOrder + 1, #(mainFrame.optionsTabButtons or {}) do
    if mainFrame.optionsTabButtons[index] then
        mainFrame.optionsTabButtons[index]:Hide()
        mainFrame.optionsTabButtons[index] = nil
    end
end

mainFrame.optionsActiveTab = mainFrame.optionsActiveTab or "APPEARANCE"

mainFrame.optionsAppearancePanel = mainFrame.optionsAppearancePanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsAppearancePanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsAppearancePanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsAppearancePanel:SetHeight(404)
apply_surface_variant(mainFrame.optionsAppearancePanel, "panel-alt")

mainFrame.optionsStockSettingsPanel = mainFrame.optionsStockSettingsPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsStockSettingsPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsStockSettingsPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsStockSettingsPanel:SetHeight(176)
apply_surface_variant(mainFrame.optionsStockSettingsPanel, "panel-alt")

mainFrame.optionsAuthPanel = mainFrame.optionsAuthPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsAuthPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsAuthPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsAuthPanel:SetHeight(560)
apply_surface_variant(mainFrame.optionsAuthPanel, "panel")

mainFrame.optionsPermissionsPanel = mainFrame.optionsPermissionsPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsPermissionsPanel:SetPoint("TOPLEFT", mainFrame.optionsAuthPanel, "TOPLEFT", 0, 0)
mainFrame.optionsPermissionsPanel:SetPoint("TOPRIGHT", mainFrame.optionsAuthPanel, "TOPRIGHT", 0, 0)
mainFrame.optionsPermissionsPanel:SetHeight(392)
apply_surface_variant(mainFrame.optionsPermissionsPanel, "panel-alt")

mainFrame.optionsBlacklistPanel = mainFrame.optionsBlacklistPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsBlacklistPanel:SetPoint("TOPLEFT", mainFrame.optionsAuthPanel, "TOPLEFT", 0, 0)
mainFrame.optionsBlacklistPanel:SetPoint("TOPRIGHT", mainFrame.optionsAuthPanel, "TOPRIGHT", 0, 0)
mainFrame.optionsBlacklistPanel:SetHeight(390)
apply_surface_variant(mainFrame.optionsBlacklistPanel, "panel-alt")

mainFrame.optionsLogsHistoryPanel = mainFrame.optionsLogsHistoryPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsLogsHistoryPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsLogsHistoryPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsLogsHistoryPanel:SetHeight(492)
apply_surface_variant(mainFrame.optionsLogsHistoryPanel, "panel-alt")

mainFrame.optionsSyncPanel = mainFrame.optionsSyncPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsSyncPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsSyncPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsSyncPanel:SetHeight(360)
apply_surface_variant(mainFrame.optionsSyncPanel, "panel-alt")

mainFrame.optionsAutomationPanel = mainFrame.optionsAutomationPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsAutomationPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsAutomationPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsAutomationPanel:SetHeight(180)
apply_surface_variant(mainFrame.optionsAutomationPanel, "panel-alt")

mainFrame.optionsExportsPanel = mainFrame.optionsExportsPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsExportsPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsExportsPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsExportsPanel:SetHeight(180)
apply_surface_variant(mainFrame.optionsExportsPanel, "panel-alt")

mainFrame.optionsRequestsPanel = mainFrame.optionsRequestsPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsRequestsPanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsRequestsPanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsRequestsPanel:SetHeight(180)
apply_surface_variant(mainFrame.optionsRequestsPanel, "panel-alt")

mainFrame.optionsTitle = mainFrame.optionsTitle or make_label(mainFrame.optionsAppearancePanel, "Appearance", "GameFontHighlight")
mainFrame.optionsTitle:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "TOPLEFT", 16, -16)

mainFrame.optionsHint = mainFrame.optionsHint or make_label(mainFrame.optionsAppearancePanel, "Theme presets stay local, UI scale keeps the shell and shared table density aligned, and the minimap launcher stays optional per character.", "GameFontHighlightSmall")
mainFrame.optionsHint:SetPoint("TOPLEFT", mainFrame.optionsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.optionsThemePresetLabel = mainFrame.optionsThemePresetLabel or make_label(mainFrame.optionsAppearancePanel, "Theme Preset", "GameFontHighlightSmall")
mainFrame.optionsThemePresetLabel:SetPoint("TOPLEFT", mainFrame.optionsHint, "BOTTOMLEFT", 0, -14)

mainFrame.optionsThemeButtons = mainFrame.optionsThemeButtons or {}
local themePresetOrder = type(mainFrameShell.GetThemePresetOrder) == "function" and mainFrameShell.GetThemePresetOrder() or { "generic_wow", "high_contrast", "alliance", "horde", "legion", "nature", "pride", "void" }
local themePresets = type(mainFrameShell.GetThemePresets) == "function" and mainFrameShell.GetThemePresets() or {}
local themeButtonLayout = {
    generic_wow = { width = 72, row = 1 },
    high_contrast = { width = 104, row = 1 },
    alliance = { width = 80, row = 1 },
    horde = { width = 68, row = 2 },
    legion = { width = 72, row = 2 },
    nature = { width = 74, row = 2 },
    pride = { width = 64, row = 3 },
    void = { width = 64, row = 3 },
}
local themeButtonRowAnchors = {}
local lastThemeButtonByRow = {}
for _, presetKey in ipairs(themePresetOrder) do
    local preset = themePresets[presetKey] or {}
    local buttonLayout = themeButtonLayout[presetKey] or { width = 80, row = 1 }
    local button = mainFrame.optionsThemeButtons[presetKey] or make_button(mainFrame.optionsAppearancePanel, buttonLayout.width, 24, preset.label or tostring(presetKey))
    button:SetWidth(buttonLayout.width)
    button.labelText:SetText(preset.label or tostring(presetKey))
    button:ClearAllPoints()
    if lastThemeButtonByRow[buttonLayout.row] == nil then
        if buttonLayout.row == 1 then
            button:SetPoint("TOPLEFT", mainFrame.optionsThemePresetLabel, "BOTTOMLEFT", 0, -6)
        else
            button:SetPoint("TOPLEFT", themeButtonRowAnchors[buttonLayout.row - 1], "BOTTOMLEFT", 0, -8)
        end
    else
        button:SetPoint("LEFT", lastThemeButtonByRow[buttonLayout.row], "RIGHT", 8, 0)
    end
    mainFrame.optionsThemeButtons[presetKey] = button
    themeButtonRowAnchors[buttonLayout.row] = themeButtonRowAnchors[buttonLayout.row] or button
    lastThemeButtonByRow[buttonLayout.row] = button
end
mainFrame.optionsThemeDefaultButton = mainFrame.optionsThemeButtons.generic_wow
mainFrame.optionsThemeContrastButton = mainFrame.optionsThemeButtons.high_contrast
mainFrame.optionsThemeWarmButton = mainFrame.optionsThemeButtons.nature
mainFrame.optionsThemeFelButton = mainFrame.optionsThemeButtons.legion
mainFrame.optionsThemePrideButton = mainFrame.optionsThemeButtons.pride

mainFrame.optionsShellScaleLabel = mainFrame.optionsShellScaleLabel or make_label(mainFrame.optionsAppearancePanel, "UI Scale", "GameFontHighlightSmall")
mainFrame.optionsShellScaleLabel:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "TOPLEFT", 408, -54)

mainFrame.optionsShellScaleDecreaseButton = mainFrame.optionsShellScaleDecreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "-")
mainFrame.optionsShellScaleDecreaseButton:SetPoint("TOPLEFT", mainFrame.optionsShellScaleLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsShellScaleSlider = mainFrame.optionsShellScaleSlider or make_slider(mainFrame.optionsAppearancePanel, 160, 18, 0.9, 1.2, 1)
mainFrame.optionsShellScaleSlider:SetPoint("LEFT", mainFrame.optionsShellScaleDecreaseButton, "RIGHT", 8, 0)
if type(mainFrame.optionsShellScaleSlider.SetValueStep) == "function" then
    mainFrame.optionsShellScaleSlider:SetValueStep(0.05)
end
if type(mainFrame.optionsShellScaleSlider.SetObeyStepOnDrag) == "function" then
    mainFrame.optionsShellScaleSlider:SetObeyStepOnDrag(true)
end

mainFrame.optionsShellScaleIncreaseButton = mainFrame.optionsShellScaleIncreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "+")
mainFrame.optionsShellScaleIncreaseButton:SetPoint("LEFT", mainFrame.optionsShellScaleSlider, "RIGHT", 8, 0)

mainFrame.optionsShellScaleValueText = mainFrame.optionsShellScaleValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.optionsShellScaleValueText:SetPoint("TOPLEFT", mainFrame.optionsShellScaleDecreaseButton, "BOTTOMLEFT", 0, -6)

mainFrame.optionsTableDensityLabel = mainFrame.optionsTableDensityLabel or make_label(mainFrame.optionsAppearancePanel, "Table Density (Linked)", "GameFontHighlightSmall")
mainFrame.optionsTableDensityLabel:SetPoint("TOPLEFT", mainFrame.optionsShellScaleDecreaseButton, "BOTTOMLEFT", 0, -12)

mainFrame.optionsTableDensityDecreaseButton = mainFrame.optionsTableDensityDecreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "-")
mainFrame.optionsTableDensityDecreaseButton:SetPoint("TOPLEFT", mainFrame.optionsTableDensityLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsTableDensitySlider = mainFrame.optionsTableDensitySlider or make_slider(mainFrame.optionsAppearancePanel, 180, 18, 0.9, 1.2, 1)
mainFrame.optionsTableDensitySlider:SetPoint("LEFT", mainFrame.optionsTableDensityDecreaseButton, "RIGHT", 8, 0)
if type(mainFrame.optionsTableDensitySlider.SetValueStep) == "function" then
    mainFrame.optionsTableDensitySlider:SetValueStep(0.05)
end

mainFrame.optionsTableDensityIncreaseButton = mainFrame.optionsTableDensityIncreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "+")
mainFrame.optionsTableDensityIncreaseButton:SetPoint("LEFT", mainFrame.optionsTableDensitySlider, "RIGHT", 8, 0)

mainFrame.optionsTableDensityValueText = mainFrame.optionsTableDensityValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.optionsTableDensityValueText:SetPoint("LEFT", mainFrame.optionsTableDensityIncreaseButton, "RIGHT", 8, 0)
set_frame_shown(mainFrame.optionsTableDensityLabel, false)
set_frame_shown(mainFrame.optionsTableDensityDecreaseButton, false)
set_frame_shown(mainFrame.optionsTableDensitySlider, false)
set_frame_shown(mainFrame.optionsTableDensityIncreaseButton, false)
set_frame_shown(mainFrame.optionsTableDensityValueText, false)

mainFrame.optionsShellOpacityLabel = mainFrame.optionsShellOpacityLabel or make_label(mainFrame.optionsAppearancePanel, "Shell Opacity", "GameFontHighlightSmall")
mainFrame.optionsShellOpacityLabel:SetPoint("TOPLEFT", mainFrame.optionsShellScaleValueText, "BOTTOMLEFT", 0, -14)

mainFrame.optionsShellOpacityDecreaseButton = mainFrame.optionsShellOpacityDecreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "-")
mainFrame.optionsShellOpacityDecreaseButton:SetPoint("TOPLEFT", mainFrame.optionsShellOpacityLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsShellOpacitySlider = mainFrame.optionsShellOpacitySlider or make_slider(mainFrame.optionsAppearancePanel, 160, 18, 0.0, 1.0, 0.96)
mainFrame.optionsShellOpacitySlider:SetPoint("LEFT", mainFrame.optionsShellOpacityDecreaseButton, "RIGHT", 8, 0)
if type(mainFrame.optionsShellOpacitySlider.SetValueStep) == "function" then
    mainFrame.optionsShellOpacitySlider:SetValueStep(0.01)
end
if type(mainFrame.optionsShellOpacitySlider.SetObeyStepOnDrag) == "function" then
    mainFrame.optionsShellOpacitySlider:SetObeyStepOnDrag(true)
end

mainFrame.optionsShellOpacityIncreaseButton = mainFrame.optionsShellOpacityIncreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "+")
mainFrame.optionsShellOpacityIncreaseButton:SetPoint("LEFT", mainFrame.optionsShellOpacitySlider, "RIGHT", 8, 0)

mainFrame.optionsShellOpacityValueText = mainFrame.optionsShellOpacityValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.optionsShellOpacityValueText:SetPoint("TOPLEFT", mainFrame.optionsShellOpacityDecreaseButton, "BOTTOMLEFT", 0, -6)

mainFrame.optionsModalOpacityLabel = mainFrame.optionsModalOpacityLabel or make_label(mainFrame.optionsAppearancePanel, "Modal Opacity", "GameFontHighlightSmall")
mainFrame.optionsModalOpacityLabel:SetPoint("TOPLEFT", mainFrame.optionsShellOpacityValueText, "BOTTOMLEFT", 0, -14)

mainFrame.optionsModalOpacityDecreaseButton = mainFrame.optionsModalOpacityDecreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "-")
mainFrame.optionsModalOpacityDecreaseButton:SetPoint("TOPLEFT", mainFrame.optionsModalOpacityLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsModalOpacitySlider = mainFrame.optionsModalOpacitySlider or make_slider(mainFrame.optionsAppearancePanel, 160, 18, 0.0, 1.0, 1)
mainFrame.optionsModalOpacitySlider:SetPoint("LEFT", mainFrame.optionsModalOpacityDecreaseButton, "RIGHT", 8, 0)
if type(mainFrame.optionsModalOpacitySlider.SetValueStep) == "function" then
    mainFrame.optionsModalOpacitySlider:SetValueStep(0.01)
end
if type(mainFrame.optionsModalOpacitySlider.SetObeyStepOnDrag) == "function" then
    mainFrame.optionsModalOpacitySlider:SetObeyStepOnDrag(true)
end

mainFrame.optionsModalOpacityIncreaseButton = mainFrame.optionsModalOpacityIncreaseButton or make_button(mainFrame.optionsAppearancePanel, 24, 22, "+")
mainFrame.optionsModalOpacityIncreaseButton:SetPoint("LEFT", mainFrame.optionsModalOpacitySlider, "RIGHT", 8, 0)

mainFrame.optionsModalOpacityValueText = mainFrame.optionsModalOpacityValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.optionsModalOpacityValueText:SetPoint("TOPLEFT", mainFrame.optionsModalOpacityDecreaseButton, "BOTTOMLEFT", 0, -6)

mainFrame.optionsMinimapToggle = mainFrame.optionsMinimapToggle or make_checkbox(mainFrame.optionsAppearancePanel, "Show Minimap Button")
mainFrame.optionsMinimapToggle:SetPoint("TOPLEFT", themeButtonRowAnchors[3] or themeButtonRowAnchors[2] or themeButtonRowAnchors[1], "BOTTOMLEFT", 0, -18)

mainFrame.optionsMuteSilvermoonCitizenToggle = mainFrame.optionsMuteSilvermoonCitizenToggle or make_checkbox(mainFrame.optionsAppearancePanel, "Mute Silvermoon Citizen")
mainFrame.optionsMuteSilvermoonCitizenToggle:SetPoint("TOPLEFT", mainFrame.optionsMinimapToggle, "BOTTOMLEFT", 0, -12)

mainFrame.optionsSuppressRoutineChatToggle = mainFrame.optionsSuppressRoutineChatToggle or make_checkbox(mainFrame.optionsAppearancePanel, "Suppress Routine Chat")
mainFrame.optionsSuppressRoutineChatToggle:SetPoint("TOPLEFT", mainFrame.optionsMuteSilvermoonCitizenToggle, "BOTTOMLEFT", 0, -12)

mainFrame.optionsOnboardingTitle = mainFrame.optionsOnboardingTitle or make_label(mainFrame.optionsAppearancePanel, "First-Run Walkthrough", "GameFontHighlightSmall")
mainFrame.optionsOnboardingTitle:SetPoint("TOPLEFT", mainFrame.optionsSuppressRoutineChatToggle, "BOTTOMLEFT", 0, -18)

mainFrame.optionsOnboardingHint = mainFrame.optionsOnboardingHint or make_label(mainFrame.optionsAppearancePanel, "Replay the manager walkthrough for permissions, blacklist guidance, and the request workflow at any time.", "GameFontHighlightSmall")
mainFrame.optionsOnboardingHint:SetPoint("TOPLEFT", mainFrame.optionsOnboardingTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsOnboardingHint.SetWidth) == "function" then
    mainFrame.optionsOnboardingHint:SetWidth(280)
end

mainFrame.optionsReplayOnboardingButton = mainFrame.optionsReplayOnboardingButton or make_button(mainFrame.optionsAppearancePanel, 156, 24, "Replay Onboarding")
mainFrame.optionsReplayOnboardingButton:SetPoint("TOPLEFT", mainFrame.optionsOnboardingHint, "BOTTOMLEFT", 0, -10)

mainFrame.optionsRestockTitle = mainFrame.optionsRestockTitle or make_label(mainFrame.optionsStockSettingsPanel, "Restock Default", "GameFontHighlight")
mainFrame.optionsRestockTitle:SetPoint("TOPLEFT", mainFrame.optionsStockSettingsPanel, "TOPLEFT", 16, -16)

mainFrame.optionsRestockHint = mainFrame.optionsRestockHint or make_label(mainFrame.optionsStockSettingsPanel, "Used when staging new minimum rows without a custom quantity.", "GameFontHighlightSmall")
mainFrame.optionsRestockHint:SetPoint("TOPLEFT", mainFrame.optionsRestockTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsRestockHint.SetWidth) == "function" then
    mainFrame.optionsRestockHint:SetWidth(240)
end

mainFrame.defaultMinimumInput = mainFrame.defaultMinimumInput or make_input(mainFrame.optionsStockSettingsPanel, 72, 22)
mainFrame.defaultMinimumInput:SetPoint("TOPLEFT", mainFrame.optionsRestockHint, "BOTTOMLEFT", 0, -16)

mainFrame.optionsCriticalThresholdTitle = mainFrame.optionsCriticalThresholdTitle or make_label(mainFrame.optionsStockSettingsPanel, "Critical Shortage Threshold", "GameFontHighlight")
mainFrame.optionsCriticalThresholdTitle:SetPoint("TOPLEFT", mainFrame.optionsStockSettingsPanel, "TOPLEFT", 300, -16)

mainFrame.optionsCriticalThresholdHint = mainFrame.optionsCriticalThresholdHint or make_label(mainFrame.optionsStockSettingsPanel, "Current stock at or below this percentage of minimum counts as critical.", "GameFontHighlightSmall")
mainFrame.optionsCriticalThresholdHint:SetPoint("TOPLEFT", mainFrame.optionsCriticalThresholdTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsCriticalThresholdHint.SetWidth) == "function" then
    mainFrame.optionsCriticalThresholdHint:SetWidth(250)
end

mainFrame.optionsCriticalThresholdInput = mainFrame.optionsCriticalThresholdInput or make_input(mainFrame.optionsStockSettingsPanel, 56, 22)
mainFrame.optionsCriticalThresholdInput:SetPoint("TOPLEFT", mainFrame.optionsCriticalThresholdHint, "BOTTOMLEFT", 0, -16)

mainFrame.optionsCriticalThresholdPercentText = mainFrame.optionsCriticalThresholdPercentText or make_label(mainFrame.optionsStockSettingsPanel, "%", "GameFontNormal")
mainFrame.optionsCriticalThresholdPercentText:SetPoint("LEFT", mainFrame.optionsCriticalThresholdInput, "RIGHT", 6, 0)

mainFrame.optionsStockSettingsSaveButton = mainFrame.optionsStockSettingsSaveButton or make_button(mainFrame.optionsStockSettingsPanel, 104, 28, "Save Settings")
mainFrame.optionsStockSettingsSaveButton:SetPoint("BOTTOMLEFT", mainFrame.optionsStockSettingsPanel, "BOTTOMLEFT", 16, 16)
mainFrame.defaultMinimumSaveButton = mainFrame.optionsStockSettingsSaveButton

mainFrame.optionsLogsHistoryTitle = mainFrame.optionsLogsHistoryTitle or make_label(mainFrame.optionsLogsHistoryPanel, "Data", "GameFontHighlight")
mainFrame.optionsLogsHistoryTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -16)

mainFrame.optionsSyncTitle = mainFrame.optionsSyncTitle or make_label(mainFrame.optionsSyncPanel, "Sync", "GameFontHighlight")
mainFrame.optionsSyncTitle:SetPoint("TOPLEFT", mainFrame.optionsSyncPanel, "TOPLEFT", 16, -16)

mainFrame.optionsSyncHint = mainFrame.optionsSyncHint or make_label(mainFrame.optionsSyncPanel, "Known peers update whenever sync traffic or hello messages are seen for this guild. Use the actions below to manually request sync from online guild peers with the addon.", "GameFontHighlightSmall")
mainFrame.optionsSyncHint:SetPoint("TOPLEFT", mainFrame.optionsSyncTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsSyncHint.SetWidth) == "function" then
    mainFrame.optionsSyncHint:SetWidth(620)
end

mainFrame.optionsSyncRequestsButton = mainFrame.optionsSyncRequestsButton or make_button(mainFrame.optionsSyncPanel, 108, 24, "Sync Requests")
mainFrame.optionsSyncRequestsButton:SetPoint("TOPLEFT", mainFrame.optionsSyncHint, "BOTTOMLEFT", 0, -16)

mainFrame.optionsSyncMinimumsButton = mainFrame.optionsSyncMinimumsButton or make_button(mainFrame.optionsSyncPanel, 112, 24, "Sync Minimums")
mainFrame.optionsSyncMinimumsButton:SetPoint("LEFT", mainFrame.optionsSyncRequestsButton, "RIGHT", 8, 0)

mainFrame.optionsSyncHistoryButton = mainFrame.optionsSyncHistoryButton or make_button(mainFrame.optionsSyncPanel, 104, 24, "Sync History")
mainFrame.optionsSyncHistoryButton:SetPoint("LEFT", mainFrame.optionsSyncMinimumsButton, "RIGHT", 8, 0)

mainFrame.optionsSyncLedgerButton = mainFrame.optionsSyncLedgerButton or make_button(mainFrame.optionsSyncPanel, 96, 24, "Sync Ledger")
mainFrame.optionsSyncLedgerButton:SetPoint("LEFT", mainFrame.optionsSyncHistoryButton, "RIGHT", 8, 0)

mainFrame.optionsSyncAllButton = mainFrame.optionsSyncAllButton or make_button(mainFrame.optionsSyncPanel, 88, 24, "Sync All")
mainFrame.optionsSyncAllButton:SetPoint("LEFT", mainFrame.optionsSyncLedgerButton, "RIGHT", 8, 0)

mainFrame.optionsSyncStatusText = mainFrame.optionsSyncStatusText or make_label(mainFrame.optionsSyncPanel, "", "GameFontHighlightSmall")
mainFrame.optionsSyncStatusText:SetPoint("TOPLEFT", mainFrame.optionsSyncRequestsButton, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsSyncStatusText.SetWidth) == "function" then
    mainFrame.optionsSyncStatusText:SetWidth(620)
end

mainFrame.optionsSyncTable = mainFrame.optionsSyncTable or _G.CreateFrame("Frame", nil, mainFrame.optionsSyncPanel, "BackdropTemplate")
mainFrame.optionsSyncTable:SetPoint("TOPLEFT", mainFrame.optionsSyncStatusText, "BOTTOMLEFT", 0, -12)
mainFrame.optionsSyncTable:SetPoint("TOPRIGHT", mainFrame.optionsSyncPanel, "TOPRIGHT", -16, 0)
mainFrame.optionsSyncTable:SetWidth(680)
mainFrame.optionsSyncTable:SetHeight(200)
apply_surface_variant(mainFrame.optionsSyncTable, "table-viewport-structured")

mainFrame.optionsSyncColumnHeaders = mainFrame.optionsSyncColumnHeaders or {}
local syncHeaderTitles = { "Character", "Last Time Seen", "Last Time Synchronized", "" }
local syncHeaderWidths = { 200, 160, 200, 28 }
mainFrame.optionsSyncTableContentWidth = 8
mainFrame.optionsSyncTableScrollbarGutterWidth = 26
local previousSyncHeader = nil
for index, title in ipairs(syncHeaderTitles) do
    local header = mainFrame.optionsSyncColumnHeaders[index] or {}
    header.frame = header.frame or _G.CreateFrame("Frame", nil, mainFrame.optionsSyncTable, "BackdropTemplate")
    header.frame:SetHeight(22)
    header.frame:SetWidth(syncHeaderWidths[index])
    header.frame:ClearAllPoints()
    if previousSyncHeader == nil then
        header.frame:SetPoint("TOPLEFT", mainFrame.optionsSyncTable, "TOPLEFT", 8, -8)
    else
        header.frame:SetPoint("LEFT", previousSyncHeader.frame, "RIGHT", 8, 0)
    end
    apply_surface_variant(header.frame, "table-header")
    header.label = header.label or make_label(header.frame, title, "GameFontHighlightSmall")
    header.label:SetPoint("LEFT", header.frame, "LEFT", 8, 0)
    header.text = title
    mainFrame.optionsSyncColumnHeaders[index] = header
    previousSyncHeader = header
    mainFrame.optionsSyncTableContentWidth = (tonumber(mainFrame.optionsSyncTableContentWidth or 0) or 0) + syncHeaderWidths[index]
    if index < #syncHeaderTitles then
        mainFrame.optionsSyncTableContentWidth = (tonumber(mainFrame.optionsSyncTableContentWidth or 0) or 0) + 8
    end
end

mainFrame.optionsSyncTableScrollFrame = mainFrame.optionsSyncTableScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.optionsSyncTable, "BackdropTemplate")
mainFrame.optionsSyncTableScrollFrame:SetPoint("TOPLEFT", mainFrame.optionsSyncTable, "TOPLEFT", 8, -36)
mainFrame.optionsSyncTableScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame.optionsSyncTable, "BOTTOMRIGHT", -(8 + (tonumber(mainFrame.optionsSyncTableScrollbarGutterWidth or 26) or 26)), 8)
mainFrame.optionsSyncTableScrollFrame:SetSize(
    math.max(0, (mainFrame.optionsSyncTable:GetWidth() or 0) - 16 - (tonumber(mainFrame.optionsSyncTableScrollbarGutterWidth or 26) or 26)),
    math.max(24, (mainFrame.optionsSyncTable:GetHeight() or 0) - 44)
)
if type(mainFrame.optionsSyncTableScrollFrame.SetBackdrop) == "function" then
    mainFrame.optionsSyncTableScrollFrame:SetBackdrop(nil)
end

mainFrame.optionsSyncTableScrollChild = mainFrame.optionsSyncTableScrollChild or _G.CreateFrame("Frame", nil, mainFrame.optionsSyncTableScrollFrame, "BackdropTemplate")
mainFrame.optionsSyncTableScrollChild:SetPoint("TOPLEFT", mainFrame.optionsSyncTableScrollFrame, "TOPLEFT", 0, 0)
mainFrame.optionsSyncTableScrollChild:SetPoint("TOPRIGHT", mainFrame.optionsSyncTableScrollFrame, "TOPRIGHT", 0, 0)
mainFrame.optionsSyncTableScrollChild:SetWidth(tonumber(mainFrame.optionsSyncTableContentWidth or 0) or 0)
mainFrame.optionsSyncTableScrollChild:SetHeight(24)
mainFrame.optionsSyncTableScrollFrame:SetScrollChild(mainFrame.optionsSyncTableScrollChild)
mainFrame.optionsSyncTableScrollBar = mainFrame.optionsSyncTableScrollBar or make_slim_scroll_bar(mainFrame.optionsSyncTable, 14)
mainFrame.optionsSyncTableScrollBar:ClearAllPoints()
mainFrame.optionsSyncTableScrollBar:SetPoint("TOPRIGHT", mainFrame.optionsSyncTable, "TOPRIGHT", -8, -38)
mainFrame.optionsSyncTableScrollBar:SetPoint("BOTTOMRIGHT", mainFrame.optionsSyncTable, "BOTTOMRIGHT", -8, 10)
mainFrame.optionsSyncTableScrollController = mainFrame.optionsSyncTableScrollController
    or (type(attach_scroll_behavior) == "function" and attach_scroll_behavior(mainFrame.optionsSyncTableScrollFrame, mainFrame.optionsSyncTableScrollBar, {
        wheelStep = 26,
    }) or nil)
set_frame_shown(mainFrame.optionsSyncTableScrollBar, false)

mainFrame.optionsSyncEmptyStateText = mainFrame.optionsSyncEmptyStateText or make_label(mainFrame.optionsSyncTableScrollChild, "No peers seen yet.", "GameFontNormal")
mainFrame.optionsSyncEmptyStateText:SetPoint("TOPLEFT", mainFrame.optionsSyncTableScrollChild, "TOPLEFT", 0, 0)
if type(mainFrame.optionsSyncEmptyStateText.SetWidth) == "function" then
    mainFrame.optionsSyncEmptyStateText:SetWidth(560)
end

mainFrame.optionsSyncTableRows = mainFrame.optionsSyncTableRows or {}
mainFrame.optionsSyncTableRowsData = mainFrame.optionsSyncTableRowsData or {}

mainFrame.optionsLogsHistoryHint = mainFrame.optionsLogsHistoryHint or make_label(mainFrame.optionsLogsHistoryPanel, "Control how long local guild-bank logs and audit history are retained, and how often guild-bank scans and ledger rescans can run.", "GameFontHighlightSmall")
mainFrame.optionsLogsHistoryHint:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsLogsHistoryHint.SetWidth) == "function" then
    mainFrame.optionsLogsHistoryHint:SetWidth(640)
end

mainFrame.optionsLedgerRetentionTitle = mainFrame.optionsLedgerRetentionTitle or make_label(mainFrame.optionsLogsHistoryPanel, "Guild Bank Log Retention", "GameFontHighlight")
mainFrame.optionsLedgerRetentionTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -66)

mainFrame.optionsLedgerRetentionButton = mainFrame.optionsLedgerRetentionButton or make_button(mainFrame.optionsLogsHistoryPanel, 132, 24, "Indefinite")
mainFrame.optionsLedgerRetentionButton:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -94)

mainFrame.optionsHistoryRetentionTitle = mainFrame.optionsHistoryRetentionTitle or make_label(mainFrame.optionsLogsHistoryPanel, "History Retention", "GameFontHighlight")
mainFrame.optionsHistoryRetentionTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 300, -66)

mainFrame.optionsHistoryRetentionButton = mainFrame.optionsHistoryRetentionButton or make_button(mainFrame.optionsLogsHistoryPanel, 132, 24, "Indefinite")
mainFrame.optionsHistoryRetentionButton:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 300, -94)

mainFrame.optionsLedgerScanIntervalTitle = mainFrame.optionsLedgerScanIntervalTitle or make_label(mainFrame.optionsLogsHistoryPanel, "Scan Interval", "GameFontHighlight")
mainFrame.optionsLedgerScanIntervalTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 560, -66)

mainFrame.optionsLedgerScanIntervalButton = mainFrame.optionsLedgerScanIntervalButton or make_button(mainFrame.optionsLogsHistoryPanel, 132, 24, "5 Minutes")
mainFrame.optionsLedgerScanIntervalButton:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 560, -94)

mainFrame.optionsRepairThresholdTitle = mainFrame.optionsRepairThresholdTitle or make_label(mainFrame.optionsLogsHistoryPanel, "Repair Threshold", "GameFontHighlight")
mainFrame.optionsRepairThresholdTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -132)

mainFrame.optionsRepairThresholdInput = mainFrame.optionsRepairThresholdInput or make_input(mainFrame.optionsLogsHistoryPanel, 72, 22)
mainFrame.optionsRepairThresholdInput:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -160)

mainFrame.optionsRepairThresholdSuffixText = mainFrame.optionsRepairThresholdSuffixText or make_label(mainFrame.optionsLogsHistoryPanel, "gold", "GameFontNormal")
mainFrame.optionsRepairThresholdSuffixText:SetPoint("LEFT", mainFrame.optionsRepairThresholdInput, "RIGHT", 6, 0)

mainFrame.optionsRepairThresholdHint = mainFrame.optionsRepairThresholdHint or make_label(mainFrame.optionsLogsHistoryPanel, "Withdrawals equal to or under this amount count as repairs instead of normal withdrawals.", "GameFontHighlightSmall")
mainFrame.optionsRepairThresholdHint:SetPoint("TOPLEFT", mainFrame.optionsRepairThresholdInput, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsRepairThresholdHint.SetWidth) == "function" then
    mainFrame.optionsRepairThresholdHint:SetWidth(300)
end

mainFrame.optionsLogsHistorySaveButton = mainFrame.optionsLogsHistorySaveButton or make_button(mainFrame.optionsLogsHistoryPanel, 104, 28, "Save Settings")
mainFrame.optionsLogsHistorySaveButton:SetPoint("TOPLEFT", mainFrame.optionsRepairThresholdHint, "BOTTOMLEFT", 0, -18)

mainFrame.optionsLogsHistoryStatusText = mainFrame.optionsLogsHistoryStatusText or make_label(mainFrame.optionsLogsHistoryPanel, "", "GameFontHighlightSmall")
mainFrame.optionsLogsHistoryStatusText:SetPoint("TOPLEFT", mainFrame.optionsLogsHistorySaveButton, "BOTTOMLEFT", 0, -8)
mainFrame.optionsLogsHistoryStatusText:SetWidth(360)

mainFrame.optionsClearDataTitle = mainFrame.optionsClearDataTitle or make_label(mainFrame.optionsLogsHistoryPanel, "Clear Data", "GameFontHighlight")
mainFrame.optionsClearDataTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryStatusText, "BOTTOMLEFT", 0, -26)

mainFrame.optionsClearDataHint = mainFrame.optionsClearDataHint or make_label(mainFrame.optionsLogsHistoryPanel, "These actions are irreversible. Use them only when you want to remove saved local data on purpose.", "GameFontHighlightSmall")
mainFrame.optionsClearDataHint:SetPoint("TOPLEFT", mainFrame.optionsClearDataTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsClearDataHint.SetWidth) == "function" then
    mainFrame.optionsClearDataHint:SetWidth(640)
end

mainFrame.optionsDedupeLedgerButton = mainFrame.optionsDedupeLedgerButton or make_button(mainFrame.optionsLogsHistoryPanel, 252, 28, "Dedupe Ledger")
mainFrame.optionsDedupeLedgerButton:SetPoint("TOPLEFT", mainFrame.optionsClearDataHint, "BOTTOMLEFT", 0, -14)
mainFrame.optionsDedupeLedgerButton:Hide()

mainFrame.optionsClearBankLedgerButton = mainFrame.optionsClearBankLedgerButton or make_button(mainFrame.optionsLogsHistoryPanel, 252, 28, "Clear Guild Bank Log Data")
mainFrame.optionsClearBankLedgerButton:SetPoint("TOPLEFT", mainFrame.optionsClearDataHint, "BOTTOMLEFT", 0, -14)

mainFrame.optionsClearInventoryDataButton = mainFrame.optionsClearInventoryDataButton or make_button(mainFrame.optionsLogsHistoryPanel, 252, 28, "Clear Guild Bank Inventory Data")
mainFrame.optionsClearInventoryDataButton:SetPoint("TOPLEFT", mainFrame.optionsClearBankLedgerButton, "BOTTOMLEFT", 0, -10)

mainFrame.optionsClearCompletedRequestsButton = mainFrame.optionsClearCompletedRequestsButton or make_button(mainFrame.optionsLogsHistoryPanel, 252, 28, "Clear Completed Request History")
mainFrame.optionsClearCompletedRequestsButton:SetPoint("TOPLEFT", mainFrame.optionsClearInventoryDataButton, "BOTTOMLEFT", 0, -10)

mainFrame.optionsAuthTitle = mainFrame.optionsAuthTitle or make_label(mainFrame.optionsAuthPanel, "Guild Permissions", "GameFontHighlight")
mainFrame.optionsAuthTitle:SetPoint("TOPLEFT", mainFrame.optionsAuthPanel, "TOPLEFT", 16, -16)

mainFrame.optionsAuthHint = mainFrame.optionsAuthHint or make_label(mainFrame.optionsAuthPanel, "Configure rank-based access, request submission, and guild-shared blacklist membership.\nUse Character-Server formatting for blacklist entries stored through officer-note tags.", "GameFontHighlightSmall")
mainFrame.optionsAuthHint:SetPoint("TOPLEFT", mainFrame.optionsAuthTitle, "BOTTOMLEFT", 0, -8)
if type(mainFrame.optionsAuthHint.SetWidth) == "function" then
    mainFrame.optionsAuthHint:SetWidth(620)
end
if type(mainFrame.optionsAuthHint.SetWordWrap) == "function" then
    mainFrame.optionsAuthHint:SetWordWrap(true)
end

mainFrame.optionsAuthMetadataText = mainFrame.optionsAuthMetadataText or make_label(mainFrame.optionsAuthPanel, "", "GameFontHighlightSmall")
mainFrame.optionsAuthMetadataText:SetPoint("TOPLEFT", mainFrame.optionsAuthHint, "BOTTOMLEFT", 0, -8)

mainFrame.optionsAccessPreviewText = mainFrame.optionsAccessPreviewText or make_label(mainFrame.optionsAuthPanel, "", "GameFontNormal")
mainFrame.optionsAccessPreviewText:SetPoint("TOPLEFT", mainFrame.optionsAuthMetadataText, "BOTTOMLEFT", 0, -10)

mainFrame.optionsRankPickerLabel = mainFrame.optionsRankPickerLabel or make_label(mainFrame.optionsAuthPanel, "Selected Rank", "GameFontHighlightSmall")
mainFrame.optionsRankPickerLabel:SetPoint("TOPLEFT", mainFrame.optionsAccessPreviewText, "BOTTOMLEFT", 0, -12)

mainFrame.optionsAuthRankButton = mainFrame.optionsAuthRankButton or make_button(mainFrame.optionsAuthPanel, 180, 24, "")
mainFrame.optionsAuthRankButton:SetPoint("TOPLEFT", mainFrame.optionsRankPickerLabel, "BOTTOMLEFT", 0, -6)

mainFrame.optionsAuthRankDropdown = mainFrame.optionsAuthRankDropdown or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAuthRankDropdown:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -4)
mainFrame.optionsAuthRankDropdown:SetSize(196, 88)
apply_panel_style(mainFrame.optionsAuthRankDropdown, theme.colors.panel)
if type(mainFrame.optionsAuthRankDropdown.SetFrameStrata) == "function" then
    mainFrame.optionsAuthRankDropdown:SetFrameStrata("TOOLTIP")
end
if type(mainFrame.optionsAuthRankDropdown.SetFrameLevel) == "function" then
    mainFrame.optionsAuthRankDropdown:SetFrameLevel(80)
end
if type(mainFrame.optionsAuthRankDropdown.SetBackdropColor) == "function" then
    mainFrame.optionsAuthRankDropdown:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
end
mainFrame.optionsAuthRankDropdown:Hide()

mainFrame.optionsAuthRankDropdownBackdrop = mainFrame.optionsAuthRankDropdownBackdrop or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAuthRankDropdownBackdrop:SetPoint("TOPLEFT", mainFrame.optionsAuthRankDropdown, "TOPLEFT", 0, 0)
mainFrame.optionsAuthRankDropdownBackdrop:SetPoint("BOTTOMRIGHT", mainFrame.optionsAuthRankDropdown, "BOTTOMRIGHT", 0, 0)
apply_panel_style(mainFrame.optionsAuthRankDropdownBackdrop, theme.colors.background)
if type(mainFrame.optionsAuthRankDropdownBackdrop.SetFrameStrata) == "function" then
    mainFrame.optionsAuthRankDropdownBackdrop:SetFrameStrata("TOOLTIP")
end
if type(mainFrame.optionsAuthRankDropdownBackdrop.SetFrameLevel) == "function" then
    mainFrame.optionsAuthRankDropdownBackdrop:SetFrameLevel(84)
end
if type(mainFrame.optionsAuthRankDropdownBackdrop.SetBackdropColor) == "function" then
    mainFrame.optionsAuthRankDropdownBackdrop:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
end
mainFrame.optionsAuthRankDropdownBackdrop:Hide()

mainFrame.optionsAuthRankButtons = mainFrame.optionsAuthRankButtons or {}
for index = 1, 8 do
    local button = mainFrame.optionsAuthRankButtons[index] or make_button(mainFrame.optionsAuthRankDropdown, 180, 20, "")
    button:SetPoint("TOPLEFT", mainFrame.optionsAuthRankDropdown, "TOPLEFT", 6, -6 - ((index - 1) * 22))
    if type(button.SetFrameStrata) == "function" then
        button:SetFrameStrata("TOOLTIP")
    end
    if type(button.SetFrameLevel) == "function" then
        button:SetFrameLevel(90 + index)
    end
    mainFrame.optionsAuthRankButtons[index] = button
end

mainFrame.optionsAllowedPermissionTitle = mainFrame.optionsAllowedPermissionTitle or make_label(mainFrame.optionsAuthPanel, "Allowed Permissions", "GameFontHighlight")
mainFrame.optionsAllowedPermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -18)

mainFrame.optionsAllowedPermissionPanel = mainFrame.optionsAllowedPermissionPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAllowedPermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionTitle, "BOTTOMLEFT", 0, -6)
mainFrame.optionsAllowedPermissionPanel:SetSize(250, 138)
apply_panel_style(mainFrame.optionsAllowedPermissionPanel, theme.colors.panel)

mainFrame.optionsAvailablePermissionTitle = mainFrame.optionsAvailablePermissionTitle or make_label(mainFrame.optionsAuthPanel, "Available Permissions", "GameFontHighlight")
mainFrame.optionsAvailablePermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 126, 6)

mainFrame.optionsAvailablePermissionPanel = mainFrame.optionsAvailablePermissionPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAvailablePermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionTitle, "BOTTOMLEFT", 0, -6)
mainFrame.optionsAvailablePermissionPanel:SetSize(250, 138)
apply_panel_style(mainFrame.optionsAvailablePermissionPanel, theme.colors.panel)

mainFrame.optionsAuthRankDropdownOccluder = mainFrame.optionsAuthRankDropdownOccluder or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAuthRankDropdownOccluder:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPLEFT", 0, 0)
mainFrame.optionsAuthRankDropdownOccluder:SetPoint("BOTTOMRIGHT", mainFrame.optionsAvailablePermissionPanel, "BOTTOMRIGHT", 0, 0)
apply_panel_style(mainFrame.optionsAuthRankDropdownOccluder, theme.colors.background)
if type(mainFrame.optionsAuthRankDropdownOccluder.SetFrameStrata) == "function" then
    mainFrame.optionsAuthRankDropdownOccluder:SetFrameStrata("TOOLTIP")
end
if type(mainFrame.optionsAuthRankDropdownOccluder.SetFrameLevel) == "function" then
    mainFrame.optionsAuthRankDropdownOccluder:SetFrameLevel(79)
end
mainFrame.optionsAuthRankDropdownOccluder:Hide()

mainFrame.optionsAuthRemovePermissionButton = mainFrame.optionsAuthRemovePermissionButton or make_button(mainFrame.optionsAuthPanel, 92, 24, "Remove >>")
mainFrame.optionsAuthRemovePermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 16, -36)

mainFrame.optionsAuthAddPermissionButton = mainFrame.optionsAuthAddPermissionButton or make_button(mainFrame.optionsAuthPanel, 92, 24, "<< Add")
mainFrame.optionsAuthAddPermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAuthRemovePermissionButton, "BOTTOMLEFT", 0, -10)

mainFrame.optionsAllowedPermissionButtons = mainFrame.optionsAllowedPermissionButtons or {}
mainFrame.optionsAvailablePermissionButtons = mainFrame.optionsAvailablePermissionButtons or {}
for index = 1, 11 do
    local allowedButton = mainFrame.optionsAllowedPermissionButtons[index] or make_button(mainFrame.optionsAllowedPermissionPanel, 114, 18, "")
    allowedButton:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPLEFT", 8, -8 - ((index - 1) * 20))
    mainFrame.optionsAllowedPermissionButtons[index] = allowedButton

    local availableButton = mainFrame.optionsAvailablePermissionButtons[index] or make_button(mainFrame.optionsAvailablePermissionPanel, 114, 18, "")
    availableButton:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionPanel, "TOPLEFT", 8, -8 - ((index - 1) * 20))
    mainFrame.optionsAvailablePermissionButtons[index] = availableButton
end

mainFrame.optionsBlacklistTitle = mainFrame.optionsBlacklistTitle or make_label(mainFrame.optionsAuthPanel, "Blacklist", "GameFontHighlight")
mainFrame.optionsBlacklistTitle:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionPanel, "BOTTOMLEFT", 0, -18)

mainFrame.optionsBlacklistCharacterLabel = mainFrame.optionsBlacklistCharacterLabel or make_label(mainFrame.optionsAuthPanel, "Character-Server", "GameFontHighlightSmall")
mainFrame.optionsBlacklistCharacterLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistTitle, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistNameInput = mainFrame.optionsBlacklistNameInput or make_input(mainFrame.optionsAuthPanel, 220, 22)
mainFrame.optionsBlacklistNameInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistCharacterLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsBlacklistReasonLabel = mainFrame.optionsBlacklistReasonLabel or make_label(mainFrame.optionsAuthPanel, "Reason", "GameFontHighlightSmall")
mainFrame.optionsBlacklistReasonLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistNameInput, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistReasonInput = mainFrame.optionsBlacklistReasonInput or make_input(mainFrame.optionsAuthPanel, 220, 22)
mainFrame.optionsBlacklistReasonInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsBlacklistAddButton = mainFrame.optionsBlacklistAddButton or make_button(mainFrame.optionsAuthPanel, 96, 24, "Add / Update")
mainFrame.optionsBlacklistAddButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonInput, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistRemoveButton = mainFrame.optionsBlacklistRemoveButton or make_button(mainFrame.optionsAuthPanel, 74, 24, "Remove")
mainFrame.optionsBlacklistRemoveButton:SetPoint("LEFT", mainFrame.optionsBlacklistAddButton, "RIGHT", 8, 0)

mainFrame.optionsBlacklistListTitle = mainFrame.optionsBlacklistListTitle or make_label(mainFrame.optionsAuthPanel, "Blacklisted Members", "GameFontHighlightSmall")
mainFrame.optionsBlacklistListTitle:SetPoint("TOPLEFT", mainFrame.optionsBlacklistTitle, "BOTTOMLEFT", 0, -12)

mainFrame.optionsBlacklistListPanel = mainFrame.optionsBlacklistListPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsBlacklistListPanel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListTitle, "BOTTOMLEFT", 0, -4)
mainFrame.optionsBlacklistListPanel:SetSize(324, 220)
apply_panel_style(mainFrame.optionsBlacklistListPanel, theme.colors.panel)

mainFrame.optionsBlacklistStatusText = mainFrame.optionsBlacklistStatusText or make_label(mainFrame.optionsBlacklistPanel, "", "GameFontHighlightSmall")
mainFrame.optionsBlacklistStatusText:SetWidth(324)

mainFrame.optionsBlacklistRefreshButton = mainFrame.optionsBlacklistRefreshButton or make_button(mainFrame.optionsBlacklistPanel, 74, 24, "Refresh")

mainFrame.optionsBlacklistSaveButton = mainFrame.optionsBlacklistSaveButton or make_button(mainFrame.optionsBlacklistPanel, 88, 24, "Save")
mainFrame.optionsBlacklistResetButton = mainFrame.optionsBlacklistResetButton or make_button(mainFrame.optionsBlacklistPanel, 70, 24, "Revert")

mainFrame.optionsBlacklistButtons = mainFrame.optionsBlacklistButtons or {}
for index = 1, 12 do
    local button = mainFrame.optionsBlacklistButtons[index] or make_button(mainFrame.optionsBlacklistListPanel, 308, 18, "")
    button:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListPanel, "TOPLEFT", 8, -8 - ((index - 1) * 22))
    mainFrame.optionsBlacklistButtons[index] = button
end

mainFrame.optionsPolicyStringLabel = mainFrame.optionsPolicyStringLabel or make_label(mainFrame.optionsAuthPanel, "Policy String", "GameFontHighlightSmall")
mainFrame.optionsPolicyStringLabel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "BOTTOMLEFT", 0, -18)

mainFrame.optionsPolicyStringInput = mainFrame.optionsPolicyStringInput or make_input(mainFrame.optionsAuthPanel, 250, 22)
mainFrame.optionsPolicyStringInput:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsPolicyStringSelectAllButton = mainFrame.optionsPolicyStringSelectAllButton or make_button(mainFrame.optionsAuthPanel, 78, 22, "Select All")
mainFrame.optionsPolicyStringSelectAllButton:SetPoint("LEFT", mainFrame.optionsPolicyStringInput, "RIGHT", 8, 0)

mainFrame.optionsPolicyStringHelpText = mainFrame.optionsPolicyStringHelpText or make_label(mainFrame.optionsAuthPanel, "1. Save to update the local policy.\n2. Copy the policy string into Guild Information.\n3. Press Accept in Guild Information.\n4. Use Refresh Guild Info to confirm the live string.\n\nGuild Info stores the compact policy string only.\nBlacklist membership stays in officer-note tags.\nBlacklist reasons stay local and sync through the addon.", "GameFontHighlightSmall")
mainFrame.optionsPolicyStringHelpText:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringInput, "BOTTOMLEFT", 0, -6)
mainFrame.optionsPolicyStringHelpText:SetWidth(280)
if type(mainFrame.optionsPolicyStringHelpText.SetJustifyH) == "function" then
    mainFrame.optionsPolicyStringHelpText:SetJustifyH("LEFT")
end
if type(mainFrame.optionsPolicyStringHelpText.SetWordWrap) == "function" then
    mainFrame.optionsPolicyStringHelpText:SetWordWrap(true)
end

mainFrame.optionsAuthStatusText = mainFrame.optionsAuthStatusText or make_label(mainFrame.optionsAuthPanel, "", "GameFontHighlightSmall")
mainFrame.optionsAuthStatusText:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringHelpText, "BOTTOMLEFT", 0, -8)
mainFrame.optionsAuthStatusText:SetWidth(280)

mainFrame.optionsAuthSaveButton = mainFrame.optionsAuthSaveButton or make_button(mainFrame.optionsAuthPanel, 88, 24, "Save")
mainFrame.optionsAuthSaveButton:SetPoint("TOPLEFT", mainFrame.optionsAuthStatusText, "BOTTOMLEFT", 0, -12)

mainFrame.optionsAuthReadButton = mainFrame.optionsAuthReadButton or make_button(mainFrame.optionsAuthPanel, 128, 24, "Refresh Guild Info")
mainFrame.optionsAuthReadButton:SetPoint("LEFT", mainFrame.optionsAuthSaveButton, "RIGHT", 8, 0)

mainFrame.optionsAuthResetButton = mainFrame.optionsAuthResetButton or make_button(mainFrame.optionsAuthPanel, 70, 24, "Revert")
mainFrame.optionsAuthResetButton:SetPoint("LEFT", mainFrame.optionsAuthReadButton, "RIGHT", 8, 0)

local function move_to_panel(widget, panel)
    if type(widget) ~= "table" or type(panel) ~= "table" then
        return
    end

    if type(widget.SetParent) == "function" then
        widget:SetParent(panel)
    end
    if type(widget.ClearAllPoints) == "function" then
        widget:ClearAllPoints()
    end
end

move_to_panel(mainFrame.optionsAuthTitle, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthTitle:SetPoint("TOPLEFT", mainFrame.optionsPermissionsPanel, "TOPLEFT", 16, -16)
move_to_panel(mainFrame.optionsAuthHint, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthHint:SetPoint("TOPLEFT", mainFrame.optionsAuthTitle, "BOTTOMLEFT", 0, -8)
move_to_panel(mainFrame.optionsAuthMetadataText, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthMetadataText:SetPoint("TOPLEFT", mainFrame.optionsAuthHint, "BOTTOMLEFT", 0, -8)
move_to_panel(mainFrame.optionsAccessPreviewText, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAccessPreviewText:SetPoint("TOPLEFT", mainFrame.optionsAuthMetadataText, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsRankPickerLabel, mainFrame.optionsPermissionsPanel)
mainFrame.optionsRankPickerLabel:SetPoint("TOPLEFT", mainFrame.optionsAccessPreviewText, "BOTTOMLEFT", 0, -12)
move_to_panel(mainFrame.optionsAuthRankButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthRankButton:SetPoint("TOPLEFT", mainFrame.optionsRankPickerLabel, "BOTTOMLEFT", 0, -6)
move_to_panel(mainFrame.optionsAuthRankDropdown, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthRankDropdown:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -4)
move_to_panel(mainFrame.optionsAllowedPermissionTitle, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAllowedPermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -18)
move_to_panel(mainFrame.optionsAllowedPermissionPanel, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAllowedPermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionTitle, "BOTTOMLEFT", 0, -6)
move_to_panel(mainFrame.optionsAvailablePermissionTitle, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAvailablePermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 126, 6)
move_to_panel(mainFrame.optionsAvailablePermissionPanel, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAvailablePermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionTitle, "BOTTOMLEFT", 0, -6)
move_to_panel(mainFrame.optionsAuthRankDropdownOccluder, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthRankDropdownOccluder:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPLEFT", 0, 0)
mainFrame.optionsAuthRankDropdownOccluder:SetPoint("BOTTOMRIGHT", mainFrame.optionsAvailablePermissionPanel, "BOTTOMRIGHT", 0, 0)
move_to_panel(mainFrame.optionsAuthRemovePermissionButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthRemovePermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 16, -36)
move_to_panel(mainFrame.optionsAuthAddPermissionButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthAddPermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAuthRemovePermissionButton, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsPolicyStringLabel, mainFrame.optionsPermissionsPanel)
mainFrame.optionsPolicyStringLabel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "BOTTOMLEFT", 0, -18)
move_to_panel(mainFrame.optionsPolicyStringInput, mainFrame.optionsPermissionsPanel)
mainFrame.optionsPolicyStringInput:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringLabel, "BOTTOMLEFT", 0, -4)
move_to_panel(mainFrame.optionsPolicyStringSelectAllButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsPolicyStringSelectAllButton:SetPoint("LEFT", mainFrame.optionsPolicyStringInput, "RIGHT", 8, 0)
move_to_panel(mainFrame.optionsPolicyStringHelpText, mainFrame.optionsPermissionsPanel)
mainFrame.optionsPolicyStringHelpText:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringInput, "BOTTOMLEFT", 0, -6)
move_to_panel(mainFrame.optionsAuthStatusText, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthStatusText:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringHelpText, "BOTTOMLEFT", 0, -8)
move_to_panel(mainFrame.optionsAuthSaveButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthSaveButton:SetPoint("TOPLEFT", mainFrame.optionsAuthStatusText, "BOTTOMLEFT", 0, -12)
move_to_panel(mainFrame.optionsAuthReadButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthReadButton:SetPoint("LEFT", mainFrame.optionsAuthSaveButton, "RIGHT", 8, 0)
move_to_panel(mainFrame.optionsAuthResetButton, mainFrame.optionsPermissionsPanel)
mainFrame.optionsAuthResetButton:SetPoint("LEFT", mainFrame.optionsAuthReadButton, "RIGHT", 8, 0)

mainFrame.optionsBlacklistPanelTitle = mainFrame.optionsBlacklistPanelTitle or make_label(mainFrame.optionsBlacklistPanel, "Blacklist", "GameFontHighlight")
mainFrame.optionsBlacklistPanelTitle:SetPoint("TOPLEFT", mainFrame.optionsBlacklistPanel, "TOPLEFT", 16, -16)
mainFrame.optionsBlacklistPanelHint = mainFrame.optionsBlacklistPanelHint or make_label(mainFrame.optionsBlacklistPanel, "Guild-shared blacklist membership is read from officer notes. This tab is read-only.", "GameFontHighlightSmall")
mainFrame.optionsBlacklistPanelHint:SetPoint("TOPLEFT", mainFrame.optionsBlacklistPanelTitle, "BOTTOMLEFT", 0, -8)
mainFrame.optionsBlacklistInstructionText = mainFrame.optionsBlacklistInstructionText or make_label(mainFrame.optionsBlacklistPanel, "1. Open Guild & Communities.\n2. Append [GBMBL] to the member's officer note.\n3. Refresh the guild roster or press Refresh below.\n4. Tagged members appear in the list.", "GameFontHighlightSmall")
mainFrame.optionsBlacklistInstructionText:SetPoint("TOPLEFT", mainFrame.optionsBlacklistPanelHint, "BOTTOMLEFT", 0, -8)
mainFrame.optionsBlacklistInstructionText:SetWidth(500)
if type(mainFrame.optionsBlacklistInstructionText.SetJustifyH) == "function" then
    mainFrame.optionsBlacklistInstructionText:SetJustifyH("LEFT")
end
if type(mainFrame.optionsBlacklistInstructionText.SetWordWrap) == "function" then
    mainFrame.optionsBlacklistInstructionText:SetWordWrap(true)
end
move_to_panel(mainFrame.optionsBlacklistTitle, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistTitle:SetPoint("TOPLEFT", mainFrame.optionsBlacklistInstructionText, "BOTTOMLEFT", 0, -12)
move_to_panel(mainFrame.optionsBlacklistCharacterLabel, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistCharacterLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistTitle, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsBlacklistNameInput, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistNameInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistCharacterLabel, "BOTTOMLEFT", 0, -4)
move_to_panel(mainFrame.optionsBlacklistReasonLabel, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistReasonLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistNameInput, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsBlacklistReasonInput, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistReasonInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonLabel, "BOTTOMLEFT", 0, -4)
move_to_panel(mainFrame.optionsBlacklistAddButton, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistAddButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonInput, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsBlacklistRemoveButton, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistRemoveButton:SetPoint("LEFT", mainFrame.optionsBlacklistAddButton, "RIGHT", 8, 0)
move_to_panel(mainFrame.optionsBlacklistListTitle, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistListTitle:SetPoint("TOPLEFT", mainFrame.optionsBlacklistInstructionText, "BOTTOMLEFT", 0, -12)
move_to_panel(mainFrame.optionsBlacklistRefreshButton, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistRefreshButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListPanel, "BOTTOMLEFT", 0, -8)
move_to_panel(mainFrame.optionsBlacklistListPanel, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistListPanel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListTitle, "BOTTOMLEFT", 0, -4)
move_to_panel(mainFrame.optionsBlacklistStatusText, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistStatusText:SetPoint("TOPLEFT", mainFrame.optionsBlacklistRefreshButton, "BOTTOMLEFT", 0, -8)
move_to_panel(mainFrame.optionsBlacklistSaveButton, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistSaveButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistStatusText, "BOTTOMLEFT", 0, -10)
move_to_panel(mainFrame.optionsBlacklistResetButton, mainFrame.optionsBlacklistPanel)
mainFrame.optionsBlacklistResetButton:SetPoint("LEFT", mainFrame.optionsBlacklistSaveButton, "RIGHT", 8, 0)

mainFrame.optionsAutomationTitle = mainFrame.optionsAutomationTitle or make_label(mainFrame.optionsAutomationPanel, "Automation", "GameFontHighlight")
mainFrame.optionsAutomationTitle:SetPoint("TOPLEFT", mainFrame.optionsAutomationPanel, "TOPLEFT", 16, -16)
mainFrame.optionsAutomationHint = mainFrame.optionsAutomationHint or make_label(mainFrame.optionsAutomationPanel, "Auto-scan and guild sync behavior continue to use the existing runtime settings. This tab is reserved for the polished automation controls pass.", "GameFontHighlightSmall")
mainFrame.optionsAutomationHint:SetPoint("TOPLEFT", mainFrame.optionsAutomationTitle, "BOTTOMLEFT", 0, -8)
mainFrame.optionsExportsTitle = mainFrame.optionsExportsTitle or make_label(mainFrame.optionsExportsPanel, "Exports", "GameFontHighlight")
mainFrame.optionsExportsTitle:SetPoint("TOPLEFT", mainFrame.optionsExportsPanel, "TOPLEFT", 16, -16)
mainFrame.optionsExportsHint = mainFrame.optionsExportsHint or make_label(mainFrame.optionsExportsPanel, "Auctionator, TSM, CSV, and shopping-list formats stay behavior-compatible. This tab will host export-specific appearance controls as the polish pass continues.", "GameFontHighlightSmall")
mainFrame.optionsExportsHint:SetPoint("TOPLEFT", mainFrame.optionsExportsTitle, "BOTTOMLEFT", 0, -8)
mainFrame.optionsRequestsTitle = mainFrame.optionsRequestsTitle or make_label(mainFrame.optionsRequestsPanel, "Requests", "GameFontHighlight")
mainFrame.optionsRequestsTitle:SetPoint("TOPLEFT", mainFrame.optionsRequestsPanel, "TOPLEFT", 16, -16)
mainFrame.optionsRequestsHint = mainFrame.optionsRequestsHint or make_label(mainFrame.optionsRequestsPanel, "Member-request defaults, wizard affordances, and request-admin visual options will live here as the screen pass continues.", "GameFontHighlightSmall")
mainFrame.optionsRequestsHint:SetPoint("TOPLEFT", mainFrame.optionsRequestsTitle, "BOTTOMLEFT", 0, -8)

local function modal_frames(frame)
    return {
        frame.requestWizardModal,
        frame.requestDetailsModal,
        frame.historyDetailsModal,
        frame.minimumAddModal,
        frame.minimumDetailsModal,
        frame.exportModal,
        frame.exportStockedElsewhereModal,
        frame.exportManualShoppingListModal,
    }
end

local function child_frames(frame)
    if type(frame) ~= "table" then
        return {}
    end

    if type(frame.GetChildren) == "function" then
        return { frame:GetChildren() }
    end

    if type(frame.children) == "table" then
        return frame.children
    end

    return {}
end

local function visit_frame_tree(frame, visitor, seen, excluded)
    if type(frame) ~= "table" or seen[frame] or (excluded and excluded[frame]) then
        return
    end

    seen[frame] = true
    visitor(frame)

    for _, child in ipairs(child_frames(frame)) do
        visit_frame_tree(child, visitor, seen, excluded)
    end
end

function mainFrame:ApplyShellOpacity(alpha)
    alpha = clamp_range(alpha, 0.0, 1.0)
    if type(set_surface_alpha) ~= "function" then
        return
    end

    local excluded = {}
    for _, frame in ipairs(modal_frames(self)) do
        if frame then
            excluded[frame] = true
        end
    end

    visit_frame_tree(self, function(frame)
        if frame == self or (frame.gbmSurfaceVariant and frame.gbmButtonVariant == nil) then
            set_surface_alpha(frame, alpha)
        end
    end, {}, excluded)
end

function mainFrame:ApplyModalOpacity(alpha)
    alpha = clamp_range(alpha, 0.0, 1.0)
    local shell = ns.modules.mainFrameShell or mainFrameShell
    local fallbackColor = shell and type(shell.GetTheme) == "function" and shell.GetTheme().colors.panelAlt or { 0.13, 0.17, 0.24, 0.98 }

    for _, frame in ipairs(modal_frames(self)) do
        if frame and type(frame.SetAlpha) == "function" then
            frame:SetAlpha(1)
        end
        if frame and type(set_surface_alpha) == "function" then
            visit_frame_tree(frame, function(child)
                if child == frame or (child.gbmSurfaceVariant and child.gbmButtonVariant == nil) then
                    set_surface_alpha(child, alpha)
                end
            end, {})
        end
        if frame and type(frame.SetBackdropColor) == "function" then
            local color = frame.gbmBackdropBaseColor or fallbackColor
            frame:SetBackdropColor(color[1] or 0, color[2] or 0, color[3] or 0, (color[4] or 1) * alpha)
        end
    end
end

function mainFrame:RefreshAppearanceControls()
    self.isRefreshingAppearanceControls = true
    if self.optionsShellScaleSlider then
        self.optionsShellScaleSlider:SetValue(self.appearanceShellScale or 1)
    end
    if self.optionsShellOpacitySlider then
        self.optionsShellOpacitySlider:SetValue(self.appearanceShellOpacity or 0.96)
    end
    if self.optionsModalOpacitySlider then
        self.optionsModalOpacitySlider:SetValue(self.appearanceModalOpacity or 1)
    end

    if self.optionsShellScaleValueText then
        self.optionsShellScaleValueText:SetText(percent_text(self.appearanceShellScale or 1))
    end
    if self.optionsShellOpacityValueText then
        self.optionsShellOpacityValueText:SetText(percent_text(self.appearanceShellOpacity or 0.96))
    end
    if self.optionsModalOpacityValueText then
        self.optionsModalOpacityValueText:SetText(percent_text(self.appearanceModalOpacity or 1))
    end
    if self.optionsMinimapToggle and type(self.optionsMinimapToggle.SetChecked) == "function" then
        self.optionsMinimapToggle:SetChecked(self.appearanceShowMinimapButton ~= false)
    end
    if self.optionsMuteSilvermoonCitizenToggle and type(self.optionsMuteSilvermoonCitizenToggle.SetChecked) == "function" then
        local logsHistorySettings = bankLedger and type(bankLedger.GetSettings) == "function"
            and bankLedger.GetSettings(current_db())
            or (((current_db() or {}).ui or {}).logsHistorySettings or {})
        self.optionsMuteSilvermoonCitizenToggle:SetChecked(logsHistorySettings.muteSilvermoonCitizen == true)
    end
    if self.optionsSuppressRoutineChatToggle and type(self.optionsSuppressRoutineChatToggle.SetChecked) == "function" then
        local chatSettings = (((current_db() or {}).ui or {}).chatSettings or {})
        self.optionsSuppressRoutineChatToggle:SetChecked(chatSettings.suppressRoutineMessages == true)
    end
    self.isRefreshingAppearanceControls = false
end

function mainFrame:LoadAppearanceSettingsFromDb(db)
    db = db or current_db()
    local appearance = current_appearance_settings(db)
    local presetKey = type(themeManager.NormalizePresetKey) == "function"
        and themeManager.NormalizePresetKey(appearance.themePreset or "generic_wow")
        or tostring(appearance.themePreset or "generic_wow")
    local shell = ns.modules.mainFrameShell or mainFrameShell

    self.appearanceThemePreset = presetKey
    self.appearanceShellScale = clamp_range(appearance.shellScale, 0.9, 1.2)
    self.appearanceTableDensity = self.appearanceShellScale
    self.appearanceShellOpacity = clamp_range(appearance.shellOpacity, 0.0, 1.0)
    self.appearanceModalOpacity = clamp_range(appearance.modalOpacity, 0.0, 1.0)
    self.appearanceShowMinimapButton = appearance.showMinimapButton ~= false

    appearance.themePreset = self.appearanceThemePreset
    appearance.shellScale = self.appearanceShellScale
    appearance.tableDensity = self.appearanceTableDensity
    appearance.shellOpacity = self.appearanceShellOpacity
    appearance.modalOpacity = self.appearanceModalOpacity
    appearance.showMinimapButton = self.appearanceShowMinimapButton

    if shell and shell.ApplyThemePreset then
        shell.ApplyThemePreset(self.appearanceThemePreset)
    end
    if shell and shell.ApplyShellScale then
        shell.ApplyShellScale(self.appearanceShellScale)
    end

    self.tableHeaderHeight = math.max(24, math.floor((self.baseTableHeaderHeight or 34) * self.appearanceTableDensity + 0.5))
    self.tableFilterHeight = math.max(22, math.floor((self.baseTableFilterHeight or 28) * self.appearanceTableDensity + 0.5))
    self.tableRowHeight = math.max(20, math.floor((self.baseTableRowHeight or 26) * self.appearanceTableDensity + 0.5))
    self.tableVisibleCount = math.max(1, math.floor(math.max(0, self.tableViewportHeight or self.defaultTableViewportHeight or 0) / self.tableRowHeight))
    if self.tableScrollController and self.tableScrollController.options then
        self.tableScrollController.options.wheelStep = self.tableRowHeight
    end

    set_alpha(self.appearanceShellOpacity)
    self:ApplyModalOpacity(self.appearanceModalOpacity)
    if minimapButton and type(minimapButton.EnsureButton) == "function" then
        minimapButton.EnsureButton()
    end
    if minimapButton and type(minimapButton.SetShown) == "function" then
        minimapButton.SetShown(self.appearanceShowMinimapButton ~= false)
    end
    if minimapButton and type(minimapButton.RefreshAppearance) == "function" then
        minimapButton.RefreshAppearance()
    end
    self:RefreshAppearanceControls()

    return appearance
end

local function refresh_after_appearance_change()
    mainFrame:ApplyTheme()
    if mainFrame.activeView then
        mainFrame:RefreshView()
    end
end

function mainFrame:SetThemePreset(presetKey)
    local db = current_db()
    local appearance = current_appearance_settings(db)
    appearance.themePreset = type(themeManager.NormalizePresetKey) == "function"
        and themeManager.NormalizePresetKey(presetKey or "generic_wow")
        or tostring(presetKey or "generic_wow")
    self:LoadAppearanceSettingsFromDb(db)
    refresh_after_appearance_change()
end

function mainFrame:SetShellScale(scale)
    local db = current_db()
    local appearance = current_appearance_settings(db)
    local nextScale = clamp_range(scale, 0.9, 1.2)
    appearance.shellScale = nextScale
    appearance.tableDensity = nextScale
    self:LoadAppearanceSettingsFromDb(db)
    refresh_after_appearance_change()
end

function mainFrame:SetTableDensity(scale)
    self:SetShellScale(scale)
end

function mainFrame:SetShellOpacity(alpha)
    local db = current_db()
    local appearance = current_appearance_settings(db)
    appearance.shellOpacity = clamp_range(alpha, 0.0, 1.0)
    self:LoadAppearanceSettingsFromDb(db)
    refresh_after_appearance_change()
end

function mainFrame:SetModalOpacity(alpha)
    local db = current_db()
    local appearance = current_appearance_settings(db)
    appearance.modalOpacity = clamp_range(alpha, 0.0, 1.0)
    self:LoadAppearanceSettingsFromDb(db)
    refresh_after_appearance_change()
end

function mainFrame:SetShowMinimapButton(isShown)
    local db = current_db()
    local appearance = current_appearance_settings(db)
    appearance.showMinimapButton = isShown == true
    self:LoadAppearanceSettingsFromDb(db)
    refresh_after_appearance_change()
end

function mainFrame:SetMuteSilvermoonCitizen(isMuted)
    local db = current_db()
    local settings = bankLedger and type(bankLedger.GetSettings) == "function"
        and bankLedger.GetSettings(db)
        or (((db or {}).ui or {}).logsHistorySettings or {})
    settings.muteSilvermoonCitizen = isMuted == true
    self:RefreshLogsHistoryControls()
    self:RefreshAppearanceControls()
    return settings.muteSilvermoonCitizen
end

function mainFrame:SetSuppressRoutineChat(isMuted)
    local db = current_db()
    db.ui = type(db.ui) == "table" and db.ui or {}
    db.ui.chatSettings = type(db.ui.chatSettings) == "table" and db.ui.chatSettings or {}
    db.ui.chatSettings.suppressRoutineMessages = isMuted == true
    self:RefreshAppearanceControls()
    return db.ui.chatSettings.suppressRoutineMessages
end

local function adjust_appearance_value(getter, setter, delta)
    local currentValue = getter()
    setter(currentValue + delta)
end

for presetKey, button in pairs(mainFrame.optionsThemeButtons or {}) do
    button:SetScript("OnClick", function()
        mainFrame:SetThemePreset(presetKey)
    end)
end

mainFrame.optionsShellScaleDecreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceShellScale or 1
    end, function(nextValue)
        mainFrame:SetShellScale(nextValue)
    end, -0.05)
end)

mainFrame.optionsShellScaleIncreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceShellScale or 1
    end, function(nextValue)
        mainFrame:SetShellScale(nextValue)
    end, 0.05)
end)

mainFrame.optionsShellOpacityDecreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceShellOpacity or 0.96
    end, function(nextValue)
        mainFrame:SetShellOpacity(nextValue)
    end, -0.01)
end)

mainFrame.optionsShellOpacityIncreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceShellOpacity or 0.96
    end, function(nextValue)
        mainFrame:SetShellOpacity(nextValue)
    end, 0.01)
end)

mainFrame.optionsModalOpacityDecreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceModalOpacity or 1
    end, function(nextValue)
        mainFrame:SetModalOpacity(nextValue)
    end, -0.01)
end)

mainFrame.optionsModalOpacityIncreaseButton:SetScript("OnClick", function()
    adjust_appearance_value(function()
        return mainFrame.appearanceModalOpacity or 1
    end, function(nextValue)
        mainFrame:SetModalOpacity(nextValue)
    end, 0.01)
end)

mainFrame.optionsShellScaleSlider.onValueChanged = function(_, value)
    if mainFrame.isRefreshingAppearanceControls then
        return
    end
    if not nearly_equal(mainFrame.appearanceShellScale or 1, value) then
        mainFrame:SetShellScale(value)
    end
end

mainFrame.optionsShellOpacitySlider.onValueChanged = function(_, value)
    if mainFrame.isRefreshingAppearanceControls then
        return
    end
    if not nearly_equal(mainFrame.appearanceShellOpacity or 0.96, value) then
        mainFrame:SetShellOpacity(value)
    end
end

mainFrame.optionsModalOpacitySlider.onValueChanged = function(_, value)
    if mainFrame.isRefreshingAppearanceControls then
        return
    end
    if not nearly_equal(mainFrame.appearanceModalOpacity or 1, value) then
        mainFrame:SetModalOpacity(value)
    end
end

if mainFrame.optionsMinimapToggle then
    mainFrame.optionsMinimapToggle:SetScript("OnClick", function(toggle)
        if mainFrame.isRefreshingAppearanceControls then
            return
        end
        mainFrame:SetShowMinimapButton(toggle:GetChecked() == true)
    end)
end

if mainFrame.optionsMuteSilvermoonCitizenToggle then
    mainFrame.optionsMuteSilvermoonCitizenToggle:SetScript("OnClick", function(toggle)
        if mainFrame.isRefreshingAppearanceControls then
            return
        end
        mainFrame:SetMuteSilvermoonCitizen(toggle:GetChecked() == true)
    end)
end

if mainFrame.optionsSuppressRoutineChatToggle then
    mainFrame.optionsSuppressRoutineChatToggle:SetScript("OnClick", function(toggle)
        if mainFrame.isRefreshingAppearanceControls then
            return
        end
        mainFrame:SetSuppressRoutineChat(toggle:GetChecked() == true)
    end)
end

if mainFrame.optionsReplayOnboardingButton then
    mainFrame.optionsReplayOnboardingButton:SetScript("OnClick", function()
        mainFrame:OpenOnboarding("manager", {
            auto = false,
            reason = "options_replay",
        })
    end)
end

mainFrame.optionsStockSettingsSaveButton:SetScript("OnClick", function()
    mainFrame:SaveStockSettings()
end)

function mainFrame:RefreshLogsHistoryControls()
    local db = current_db()
    local settings = bankLedger and type(bankLedger.GetSettings) == "function"
        and bankLedger.GetSettings(db)
        or (((db or {}).ui or {}).logsHistorySettings or {})
    if self.optionsLedgerRetentionButton then
        self.optionsLedgerRetentionButton.labelText:SetText(bankLedger.GetRetentionLabel(settings.ledgerRetention))
    end
    if self.optionsHistoryRetentionButton then
        self.optionsHistoryRetentionButton.labelText:SetText(bankLedger.GetRetentionLabel(settings.historyRetention))
    end
    if self.optionsLedgerScanIntervalButton then
        self.optionsLedgerScanIntervalButton.labelText:SetText(bankLedger.GetScanIntervalLabel(settings.ledgerScanIntervalSeconds))
    end
    if self.optionsRepairThresholdInput and type(self.optionsRepairThresholdInput.SetText) == "function" then
        self.optionsRepairThresholdInput:SetText(tostring(math.floor(tonumber(settings.repairThresholdGold or 5000) or 5000)))
    end
    if self.optionsMuteSilvermoonCitizenToggle and type(self.optionsMuteSilvermoonCitizenToggle.SetChecked) == "function" then
        self.optionsMuteSilvermoonCitizenToggle:SetChecked(settings.muteSilvermoonCitizen == true)
    end
    return settings
end

function mainFrame:SetOptionsSyncStatus(message)
    if self.optionsSyncStatusText and type(self.optionsSyncStatusText.SetText) == "function" then
        self.optionsSyncStatusText:SetText(tostring(message or ""))
    end
end

function mainFrame:RefreshSyncControls()
    local db = current_db()
    local rows = build_sync_peer_rows(db)
    self.optionsSyncTableRowsData = rows
    local contentWidth = math.max(
        tonumber(self.optionsSyncTableContentWidth or 0) or 0,
        self.optionsSyncTableScrollFrame and (tonumber(self.optionsSyncTableScrollFrame:GetWidth() or 0) or 0) or 0
    )

    if self.optionsSyncTableRows == nil then
        self.optionsSyncTableRows = {}
    end

    for index, row in ipairs(rows) do
        local rowFrame = self.optionsSyncTableRows[index]
        if rowFrame == nil then
            rowFrame = _G.CreateFrame("Frame", nil, self.optionsSyncTableScrollChild, "BackdropTemplate")
            rowFrame:SetHeight(24)
            rowFrame.characterText = make_label(rowFrame, "", "GameFontNormal")
            rowFrame.characterText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 8, -4)
            rowFrame.lastSeenText = make_label(rowFrame, "", "GameFontNormal")
            rowFrame.lastSeenText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 216, -4)
            rowFrame.lastSynchronizedText = make_label(rowFrame, "", "GameFontNormal")
            rowFrame.lastSynchronizedText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 384, -4)
            rowFrame.removeButton = make_button(rowFrame, 24, 18, "")
            rowFrame.removeButton:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, -2)
            apply_button_variant(rowFrame.removeButton, "danger")
            set_button_icon(rowFrame.removeButton, "remove")
            self.optionsSyncTableRows[index] = rowFrame
        end

        rowFrame:ClearAllPoints()
        rowFrame:SetPoint("TOPLEFT", self.optionsSyncTableScrollChild, "TOPLEFT", 0, -((index - 1) * 26))
        rowFrame:SetWidth(contentWidth)
        apply_surface_variant(rowFrame, index % 2 == 1 and "row" or "row-alt")
        rowFrame.rowData = row
        rowFrame.characterText:SetText(tostring(row.character or ""))
        rowFrame.lastSeenText:SetText(tostring(row.lastSeen or ""))
        rowFrame.lastSynchronizedText:SetText(tostring(row.lastSynchronized or ""))
        rowFrame.removeButton:SetScript("OnClick", function()
            local syncPeerState = ns.modules.syncPeerState or {}
            local guildKey = current_sync_guild_key(db)
            local characterKey = tostring((rowFrame.rowData or {}).characterKey or "")
            if characterKey == "" or type(syncPeerState.RemovePeer) ~= "function" then
                self:SetOptionsSyncStatus("Sync peer removal is unavailable right now.")
                return
            end

            local removed = syncPeerState.RemovePeer(db, guildKey, characterKey)
            if removed then
                self:SetOptionsSyncStatus(string.format("Removed sync peer %s.", display_character_key(characterKey)))
            else
                self:SetOptionsSyncStatus(string.format("Sync peer %s was already gone.", display_character_key(characterKey)))
            end
            self:RefreshSyncControls()
        end)
        rowFrame:Show()
    end

    for index = #rows + 1, #(self.optionsSyncTableRows or {}) do
        local rowFrame = self.optionsSyncTableRows[index]
        if rowFrame then
            rowFrame.rowData = nil
            rowFrame:Hide()
        end
    end

    if self.optionsSyncTableScrollChild then
        self.optionsSyncTableScrollChild:SetWidth(contentWidth)
        self.optionsSyncTableScrollChild:SetHeight(math.max(24, #rows * 26))
    end

    if self.optionsSyncTableScrollController then
        self.optionsSyncTableScrollController:Refresh(
            self.optionsSyncTableScrollChild and (self.optionsSyncTableScrollChild:GetHeight() or 0) or (#rows * 26),
            self.optionsSyncTableScrollFrame and (self.optionsSyncTableScrollFrame:GetHeight() or 0) or 0
        )
    elseif self.optionsSyncTableScrollFrame then
        self.optionsSyncTableScrollFrame.verticalScrollRange = math.max(0, (self.optionsSyncTableScrollChild and (self.optionsSyncTableScrollChild:GetHeight() or 0) or (#rows * 26)) - (self.optionsSyncTableScrollFrame:GetHeight() or 0))
        self.optionsSyncTableScrollFrame.verticalScroll = math.max(0, math.min(self.optionsSyncTableScrollFrame.verticalScroll or 0, self.optionsSyncTableScrollFrame.verticalScrollRange or 0))
        self.optionsSyncTableScrollFrame:SetVerticalScroll(self.optionsSyncTableScrollFrame.verticalScroll)
    end

    set_frame_shown(self.optionsSyncEmptyStateText, #rows == 0)

    local manualActions = ns.modules.syncManualActions or {}
    local accessProfile = current_access_profile(db)
    local requestOnly = accessProfile == "request_only"

    if self.optionsSyncRequestsButton then
        self.optionsSyncRequestsButton:SetEnabled(true)
    end
    if self.optionsSyncMinimumsButton then
        self.optionsSyncMinimumsButton:SetEnabled(not requestOnly)
    end
    if self.optionsSyncHistoryButton then
        self.optionsSyncHistoryButton:SetEnabled(not requestOnly)
    end
    if self.optionsSyncLedgerButton then
        self.optionsSyncLedgerButton:SetEnabled(not requestOnly)
    end
    if self.optionsSyncAllButton then
        self.optionsSyncAllButton:SetEnabled(not requestOnly)
    end

    if requestOnly then
        self:SetOptionsSyncStatus("Only request sync is available with request-only access. Minimums and ledger sync require broader guild-management access.")
    elseif type(self.optionsSyncStatusText.GetText) == "function" and self.optionsSyncStatusText:GetText() == "" then
        self:SetOptionsSyncStatus("Use these actions to request sync from online guild peers with the addon.")
    end

    local function run_sync_action(action)
        if type(manualActions.Run) ~= "function" then
            self:SetOptionsSyncStatus("Manual sync is unavailable right now.")
            return nil
        end

        local result = manualActions.Run(db, {
            action = action,
            accessProfile = accessProfile,
        })
        self:SetOptionsSyncStatus(type(result) == "table" and result.message or "")
        return result
    end

    if self.optionsSyncRequestsButton then
        self.optionsSyncRequestsButton:SetScript("OnClick", function()
            run_sync_action("requests")
        end)
    end
    if self.optionsSyncMinimumsButton then
        self.optionsSyncMinimumsButton:SetScript("OnClick", function()
            run_sync_action("minimums")
        end)
    end
    if self.optionsSyncHistoryButton then
        self.optionsSyncHistoryButton:SetScript("OnClick", function()
            run_sync_action("history")
        end)
    end
    if self.optionsSyncLedgerButton then
        self.optionsSyncLedgerButton:SetScript("OnClick", function()
            run_sync_action("ledger")
        end)
    end
    if self.optionsSyncAllButton then
        self.optionsSyncAllButton:SetScript("OnClick", function()
            run_sync_action("all")
        end)
    end
end

function mainFrame:ApplyLogsHistoryChoice(fieldName, value)
    local db = current_db()
    local settings = bankLedger.GetSettings(db)
    if fieldName == "ledgerScanIntervalSeconds" then
        settings.ledgerScanIntervalSeconds = tonumber(value) or 300
    else
        settings[fieldName] = tostring(value or "indefinite")
    end
    self:RefreshLogsHistoryControls()
end

function mainFrame:CycleLogsHistoryChoice(fieldName)
    local db = current_db()
    local settings = bankLedger.GetSettings(db)
    if fieldName == "ledgerScanIntervalSeconds" then
        local choices = bankLedger.GetScanIntervalChoices()
        local nextValue = choices[1] and choices[1].value or 300
        for index, choice in ipairs(choices) do
            if tonumber(choice.value) == tonumber(settings.ledgerScanIntervalSeconds) then
                nextValue = (choices[index + 1] or choices[1]).value
                break
            end
        end
        self:ApplyLogsHistoryChoice(fieldName, nextValue)
    else
        local choices = bankLedger.GetRetentionChoices()
        local current = tostring(settings[fieldName] or "indefinite")
        local nextValue = choices[1] and choices[1].value or "indefinite"
        for index, choice in ipairs(choices) do
            if tostring(choice.value) == current then
                nextValue = (choices[index + 1] or choices[1]).value
                break
            end
        end
        self:ApplyLogsHistoryChoice(fieldName, nextValue)
    end
end

function mainFrame:OpenChoiceMenu(ownerButton, choices, onSelect, fallbackCallback)
    choices = type(choices) == "table" and choices or {}
    if ownerButton == nil
        or type(ownerButton.GetWidth) ~= "function"
        or type(ownerButton.ClearAllPoints) ~= "function"
        or #choices == 0
        or type(onSelect) ~= "function"
    then
        if type(fallbackCallback) == "function" then
            fallbackCallback()
        end
        return false
    end

    self.sharedChoiceDropdownPanel = self.sharedChoiceDropdownPanel or _G.CreateFrame("Frame", nil, self, "BackdropTemplate")
    self.sharedChoiceDropdownPanel:SetFrameStrata("DIALOG")
    if type(self.sharedChoiceDropdownPanel.SetFrameLevel) == "function" then
        self.sharedChoiceDropdownPanel:SetFrameLevel(60)
    end
    self.sharedChoiceDropdownPanel:EnableMouse(true)
    apply_surface_variant(self.sharedChoiceDropdownPanel, "panel")
    self.sharedChoiceDropdownOptions = self.sharedChoiceDropdownOptions or {}

    if self.sharedChoiceDropdownOwner == ownerButton and self.sharedChoiceDropdownPanel:IsShown() then
        self.sharedChoiceDropdownPanel:Hide()
        self.sharedChoiceDropdownOwner = nil
        return true
    end

    local maxLabelLength = 0
    for _, choice in ipairs(choices) do
        maxLabelLength = math.max(maxLabelLength, string.len(tostring(choice.label or "")))
    end
    local dropdownWidth = math.max(type(ownerButton.GetWidth) == "function" and (ownerButton:GetWidth() or 0) or 0, math.min(260, math.max(132, 28 + (maxLabelLength * 7))))
    local dropdownHeight = math.max(28, (#choices * 24) + 8)
    self.sharedChoiceDropdownPanel:ClearAllPoints()
    self.sharedChoiceDropdownPanel:SetPoint("TOPLEFT", ownerButton, "BOTTOMLEFT", 0, -2)
    self.sharedChoiceDropdownPanel:SetSize(dropdownWidth, dropdownHeight)

    for index, choice in ipairs(choices) do
        local option = self.sharedChoiceDropdownOptions[index] or make_button(self.sharedChoiceDropdownPanel, dropdownWidth - 8, 22, "")
        apply_button_variant(option, "secondary")
        option:ClearAllPoints()
        option:SetPoint("TOPLEFT", self.sharedChoiceDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
        option:SetWidth(dropdownWidth - 8)
        option.labelText:SetText(choice.label)
        option:SetScript("OnClick", function()
            self.sharedChoiceDropdownPanel:Hide()
            self.sharedChoiceDropdownOwner = nil
            onSelect(choice.value)
        end)
        self.sharedChoiceDropdownOptions[index] = option
        option:Show()
    end
    for index = #choices + 1, #(self.sharedChoiceDropdownOptions or {}) do
        self.sharedChoiceDropdownOptions[index]:Hide()
    end

    self.sharedChoiceDropdownOwner = ownerButton
    self.sharedChoiceDropdownPanel:Show()
    return true
end

function mainFrame:HideChoiceMenu()
    if self.sharedChoiceDropdownPanel then
        self.sharedChoiceDropdownPanel:Hide()
        self.sharedChoiceDropdownOwner = nil
    end
end

function mainFrame:OpenLogsHistoryChoiceMenu(fieldName, ownerButton)
    local choiceProvider = fieldName == "ledgerScanIntervalSeconds"
        and bankLedger.GetScanIntervalChoices
        or bankLedger.GetRetentionChoices
    local choices = type(choiceProvider) == "function" and choiceProvider() or {}
    self:OpenChoiceMenu(ownerButton, choices, function(value)
        self:ApplyLogsHistoryChoice(fieldName, value)
    end, function()
        self:CycleLogsHistoryChoice(fieldName)
    end)
end

function mainFrame:OpenBankLedgerActionFilterMenu()
    local bankLedgerView = current_bank_ledger_view()
    local choices = type(bankLedgerView.GetActionChoices) == "function"
        and bankLedgerView.GetActionChoices(mainFrame.bankLedgerMode)
        or {}
    self:OpenChoiceMenu(self.bankLedgerActionFilterButton, choices, function(value)
        self.bankLedgerActionFilter = value
        if self.activeView == "BANK_LEDGER" then
            self:RefreshBankLedgerTable()
        end
    end, function()
        self.bankLedgerActionFilter = bankLedgerView.CycleActionFilter(mainFrame.bankLedgerMode, mainFrame.bankLedgerActionFilter)
        if self.activeView == "BANK_LEDGER" then
            self:RefreshBankLedgerTable()
        end
    end)
end

function mainFrame:OpenBankLedgerDateRangeMenu()
    local bankLedgerView = current_bank_ledger_view()
    local choices = type(bankLedgerView.GetDateRangeChoices) == "function"
        and bankLedgerView.GetDateRangeChoices()
        or {}
    self:OpenChoiceMenu(self.bankLedgerDateRangeButton, choices, function(value)
        self.bankLedgerDateRangeFilter = tostring(value or "all")
        if self.activeView == "BANK_LEDGER" then
            self:RefreshBankLedgerTable()
        end
    end)
end

function mainFrame:SaveLogsHistorySettings()
    local db = current_db()
    local settings = bankLedger.GetSettings(db)
    settings.ledgerScanIntervalSeconds = math.max(300, tonumber(settings.ledgerScanIntervalSeconds or 300) or 300)
    settings.ledgerRetention = tostring(settings.ledgerRetention or "indefinite")
    settings.historyRetention = tostring(settings.historyRetention or "indefinite")
    if self.optionsRepairThresholdInput and type(self.optionsRepairThresholdInput.GetText) == "function" then
        settings.repairThresholdGold = math.max(0, math.floor(tonumber(self.optionsRepairThresholdInput:GetText() or settings.repairThresholdGold or 5000) or (tonumber(settings.repairThresholdGold or 5000) or 5000)))
    end
    if self.optionsMuteSilvermoonCitizenToggle and type(self.optionsMuteSilvermoonCitizenToggle.GetChecked) == "function" then
        settings.muteSilvermoonCitizen = self.optionsMuteSilvermoonCitizenToggle:GetChecked() and true or false
    end
    if bankLedger and type(bankLedger.PruneRetention) == "function" then
        local now = type(_G.time) == "function" and (_G.time() or 0) or 0
        bankLedger.PruneRetention(db, now)
    end
    self:RefreshLogsHistoryControls()
    if self.activeView == "HISTORY" or self.activeView == "BANK_LEDGER" then
        self:RefreshView()
    end
    if self.optionsLogsHistoryStatusText then
        self.optionsLogsHistoryStatusText:SetText("Saved logs/history settings.")
    end
    return settings
end

function mainFrame:CloseLedgerDedupeModals()
    if self.ledgerDedupePreviewModal then
        self.ledgerDedupePreviewModal:Hide()
    end
    if self.ledgerDedupeReviewModal then
        self.ledgerDedupeReviewModal:Hide()
    end
end

function mainFrame:BuildLedgerDedupeReviewText(plan)
    plan = type(plan) == "table" and plan or {}
    local lines = {
        string.format("Duplicate rows to remove: %d", tonumber(plan.totalDuplicateRowCount or 0) or 0),
        string.format("Duplicate groups: %d", tonumber(plan.totalDuplicateGroupCount or 0) or 0),
        string.format("Item duplicates: %d", tonumber(plan.itemDuplicateRowCount or 0) or 0),
        string.format("Money duplicates: %d", tonumber(plan.moneyDuplicateRowCount or 0) or 0),
        "",
    }

    for _, row in ipairs(plan.reviewRows or {}) do
        lines[#lines + 1] = tostring(row.summary or "")
    end

    return table.concat(lines, "\n")
end

function mainFrame:RefreshLedgerDedupeReviewScrollMetrics(text)
    local output = self.ledgerDedupeReviewOutput
    if not output then
        return nil
    end

    local viewportHeight = tonumber(output:GetHeight() or 0) or 0
    local contentHeight = math.max(viewportHeight, (count_lines(text or output:GetText()) * 15) + 16)
    local editBox = output.EditBox
    if editBox and type(editBox.SetHeight) == "function" then
        editBox:SetHeight(contentHeight)
    end

    output.verticalScroll = 0
    if type(output.SetVerticalScroll) == "function" then
        output:SetVerticalScroll(0)
    end
    if self.ledgerDedupeReviewScrollController and type(self.ledgerDedupeReviewScrollController.Refresh) == "function" then
        self.ledgerDedupeReviewScrollController:Refresh(contentHeight, viewportHeight)
    end
    return contentHeight
end

function mainFrame:OpenLedgerDedupePreviewModal(plan)
    plan = type(plan) == "table" and plan or {}
    self.pendingLedgerDedupePlan = plan
    self.ledgerDedupePreviewSummaryText:SetText(string.format(
        "Found %d duplicate row(s) across %d group(s).\nItem duplicates: %d\nMoney duplicates: %d\nUse Review Rows to inspect the exact rows before cleanup.",
        tonumber(plan.totalDuplicateRowCount or 0) or 0,
        tonumber(plan.totalDuplicateGroupCount or 0) or 0,
        tonumber(plan.itemDuplicateRowCount or 0) or 0,
        tonumber(plan.moneyDuplicateRowCount or 0) or 0
    ))
    self.ledgerDedupeReviewModal:Hide()
    self.ledgerDedupePreviewModal:Show()
    self:BringToFront(self.ledgerDedupePreviewModal)
    return self.ledgerDedupePreviewModal
end

function mainFrame:OpenLedgerDedupeReviewModal()
    local plan = type(self.pendingLedgerDedupePlan) == "table" and self.pendingLedgerDedupePlan or nil
    if not plan then
        return nil
    end

    local reviewText = self:BuildLedgerDedupeReviewText(plan)
    self.ledgerDedupeReviewOutput:SetText(reviewText)
    self:RefreshLedgerDedupeReviewScrollMetrics(reviewText)
    self.ledgerDedupeReviewOutput:SetFocus()
    self.ledgerDedupeReviewOutput:SetCursorPosition(0)
    self.ledgerDedupePreviewModal:Hide()
    self.ledgerDedupeReviewModal:Show()
    self:BringToFront(self.ledgerDedupeReviewModal)
    return self.ledgerDedupeReviewModal
end

function mainFrame:ApplyLedgerDedupePlan()
    local ledgerModule = ns.modules.bankLedger or {}
    local plan = type(self.pendingLedgerDedupePlan) == "table" and self.pendingLedgerDedupePlan or nil
    if type(ledgerModule.ApplyDedupePlan) ~= "function" or not plan then
        return nil
    end

    local result = ledgerModule.ApplyDedupePlan(current_db(), plan)
    self.pendingLedgerDedupePlan = nil
    self:CloseLedgerDedupeModals()
    if type(self.RefreshView) == "function" then
        self:RefreshView()
    end
    if self.optionsLogsHistoryStatusText then
        self.optionsLogsHistoryStatusText:SetText(string.format(
            "Removed %d duplicate ledger row(s).",
            tonumber((result or {}).totalRemoved or 0) or 0
        ))
    end
    return result
end

local function ensure_clear_data_popups()
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    local popupDefinitions = {
        GBM_CONFIRM_CLEAR_BANK_LEDGER = "This is irreversible. Clear all saved guild bank log data?",
        GBM_CONFIRM_CLEAR_INVENTORY = "This is irreversible. Clear all saved guild bank inventory data?",
        GBM_CONFIRM_CLEAR_COMPLETED_REQUESTS = "This is irreversible. Clear completed request history and matching audit rows?",
    }

    for which, text in pairs(popupDefinitions) do
        if _G.StaticPopupDialogs[which] == nil then
            _G.StaticPopupDialogs[which] = {
                text = text,
                button1 = "Confirm",
                button2 = "Cancel",
                OnAccept = function(_, data)
                    if type(data) == "table" and type(data.confirm) == "function" then
                        data.confirm()
                    end
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                preferredIndex = 3,
            }
        end
    end
end

local function show_clear_popup(which, confirmCallback)
    ensure_clear_data_popups()
    if type(_G.StaticPopup_Show) == "function" then
        _G.StaticPopup_Show(which, nil, nil, {
            confirm = confirmCallback,
        })
    elseif type(confirmCallback) == "function" then
        confirmCallback()
    end
end

mainFrame.optionsLedgerRetentionButton:SetScript("OnClick", function()
    mainFrame:OpenLogsHistoryChoiceMenu("ledgerRetention", mainFrame.optionsLedgerRetentionButton)
end)

mainFrame.optionsHistoryRetentionButton:SetScript("OnClick", function()
    mainFrame:OpenLogsHistoryChoiceMenu("historyRetention", mainFrame.optionsHistoryRetentionButton)
end)

mainFrame.optionsLedgerScanIntervalButton:SetScript("OnClick", function()
    mainFrame:OpenLogsHistoryChoiceMenu("ledgerScanIntervalSeconds", mainFrame.optionsLedgerScanIntervalButton)
end)

mainFrame.optionsLogsHistorySaveButton:SetScript("OnClick", function()
    mainFrame:SaveLogsHistorySettings()
end)

mainFrame.optionsDedupeLedgerButton:SetScript("OnClick", function()
    local ledgerModule = ns.modules.bankLedger or {}
    if type(ledgerModule.BuildDedupePlan) ~= "function" then
        return
    end

    local plan = ledgerModule.BuildDedupePlan(current_db())
    if (tonumber((plan or {}).totalDuplicateRowCount or 0) or 0) <= 0 then
        if mainFrame.optionsLogsHistoryStatusText then
            mainFrame.optionsLogsHistoryStatusText:SetText("No duplicate ledger rows found.")
        end
        return
    end

    mainFrame:OpenLedgerDedupePreviewModal(plan)
end)

mainFrame.optionsClearBankLedgerButton:SetScript("OnClick", function()
    show_clear_popup("GBM_CONFIRM_CLEAR_BANK_LEDGER", function()
        local store = ns.modules.store or {}
        if type(store.ClearGuildBankLogData) == "function" then
            store.ClearGuildBankLogData(current_db())
        end
        if type(mainFrame.RefreshView) == "function" then
            mainFrame:RefreshView()
        end
        if mainFrame.optionsLogsHistoryStatusText then
            mainFrame.optionsLogsHistoryStatusText:SetText("Cleared guild bank log data.")
        end
    end)
end)

mainFrame.optionsClearInventoryDataButton:SetScript("OnClick", function()
    show_clear_popup("GBM_CONFIRM_CLEAR_INVENTORY", function()
        local store = ns.modules.store or {}
        if type(store.ClearGuildBankInventoryData) == "function" then
            store.ClearGuildBankInventoryData(current_db())
        end
        if type(mainFrame.RefreshView) == "function" then
            mainFrame:RefreshView()
        end
        if mainFrame.optionsLogsHistoryStatusText then
            mainFrame.optionsLogsHistoryStatusText:SetText("Cleared guild bank inventory data.")
        end
    end)
end)

mainFrame.optionsClearCompletedRequestsButton:SetScript("OnClick", function()
    show_clear_popup("GBM_CONFIRM_CLEAR_COMPLETED_REQUESTS", function()
        local store = ns.modules.store or {}
        if type(store.ClearCompletedRequestHistory) == "function" then
            store.ClearCompletedRequestHistory(current_db())
        end
        if type(mainFrame.RefreshView) == "function" then
            mainFrame:RefreshView()
        end
        if mainFrame.optionsLogsHistoryStatusText then
            mainFrame.optionsLogsHistoryStatusText:SetText("Cleared completed request history.")
        end
    end)
end)

mainFrame.ledgerDedupePreviewReviewButton:SetScript("OnClick", function()
    mainFrame:OpenLedgerDedupeReviewModal()
end)

mainFrame.ledgerDedupePreviewApplyButton:SetScript("OnClick", function()
    mainFrame:ApplyLedgerDedupePlan()
end)

mainFrame.ledgerDedupePreviewCancelButton:SetScript("OnClick", function()
    mainFrame.pendingLedgerDedupePlan = nil
    mainFrame:CloseLedgerDedupeModals()
end)

mainFrame.ledgerDedupeReviewBackButton:SetScript("OnClick", function()
    local plan = type(mainFrame.pendingLedgerDedupePlan) == "table" and mainFrame.pendingLedgerDedupePlan or nil
    if plan then
        mainFrame:OpenLedgerDedupePreviewModal(plan)
    else
        mainFrame:CloseLedgerDedupeModals()
    end
end)

mainFrame.ledgerDedupeReviewApplyButton:SetScript("OnClick", function()
    mainFrame:ApplyLedgerDedupePlan()
end)

mainFrame.ledgerDedupeReviewCancelButton:SetScript("OnClick", function()
    mainFrame.pendingLedgerDedupePlan = nil
    mainFrame:CloseLedgerDedupeModals()
end)

function mainFrame:GetOptionsCanvasPanel()
    local activeTab = self.optionsActiveTab or "APPEARANCE"
    if activeTab == "APPEARANCE" then
        return self.optionsAppearancePanel
    end
    if activeTab == "STOCK" then
        return self.optionsStockSettingsPanel
    end
    if activeTab == "PERMISSIONS" or activeTab == "BLACKLIST" then
        return self.optionsAuthPanel
    end
    if activeTab == "SYNC" then
        return self.optionsSyncPanel
    end
    if activeTab == "LOGS_HISTORY" then
        return self.optionsLogsHistoryPanel
    end

    return self.optionsAppearancePanel
end

function mainFrame:SetOptionsTab(tabKey)
    local nextTab = tostring(tabKey or "APPEARANCE")
    if request_only_shell(self) then
        nextTab = normalize_request_only_options_tab(nextTab)
    end
    self.optionsActiveTab = nextTab

    set_frame_shown(self.optionsAppearancePanel, nextTab == "APPEARANCE")
    set_frame_shown(self.optionsMuteSilvermoonCitizenToggle, nextTab == "APPEARANCE")
    set_frame_shown(self.optionsSuppressRoutineChatToggle, nextTab == "APPEARANCE")
    set_frame_shown(self.optionsStockSettingsPanel, nextTab == "STOCK")
    set_frame_shown(self.optionsPermissionsPanel, nextTab == "PERMISSIONS")
    set_frame_shown(self.optionsBlacklistPanel, nextTab == "BLACKLIST")
    set_frame_shown(self.optionsSyncPanel, nextTab == "SYNC")
    set_frame_shown(self.optionsLogsHistoryPanel, nextTab == "LOGS_HISTORY")
    set_frame_shown(self.optionsAuthPanel, nextTab == "PERMISSIONS" or nextTab == "BLACKLIST")
    set_frame_shown(self.optionsAutomationPanel, false)
    set_frame_shown(self.optionsExportsPanel, false)
    set_frame_shown(self.optionsRequestsPanel, false)

    local previousVisibleButton = nil
    for _, button in ipairs(self.optionsTabButtons or {}) do
        local showButton = not request_only_shell(self) or request_only_options_tab_allowed(button.key)
        if type(button.ClearAllPoints) == "function" then
            button:ClearAllPoints()
        end
        if showButton then
            if previousVisibleButton == nil then
                button:SetPoint("TOPLEFT", self.optionsTabBar, "TOPLEFT", 0, 0)
            else
                button:SetPoint("LEFT", previousVisibleButton, "RIGHT", 8, 0)
            end
            button:Show()
            previousVisibleButton = button
        else
            button:Hide()
        end

        apply_button_variant(button, button.key == nextTab and "primary" or "tab")
        button.gbmTabStyle = "segmented-soft"
    end

    if self.optionsScrollFrame then
        self.optionsScrollFrame.verticalScroll = 0
        self.optionsScrollFrame:SetVerticalScroll(0)
    end

    if nextTab == "SYNC" and type(self.RefreshSyncControls) == "function" then
        self:RefreshSyncControls()
    end

    self:UpdateOptionsCanvasHeight()
    self:SyncOptionsScrollVisuals()
    return self.optionsActiveTab
end

for _, button in ipairs(mainFrame.optionsTabButtons or {}) do
    button:SetScript("OnClick", function(selfButton)
        mainFrame:SetOptionsTab(selfButton.key)
    end)
end

function mainFrame:EnsureOnboardingModal()
    if self.onboardingModal then
        return self.onboardingModal
    end

    local themeState = mainFrameShell.GetTheme()
    local modal = _G.CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    modal:SetSize(548, 360)
    modal:SetPoint("CENTER", self.content, "CENTER", 0, 0)
    if type(modal.SetMovable) == "function" then
        modal:SetMovable(true)
    end
    modal:EnableMouse(true)
    if type(modal.RegisterForDrag) == "function" then
        modal:RegisterForDrag("LeftButton")
    end
    apply_surface_variant(modal, "modal-sheet")
    modal:Hide()
    self:RegisterModalFrame(modal, 24, "FULLSCREEN_DIALOG")
    if type(modal.SetScript) == "function" then
        modal:SetScript("OnDragStart", function(frame)
            if type(frame.StartMoving) == "function" then
                frame:StartMoving()
            end
        end)
        modal:SetScript("OnDragStop", function(frame)
            if type(frame.StopMovingOrSizing) == "function" then
                frame:StopMovingOrSizing()
            end
        end)
    end

    modal.titleText = make_label(modal, "First-Run Onboarding", "GameFontHighlight")
    modal.titleText:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)

    modal.progressText = make_label(modal, "", "GameFontHighlightSmall")
    modal.progressText:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -18)

    modal.stepTitleText = make_label(modal, "", "GameFontHighlightLarge")
    modal.stepTitleText:SetPoint("TOPLEFT", modal.titleText, "BOTTOMLEFT", 0, -18)

    modal.stepDescriptionText = make_label(modal, "", "GameFontHighlightSmall")
    modal.stepDescriptionText:SetPoint("TOPLEFT", modal.stepTitleText, "BOTTOMLEFT", 0, -14)
    if type(modal.stepDescriptionText.SetWidth) == "function" then
        modal.stepDescriptionText:SetWidth(512)
    end
    if type(modal.stepDescriptionText.SetJustifyH) == "function" then
        modal.stepDescriptionText:SetJustifyH("LEFT")
    end
    if type(modal.stepDescriptionText.SetWordWrap) == "function" then
        modal.stepDescriptionText:SetWordWrap(true)
    end

    modal.primaryActionButton = make_button(modal, 164, 24, "")

    modal.backButton = make_button(modal, 88, 24, "Back")

    modal.nextButton = make_button(modal, 96, 24, "Next")

    modal.doNotShowAgainButton = make_button(modal, 188, 24, "Do Not Show Again")

    modal.nextButton:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -18, 18)
    modal.doNotShowAgainButton:SetPoint("RIGHT", modal.nextButton, "LEFT", -12, 0)
    modal.primaryActionButton:SetPoint("RIGHT", modal.doNotShowAgainButton, "LEFT", -12, 0)
    modal.backButton:SetPoint("RIGHT", modal.primaryActionButton, "LEFT", -12, 0)

    apply_surface_variant(modal, "modal-sheet")
    apply_button_variant(modal.primaryActionButton, "primary")
    apply_button_variant(modal.backButton, "secondary")
    apply_button_variant(modal.nextButton, "primary")
    apply_button_variant(modal.doNotShowAgainButton, "secondary")

    if themeState and themeState.tokens then
        set_label_color(modal.titleText, themeState.tokens.header)
        set_label_color(modal.progressText, themeState.tokens.textMuted)
        set_label_color(modal.stepTitleText, themeState.tokens.header)
        set_label_color(modal.stepDescriptionText, themeState.tokens.text)
    end

    modal.backButton:SetScript("OnClick", function()
        self.onboardingStepIndex = math.max(1, (self.onboardingStepIndex or 1) - 1)
        self.onboardingCurrentStep = (self.onboardingSteps or {})[self.onboardingStepIndex]
        self:RenderOnboardingStep()
    end)
    modal.nextButton:SetScript("OnClick", function()
        self:AdvanceOnboardingStep()
    end)
    modal.doNotShowAgainButton:SetScript("OnClick", function()
        local onboarding = ns.modules.onboarding
        if onboarding and type(onboarding.MarkDoNotShowAgain) == "function" then
            onboarding.MarkDoNotShowAgain(current_db(), self.onboardingFlowKey)
        end
        self:CloseOnboarding()
    end)
    modal.primaryActionButton:SetScript("OnClick", function()
        self:RunOnboardingPrimaryAction()
    end)

    self.onboardingModal = modal
    return self.onboardingModal
end

function mainFrame:RenderOnboardingStep()
    local modal = self:EnsureOnboardingModal()
    local steps = self.onboardingSteps or {}
    local stepCount = #steps
    local stepIndex = math.max(1, math.min(tonumber(self.onboardingStepIndex or 1) or 1, math.max(stepCount, 1)))
    local step = steps[stepIndex] or {}

    self.onboardingStepIndex = stepIndex
    self.onboardingCurrentStep = step

    modal.titleText:SetText("First-Run Onboarding")
    modal.progressText:SetText(string.format("Step %d of %d", stepIndex, math.max(stepCount, 1)))
    modal.stepTitleText:SetText(step.title or "Welcome")
    modal.stepDescriptionText:SetText(step.description or "")
    modal.primaryActionButton.labelText:SetText(step.primaryActionLabel or "Open")
    modal.nextButton.labelText:SetText(stepIndex >= stepCount and "Finish" or "Next")

    local showPrimaryAction = tostring(step.primaryActionLabel or "") ~= ""
    set_frame_shown(modal.primaryActionButton, showPrimaryAction)
    set_frame_shown(modal.backButton, stepIndex > 1)
    set_frame_shown(modal.nextButton, stepCount > 0)
    set_frame_shown(modal.doNotShowAgainButton, stepIndex == 1)

    if type(modal.nextButton.ClearAllPoints) == "function" then
        modal.nextButton:ClearAllPoints()
    end
    if type(modal.primaryActionButton.ClearAllPoints) == "function" then
        modal.primaryActionButton:ClearAllPoints()
    end
    if type(modal.backButton.ClearAllPoints) == "function" then
        modal.backButton:ClearAllPoints()
    end
    if type(modal.doNotShowAgainButton.ClearAllPoints) == "function" then
        modal.doNotShowAgainButton:ClearAllPoints()
    end

    if stepIndex == 1 then
        modal.nextButton:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -18, 18)
        modal.doNotShowAgainButton:SetPoint("RIGHT", modal.nextButton, "LEFT", -12, 0)
        modal.primaryActionButton:SetPoint("RIGHT", modal.doNotShowAgainButton, "LEFT", -12, 0)
        modal.backButton:SetPoint("RIGHT", modal.primaryActionButton, "LEFT", -12, 0)
    else
        modal.nextButton:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -18, 18)
        modal.doNotShowAgainButton:SetPoint("RIGHT", modal.nextButton, "LEFT", -12, 0)
        modal.backButton:SetPoint("RIGHT", modal.nextButton, "LEFT", -12, 0)
        modal.primaryActionButton:SetPoint("RIGHT", modal.backButton, "LEFT", -12, 0)
    end
end

function mainFrame:OpenOnboarding(flowKey, options)
    local onboarding = ns.modules.onboarding
    local steps = onboarding and type(onboarding.GetSteps) == "function" and onboarding.GetSteps(flowKey) or {}
    if type(steps) ~= "table" or #steps == 0 then
        return nil
    end

    if flowKey == "requestOnly" then
        self:ShowRequestOnly()
    else
        self:ShowDashboard()
    end

    local modal = self:EnsureOnboardingModal()
    modal:ClearAllPoints()
    modal:SetPoint("CENTER", self.content, "CENTER", 0, 0)
    self.onboardingFlowKey = flowKey
    self.onboardingSteps = steps
    self.onboardingStepIndex = 1
    self.onboardingCurrentStep = steps[1]
    self.onboardingOpenOptions = type(options) == "table" and options or {}

    self:RenderOnboardingStep()
    modal:Show()
    self:BringToFront(modal)
    return modal
end

function mainFrame:AdvanceOnboardingStep()
    local steps = self.onboardingSteps or {}
    local stepCount = #steps
    if stepCount == 0 then
        self:CloseOnboarding()
        return nil
    end

    if (self.onboardingStepIndex or 1) >= stepCount then
        local onboarding = ns.modules.onboarding
        if onboarding and type(onboarding.MarkCompleted) == "function" then
            onboarding.MarkCompleted(current_db(), self.onboardingFlowKey)
        end
        self:CloseOnboarding()
        return nil
    end

    self.onboardingStepIndex = (self.onboardingStepIndex or 1) + 1
    self.onboardingCurrentStep = steps[self.onboardingStepIndex]
    self:RenderOnboardingStep()
    return self.onboardingStepIndex
end

function mainFrame:CloseOnboarding()
    if self.onboardingModal then
        self.onboardingModal:Hide()
    end

    self.onboardingFlowKey = nil
    self.onboardingSteps = nil
    self.onboardingStepIndex = nil
    self.onboardingCurrentStep = nil
    self.onboardingOpenOptions = nil
    return self.onboardingModal
end

function mainFrame:RunOnboardingPrimaryAction()
    local step = self.onboardingCurrentStep or {}
    if step.targetView == "OPTIONS" then
        self:ShowDashboard()
        self:SelectView("OPTIONS")
        if step.optionsTab then
            self:SetOptionsTab(step.optionsTab)
        end
        return self.activeView
    end

    if step.targetView == "REQUESTS" and self.onboardingFlowKey == "requestOnly" then
        self:ShowRequestOnly()
        if step.primaryAction == "open_request_wizard" and type(self.OpenRequestWizard) == "function" then
            self:OpenRequestWizard()
        end
        return self.activeView
    end

    if step.targetView == "REQUESTS" then
        self:ShowDashboard()
        self:SelectView("REQUESTS")
        return self.activeView
    end

    if step.targetView == "DASHBOARD" then
        self:ShowDashboard()
        return self.activeView
    end

    return nil
end

function mainFrame:GetBankLedgerFilters()
    local tableFilters = self:GetSharedFilterState()
    local bankLedgerView = current_bank_ledger_view()
    return bankLedgerView.BuildFilters(
        self.bankLedgerMode,
        tableFilters,
        self.bankLedgerActionFilter,
        self.bankLedgerDateRangeFilter or "all"
    )
end

function mainFrame:RefreshBankLedgerSummary()
    local bankLedgerView = current_bank_ledger_view()
    local summary = bankLedgerView.BuildSummaryTexts(current_db(), self.bankLedgerMode, self:GetBankLedgerFilters())
    self.bankLedgerSummaryPrimaryText:SetText(summary[1] or "")
    self.bankLedgerSummarySecondaryText:SetText(summary[2] or "")
    self.bankLedgerSummaryTertiaryText:SetText(summary[3] or "")
end

function mainFrame:RefreshBankLedgerTable()
    local db = current_db()
    local bankLedgerView = current_bank_ledger_view()
    local columns = bankLedgerView.GetColumns(self.bankLedgerMode)
    local rows = bankLedgerView.BuildDisplayRows(db, self.bankLedgerMode, self:GetBankLedgerFilters())
    self.tableScrollOffset = 0
    self:ConfigureTable(columns, rows)
    self:RefreshVisibleTableRows()
    self:RefreshBankLedgerSummary()
    if self.bankLedgerActionFilterButton and self.bankLedgerActionFilterButton.labelText then
        self.bankLedgerActionFilterButton.labelText:SetText(bankLedgerView.GetActionChoiceLabel(self.bankLedgerMode, self.bankLedgerActionFilter))
    end
    if self.bankLedgerDateRangeButton and self.bankLedgerDateRangeButton.labelText then
        self.bankLedgerDateRangeButton.labelText:SetText(bankLedgerView.GetDateRangeChoiceLabel(self.bankLedgerDateRangeFilter))
    end
end

function mainFrame:SetBankLedgerMode(mode)
    self.bankLedgerMode = tostring(mode or "ITEM")
    self.bankLedgerActionFilter = ""
    self.bankLedgerDateRangeFilter = self.bankLedgerDateRangeFilter or "all"
    apply_button_variant(self.bankLedgerItemModeButton, self.bankLedgerMode == "ITEM" and "primary" or "tab")
    apply_button_variant(self.bankLedgerMoneyModeButton, self.bankLedgerMode == "MONEY" and "primary" or "tab")
    if self.activeView == "BANK_LEDGER" then
        self:RefreshBankLedgerTable()
    end
    return self.bankLedgerMode
end

function mainFrame:OpenBankLedgerExportModal()
    local bankLedgerView = current_bank_ledger_view()
    local csvText = bankLedgerView.BuildCsvText(current_db(), self.bankLedgerMode, self:GetBankLedgerFilters())
    self.exportModalTitle:SetText(self.bankLedgerMode == "MONEY" and "Bank Ledger Money CSV" or "Bank Ledger Item CSV")
    self.exportModalHint:SetText("Select all and copy the filtered ledger export.")
    self.exportModalOutputInput:SetText(csvText or "")
    if type(self.RefreshExportModalScrollMetrics) == "function" then
        self:RefreshExportModalScrollMetrics()
    end
    if type(set_frame_shown) == "function" then
        set_frame_shown(self.exportModalBuyAllButton, false)
        set_frame_shown(self.exportModalMissingOnlyButton, false)
        set_frame_shown(self.exportModalScrollFrame, true)
        set_frame_shown(self.exportModalSelectAllButton, true)
        set_frame_shown(self.exportModalCopyButton, false)
    end
    self.exportModal:Show()
    return self.exportModal
end

function mainFrame:OpenInventoryExportModal()
    local inventoryView = ns.modules.inventoryView or {}
    local csvText = type(inventoryView.BuildCsvText) == "function" and inventoryView.BuildCsvText(self.cachedInventoryRows or {}) or ""
    self.exportModalTitle:SetText("Inventory CSV")
    self.exportModalHint:SetText("Select all and copy the filtered inventory export.")
    self.exportModalOutputInput:SetText(csvText or "")
    if type(self.RefreshExportModalScrollMetrics) == "function" then
        self:RefreshExportModalScrollMetrics()
    end
    if type(set_frame_shown) == "function" then
        set_frame_shown(self.exportModalBuyAllButton, false)
        set_frame_shown(self.exportModalMissingOnlyButton, false)
        set_frame_shown(self.exportModalScrollFrame, true)
        set_frame_shown(self.exportModalSelectAllButton, true)
        set_frame_shown(self.exportModalCopyButton, false)
    end
    self.exportModal:Show()
    return self.exportModal
end

mainFrame.bankLedgerItemModeButton:SetScript("OnClick", function()
    mainFrame:SetBankLedgerMode("ITEM")
end)

mainFrame.bankLedgerMoneyModeButton:SetScript("OnClick", function()
    mainFrame:SetBankLedgerMode("MONEY")
end)

mainFrame.bankLedgerActionFilterButton:SetScript("OnClick", function()
    mainFrame:OpenBankLedgerActionFilterMenu()
end)

mainFrame.bankLedgerDateRangeButton:SetScript("OnClick", function()
    mainFrame:OpenBankLedgerDateRangeMenu()
end)

mainFrame.bankLedgerExportButton:SetScript("OnClick", function()
    mainFrame:OpenBankLedgerExportModal()
end)

mainFrame.inventoryExportButton:SetScript("OnClick", function()
    mainFrame:OpenInventoryExportModal()
end)

function mainFrame:ScrollOptionsBy(delta)
    local controller = self.optionsScrollController
    if not controller then
        return 0
    end

    return controller:ScrollBy(delta or 0)
end

function mainFrame:SetOptionsScrollProgress(progress)
    local controller = self.optionsScrollController
    if not controller then
        return 0
    end

    return controller:SetProgress(progress or 0)
end

function mainFrame:UpdateOptionsCanvasHeight()
    local contentPanel = self:GetOptionsCanvasPanel()
    local contentHeight = (contentPanel and (contentPanel:GetHeight() or 0) or 0) + 16
    if self.optionsScrollChild then
        self.optionsScrollChild:SetWidth(math.max(0, (self.optionsScrollFrame and (self.optionsScrollFrame:GetWidth() or 0) or 0) - 4))
        self.optionsScrollChild:SetHeight(contentHeight)
    end

    if self.optionsScrollFrame then
        self.optionsScrollFrame.verticalScrollRange = math.max(0, contentHeight - (self.optionsScrollFrame:GetHeight() or 0))
        self.optionsScrollFrame.verticalScroll = math.max(0, math.min(self.optionsScrollFrame.verticalScroll or 0, self.optionsScrollFrame.verticalScrollRange))
        self.optionsScrollFrame:SetVerticalScroll(self.optionsScrollFrame.verticalScroll)
    end

    if self.optionsScrollController then
        self.optionsScrollController:Refresh(contentHeight, self.optionsScrollFrame and (self.optionsScrollFrame:GetHeight() or 0) or 0)
    end

    return contentHeight
end

function mainFrame:SyncOptionsScrollVisuals()
    local controller = self.optionsScrollController
    if not controller then
        return
    end

    controller:Refresh()
end

function mainFrame:UpdateOptionsAuthLayout(allowedCount, availableCount)
    local visibleCount = math.max(allowedCount or 0, availableCount or 0)
    local rowCount = math.min(6, math.max(1, visibleCount))
    local permissionPanelHeight = math.max(74, 18 + (rowCount * 20))

    self.optionsAllowedPermissionPanel:SetHeight(permissionPanelHeight)
    self.optionsAvailablePermissionPanel:SetHeight(permissionPanelHeight)
    self.optionsPermissionsPanel:SetHeight(620 + math.max(0, permissionPanelHeight - 118))
    self.optionsAuthPanel:SetHeight(math.max(self.optionsPermissionsPanel:GetHeight() or 0, self.optionsBlacklistPanel:GetHeight() or 0))
    self:UpdateOptionsCanvasHeight()
end

function mainFrame:GetAuthDraftPolicy(db)
    db = db or current_db()
    local permissions = ns.modules.auth or ns.modules.permissions

    if not self.authDraftPolicy then
        self.authDraftPolicy = clone_table((db or {}).auth or {})
    end

    if permissions and type(permissions.NormalizePolicy) == "function" then
        self.authDraftPolicy = permissions.NormalizePolicy(self.authDraftPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end

    return self.authDraftPolicy
end

function mainFrame:LoadAuthOptionsFromDb(db)
    db = db or current_db()
    local authPolicySource = ns.modules.authPolicySource
    if authPolicySource and type(authPolicySource.PullPolicyFromGuildInfo) == "function" then
        authPolicySource.PullPolicyFromGuildInfo(db)
    end
    self.authDraftPolicy = clone_table((db or {}).auth or {})
    self.authBlacklistSelectedKey = nil
    self.authRankDropdownShown = false
    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self.selectedAuthRankIndex = nil
    self:RefreshAuthOptions()
end

function mainFrame:GetAuthRankList()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(current_db())
    if permissions and type(permissions.GetSortedRankMetadata) == "function" then
        return permissions.GetSortedRankMetadata(policy)
    end

    return {}
end

function mainFrame:GetSelectedAuthRankIndex()
    local ranks = self:GetAuthRankList()
    if self.selectedAuthRankIndex ~= nil then
        return self.selectedAuthRankIndex
    end

    if ranks[1] then
        self.selectedAuthRankIndex = ranks[1].rankIndex
        return self.selectedAuthRankIndex
    end

    return nil
end

function mainFrame:SelectAuthRank(rankIndex)
    self.selectedAuthRankIndex = tonumber(rankIndex)
    self.authRankDropdownShown = false
    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self:RefreshAuthOptions()
    return self.selectedAuthRankIndex
end

function mainFrame:OpenAuthRankChoiceMenu()
    local choices = {}
    for _, rank in ipairs(self:GetAuthRankList() or {}) do
        choices[#choices + 1] = {
            value = rank.rankIndex,
            label = rank.name,
        }
    end

    return self:OpenChoiceMenu(self.optionsAuthRankButton, choices, function(value)
        self:SelectAuthRank(value)
    end)
end

function mainFrame:ToggleAuthRankDropdown()
    self.authRankDropdownShown = false
    return self:OpenAuthRankChoiceMenu()
end

function mainFrame:SetAuthPermissionListVisibility(visible)
    local shouldShow = visible == true
    set_frame_shown(self.optionsAllowedPermissionTitle, shouldShow)
    set_frame_shown(self.optionsAllowedPermissionPanel, shouldShow)
    set_frame_shown(self.optionsAvailablePermissionTitle, shouldShow)
    set_frame_shown(self.optionsAvailablePermissionPanel, shouldShow)
    set_frame_shown(self.optionsAuthAddPermissionButton, shouldShow)
    set_frame_shown(self.optionsAuthRemovePermissionButton, shouldShow)
    set_frame_shown(self.optionsAuthRankDropdownOccluder, false)
    set_frame_shown(self.optionsAuthRankDropdownBackdrop, false)

    for _, button in ipairs(self.optionsAllowedPermissionButtons or {}) do
        if button.labelText and type(button.labelText.SetAlpha) == "function" then
            button.labelText:SetAlpha(shouldShow and 1 or 0)
        end
        if shouldShow and (button.labelText:GetText() or "") ~= "" then
            button:Show()
        else
            button:Hide()
        end
    end

    for _, button in ipairs(self.optionsAvailablePermissionButtons or {}) do
        if button.labelText and type(button.labelText.SetAlpha) == "function" then
            button.labelText:SetAlpha(shouldShow and 1 or 0)
        end
        if shouldShow and (button.labelText:GetText() or "") ~= "" then
            button:Show()
        else
            button:Hide()
        end
    end
end

function mainFrame:SelectAuthCapability(listKind, capability)
    if listKind == "allowed" then
        self.selectedAllowedCapability = capability
        self.selectedAvailableCapability = nil
    else
        self.selectedAvailableCapability = capability
        self.selectedAllowedCapability = nil
    end

    self:RefreshAuthOptions()
end

function mainFrame:MoveSelectedAuthCapability(listKind)
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = self:GetAuthDraftPolicy(db)
    local rankIndex = self:GetSelectedAuthRankIndex()
    local capability = listKind == "allowed" and self.selectedAllowedCapability or self.selectedAvailableCapability

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return false
    end

    if rankIndex == nil or capability == nil or capability == "" then
        self.optionsAuthStatusText:SetText("Select a rank and permission first.")
        return false
    end

    if permissions and type(permissions.SetCapabilityRank) == "function" then
        permissions.SetCapabilityRank(policy, capability, rankIndex, listKind ~= "allowed")
    end

    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self.optionsAuthStatusText:SetText(string.format("Staged %s for %s.", capability_label(capability), listKind == "allowed" and "removal" or "grant"))
    self:RefreshAuthOptions()
    return true
end

function mainFrame:SelectBlacklistEntry(characterKey)
    self.authBlacklistSelectedKey = characterKey
    self:RefreshAuthOptions()
end

function mainFrame:StageBlacklistEntry()
    self.optionsAuthStatusText:SetText("Blacklist membership is read-only here. Add or remove [GBMBL] in Guild & Communities officer notes.")
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Read-only view. Update [GBMBL] in the guild roster officer note.")
    end
    return nil
end

function mainFrame:RemoveSelectedBlacklistEntry()
    self.optionsAuthStatusText:SetText("Blacklist membership is read-only here. Remove [GBMBL] in Guild & Communities officer notes.")
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Read-only view. Remove [GBMBL] from the guild roster officer note.")
    end
    return nil
end

function mainFrame:BuildBlacklistOnlyDraft(db)
    return clone_table(current_policy(db or current_db()))
end

function mainFrame:ResetBlacklistDraft()
    self.authBlacklistSelectedKey = nil
    self.optionsAuthStatusText:SetText("Blacklist view refreshed from parsed officer notes.")
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Blacklist view refreshed from parsed officer notes.")
    end
    self:RefreshAuthOptions()
end

function mainFrame:FinalizeBlacklistSave(previousPolicy, draft, source)
    self.pendingBlacklistPopupWorkflow = nil
    self.pendingAuthPolicySave = nil
    self.optionsAuthStatusText:SetText("Blacklist membership is read-only here. Refresh guild roster data after editing officer notes.")
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Read-only view. Refresh after editing officer notes in Guild & Communities.")
    end
    self:RefreshAuthOptions()
    return nil
end

function mainFrame:ShowNextBlacklistPopupWorkflow()
    return nil
end

function mainFrame:ResumePendingBlacklistPopupWorkflow()
    self.pendingBlacklistPopupWorkflow = nil
    return false
end

function mainFrame:SaveBlacklistChanges(options)
    self.pendingBlacklistPopupWorkflow = nil
    self.pendingAuthPolicySave = nil
    self.optionsAuthStatusText:SetText("Blacklist membership is read-only here. Add or remove [GBMBL] in Guild & Communities officer notes, then refresh the roster.")
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Read-only view. The addon lists members whose officer note includes [GBMBL].")
    end
    return nil
end

function mainFrame:RefreshBlacklistFromGuild()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    self.blacklistRefreshRequestId = (tonumber(self.blacklistRefreshRequestId) or 0) + 1
    local requestId = self.blacklistRefreshRequestId
    self.pendingBlacklistRosterRefresh = true
    if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
        _G.C_GuildInfo.GuildRoster()
    end
    if permissions and type(permissions.RefreshPolicyFromGuild) == "function" then
        permissions.RefreshPolicyFromGuild(db)
    end

    local draft = self:GetAuthDraftPolicy(db)
    draft.blacklist = clone_table((db.auth or {}).blacklist or {})
    draft.blacklistHashes = clone_table((db.auth or {}).blacklistHashes or {})
    draft.blacklistDirectory = clone_table((db.auth or {}).blacklistDirectory or {})
    draft.blacklistRosterDirectory = clone_table((db.auth or {}).blacklistRosterDirectory or {})
    self.authBlacklistSelectedKey = nil

    self.optionsAuthStatusText:SetText("Refreshing blacklist roster data from guild officer notes...")
    self:RefreshAuthOptions()
    if self.optionsBlacklistStatusText then
        self.optionsBlacklistStatusText:SetText("Refreshing parsed officer-note tags from the guild roster...")
    end
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0.5, function()
            if self.blacklistRefreshRequestId ~= requestId then
                return
            end
            if self.pendingBlacklistRosterRefresh then
                self:OnGuildRosterRefresh()
            end
        end)
    end
    return true
end

function mainFrame:OnGuildRosterRefresh()
    if self.pendingBlacklistRosterRefresh then
        self.pendingBlacklistRosterRefresh = nil
    end

    self:RefreshAuthOptions()
end

function mainFrame:ToggleAuthCapabilityRank(capability, rankIndex)
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = self:GetAuthDraftPolicy(db)

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return false
    end

    local allowed = false
    if permissions and type(permissions.ToggleCapabilityRank) == "function" then
        allowed = permissions.ToggleCapabilityRank(policy, capability, rankIndex)
    end

    self.optionsAuthStatusText:SetText(string.format("Staged %s for rank %d: %s", capability_label(capability), rankIndex, allowed and "allowed" or "denied"))
    self:RefreshAuthOptions()
    return allowed
end

function mainFrame:SaveAuthPolicy(options)
    options = options or {}
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local officerNoteBlacklist = ns.modules.officerNoteBlacklist or {}
    local transport = ns.modules.syncTransport
    local authPolicyCodec = ns.modules.authPolicyCodec
    local context = current_auth_context(db)
    local previousPolicy = clone_table(current_policy(db))
    local draft = self:GetAuthDraftPolicy(db)

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return nil
    end

    if permissions and type(permissions.NormalizePolicy) == "function" then
        draft = permissions.NormalizePolicy(draft, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end

    -- Blacklist membership now saves through the dedicated Blacklist tab workflow.
    draft.blacklist = clone_table((previousPolicy or {}).blacklist or {})
    draft.blacklistHashes = clone_table((previousPolicy or {}).blacklistHashes or {})
    draft.blacklistDirectory = clone_table((previousPolicy or {}).blacklistDirectory or {})
    draft.blacklistRosterDirectory = clone_table((previousPolicy or {}).blacklistRosterDirectory or {})

    local minimumSettings = self.GetMinimumSettings and self:GetMinimumSettings(db) or (((db or {}).ui or {}).minimumSettings or {})
    draft.restockDefault = tonumber(minimumSettings.defaultQuantity or draft.restockDefault or 100) or 100
    draft.criticalThresholdPercent = math.max(0, math.min(100, tonumber(minimumSettings.criticalThresholdPercent or draft.criticalThresholdPercent or 50) or 50))

    self.pendingAuthPolicySave = nil

    if permissions and type(permissions.StampPolicy) == "function" then
        permissions.StampPolicy(draft, context, _G.time and _G.time() or 0)
    end

    if authPolicyCodec and type(authPolicyCodec.EncodePolicy) == "function" then
        draft.guildPolicyString = authPolicyCodec.EncodePolicy(draft)
    end

    db.auth = draft
    if type(permissions.AppendPolicyAudit) == "function" then
        permissions.AppendPolicyAudit(db, previousPolicy, draft, "local")
    end
    self.authDraftPolicy = clone_table(draft)
    if self.optionsPolicyStringInput and type(self.optionsPolicyStringInput.SetText) == "function" then
        self.optionsPolicyStringInput:SetText(draft.guildPolicyString or "")
    end
    self.optionsAuthStatusText:SetText("Saved guild auth policy locally and refreshed the policy string. Copy the policy string into Guild Information and press Accept.")

    self:RefreshAuthOptions()
    return draft
end

function mainFrame:ResumePendingAuthPolicySave()
    if type(self.pendingAuthPolicySave) ~= "table" then
        return false
    end

    local pending = self.pendingAuthPolicySave
    self.pendingAuthPolicySave = nil
    return self:SaveAuthPolicy({
        retryAfterRoster = true,
    }) ~= nil
end

function mainFrame:RefreshAuthPolicyFromGuildInfo()
    local db = current_db()
    local authPolicySource = ns.modules.authPolicySource
    local authPolicyCodec = ns.modules.authPolicyCodec

    if authPolicySource and type(authPolicySource.PullPolicyFromGuildInfo) == "function" then
        local pulled, reason = authPolicySource.PullPolicyFromGuildInfo(db, {
            force = true,
        })

        if pulled then
            self.optionsAuthStatusText:SetText("Reloaded auth policy from Guild Info.")
        elseif reason == "missing_snippet" then
            self.optionsAuthStatusText:SetText("Guild Info does not contain a GBankManager policy string.")
        else
            self.optionsAuthStatusText:SetText("Unable to reload auth policy from Guild Info.")
        end
    elseif authPolicyCodec and type(authPolicyCodec.PolicyStringFromGuildInfo) == "function" then
        local policyString = authPolicyCodec.PolicyStringFromGuildInfo()
        if policyString then
            self.optionsAuthStatusText:SetText("Reloaded auth policy string from Guild Info.")
        else
            self.optionsAuthStatusText:SetText("Guild Info does not contain a GBankManager policy string.")
        end
    else
        self.optionsAuthStatusText:SetText("Guild Info refresh is unavailable.")
    end

    if self.LoadMinimumSettingsFromDb then
        self:LoadMinimumSettingsFromDb(db)
    end
    self.authDraftPolicy = clone_table(db.auth or {})
    self:RefreshAuthOptions()
end

function mainFrame:RefreshAuthOptions()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(db)
    local ranks = self:GetAuthRankList()
    local context = current_auth_context(db)
    local profile = current_access_profile(db)
    local canManage = can_access(context, "auth_manage", current_policy(db))
    local selectedRankIndex = self:GetSelectedAuthRankIndex()
    local selectedRankName = "Select Rank"

    for _, rank in ipairs(ranks) do
        if rank.rankIndex == selectedRankIndex then
            selectedRankName = rank.name
            break
        end
    end

    self.optionsAccessPreviewText:SetText(string.format("Current Access: %s (%s)", profile, actor_summary_text(context)))
    self.optionsAuthMetadataText:SetText(auth_metadata_text(policy))
    self.optionsAuthRankButton.labelText:SetText(selectedRankName)
    if self.optionsAuthStatusText:GetText() == "" then
        self.optionsAuthStatusText:SetText(canManage and "Guildmaster and delegated auth managers can save policy changes." or "Read-only auth preview. You do not have auth-manage access.")
    end

    self.authRankDropdownShown = false
    set_frame_shown(self.optionsAuthRankDropdown, false)
    set_frame_shown(self.optionsAuthRankDropdownBackdrop, false)
    set_frame_shown(self.optionsAuthRankDropdownOccluder, false)
    for _, button in ipairs(self.optionsAuthRankButtons or {}) do
        button:Hide()
    end

    local capabilityList = (permissions and permissions.GetCapabilityList and permissions.GetCapabilityList()) or {}
    local allowedCapabilities = {}
    local availableCapabilities = {}
    for _, capability in ipairs(capabilityList) do
        local allowlist = (policy.capabilities[capability] or {})
        if selectedRankIndex ~= nil and allowlist[selectedRankIndex] == true then
            allowedCapabilities[#allowedCapabilities + 1] = capability
        else
            availableCapabilities[#availableCapabilities + 1] = capability
        end
    end

    self:UpdateOptionsAuthLayout(#allowedCapabilities, #availableCapabilities)

    local function bind_permission_buttons(buttons, parentFrame, capabilities, selectedCapability, listKind)
        for index, button in ipairs(buttons or {}) do
            local capability = capabilities[index]
            if capability then
                local rowIndex = ((index - 1) % 6)
                local columnIndex = math.floor((index - 1) / 6)
                if type(button.ClearAllPoints) == "function" then
                    button:ClearAllPoints()
                end
                button:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 8 + (columnIndex * 116), -8 - (rowIndex * 20))
                button:SetSize(110, 18)
                button.labelText:SetText(capability_label(capability))
                button:SetEnabled(true)
                button:Show()
                local isSelected = selectedCapability == capability
                apply_panel_style(button, isSelected and theme.colors.accent or theme.colors.panel)
                if type(button.labelText.SetTextColor) == "function" then
                    if isSelected then
                        button.labelText:SetTextColor(unpack(theme.colors.accentStrong))
                    else
                        button.labelText:SetTextColor(1, 0.82, 0, 1)
                    end
                end
                button:SetScript("OnClick", function()
                    self:SelectAuthCapability(listKind, capability)
                end)
            else
                button.labelText:SetText("")
                button:Hide()
            end
        end
    end

    bind_permission_buttons(self.optionsAllowedPermissionButtons, self.optionsAllowedPermissionPanel, allowedCapabilities, self.selectedAllowedCapability, "allowed")
    bind_permission_buttons(self.optionsAvailablePermissionButtons, self.optionsAvailablePermissionPanel, availableCapabilities, self.selectedAvailableCapability, "available")
    self:SetAuthPermissionListVisibility(true)

    local blacklistEntries = {}
    for characterKey, entry in pairs(policy.blacklist or {}) do
        blacklistEntries[#blacklistEntries + 1] = {
            characterKey = characterKey,
            name = entry.name or characterKey,
            reason = entry.reason or "",
        }
    end
    table.sort(blacklistEntries, function(left, right)
        return left.characterKey < right.characterKey
    end)

    for index, button in ipairs(self.optionsBlacklistButtons or {}) do
        local entry = blacklistEntries[index]
        if entry then
            local displayKey = type(permissions.DisplayCharacterKey) == "function" and permissions.DisplayCharacterKey(entry.characterKey) or entry.characterKey
            button.labelText:SetText(displayKey)
            button:SetEnabled(false)
            button:Show()
            button:SetScript("OnClick", nil)
        else
            button.labelText:SetText("")
            button:Hide()
        end
    end

    local blacklistPanelHeight = math.max(220, (#blacklistEntries * 22) + 16)
    self.optionsBlacklistListPanel:SetHeight(blacklistPanelHeight)
    self.optionsBlacklistPanel:SetHeight(math.max(420, 198 + blacklistPanelHeight))

    self.optionsPolicyStringInput:SetText(policy.guildPolicyString or "")

    local persistedPolicy = current_policy(current_db())
    local blacklistDraftDirty = not tables_deep_equal((policy or {}).blacklist or {}, (persistedPolicy or {}).blacklist or {})
        or not tables_deep_equal((policy or {}).blacklistDirectory or {}, (persistedPolicy or {}).blacklistDirectory or {})
        or not tables_deep_equal((policy or {}).blacklistHashes or {}, (persistedPolicy or {}).blacklistHashes or {})

    self.optionsAuthAddPermissionButton:SetEnabled(canManage and self.selectedAvailableCapability ~= nil and selectedRankIndex ~= nil)
    self.optionsAuthRemovePermissionButton:SetEnabled(canManage and self.selectedAllowedCapability ~= nil and selectedRankIndex ~= nil)
    self.optionsAuthRankButton:SetEnabled(#ranks > 0)
    self.optionsBlacklistAddButton:SetEnabled(false)
    self.optionsBlacklistRemoveButton:SetEnabled(false)
    self.optionsBlacklistSaveButton:SetEnabled(false)
    self.optionsBlacklistResetButton:SetEnabled(false)
    self.optionsBlacklistRefreshButton:SetEnabled(true)
    self.optionsAuthSaveButton:SetEnabled(canManage)
    self.optionsAuthReadButton:SetEnabled(true)
    self.optionsAuthResetButton:SetEnabled(true)
    self.optionsPolicyStringSelectAllButton:SetEnabled(true)
    if self.optionsBlacklistStatusText then
        if self.pendingBlacklistRosterRefresh then
            self.optionsBlacklistStatusText:SetText("Refreshing parsed officer-note tags from the guild roster...")
        else
            self.optionsBlacklistStatusText:SetText(string.format("Parsed %d tagged guild member%s from officer notes.", #blacklistEntries, #blacklistEntries == 1 and "" or "s"))
        end
    end

    set_frame_shown(self.optionsBlacklistTitle, false)
    set_frame_shown(self.optionsBlacklistCharacterLabel, false)
    set_frame_shown(self.optionsBlacklistNameInput, false)
    set_frame_shown(self.optionsBlacklistReasonLabel, false)
    set_frame_shown(self.optionsBlacklistReasonInput, false)
    set_frame_shown(self.optionsBlacklistAddButton, false)
    set_frame_shown(self.optionsBlacklistRemoveButton, false)
    set_frame_shown(self.optionsBlacklistSaveButton, false)
    set_frame_shown(self.optionsBlacklistResetButton, false)
    set_frame_shown(self.optionsBlacklistRefreshButton, true)
end

mainFrame.optionsBlacklistAddButton:SetScript("OnClick", function()
    mainFrame:StageBlacklistEntry()
end)

mainFrame.optionsBlacklistSaveButton:SetScript("OnClick", function()
    mainFrame:SaveBlacklistChanges()
end)

mainFrame.optionsBlacklistResetButton:SetScript("OnClick", function()
    mainFrame:ResetBlacklistDraft()
end)

mainFrame.optionsBlacklistRefreshButton:SetScript("OnClick", function()
    mainFrame:RefreshBlacklistFromGuild()
end)

mainFrame.optionsAuthRankButton:SetScript("OnClick", function()
    mainFrame:OpenAuthRankChoiceMenu()
end)

mainFrame.optionsAuthAddPermissionButton:SetScript("OnClick", function()
    mainFrame:MoveSelectedAuthCapability("available")
end)

mainFrame.optionsAuthRemovePermissionButton:SetScript("OnClick", function()
    mainFrame:MoveSelectedAuthCapability("allowed")
end)

mainFrame.optionsBlacklistRemoveButton:SetScript("OnClick", function()
    mainFrame:RemoveSelectedBlacklistEntry()
end)

mainFrame.optionsAuthSaveButton:SetScript("OnClick", function()
    mainFrame:SaveAuthPolicy()
end)

mainFrame.optionsAuthReadButton:SetScript("OnClick", function()
    mainFrame:RefreshAuthPolicyFromGuildInfo()
end)

mainFrame.optionsPolicyStringSelectAllButton:SetScript("OnClick", function()
    if mainFrame.optionsPolicyStringInput then
        mainFrame.optionsPolicyStringInput:SetFocus()
        mainFrame.optionsPolicyStringInput:SetCursorPosition(0)
        mainFrame.optionsPolicyStringInput:HighlightText(0, -1)
    end
    mainFrame.optionsAuthStatusText:SetText("Selected the policy string. Press Ctrl+C to copy.")
end)

mainFrame.optionsAuthResetButton:SetScript("OnClick", function()
    mainFrame.optionsAuthStatusText:SetText("")
    mainFrame:LoadAuthOptionsFromDb(current_db())
end)

mainFrame.closeButton = mainFrame.closeButton or make_button(mainFrame.topBar, 96, 28, "Close")
mainFrame.closeButton:SetPoint("TOPRIGHT", mainFrame.topBar, "TOPRIGHT", -16, -16)
mainFrame.closeButton:SetScript("OnClick", function()
    mainFrame:EnableMouse(false)
    mainFrame:Hide()
end)

mainFrame.sidebarButtons = mainFrame.sidebarButtons or {}
for index, item in ipairs(mainFrame.navItems) do
    local button = mainFrame.sidebarButtons[index] or make_button(mainFrame.sidebar, theme.spacing.sidebarExpanded - 32, 32, item.label)
    button.key = item.key
    button.navIcon = button.navIcon or button:CreateTexture()
    if type(button.navIcon.SetSize) == "function" then
        button.navIcon:SetSize(16, 16)
    end
    if type(button.navIcon.SetTexture) == "function" then
        button.navIcon:SetTexture(nav_icon_texture_for(item.key))
    end
    button.navIcon.texture = nav_icon_texture_for(item.key)
    button.labelText:SetText(item.label)
    if type(button.navIcon.ClearAllPoints) == "function" then
        button.navIcon:ClearAllPoints()
    end
    button.navIcon:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.labelText:SetPoint("LEFT", button.navIcon, "RIGHT", 8, 0)
    button:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -52 - ((index - 1) * 44))
    apply_panel_style(button, item.key == mainFrame.activeView and theme.colors.panelAlt or theme.colors.panel)
    button:SetScript("OnClick", function(self)
        mainFrame:SelectView(self.key)
    end)
    mainFrame.sidebarButtons[index] = button
end

function mainFrame:ApplyTheme()
    local requestOnlyShell = request_only_shell(self)
    local compactRequestMode = request_only_layout(self)
    local shellScale = self.appearanceShellScale or 1
    local sidebarWidth = self.collapsedSidebar and theme.spacing.sidebarCollapsed or theme.spacing.sidebarExpanded
    local shellWidth = requestOnlyShell and 960 or theme.spacing.frameWidth
    local shellHeight = requestOnlyShell and 580 or theme.spacing.frameHeight
    local topBarHeight = requestOnlyShell and 44 or theme.spacing.topBarHeight
    local topBarWidth = math.max(320, shellWidth - sidebarWidth)
    local contentHeight = math.max(280, shellHeight - topBarHeight)
    local navButtonHeight = math.max(28, math.floor(30 * shellScale + 0.5))
    local navButtonSpacing = math.max(36, math.floor(40 * shellScale + 0.5))
    local navStartOffset = self.collapsedSidebar and -52 or -52
    local titleBlockWidth = math.max(220, math.floor(topBarWidth * 0.30))
    local statusBlockWidth = math.max(120, math.floor(topBarWidth * 0.18))
    local availableStatusWidth = math.max(120, topBarWidth - titleBlockWidth - 96 - 120 - 72)
    statusBlockWidth = math.min(statusBlockWidth, availableStatusWidth)

    self:SetSize(shellWidth, shellHeight)
    self.themeExpressionStyle = "colored-distinct"
    self.defaultDensityStyle = "dense-clean"
    self.navButtonSpacing = navButtonSpacing
    self.sidebar:SetWidth(sidebarWidth)
    self.sidebar:SetHeight(shellHeight)
    if type(self.topBar.ClearAllPoints) == "function" then
        self.topBar:ClearAllPoints()
    end
    if type(self.content.ClearAllPoints) == "function" then
        self.content:ClearAllPoints()
    end
    self.topBar:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.topBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
    self.content:SetPoint("TOPLEFT", self.topBar, "BOTTOMLEFT", 0, 0)
    self.content:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    topBarHeight = math.max(52, math.min(76, topBarHeight))
    self.topBar:SetSize(topBarWidth, topBarHeight)
    self.content:SetSize(topBarWidth, contentHeight)
    relayout_dashboard_shell(self)
    apply_surface_variant(self, "shell", theme.colors.background)
    apply_surface_variant(self.sidebar, "sidebar", theme.colors.panel)
    self.sidebarNavStyle = "sidebar-soft-row"
    self.headerStyle = "toolbar-band"
    self.contentSectionStyle = "flat-band"
    apply_surface_variant(self.topBar, "header-toolbar", theme.colors.panelAlt)
    apply_surface_variant(self.content, "content-band", theme.colors.background)
    apply_surface_variant(self.optionsPanel, "panel")
    if type(self.optionsTabBar.SetBackdrop) == "function" then
        self.optionsTabBar:SetBackdrop(nil)
    end
    if type(self.optionsViewportFrame.SetBackdrop) == "function" then
        self.optionsViewportFrame:SetBackdrop(nil)
    end
    if self.optionsTabBar.gbmArt then
        for _, region in pairs(self.optionsTabBar.gbmArt) do
            if type(region) == "table" and type(region.Hide) == "function" then
                region:Hide()
            end
        end
    end
    if self.optionsViewportFrame.gbmArt then
        for _, region in pairs(self.optionsViewportFrame.gbmArt) do
            if type(region) == "table" and type(region.Hide) == "function" then
                region:Hide()
            end
        end
    end
    if type(self.optionsScrollBar.SetBackdrop) == "function" then
        self.optionsScrollBar:SetBackdrop(nil)
    end
    if type(self.optionsScrollBar.track.SetBackdrop) == "function" then
        self.optionsScrollBar.track:SetBackdrop(nil)
    end
    if type(self.optionsScrollBar.thumb.SetBackdrop) == "function" then
        self.optionsScrollBar.thumb:SetBackdrop(nil)
    end
    if type(self.optionsScrollFrame.SetBackdrop) == "function" then
        self.optionsScrollFrame:SetBackdrop(nil)
    end
    if type(self.optionsScrollChild.SetBackdrop) == "function" then
        self.optionsScrollChild:SetBackdrop(nil)
    end
    apply_surface_variant(self.optionsAppearancePanel, "panel-alt")
    apply_surface_variant(self.optionsStockSettingsPanel, "panel-alt")
    apply_surface_variant(self.optionsAuthPanel, "panel")
    apply_surface_variant(self.optionsPermissionsPanel, "panel-alt")
    apply_surface_variant(self.optionsBlacklistPanel, "panel-alt")
    apply_surface_variant(self.optionsLogsHistoryPanel, "panel-alt")
    apply_surface_variant(self.optionsAutomationPanel, "panel-alt")
    apply_surface_variant(self.optionsExportsPanel, "panel-alt")
    apply_surface_variant(self.optionsRequestsPanel, "panel-alt")
    apply_panel_style(self.optionsAuthRankDropdown, theme.colors.panel)
    apply_panel_style(self.optionsAuthRankDropdownBackdrop, theme.colors.background)
    apply_panel_style(self.optionsAuthRankDropdownOccluder, theme.colors.background)
    apply_surface_variant(self.optionsAllowedPermissionPanel, "panel")
    apply_surface_variant(self.optionsAvailablePermissionPanel, "panel")
    apply_surface_variant(self.optionsBlacklistListPanel, "panel")
    apply_surface_variant(self.requestActionsPanel, "panel")
    apply_surface_variant(self.requestAdminFilterPanel, "panel-flat")
    if self.requestAdminFilterPanel and self.requestAdminFilterPanel.transparentActions == true and type(self.requestAdminFilterPanel.SetBackdrop) == "function" then
        self.requestAdminFilterPanel:SetBackdrop(nil)
    end
    apply_surface_variant(self.requestWorkflowPanel, "panel-alt")
    apply_surface_variant(self.requestWizardModal, "modal-sheet")
    apply_surface_variant(self.requestDetailsModal, "modal-sheet")
    apply_surface_variant(self.historyDetailsModal, "modal-sheet")
    if self.onboardingModal then
        apply_surface_variant(self.onboardingModal, "modal-sheet")
    end
    apply_surface_variant(self.requestCreatePanel, "panel")
    apply_surface_variant(self.minimumsPanel, "panel-flat")
    if self.minimumsPanel.transparentActions == true and type(self.minimumsPanel.SetBackdrop) == "function" then
        self.minimumsPanel:SetBackdrop(nil)
    end
    apply_surface_variant(self.minimumAddModal, "modal-sheet")
    apply_surface_variant(self.minimumDetailsModal, "modal-sheet")
    apply_surface_variant(self.exportsPanel, "panel")
    if self.exportsPanel and self.exportsPanel.transparentActions == true and type(self.exportsPanel.SetBackdrop) == "function" then
        self.exportsPanel:SetBackdrop(nil)
        self.exportsPanel.backdrop = nil
        for _, region in pairs(self.exportsPanel.gbmArt or {}) do
            if type(region) == "table" and type(region.Hide) == "function" then
                region:Hide()
            end
        end
    end
    for _, card in ipairs(self.exportActionCards or {}) do
        apply_surface_variant(card, "action-card")
    end
    apply_surface_variant(self.exportModal, "modal-sheet")
    apply_surface_variant(self.exportStockedElsewhereModal, "modal-sheet")
    apply_panel_style(self.exportModalScrollFrame, theme.colors.background)
    apply_panel_style(self.exportModalScrollChild, theme.colors.background)
    if type(self.exportModalScrollFrame.SetBackdrop) == "function" then
        self.exportModalScrollFrame:SetBackdrop(nil)
    end
    if type(self.exportModalScrollChild.SetBackdrop) == "function" then
        self.exportModalScrollChild:SetBackdrop(nil)
    end
    apply_surface_variant(self.tableHeaderFrame, "table-header-flat")
    apply_surface_variant(self.tableFilterFrame, "table-filter-flat")
    apply_surface_variant(self.tableViewportFrame, "table-viewport-structured")
    apply_surface_variant(self.tableScrollFrame, "table-viewport-structured")

    set_label_color(self.titleText, theme.tokens.header)
    set_label_color(self.subtitleText, theme.tokens.textMuted)
    set_label_color(self.statusText, theme.tokens.header)
    set_label_color(self.viewTitle, theme.tokens.header)
    set_label_color(self.viewSubtitle, theme.tokens.text)
    set_label_color(self.contentBodyText, theme.tokens.text)
    set_label_color(self.minimumEmptyStateText, theme.tokens.textMuted)
    set_label_color(self.sidebarIdentityNameText, theme.tokens.header)
    set_label_color(self.sidebarIdentityGuildText, theme.tokens.textMuted)
    if self.onboardingModal then
        set_label_color(self.onboardingModal.titleText, theme.tokens.header)
        set_label_color(self.onboardingModal.progressText, theme.tokens.textMuted)
        set_label_color(self.onboardingModal.stepTitleText, theme.tokens.header)
        set_label_color(self.onboardingModal.stepDescriptionText, theme.tokens.text)
    end

    for _, card in ipairs(self.dashboardCards) do
        apply_surface_variant(card, "metric-card-flat")
        set_label_color(card.titleText, theme.tokens.textStrong)
        set_label_color(card.valueText, theme.tokens.header)
        set_label_color(card.noteText, theme.tokens.textMuted)
        set_label_color(card.linesText, theme.tokens.text)
        if card.iconTexture and type(card.iconTexture.SetVertexColor) == "function" then
            card.iconTexture:SetVertexColor(1, 1, 1, 1)
        end
    end
    if self.dashboardCards[1] then
        apply_surface_variant(self.dashboardCards[1], "metric-card-flat", { 0.05, 0.12, 0.20, 0.98 })
    end
    if self.dashboardCards[2] then
        apply_surface_variant(self.dashboardCards[2], "metric-card-flat", { 0.15, 0.08, 0.24, 0.98 })
    end
    if self.dashboardCards[3] then
        apply_surface_variant(self.dashboardCards[3], "metric-card-flat", { 0.08, 0.18, 0.11, 0.98 })
    end
    if self.dashboardCards[4] then
        apply_surface_variant(self.dashboardCards[4], "metric-card-flat", { 0.20, 0.08, 0.07, 0.98 })
    end
    apply_surface_variant(self.dashboardTopItemsPanel, "panel-flat")
    apply_surface_variant(self.dashboardRecentActivityPanel, "panel-flat")
    apply_surface_variant(self.dashboardQuickActionsPanel, "panel-flat")
    set_label_color(self.dashboardTopItemsTitle, theme.tokens.header)
    set_label_color(self.dashboardTopItemsText, theme.tokens.text)
    set_label_color(self.dashboardRecentActivityTitle, theme.tokens.header)
    set_label_color(self.dashboardRecentActivityText, theme.tokens.text)
    set_label_color(self.dashboardQuickActionsTitle, theme.tokens.header)
    apply_surface_variant(self.aboutPanel, "panel-alt")
    for _, button in ipairs(self.dashboardQuickActionButtons or {}) do
        apply_button_variant(button, "primary", theme.colors.button)
        if button.actionIcon and type(button.actionIcon.SetVertexColor) == "function" then
            button.actionIcon:SetVertexColor(unpack(theme.tokens.header or { 1, 1, 1, 1 }))
        end
        set_label_color(button.labelText, theme.tokens.header)
    end
    for _, card in ipairs(self.exportActionCards or {}) do
        set_label_color(card.titleText, theme.tokens.header)
        set_label_color(card.descriptionText, theme.tokens.textMuted)
        if card.iconTexture and type(card.iconTexture.SetVertexColor) == "function" then
            card.iconTexture:SetVertexColor(1, 1, 1, 1)
        end
    end
    set_label_color(self.aboutNameText, theme.tokens.header)
    set_label_color(self.aboutVersionText, theme.tokens.textStrong)
    set_label_color(self.aboutAuthorText, theme.tokens.text)
    set_label_color(self.aboutGuildText, theme.tokens.text)
    set_label_color(self.aboutDescriptionText, theme.tokens.textMuted)
    set_label_color(self.aboutSlashHintText, theme.tokens.header)

    local visibleNavIndex = 0
    for _, button in ipairs(self.sidebarButtons) do
        local isActive = button.key == self.activeView
        local showButton = not requestOnlyShell or request_only_view_allowed(button.key)
        apply_button_variant(button, "nav", isActive and theme.colors.panelAlt or theme.colors.panel)
        button.gbmButtonFamily = "nav-soft"
        button.gbmSelectionStyle = isActive and "selected-strong" or "selected-soft"
        if type(button.SetBackdropBorderColor) == "function" then
            button:SetBackdropBorderColor(0, 0, 0, 0)
        end
        button:SetWidth(self.collapsedSidebar and 40 or (theme.spacing.sidebarExpanded - 32))
        button:SetHeight(navButtonHeight)
        button.labelText:SetText(self.collapsedSidebar and "" or view_label_for(button.key))
        if type(button.ClearAllPoints) == "function" then
            button:ClearAllPoints()
        end
        if showButton then
            button:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 16, navStartOffset - (visibleNavIndex * navButtonSpacing))
            visibleNavIndex = visibleNavIndex + 1
        end
        if button.navIcon then
            if type(button.navIcon.SetTexture) == "function" then
                button.navIcon:SetTexture(nav_icon_texture_for(button.key))
            end
            button.navIcon.texture = nav_icon_texture_for(button.key)
            if type(button.navIcon.ClearAllPoints) == "function" then
                button.navIcon:ClearAllPoints()
            end
            if self.collapsedSidebar then
                button.navIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
            else
                button.navIcon:SetPoint("LEFT", button, "LEFT", 10, 0)
            end
        end
        if button.labelText and type(button.labelText.SetTextColor) == "function" then
            if isActive then
                button.labelText:SetTextColor(unpack(theme.tokens.textStrong or theme.colors.accentStrong))
            else
                button.labelText:SetTextColor(unpack(theme.tokens.text or theme.colors.accentStrong))
            end
        end
        if button.navIcon and type(button.navIcon.SetVertexColor) == "function" then
            if isActive then
                button.navIcon:SetVertexColor(unpack(theme.tokens.header or { 1, 1, 1, 1 }))
            else
                button.navIcon:SetVertexColor(unpack(theme.tokens.textMuted or { 1, 1, 1, 1 }))
            end
        end
        if mainFrameShell.SetAccentBar then
            mainFrameShell.SetAccentBar(button, color_with_alpha(theme.tokens.header or theme.colors.accentStrong, 0.95), isActive)
        end
        if mainFrameShell.SetHeaderBand then
            mainFrameShell.SetHeaderBand(
                button,
                color_with_alpha(isActive and (theme.tokens.accentMuted or theme.colors.accent) or (theme.tokens.accentMuted or theme.colors.border), isActive and 0.16 or 0.08),
                false
            )
        end
        if mainFrameShell.SetGlow then
            mainFrameShell.SetGlow(button, color_with_alpha(theme.tokens.accent or theme.colors.accent, isActive and 0.08 or 0.0), isActive)
        end
        if showButton then
            button:Show()
        else
            button:Hide()
        end
    end

    apply_surface_variant(self.sidebarIdentityPanel, "panel-flat")
    self.sidebarIdentityPanel:SetWidth(math.max(40, sidebarWidth - 32))
    self.sidebarIdentityPanel:SetPoint("BOTTOMLEFT", self.sidebar, "BOTTOMLEFT", 16, 16)
    if type(self.sidebarIdentityPanel.SetBackdropColor) == "function" then
        self.sidebarIdentityPanel:SetBackdropColor(0, 0, 0, 0)
    end
    if type(self.sidebarIdentityPanel.SetBackdropBorderColor) == "function" then
        self.sidebarIdentityPanel:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if type((self.sidebarIdentityPanel or {}).gbmArt) == "table" then
        for _, region in pairs(self.sidebarIdentityPanel.gbmArt) do
            if type(region) == "table" and type(region.Hide) == "function" then
                region:Hide()
            end
        end
    end
    if self.sidebarCrestTexture then
        local footerPanelWidth = self.sidebarIdentityPanel:GetWidth() or math.max(40, sidebarWidth - 32)
        local footerPanelHeight = self.sidebarIdentityPanel:GetHeight() or (self.collapsedSidebar and 56 or 144)
        local crestInset = self.collapsedSidebar and 0 or 4
        local crestEdge = math.max(32, math.min(footerPanelWidth, footerPanelHeight) - crestInset)
        if type(self.sidebarCrestTexture.SetTexture) == "function" then
            self.sidebarCrestTexture:SetTexture(mainFrameShell.GetThemeLogoTexture(self.appearanceThemePreset))
        end
        if type(self.sidebarCrestTexture.SetTexCoord) == "function" then
            self.sidebarCrestTexture:SetTexCoord(unpack(mainFrameShell.GetThemeLogoTexCoord(self.appearanceThemePreset)))
        end
        self.sidebarCrestTexture.texture = mainFrameShell.GetThemeLogoTexture(self.appearanceThemePreset)
        if type(self.sidebarCrestTexture.SetVertexColor) == "function" then
            self.sidebarCrestTexture:SetVertexColor(1, 1, 1, 1)
        end
        if type(self.sidebarCrestTexture.SetSize) == "function" then
            self.sidebarCrestTexture:SetSize(crestEdge, crestEdge)
        end
        self.sidebarCrestTexture:SetPoint("CENTER", self.sidebarIdentityPanel, "CENTER", 0, self.collapsedSidebar and 0 or -2)
    end
    if self.aboutCrestTexture then
        if type(self.aboutCrestTexture.SetTexture) == "function" then
            self.aboutCrestTexture:SetTexture(mainFrameShell.GetThemeLogoTexture(self.appearanceThemePreset))
        end
        if type(self.aboutCrestTexture.SetTexCoord) == "function" then
            self.aboutCrestTexture:SetTexCoord(unpack(mainFrameShell.GetThemeLogoTexCoord(self.appearanceThemePreset)))
        end
        self.aboutCrestTexture.texture = mainFrameShell.GetThemeLogoTexture(self.appearanceThemePreset)
        if type(self.aboutCrestTexture.SetVertexColor) == "function" then
            self.aboutCrestTexture:SetVertexColor(1, 1, 1, 1)
        end
    end
    if self.collapsedSidebar then
        self.sidebarIdentityPanel:SetHeight(56)
        self.sidebarIdentityNameText:Hide()
        self.sidebarIdentityGuildText:Hide()
    else
        self.sidebarIdentityPanel:SetHeight(144)
        self.sidebarIdentityNameText:Hide()
        self.sidebarIdentityGuildText:Hide()
    end
    if self.collapsedSidebar then
        self.sidebarIdentityPanel:Hide()
        if self.sidebarCrestTexture then
            self.sidebarCrestTexture:Hide()
        end
    else
        self.sidebarIdentityPanel:Show()
        if self.sidebarCrestTexture then
            self.sidebarCrestTexture:Show()
        end
    end

    self.collapseButton.labelText:SetText(self.collapsedSidebar and ">" or "<")
    if requestOnlyShell then
        self.sidebar:Show()
        self.collapseButton:Show()
        self.scanButton:Hide()
        self.statusText:Hide()
        self.subtitleText:Hide()
        self.titleText:SetText("Guild Bank Manager")
        self.titleText:Show()
    else
        self.sidebar:Show()
        self.collapseButton:Show()
        self.scanButton:Show()
        self.statusText:Show()
        self.subtitleText:Show()
        self.titleText:Show()
        self.titleText:SetText("Guild Bank Manager")
    end
    if type(self.closeButton.ClearAllPoints) == "function" then
        self.closeButton:ClearAllPoints()
    end
    self.closeButton:SetPoint("TOPRIGHT", self.topBar, "TOPRIGHT", -16, compactRequestMode and -8 or -16)
    if type(self.scanButton.ClearAllPoints) == "function" then
        self.scanButton:ClearAllPoints()
    end
    self.scanButton:SetPoint("TOPRIGHT", self.closeButton, "TOPLEFT", -16, 0)
    if type(self.statusText.ClearAllPoints) == "function" then
        self.statusText:ClearAllPoints()
    end
    self.statusText:SetPoint("RIGHT", self.scanButton, "LEFT", -16, 0)
    if type(self.titleText.SetWidth) == "function" then
        self.titleText:SetWidth(titleBlockWidth)
    end
    if type(self.subtitleText.SetWidth) == "function" then
        self.subtitleText:SetWidth(titleBlockWidth)
    end
    if type(self.statusText.SetWidth) == "function" then
        self.statusText:SetWidth(statusBlockWidth)
    end
    if type(self.statusText.SetJustifyH) == "function" then
        self.statusText:SetJustifyH("RIGHT")
    end
    if self.activeView == "OPTIONS" then
        self.optionsPanel:Show()
    else
        self.optionsPanel:Hide()
    end
    apply_button_variant(self.closeButton, "secondary")
    apply_button_variant(self.scanButton, "primary")
    apply_button_variant(self.collapseButton, "icon")
    self.collapseButton.gbmButtonFamily = "nav-soft"
    for presetKey, button in pairs(self.optionsThemeButtons or {}) do
        apply_button_variant(button, self.appearanceThemePreset == presetKey and "primary" or "tab", self.appearanceThemePreset == presetKey and theme.colors.panelAlt or theme.colors.panel)
    end
    apply_button_variant(self.optionsShellScaleDecreaseButton, "icon")
    apply_button_variant(self.optionsShellScaleIncreaseButton, "icon")
    apply_button_variant(self.optionsShellOpacityDecreaseButton, "icon")
    apply_button_variant(self.optionsShellOpacityIncreaseButton, "icon")
    apply_button_variant(self.optionsModalOpacityDecreaseButton, "icon")
    apply_button_variant(self.optionsModalOpacityIncreaseButton, "icon")
    apply_button_variant(self.optionsReplayOnboardingButton, "secondary")
    for _, button in ipairs(self.optionsTabButtons or {}) do
        apply_button_variant(button, button.key == self.optionsActiveTab and "primary" or "tab")
        button.gbmTabStyle = "segmented-soft"
        if button.labelText then
            set_label_color(
                button.labelText,
                button.key == self.optionsActiveTab and (theme.tokens.buttonText or theme.tokens.textStrong) or (theme.tokens.text or theme.colors.accentStrong)
            )
        end
    end
    for _, slider in ipairs({
        self.optionsShellScaleSlider,
        self.optionsShellOpacitySlider,
        self.optionsModalOpacitySlider,
    }) do
        if slider then
            if slider.Low and type(slider.Low.SetTextColor) == "function" then
                slider.Low:SetTextColor(unpack(theme.colors.textMuted or theme.colors.accentStrong))
            end
            if slider.High and type(slider.High.SetTextColor) == "function" then
                slider.High:SetTextColor(unpack(theme.colors.textMuted or theme.colors.accentStrong))
            end
            if slider.Text and type(slider.Text.SetTextColor) == "function" then
                slider.Text:SetTextColor(unpack(theme.colors.text or theme.colors.accentStrong))
            end
        end
    end
    apply_button_variant(self.requestApproveButton, "primary")
    apply_button_variant(self.requestRejectButton, "secondary")
    apply_button_variant(self.requestFulfillButton, "primary")
    apply_button_variant(self.requestReopenButton, "secondary")
    apply_button_variant(self.requestCreateButton, "primary")
    apply_button_variant(self.requestWorkflowCreateButton, "primary")
    apply_surface_variant(self.requestWizardProgressPanel, "panel-alt")
    apply_surface_variant(self.requestWizardPrimaryPanel, "panel")
    apply_surface_variant(self.requestWizardPreviewPanel, "panel-alt")
    apply_surface_variant(self.bankLedgerPanel, "panel-flat")
    if self.onboardingModal then
        apply_button_variant(self.onboardingModal.primaryActionButton, "primary")
        apply_button_variant(self.onboardingModal.backButton, "secondary")
        apply_button_variant(self.onboardingModal.nextButton, "primary")
        apply_button_variant(self.onboardingModal.doNotShowAgainButton, "secondary")
    end
    apply_button_variant(self.requestWizardBackButton, "secondary")
    apply_button_variant(self.requestWizardNextButton, "primary")
    apply_button_variant(self.requestWizardSubmitButton, "primary")
    apply_button_variant(self.requestWizardCancelButton, "secondary")
    apply_button_variant(self.requestCreateQuantityDecreaseButton, "secondary")
    apply_button_variant(self.requestCreateQuantityIncreaseButton, "secondary")
    apply_button_variant(self.requestDetailsApproveButton, "primary")
    apply_button_variant(self.requestDetailsRejectButton, "secondary")
    apply_button_variant(self.requestDetailsFulfillButton, "primary")
    apply_button_variant(self.requestDetailsReopenButton, "secondary")
    apply_button_variant(self.requestDetailsCancelRequestButton, "secondary")
    apply_button_variant(self.requestDetailsDeleteButton, "danger")
    apply_button_variant(self.requestDetailsCloseButton, "secondary")
    apply_button_variant(self.historyDetailsCloseButton, "secondary")
    apply_button_variant(self.requestDetailsBankTabDropdownButton, "select")
    apply_surface_variant(self.requestDetailsBankTabDropdownPanel, "input")
    apply_button_variant(self.requestAdminAddButton, "secondary")
    apply_button_variant(self.requestAdminRefreshButton, "secondary")
    apply_button_variant(self.requestAdminFilterAllButton, "tab")
    apply_button_variant(self.requestAdminFilterPendingApprovalButton, "tab")
    apply_button_variant(self.requestAdminFilterPendingFulfillmentButton, "tab")
    apply_button_variant(self.requestAdminFilterCompletedButton, "tab")
    apply_panel_style(self.requestCreateResultsPanel, theme.colors.background)
    apply_button_variant(self.minimumRestockToggleButton, "secondary")
    apply_button_variant(self.minimumEnabledOnlyButton, "tab")
    apply_button_variant(self.minimumShowAllButton, "tab")
    apply_button_variant(self.minimumManualOnlyToggleButton, "tab")
    apply_button_variant(self.minimumNewButton, "secondary")
    apply_button_variant(self.minimumSaveButton, "primary")
    apply_button_variant(self.minimumSaveAllButton, "secondary")
    apply_panel_style(self.minimumEditorPanel, theme.colors.background)
    apply_button_variant(self.minimumEditorBankTabDropdownButton, "select")
    apply_surface_variant(self.minimumEditorBankTabDropdownPanel, "input")
    apply_button_variant(self.minimumEditorRestockToggleButton, "secondary")
    apply_button_variant(self.minimumEditorRemoveButton, "danger")
    apply_button_variant(self.minimumEditorUndoButton, "secondary")
    apply_button_variant(self.minimumAddButton, "primary")
    apply_button_variant(self.minimumAddCancelButton, "secondary")
    apply_button_variant(self.minimumDetailsRestockToggleButton, "secondary")
    apply_button_variant(self.minimumDetailsConfirmButton, "primary")
    apply_button_variant(self.minimumDetailsRemoveButton, "danger")
    apply_button_variant(self.minimumDetailsUndoButton, "icon")
    apply_button_variant(self.minimumDetailsCancelButton, "secondary")
    apply_button_variant(self.minimumDetailsBankTabDropdownButton, "select")
    apply_surface_variant(self.minimumDetailsBankTabDropdownPanel, "input")
    apply_button_variant(self.optionsStockSettingsSaveButton, "primary")
    apply_button_variant(self.optionsLedgerRetentionButton, "select")
    apply_button_variant(self.optionsHistoryRetentionButton, "select")
    apply_button_variant(self.optionsLedgerScanIntervalButton, "select")
    apply_button_variant(self.optionsLogsHistorySaveButton, "primary")
    apply_button_variant(self.optionsDedupeLedgerButton, "secondary")
    apply_button_variant(self.optionsClearBankLedgerButton, "secondary")
    apply_button_variant(self.optionsClearInventoryDataButton, "secondary")
    apply_button_variant(self.optionsClearCompletedRequestsButton, "secondary")
    apply_button_variant(self.optionsAuthRankButton, "select")
    apply_panel_style(self.optionsAuthRankDropdown, theme.colors.panel)
    apply_panel_style(self.optionsAuthRankDropdownBackdrop, theme.colors.background)
    apply_panel_style(self.optionsAuthRankDropdownOccluder, theme.colors.background)
    apply_button_variant(self.optionsAuthAddPermissionButton, "primary")
    apply_button_variant(self.optionsAuthRemovePermissionButton, "secondary")
    apply_button_variant(self.optionsBlacklistAddButton, "primary")
    apply_button_variant(self.optionsBlacklistRemoveButton, "secondary")
    apply_button_variant(self.optionsBlacklistRefreshButton, "secondary")
    apply_button_variant(self.optionsAuthSaveButton, "primary")
    apply_button_variant(self.optionsAuthReadButton, "secondary")
    apply_button_variant(self.optionsAuthResetButton, "secondary")
    apply_button_variant(self.optionsPolicyStringSelectAllButton, "secondary")
    for _, button in ipairs(self.requestCreateMatchButtons or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    for _, button in ipairs(self.requestDetailsBankTabDropdownOptions or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    for _, button in ipairs(self.minimumAddMatchButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    for _, button in ipairs(self.minimumEditorBankTabDropdownOptions or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    for _, button in ipairs(self.optionsBlacklistButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    for _, button in ipairs(self.optionsAuthRankButtons or {}) do
        apply_button_variant(button, "secondary")
    end
    for _, button in ipairs(self.optionsAllowedPermissionButtons or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    for _, button in ipairs(self.optionsAvailablePermissionButtons or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    apply_button_variant(self.requestWizardBankTabDropdownButton, "select")
    apply_surface_variant(self.requestWizardBankTabDropdownPanel, "input")
    apply_button_variant(self.bankLedgerDateRangeButton, "select")
    apply_button_variant(self.exportPresetSpreadsheetButton, "primary")
    apply_button_variant(self.exportPresetAuctionatorButton, "primary")
    apply_button_variant(self.exportPresetTsmButton, "primary")
    apply_button_variant(self.exportManualShoppingListButton, "primary")
    apply_button_variant(self.exportPresetCustomButton, "secondary")
    apply_button_variant(self.exportHeaderToggleButton, "secondary")
    apply_button_variant(self.exportApplyCustomButton, "primary")
    apply_button_variant(self.exportModalSelectAllButton, "secondary")
    apply_button_variant(self.exportModalCopyButton, "primary")
    apply_button_variant(self.exportModalCloseButton, "secondary")
    apply_button_variant(self.bankLedgerItemModeButton, self.bankLedgerMode == "ITEM" and "primary" or "tab")
    apply_button_variant(self.bankLedgerMoneyModeButton, self.bankLedgerMode == "MONEY" and "primary" or "tab")
    apply_button_variant(self.bankLedgerActionFilterButton, "select")
    apply_button_variant(self.bankLedgerExportButton, "secondary")
    apply_button_variant(self.inventoryExportButton, "secondary")
    if type(self.RefreshRequestWizardProgress) == "function" then
        self:RefreshRequestWizardProgress()
    end
    if type(self.tableScrollBar.SetBackdrop) == "function" then
        self.tableScrollBar:SetBackdrop(nil)
    end
    if self.tableScrollBar.track and type(self.tableScrollBar.track.SetBackdrop) == "function" then
        self.tableScrollBar.track:SetBackdrop(nil)
    end
    if self.tableScrollBar.thumb and type(self.tableScrollBar.thumb.SetBackdrop) == "function" then
        self.tableScrollBar.thumb:SetBackdrop(nil)
    end

    for index, row in ipairs(self.tableRows) do
        apply_table_row_style(row, index, row.isSelected == true)
    end

    for _, input in ipairs(self.tableFilterInputs) do
        apply_surface_variant(input, "input")
    end

    apply_surface_variant(self.requestActionNoteInput, "input")
    apply_surface_variant(self.requestCreateRequesterInput, "input")
    apply_surface_variant(self.requestCreateRoleInput, "input")
    apply_surface_variant(self.requestCreateItemIDInput, "input")
    apply_surface_variant(self.requestCreateItemNameInput, "input")
    apply_surface_variant(self.requestCreateQuantityInput, "input")
    apply_surface_variant(self.requestCreateNoteInput, "input")
    apply_surface_variant(self.defaultMinimumInput, "input")
    apply_surface_variant(self.optionsCriticalThresholdInput, "input")
    apply_surface_variant(self.minimumItemIDInput, "input")
    apply_surface_variant(self.minimumItemNameInput, "input")
    apply_surface_variant(self.minimumQuantityInput, "input")
    apply_surface_variant(self.minimumScopeInput, "input")
    apply_surface_variant(self.minimumTabNameInput, "input")
    apply_surface_variant(self.minimumSearchInput, "input")
    apply_surface_variant(self.minimumEditorQuantityInput, "input")
    apply_surface_variant(self.minimumDetailsQuantityInput, "input")
    apply_surface_variant(self.defaultMinimumInput, "input")
    apply_surface_variant(self.optionsPolicyStringInput, "input")
    apply_surface_variant(self.optionsBlacklistNameInput, "input")
    apply_surface_variant(self.optionsBlacklistReasonInput, "input")
    apply_surface_variant(self.exportAuctionatorListNameInput, "input")
    apply_surface_variant(self.exportDelimiterInput, "input")
    apply_surface_variant(self.exportFieldsInput, "input")
    apply_panel_style(self.exportModalOutputInput, theme.colors.background)
    if type(self.exportModalOutputInput.SetBackdrop) == "function" then
        self.exportModalOutputInput:SetBackdrop(nil)
    end
    self:ApplyShellOpacity(self.appearanceShellOpacity or self.currentAlpha or 0.96)
    self:ApplyModalOpacity(self.appearanceModalOpacity or 1)
end

function mainFrame:GetActiveSortState()
    if self.activeView == "MINIMUMS" then
        return self.minimumSortState
    end

    return self.inventorySortState
end

function mainFrame:ResizeInventoryColumn(index, delta)
    local inventoryView = ns.modules.inventoryView
    if not inventoryView or type(inventoryView.ResizeColumnLayout) ~= "function" then
        return
    end

    self.tableColumnLayout = inventoryView.ResizeColumnLayout(self.tableColumnLayout, index, delta, self:GetTableContentWidth())
    local db = current_db()
    local store = ns.data.store or ns.modules.store
    local inventoryColumnWidths = store.GetInventoryColumnWidths(db)

    local defaults = inventoryView.GetDefaultColumns()
    for columnIndex, column in ipairs(self.tableColumnLayout) do
        inventoryColumnWidths[columnIndex] = (column.width or 0) - (defaults[columnIndex].width or 0)
    end

    self:ConfigureTable(self.tableColumnLayout, self.tableRowsData)
    self:RefreshVisibleTableRows()
end

function mainFrame:GetInventoryFilterState()
    local filters = {}

    for index, column in ipairs(self.tableColumnLayout or {}) do
        local input = self.tableFilterInputs[index]
        if input then
            filters[column.key] = input:GetText() or ""
        end
    end

    return filters
end

function mainFrame:ApplyInventoryFilters()
    local inventoryView = ns.modules.inventoryView
    local db = current_db()
    local snapshot = self.cachedInventorySnapshot or { items = {} }
    local layout = inventoryView.GetColumnLayout(db, self:GetTableContentWidth())
    local rows = inventoryView.BuildTableRows(snapshot, db, self:GetInventoryFilterState())
    rows = inventoryView.SortRows(rows, self.inventorySortState)
    local displayRows = inventoryView.BuildDisplayRows(rows, layout)

    self.tableColumnLayout = layout
    self.tableScrollOffset = 0
    self.cachedInventoryRows = rows
    self:ConfigureTable(layout, displayRows)
    self:RefreshVisibleTableRows()
end

function mainFrame:HandleHeaderClick(index)
    if self.activeView ~= "INVENTORY" and self.activeView ~= "MINIMUMS" then
        return nil
    end

    local column = self.tableColumnLayout[index]
    if not column or column.sortable ~= true then
        return nil
    end

    local sortState = self.activeView == "MINIMUMS" and self.minimumSortState or self.inventorySortState

    if sortState.key == column.key then
        sortState.direction = sortState.direction == "asc" and "desc" or "asc"
    else
        sortState.key = column.key
        sortState.direction = "asc"
    end

    if self.activeView == "MINIMUMS" then
        self:ApplyMinimumFilters()
    else
        self:ApplyInventoryFilters()
    end
    return sortState
end

function mainFrame:HandleTableRowClick(row)
    if not row then
        return nil
    end

    if (self.requestWizardModal and self.requestWizardModal:IsShown())
        or (self.requestDetailsModal and self.requestDetailsModal:IsShown())
        or (self.historyDetailsModal and self.historyDetailsModal:IsShown())
        or (self.minimumAddModal and self.minimumAddModal:IsShown())
        or (self.minimumDetailsModal and self.minimumDetailsModal:IsShown()) then
        return nil
    end

    if self.activeView == "REQUESTS" and row.requestId then
        self:SelectRequestById(row.requestId)
        self:RefreshRequestActionButtons()
        return self:OpenRequestDetailsModal(row.requestId) or row
    end

    if self.activeView == "HISTORY" and row.details then
        return self:OpenHistoryDetailsModal(row) or row
    end

    if self.activeView == "MINIMUMS" and row.itemID then
        self.selectedMinimumKey = row.rowKey
        self:ApplyMinimumFilters()
        local refreshedRow = self:GetMinimumRowByKey(self.selectedMinimumKey) or row
        return self:OpenMinimumDetailsModal(refreshedRow) or refreshedRow
    end

    if self.activeView == "EXPORTS" and #((row or {}).stockedElsewhereTabs or {}) > 0 then
        return self:OpenExportStockedElsewhereModal(row) or row
    end

    return nil
end

function mainFrame:IsSelectedTableRow(row)
    if not row then
        return false
    end

    if self.activeView == "REQUESTS" then
        return row.requestId ~= nil and row.requestId == self.selectedRequestId
    end

    if self.activeView == "MINIMUMS" then
        return self.selectedMinimumKey ~= nil and row.rowKey == self.selectedMinimumKey
    end

    return false
end

function mainFrame:BuildExportRows()
    local db = current_db()
    local exports = ns.modules.exports
    if exports and type(exports.BuildRowsFromDatabase) == "function" then
        return exports.BuildRowsFromDatabase(db)
    end

    return {}, { items = {} }
end

function mainFrame:GetCurrentSnapshot()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetCurrentSnapshot) == "function" then
        return store.GetCurrentSnapshot(current_db())
    end

    return { items = {} }
end

function mainFrame:RefreshView()
    local db = current_db()
    local currentSnapshot = nil
    local planning = ns.modules.planning
    local dashboardView = ns.modules.dashboardView
    local inventoryView = ns.modules.inventoryView
    local historyView = ns.modules.historyView
    local minimumsView = ns.modules.minimumsView
    local requestsView = ns.modules.requestsView
    local accessProfile, authContext = current_access_profile(db)
    local compactRequestMode = request_only_layout(self)

    self:LoadAppearanceSettingsFromDb(db)
    self:UpdateSharedTableLayout()

    if type(self.SelfHealApprovedRequestMinimums) == "function" then
        self:SelfHealApprovedRequestMinimums(db)
    end

    local demandPlan = {}
    currentSnapshot = self:GetCurrentSnapshot()
    if planning and type(planning.BuildDemandPlanFromDatabase) == "function" then
        demandPlan, currentSnapshot = planning.BuildDemandPlanFromDatabase(db)
    end

    if dashboardView and type(dashboardView.BuildSummary) == "function" then
        local scanner = ns.modules.scanner
        if not (scanner and scanner.scanInProgress) then
            self:SetStatusSummary(dashboardView.BuildSummary(db, demandPlan))
        end
    end

    for _, card in ipairs(self.dashboardCards) do
        card:Hide()
    end
    self.dashboardTopItemsPanel:Hide()
    self.dashboardRecentActivityPanel:Hide()
    self.dashboardQuickActionsPanel:Hide()
    self.tableHeaderFrame:Hide()
    self.tableFilterFrame:Hide()
    self.tableViewportFrame:Hide()
    self.tableScrollFrame:Hide()
    self.tableScrollBar:Hide()
    self.requestActionsPanel:Hide()
    self.requestWorkflowPanel:Hide()
    if self.requestAdminFilterPanel then
        self.requestAdminFilterPanel:Hide()
    end
    self.requestWizardModal:Hide()
    self.requestDetailsModal:Hide()
    self.historyDetailsModal:Hide()
    self.requestCreatePanel:Hide()
    self.minimumsPanel:Hide()
    self.minimumAddModal:Hide()
    self.minimumDetailsModal:Hide()
    self.minimumEmptyStateText:Hide()
    self.exportsPanel:Hide()
    self.bankLedgerPanel:Hide()
    self.inventoryPanel:Hide()
    self.exportModal:Hide()
    if self.exportStockedElsewhereModal then
        self.exportStockedElsewhereModal:Hide()
    end
    self.optionsPanel:Hide()
    self.contentBodyText:SetText("")
    self.contentBodyText:Hide()
    self.aboutPanel:Hide()

    local showTable = false
    local showCards = false
    local showDashboardSections = false
    local bodyText = ""

    if self.activeView == "DASHBOARD" then
        local cards = dashboardView.BuildCards(db, demandPlan)
        local topItemLines = dashboardView.BuildTopItemsLines and dashboardView.BuildTopItemsLines(db, demandPlan) or {}
        local recentActivityLines = dashboardView.BuildRecentActivityLines and dashboardView.BuildRecentActivityLines(db, 5) or {}
        for index, card in ipairs(self.dashboardCards) do
            local model = cards[index]
            if model then
                card.titleText:SetText(model.title or "")
                card.valueText:SetText(model.value or "")
                card.noteText:SetText(model.note or "")
                card.linesText:SetText(model.lines and table.concat(model.lines, "\n") or "")
                card:Show()
            else
                card:Hide()
            end
        end
        self.dashboardTopItemsText:SetText(table.concat(topItemLines, "\n"))
        self.dashboardRecentActivityText:SetText(table.concat(recentActivityLines, "\n"))
        showCards = true
        showDashboardSections = true
    elseif self.activeView == "INVENTORY" then
        self.cachedInventoryDb = db
        self.cachedInventorySnapshot = currentSnapshot or { items = {} }
        self:ApplyInventoryFilters()
        showTable = true
    elseif self.activeView == "HISTORY" then
        local procurementEntries = historyView.FilterProcurementEntries(db.auditLog or {})
        local rows = historyView.BuildTableRows(procurementEntries, self:GetSharedFilterState())
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "date", label = "When", width = 150, justifyH = "LEFT" },
            { key = "category", label = "Category", width = 90, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 236, justifyH = "LEFT" },
            { key = "action", label = "Action", width = 104, justifyH = "LEFT" },
            { key = "actor", label = "Who", width = 156, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        showTable = true
    elseif self.activeView == "BANK_LEDGER" then
        self:RefreshBankLedgerTable()
        showTable = true
    elseif self.activeView == "MINIMUMS" then
        if self.RefreshMinimumFilterButtons then
            self:RefreshMinimumFilterButtons()
        end
        self.minimumManualOnlyToggleButton:Hide()
        self.minimumSaveButton.labelText:SetText("Save All")
        self:LoadMinimumSettingsFromDb(db)
        self:ApplyMinimumFilters()
        showTable = true
    elseif self.activeView == "REQUESTS" then
        for _, request in ipairs(db.requests or {}) do
            self:BackfillRequestCraftedTier(request)
        end
        local rows = requestsView.BuildTableRows(db.requests or {}, authContext, accessProfile, self:GetSharedFilterState(), self.requestAdminFilterMode or "ALL")
        if not self:GetSelectedRequest() and self.suppressNextRequestAutoSelect ~= true then
            self:SelectFirstActionableRequest()
        end
        self.suppressNextRequestAutoSelect = false
        if self.RefreshRequestAdminFilterButtons then
            self:RefreshRequestAdminFilterButtons()
        end
        self:RefreshRequestActionButtons()
        self.tableScrollOffset = 0
        if compactRequestMode then
            local tableLayouts = ns.modules.tableLayouts
            local requestColumns = tableLayouts and tableLayouts.GetRequestStatusColumns and tableLayouts.GetRequestStatusColumns() or {}
            self:ConfigureTable(requestColumns, rows)
        else
            local tableLayouts = ns.modules.tableLayouts
            local requestColumns = tableLayouts and tableLayouts.GetRequestAdminColumns and tableLayouts.GetRequestAdminColumns() or {}
            self:ConfigureTable(requestColumns, rows)
        end
        self:RefreshVisibleTableRows()
        showTable = true
    elseif self.activeView == "EXPORTS" then
        self:LoadExportSettingsFromDb(db)
        local rows = self:BuildExportRows()
        self:RefreshExportCustomControls()
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "itemID", label = "Item ID", width = 78, justifyH = "LEFT" },
            { key = "itemTier", label = "Tier", width = 56, justifyH = "CENTER" },
            { key = "itemName", label = "Item Name", width = 236, justifyH = "LEFT" },
            { key = "bankTab", label = "Bank Tab", width = 128, justifyH = "LEFT" },
            { key = "minQty", label = "Min Qty", width = 88, justifyH = "LEFT" },
            { key = "qtyInStock", label = "Qty In Stock", width = 104, justifyH = "LEFT" },
            { key = "qtyToBuy", label = "Qty To Buy", width = 92, justifyH = "LEFT" },
            { key = "excessQtyLabel", label = "Excess Qty", width = 112, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        self:RefreshExportOutput(rows)
        showTable = true
    elseif self.activeView == "OPTIONS" then
        self:LoadMinimumSettingsFromDb(db)
        self:LoadAuthOptionsFromDb(db)
        self:RefreshLogsHistoryControls()
        self:SetOptionsTab(self.optionsActiveTab or "APPEARANCE")
        bodyText = ""
    elseif self.activeView == "ABOUT" then
        local guildName = "No Guild"
        if type(_G.GetGuildInfo) == "function" then
            local resolvedGuild = _G.GetGuildInfo("player")
            if resolvedGuild and resolvedGuild ~= "" then
                guildName = tostring(resolvedGuild)
            end
        end
        self.aboutNameText:SetText("Guild Bank Manager")
        self.aboutVersionText:SetText(string.format("Version %s (%s)", ABOUT_VERSION, ABOUT_BUILD_STAMP))
        self.aboutAuthorText:SetText("Author: Zirleficent-Stormrage")
        self.aboutGuildText:SetText(string.format("Guild: %s", guildName))
        self.aboutDescriptionText:SetText("")
        self.aboutSlashHintText:SetText("/gbm help")
        bodyText = ""
    else
        bodyText = "Detailed content for this view is coming next."
    end

    for _, card in ipairs(self.dashboardCards) do
        if showCards then
            card:Show()
        else
            card:Hide()
        end
    end
    if showDashboardSections then
        self.dashboardTopItemsPanel:Show()
        self.dashboardRecentActivityPanel:Show()
        self.dashboardQuickActionsPanel:Show()
    else
        self.dashboardTopItemsPanel:Hide()
        self.dashboardRecentActivityPanel:Hide()
        self.dashboardQuickActionsPanel:Hide()
    end

    if type(self.requestActionsPanel.ClearAllPoints) == "function" then
        self.requestActionsPanel:ClearAllPoints()
    end
    self.requestActionsPanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
    self.requestActionsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
    if type(self.requestCreatePanel.ClearAllPoints) == "function" then
        self.requestCreatePanel:ClearAllPoints()
    end
    if compactRequestMode then
        self.requestWorkflowPanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
        self.requestCreatePanel:SetPoint("TOPLEFT", self.requestWorkflowPanel, "BOTTOMLEFT", 0, -12)
    else
        self.requestCreatePanel:SetPoint("TOPLEFT", self.requestActionsPanel, "BOTTOMLEFT", 0, -12)
    end
    self.requestWorkflowPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
    self.requestCreatePanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
    if type(self.tableHeaderFrame.ClearAllPoints) == "function" then
        self.tableHeaderFrame:ClearAllPoints()
    end
    if self.activeView == "REQUESTS" then
        self.tableHeaderFrame:SetPoint("TOPLEFT", compactRequestMode and self.requestWorkflowPanel or self.viewSubtitle, "BOTTOMLEFT", 0, -16)
    else
        self.tableHeaderFrame:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
    end

    if showTable then
        self.tableHeaderFrame:Show()
        if self:UsesInlineTableFilters() then
            self.tableFilterFrame:Show()
        else
            self.tableFilterFrame:Hide()
        end
        self.tableViewportFrame:Show()
        self.tableScrollFrame:Show()
    else
        self.tableHeaderFrame:Hide()
        self.tableFilterFrame:Hide()
        self.tableViewportFrame:Hide()
        self.tableScrollFrame:Hide()
        self.tableScrollBar:Hide()
    end

    if bodyText ~= "" then
        self.contentBodyText:SetText(bodyText)
        self.contentBodyText:Show()
    else
        self.contentBodyText:SetText("")
        self.contentBodyText:Hide()
    end

    if self.activeView == "ABOUT" then
        self.aboutPanel:Show()
    else
        self.aboutPanel:Hide()
    end

    if self.activeView == "REQUESTS" and not compactRequestMode then
        self.requestActionsPanel:Hide()
        if self.requestAdminFilterPanel then
            self.requestAdminFilterPanel:Show()
        end
    else
        self.requestActionsPanel:Hide()
        if self.requestAdminFilterPanel then
            self.requestAdminFilterPanel:Hide()
        end
    end

    if self.activeView == "REQUESTS" and compactRequestMode then
        self.requestWorkflowPanel:Show()
        self.requestCreatePanel:Hide()
    else
        self.requestWorkflowPanel:Hide()
        self.requestCreatePanel:Hide()
    end

    if self.activeView == "MINIMUMS" then
        self.minimumsPanel:Show()
    else
        self.minimumsPanel:Hide()
        self.minimumDetailsModal:Hide()
        self.minimumEmptyStateText:Hide()
    end

    if self.activeView == "EXPORTS" then
        self.exportsPanel:Show()
    else
        self.exportsPanel:Hide()
    end

    if self.activeView == "INVENTORY" then
        self.inventoryPanel:Show()
    else
        self.inventoryPanel:Hide()
    end

    if self.activeView == "BANK_LEDGER" then
        self.bankLedgerPanel:Show()
    else
        self.bankLedgerPanel:Hide()
    end

    if self.activeView == "OPTIONS" then
        self.optionsPanel:Show()
        self.optionsViewportFrame:Show()
        self.optionsScrollFrame.verticalScroll = 0
        self.optionsScrollFrame:SetVerticalScroll(0)
        self:SetOptionsTab(self.optionsActiveTab or "APPEARANCE")
        self:UpdateOptionsCanvasHeight()
        self:SyncOptionsScrollVisuals()
    else
        self.optionsPanel:Hide()
        self.optionsViewportFrame:Hide()
    end
end

for _, input in ipairs(mainFrame.tableFilterInputs) do
    input:SetScript("OnTextChanged", function()
        if mainFrame.isConfiguringTable then
            return
        end
        if mainFrame.activeView == "INVENTORY" then
            mainFrame:ApplyInventoryFilters()
        elseif mainFrame.activeView == "MINIMUMS" then
            mainFrame:ApplyMinimumFilters()
        elseif mainFrame.activeView == "HISTORY" then
            mainFrame:RefreshView()
        elseif mainFrame.activeView == "BANK_LEDGER" then
            mainFrame:RefreshBankLedgerTable()
        elseif mainFrame.activeView == "REQUESTS" and mainFrame.requestOnlyMode ~= true then
            mainFrame:RefreshView()
        end
    end)
end

function mainFrame:SelectView(name)
    local nextView = name or "DASHBOARD"
    if request_only_shell(self) then
        nextView = normalize_request_only_view(nextView)
    end
    if nextView ~= self.activeView then
        self:ClearTableFilters()
    end
    self.activeView = nextView
    self.viewTitle:SetText(view_label_for(nextView))
    self.viewSubtitle:SetText(self.viewDescriptions[self.activeView] or self.viewDescriptions.DASHBOARD)
    self:ApplyTheme()
    self:RefreshView()
    self:EnableMouse(true)
    self:BringToFront()
    self:Show()
    return self.activeView
end

function mainFrame:ShowDashboard()
    self.requestOnlyMode = false
    return self:SelectView("DASHBOARD")
end

function mainFrame:ShowRequestOnly()
    self.requestOnlyMode = true
    return self:SelectView("REQUESTS")
end

function mainFrame:ShowBlockedAccess(message)
    self.requestOnlyMode = false
    self:SetStatusSummary({})
    self.statusText:SetText(message or "Access blocked")
    self:EnableMouse(false)
    self:Hide()
    return false
end

function mainFrame:ToggleSidebar()
    self.collapsedSidebar = not self.collapsedSidebar
    self:ApplyTheme()
    return self.collapsedSidebar
end

function mainFrame:SetStatusSummary(summary)
    summary = summary or {}
    local lastScanAt = summary.lastScanAt or 0
    self.statusText:SetText(string.format("Last scan %s", format_timestamp(lastScanAt)))
end

function mainFrame:SetScanStatus(text)
    self.statusText:SetText(text or "No scan yet")
    self:RefreshView()
end

mainFrame:LoadAppearanceSettingsFromDb(current_db())
mainFrame:ApplyTheme()
mainFrame:Hide()

ns.modules.mainFrame = mainFrame

return mainFrame
