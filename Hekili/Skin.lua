setfenv( 1, select( 2, ... ).CompatEnv ) -- WoW 3.3.5a API layer (Compat.lua)
-- Skin.lua
-- Flat dark look for the options window, and the Escape > Interface > AddOns panel.
-- The options window is its own AceGUI container type ("HekiliOptionsFrame"), so the
-- look never leaks to other addons' windows. Inner widgets (trees, groups, boxes) are
-- only restyled while Hekili's window is open and are put back when it closes.

local addon, ns = ...
local Hekili = _G.Hekili

local AceGUI = LibStub( "AceGUI-3.0" )

local C = {
    bg       = { 0.06, 0.06, 0.06, 0.96 },
    panel    = { 0.10, 0.10, 0.10, 1 },
    inset    = { 0.08, 0.08, 0.08, 0.90 },
    border   = { 0, 0, 0, 1 },
    line     = { 0.22, 0.22, 0.22, 1 },
    accent   = { 0.99, 0.48, 0.17, 1 },   -- Hekili orange
    text     = { 0.90, 0.90, 0.90, 1 },
    hover    = { 0.18, 0.18, 0.18, 1 },
}
ns.SkinColors = C

local FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function Flat( f, bg, border )
    f:SetBackdrop( FLAT )
    f:SetBackdropColor( unpack( bg or C.bg ) )
    f:SetBackdropBorderColor( unpack( border or C.border ) )
end
ns.FlatBackdrop = Flat


---------------------------------------------------------------------------
-- Flat button (used for the close button and the Interface panel)
---------------------------------------------------------------------------
local function FlatButton( parent, text, width, height )
    local b = CreateFrame( "Button", nil, parent )
    b:SetWidth( width or 100 )
    b:SetHeight( height or 22 )
    Flat( b, C.panel, C.border )

    local fs = b:CreateFontString( nil, "OVERLAY", "GameFontHighlight" )
    fs:SetPoint( "CENTER" )
    fs:SetText( text or "" )
    b:SetFontString( fs )
    b.text = fs

    b:SetScript( "OnEnter", function( self ) self:SetBackdropBorderColor( unpack( C.accent ) ) end )
    b:SetScript( "OnLeave", function( self ) self:SetBackdropBorderColor( unpack( C.border ) ) end )
    return b
end
ns.FlatButton = FlatButton


---------------------------------------------------------------------------
-- The options window: a flat copy of AceGUI's "Frame" container
---------------------------------------------------------------------------
do
    local Type, Version = "HekiliOptionsFrame", 1

    if ( AceGUI:GetWidgetVersion( Type ) or 0 ) < Version then
        local function Button_OnClick( frame ) PlaySound( "gsTitleOptionExit" ) frame.obj:Hide() end
        local function Frame_OnShow( frame ) frame.obj:Fire( "OnShow" ) end
        local function Frame_OnClose( frame ) frame.obj:Fire( "OnClose" ) end
        local function Frame_OnMouseDown() AceGUI:ClearFocus() end
        local function Title_OnMouseDown( frame ) frame:GetParent():StartMoving() AceGUI:ClearFocus() end

        local function MoverSizer_OnMouseUp( mover )
            local frame = mover:GetParent()
            frame:StopMovingOrSizing()
            local self = frame.obj
            local status = self.status or self.localstatus
            status.width = frame:GetWidth()
            status.height = frame:GetHeight()
            status.top = frame:GetTop()
            status.left = frame:GetLeft()
        end

        local function SizerSE_OnMouseDown( frame ) frame:GetParent():StartSizing( "BOTTOMRIGHT" ) AceGUI:ClearFocus() end
        local function SizerS_OnMouseDown( frame ) frame:GetParent():StartSizing( "BOTTOM" ) AceGUI:ClearFocus() end
        local function SizerE_OnMouseDown( frame ) frame:GetParent():StartSizing( "RIGHT" ) AceGUI:ClearFocus() end
        local function StatusBar_OnEnter( frame ) frame.obj:Fire( "OnEnterStatusBar" ) end
        local function StatusBar_OnLeave( frame ) frame.obj:Fire( "OnLeaveStatusBar" ) end

        local methods = {
            OnAcquire = function( self )
                self.frame:SetParent( UIParent )
                self.frame:SetFrameStrata( "FULLSCREEN_DIALOG" )
                self:SetTitle()
                self:SetStatusText()
                self:ApplyStatus()
                self:Show()
                self:EnableResize( true )
            end,
            OnRelease = function( self )
                self.status = nil
                wipe( self.localstatus )
            end,
            OnWidthSet = function( self, width )
                local w = max( 0, width - 24 )
                self.content:SetWidth( w )
                self.content.width = w
            end,
            OnHeightSet = function( self, height )
                local h = max( 0, height - 70 )
                self.content:SetHeight( h )
                self.content.height = h
            end,
            SetTitle = function( self, title )
                self.titletext:SetText( title or "" )
            end,
            SetStatusText = function( self, text ) self.statustext:SetText( text ) end,
            Hide = function( self ) self.frame:Hide() end,
            Show = function( self ) self.frame:Show() end,
            EnableResize = function( self, state )
                local func = state and "Show" or "Hide"
                self.sizer_se[ func ]( self.sizer_se )
                self.sizer_s[ func ]( self.sizer_s )
                self.sizer_e[ func ]( self.sizer_e )
            end,
            SetStatusTable = function( self, status )
                self.status = status
                self:ApplyStatus()
            end,
            ApplyStatus = function( self )
                local status = self.status or self.localstatus
                local frame = self.frame
                self:SetWidth( status.width or 800 )
                self:SetHeight( status.height or 608 )
                frame:ClearAllPoints()
                if status.top and status.left then
                    frame:SetPoint( "TOP", UIParent, "BOTTOM", 0, status.top )
                    frame:SetPoint( "LEFT", UIParent, "LEFT", status.left, 0 )
                else
                    frame:SetPoint( "CENTER" )
                end
            end,
        }

        local function Constructor()
            local frame = CreateFrame( "Frame", "HekiliOptionsWindow", UIParent )
            frame:Hide()
            frame:EnableMouse( true )
            frame:SetMovable( true )
            frame:SetResizable( true )
            frame:SetClampedToScreen( true )
            frame:SetFrameStrata( "FULLSCREEN_DIALOG" )
            Flat( frame, C.bg, C.border )
            frame:SetMinResize( 640, 400 )
            frame:SetToplevel( true )
            frame:SetScript( "OnShow", Frame_OnShow )
            frame:SetScript( "OnHide", Frame_OnClose )
            frame:SetScript( "OnMouseDown", Frame_OnMouseDown )

            -- Title bar
            local title = CreateFrame( "Frame", nil, frame )
            title:SetPoint( "TOPLEFT", 1, -1 )
            title:SetPoint( "TOPRIGHT", -1, -1 )
            title:SetHeight( 26 )
            Flat( title, C.panel, C.panel )
            title:EnableMouse( true )
            title:SetScript( "OnMouseDown", Title_OnMouseDown )
            title:SetScript( "OnMouseUp", MoverSizer_OnMouseUp )

            local accent = title:CreateTexture( nil, "OVERLAY" )
            accent:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            accent:SetVertexColor( unpack( C.accent ) )
            accent:SetPoint( "BOTTOMLEFT" )
            accent:SetPoint( "BOTTOMRIGHT" )
            accent:SetHeight( 1 )

            local logo = title:CreateTexture( nil, "OVERLAY" )
            logo:SetTexture( ns.AddonPath .. "Textures\\LOGO-ORANGE" )
            logo:SetWidth( 20 )
            logo:SetHeight( 20 )
            logo:SetPoint( "LEFT", 6, 0 )

            local titletext = title:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
            titletext:SetPoint( "LEFT", logo, "RIGHT", 6, 0 )
            titletext:SetTextColor( unpack( C.text ) )

            local version = title:CreateFontString( nil, "OVERLAY", "GameFontDisableSmall" )
            version:SetPoint( "LEFT", titletext, "RIGHT", 8, 0 )
            version:SetText( "WoW 3.3.5a backport by Saranwrap" )

            local closeX = CreateFrame( "Button", nil, title )
            closeX:SetWidth( 24 )
            closeX:SetHeight( 20 )
            closeX:SetPoint( "RIGHT", -4, 0 )
            Flat( closeX, C.panel, C.panel )
            local x = closeX:CreateFontString( nil, "OVERLAY", "GameFontHighlight" )
            x:SetPoint( "CENTER" )
            x:SetText( "X" )
            closeX:SetScript( "OnClick", Button_OnClick )
            closeX:SetScript( "OnEnter", function( self ) x:SetTextColor( unpack( C.accent ) ) end )
            closeX:SetScript( "OnLeave", function( self ) x:SetTextColor( 1, 1, 1 ) end )

            -- Bottom: status text + close button
            local closebutton = FlatButton( frame, CLOSE, 100, 22 )
            closebutton:SetScript( "OnClick", Button_OnClick )
            closebutton:SetPoint( "BOTTOMRIGHT", -10, 10 )

            local statusbg = CreateFrame( "Button", nil, frame )
            statusbg:SetPoint( "BOTTOMLEFT", 10, 10 )
            statusbg:SetPoint( "BOTTOMRIGHT", closebutton, "BOTTOMLEFT", -6, 0 )
            statusbg:SetHeight( 22 )
            Flat( statusbg, C.inset, C.border )
            statusbg:SetScript( "OnEnter", StatusBar_OnEnter )
            statusbg:SetScript( "OnLeave", StatusBar_OnLeave )

            local statustext = statusbg:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
            statustext:SetPoint( "TOPLEFT", 7, -2 )
            statustext:SetPoint( "BOTTOMRIGHT", -7, 2 )
            statustext:SetJustifyH( "LEFT" )
            statustext:SetText( "" )

            local sizer_se = CreateFrame( "Frame", nil, frame )
            sizer_se:SetPoint( "BOTTOMRIGHT" )
            sizer_se:SetWidth( 16 )
            sizer_se:SetHeight( 16 )
            sizer_se:EnableMouse( true )
            sizer_se:SetScript( "OnMouseDown", SizerSE_OnMouseDown )
            sizer_se:SetScript( "OnMouseUp", MoverSizer_OnMouseUp )
            local grip = sizer_se:CreateTexture( nil, "OVERLAY" )
            grip:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            grip:SetVertexColor( unpack( C.accent ) )
            grip:SetWidth( 6 )
            grip:SetHeight( 6 )
            grip:SetPoint( "BOTTOMRIGHT", -2, 2 )

            local sizer_s = CreateFrame( "Frame", nil, frame )
            sizer_s:SetPoint( "BOTTOMRIGHT", -16, 0 )
            sizer_s:SetPoint( "BOTTOMLEFT" )
            sizer_s:SetHeight( 6 )
            sizer_s:EnableMouse( true )
            sizer_s:SetScript( "OnMouseDown", SizerS_OnMouseDown )
            sizer_s:SetScript( "OnMouseUp", MoverSizer_OnMouseUp )

            local sizer_e = CreateFrame( "Frame", nil, frame )
            sizer_e:SetPoint( "BOTTOMRIGHT", 0, 16 )
            sizer_e:SetPoint( "TOPRIGHT", 0, -28 )
            sizer_e:SetWidth( 6 )
            sizer_e:EnableMouse( true )
            sizer_e:SetScript( "OnMouseDown", SizerE_OnMouseDown )
            sizer_e:SetScript( "OnMouseUp", MoverSizer_OnMouseUp )

            local content = CreateFrame( "Frame", nil, frame )
            content:SetPoint( "TOPLEFT", 12, -36 )
            content:SetPoint( "BOTTOMRIGHT", -12, 40 )

            local widget = {
                localstatus = {},
                titletext   = titletext,
                statustext  = statustext,
                sizer_se    = sizer_se,
                sizer_s     = sizer_s,
                sizer_e     = sizer_e,
                content     = content,
                frame       = frame,
                type        = Type,
            }
            for method, func in pairs( methods ) do widget[ method ] = func end
            closebutton.obj, statusbg.obj, closeX.obj = widget, widget, widget

            return AceGUI:RegisterAsContainer( widget )
        end

        AceGUI:RegisterWidgetType( Type, Constructor, Version )
    end
end


---------------------------------------------------------------------------
-- Inner widgets: restyled while Hekili's window is open, put back as soon as a widget
-- is released (AceGUI reuses widgets for every addon) and when the window closes.
---------------------------------------------------------------------------
do
    local saved = {}        -- frame -> how it looked before
    local active = false

    local function SideTextures( f )
        local name = f.GetName and f:GetName()
        if not name then return end
        return _G[ name .. "Left" ], _G[ name .. "Middle" ], _G[ name .. "Right" ]
    end

    -- Panels and borders (tree, groups, inline groups): flat background, thin border.
    local function SkinBackdrop( f )
        local bd = f.GetBackdrop and f:GetBackdrop()
        if not bd then return end
        if bd.edgeFile == FLAT.edgeFile and bd.edgeSize == 1 then return end -- already flat

        local r, g, b, a = f:GetBackdropColor()
        local br, bg_, bb, ba = f:GetBackdropBorderColor()
        saved[ f ] = { kind = "backdrop", bd = bd, c = { r, g, b, a }, bc = { br, bg_, bb, ba } }

        Flat( f, C.inset, C.line )
    end

    local function Hover( f )
        if f.__hekiliHover then return end
        f.__hekiliHover = true
        f:HookScript( "OnEnter", function( self )
            if saved[ self ] then self:SetBackdropBorderColor( unpack( C.accent ) ) end
        end )
        f:HookScript( "OnLeave", function( self )
            if saved[ self ] then self:SetBackdropBorderColor( unpack( saved[ self ].border ) ) end
        end )
    end

    -- Buttons and edit boxes: the same flat look as the buttons of the other windows.
    local function SkinBox( f, bg, border, white )
        local l, m, r = SideTextures( f )
        local hl = f.GetHighlightTexture and f:GetHighlightTexture()
        local fs = f.GetFontString and f:GetFontString()
        local rec = { kind = "box", l = l, m = m, r = r, hl = hl, hlAlpha = hl and hl:GetAlpha(), fs = fs, border = border }
        if fs then rec.color = { fs:GetTextColor() } end
        -- Keep any backdrop it already had (another UI skin may have given it one).
        rec.bd = f:GetBackdrop()
        if rec.bd then
            rec.c = { f:GetBackdropColor() }
            rec.bc = { f:GetBackdropBorderColor() }
        end
        saved[ f ] = rec

        rec.shown = { l and l:IsShown(), m and m:IsShown(), r and r:IsShown() }
        if l then l:Hide() end
        if m then m:Hide() end
        if r then r:Hide() end
        if hl then hl:SetAlpha( 0 ) end
        Flat( f, bg, border )
        if fs and white then fs:SetTextColor( unpack( C.text ) ) end
        Hover( f )
    end

    local function Restore( f )
        local rec = saved[ f ]
        if not rec then return end
        saved[ f ] = nil

        f:SetBackdrop( rec.bd )
        if rec.bd then
            if rec.c and rec.c[1] then f:SetBackdropColor( unpack( rec.c ) ) end
            if rec.bc and rec.bc[1] then f:SetBackdropBorderColor( unpack( rec.bc ) ) end
        end

        if rec.kind == "box" then
            if rec.l and rec.shown[1] then rec.l:Show() end
            if rec.m and rec.shown[2] then rec.m:Show() end
            if rec.r and rec.shown[3] then rec.r:Show() end
            if rec.hl then rec.hl:SetAlpha( rec.hlAlpha or 1 ) end
            if rec.fs and rec.color and rec.color[1] then rec.fs:SetTextColor( unpack( rec.color ) ) end
        end
    end

    local function SkinFrame( f )
        if saved[ f ] then return end
        local obj = f.obj
        if obj and obj.type == "Button" and f == obj.frame and f:GetObjectType() == "Button" then
            SkinBox( f, C.panel, C.border, true )
        elseif obj and obj.type == "EditBox" and f == obj.editbox then
            SkinBox( f, C.inset, C.line )
        else
            SkinBackdrop( f )
        end
    end

    local function Walk( f, depth )
        if depth > 14 then return end
        SkinFrame( f )
        local n = f:GetNumChildren()
        if n > 0 then
            local children = { f:GetChildren() }
            for i = 1, n do Walk( children[ i ], depth + 1 ) end
        end
    end

    local function OptionsWidget()
        local w = LibStub( "AceConfigDialog-3.0" ).OpenFrames[ "Hekili" ]
        if w and w.frame and w.frame:IsShown() then return w end
    end

    local function SkinNow()
        local w = active and OptionsWidget()
        if w then Walk( w.content, 0 ) end
    end

    local function RestoreAll()
        for f in pairs( saved ) do Restore( f ) end
    end

    local function IsInside( f, root )
        for _ = 1, 20 do
            if not f then return false end
            if f == root then return true end
            f = f:GetParent()
        end
        return false
    end

    local hooked = false
    local function Hook()
        if hooked then return end
        hooked = true

        local ACD = LibStub( "AceConfigDialog-3.0" )

        -- The page is rebuilt every time a group is picked in the tree.
        hooksecurefunc( ACD, "FeedGroup", function( _, appName )
            if appName == "Hekili" and active then SkinNow() end
        end )

        -- A widget going back to AceGUI's shared pool gets its normal look back first.
        hooksecurefunc( AceGUI, "Release", function( _, widget )
            if not next( saved ) or type( widget ) ~= "table" or not widget.frame then return end
            for f in pairs( saved ) do
                if IsInside( f, widget.frame ) then Restore( f ) end
            end
        end )
    end

    function ns.StartOptionsSkin()
        Hook()
        active = true
        SkinNow()

        local w = OptionsWidget()
        if w and not w.frame.__hekiliRestore then
            w.frame.__hekiliRestore = true
            w.frame:HookScript( "OnHide", function()
                active = false
                RestoreAll()
            end )
        end
    end
end


---------------------------------------------------------------------------
-- Make AceConfigDialog use the flat window for Hekili
---------------------------------------------------------------------------
function ns.PrepareOptionsWindow()
    local ACD = LibStub( "AceConfigDialog-3.0" )
    local w = ACD.OpenFrames[ "Hekili" ]
    if not w then
        ACD.OpenFrames[ "Hekili" ] = AceGUI:Create( "HekiliOptionsFrame" )
    end
end


---------------------------------------------------------------------------
-- Escape > Interface > AddOns > Hekili
---------------------------------------------------------------------------
function ns.CreateInterfacePanel()
    if ns.InterfacePanel then return end

    local panel = CreateFrame( "Frame", "HekiliInterfacePanel", UIParent )
    panel.name = "Hekili"
    panel:Hide()

    local logo = panel:CreateTexture( nil, "ARTWORK" )
    logo:SetTexture( ns.AddonPath .. "Textures\\LOGO-ORANGE" )
    logo:SetWidth( 48 )
    logo:SetHeight( 48 )
    logo:SetPoint( "TOPLEFT", 16, -16 )

    local title = panel:CreateFontString( nil, "ARTWORK", "GameFontNormalLarge" )
    title:SetPoint( "TOPLEFT", logo, "TOPRIGHT", 10, -4 )
    title:SetText( "Hekili" )

    local sub = panel:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
    sub:SetPoint( "TOPLEFT", title, "BOTTOMLEFT", 0, -6 )
    sub:SetText( "v" .. tostring( Hekili.Version or "" ) .. "  -  priority helper for WoW 3.3.5a (backport of the Wrath Classic version)" )

    local desc = panel:CreateFontString( nil, "ARTWORK", "GameFontHighlight" )
    desc:SetPoint( "TOPLEFT", logo, "BOTTOMLEFT", 0, -16 )
    desc:SetWidth( 560 )
    desc:SetJustifyH( "LEFT" )
    desc:SetText( "Shows the next abilities to use for your class and spec. The priority is picked from your talents automatically.\n\n"
        .. "|cFFFFD100/hek|r opens the options. |cFFFFD100/hek move|r unlocks the displays so you can drag them; |cFFFFD100/hek lock|r locks them again." )

    local function Close()
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel( InterfaceOptionsFrame ) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel( GameMenuFrame ) end
    end

    local y = -170
    local function Button( text, tip, onClick )
        local b = FlatButton( panel, text, 220, 24 )
        b:SetPoint( "TOPLEFT", 16, y )
        b:SetScript( "OnClick", onClick )
        local t = panel:CreateFontString( nil, "ARTWORK", "GameFontDisableSmall" )
        t:SetPoint( "LEFT", b, "RIGHT", 10, 0 )
        t:SetText( tip )
        y = y - 32
        return b
    end

    Button( "Open Hekili options", "All the settings (also /hek).", function() Close() ns.StartConfiguration() end )
    Button( "Move the displays", "Unlock the displays to drag them (also /hek move).", function() Close() Hekili:CmdLine( "move" ) end )
    Button( "Lock the displays", "Lock them again (also /hek lock).", function() Hekili:CmdLine( "lock" ) end )
    Button( "Show / hide minimap button", "Left-click it: quick menu. Right-click: options.", function()
        local db = Hekili.DB.profile
        db.iconStore = db.iconStore or {}
        db.iconStore.hide = not db.iconStore.hide
        local LDBIcon = LibStub( "LibDBIcon-1.0", true )
        if LDBIcon then
            if db.iconStore.hide then LDBIcon:Hide( "Hekili" ) else LDBIcon:Show( "Hekili" ) end
        end
    end )
    Button( "Turn Hekili on / off", "Same as /hek enable and /hek disable.", function() Hekili:Toggle() end )

    InterfaceOptions_AddCategory( panel )
    ns.InterfacePanel = panel
end
