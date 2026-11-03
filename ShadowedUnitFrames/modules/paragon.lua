-- SingleWoW paragon numbers for the [paragon] tag.
-- Server pushes CHAT_MSG_ADDON: prefix SWParagonOf, payload "Name;level".
-- Ask for any player unit (party/raid/target/ToT/focus) by whispering self SWParagonOf | Name.
local Paragon = {}
local cache = {}
local requested = {}
local taggedFrames = {}
local tagRegistered
local lastHello = 0

ShadowUF.Paragon = Paragon

local REQUEST_WAIT = 8
local HELLO_WAIT = 3

local function IsPlayerUnit(unit)
	return unit and UnitExists(unit) and UnitIsPlayer(unit)
end

local function NormName(name)
	if( not name or name == "" ) then
		return
	end
	return string.lower(name)
end

local function CacheLevel(name, level)
	level = tonumber(level)
	name = NormName(name)
	if( level == nil or level < 0 or not name ) then
		return
	end
	cache[name] = level
	return level
end

local function ParseParagonOf(prefix, message)
	prefix = prefix or ""
	message = message or ""
	local blob = prefix
	if( message ~= "" ) then
		blob = prefix .. " | " .. message
	end

	local name, level = string.match(blob, "SWParagonOf%s*|%s*([^;]+);(%-?%d+)")
	if( not name and ( prefix == "SWParagonOf" or prefix == "SingleWoWParagon" or prefix == "SWParagon" ) ) then
		name, level = string.match(message, "^([^;]+);(%-?%d+)")
	end
	if( name ) then
		name = strtrim(name)
	end
	return name, level
end

local function SendHello()
	local now = GetTime()
	if( ( now - lastHello ) < HELLO_WAIT ) then
		return
	end
	lastHello = now
	local me = UnitName("player")
	if( me and SendAddonMessage ) then
		SendAddonMessage("SWHello", "1", "WHISPER", me)
	end
end

function Paragon:RequestIfNeeded(unit)
	if( not IsPlayerUnit(unit) or not SendAddonMessage ) then
		return
	end
	local name = UnitName(unit)
	local key = NormName(name)
	if( not key ) then
		return
	end
	if( cache[key] ~= nil ) then
		return
	end
	local now = GetTime()
	if( requested[key] and ( now - requested[key] ) < REQUEST_WAIT ) then
		return
	end
	requested[key] = now
	local me = UnitName("player")
	if( me ) then
		SendAddonMessage("SWParagonOf", name, "WHISPER", me)
	end
end

function Paragon:RequestVisible()
	SendHello()
	for frame in pairs(taggedFrames) do
		self:RequestIfNeeded(frame.unitOwner or frame.unit)
	end
	self:RequestIfNeeded("player")
	self:RequestIfNeeded("target")
	self:RequestIfNeeded("focus")
	self:RequestIfNeeded("targettarget")
	self:RequestIfNeeded("focustarget")
end

function Paragon:GetLevel(unit)
	if( not IsPlayerUnit(unit) ) then
		return
	end
	self:RequestIfNeeded(unit)
	local level = cache[NormName(UnitName(unit)) or ""]
	if( level ~= nil ) then
		return level
	end
	-- Unknown player: show 0 until SWParagonOf arrives (party/raid/target/ToT included).
	return 0
end

function Paragon:GetLevelText(unit, wrap)
	local level = self:GetLevel(unit)
	if( level == nil ) then
		return
	end
	if( wrap ) then
		return "(" .. tostring(level) .. ")"
	end
	return tostring(level)
end

function Paragon:UpdateTaggedFrames()
	if( not tagRegistered ) then
		return
	end

	for frame in pairs(taggedFrames) do
		if( frame.fontStrings ) then
			for _, fontString in pairs(frame.fontStrings) do
				if( fontString.PARAGON and fontString.UpdateTags ) then
					fontString:UpdateTags()
				end
			end
		end
	end
end

function Paragon:EnableTag(frame)
	if( not self:RegisterTag() ) then
		return
	end

	taggedFrames[frame] = true
	frame.hasParagonTag = true
	self:EnsureListener()
	self:RequestIfNeeded(frame.unitOwner or frame.unit)
end

function Paragon:DisableTag(frame)
	if( frame.fontStrings ) then
		for _, fontString in pairs(frame.fontStrings) do
			if( fontString.PARAGON ) then
				return
			end
		end
	end

	frame.hasParagonTag = nil
	taggedFrames[frame] = nil
end

function Paragon:EnsureListener()
	if( self.listener ) then
		return
	end

	local frame = CreateFrame("Frame")
	self.listener = frame
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	frame:RegisterEvent("RAID_ROSTER_UPDATE")
	frame:RegisterEvent("UNIT_TARGET")
	frame:SetScript("OnEvent", function(_, event, prefix, message)
		if( event == "CHAT_MSG_ADDON" ) then
			local name, level = ParseParagonOf(prefix, message)
			if( name and CacheLevel(name, level) ~= nil ) then
				Paragon:UpdateTaggedFrames()
			end
			return
		end
		if( event == "UNIT_TARGET" and prefix ~= "target" and prefix ~= "focus" and prefix ~= "player" ) then
			return
		end
		Paragon:RequestVisible()
		Paragon:UpdateTaggedFrames()
	end)

	local me = UnitName("player")
	if( me ) then
		CacheLevel(me, 0)
	end
	SendHello()
	self:RequestVisible()
	self:UpdateTaggedFrames()
end

function Paragon:RegisterTag()
	if( tagRegistered ) then
		return true
	end

	local Tags = ShadowUF.Tags
	local L = ShadowUF.L
	Tags.customEvents["PARAGON"] = Paragon
	-- [paragon] → 12   [()paragon] → (12)   both with no leading space
	Tags.defaultTags["paragon"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		return Paragon:GetLevelText(unitOwner)
	end]]
	Tags.defaultTags["()paragon"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		return Paragon:GetLevelText(unitOwner, true)
	end]]
	Tags.defaultEvents["paragon"] = "PARAGON PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PARTY_MEMBERS_CHANGED RAID_ROSTER_UPDATE"
	Tags.defaultEvents["()paragon"] = "PARAGON PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PARTY_MEMBERS_CHANGED RAID_ROSTER_UPDATE"
	Tags.defaultCategories["paragon"] = "classification"
	Tags.defaultCategories["()paragon"] = "classification"
	Tags.defaultHelp["paragon"] = L["Shows the units SingleWoW Paragon level if the server has sent it. Only shown for players, not NPCs or mobs."]
	Tags.defaultHelp["()paragon"] = L["Same as [paragon], but wraps the number in parentheses, for example (12). No space before it."]
	Tags.defaultNames["paragon"] = L["Paragon"]
	Tags.defaultNames["()paragon"] = L["Paragon (parentheses)"]

	if( ShadowUF.tagFunc ) then
		ShadowUF.tagFunc["paragon"] = nil
		ShadowUF.tagFunc["()paragon"] = nil
		ShadowUF.tagFunc["paragon()"] = nil
	end
	Tags.defaultTags["paragon()"] = nil
	Tags.defaultEvents["paragon()"] = nil
	Tags.defaultCategories["paragon()"] = nil
	Tags.defaultHelp["paragon()"] = nil
	Tags.defaultNames["paragon()"] = nil

	tagRegistered = true
	self:EnsureListener()
	return true
end

Paragon:RegisterTag()
