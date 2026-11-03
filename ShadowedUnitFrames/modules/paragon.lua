-- SingleWoW paragon numbers for the [paragon] tag.
-- Server pushes CHAT_MSG_ADDON: prefix SWParagonOf, payload "Name;level".
-- SingleWoWParagon (official UI) sends SWHello | 1 to start that stream.
local Paragon = {}
local cache = {}
local taggedFrames = {}
local tagRegistered

ShadowUF.Paragon = Paragon

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
	local payload = message
	if( prefix == "SWParagonOf" ) then
		payload = message
	elseif( prefix == "SingleWoWParagon" or prefix == "SWParagon" ) then
		payload = string.match(message or "", "^SWParagonOf%s*|%s*(.+)$")
	else
		return
	end
	if( not payload ) then
		return
	end
	local name, level = string.match(payload, "^([^;]+);(%-?%d+)")
	if( name ) then
		name = strtrim(name)
	end
	return name, level
end

function Paragon:GetLevel(unit)
	if( not IsPlayerUnit(unit) ) then
		return
	end
	local level = cache[NormName(UnitName(unit)) or ""]
	if( level ~= nil ) then
		return level
	end
	-- Fresh 80s often have no SWParagonOf yet. Show 0 on yourself until the server sends a number.
	if( UnitIsUnit(unit, "player") ) then
		return 0
	end
end

function Paragon:GetLevelText(unit)
	local level = self:GetLevel(unit)
	if( level == nil ) then
		return
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
	frame:SetScript("OnEvent", function(_, _, prefix, message)
		local name, level = ParseParagonOf(prefix, message)
		if( name and CacheLevel(name, level) ~= nil ) then
			Paragon:UpdateTaggedFrames()
		end
	end)

	local me = UnitName("player")
	if( me ) then
		CacheLevel(me, 0)
	end
	-- Official SingleWoWParagon already handshakes. If it is missing, start the stream ourselves.
	if( not IsAddOnLoaded("SingleWoWParagon") and me and SendAddonMessage ) then
		SendAddonMessage("SWHello", "1", "WHISPER", me)
	end
	self:UpdateTaggedFrames()
end

function Paragon:RegisterTag()
	if( tagRegistered ) then
		return true
	end

	local Tags = ShadowUF.Tags
	local L = ShadowUF.L
	Tags.customEvents["PARAGON"] = Paragon
	Tags.defaultTags["paragon"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		return Paragon:GetLevelText(unitOwner)
	end]]
	Tags.defaultEvents["paragon"] = "PARAGON PLAYER_TARGET_CHANGED"
	Tags.defaultCategories["paragon"] = "classification"
	Tags.defaultHelp["paragon"] = L["Shows the units SingleWoW Paragon level if the server has sent it. Only shown for players, not NPCs or mobs."]
	Tags.defaultNames["paragon"] = L["Paragon"]

	if( ShadowUF.tagFunc ) then
		ShadowUF.tagFunc["paragon"] = nil
	end

	-- Old Aethro copy registered a second [paragon()] checkbox that SUF treats as the same tag.
	Tags.defaultTags["paragon()"] = nil
	Tags.defaultEvents["paragon()"] = nil
	Tags.defaultCategories["paragon()"] = nil
	Tags.defaultHelp["paragon()"] = nil
	Tags.defaultNames["paragon()"] = nil
	if( ShadowUF.tagFunc ) then
		ShadowUF.tagFunc["paragon()"] = nil
	end

	tagRegistered = true
	self:EnsureListener()
	return true
end

Paragon:RegisterTag()
