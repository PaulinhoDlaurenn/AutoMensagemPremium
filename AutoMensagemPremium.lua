script_name("AutoMensagemPremium")
script_author("PaulinhoDlaurenn")
script_description("Painel Staff Horizonte Rp")

local inicfg = require "inicfg"
local imgui  = require "imgui"
local vkeys  = require "vkeys"
local ffi = require "ffi"
local memory = require 'memory'
local weapons = require 'game.weapons'
local SCRIPT_VERSION = "1.0.6"
local UPDATE_API = "https://raw.githubusercontent.com/PaulinhoDlaurenn/AutoMensagemPremium/main/version.json"
local UPDATE_FILE_PATH = getWorkingDirectory() .. "\\AutoMensagemPremium_new.lua"

function showUpdateMessage(text)
    sampAddChatMessage("{3486F2}[AutoUpdate] {FFFFFF}" .. text, -1)
    print("[AutoUpdate] " .. text) 
end

function restartScript()
    showUpdateMessage("Reiniciando script...")
    thisScript():reload()
end

function replaceCurrentScript(newFile)
    local currentFile = thisScript().path
    
    local f_new = io.open(newFile, "rb")
    if not f_new then
        showUpdateMessage("Erro: Não foi possível ler o arquivo baixado.")
        return
    end
    
    local content = f_new:read("*a")
    f_new:close()
    
    if content == nil or #content < 100 then 
        showUpdateMessage("Erro: O arquivo baixado parece estar vazio ou corrompido.")
        return
    end

    local f_curr = io.open(currentFile, "wb")
    if f_curr then
        f_curr:write(content)
        f_curr:close()
        
        pcall(os.remove, newFile)
        
        showUpdateMessage("Arquivo substituído com sucesso!")
        restartScript()
    else
        showUpdateMessage("Erro: Falha ao abrir o script atual para escrita. Verifique permissões.")
    end
end

function downloadUpdate(url)
    showUpdateMessage("Download iniciado...")
    downloadUrlToFile(url, UPDATE_FILE_PATH, function(id, status, p1, p2)
        if status == 6 then 
            showUpdateMessage("Download concluído!")
            replaceCurrentScript(UPDATE_FILE_PATH)
        elseif status == -1 then
            showUpdateMessage("Erro: Falha no download da atualização.")
        end
    end)
end

function checkForUpdates()
    showUpdateMessage("Verificando atualização...")
    lua_thread.create(function()
        local tempFile = getWorkingDirectory() .. "\\version_check.json"
        downloadUrlToFile(UPDATE_API, tempFile, function(id, status, p1, p2)
            if status == 6 then
                local f = io.open(tempFile, "r")
                if f then
                    local content = f:read("*a")
                    f:close()
                    pcall(os.remove, tempFile)
                    
                    local ok, json = pcall(decodeJson, content)
                    if ok and json and json.version then
                        if json.version ~= SCRIPT_VERSION then
                            showUpdateMessage("Nova versao encontrada: " .. json.version)
                            showUpdateMessage(json.message or "Iniciando processo de atualizacao...")
                            downloadUpdate(json.download)
                        else
                            print("[AutoUpdate] O script ja esta na versao mais recente (" .. SCRIPT_VERSION .. ").")
                        end
                    else
                        showUpdateMessage("Erro: Resposta da API de atualizao invalida.")
                    end
                else
                    showUpdateMessage("Erro: Falha ao ler dados da atualizacao.")
                end
            elseif status == -1 then
                showUpdateMessage("Erro: Não foi possivel verificar atualizações.")
            end
        end)
    end)
end

local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local ti_ok, ti = pcall(require, "tabler_icons")
if not ti_ok then
  ti_ok, ti = pcall(require, "tabler_icons(1)")
end
if not ti_ok then
  ti = setmetatable({}, { __call = function() return "" end })
end

local tablerSetupDone = false
local tablerReady = false
local tablerGlyphRanges = nil
local tablerFontConfig = nil
local uiFontConfig = nil
local uiFontRanges = nil

local function fileExists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function safeAddUIFont(io)
  local candidates = {
    {"C:\\Windows\\Fonts\\tahomabd.ttf", 13.0},
    {"C:\\Windows\\Fonts\\tahoma.ttf", 13.5},
  }
  uiFontConfig = nil
  uiFontRanges = nil
  for _, item in ipairs(candidates) do
    local path, size = item[1], item[2]
    if fileExists(path) then
      local ok = pcall(function()
        uiFontConfig = imgui.ImFontConfig()
        uiFontConfig.PixelSnapH = true
        uiFontRanges = imgui.ImGlyphRanges({0x0020, 0x00FF, 0})
        io.Fonts:AddFontFromFileTTF(path, size, uiFontConfig, uiFontRanges)
      end)
      if ok then return true end
    end
  end
  pcall(function() io.Fonts:AddFontDefault() end)
  return false
end

local function setupTablerIconFont()
  if tablerSetupDone then return end
  tablerSetupDone = true
  local ok = pcall(function()
    local io = imgui.GetIO()
    safeAddUIFont(io)
    if not ti_ok or type(ti.get_font_data_base85) ~= "function" then
      tablerReady = false
      pcall(function() io.Fonts:Build() end)
      return
    end
    local minr = tonumber(ti.min_range) or 59906
    local maxr = tonumber(ti.max_range) or 65291
    tablerGlyphRanges = imgui.ImGlyphRanges({ minr, maxr, 0 })
    tablerFontConfig = imgui.ImFontConfig()
    tablerFontConfig.MergeMode = true
    tablerFontConfig.PixelSnapH = true
    local data = ti.get_font_data_base85()
    local okFont, font = pcall(function()
      return io.Fonts:AddFontFromMemoryCompressedBase85TTF(data, 14.0, tablerFontConfig, tablerGlyphRanges)
    end)
    tablerReady = okFont and font ~= nil
    pcall(function() io.Fonts:Build() end)
  end)
  if not ok then tablerReady = false end
end

if not imgui.OnInitialize then pcall(setupTablerIconFont) end
if imgui.OnInitialize then imgui.OnInitialize(function() setupTablerIconFont() end) end

local function IC(name)
  if tablerReady and ti_ok and ti then
    local icon = ti(name)
    if icon and icon ~= "?" then return icon end
  end
  return ""
end

local logo_texture = nil
local staff_icon_texture = nil

local function loadAssets()
    local logo_path = getWorkingDirectory() .. "\\resource\\logo_hz.png"
    if fileExists(logo_path) then
        logo_texture = imgui.CreateTextureFromFile(logo_path)
    end
    
    local staff_path = getWorkingDirectory() .. "\\resource\\user-shield.png"
    if fileExists(staff_path) then
        staff_icon_texture = imgui.CreateTextureFromFile(staff_path)
    end
end
local keyNames = {
    [0x08] = "BACKSPACE",
    [0x09] = "TAB",
    [0x0C] = "CLEAR",
    [0x0D] = "ENTER",
    [0x10] = "SHIFT",
    [0x11] = "CTRL",
    [0x12] = "ALT",
    [0x13] = "PAUSE",
    [0x14] = "CAPS",
    [0x1B] = "ESC",
    [0x20] = "SPACE",
    [0x21] = "PAGE UP",
    [0x22] = "PAGE DOWN",
    [0x23] = "END",
    [0x24] = "HOME",
    [0x25] = "LEFT",
    [0x26] = "UP",
    [0x27] = "RIGHT",
    [0x28] = "DOWN",
    [0x29] = "SELECT",
    [0x2A] = "PRINT",
    [0x2B] = "EXECUTE",
    [0x2C] = "SNAP",
    [0x2D] = "INSERT",
    [0x2E] = "DELETE",
    [0x2F] = "HELP",
    [0x30] = "0",
    [0x31] = "1",
    [0x32] = "2",
    [0x33] = "3",
    [0x34] = "4",
    [0x35] = "5",
    [0x36] = "6",
    [0x37] = "7",
    [0x38] = "8",
    [0x39] = "9",
    [0x41] = "A",
    [0x42] = "B",
    [0x43] = "C",
    [0x44] = "D",
    [0x45] = "E",
    [0x46] = "F",
    [0x47] = "G",
    [0x48] = "H",
    [0x49] = "I",
    [0x4A] = "J",
    [0x4B] = "K",
    [0x4C] = "L",
    [0x4D] = "M",
    [0x4E] = "N",
    [0x4F] = "O",
    [0x50] = "P",
    [0x51] = "Q",
    [0x52] = "R",
    [0x53] = "S",
    [0x54] = "T",
    [0x55] = "U",
    [0x56] = "V",
    [0x57] = "W",
    [0x58] = "X",
    [0x59] = "Y",
    [0x5A] = "Z",
    [0x5B] = "LWIN",
    [0x5C] = "RWIN",
    [0x5D] = "APPS",
    [0x60] = "NUMPAD 0",
    [0x61] = "NUMPAD 1",
    [0x62] = "NUMPAD 2",
    [0x63] = "NUMPAD 3",
    [0x64] = "NUMPAD 4",
    [0x65] = "NUMPAD 5",
    [0x66] = "NUMPAD 6",
    [0x67] = "NUMPAD 7",
    [0x68] = "NUMPAD 8",
    [0x69] = "NUMPAD 9",
    [0x6A] = "NUMPAD *",
    [0x6B] = "NUMPAD +",
    [0x6C] = "NUMPAD .",
    [0x6D] = "NUMPAD -",
    [0x6E] = "NUMPAD /",
    [0x70] = "F1",
    [0x71] = "F2",
    [0x72] = "F3",
    [0x73] = "F4",
    [0x74] = "F5",
    [0x75] = "F6",
    [0x76] = "F7",
    [0x77] = "F8",
    [0x78] = "F9",
    [0x79] = "F10",
    [0x7A] = "F11",
    [0x7B] = "F12",
    [0x90] = "NUM LOCK",
    [0x91] = "SCROLL",
}

local blockedKeys = {
    [0x0D] = true, 
    [0x10] = true, 
    [0x11] = true, 
    [0x12] = true, 
    [0x14] = true, 
    [0x1B] = true, 
    [0x20] = true, 
    [0x5B] = true, 
    [0x5C] = true, 
}

local function getKeyDisplayName(vkCode)
    if keyNames[vkCode] then
        return keyNames[vkCode]
    end
    return "KEY " .. vkCode
end
local CFG_NAME = "AutoMensagemPremium"
local defaultCfg = {
    config = {
        tema_cor = 1,
        notify = true,
        auto_saciar = false,
        auto_saciar_tempo = 300,
        toggle_key = 0x76, 
    },
    ped = {
        pedLvl = true,
        pedHpArm = true,
        pedAfk = true,
        pedGun = true,
        pedCustomNicks = false,
        pedDefault = true,
        distance = 35.0,
        pedPing = false,
        espActive = false,
        pedSkeleton = true 
    },
    systems = {
        [1] = { channel = "/ac", interval = 60, status = true, messages = { "Boa noite! Este é o nosso servidor." } },
        [2] = { channel = "/a", interval = 90, status = false, messages = { "Recrutando membros ativos!" } }
    }
}

local systems = {}
local cfg = { config = defaultCfg.config, ped = defaultCfg.ped }

local capturingKey = false       
local keyCaptureCooldown = false 
local keyCaptureCooldownTime = 0 
local captureMessage = ""        
local captureMessageTime = 0     
local lastToggleKeyState = false 
local function saveConfig()
    local folder = getWorkingDirectory() .. "\\config"
    if not doesDirectoryExist(folder) then createDirectory(folder) end
    local f = io.open(folder .. "\\" .. CFG_NAME .. ".json", "w")
    if f then
        local data = { config = cfg.config, systems = systems, ped = cfg.ped }
        local function serialize(t)
            local s = "{\n"
            for k, v in pairs(t) do
                s = s .. "  [" .. (type(k) == "number" and k or '"'..k..'"') .. "] = "
                if type(v) == "table" then s = s .. serialize(v) .. ",\n"
                elseif type(v) == "string" then s = s .. '"' .. v:gsub('"', '\\"'):gsub('\n', '\\n') .. '",\n'
                else s = s .. tostring(v) .. ",\n" end
            end
            return s .. "}"
        end
        f:write("return " .. serialize(data))
        f:close()
    end
end

local function loadConfig()
    local path = getWorkingDirectory() .. "\\config\\" .. CFG_NAME .. ".json"
    if fileExists(path) then
        local ok, res = pcall(function() return loadfile(path)() end)
        if ok and type(res) == "table" then
            cfg.config = res.config or defaultCfg.config
            if not cfg.config.toggle_key then
                cfg.config.toggle_key = 0x76 
            end
            systems = res.systems or defaultCfg.systems
            cfg.ped = res.ped or defaultCfg.ped
            for _, s in pairs(systems) do
                s.lastTime = 0
            end
            return
        end
    end
    systems = {}
    for k, v in pairs(defaultCfg.systems) do
        systems[k] = {
            channel = v.channel,
            interval = v.interval,
            status = v.status,
            messages = {},
            lastTime = 0
        }
        for _, m in ipairs(v.messages) do table.insert(systems[k].messages, m) end
    end
end

local menuOpen = imgui.ImBool(false)
local activeTab = imgui.ImInt(5)
local selectedSystemIdx = 1
local staffProfile = {
    isStaff = false,
    nick = "",
    rg = "",
    cargo = "",
    msgBoasVindas = ""
}


local editChannel = imgui.ImBuffer(64)
local editInterval = imgui.ImInt(60)
local editStatus = imgui.ImBool(false)
local newMessageBuffer = imgui.ImBuffer(128)
local ui_notify = imgui.ImBool(true)
local ui_auto_saciar = imgui.ImBool(false)
local ui_auto_saciar_tempo = imgui.ImInt(300)
local espActive = imgui.ImBool(false)
local espLvl = imgui.ImBool(true)
local espHpArm = imgui.ImBool(true)
local espAfk = imgui.ImBool(true)
local espGun = imgui.ImBool(true)
local espCustomNicks = imgui.ImBool(false)
local espDefault = imgui.ImBool(true)
local espDistance = imgui.ImFloat(35.0)
local espPing = imgui.ImBool(false)
local espSkeleton = imgui.ImBool(true) 

local function updateEditBuffers()
    local sys = systems[selectedSystemIdx]
    if sys then
        editChannel.v = sys.channel
        editInterval.v = sys.interval
        editStatus.v = sys.status
    end
    ui_notify.v = cfg.config.notify
    ui_auto_saciar.v = cfg.config.auto_saciar or false
    ui_auto_saciar_tempo.v = cfg.config.auto_saciar_tempo or 300
    espActive.v = cfg.ped.espActive
    espLvl.v = cfg.ped.pedLvl
    espHpArm.v = cfg.ped.pedHpArm
    espAfk.v = cfg.ped.pedAfk
    espGun.v = cfg.ped.pedGun
    espCustomNicks.v = cfg.ped.pedCustomNicks
    espDefault.v = cfg.ped.pedDefault
    espDistance.v = cfg.ped.distance
    espPing.v = cfg.ped.pedPing
    espSkeleton.v = cfg.ped.pedSkeleton or false
end

local function setTheme(cor)
  local style  = imgui.GetStyle()
  local colors = style.Colors
  local clr    = imgui.Col
  local ImVec4 = imgui.ImVec4

  style.WindowRounding    = 12.0
  style.ChildWindowRounding = 10.0
  style.FrameRounding     = 8.0
  style.GrabRounding      = 8.0
  style.ScrollbarRounding = 10.0
  style.WindowTitleAlign  = imgui.ImVec2(0.5, 0.5)
  style.ItemSpacing       = imgui.ImVec2(10, 10)
  style.WindowPadding     = imgui.ImVec2(15, 15)
  style.FramePadding      = imgui.ImVec2(10, 8)

  colors[clr.WindowBg]         = ImVec4(0.02, 0.02, 0.03, 0.99)
  colors[clr.ChildWindowBg]    = ImVec4(0.04, 0.04, 0.05, 1.00)
  colors[clr.PopupBg]          = ImVec4(0.05, 0.05, 0.06, 0.98)
  colors[clr.Border]           = ImVec4(0.12, 0.12, 0.15, 0.50)
  colors[clr.FrameBg]          = ImVec4(0.07, 0.07, 0.09, 1.00)
  colors[clr.FrameBgHovered]   = ImVec4(0.10, 0.10, 0.13, 1.00)
  colors[clr.FrameBgActive]    = ImVec4(0.13, 0.13, 0.16, 1.00)
  colors[clr.Text]             = ImVec4(0.95, 0.95, 0.98, 1.00)
  colors[clr.TextDisabled]     = ImVec4(0.45, 0.45, 0.50, 1.00)
  
  local themes = {
    [1] = {0.10, 0.40, 0.90}, 
    [2] = {0.50, 0.00, 0.80}, 
  }
  local c = themes[cor] or themes[1]
  colors[clr.TitleBgActive]    = ImVec4(c[1]*0.6, c[2]*0.6, c[3]*0.6, 1.00)
  colors[clr.Button]           = ImVec4(c[1], c[2], c[3], 0.85)
  colors[clr.ButtonHovered]    = ImVec4(c[1], c[2], c[3], 1.00)
  colors[clr.ButtonActive]     = ImVec4(c[1]*0.8, c[2]*0.8, c[3]*0.8, 1.00)
  colors[clr.Header]           = ImVec4(c[1], c[2], c[3], 0.55)
  colors[clr.CheckMark]        = ImVec4(c[1], c[2], c[3], 1.00)
end

local function ToggleSwitch(label, bool_ref)
    local p = imgui.GetCursorScreenPos()
    local draw_list = imgui.GetWindowDrawList()
    local height = 20
    local width = 40
    local radius = height * 0.5
    
    local clicked = false
    if imgui.InvisibleButton(label, imgui.ImVec2(width, height)) then
        bool_ref.v = not bool_ref.v
        clicked = true
    end
    
    local col_bg = bool_ref.v and imgui.GetColorU32(imgui.ImVec4(0.1, 0.4, 0.9, 0.9)) or imgui.GetColorU32(imgui.ImVec4(0.25, 0.25, 0.25, 1.0))
    draw_list:AddRectFilled(p, imgui.ImVec2(p.x + width, p.y + height), col_bg, radius)
    
    local circle_pos = bool_ref.v and (p.x + width - radius) or (p.x + radius)
    draw_list:AddCircleFilled(imgui.ImVec2(circle_pos, p.y + radius), radius - 2, imgui.GetColorU32(imgui.ImVec4(1, 1, 1, 1)))
    
    imgui.SameLine()
    imgui.Text(label)
    return clicked
end

local function StatCard(title, value, icon, color)
    imgui.BeginChild("##stat_" .. title, imgui.ImVec2(230, 100), true)
    imgui.TextColored(color, IC(icon) .. " " .. title)
    imgui.Spacing()
    imgui.Text(" ") imgui.SameLine()
    imgui.Text(tostring(value))
    imgui.EndChild()
end

local function msg(text)
    if cfg.config.notify then
        sampAddChatMessage("{3486F2}[AutoMensagem] {FFFFFF}" .. tostring(text), -1)
    end
end

local function getOnlinePlayers()
    local count = 0
    for i = 0, 1000 do
        if sampIsPlayerConnected(i) then count = count + 1 end
    end
    return count
end

local function getTotalMessages()
    local count = 0
    for _, s in pairs(systems) do count = count + #s.messages end
    return count
end

function getBodyPartCoordinates(id, handle)
  local pedptr = getCharPointer(handle)
  local vec = ffi.new("float[3]")
  getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
  return vec[0], vec[1], vec[2]
end


local fontESP = renderCreateFont("Segoe UI", 9, 12)

function drawBar(x, y, width, height, val, max, color, background)
    local fill = (val / max) * width
    if fill > width then fill = width end
    if fill < 0 then fill = 0 end
    renderDrawBox(x - 1, y - 1, width + 2, height + 2, background)
    renderDrawBox(x, y, width, height, background)
    
    if fill > 0 then
        renderDrawBox(x, y, fill, height, color)
    end
end

function drawSkeleton(handle)
    local bones = {
   
        {1, 2}, {2, 3}, {3, 4}, {4, 5}, {5, 8},
        {3, 22}, {22, 23}, {23, 24}, {24, 25},
        {3, 32}, {32, 33}, {33, 34}, {34, 35},
        {1, 51}, {51, 52}, {52, 53}, {53, 54},
        {1, 41}, {41, 42}, {42, 43}, {43, 44}
    }
    
    for _, connection in ipairs(bones) do
        local b1X, b1Y, b1Z = getBodyPartCoordinates(connection[1], handle)
        local b2X, b2Y, b2Z = getBodyPartCoordinates(connection[2], handle)
        
        if isPointOnScreen(b1X, b1Y, b1Z, 0.0) and isPointOnScreen(b2X, b2Y, b2Z, 0.0) then
            local s1X, s1Y = convert3DCoordsToScreen(b1X, b1Y, b1Z)
            local s2X, s2Y = convert3DCoordsToScreen(b2X, b2Y, b2Z)
            renderDrawLine(s1X, s1Y, s2X, s2Y, 1, 0xFFFFFFFF) 
        end
    end
end

function runESP()
    if not cfg.ped.espActive then return end
    
    for id = 0, sampGetMaxPlayerId(true) do
        if sampIsPlayerConnected(id) then
            local exist, handle = sampGetCharHandleBySampPlayerId(id)
            if exist and not sampIsDialogActive() and handle ~= PLAYER_PED then
                local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
                local pedX, pedY, pedZ = getCharCoordinates(handle)
                local floordistance = math.floor(getDistanceBetweenCoords3d(myX, myY, myZ, pedX, pedY, pedZ))
                
               
                if floordistance <= cfg.ped.distance then
                  
                    if cfg.ped.pedSkeleton then
                        drawSkeleton(handle)
                    end

                    local dynamicOffset = 1.45 + (floordistance / 150)
                    local X, Y, Z = getOffsetFromCharInWorldCoords(handle, 0.0, 0.0, dynamicOffset)
                    local result = isPointOnScreen(X, Y, Z, 0.0)
                    
                    if result then
                        local screenX, screenY = convert3DCoordsToScreen(X, Y, Z)
                        local color = ("%06X"):format(bit.band(sampGetPlayerColor(id), 0xFFFFFF))
                        local hp = sampGetPlayerHealth(id)
                        local arm = sampGetPlayerArmor(id)
                        local name = sampGetPlayerNickname(id)
                        
                        if cfg.ped.pedCustomNicks then 
                            memory.setint16(sampGetBase() + 0x70D40, 0xC390, true) 
                        else 
                            memory.setint16(sampGetBase() + 0x70D40, 0x8B55, true) 
                        end
                        
                        local currentY = screenY
                        local barWidth = 40
                        local barHeight = 4
                        
                        if cfg.ped.pedCustomNicks then
                            local afkPart = ""
                            if cfg.ped.pedAfk and sampIsPlayerPaused(id) then
                                afkPart = "{A9A9A9}[AFK] "
                            end
                            
                            local nickText = afkPart .. "{"..color.."}"..name.." {DCDDE1}["..id.."]"
                            local textWidth = renderGetFontDrawTextLength(fontESP, nickText:gsub("{%x%x%x%x%x%x}", ""))
                            
                            renderFontDrawText(fontESP, nickText:gsub("{%x%x%x%x%x%x}", ""), screenX - (textWidth / 2) + 1, currentY - 4 + 1, 0xFF000000)
                            renderFontDrawText(fontESP, nickText, screenX - (textWidth / 2), currentY - 4, 0xFFFFFFFF)
                            currentY = currentY + 14
                        end
                        
                        if cfg.ped.pedHpArm then
                            drawBar(screenX - (barWidth / 2), currentY, barWidth, barHeight, hp, 100, 0xFFFF0000, 0xFF333333)
                            currentY = currentY + barHeight + 2
                            if arm > 0 then
                                drawBar(screenX - (barWidth / 2), currentY, barWidth, barHeight, arm, 100, 0xFFFFFFFF, 0xFF333333)
                                currentY = currentY + barHeight + 2
                            end
                        end
                        
                        if cfg.ped.pedLvl then
                            local lvlText = "{D1EEEE}"..sampGetPlayerScore(id).." LVL"
                            local textWidth = renderGetFontDrawTextLength(fontESP, lvlText:gsub("{%x%x%x%x%x%x}", ""))
                            renderFontDrawText(fontESP, lvlText, screenX - (textWidth / 2), currentY, 0xFFFFFFFF)
                            currentY = currentY + 12
                        end
                        
                        if cfg.ped.pedPing then
                            local pingText = "{FFFFFF}"..sampGetPlayerPing(id).." Ping"
                            local textWidth = renderGetFontDrawTextLength(fontESP, pingText:gsub("{%x%x%x%x%x%x}", ""))
                            renderFontDrawText(fontESP, pingText, screenX - (textWidth / 2), currentY, 0xFFFFFFFF)
                            currentY = currentY + 12
                        end
                        
                        if cfg.ped.pedGun then
                            local gunName = weapons.get_name(getCurrentCharWeapon(handle))
                            local gunText = "{A9A9A9}"..gunName
                            local textWidth = renderGetFontDrawTextLength(fontESP, gunText:gsub("{%x%x%x%x%x%x}", ""))
                            renderFontDrawText(fontESP, gunText, screenX - (textWidth / 2), currentY, 0xFFFFFFFF)
                        end
                    end
                end
            end
        end
    end
end

local function drawSidebar()
    imgui.BeginChild("##sidebar", imgui.ImVec2(180, 0), true)
    
    imgui.Spacing()
    if logo_texture then
        imgui.Image(logo_texture, imgui.ImVec2(150, 40))
    else
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.2, 0.5, 1.0, 1.0))
        imgui.SetWindowFontScale(1.4)
        imgui.Text(" " .. IC("send") .. " Auto Msg")
        imgui.SetWindowFontScale(1.0)
        imgui.PopStyleColor()
    end
    imgui.TextDisabled("Horizonte Roleplay")
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local tabs = {
        { "Perfil Staff", "user-shield", 5 },
        { "Início", "home", 0 },
        { "Sistemas Msg", "layout-grid", 1 },
        { "ESP (Wallhack)", "eye", 6 },
        { "Configurações", "settings", 2 },
        { "Sobre", "info-circle", 4 }
    }

    for _, t in ipairs(tabs) do
        local selected = activeTab.v == t[3]
        if selected then imgui.PushStyleColor(imgui.Col.Button, imgui.GetStyle().Colors[imgui.Col.Header]) end
        if imgui.Button(IC(t[2]) .. "  " .. t[1], imgui.ImVec2(160, 40)) then activeTab.v = t[3] end
        if selected then imgui.PopStyleColor() end
        imgui.Spacing()
    end

    imgui.SetCursorPosY(imgui.GetWindowHeight() - 60)
    imgui.TextDisabled(" Desenvolvido por Paulinho")
    imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.2, 1.0), " " .. IC("circle-check") .. " Ativo")

    imgui.EndChild()
end

local function drawESPMenu()
    imgui.BeginChild("##esp_tab", imgui.ImVec2(0, 0), true)
    imgui.TextColored(imgui.ImVec4(0.2, 0.5, 1.0, 1.0), IC("eye") .. " CONFIGURAÇÕES DE ESP (WALLHACK)")
    imgui.Separator()
    imgui.Spacing()
    
    if ToggleSwitch("Ativar ESP", espActive) then
        cfg.ped.espActive = espActive.v
        saveConfig()
    end
    
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    
    imgui.Columns(2, "esp_cols", false)
    
    if imgui.Checkbox('Mostrar Nível', espLvl) then
        cfg.ped.pedLvl = espLvl.v 
        saveConfig()
    end
    if imgui.Checkbox('Mostrar HP/Colete', espHpArm) then
        cfg.ped.pedHpArm = espHpArm.v 
        saveConfig()
    end
    if imgui.Checkbox('Mostrar Status AFK', espAfk) then
        cfg.ped.pedAfk = espAfk.v 
        saveConfig()
    end
    if imgui.Checkbox('Exibir Arma Atual', espGun) then
        cfg.ped.pedGun = espGun.v 
        saveConfig()
    end
    
    imgui.NextColumn()
    
    if imgui.Checkbox('Mostrar Ping', espPing) then
        cfg.ped.pedPing = espPing.v 
        saveConfig()
    end
    if imgui.Checkbox('ESP Esqueleto', espSkeleton) then
        cfg.ped.pedSkeleton = espSkeleton.v 
        saveConfig()
    end
    if imgui.Checkbox('Nick Personalizado', espCustomNicks) then
        cfg.ped.pedCustomNicks = espCustomNicks.v 
        saveConfig()
    end
    
    imgui.Columns(1)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    
    imgui.PushItemWidth(300)
    if imgui.SliderFloat('Distância Máxima', espDistance, 0, 500) then
        cfg.ped.distance = espDistance.v 
        saveConfig()
    end
    imgui.PopItemWidth()
    imgui.TextDisabled("Ajuste a distância de renderização dos nomes e status.")
    
    imgui.EndChild()
end

local function drawStaffProfile()
    imgui.BeginChild("##staff_profile_tab", imgui.ImVec2(0, 0), true)
    
    if not staffProfile.isStaff then
        imgui.SetCursorPosY(imgui.GetWindowHeight() / 2 - 30)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.6, 0.6, 0.6, 1.0))
        imgui.SetWindowFontScale(1.1)
        imgui.TextWrapped("AGUARDANDO AUTENTICAÇÃO...")
        imgui.SetWindowFontScale(1.0)
        imgui.TextWrapped("\nConecte-se à administração para desbloquear o seu Painel de Elite.")
        imgui.PopStyleColor()
    else
        imgui.TextColored(imgui.ImVec4(0.2, 0.5, 1.0, 1.0), IC("shield-check") .. " CENTRAL DO COLABORADOR")
        imgui.Separator()
        imgui.Spacing()
        
        imgui.PushStyleColor(imgui.Col.ChildWindowBg, imgui.ImVec4(0.06, 0.08, 0.12, 1.0))
        imgui.BeginChild("##staff_identity", imgui.ImVec2(0, 180), true)
        
        local p = imgui.GetCursorScreenPos()
        local draw = imgui.GetWindowDrawList()
        local iconSize = 110
        local iconX = 20
        local iconY = 35
        
        draw:AddRectFilled(imgui.ImVec2(p.x + iconX, p.y + iconY), imgui.ImVec2(p.x + iconX + iconSize, p.y + iconY + iconSize), imgui.GetColorU32(imgui.ImVec4(0.08, 0.1, 0.15, 0.9)), 15.0)
        draw:AddRect(imgui.ImVec2(p.x + iconX, p.y + iconY), imgui.ImVec2(p.x + iconX + iconSize, p.y + iconY + iconSize), imgui.GetColorU32(imgui.ImVec4(0.2, 0.5, 1.0, 0.8)), 15.0, 15, 2.0)

        if staff_icon_texture then
            imgui.SetCursorPos(imgui.ImVec2(iconX + 10, iconY + 10))
            imgui.Image(staff_icon_texture, imgui.ImVec2(90, 90))
        else
            imgui.SetCursorPos(imgui.ImVec2(iconX + 18, iconY + 8))
            imgui.SetWindowFontScale(4.8)
            imgui.TextColored(imgui.ImVec4(0.2, 0.6, 1.0, 1.0), IC("user-shield"))
            imgui.SetWindowFontScale(1.0)
        end

        local textStartX = 150
        imgui.SetCursorPos(imgui.ImVec2(textStartX, 40))
        imgui.TextDisabled(IC("user") .. " ADMINISTRADOR:")
        imgui.SetCursorPos(imgui.ImVec2(textStartX, 60))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.2, 0.6, 1.0, 1.0))
        imgui.Text(staffProfile.nick:upper())
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(textStartX, 80))
        imgui.TextDisabled(IC("id") .. " RG DO STAFF:")
        imgui.SetCursorPos(imgui.ImVec2(textStartX, 100))
        imgui.Text(staffProfile.rg ~= "" and staffProfile.rg or "N/A")
        
        imgui.SetCursorPos(imgui.ImVec2(textStartX, 130))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.6, 0.1, 0.3))
        imgui.Button(IC("award") .. " " .. staffProfile.cargo:upper(), imgui.ImVec2(0, 32))
        imgui.PopStyleColor()
    
        
        imgui.EndChild()
        imgui.PopStyleColor()
        
        imgui.Spacing()
        
        imgui.PushStyleColor(imgui.Col.ChildWindowBg, imgui.ImVec4(0.08, 0.12, 0.10, 0.6))
        imgui.BeginChild("##staff_motivation", imgui.ImVec2(0, 140), true)
        
        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), IC("sparkles") .. " MENSAGEM DE ELITE")
        imgui.Separator()
        imgui.Spacing()
        
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.9, 0.9, 0.9, 1.0))
        imgui.TextWrapped(staffProfile.msgBoasVindas)
        imgui.PopStyleColor()
        
        imgui.EndChild()
        imgui.PopStyleColor()

        imgui.SetCursorPosY(imgui.GetWindowHeight() - 40)
        imgui.TextDisabled(IC("star") .. " Você faz a diferença na nossa comunidade hoje!")
    end
    imgui.EndChild()
end

local function drawDashboard()
    imgui.BeginChild("##dashboard", imgui.ImVec2(0, 0), true)
    imgui.Text(" Painel de Resumo")
    imgui.Separator()
    imgui.Spacing()

    imgui.Columns(3, "stats_cols", false)
    StatCard("Players Online", getOnlinePlayers(), "users", imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
    imgui.NextColumn()
    StatCard("Canais Ativos", #systems, "broadcast", imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
    imgui.NextColumn()
    StatCard("Total Mensagens", getTotalMessages(), "message-dots", imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
    imgui.Columns(1)

    imgui.Spacing()
    imgui.Text(" Status dos Serviços")
    imgui.Separator()
    imgui.Spacing()

    imgui.BeginChild("##services_status", imgui.ImVec2(0, 150), true)
    
    local saciar_status = cfg.config.auto_saciar and "ATIVO" or "DESATIVADO"
    local saciar_color = cfg.config.auto_saciar and imgui.ImVec4(0.2, 0.8, 0.2, 1.0) or imgui.ImVec4(0.8, 0.2, 0.2, 1.0)
    
    imgui.Text(" " .. IC("cookie") .. " Auto Saciarme:")
    imgui.SameLine(180)
    imgui.TextColored(saciar_color, saciar_status)
    
    local esp_status = cfg.ped.espActive and "ATIVO" or "DESATIVADO"
    local esp_color = cfg.ped.espActive and imgui.ImVec4(0.2, 0.8, 0.2, 1.0) or imgui.ImVec4(0.8, 0.2, 0.2, 1.0)
    
    imgui.Spacing()
    imgui.Text(" " .. IC("eye") .. " ESP (Wallhack):")
    imgui.SameLine(180)
    imgui.TextColored(esp_color, esp_status)

    imgui.EndChild()

    imgui.Columns(1)
    imgui.SetCursorPosY(imgui.GetWindowHeight() - 40)
    imgui.TextDisabled(" Servidor: " .. (sampGetCurrentServerName() or "Desconhecido"))

    imgui.EndChild()
end

local function drawSystemList()
    imgui.BeginChild("##system_list", imgui.ImVec2(300, 0), true)
    imgui.Text(" Sistemas Configurados")
    imgui.SameLine(180)
    if imgui.Button(IC("plus") .. " Novo", imgui.ImVec2(100, 25)) then
        local newId = #systems + 1
        systems[newId] = { channel = "/n", interval = 60, status = false, messages = {}, lastTime = 0 }
        selectedSystemIdx = newId
        updateEditBuffers()
        saveConfig()
    end
    imgui.Separator()
    imgui.Spacing()

    for i, sys in ipairs(systems) do
        local isSelected = selectedSystemIdx == i
        local color = sys.status and imgui.ImVec4(0.2, 0.8, 0.2, 1.0) or imgui.ImVec4(0.8, 0.2, 0.2, 1.0)
        if isSelected then imgui.PushStyleColor(imgui.Col.ChildWindowBg, imgui.ImVec4(0.10, 0.12, 0.18, 1.0)) end
        imgui.BeginChild("##sys_card_" .. i, imgui.ImVec2(0, 95), true)
        imgui.TextColored(color, IC("circle") .. " Sistema " .. i)
        imgui.SameLine(200)
        imgui.TextDisabled(sys.status and "ATIVO" or "DESLIGADO")
        imgui.TextDisabled(" Canal: " .. sys.channel)
        imgui.TextDisabled(" Tempo: " .. sys.interval .. "s | Mensagens: " .. #sys.messages)
        imgui.SetCursorPos(imgui.ImVec2(180, 50))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.7, 0.2, 0.6)) 
        if imgui.Button(IC("edit") .. "##edit_" .. i, imgui.ImVec2(35, 35)) then
            selectedSystemIdx = i
            updateEditBuffers()
        end
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 0.6)) 
        if imgui.Button(IC("trash") .. "##del_" .. i, imgui.ImVec2(35, 35)) then
            table.remove(systems, i)
            if selectedSystemIdx > #systems then selectedSystemIdx = math.max(1, #systems) end
            updateEditBuffers()
            saveConfig()
        end
        imgui.PopStyleColor()
        imgui.EndChild()
        if isSelected then imgui.PopStyleColor() end
        imgui.Spacing()
    end
    imgui.EndChild()
end

local function drawEditor()
    local sys = systems[selectedSystemIdx]
    if not sys then 
        imgui.BeginChild("##editor", imgui.ImVec2(0, 0), true)
        imgui.Text("Selecione ou crie um sistema para editar.")
        imgui.EndChild()
        return 
    end

    imgui.BeginChild("##editor", imgui.ImVec2(0, 0), true)
    imgui.Text(" Editar Sistema " .. selectedSystemIdx)
    imgui.Separator()
    if ToggleSwitch("Sistema Ativado", editStatus) then
        sys.status = editStatus.v
        saveConfig()
    end
    imgui.Columns(2, "edit_cols", false)
    imgui.Text("Canal")
    imgui.InputText("##channel", editChannel)
    imgui.NextColumn()
    imgui.Text("Intervalo (segundos)")
    imgui.InputInt("##interval", editInterval)
    imgui.Columns(1)
    imgui.BeginChild("##msg_list", imgui.ImVec2(0, 180), true)
    for i, m in ipairs(sys.messages) do
        imgui.Text(i .. "  " .. m)
        imgui.SameLine(imgui.GetWindowWidth() - 85)
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.7, 0.2, 0.6)) 
        if imgui.Button(IC("edit") .. "##edit_msg_" .. i, imgui.ImVec2(30, 30)) then
            newMessageBuffer.v = m
            table.remove(sys.messages, i)
        end
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 0.6)) 
        if imgui.Button(IC("trash") .. "##del_msg_" .. i, imgui.ImVec2(30, 30)) then
            table.remove(sys.messages, i)
            saveConfig()
        end
        imgui.PopStyleColor()
        imgui.Separator()
    end
    imgui.EndChild()
    imgui.InputText("##new_msg", newMessageBuffer)
    imgui.SameLine()
    if imgui.Button(IC("plus") .. " Adicionar", imgui.ImVec2(100, 30)) then
        if newMessageBuffer.v ~= "" then
            table.insert(sys.messages, newMessageBuffer.v)
            newMessageBuffer.v = ""
            saveConfig()
        end
    end
    imgui.SetCursorPosY(imgui.GetWindowHeight() - 60)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 0.6)) 
    if imgui.Button(IC("trash") .. " Excluir Sistema", imgui.ImVec2(160, 40)) then
        table.remove(systems, selectedSystemIdx)
        selectedSystemIdx = 1
        updateEditBuffers()
        saveConfig()
    end
    imgui.PopStyleColor()
    imgui.SameLine(imgui.GetWindowWidth() - 190)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.7, 0.2, 0.6)) 
    if imgui.Button(IC("save") .. " Salvar Alterações", imgui.ImVec2(180, 40)) then
        sys.channel = editChannel.v
        sys.interval = math.max(1, editInterval.v)
        sys.status = editStatus.v
        saveConfig()
        msg("Alterações salvas!")
    end
    imgui.PopStyleColor()
    imgui.EndChild()
end

local function drawConfigTab()
    imgui.BeginChild("##config_tab", imgui.ImVec2(0, 0), true)
    imgui.Text("Configurações Gerais")
    imgui.Separator()
    imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(0.2, 0.5, 1.0, 1.0), IC("settings") .. " Atalho do Menu")
    imgui.Separator()
    imgui.Spacing()

    local currentKeyName = getKeyDisplayName(cfg.config.toggle_key or 0x76)

    local keyBtnLabel = capturingKey
        and IC("keyboard") .. "  Pressione qualquer tecla..."
        or IC("keyboard") .. "  Tecla atual: " .. currentKeyName

    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.05))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1, 1, 1, 0.10))

    if imgui.Button(keyBtnLabel, imgui.ImVec2(0, 35)) then
        if capturingKey then
            capturingKey = false
        else
            capturingKey = true
            captureMessage = ""
            captureMessageTime = 0
        end
    end

    imgui.PopStyleColor(3)
    
    imgui.Spacing()
    
    if capturingKey then
        local alpha = (math.sin(os.clock() * 6) + 1) * 0.35 + 0.15
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.7, 0.2, alpha))
        imgui.Text("  Aguardando tecla... Pressione qualquer tecla para definir o novo atalho.")
        imgui.PopStyleColor()
        imgui.Spacing()
        
        imgui.TextDisabled("  Dica: Pressione ESC para cancelar.")
    end
    
  
    if captureMessage ~= "" and os.clock() - captureMessageTime < 5 then
        local elapsed = os.clock() - captureMessageTime
        local fadeAlpha = elapsed < 3 and 1.0 or math.max(0, 1.0 - (elapsed - 3) / 2)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.2, 0.9, 0.3, fadeAlpha))
        imgui.Text("  " .. captureMessage)
        imgui.PopStyleColor()
    end
    
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    if ToggleSwitch("Notificações no Chat", ui_notify) then
        cfg.config.notify = ui_notify.v
        saveConfig()
    end
    imgui.Spacing()
    if ToggleSwitch("Auto Saciar (/saciarme)", ui_auto_saciar) then
        cfg.config.auto_saciar = ui_auto_saciar.v
        saveConfig()
    end
    if cfg.config.auto_saciar then
        imgui.PushItemWidth(200)
        if imgui.InputInt("Tempo (seg)", ui_auto_saciar_tempo) then
            cfg.config.auto_saciar_tempo = ui_auto_saciar_tempo.v
            saveConfig()
        end
        imgui.PopItemWidth()
    end
    imgui.Spacing()
    local themes = {"Azul (Padrão)", "Roxo"}
    for i, name in ipairs(themes) do
        if imgui.RadioButton(name, cfg.config.tema_cor == i) then
            cfg.config.tema_cor = i
            setTheme(i)
            saveConfig()
        end
    end
    imgui.EndChild()
end

function imgui.OnDrawFrame()
    if not menuOpen.v then return end

    imgui.SetNextWindowSize(imgui.ImVec2(950, 650), imgui.Cond.FirstUseEver)
    imgui.Begin("Auto Mensagem Premium", menuOpen, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)

    imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 50, 15))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4, 0.1, 0.1, 0.6))
    if imgui.Button(IC("x") .. "##close_menu", imgui.ImVec2(40, 35)) then
        menuOpen.v = false
        imgui.Process = false
    end
    imgui.PopStyleColor(1)

    drawSidebar()
    imgui.SameLine()

    if activeTab.v == 0 then
        drawDashboard()
    elseif activeTab.v == 1 then
        drawSystemList()
        imgui.SameLine()
        drawEditor()
    elseif activeTab.v == 5 then
        drawStaffProfile()
    elseif activeTab.v == 6 then
        drawESPMenu()
    elseif activeTab.v == 2 then
        drawConfigTab()
    else
        imgui.BeginChild("##about_tab", imgui.ImVec2(0, 0), true)

    imgui.Text("Painel Hz")
    imgui.Separator()

    imgui.Text("Versao: v2.0")
    imgui.Text("Desenvolvedor: PaulinhoDlaurenn")
    imgui.Text("Base Grafica: Horizonte RP")
    imgui.Spacing()

    imgui.Text("Recursos")
    imgui.BulletText("Sistemas ilimitados de Auto Mensagem")
    imgui.BulletText("ESP Premium Integrado")
    imgui.BulletText("ESP Esqueleto (Skeleton)")
    imgui.BulletText("Atualizacao automatica")
    imgui.BulletText("Configuracoes salvas automaticamente")
    imgui.BulletText("Interface moderna e otimizada")

    imgui.Spacing()
    imgui.Separator()
    imgui.Text("Obrigado por utilizar o Painel Hz!")

    imgui.EndChild()
    end
    imgui.End()
end

local lastSaciarTime = 0
local ev = require "lib.samp.events"

function ev.onServerMessage(color, text)
    local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
    if cleanText:find("INFO: Ola ") and cleanText:find("voce logou na administra") then
        local cargo, nick = cleanText:match("INFO: Ola (.-) (.-), voce logou")
        if cargo and nick then
            staffProfile.isStaff = true
            staffProfile.nick = nick:gsub(",", "")
            staffProfile.cargo = cargo
            staffProfile.msgBoasVindas = string.format(
    "Bem-vindo(a), %s!\n\nÉ um prazer tê-lo(a) em nossa equipe. Como %s, sua dedicação, profissionalismo e colaboração são essenciais para o sucesso de nossas operações. Desejamos uma excelente experiência e muito sucesso em sua jornada.",
    staffProfile.nick,
    cargo
)
            sampAddChatMessage("{3486F2}[Staff] {FFFFFF}Perfil administrativo atualizado!", -1)
        end
    end

    if cleanText:find("INFO: Seja bem%-vindo%(a%)") and cleanText:find("Ultimo login:") then
        local nick, rg = cleanText:match("INFO: Seja bem%-vindo%(a%) (.-)%[(%d+)%]")
        if nick and rg then
            staffProfile.nick = nick:gsub("%s+$", "")
            staffProfile.rg = rg
            sampAddChatMessage("{3486F2}[Staff] {FFFFFF}RG coletado: {0080FF}" .. rg, -1)
        end
    end
end

local function processKeyToggle()
    local currentKeyState = isKeyDown(cfg.config.toggle_key or 0x76)
    
    if currentKeyState and not lastToggleKeyState then
        if not capturingKey and not sampIsChatInputActive() and not sampIsDialogActive() and not sampIsCursorActive() then
            menuOpen.v = not menuOpen.v
            imgui.Process = menuOpen.v
        end
    end
    
    lastToggleKeyState = currentKeyState
    if keyCaptureCooldown and os.clock() - keyCaptureCooldownTime > 0.5 then
        keyCaptureCooldown = false
    end
end

local function processKeyCapture()
    if not capturingKey then return end
    if keyCaptureCooldown then return end
    if isKeyDown(0x1B) then
        capturingKey = false
        keyCaptureCooldown = true
        keyCaptureCooldownTime = os.clock()
        msg("Captura de tecla cancelada.")
        return
    end
    for vk = 0, 255 do
        if isKeyDown(vk) and not blockedKeys[vk] then
            cfg.config.toggle_key = vk
            saveConfig()
            captureMessage = "Tecla alterada para: " .. getKeyDisplayName(vk)
            captureMessageTime = os.clock()
            capturingKey = false
            keyCaptureCooldown = true
            keyCaptureCooldownTime = os.clock()
            
            msg("Atalho do menu alterado para: " .. getKeyDisplayName(vk))
            break
        end
    end
end

function main()
    while not isSampAvailable() do wait(0) end

    pcall(checkForUpdates)
    
    loadConfig()
    setTheme(cfg.config.tema_cor)
    updateEditBuffers()
    loadAssets()

    sampRegisterChatCommand("painelhz", function()
        menuOpen.v = not menuOpen.v
        imgui.Process = menuOpen.v
    end)

    msg("Mod carregado! Use /painelhz ou pressione " .. getKeyDisplayName(cfg.config.toggle_key or 0x76) .. " para abrir o menu.")

    while true do
        wait(0)
        local now = os.clock()
        processKeyCapture()
        processKeyToggle()

        runESP()

        if now % 0.1 < 0.01 then
            for _, sys in pairs(systems) do
                if sys.status and #sys.messages > 0 then
                  
                    if not sys.msgIndex then sys.msgIndex = 1 end
                    if now - (sys.lastTime or 0) >= sys.interval then
                        sys.lastTime = now
                        if sys.msgIndex > #sys.messages then
                            sys.msgIndex = 1
                        end
                        local sent = 0
                        while sent < 2 and sys.msgIndex <= #sys.messages do
                            sampSendChat(sys.channel .. " " .. sys.messages[sys.msgIndex])
                            sys.msgIndex = sys.msgIndex + 1
                            sent = sent + 1
                            wait(50)
                        end
                        if sys.msgIndex > #sys.messages then
                            sys.msgIndex = 1
                        end
                    end
                end
            end
        end

        if cfg.config.auto_saciar and sampIsLocalPlayerSpawned() then
            if now - lastSaciarTime >= (cfg.config.auto_saciar_tempo or 300) then
                sampSendChat("/saciarme")
                lastSaciarTime = now
            end
        end
    end
end
