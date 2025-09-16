-- made ts shi cuz im lwkey dont want to use profile store or profile service type shi, im prob using it for every game i make since its de cool

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local DataStore : DataStore
local DATA_PROFILE: string
local PlayerCache = {}
local DefaultValues = {}
local InfoStore = {}

local function resolvePath(tbl, path) -- for deeply neested tab
	local parts = string.split(path, ".")
	for i = 1, #parts - 1 do
		tbl = tbl[parts[i]]
		if type(tbl) ~= "table" then
			return nil, "Invalid path"
		end
	end
	return tbl, parts[#parts]
end

local function Copy(tbl) -- to copy a table since apparently, attributing a table to another one will link both (idk if its true, correct me if im wrong)
	local copy
	if type(tbl) == "table" then
		copy = {}
		for key, value in pairs(tbl) do
			copy[Copy(key)] = Copy(value)
		end
	else
		copy = tbl
	end
	return copy
end


local function Check(player: Player) -- the obvious
	if not RunService:IsServer() then error(script.Name.. " Can't fire a function called from a local script, " ..debug.traceback()) end
	if player == nil then return end
	if not PlayerCache[player.UserId] then warn(script.Name.. " Is not in the cache, please initialize the script, " ..debug.traceback()) end
end

local function DeleteTempData(player: Player)
	PlayerCache[player.UserId] = nil
end


function InfoStore:GlobalInit(profileName: string, values: {}) -- Run it once on server
	Check()
	if DATA_PROFILE ~= nil then warn("Datastores have been already initialized for server, traceback: " ..debug.traceback()) end
	DATA_PROFILE = profileName
	DataStore = DataStoreService:GetDataStore(DATA_PROFILE)
	DefaultValues = values
	PlayerService.PlayerRemoving:Connect(function(plr) -- Don't need to save the data manually dw <3
		InfoStore:SaveDataStore(plr)
		DeleteTempData(plr)
	end)
end

function InfoStore:PlayerInit(player: Player) -- Still need to load the data manually tho (run it for every player that joins)
	Check()
	local key = DATA_PROFILE.. "_" ..player.UserId
	local success, data = pcall(function()
		return DataStore:GetAsync(key)
	end)
	if not success then player:Kick("Failed to load data, please rejoin.") InfoStore:DeleteTempData(player) return end
	if data then
		PlayerCache[player.UserId] = data
	else
		PlayerCache[player.UserId] = Copy(DefaultValues)
	end
end

function InfoStore:SetValue(player: Player, valueName, value) -- to modify a value type shi
	Check(player)
	local data = PlayerCache[player.UserId]
	local tbl, key = resolvePath(data, valueName)
	if tbl and key then
		tbl[key] = value
	end
end

function InfoStore:GetValue(player: Player, Value) -- the obvious x2
	Check(player)
	local data = PlayerCache[player.UserId]
	local tbl, key = resolvePath(data, Value)
	if tbl and key then
		return tbl[key]
	end
end

function InfoStore:SaveDataStore(player: Player) -- the obvious x3
	Check(player)
	local key = DATA_PROFILE.. "_" ..player.UserId
	local success, err = pcall(function()
		DataStore:SetAsync(key, PlayerCache[player.UserId])
	end)
	if not success then warn("Data of " ..player.Name.. " Have not been saved due to an error!") return end
end



return InfoStore

-- allat made by BlocksumoGuys/XavierKc624/BSG_DEV (they are all me, just different users)
-- shoutout to rodevs member bcuz cool
