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

    -- Check boxes: a flat dark square with the yellow game check mark (as in the other addons).
    -- Another UI skin's own pieces (ElvUI adds a backdrop frame) are hidden meanwhile.
    local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"

    local function CheckBoxParts( f, anchor )
        local box = f.__hekiliCheck
        if box then return box end
        box = {}
        local function T( layer )
            local tx = f:CreateTexture( nil, layer )
            tx:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            box[ #box + 1 ] = tx
            return tx
        end
        local fill = T( "BACKGROUND" )
        fill:SetPoint( "TOPLEFT", anchor, "TOPLEFT", 4, -4 )
        fill:SetPoint( "BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -4, 4 )
        fill:SetVertexColor( unpack( C.inset ) )
        local top, bottom, left, right = T( "BORDER" ), T( "BORDER" ), T( "BORDER" ), T( "BORDER" )
        top:SetPoint( "TOPLEFT", fill ) top:SetPoint( "TOPRIGHT", fill ) top:SetHeight( 1 )
        bottom:SetPoint( "BOTTOMLEFT", fill ) bottom:SetPoint( "BOTTOMRIGHT", fill ) bottom:SetHeight( 1 )
        left:SetPoint( "TOPLEFT", fill ) left:SetPoint( "BOTTOMLEFT", fill ) left:SetWidth( 1 )
        right:SetPoint( "TOPRIGHT", fill ) right:SetPoint( "BOTTOMRIGHT", fill ) right:SetWidth( 1 )
        box.edges = { top, bottom, left, right }
        for _, e in ipairs( box.edges ) do e:SetVertexColor( unpack( C.line ) ) end
        f.__hekiliCheck = box
        return box
    end

    local function SkinCheck( f, w )
        local bg, ck = w.checkbg, w.check
        if not ( bg and ck ) then return end

        local rec = { kind = "check", bg = bg, ck = ck, kids = {} }
        rec.bgAlpha = bg:GetAlpha()
        rec.ckTex = ck:GetTexture()
        rec.ckCoord = { ck:GetTexCoord() }
        rec.ckColor = { ck:GetVertexColor() }
        rec.ckBlend = ck.GetBlendMode and ck:GetBlendMode() or "BLEND"
        rec.ckPoints = {}
        for i = 1, ck:GetNumPoints() do rec.ckPoints[ i ] = { ck:GetPoint( i ) } end
        for _, c in ipairs( { f:GetChildren() } ) do
            if c:IsShown() then rec.kids[ #rec.kids + 1 ] = c c:Hide() end
        end
        saved[ f ] = rec

        bg:SetAlpha( 0 )
        local box = CheckBoxParts( f, bg )
        for _, tx in ipairs( box ) do tx:Show() end

        ck:SetTexture( CHECK )
        ck:SetTexCoord( 0, 1, 0, 1 )
        ck:SetVertexColor( 1, 1, 1, 1 )
        ck:SetBlendMode( "BLEND" )
        ck:ClearAllPoints()
        ck:SetAllPoints( bg )

        if not f.__hekiliCheckHover then
            f.__hekiliCheckHover = true
            f:HookScript( "OnEnter", function( self )
                if saved[ self ] and self.__hekiliCheck then
                    for _, e in ipairs( self.__hekiliCheck.edges ) do e:SetVertexColor( unpack( C.accent ) ) end
                end
            end )
            f:HookScript( "OnLeave", function( self )
                if self.__hekiliCheck then
                    for _, e in ipairs( self.__hekiliCheck.edges ) do e:SetVertexColor( unpack( C.line ) ) end
                end
            end )
        end
    end

    -- A flat box (fill + 1 px border) drawn with textures on f, kept on f for reuse.
    local function FlatBox( f, key, layer )
        local box = f[ key ]
        if box then return box end
        box = {}
        local fill = f:CreateTexture( nil, layer or "BACKGROUND" )
        fill:SetTexture( "Interface\\Buttons\\WHITE8X8" )
        box[ 1 ] = fill
        box.fill = fill
        box.edges = {}
        for i = 1, 4 do
            local e = f:CreateTexture( nil, "BORDER" )
            e:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            box[ #box + 1 ] = e
            box.edges[ i ] = e
        end
        local top, bottom, left, right = unpack( box.edges )
        top:SetPoint( "TOPLEFT", fill ) top:SetPoint( "TOPRIGHT", fill ) top:SetHeight( 1 )
        bottom:SetPoint( "BOTTOMLEFT", fill ) bottom:SetPoint( "BOTTOMRIGHT", fill ) bottom:SetHeight( 1 )
        left:SetPoint( "TOPLEFT", fill ) left:SetPoint( "BOTTOMLEFT", fill ) left:SetWidth( 1 )
        right:SetPoint( "TOPRIGHT", fill ) right:SetPoint( "BOTTOMRIGHT", fill ) right:SetWidth( 1 )
        f[ key ] = box
        return box
    end

    local function ShowBox( box, fill, line )
        box.fill:SetVertexColor( unpack( fill ) )
        for _, e in ipairs( box.edges ) do e:SetVertexColor( unpack( line ) ) end
        for _, tx in ipairs( box ) do tx:Show() end
    end

    local function HideBox( box )
        if box then for _, tx in ipairs( box ) do tx:Hide() end end
    end

    local function BoxHover( f, target, key )
        if f.__hekiliBoxHover then return end
        f.__hekiliBoxHover = true
        f:HookScript( "OnEnter", function()
            local box = target[ key ]
            if saved[ target ] and box then for _, e in ipairs( box.edges ) do e:SetVertexColor( unpack( C.accent ) ) end end
        end )
        f:HookScript( "OnLeave", function()
            local box = target[ key ]
            if saved[ target ] and box then for _, e in ipairs( box.edges ) do e:SetVertexColor( unpack( C.line ) ) end end
        end )
    end

    -- Remember a texture's alpha and hide it (alpha survives the Show/Hide calls of the game's templates).
    local function Fade( rec, tx )
        if not tx then return end
        rec.faded = rec.faded or {}
        rec.faded[ #rec.faded + 1 ] = { tx, tx:GetAlpha() }
        tx:SetAlpha( 0 )
    end

    -- Another UI skin (ElvUI, Tukui...) adds frames with a backdrop on top of these widgets:
    -- hidden while ours is shown, shown again on restore.
    local function HideSkinFrames( rec, parent, keep )
        if not parent or not parent.GetChildren then return end
        for _, c in ipairs( { parent:GetChildren() } ) do
            if not ( keep and keep[ c ] ) and c:IsShown() and c.GetBackdrop and c:GetBackdrop() then
                rec.kids = rec.kids or {}
                rec.kids[ #rec.kids + 1 ] = c
                c:Hide()
            end
        end
    end

    local function ArrowText( f, anchor )
        local fs = f.__hekiliArrow
        if not fs then
            fs = f:CreateFontString( nil, "OVERLAY", "GameFontHighlightSmall" )
            fs:SetText( "v" )
            f.__hekiliArrow = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint( "CENTER", anchor, "CENTER", 0, 0 )
        fs:SetTextColor( unpack( C.text ) )
        fs:Show()
        return fs
    end

    -- Dropdowns (AceGUI and the font / texture pickers): a flat field with a small "v" at its right.
    local function SkinDropdown( f, w )
        local rec = { kind = "drop" }
        local left, middle, right, button

        if w.dropdown then -- AceGUI Dropdown
            local name = w.dropdown:GetName()
            left, middle, right = _G[ name .. "Left" ], _G[ name .. "Middle" ], _G[ name .. "Right" ]
            button = w.button
        else -- AceGUI-SharedMediaWidgets
            left, middle, right = f.DLeft, f.DMiddle, f.DRight
            button = f.dropButton
        end
        if not ( left and right and button ) then return end

        saved[ f ] = rec
        Fade( rec, left ) Fade( rec, middle ) Fade( rec, right )
        Fade( rec, button:GetNormalTexture() ) Fade( rec, button:GetPushedTexture() )
        Fade( rec, button:GetDisabledTexture() ) Fade( rec, button:GetHighlightTexture() )

        local keep = {}
        if w.dropdown then keep[ w.dropdown ] = true end
        if w.button_cover then keep[ w.button_cover ] = true end
        keep[ button ] = true
        if f.displayButton then keep[ f.displayButton ] = true end
        HideSkinFrames( rec, f, keep )
        HideSkinFrames( rec, w.dropdown, keep )

        local box = FlatBox( f, "__hekiliDrop" )
        box.fill:ClearAllPoints()
        -- The visible field of the game's dropdown art is 24 px high, 19 px under the top of these textures.
        box.fill:SetPoint( "TOPLEFT", left, "TOPLEFT", 17, -19 )
        box.fill:SetPoint( "BOTTOMRIGHT", right, "TOPRIGHT", -17, -43 )
        ShowBox( box, C.inset, C.line )
        rec.box = box

        rec.arrow = ArrowText( f, button )
        BoxHover( button, f, "__hekiliDrop" )
        if w.button_cover then BoxHover( w.button_cover, f, "__hekiliDrop" ) end

        -- The list that opens.
        if w.pullout and w.pullout.frame and not saved[ w.pullout.frame ] then
            local pf = w.pullout.frame
            local bd = pf:GetBackdrop()
            saved[ pf ] = { kind = "backdrop", bd = bd, c = { pf:GetBackdropColor() }, bc = { pf:GetBackdropBorderColor() } }
            Flat( pf, C.panel, C.line )
        end

        -- Font / texture pickers open a list of their own, shared with every addon: restyled while open.
        if not w.dropdown and not button.__hekiliList then
            button.__hekiliList = true
            button:HookScript( "OnClick", function( self )
                local dd = self.obj and self.obj.dropdown
                if not ( dd and saved[ f ] ) or saved[ dd ] then return end
                saved[ dd ] = { kind = "backdrop", bd = dd:GetBackdrop(), c = { dd:GetBackdropColor() }, bc = { dd:GetBackdropBorderColor() } }
                Flat( dd, C.panel, C.line )
                if not dd.__hekiliHide then
                    dd.__hekiliHide = true
                    dd:HookScript( "OnHide", function( d )
                        local r = saved[ d ]
                        if r then
                            saved[ d ] = nil
                            d:SetBackdrop( r.bd )
                            if r.bd then
                                if r.c[1] then d:SetBackdropColor( unpack( r.c ) ) end
                                if r.bc[1] then d:SetBackdropBorderColor( unpack( r.bc ) ) end
                            end
                        end
                    end )
                end
            end )
        end
    end

    -- Sliders: a thin flat track with a small orange handle.
    local function SkinSlider( f )
        local thumb = f:GetThumbTexture()
        local rec = { kind = "slider", bd = f:GetBackdrop() }
        if rec.bd then
            rec.c = { f:GetBackdropColor() }
            rec.bc = { f:GetBackdropBorderColor() }
        end
        if thumb then
            rec.thumb = thumb
            rec.thumbTex = thumb:GetTexture()
            rec.thumbW, rec.thumbH = thumb:GetWidth(), thumb:GetHeight()
            rec.thumbColor = { thumb:GetVertexColor() }
        end
        saved[ f ] = rec

        f:SetBackdrop( nil )
        local box = FlatBox( f, "__hekiliTrack" )
        box.fill:ClearAllPoints()
        box.fill:SetPoint( "LEFT", f, "LEFT", 0, 0 )
        box.fill:SetPoint( "RIGHT", f, "RIGHT", 0, 0 )
        box.fill:SetHeight( 6 )
        ShowBox( box, C.inset, C.line )
        rec.box = box

        if thumb then
            thumb:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            thumb:SetVertexColor( unpack( C.accent ) )
            thumb:SetWidth( 8 )
            thumb:SetHeight( 14 )
        end
        BoxHover( f, f, "__hekiliTrack" )
    end

    -- Tabs (the display pages): flat, the selected one with an orange border. The game overlaps
    -- tabs by 10 px, so each box is inset 6 px on both sides.
    local function TabLook( tab )
        local rec = saved[ tab ]
        local box = tab.__hekiliTabBox
        if not ( rec and box ) then return end
        ShowBox( box, tab.selected and C.hover or C.panel, tab.selected and C.accent or C.line )
    end

    local function SkinTab( f )
        local name = f:GetName()
        if not name then return end
        local rec = { kind = "tab" }
        saved[ f ] = rec
        for _, part in ipairs( { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" } ) do
            Fade( rec, _G[ name .. part ] )
        end
        Fade( rec, f:GetHighlightTexture() )
        HideSkinFrames( rec, f )

        local box = FlatBox( f, "__hekiliTabBox" )
        box.fill:ClearAllPoints()
        box.fill:SetPoint( "TOPLEFT", f, "TOPLEFT", 6, -2 )
        box.fill:SetPoint( "BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 0 )
        rec.box = box
        TabLook( f )

        if not f.__hekiliTab then
            f.__hekiliTab = true
            if f.SetSelected then hooksecurefunc( f, "SetSelected", TabLook ) end
            f:HookScript( "OnEnter", function( self )
                local b = self.__hekiliTabBox
                if saved[ self ] and b and not self.selected then for _, e in ipairs( b.edges ) do e:SetVertexColor( unpack( C.accent ) ) end end
            end )
            f:HookScript( "OnLeave", function( self ) TabLook( self ) end )
        end
    end

    -- Scroll bars (page and tree): flat buttons with ^ / v, a thin track and a grey handle.
    local function SkinScrollBar( f )
        local name = f:GetName()
        local up, down = _G[ name .. "ScrollUpButton" ], _G[ name .. "ScrollDownButton" ]
        local thumb = f:GetThumbTexture()
        local rec = { kind = "scroll", bd = f:GetBackdrop() }
        if rec.bd then rec.c = { f:GetBackdropColor() } rec.bc = { f:GetBackdropBorderColor() } end
        saved[ f ] = rec
        f:SetBackdrop( nil )

        local track = FlatBox( f, "__hekiliTrack" )
        track.fill:ClearAllPoints()
        track.fill:SetPoint( "TOP", f, "TOP", 0, 0 )
        track.fill:SetPoint( "BOTTOM", f, "BOTTOM", 0, 0 )
        track.fill:SetWidth( 8 )
        ShowBox( track, C.inset, C.line )
        rec.boxes = { track }

        if thumb then
            rec.thumb = thumb
            rec.thumbTex = thumb:GetTexture()
            rec.thumbW, rec.thumbH = thumb:GetWidth(), thumb:GetHeight()
            rec.thumbColor = { thumb:GetVertexColor() }
            thumb:SetTexture( "Interface\\Buttons\\WHITE8X8" )
            thumb:SetVertexColor( 0.45, 0.45, 0.45, 1 )
            thumb:SetWidth( 8 )
        end

        rec.arrows = {}
        for _, pair in ipairs( { { up, "^" }, { down, "v" } } ) do
            local b, symbol = pair[ 1 ], pair[ 2 ]
            if b then
                Fade( rec, b:GetNormalTexture() ) Fade( rec, b:GetPushedTexture() )
                Fade( rec, b:GetDisabledTexture() ) Fade( rec, b:GetHighlightTexture() )
                local box = FlatBox( b, "__hekiliBtn" )
                box.fill:ClearAllPoints()
                box.fill:SetPoint( "TOPLEFT", b, "TOPLEFT", 1, -1 )
                box.fill:SetPoint( "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1 )
                ShowBox( box, C.panel, C.line )
                rec.boxes[ #rec.boxes + 1 ] = box
                local fs = ArrowText( b, b )
                fs:SetText( symbol )
                rec.arrows[ #rec.arrows + 1 ] = fs
                if not b.__hekiliBtnHover then
                    b.__hekiliBtnHover = true
                    b:HookScript( "OnEnter", function( self ) if saved[ f ] and self.__hekiliBtn then for _, e in ipairs( self.__hekiliBtn.edges ) do e:SetVertexColor( unpack( C.accent ) ) end end end )
                    b:HookScript( "OnLeave", function( self ) if self.__hekiliBtn then for _, e in ipairs( self.__hekiliBtn.edges ) do e:SetVertexColor( unpack( C.line ) ) end end end )
                end
            end
        end
    end

    local function Restore( f )
        local rec = saved[ f ]
        if not rec then return end
        saved[ f ] = nil

        if rec.faded then
            for _, pair in ipairs( rec.faded ) do pair[ 1 ]:SetAlpha( pair[ 2 ] or 1 ) end
        end

        if rec.kids and rec.kind ~= "check" then
            for _, c in ipairs( rec.kids ) do c:Show() end
        end

        if rec.kind == "drop" or rec.kind == "tab" then
            HideBox( rec.box )
            if rec.arrow then rec.arrow:Hide() end
            return
        elseif rec.kind == "slider" or rec.kind == "scroll" then
            HideBox( rec.box )
            for _, b in ipairs( rec.boxes or {} ) do HideBox( b ) end
            for _, fs in ipairs( rec.arrows or {} ) do fs:Hide() end
            f:SetBackdrop( rec.bd )
            if rec.bd then
                if rec.c and rec.c[1] then f:SetBackdropColor( unpack( rec.c ) ) end
                if rec.bc and rec.bc[1] then f:SetBackdropBorderColor( unpack( rec.bc ) ) end
            end
            local thumb = rec.thumb
            if thumb then
                thumb:SetTexture( rec.thumbTex )
                if rec.thumbColor[1] then thumb:SetVertexColor( unpack( rec.thumbColor ) ) else thumb:SetVertexColor( 1, 1, 1, 1 ) end
                if rec.thumbW and rec.thumbW > 0 then thumb:SetWidth( rec.thumbW ) end
                if rec.thumbH and rec.thumbH > 0 then thumb:SetHeight( rec.thumbH ) end
            end
            return
        end

        if rec.kind == "check" then
            local bg, ck = rec.bg, rec.ck
            if f.__hekiliCheck then
                for _, tx in ipairs( f.__hekiliCheck ) do tx:Hide() end
                for _, e in ipairs( f.__hekiliCheck.edges ) do e:SetVertexColor( unpack( C.line ) ) end
            end
            bg:SetAlpha( rec.bgAlpha or 1 )
            ck:SetTexture( rec.ckTex )
            if rec.ckCoord[1] then ck:SetTexCoord( unpack( rec.ckCoord ) ) end
            if rec.ckColor[1] then ck:SetVertexColor( unpack( rec.ckColor ) ) end
            ck:SetBlendMode( rec.ckBlend or "BLEND" )
            if #rec.ckPoints > 0 then
                ck:ClearAllPoints()
                for _, pt in ipairs( rec.ckPoints ) do ck:SetPoint( unpack( pt ) ) end
            end
            for _, c in ipairs( rec.kids ) do c:Show() end
            return
        end

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
        local otype = obj and obj.type
        if otype == "CheckBox" and f == obj.frame then
            SkinCheck( f, obj )
        elseif otype and ( otype == "Dropdown" or otype:match( "^LSM30_" ) ) and f == obj.frame then
            SkinDropdown( f, obj )
        elseif otype == "Slider" and f == obj.slider then
            SkinSlider( f )
        elseif f:GetObjectType() == "Slider" and f:GetName() and _G[ f:GetName() .. "ScrollUpButton" ] then
            SkinScrollBar( f )
        elseif otype == "TabGroup" and f.id and f.SetSelected and f:GetObjectType() == "Button" then
            SkinTab( f )
        elseif otype == "Keybinding" and f == obj.button then
            SkinBox( f, C.panel, C.border, true )
            local hl = f:GetHighlightTexture()
            if hl then hl:SetAlpha( 0.35 ) end -- kept: it shows the key box is waiting for a key
        elseif obj and obj.type == "Button" and f == obj.frame and f:GetObjectType() == "Button" then
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
        if f.obj and ( f.obj.type == "CheckBox" or f.obj.type == "Dropdown" or ( f.obj.type or "" ):match( "^LSM30_" ) ) and f == f.obj.frame then
            return -- their parts are handled by SkinCheck / SkinDropdown
        end
        if f:GetObjectType() == "Slider" and saved[ f ] and saved[ f ].kind == "scroll" then return end -- SkinScrollBar
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
