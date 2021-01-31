local sampev = require 'samp.events'
require 'lib.sampfuncs'
require 'lib.moonloader'
local inicfg = require 'inicfg'
local vkeys = require 'vkeys'
local socket = require 'luasocket.socket'

local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local memory = require 'memory'
local ffi = require "ffi"
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local dlstatus = require('moonloader').download_status

local cfd -- ID жертвы
local c_ids = {} -- люди из /contractas
local anonymizer_names = {} -- ники в анонимайзере
local weapons_list = {} -- названия оружий
local macrosses_list = {} -- макросы
local lastdamage = {} -- информация о последнем попадании

sw, sh = getScreenResolution()
defaultIni = {
    config = {
        cstream = false,
        autoscreen = false,
        automobile = false,
        autofill = false,
        customid = false,
        s_speed = false,
        customctstr = false,
        macrosses = true,
        metka = false,
        autofind = true,
        without_screen = false,
        otstrel = false,
        ooc_only = false,
        search_other_servers = false,
        onlypp = false,
        autoupdate = false,
        anonymizer = false,
        shud = false,
        hud = true,
        screen_type = true,
        points_ammo = 1,
        points_contracts = 2,
        points_otstrel = 3.5,
        points_otstrel_squad = 3
    },
    
    temp = {
        nametag = true,
        fakenick = false,
        accept_ct = 'Nick_Name',
        last_ct = 'Nick_Name'
    },

    otstrel_list = {
        nil,
    },

    stats = {
        nil,
    },

    chat = {
        misli = true,
        p_adm = true,
        frac = true,
        fam = true,
        ads = true,
        invites = true,
        gos_ads = true,
        a_adm = true,
        news_cnn = true,
        news_sekta = true,
        hit_ads = true,
        propose = true
    },

    weapons = {
        [1] = 'Fist',
        [2] = 'Brass Knuckles',
        [3] = 'Golf Club',
        [4] = 'Nitestick',
        [5] = 'Knife',
        [6] = 'Baseball Bat',
        [7] = 'Shovel',
        [8] = 'Pool Cue',
        [9] = 'Kantana',
        [10] = 'Chainsaw',
        [11] = 'Purple Dildo',
        [12] = 'Short Vibrator',
        [13] = 'Long Vibrator',
        [14] = 'White Dildo',
        [15] = 'Flowers',
        [16] = 'Cane',
        [17] = 'Grenade',
        [18] = 'Tear Gas',
        [19] = 'Molotov Cocktail',
        [22] = '9mm Pistol',
        [23] = 'Silenced 9mm',
        [24] = 'Desert Eagle',
        [25] = 'Shotgun',
        [26] = 'Sawn-off Shotgun',
        [27] = 'Combat Shotgun',
        [28] = 'Micro Uzi',
        [29] = 'MP5',
        [30] = 'AK-47',
        [31] = 'M4',
        [32] = 'Tec-9',
        [33] = 'Country Rifle',
        [34] = 'Sniper Rifle',
        [35] = 'RPG',
        [36] = 'HS Rocket',
        [37] = 'Flamethrower',
        [38] = 'Minigun',
        [39] = 'Satchel Charge',
        [40] = 'Detonator',
        [41] = 'Spraycan',
        [42] = 'Fire Extinguisher',
        [43] = 'Camera',
        [44] = 'Night Vision',
        [45] = 'Thermal Goggles',
        [46] = 'Parachute'      
    },

    hud = {
        xpos = sw - 359,
        ypos = sh - 48
    },

    macrosses = {
        knock = 90 ..' + '.. 221,
        boot = 90 ..' + '.. 219,
        members = 90 ..' + '.. 186,
        contracts = 90 ..' + '.. 222,
        cancel = 90 .. ' + '.. 190,
        getct = 190 .. ' + '.. 191,
        myc = 90 .. ' + '.. 188,
        invis = 88 .. ' + '.. 90,
        otstrel = 90 .. ' + '.. 76,
        admins = 90 .. ' + '.. 75,
        setting = 35,
        screen = 119,
        find = 88 .. ' + '.. 87,
        takect = 75,
        tempname_otstrel = 90 .. ' + ' .. 49,
        tempname_contracts = 90 .. ' + ' .. 50,
        tempname_trainings = 90 .. ' + ' .. 51
    },

    tempname = {
        otstrel = 'Nick_Name',
        contracts = 'Nick_Name',
        trainings = 'Nick_Name'
    }
}

local otstrel_list = {} -- люди, состоящие в списке отстрела
local otstrel_online = {} -- люди, состоящие в списке отстрела онлайн
local car = {
    engine = false,
    light = false,
    lock = false,
    sport = false,
    health = 1000,
    fuel = 100,
    speed = 0
}

local autogoc_price = 0
local carmenu_count = 0
local nkeys_bind = {} -- хранит id клавиш при изменении макроса

local anonymizer_path = getWorkingDirectory()..'/config/Hitman Helper/anonymizer.txt'
local otstrel_path = getWorkingDirectory()..'/config/Hitman Helper/otstrel.txt'

local D_SETCOLOR = 7130 -- диалог для выбора цвета
local D_SETTING = 7131 -- диалог для настройки скрипта
local D_INVALID = 7132 -- диалог, использующийся для вывода информации
local D_CSETTING = 7133 -- диалог для настройки чата
local D_MSETTING = 7134 -- диалог для настройки макросов

local D_ASETTING_ONE = 7135 -- диалог для настройки анонимайзера (1)
local D_ASETTING_TWO = 7136 -- диалог для настройки анонимайзера (2)
local D_ASETTING_THREE = 7137 -- диалог для настройки анонимайзера (3)

local D_GSETTING_ONE = 7138 -- диалог для настройки названия оружий (1)
local D_GSETTING_TWO = 7139 -- диалог для настройки названия оружий (2)

local D_TNSETTING_ONE = 7140 -- диалог для выбора временного никнейма (1)
local D_TNSETTING_TWO = 7141 -- диалог для выбора временного никнейма (2)
local D_TNSETTING_THREE = 7142 -- диалог для выбора временного никнейма (3)

local D_AGENTSTATS_MAIN = 7143 -- диалог для просмотра работоспособности агента (1)
local D_AGENTSTATS_POINTS = 7144 -- диалог для просмотра работоспособности агента (2)
local D_AGENTSTATS_INFO = 7145 -- диалог для просмотра работоспособности агента (3)

local script_version = 43 --[[ Используется для автообновления, во избежание проблем 
с получением новых обновлений, рекомендуется не изменять. В случае их появления измените значение на "1" ]]
local text_version = '1.7' -- версия для вывода в окне настроек, не изменять

local update_url = 'https://raw.githubusercontent.com/moreveal/moreveal_hh/main/script/update.cfg'

local time_find = os.clock() -- таймер /find
local time_stream = os.clock() -- таймер чекера контрактов в зоне стрима
local time_otstrel = os.clock() -- таймер чекера людей из списка отстрела

font = renderCreateFont('Bahnschrift Bold', 10) -- подключение шрифта для большей части надписей
font_hud = renderCreateFont("BigNoodleTitlingCyr", 16) -- подключение шрифта для остального текста

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    if not doesDirectoryExist(getWorkingDirectory()..'/config/Hitman Helper') then createDirectory(getWorkingDirectory()..'/config/Hitman Helper') end
    if not doesFileExist(getWorkingDirectory()..'/config/Hitman Helper/hh_config.ini') then io.open(getWorkingDirectory()..'/config/Hitman Helper/hh_config.ini', 'w+'):close() end

    config_path = getWorkingDirectory()..'/config/Hitman Helper/hh_config.ini'
    weaponslist_path = getWorkingDirectory()..'/config/Hitman Helper/weapons_list.txt'
    mainIni = inicfg.load(defaultIni, config_path)

    if not doesFileExist(getWorkingDirectory()..'/lib/requests.lua') then
        downloadUrlToFile('https://raw.githubusercontent.com/moreveal/moreveal_hh/main/lib/requests/requests.lua', getWorkingDirectory()..'/lib/requests.lua', function(id, status)  end)
        wait(1000)
    elseif not doesFileExist(getWorkingDirectory()..'/lib/screenshot.lua') or not doesFileExist(getGameDirectory()..'/Screenshot.asi') then
        downloadUrlToFile('https://raw.githubusercontent.com/moreveal/moreveal_hh/main/lib/screenshot/screenshot.lua', getWorkingDirectory()..'/lib/screenshot.lua', function(id, status) end)
        downloadUrlToFile('https://github.com/moreveal/moreveal_hh/raw/main/lib/screenshot/Screenshot.asi', getGameDirectory()..'/Screenshot.asi', function(id, status) end)
        wait(3000)
    end
    requests = require 'requests'
    screenshot = require 'screenshot'

    local ip = select(1, sampGetCurrentServerAddress())..':'..select(2, sampGetCurrentServerAddress())
    if ip ~= '176.32.37.62:7777' then
        mainIni.temp.fakenick = false 
        mainIni.temp.nametag = true
        if mainIni.config.onlypp then
            thisScript():unload()
        end
    else
        thispp = true
    end

    for k, v in pairs(mainIni['weapons']) do weapons_list[k] = v end

    for k, v in pairs(mainIni.macrosses) do
        macrosses_list[k] = {}
        for key in tostring(v):gmatch('[^%s?%+]+') do
            table.insert(macrosses_list[k], tonumber(key))
        end
    end

    local f = (not doesFileExist(anonymizer_path) and io.open(anonymizer_path, 'w+') or io.open(anonymizer_path, 'r+'))
    for line in f:lines() do
        table.insert(anonymizer_names, u8:decode(line))
    end
    f:close()

    repeat wait(0) until sampIsLocalPlayerSpawned() and isCharOnScreen(PLAYER_PED)

    if mainIni.config.anonymizer then
        for k, v in pairs(anonymizer_names) do
            local name = v:match('(.+) =')
            local mask = v:match('= (.+)')
            if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == name or sampGetPlayerIdByNickname(name) ~= -1 then
                changeName(name, mask)
            end
        end
    else
        for k, v in pairs(anonymizer_names) do
            local name = v:match('(.+) =')
            local mask = v:match('= (.+)')
            if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == name or sampGetPlayerIdByNickname(mask) ~= -1 then
                changeName(mask, name)
            end
        end
    end

    local response = requests.get(update_url)
    new_version, text_new_version = response.text:match('(%d+) | (.+)')
    if tonumber(new_version) > script_version then updateScript() update = true end
    changelog = u8:decode(requests.get('https://raw.githubusercontent.com/moreveal/moreveal_hh/main/script/last_news.txt').text)

    lua_thread.create(function ()
        if not update then
            local c_one, c_two = 0, 16777215
            local name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
            local lenght = renderGetFontDrawTextLength(font, "Settings: " .. layoutMacrossString('setting')) > renderGetFontDrawTextLength(font, "Hello, " .. name:gsub("_", " ")) + 80 and renderGetFontDrawTextLength(font, "Settings: " .. layoutMacrossString('setting')) or renderGetFontDrawTextLength(font, "Hello, " .. name:gsub("_", " ")) + 80
            local w_one, w_two = renderGetFontDrawHeight(font) + 20, renderGetFontDrawHeight(font)
            local timer = os.clock()

            while os.clock() - timer < 10 do
                wait(0)

                if os.clock() - timer < 5 then
                    if c_one < 2852126720.0 then
                        c_one = c_one + 83886080
                    elseif c_two < 4278190080.0 then
                        c_two = c_two + 16777216
                    end
                elseif c_one < c_two then
                    c_two = c_two - 167772160
                else
                    if c_one - 16777216 > 0 then
                        c_one = c_one - 16777216
                    end

                    if c_two - 16777216 > 0 then
                        c_two = c_two - 16777216
                    end
                end
                
                renderDrawBox(sw / 2 - lenght / 2, sh / 2 - w_one / 2, lenght, w_one, c_one)
                renderDrawBox(sw / 2 - lenght / 2, sh / 2 + renderGetFontDrawHeight(font) / 2 + renderGetFontDrawHeight(font) / 2 + 4, lenght, renderGetFontDrawHeight(font), c_one)
                renderFontDrawText(font, "Hello, " .. name:gsub("_", " "), sw / 2 - renderGetFontDrawTextLength(font, "Hello, " .. name:gsub("_", " ")) / 2, sh / 2 - renderGetFontDrawHeight(font) / 2, c_two)
                renderFontDrawText(font, "Settings: " .. layoutMacrossString('setting'), sw / 2 - renderGetFontDrawTextLength(font, "Settings: " .. layoutMacrossString('setting')) / 2, sh / 2 + renderGetFontDrawHeight(font) / 2 + renderGetFontDrawHeight(font) / 2 + 4, c_two)
            end
        end
    end)
    loadOtstrelList(1)

    id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    if thispp then
        openStats = true
        sampSendChat('/stats')
    end

    lua_thread.create(scriptBody)
    lua_thread.create(dialogFunc)
    lua_thread.create(macrossesFunc)

    sampRegisterChatCommand('autogoc', function(price)
        if #price ~= 0 and not price:find('%D') then
            autogoc_price = tonumber(price)
            if autogoc_price ~= 0 then
                sampAddChatMessage('[ Мысли ]: Я автоматически возьму контракт на сумму от {3caa3c}'..setpoint(price)..'$', 0xCCCCCC)
            else
                sampAddChatMessage('[ Мысли ]: Я отключил автоматическое взятие контракта', 0xCCCCCC)
            end
        else
            sampAddChatMessage('[ Мысли ]: Автоматическое взятие контракта: {FF6347}/autogoc [сумма]', 0xCCCCCC)
        end
    end)

    sampRegisterChatCommand('shud', function(arg)
        mainIni.config.shud = not mainIni.config.shud
        sampAddChatMessage('[ Hitman Helper ]: Статус отображения стандартного худа GTA San Andreas: {FF6347}'..(mainIni.config.shud and 'отображается' or 'не отображается'), 0xCCCCCC)
    end)

    sampRegisterChatCommand('tempname', function(arg)
        sampShowDialog(D_TNSETTING_ONE, ' ', 'Тип\tВременный никнейм\n{FF6347}Отстрел\t{FFFFFF}'..mainIni.tempname.otstrel..'\n{FF6347}Контракты\t{FFFFFF}'..mainIni.tempname.contracts..'\n{FF6347}Тренировки\t{FFFFFF}'..mainIni.tempname.trainings, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
    end)

    sampRegisterChatCommand('cfd', function(arg)
        if cfd == nil then
            if arg:find('%D') or #arg == 0 then
                sampAddChatMessage('[ Мысли ]: Начало преследования: {FF6347}/cfd [id]', 0xCCCCCC)
            else
                if sampIsPlayerConnected(tonumber(arg)) then
                    cfd = tonumber(arg)
                    --sampAddChatMessage('[ Мысли ]: Преследование за '..sampGetPlayerNickname(cfd)..' ['..cfd..'] запущено.', 0xCCCCCC)
                else
                    sampAddChatMessage('[ Мысли ]: Кажется, этого игрока нет в сети', 0xCCCCCC)
                end
            end
        else
            cfd = nil
            --sampAddChatMessage('[ Мысли ]: Преследование прекращено.', 0xCCCCCC)
        end
    end)

    sampRegisterChatCommand('otstrel_list', openOtstrelList)

    sampRegisterChatCommand('zask', function(id)
        if not id:find('%D') and #id ~= 0 then
            sampSendChat('/f Я, Агент №'..acc_id..', готов приступить к выполнению контракта №'..id)
        else
            sampAddChatMessage('[ Мысли ]: Запрос контракта: {FF6347}/zask [id]', 0xCCCCCC)
        end
    end)
    
    while true do
        wait(0)

        if setting_bind ~= nil then
            renderFontDrawText(font, "Изменение макроса. Поочередно нажимайте клавиши:", sw / 2 - renderGetFontDrawTextLength(font, "Изменение макроса. Поочерёдно нажимайте клавиши:") / 2, sh / 2, 0xFFFFFFFF, true)
            renderFontDrawText(font, "Максимум - 3. Backspace - стереть. Enter - применить.", sw / 2 - renderGetFontDrawTextLength(font, "Максимум - 3. Backspace - стереть. Enter - применить.") / 2, sh / 2 + 20, 0xFFFFFFFF, true)
            
            local sh_plus = 40

            for i = 1, #nkeys_bind, 1 do
                renderFontDrawText(font, i .. " клавиша: " .. vkeys.id_to_name(nkeys_bind[i]), sw / 2 - renderGetFontDrawTextLength(font, i .. " клавиша: " .. vkeys.id_to_name(nkeys_bind[i])) / 2, sh / 2 + sh_plus, 0xFFFFFFFF, true)
                sh_plus = sh_plus + 20
            end
        end
        
        if hud_move then
            showCursor(true, true)
            mainIni.hud.xpos, mainIni.hud.ypos = getCursorPos()
            if isKeyJustPressed(0x01) then
                showCursor(false, false)
                hud_move = false
            end
            if isKeyJustPressed(0x02) then
                mainIni.hud.xpos = sw - 359
                mainIni.hud.ypos = sh - 48
                showCursor(false, false)
                hud_move = false
            end
        end

        if test_as then
            if isKeyJustPressed(0x73) then -- F4
                screenct()
            end
            if isKeyJustPressed(0x74) then -- F5
                sampAddChatMessage('[ Hitman Helper ]: Вы вышли из режима тестирования авто-скриншота', 0xCCCCCC)
                test_as = false
            end
        end
    end
end

function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    local vec = ffi.new("float[3]")
    getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
    return vec[0], vec[1], vec[2]
end

function updateScript()
    if mainIni.config.autoupdate then
        downloadUrlToFile('https://raw.githubusercontent.com/moreveal/moreveal_hh/main/script/h_helper.lua', thisScript().path, function(id, status)
            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                sampAddChatMessage('[ Hitman Helper ]: Обновление загружено. Новая версия: '..text_new_version, 0xCCCCCC)
                sampAddChatMessage('[ Hitman Helper ]: Начинаю перезапуск скрипта. Ожидай, это не займет много времени.', 0xCCCCCC)
                sampAddChatMessage('[ Hitman Helper ]: Если скрипт не запустился - скачай его вручную, ссылка оставлена в лог-файле [moonloader/moonloader.log]', 0xCCCCCC)
                print('Ссылка на актуальную версию: raw.githubusercontent.com/moreveal_hh/main/script/h_helper.lua')
                thisScript():reload()
            end 
        end)
        update = false
    else
        sampAddChatMessage('[ Hitman Helper ]: Найдено новое обновление. Версия: '..text_new_version, 0xCCCCCC)
        sampAddChatMessage('[ Hitman Helper ]: Рекомендуется включить автообновление в скрипте.', 0xCCCCCC)
    end
end

function openOtstrelList()
    if mainIni.config.otstrel then
        otstrel_online = {}
        for k, v in pairs(otstrel_list) do
            local id = sampGetPlayerIdByNickname(v.name)
            if id ~= -1 then
                table.insert(otstrel_online, {id = id, name = sampGetPlayerNickname(id)})
            end
        end

        local dialog_text
        if #otstrel_online ~= 0 then
            for k = 1, table.maxn(otstrel_online) do
                local id = otstrel_online[k]['id']
                local name = otstrel_online[k]['name']
                local status
                local color = string.format('%06X', bit.band(sampGetPlayerColor(id),  0xFFFFFF))
                for k, v in pairs(otstrel_list) do
                    if v.name == name then
                        if v.time ~= nil then
                            local cooldown = os.time() - v.time >= 600
                            if cooldown then 
                                for s, t in pairs(mainIni.otstrel_list) do
                                    if s == v.name then
                                        mainIni.otstrel_list[s] = nil
                                    end
                                end
                                v.time = nil
                            end
                            status = (cooldown and '{008000}V' or '{ff0000}X')
                        else
                            status = '{008000}V'
                        end
                        break
                    end
                end
                dialog_text = (dialog_text == nil and 'Игрок\tСтатус\n'..'{'..color..'}'..name..' ['..id..']\t'..status..'\n' or dialog_text..'{'..color..'}'..name..' ['..id..']\t'..status..'\n')
            end
            sampShowDialog(D_INVALID, '{ffffff}Люди из списка отстрела {008000}Online   {ffffff}['..#otstrel_online..']', dialog_text, '*', nil, DIALOG_STYLE_TABLIST_HEADERS)
        else
            sampAddChatMessage('[ Отстрел ]: К сожалению, этот список пуст :(', 0xCCCCCC)
        end
    else
        sampAddChatMessage('[ Мысли ]: Чекер людей из списка отстрела выключен. Сперва я должен его включить.', 0xCCCCCC)
    end
end

function sampGetNearestPlayer()
	for i = 0, sampGetMaxPlayerId(true) do
		if sampIsPlayerConnected(i) then
			playerStreamed, playerHandle = sampGetCharHandleBySampPlayerId(i)

			if playerStreamed then
				local vhandle, phandle = storeClosestEntities(PLAYER_PED)
				local result, id = sampGetPlayerIdByCharHandle(phandle)

				return id
			end
		end
	end

	return -1
end

function loadOtstrelList(type)
    --[[local f = io.open(otstrel_path, 'r+')
    if f == nil then
        f = io.open(otstrel_path, 'w') 
    else
        for line in f:lines() do
            local fdate, ldate, name
            if not line:find('%> (.-) %- .+') then
                fdate, ldate, name = line:match('%[(.-)%-(.-)%] (.-) %-')
            else
                fdate, ldate, name = line:match('%[(.-)%-(.-)%] .+%> (.-) %-')
            end
            --local fday, fmonth, fyear = fdate:match('(%d+)%.(%d+)%.(%d+)')
            local lday, lmonth, lyear = ldate:match('(%d+)%.(%d+)%.(%d+)')
            --fdate = os.time({year = fyear, month = fmonth, day = fday})
            ldate = os.time({year = lyear, month = lmonth, day = lday})
            if ldate >= os.time() then
                table.insert(otstrel_list, {name = name})
                sampAddChatMessage(name, 0xCCCCCC)
            end
        end
    end
    f:close()]]

    otstrel_list = {}
    --[[local response = requests.get('https://raw.githubusercontent.com/moreveal/moreveal_hh/main/script/otstrel_list')
    for name in response.text:gmatch('[^\r\n]+') do table.insert(otstrel_list, {name = name}) end]]
    if doesFileExist(otstrel_path) then
        local f = io.open(otstrel_path, 'r+')
        for name in f:lines() do table.insert(otstrel_list, {name = name}) end
        f:close()
    end

    if type == 1 and mainIni.config.otstrel then
        local count, count_online = 0, 0
        for k, v in pairs(otstrel_list) do
            count = count + 1
            for s, t in pairs(mainIni.otstrel_list) do 
                if s == v.name then 
                    v.time = t
                    break 
                end 
            end 

            local id = sampGetPlayerIdByNickname(v.name)
            if id ~= -1 then
                count_online = count_online + 1
            end
        end
        sampAddChatMessage('[ Отстрел ]: Всего в списке: '..count..'. В сети найдено: '..count_online..'.', 0xCCCCCC)
    end
end

function isKeysDown(key, state)
	if state == nil then
		state = false
	end

	if key[1] == nil then
		return false
	end

	local result = false
	slot4 = #key < 2 and tonumber(key[1]) or tonumber(key[2])

	if #key < 2 then
		if not isKeyDown(VK_RMENU) and not isKeyDown(VK_LMENU) and not isKeyDown(VK_LSHIFT) and not isKeyDown(VK_RSHIFT) and not isKeyDown(VK_LCONTROL) and not isKeyDown(VK_RCONTROL) then
			if wasKeyPressed(slot4) and not state then
				result = true
			elseif isKeyDown(slot4) and state then
				result = true
			end
		end
	elseif isKeyDown(tonumber(key[1])) and not wasKeyReleased(tonumber(key[1])) then
		if wasKeyPressed(slot4) and not state then
			result = true
		elseif isKeyDown(slot4) and state then
			result = true
		end
	end

	if nextLockKey == key then
		if state and not wasKeyReleased(slot4) then
			result = false
		else
			result = false
			nextLockKey = ""
		end
	end

	return result
end

function sampev.onDisplayGameText(style, time, text)
    if style == 6 then
        if cfd ~= nil and mainIni.config.autofind then 
            return false
        end
    end
end

function sampev.onPlayerJoin(playerid, color, isnpc, nick)
    if mainIni.config.otstrel then
        for k, v in pairs(otstrel_list) do
            if nick == v.name then
                for s, t in pairs(mainIni.otstrel_list) do
                    if s == nick then
                        v.time = t
                        break
                    end 
                end
                sampAddChatMessage('[ Отстрел ]: '..nick..' ['..playerid..'] зашел на сервер.', 0xCCCCCC)
                table.insert(otstrel_online, {id = playerid, name = nick})
                break
            end
        end
    end
    if mainIni.config.anonymizer then
        for k, v in pairs(anonymizer_names) do
            local name = v:match('(.+) =')
            local mask = v:match('= (.+)')
            if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == name or sampGetPlayerIdByNickname(name) ~= -1 then
                changeName(name, mask)
            end
        end
    end
end

function sampev.onPlayerQuit(playerid, reason)
    if mainIni.config.otstrel then
        for k, v in pairs(otstrel_online) do
            if v.id == playerid then
                for s, t in pairs(otstrel_list) do
                    if s == sampGetPlayerNickname(playerid) and t ~= nil then
                        mainIni.otstrel_list[s] = t
                        break 
                    end
                end
                sampAddChatMessage('[ Отстрел ]: '..sampGetPlayerNickname(playerid)..' ['..playerid..'] покинул сервер.', 0xCCCCCC)
                otstrel_online[k] = nil
                break
            end
        end
    end
end

function showSettingMacrosses()
    local macrosses_array = {}
    for k, v in pairs(macrosses_list) do macrosses_array[k] = layoutMacrossString(k) end
    sampShowDialog(D_MSETTING, 'Макросы', 'Название\tЗначение\nБинды активны:\t'..(mainIni.config.macrosses and '{008000}V' or '{ff0000}X')..'\n{cccccc}Выставить значения по умолчанию\nВырубить ближайшего к себе игрока:\t'..macrosses_array.knock..'\nЗакинуть ранее вырубленного игрока в багажник:\t'..macrosses_array.boot..'\nОткрыть список членов организации онлайн:\t'..macrosses_array.members..'\nОткрыть список контрактов:\t'..macrosses_array.contracts..'\nОтказаться от контракта:\t'..macrosses_array.cancel..'\nВзять последний контракт из зоны прорисовки:\t'..macrosses_array.getct..'\nПосмотреть информацию о взятом контракте:\t'..macrosses_array.myc..'\nВключить невидимость на карте:\t'..macrosses_array.invis..'\nСписок отстрела онлайн:\t'..macrosses_array.otstrel..'\nАдминистрация онлайн:\t'..macrosses_array.admins..'\nНайти человека из [/cfd]:\t'..macrosses_array.find..'\nСочетание клавиш, нажимаемое при автоскриншоте:\t'..macrosses_array.screen..'\nВзять последний пришедший контракт:\t'..macrosses_array.takect..'\nВременный ник [Отстрел]:\t'..macrosses_array.tempname_otstrel..'\nВременный ник [Контракты]:\t'..macrosses_array.tempname_contracts..'\nВременный ник [Тренировки]:\t'..macrosses_array.tempname_trainings..'\nОткрыть меню настроек:\t'..macrosses_array.setting, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function layoutMacrossString(m_key)
    local string
    if type(m_key) == 'string' then
        for k, v in pairs(macrosses_list[m_key]) do
            local key = vkeys.id_to_name(v)
            string = (macrosses_list[m_key][k + 1] ~= nil and (string == nil and key..' + ' or string..key..' + ') or (string == nil and key or string..key))
        end
    elseif type(m_key) == 'table' then
        for k, v in pairs(m_key) do
            local key = vkeys.id_to_name(v)
            string = (m_key[k + 1] ~= nil and (string == nil and key..' + ' or string..key..' + ') or (string == nil and key or string..key))
        end
    end
    return (string == nil and 'Не назначено' or string)
end

function sampev.onSendGiveDamage(playerid, damage, weapon, bodypart)
    lastdamage.playerid, lastdamage.damage, lastdamage.weapon, lastdamage.bodypart = playerid, damage, {id = weapon, name = weapons_list[((weapon ~= nil and weapon <= 19) and weapon + 1 or weapon)]}, bodypart
    for k, v in pairs(otstrel_list) do
        local id = sampGetPlayerIdByNickname(v.name)
        if playerid == id and mainIni.temp.accept_ct ~= v.name then
            if sampGetPlayerHealth(playerid) - damage <= 0 or (weapon == 34 and bodypart == 9) and getCharArmour(select(2, sampGetCharHandleBySampPlayerId(playerid))) <= 0 then
                sampAddChatMessage('[ Отстрел ]: Я нанес урон (-'..tostring(damage):match('(%d+)%.')..'HP) игроку {800000}'..sampGetPlayerNickname(playerid)..'{cccccc} [ {800000}'..playerid..'{cccccc} ] с оружия '..lastdamage.weapon.name, 0xCCCCCC)
                table.insert(mainIni.stats, '2,0,'..os.time()..','..sampGetPlayerNickname(playerid)..','..select(1, math.modf(damage))..','..lastdamage.weapon.name..','..(otstrel_squad and 1 or 0))
                if mainIni.config.autoscreen then screenct() end
                if playerid == cfd then cfd = nil end
                if v.name == sampGetPlayerNickname(playerid) then
                    v.time = os.time()
                    break
                end
            end
            break
        end
    end
end

local lower, sub, char, upper = string.lower, string.sub, string.char, string.upper
local concat = table.concat

-- initialization table
local lu_rus, ul_rus = {}, {}
for i = 192, 223 do
    local A, a = char(i), char(i + 32)
    ul_rus[A] = a
    lu_rus[a] = A
end
local E, e = char(168), char(184)
ul_rus[E] = e
lu_rus[e] = E

function string.nlower(s)
    s = lower(s)
    local len, res = #s, {}
    for i = 1, len do
        local ch = sub(s, i, i)
        res[i] = ul_rus[ch] or ch
    end
    return concat(res)
end

function string.nupper(s)
    s = upper(s)
    local len, res = #s, {}
    for i = 1, len do
        local ch = sub(s, i, i)
        res[i] = lu_rus[ch] or ch
    end
    return concat(res)
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

if cmd:find('^/id ') then
        if mainIni.config.customid then
            local nick_colours = {
                [4281169149] = "/cvet 60",
                [4280767010] = "/cvet 33",
                [2868856064] = "/orangered",
                [4287636381] = "/cvet 41",
                [4287317267] = "/cvet 11",
                [2867919103] = "/aqua",
                [4284701443] = "/cvet 24",
                [2859441775] = "/col13",
                [2861666705] = "/col12",
                [2868880896] = "/col4",
                [4279782715] = "/cvet 81",
                [2868838400] = "Администратор",
                [4282957824] = "/cvet 63",
                [4279826207] = "/cvet 53",
                [4290589914] = "/cvet 21",
                [4293503791] = "/cvet 42",
                [4290199746] = "/cvet 69",
                [4291526355] = "/cvet 25",
                [4282993056] = "/cvet 12",
                [2868887755] = "/pink",
                [2858718701] = "/flblue",
                [4294907027] = "/cvet 7",
                [4284782061] = "/cvet 4",
                [4294937619] = "/cvet 0",
                [4283646081] = "/cvet 18",
                [2868864614] = "Медик",
                [4287867676] = "/cvet 50",
                [4282129421] = "/cvet 61",
                [2868838655] = "/col6",
                [4278550420] = "/cvet 44",
                [2868890675] = "Вагос",
                [4294956832] = "/cvet 10",
                [2860515072] = "/chartreuse",
                [2862179942] = "Байкер",
                [4290756802] = "Незалогинившийся",
                [2865548288] = "Макаронник",
                [4286265770] = "/cvet 30",
                [553648127]  = "/inv",
                [4290901996] = "/cvet 76",
                [4294583500] = "/cvet 85",
                [2853771632] = "/midnightblue",
                [4288309632] = "/cvet 38",
                [4290348313] = "/cvet 45",
                [4291785385] = "/cvet 95",
                [4286750151] = "/cvet 56",
                [4281768310] = "/cvet 52",
                [4286023833] = "/cvet 6",
                [4279228922] = "/cvet 16",
                [2864035253] = "/col11",
                [2868903810] = "/ivory",
                [4279367825] = "/cvet 29",
                [2868903680] = "/yellow",
                [2868838544] = "/col7",
                [2858824448] = "Араб",
                [2860317696] = "/lawngreen",
                [2861236363] = "/mediummagenta",
                [2865548441] = "Стритрейсер",
                [4294113363] = "/cvet 28",
                [2864882394] = "/purple",
                [2868896964] = "/bisque",
                [2862271794] = "/yellowgreen",
                [4288002800] = "/cvet 51",
                [4281896682] = "/cvet 46",
                [4294902015] = "/magenta",
                [4279424724] = "/cvet 62",
                [4280581147] = "/cvet 22",
                [2855508377] = "Рифа",
                [2854972612] = "Полицейский ЛВ",
                [4282981278] = "/cvet 55",
                [4280963554] = "/cvet 64",
                [2868892928] = "/col3",
                [4289024067] = "/cvet 48",
                [2862950954] = "/brown",
                [4293110802] = "/cvet 65",
                [4281321511] = "/cvet 67",
                [2865548492] = "/grey",
                [4282559733] = "/cvet 70",
                [2868870992] = "/coral",
                [4281326046] = "/cvet 71",
                [4294638449] = "/cvet 72",
                [4278571469] = "/cvet 73",
                [2852139878] = "Триадовец",
                [4291064253] = "/cvet 74",
                [2862153932] = "Баллас",
                [4291721710] = "/cvet 77",
                [4287870948] = "/cvet 79",
                [4291237375] = "/cvet 1",
                [4280332970] = "/cvet 2",
                [2863530239] = "/col10",
                [2862153728] = "Якудза",
                [4281472170] = "/cvet 80",
                [4288648284] = "/cvet 88",
                [4289612697] = "/cvet 82",
                [4281832442] = "/cvet 40",
                [2860548096] = "/olive",
                [2866549820] = "/brightred",
                [4283188078] = "/cvet 84",
                [4280481639] = "/cvet 36",
                [4291720894] = "/cvet 86",
                [2852192255] = "Ацтек",
                [4288695818] = "/cvet 87",
                [2856714240] = "/darkred",
                [4278490573] = "/cvet 19",
                [4292664893] = "/cvet 89",
                [4292227124] = "/cvet 37",
                [4278969458] = "/cvet 92",
                [4287245527] = "/cvet 93",
                [4284568258] = "/cvet 94",
                [2868863815] = "/tomato",
                [4284853739] = "/cvet 26",
                [4293959515] = "/cvet 34",
                [4293235512] = "/cvet 96",
                [2858837759] = "ФБР",
                [4293844013] = "/cvet 97",
                [4292396898] = "/cvet 98",
                [2853318570] = "Полицейский СФ",
                [4279566207] = "/cvet 14",
                [4293821166] = "/cvet 9",
                [4292613180] = "/cvet 3",
                [2852178944] = "Грувовец",
                [2865299200] = "/col1",
                [2857042096] = "/indigo",
                [4283689744] = "/cvet 31",
                [4279290309] = "/cvet 90",
                [4283140487] = "/cvet 54",
                [4291733215] = "/cvet 58",
                [2868877568] = "/orange",
                [4279099416] = "/cvet 49",
                [16777215] = "/inv",
                [4284226252] = "/cvet 27",
                [4278354257] = "/cvet 47",
                [2860515328] = "/maroon",
                [4283700093] = "/cvet 32",
                [4286466519] = "/cvet 83",
                [2855521535] = "/lightblue",
                [4290584306] = "/cvet 78",
                [2855456050] = "/limegreen",
                [4287906670] = "/cvet 75",
                [4292852021] = "/cvet 39",
                [4279295017] = "/cvet 17",
                [4294722216] = "/cvet 66",
                [4279536523] = "/cvet 13",
                [4285551181] = "/cvet 91",
                [2868890726] = "Репортер",
                [2868159584] = "/cvet 8",
                [4290569781] = "/cvet 57",
                [2855508326] = "Солдат ВМФ",
                [4289671155] = "/cvet 43",
                [2853568256] = "/col9",
                [4280341677] = "/cvet 59",
                [4293881064] = "/cvet 20",
                [4279906495] = "/cvet 68",
                [2863529775] = "/greenyellow",
                [2853237825] = "/lime",
                [2855482163] = "Русская Мафия",
                [4279012957] = "/cvet 23",
                [2852153087] = "Полицейский LS",
                [2852192153] = "/col8",
                [2860761023] = "/mediumaqua",
                [2855482112] = "Срочник",
                [4293977740] = "/cvet 5",
                [2863280947] = "/red",
                [2852179097] = "Солдат ВВС",
                [2852192127] = "/springgreen",
                [4282377820] = "/cvet 99",
                [2861367040] = "/col2",
                [4282190415] = "/cvet 35",
                [4283788079] = "/cvet 15",
                [2868903935] = "Правительство"
            }
            local players = {}
            local colour, target_lower
            local target = cmd:match('/id (.+)')
            target_lower = string.nlower(target)

            for k, v in pairs(nick_colours) do
                if string.nlower(v):find(target_lower) then
                    for i = 0, sampGetMaxPlayerId() do
                        if (sampGetPlayerColor(i) == k) and (sampIsPlayerConnected(i) or select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == i) then
                            table.insert(players, {name = sampGetPlayerNickname(i), id = i, colour = sampGetPlayerColor(i), level = sampGetPlayerScore(i), ping = sampGetPlayerPing(i)})
                        end
                    end
                end
            end
            if not target:find('%D') then
                local id = tonumber(target)
                if sampIsPlayerConnected(tonumber(target_lower)) or select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == tonumber(target_lower) then
                    table.insert(players, {name = sampGetPlayerNickname(id), id = id, colour = sampGetPlayerColor(id), level = sampGetPlayerScore(id), ping = sampGetPlayerPing(id)})
                end
            end
            
            for i = 0, sampGetMaxPlayerId() do
                if sampIsPlayerConnected(i) or select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == i then
                    if string.nlower(sampGetPlayerNickname(i)):find(target_lower) or sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))):find(target_lower) then
                        table.insert(players, {name = sampGetPlayerNickname(i), id = i, colour = sampGetPlayerColor(i), level = sampGetPlayerScore(i), ping = sampGetPlayerPing(i)})
                    end
                end
            end
            if table.maxn(players) ~= 0 then
                sampAddChatMessage('По запросу "'..target..'" найдены следующие игроки:', 0xCCCCCC)
                for i = 1, table.maxn(players) do
                    colour = (nick_colours[players[i]['colour']] == nil and 'Неизвестно' or nick_colours[players[i]['colour']])
                    local color = string.format('%06X', bit.band(sampGetPlayerColor(players[i]['id']),  0xFFFFFF))
                    sampAddChatMessage('[ '..colour..' ]: {'..color..'}'..players[i]['name']:gsub('_', ' ')..'{cccccc} ['..players[i]['id']..'] | Уровень: '..players[i]['level']..' | Пинг: '..players[i]['ping'], 0xCCCCCC)
                end
            else
                if not target:find('%D') then
                    if sampIsPlayerConnected(tonumber(target_lower)) or select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == tonumber(target_lower) then
                        target = tonumber(target_lower)
                        colour = (nick_colours[sampGetPlayerColor(target_lower)] == nil and 'Неизвестно' or nick_colours[sampGetPlayerColor(target)])
                        local color = string.format('%06X', bit.band(sampGetPlayerColor(target),  0xFFFFFF))
                        sampAddChatMessage('По запросу "'..target..'" найден следующий игрок:', 0xCCCCCC)
                        sampAddChatMessage('[ '..colour..' ]: {'..color..'}'..sampGetPlayerNickname(target):gsub('_', ' ')..'{cccccc} ['..target..'] | Уровень: '..sampGetPlayerScore(target)..' | Пинг: '..sampGetPlayerPing(target), 0xCCCCCC)
                    else
                        sampAddChatMessage('[ Мысли ]: По запросу "'..target..'" ничего не найдено..', 0xCCCCCC)
                    end
                else
                    sampAddChatMessage('[ Мысли ]: По запросу "'..target..'" ничего не найдено..', 0xCCCCCC)
                end
            end
            return false
        end
    end
end

function sampev.onShowDialog(dialogid, style, title, b1, b2, text)
    if text:find('{99ff66}Теперь все видят это имя:') then mainIni.temp.fakenick = true end
    if text:find('{99ff66}Вы вернули своё имя:') then mainIni.temp.fakenick = false end
    if dialogid == 66 then -- меню управления транспортом
        if openCarDoors then
            carmenu_count = carmenu_count + 1
            if carmenu_count == 1 then
                sampSendDialogResponse(dialogid, 1, 0, -1)
            else
                carmenu_count = 0
                openCarDoors = false
            end
            return false
        end
    end
    if dialogid == 586 then -- диалог меню агентства
        if incInvis then
            sampSendDialogResponse(dialogid, 1, 0, -1)
            incInvis = false
            return false
        end
    end
    if openStats and dialogid == 1500 then -- диалог статистики
        for line in text:gmatch('[^\r\n]+') do
            if line:find('Аккаунт №') then
                acc_id = line:match('Аккаунт №%s?%{......%}?%s?(%d+)')
                break
            end
        end
        openStats = false
        return false
    end
    if dialogid == 1700 then -- диалог ошибки (у вашего персонажа заняты руки и т.п.)
		if text:find('{FF6347}Вы не за рулём транспортного средства %[ Управление транспортом ALT %]') then
			goKeyPressed(0x12)
			openCarDoors = true
			return false
		end
    end
    if dialogid == 8999 then -- диалог списка заказов
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
        if result == nil then return sampAddChatMessage('[ Мысли ]: К сожалению, этот список пуст :(', 0xCCCCCC) end
        return {dialogid, style, title, b1, b2, result}
    end
    if mainIni.config.automobile then
        if dialogid == 365 then -- диалог при оплате счета мобильного телефона
            for line in text:gmatch('[^\r\n]+') do
                if line:find('%$') then
                    local pay = 2000 - line:match('(%d+)%$')
                    sampSendDialogResponse(dialogid, 1, nil, pay)
                    break
                end
            end
            return false
        end
    end
    if mainIni.config.autofill then
        if dialogid == 484 then -- диалог при заправке наземного транспорта
            for line in text:gmatch('[^\r\n]+') do
                if line:find('{99ff66}') then
                    local fill = line:match('Для полного бака вам требуется: (%d-) литров')
                    sampSendDialogResponse(dialogid, 1, nil, fill)
                end
            end
            return false
        end
        if dialogid == 764 then -- диалог при заправке воздушного транспорта
            if car.fuel ~= nil then
                sampSendDialogResponse(dialogid, 1, nil, 100 - car.fuel)
                return false
            end
        end
        if dialogid == 1990 then return false end -- юзлесс диалог :)
    end
    if mainIni.config.anonymizer then
        local result = text
        for k, v in pairs(anonymizer_names) do
            local name = v:match('(.+) =')
            local mask = v:match('= (.+)')
            if result:find(name) then
                result = result:gsub(name, mask)
            end
        end
        return {dialogid, style, title, b1, b2, result}
    end
end

function sampev.onServerMessage(color, text)
    if text:find('{0088ff}Привет, {FFFFFF}.-! Сегодня {ffcc66}') then mainIni.temp.fakenick = false mainIni.temp.nametag = true end
    if acc_id ~= nil then
        if text:find('{FF0000}<< {0088ff}Агент № '..acc_id..' выполнил контракт на .+, и получил {00BC12}%d+%$ {FF0000}>>') then
            local ct_name = text:match('выполнил контракт на (.+), и получил')
            if cfd == sampGetPlayerIdByNickname(ct_name) then cfd = nil end
            table.insert(mainIni.stats, '1,0,'..os.time()..','..ct_name..','..lastdamage.damage..','..lastdamage.weapon.name..','..text:match('и получил {00BC12}(%d+%$)'))
        end
        if text:find('{8B8B8B}Агент №'..acc_id..' {FF0000}принял контракт на: {8B8B8B}.-%[%d-%] {00AC31}Цена: %d-$ {cccccc}') then
            mainIni.temp.accept_ct = text:match('на: {8B8B8B}(.-)%[%d-%]')
        end
        if text:find('{FF0000}%*%* {8B8B8B}.- поручил {FF0000}Агенту №{8B8B8B}'..acc_id..' {FF0000}выполнить контракт на: {8B8B8B}.- %*%*') then
            mainIni.temp.accept_ct = text:match('на: {8B8B8B}(.-) %*%*')
        end
    end
    if text == "{0088ff}[Агентство]: {FFFFFF}Деньги перечислены на ваш банковский счёт" then
        sampAddChatMessage(text, 0x0088FF)
        if mainIni.config.autoscreen then screenct() end
        return false
    end
    if text:find('%[ Мысли %]%: Я положил ящик на склад {ff9000}%[ (.-) %]') then
        sampAddChatMessage(text, 0xCCCCCC)
        screenct()
        local ammo, n = text:match('Я положил ящик на склад {......}%[ (.+) | (%d+) ]')
        table.insert(mainIni.stats, '3,'..(ammo:find(',') and ammo:gsub(',','.') or ammo)..','..os.time()..','..n)
        return false
    end
    if text:find('{8B8B8B}Агентство: {FF0000}новый контракт {8B8B8B}.+{FF0000}, сумма {8B8B8B}%d+$ %[ /goc принять %]%[ /givec поручить %]') then
        local name = text:match('новый контракт {8B8B8B}(.-){')
        mainIni.temp.last_ct = name
        if autogoc_price ~= 0 then 
            if tonumber(text:match('сумма {......}(%d-)%$')) >= autogoc_price then
            sampSendChat('/goc '..sampGetPlayerIdByNickname(name))
            sampAddChatMessage('[ Мысли ]: Я автоматически взял контракт на '..name..' [ отключить /autogoc 0 ]', 0xCCCCCC)
            end
        end
        text = text:gsub(name, name..'['..sampGetPlayerIdByNickname(name)..']')
        return {color, text}
    end
    --[[if text:find('%[ Мысли %]: Я закрыла* своё лицо {FF6347}%[ Никнейм отключён %]') or text:find('%[ Мысли %]: Я открыла* своё лицо {99ff66}%[ Никнейм включён %]') then end]]
    if text == '[ Мысли ]: Я не могу видеть список потенциальных жертв' then
        return false
    end
    if text == '[ Мысли ]: Я не могу искать человека' then
        return false
    end

    if mainIni.config.anonymizer then
        for k, v in pairs(anonymizer_names) do
            local name = v:match('(.+) =')
            local mask = v:match('= (.+)')
            if text:find(name) then
                text = text:gsub(name, mask)
                return {color, text}
            end
        end
    end
    
    if mainIni.config.customctstr then
        if text:find('%*%* %{......%}Агент №(%d+) %{......%}принял контракт на: %{......%}.+%[(%d+)%] %{......%}Цена: (%d+)$ %{......%}%*%*') then
            local number, id, price = text:match('%*%* %{......%}Агент №(%d+) %{......%}принял контракт на: %{......%}.+%[(%d+)%] %{......%}Цена: (%d+)$ %{......%}%*%*')
            local colour = string.format('%06X', bit.band(sampGetPlayerColor(id),  0xFFFFFF))
            return {color, '{ffff00}Агент №'..number..' принял контракт на: {'..colour..'}'..sampGetPlayerNickname(id):gsub('_', ' ')..' ['..id..']{ffff00} | Цена: {008000}'..price..'$'}
        end

        if text:find('{FF0000}<< {0088ff}Агент № %d- выполнил контракт на .-, и получил {00BC12}%d-$ {FF0000}>>') then
            local number, nick, price = text:match('{FF0000}<< {0088ff}Агент № (%d-) выполнил контракт на (.-), и получил {00BC12}(%d-)$ {FF0000}>>')
            local id = sampGetPlayerIdByNickname(nick)
            local colour = string.format('%06X', bit.band(sampGetPlayerColor(id),  0xFFFFFF))
            return {color, '{ffff00}Агент №'..number..' выполнил контракт на {'..colour..'}'..nick:gsub('_', ' ')..'{ffff00}['..id..'], получив {008000}'..price..'$'}
        end

        if text:find('%{......%}%*%* %{......%}Агент №(%d+) %{......%}отказывается выполнять контракт на: %{......%}.+%[(%d+)%] %{......%}%*%*') then
            local number, id = text:match('%{......%}%*%* %{......%}Агент №(%d+) %{......%}отказывается выполнять контракт на: %{......%}.+%[(%d+)%] %{......%}%*%*')
            local colour = string.format('%06X', bit.band(sampGetPlayerColor(id),  0xFFFFFF))
            return {color, '{ffff00}Агент №'..number..' отказывается выполнять контракт на {'..colour..'}'..sampGetPlayerNickname(id):gsub('_', ' ')..'{ffff00} ['..id..']'} 
        end
    end

    if not mainIni.chat.misli then
        if text:find('%[ Мысли %]: ') then
            print(text)
            return false
        end
    end
    if not mainIni.chat.p_adm then
        if text:find('%[RP%]Pears Project:') then
            print(text)
            return false
        end
    end
    if not mainIni.chat.frac then
        if text:find('%*%* %{......%}.+№ %d+: {......}.+') or text:find('%*%* %{......%}.+ %{......%}.+%{......}%[%d+%]: .+') then
            print(text)
            return false
        end
    end
    if not mainIni.chat.fam then
        if text:find('%[F%] .+ %{......%}.+%[%d+%]: {......}.+') then
            print(text)
            return false
        end
    end
    if not mainIni.chat.ads then
        if text:find('%* %[.*Реклама%]:%{......%}.+, %{......%}Контакт: [^Неизвестный]') or text:find('%* Обработал:{......} .+ %*') then
            print(text)
            return false
        end
    end
    if not mainIni.chat.invites then
        if (color == -86 or color == -858993494) and (text:find("%*%*%p+%{") or text:find("%[ %{00cc00%}Открыт %{ffffff%}| %{00cc00%}/invites %{ffffff%}%]") or text:find("Открыт призыв в NGSA: %[ %{333300%}Открыт %{ffffff%}|")) then
            print(text)
            return false
        end
    end
    if not mainIni.chat.gos_ads then
        if (color == 869072810 and text:find("выдал ордер адвокату") or (color == -86 or color == -858993494) and (text:find("%*%*%p+%P") or text:find("%a+_%a+:"))) then
            print(text)
            return false
        end
    end
    if not mainIni.chat.a_adm then
        if (text:find("%{ff9000%}%* %[ADM%]%a+_%a+%[%d+%]:") or text:find("%{0088ff%}%(%( %a+_%a+%[%d+%]%: %{FFFFFF%}")) then
            print(text)
            return false
        end
    end
    if not mainIni.chat.news_cnn then
        if (color == -5963606 or color == -1697828182) and (text:find("%{FFFFFF%}%* CNN %* %a+_%a+:") or text:find("%[Прямой Эфир%]")) then
            print(text)
            return false
        end
    end
    if not mainIni.chat.news_sekta then
        if color == -5963606 and text:find("%{FFFFFF%}%* CNN %* Сектант:") then
            print(text)
            return false
        end
    end
    if not mainIni.chat.hit_ads then
        if color == -1 and text:find("%{FF6C00%}%* %[Реклама%]:%{00FF0C%}") or text:find("%{FF0000%}отправил рекламу %*%*") then
            print(text)
            return false
        end
    end
    if not mainIni.chat.propose then
        if color == -86 and (text:find("%{0088ff%}___________________________________________________________________________________________________________") or text:find("%{0088ff%}%[Pears Project%]: %{aeff00%}Поздравляем")) then
            print(text)
            return false
        end
    end

    if text:find('сбил с ног .+, ударом по голове%.') then lastknocked = sampGetPlayerIdByNickname(text:match('с ног (.-), ударом')) end
end

function sampev.onPlayerStreamIn(playerid, team, model, position)
    --[[if mainIni.config.cstream then
        for k, v in pairs(c_ids) do
            if k == playerid then
                sampAddChatMessage('[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {cccccc}[ {800000}'..k..' {cccccc}] в зоне стрима. Стоимость - {800000}'..v..'${ffffff}.', 0xCCCCCC)
                lastct_instream = k
            end
        end
    end
    if mainIni.config.otstrel then
        for k, v in pairs(otstrel_online) do
            if v.id == playerid then
                sampAddChatMessage('[ Отстрел ]: Игрок {800000}'..v.name:gsub('_', ' ')..' {cccccc}[ {800000}'..v.id..' {cccccc}] в зоне стрима.', 0xCCCCCC)
            end
        end
    end]]
end

function sampev.onPlayerStreamOut(playerid)
    --[[if mainIni.config.cstream then
        for k, v in pairs(c_ids) do
            if k == playerid then
                sampAddChatMessage('[ Мысли ]: Контракт {800000}'..sampGetPlayerNickname(k):gsub('_', ' ')..' {cccccc}[ {800000}'..k..' {cccccc}] покинул зону стрима.', 0xCCCCCC)
            end
        end
    end
    if mainIni.config.otstrel then
        for k, v in pairs(otstrel_online) do
            if v.id == playerid then
                sampAddChatMessage('[ Отстрел ]: Игрок {800000}'..v.name:gsub('_', ' ')..' {cccccc}[ {800000}'..v.id..' {cccccc}] покинул зону стрима.', 0xCCCCCC)
            end
        end
    end]]
end

function sampev.onPlaySound(id)
    if id == 40405 then 
        if mainIni.config.cstream then
            return false
        end
    end
    if id == 4203 or id == 40405 then
        if openCarDoors then
            return false
        end
    end
end

function sampev.onSendChat(msg)
    if mainIni.config.ooc_only then
        if not msg:find('^>') then
            sampSendChat('/b '..msg)
            return false
        else
            msg = msg:gsub('^>', '')
            if not msg:find('^/') then
                return {msg}
            else
                sampSendChat(msg)
                return false
            end
        end
    end
end

function getInvisibility(id)
    if sampGetPlayerColor(id) == 16777215 then return true end
end

function sampGetPlayerIdByNickname(nick)
    local _, myid = sampGetPlayerIdByCharHandle(playerPed)
    if tostring(nick) == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1000 do if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == tostring(nick) then return i end end
	return -1
end

function goKeyPressed(id)
    lua_thread.create(function ()
        setVirtualKeyDown(id, true)
        wait(100)
        setVirtualKeyDown(id, false)
    end)
end

function scriptMenu()
    sampShowDialog(D_SETTING, '{ffffff}Настройка {cccccc}Hitman Helper {ffffff}| Версия: '..text_version, 'Название\tЗначение\n{cccccc}Последние нововведения\t'..'Версия: '..text_version..'\n{cccccc}Моя работоспособность\n{ffffff}Метод сохранения скриншотов:\t'..(mainIni.config.screen_type and 'Встроенный модуль' or 'Сочетание клавиш')..'\nТест авто-скриншота\nАвто-скриншот выполненного контракта\t'..(mainIni.config.autoscreen and '{008000}V' or '{ff0000}X')..'\n{ffffff}Чекер контрактов\t'..(mainIni.config.cstream and '{008000}V' or '{ff0000}X')..'\n{ffffff}Метка на игроке в [/cfd]\t'..(mainIni.config.metka and '{008000}V' or '{ff0000}X')..'\nПостоянный поиск игрока в [/cfd]\t'..(mainIni.config.autofind and '{008000}V' or '{ff0000}X')..'\n{ffffff}Скрывать при скриншоте\t'..(mainIni.config.without_screen and '{008000}V' or '{ff0000}X')..'\n{ffffff}Чекер отстрела\t'..(mainIni.config.otstrel and '{008000}V' or '{ff0000}X')..'\n{ffffff}OOC-чат по умолчанию\t'..(mainIni.config.ooc_only and '{008000}V' or '{ff0000}X')..'\n{ffffff}Поиск игрока в [/cfd] на сторонних серверах\t'..(mainIni.config.search_other_servers and '{008000}V' or '{ff0000}X')..'\nКастомный худ\t'..(mainIni.config.hud and '{008000}V' or '{ff0000}X')..'\nИзмененные строки о взятии/отказе/выполнении контракта\t'..(mainIni.config.customctstr and '{008000}V' or '{ff0000}X')..'\nАвтоматическое пополнение счёта телефона\t'..(mainIni.config.automobile and '{008000}V' or '{ff0000}X')..'\nАвтоматическая заправка\t'..(mainIni.config.autofill and '{008000}V' or '{ff0000}X')..'\nКастомный [/id]\t'..(mainIni.config.customid and '{008000}V' or '{ff0000}X')..'\nСкрывать серверный спидометр\t'..(mainIni.config.s_speed and '{008000}V' or '{ff0000}X')..'\nНастройка чата\nНастройка анонимайзера\nНастройка названий оружий\nНастройка положения HUD\nНастройка макросов', 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function statsMenu()
    local points = 0
    for _, line in pairs(mainIni.stats) do
        local type, type_ots = tonumber(line:match('(%d-),')), nil
        if type == 2 then type_ots = tonumber(line:match('(%d+)$')) == 1 and true or false end
        points = points + (type == 1 and mainIni.config.points_contracts or (type == 2 and (type_ots and mainIni.config.points_otstrel_squad or mainIni.config.points_otstrel) or mainIni.config.points_ammo))
    end
    sampShowDialog(D_AGENTSTATS_MAIN, 'Моя работоспособность ['..os.date('%d.%m.%Y')..']', 'Тип\tЗначение\n{cccccc}Суммарное количество набранных баллов:\t{0088FF}'..points..'{FFFFFF}\n{cccccc}Тип работы отстрела:\t'..'{cccccc}'..(otstrel_squad and 'Squad' or 'Solo')..'\nИнформация о выполненных контрактах\nИнформация о работе отстрела\nИнформация о доставленных боеприпасах\nНастройка баллов\n{cccccc}Очистить свою работоспособность', 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function macrossesFunc()
    while true do
        wait(0)

        if isKeysDown(macrosses_list.setting, true) and not isPauseMenuActive() and not sampIsChatInputActive() and not sampIsDialogActive() then
            scriptMenu()
        end

        if mainIni.config.macrosses then
            if not sampIsChatInputActive() then
                if isKeysDown(macrosses_list.knock, true) then
                    if tonumber(sampGetNearestPlayer()) ~= -1 then
                        sampSendChat("/ko " .. sampGetNearestPlayer())
                        wait(300)
                    end

                elseif isKeysDown(macrosses_list.boot, true) and lastknocked ~= nil then
                    goKeyPressed(78)
                    lua_thread.create(function ()
                        while not sampTextdrawIsExists(2202) do wait(0) end
                        sampSendClickTextdraw(2202)
                        while not sampTextdrawIsExists(2176) do wait(0) end
                        sampSendClickTextdraw(2176)
                        while not sampIsDialogActive(899) do wait(0) end
                        sampSendDialogResponse(899, 1, 1, -1)
                        while not sampIsDialogActive(547) do wait(0) end
                        sampSendDialogResponse(547, 1, 1, lastknocked) sampCloseCurrentDialogWithButton(1)
                    end)
                    wait(300)

                elseif isKeysDown(macrosses_list.members, true) then
                    sampSendChat('/members')
                    wait(300)

                elseif isKeysDown(macrosses_list.contracts, true) then
                    sampSendChat('/contractas')
                    wait(300)

                elseif isKeysDown(macrosses_list.cancel, true) then
                    sampSendChat('/cancel')
                    wait(300)

                elseif isKeysDown(macrosses_list.getct, true) then
                    if lastct_instream ~= nil then
                        sampSendChat('/goc '..lastct_instream)
                    end
                    wait(300)

                elseif isKeysDown(macrosses_list.myc, true) then
                    sampSendChat('/myc')
                    wait(300)

                elseif isKeysDown(macrosses_list.invis, true) then
                    sampSendChat('/hmenu')
                    incInvis = true
                    wait(300)

                elseif isKeysDown(macrosses_list.otstrel, true) then
                    openOtstrelList()
                    wait(300)

                elseif isKeysDown(macrosses_list.admins, true) then
                    sampSendChat('/admins')
                    wait(300)
                
                elseif isKeysDown(macrosses_list.find, true) then
                    if cfd ~= nil then sampSendChat('/find '..cfd) end
                    wait(300)

                elseif isKeysDown(macrosses_list.takect, true) then
                    local id = sampGetPlayerIdByNickname(mainIni.temp.last_ct)
                    if id ~= -1 then
                        sampSendChat('/cancel')
                        sampSendChat('/goc '..id)
                    end
                    wait(300)
                
                elseif isKeysDown(macrosses_list.tempname_otstrel, true) then incFakeNick('otstrel') wait(300)
                elseif isKeysDown(macrosses_list.tempname_contracts, true) then incFakeNick('contracts') wait(300)
                elseif isKeysDown(macrosses_list.tempname_trainings, true) then incFakeNick('trainings') wait(300)

                end
            end
        end
    end
end

function incFakeNick(type)
    -- types: otstrel, contracts, trainings
    if mainIni.temp.fakenick then sampSendChat('/sign') end
    sampSendChat('/sign '..mainIni['tempname'][type])
end

function dialogFunc()
    while true do
        wait(0)

        local result, button, listitem, input = sampHasDialogRespond(D_MSETTING)
        if result and button == 1 then
            if listitem == 0 then
                mainIni.config.macrosses = not mainIni.config.macrosses
                showSettingMacrosses()
            elseif listitem == 1 then
                macrosses_list.knock = {90, 221}
                macrosses_list.boot = {90, 219}
                macrosses_list.members = {90, 186}
                macrosses_list.contracts = {90, 222}
                macrosses_list.cancel = {90, 190}
                macrosses_list.getct = {190, 191}
                macrosses_list.myc = {90, 188}
                macrosses_list.invis = {88, 90}
                macrosses_list.otstrel = {90, 76}
                macrosses_list.admins = {90, 75}
                macrosses_list.setting = {35}
                macrosses_list.screen = {119}
                macrosses_list.find = {88, 87}
                macrosses_list.takect = {75}
                macrosses_list.tempname_otstrel = {90, 49}
                macrosses_list.tempname_contracts = {90, 50}
                macrosses_list.tempname_trainings = {90, 51}
                showSettingMacrosses()
            elseif listitem == 2 then setting_bind = 'knock'
            elseif listitem == 3 then setting_bind = 'boot'
            elseif listitem == 4 then setting_bind = 'members'
            elseif listitem == 5 then setting_bind = 'contracts'
            elseif listitem == 6 then setting_bind = 'cancel'
            elseif listitem == 7 then setting_bind = 'getct'
            elseif listitem == 8 then setting_bind = 'myc'
            elseif listitem == 9 then setting_bind = 'invis'
            elseif listitem == 10 then setting_bind = 'otstrel'
            elseif listitem == 11 then setting_bind = 'admins'
            elseif listitem == 12 then setting_bind = 'find'
            elseif listitem == 13 then setting_bind = 'screen'
            elseif listitem == 14 then setting_bind = 'takect'
            elseif listitem == 15 then setting_bind = 'tempname_otstrel'
            elseif listitem == 16 then setting_bind = 'tempname_contracts'
            elseif listitem == 17 then setting_bind = 'tempname_trainings'
            elseif listitem == 18 then setting_bind = 'setting' end
            lockPlayerControl(true)   
        end

        local result, button, listitem, input = sampHasDialogRespond(D_ASETTING_ONE)
        if result and button == 1 then
            local openMenu = true
            if listitem == 0 then
                mainIni.config.anonymizer = not mainIni.config.anonymizer
                if mainIni.config.anonymizer then
                    for k, v in pairs(anonymizer_names) do
                        local name = v:match('(.+) =')
                        local mask = v:match('= (.+)')
                        if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == name or sampIsPlayerConnected(sampGetPlayerIdByNickname(name)) then
                            changeName(name, mask)
                        end
                    end
                else
                    for k, v in pairs(anonymizer_names) do
                        local name = v:match('(.+) =')
                        local mask = v:match('= (.+)')
                        if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == mask or sampIsPlayerConnected(sampGetPlayerIdByNickname(mask)) then
                            changeName(mask, name)
                        end
                    end
                end
                sampAddChatMessage('[ Мысли ]: Я '..(mainIni.config.anonymizer and 'включил' or 'выключил')..' анонимайзер', 0xCCCCCC)
            end
            if listitem == 1 then
                sampShowDialog(D_ASETTING_TWO, 'Добавление/редактирование маски', 'Введите ник игрока и маску для него\n{cccccc}Требуемый формат:{cccccc} Nick_Name = Mask', 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
                openMenu = false
            end
            if listitem == 2 then
                sampShowDialog(D_ASETTING_THREE, 'Удаление маски', 'Введите часть ника, или часть маски, для того, чтобы удалить запись:', 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
                openMenu = false
            end
            if openMenu then anonymizerSettings() end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_ASETTING_TWO)
        if result and button == 1 then
            if not input:find('.+ = .+') then
                sampAddChatMessage('[ Мысли ]: Я должен ввести ник и маску в требуемом формате: Nick_Name = Mask', 0xCCCCCC)
                sampShowDialog(D_ASETTING_TWO, 'Добавление/редактирование маски', 'Введите ник игрока и маску для него\n{ff0000}Требуемый формат:{cccccc} Nick_Name = Mask', 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
            else
                local retry
                for k, v in pairs(anonymizer_names) do
                    if input:find(v:match('(.+) =')) or input:find(v:match('= (.+)')) then
                        retry = true
                        break
                    end
                end
                if not retry then
                    table.insert(anonymizer_names, input)
                    sampAddChatMessage('[ Мысли ]: Запись "'..input..'" успешно создана', 0xCCCCCC)
                    if mainIni.config.anonymizer then
                        local name = input:match('(.+) =')
                        local mask = input:match('= (.+)')
                        local localid = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
                        if sampGetPlayerNickname(localid) == name or sampGetPlayerIdByNickname(name) ~= -1 then
                            changeName(name, mask)
                        end
                    end
                else
                    sampAddChatMessage('[ Мысли ]: Никнеймы и маски не должны повторяться. Сперва я должен удалить старую запись', 0xCCCCCC)
                end
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_ASETTING_THREE)
        if result and button == 1 then
            local delete
            for k, v in pairs(anonymizer_names) do
                if v:find(input) then
                    delete = v
                    table.remove(anonymizer_names, k)
                    break
                end
            end
            if delete ~= nil then
                sampAddChatMessage('[ Мысли ]: Запись "'..delete..'" успешно удалена', 0xCCCCCC)
                local name = delete:match('(.+) =')
                local mask = delete:match('= (.+)')
                if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == name or sampGetPlayerIdByNickname(mask) ~= -1 then
                    changeName(mask, name)
                end
            else
                sampAddChatMessage('[ Мысли ]: Запись по запросу "'..input..'" не обнаружена', 0xCCCCCC)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_SETCOLOR)
        if result then
            if button == 1 then
                sampSendChat('/setcolor '..listitem + 1)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_CSETTING)
        if result then
            if button == 1 then
                if listitem == 0 then mainIni.chat.misli = not mainIni.chat.misli end
                if listitem == 1 then mainIni.chat.p_adm = not mainIni.chat.p_adm end
                if listitem == 2 then mainIni.chat.frac = not mainIni.chat.frac end
                if listitem == 3 then mainIni.chat.fam = not mainIni.chat.fam end
                if listitem == 4 then mainIni.chat.ads = not mainIni.chat.ads end
                if listitem == 5 then mainIni.chat.invites = not mainIni.chat.invites end
                if listitem == 6 then mainIni.chat.gos_ads = not mainIni.chat.gos_ads end
                if listitem == 7 then mainIni.chat.a_adm = not mainIni.chat.a_adm end
                if listitem == 8 then mainIni.chat.news_cnn = not mainIni.chat.news_cnn end
                if listitem == 9 then mainIni.chat.news_sekta = not mainIni.chat.news_sekta end
                if listitem == 10 then mainIni.chat.hit_ads = not mainIni.chat.hit_ads end
                if listitem == 11 then mainIni.chat.propose = not mainIni.chat.propose end

                chatSettings()
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_SETTING)
        if result then
            if button == 1 then
                local openMenu = true
                if listitem == 0 then
                    sampShowDialog(D_INVALID, 'Последние нововведения || Версия: '..text_version, changelog, '*', nil, DIALOG_STYLE_MSGBOX)
                    openMenu = false
                end
                if listitem == 1 then
                    statsMenu()
                    openMenu = false
                end
                if listitem == 2 then mainIni.config.screen_type = not mainIni.config.screen_type end
                if listitem == 3 then
                    if mainIni.config.screen_type then
                        sampAddChatMessage('[ Hitman Helper ]: Сейчас скрипт использует метод сохранения скриншотов через встроенный в него модуль.', 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: По умолчанию скриншоты сохраняются по этому пути: [GTA San Andreas User Files/SAMP/screens]', 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: Нажмите F4, чтобы скрипт сделал скриншот, либо F5, чтобы выйти из этого режима', 0xCCCCCC)
                    else
                        sampAddChatMessage('[ Hitman Helper ]: После выполненного контракта скрипт автоматически нажимает сочетание клавиш [ '..layoutMacrossString('screen')..' ]', 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: Вам необходимо выбрать это сочетание клавиш в любой программе для сохранения скриншотов', 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: Нажмите F4, чтобы скрипт нажал данное сочетание клавиш, либо F5, чтобы выйти из этого режима', 0xCCCCCC)
                    end
                    test_as = true
                    openMenu = false
                end
                if listitem == 4 then mainIni.config.autoscreen = not mainIni.config.autoscreen end
                if listitem == 5 then mainIni.config.cstream = not mainIni.config.cstream end
                if listitem == 6 then mainIni.config.metka = not mainIni.config.metka end
                if listitem == 7 then mainIni.config.autofind = not mainIni.config.autofind end
                if listitem == 8 then mainIni.config.without_screen = not mainIni.config.without_screen end
                if listitem == 9 then
                    mainIni.config.otstrel = not mainIni.config.otstrel
                    if mainIni.config.otstrel then
                        if not doesFileExist(getWorkingDirectory()..'/config/Hitman Helper/otstrel.txt') then
                            local f = io.open(getWorkingDirectory()..'/config/Hitman Helper/otstrel.txt', 'w')
                            f:close()
                        end
                        sampAddChatMessage('[ Hitman Helper ]: Вы включили чекер отстрела. Теперь необходимо заполнить список [/config/Hitman Helper/otstrel.txt]', 0xCCCCCC)
                        sampAddChatMessage('[ Hitman Helper ]: Для просмотра людей из списка отстрела в сети, используйте - {FF6347}/otstrel_list [ '..layoutMacrossString(macrosses_list.otstrel)..' ]', 0xCCCCCC)
                        loadOtstrelList(1)
                    end
                end
                if listitem == 10 then 
                    mainIni.config.ooc_only = not mainIni.config.ooc_only
                    if mainIni.config.ooc_only then sampAddChatMessage('Вы включили OOC-чат по умолчанию. Для использования IC чата, введите ">" перед сообщением.', 0xCCCCCC) end
                end
                if listitem == 11 then mainIni.config.search_other_servers = not mainIni.config.search_other_servers end
                if listitem == 12 then mainIni.config.hud = not mainIni.config.hud end
                if listitem == 13 then mainIni.config.customctstr = not mainIni.config.customctstr end
                if listitem == 14 then mainIni.config.automobile = not mainIni.config.automobile end
                if listitem == 15 then mainIni.config.autofill = not mainIni.config.autofill end
                if listitem == 16 then mainIni.config.customid = not mainIni.config.customid end
                if listitem == 17 then mainIni.config.s_speed = not mainIni.config.s_speed end
                if listitem == 18 then
                    chatSettings()
                    openMenu = false
                end
                if listitem == 19 then
                    anonymizerSettings()
                    openMenu = false
                end
                if listitem == 20 then
                    local weapon_line
                    for k, v in pairs(weapons_list) do
                        weapon_line = (weapon_line == nil and 'Текущее название оружия\tНовое значение\n'..v..'\t>>\n' or weapon_line..v..'\t>>\n')
                    end
                    sampShowDialog(D_GSETTING_ONE, 'Настройка', weapon_line, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
                    openMenu = false
                end
                if listitem == 21 then
                    sampAddChatMessage('[ Hitman Helper ]: Перемещайте курсор для установки нового положения кастомного худа', 0xCCCCCC)
                    sampAddChatMessage('[ Hitman Helper ]: ЛКМ - установить новое положение | ПКМ - вернуть изначальное положение', 0xCCCCCC)
                    hud_move = true
                    openMenu = false
                end
                if listitem == 22 then
                    showSettingMacrosses()
                    openMenu = false
                end

                if openMenu then scriptMenu() end
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_GSETTING_ONE)
        if result and button == 1 then
            local gun
            if listitem <= 18 then
                gun = weapons_list[listitem + 1]
            else
                gun = weapons_list[listitem + 3]
            end
            sampShowDialog(D_GSETTING_TWO, 'Настройка', 'Введите новое название для '..gun, 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
        end

        local result, button, listitem, input = sampHasDialogRespond(D_GSETTING_TWO)
        if result and button == 1 then
            local weapon_name = sampGetDialogText():match('название для (.+)')
            local weapon_id
            for k, v in pairs(weapons_list) do
                if weapon_name == v then
                    weapon_id = k
                    break
                end
            end
            weapons_list[weapon_id] = input
            sampAddChatMessage('[ Мысли ]: Название оружия успешно изменено на "'..input..'"', 0xCCCCCC)
        end

        local result, button, listitem, input = sampHasDialogRespond(D_TNSETTING_ONE)
        if result and button == 1 then
            current_tempname = (listitem == 0 and 'otstrel' or (listitem == 1 and 'contracts' or 'trainings'))
            sampShowDialog(D_TNSETTING_TWO, 'Взаимодействие', 'Установить\nРедактировать', 'Ок', 'Отмена', DIALOG_STYLE_LIST)
        end

        local result, button, listitem, input = sampHasDialogRespond(D_TNSETTING_TWO)
        if result and button == 1 then
            if listitem == 0 then
                incFakeNick(current_tempname)
            elseif listitem == 1 then
                sampShowDialog(D_TNSETTING_THREE, 'Редактирование', '{FFFFFF}Введите желаемый никнейм:', 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_TNSETTING_THREE)
        if result and button == 1 then
            mainIni['tempname'][current_tempname] = input
            sampShowDialog(D_TNSETTING_ONE, ' ', 'Тип\tВременный никнейм\n{FF6347}Отстрел\t{FFFFFF}'..mainIni.tempname.otstrel..'\n{FF6347}Контракты\t{FFFFFF}'..mainIni.tempname.contracts..'\n{FF6347}Тренировки\t{FFFFFF}'..mainIni.tempname.trainings, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
        end

        local result, button, listitem, input = sampHasDialogRespond(D_AGENTSTATS_INFO)
        if result and button == 1 then
            if listitem ~= 0 then
                local dialog_text, array = (agentstats_type == 1 and 'Время\tНикнейм\tОружие\tСумма\n' or (agentstats_type == 2 and 'Время\tНикнейм\tОружие\tТип\n' or 'Время\tБоеприпасы\tКоличество\n')), {}
                for _, line in pairs(mainIni.stats) do
                    local type, date = tonumber(line:match('(%d-),')), tonumber(line:match('%d-,.-,(%d+),*'))
                    if type == agentstats_type then
                        local found = false
                        for k,v in pairs(array) do
                            if os.date('%d.%m.%Y', v) == os.date('%d.%m.%Y', date) then
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(array, date)
                        end
                    end
                end
                for item, v in pairs(array) do
                    if listitem == item then
                        for _, line in pairs(mainIni.stats) do
                            local type, date = tonumber(line:match('(%d-),')), tonumber(line:match('%d-,.-,(%d+),*'))
                            local ammo, time, nickname, damage, weapon, type_ots, sum

                            if type == 1 then
                                time, nickname, damage, weapon, sum = line:match('.-,.-,(.-),(.-),(.-),(.-),(.+)')
                            elseif type == 2 then
                                time, nickname, damage, weapon = line:match('.-,.-,(.-),(.-),(.-),(.-),')
                                type_ots = tonumber(line:match('(%d+)$')) == 1 and true or false
                            elseif type == 3 then
                                ammo, time, sum = line:match('.-,(.+),(%d+),(%d+)')
                            end

                            if type == agentstats_type and os.date('%d.%m.%Y', date) == os.date('%d.%m.%Y', v) then
                                g_date = os.date('%d.%m.%Y', date)
                                if agentstats_type == 1 then
                                    dialog_text = dialog_text..os.date('[%H:%M:%S]', tonumber(time))..'\t'..nickname..'\t'..weapon..' [{FF6347}-'..damage..'HP{ffffff}]\t{3caa3c}'..sum..'\n'
                                elseif agentstats_type == 2 then
                                    dialog_text = dialog_text..os.date('[%H:%M:%S]', tonumber(time))..'\t'..nickname..'\t'..weapon..' [{FF6347}-'..damage..'HP{ffffff}]\t'..(type_ots and 'Squad' or 'Solo')..'\n'
                                elseif agentstats_type == 3 then
                                    dialog_text = dialog_text..os.date('[%H:%M:%S]', tonumber(time))..'\t{FF6347}'..ammo..'\t{0088FF}'..sum..'\n'
                                end
                            end
                        end
                    end
                end

                sampShowDialog(D_INVALID, 'Информация о '..(agentstats_type == 1 and 'выполненных контрактах' or (agentstats_type == 2 and 'работе отстрела' or 'принесенных боеприпасах'))..' ['..g_date..']', dialog_text, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_AGENTSTATS_POINTS)
        if result and button == 1 then
            if sampGetDialogText():find('Введите новое значение баллов') then
                mainIni['config'][agentstats_points] = tonumber(input)  
                sampShowDialog(D_AGENTSTATS_POINTS, 'Настройка баллов', 'Баллы за выполнение контрактов:\t'..mainIni.config.points_contracts..'\nБаллы за работу отстрела [SOLO]:\t'..mainIni.config.points_otstrel..'\nБаллы за работу отстрела [SQUAD]:\t'..mainIni.config.points_otstrel_squad..'\nБаллы за доставку боеприпасов:\t'..mainIni.config.points_ammo, 'Ок', 'Отмена', DIALOG_STYLE_LIST)
            else
                agentstats_points = (listitem == 0 and 'points_contracts' or (listitem == 1 and 'points_otstrel' or (listitem == 2 and 'points_otstrel_squad' or 'points_ammo')))
                sampShowDialog(D_AGENTSTATS_POINTS, 'Настройка баллов', 'Введите новое значение баллов:', 'Ок', 'Отмена', DIALOG_STYLE_INPUT)
            end
        end

        local result, button, listitem, input = sampHasDialogRespond(D_AGENTSTATS_MAIN)
        if result and button == 1 then
            if sampGetDialogText():find('При очистке вашей работоспособности, восстановить её уже не получится') then
                mainIni.stats = {}
                sampAddChatMessage('[ Hitman Helper ]: Ваша работоспособность была очищена.', 0xCCCCCC)
            else
                if listitem == 1 then -- Смена типа работы отстрела (Solo/Squad)
                    otstrel_squad = not otstrel_squad
                    statsMenu()
                end
                if listitem == 2 then -- Информация о выполненных контрактах
                    showAgentStats(1)
                end
                if listitem == 3 then -- Информация о работе отстрела
                    showAgentStats(2)
                end
                if listitem == 4 then -- Информация о доставленных боеприпасах
                    showAgentStats(3)
                end
                if listitem == 5 then
                    sampShowDialog(D_AGENTSTATS_POINTS, 'Настройка баллов', 'Баллы за выполнение контрактов:\t'..mainIni.config.points_contracts..'\nБаллы за работу отстрела [SOLO]:\t'..mainIni.config.points_otstrel..'\nБаллы за работу отстрела [SQUAD]:\t'..mainIni.config.points_otstrel_squad..'\nБаллы за доставку боеприпасов:\t'..mainIni.config.points_ammo, 'Ок', 'Отмена', DIALOG_STYLE_LIST)
                end
                if listitem == 6 then
                    sampShowDialog(D_AGENTSTATS_MAIN, 'Предупреждение', 'При очистке вашей работоспособности, восстановить её уже не получится.\nВы уверены, что желаете это сделать?', 'Да', 'Нет', DIALOG_STYLE_MSGBOX)
                end
            end
        end
    end
end

function showAgentStats(num)
    local array = {}
    for _, line in pairs(mainIni.stats) do
        local type, date = tonumber(line:match('(%d-),')), tonumber(line:match('%d-,.-,(%d+),*'))
        if type == num then
            local found = false
            for _, v in pairs(array) do
                if v.date == os.date('%d.%m.%Y', date) then 
                    v.number = v.number + 1
                    found = true
                end
            end
            if not found then table.insert(array, {date = os.date('%d.%m.%Y', date), number = 1}) end
        end
    end
    local kills = 0
    for _,v in pairs(array) do kills = kills + v.number end
    local dialog_text = 'День\tКоличество '..(num == 3 and 'боеприпасов' or 'убийств')..'\n{cccccc}Суммарное количество '..(num == 3 and 'боеприпасов' or 'убийств')..':\t'..kills..'\n'
    for _,v in pairs(array) do dialog_text = dialog_text..'['..v.date..']\t'..v.number..'\n' end
    agentstats_type = num
    sampShowDialog(D_AGENTSTATS_INFO, '{cccccc}Информация о '..(num == 3 and 'принесенных боеприпасах' or (num == 1 and 'выполненных контрактах' or 'работе отстрела')), dialog_text, 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function chatSettings()
    sampShowDialog(D_CSETTING, 'Настройка чата', 'Тип\tЗначение\nМысли персонажа\t'..(mainIni.chat.misli and '{008000}V' or '{ff0000}X')..'\nНаказания от администрации\t'..(mainIni.chat.p_adm and '{008000}V' or '{ff0000}X')..'\nЧат организации [/f]\t'..(mainIni.chat.frac and '{008000}V' or '{ff0000}X')..'\nЧат семьи [/c]\t'..(mainIni.chat.fam and '{008000}V' or '{ff0000}X')..'\nОбъявления игроков\t'..(mainIni.chat.ads and '{008000}V' or '{ff0000}X')..'\nОповещения о наборах\t'..(mainIni.chat.invites and '{008000}V' or '{ff0000}X')..'\nГосударственные объявления\t'..(mainIni.chat.gos_ads and '{008000}V' or '{ff0000}X')..'\nСообщения администрации\t'..(mainIni.chat.a_adm and '{008000}V' or '{ff0000}X')..'\nНовости от CNN\t'..(mainIni.chat.news_cnn and '{008000}V' or '{ff0000}X')..'\nНовости от Секты\t'..(mainIni.chat.news_sekta and '{008000}V' or '{ff0000}X')..'\nРеклама агентства\t'..(mainIni.chat.hit_ads and '{008000}V' or '{ff0000}X')..'\nОповещения о свадьбах\t'..(mainIni.chat.propose and '{008000}V' or '{ff0000}X'), 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function anonymizerSettings()
    local names
    for k, v in pairs(anonymizer_names) do names = (names == nil and v..'\n' or names..v..'\n') end
    sampShowDialog(D_ASETTING_ONE, 'Настройка анонимайзера', 'Название\tЗначение\nВключить/выключить\t'..(mainIni.config.anonymizer and '{008000}V' or '{ff0000}X')..'\n{cccccc}Добавить/редактировать\n{cccccc}Удалить\n'..(names ~= nil and names or ''), 'Ок', 'Отмена', DIALOG_STYLE_TABLIST_HEADERS)
end

function screenct()
    if mainIni.config.screen_type then -- Используя модуль
        local filePath = screenshot.getUserDirectoryPath()..'/SAMP/screens'
        local fileName = os.date('%Y-%m-%d %H-%M-%S')
        screenshot.requestEx(filePath, fileName)
    else -- Используя сторонние программы
        for k, v in pairs(macrosses_list.screen) do goKeyPressed(v) end
    end
    sampAddChatMessage('Screenshot completed', 0x850000)
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function scriptBody()
    while true do
        wait(0)

        local pressed_screen = isKeysDown(macrosses_list.screen, true) or isKeyDown(0x74) or isKeyDown(0x77) or isKeyDown(0x2C) and true or false
        local showed = true
        if pressed_screen and mainIni.config.without_screen then showed = false end
        displayHud(mainIni.config.shud and true or false)

        if showed and mainIni.config.hud then
            local health = getCharHealth(PLAYER_PED) < 100 and getCharHealth(PLAYER_PED) > -1 and getCharHealth(PLAYER_PED) or 100
            local weapon = getCurrentCharWeapon(PLAYER_PED)
            local money_string = setpoint(getPlayerMoney(PLAYER_HANDLE))..'$'
            local weaponline = string.upper(weapons_list[((weapon ~= nil and weapon <= 19) and weapon + 1 or weapon)])..(weapon > 15 and weapon ~= 46 and ' ('..getAmmoInClip() ..'/'.. getAmmoInCharWeapon(PLAYER_PED, weapon) - getAmmoInClip()..')' or '')

            renderDrawBox(mainIni.hud.xpos, mainIni.hud.ypos, 357, 30, 2852126720.0)

            if getCharArmour(PLAYER_PED) ~= 0 then
                renderDrawBox(mainIni.hud.xpos, mainIni.hud.ypos + 27, 357, 5, 0xFF2d2d2d)
                renderDrawBox(mainIni.hud.xpos + 357 - math.ceil(357/100*getCharArmour(PLAYER_PED)), mainIni.hud.ypos + 27, math.ceil(357/100*getCharArmour(PLAYER_PED)), 5, 0xFFc7d3e2)
                renderDrawBox(mainIni.hud.xpos, mainIni.hud.ypos + 33, 357, 5, 0xFF2d2d2d)
                renderDrawBox(mainIni.hud.xpos + 357 - math.ceil(3.57 * health), mainIni.hud.ypos + 33, math.ceil(3.57 * health), 5, 0xFFce7c7c)
            else
                renderDrawBox(mainIni.hud.xpos, mainIni.hud.ypos + 27, 357, 5, 0xFF2d2d2d)
                renderDrawBox(mainIni.hud.xpos + 357 - math.ceil(3.57 * health), mainIni.hud.ypos + 27, math.ceil(3.57 * health), 5, 0xFFce7c7c)
            end

            renderDrawLine(mainIni.hud.xpos, mainIni.hud.ypos, mainIni.hud.xpos + 357, mainIni.hud.ypos, 1, 0xFFFFFFFF)
        
            if getCurrentCharWeapon(PLAYER_PED) ~= 0 and (not isCharInAnyCar(PLAYER_PED) or PLAYER_PED ~= getDriverOfCar(storeCarCharIsInNoSave(PLAYER_PED))) then
                renderFontDrawText(font_hud, money_string, mainIni.hud.xpos + 2, mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, weaponline, mainIni.hud.xpos + 355 - renderGetFontDrawTextLength(font_hud, weaponline), mainIni.hud.ypos + 3, 4294967295.0)
            elseif thispp and isCharInAnyCar(PLAYER_PED) and PLAYER_PED == getDriverOfCar(storeCarCharIsInNoSave(PLAYER_PED)) then
                renderFontDrawText(font_hud, money_string, mainIni.hud.xpos + 2, mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.sport and "S" or "•", mainIni.hud.xpos + 349 - renderGetFontDrawTextLength(font_hud, "E"), mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.lock and "D" or "•", mainIni.hud.xpos + 343 - 2 * renderGetFontDrawTextLength(font_hud, "E"), mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.light and "L" or "•", mainIni.hud.xpos + 337 - 3 * renderGetFontDrawTextLength(font_hud, "E"), mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.engine and "E" or "•", mainIni.hud.xpos + 331 - 4 * renderGetFontDrawTextLength(font_hud, "E"), mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, "—", mainIni.hud.xpos + 281, mainIni.hud.ypos + 2, 2868903935.0)
                renderFontDrawText(font_hud, "—", mainIni.hud.xpos + 14 + renderGetFontDrawTextLength(font_hud, money_string), mainIni.hud.ypos + 2, 2868903935.0)
                renderFontDrawText(font_hud, car.speed .. " km/h", mainIni.hud.xpos + 14 + renderGetFontDrawTextLength(font_hud, money_string) + 20, mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.fuel .. " l", mainIni.hud.xpos + 270 - renderGetFontDrawTextLength(font_hud, car.fuel .. " l"), mainIni.hud.ypos + 2, 4294967295.0)
                renderFontDrawText(font_hud, car.health .. " HP", mainIni.hud.xpos + 14 + renderGetFontDrawTextLength(font_hud, money_string) + 20 + renderGetFontDrawTextLength(font_hud, car.speed .. " mh/h") + (mainIni.hud.xpos + 270 - renderGetFontDrawTextLength(font_hud, car.fuel .. " l") - (mainIni.hud.xpos + 14 + renderGetFontDrawTextLength(font_hud, money_string) + 20 + renderGetFontDrawTextLength(font_hud, car.speed .. " mh/h"))) / 2 - renderGetFontDrawTextLength(font_hud, car.health .. " HP") / 2, mainIni.hud.ypos + 2, 4294967295.0)
            else
                renderFontDrawText(font_hud, money_string, mainIni.hud.xpos + 180 - renderGetFontDrawTextLength(font_hud, money_string) / 2, mainIni.hud.ypos + 3, 4294967295.0)
            end

            if cfd ~= nil then
                if not isPauseMenuActive() and sampIsPlayerConnected(tonumber(cfd)) then
                    renderFontDrawText(font, '{ff0000}SEARCH: {ffffff}'..sampGetPlayerNickname(cfd):gsub('_', ' ')..' [ '..cfd..' ]', mainIni.hud.xpos - 1, mainIni.hud.ypos - 27, 0xFFFFFFFF, 1)
                    
                    if mainIni.config.metka then
                        local result, handle = sampGetCharHandleBySampPlayerId(cfd)

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

            local checkstream_pos = (cfd ~= nil and (getInvisibility(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) and mainIni.hud.ypos - 60 or mainIni.hud.ypos - 40) or mainIni.hud.ypos - 35)
            if mainIni.config.otstrel then
                local found, otstrel_stream = false, {}
                for id = 0, sampGetMaxPlayerId(true) do
                    if sampIsPlayerConnected(id) then
                        for k,v in pairs(otstrel_list) do
                            if v.name == sampGetPlayerNickname(id) then
                                table.insert(otstrel_stream, id)
                            end
                        end
                    end
                end
        
                for _, id in pairs(otstrel_stream) do
                    local p_xpos, p_ypos, p_zpos = getCharCoordinates(PLAYER_PED)
                    local res, handle = sampGetCharHandleBySampPlayerId(id)
                    if res then
                        checkstream_pos = checkstream_pos - 15
                        local o_xpos, o_ypos, o_zpos = getCharCoordinates(handle)
                        local result, distance = pcall(getDistanceBetweenCoords3d, p_xpos, p_ypos, p_zpos, o_xpos, o_ypos, o_zpos)
                        if result then
                            renderFontDrawText(font, sampGetPlayerNickname(id)..' {FFFFFF}[ {800000}'..id..' {FFFFFF}] | '..select(1, math.modf(distance))..'m', mainIni.hud.xpos - 1, checkstream_pos, 0xFF800000)
                            found = true
                        end
                    end
                end
                checkstream_pos = checkstream_pos - 15
                if found then renderFontDrawText(font, 'Отстрел:', mainIni.hud.xpos - 1, checkstream_pos, 0xFFFFFFFF) end
            end

            if mainIni.config.cstream then
                local found, ct_stream = false, {}
                for id = 0, sampGetMaxPlayerId(true) do
                    if sampIsPlayerConnected(id) then
                        for k,v in pairs(c_ids) do
                            if k == id then
                                table.insert(ct_stream, k, v)
                            end
                        end
                    end
                end

                for id, sum in pairs(ct_stream) do
                    local p_xpos, p_ypos, p_zpos = getCharCoordinates(PLAYER_PED)
                    local res, handle = sampGetCharHandleBySampPlayerId(id)
                    if res then
                        checkstream_pos = checkstream_pos - 15
                        local o_xpos, o_ypos, o_zpos = getCharCoordinates(handle)
                        local result, distance = pcall(getDistanceBetweenCoords3d, p_xpos, p_ypos, p_zpos, o_xpos, o_ypos, o_zpos)
                        if result then
                            renderFontDrawText(font, sampGetPlayerNickname(id)..' {FFFFFF}[ {800000}'..id..' {FFFFFF}] ('..sum..'$) | '..select(1, math.modf(distance))..'m', mainIni.hud.xpos - 1, checkstream_pos, 0xFF800000)
                            found = true
                        end
                    end
                end
                checkstream_pos = checkstream_pos - 15
                if found then renderFontDrawText(font, 'Контракты:', mainIni.hud.xpos - 1, checkstream_pos, 0xFFFFFFFF) end
            end
        
            if getInvisibility(id) then renderFontDrawText(font, 'INVISIBILITY', mainIni.hud.xpos - 1, (cfd ~= nil and mainIni.hud.ypos - 50 or mainIni.hud.ypos - 27), 0xFF0088FF) end
            renderFontDrawText(font, 'NAMETAG ['..(mainIni.temp.fakenick and '{8a2be2}FAKE{FFFFFF} / '..(mainIni.temp.nametag and '{008000}ON' or '{ff0000}OFF') or mainIni.temp.nametag and '{008000} ON ' or '{ff0000} OFF ')..'{ffffff}]', (cfd ~= nil and mainIni.hud.xpos + 225 or getInvisibility(id) and mainIni.hud.xpos + 114.2 or mainIni.hud.xpos - 1), mainIni.hud.ypos - 27, 0xFFFFFFFF, 1)
        end

        if mainIni.config.cstream then
            lua_thread.create(function ()
                if os.clock() - time_stream >= 10 then
                    c_ids = {}
                    sampSendChat('/contractas')
                    openContractas = true
                    time_stream = os.clock()
                end
            end)
        end

        if cfd ~= nil then
            if mainIni.config.autofind then
                if (os.clock() - time_find >= 4) and (cfd ~= nil) then
                    if thispp or mainIni.config.search_other_servers then
                        sampSendChat('/find '..cfd)
                    end
                    time_find = os.clock()
                end
            end

            if not sampIsPlayerConnected(cfd) then
                cfd = nil
                --sampAddChatMessage('[ Мысли ]: Преследование прекращено.', 0xCCCCCC)
            end
        end
    end
end

function getAmmoInClip()
	local struct = getCharPointer(PLAYER_PED)
	local prisv = struct + 0x0718
	local prisv = memory.getint8(prisv, false)
	local prisv = prisv * 0x1C
	local prisv2 = struct + 0x5A0
	local prisv2 = prisv2 + prisv
	local prisv2 = prisv2 + 0x8
	local ammo = memory.getint32(prisv2, false)
	return ammo
end

function emul_rpc(hook, parameters)
    local bs_io = require 'samp.events.bitstream_io'
    local handler = require 'samp.events.handlers'
    local extra_types = require 'samp.events.extra_types'
    local hooks = {

        --[[ Outgoing rpcs
        ['onSendEnterVehicle'] = { 'int16', 'bool8', 26 },
        ['onSendClickPlayer'] = { 'int16', 'int8', 23 },
        ['onSendClientJoin'] = { 'int32', 'int8', 'string8', 'int32', 'string8', 'string8', 'int32', 25 },
        ['onSendEnterEditObject'] = { 'int32', 'int16', 'int32', 'vector3d', 27 },
        ['onSendCommand'] = { 'string32', 50 },
        ['onSendSpawn'] = { 52 },
        ['onSendDeathNotification'] = { 'int8', 'int16', 53 },
        ['onSendDialogResponse'] = { 'int16', 'int8', 'int16', 'string8', 62 },
        ['onSendClickTextDraw'] = { 'int16', 83 },
        ['onSendVehicleTuningNotification'] = { 'int32', 'int32', 'int32', 'int32', 96 },
        ['onSendChat'] = { 'string8', 101 },
        ['onSendClientCheckResponse'] = { 'int8', 'int32', 'int8', 103 },
        ['onSendVehicleDamaged'] = { 'int16', 'int32', 'int32', 'int8', 'int8', 106 },
        ['onSendEditAttachedObject'] = { 'int32', 'int32', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 116 },
        ['onSendEditObject'] = { 'bool', 'int16', 'int32', 'vector3d', 'vector3d', 117 },
        ['onSendInteriorChangeNotification'] = { 'int8', 118 },
        ['onSendMapMarker'] = { 'vector3d', 119 },
        ['onSendRequestClass'] = { 'int32', 128 },
        ['onSendRequestSpawn'] = { 129 },
        ['onSendPickedUpPickup'] = { 'int32', 131 },
        ['onSendMenuSelect'] = { 'int8', 132 },
        ['onSendVehicleDestroyed'] = { 'int16', 136 },
        ['onSendQuitMenu'] = { 140 },
        ['onSendExitVehicle'] = { 'int16', 154 },
        ['onSendUpdateScoresAndPings'] = { 155 },
        ['onSendGiveDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },
        ['onSendTakeDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },]]

        -- Incoming rpcs
        ['onInitGame'] = { 139 },
        ['onPlayerJoin'] = { 'int16', 'int32', 'bool8', 'string8', 137 },
        ['onPlayerQuit'] = { 'int16', 'int8', 138 },
        ['onRequestClassResponse'] = { 'bool8', 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 128 },
        ['onRequestSpawnResponse'] = { 'bool8', 129 },
        ['onSetPlayerName'] = { 'int16', 'string8', 'bool8', 11 },
        ['onSetPlayerPos'] = { 'vector3d', 12 },
        ['onSetPlayerPosFindZ'] = { 'vector3d', 13 },
        ['onSetPlayerHealth'] = { 'float', 14 },
        ['onTogglePlayerControllable'] = { 'bool8', 15 },
        ['onPlaySound'] = { 'int32', 'vector3d', 16 },
        ['onSetWorldBounds'] = { 'float', 'float', 'float', 'float', 17 },
        ['onGivePlayerMoney'] = { 'int32', 18 },
        ['onSetPlayerFacingAngle'] = { 'float', 19 },
        --['onResetPlayerMoney'] = { 20 },
        --['onResetPlayerWeapons'] = { 21 },
        ['onGivePlayerWeapon'] = { 'int32', 'int32', 22 },
        --['onCancelEdit'] = { 28 },
        ['onSetPlayerTime'] = { 'int8', 'int8', 29 },
        ['onSetToggleClock'] = { 'bool8', 30 },
        ['onPlayerStreamIn'] = { 'int16', 'int8', 'int32', 'vector3d', 'float', 'int32', 'int8', 32 },
        ['onSetShopName'] = { 'string256', 33 },
        ['onSetPlayerSkillLevel'] = { 'int16', 'int32', 'int16', 34 },
        ['onSetPlayerDrunk'] = { 'int32', 35 },
        ['onCreate3DText'] = { 'int16', 'int32', 'vector3d', 'float', 'bool8', 'int16', 'int16', 'encodedString4096', 36 },
        --['onDisableCheckpoint'] = { 37 },
        ['onSetRaceCheckpoint'] = { 'int8', 'vector3d', 'vector3d', 'float', 38 },
        --['onDisableRaceCheckpoint'] = { 39 },
        --['onGamemodeRestart'] = { 40 },
        ['onPlayAudioStream'] = { 'string8', 'vector3d', 'float', 'bool8', 41 },
        --['onStopAudioStream'] = { 42 },
        ['onRemoveBuilding'] = { 'int32', 'vector3d', 'float', 43 },
        ['onCreateObject'] = { 44 },
        ['onSetObjectPosition'] = { 'int16', 'vector3d', 45 },
        ['onSetObjectRotation'] = { 'int16', 'vector3d', 46 },
        ['onDestroyObject'] = { 'int16', 47 },
        ['onPlayerDeathNotification'] = { 'int16', 'int16', 'int8', 55 },
        ['onSetMapIcon'] = { 'int8', 'vector3d', 'int8', 'int32', 'int8', 56 },
        ['onRemoveVehicleComponent'] = { 'int16', 'int16', 57 },
        ['onRemove3DTextLabel'] = { 'int16', 58 },
        ['onPlayerChatBubble'] = { 'int16', 'int32', 'float', 'int32', 'string8', 59 },
        ['onUpdateGlobalTimer'] = { 'int32', 60 },
        ['onShowDialog'] = { 'int16', 'int8', 'string8', 'string8', 'string8', 'encodedString4096', 61 },
        ['onDestroyPickup'] = { 'int32', 63 },
        ['onLinkVehicleToInterior'] = { 'int16', 'int8', 65 },
        ['onSetPlayerArmour'] = { 'float', 66 },
        ['onSetPlayerArmedWeapon'] = { 'int32', 67 },
        ['onSetSpawnInfo'] = { 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 68 },
        ['onSetPlayerTeam'] = { 'int16', 'int8', 69 },
        ['onPutPlayerInVehicle'] = { 'int16', 'int8', 70 },
        --['onRemovePlayerFromVehicle'] = { 71 },
        ['onSetPlayerColor'] = { 'int16', 'int32', 72 },
        ['onDisplayGameText'] = { 'int32', 'int32', 'string32', 73 },
        --['onForceClassSelection'] = { 74 },
        ['onAttachObjectToPlayer'] = { 'int16', 'int16', 'vector3d', 'vector3d', 75 },
        ['onInitMenu'] = { 76 },
        ['onShowMenu'] = { 'int8', 77 },
        ['onHideMenu'] = { 'int8', 78 },
        ['onCreateExplosion'] = { 'vector3d', 'int32', 'float', 79 },
        ['onShowPlayerNameTag'] = { 'int16', 'bool8', 80 },
        ['onAttachCameraToObject'] = { 'int16', 81 },
        ['onInterpolateCamera'] = { 'bool', 'vector3d', 'vector3d', 'int32', 'int8', 82 },
        ['onGangZoneStopFlash'] = { 'int16', 85 },
        ['onApplyPlayerAnimation'] = { 'int16', 'string8', 'string8', 'bool', 'bool', 'bool', 'bool', 'int32', 86 },
        ['onClearPlayerAnimation'] = { 'int16', 87 },
        ['onSetPlayerSpecialAction'] = { 'int8', 88 },
        ['onSetPlayerFightingStyle'] = { 'int16', 'int8', 89 },
        ['onSetPlayerVelocity'] = { 'vector3d', 90 },
        ['onSetVehicleVelocity'] = { 'bool8', 'vector3d', 91 },
        ['onServerMessage'] = { 'int32', 'string32', 93 },
        ['onSetWorldTime'] = { 'int8', 94 },
        ['onCreatePickup'] = { 'int32', 'int32', 'int32', 'vector3d', 95 },
        ['onMoveObject'] = { 'int16', 'vector3d', 'vector3d', 'float', 'vector3d', 99 },
        ['onEnableStuntBonus'] = { 'bool', 104 },
        ['onTextDrawSetString'] = { 'int16', 'string16', 105 },
        ['onSetCheckpoint'] = { 'vector3d', 'float', 107 },
        ['onCreateGangZone'] = { 'int16', 'vector2d', 'vector2d', 'int32', 108 },
        ['onPlayCrimeReport'] = { 'int16', 'int32', 'int32', 'int32', 'int32', 'vector3d', 112 },
        ['onGangZoneDestroy'] = { 'int16', 120 },
        ['onGangZoneFlash'] = { 'int16', 'int32', 121 },
        ['onStopObject'] = { 'int16', 122 },
        ['onSetVehicleNumberPlate'] = { 'int16', 'string8', 123 },
        ['onTogglePlayerSpectating'] = { 'bool32', 124 },
        ['onSpectatePlayer'] = { 'int16', 'int8', 126 },
        ['onSpectateVehicle'] = { 'int16', 'int8', 127 },
        ['onShowTextDraw'] = { 134 },
        ['onSetPlayerWantedLevel'] = { 'int8', 133 },
        ['onTextDrawHide'] = { 'int16', 135 },
        ['onRemoveMapIcon'] = { 'int8', 144 },
        ['onSetWeaponAmmo'] = { 'int8', 'int16', 145 },
        ['onSetGravity'] = { 'float', 146 },
        ['onSetVehicleHealth'] = { 'int16', 'float', 147 },
        ['onAttachTrailerToVehicle'] = { 'int16', 'int16', 148 },
        ['onDetachTrailerFromVehicle'] = { 'int16', 149 },
        ['onSetWeather'] = { 'int8', 152 },
        ['onSetPlayerSkin'] = { 'int32', 'int32', 153 },
        ['onSetInterior'] = { 'int8', 156 },
        ['onSetCameraPosition'] = { 'vector3d', 157 },
        ['onSetCameraLookAt'] = { 'vector3d', 'int8', 158 },
        ['onSetVehiclePosition'] = { 'int16', 'vector3d', 159 },
        ['onSetVehicleAngle'] = { 'int16', 'float', 160 },
        ['onSetVehicleParams'] = { 'int16', 'int16', 'bool8', 161 },
        --['onSetCameraBehind'] = { 162 },
        ['onChatMessage'] = { 'int16', 'string8', 101 },
        ['onConnectionRejected'] = { 'int8', 130 },
        ['onPlayerStreamOut'] = { 'int16', 163 },
        ['onVehicleStreamIn'] = { 164 },
        ['onVehicleStreamOut'] = { 'int16', 165 },
        ['onPlayerDeath'] = { 'int16', 166 },
        ['onPlayerEnterVehicle'] = { 'int16', 'int16', 'bool8', 26 },
        ['onUpdateScoresAndPings'] = { 'PlayerScorePingMap', 155 },
        ['onSetObjectMaterial'] = { 84 },
        ['onSetObjectMaterialText'] = { 84 },
        ['onSetVehicleParamsEx'] = { 'int16', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 24 },
        ['onSetPlayerAttachedObject'] = { 'int16', 'int32', 'bool', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 113 }

    }
    local handler_hook = {
        ['onInitGame'] = true,
        ['onCreateObject'] = true,
        ['onInitMenu'] = true,
        ['onShowTextDraw'] = true,
        ['onVehicleStreamIn'] = true,
        ['onSetObjectMaterial'] = true,
        ['onSetObjectMaterialText'] = true
    }
    local extra = {
        ['PlayerScorePingMap'] = true,
        ['Int32Array3'] = true
    }
    local hook_table = hooks[hook]
    if hook_table then
        local bs = raknetNewBitStream()
        if not handler_hook[hook] then
            local max = #hook_table-1
            if max > 0 then
                for i = 1, max do
                    local p = hook_table[i]
                    if extra[p] then extra_types[p]['write'](bs, parameters[i])
                    else bs_io[p]['write'](bs, parameters[i]) end
                end
            end
        else
            if hook == 'onInitGame' then handler.on_init_game_writer(bs, parameters)
            elseif hook == 'onCreateObject' then handler.on_create_object_writer(bs, parameters)
            elseif hook == 'onInitMenu' then handler.on_init_menu_writer(bs, parameters)
            elseif hook == 'onShowTextDraw' then handler.on_show_textdraw_writer(bs, parameters)
            elseif hook == 'onVehicleStreamIn' then handler.on_vehicle_stream_in_writer(bs, parameters)
            elseif hook == 'onSetObjectMaterial' then handler.on_set_object_material_writer(bs, parameters, 1)
            elseif hook == 'onSetObjectMaterialText' then handler.on_set_object_material_writer(bs, parameters, 2) end
        end
        raknetEmulRpcReceiveBitStream(hook_table[#hook_table], bs)
        raknetDeleteBitStream(bs)
    end
end

function setpoint(sum)
	if sum then
		sum = tostring(sum):reverse()
		array = {}
		for i in sum:gmatch(".") do
			table.insert(array, i)
		end
		sum = ""
		for k, _ in pairs(array) do
			if math.fmod(k, 4) == 0 then
				table.insert(array, k, ".")
			end
		end
		for _, v in pairs(array) do
			sum = sum .. v
		end
		return sum:reverse()
	else
		return "Error"
	end
end

function changeName(name, mask)
    local id = sampGetPlayerIdByNickname(name)
    emul_rpc("onSetPlayerName", {sampGetPlayerIdByNickname(name), mask, true})
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x100 or msg == 0x104 then
    	if bit.band(lparam, 0x40000000) == 0 then
			if setting_bind ~= nil then
				if wparam == 8 or wparam == 13 then
					if wparam == 8 then
						nkeys_bind = {}
					end
					if wparam == 13 then
						macrosses_list[setting_bind] = nkeys_bind
						setting_bind = nil
						lockPlayerControl(false)
						nkeys_bind = {}
					end
				else
					if #nkeys_bind < 3 then
						local state = true
						for k, v in pairs(nkeys_bind) do
							if v == wparam then
								state = false
							end
						end
						if state then table.insert(nkeys_bind, wparam) end
					end
				end
			end
		end
	end
end

function sampev.onShowPlayerNameTag(playerid, state)
    if playerid == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) then mainIni.temp.nametag = state end
end

function sampev.onShowTextDraw(id, data)
    if id == 2230 then car.speed = data.text:match('(%d+)') end
    if id == 2234 then car.health = data.text:match('HEALTH:_(%d+)') end
    if id == 2235 then car.fuel = data.text:match('FUEL:_(%d+)') end
    if id == 2236 then car.engine = data.boxColor ~= 671088640 and true or false end
    if id == 2237 then car.light = data.boxColor ~= 671088640 and true or false end
    if id == 2238 then car.lock = data.boxColor ~= 671088640 and true or false end
    if id == 2239 then car.sport = data.boxColor ~= 671088640 and true or false end

    if mainIni.config.s_speed then
        for _, v in pairs({2229, 2232, 2234, 2233, 2235, 2236, 2240, 2237, 2241, 2238, 2243, 2239, 2243, 2230, 2231, 2242}) do
            if id == v then
                return false
            end
        end
    end
end

function onScriptTerminate(script, quit)
    if script == thisScript() then
        io.open(anonymizer_path, 'w'):close()
        local f = io.open(anonymizer_path, 'r+')
        for k, v in pairs(anonymizer_names) do f:write((anonymizer_names[k + 1] ~= nil and u8(v)..'\n' or u8(v))) end
        f:close()

        local m_string
        for k, v in pairs(macrosses_list) do
            for kt, vt in pairs(macrosses_list[k]) do
                if macrosses_list[k][kt + 1] ~= nil then 
                    m_string = (m_string == nil and vt..' + ' or m_string..vt..' + ')
                else
                    m_string = (m_string == nil and vt or m_string..vt)
                end
            end
            mainIni['macrosses'][k] = m_string
			if m_string == nil then mainIni['macrosses'][k] = "" end
            m_string = nil
        end

        for k, v in pairs(weapons_list) do
            mainIni.weapons[k] = v
        end

        for k, v in pairs(otstrel_list) do 
            if v.time ~= nil then 
                mainIni.otstrel_list[v.name] = v.time
            end 
        end

        lockPlayerControl(false)
        displayHud(true)

        inicfg.save(mainIni, config_path)
    end
end