sampev = require 'lib.samp.events'
require 'lib.sampfuncs'
require 'lib.moonloader'

local ffi = require "ffi"
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local dlstatus = require('moonloader').download_status

function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    local vec = ffi.new("float[3]")
    getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
    return vec[0], vec[1], vec[2]
end

local pfd -- ID жертвы
local acc_id -- номера аккаунта агента
local c_ids = {} -- челы из /contractas
local cstream -- состояние чекера контрактов в зоне стрима
local nametag -- состояние неймтега
local onlypp = false -- выключать ли скрипт, если он запущен не на PP
local autoupdate = true -- загружать ли обновления, если они имеются

local script_version = 4 --[[ используется для автообновления, во избежание проблем 
с получением новых обновлений, рекомендуется не изменять, в случае их появления измените значение на "1" ]]

local openStats = false
local openContractas = false

local update_url = 'https://raw.githubusercontent.com/moreveal/moreveal_hh/main/update.cfg'

local time_find = os.clock()
local time_stream = os.clock()

font = renderCreateFont('Bahnschrift Bold', 10) -- подключение шрифта для рендера текста

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    if not doesFileExist(getWorkingDirectory()..'/lib/requests.lua') then
        local requests_url = 'https://raw.githubusercontent.com/moreveal/moreveal_hh/main/requests.lua'
        local requests_path = getWorkingDirectory()..'/lib/requests.lua'
        downloadUrlToFile(requests_url, requests_path, function(id, status) 
            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                sampAddChatMessage("{cccccc}[ Hitman Helper ]: Библиотека 'requests' установлена автоматически.", -1)
            end
        end)
    end
    wait(1000)
    requests = require 'requests'

    local ip, port = sampGetCurrentServerAddress()
    if onlypp and ip ~= '176.32.37.62' and port ~= '7777' then
        sampAddChatMessage('{cccccc}[ Hitman Helper ]: Это не Pears Project, не думаю, что я буду полезен тебе тут..', -1)
        thisScript():unload()
    end

    repeat wait(0) until sampIsLocalPlayerSpawned() and isCharOnScreen(PLAYER_PED)

    if autoupdate then
        local response = requests.get(update_url)
        version, text_version = response.text:match('(%d+) | (.+)')
        if tonumber(version) > script_version then
            update = true
        end
    end

    id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    sampSendChat('/stats')
    openStats = true

    sampRegisterChatCommand('pfd', function(arg)
        if pfd == nil then
            if arg:find('%D') or #arg == 0 then
                sampAddChatMessage('{cccccc}[ Мысли ]: Правильное использование поиска: [/pfd ID]', -1)
            else
                if sampIsPlayerConnected(tonumber(arg)) then
                    pfd = tonumber(arg)
                    sampAddChatMessage('{cccccc}[ Мысли ]: Преследование за '..sampGetPlayerNickname(pfd)..' ['..pfd..'] запущено.', -1)
                else
                    sampAddChatMessage('{cccccc}[ Мысли ]: Кажется, этого игрока нет в сети', -1)
                end
            end
        else
            pfd = nil
            sampAddChatMessage('{cccccc}[ Мысли ]: Преследование прекращено.', -1)
        end
    end)

    sampRegisterChatCommand('zask', function(id)
        if not id:find('%D') and #id ~= 0 then
            sampSendChat('Я, Агент №'..acc_id..', готов приступить к выполнению контракта №'..id)
        else
            sampAddChatMessage('{cccccc}[ Мысли ]: Чтобы запросить контракт, я должен ввести: [/zask ID]')
        end
    end)

	sampRegisterChatCommand('cstream', function()
        cstream = not cstream
		sampAddChatMessage('{cccccc}[ Мысли ]: Я '..(cstream and 'включил' or 'выключил')..' чекер контрактов в зоне стрима.', -1)
    end)
    
    while true do
        wait(0)

        lua_thread.create(function ()
            if update then
                local script_url = 'https://www.dropbox.com/s/5ub84kcrtoq8mhz/moreveal_hh.lua?dl=1'
                downloadUrlToFile(script_url, thisScript().path, function(id, status)
                    if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                        sampAddChatMessage('{cccccc}[ Hitman Helper ]: Обновление загружено. Новая версия: '..text_version, -1)
                        sampAddChatMessage('{cccccc}[ Hitman Helper ]: Начинаю перезапуск скрипта. Ожидай, это не займет много времени.', -1)
                        thisScript():reload()
                    end 
                end)
                update = false
            end
        end)

        if not isKeyDown(0x77) then -- если кнопка F8 не нажата
            local sw, sh = getScreenResolution()
            

            if cstream then
                lua_thread.create(function ()
                    if os.clock() - time_stream >= 10 then
                        c_ids = {}
                        sampSendChat('/contractas')
                        openContractas = true
                        time_stream = os.clock()
                    end
                end)
            end

            if pfd ~= nil then
                lua_thread.create(function ()
                    if os.clock() - time_find >= 3 then
                        sampSendChat('/find '..pfd)
                        time_find = os.clock()
                    end
                end)

                if not isPauseMenuActive() and sampIsPlayerConnected(tonumber(pfd)) then
                    renderFontDrawText(font, '{ff0000}ПОИСК: {ffffff}'..sampGetPlayerNickname(pfd)..' [ '..pfd..' ]', sw * 0.75, sh * 0.91, 0xFFFFFFFF, 1)
                    local result, handle = sampGetCharHandleBySampPlayerId(pfd)
    
                    if result and doesCharExist(handle) and isCharOnScreen(handle) then
                        local px, py, pz = getActiveCameraCoordinates()
                        local tpx, tpy, tpz = getBodyPartCoordinates(5, handle)
    
                        local result, _ = processLineOfSight(px, py, pz, tpx, tpy, tpz, true, false, false, true, false, true, false, false)
                        if not result then
                            local wposX, wposY = convert3DCoordsToScreen(tpx, tpy, tpz)
    
                            renderDrawLine(wposX - 3, wposY - 3, wposX + 3, wposY + 3, 1, 0xFFFFFFFF)
                            renderDrawLine(wposX - 3, wposY + 3, wposX + 3, wposY - 3, 1, 0xFFFFFFFF)
                        end
                    end
                end
            end

            if getInvisiblity(id) then
                if pfd ~= nil then
                    renderFontDrawText(font, '{0088ff}НЕВИДИМОСТЬ', sw * 0.75, sh * 0.88, 0xFFFFFFFF)
                else
                    renderFontDrawText(font, '{0088ff}НЕВИДИМОСТЬ', sw * 0.75, sh * 0.91, 0xFFFFFFFF)
                end
            end

            if pfd ~= nil then
                renderFontDrawText(font, 'NAMETAG ['..(nametag and '{008000} ON ' or '{ff0000} OFF ')..'{ffffff}]', sw * 0.902, sh * 0.91, 0xFFFFFFFF, 1)
            else
                if getInvisiblity(id) then
                    renderFontDrawText(font, 'NAMETAG ['..(nametag and '{008000} ON ' or '{ff0000} OFF ')..'{ffffff}]', sw * 0.83, sh * 0.91, 0xFFFFFFFF, 1)
                else
                    renderFontDrawText(font, 'NAMETAG ['..(nametag and '{008000} ON ' or '{ff0000} OFF ')..'{ffffff}]', sw * 0.75, sh * 0.91, 0xFFFFFFFF, 1)
                end
            end
        end
    end
end

function sampev.onSendGiveDamage(playerid, damage, weapon, bodypart)
    if playerid == pfd and sampGetPlayerHealth(playerid) - damage <= 0 then
        pfd = nil
    end
end

function sampev.onShowDialog(dialogid, style, title, b1, b2, text)
    if openStats and dialogid == 1500 then
        for line in text:gmatch('[^\r\n]+') do
            if line:find('Аккаунт №') then
                acc_id = line:match('Аккаунт №%s?%{......%}?%s?(%d+)')
                break
            end
        end
        openStats = false
        return false
    end
    if openContractas and dialogid == 8999 then
        for line in text:gmatch("[^\r\n]+") do
            local id, sum = line:match('%[(%d+)%].+(%d+)$')
            table.insert(array, id, sum)
        end
		openContractas = false
        return false
    end
end

function sampev.onServerMessage(color, text)
    if text:find('Я открыл своё лицо%s?%{......%}%s?%[ Никнейм включён %]') then
        nametag = false
    end
    if text:find('Я закрыл своё лицо%s?%{......%}%s?%[ Никнейм отключён %]') then
        nametag = true
    end
    if text:find('%[ Мысли %]%: Я не могу видеть список потенциальных жертв') then
        return false
    end
    if text:find('%[ Мысли %]%: Я не могу искать человека') then
        return false
    end
end

function sampev.onPlayerStreamIn(playerid, team, model, position)
    if cstream then
        for k, v in pairs(c_ids) do
            if k == playerid then
                sampAddChatMessage('{cccccc}[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {ffffff}[ {800000}'..k..' {ffffff}] в зоне стрима. Стоимость - {800000}'..v..'${ffffff}.', -1)
            end
        end
    end
end

function sampev.onPlaySound(id)
    if id == 40405 then 
        if cstream then
            return false
        end
    end
end

function sampev.onPlayerStreamOut(playerid)
    if cstream then
        for k, v in pairs(c_ids) do
            if k == playerid then
                sampAddChatMessage('{cccccc}[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {ffffff}[ {800000}'..k..' {ffffff}] покинул зону стрима.', -1)
            end
        end
    end
end

function getInvisiblity(id)
    if sampGetPlayerColor(id) == 16777215 then
        return true 
    else 
        return false
    end
end
