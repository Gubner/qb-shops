local QBCore = exports['qb-core']:GetCoreObject()
--Events
QBCore.Functions.CreateCallback('qb-shops:server:SetShopInv', function(_,cb)
    local shopInvJson = LoadResourceFile(GetCurrentResourceName(), Config.ShopsInvJsonFile)
    cb(shopInvJson)
end)
RegisterNetEvent('qb-shops:server:SaveShopInv',function()
    if not Config.UseTruckerJob then return end
    local shopinv = {}
    for k, v in pairs(Config.Locations) do
        shopinv[k] = {}
        shopinv[k].products = {}
        for kk, vv in pairs(v.products) do
            shopinv[k].products[kk] = {}
            shopinv[k].products[kk].amount = vv['amount']
        end
    end
    SaveResourceFile(GetCurrentResourceName(), Config.ShopsInvJsonFile, json.encode(shopinv))
end)
RegisterNetEvent('qb-shops:server:UpdateShopItems', function(shop, itemData, amount)
    if not Config.UseTruckerJob then return end
    if not shop or not itemData or not amount then return end
    Config.Locations[shop].products[itemData.slot].amount -= amount
    if Config.Locations[shop].products[itemData.slot].amount < 0 then
        Config.Locations[shop].products[itemData.slot].amount = 0
    end
    TriggerEvent('qb-shops:server:SaveShopInv')
    TriggerClientEvent('qb-shops:client:SetShopItems', -1, shop, Config.Locations[shop].products)
end)
RegisterNetEvent('qb-shops:server:RestockShopItems', function(shop)
    if not shop or not Config.Locations[shop].products then return end
    local randAmount = math.random(10, 50)
    for k in pairs(Config.Locations[shop].products) do
        Config.Locations[shop].products[k].amount += randAmount
    end
    TriggerEvent('qb-shops:server:SaveShopInv')
    TriggerClientEvent('qb-shops:client:RestockShopItems', -1, shop, randAmount)
end)
local ItemList = {
    ["casinochips"] = 1,
}
RegisterNetEvent('qb-shops:server:sellChips', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local xItem = Player.Functions.GetItemByName("casinochips")
    if xItem then
        for k in pairs(Player.PlayerData.items) do
            if Player.PlayerData.items[k] then
                if ItemList[Player.PlayerData.items[k].name] then
                    local price = ItemList[Player.PlayerData.items[k].name] * Player.PlayerData.items[k].amount
                    Player.Functions.RemoveItem(Player.PlayerData.items[k].name, Player.PlayerData.items[k].amount, k)
                    Player.Functions.AddMoney("cash", price, "sold-casino-chips")
                    QBCore.Functions.Notify(src, "You sold your chips for $" .. price)
                    TriggerEvent("qb-log:server:CreateLog", "casino", "Chips", "blue", "**" .. GetPlayerName(src) .. "** got $" .. price .. " for selling the Chips")
                end
            end
        end
    else
        QBCore.Functions.Notify(src, "You have no chips..")
    end
end)
RegisterNetEvent('qb-shops:server:SetShopList',function()
    local shoplist = {}
    local cnt = 0
    for k, v in pairs(Config.Locations) do
        cnt = cnt + 1
        shoplist[cnt] = {}
        shoplist[cnt].name = k
        shoplist[cnt].coords = v.delivery
    end
    TriggerClientEvent('qb-truckerjob:client:SetShopList',-1,shoplist)
end)

--gg edit
local function GetStashItems(stashName) -- taken from qb-inventory\server\main.lua SetupShopItems
	local items = {}
	local result = MySQL.Sync.fetchScalar('SELECT items FROM stashitems WHERE stash = ?', {stashName})
	if result then
		local stashItems = json.decode(result)
		if stashItems then
			for k, item in pairs(stashItems) do
				local itemInfo = QBCore.Shared.Items[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
					}
				end
			end
		end
	end
	return items
end
--

--gg edit
local function RemoveStashItems(shop, stashName, itemName, amount)
	local items = {}
	local result = MySQL.Sync.fetchScalar('SELECT items FROM stashitems WHERE stash = ?', {stashName})
	if result then
		local stashItems = json.decode(result)
		if stashItems then
			for k, item in pairs(stashItems) do
				local itemInfo = QBCore.Shared.Items[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
						info = item.info or "",
						label = itemInfo["label"],
						description = itemInfo["description"] or "",
						weight = itemInfo["weight"],
						type = itemInfo["type"],
						unique = itemInfo["unique"],
						useable = itemInfo["useable"],
						price = item.price,
						image = itemInfo["image"],
						slot = item.slot,
					}
				end
				
				if items[item.slot].name == itemName then
					items[item.slot].amount -= amount
					if items[item.slot].amount < 0 then items[item.slot].amount = 0 end
				end
				
			end
		end
	end
	MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
		['stash'] = stashName,
		['items'] = json.encode(items)
	})
	local jobName = Config.Locations[shop]["job"]
	local currentAmount = 0
	local addAmount = 0
	for k, v in pairs(Config.Locations[shop]["products"]) do
		if v.name == itemName then
			addAmount = math.floor(v.price * amount * 0.5) --Suggest making price of item in config HIGHER than normal on duty price (say 150%), and suggest offduty sale to only get part of the sale (say 50%). This means -> $100 * 150% = $150 sell price; $150 * 50% = $75 received
		end
	end
	local results = MySQL.Sync.fetchScalar('SELECT amount FROM management_funds WHERE job_name = ?', {jobName})
	if results then
		currentAmount = tonumber(results)
	end
	local newAmount = currentAmount + addAmount
	MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount', {
		['job_name'] = 'burgershot',
		['amount'] = newAmount,
		['type'] = 'boss'
	})
end
--


--Off Duty Shops-- gg edit

local DutyCount = {}

RegisterNetEvent('qb-shops:server:UpdateDutyCount')
AddEventHandler('qb-shops:server:UpdateDutyCount', function()
	UpdateDutyCount()
end)

RegisterNetEvent('QBCore:Server:OnJobUpdate')
AddEventHandler('QBCore:Server:OnJobUpdate', function()
	Wait(3000) -- wait for QBCore:Server:OnJobUpdate to complete
	UpdateDutyCount()
end)

RegisterNetEvent('QBCore:ToggleDuty')
AddEventHandler('QBCore:ToggleDuty', function()
	Wait(3000) -- wait for QBCore:ToggleDuty to complete
	UpdateDutyCount()
end)

RegisterNetEvent('playerDropped')
AddEventHandler('playerDropped', function()
	Wait(3000) -- wait for qbcore updates
	UpdateDutyCount()
end)

function UpdateDutyCount()
	DutyCount = {}
	for k, v in pairs(Config.Locations) do
		if v.type == "offduty" then
			local count = QBCore.Functions.GetDutyCount(k)
			DutyCount[k] = count
		end
	end
	TriggerClientEvent('qb-shops:client:UpdateDutyCount', -1, DutyCount)
end
