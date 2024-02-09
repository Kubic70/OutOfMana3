-- constants
local defaultMpThreshold = 50
local antiSpamThresholdValue = 20
local defaultMessage = "У меня %s%% маны!"
local defaultMessageEnd = "Мана кончилась!"

-- Saved vars (config)
local mpThreshold -- mp = mana percentage
local message
local message_end

-- vars
local antiSpam = false
local antiSpamEnd = false
local antiSpamThreshold

local version = GetAddOnMetadata("OutOfMana3","Version")
-- Addon loaded message
print("|c0003fc07OOM |r[v|c0003fc07" .. version .. "|r] загружен: /mana")

-- Handle Events
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("UNIT_MANA")
f:RegisterEvent('UNIT_SPELLCAST_FAILED')

f:SetScript("OnEvent", function(self, event, ...)

        local arg1, arg2, arg3= ...
        if event == "ADDON_LOADED" and arg1 == "OutOfMana3" then    --проверяем есть ли файл сохранений, загружаем/создаем
            if not OutOfManaDB3 then
                OutOfManaDB3 = {}
                OutOfManaDB3.mpThreshold = defaultMpThreshold
                OutOfManaDB3.message = defaultMessage
                OutOfManaDB3.message_end = defaultMessageEnd
            end
            -- на случай добавления новых переменных в файл сохранения, проверям есть ли они в нем
            mpThreshold = OutOfManaDB3.mpThreshold or defaultMpThreshold
            message = OutOfManaDB3.message or defaultMessage
            message_end = OutOfManaDB3.message_end or defaultMessageEnd

            antiSpamThreshold = mpThreshold + antiSpamThresholdValue
        end
        if event == "PLAYER_LOGOUT" then    -- сохраняем в файл
            OutOfManaDB3.mpThreshold = mpThreshold
            OutOfManaDB3.message = message
            OutOfManaDB3.message_end = message_end
        end

        if event == "UNIT_MANA" and (mpThreshold ~= 0) and (UnitHealth('player') > 0) then -- ивент расхода маны
            local mp = math.floor((UnitPower("player", 0) / UnitPowerMax("player")) * 100) -- current player mana percentage

            if (arg1 == "player") and (mp <= mpThreshold) and (not antiSpam) then   --выводим сообщение
                antiSpam = true
                SendMessage(message ,GetPlayerGroupType(), mp)

            elseif (arg1 == "player") and (mp >= antiSpamThreshold) and not UnitIsGhost('player') and antiSpam then   --выключаем спам защиту
                antiSpam = false
                antiSpamEnd = false
            end
        end

        if event == "UNIT_SPELLCAST_FAILED" and arg1 == "player" and (mpThreshold ~= 0) and (UnitHealth('player') > 0 and not UnitIsGhost('player')) then    --ивент фейл каста
            local manacost
            if arg3 ~= "" then  -- вычисляем стоимость умения
                manacost = select(4,GetSpellInfo(arg2,arg3))
            else
                manacost = select(4,GetSpellInfo(arg2))
            end
            if not manacost then return end --отсекаем ошибку сравнения если умение бесплатное
            if manacost > UnitPower("player", 0) and (not antiSpamEnd) then --если маны меньше чем стоит умение
                antiSpamEnd = true
                SendMessage(message_end , GetPlayerGroupType())
            end
        end

    end)

--проверяем находится ли игрок в группе/рейде и возвращаем тип чата либо nil
function GetPlayerGroupType()
    if GetNumPartyMembers() > 0 and not UnitInRaid("player") then
        return "PARTY"
    elseif UnitInRaid("player") then
        return "RAID"
    else
        return nil
    end
end

--Выводит сообщение в чат
--msg - сообщение
--che - канал
--mana - значение маны (только для форматированного текста с параметром)
function SendMessage(msg, che, mana)
    if che then
        DoEmote("OOM")
        if not mana then
            SendChatMessage(msg, che)
        else
            SendChatMessage(string.format(msg, mana), che)
        end
    end
end

-- Commands     кто то должен тут приьраться
SLASH_MANA1 = "/mana"   -- выводит меню аддона в чат
function SlashCmdList.MANA()
    print("-------OutOfMana3-------")
    if mpThreshold == 0 then
        print("Лимит: |c00fc4103" .. mpThreshold .. "%, оповещения выключены|r (\"|c0003fc07/mmth число|r\" для изменения. |c00fc41030 = выкл|r)")
    else
        print("Лимит: |c0003fc07" .. mpThreshold .. "%" .. "|r (\"|c0003fc07/mmth число|r\" для изменения. |c00fc41030 = выкл|r)")
    end
    print("Сообщение малой маны: |c0003fc07" .. message .. "|r. (\"|c0003fc07/mmsg сообщение|r\" с параметром \"|c0003fc07%s%%|r\" для изменения)")
    print("Сообщение конца маны: |c0003fc07" .. message_end .. "|r. (\"|c0003fc07/mmsge сообщение|r\" для изменения)")
    print("-------OutOfMana3-------")
end

SLASH_MHT1 = "/mmth"    -- команда настройки порога маны
function SlashCmdList.MHT(msg)
    if msg ~= "" then 
        mpThreshold = tonumber(msg)
        if mpThreshold == 0 then
            print("Установлен лимит в: |c00fc4103" .. mpThreshold .. "%, оповещения выключены|r")
        else
            print("Установлен лимит в: |c0003fc07" .. mpThreshold .. "%|r")
        end
        if (mpThreshold + antiSpamThresholdValue > 100) then
            antiSpamThreshold = 100
        else
            antiSpamThreshold = mpThreshold + antiSpamThresholdValue
        end
    else 
        if mpThreshold == 0 then
            print("Лимит: |c00fc4103" .. mpThreshold .. "%, оповещения выключены|r (\"|c0003fc07/mmth число|r\" для изменения. |c00fc41030 = выкл|r)")
        else
            print("Лимит: |c0003fc07" .. mpThreshold .. "%" .. "|r (\"|c0003fc07/mmth число|r\" для изменения. |c00fc41030 = выкл|r)")
        end
    end
end

SLASH_MSG1 = "/mmsg"    -- команда настройки сообщения порога маны
function SlashCmdList.MSG(msg)
    if msg ~= "" then
        if string.find(msg, "%s%%") then
            message = msg
            print("|c0003fc07Новое сообщение установлено!|r")
        else
            print("|c00fc4103Сообщение не установлено, не найден параметр %s%%!|r")
        end
    else
        print("Сообщение: |c0003fc07" .. message .. "|r. (\"|c0003fc07/mmsg сообщение|r\" с параметром \"|c0003fc07%s%%|r\" для изменения)")
    end
end

SLASH_MSGE1 = "/mmsge"  -- команда настройки сообщения о пустой мане
function SlashCmdList.MSGE(msg)
    if msg ~= "" then
        message_end = msg
        print("|c0003fc07Новое сообщение установлено!|r")
    else
        print("Сообщение: |c0003fc07" .. message_end .. "|r. (\"|c0003fc07/mmsge сообщение|r\" с параметром для изменения)")
    end
end