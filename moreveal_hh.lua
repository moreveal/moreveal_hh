sampev = require 'lib.samp.events'
require 'lib.sampfuncs'
require 'lib.moonloader'
local inicfg = require 'inicfg'

local ffi = require "ffi"
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local dlstatus = require('moonloader').download_status
local thispp = false

function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    local vec = ffi.new("float[3]")
    getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
    return vec[0], vec[1], vec[2]
end

local pfd -- ID жертвы
local acc_id -- номера аккаунта агента
local c_ids = {} -- люди из /contractas

local otstrel_list = {} -- люди, состоящие в списке отстрела
local otstrel_online = {} -- люди, состоящие в списке отстрела онлайн

local cstream -- состояние чекера контрактов в зоне стрима
local nametag -- состояние неймтега
local autoscreen -- делать ли скриншот после выполненного контракта
local metka -- ставить ли метку на голове у игрока, занесенного в PFD
local without_screen -- скрывать ли скрипт при скриншоте
local otstrel -- состояние чекера отстрела
local ooc_only -- состояние OOC-чата по умолчанию
local search_other_servers -- вести ли поиск за игроком, занесенного в PFD, на сторонних серверах
local onlypp -- выключать ли скрипт, если он запущен не на PP
local autoupdate -- загружать ли обновления, если они имеются

local D_SETCOLOR = 5111 -- диалог для выбора цвета
local D_SETTING = 5112 -- диалог для настройки скрипта
local D_INVALID = 5113 -- диалог, использующийся для вывода информации

local script_version = 8 --[[ Используется для автообновления, во избежание проблем 
с получением новых обновлений, рекомендуется не изменять. В случае их появления измените значение на "1" ]]
local text_version = '0.6' -- версия для вывода в окне настроек, не изменять
local last_news = [[
{0088ff}Были добавлены/изменены следующие функции:
    {ff0000}*{ffffff} Меню с возможностью настройки каждой функции отдельно
    {ff0000}*{ffffff} Чекер отстрела [ /otstrel_list ]
    {ff0000}*{ffffff} Окно "О скрипте", которое ты сейчас читаешь
    {ff0000}*{ffffff} По умолчанию поиск жертвы не ведется на сторонних серверах
    {ff0000}*{ffffff} Возможность включения OOC-чата по умолчанию
    {ff0000}*{ffffff} Возможность авто-скриншота при выполнении контракта
      [только при убийстве цели, предварительно занесенной в PFD]
    {ff0000}*{ffffff} Возможность выключения скрипта при скриншоте
    {ff0000}*{ffffff} Команда [/cstream] была убрана, ввиду её переноса 
      в основное меню
    {ff0000}*{ffffff} Поиск игрока, занесенного в PFD, совершается раз в 4 секунды

{cccccc}Помимо этого было исправлено несколько недочетов, добавлена автоматическая
загрузка библиотек при их отсутствии

{cccccc}Список доступных команд:{ffffff}
    /sethh - основное меню скрипта с необходимыми настройками
    /pfd [id] - запустить постоянный поиск за человеком
    /zask [id] - запросить контракт в [/f]
    /otstrel_list - просмотреть людей из списка отстрела {008000}Online{ffffff}
    /setcolor - быстрый выбор цвета организации{ff0000}
    ----------------------------------------------------------------------------------------------------------------------
]]

local openStats = false
local openContractas = false

local update_url = 'https://raw.githubusercontent.com/moreveal/moreveal_hh/main/update.cfg'

local time_find = os.clock() -- таймер /find
local time_stream = os.clock() -- таймер чекера контрактов в зоне стрима
local time_otstrel = os.clock() -- таймер чекера людей из списка отстрела

font = renderCreateFont('Bahnschrift Bold', 10) -- подключение шрифта для большей части надписей
font_hud = renderCreateFont('Bahnschrift Bold', 14) -- подключение шрифта для остального текста

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    if not doesFileExist(getWorkingDirectory()..'/lib/requests.lua') then
        local requests_url = 'https://www.dropbox.com/s/ytymzr9p8bw6vui/requests.lua?dl=1'
        local requests_path = getWorkingDirectory()..'/lib/requests.lua'
        downloadUrlToFile(requests_url, requests_path, function(id, status) 
            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                sampAddChatMessage("[ Hitman Helper ]: Библиотека 'requests' установлена автоматически.", -1)
            end
        end)
    end
    wait(1000)
    requests = require 'requests'

    local ip, port = sampGetCurrentServerAddress()
    if ip ~= '176.32.37.62' and port ~= '7777' then
        if onlypp then
            sampAddChatMessage('[ Hitman Helper ]: Это не Pears Project, не думаю, что я буду полезен тебе тут..', 0xCCCCCC)
            thisScript():unload()
        end
    else
        thispp = true
    end

    config_path = getWorkingDirectory()..'/config/hh_config.ini'
    mainIni = inicfg.load(nil, config_path)

    if not doesFileExist(config_path) then
        mainIni = inicfg.load({
        config = {
            cstream = 0,
            autoscreen = 0,
            metka = 0,
            without_screen = 0,
            otstrel = 0,
            ooc_only = 0,
            search_other_servers = 0,
            onlypp = 0,
            autoupdate = 1
            }
        }, '/config/hh_config.ini')
    else
        if mainIni.config.cstream == 0 then cstream = false else cstream = true end
        if mainIni.config.autoscreen == 0 then autoscreen = false else autoscreen = true end
        if mainIni.config.metka == 0 then metka = false else metka = true end
        if mainIni.config.without_screen == 0 then without_screen = false else without_screen = true end
        if mainIni.config.otstrel == 0 then otstrel = false else otstrel = true end
        if mainIni.config.ooc_only == 0 then ooc_only = false else ooc_only = true end
        if mainIni.config.search_other_servers == 0 then search_other_servers = false else search_other_servers = true end
        if mainIni.config.onlypp == 0 then onlypp = false else onlypp = true end
        if mainIni.config.autoupdate == 0 then autoupdate = false else autoupdate = true end
    end

    if otstrel then
        local otstrel_path = getWorkingDirectory()..'/config/otstrel.txt'
        local f = io.open(otstrel_path, 'r+')
        if f == nil then f = io.open(otstrel_path, 'w') end
        for line in f:lines() do
            table.insert(otstrel_list, line)
        end
        f:close()
    end

    repeat wait(0) until sampIsLocalPlayerSpawned() and isCharOnScreen(PLAYER_PED)

    local response = requests.get(update_url)
    new_version, text_new_version = response.text:match('(%d+) | (.+)')
    if tonumber(new_version) > script_version then
        if autoupdate then
            update = true
        else
            sampAddChatMessage('[ Hitman Helper ]: Найдено новое обновление. Версия: '..text_new_version, 0xCCCCCC)
            sampAddChatMessage('[ Hitman Helper ]: Рекомендуется включить автообновление в скрипте.', 0xCCCCCC)
        end
    end

    id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    if thispp then
        sampSendChat('/stats')
        openStats = true
    end

    if otstrel then
        for k, v in pairs(otstrel_list) do
            local id = sampGetPlayerIdByNickname(v)
            if id ~= nil then
                table.insert(otstrel_online, id)
            end
        end
        sampAddChatMessage('[ Отстрел ]: В сети обнаружено '..table.maxn(otstrel_online)..' человек из списка.', 0xCCCCCC)
    end

    sampRegisterChatCommand('pfd', function(arg)
        if pfd == nil then
            if arg:find('%D') or #arg == 0 then
                sampAddChatMessage('[ Мысли ]: Правильное использование поиска: [/pfd ID]', 0xCCCCCC)
            else
                if sampIsPlayerConnected(tonumber(arg)) then
                    pfd = tonumber(arg)
                    sampAddChatMessage('[ Мысли ]: Преследование за '..sampGetPlayerNickname(pfd)..' ['..pfd..'] запущено.', 0xCCCCCC)
                else
                    sampAddChatMessage('[ Мысли ]: Кажется, этого игрока нет в сети', 0xCCCCCC)
                end
            end
        else
            pfd = nil
            sampAddChatMessage('[ Мысли ]: Преследование прекращено.', 0xCCCCCC)
        end
    end)

    sampRegisterChatCommand('sethh', scriptMenu)

    sampRegisterChatCommand('otstrel_list', function()
        local dialog_text
        for k, v in pairs(otstrel_online) do
            local color = string.format('%06X', bit.band(sampGetPlayerColor(v),  0xFFFFFF))
            if dialog_text == nil then
                dialog_text = 'Никнейм\tID\n'..'{'..color..'}'..sampGetPlayerNickname(v)..'\t[ '..v..' ]\n'
            else
                dialog_text = dialog_text..'{'..color..'}'..sampGetPlayerNickname(v)..'\t[ '..v..' ]\n'
            end
        end
        sampShowDialog(D_INVALID, 'Список людей из списка отстрела {008000}Online', dialog_text, '*', nil, DIALOG_STYLE_TABLIST_HEADERS)
    end)

    sampRegisterChatCommand('zask', function(id)
        if not id:find('%D') and #id ~= 0 then
            if acc_id ~= nil then
                sampSendChat('Я, Агент №'..acc_id..', готов приступить к выполнению контракта №'..id)
            end
        else
            sampAddChatMessage('[ Мысли ]: Чтобы запросить контракт, я должен ввести: [/zask ID]', 0xCCCCCC)
        end
    end)
    
    while true do
        wait(0)

        local result, button, listitem, input = sampHasDialogRespond(D_SETCOLOR)
        if result then
            if button == 1 then
                sampSendChat('/setcolor '..listitem + 1)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_SETTING)
        if result then
            if button == 1 then
                local openMenu = true
                if listitem == 0 then
                    sampShowDialog(D_INVALID, 'О скрипте || Версия: '..text_version, last_news, '*', nil, DIALOG_STYLE_MSGBOX)
                    openMenu = false
                end
                if listitem == 1 then
                    autoscreen = not autoscreen
                    if autoscreen == false then mainIni.config.autoscreen = 0 else mainIni.config.autoscreen = 1 end
                    sampAddChatMessage('[ Мысли ]: Авто-скриншот выполненного контракта '..(autoscreen and 'включен' or 'выключен'), 0xCCCCCC)
                end
                if listitem == 2 then
                    cstream = not cstream
                    if cstream == false then mainIni.config.cstream = 0 else mainIni.config.cstream = 1 end
                    sampAddChatMessage('[ Мысли ]: Я '..(cstream and 'включил' or 'выключил')..' чекер контрактов в зоне стрима.', 0xCCCCCC)
                end
                if listitem == 3 then
                    metka = not metka
                    if metka == false then mainIni.config.metka = 0 else mainIni.config.metka = 1 end
                    sampAddChatMessage('[ Мысли ]: Я '..(metka and 'включил' or 'выключил')..' метку на голове игрока, занесенного в [ /pfd ]', 0xCCCCCC)
                end
                if listitem == 4 then
                    without_screen = not without_screen
                    if without_screen == false then mainIni.config.without_screen = 0 else mainIni.config.without_screen = 1 end
                    sampAddChatMessage('[ Мысли ]: Теперь скрипт '..(without_screen and 'будет' or 'не будет')..' скрываться при скриншоте', 0xCCCCCC)
                end
                if listitem == 5 then
                    otstrel = not otstrel
                    if otstrel == false then mainIni.config.otstrel = 0 else mainIni.config.otstrel = 1 end
                    if not doesFileExist(getWorkingDirectory()..'/config/otstrel.txt') then
                        local f = io.open(getWorkingDirectory()..'/config/otstrel.txt', 'w')
                        f:close()
                    end
                    sampAddChatMessage('[ Мысли ]: Я '..(otstrel and 'включил' or 'выключил')..' чекер людей из списка отстрела', 0xCCCCCC)
                end
                if listitem == 6 then
                    ooc_only = not ooc_only
                    if ooc_only == false then mainIni.config.ooc_only = 0 else mainIni.config.ooc_only = 1 end
                    sampAddChatMessage('[ Мысли ]: Я '..(ooc_only and 'включил' or 'выключил').." OOC-чат по умолчанию "..(ooc_only and "[ Чтобы писать в IC чат, поставьте '>' перед сообщением ]" or ''), 0xCCCCCC)
                end
                if listitem == 7 then
                    search_other_servers = not search_other_servers
                    if search_other_servers == false then mainIni.config.search_other_servers = 0 else mainIni.config.search_other_servers = 1 end
                    sampAddChatMessage('[ Мысли ]: Теперь поиск '..(search_other_servers and 'будет' or 'не будет')..' работать на сторонних серверах', 0xCCCCCC)
                end
                if listitem == 8 then
                    sampAddChatMessage('[ Hitman Helper ]: После выполненного контракта скрипт автоматически нажимает сочетание клавиш [ Shift + M ]', 0xCCCCCC)
                    sampAddChatMessage('[ Hitman Helper ]: Вам необходимо выбрать это сочетание клавиш в любой программе для сохранения скриншотов', 0xCCCCCC)
                    sampAddChatMessage('[ Hitman Helper ]: Нажмите F4, чтобы скрипт нажал сочетание клавиш [ Shift + M ], либо F5, чтобы выйти из этого режима', 0xCCCCCC)
                    test_as = true
                    openMenu = false
                end
                if openMenu then scriptMenu() end
            end
        end

        if test_as then
            if isKeyJustPressed(0x73) then
                screenct()
            end
            if isKeyJustPressed(0x74) then
                sampAddChatMessage('[ Hitman Helper ]: Вы вышли из режима тестирования авто-скриншота', 0xCCCCCC)
                test_as = false
            end
        end

        lua_thread.create(function ()
            if update then
                local script_url = 'https://www.dropbox.com/s/5ub84kcrtoq8mhz/moreveal_hh.lua?dl=1'
                downloadUrlToFile(script_url, thisScript().path, function(id, status)
                    if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                        sampAddChatMessage('[ Hitman Helper ]: Обновление загружено. Новая версия: '..text_new_version, 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: Начинаю перезапуск скрипта. Ожидай, это не займет много времени.', 0xCCCCCC)
                        thisScript():reload()
                    end 
                end)
                update = false
            end
        end)

        if c_pfd_hp then
            lua_thread.create(function ()
                wait(300)
                if sampGetPlayerHealth(pfd) <= 0 then
                    if autoscreen then screenct() end
                    pfd = nil
                end
            end)
            c_pfd_hp = false
        end

        if isKeyDown(0x10) and isKeyDown(0x4D) or isKeyDown(0x77) or isKeyDown(0x74) then
            pressed_screen = true
        else
            pressed_screen = false
        end

        if not pressed_screen then
            scriptBody()
        else
            if not without_screen then
                scriptBody()
            end
        end
    end
end

function sampev.onSendGiveDamage(playerid, damage, weapon, bodypart)
    if playerid == pfd then
        c_pfd_hp = true
    end
end

function sampev.onSendCommand(cmd)
    if cmd:find('/setcolor%s*$') then
        local dialog_text = [[
{0066FF}LSPD [1]
{6666FF}FBI [2]
{F4A460}Национальная гвардия [3]
{FF6666}Министерство здравоохранения [4]
{CCCC00}La Cosa Nostra [5]
{990000}Yakuza Mafia [6]
{FFFFFF}Правительство [7]
{CCCCCC}Hitman's Agency [8]
{FFCC66}CNN [9]
{003366}Triada Magia [10]
{122FAA}SFPD [11]
{333333}Russian Mafia [12]
{00CC00}Grove Street [13]
{9900CC}Ballas [14]
{FFCC33}Vagos [15]
{00FFFF}Aztecas [16]
{499092}Rifa Gang [17]
{663300}Arabian Mafia [18]
{CDC9A4}Street Racers [19]
{90696A}Bikers [20]
{4B6894}LVPD [21]
{191970}SWAT [22]
{333300}Призывник [23]
{00CC99}ВВС [24]
{339966}ВМФ [25]
]]
        sampShowDialog(D_SETCOLOR, 'Выбор цвета', dialog_text, 'Ок', 'Отмена', DIALOG_STYLE_LIST)

        return false
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
    if dialogid == 8999 then
        if openContractas then
            for line in text:gmatch("[^\r\n]+") do
                if line:find('%$') then
                    local id, sum = line:match('%[(%d+)%].+%{99ff66}(%d+)%$')
                    table.insert(c_ids, id, sum)
                end
            end
            openContractas = false
            return false
        end
        local count = 0
        local result
        for line in text:gmatch('[^\r\n]+') do
            line = line:gsub('ff9000', string.format('%06X', bit.band(sampGetPlayerColor(line:match('%[(%d+)%]')),  0xFFFFFF)))
            if count > 0 then
                result = result..line..'\n'
            else
                result = line..'\n'
            end
            count = count + 1
        end
        return {dialogid, style, title, b1, b2, result}
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
                sampAddChatMessage('[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {cccccc}[ {800000}'..k..' {cccccc}] в зоне стрима. Стоимость - {800000}'..v..'${ffffff}.', 0xCCCCCC)
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
                sampAddChatMessage('[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {cccccc}[ {800000}'..k..' {cccccc}] покинул зону стрима.', 0xCCCCCC)
            end
        end
    end
end

function sampev.onSendChat(msg)
    if ooc_only then
        if not msg:find('^>') then
            sampSendChat('/b '..msg)
            return false
        else
            local msg = msg:gsub('>', '')
            return {msg}
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

function sampGetPlayerIdByNickname(nick)
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) then
            if sampGetPlayerNickname(i) == nick then
                id = i
                break
            end
        end
    end

    if id ~= nil then 
        return id
    else 
        return false
    end
end

function goKeyPressed(id)
    lua_thread.create(function ()
        setVirtualKeyDown(id, true)
        wait(100)
        setVirtualKeyDown(id, false)
    end)
end

function scriptMenu()
    sampShowDialog(D_SETTING, '{ffffff}Настройка {cccccc}Hitman Helper {ffffff}| Версия: '..text_version, 'Название\tЗначение\n{cccccc}О скрипте\t'..'Версия: '..text_version..'\n{ffffff}Авто-скриншот выполненного контракта\t'..(autoscreen and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}Контракты в зоне стрима\t'..(cstream and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}Метка на голове игрока, занесенного в PFD\t'..(metka and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}Скрывать при скриншоте\t'..(without_screen and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}Чекер отстрела\t'..(otstrel and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}OOC-чат по умолчанию\t'..(ooc_only and '{008000}Да' or '{ff0000}Нет')..'\n{ffffff}Поиск игрока, занесенного в PFD, на сторонних серверах\t'..(search_other_servers and '{008000}Да' or '{ff0000}Нет')..'\nТест авто-скриншота', 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function screenct()
    goKeyPressed(0x10) -- Shift
    goKeyPressed(0x4D) -- M
    sampAddChatMessage('[ Мысли ]: Скриншот выполненного контракта выполнен', 0xCCCCCC)
end

function scriptBody()
    local sw, sh = getScreenResolution()

    if otstrel then
        lua_thread.create(function ()
            if os.clock() - time_otstrel >= 10 then
                otstrel_online = {}
                for k, v in pairs(otstrel_list) do
                    if sampGetPlayerIdByNickname(v) ~= nil then
                        table.insert(otstrel_online, v)
                    end
                end
                time_otstrel = os.clock()
            end
        end)
    end

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
            if os.clock() - time_find >= 4 then
                if thispp or search_other_servers then
                    sampSendChat('/find '..pfd)
                end
                time_find = os.clock()
            end
        end)

        if not isPauseMenuActive() and sampIsPlayerConnected(tonumber(pfd)) then
            renderFontDrawText(font, '{ff0000}ПОИСК: {ffffff}'..sampGetPlayerNickname(pfd)..' [ '..pfd..' ]', sw * 0.75, sh * 0.91, 0xFFFFFFFF, 1)
            
            if metka then
                local result, handle = sampGetCharHandleBySampPlayerId(pfd)

                if result and doesCharExist(handle) and isCharOnScreen(handle) then
                    local px, py, pz = getActiveCameraCoordinates()
                    local tpx, tpy, tpz = getBodyPartCoordinates(5, handle)

                    local result = processLineOfSight(px, py, pz, tpx, tpy, tpz, true, false, false, true, false, true, false, false)
                    if not result then
                        local wposX, wposY = convert3DCoordsToScreen(tpx, tpy, tpz)

                        renderDrawLine(wposX - 3, wposY - 3, wposX + 3, wposY + 3, 1, 0xFFFFFFFF)
                        renderDrawLine(wposX - 3, wposY + 3, wposX + 3, wposY - 3, 1, 0xFFFFFFFF)
                    end
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

function onScriptTerminate(script, quit)
    if script == thisScript() then
        inicfg.save(mainIni, config_path)
    end
end
