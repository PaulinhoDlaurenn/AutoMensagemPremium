script_name("AutoMensagemPremium Updater")
script_author("Respected")
require "lib.moonloader"

local requests = require "requests"

-- CONFIGURAÇÕES DO PROJETO
local GITHUB_USER = "PaulinhoDlaurenn"
local GITHUB_REPO = "AutoMensagemPremium"
local SCRIPT_NAME = "AutoMensagemPremium.lua"
local PROJECT_TAG = "AutoMensagemPremium" -- Tag para assinatura
local UPDATER_TAG = "HZUpdaterPC"         -- Tag exigida na validação

local VERSAO_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/main/versao.txt"
local SCRIPT_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/main/" .. SCRIPT_NAME
local SCRIPT_PATH = getWorkingDirectory() .. "\\" .. SCRIPT_NAME
local BACKUP_PATH = SCRIPT_PATH .. ".bak"
local TEMP_PATH = SCRIPT_PATH .. ".download"

local consultando = false

--------------------------------------------------------------------------------
-- FUNÇÕES UTILITÁRIAS
--------------------------------------------------------------------------------

local function chat(texto, cor)
    if isSampAvailable() then sampAddChatMessage(texto, cor or -1) end
end

local function ler(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function escrever(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    local ok = f:write(data)
    f:flush()
    f:close()
    return ok ~= nil and ler(path) == data
end

local function corpo(res)
    if type(res) ~= "table" then return nil end
    return res.text or res.body or res.data
end

local function urlNova(url)
    local sep = url:find("?", 1, true) and "&" or "?"
    return url .. sep .. "update_cache=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
end

--------------------------------------------------------------------------------
-- LÓGICA DE ATUALIZAÇÃO
--------------------------------------------------------------------------------

local function baixar(url)
    for tentativa = 1, 3 do
        local ok, res = pcall(requests.get, urlNova(url))
        local data = ok and corpo(res) or nil
        if type(data) == "string" and data ~= "" then return data end
        wait(700 * tentativa)
    end
    return nil
end

local function versaoDoCodigo(codigo)
    -- Procura por SCRIPT_VERSION = "x.x.x" ou versao = "x.x.x"
    local v = tostring(codigo or ""):match('SCRIPT_VERSION%s*=%s*"([%d%.]+)"')
    if not v then
        v = tostring(codigo or ""):match('versao%s*=%s*"([%d%.]+)"')
    end
    return v
end

local function comparar(a, b)
    local va, vb = {}, {}
    for n in tostring(a or ""):gmatch("%d+") do va[#va + 1] = tonumber(n) or 0 end
    for n in tostring(b or ""):gmatch("%d+") do vb[#vb + 1] = tonumber(n) or 0 end
    for i = 1, math.max(#va, #vb) do
        if (va[i] or 0) > (vb[i] or 0) then return 1 end
        if (va[i] or 0) < (vb[i] or 0) then return -1 end
    end
    return 0
end

local function validar(codigo, versaoEsperada)
    -- Validação de tamanho (ajustado para o seu script que tem ~1300 linhas, aprox 40-50kb)
    if type(codigo) ~= "string" or #codigo < 10000 then return false, "arquivo incompleto ou muito pequeno" end
    
    -- Validação de HTML/404
    if codigo:find("<html", 1, true) or codigo:find("404: Not Found", 1, true) then
        return false, "resposta do GitHub invalida (404 ou HTML)"
    end
    
    -- Validação de Assinatura (Exigido pelo modelo SETOR)
    if not codigo:find(PROJECT_TAG, 1, true) or not codigo:find(UPDATER_TAG, 1, true) then
        return false, "assinatura do projeto ausente (" .. PROJECT_TAG .. " ou " .. UPDATER_TAG .. ")"
    end
    
    -- Validação de Versão
    local versaoCodigo = versaoDoCodigo(codigo)
    if not versaoCodigo or tostring(versaoCodigo) ~= tostring(versaoEsperada) then
        return false, "versao.txt (" .. tostring(versaoEsperada) .. ") e script (" .. tostring(versaoCodigo) .. ") nao correspondem"
    end
    
    -- Validação de Sintaxe (loadstring)
    local compilado, erro = loadstring(codigo, "@" .. SCRIPT_NAME .. ".download")
    if not compilado then return false, "erro de sintaxe no codigo baixado: " .. tostring(erro) end
    
    return true
end

local function versaoInstalada()
    return versaoDoCodigo(ler(SCRIPT_PATH)) or "0.0.0"
end

local function restaurarBackup()
    local backup = ler(BACKUP_PATH)
    if not backup or #backup < 10000 then
        chat("{FF5555}[UPDATE]: Backup valido nao encontrado.")
        return false
    end
    if escrever(SCRIPT_PATH, backup) then
        chat("{00FF7F}[UPDATE]: Backup restaurado com sucesso. Reinicie o script.")
        return true
    end
    chat("{FF5555}[UPDATE]: Nao foi possivel restaurar o backup.")
    return false
end

local function instalar(silencioso, forcar)
    if consultando then return chat("{FFFF00}[UPDATE]: Atualizacao ja em andamento.") end
    consultando = true
    
    lua_thread.create(function()
        if not silencioso then chat("{48C6FF}[UPDATE]: Consultando GitHub...") end
        
        local versaoTexto = baixar(VERSAO_URL)
        local remota = versaoTexto and versaoTexto:match("([%d%.]+)") or nil
        local instalada = versaoInstalada()
        
        if not remota then
            consultando = false
            return chat("{FF5555}[UPDATE]: Falha ao consultar versao remota.")
        end
        
        if not forcar and comparar(remota, instalada) <= 0 then
            consultando = false
            if not silencioso then chat("{00FF7F}[UPDATE]: Script ja esta na versao mais recente (" .. instalada .. ").") end
            return
        end

        if not silencioso then chat("{FFFF00}[UPDATE]: Baixando versao " .. remota .. "...") end
        local novo = baixar(SCRIPT_URL)
        
        local valido, motivo = validar(novo, remota)
        if not valido then
            consultando = false
            return chat("{FF5555}[UPDATE]: Instalacao cancelada: " .. tostring(motivo) .. ".")
        end

        if not escrever(TEMP_PATH, novo) then
            consultando = false
            return chat("{FF5555}[UPDATE]: Falha ao salvar arquivo temporario.")
        end

        local atual = ler(SCRIPT_PATH)
        if atual and #atual >= 10000 then
            if not escrever(BACKUP_PATH, atual) then
                os.remove(TEMP_PATH)
                consultando = false
                return chat("{FF5555}[UPDATE]: Falha ao criar backup. Operacao abortada.")
            end
        end

        if not escrever(SCRIPT_PATH, novo) then
            if atual then escrever(SCRIPT_PATH, atual) end
            os.remove(TEMP_PATH)
            consultando = false
            return chat("{FF5555}[UPDATE]: Falha na substituicao. Versao anterior preservada.")
        end

        os.remove(TEMP_PATH)
        consultando = false
        chat("{00FF7F}[UPDATE]: Versao " .. remota .. " instalada com sucesso! Reiniciando...")
        wait(1000)
        -- Tenta recarregar o script alvo se ele estiver rodando
        local script = thisScript()
        if script.name ~= SCRIPT_NAME then
            -- Se este for um updater separado, ele apenas avisa
            chat("{FFFF00}[UPDATE]: Por favor, recarregue o script " .. SCRIPT_NAME)
        else
            script:reload()
        end
    end)
end

--------------------------------------------------------------------------------
-- COMANDOS E LOOP PRINCIPAL
--------------------------------------------------------------------------------

function main()
    while not isSampAvailable() do wait(200) end
    
    sampRegisterChatCommand("hzversao", function()
        chat("{48C6FF}[UPDATE]: Versao instalada: " .. versaoInstalada())
        instalar(false, false)
    end)
    
    sampRegisterChatCommand("hzatualizar", function() 
        instalar(false, true) 
    end)
    
    sampRegisterChatCommand("hzrollback", function()
        restaurarBackup()
    end)

    -- Verificação automática após 7 segundos
    wait(7000)
    instalar(true, false)
    
    while true do 
        wait(1000) 
    end
end
