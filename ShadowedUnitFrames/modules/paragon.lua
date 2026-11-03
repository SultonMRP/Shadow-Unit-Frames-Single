-- SingleWoW [paragon] only. Do not read AethroParagon, UIParagon, ParagonCharacterLevel,
-- ParagonTargetLevel, SendClientRequest, or ParagonAnniversary.
local Paragon = {}
local cache = {}
local known = {}
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
	local changed = cache[name] ~= level
	cache[name] = level
	known[name] = true
	return level, changed
end

local BindOfficial, HarvestOfficial, ScanBoardUI

local OFFICIAL_METHODS = {
	"GetLevel", "GetParagonLevel", "GetParagon", "GetUnitParagon",
	"GetPlayerLevel", "GetUnitLevel", "Level",
}
local OFFICIAL_TABLES = {
	"levels", "cache", "paragon", "paragons", "players", "data",
	"byName", "units", "list", "map", "store",
}

local function OfficialAddon()
	local sw = _G.SingleWoWParagon
	if( type(sw) == "table" ) then
		return sw
	end
	if( LibStub ) then
		local Ace = LibStub("AceAddon-3.0", true)
		if( Ace and Ace.GetAddon ) then
			local ok, addon = pcall(Ace.GetAddon, Ace, "SingleWoWParagon", true)
			if( ok and type(addon) == "table" ) then
				return addon
			end
		end
	end
end

local function NumberFrom(value)
	if( type(value) == "number" ) then
		return value
	end
	if( type(value) == "string" ) then
		return tonumber(value)
	end
	if( type(value) == "table" ) then
		return tonumber(value.level or value.paragon or value.lvl or value.value or value[1])
	end
end

local function LookupName(tbl, name, depth, seen)
	if( type(tbl) ~= "table" or not name or ( depth or 0 ) > 4 ) then
		return
	end
	seen = seen or {}
	if( seen[tbl] ) then
		return
	end
	seen[tbl] = true

	local n = NumberFrom(tbl[name] or tbl[string.lower(name)] or tbl[string.upper(name)])
	if( n ~= nil ) then
		return n
	end
	if( type(tbl.profile) == "table" ) then
		n = LookupName(tbl.profile, name, ( depth or 0 ) + 1, seen)
		if( n ~= nil ) then
			return n
		end
	end
	if( type(tbl.char) == "table" ) then
		n = LookupName(tbl.char, name, ( depth or 0 ) + 1, seen)
		if( n ~= nil ) then
			return n
		end
	end
	for i = 1, #OFFICIAL_TABLES do
		local child = tbl[OFFICIAL_TABLES[i]]
		if( type(child) == "table" ) then
			n = LookupName(child, name, ( depth or 0 ) + 1, seen)
			if( n ~= nil ) then
				return n
			end
		end
	end
end

local function ReadOfficial(unit)
	local sw = OfficialAddon()
	if( type(sw) ~= "table" ) then
		return
	end
	for i = 1, #OFFICIAL_METHODS do
		local fn = sw[OFFICIAL_METHODS[i]]
		if( type(fn) == "function" ) then
			local ok, ret = pcall(fn, sw, unit)
			local n = ok and NumberFrom(ret)
			if( n == nil and ok ) then
				ok, ret = pcall(fn, sw, UnitName(unit))
				n = ok and NumberFrom(ret)
			end
			if( n ~= nil ) then
				return n
			end
		end
	end
	local fromSw = LookupName(sw, UnitName(unit), 0)
	if( fromSw ~= nil ) then
		return fromSw
	end
	if( type(sw.db) == "table" ) then
		return LookupName(sw.db, UnitName(unit), 0)
	end
end

function HarvestOfficial()
	BindOfficial()
	local level = ReadOfficial("player")
	if( level ~= nil ) then
		local _, did = CacheLevel(UnitName("player"), level)
		if( did ) then
			Paragon:UpdateTaggedFrames()
		end
	end
end

function BindOfficial()
	local sw = OfficialAddon()
	if( type(sw) ~= "table" or sw.__sufParagonBound ) then
		return
	end
	sw.__sufParagonBound = true
	if( not hooksecurefunc ) then
		return
	end
	for key, value in pairs(sw) do
		if( type(value) == "function" and string.find(key, "Update", 1, true) ) then
			hooksecurefunc(sw, key, function()
				Paragon:UpdateTaggedFrames()
			end)
		end
	end
end

local function ParseParagonOf(prefix, message)
	prefix = prefix or ""
	message = message or ""
	if( not string.find(prefix, "SWParagonOf", 1, true) ) then
		return
	end
	local name, level = string.match(message, "^([^;]+);(%-?%d+)")
	if( name ) then
		name = strtrim(name)
	end
	return name, tonumber(level)
end

-- Board reply: "0;32:9" = 0 unspent + 9 spent = Paragon 9 (matches the green "PARAGON 9").
local function ParseSWBoard(prefix, message)
	if( prefix ~= "SWBoard" ) then
		return
	end
	message = message or ""
	if( message == "" or message == "get" or message == "open" or string.find(message, "^%a") ) then
		return
	end
	local unspent = tonumber(string.match(message, "^(%-?%d+)"))
	if( unspent == nil ) then
		return
	end
	local total = unspent
	for pts in string.gmatch(message, ":(%-?%d+)") do
		total = total + (tonumber(pts) or 0)
	end
	return total
end

local function StripColors(text)
	text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	return text
end

-- Green label on the board: "PARAGON 9". Skip the window title "PARAGON BOARD".
local function LevelFromBoardText(text)
	if( type(text) ~= "string" ) then
		return
	end
	text = StripColors(text)
	if( string.find(string.lower(text), "board", 1, true) ) then
		return
	end
	return tonumber(string.match(text, "[Pp][Aa][Rr][Aa][Gg][Oo][Nn]%s+(%d+)"))
end

local function RememberPlayer(level)
	local me = UnitName("player")
	if( me and CacheLevel(me, level) ~= nil ) then
		Paragon:UpdateTaggedFrames()
	end
end

local function HookBoardFontString(fs)
	if( not fs or fs.SUFParagonBoardHook or not fs.SetText ) then
		return
	end
	fs.SUFParagonBoardHook = true
	if( hooksecurefunc ) then
		hooksecurefunc(fs, "SetText", function(_, text)
			local level = LevelFromBoardText(text)
			if( level ~= nil ) then
				RememberPlayer(level)
			end
		end)
	end
	local level = LevelFromBoardText(fs:GetText())
	if( level ~= nil ) then
		RememberPlayer(level)
	end
end

local function ScanFrameText(frame, depth)
	if( not frame or ( depth or 0 ) > 8 ) then
		return
	end
	if( frame.GetObjectType ) then
		local ok, kind = pcall(frame.GetObjectType, frame)
		if( ok and kind == "FontString" ) then
			if( LevelFromBoardText(frame:GetText()) ~= nil ) then
				HookBoardFontString(frame)
			end
		end
	end
	if( frame.GetRegions ) then
		local regions = { frame:GetRegions() }
		for i = 1, #regions do
			local region = regions[i]
			if( region and region.GetObjectType and region:GetObjectType() == "FontString" ) then
				if( LevelFromBoardText(region:GetText()) ~= nil ) then
					HookBoardFontString(region)
				end
			end
		end
	end
	if( frame.GetChildren ) then
		local kids = { frame:GetChildren() }
		for i = 1, #kids do
			ScanFrameText(kids[i], ( depth or 0 ) + 1)
		end
	end
end

function ScanBoardUI()
	for key, value in pairs(_G) do
		if( type(key) == "string" and type(value) == "table" and value.GetObjectType ) then
			local lower = string.lower(key)
			if( string.find(lower, "paragon", 1, true) or string.find(lower, "swboard", 1, true) ) then
				local ok, kind = pcall(value.GetObjectType, value)
				if( ok and ( kind == "Frame" or kind == "Button" ) ) then
					ScanFrameText(value, 0)
				end
			end
		end
	end
end

-- SingleWoWParagon tooltip: "Paragon 9" (sometimes colored). Not Aethro "Paragon:".
local function ParseSWTipParagon(text)
	if( type(text) ~= "string" ) then
		return
	end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	-- Require "Paragon 12", not Aethro-style "Paragon: 12"
	local level = string.match(text, "[Pp]aragon%s+(%d+)")
	return tonumber(level)
end

local function CacheFromTooltip(tip)
	if( not tip or not tip.NumLines ) then
		return
	end
	local tipName, unit
	if( tip.GetUnit ) then
		tipName, unit = tip:GetUnit()
	end
	local who
	if( unit and UnitIsPlayer(unit) ) then
		who = UnitName(unit)
	elseif( tipName and ( not unit or UnitIsPlayer(unit) ) ) then
		who = tipName
	end
	if( not who ) then
		return
	end
	local tipFrameName = tip:GetName() or "GameTooltip"
	for i = 1, tip:NumLines() do
		local line = _G[tipFrameName .. "TextLeft" .. i]
		local right = _G[tipFrameName .. "TextRight" .. i]
		local level = ParseSWTipParagon(line and line:GetText() or "")
		if( level == nil and right ) then
			level = ParseSWTipParagon((line and line:GetText() or "") .. " " .. (right:GetText() or ""))
		end
		if( level ~= nil ) then
			if( CacheLevel(who, level) ~= nil ) then
				Paragon:UpdateTaggedFrames()
			end
			return
		end
	end
end

local function HookTooltip(tip)
	if( not tip or tip.SUFParagonHooked ) then
		return
	end
	tip.SUFParagonHooked = true

	local function Remember(text, right)
		local level = ParseSWTipParagon(tostring(text or "") .. " " .. tostring(right or ""))
		if( level == nil ) then
			return
		end
		local tipName, unit = tip:GetUnit()
		local who = (unit and UnitIsPlayer(unit) and UnitName(unit)) or tipName
		if( who and CacheLevel(who, level) ~= nil ) then
			Paragon:UpdateTaggedFrames()
		end
	end

	if( hooksecurefunc ) then
		hooksecurefunc(tip, "AddLine", function(_, text)
			Remember(text)
		end)
		hooksecurefunc(tip, "AddDoubleLine", function(_, left, right)
			Remember(left, right)
		end)
	end
	if( tip.HookScript ) then
		tip:HookScript("OnShow", function(self)
			CacheFromTooltip(self)
		end)
		tip:HookScript("OnTooltipSetUnit", function(self)
			CacheFromTooltip(self)
		end)
	end
end

-- Same handshake ChatTrace logged from SingleWoWParagon: prefix SWHello, payload 1.
local function SendHello()
	local me = UnitName("player")
	if( me and SendAddonMessage ) then
		SendAddonMessage("SWHello", "1", "WHISPER", me)
		SendAddonMessage("SWBoard", "get", "WHISPER", me)
	end
end

local function IsSelfUnit(unit)
	return unit and UnitExists(unit) and UnitIsUnit(unit, "player")
end

function Paragon:GetLevel(unit)
	if( not IsSelfUnit(unit) ) then
		return
	end
	local name = UnitName(unit)
	local official = ReadOfficial(unit)
	if( official ~= nil ) then
		CacheLevel(name, official)
		return official
	end
	if( GameTooltip and GameTooltip:IsShown() ) then
		CacheFromTooltip(GameTooltip)
	end
	local key = NormName(name)
	return key and cache[key]
end

function Paragon:GetLevelText(unit, wrap)
	local level = tonumber(self:GetLevel(unit))
	if( type(level) ~= "number" or level < 1 ) then
		level = 0
	end
	if( wrap ) then
		return "(" .. tostring(level) .. ")"
	end
	return tostring(level)
end

function Paragon:UpdateTaggedFrames()
	if( not tagRegistered or self.updating ) then
		return
	end
	self.updating = true
	for frame in pairs(taggedFrames) do
		if( frame.fontStrings ) then
			for _, fontString in pairs(frame.fontStrings) do
				if( fontString.PARAGON and fontString.UpdateTags ) then
					fontString:UpdateTags()
				end
			end
		end
	end
	self.updating = nil
end

function Paragon:EnableTag(frame)
	if( frame.unitType and frame.unitType ~= "player" ) then
		return
	end
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
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	frame:RegisterEvent("RAID_ROSTER_UPDATE")
	frame.elapsed = 0
	frame.boardElapsed = 0
	frame:SetScript("OnEvent", function(_, event, prefix, message)
		if( event == "ADDON_LOADED" and ( prefix == "SingleWoWParagon" or prefix == "ShadowedUnitFrames" ) ) then
			BindOfficial()
			HarvestOfficial()
			return
		end
		if( event == "CHAT_MSG_ADDON" ) then
			prefix = prefix or arg1
			message = message or arg2
			local board = ParseSWBoard(prefix, message)
			if( board ~= nil ) then
				RememberPlayer(board)
			end
			local name, level = ParseParagonOf(prefix, message)
			if( name and CacheLevel(name, level) ~= nil ) then
				Paragon:UpdateTaggedFrames()
			end
			HarvestOfficial()
			ScanBoardUI()
			return
		end
		if( event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" ) then
			SendHello()
			BindOfficial()
			Paragon:StripOtherFrames()
		end
		if( GameTooltip ) then
			CacheFromTooltip(GameTooltip)
		end
		HarvestOfficial()
		Paragon:UpdateTaggedFrames()
	end)
	frame:SetScript("OnUpdate", function(self, dt)
		self.elapsed = self.elapsed + dt
		self.boardElapsed = self.boardElapsed + dt
		if( self.elapsed >= 0.25 ) then
			self.elapsed = 0
			HarvestOfficial()
			if( GameTooltip and GameTooltip:IsShown() ) then
				CacheFromTooltip(GameTooltip)
			end
		end
		if( self.boardElapsed >= 1 ) then
			self.boardElapsed = 0
			ScanBoardUI()
		end
	end)

	HookTooltip(GameTooltip)
	if( ItemRefTooltip ) then
		HookTooltip(ItemRefTooltip)
	end
	BindOfficial()
	HarvestOfficial()
	self:StripOtherFrames()
	if( IsLoggedIn() ) then
		SendHello()
	end
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
	Tags.defaultTags["()paragon"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		return Paragon:GetLevelText(unitOwner, true)
	end]]
	Tags.defaultEvents["paragon"] = "PARAGON PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PARTY_MEMBERS_CHANGED RAID_ROSTER_UPDATE"
	Tags.defaultEvents["()paragon"] = "PARAGON PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PARTY_MEMBERS_CHANGED RAID_ROSTER_UPDATE"
	Tags.defaultCategories["paragon"] = "classification"
	Tags.defaultCategories["()paragon"] = "classification"
	Tags.unitRestrictions["paragon"] = "player"
	Tags.unitRestrictions["()paragon"] = "player"
	Tags.defaultHelp["paragon"] = L["Shows your SingleWoW Paragon level on the player frame."]
	Tags.defaultHelp["()paragon"] = L["Same as [paragon], but wraps the number in parentheses, for example (12). No space before it. Player frame only."]
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
	self:StripOtherFrames()
	return true
end

function Paragon:StripOtherFrames()
	local units = ShadowUF.db and ShadowUF.db.profile and ShadowUF.db.profile.units
	if( type(units) ~= "table" ) then
		return
	end
	for unit, config in pairs(units) do
		if( unit ~= "player" and type(config) == "table" and type(config.text) == "table" ) then
			for _, row in pairs(config.text) do
				if( type(row) == "table" and type(row.text) == "string" ) then
					local text = row.text
					text = string.gsub(text, "%[paragon%]", "")
					text = string.gsub(text, "%[%(%)paragon%]", "")
					text = string.gsub(text, "  ", " ")
					if( string.trim ) then
						text = string.trim(text)
					end
					row.text = text
				end
			end
		end
	end
end

Paragon:RegisterTag()
