-- This module script is used to store and manage player's data
local DEBUG = false -- This variable is for debugging purposes, you can deactivate it so you don't see any prints
local started = false
-- All the services needed
local DataStoreService = game:GetService("DataStoreService")
local PlayerService = game:GetService("Players")
local HTTPservice = game:GetService("HttpService")

local DataStore : DataStore
local LogStore : DataStore
local DATA_PROFILE: string 
local LogCache = {}
local DefaultValues = {}
local InfoStore = {}

local function resolvePath(tbl, path) -- This function is made to find a certain value in a nested table 
	local parts = string.split(path, ".")
	for i = 1, #parts - 1 do
		tbl = tbl[parts[i]]
		if type(tbl) ~= "table" then
			return nil, "Invalid path"
		end
	end
	return tbl, parts[#parts]
end

local function DeleteTempData(player: Player, self) -- this function is for deleting cache data to free up some memory
	self[player.UserId] = nil
end

local function RetrySave(player: Player, attemptCount: number, self) --This function is for retrying to save the player's data
	local RETRY_ATTEMPTS = attemptCount or 3
	local key = DATA_PROFILE.. "_" ..player.UserId

	for retrys = 1, RETRY_ATTEMPTS do
		local success, err = pcall(function()
			DataStore:SetAsync(key, self[player.UserId])
		end)
		if success then
			if DEBUG then
				warn("Data succesfully saved in " ..retrys.. " attempts")
			end
			return true
		else
			if retrys == RETRY_ATTEMPTS then
				if DEBUG then
					warn("Data failed to save, error: " ..err)
				end
			else
				if DEBUG then
					warn("Data failed to save in " ..retrys.. " attempt, retrying...")
				end
			end
		end
	end
end

local function AutoSave(player: Player, SaveTime: number, self) -- This function is for autosaving the player's data
	local key = DATA_PROFILE.. "_" ..player.UserId
	local SaveTime = SaveTime or 60
	task.spawn(function()
		while self[player.UserId] do
			task.wait(SaveTime)
			local success, err = pcall(function()
				DataStore:SetAsync(key, self[player.UserId])
			end)
			if not success then
				RetrySave(player, 3, self)
			end
		end
	end)
end

local function PlayerInit(player: Player, self) -- This functions if to create/load the player's data
	if DEBUG then
		warn("player" ..player.Name.. "initiated")
	end
	local key = DATA_PROFILE.. "_" ..player.UserId
	local success, data = pcall(function()
		return DataStore:GetAsync(key)
	end)
	if not success then
		player:Kick("Failed to load data, please rejoin.")
		InfoStore:DeleteTempData(player)
		return
	end
	if data then
		self[player.UserId] = data
	else
		self[player.UserId] = table.clone(DefaultValues)
	end
end

function InfoStore:GlobalInit(profileName: string, values: {}, IsAutoSave: boolean, AutoSaveTime: number) -- This function is to initiate the datastore and playeradded/playerremoving events
	if started then
		warn("Datastores have been already initialized for server, traceback: " ..debug.traceback())
	end	
	started = true
	DATA_PROFILE = profileName
	DataStore = DataStoreService:GetDataStore(DATA_PROFILE)
	LogStore = DataStoreService:GetDataStore("LogStore")
	DefaultValues = values
	if DEBUG then
		warn(DATA_PROFILE, DefaultValues)
	end	
	PlayerService.PlayerAdded:Connect(function(plr)
		local key = DATA_PROFILE.. "_" ..plr.UserId
		PlayerInit(plr, self)
		LogCache[plr.UserId] = LogStore:GetAsync(key)
		LogCache[plr.UserId] = os.date()
		if IsAutoSave then
			AutoSave(plr, AutoSaveTime)
		end
	end)
	PlayerService.PlayerRemoving:Connect(function(plr)
		local key = DATA_PROFILE.. "_" ..plr.UserId
		InfoStore:SaveDataStore(plr)
		DeleteTempData(plr, self)
		if DEBUG then
			warn("Data saved and deleted temp data")
		end
	end)
end

function InfoStore:SetValue(player: Player, valueName, value) -- This function is to set a value inside the player's cache
	local data = self[player.UserId]
	local tbl, key = resolvePath(data, valueName)
	if tbl and key then
		tbl[key] = value
	end
	if DEBUG then
		warn(self[player.UserId], DefaultValues)
	end
end

function InfoStore:GetValue(player: Player, Value) -- This function is to get a value inside the player's cache
	local data = self[player.UserId]
	local tbl, key = resolvePath(data, Value)
	if tbl and key then
		if DEBUG then
			warn(tbl, tbl[key])
		end
		return tbl[key]
	end
end

function InfoStore:SaveDataStore(player: Player) -- This function is to save the player's data (datastore and lastlogged)
	local key = DATA_PROFILE.. "_" ..player.UserId
	local success, err = pcall(function()
		DataStore:SetAsync(key, self[player.UserId])
		LogStore:SetAsync(player.UserId, LogCache[player.UserId])
	end)
	if success then
		if DEBUG then
			warn("Player data saved")
		end
	end
	if not success then
		if DEBUG then
			warn("Data of " ..player.Name.. " Have not been saved due to an error! Retrying...")
		end
		RetrySave(player, 3, self)
	end
end

function InfoStore:ExportData(player: Player): string -- This function is to export the player's data as JSON
	if self[player.UserId] then
		if DEBUG then
			warn("Succesfully exported data! Data: " ..HTTPservice:JSONEncode(self[player.UserId]))
		end
		return HTTPservice:JSONEncode(self[player.UserId])
	end
end

function InfoStore:OverwriteData(player: Player, data: {}) -- This function is to overwrite the player's data with another one
	self[player.UserId] = data
	if DEBUG then
		warn("The data of " ..player.Name.. " Have been overwriten!")
	end
end

function InfoStore:DeleteAllData(player: Player) -- This function is to delete all the player's data
	local key = DATA_PROFILE.. "_" ..player.UserId
	self[player.UserId] = nil
	DataStore:SetAsync(key, {})
	if DEBUG then
		warn("Data of " ..player.Name.. " Have been deleted!")
	end
end

function InfoStore:GetOfflinePlayerDataById(userId: Player) -- This function is to get the player's data by their user id
	local key = DATA_PROFILE.. "_" ..userId
	local success, data = pcall(function()
		return DataStore:GetAsync(key)
	end)
	if success then
		if DEBUG then
			warn("Offline data of " ..userId.. " has been loaded!")
		end
	else
		if DEBUG then
			warn("Offline data of " ..userId.. " has not been loaded! Error: " ..data)
		end
	end
end

function InfoStore:GetLastJoinedOfflinePlayer(userId: number) -- This function is to get the last joined time of an offline player
	local success, data = pcall(function()
		return LogStore:GetAsync(userId)
	end)
	if success then
		if DEBUG then
			warn("Log data of " ..userId.. " has been loaded! The User Have Joined on " ..data)
		end
		return data
	else
		if DEBUG then
			warn("Log data of " ..userId.. " has not been loaded! Error: " ..data)
		end
		return nil
	end
end

return InfoStore
-- FURTHER EXPLAINATION
-- How will the data be managed you may ask, first, we need to create a cache, and in this cache,
--	we will put the player's data (if he has any) or create new data for the player, and when the player leaves,
--the cache will be saved in the datastore, the cache will be deleted to save memory, and voila!


-- made by BlocksumoGuys/XavierKc624/BSG_DEV (they are all me, just different users)
-- shoutout to rodevs member bcuz cool
