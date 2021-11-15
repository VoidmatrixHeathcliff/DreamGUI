Graphic = require("@Graphic")
Input   = require("@Input")
String  = require("@String")
Time    = require("@Time")

--[[
    DreamGUI

    UpdateEvent()
    UpdateRender()
    Remove(_ele)

    DialogBox(_params)
--]]

local DreamGUI = {}

DreamGUI.__elements = {}

DreamGUI.__interval_render = 0

DreamGUI.__is_first_update_render = true

DreamGUI.__last_update_render = 0

DreamGUI.__DEFAULT_COLOR_TEXT = {r = 200, g = 200, b = 200, a = 255}
DreamGUI.__DEFAULT_COLOR_BACK = {r = 45, g = 45, b = 45, a = 255}

DreamGUI.UpdateEvent = function(_event_type)
    for _, ele in pairs(DreamGUI.__elements) do 
        ele:UpdateEvent(_event_type) 
    end
end

DreamGUI.UpdateRender = function()
    -- 如果是第一次更新 GUI，则重置定时器时间
    local current_time = Time.GetInitTime()
    if DreamGUI.__is_first_update_render then
        DreamGUI.__last_update_render = current_time
        DreamGUI.__is_first_update_render = false
    end
    DreamGUI.__interval_render = current_time - DreamGUI.__last_update_render
    DreamGUI.__last_update_render = current_time
    for _, ele in pairs(DreamGUI.__elements) do 
        ele:UpdateRender() 
    end
end

DreamGUI.Remove = function(_ele)
    for idx, ele in pairs(DreamGUI.__elements) do
        if ele == _ele then
            if _ele.OnUnload then
                _ele:OnUnload()
            end
            table.remove(DreamGUI.__elements, idx)
            break
        end
    end
end

--[[
    DialogBox
    
    padding_x
    padding_y
    text
    speed
    text_color
    back_color
    back_texture
    back_mode
    font
    area
    line_spacing

    SetText(_str)
    SetFont(_font)
    ShowAllText()
    SetPadding(_widthX, _widthY)
    CheckAnimating()
    SetTextSpeed(_val)
    SetTextColor(_color)
    SetBackMode(_val)
    SetBackColor(_color)
    SetBackTexture(_texture)
    SetLineSpacing(_val)
    RedisplayText()
    Transform(_rect)
--]]

DreamGUI.DialogBox = function(_params)

    assert(type(_params) == "table")

    local ele = {}

    -- 水平内边距
    ele.__padding_x = _params.padding_x or 0
    -- 竖直内边距
    ele.__padding_y = _params.padding_y or 0
    -- 当前是否正在播放动画
    ele.__animating = true
    -- 原始文本内容
    ele.__raw_text = _params.text or ""
    -- 换行后的文本列表渲染信息
    ele.__line_text_render_info = {}
    -- 文本显示速度，-1 为立即显示
    ele.__text_speed = _params.speed or -1
    -- 文本颜色
    ele.__text_color = _params.text_color or DreamGUI.__DEFAULT_COLOR_TEXT
    -- 纯色背景颜色
    ele.__back_color = _params.back_color or DreamGUI.__DEFAULT_COLOR_BACK
    -- 背景纹理
    ele.__back_texture = _params.back_texture or nil
    -- 背景模式，0 为纯色背景，1 为纹理背景
    if _params.back_mode then
        ele.__back_mode = _params.back_mode
    elseif ele.__back_texture then
        ele.__back_mode = 1
    else
        ele.__back_mode = 0
    end
    -- 文本字体
    ele.__font = _params.font or nil
    -- 字体高度
    if ele.__font then
        ele.__font_height = ele.__font:Height()
    else
        ele.__font_height = 0
    end
    -- 显示区域
    ele.__area = _params.area or {x = 0, y = 0, w = 640, h = 360}
    -- 文本区域
    ele.__text_area = {
        x = ele.__area.x + ele.__padding_x,
        y = ele.__area.y + ele.__padding_y,
        w = ele.__area.w - ele.__padding_x * 2,
        h = ele.__area.h - ele.__padding_y * 2
    }
    -- 行间距
    ele.__line_spacing = _params.line_spacing or 0
    -- 当前正在更新动画的分行文本索引
    ele.__idx_line_text_animating = 0

    function ele:__UpdateLineTextRenderInfo()
        self.__line_text_render_info = {}
        local line_text = {}
        if #self.__raw_text == 0 then return end
        self.__idx_line_text_animating = 1
        local idx_line, idx_start_sub = 1, 1
        for idx_end_sub = 2, String.UTF8Len(self.__raw_text) do
            if (idx_line - 1) * (self.__font_height + self.__line_spacing) >= self.__text_area.h then break end 
            local text_clip = String.UTF8Sub(self.__raw_text, idx_start_sub, idx_end_sub - idx_start_sub)
            local width_text_clip, _ = Graphic.GetTextSize(self.__font, text_clip)
            if width_text_clip <= self.__text_area.w then
                line_text[idx_line] = text_clip
            else
                idx_start_sub = idx_end_sub - 1
                idx_line = idx_line + 1
            end
        end

        for idx, text in pairs(line_text) do
            local render_info = {
                texture = Graphic.CreateTexture(Graphic.TextImageQuality(self.__font, line_text[idx], self.__text_color)),
                rect_dst = {
                    x = self.__text_area.x,
                    y = self.__text_area.y + (idx - 1) * (self.__font_height + self.__line_spacing),
                    w = 0, h = 0
                },
                rect_src = {x = 0, y = 0, w = 0, h = 0},
                width = 0, height = 0
            }
            render_info.width, render_info.height = render_info.texture:Size()
            if render_info.rect_dst.y + render_info.height > self.__text_area.y + self.__text_area.h then
                local show_height = self.__text_area.y + self.__text_area.h - render_info.rect_dst.y
                render_info.rect_dst.h, render_info.rect_src.h = show_height, show_height
            else
                render_info.rect_dst.h, render_info.rect_src.h = render_info.height, render_info.height
            end
            table.insert(self.__line_text_render_info, render_info)
        end
    end

    function ele:SetText(_str)
        self.__raw_text = _str
        self.__UpdateLineTextRenderInfo()
    end

    function ele:SetFont(_font)
        self.__font = _font
        self.__font_height = _font:Height()
        self.__UpdateLineTextRenderInfo()
    end

    function ele:ShowAllText()
        self.__animating = false
        for _, info in pairs(self.__line_text_render_info) do
            info.rect_dst.w, info.rect_src.w = info.width, info.width
        end
        self.__idx_line_text_animating = #self.__line_text_render_info
    end

    function ele:SetPadding(_widthX, _widthY)
        self.__padding_x = _widthX or self.__padding_x
        self.__padding_y = _widthY or self.__padding_y
        self.__text_area.x = self.__area.x + self.__padding_x
        self.__text_area.y = self.__area.y + self.__padding_y
        self.__text_area.w = self.__area.w - self.__padding_x * 2
        self.__text_area.h = self.__area.h - self.__padding_y * 2
        self:__UpdateLineTextRenderInfo()
    end

    function ele:CheckAnimating()
        return self.__animating
    end

    function ele:SetTextSpeed(_val)
        self.__text_speed = _val
    end

    function ele:SetTextColor(_color)
        self.__text_color = _color
        self:__UpdateLineTextRenderInfo()
    end

    function ele:SetBackMode(_val)
        self.__back_mode = _val
    end

    function ele:SetBackColor(_color)
        self.__back_mode = 0
        self.__back_color = _color
    end

    function ele:SetBackTexture(_texture)
        self.__back_mode = 1
        self.__back_texture = _texture
    end

    function ele:SetLineSpacing(_val)
        self.__line_spacing = _val
        self:__UpdateLineTextRenderInfo()
    end

    function ele:RedisplayText()
        self.__animating = true
        for _, info in pairs(self.__line_text_render_info) do
            info.rect_dst.w, info.rect_src.w = 0, 0
        end
        self.__idx_line_text_animating = 1
    end

    function ele:Transform(_rect)
        assert(type(_rect) == "table")

        self.__area.x = _rect.x or self.__area.x
        self.__area.y = _rect.y or self.__area.y
        self.__area.w = _rect.w or self.__area.w
        self.__area.h = _rect.h or self.__area.h
        self.__text_area.x = self.__area.x + self.__padding_x
        self.__text_area.y = self.__area.y + self.__padding_y
        self.__text_area.w = self.__area.w - self.__padding_x * 2
        self.__text_area.h = self.__area.h - self.__padding_y * 2
        self:__UpdateLineTextRenderInfo()
        self.__animating = true
    end

    function ele:UpdateEvent(_event_type) end

    function ele:UpdateRender()

        if self.__back_mode == 1 then
            Graphic.RenderTexture(self.__back_texture, self.__area)
        else
            Graphic.SetDrawColor(self.__back_color)
            Graphic.DrawRectangle(self.__area, true)
        end

        if self.__animating then
            if self.__text_speed >= 0 then
                local forward_width = DreamGUI.__interval_render * self.__text_speed
                while forward_width > 0 and self.__idx_line_text_animating <= #self.__line_text_render_info do
                    local info = self.__line_text_render_info[self.__idx_line_text_animating]
                    if info.rect_dst.w + forward_width > info.width then
                        forward_width = forward_width - (info.width - info.rect_dst.w)
                        info.rect_dst.w, info.rect_src.w = info.width, info.width
                        self.__idx_line_text_animating = self.__idx_line_text_animating + 1
                    else
                        info.rect_dst.w = info.rect_dst.w + forward_width
                        info.rect_src.w = info.rect_dst.w
                        forward_width = 0
                    end
                end
            else
                for _, info in pairs(self.__line_text_render_info) do
                    info.rect_dst.w, info.rect_src.w = info.width, info.width
                    self.__animating = false
                end
            end
        end        

        for _, info in pairs(self.__line_text_render_info) do
            Graphic.RenderTexture(info.texture, info.rect_dst, info.rect_src)
        end
    end

    -- 如果初始化时已定义文本字体，则在此时更新分行文本渲染数据
    if ele.__font then ele:__UpdateLineTextRenderInfo() end

    table.insert(DreamGUI.__elements, ele)

    return ele

end

--[[
    Label
    
    padding_x
    padding_y
    text
    text_color
    back_color
    back_texture
    back_mode
    frame_color
    font
    area
    align_mode_x
    align_mode_y

    SetText(_str)
    SetFont(_font)
    SetPadding(_widthX, _widthY)
    SetTextColor(_color)
    SetBackMode(_val)
    SetBackColor(_color)
    SetBackTexture(_texture)
    SetFrameColor(_texture)
    SetAlignMode(_modeX, _modeY)
    Transform(_rect)
--]]

DreamGUI.Label = function(_params)

    assert(type(_params) == "table")

    local ele = {}

    -- 水平内边距
    ele.__padding_x = _params.padding_x or 0
    -- 竖直内边距
    ele.__padding_y = _params.padding_y or 0
    -- 文本
    ele.__text = _params.text or ""
    -- 文本颜色
    ele.__text_color = _params.text_color or DreamGUI.__DEFAULT_COLOR_TEXT
    -- 背景颜色
    ele.__back_color = _params.back_color or {r = 0, g = 0, b = 0, a = 0}
    -- 背景纹理
    ele.__back_texture = _params.back_texture or nil
    -- 背景模式，0 为纯色背景，1 为纹理背景
    if _params.back_mode then
        ele.__back_mode = _params.back_mode
    elseif ele.__back_texture then
        ele.__back_mode = 1
    else
        ele.__back_mode = 0
    end
    -- 边框颜色
    ele.__frame_color = _params.frame_color or {r = 0, g = 0, b = 0, a = 0}
    -- 文本字体
    ele.__font = _params.font or nil
    -- 字体高度
    if ele.__font then
        ele.__font_height = ele.__font:Height()
    else
        ele.__font_height = 0
    end
    -- 显示区域
    ele.__area = _params.area or {x = 0, y = 0, w = 135, h = 75}
    -- 文本区域
    ele.__text_area = {
        x = ele.__area.x + ele.__padding_x,
        y = ele.__area.y + ele.__padding_y,
        w = ele.__area.w - ele.__padding_x * 2,
        h = ele.__area.h - ele.__padding_y * 2
    }
    -- 文本纹理
    if ele.__font then
        ele.__text_texture = Graphic.CreateTexture(Graphic.TextImageQuality(ele.__font, ele.__text, ele.__text_color))
    else
        ele.__text_texture = nil
    end
    -- 水平对齐模式，-1 为左对齐，0 为居中，1 为右对齐
    ele.__align_mode_x = _params.align_mode_x or 0
    -- 竖直对齐模式，-1 为上对齐，0 为居中，1 为下对齐
    ele.__align_mode_y = _params.align_mode_y or 0
    -- 文本纹理裁剪区域
    ele.__text_texture_rect_src = {x = 0, y = 0, w = 0, h = 0}
    -- 文本纹理显示区域
    ele.__text_texture_rect_dst = {x = 0, y = 0, w = 0, h = 0}

    function ele:__UpdateDstAndSrcRect()
        local texture_width, texture_height = self.__text_texture:Size()

        self.__text_texture_rect_src.w = math.min(texture_width, self.__text_area.w)
        self.__text_texture_rect_src.h = math.min(texture_height, self.__text_area.h)
        self.__text_texture_rect_dst.w = self.__text_texture_rect_src.w
        self.__text_texture_rect_dst.h = self.__text_texture_rect_src.h

        if self.__align_mode_x == -1 then
            self.__text_texture_rect_src.x = 0
            self.__text_texture_rect_dst.x = self.__text_area.x
        elseif self.__align_mode_x == 1 then
            self.__text_texture_rect_src.x = texture_width - self.__text_texture_rect_src.w
            self.__text_texture_rect_dst.x = self.__text_area.x + self.__text_area.w - self.__text_texture_rect_src.w
        else
            self.__text_texture_rect_src.x = (texture_width - self.__text_texture_rect_src.w) / 2
            self.__text_texture_rect_dst.x = self.__text_area.x + (self.__text_area.w - self.__text_texture_rect_src.w) / 2
        end

        if self.__align_mode_y == -1 then
            self.__text_texture_rect_src.y = 0
            self.__text_texture_rect_dst.y = self.__text_area.y
        elseif self.__align_mode_y == 1 then
            self.__text_texture_rect_src.y = texture_height - self.__text_texture_rect_src.h
            self.__text_texture_rect_dst.y = self.__text_area.y + self.__text_area.h - self.__text_texture_rect_src.h
        else
            self.__text_texture_rect_src.y = (texture_height - self.__text_texture_rect_src.h) / 2
            self.__text_texture_rect_dst.y = self.__text_area.y + (self.__text_area.h - self.__text_texture_rect_src.h) / 2
        end
    end

    function ele:SetText(_str)
        self.__text = _str
        self.__text_texture = Graphic.CreateTexture(Graphic.TextImageQuality(ele.__font, ele.__text, ele.__text_color))
        self:__UpdateDstAndSrcRect()
    end

    function ele:SetText(_font)
        self.__font = _font
        self.__text_texture = Graphic.CreateTexture(Graphic.TextImageQuality(ele.__font, ele.__text, ele.__text_color))
        self:__UpdateDstAndSrcRect()
    end

    function ele:SetPadding(_widthX, _widthY)
        self.__padding_x = _widthX or self.__padding_x
        self.__padding_y = _widthY or self.__padding_y
        self.__text_area.x = self.__area.x + self.__padding_x
        self.__text_area.y = self.__area.y + self.__padding_y
        self.__text_area.w = self.__area.w - self.__padding_x * 2
        self.__text_area.h = self.__area.h - self.__padding_y * 2
        self:__UpdateDstAndSrcRect()
    end

    function ele:SetTextColor(_color)
        self.__text_color = _color
        self.__text_texture = Graphic.CreateTexture(Graphic.TextImageQuality(ele.__font, ele.__text, ele.__text_color))
    end

    function ele:SetBackMode(_val)
        self.__back_mode = _val
    end

    function ele:SetBackColor(_color)
        self.__back_mode = 0
        self.__back_color = _color
    end

    function ele:SetBackTexture(_texture)
        self.__back_mode = 1
        self.__back_texture = _texture
    end

    function ele:SetFrameColor(_color)
        self.__frame_color = _color
    end

    function ele:SetAlignMode(_modeX, _modeY)
        self.__align_mode_x = _modeX or self.__align_mode_x
        self.__align_mode_y = _modeY or self.__align_mode_y
        self:__UpdateDstAndSrcRect()
    end

    function ele:Transform(_rect)
        assert(type(_rect) == "table")

        self.__area.x = _rect.x or self.__area.x
        self.__area.y = _rect.y or self.__area.y
        self.__area.w = _rect.w or self.__area.w
        self.__area.h = _rect.h or self.__area.h
        self.__text_area.x = self.__area.x + self.__padding_x
        self.__text_area.y = self.__area.y + self.__padding_y
        self.__text_area.w = self.__area.w - self.__padding_x * 2
        self.__text_area.h = self.__area.h - self.__padding_y * 2
        self:__UpdateLineTextRenderInfo()
    end

    function ele:UpdateEvent(_event_type) end

    function ele:UpdateRender()
        if self.__back_mode == 0 then
            Graphic.SetDrawColor(self.__back_color)
            Graphic.DrawRectangle(self.__area, true)
        else
            Graphic.RenderTexture(self.__back_texture, self.__area)
        end

        Graphic.SetDrawColor(self.__frame_color)
        Graphic.DrawRectangle(self.__area)

        Graphic.RenderTexture(self.__text_texture, self.__text_texture_rect_dst, self.__text_texture_rect_src)
    end

    -- 如果此时文本纹理已存在，则计算纹理的显示和裁剪矩形
    if ele.__text_texture then
        ele:__UpdateDstAndSrcRect()
    end

    table.insert(DreamGUI.__elements, ele)

    return ele

end

return DreamGUI