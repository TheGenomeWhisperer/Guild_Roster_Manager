-- Author: Arkaan
-- Addon Name: "Guild Roster Manager"

local Version = "7.2.5r1.00";
local Patch = "7.2.5";
-- Table to hold all functions
GRM = {};

-- Global tables saved account wide.
-- Just load the settings the first time addon is loaded.
GRM_AddonSettings_Save = {};
GRM_LogReport_Save = {};                 -- This will be the stored Log of events and changes.
GRM_GuildMemberHistory_Save = {}         -- Detailed information on each guild member
GRM_PlayersThatLeftHistory_Save = {};    -- Data storage of all players that left the guild, so metadata is stored if they return. Useful for "rejoin" tracking, and to see if players were banned.
GRM_CalendarAddQue_Save = {};            -- Since the add to calendar is protected, and requires a player input, this will be qued here between sessions. { name , eventTitle , eventMonth , eventDay , eventYear , eventDescription } 

-- slash commands
SLASH_GRM1 = '/roster';

-- Useful Variables ( kept in table to keep low upvalues count )
GR_AddonGlobals = {};
-- Live tracking settings
-- Initialization Useful Globals
-- ADDON
GR_AddonGlobals.addonName = "Guild_Roster_Manager";
-- Player Details
GR_AddonGlobals.guildName = GetGuildInfo ( "PLAYER" );
GR_AddonGlobals.realmName = GetRealmName();
GR_AddonGlobals.addonPlayerName = ( GetUnitName ( "PLAYER" , false ) .. "-" .. GR_AddonGlobals.realmName );
GR_AddonGlobals.faction = UnitFactionGroup ( "PLAYER" );
GR_AddonGlobals.FID = 0;        -- index for Horde = 1; Ally = 2
GR_AddonGlobals.logGID = 0;     -- index of the guild, so no need for repeat lookups.
GR_AddonGlobals.saveGID = 0;    -- Needs a separate GID "Guild Index ID" because it may not match the log index depending on if a log entry is cleared vs guild info, whcih can be separate.
GR_AddonGlobals.setPID = 0;     -- Since settings are player unique, PID = Player ID

-- To ensure frame initialization occurse just once... what a waste in resources otherwise.
GR_AddonGlobals.timeDelayValue = 0;  
GR_AddonGlobals.FramesInitialized = false;
GR_AddonGlobals.OnFirstLoad = true;
GR_AddonGlobals.currentlyTracking = false;
GR_AddonGlobals.trackingTriggered = false;

-- Guild Status holder for checkover.
GR_AddonGlobals.guildStatusChecked = false;

-- Tempt Logs For FinalReport()
GR_AddonGlobals.TempNewMember = {};
GR_AddonGlobals.TempLogPromotion = {};
GR_AddonGlobals.TempInactiveReturnedLog = {};
GR_AddonGlobals.TempEventRecommendKickReport = {};
GR_AddonGlobals.TempLogDemotion = {};
GR_AddonGlobals.TempLogLeveled = {};
GR_AddonGlobals.TempLogNote = {};
GR_AddonGlobals.TempLogONote = {};
GR_AddonGlobals.TempRankRename = {};
GR_AddonGlobals.TempRejoin = {};
GR_AddonGlobals.TempBannedRejoin = {};
GR_AddonGlobals.TempLeftGuild = {};
GR_AddonGlobals.TempNameChanged = {};
GR_AddonGlobals.TempEventReport = {};

-- DropDownMenu Globals for Quick Use
GR_AddonGlobals.tempName = "";
GR_AddonGlobals.rankIndex = 1;
GR_AddonGlobals.playerIndex = -1;
GR_AddonGlobals.monthIndex = 1;
GR_AddonGlobals.yearIndex = 1;
GR_AddonGlobals.dayIndex = 1;

-- Alt Helpers
GR_AddonGlobals.selectedAlt = {};
GR_AddonGlobals.selectedAltList = {};
GR_AddonGlobals.currentHighlightIndex = 1;
-- Guildie info
GR_AddonGlobals.listOfGuildies = {};

-- MISC Globals for resource handling... generally to avoid wasteful checks based on timers, position, pause controls.
GR_AddonGlobals.timer = 0;
GR_AddonGlobals.timer2 = 0; 
GR_AddonGlobals.timer3 = 0;
GR_AddonGlobals.DelayedAtLeastOnce = false;
GR_AddonGlobals.CalendarAddDelay = 0; -- Needs to be at least 5 seconds...
GR_AddonGlobals.RaidGCountBeingChecked = false;
GR_AddonGlobals.timerUIChange = 0;
GR_AddonGlobals.position = 0;
GR_AddonGlobals.pause = false;
GR_AddonGlobals.rankDateSet = false;
GR_AddonGlobals.editPromoDate = false;
GR_AddonGlobals.editJoinDate = false;
GR_AddonGlobals.editFocusPlayer = false;

------------------------
------ FRAMES ----------
------------------------
--------------------------------------
---- UI BUILDING COMPLETELY IN LUA ---
---- FRAMES, FONTS, STYLES, ETC. -----
--------------------------------------

-- Contains the entire UI initialization of frames (no logic details yet)
-- Note: In explanation as to why they are not tabled, but kept in local, Lua allows 200 "locals" to be declared. Locals are insanely fast.
-- While it is probably unnecessary to be concerned about speed, since this is a fairly low-resource cost addon, I am a bit OCD in peaking performance.
-- As such, for the time being, frames will not be tabled to an array, but instead will be kept local for the fastest possible lookups and resource management.
-- This may change in the future, but for now, it is unnecessary.

-- Live Frames
local Initialization = CreateFrame("Frame");
local GeneralEventTracking = CreateFrame("Frame");
local UI_Events = CreateFrame("Frame");

-- Core Frame
local MemberDetailMetaData = CreateFrame( "Frame" , "MemberDetailMetaData" , GuildRosterFrame , "TranslucentFrameTemplate" );
local MemberDetailMetaDataCloseButton = CreateFrame( "Button" , "MemberDetailMetaDataCloseButton" , MemberDetailMetaData , "UIPanelCloseButton");
MemberDetailMetaData:Hide();  -- Prevent error where it sometimes auto-loads.

-- Guild Member Detail Frame UI and Children
local GRM_SetPromoDateButton = CreateFrame ( "Button" , "GRM_SetPromoDateButton" , MemberDetailMetaData , "GameMenuButtonTemplate" );
GRM_SetPromoDateButton.GRM_SetPromoDateButtonText = GRM_SetPromoDateButton:CreateFontString ( "GRM_SetPromoDateButtonText" , "OVERLAY" , "GameFontWhiteTiny" );

local DayDropDownMenuSelected = CreateFrame ( "Frame" , "DayDropDownMenuSelected" , MemberDetailMetaData , "InsetFrameTemplate" );
DayDropDownMenuSelected:Hide();
DayDropDownMenuSelected.DayText = DayDropDownMenuSelected:CreateFontString ( "DayDropDownMenuSelected.DayText" , "OVERLAY" , "GameFontWhiteTiny" );
local DayDropDownMenu = CreateFrame ( "Frame" , "DayDropDownMenu" , DayDropDownMenuSelected , "InsetFrameTemplate" );
local DayDropDownButton = CreateFrame ( "Button" , "DayDropDownButton" , DayDropDownMenuSelected , "UIPanelScrollDownButtonTemplate" );

local YearDropDownMenuSelected = CreateFrame ( "Frame" , "YearDropDownMenuSelected" , MemberDetailMetaData , "InsetFrameTemplate" );
YearDropDownMenuSelected:Hide();
YearDropDownMenuSelected.YearText = YearDropDownMenuSelected:CreateFontString ( "YearDropDownMenuSelected.YearText" , "OVERLAY" , "GameFontWhiteTiny" );
local YearDropDownMenu = CreateFrame ( "Frame" , "YearDropDownMenu" , YearDropDownMenuSelected , "InsetFrameTemplate" );
local YearDropDownButton = CreateFrame ( "Button" , "YearDropDownButton" , YearDropDownMenuSelected , "UIPanelScrollDownButtonTemplate" );

local MonthDropDownMenuSelected = CreateFrame ( "Frame" , "MonthDropDownMenuSelected" , MemberDetailMetaData , "InsetFrameTemplate" );
MonthDropDownMenuSelected:Hide();
MonthDropDownMenuSelected.MonthText = MonthDropDownMenuSelected:CreateFontString ( "MonthDropDownMenuSelected.MonthText" , "OVERLAY" , "GameFontWhiteTiny" );
local MonthDropDownMenu = CreateFrame ( "Frame" , "MonthDropDownMenu" , MonthDropDownMenuSelected , "InsetFrameTemplate" );
local MonthDropDownButton = CreateFrame ( "Button" , "MonthDropDownButton" , MonthDropDownMenuSelected , "UIPanelScrollDownButtonTemplate" );

-- SUBMIT BUTTONS
local DateSubmitButton = CreateFrame ( "Button" , "DateSubmitButton" , MemberDetailMetaData , "UIPanelButtonTemplate" );
local DateSubmitCancelButton = CreateFrame ( "Button" , "DateSubmitCancelButton" , MemberDetailMetaData , "UIPanelButtonTemplate" );
local DateSubmitButtonTxt = DateSubmitButton:CreateFontString ( "DateSubmitButtonTxt" , "OVERLAY" , "GameFontWhiteTiny" );
local DateSubmitCancelButtonTxt = DateSubmitCancelButton:CreateFontString ( "DateSubmitCancelButtonTxt" , "OVERLAY" , "GameFontWhiteTiny" );

-- RANK DROPDOWN
local guildRankDropDownMenuSelected = CreateFrame ( "Frame" , "guildRankDropDownMenuSelected" , MemberDetailMetaData , "InsetFrameTemplate" );
guildRankDropDownMenuSelected:Hide();
guildRankDropDownMenuSelected.RankText = guildRankDropDownMenuSelected:CreateFontString ( "guildRankDropDownMenuSelected.RankText" , "OVERLAY" , "GameFontWhiteTiny" );
local RankDropDownMenu = CreateFrame ( "Frame" , "RankDropDownMenu" , guildRankDropDownMenuSelected , "InsetFrameTemplate" );
local RankDropDownMenuButton = CreateFrame ( "Button" , "RankDropDownMenuButton" , guildRankDropDownMenuSelected , "UIPanelScrollDownButtonTemplate" );


-- Normal frame translucent
local noteBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" ,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 18,
    insets = { left == 5 , right = 5 , top = 5 , bottom = 5 }
}

-- Thinnner frame translucent template
local noteBackdrop2 = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" ,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 9,
    insets = { left == 2 , right = 2 , top = 3 , bottom = 2 }
}

local GRM_PlayerNoteWindow = CreateFrame( "Frame" , "GRM_PlayerNoteWindow" , MemberDetailMetaData );
local GRM_noteFontString1 = GRM_PlayerNoteWindow:CreateFontString ( "GRM_noteFontString1" , "OVERLAY" , "GameFontWhiteTiny" );
local GRM_PlayerNoteEditBox = CreateFrame( "EditBox" , "GRM_PlayerNoteEditBox" , MemberDetailMetaData );
local GRM_PlayerOfficerNoteWindow = CreateFrame( "Frame" , "GRM_PlayerOfficerNoteWindow" , MemberDetailMetaData );
local GRM_noteFontString2 = GRM_PlayerOfficerNoteWindow:CreateFontString ( "GRM_noteFontString2" , "OVERLAY" , "GameFontWhiteTiny" );
local GRM_PlayerOfficerNoteEditBox = CreateFrame( "EditBox" , "GRM_PlayerOfficerNoteEditBox" , MemberDetailMetaData );
local GRM_NoteCount = MemberDetailMetaData:CreateFontString ( "GRM_NoteCount" , "OVERLAY" , "GameFontWhiteTiny" );
GRM_PlayerNoteEditBox:Hide();
GRM_PlayerOfficerNoteEditBox:Hide();

-- Populating Frames with FontStrings
local GRM_MemberDetailNameText = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailNameText" , "OVERLAY" , "GameFontNormalLarge" );
local GRM_MemberDetailMainText = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailMainText" , "OVERLAY" , "GameFontWhiteTiny" );
local GRM_MemberDetailLevel = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailLevel" , "OVERLAY" , "GameFontNormalSmall" );
local GRM_MemberDetailRankTxt = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailRankTxt" , "OVERLAY" , "GameFontNormal" );
local GRM_MemberDetailRankDateTxt = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailRankDateTxt" , "OVERLAY" , "GameFontNormalSmall" );
local GRM_MemberDetailNoteTitle = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailNoteTitle" , "OVERLAY" , "GameFontNormalSmall" );
local GRM_MemberDetailONoteTitle = MemberDetailMetaData:CreateFontString ( "GRM_MemberDetailONoteTitle" , "OVERLAY" , "GameFontNormalSmall" );

-- Fontstring for MemberRank History 
local GRM_MemberDetailJoinDateButton = CreateFrame ( "Button" , "GRM_MemberDetailJoinDateButton" , MemberDetailMetaData , "GameMenuButtonTemplate" );
local GRM_MemberDetailJoinDateButtonText = GRM_MemberDetailJoinDateButton:CreateFontString ( "GRM_MemberDetailJoinDateButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local GRM_JoinDateText = MemberDetailMetaData:CreateFontString ( "GRM_JoinDateText" , "OVERLAY" , "GameFontWhiteTiny" );

-- LAST ONLINE
local GR_MemberDetailLastOnlineTitleTxt = MemberDetailMetaData:CreateFontString ( "GR_MemberDetailLastOnlineTitleTxt" , "OVERYALY" , "GameFontNormalSmall" );
local GR_MemberDetailLastOnlineTxt = MemberDetailMetaData:CreateFontString ( "GR_MemberDetailLastOnlineTxt" , "OVERYALY" , "GameFontWhiteTiny" );
local GR_MemberDetailDateJoinedTitleTxt = MemberDetailMetaData:CreateFontString ( "GR_MemberDetailDateJoinedTitleTxt" , "OVERYALY" , "GameFontNormalSmall" );

-- STATUS TEXT
local GRM_MemberDetailPlayerStatus = MemberDetailMetaData:CreateFontString (" GRM_MemberDetailPlayerStatus" , "OVERYALY" , "GameFontNormalSmall" );

-- ZONEINFORMATION
MemberDetailMetaData.MemberDetailMetaZoneInfoText = MemberDetailMetaData:CreateFontString ( "MemberDetailMetaZoneInfoText" , "OVERYALY" , "GameFontNormalSmall" );
MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText = MemberDetailMetaData:CreateFontString ( "MemberDetailMetaZoneInfoZoneText" , "OVERYALY" , "GameFontWhiteTiny" );
MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1 = MemberDetailMetaData:CreateFontString ( "MemberDetailMetaZoneInfoTimeText1" , "OVERYALY" , "GameFontNormalSmall" );
MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2 = MemberDetailMetaData:CreateFontString ( "MemberDetailMetaZoneInfoTimeText2" , "OVERYALY" , "GameFontWhiteTiny" );

-- GROUP INVITE and REMOVE from Guild BUTTONS
local GRM_GroupInviteButton = CreateFrame ( "Button" , "GRM_GroupInviteButton" , MemberDetailMetaData , "GameMenuButtonTemplate" );
GRM_GroupInviteButton.GRM_GroupInviteButtonText = GRM_GroupInviteButton:CreateFontString ( "GRM_GroupInviteButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local GRM_RemoveGuildieButton = CreateFrame ( "Button" , "GRM_RemoveGuildieButton" , MemberDetailMetaData , "GameMenuButtonTemplate" );
GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText = GRM_RemoveGuildieButton:CreateFontString ( "GRM_RemoveGuildieButtonText" , "OVERLAY" , "GameFontWhiteTiny" );

-- Tooltips
local GRM_MemberDetailRankToolTip = CreateFrame ( "GameTooltip" , "GRM_MemberDetailRankToolTip" , MemberDetailMetaData , "GameTooltipTemplate" );
GRM_MemberDetailRankToolTip:Hide();
local GRM_MemberDetailJoinDateToolTip = CreateFrame ( "GameTooltip" , "GRM_MemberDetailJoinDateToolTip" , MemberDetailMetaData , "GameTooltipTemplate" );
GRM_MemberDetailJoinDateToolTip:Hide();

-- CUSTOM POPUPBOX FOR REUSE -- Avoids all possibility of UI Taint by just building my own, for those that use a lot of addons.
local GR_PopupWindow = CreateFrame ( "Frame" , "GR_PopupWindow" , MemberDetailMetaData , "TranslucentFrameTemplate" );
GR_PopupWindow:Hide() -- Prevents it from autopopping up on load like it sometimes will.
local GR_PopupWindowButton1 = CreateFrame ( "Button" , "GR_PopupWindowButton1" , GR_PopupWindow , "UIPanelButtonTemplate" );
GR_PopupWindowButton1.GR_PopupWindowButton1Text = GR_PopupWindowButton1:CreateFontString ( "GR_PopupWindowButton1Text" , "OVERLAY" , "GameFontNormal" );
local GR_PopupWindowButton2 = CreateFrame ( "Button" , "GR_PopupWindowButton2" , GR_PopupWindow , "UIPanelButtonTemplate" );
GR_PopupWindowButton2.GR_PopupWindowButton2Text = GR_PopupWindowButton2:CreateFontString ( "GR_PopupWindowButton2Text" , "OVERLAY" , "GameFontNormal" );
local GR_PopupWindowCheckButton1 = CreateFrame ( "CheckButton" , "GR_PopupWindowCheckButton1" , GR_PopupWindow , "OptionsSmallCheckButtonTemplate" );
local GR_PopupWindowCheckButtonText = GR_PopupWindowCheckButton1:CreateFontString ( "GR_PopupWindowCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local GR_PopupWindowCheckButton2 = CreateFrame ( "CheckButton" , "GR_PopupWindowCheckButton2" , GR_PopupWindow , "OptionsSmallCheckButtonTemplate" );
local GR_PopupWindowCheckButton2Text = GR_PopupWindowCheckButton2:CreateFontString ( "GR_PopupWindowCheckButton2Text" , "OVERLAY" , "GameFontNormalSmall" );
local GR_PopupWindowConfirmText = GR_PopupWindow:CreateFontString ( "GR_PopupWindowConfirmText" , "OVERLAY" , "GameFontNormal" );

-- EDIT BOX FOR ANYTHING ( like banned player note );
local GR_MemberDetailEditBoxFrame = CreateFrame ( "Frame" , "GR_MemberDetailEditBoxFrame" , GR_PopupWindow , "TranslucentFrameTemplate" );
GR_MemberDetailEditBoxFrame:Hide();
local MemberDetailPopupEditBox = CreateFrame ( "EditBox" , "MemberDetailPopupEditBox" , GR_MemberDetailEditBoxFrame );

-- Banned Fontstring and Buttons
local GR_MemberDetailBannedText1 = MemberDetailMetaData:CreateFontString ( "GR_MemberDetailBannedText1" , "OVERLAY" , "GameFontNormalSmall");
local GR_MemberDetailBannedIgnoreButton = CreateFrame ( "Button" , "GR_MemberDetailBannedIgnoreButton" , MemberDetailMetaData , "GameMenuButtonTemplate" );

-- ALT FRAMES!!!
local GR_CoreAltFrame = CreateFrame( "Frame" , "GR_CoreAltFrame" , MemberDetailMetaData );
GR_CoreAltFrame:Hide(); -- No need to show initially. Occasionally on init. it would popup the title text. Just keep hidden with init.
-- ALT HEADER
local altFrameTitleText = GR_CoreAltFrame:CreateFontString ( "altFrameTitleText" , "OVERLAY" , "GameFontNormalSmall" );
-- ALT OPTIONSFRAME
local altDropDownOptions = CreateFrame ( "Frame" , "altDropDownOptions" , MemberDetailMetaData );
altDropDownOptions:Hide();
local altOptionsText = altDropDownOptions:CreateFontString ( "altOptionsText" , "OVERLAY" , "GameFontNormalSmall" );
local altOptionsDividerText = altDropDownOptions:CreateFontString ( "altOptionsDividerText" , "OVERLAY" , "GameFontWhiteTiny" );
-- ALT BUTTONS
local AddAltButton = CreateFrame ( "Button" , "AddAltButton" , GR_CoreAltFrame , "GameMenuButtonTemplate" );
local AddAltButtonText = AddAltButton:CreateFontString ( "AddAltButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local altSetMainButton = CreateFrame ( "Button" , "altSetMainButton" , altDropDownOptions  );
local altSetMainButtonText = altSetMainButton:CreateFontString ( "altSetMainButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local altRemoveButton = CreateFrame ( "Button" , "altRemoveButton" , altDropDownOptions );
local altRemoveButtonText = altRemoveButton:CreateFontString ( "altRemoveButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local altFrameCancelButton = CreateFrame ( "Button" , "altFrameCancelButton" , altDropDownOptions );
local altFrameCancelButtonText = altFrameCancelButton:CreateFontString ( "altFrameCancelButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
-- ALT TOOLTIP
local altFrameToolTip = CreateFrame ( "GameTooltip" , "altFrameToolTip" , MemberDetailMetaData , "GameTooltipTemplate" );
-- ALT NAMES (If I end up running short on FontStrings, I may need to convert to use static buttons.)
local GR_AltName1 = GR_CoreAltFrame:CreateFontString ( "GR_AltName1" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName2 = GR_CoreAltFrame:CreateFontString ( "GR_AltName2" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName3 = GR_CoreAltFrame:CreateFontString ( "GR_AltName3" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName4 = GR_CoreAltFrame:CreateFontString ( "GR_AltName4" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName5 = GR_CoreAltFrame:CreateFontString ( "GR_AltName5" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName6 = GR_CoreAltFrame:CreateFontString ( "GR_AltName6" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName7 = GR_CoreAltFrame:CreateFontString ( "GR_AltName7" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName8 = GR_CoreAltFrame:CreateFontString ( "GR_AltName8" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName9 = GR_CoreAltFrame:CreateFontString ( "GR_AltName9" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName10 = GR_CoreAltFrame:CreateFontString ( "GR_AltName10" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName11 = GR_CoreAltFrame:CreateFontString ( "GR_AltName11" , "OVERLAY" , "GameFontNormalSmall" );
local GR_AltName12 = GR_CoreAltFrame:CreateFontString ( "GR_AltName12" , "OVERLAY" , "GameFontNormalSmall" );
-- ADD ALT EDITBOX Frame
local AddAltEditFrame = CreateFrame ( "Frame" , "AddAltEditFrame" , GR_CoreAltFrame , "TranslucentFrameTemplate" );
AddAltEditFrame:Hide();
local AddAltTitleText = AddAltEditFrame:CreateFontString ( "AddAltTitleText" , "OVERLAY" , "GameFontNormalSmall" );
local AddAltEditBox = CreateFrame ( "EditBox" , "altAddEditBox" , AddAltEditFrame , "InputBoxTemplate" );
local AddAltNameButton1 = CreateFrame ( "Button" , "AddAltNameButton1" , AddAltEditFrame );
local AddAltNameButton2 = CreateFrame ( "Button" , "AddAltNameButton2" , AddAltEditFrame );
local AddAltNameButton3 = CreateFrame ( "Button" , "AddAltNameButton3" , AddAltEditFrame );
local AddAltNameButton4 = CreateFrame ( "Button" , "AddAltNameButton4" , AddAltEditFrame );
local AddAltNameButton5 = CreateFrame ( "Button" , "AddAltNameButton5" , AddAltEditFrame );
local AddAltNameButton6 = CreateFrame ( "Button" , "AddAltNameButton6" , AddAltEditFrame );
local AddAltNameButton1Text = AddAltNameButton1:CreateFontString ( "AddAltNameButton1" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltNameButton2Text = AddAltNameButton2:CreateFontString ( "AddAltNameButton2" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltNameButton3Text = AddAltNameButton3:CreateFontString ( "AddAltNameButton3" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltNameButton4Text = AddAltNameButton4:CreateFontString ( "AddAltNameButton4" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltNameButton5Text = AddAltNameButton5:CreateFontString ( "AddAltNameButton5" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltNameButton6Text = AddAltNameButton6:CreateFontString ( "AddAltNameButton6" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltEditFrameTextBottom = AddAltEditFrame:CreateFontString ( "AddAltEditFrameTextBottom" , "OVERLAY" , "GameFontWhiteTiny" );
local AddAltEditFrameHelpText = AddAltEditFrame:CreateFontString ( "AddAltEditFrameHelpText" , "OVERLAY" , "GameFontNormalSmall" );

-- CALENDAR ADD EVENT WINDOW
local AddEventFrame = CreateFrame ( "Frame" , "AddEventFrame" , UIParent , "BasicFrameTemplate" );
AddEventFrame:Hide();
local AddEventFrameTitleText = AddEventFrame:CreateFontString ( "AddEventFrameTitleText" , "OVERLAY" , "GameFontNormal" );
local AddEventFrameNameTitleText = AddEventFrame:CreateFontString ( "AddEventFrameNameTitleText" , "OVERLAY" , "GameFontNormal" );
local AddEventFrameStatusMessageText = AddEventFrame:CreateFontString ( "AddEventFrameNameTitleText" , "OVERLAY" , "GameFontNormal" );
local AddEventFrameNameToAddText = AddEventFrame:CreateFontString ( "AddEventFrameNameTitleText" , "OVERLAY" , "GameFontNormal" );
local AddEventFrameNameToAddTitleText = AddEventFrame:CreateFontString ( "AddEventFrameNameToAddTitleText" , "OVERLAY" , "GameFontNormal" );   -- Will never be displayed, just a frame txt holder
-- Set and Ignore Buttons
local AddEventFrameSetAnnounceButton = CreateFrame ( "Button" , "AddEventFrameSetAnnounceButton" , AddEventFrame , "UIPanelButtonTemplate" );
local AddEventFrameSetAnnounceButtonText = AddEventFrameSetAnnounceButton:CreateFontString ( "AddEventFrameSetAnnounceButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
local AddEventFrameIgnoreButton = CreateFrame ( "Button" , "AddEventFrameIgnoreButton" , AddEventFrame , "UIPanelButtonTemplate" );
local AddEventFrameIgnoreButtonText = AddEventFrameIgnoreButton:CreateFontString ( "AddEventFrameIgnoreButtonText" , "OVERLAY" , "GameFontWhiteTiny" );
-- SCROLL FRAME
local AddEventScrollFrame = CreateFrame ( "ScrollFrame" , "AddEventScrollFrame" , AddEventFrame );
local AddEventScrollBorderFrame = CreateFrame ( "Frame" , "AddEventScrollBorderFrame" , AddEventFrame , "TranslucentFrameTemplate" );
-- CONTENT FRAME (Child Frame)
local AddEventScrollChildFrame = CreateFrame ( "Frame" , "AddEventScrollChildFrame" );
-- SLIDER
local AddEventScrollFrameSlider = CreateFrame ( "Slider" , "AddEventScrollFrameSlider" , AddEventScrollFrame , "UIPanelScrollBarTemplate" );
-- EvntWindowButton
local AddEventLoadFrameButton = CreateFrame( "Button" , "AddEventLoadFrameButton" , GuildRosterFrame , "UIPanelButtonTemplate" );
local AddEventLoadFrameButtonText = AddEventLoadFrameButton:CreateFontString ( "AddEventLoadFrameButtonText" , "OVERLAY" , "GameFontWhiteTiny");
AddEventLoadFrameButton:Hide();

-- CORE GUILD LOG EVENT FRAME!!!
local RosterChangeLogFrame = CreateFrame ( "Frame" , "RosterChangeLogFrame" , UIParent , "BasicFrameTemplate" );
RosterChangeLogFrame:Hide();
local RosterChangeLogFrameTitleText = RosterChangeLogFrame:CreateFontString ( "RosterChangeLogFrameTitleText" , "OVERLAY" , "GameFontNormal" );
-- CHECKBOX FRAME
local RosterCheckBoxSideFrame = CreateFrame ( "Frame" , "RosterCheckBoxSideFrame" , RosterChangeLogFrame , "TranslucentFrameTemplate" );
-- CHECKBOXES
local RosterPromotionChangeCheckButton = CreateFrame ( "CheckButton" , "RosterPromotionChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterPromotionChangeCheckButtonText = RosterPromotionChangeCheckButton:CreateFontString ( "RosterPromotionChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterDemotionChangeCheckButton = CreateFrame ( "CheckButton" , "RosterDemotionChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterDemotionChangeCheckButtonText = RosterDemotionChangeCheckButton:CreateFontString ( "RosterDemotionChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterLeveledChangeCheckButton = CreateFrame ( "CheckButton" , "RosterLeveledChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterLeveledChangeCheckButtonText = RosterLeveledChangeCheckButton:CreateFontString ( "RosterLeveledChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterNoteChangeCheckButton = CreateFrame ( "CheckButton" , "RosterNoteChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterNoteChangeCheckButtonText = RosterNoteChangeCheckButton:CreateFontString ( "RosterNoteChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterOfficerNoteChangeCheckButton = CreateFrame ( "CheckButton" , "RosterOfficerNoteChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterOfficerNoteChangeCheckButtonText = RosterOfficerNoteChangeCheckButton:CreateFontString ( "RosterOfficerNoteChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterJoinedCheckButton = CreateFrame ( "CheckButton" , "RosterJoinedCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterJoinedCheckButtonText = RosterJoinedCheckButton:CreateFontString ( "RosterJoinedCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterLeftGuildCheckButton = CreateFrame ( "CheckButton" , "RosterLeftGuildCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterLeftGuildCheckButtonText = RosterLeftGuildCheckButton:CreateFontString ( "RosterLeftGuildCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterInactiveReturnCheckButton = CreateFrame ( "CheckButton" , "RosterInactiveReturnCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterInactiveReturnCheckButtonText = RosterInactiveReturnCheckButton:CreateFontString ( "RosterInactiveReturnCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterNameChangeCheckButton = CreateFrame ( "CheckButton" , "RosterNameChangeCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterNameChangeCheckButtonText = RosterNameChangeCheckButton:CreateFontString ( "RosterNameChangeCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterEventCheckButton = CreateFrame ( "CheckButton" , "RosterEventCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterEventCheckButtonText = RosterEventCheckButton:CreateFontString ( "RosterEventCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterShowAtLogonCheckButton = CreateFrame ( "CheckButton" , "RosterShowAtLogonCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterShowAtLogonCheckButtonText = RosterShowAtLogonCheckButton:CreateFontString ( "RosterShowAtLogonCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterRankRenameCheckButton = CreateFrame ( "CheckButton" , "RosterRankRenameCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterRankRenameCheckButtonText = RosterRankRenameCheckButton:CreateFontString ( "RosterShowAtLogonCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterRecommendationsButton = CreateFrame ( "CheckButton" , "RosterRecommendationsButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterRecommendationsButtonText = RosterRecommendationsButton:CreateFontString ( "RosterRecommendationsButtonText" , "OVERLAY" , "GameFontNormalSmall" );
-- CHAT BOX CONFIRM CHECKBOXES
RosterCheckBoxSideFrame.RosterJoinedChatCheckButton = CreateFrame ( "CheckButton" , "RosterJoinedChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterLeveledChatCheckButton = CreateFrame ( "CheckButton" , "RosterLeveledChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterInactiveReturnChatCheckButton = CreateFrame ( "CheckButton" , "RosterInactiveReturnChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterPromotionChatCheckButton = CreateFrame ( "CheckButton" , "RosterPromotionChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterDemotionChatCheckButton = CreateFrame ( "CheckButton" , "RosterDemotionChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterNoteChatCheckButton = CreateFrame ( "CheckButton" , "RosterNoteChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterOfficerNoteChatCheckButton = CreateFrame ( "CheckButton" , "RosterOfficerNoteChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterNameChangeChatCheckButton = CreateFrame ( "CheckButton" , "RosterNameChangeChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterRankRenameChatCheckButton = CreateFrame ( "CheckButton" , "RosterRankRenameChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterEventChatCheckButton = CreateFrame ( "CheckButton" , "RosterEventChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterLeftGuildChatCheckButton = CreateFrame ( "CheckButton" , "RosterLeftGuildChatCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterRecommendationsChatButton = CreateFrame ( "CheckButton" , "RosterRecommendationsChatButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
-- Fontstrings for side frame
RosterCheckBoxSideFrame.TitleSideFrameText = RosterCheckBoxSideFrame:CreateFontString ( "TitleSideFrameText" , "OVERLAY" , "GameFontNormalSmall" );
RosterCheckBoxSideFrame.ShowOnLogSideFrameText = RosterCheckBoxSideFrame:CreateFontString ( "ShowOnLogSideFrameText" , "OVERLAY" , "GameFontNormalSmall" );
RosterCheckBoxSideFrame.ShowOnChatSideFrameText = RosterCheckBoxSideFrame:CreateFontString ( "ShowOnChatSideFrameText" , "OVERLAY" , "GameFontNormalSmall" );

-- SCROLL FRAME
local RosterChangeLogScrollFrame = CreateFrame ( "ScrollFrame" , "RosterChangeLogScrollFrame" , RosterChangeLogFrame );
local RosterChangeLogScrollBorderFrame = CreateFrame ( "Frame" , "RosterChangeLogScrollBorderFrame" , RosterChangeLogFrame , "TranslucentFrameTemplate" );
-- CONTENT FRAME (Child Frame)
local RosterChangeLogScrollChildFrame = CreateFrame ( "Frame" , "RosterChangeLogScrollChildFrame" );
-- SLIDER
local RosterChangeLogScrollFrameSlider = CreateFrame ( "Slider" , "RosterChangeLogScrollFrameSlider" , RosterChangeLogScrollFrame , "UIPanelScrollBarTemplate" );
-- BUTTONS
local LoadLogButton = CreateFrame( "Button" , "LoadLogButton" , GuildRosterFrame , "UIPanelButtonTemplate" );
LoadLogButton:Hide();
local LoadLogButtonText = LoadLogButton:CreateFontString ( "LoadLogButtonText" , "OVERLAY" , "GameFontWhiteTiny");

-- OPTIONS PANEL BUTTONS ( in the Roster Log Frame)
local RosterOptionsButton = CreateFrame ( "Button" , "RosterOptionsButton" , RosterChangeLogFrame , "UIPanelButtonTemplate" );
local RosterOptionsButtonText = RosterOptionsButton:CreateFontString ( "RosterOptionsButtonText" , "OVERLAY" , "GameFontWhiteTiny");
local RosterClearLogButton = CreateFrame( "Button" , "RosterClearLogButton" , RosterCheckBoxSideFrame , "UIPanelButtonTemplate" );
local RosterClearLogButtonText = RosterClearLogButton:CreateFontString ( "RosterClearLogButtonText" , "OVERLAY" , "GameFontWhiteTiny");
-- Options Panel Checkboxes
local RosterLoadOnLogonCheckButton = CreateFrame ( "CheckButton" , "RosterLoadOnLogonCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterLoadOnLogonCheckButtonText = RosterLoadOnLogonCheckButton:CreateFontString ( "RosterLoadOnLogonCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterAddTimestampCheckButton = CreateFrame ( "CheckButton" , "RosterAddTimestampCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterAddTimestampCheckButtonText = RosterAddTimestampCheckButton:CreateFontString ( "RosterAddTimestampCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
-- Kick Recommendation Options
local RosterRecommendKickCheckButton = CreateFrame ( "CheckButton" , "RosterRecommendKickCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterRecommendKickCheckButtonText = RosterRecommendKickCheckButton:CreateFontString ( "RosterRecommendKickCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterKickRecommendEditBox = CreateFrame( "EditBox" , "RosterKickRecommendEditBox" , RosterCheckBoxSideFrame );
RosterKickRecommendEditBox:Hide();
local RosterKickOverlayNote = CreateFrame ( "Frame" , "RosterKickOverlayNote" , RosterCheckBoxSideFrame );
local RosterKickOverlayNoteText = RosterKickOverlayNote:CreateFontString ( "RosterKickOverlayNoteText" , "OVERLAY" , "GameFontNormalSmall" );
-- Report Inactive Options
local RosterReportInactiveReturnButton = CreateFrame ( "CheckButton" , "RosterReportInactiveReturnButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterReportInactiveReturnButtonText = RosterReportInactiveReturnButton:CreateFontString ( "RosterReportInactiveReturnButtonText" , "OVERLAY" , "GameFontNormalSmall" );
local ReportInactiveReturnEditBox = CreateFrame( "EditBox" , "ReportInactiveReturnEditBox" , RosterCheckBoxSideFrame );
ReportInactiveReturnEditBox:Hide();
local ReportInactiveReturnOverlayNote = CreateFrame ( "Frame" , "ReportInactiveReturnOverlayNote" , RosterCheckBoxSideFrame );
local ReportInactiveReturnOverlayNoteText = ReportInactiveReturnOverlayNote:CreateFontString ( "ReportInactiveReturnOverlayNoteText" , "OVERLAY" , "GameFontNormalSmall" );
-- Report Upcoming Events
local RosterReportUpcomingEventsCheckButtonDays = CreateFrame ( "CheckButton" , "RosterReportUpcomingEventsCheckButtonDays" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterReportUpcomingEventsCheckButtonDaysText = RosterReportUpcomingEventsCheckButtonDays:CreateFontString ( "RosterReportUpcomingEventsCheckButtonDaysText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterReportUpcomingEventsEditBox = CreateFrame( "EditBox" , "RosterReportUpcomingEventsEditBox" , RosterCheckBoxSideFrame );
RosterReportUpcomingEventsEditBox:Hide();
local RosterReportUpcomingEventsOverlayNote = CreateFrame ( "Frame" , "RosterReportUpcomingEventsOverlayNote" , RosterCheckBoxSideFrame );
local RosterReportUpcomingEventsOverlayNoteText = RosterReportUpcomingEventsOverlayNote:CreateFontString ( "RosterReportUpcomingEventsOverlayNoteText" , "OVERLAY" , "GameFontNormalSmall" );
local RosterReportUpcomingEventsCheckButton = CreateFrame ( "CheckButton" , "RosterReportUpcomingEventsCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
local RosterReportUpcomingEventsCheckButtonText = RosterReportUpcomingEventsCheckButton:CreateFontString ( "RosterReportUpcomingEventsCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
-- Share changes with ONLINE guildies
RosterCheckBoxSideFrame.RosterSyncCheckButton = CreateFrame ( "CheckButton" , "RosterSyncCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterSyncCheckButtonText = RosterCheckBoxSideFrame.RosterSyncCheckButton:CreateFontString ( "RosterSyncCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );
RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton = CreateFrame ( "CheckButton" , "RosterNotifyOnChangesCheckButton" , RosterCheckBoxSideFrame , "OptionsSmallCheckButtonTemplate" );
RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButtonText = RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:CreateFontString ( "RosterSyncCheckButtonText" , "OVERLAY" , "GameFontNormalSmall" );

-- Options RankDropDown
RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected = CreateFrame ( "Frame" , "RosterSyncRankDropDownSelected" , RosterCheckBoxSideFrame.RosterSyncCheckButton , "InsetFrameTemplate" );
RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText = RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:CreateFontString ( "RosterSyncRankDropDownSelectedText" , "OVERLAY" , "GameFontWhiteTiny" );
RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu = CreateFrame ( "Frame" , "RosterSyncRankDropDownMenu" , RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected , "InsetFrameTemplate" );
RosterCheckBoxSideFrame.RosterSyncRankDropDownMenuButton = CreateFrame ( "Button" , "RosterSyncRankDropDownMenuButton" , RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected , "UIPanelScrollDownButtonTemplate" );

-- Guild Event Log Frame Confirm Details.
local RosterConfirmFrame = CreateFrame ( "Frame" , "RosterConfirmFrame" , UIPanel , "BasicFrameTemplate" );
local RosterConfirmFrameText = RosterConfirmFrame:CreateFontString ( "RosterConfirmFrameText" , "OVERLAY" , "GameFontWhiteTiny");
local RosterConfirmYesButton = CreateFrame ( "Button" , "RosterConfirmYesButton" , RosterConfirmFrame , "UIPanelButtonTemplate" );
local RosterConfirmYesButtonText = RosterConfirmYesButton:CreateFontString ( "RosterConfirmYesButtonText" , "OVERLAY" , "GameFontWhiteTiny");
local RosterConfirmCancelButton = CreateFrame ( "Button" , "RosterConfirmCancelButton" , RosterConfirmFrame , "UIPanelButtonTemplate" );
local RosterConfirmCancelButtonText = RosterConfirmCancelButton:CreateFontString ( "RosterConfirmCancelButtonText" , "OVERLAY" , "GameFontWhiteTiny");

-- MISC FRAMES
UI_Events.NumGuildiesText = UI_Events:CreateFontString ( "NumGuildiesText" , "OVERLAY" , "GameFontNormalSmall" );

--------------------------
--- FUNCTIONS ------------
--------------------------


-- Method:          GRM.ClearPermData()
-- What it Does:    Resets all the saved data back to nothing... and does not rebuid it.
-- Purpose:         Mainly for use if ever there is a need to purge the data, in beta, without rebuilding the roster.
GRM.ClearPermData = function()
    -- SPECIAL NOTE (if ever needed);

    GRM_GuildMemberHistory_Save = nil;
    GRM_GuildMemberHistory_Save = {};
    table.insert ( GRM_GuildMemberHistory_Save , { "Horde" } );
    table.insert ( GRM_GuildMemberHistory_Save , { "Alliance" } );

    GRM_PlayersThatLeftHistory_Save = nil;
    GRM_PlayersThatLeftHistory_Save = {};
    table.insert ( GRM_PlayersThatLeftHistory_Save , { "Horde" } );
    table.insert ( GRM_PlayersThatLeftHistory_Save , { "Alliance" } );

    GRM_LogReport_Save = nil;
    GRM_LogReport_Save = {};
    table.insert ( GRM_LogReport_Save , { "Horde" } );
    table.insert ( GRM_LogReport_Save , { "Alliance" } );

    GRM_CalendarAddQue_Save = nil;
    GRM_CalendarAddQue_Save = {};
    table.insert ( GRM_CalendarAddQue_Save , { "Horde" } );
    table.insert ( GRM_CalendarAddQue_Save , { "Alliance" } );
    
    GRM_AddonSettings_Save = nil;
    GRM_AddonSettings_Save = {};
    table.insert ( GRM_AddonSettings_Save , { "Horde" } );
    table.insert ( GRM_AddonSettings_Save , { "Alliance" } );
end

-- Method:          GRM.LoadSettings()
-- What it Does:    On first time loading addon, it builds default addon settings. It checks for addon version change
--                  And, if there are any changes, they will be added into that logic block. 
--                  And new setting can be tagged on.
-- Purpose:         Saving settings between gaming sessions. Also, this is built to provide backwards compatibility for future flexibility on feature adding, if necessary.
GRM.LoadSettings = function()
    -- Build the settings
    -- First, determine if addon settings have ever been initialized.
    if GRM_AddonSettings_Save[1] == nil then
        GRM.ClearPermData();                        -- This will purge the old data and then it needs to be built and reinitialized.
    end

    -- Find the player
    local isFound = false;
    local indexFound = 0;
    for i = 2 , #GRM_AddonSettings_Save[GR_AddonGlobals.FID] do
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.addonPlayerName then
            isFound = true;
            indexFound = i;
        end
    end

    -- Build settings for first time.
    if not isFound then
         -- Add new player
        table.insert ( GRM_AddonSettings_Save[GR_AddonGlobals.FID] , { GR_AddonGlobals.addonPlayerName } );
        print ( "\nConfiguring Guild Roster Manager for " .. GetUnitName ( "PLAYER" , false ) .. " for the first time." );

        local AllDefaultSettings = {

            Version,                                                                                -- 1)  Version
            true,                                                                                   -- 2)  View on Load
            { true , true , true , true , true , true , true , true , true , true , true , true },  -- 3)  All buttons are checked in the log window 
            336,                                                                                    -- 4)  Report inactive return of player coming back (2 weeks is default value)
            14,                                                                                     -- 5)  Event Announce in Advance - Cannot be higher than 4 weeks ( 28 days ) ( 1 week is default);
            10,                                                                                     -- 6)  How often to check for changes ( in seconds )
            true,                                                                                   -- 7)  Add Timestamp on join to Officer Note
            true,                                                                                   -- 8)  Use Calendar Announcements
            12,                                                                                     -- 9)  Months Player Has Been Offline to Add Announcement To Kick
            false,                                                                                  -- 10) Recommendations!
            true,                                                                                   -- 11) Report Inactive Returns
            true,                                                                                   -- 12) Announce Upcoming Events.
            { true , true , true , true , true , true , true , true , true , true , true , true },  -- 13) Checkbox for message frame announcing. Disable 
            false,                                                                                  -- 14) Allow Data sharing between guildies
            1,                                                                                      -- 15) Rank Player must be to accept sync updates from them.
            true,                                                                                   -- 16) Receive Notifications if others in the guild send updates!
            
            true,                                                                                   -- 17) MISC TO BE USED IN THE FUTURE IF NEEDED
            true,                                                                                   -- 18) ''
            true,                                                                                   -- 19) ''
            true,                                                                                   -- 20) ''
            true,                                                                                   -- 21) ''
            0,                                                                                      -- 22) ''
            0,                                                                                      -- 23) ''
            0,                                                                                      -- 24) ''
            0,                                                                                      -- 25) ''
            0                                                                                       -- 26) ''

        };
       
        -- Unique Settings added to the player.
        table.insert ( GRM_AddonSettings_Save[GR_AddonGlobals.FID][ #GRM_AddonSettings_Save[GR_AddonGlobals.FID] ] , AllDefaultSettings );

    elseif GRM_AddonSettings_Save[GR_AddonGlobals.FID][indexFound][2][1] ~= Version then
        -- Table that will have all of the release patch names.
        local ListOfReleasePatches = { "7.2.5r1.00" } ;
            
        -------------------------------
        --- START PATCH FIXES ---------
        -------------------------------



        -------------------------------
        -- END OF PATCH FIXES ---------
        -------------------------------

        -- Ok, let's update the version!
        print ( GR_AddonGlobals.addonName .. " v" .. GRM_AddonSettings_Save[GR_AddonGlobals.FID][2][1] .. " has been Updated to v" .. Version );

        -- Updating the version for ALL saved accoutns.
        for i = 1 , #GRM_AddonSettings_Save do
            for j = 2 , #GRM_AddonSettings_Save[i] do
                GRM_AddonSettings_Save[i][j][2][1] = Version;      -- Changing version for all indexes.
            end
        end
    end    
end


-- Method:          GRM.SlimName(string)
-- What it Does:    Removes the server name after character name.
-- Purpose:         Server name is not important in a guild since all will be server name.
GRM.SlimName = function( name )
    if string.find ( name , "-" , 1 ) ~= nil then
        return strsub ( name , 1 , string.find ( name ,"-" ) - 1 );
    else
        return name;
    end
end

-- Method:          GRM.ParseClass(string) 
-- DEPRECATED for now as a result of custom UI being built
-- What it Does:    Takes a line of text from GuildMemberDetailFrame and parses out the Class
-- Purpose:         While a call can be made to the server after parsing the index number in a built-in API lookup, that is resource hungry.
--                  Since the server has already pulled the info in text form, this saves a lot of resources from querying the server for player class.
GRM.ParseClass = function( class )
    local result = "";
    local numFound = false;
    for i = 1 , #class do
        if numFound ~= true then
            if tonumber ( string.sub ( class , i , i ) ) ~= nil then
                -- NUM FOUND!
                numFound = true;
            end
        else
            if tonumber ( string.sub ( class , i , i ) ) == nil then   -- I am at the space after the player level ends
                result = string.sub ( class , i + 1 );
                break;  
            end
        end
    end
    return result;
end

-- Method:          GRM.ParseLevel(string)
-- DEPRECATED for now...
-- What it Does:    Takes the same text line from GuildMemberDetailFrame and parses out the Level
-- Purpose:         To obtain a player's level one needs to query the server. Since the string is already available, this just grabs the string simply.
GRM.ParseLevel = function ( level )
    local result = "";
    local numFound = false;
    local startIndex = 1;

    for i = 1, #level do
        if numFound ~= true then
            if tonumber ( string.sub ( level , i , i ) ) ~= nil then
                -- Num Found!
                numFound = true;
                startIndex = i;
            end
        else
            if tonumber ( string.sub ( level , i , i ) ) == nil then
                result = string.sub ( level , startIndex , i - 1 );
                break;
            end
        end
    end
    return result;
end

-- Method           GRM.Trim ( string )
-- What it Does:    Removes the white space at front and at tail of string.
-- Purpose:         Cleanup strings for ease of logic control, as needed.
GRM.Trim = function ( str )
    return ( str:gsub ( "^%s*(.-)%s*$" , "%1" ) );
end

-- Method:          GRM.GetNumGuildies()
-- What it Does:    Returns the int number of total toons within the guild, including main/alts
-- Purpose:         For book-keeping and tracking total guild membership.
--                  Overall, this is mostly redundant as a simple GetNumGuildMembers() call is the same thing, however, this is just a tech Demo
--                  as a coding example of how to pull info and return it in your own function.
--                  A simple "GetNumGuildMembers()" would result in the same result in less steps. This is just more explicit to keep it within the style of the functions of the addon.
GRM.GetNumGuildies = function()
    return GetNumGuildMembers();
end

-- Method:          GRM.ResetTempLogs()
-- What it Does:    Empties the arrays of the reporting logs
-- Purpose:         Logs are used to build changes in the guild and then to cleanly report them in order.
GRM.ResetTempLogs = function()
    GR_AddonGlobals.TempNewMember = {};
    GR_AddonGlobals.TempInactiveReturnedLog = {};
    GR_AddonGlobals.TempLogPromotion = {};
    GR_AddonGlobals.TempLogDemotion = {};
    GR_AddonGlobals.TempLogLeveled = {};
    GR_AddonGlobals.TempLogNote = {};
    GR_AddonGlobals.TempLogONote = {};
    GR_AddonGlobals.TempRankRename = {};
    GR_AddonGlobals.TempRejoin = {};
    GR_AddonGlobals.TempBannedRejoin = {};
    GR_AddonGlobals.TempLeftGuild = {};
    GR_AddonGlobals.TempNameChanged = {};
    GR_AddonGlobals.TempEventReport = {};
    GR_AddonGlobals.TempEventRecommendKickReport = {};
end

-- Method:          GRM.ModifyCustomNote(string,string)
-- What it Does:    Adds a new note to the custom notes string
-- Purpose:         For expanded information on players to create in-game notes or tracking.
GRM.ModifyCustomNote = function ( newNote , playerName )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                       -- Scanning through guild Roster
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then       -- Player Found
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][23] = newNote;             -- Storing new note.
            break;
        end
    end
end

------------------------------------
------ TIME TRACKING TOOLS ---------
--- TIMESTAMPS , TIMEPASSED, ETC. --
------------------------------------

-- Useful Lookup Tables for date indexing.
local monthEnum = { Jan = 1 , Feb = 2 , Mar = 3 , Apr = 4 , May = 5 , Jun = 6 , Jul = 7 , Aug = 8 , Sep = 9 , Oct = 10 , Nov = 11 , Dec = 12 };
local monthsFullnameEnum = { January = 1 , February = 2 , March = 3 , April = 4 , May = 5 , June = 6 , July = 7 , August = 8 , September = 9 , October = 10 , November = 11 , December = 12 };
local daysBeforeMonthEnum = { ['1']=0 , ['2']=31 , ['3']=31+28 , ['4']=31+28+31 , ['5']=31+28+31+30 , ['6']=31+28+31+30+31 , ['7']=31+28+31+30+31+30 , 
                                ['8']=31+28+31+30+31+30+31 , ['9']=31+28+31+30+31+30+31+31 , ['10']=31+28+31+30+31+30+31+31+30 ,['11']=31+28+31+30+31+30+31+31+30+31, ['12']=31+28+31+30+31+30+31+31+30+31+30 };
local daysInMonth = { ['1']=31 , ['2']=28 , ['3']=31 , ['4']=30 , ['5']=31 , ['6']=30 , ['7']=31 , ['8']=31 , ['9']=30 , ['10']=31 , ['11']=30 , ['12']=31 };

-- Method:          GRM.IsLeapYear(int)
-- What it Does:    Returns true if the given year is a leapYear
-- Purpose:         For this addon, the calendar date selection, allows it to know to produce 29 days on leap year.
GRM.IsLeapYear = function ( yearDate )
    if ( ( ( yearDate % 4 == 0 ) and ( yearDate % 100 ~= 0 ) ) or ( yearDate % 400 == 0 ) ) then
        return true;
    else
        return false;
    end
end

-- Method:          GRM.GetHoursSinceLastOnline(int)
-- What it Does:    Returns the total numbner of hours since the player last logged in at given index position of guild roster
-- Purpose:         For player management to notify addon user of too much time has passed, for recommendation to kick,
GRM.GetHoursSinceLastOnline = function ( index )
    local years , months, days, hours = GetGuildRosterLastOnline ( index );
    if years == nil then
        years = 0;
    end
    if months == nil then
        months = 0;
    end
    if days == nil then
        days = 0;
    end
    if hours == nil then
        hours = 0;
    end
    if ( years == 0 ) and ( months == 0 ) and ( days == 0 ) and ( hours == 0) then
        hours = 0.5;    -- This can be any value less than 1, but must be between 0 and 1, to just make the point that total number of hrs since last login is < 1
    end
    local totalHours = math.floor ( ( years * 8766 ) + ( months * 730.5 ) + ( days * 24 ) + hours );
    return totalHours;
end

-- Method:          GRM.IsValidSubmitDate ( int , int , boolean )
-- What it Does:    Returns true if the submission date is valid (not an untrue day or in the future)
-- Purpose:         Check to ensure the wrong date is not submitted on accident.
GRM.IsValidSubmitDate = function ( daySelected , monthSelected , yearSelected , IsLeapYearSelected )
    local closeButtons = true;
    local _ , month , day , year = CalendarGetDate()
    local numDays;

    if monthSelected == 1 or monthSelected == 3 or monthSelected == 5 or monthSelected == 7 or monthSelected == 8 or monthSelected == 10 or monthSelected == 12 then
        numDays = 31;
    elseif monthSelected == 2 and IsLeapYearSelected then
        numDays = 29;
    elseif monthSelected == 2 then
        numDays = 28;
    else
        numDays = 30;
    end
    if daySelected > numDays then
        closeButtons = false;
    end
    
    if closeButtons then
        if ( year < yearSelected ) or ( year == yearSelected and month < monthSelected ) or ( year == yearSelected and month == monthSelected and day < daySelected ) then
            print ( "Player Does Not Have a Time Machine!" );
            closeButtons = false;
        end
    end

    if closeButtons == false then
        print ( "Please choose a valid DAY" );
    end
    return closeButtons;
end

-- Method:          GRM.TimeStampToEpoch(timestamp)
-- What it Does:    Converts a given timestamp: "22 Mar '17" into Epoch Seconds time.
-- Purpose:         On adding notes, epoch time is considered when calculating how much time has passed, for exactness and custom dates need to include it.
GRM.TimeStampToEpoch = function ( timestamp )
    -- Parsing Timestamp to useful data.
    local year = tonumber ( strsub ( timestamp , string.find ( timestamp , "'" )  + 1 ) ) + 2000;
    local leapYear = GRM.IsLeapYear ( year );
    -- Find second index of spaces
    local count = 0;
    local index = 0;
    local dayInd = -1;
    for i = 1 , #timestamp do
        if string.sub( timestamp , i , i ) == " " then
            count = count + 1;
        end
        if count == 1 and dayInd == -1 then
            dayInd = i;
        end
        if count == 2 then
            index = i;
            break;
        end
    end
    local month = monthEnum [ string.sub ( timestamp , index + 1 , index + 3) ];
    local day = tonumber ( string.sub ( timestamp , dayInd + 1 , index - 1 ) );

    -- End timestamp Parsing... 
    local hour , minute = GetGameTime();
    local tempTime = date ( '*t' );
    local seconds = tempTime.sec;

    -- calculate the number of seconds passed since 1970 based on number of years that have passed.
    local totalSeconds = 0;
    for i = year - 1 , 1970 , -1 do
        if GRM.IsLeapYear ( i ) then
            totalSeconds = totalSeconds + ( 366 * 24 * 3600 ); -- leap year = 366 days
        else
            totalSeconds = totalSeconds + ( 365 * 24 * 3600 ); -- 365 days in normal year
        end
    end
    
    -- Now lets calculate how much time this year...
    local monthDays = daysBeforeMonthEnum [ tostring ( month ) ];
    if month > 2 and leapYear then -- Adding 1 for the leap year
        monthDays = monthDays + 1;
    end
    -- adding month days so far this year to result so far.
    totalSeconds = totalSeconds + ( monthDays * 24 * 3600);

    -- The rest is easy... as of now, I will not import hours/minutes/seconds, but I will leave the calculations in place in case need arises.
    totalSeconds = totalSeconds + ( ( day - 1 ) * 24 * 3600 );  -- days
    totalSeconds = totalSeconds + ( hour * 3600 );
    totalSeconds = totalSeconds + ( minute * 60 );
    totalSeconds = totalSeconds + seconds;
    
    return totalSeconds;
end


-- Method:          GRM.GetTimestamp()
-- What it Does:    Reports the current moment in time in a much more clear, concise, pretty way. Example: "9 Feb '17 1:36pm" instead of 09/02/2017/13:36
-- Purpose:         Just for cleaner presentation of the results. Also, need to report based on server time. In-game API only returns hour/min, not month and day. This resolves that.
GRM.GetTimestamp = function()
    -- Time Variables
    local morning = true;
    local months = { "Jan" , "Feb" , "Mar" , "Apr" , "May" , "Jun" , "Jul" , "Aug" , "Sep" , "Oct" , "Nov" , "Dec" };
    local hour, minutes = GetGameTime();
    local weekday, month, day, year = CalendarGetDate();
    local stampMonth = months [ month ];

    -- Formatting...
    if minutes < 10 then
        minutes = ( "0" .. minutes ); -- Example, if it was 6:09, the minutes would only be "9" not "09" - so this looks better.
    end
     -- Swap from military time
    if hour > 12 then
        hour = hour - 12;
        morning = false;
    elseif hour == 12 then
        morning = false;
    elseif hour == 0 then
        hour = 12;
    end

    year = tostring ( year );
    year = strsub ( year , 3 );
   
    -- Establishing proper format
    local time = ( day .. " " .. stampMonth .. " '" .. year .. " " .. hour .. ":" .. minutes );
    if morning then
        time =  ( time .. "am" );
    else
        time =  ( time .. "pm" );
    end
    return time;
end

-- Method:          GRM.GetTimePassed ( oldTimestamp )
-- What it Does:    Reports back the elapsed, in English, since the previous given timestamp, based on the 1970 seconds count.
-- Purpose:         Time tracking to keep track of elapsed time since previous action.
GRM.GetTimePassed = function ( oldTimestamp )

    -- Need to consider Leap year, but for now, no biggie. 24hr differentiation only in 4 years.
    local totalSeconds = time() - oldTimestamp;
    local year = math.floor ( totalSeconds / 31536000 ); -- seconds in a year
    local yearTag = "year";
    local month = math.floor ( ( totalSeconds % 31536000 ) / 2592000 ); -- etc. 
    local monthTag = "month";
    local days = math.floor ( ( totalSeconds % 2592000) / 86400 );
    local dayTag = "day";
    local hours = math.floor ( ( totalSeconds % 86400 ) / 3600 );
    local hoursTag = "hour";
    local minutes = math.floor ( ( totalSeconds % 3600 ) / 60 );
    local minutesTag = "minute";
    local seconds = math.floor ( ( totalSeconds % 60) );
    local secondsTag = "second";
    
    local timestamp = "";
    if year > 1 then
        yearTag = "years";
    end
    if month > 1 then
        monthTag = "months";
    end
    if days > 1 then
        dayTag = "days";
    end
    if hours > 1 then
        hoursTag = "hours";
    end
    if minutes > 1 then
        minutesTag = "minutes";
    end
    if seconds > 1 then
        secondsTag = "seconds";
    end

    if year > 0 or month > 0 or days > 0 then
        if year > 0 then
            timestamp = ( year .. " " .. yearTag );
        end
        if month > 0 then
            timestamp = ( timestamp .. " " .. month .. " " .. monthTag );
        end
        if days > 0 then
            timestamp = ( timestamp .. " " .. days .. " " .. dayTag );
        else
            timestamp = ( timestamp .. " " .. days .. " " .. "days" ); -- exception to put zero days since it seems smoother, aesthetically.
        end
    else
        if hours > 0 or minutes > 0 then
            if hours > 0 then
                timestamp = ( timestamp .. " " .. hours .. " " .. hoursTag );
            end
            if minutes > 0 then
                timestamp = ( timestamp .. " " .. minutes .. " " .. minutesTag );
            end
        else
            timestamp = ( seconds .. " " .. secondsTag );
        end
    end
    
    return timestamp;
end

-- Method:          GRM.GetTimePassedUsingStringStamp()
-- What it Does:    Returns the Years, hours, and days that have passed since the given timestamp ( In format "day mon 'year")
-- Purpose:         Honestly, simpler solution than build a solution to parse through epoch time, since I don't need hours, minutes, seconds.
GRM.GetTimePassedUsingStringStamp = function ( timestamp )
    local startYear = tonumber ( strsub ( timestamp , string.find ( timestamp , "'" )  + 1 ) ) + 2000;
    local index = string.find ( timestamp , " " );
    local monthName = strsub ( timestamp , index + 1 , index + 3 );
    local startMonth = monthEnum [ monthName ];
    local startDay = tonumber ( strsub ( timestamp , 0 , index - 1 ) );
    local _ , month , day , year = CalendarGetDate();
    local LeapYear = GRM.IsLeapYear ( year );
    local result = { 0 , 0 , 0 , "" };           -- resultYear, resultMonth , resultDay;
    -- Narrow down the year!
    if year > startYear then                -- If this event happened in a previous year.
        result[1] = year - startYear;
        if month < startMonth then          -- Event is less than a year!
            result[1] = result[1] - 1;
        elseif month == startMonth then
            -- Need to check the day!
            if day < startDay then
                result[1] = result[1] - 1;
            else
                result[1] = year - startYear;   -- If >= then it counts as 1 year.
            end
        else                                -- month > start meaning it's been a year.
            result[1] = year - startYear;
        end
    else
        result[1] = 0;
    end

    -- Ok, now let's get the month! Much easier!
    if month < startMonth then
        result[2] = month + ( 12 - startMonth );
        if day < startDay then          -- Not quite 1 month
            result[2] = result[2] - 1;
        end
    elseif month == startMonth then
        if startYear == year then
            result[2] = 0;
        else
            if day < startDay then
                result[2] = 11;
            else
                result[2] = 0;
            end
        end
    else                        -- month > start 
        if day < startDay then
            result[2] = ( month - startMonth ) - 1;
        else
            result[2] = month - startMonth;
        end
    end

    -- Finally, let's do the day!
    if day < startDay then
        -- Gonna have to take leap year into account now!
        local tempMonth = month;
        if tempMonth == 12 then
            tempMonth = 1;
        end
        result[3] = day + ( daysInMonth [ tostring ( tempMonth ) ] - startDay );
        if LeapYear then
            result[3] = result[3] + 1;
        end
    else
        result[3] = day - startDay;
    end

    --Final text report
    if result[1] > 0 then
        if result[1] == 1 then
            result[4] = result[1] .. " year ";
        else
            result[4] =  result[1] .. " years ";
        end
    end
    if result[2] > 0 then
        if result[2] == 1 then
            result[4] = result[4] .. "" .. result[2] .. " month ";
        else
            result[4] = result[4] .. "" .. result[2] .. " months ";
        end
    end
    if result[3] > 0 then
        if result[3] == 1 then
            result[4] = result[4] .. "" .. result[3] .. " day";
        else
            result[4] = result[4] .. "" .. result[3] .. " days";
        end
    end
    -- Clear off any white space.
    if result[1] == 0 and result[2] == 0 and result[3] == 0 then
        result[4] = "< 1 day";
    else
        result[4] = GRM.Trim ( result[4] );
    end
    return result;
end

-- Method:          GRM.HoursReport(int)
-- What it Does:    Reports as a string the time passed since player last logged on.
-- Purpose:         Cleaner reporting to the log, and it just reports the lesser info, no seconds and so on.
GRM.HoursReport = function ( hours )
    local result = "";
    local years = math.floor ( hours / 8766 );
    local months = math.floor ( ( hours % 8766 ) / 730.5 );
    local days = math.floor ( ( hours % 730.5 ) / 24 );

    -- Continue calculations.
    local hours = math.floor ( ( ( hours % 8760 ) % 730 ) % 24 );
    
    
    if years >= 1 then
        if years > 1 then
            result = result .. "" .. years .. " yrs ";
        else
            result = result .. "" .. years .. " yr ";
        end
    end

    if months >= 1 then
        if years > 0 then
            result = GRM.Trim ( result ) .. ", ";
        end
        if months > 1 then
            result = result .. "" .. months .. " mos ";
        else
            result = result .. "" .. months .. " mo ";
        end
    end

    if days >= 1 then
        if months > 0 then
            result = GRM.Trim ( result ) .. ", ";
        end
        if days > 1 then
            result = result .. "" .. days .. " days ";
        else
            result = result .. "" .. days .. " day ";
        end
    end

    if hours >= 1 and years < 1 and months < 1 then  -- No need to give exact hours on anything over than a month, just the day is good enough.
        if days > 0 then
            result = GRM.Trim ( result ) .. ", ";
        end
        if hours > 1 then
            result = result .. "" .. hours .. " hrs";
        else
            result = result .. "" .. hours .. " hr";
        end
    end

    if result == "" or result == nil then
        result = result .. "< 1 hour"
    end
    return result;
end

------------------------------------
------ END OF TIME METHODS ---------
------------------------------------


------------------------------------
---- ALT MANAGEMENT METHODS --------
------------------------------------

-- Method:          GRM.GetMouseOverName()
-- What it Does:    Returns the full player's name with server on mouseover
-- Purpose:         Name needed to check metadata to populate UI window.
GRM.GetMouseOverName = function( button )
    button:Click();
    button:UnlockHighlight();

    local name = GuildMemberDetailName:GetText();
    local MobileIconCheck = "\"" .. name .. "\"";
    local length = 84;

    if #MobileIconCheck > 50 then
        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
            length = 85
        end
        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
    end
    return name;
end

-- Method:          GRM.GetMobileFreeName()
-- What it Does:    Returns the cleared name properly as if player is on mobile the string will not pass through data right.
-- Purpose:         String name has an icon attached. This resolves that.
GRM.GetMobileFreeName = function ( name )
    local MobileIconCheck = "\"" .. name .. "\"";
    local length = 84;

    if #MobileIconCheck > 50 then
        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
            length = 85
        end
        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
    end
    return name;
end

-- Method:          GRM.AltButtonPos(int)
-- What it Does:    Returns the horizontal and vertical coordinates for the button position on frame
-- Purpose:         To adjust the position of the AddAlt button based on the number of alts.
GRM.AltButtonPos = function ( index )
    local result;
    if index == 0 then
        result = { 2 , -16 };
    elseif index == 1 then
        result = { 32 , -20 };
    elseif index == 2 then
        result = { -32 , -37 };
    elseif index == 3 then
        result = { 32 , -37 };
    elseif index == 4 then
        result = { -32 , -54 };
    elseif index == 5 then
        result = { 32 , -54 };
    elseif index == 6 then
        result = { -32 , -71 };
    elseif index == 7 then
        result = { 32 , -71 };
    elseif index == 8 then
        result = { -32 , -88 };
    elseif index == 9 then
        result = { 32 , -88 };
    elseif index == 10 then
        result = { -32 , -103 };
    elseif index == 11 then
        result = { 32 , -103 };
    else -- is 12+ alts
        result = { -64 , -124 };
    end
    return result;
end

-- Method:          GRM.PopulateAltFrames(string, int , int )
-- What it Does:    This generates the alt frames in the main addon metadata detail frame
-- Purpose:         Clean formatting of the alt frames.
GRM.PopulateAltFrames = function ( index1 )
    -- let's start by prepping the frames.
    local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index1][11];
    local numAlts = #listOfAlts
    local butPos = GRM.AltButtonPos ( numAlts );
    AddAltButton:SetPoint ( "TOP" , GR_CoreAltFrame , butPos[1] , butPos[2] );
    AddAltButton:Show();
    -- now, let's populate them
    if numAlts > 0 then
        local result = GRM.SlimName ( listOfAlts[1][1] );
        if listOfAlts[1][5] == true then  --- this person is the main!
            result = result .. "\n|cffff0000(main)"
        end
        GR_AltName1:SetText ( result );
        GR_AltName1:SetTextColor ( listOfAlts[1][2] , listOfAlts[1][3] , listOfAlts[1][4] , 1.0 );
        GR_AltName1:Show();
    else
        GR_AltName1:Hide();
    end
    if numAlts > 1 then
        GR_AltName2:SetText ( GRM.SlimName ( listOfAlts[2][1] ) );
        GR_AltName2:SetTextColor ( listOfAlts[2][2] , listOfAlts[2][3] , listOfAlts[2][4] , 1.0 );
        GR_AltName2:Show();
    else
        GR_AltName2:Hide();
    end
    if numAlts > 2 then
        GR_AltName3:SetText ( GRM.SlimName ( listOfAlts[3][1] ) );
        GR_AltName3:SetTextColor ( listOfAlts[3][2] , listOfAlts[3][3] , listOfAlts[3][4] , 1.0 );
        GR_AltName3:Show();
    else
        GR_AltName3:Hide();
    end
    if numAlts > 3 then
        GR_AltName4:SetText ( GRM.SlimName ( listOfAlts[4][1] ) );
        GR_AltName4:SetTextColor ( listOfAlts[4][2] , listOfAlts[4][3] , listOfAlts[4][4] , 1.0 );
        GR_AltName4:Show();
    else
        GR_AltName4:Hide();
    end
    if numAlts > 4 then
        GR_AltName5:SetText ( GRM.SlimName ( listOfAlts[5][1] ) );
        GR_AltName5:SetTextColor ( listOfAlts[5][2] , listOfAlts[5][3] , listOfAlts[5][4] , 1.0 );
        GR_AltName5:Show();
    else
        GR_AltName5:Hide();
    end
    if numAlts > 5 then
        GR_AltName6:SetText ( GRM.SlimName ( listOfAlts[6][1] ) );
        GR_AltName6:SetTextColor ( listOfAlts[6][2] , listOfAlts[6][3] , listOfAlts[6][4] , 1.0 );
        GR_AltName6:Show();
    else
        GR_AltName6:Hide();
    end
    if numAlts > 6 then
        GR_AltName7:SetText ( GRM.SlimName ( listOfAlts[7][1] ) );
        GR_AltName7:SetTextColor ( listOfAlts[7][2] , listOfAlts[7][3] , listOfAlts[7][4] , 1.0 );
        GR_AltName7:Show();
    else
        GR_AltName7:Hide();
    end
    if numAlts > 7 then
        GR_AltName8:SetText ( GRM.SlimName ( listOfAlts[8][1] ) );
        GR_AltName8:SetTextColor ( listOfAlts[8][2] , listOfAlts[8][3] , listOfAlts[8][4] , 1.0 );
        GR_AltName8:Show();
    else
        GR_AltName8:Hide();
    end
    if numAlts > 8 then
        GR_AltName9:SetText ( GRM.SlimName ( listOfAlts[9][1] ) );
        GR_AltName9:SetTextColor ( listOfAlts[9][2] , listOfAlts[9][3] , listOfAlts[9][4] , 1.0 );
        GR_AltName9:Show();
    else
        GR_AltName9:Hide();
    end
    if numAlts > 9 then
        GR_AltName10:SetText ( GRM.SlimName ( listOfAlts[10][1] ) );
        GR_AltName10:SetTextColor ( listOfAlts[10][2] , listOfAlts[10][3] , listOfAlts[10][4] , 1.0 );
        GR_AltName10:Show();
    else
        GR_AltName10:Hide();
    end
    if numAlts > 10 then
        GR_AltName11:SetText ( GRM.SlimName ( listOfAlts[11][1] ) );
        GR_AltName11:SetTextColor ( listOfAlts[11][2] , listOfAlts[11][3] , listOfAlts[11][4] , 1.0 );
        GR_AltName11:Show();
    else
        GR_AltName11:Hide();
    end
    if numAlts > 11 then
        GR_AltName12:SetText ( GRM.SlimName ( listOfAlts[12][1] ) );
        GR_AltName12:SetTextColor ( listOfAlts[12][2] , listOfAlts[12][3] , listOfAlts[12][4] , 1.0 );
        GR_AltName12:Show();
    else
        GR_AltName12:Hide();
    end
    GR_CoreAltFrame:Show();
end

-- Method:          GRM.GetClassColorRGB ( string )
-- What it Does:    Returns the 0-1 RGB color scale for the player class
-- Purpose:         Easy class color tagging for UI feature.
GRM.GetClassColorRGB = function ( className )
    local result = {};
     if className == "DEATHKNIGHT" then
        result = { 0.77 , 0.12 , 0.23 }
    elseif className == "DEMONHUNTER" then
        result = { 0.64 , 0.19 , 0.79 }
    elseif className == "DRUID" then
        result = { 1.0 , 0.49 , 0.04 }
    elseif className == "HUNTER" then
        result = { 0.67 , 0.83 , 0.45 }
    elseif className == "MAGE" then
        result = { 0.41 , 0.80 , 0.94 }
    elseif className == "MONK" then
        result = { 0.0 , 1.0 , 0.59 }
    elseif className == "PALADIN" then
        result = { 0.96 , 0.55 , 0.73 }
    elseif className == "PRIEST" then
        result = { 1.0 , 1.0 , 1.0 }
    elseif className == "ROGUE" then
        result = { 1.0 , 0.96 , 0.41 }
    elseif className == "SHAMAN" then
        result = { 0.0 , 0.44 , 0.87 }
    elseif className == "WARLOCK" then
        result = { 0.58 , 0.51 , 0.79 }
    elseif className == "WARRIOR" then
        result = { 0.78 , 0.61 , 0.43 }
    end
    return result;
end

-- Method:          GRM.RemoveAlt(string , string , string)
-- What it Does:    Detags the given altName to that set of toons.
-- Purpose:         Alt management, so whoever has addon installed can tag player.
GRM.RemoveAlt = function ( playerName , altName , guildName )
    local isRemoveMain = false;
    if playerName ~= altName then
        local index1;
        local altIndex1;
        local count = 0;

        -- This block is mainly for resource efficiency, to prevent the blocks from getting too nested, and to store index location for quick access.
        for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do      
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then        -- Identify position of player
                count = count + 1;
                index1 = j;
            end
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == altName then           -- Pull altName to attach class on Color
                count = count + 1;
                altIndex1 = j;
                -- Need to preserve the list, in the case of syncing to live update the frames if they are on the alt of the alt.
                if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                    GR_AddonGlobals.selectedAltList = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11];
                end
                if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 1 and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] then -- No need to report if the person is removing the last alt. No need to set oneself as main.
                    isRemoveMain = true;
                end
            end
            if count == 2 then
                break;
            end
        end

        -- Removing the alt from all of the player's alts.'
        local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index1][11];
        if #listOfAlts > 0 then                                                                                                     -- There is more than 1 alt for new alt to be added to
            for i = 1 , #listOfAlts do
                if listOfAlts[i][1] ~= altName then                                                                                 -- Cycle through previously known alt names to add new on each, one by one.
                    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                                                             -- Need to now cycle through all toons in the guild to set the alt
                        if listOfAlts[i][1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then                                       -- name on current focus altList found in the metadata and is not the alt to be removed.
                            -- Now, we have the list!
                            for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] do
                                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][1] == altName then
                                    table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] , m );     -- removing the alt
                                    break;
                                end
                            end
                            break;
                        end
                    end
                end
            end
        end
        -- Remove the alt name from the current focus
        for i = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index1][11] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index1][11][i][1] == altName then
                table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index1][11] , i );
                break;
            end
        end
        -- Resetting the alt's list
        if isRemoveMain then 
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex1][10] = false;
        end
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex1][11] = nil;
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex1][11] = {};
        -- Insta update the frames!
        if MemberDetailMetaData ~= nil and MemberDetailMetaData:IsVisible() then
            local altFound = false;
            if #GR_AddonGlobals.selectedAltList > 0 then
                for m = 1 , #GR_AddonGlobals.selectedAltList do
                    if GR_AddonGlobals.selectedAltList[m][1] == GuildMemberDetailName:GetText() then
                        -- Alt is found! Let's update the alt frames!
                        altFound = true;
                        for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][1] == GR_AddonGlobals.selectedAltList[m][1] then
                                -- woot! Now have the index of the alt and can successfully populate the alt frames.
                                GRM.PopulateAltFrames ( i );
                            end
                        end
                        break;
                    end
                end
            end
            -- If it is just the player's same frame, then update it!
            if not altFound and playerName == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
                GRM.PopulateAltFrames ( index1 );
            end
        end
    else
        print ( GRM.SlimName ( playerName ) .. " cannot remove themselves from alts." );
    end

    -- Warn the player that the toon they removed is the main!
    if isRemoveMain then
        print ( GRM.SlimName ( altName ) .. " was listed as the main! Don't forget to set a new main!" );
    end
end

-- Method:          GRM.AddAlt (string,string,string)
-- What it Does:    Tags toon to a player's set of alts. It will tag them not just to the given player, but reverse tag itself to all of the alts.
-- Purpose:         Organizing a player and their alts.
GRM.AddAlt = function ( playerName , altName , guildName )
    if playerName ~= altName then
        -- First, let's identify player index, then identify the classColor of the alt
        local index2;
        local altIndex2;
        local count = 0;
        local classAlt = "";
        local classMain = "";
        local classColorsAlt , classColorsMain , classColorsTemp;
        local isMain = false;

        -- This block is mainly for resource efficiency, to prevent the blocks from getting too nested, and to store index location for quick access.
        for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do      
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then        -- Identify position of player
                count = count + 1;
                index2 = j;
                classMain = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][9];
            end
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == altName then           -- Pull altName to attach class on Color
                count = count + 1;
                altIndex2 = j;
                -- Need to preserve the list, in the case of syncing to live update the frames if they are on the alt of the alt.
                if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                    GR_AddonGlobals.selectedAltList = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11];
                end
                classAlt = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][9];
            end
            if count == 2 then
                break;
            end
        end

        -- NEED TO VERIFY IT IS NOT AN ALT FIRST!!! it is removing and re-adding if it is same person.
        local isFound = false;
        if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] > 0 then
            local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11];
            
            for m = 1 , #listOfAlts do                                              -- Let's quickly verify that this is not a repeat alt add.
                if listOfAlts[m][1] == playerName then
                    print ( GRM.SlimName ( altName ) .. " is Already Listed as an Alt." );
                    isFound = true;
                    break;
                end
            end
        end
        -- If player is trying to add this toon to a list that is already on a list then it adds it in reverse
        if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] > 0 and #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] > 0 and not isFound then  -- Oh my! Both players have current lists!!! Remove the alt from his list, add to this new one.
            GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11][1][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][1] , guildName );
        end
        if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] > 0 then

            if isFound ~= true then
                GRM.AddAlt ( altName , playerName , guildName );
            end
            
        else
            -- add altName to each of the previously
            local isFound2 = false;
            classColorsAlt = GRM.GetClassColorRGB ( classAlt );
            local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11];
            if #listOfAlts > 0 then                                                                 -- There is more than 1 alt for new alt to be added to
                for i = 1 , #listOfAlts do                                                          -- Cycle through previously known alt names to add new on each, one by one.
                    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                             -- Need to now cycle through all toons in the guild to set the alt
                        if listOfAlts[i][1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then       -- name on current focus altList found in the metadata!
                            -- Now, make sure it is not a repeat add!
                            
                            for m = 1 , #listOfAlts do                                              -- Let's quickly verify that this is not a repeat alt add.
                                if listOfAlts[m][1] == altName then
                                    print( GRM.SlimName ( altName ) .. " is Already Listed as an Alt." );
                                    isFound2 = true;
                                    break;
                                end
                            end
                            if isFound2 ~= true then
                                classColorsTemp = GRM.GetClassColorRGB ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][9] );
                                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] , { altName , classColorsAlt[1] , classColorsAlt[2] , classColorsAlt[3] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][10] } ); -- altName is added to a currentFocus previously added alt.
                                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] , { GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , classColorsTemp[1] , classColorsTemp[2] , classColorsTemp[3] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] } );
                            end
                            break;
                        end
                    end
                    if isFound2 then
                        break;
                    end
                end
            end

            if isFound2 ~= true then
                -- Add all of the CurrentFocus player's alts to the new alt
                -- then add the currentFocus player as well
                classColorsMain = GRM.GetClassColorRGB ( classMain );
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] then
                    table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] , 1 , { playerName , classColorsMain[1] , classColorsMain[2] , classColorsMain[3] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] } );
                else
                    table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][11] , { playerName , classColorsMain[1] , classColorsMain[2] , classColorsMain[3] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] } );
                end
                -- Finally, let's add the alt to the player's currentFocus.
                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] , { altName , classColorsAlt[1] , classColorsAlt[2] , classColorsAlt[3] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][10] } );
            end
            -- Insta update the frames!
            if MemberDetailMetaData ~= nil and MemberDetailMetaData:IsVisible() then
                -- For use with syncing UI LIVE
                local altFound = false;
                if #GR_AddonGlobals.selectedAltList > 0 then
                    for m = 1 , #GR_AddonGlobals.selectedAltList do
                        if GR_AddonGlobals.selectedAltList[m][1] == GuildMemberDetailName:GetText() then
                            -- Alt is found! Let's update the alt frames!
                            altFound = true;
                            for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][1] == GR_AddonGlobals.selectedAltList[m][1] then
                                    -- woot! Now have the index of the alt and can successfully populate the alt frames.
                                    GRM.PopulateAltFrames ( i );
                                end
                            end
                            break;
                        end
                    end
                end

                if not altFound then
                    if playerName == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then 
                        GRM.PopulateAltFrames ( index2 );
                    elseif altName == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
                        GRM.PopulateAltFrames ( altIndex2 );
                    end
                end
            end
        end
    else
        print ( GRM.SlimName ( playerName ) .. " cannot become their own alt!" );
    end
end


-- Method:              GRM.SortMainToTop (string , int , int , string)
-- What it Does:        Sorts the alts list and sets the main to the top.
-- Purpose:             To keep the main as the first name in the list of alts.
GRM.SortMainToTop = function ( playerName , index2 )
    local tempList;
    -- Ok, now, let's grab the list and do some sorting!
    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] ~= true then                               -- no need to attempt sorting if they are all alts, none are the main.
        for i = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] do                           -- scanning through the list of alts
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][i][5] then                         -- if one of them equals the main!
                tempList = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][i];                    -- Saving main's info to temp holder
                table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] , i );             -- removing
                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] , 1 , tempList );  -- Re-adding it to the front and done!
                break
            end
        end
    end
end

-- Method:              GRM.SetMain (string,string,string)
-- What it Does:        Sets the player as main, as well as updates that status among the alt grouping.
-- Purpose:             Main/alt management control.
GRM.SetMain = function ( playerName , mainName , guildName )
    local index2;
    local altIndex2;
    local count = 0;

    -- This block is mainly for resource efficiency, to prevent the blocks from getting too nested,difficult to follow, and bloated.
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do      
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then        -- Identify position of player
            index2 = j;
            if playerName == mainName then                               -- no need to identify an alt if there is none.
                break;
            else
                count = count + 1;
            end
        end
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == mainName then           -- Pull mainName to attach class on Color
            count = count + 1;
            altIndex2 = j;
        end
        if count == 2 then
            break;
        end
    end

    local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11];
    if #listOfAlts > 0 then
        -- Need to tag each alt's list with who is the main.
        for i = 1 , #listOfAlts do
            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                                  -- Cycling through the guild names to find the alt match
                if listOfAlts[i][1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then            -- Alt location identified!
                    -- Now need to find the name of the alt to tag it.
                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == mainName then                -- this alt is the main!
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = true;                       -- Setting toon as main!
                        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] do               -- making sure all their alts are listed as notMain
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = false;
                        end
                    else
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = false;                      -- ensure alt is not listed as main
                        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] do               -- identifying who is to be tagged as main
                            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][1] == mainName then
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = true;
                            else
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = false;        -- tagging everyone not the main as false
                            end
                        end
                    end

                    -- Now, let's sort
                    GRM.SortMainToTop ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , j );
                    break
                end
            end            
        end
    end

    -- Let's ensure the main is the main!
    if playerName ~= mainName then
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] = false;
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][10] = true;
        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] do               -- identifying who is to be tagged as main
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][1] == mainName then
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][5] = true;
            else
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][5] = false;        -- tagging everyone not the main as false
            end
        end
        GRM.SortMainToTop ( playerName , index2 );
    else
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] = true;
    end
    -- Insta update the frames!
    if MemberDetailMetaData ~= nil and MemberDetailMetaData:IsVisible() then
        if mainName ~= GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
            GRM.PopulateAltFrames ( index2 );
        elseif mainName == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
            GRM.PopulateAltFrames ( altIndex2 );
        end
    end
end

-- Method:          GRM.PlayerHasMain( string , int , int )
-- What it Does:    Returns true if either the player has a main or is a main themselves
-- Purpose:         Better alt management logic.
GRM.PlayerHasMain = function ( playerName , index2 )
    local hasMain = false;

    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] then
        hasMain = true;
    else
        for i = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][i][5] then
                hasMain = true;
                break;
            end
        end
    end
    return hasMain;
end

-- Method:          GRM.GetCoreFontStringClicked()
-- What it Does:    Returns a table with the name of the player, the altName, and the guild.
-- Puspose:         To easily pass the info on without having to use a global variable, and set one function to all 12 alt frames.
GRM.GetCoreFontStringClicked = function()
    local altName;
    local focusName = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );
    local isMain = false;
    local isAlt1 = false;
    for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][1] == focusName then
    
            if GR_AltName1:IsVisible() and GR_AltName1:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][1][1];
                isAlt1 = true;
            elseif GR_AltName2:IsVisible() and GR_AltName2:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][2][1];
            elseif GR_AltName3:IsVisible() and GR_AltName3:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][3][1];
            elseif GR_AltName4:IsVisible() and GR_AltName4:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][4][1];
            elseif GR_AltName5:IsVisible() and GR_AltName5:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][5][1];
            elseif GR_AltName6:IsVisible() and GR_AltName6:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][6][1];
            elseif GR_AltName7:IsVisible() and GR_AltName7:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][7][1];
            elseif GR_AltName8:IsVisible() and GR_AltName8:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][8][1];
            elseif GR_AltName9:IsVisible() and GR_AltName9:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][9][1];
            elseif GR_AltName10:IsVisible() and GR_AltName10:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][10][1];
            elseif GR_AltName11:IsVisible() and GR_AltName11:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][11][1];
            elseif GR_AltName12:IsVisible() and GR_AltName12:IsMouseOver( 2 , -2 , -2 , 2 ) then
                altName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][11][12][1];
            elseif ( GRM_MemberDetailRankDateTxt:IsVisible() and GRM_MemberDetailRankDateTxt:IsMouseOver ( 2 , -2 , -2 , 2 ) ) or ( GRM_JoinDateText:IsVisible() and GRM_JoinDateText:IsMouseOver ( 2 , -2 , -2 , 2 ) ) or GRM_MemberDetailNameText:IsMouseOver ( 2 , -2 , -2 , 2 ) then -- Covers both promo date and join date focus.
                altName = focusName;
            else
                -- MOUSE WAS NOT OVER, EVEN ON A RIGHT CLICK OF THE FRAME!!!
                focusName = nil;
                altName = nil;
            end
            break;
        end
    end
    if ( isAlt1 and altName ~= nil and string.find ( GR_AltName1:GetText() , "(main)" ) ~= nil ) then        -- This is the main! Let's parse main out of the name!
        isMain = true;
    elseif altName == focusName and GRM_MemberDetailMainText:IsVisible() then
        isMain = true;
    end
    return { focusName , altName , GR_AddonGlobals.guildName , isMain };
end


-- Method:              GRM.DemoteFromMain ( string , string , string )
-- What it Does:        If the player is "main" then it removes the main tag to false
-- Purpose:             User Experience (UX) and alt management!
GRM.DemoteFromMain = function ( playerName , mainName , guildName )
    local index2;
    local altIndex2;
    local count = 0;

    -- This block is mainly for resource efficiency, to prevent the blocks from getting too nested,difficult to follow, and bloated.
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do      
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then   -- Identify position of player
            index2 = j;
            if playerName == mainName then                                                                          -- no need to identify an alt if there is none.
                break;
            else
                count = count + 1;
            end
        end
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == mainName then     -- Pull mainName to attach class on Color
            count = count + 1;
            altIndex2 = j;
        end
        if count == 2 then
            break;
        end
    end

    local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11];
    if #listOfAlts > 0 then
        -- Need to tag each alt's list with who is the main.
        for i = 1 , #listOfAlts do
            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                                  -- Cycling through the guild names to find the alt match
                if listOfAlts[i][1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then            -- Alt location identified!
                    -- Now need to find the name of the alt to tag it.
                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == mainName then                -- this alt is the main!
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = false;                       -- Setting toon as main!
                        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] do               -- making sure all their alts are listed as notMain
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = false;
                        end
                    else
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = false;                      -- ensure alt is not listed as main
                        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] do               -- identifying who is to be tagged as main
                            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][1] == mainName then
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = false;
                            else
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][5] = false;        -- tagging everyone not the main as false
                            end
                        end
                    end

                    -- Now, let's sort
                    GRM.SortMainToTop ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , j );
                    break
                end
            end            
        end
    end

    -- Let's ensure the main is the main!
    if playerName ~= mainName then
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] = false;
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][altIndex2][10] = false;
        for m = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11] do               -- identifying who is to be tagged as main
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][1] == mainName then
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][5] = false;
            else
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][11][m][5] = false;        -- tagging everyone not the main as false
            end
        end
        GRM.SortMainToTop ( playerName , index2 );
    else
        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][index2][10] = false;
    end
    -- Insta update the frames!
    if MemberDetailMetaData ~= nil and MemberDetailMetaData:IsVisible() then
        if mainName ~= GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
            GRM.PopulateAltFrames ( index2 );
        elseif mainName == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
            GRM.PopulateAltFrames ( altIndex2 );
        end
    end
end

-- Method:          GRM.ResetAltButtonHighlights();
-- What it Does:    Just resets the highlight of the tab/alt-tab highlight for a better user-experience to default position
-- Purpose:         UX
GRM.ResetAltButtonHighlights = function()
    AddAltNameButton1:LockHighlight();
    AddAltNameButton2:UnlockHighlight();
    AddAltNameButton3:UnlockHighlight();
    AddAltNameButton4:UnlockHighlight();
    AddAltNameButton5:UnlockHighlight();
    AddAltNameButton6:UnlockHighlight();
    GR_AddonGlobals.currentHighlightIndex = 1;
end


-- Method:          GRM.AddAltAutoComplete()
-- What it Does:    Takes the entire list of guildies, then sorts them as player types to be added to alts list
-- Purpose:         Eliminates the possibility of a person entering a fake name of a player no longer in the guild.
GRM.AddAltAutoComplete = function()
    local partName = AddAltEditBox:GetText();
    GR_AddonGlobals.listOfGuildies = nil;
    GR_AddonGlobals.listOfGuildies = {};
    local numButtons = 6;

    for i = 1 , GRM.GetNumGuildies() do
        local name = GetGuildRosterInfo( i );
        if name ~= GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then   -- no need to go through player's own window
            table.insert ( GR_AddonGlobals.listOfGuildies , name );
        end
    end
    sort ( GR_AddonGlobals.listOfGuildies );    -- Alphabetizing it for easier parsing for buttontext updating.
    
    -- Now, let's identify the names that match
    local count = 0;
    local matchingList = {};
    local found = false;
    for i = 1 , #GR_AddonGlobals.listOfGuildies do
        local innerFound = false;
        if string.lower ( partName ) == string.lower ( string.sub ( GR_AddonGlobals.listOfGuildies[i] , 1 , #partName ) ) then
            innerFound = true;
            found = true;
            count = count + 1;
            table.insert ( matchingList , GR_AddonGlobals.listOfGuildies[i] );
        end
        if count > 6 then
            break;
        end
        if innerFound ~= true and found then    -- resource saving
            break;
        end
    end
    
    -- Populate the buttons now...
    if partName ~= nil and partName ~= "" then
        local resultCount = #matchingList;
        GRM.ResetAltButtonHighlights();
        if resultCount > 0 then
            AddAltEditFrameHelpText:Hide();
            AddAltNameButton1Text:SetText ( matchingList[1] );
            AddAltNameButton1:Enable();
            AddAltNameButton1:Show();
            AddAltEditFrameTextBottom:Show();
        else
            AddAltEditFrameHelpText:SetText ( "Player Not Found" );
            AddAltEditFrameHelpText:Show();
            AddAltNameButton1:Hide();
            AddAltEditFrameTextBottom:Hide();
        end
        if resultCount > 1 then
            AddAltNameButton2Text:SetText ( matchingList[2] );
            AddAltNameButton2:Enable();
            AddAltNameButton2:Show();
        else
            AddAltNameButton2:Hide();
        end
        if resultCount > 2 then
            AddAltNameButton3Text:SetText ( matchingList[3] );
            AddAltNameButton3:Enable();
            AddAltNameButton3:Show();
        else
            AddAltNameButton3:Hide();
        end
        if resultCount > 3 then
            AddAltNameButton4Text:SetText ( matchingList[4] );
            AddAltNameButton4:Enable();
            AddAltNameButton4:Show();
        else
            AddAltNameButton4:Hide();
        end
        if resultCount > 4 then
            AddAltNameButton5Text:SetText ( matchingList[5] );
            AddAltNameButton5:Enable();
            AddAltNameButton5:Show();
        else
            AddAltNameButton5:Hide();
        end
        if resultCount > 5 then
            if resultCount == 6 then
                AddAltNameButton6Text:SetText ( matchingList[6] );
                AddAltNameButton6:Enable();
            else
                AddAltNameButton6Text:SetText ( "..." );
                AddAltNameButton6:Disable();
            end
            AddAltNameButton6:Show();
        else
            AddAltNameButton6:Hide();
        end
    else
        AddAltNameButton1:Hide();
        AddAltNameButton2:Hide();
        AddAltNameButton3:Hide();
        AddAltNameButton4:Hide();
        AddAltNameButton5:Hide();
        AddAltNameButton6:Hide();
        GRM.ResetAltButtonHighlights();
        AddAltEditFrameTextBottom:Hide();
        AddAltEditFrameHelpText:SetText ( "Please Type the Name\nof the alt" );
        AddAltEditFrameHelpText:Show();  
    end
end

-- Method:              GRM.KickAllAlts ( string , string )
-- What it Does:        Bans and/or kicks all the alts a player has given the status of checekd button on ban window.
-- Purpose:             QoL. Option to ban players' alts as well if they are getting banned.
GRM.KickAllAlts = function ( playerName , guildName )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do      
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then        -- Identify position of player
        -- Ok, let's parse the player's data!
            local listOfAlts = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11];
            if #listOfAlts > 0 then                                  -- There is at least 1 alt
                for m = 1 , #listOfAlts do                           -- Cycling through the alts
                    if GR_PopupWindowCheckButton1:GetChecked() then     -- Player wants to BAN the alts!
                        for s = 1 , #listOfAlts do
                            for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == listOfAlts[s][1] and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] ~= GR_AddonGlobals.addonPlayerName then        -- Logic to avoid kicking oneself ( or at least to avoid getting error notification )
                                    -- Set the banned info.
                                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][17] = true;
                                    local instructionNote = "Reason Banned? (Press ENTER when done)";
                                    local result = MemberDetailPopupEditBox:GetText();

                                    if result ~= nil and result ~= instructionNote and result ~= "" then
                                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = result;
                                    elseif result == nil then
                                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = "";
                                    end

                                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = result;
                                    GuildUninvite ( listOfAlts[s][1] );

                                    break;
                                end
                            end
                        end
                        break;
                    else
                        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][1] ~= GR_AddonGlobals.addonPlayerName then
                            GuildUninvite ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][m][1] );
                        end                       
                    end
                end
            end
            break;
        end
    end
end


------------------------------------
---- END OF ALT MANAGEMENT ---------
------------------------------------



------------------------------------
------ METADATA TRACKING LOGIC -----
--- Reporting, Live Tracking, Etc --
------------------------------------

-- Method:          GRM.AddMemberRecord()
-- What it Does:    Builds Member Record into Guild History with various metadata
-- Purpose:         For reliable guild data tracking.
GRM.AddMemberRecord = function ( memberInfo , isReturningMember , oldMemberInfo , guildName )
    -- Metadata to track on all players.
    -- Basic Info
    local timeSeconds = time();
    local name = memberInfo[1];
    local slim = GRM.SlimName ( name );
    local joinDate = GRM.GetTimestamp();
    local joinDateMeta = timeSeconds;  -- Saved in Seconds since Jan 1, 1970, to be parsed later
    local rank = memberInfo[2];
    local rankInd = memberInfo[3];
    local currentLevel = memberInfo[4];
    local note = memberInfo[5];
    local officerNote = memberInfo[6];
    local class = memberInfo[7]; 
    local isMainToon = false;
    local listOfAltsInGuild = {};
    local dateOfLastPromotion = nil;
    local dateOfLastPromotionMeta = nil;
    local birthday = nil;

    -- Event and Anniversary tracking.
    local eventTrackers = { { slim .. "'s Anniversary!" , nil , false , "" } , { slim .. "'s Birthday!" , nil , false , "" } };  -- Position 1 = anniversary , Position 2 = birthday , 3 = anniversary For Each = { date , needsToNotify , SpecialNotes }
    local customNote = ""; -- Extra note space, for GM to add futher info.

    -- Info nil now, but to be populated on leaving the guild
    local leftGuildDate = {};
    local leftGuildDateMeta = {};
    local bannedFromGuild = false;
    local reasonBanned = "";
    local oldRank = nil;
    local oldJoinDate = {}; -- filled upon player leaving the guild.
    local oldJoinDateMeta = {};

    -- Pieces info that were added on later-- from index 24 of metaData array, so as not to mess with previous code
    local lastOnline = 0;                                                                           -- Stores it in number of HOURS since last online.
    local rankHistory = {};
    local playerLevelOnJoining = currentLevel;
    local recommendToKickReported = false;
    -- More metadata!
    local zone = memberInfo[9];
    local achievementPoints = memberInfo[10];
    local isMobile = memberInfo[11];
    local rep = memberInfo[12];
    local timePlayerEnteredZone = timeSeconds;  -- ( time() - timePlayerEnteredZone ) = seconds passed. If zone changes, player re-timestamps it...
    local isOnline = memberInfo[13];
    local currentStatus = memberInfo[14];       -- AFK, Active, Busy

    if isReturningMember then
        dateOfLastPromotion = oldMemberInfo[12];
        dateOfLastPromotionMeta = oldMemberInfo[13];
        birthday = oldMemberInfo[14];
        leftGuildDate = oldMemberInfo[15];
        leftGuildDateMeta = oldMemberInfo[16];
        bannedFromGuild = oldMemberInfo[17];
        reasonBanned = oldMemberInfo[18];
        oldRank = oldMemberInfo[19];
        oldJoinDate = oldMemberInfo[20];
        table.insert ( oldJoinDate , joinDate );                -- Add the new join date to history
        oldJoinDateMeta = oldMemberInfo[21];
        table.insert ( oldJoinDateMeta , joinDateMeta );        -- likewise, add the meta seconds.
        specialTrackers = oldMemberInfo[22];
        customNote = oldMemberInfo[23];
        rankHistory = oldMemberInfo[25];
        playerLevelOnJoining = oldMemberInfo[26];
    end

    -- For both returning players and new adds
    table.insert ( rankHistory , { rank , strsub ( joinDate , 1 , string.find ( joinDate , "'" ) + 2 ) , joinDateMeta } );

    table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] , { name , joinDate , joinDateMeta , rank , rankInd , currentLevel , note , officerNote , class , isMainToon ,
        listOfAltsInGuild , dateOfLastPromotion , dateOfLastPromotionMeta , birthday , leftGuildDate , leftGuildDateMeta , bannedFromGuild , reasonBanned , oldRank ,
            oldJoinDate , oldJoinDateMeta , eventTrackers , customNote , lastOnline , rankHistory , playerLevelOnJoining , 56 , zone , achievementPoints ,
                        isMobile , rep , timePlayerEnteredZone , isOnline , memberStatus } );  -- 34 so far.
end

-- Method:          GRM.GetGuildEventString ( int , string )
-- What it Does:    Gets more exact info from the actual Guild Event Log ( can only be queried once per 10 seconds) as a string
-- Purpose:         This parses more exact info, like "who" did the kicking, or "who" invited who, and so on.
GRM.GetGuildEventString = function ( index , playerName )
    -- index 1 = demote , 2 = promote , 3 = remove/quit , 4 = invite/join
    local result = "";
    local eventType = { "demote" , "promote" , "invite" , "join" , "quit" , "remove" };
    QueryGuildEventLog();

    if index == 1 or index == 2 then
        for i = GetNumGuildEvents() , 1 , -1 do
            local type , p1, p2 , rank = GetGuildEventInfo ( i );
            if eventType [ 1 ] == type or eventType [ 2 ] == type and p2 ~= nil and p2 == playerName then
                if index == 1 and eventType [ 1 ] == type then
                    result = ( p1 .. " DEMOTED " .. p2 );
                    break;
                elseif index == 2 and eventType [ 2 ] == type then
                    result = ( p1 .. " PROMOTED " .. p2 );
                    break;
                end
            end
        end
   elseif index == 3 then
        local notFound = true;
        for i = GetNumGuildEvents() , 1 , -1 do 
            local type , p1, p2 , rank = GetGuildEventInfo ( i );
            if eventType [ 5 ] == type or eventType [ 6 ] == type then   -- Quit or Remove
                if eventType [ 6 ] == type and p2 ~= nil and p2 == playerName then
                    result = ( p1 .. " KICKED " .. p2 .. " from the guild!" );
                    notFound = false;
                elseif eventType [ 5 ] == type and p1 == playerName then
                    -- FOUND!
                    result = ( p1 .. " has Left the guild" );
                    notFound = false;
                end
                if notFound ~= true then
                    break;
                end
            end
        end
    elseif index == 4 then
        for i = GetNumGuildEvents() , 1 , -1 do 
            local type , p1, p2 , rank = GetGuildEventInfo ( i );
            if eventType [ 3 ] == type and p1 ~= nil and p2 ~= nil and p2 == playerName then   -- Quit or Remove
                result = ( p1 .. " INVITED " .. p2 .. " to the guild." );
                break;
            end
        end
    end

    return result;
end

-- Method:          GRM.GetMessageRGB( int )
-- What it Does:    Returns the 3 RGB colors colors based on the given index on a 1.0 scale
-- Purpose:         Save on code when need color call. I also did this as a 3 argument return, rather than a single array, just as a proof of concept
--                  since this whole project was also a bit of a Lua learning moment.
GRM.GetNMessageRGB = function ( index )
    local r = 0;
    local g = 0;
    local b = 0;

    if index == 1 then      -- Promotion 
        r = 1.0;
        g = 0.914;
        b = 0.0;
    elseif index == 2 then  -- Demotion
        r = 0.91;
        g = 0.388;
        b = 0.047;
    elseif index == 3 then  -- Leveled
        r = 0;
        g = 0.44;
        b = 0.87;
    elseif index == 4 then  -- Note
        r = 1.0;
        g = 0.6;
        b = 1.0;
    elseif index == 5 then  -- OfficerNote
        r = 1.0;
        g = 0.094;
        b = 0.93;
    elseif index == 6 then  -- Rank Rename
        r = 0.64;
        g = 0.102;
        b = 0.102;
    elseif index == 7 or index == 8 then  -- Join/Rejoin
        r = 0.5;
        g = 1.0;
        b = 0;
    elseif index == 9 then  -- Banned Player
        r = 1.0;
        g = 0;
        b = 0;
    elseif index == 10 then -- Left Guild
        r = 0.5;
        g = 0.5;
        b = 0.5;
    elseif index == 11 then -- NameChange
        r = 0.90;
        g = 0.82;
        b = 0.62;
    elseif index == 12 then -- WhiteText
        r = 1.0;
        g = 1.0;
        b = 1.0;
    elseif index == 13 then -- Rejoining Player Warning (RED)
        r = 0.4;
        g = 0.71;
        b = 0.9;
    elseif index == 14 then -- Return from inactivity
        r = 0;
        g = 1.0;
        b = 0.87;
    elseif index == 15 then -- Event Announcement
        r = 0;
        g = 0.8;
        b = 1.0;
    elseif index == 16 then -- Recommendations
        r = 1.0;
        g = 0.0;
        b = 0.0;
    end

    return r , g , b;
end

-- Method:          GRM.AddLog(int , string)
-- What it Does:    Adds a simple array to the Logreport that includes the indexcode for color, and the included changes as a string
-- Purpose:         For ease in adding to the core log.
GRM.AddLog = function ( indexCode , logEntry )
        table.insert ( GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] , { indexCode , logEntry } );
end

-- Method:          GRM.PrintLog(index)
-- What it Does:    Sets the color of the string to be reported to the frame (typically chat frame, or to the Log Report frame)
-- Purpose:         Color coding log and chat frame reporting.
GRM.PrintLog = function ( index , logReport , LoggingIt ) -- 2D array index and logReport ?? 
    -- Which frame to send AddMessage
    local chat = DEFAULT_CHAT_FRAME;
    -- index of what kind of report, thus determining color
    if ( index == 1 ) then -- Promoted
        if LoggingIt then
            -- Add to log
        else
            -- sending it to chatFrame
            chat:AddMessage( logReport , 1.0 , 0.914 , 0.0 );
        end
    elseif ( index == 2 ) then -- Demoted
        if LoggingIt then
            -- Add to log
        else
            -- sending it to chatFrame
            chat:AddMessage( logReport , 0.91 , 0.388 , 0.047 );
        end
    elseif ( index == 3 ) then -- Leveled
        if LoggingIt then
            -- Add to log
        else
            -- sending it to chatFrame
            chat:AddMessage( logReport , 0.0 , 0.44 , 0.87 );
        end
    elseif ( index == 4 ) then -- Note
        if LoggingIt then
            
        else
            chat:AddMessage( logReport , 1.0 , 0.6 , 1.0 );
        end
    elseif ( index == 5 ) then -- Officer Note
        if LoggingIt then
            
        else
            chat:AddMessage( logReport , 1.0 , 0.094 , 0.93 );
        end
    elseif ( index == 6 ) then -- Rank Renamed
        if LoggingIt then
            
        else
            chat:AddMessage( logReport , 0.64 , 0.102 , 0.102 );
        end
    elseif ( index == 7 ) or ( index == 8 ) then -- Join and Rejoin!
        if LoggingIt then
            
        else
            chat:AddMessage( logReport, 0.5, 1.0, 0 );
        end
    elseif ( index == 9 ) then -- WARNING BANNED PLAYER REJOIN!
        if LoggingIt then
            
        else
            chat:AddMessage( logReport , 1.0 , 0.0 , 0.0 );
        end
    elseif ( index == 10 ) then -- Left the guild
        if LoggingIt then
            
        else
            chat:AddMessage( logReport, 0.5, 0.5, 0.5 );
        end
    elseif ( index == 11 ) then -- Namechanged
        if LoggingIt then
            
        else
            chat:AddMessage( logReport, 0.9 , 0.82 , 0.62 );
        end
    elseif ( index == 12 ) then -- WHITE TEXT IGNORE RGB COLORING
        if LoggingIt then

        else
            chat:AddMessage( logReport , 1.0 , 1.0 , 1.0 );
        end
    elseif ( index == 13 ) then -- Rejoining PLayer Custom Note Report
        if LoggingIt then

        else
            chat:AddMessage( logReport , 0.4 , 0.71 , 0.9 )
        end
    elseif ( index == 14 ) then -- Player has returned from inactivity
        if LoggingIt then

        else
            chat:AddMessage( logReport , 0 , 1.0 , 0.87 );
        end
    elseif ( index == 15 ) then -- For event notifications like upcoming anniversaries.
        if LoggingIt then

        else
            chat:AddMessage( logReport , 0 , 0.8 , 1.0 );
        end
    elseif ( index == 16 ) then -- For Recommendations
        if LoggingIt then

        else
            chat:AddMessage( logReport , 1.0 , 0.0 , 0.0 );
        end
    elseif ( index == 99 ) then
        -- Addon Name Report Colors!
        
    end
end

-- Method:          GRM.BuildEventCalendarManagerScrollFrame()
-- What it Does:    This populates properly the event ScrollFrame
-- Purpose:         Scroll Frame management for smoother User Experience
GRM.BuildEventCalendarManagerScrollFrame = function()
    -- SCRIPT LOGIC ON ADD EVENT SCROLLING FRAME
    local scrollHeight = 0;
    local scrollWidth = 220;
    local buffer = 5;

    AddEventScrollChildFrame.allFrameButtons = AddEventScrollChildFrame.allFrameButtons or {};  -- Create a table for the Buttons.
    -- populating the window correctly.
    for i = 1 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] - 1 do
        -- if font string is not created, do so.
        if not AddEventScrollChildFrame.allFrameButtons[i] then
            local tempButton = CreateFrame ( "Button" , "PlayerToAdd" .. i , AddEventScrollChildFrame ); -- Names each Button 1 increment up
            AddEventScrollChildFrame.allFrameButtons[i] = { tempButton , tempButton:CreateFontString ( "PlayerToAddText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) , tempButton:CreateFontString ( "PlayerToAddTitleText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) };
        end

        local EventButtons = AddEventScrollChildFrame.allFrameButtons[i][1];
        local EventButtonsText = AddEventScrollChildFrame.allFrameButtons[i][2];
        local EventButtonsText2 = AddEventScrollChildFrame.allFrameButtons[i][3];
        EventButtons:SetPoint ( "TOP" , AddEventScrollChildFrame , 7 , -99 );
        EventButtons:SetWidth ( 110 );
        EventButtons:SetHeight ( 19 );
        EventButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        EventButtonsText:SetText ( GRM.SlimName ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][1] ) );
        EventButtonsText:SetWidth ( 105 );
        EventButtonsText:SetWordWrap ( false );
        EventButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
        EventButtonsText:SetPoint ( "LEFT" , EventButtons );
        EventButtonsText:SetJustifyH ( "LEFT" );
        EventButtonsText2:SetText ( GRM.SlimName( string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][2] , 0 , ( string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][2] , " " ) - 1 ) ) ) .. "'s" .. string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][2] , string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][2] , " " ) , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i + 1][2] ) );
        EventButtonsText2:SetWidth ( 162 );
        EventButtonsText2:SetWordWrap ( false );
        EventButtonsText2:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
        EventButtonsText2:SetPoint ( "LEFT" , EventButtons , "RIGHT" , 5 , 0 );
        EventButtonsText2:SetJustifyH ( "LEFT" );
        -- Logic
        EventButtons:SetScript ( "OnClick" , function ( _ , button )
            if button == "LeftButton" then
                -- For highlighting purposes
                for j = 1 , #AddEventScrollChildFrame.allFrameButtons do
                    if EventButtons ~= AddEventScrollChildFrame.allFrameButtons[j][1] then
                        AddEventScrollChildFrame.allFrameButtons[j][1]:UnlockHighlight();
                    else
                        AddEventScrollChildFrame.allFrameButtons[j][1]:LockHighlight();
                    end
                end
                AddEventFrameNameToAddText:SetText ( EventButtonsText2:GetText() );
                AddEventFrameNameToAddTitleText:SetText ( EventButtonsText: GetText() );

                if AddEventFrameStatusMessageText:IsVisible() then
                    AddEventFrameStatusMessageText:Hide();
                    AddEventFrameNameToAddText:Show();
                end
            end
        end);
        
        -- Now let's pin it!
        if i == 1 then
            EventButtons:SetPoint( "TOPLEFT" , 0 , - 5 );
            scrollHeight = scrollHeight + EventButtons:GetHeight();
        else
            EventButtons:SetPoint( "TOPLEFT" , AddEventScrollChildFrame.allFrameButtons[i - 1][1] , "BOTTOMLEFT" , 0 , - buffer );
            scrollHeight = scrollHeight + EventButtons:GetHeight() + buffer;
        end
        EventButtons:Show();
    end
    -- Update the size -- it either grows or it shrinks!
    AddEventScrollChildFrame:SetSize ( scrollWidth , scrollHeight );

    --Set Slider Parameters ( has to be done after the above details are placed )
    local scrollMax = ( scrollHeight - 145 ) + ( buffer * .5 );
    if scrollMax < 0 then
        scrollMax = 0;
    end
    AddEventScrollFrameSlider:SetMinMaxValues ( 0 , scrollMax );
    -- Mousewheel Scrolling Logic
    AddEventScrollFrame:EnableMouseWheel( true );
    AddEventScrollFrame:SetScript( "OnMouseWheel" , function( self , delta )
        local current = AddEventScrollFrameSlider:GetValue();
        
        if IsShiftKeyDown() and delta > 0 then
            AddEventScrollFrameSlider:SetValue ( 0 );
        elseif IsShiftKeyDown() and delta < 0 then
            AddEventScrollFrameSlider:SetValue ( scrollMax );
        elseif delta < 0 and current < scrollMax then
            AddEventScrollFrameSlider:SetValue ( current + 20 );
        elseif delta > 0 and current > 1 then
            AddEventScrollFrameSlider:SetValue ( current - 20 );
        end
    end);
end

-- Method:          GRM.RefreshAddEventFrame();
-- What it Does:    Refreshes the details, in case an event happes WHILE the window is open
-- Purpose:         QOL - Clean user experience. User it not forced to close window and reopen it to trigger updates. This will be used on the fly.
GRM.RefreshAddEventFrame = function()
    -- Clear the buttons first
    if AddEventScrollChildFrame.allFrameButtons ~= nil then
        for i = 1 , #AddEventScrollChildFrame.allFrameButtons do
            AddEventScrollChildFrame.allFrameButtons[i][1]:Hide();
            AddEventScrollChildFrame.allFrameButtons[i][1]:UnlockHighlight();
        end
    end
    -- Status Notification logic
    if #GRM_CalendarAddQue_Save > 0 then
        AddEventFrameStatusMessageText:SetText ( "Please Select\na Player" );
        AddEventFrameStatusMessageText:Show();
        AddEventFrameNameToAddText:Hide();
    else
        AddEventFrameStatusMessageText:SetText ( "No Events\nto Add");
        AddEventFrameStatusMessageText:Show();
        AddEventFrameNameToAddText:Hide();
    end
    -- Ok Building Frame!
    GRM.BuildEventCalendarManagerScrollFrame();
end

-- Method:          GRM.FinalReport()
-- What it Does:    Organizes flow of final report and send it to chat frame and to the logReport.
-- Purpose:         Clean organization for presentation.
GRM.FinalReport = function()
    local needToReport = false;

    if #GR_AddonGlobals.TempNewMember > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] then
        for i = 1 , #GR_AddonGlobals.TempNewMember do
            GRM.PrintLog ( GR_AddonGlobals.TempNewMember[i][1] , GR_AddonGlobals.TempNewMember[i][2] , GR_AddonGlobals.TempNewMember[i][3] );   -- Send to print to chat window
        end
    end
   
    if #GR_AddonGlobals.TempRejoin > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] then
        for i = 1 , #GR_AddonGlobals.TempRejoin do
            GRM.PrintLog ( GR_AddonGlobals.TempRejoin[i][1] , GR_AddonGlobals.TempRejoin[i][2] , GR_AddonGlobals.TempRejoin[i][3] );            -- Same Comments on down
            GRM.PrintLog ( GR_AddonGlobals.TempRejoin[i][4] , GR_AddonGlobals.TempRejoin[i][5] , GR_AddonGlobals.TempRejoin[i][3] );
            if GR_AddonGlobals.TempRejoin[i][6] then
                GRM.PrintLog ( GR_AddonGlobals.TempRejoin[i][7] , GR_AddonGlobals.TempRejoin[i][8] );
            end
        end
    end

    if #GR_AddonGlobals.TempBannedRejoin > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] then
        for i = 1 , #GR_AddonGlobals.TempBannedRejoin do
            GRM.PrintLog ( GR_AddonGlobals.TempBannedRejoin[i][1] , GR_AddonGlobals.TempBannedRejoin[i][2] , GR_AddonGlobals.TempBannedRejoin[i][3] );
            GRM.PrintLog ( GR_AddonGlobals.TempBannedRejoin[i][4] , GR_AddonGlobals.TempBannedRejoin[i][5] , GR_AddonGlobals.TempBannedRejoin[i][3] );
            if GR_AddonGlobals.TempBannedRejoin[i][6] then
                GRM.PrintLog ( GR_AddonGlobals.TempBannedRejoin[i][7] , GR_AddonGlobals.TempBannedRejoin[i][8] );
            end
        end
    end

    if #GR_AddonGlobals.TempLeftGuild > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][11] then
        for i = 1 , #GR_AddonGlobals.TempLeftGuild do
            GRM.PrintLog ( GR_AddonGlobals.TempLeftGuild[i][1] , GR_AddonGlobals.TempLeftGuild[i][2] , GR_AddonGlobals.TempLeftGuild[i][3] );
        end
    end

    if #GR_AddonGlobals.TempInactiveReturnedLog > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][3] then
        for i = 1 , #GR_AddonGlobals.TempInactiveReturnedLog do
            GRM.PrintLog ( GR_AddonGlobals.TempInactiveReturnedLog[i][1] , GR_AddonGlobals.TempInactiveReturnedLog[i][2] , GR_AddonGlobals.TempInactiveReturnedLog[i][3] );
        end
    end

    if #GR_AddonGlobals.TempNameChanged > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][8] then
        for i = 1 , #GR_AddonGlobals.TempNameChanged do
            GRM.PrintLog ( GR_AddonGlobals.TempNameChanged[i][1] , GR_AddonGlobals.TempNameChanged[i][2] , GR_AddonGlobals.TempNameChanged[i][3] );
        end
    end

    if #GR_AddonGlobals.TempLogPromotion > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][4] then
        for i = 1 , #GR_AddonGlobals.TempLogPromotion do
            GRM.PrintLog ( GR_AddonGlobals.TempLogPromotion[i][1] , GR_AddonGlobals.TempLogPromotion[i][2] , GR_AddonGlobals.TempLogPromotion[i][3] );
        end
    end

    if #GR_AddonGlobals.TempLogDemotion > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][5] then
        for i = 1 , #GR_AddonGlobals.TempLogDemotion do
            GRM.PrintLog ( GR_AddonGlobals.TempLogDemotion[i][1] , GR_AddonGlobals.TempLogDemotion[i][2] , GR_AddonGlobals.TempLogDemotion[i][3] );                          
        end
    end

    if #GR_AddonGlobals.TempRankRename > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][9] then
        for i = 1 , #GR_AddonGlobals.TempRankRename do
            GRM.PrintLog ( GR_AddonGlobals.TempRankRename[i][1] , GR_AddonGlobals.TempRankRename[i][2] , GR_AddonGlobals.TempRankRename[i][3] );
        end
    end

    if #GR_AddonGlobals.TempLogLeveled > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][2] then
        for i = 1 , #GR_AddonGlobals.TempLogLeveled do
            GRM.PrintLog ( GR_AddonGlobals.TempLogLeveled[i][1] , GR_AddonGlobals.TempLogLeveled[i][2] , GR_AddonGlobals.TempLogLeveled[i][3] );                  
        end
    end

    if #GR_AddonGlobals.TempLogNote > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][6] then
        for i = 1 , #GR_AddonGlobals.TempLogNote do
            GRM.PrintLog ( GR_AddonGlobals.TempLogNote[i][1] , GR_AddonGlobals.TempLogNote[i][2] , GR_AddonGlobals.TempLogNote[i][3] );         
        end
    end

    if #GR_AddonGlobals.TempLogONote > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][7] then
        for i = 1 , #GR_AddonGlobals.TempLogONote do
            GRM.PrintLog ( GR_AddonGlobals.TempLogONote[i][1] , GR_AddonGlobals.TempLogONote[i][2] , GR_AddonGlobals.TempLogONote[i][3] );  
        end
    end

    if #GR_AddonGlobals.TempEventReport > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][10] then
        for i = 1 , #GR_AddonGlobals.TempEventReport do
            GRM.PrintLog ( GR_AddonGlobals.TempEventReport[i][1] , GR_AddonGlobals.TempEventReport[i][2] , GR_AddonGlobals.TempEventReport[i][3] );
        end
    end

    if #GR_AddonGlobals.TempEventRecommendKickReport > 0 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][12] then
        for i = 1 , #GR_AddonGlobals.TempEventRecommendKickReport do
            GRM.PrintLog ( GR_AddonGlobals.TempEventRecommendKickReport[i][1] , GR_AddonGlobals.TempEventRecommendKickReport[i][2] , GR_AddonGlobals.TempEventRecommendKickReport[i][3]); 
        end
    end

    -- OK, NOW LET'S REPORT TO LOG FRAME IN REVERSE ORDER!!!

    if #GR_AddonGlobals.TempEventRecommendKickReport > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempEventRecommendKickReport do
            GRM.AddLog ( GR_AddonGlobals.TempEventRecommendKickReport[i][1] , GR_AddonGlobals.TempEventRecommendKickReport[i][2]);                    
        end
    end

    if #GR_AddonGlobals.TempEventReport > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempEventReport do
            GRM.AddLog( GR_AddonGlobals.TempEventReport[i][1] , GR_AddonGlobals.TempEventReport[i][2] );
        end
    end

    if #GR_AddonGlobals.TempLogONote > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLogONote do
            GRM.AddLog ( GR_AddonGlobals.TempLogONote[i][1] , GR_AddonGlobals.TempLogONote[i][2] );                    
        end
    end
 
    if #GR_AddonGlobals.TempLogNote > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLogNote do
            GRM.AddLog ( GR_AddonGlobals.TempLogNote[i][1] , GR_AddonGlobals.TempLogNote[i][2] );                    
        end
    end

    if #GR_AddonGlobals.TempLogLeveled > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLogLeveled do
            GRM.AddLog ( GR_AddonGlobals.TempLogLeveled[i][1] , GR_AddonGlobals.TempLogLeveled[i][2] );                    
        end
    end

    if #GR_AddonGlobals.TempRankRename > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempRankRename do
            GRM.AddLog ( GR_AddonGlobals.TempRankRename[i][1] , GR_AddonGlobals.TempRankRename[i][2] );
        end
    end

    if #GR_AddonGlobals.TempLogDemotion > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLogDemotion do
            GRM.AddLog ( GR_AddonGlobals.TempLogDemotion[i][1] , GR_AddonGlobals.TempLogDemotion[i][2] );                           
        end
    end

    if #GR_AddonGlobals.TempLogPromotion > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLogPromotion do
            GRM.AddLog ( GR_AddonGlobals.TempLogPromotion[i][1] , GR_AddonGlobals.TempLogPromotion[i][2] );
        end
    end

    if #GR_AddonGlobals.TempNameChanged > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempNameChanged do
            GRM.AddLog ( GR_AddonGlobals.TempNameChanged[i][1] , GR_AddonGlobals.TempNameChanged[i][2] );
        end
    end

    if #GR_AddonGlobals.TempInactiveReturnedLog > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempInactiveReturnedLog do
            GRM.AddLog ( GR_AddonGlobals.TempInactiveReturnedLog[i][1] , GR_AddonGlobals.TempInactiveReturnedLog[i][2] );
        end
    end

    if #GR_AddonGlobals.TempLeftGuild > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempLeftGuild do
            GRM.AddLog ( GR_AddonGlobals.TempLeftGuild[i][1] , GR_AddonGlobals.TempLeftGuild[i][2] );
        end
    end

    if #GR_AddonGlobals.TempBannedRejoin > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempBannedRejoin do
            if GR_AddonGlobals.TempBannedRejoin[i][6] then
                GRM.AddLog ( GR_AddonGlobals.TempBannedRejoin[i][7] , GR_AddonGlobals.TempBannedRejoin[i][8] );
            end
            GRM.AddLog ( GR_AddonGlobals.TempBannedRejoin[i][4] , GR_AddonGlobals.TempBannedRejoin[i][5] );
            GRM.AddLog ( GR_AddonGlobals.TempBannedRejoin[i][1] , GR_AddonGlobals.TempBannedRejoin[i][2] );
        end
    end

    if #GR_AddonGlobals.TempRejoin > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempRejoin do
            if GR_AddonGlobals.TempRejoin[i][6] then
                GRM.AddLog ( GR_AddonGlobals.TempRejoin[i][7] , GR_AddonGlobals.TempRejoin[i][8] );
            end
            GRM.AddLog ( GR_AddonGlobals.TempRejoin[i][4] , GR_AddonGlobals.TempRejoin[i][5] );
            GRM.AddLog ( GR_AddonGlobals.TempRejoin[i][1] , GR_AddonGlobals.TempRejoin[i][2] );
        end
    end

    if #GR_AddonGlobals.TempNewMember > 0 then
        needToReport = true;
        for i = 1 , #GR_AddonGlobals.TempNewMember do
            GRM.AddLog ( GR_AddonGlobals.TempNewMember[i][1] , GR_AddonGlobals.TempNewMember[i][2] );                                           -- Adding to the Log of Events
        end
    end


    -- Update the Add Event Window
    if #GR_AddonGlobals.TempEventReport > 0 and AddEventFrame:IsVisible() then
        GRM.RefreshAddEventFrame();
    end

    -- Clear the changes.
    GRM.ResetTempLogs();

    -- Let's update the frames!
    if needToReport and RosterChangeLogFrame ~= nil and RosterChangeLogFrame:IsVisible() then
        GRM.BuildLog();
    end

    
end  

-- Method           GRM.RecordChanges()
-- What it does:    Builds all the changes, sorts them, then adds them to change report
-- Purpose:         Consolidation of data for final output report.
GRM.RecordChanges = function ( indexOfInfo , memberInfo , memberOldInfo , guildName )
    local logReport = "";
    local simpleName = "";
    if memberInfo[1] == nil then
        simpleName = GRM.SlimName ( memberInfo );
    else
        simpleName = GRM.SlimName ( memberInfo[1] );
    end

    -- 2 = Guild Rank Promotion
    if indexOfInfo == 2 then
        local tempString = GRM.GetGuildEventString ( 2 , simpleName );
        if tempString ~= nil and tempString ~= "" then
            logReport = ( GRM.GetTimestamp() .. " : " .. tempString .. " from " .. memberOldInfo[4] .. " to " .. memberInfo[2] );
        else
            logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. " has been PROMOTED from " .. memberOldInfo[4] .. " to " .. memberInfo[2] );
        end
        table.insert ( GR_AddonGlobals.TempLogPromotion , { 1 , logReport , false } );
    -- 9 = Guild Rank Demotion
    elseif indexOfInfo == 9 then
        local tempString = GRM.GetGuildEventString ( 1 , simpleName );
        if tempString ~= nil and tempString ~= "" then
            logReport = ( GRM.GetTimestamp() .. " : " .. tempString .. " from " .. memberOldInfo[4] .. " to " .. memberInfo[2] );
        else
            logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. " has been DEMOTED from " .. memberOldInfo[4] .. " to " .. memberInfo[2] );
        end
        table.insert ( GR_AddonGlobals.TempLogDemotion , { 2 , logReport , false } );
    -- 4 = level
    elseif indexOfInfo == 4 then
        local numGained = memberInfo[4] - memberOldInfo[6];
        if numGained > 1 then
            logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. " has Leveled to " .. memberInfo[4] .. " (+ " .. numGained .. " levels)" );
        else
            logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. " has Leveled to " .. memberInfo[4] .. " (+ " .. numGained .. " level)" );
        end
        table.insert ( GR_AddonGlobals.TempLogLeveled , { 3 , logReport , false } );
    -- 5 = note
    elseif indexOfInfo == 5 then
        logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. "'s Note has Changed\nFrom:  " .. memberOldInfo[7] .. "\nTo:       " .. memberInfo[5] );
        table.insert ( GR_AddonGlobals.TempLogNote , { 4 , logReport , false } );
    -- 6 = officerNote
    elseif indexOfInfo == 6 then
        logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. "'s OFFICER Note has Changed\nFrom:  " .. memberOldInfo[8] .. "\nTo:       " .. memberInfo[6] );
        table.insert ( GR_AddonGlobals.TempLogONote , { 5 , logReport , false } );
    -- 8 = Guild Rank Name Changed to something else
    elseif indexOfInfo == 8 then
        logReport = ( GRM.GetTimestamp() .. " : Guild Rank Renamed from " .. memberOldInfo[4] .. " to " .. memberInfo[2] );
        table.insert ( GR_AddonGlobals.TempRankRename , { 6 , logReport , false } );
    -- 10 = New Player
    elseif indexOfInfo == 10 then
        -- Check against old member list first to see if returning player!
        local rejoin = false;
        local tempStringInv = GRM.GetGuildEventString ( 4 , simpleName ); -- For determining who did the invite.
        
                for j = 2 , #GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID] do -- Number of players that have left the guild.
                    if memberInfo[1] == GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][1] then 
                        -- MATCH FOUND - Player is RETURNING to the guild!
                        -- Now, let's see if the player was banned before!
                        local numTimesInGuild = #GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][20];
                        local numTimesString = "";
                        if numTimesInGuild > 1 then
                            numTimesString = ( simpleName .. " has Been in the Guild " .. numTimesInGuild .. " Times Before" );
                        else
                            numTimesString = ( simpleName .. " is Returning for the First Time." );
                        end

                        local timeStamp = GRM.GetTimestamp();
                        if GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][17] == true then
                            -- Player was banned! WARNING!!!
                            local reasonBanned = GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][18];
                            if reasonBanned == nil or reasonBanned == "" then
                                reasonBanned = "<None Given>";
                            end
                            local warning = "";
                            if tempStringInv ~= nil and tempStringInv ~= "" then
                                warning = ( "     " .. timeStamp .. " :\n---------- WARNING! WARNING! WARNING! WARNING! ----------\n" .. simpleName .. " has REJOINED the guild but was previously BANNED! \nInvited by: " .. string.sub ( tempStringInv , 1 , string.find ( tempStringInv , " " ) - 1 ) );
                            else
                                warning = ( "     " .. timeStamp .. " :\n---------- WARNING! WARNING! WARNING! WARNING! ----------\n" .. simpleName .. " has REJOINED the guild but was previously BANNED!" );
                            end
                            logReport = ("Date of Ban:                       " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][15][#GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][15]] .. " (" .. GRM.GetTimePassed(GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][16][#GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][16]]) .. " ago)\nReason:                               " .. reasonBanned .. "\nDate Originally Joined:    " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][20][1] .. "\nOld Guild Rank:                 " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][19] .. "\n" .. numTimesString );
                            local custom = "";
                            local toReport = { 9 , warning , false , 12 , logReport , false , 13 , custom };
                            -- Extra Custom Note added for returning players.
                            if GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][23] ~= "" then
                                custom = ( "Notes:     " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][23] );
                                toReport[6] = true;
                                toReport[8] = custom;
                            end
                            table.insert ( GR_AddonGlobals.TempBannedRejoin , toReport );
                        else
                            -- No Ban found, player just returning!
                            if tempStringInv ~= nil and tempStringInv ~= "" then
                                logReport = ( timeStamp .. " : " .. string.sub ( tempStringInv , 1 , string.find ( tempStringInv , " " ) - 1 ) .. " has REINVITED " .. simpleName .. " to the guild (LVL: " .. memberInfo[4] .. ")");
                            else
                                logReport = ( timeStamp .. " : " .. simpleName .. " has REJOINED the guild (LVL: " .. memberInfo[4] .. ")");
                            end
                            local custom = "";
                            local details = ( "Date Left:                           " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][15][#GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][15]] .. " (" .. GRM.GetTimePassed(GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][16][#GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][16]]) .. " ago)\nDate Originally Joined:    " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][20][1] .. "\nOld Guild Rank:                 " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][19] .. "\n" .. numTimesString );
                            local toReport = { 7 , logReport , false , 12 , details , false , 13 , custom };
                            -- Extra Custom Note added for returning players.
                            if GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][23] ~= "" then
                                custom = ( "Notes:     " .. GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j][23]) ;
                                toReport[6] = true;
                                toReport[8] = custom;
                            end
                            table.insert ( GR_AddonGlobals.TempRejoin , toReport );
                        end
                        rejoin = true;
                        -- AddPlayerTo MemberHistory

                        -- Adding timestamp to new Player.
                        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] and CanEditOfficerNote() then
                            for h = 1 , GRM.GetNumGuildies() do
                                local name ,_,_,_,_,_,_, oNote = GetGuildRosterInfo( h );
                                if name == memberInfo[1] and oNote == "" then
                                    GuildRosterSetOfficerNote( h , ( "Rejoined: " .. GRM.Trim ( strsub ( GRM.GetTimestamp() , 1 , 10 ) ) ) );
                                    break;
                                end
                            end
                        end
                        -- Do extra query
                        GuildRoster();

                        GRM.AddMemberRecord( memberInfo , true , GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID][j] , guildName );

                        
                        -- Removing Player from LeftGuild History (Yes, they will be re-added upon leaving the guild.)
                        table.remove ( GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID] , j );
                        break;
                    end
                end
                
        if rejoin ~= true then
            -- New Guildie. NOT a rejoin!
            local timestamp = GRM.GetTimestamp();
            local timeEpoch = time();
            if tempStringInv ~= nil and tempStringInv ~= "" then
                logReport = ( GRM.GetTimestamp() .. " : " .. simpleName .. " has JOINED the guild! (LVL: " .. memberInfo[4] .. ") - Invited By: " .. string.sub ( tempStringInv , 1 , string.find ( tempStringInv , " " ) - 1 ) );
            else
                logReport = ( timestamp .. " : " .. simpleName .. " has JOINED the guild! (LVL: " .. memberInfo[4] .. ")");
            end
            local finalTimestamp = ( "Joined: " .. GRM.Trim ( strsub ( GRM.GetTimestamp() , 1 , 10 ) ) );

            -- Adding timestamp to new Player.
            if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] and CanEditOfficerNote() then
                for s = 1 , GRM.GetNumGuildies() do
                    local name ,_,_,_,_,_,_, oNote = GetGuildRosterInfo ( s );
                    if name == memberInfo[1] and oNote == "" then
                        GuildRosterSetOfficerNote ( s , finalTimestamp );
                        break;
                    end
                end
            end
            -- Do extra query
            GuildRoster();

            -- Adding to global saved array, adding to report 
            GRM.AddMemberRecord ( memberInfo , false , nil , guildName );
            table.insert ( GR_AddonGlobals.TempNewMember , { 8 , logReport , false } );
           
            -- adding join date to history and rank date.
            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                     -- Number of players that have left the guild.
                if memberInfo[1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then
                    -- Add the timestamp to officer note... this avoids report spam
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][8] = finalTimestamp;

                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][12] = strsub ( timestamp , 1 , string.find ( timestamp , "'" ) + 2 );  -- Date of Last Promotion
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][13] = timeEpoch;                                                       -- Date of Last Promotion Epoch time.
                    table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] , timestamp );
                    table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][21] , timeEpoch );
                    -- For anniverary tracking!
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][1][2] = timestamp;
                    break;
                end
            end
        end
    -- 11 = Player Left  
    elseif indexOfInfo == 11 then
        local timestamp = GRM.GetTimestamp();
        local tempStringRemove = GRM.GetGuildEventString ( 3 , simpleName ); -- Kicked from the guild.
        if tempStringRemove ~= nil and tempStringRemove ~= "" then
            logReport = ( timestamp .. " : " .. tempStringRemove );
        else
            logReport = ( timestamp .. " : " .. simpleName .. " has Left the guild" );
        end
        table.insert( GR_AddonGlobals.TempLeftGuild , { 10 , logReport , false } );
        -- Finding Player's record for removal of current guild and adding to the Left Guild table.
        for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do  -- Scanning through all entries
            if memberInfo[1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] then -- Matching member leaving to guild saved entry
                -- Found!
                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][15], timestamp );                                  -- leftGuildDate
                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][16], time() );                                     -- leftGuildDateMeta
                table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25] , { "|CFFC41F3BLeft Guild" , GRM.Trim ( strsub ( timestamp , 1 , 10 ) ) } );
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][19] = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][4];         -- oldRank on leaving.
                if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] == 0 then                                                 -- Let it default to date addon was installed if date joined was never given
                    table.insert( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][2] );   -- oldJoinDate
                    table.insert( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][21] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][3] );   -- oldJoinDateMeta
                end
                -- Adding to LeftGuild Player history library
                table.insert ( GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j] );
                        
                -- Removing it from the alt list
                if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                    GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][1][1] ,GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , guildName );
                end
                -- removing from active member library
                table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] , j );
                break;
            end
        end
    -- 12 = NameChanged
    elseif indexOfInfo == 12 then
        logReport = ( GRM.GetTimestamp() .. " : " .. GRM.SlimName ( memberOldInfo[1] ) .. " has Name-Changed to ".. simpleName );
        table.insert ( GR_AddonGlobals.TempNameChanged , { 11 , logReport , false } );
    -- 13 = Inactive Members Return!
    elseif indexOfInfo == 13 then
        logReport = ( GRM.GetTimestamp() .. " : " .. GRM.SlimName ( memberInfo ) .. " has Come ONLINE after being INACTIVE for " .. GRM.HoursReport ( memberOldInfo ) );
        table.insert( GR_AddonGlobals.TempInactiveReturnedLog , { 14 , logReport , false } );
    end
end

-- Method:          GRM.ReportLastOnline( string , string , int )
-- What it Does:    Like the "GRM.CheckPlayerChanges()", this one does a one time scan on login or reload of notable changes of players who have returned from being offline for an extended period of time.
-- Purpose:         To inform the guild leader that a guildie who has not logged in in a while has returned!
GRM.ReportLastOnline = function ( name , guildName , index )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do                           -- Scanning through roster so can check changes (position 1 is guild name, so no need to rescan)
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == name then                 -- Player matched.
            local hours = GRM.GetHoursSinceLastOnline ( index );            -- index is location in in-game Guild Roster for lookup to only query server one time, not multiple.
            
            -- Report player return after being inactive!
            if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][11] and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][24] > GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][4] and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][24] > hours then  -- Player has logged in after having been inactive for greater than 2 weeks!
                GRM.RecordChanges ( 13 , name , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][24] , guildName );      -- Recording the change in hours to log
            end

            -- Recommend to kick offline if player has the power to!
            if CanGuildRemove() then
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][10] and not GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][27] and ( 30 * 24 * GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][9] ) <= hours then
                    -- Player has been offline for longer than the given time... REPORT RECOMMENDATION TO KICK!!!
                    local logReport = ( GRM.GetTimestamp() .. " : " .. GRM.SlimName ( name ) .. " has been OFFLINE for " .. GRM.HoursReport ( hours ) .. ". Kick Recommended!" );
                    table.insert ( GR_AddonGlobals.TempEventRecommendKickReport , { 16 , logReport , false } );
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][27] = true;    -- No need to report more than once.
                elseif GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][27] and ( 30 * 24 * GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][9] ) > hours  then
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][27] = false;
                end
            end
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][24] = hours;                   -- Set new hours since last login.
            break;
        end
    end
end

-- Method:          GRM.CheckPlayerChanges ( array , string )
-- What it Does:    Scans through guild roster and re-checks for any  (Will only fire if guild is found!)
-- Purpose:         Keep whoever uses the addon in the know instantly of what is going and changing in the guild.
GRM.CheckPlayerChanges = function ( metaData , guildName )
    local newPlayerFound;
    local guildRankIndexIfChanged = -1; -- Rank index must start below zero, as zero is Guild Leader.

    -- new member and leaving members arrays to check at the end
    local newPlayers = {};
    local leavingPlayers = {};


    for j = 1 , #metaData do
        newPlayerFound = true;
        for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do -- Number of members in guild (Position 1 = guild name, so we skip)
            if metaData[j][1] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] then
                newPlayerFound = false;
                for k = 2 , 14 do
                    
                    if k ~= 3 and k < 7 and metaData[j][k] ~= GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][k + 2] then -- CHANGE FOUND! New info and old info are not equal!
                        -- Ranks
                        if k == 2 and metaData[j][3] ~= GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5] and metaData[j][2] ~= GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] then -- This checks to see if guild just changed the name of a rank.
                            -- Promotion Obtained
                            if metaData[j][3] < GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5] then
                                GRM.RecordChanges ( k , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                            -- Demotion Obtained
                            elseif metaData[j][3] > GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5] then
                                GRM.RecordChanges ( 9 , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                            end
                            local timestamp = GRM.GetTimestamp();
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] = metaData[j][2]; -- Saving new rank Info
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5] = metaData[j][3]; -- Saving new rank Index Info
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] = strsub ( timestamp , 1 , string.find ( timestamp , "'" ) + 2 ) -- Time stamping rank change
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][13] = time();
                            table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][25] , { GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][13] } ); -- New rank, date, metatimestamp
                            
                            -- Update the player index if it is the player themselves that received the change in rank.
                            if metaData[j][1] == GR_AddonGlobals.addonPlayerName then
                                GR_AddonGlobals.playerIndex = metaData[j][3];
                            end
                        elseif k == 2 and metaData[j][2] ~= GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] and metaData[j][3] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5] then
                            -- RANK RENAMED!
                            if guildRankIndexIfChanged ~= metaData[j][3] then -- If alrady been reported, no need to report it again.
                                GRM.RecordChanges ( 8 , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                                guildRankIndexIfChanged = metaData[j][3]; -- Avoid repeat reporting for each member of that rank upon a namechange.
                            end
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] = metaData[j][2]; -- Saving new Info
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][25][#GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][25]][1] = metaData[j][2];   -- Adjusting the historical name if guild rank changes.
                        -- Level
                        elseif k == 4 then
                            GRM.RecordChanges ( k , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][6] = metaData[j][4]; -- Saving new Info
                        -- Note
                        elseif k == 5 then
                            GRM.RecordChanges ( k , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][7] = metaData[j][5];
                        -- Officer Note
                        elseif k == 6 and CanViewOfficerNote() then
                            if metaData[j][k] == nil or GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8] == nil then
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8] = metaData[j][6];
                            else
                                GRM.RecordChanges ( k , metaData[j] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] , guildName );
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8] = metaData[j][6];
                            end
                        end

                        -- Zone Last Spotted
                    elseif k == 9 then
                        if ( metaData[j][13] and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] ~= metaData[j][9] ) or GR_AddonGlobals.OnFirstLoad then     -- If player is currently online and in a different zone! - Also, you need to reset on first load anyway because if player has not zone-changed when you login, you will get crazy long hours and it will be wrong.
                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][32] = time();                                                                          -- Resetting the time on hitting this zone.
                        end
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] = metaData[j][9];
                    -- Player non-account wide achievement points total
                    elseif k == 10 then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][29] = metaData[j][10];
                    -- Player is not online in-game, but is on Mobile armory app for chat
                    elseif k == 11 then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][30] = metaData[j][11];
                    -- GuilD reputation ( 8 = exalted)
                    elseif k == 12 then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][31] = metaData[j][12];
                    elseif k == 13 then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] = metaData[j][13];
                    elseif k == 14 then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][34] = metaData[j][14]
                    end
                end
                break;
            end
        end
        -- NEW PLAYER FOUND! (Maybe)
        if newPlayerFound then
            newPlayers[#newPlayers + 1] = {};     -- Player "maybe" found. Let's store info to compare notes of players that left guild in case of name change.
            newPlayers[#newPlayers] = metaData[j];
        end
    end
    -- Checking if any players left the guild
    local playerLeftGuild;
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        playerLeftGuild = true;
        for k = 1 , #metaData do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == metaData[k][1] then
                playerLeftGuild = false;
                break;
            end
        end
        -- PLAYER LEFT! (maybe)
        if playerLeftGuild then
            table.insert ( leavingPlayers , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j] );
        end
    end
    -- Final check on players that left the guild to see if they are namechanges.CanViewOfficerNote
    local playerNotMatched = true;
    if #leavingPlayers > 0 and #newPlayers > 0 then
        for k = 1 , #leavingPlayers do
            for j = 1 , #newPlayers do
               if leavingPlayers[k][9] == newPlayers[j][7] -- Class is the sane
                    and leavingPlayers[k][5] == newPlayers[j][3]  -- Guild Rank is the same
                        and ( newPlayers[j][10] >= leavingPlayers[k][29] - 50 and newPlayers[j][10] <= leavingPlayers[k][29] + 100 ) then -- In other words, sometimes patches can remove achievements, so gives negative cushion, but assumes they didn't gain 100 + pts since last you noticed

                    -- PLAYER IS A NAMECHANGE!!!
                    playerNotMatched = false;
                    GRM.RecordChanges ( 12 , newPlayers[j] , leavingPlayers[k] , guildName );
                    for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                        if leavingPlayers[k][9] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][9] -- Mathching the Leaving player to historical index so it can be identified and new name stored.
                            and leavingPlayers[k][5] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5]
                                and leavingPlayers[k][29] == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][29] then

                            -- Need to remove him from list of alts IF he has a lot of alts...
                            if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11] > 0 then
                                local tempNameToReAddAltTo = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11][1][1];
                                GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11][1][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] , guildName );
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] = newPlayers[j][1]; -- Changing the name...
                                -- Now, let's re-add him back.
                                GRM.AddAlt ( tempNameToReAddAltTo , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] , guildName );
                            else
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] = newPlayers[j][1]; -- Changing the name!
                            end

                            break
                        end
                    end
                    -- since namechange identified, also need to remove name from newPlayers array now.
                    if #newPlayers == 1 then
                        newPlayers = {}; -- Clears the array of the one name.
                    else
                        local tempArray = {};
                        local count = 1;
                        for r = 1 , #newPlayers do -- removing the namechange from newPlayers list.
                            if r ~= j then  -- j = the position of the nameChanged player, so I am SKIPPING the nameChange player when adding to new array.
                                tempArray[count] = {};
                                tempArray[count] = newPlayers[r];
                                count = count + 1;
                            end
                        end
                        newPlayers = {};
                        newPlayers = tempArray;
                    end
                end
            end
            -- Player not matched! For sure this player has left the guild!
            if playerNotMatched then
                GRM.RecordChanges ( 11 , leavingPlayers[k] , leavingPlayers[k] , guildName );

                for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == leavingPlayers[k][1] then -- Player matched to Leaving Players
                        table.insert ( GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] ); -- Adding Leaving Player to proper guild Leaving table

                        -- Removing it from the alt list
                        if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11] > 0 then
                            GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11][1][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] , guildName );
                        end
                        
                        table.remove( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] , r ); -- Removes Player from the Current Guild Roster
                        break;
                    end
                end
            end
        end
    elseif #leavingPlayers > 0 then
        for k = 1 , #leavingPlayers do
            GRM.RecordChanges ( 11 , leavingPlayers[k] , leavingPlayers[k] , guildName );
            for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == leavingPlayers[k][1] then -- Player matched to Leaving Players
                    table.insert ( GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][GR_AddonGlobals.saveGID] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r] ); -- Adding Leaving Player to proper guild Leaving table

                    -- Removing it from the alt list
                    if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11] > 0 then
                        GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11][1][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] , guildName );
                    end

                    table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] , r ); -- Removes Player from the Current Guild Roster
                    break;
                end
            end
        end
    end
    if #newPlayers > 0 then
        for k = 1,#newPlayers do
            GRM.RecordChanges ( 10 , newPlayers[k] , newPlayers[k] , guildName );
        end
    end
end

-- Method:          GRM.GuildNameChanged()
-- What it Does:    Returns true if the player's guild is the same, it just changed its name
-- Purpose:         Good to know... what a pain it would be if you had to reset all of your settings
GRM.GuildNameChanged = function ( currentGuildName )
    local result = false;
    -- For each guild
    for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ][1] ~= currentGuildName then
            local numEntries = #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ] - 1;     -- Total number of entries, minus 1 since first index is guild name.
            local count = 0;
            -- for each member in that guild
            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ] do
                for r = 1 , GRM.GetNumGuildies() do
                    local name = GetGuildRosterInfo ( r );
                    if name == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ][j][1] then
                        count = count + 1;
                        break;
                    end
                end

                if j == 10 and count == 0 then
                    break;
                end
            end
            if ( count / numEntries ) >= 0.5 then       -- Default threshold is > 50% matches. I would think it would be higher, but this keeps it so player can be 2 person guild, kick 1 person, change name, and it will stiill stay in threshold.
                -- Player is within the threshold
                result = true;
                local tempGuildName = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ][1];

                -- Changing the name of the guild in the saved data to the new name.
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ][1] = currentGuildName;

                -- Need to change index name of the left player history too.
                for s = 2 , #GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ] do
                    if GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][s][1] == tempGuildName then
                        GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ][s][1] = currentGuildName;
                        break;
                    end
                end

                break;
            end
        end
    end
    return result;
end

-- Method:          GRM.BuildNewRoster()
-- What it does:    Rebuilds the roster to check against for any changes.
-- Purpose:         To track for guild changes of course!
GRM.BuildNewRoster = function()
    local roster = {};

    -- Checking if Guild Found or Not Found, to pre-check for Guild name tag.
    local guildNotFound = true;
    for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ] do
        if GR_AddonGlobals.guildName == GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ i ][1] then
            guildNotFound = false;
            break;
        end
    end

    for i = 1 , GRM.GetNumGuildies() do
        local name , rank , rankInd , level , _ , zone , note , officerNote , online , status , class , achievementPoints , _ , isMobile , _ , rep = GetGuildRosterInfo ( i ); 
        roster[i] = {};
        roster[i][1] = name
        roster[i][2] = rank;
        roster[i][3] = rankInd;
        roster[i][4] = level;
        roster[i][5] = note;
        if CanViewOfficerNote() then -- Officer Note permission to view.
            roster[i][6] = officerNote;
        else
            roster[i][6] = nil; -- Set Officer note to nil if needed.
        end

        roster[i][7] = class;
        roster[i][8] = GRM.GetHoursSinceLastOnline ( i ); -- Time since they last logged in in hours.
        roster[i][9] = zone;
        roster[i][10] = achievementPoints;
        roster[i][11] = isMobile;
        roster[i][12] = rep;
        roster[i][13] = online;
        roster[i][14] = status;

        -- Items to check One time check on login
        -- Check players who have not been on a long time only on login or addon reload.
        if guildNotFound ~= true then
            GRM.ReportLastOnline ( name , GR_AddonGlobals.guildName , i );
        end

    end
    
    -- Build Roster for the first time if guild not found.
    if guildNotFound then
        -- See if it is a Guild NameChange first!
        if GRM.GuildNameChanged ( GR_AddonGlobals.guildName ) then
            local logEntry = "\n\n-------------------------------------------------------------\n" .. GRM.SlimName( GR_AddonGlobals.addonPlayerName ) .. "'s Guild has Name-Changed to \n\"" .. GR_AddonGlobals.guildName .. "\"\n-------------------------------------------------------------\n\n"
            GRM.PrintLog ( 15 , logEntry , false );   
            GRM.AddLog ( 15 , logEntry ); 
            -- ADD NEW GUILD VALUES
        else
            print ( "\nGUILD ROSTER MANAGER\nAnalyzing guild for the first time...\nBuilding Profiles on ALL \"" .. GR_AddonGlobals.guildName .. "\" members.\n" );
            -- This reiterates over this, because sometimes it can have a delay. This ensures it is secure.
            if GR_AddonGlobals.faction == "Horde" then
                GR_AddonGlobals.FID = 1;
            else
                GR_AddonGlobals.FID = 2;
            end
            table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ] , { GR_AddonGlobals.guildName } );                        -- Creating a position in table for Guild Member Data
            table.insert ( GRM_PlayersThatLeftHistory_Save[ GR_AddonGlobals.FID ] , { GR_AddonGlobals.guildName } );                    -- Creating a position in Left Player Table for Guild Member Data
            table.insert ( GRM_LogReport_Save[ GR_AddonGlobals.FID ] , { GR_AddonGlobals.guildName } );                                 -- Logreport, let's create an index
            table.insert ( GRM_CalendarAddQue_Save[ GR_AddonGlobals.FID ] , { GR_AddonGlobals.guildName } );                            -- AddQue, let's create an index for the guild

            -- SET THE INDEXES PROPERLY
            for i = 2 , #GRM_LogReport_Save[GR_AddonGlobals.FID] do
                if GRM_LogReport_Save[GR_AddonGlobals.FID][i][1] ==  GR_AddonGlobals.guildName then
                    GR_AddonGlobals.logGID = i;
                    break;
                end
            end
            for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID] do
                if GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.guildName then
                    GR_AddonGlobals.saveGID = i;
                    break;
                end
            end
            
            for i = 1 , #roster do
                -- Add last time logged in initial timestamp.
                GRM.AddMemberRecord ( roster[i] , false , nil , GR_AddonGlobals.guildName );
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][#GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ]][24] = roster[i][8];   -- Setting Timestamp for the first time only.
            end
        end
    else -- Check over changes!
        GRM.CheckPlayerChanges ( roster , GR_AddonGlobals.guildName );
    end
end


--------------------------------------
------ END OF METADATA LOGIC ---------
--------------------------------------


--------------------------------------
------ GROUP METHODS AND LOGIC -------
--------------------------------------

-- Method:          GRM.IsGuildieInSameGroup ( string )  -- proper format of the name should be "PlayerName-ServerName"
-- What it Does:    Returns true if the given guildie is grouped with you.
-- Purpose:         To determine if you are grouped with a guildie!
GRM.IsGuildieInSameGroup = function ( guildMember )
    local result = false;
    for i = 1 , GetNumGroupMembers() do
        local raidPlayer = GetRaidRosterInfo ( i );
        if raidPlayer == GRM.SlimName ( guildMember ) then
            result = true;
            break;
        end
    end
    return result;
end

-- Method:          GRM.GetAllGuildiesOnline()
-- What it Does:    Returns a table of names of all guildies that are currently online in the guild
-- Purpose:         Group management info and reporting. Pretty much some UI features, but possibly will be expanded upon.
GRM.GetAllGuildiesOnline = function()
    local listOfNames = {};
    for i = 1 , GRM.GetNumGuildies() do
        local name , _ , _ , _ , _ , _ , _ , _ , online = GetGuildRosterInfo ( i );
        if online then
            table.insert ( listOfNames , GRM.SlimName ( name) );
        end
    end
    return listOfNames;
end

-- Method:          GRM.GetGroupUnitsOfflineOrAFK()
-- What it Does:    Returns a 2D array of the names of the players (not including server names) that are offline and afk in group
-- Purpose:         Mainly to notify the group leader who is AFK, possibly to make room for others in raid by informing leader of offline members.
GRM.GetGroupUnitsOfflineOrAFK = function()
    local offline = {};
    local afkMembers = {};
    
    for i = 1 , GetNumGroupMembers() do
        local raidPlayer , _ , _ , _ , _ , _ , _ , isOnline = GetRaidRosterInfo ( i );
        if isOnline ~= true then
            table.insert ( offline , raidPlayer );
        end
        if isOnline and UnitIsAFK( raidPlayer ) then
            table.insert ( afkMembers , raidPlayer );
        end        
    end
    local result = { offline , afkMembers };
    return result;
end

-- Method:          GRM.GetNumGuildiesInGroup()
-- What it Does:    Returns the int number of guildies you are grouped with, either in party or raid.
-- Purpose:         To report how many players are grouped with you from the guild. Helps you realize who is grouped with you
GRM.GetNumGuildiesInGroup = function()
    local result = 0;
    local allGuildiesOnline = GRM.GetAllGuildiesOnline();
    for i = 1 , GetNumGroupMembers() do
        local groupMemberName = GetRaidRosterInfo ( i );
        for j = 1 , #allGuildiesOnline do
            if groupMemberName == allGuildiesOnline[j] then
                result = result + 1;
                break;
            end
        end
        if result >= #allGuildiesOnline then
            -- No need to keep scanning, just break out.
            break;
        end
    end
    return result;
end

-- Method:          GRM.GetGuildMemberRankID ( string )
-- What it does:    Returns the rank index of the given player's name, or 0 if unable to find player
-- Purpose:         Rank needs to be known in certain circumstances, like knowing if something was a promotion or a demotion.
GRM.GetGuildMemberRankID = function( name )
    local result = -1;
    for i = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][1] == name then
            result = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][i][5];
            break;
        end
    end
    if result == -1 then
        error ( "Error: GRM.GetGuildMemberRankID() was not able to establish " .. name .. "'s rank!" );
    end
    return result;
end


----------------------
-- EVENT TRACKING!!!!!
----------------------

-- Method:          GRM.GetEventYear ( string )
-- What it Does:    Returns the year of the given event from timestamp as a string
-- Purpose:         Keep code clutter down, put this block in reusable form.
GRM.GetEventYear = function ( timestamp )
    -- timestamp format = "Day month year hour min"
    local count = 0;
    local result = "";
    if timestamp ~= "" and timestamp ~= nil then
        for i = 1 , #timestamp do
            if string.sub ( timestamp , i , i ) == " " then
                count = count + 1;
            end
            if count == 2 then
                result = result .. "20" .. string.sub ( timestamp , i + 2 , i + 4 );
                break;
            end
        end
    end
    return result;
end

-- Method:          GRM.GetEventMonth ( string )
-- What it Does:    Returns the 3 letter string of the name of the month of the event.
-- Purpose:         Again, avoid code cludder. For event tracking, knowing exact date is essential.
GRM.GetEventMonth = function ( timestamp )
    if timestamp == "" or timestamp == nil then
        return "";
    else
        return string.sub ( timestamp , string.find ( timestamp , " " ) + 1 , string.find ( timestamp , " " ) + 3 );
    end
end

-- Method:          GRM.GetEventDay ( string )
-- What it Does:    Returns the number of the day, as a string, based on day of the month for given event timestamp
-- Purpose:         Important to know what day event should happen on.
GRM.GetEventDay = function ( timestamp )
    if timestamp == "" or timestamp == nil then
        return "";
    else
        return string.sub ( timestamp , 1 , string.find ( timestamp , " " ) - 1 );
    end
end

-- Method:          GRM.IsCalendarEventAlreadyAdded ( string , int , int , int )
-- What it Does:    Returns true if the event has already been added to the calendar 
-- Purpose:         If the player wipes his save history, it does not wipe what is added to in-game calendar. This just double-checks to avoid double adding.
GRM.IsCalendarEventAlreadyAdded = function ( eventName , year , month , day )
    eventName = GRM.SlimName( string.sub ( eventName , 0 , ( string.find ( eventName , " " ) - 1 ) ) ) .. "'s" .. string.sub ( eventName , string.find ( eventName , " " ) , #eventName );
    local result = false;
    local monthIndex = 0;
    local m , y;

    for i = 0 , 17 do                       -- Let's get to the right month on the calendar
        m , y = CalendarGetMonth ( i );
        if m == month and y == year then
            monthIndex = i;
            break;
        end
    end
    for i = 1 , CalendarGetNumDayEvents ( monthIndex , day ) do         -- Let's look at all the events on the day of the event
        if eventName == CalendarGetDayEvent ( monthIndex , day, i ) then
            result = true;
            break;
        end
    end
    return result;
end


-- Method:          GRM.IsOnAnnouncementList ( string , string )
-- What it Does:    returns true if the player is in the que to add to the calendar
-- Purpose:         Avoid double adding to que, and basic logic checking.
GRM.IsOnAnnouncementList = function ( name , title )
    local result = false;
    for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] do
        if GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][1] == name and GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] == title then
            result = true;
            break; 
        end
    end
    return result;
end

-- Method:          GRM.RemoveFromCalendarQue ( string , string )
-- What it Does:    Removes the player/event from the global Calendar Add Que table
-- Purpose:         Keep the Que Clean
GRM.RemoveFromCalendarQue = function ( name , title )
    for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] do
        if GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][1] == name and GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] == title then
            table.remove ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] , i );
            break;
        end
    end
end

-- Method:          GRM.CheckPlayerEvents ( string )
-- What it Does:    Scans through all players'' "events" of the given guild and updates if any are pending
-- Purpose:         Event Management for Anniversaries, Birthdays, and Custom Events
GRM.CheckPlayerEvents = function ( guildName )
    -- including anniversary, birthday , and custom
    local _ , month , day , year = CalendarGetDate()
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        -- Player identified, now let's check his event info!
        for r = 1 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22] do          -- Loop all events!
            local eventMonth = GRM.GetEventMonth ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] );
            local eventMonthIndex = monthEnum [ eventMonth ];
            local eventDay = tonumber ( GRM.GetEventDay ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] ) );
            local eventYear = tonumber ( GRM.GetEventYear ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] ) );
            local isLeapYear = GRM.IsLeapYear ( year );
            local logReport = "";
            --  Quick Leap Year Check
            if ( eventDay == 29 and eventMonthIndex == 2 ) and not isLeapYear then  -- If Event is Feb 29th Leap year, and reporting year is not, then put event in Mar 1st.
                eventMonthIndex = 3;
                eventDay = 1;
            end

            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] ~= nil and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] ~= true and ( month == eventMonthIndex or month + 1 == eventMonthIndex ) and not ( year == eventYear and month == eventMonthIndex and day == eventDay ) then        -- if it has already been reported, then we are good!
                local daysTil = eventDay - day;
                local daysLeftInMonth = daysInMonth [ tostring ( month ) ] - day;
                if month == 2 and GRM.IsLeapYear ( year ) then
                    daysLeftInMonth = daysLeftInMonth + 1;
                end
                            
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][12] and ( ( month == eventMonthIndex and daysTil >= 0 and daysTil <= GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] ) or 
                        ( month + 1 == eventMonthIndex and ( eventDay + daysLeftInMonth <= GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] ) ) ) then
                    -- SAME MONTH!
                    -- Join Date Anniversary
                    if r == 1 then
                        local numYears = year - eventYear;
                        if numYears == 0 then
                            numYears = 1;
                        end
                        local eventDate;
                        if ( eventDay == 29 and eventMonthIndex == 2 ) and not isLeapYear then    -- If anniversary happened on leap year date, and the current year is NOT a leap year, then put it on 1 Mar.
                            eventDate = "1 Mar";
                        else
                            eventDate = string.sub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] , 0 , string.find ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][2] , " " ) + 3 );
                        end
                        if numYears == 1 then
                            
                            logReport = ( GRM.GetTimestamp() .. " : " .. GRM.SlimName ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] ) .. " will be celebrating " .. numYears .. " year in the Guild! ( " .. eventDate .. " )"  );
                        else
                            logReport = ( GRM.GetTimestamp() .. " : " .. GRM.SlimName ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] ) .. " will be celebrating " .. numYears .. " years in the Guild! ( " .. eventDate .. " )"  );
                        end
                        table.insert ( GR_AddonGlobals.TempEventReport , { 15 , logReport , false } );
                    
                    elseif r == 2 then
                    -- BIRTHDAY!

                    else
                    -- MISC EVENT!
                    
                    end

                    -- Now, let's add it to the calendar!
                    if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][8] and CanEditGuildEvent() then
                        local year = year;
                        if month == 12 and eventMonthIndex == 1 then
                            year = year + 1;
                        end 

                        -- 
                        local isAddedAlready = GRM.IsCalendarEventAlreadyAdded (  GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] , year , eventMonthIndex , eventDay  );
                            if not isAddedAlready and not GRM.IsOnAnnouncementList ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] ) then
                            table.insert ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] , { GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] , eventMonthIndex , eventDay , year , string.sub ( logReport , 1 , #logReport - 11 ) } );
                        end
                    end
                    -- This has been reported, save it!
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] = true;
                end                  
                
            -- Resetting the event report to false if parameters meet
            elseif GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] then                                                   -- It is still true! Event has been reported! Let's check if time has passed sufficient to wipe it to false
                if ( month == eventMonthIndex and eventDay - day < 0 ) or ( month > eventMonthIndex  ) or ( eventMonthIndex - month > 1 ) then     -- Event is behind us now
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] = false;
                    if GRM.IsOnAnnouncementList ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] ) then
                        GRM.RemoveFromCalendarQue ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] );
                    end
                elseif month == eventMonthIndex and eventDay - day > GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] then      -- Setting back to false;
                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] = false;
                    if GRM.IsOnAnnouncementList ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] ) then
                        GRM.RemoveFromCalendarQue ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] );
                    end
                elseif month + 1 == eventMonthIndex then
                    local daysLeftInMonth = daysInMonth [ tostring ( month ) ] - day;
                    if month == 2 and GRM.IsLeapYear ( year ) then
                        daysLeftInMonth = daysLeftInMonth + 1;
                    end
                    if eventDay + daysLeftInMonth > GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][3] = false;
                        if GRM.IsOnAnnouncementList ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] ) then
                            GRM.RemoveFromCalendarQue ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][22][r][1] );
                        end
                    end
                end
            end
        end
    end
end

-- Method:          AddAnnouncementToCalendar ( string , int , int , int , string , string )
-- What it Does:    Adds the announcement to the in-game calendar, if player has permissions to do so.
-- Purpose:         CalendarAddEvent() is a protected function thus it needs to be triggered by a player in-game action, so it will
--                  be linked to a button on the "AddEventFrame" window. Again, this cannot be activated, it WILL NOT WORK without 
--                  in-game action to remove protection on function
GRM.AddAnnouncementToCalendar = function ( name , title , eventMonthIndex , eventDay , year , description )
    CalendarCloseEvent();                           -- Just in case previous event was never closed, either by other addons or by player
    local _, month, day, year = CalendarGetDate()
    local hourServer , minServer = GetGameTime();
    local hour = 0;                                 -- 24hr scale, on when to add it...
    local min = 5;

    if eventMonthIndex == month and eventDay == day then      -- Add current time now!
        hour = hourServer;
        min = minServer;

        local tempMin = min;
        min = min - ( min % 5 ) + 5;    -- To get incrememnt by 5
        if min == 60 then
            if tempMin <= 55 then
                min = 55;
            else
                min = tempMin;
            end
        end
    end

    CalendarNewGuildAnnouncement();
    CalendarEventSetDate ( eventMonthIndex , eventDay , year );
    CalendarEventSetTitle ( title );
    CalendarEventSetDescription ( description ); -- No need to include the date at the end.
    CalendarEventSetTime ( hour , min );    
    CalendarEventSetType ( 5 );     -- 5 = announcement
    CalendarAddEvent();
    CalendarCloseEvent();
end

-- Method:          GRM.BuildLog()
-- What it Does:    Builds the guildLog frame details for the scrollframe
-- Purpose:         You aren't tracking all of that info for nothing!
GRM.BuildLog = function()
    -- SCRIPT LOGIC ON ADD EVENT SCROLLING FRAME
    local scrollHeight = 0;
    local scrollWidth = 220;
    local buffer = 7;

    RosterChangeLogScrollChildFrame.allFontStrings = RosterChangeLogScrollChildFrame.allFontStrings or {};  -- Create a table for the Buttons.
    -- populating the window correctly.
    local count = 1;
    for i = 1 , #GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] do
        -- if font string is not created, do so.
        local trueString = false;
        
        -- Check buttons
        local index = GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID][#GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] - i + 1][1];
        if index == 1 and RosterPromotionChangeCheckButton:GetChecked() then      -- Promotion 
            trueString = true;
        elseif index == 2 and RosterDemotionChangeCheckButton:GetChecked() then  -- Demotion
            trueString = true;
        elseif index == 3 and RosterLeveledChangeCheckButton:GetChecked() then  -- Leveled
            trueString = true;
        elseif index == 4 and RosterNoteChangeCheckButton:GetChecked() then  -- Note
            trueString = true;
        elseif index == 5 and RosterOfficerNoteChangeCheckButton:GetChecked() then  -- OfficerNote
            trueString = true;
        elseif index == 6 and RosterRankRenameCheckButton:GetChecked() then  -- OfficerNote
            trueString = true;
        elseif ( index == 7 or index == 8 ) and RosterJoinedCheckButton:GetChecked() then  -- Join/Rejoin
            trueString = true;
        elseif index == 10 and RosterLeftGuildCheckButton:GetChecked() then -- Left Guild
            trueString = true;
        elseif index == 11 and RosterNameChangeCheckButton:GetChecked() then -- NameChange
            trueString = true;
        elseif index == 14 and RosterInactiveReturnCheckButton:GetChecked() then -- Return from inactivity
            trueString = true;
        elseif index == 15 and RosterEventCheckButton:GetChecked() then -- Event Announcement
            trueString = true;
        elseif index == 16 and RosterRecommendationsButton:GetChecked() then -- Event Announcement
            trueString = true;
        elseif index == 9 or index == 12 or index == 13 then
            trueString = true;
        end

        if trueString then
            if not RosterChangeLogScrollChildFrame.allFontStrings[count] then
                RosterChangeLogScrollChildFrame.allFontStrings[count] = RosterChangeLogScrollChildFrame:CreateFontString ( "GRM_LogEntry_" .. count );
            end

            -- coloring
            local r , g , b = GRM.GetNMessageRGB ( GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID][#GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] - i + 1][1] );
            local logFontString = RosterChangeLogScrollChildFrame.allFontStrings[count];
            logFontString:SetPoint ( "TOP" , RosterChangeLogScrollChildFrame , 7 , -99 );
            logFontString:SetFont ( "Fonts\\FRIZQT__.TTF" , 11 );
            logFontString:SetJustifyH ( "LEFT" );
            logFontString:SetSpacing ( buffer );
            logFontString:SetTextColor ( r , g , b , 1.0 );
            logFontString:SetText ( GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID][#GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] - i + 1][2] );
            local stringHeight = logFontString:GetStringHeight();

            -- Now let's pin it!
            if count == 1 then
                logFontString:SetPoint( "TOPLEFT" , 0 , - 5 );
                scrollHeight = scrollHeight + stringHeight;
            else
                logFontString:SetPoint( "TOPLEFT" , RosterChangeLogScrollChildFrame.allFontStrings[count - 1] , "BOTTOMLEFT" , 0 , - buffer );
                scrollHeight = scrollHeight + stringHeight + buffer;
            end
            count = count + 1;
            logFontString:Show();
        end
    end
            

    -- Hides all the additional buttons... if necessary
    for i = count , #RosterChangeLogScrollChildFrame.allFontStrings do
        RosterChangeLogScrollChildFrame.allFontStrings[i]:Hide();
    end 

    -- Update the size -- it either grows or it shrinks!
    RosterChangeLogScrollChildFrame:SetSize ( scrollWidth , scrollHeight );

    --Set Slider Parameters ( has to be done after the above details are placed )
    local scrollMax = ( scrollHeight - 397 ) +  ( buffer * .5 );  -- 18 comes from fontSize (11) + buffer (7);
    if scrollMax < 0 then
        scrollMax = 0;
    end
    RosterChangeLogScrollFrameSlider:SetMinMaxValues ( 0 , scrollMax );
    -- Mousewheel Scrolling Logic
    RosterChangeLogScrollFrame:EnableMouseWheel( true );
    RosterChangeLogScrollFrame:SetScript( "OnMouseWheel" , function( self , delta )
        local current = RosterChangeLogScrollFrameSlider:GetValue();
        
        if IsShiftKeyDown() and delta > 0 then
            RosterChangeLogScrollFrameSlider:SetValue ( 0 );
        elseif IsShiftKeyDown() and delta < 0 then
            RosterChangeLogScrollFrameSlider:SetValue ( scrollMax );
        elseif delta < 0 and current < scrollMax then
            RosterChangeLogScrollFrameSlider:SetValue ( current + 20 );
        elseif delta > 0 and current > 1 then
            RosterChangeLogScrollFrameSlider:SetValue ( current - 20 );
        end
    end);
end


------------------------------------
---- BEGIN OF FRAME/UI LOGIC -------
---- General Framebuild Methods ----
------------------------------------


-- Method:          GRM.OnDropMenuClickDay()
-- What it Does:    Upon clicking any item in a drop down menu, this sets the ID of that item as defaulted choice
-- Purpose:         General use clicking logic for month based drop down menu.
GRM.OnDropMenuClickDay = function ()
    GR_AddonGlobals.dayIndex = tonumber ( DayDropDownMenuSelected.DayText:GetText() );
    GRM.InitializeDropDownDay();
end

-- Method:          GRM.OnDropMenuClickMonth()
-- What it Does:    Recalculates the logic of number days to show.
-- Purpose:         General use clicking logic for month based drop down menu.
GRM.OnDropMenuClickMonth = function ()
    GR_AddonGlobals.monthIndex = monthsFullnameEnum [ MonthDropDownMenuSelected.MonthText:GetText() ];
    GRM.InitializeDropDownDay();
end

-- Method:          GRM.OnDropMenuClickYear()
-- What it Does:    Upon clicking any item in a drop down menu, this sets the ID of that item as defaulted choice
-- Purpose:         General use clicking logic for year based drop down menu.
GRM.OnDropMenuClickYear = function ()
    GR_AddonGlobals.yearIndex = tonumber ( YearDropDownMenuSelected.YearText:GetText() );
    GRM.InitializeDropDownDay();
end

-- Method:          GRM.InitializeDropDownDay ( self , int )
-- What it Does:    Initializes the Drop Down "Day" select window with values based on selected month
-- Purpose:         UI feature for easy date select.
GRM.InitializeDropDownDay = function ()
    local shortMonth = 30;
    local longMonth = 31;
    local febMonth = 28;
    local leapYear = 29;
    local yearDate = 0;

    yearDate = GR_AddonGlobals.yearIndex;
    local isDateALeapyear = GRM.IsLeapYear(yearDate);
    local numDays;
    
    if GR_AddonGlobals.monthIndex == 1 or GR_AddonGlobals.monthIndex == 3 or GR_AddonGlobals.monthIndex == 5 or GR_AddonGlobals.monthIndex == 7 or GR_AddonGlobals.monthIndex == 8 or GR_AddonGlobals.monthIndex == 10 or GR_AddonGlobals.monthIndex == 12 then
        numDays = longMonth;
    elseif GR_AddonGlobals.monthIndex == 2 and isDateALeapyear then
        numDays = leapYear;
    elseif GR_AddonGlobals.monthIndex == 2 then
        numDays = febMonth;
    else
        numDays = shortMonth;
    end
      
    -- populating the frames!
    local buffer = 3;
    local height = 0;
    DayDropDownMenu.Buttons = DayDropDownMenu.Buttons or {};

    -- Resetting the buttons!
    for i = 1 , #DayDropDownMenu.Buttons do
        DayDropDownMenu.Buttons[i][1]:Hide();
    end
    
    for i = 1 , numDays do
        if not DayDropDownMenu.Buttons[i] then
            local tempButton = CreateFrame ( "Button" , "DayOfTheMonth" .. i , DayDropDownMenu );
            DayDropDownMenu.Buttons[i] = { tempButton , tempButton:CreateFontString ( "DayOfTheMonthText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) }
        end

        local DayButtons = DayDropDownMenu.Buttons[i][1];
        local DayButtonsText = DayDropDownMenu.Buttons[i][2];
        DayButtons:SetWidth ( 24 );
        DayButtons:SetHeight ( 10 );
        DayButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        DayButtonsText:SetText ( i );
        DayButtonsText:SetWidth ( 25 );
        DayButtonsText:SetWordWrap ( false );
        DayButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
        DayButtonsText:SetPoint ( "CENTER" , DayButtons );
        DayButtonsText:SetJustifyH ( "CENTER" );

        if i == 1 then
            DayButtons:SetPoint ( "TOP" , DayDropDownMenu , 0 , -7 );
            height = height + DayButtons:GetHeight();
        else
            DayButtons:SetPoint ( "TOP" , DayDropDownMenu.Buttons[i - 1][1] , "BOTTOM" , 0 , -buffer );
            height = height + DayButtons:GetHeight() + buffer;
        end

        DayButtons:SetScript ( "OnClick" , function( _ , button ) 
            if button == "LeftButton" then
                DayDropDownMenuSelected.DayText:SetText ( DayButtonsText:GetText() );
                DayDropDownMenu:Hide();
                DayDropDownMenuSelected:Show();
                GRM.OnDropMenuClickDay();
            end
        end); 

        DayButtons:Show();
    end
    DayDropDownMenu:SetHeight ( height + 15 );
end

-- Method:          GRM.InitializeDropDownYear(self,level)
-- What it Does:    Initializes the year select drop-down OnDropMenuClick
-- Purpose:         Easy way to set when player joined the guild.         
GRM.InitializeDropDownYear = function ()
    -- Year Drop Down
    local _,_,_,currentYear = CalendarGetDate();
    local yearStamp = currentYear;

    -- populating the frames!
    local buffer = 2;
    local height = 0;
    YearDropDownMenu.Buttons = YearDropDownMenu.Buttons or {};

    -- Resetting the buttons!
    for i = 1 , #YearDropDownMenu.Buttons do
        YearDropDownMenu.Buttons[i][1]:Hide();
    end
    
    for i = 1 , currentYear - 2003 do
        if not YearDropDownMenu.Buttons[i] then
            local tempButton = CreateFrame ( "Button" , "YearIndexButton" .. i , YearDropDownMenu );
            YearDropDownMenu.Buttons[i] = { tempButton , tempButton:CreateFontString ( "YearIndexButtonText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) }
        end

        local YearButtons = YearDropDownMenu.Buttons[i][1];
        local YearButtonsText = YearDropDownMenu.Buttons[i][2];
        YearButtons:SetWidth ( 40 );
        YearButtons:SetHeight ( 10 );
        YearButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        YearButtonsText:SetText ( yearStamp );
        YearButtonsText:SetWidth ( 25 );
        YearButtonsText:SetWordWrap ( false );
        YearButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
        YearButtonsText:SetPoint ( "CENTER" , YearButtons );
        YearButtonsText:SetJustifyH ( "CENTER" );

        if i == 1 then
            YearButtons:SetPoint ( "TOP" , YearDropDownMenu , 0 , -7 );
            height = height + YearButtons:GetHeight();
        else
            YearButtons:SetPoint ( "TOP" , YearDropDownMenu.Buttons[i - 1][1] , "BOTTOM" , 0 , -buffer );
            height = height + YearButtons:GetHeight() + buffer;
        end

        YearButtons:SetScript ( "OnClick" , function( _ , button ) 
            if button == "LeftButton" then
                YearDropDownMenuSelected.YearText:SetText ( YearButtonsText:GetText() );
                YearDropDownMenu:Hide();
                YearDropDownMenuSelected:Show();
                GRM.OnDropMenuClickYear();
            end
        end); 
        yearStamp = yearStamp - 1                       -- Descending the year by 1
        YearButtons:Show();
    end
    YearDropDownMenu:SetHeight ( height + 15 );

end

-- Method:          GRM.InitializeDropDownMonth(self,level)
-- What it Does:    Initializes month drop select menu
-- Purpose:         Date select for Officer Note "Join Date"
GRM.InitializeDropDownMonth = function ()
    -- Month Drop Down
    local months = { "January" , "February" , "March" , "April" , "May" , "June" , "July" , "August" , "September" , "October" , "November" , "December" };
    
    -- populating the frames!
    local buffer = 3;
    local height = 0;
    MonthDropDownMenu.Buttons = MonthDropDownMenu.Buttons or {};

    -- Resetting the buttons!
    for i = 1 , #MonthDropDownMenu.Buttons do
        MonthDropDownMenu.Buttons[i][1]:Hide();
    end
    
    for i = 1 , #months do
        if not MonthDropDownMenu.Buttons[i] then
            local tempButton = CreateFrame ( "Button" , "monthIndex" .. i , MonthDropDownMenu );
            MonthDropDownMenu.Buttons[i] = { tempButton , tempButton:CreateFontString ( "monthIndexText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) }
        end

        local MonthButtons = MonthDropDownMenu.Buttons[i][1];
        local MonthButtonsText = MonthDropDownMenu.Buttons[i][2];
        MonthButtons:SetWidth ( 83 );
        MonthButtons:SetHeight ( 10 );
        MonthButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        MonthButtonsText:SetText ( months[i] );
        MonthButtonsText:SetWidth ( 83 );
        MonthButtonsText:SetWordWrap ( false );
        MonthButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
        MonthButtonsText:SetPoint ( "CENTER" , MonthButtons );
        MonthButtonsText:SetJustifyH ( "CENTER" );

        if i == 1 then
            MonthButtons:SetPoint ( "TOP" , MonthDropDownMenu , 0 , -7 );
            height = height + MonthButtons:GetHeight();
        else
            MonthButtons:SetPoint ( "TOP" , MonthDropDownMenu.Buttons[i - 1][1] , "BOTTOM" , 0 , -buffer );
            height = height + MonthButtons:GetHeight() + buffer;
        end

        MonthButtons:SetScript ( "OnClick" , function( _ , button ) 
            if button == "LeftButton" then
                MonthDropDownMenuSelected.MonthText:SetText ( MonthButtonsText:GetText() );
                MonthDropDownMenu:Hide();
                MonthDropDownMenuSelected:Show();
                GRM.OnDropMenuClickMonth();
            end
        end); 

        MonthButtons:Show();
    end
    MonthDropDownMenu:SetHeight ( height + 15 );
end

-- Method:          GRM.SetJoinDate ( self , string )
-- What it Does:    Sets the player's join date properly, be it the first time, a modified time, or an edit.
-- Purpose:         For so many uses! Anniversary tracking, for editing the date, and so on...
GRM.SetJoinDate = function ( _ , button )
    local name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );
    local dayJoined = tonumber ( DayDropDownMenuSelected.DayText:GetText() );
    local yearJoined = tonumber ( YearDropDownMenuSelected.YearText:GetText() );
    local IsLeapYearSelected = GRM.IsLeapYear ( yearJoined );
    local buttonText = DateSubmitButtonTxt:GetText();

    if GRM.IsValidSubmitDate ( dayJoined , monthsFullnameEnum [ MonthDropDownMenuSelected.MonthText:GetText() ] , yearJoined, IsLeapYearSelected ) then
        local rankButton = false;
        for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == name then

                local joinDate = ( "Joined: " .. dayJoined .. " " ..  strsub ( MonthDropDownMenuSelected.MonthText:GetText() , 1 , 3 ) .. " '" ..  strsub ( YearDropDownMenuSelected.YearText:GetText() , 3 ) );
                local finalTimeStamp = ( strsub ( joinDate , 9) .. " 12:01am" );
                local finalEpochStamp = GRM.TimeStampToEpoch ( joinDate );
                
                if buttonText == "Edit Join Date" then
                    table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20] , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20] );  -- Removing previous instance to replace
                    table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][21] , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][21] );
                end
                table.insert( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20] , finalTimeStamp );     -- oldJoinDate
                table.insert( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][21] , finalEpochStamp ) ;   -- oldJoinDateMeta
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][2] = finalTimeStamp;
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][3] = finalEpochStamp;
                GRM_JoinDateText:SetText ( strsub ( joinDate , 9 ) );
                
                -- Update timestamp to officer note.
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] and CanEditOfficerNote() then
                    for h = 1 , GRM.GetNumGuildies() do
                        local guildieName ,_,_,_,_,_,_, oNote = GetGuildRosterInfo( h );
                        if guildieName == name and oNote == "" then
                            GuildRosterSetOfficerNote ( h , joinDate );
                            GRM_noteFontString2:SetText ( joinDate );
                            GRM_PlayerOfficerNoteEditBox:SetText ( joinDate );
                            break;
                        end
                    end
                end

                -- Gotta update the event tracker date too!
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][22][1][2] = strsub ( joinDate , 9 ); -- Remember, position 1 of the events tracker for anniversary tracking is always position 1 of the array, with date being pos 1 of table too.
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][22][1][3] = false;  -- Gotta Reset the "reported already" boolean!
                GRM.RemoveFromCalendarQue ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][22][1][1] );
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] == nil then
                    rankButton = true;
                end

                -- Need player index to get this info.
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] then
                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] ~= nil then
                        MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetText ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] );                                     -- Zone
                        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetText ( GRM.GetTimePassed ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][32] ) );              -- Time Passed
                    end
                    MemberDetailMetaData.MemberDetailMetaZoneInfoText:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Show();
                end

                -- Let's send the changes out as well!
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
                    GRMsync.SendMessage ( "GRM_JD" , name .. "?" .. joinDate .. "?" .. finalTimeStamp .. "?" .. finalEpochStamp , "GUILD");
                end
                break;
            end
        end

        DayDropDownMenuSelected:Hide();
        MonthDropDownMenuSelected:Hide();
        YearDropDownMenuSelected:Hide();
        DateSubmitCancelButton:Hide();
        DateSubmitButton:Hide();
        GRM_JoinDateText:Show();
        if rankButton then
            GRM_SetPromoDateButton:Show();
        else
            GRM_MemberDetailRankDateTxt:Show();
        end
        GR_AddonGlobals.pause = false;
    end
end

-- Method:          GRM.SetPromoDate ( self , string )
-- What it Does:    Set's the date the player was promoted to the current rank
-- Purpose:         Date tracking and control of rank promotions.
GRM.SetPromoDate = function ( _ , button )
    local name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );
    local dayJoined = tonumber ( DayDropDownMenuSelected.DayText:GetText() );
    local yearJoined = tonumber ( YearDropDownMenuSelected.YearText:GetText() );
    local IsLeapYearSelected = GRM.IsLeapYear ( yearJoined );

    if GRM.IsValidSubmitDate ( dayJoined , monthsFullnameEnum [ MonthDropDownMenuSelected.MonthText:GetText() ] , yearJoined, IsLeapYearSelected ) then

        for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == name then
                local promotionDate = ( "Joined: " .. dayJoined .. " " ..  strsub ( MonthDropDownMenuSelected.MonthText:GetText() , 1 , 3 ) .. " '" ..  strsub ( YearDropDownMenuSelected.YearText:GetText() , 3 ) );
                
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] = strsub ( promotionDate , 9 );
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][25][#GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][25]][2] = strsub ( promotionDate , 9 );
                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][13] = GRM.TimeStampToEpoch ( promotionDate );
                if GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex then
                    GRM_MemberDetailRankDateTxt:SetPoint ( "TOP" , 0 , -80 ); -- slightly varied positioning due to drop down window or not.
                else
                    GRM_MemberDetailRankDateTxt:SetPoint ( "TOP" , 0 , -68 );
                end
                GRM_MemberDetailRankDateTxt:SetTextColor ( 1 , 1 , 1 , 1.0 );
                GRM_MemberDetailRankDateTxt:SetText ( "Promoted: " .. GRM.Trim ( strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] , 1 , 10) ) );

                -- Need player index to get this info.
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] then
                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] ~= nil then
                        MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetText ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] );                                     -- Zone
                        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetText ( GRM.GetTimePassed ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][32] ) );              -- Time Passed
                    end
                    MemberDetailMetaData.MemberDetailMetaZoneInfoText:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Show();
                    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Show();
                end

                -- Send the details out for others to pickup!
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
                    GRMsync.SendMessage ( "GRM_PD" , name .. "?" .. promotionDate , "GUILD");
                end

                break;
            end
        end

        DayDropDownMenuSelected:Hide();
        MonthDropDownMenuSelected:Hide();
        YearDropDownMenuSelected:Hide();
        DateSubmitCancelButton:Hide();
        DateSubmitButton:Hide();
        GRM_MemberDetailRankDateTxt:Show();
        GR_AddonGlobals.pause = false;
    end
end

-- Method:          GRM.DateSubmitCancelResetLogic()
-- What it Does:    Resets the logic on what occurs with the cancel button, since it will have multiple uses.
-- Purpose:         Resource efficiency. No need to make new buttons for everything! This reuses the button, just resets the click logic in join date submit cancel event.
GRM.DateSubmitCancelResetLogic = function()
    DateSubmitCancelButton:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            local buttonText = DateSubmitButtonTxt:GetText();
            local joinDateText = "Set Join Date";
            local promoDateText = "Set Promo Date";
            local editDateText = "Edit Promo Date";
            local editJoinText = "Edit Join Date";
            local name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );

            -- Determine which information needs to repopulate.
            if joinDateText == buttonText or editJoinText == buttonText then
                if buttonText == editJoinText then
                    GRM_JoinDateText:Show();
                else
                    GRM_MemberDetailJoinDateButton:Show();
                end
                --RANK PROMO DATE
                if GR_AddonGlobals.rankDateSet == false then      --- Promotion has never been recorded!
                    GRM_MemberDetailRankDateTxt:Hide();                     
                    GRM_SetPromoDateButton:Show();
                else
                    GRM_MemberDetailRankDateTxt:Show();
                end
            elseif buttonText == promoDateText then
                GRM_SetPromoDateButton:Show();
            elseif buttonText == editDateText then
                GRM_MemberDetailRankDateTxt:Show();
            end
            GR_AddonGlobals.pause = false;

            -- Need player index to get this info.
            for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == name then

                    if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] then
                        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] ~= nil then
                            MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetText ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] );                                     -- Zone
                            MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetText ( GRM.GetTimePassed ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][32] ) );              -- Time Passed
                        end
                        MemberDetailMetaData.MemberDetailMetaZoneInfoText:Show();
                        MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Show();
                        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Show();
                        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Show();
                    end
                    break;
                end
            end

            -- Close the rest
            MonthDropDownMenuSelected:Hide();
            YearDropDownMenuSelected:Hide();
            DayDropDownMenuSelected:Hide();
            DateSubmitButton:Hide();
            DateSubmitCancelButton:Hide();

        end
    end);
end

-- Method:          GRM.SetDateSelectFrame( string , frameObject, string )
-- What it Does:    On Clicking the "Set Join Date" button this logic presents itself
-- Purpose:         Handle the event to modify when a player joined the guild. This is useful for anniversary date tracking.
--                  It is also necessary because upon starting the addon, it is unknown a person's true join date. This allows the gleader to set a general join date.
GRM.SetDateSelectFrame = function ( fposition , frame , buttonName )
    local _ , month , day , currentYear = CalendarGetDate();
    local xPosMonth , yPosMonth , xPosDay , yPosDay , xPosYear , yPosYear , xPosSubmit , yPosSubmit , xPosCancel , yPosCancel = 0;        -- Default position.
    local months = { "January" , "February" , "March" , "April" , "May" , "June" , "July" , "August" , "September" , "October" , "November" , "December" };
    local joinDateText = "Set Join Date";
    local promoDateText = "Set Promo Date";

    -- Month
    MonthDropDownMenuSelected.MonthText:SetText ( months [ month ] );
    MonthDropDownMenuSelected.MonthText:SetPoint ( "CENTER" , MonthDropDownMenuSelected );
    MonthDropDownMenuSelected.MonthText:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
    MonthDropDownButton:SetScript ( "OnMouseDown" , function( _ , button ) 
        if button == "LeftButton" then
            if MonthDropDownMenu:IsVisible() then
                MonthDropDownMenu:Hide();
            else
                GRM.InitializeDropDownMonth();
                MonthDropDownMenu:Show();
                DayDropDownMenu:Hide();
                YearDropDownMenu:Hide();
            end
        end
    end);
    GR_AddonGlobals.monthIndex = month;
    
    -- Year
    YearDropDownMenuSelected.YearText:SetText ( currentYear );
    YearDropDownMenuSelected.YearText:SetPoint ( "CENTER" , YearDropDownMenuSelected );
    YearDropDownMenuSelected.YearText:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
    YearDropDownButton:SetScript ( "OnMouseDown" , function( _ , button ) 
        if button == "LeftButton" then
            if YearDropDownMenu:IsVisible() then
                YearDropDownMenu:Hide();
            else
                GRM.InitializeDropDownYear();
                YearDropDownMenu:Show();
                MonthDropDownMenu:Hide();
                DayDropDownMenu:Hide();
            end
        end
    end);
    GR_AddonGlobals.yearIndex = currentYear;
    
    -- Initialize the day choice now.
    DayDropDownMenuSelected.DayText:SetText ( day );
    DayDropDownMenuSelected.DayText:SetPoint ( "CENTER" , DayDropDownMenuSelected );
    DayDropDownMenuSelected.DayText:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
    DayDropDownButton:SetScript ( "OnMouseDown" , function( _ , button ) 
        if button == "LeftButton" then
            if DayDropDownMenu:IsVisible() then
                DayDropDownMenu:Hide();
            else
                GRM.InitializeDropDownDay();
                DayDropDownMenu:Show();
                YearDropDownMenu:Hide();
                MonthDropDownMenu:Hide();
            end
        end
    end);
    GR_AddonGlobals.dayIndex = day;
    
    GRM.DateSubmitCancelResetLogic(); 

    if buttonName == "PromoRank" then
        
        -- Change this button
        DateSubmitButtonTxt:SetText ( promoDateText );
        DateSubmitButton:SetScript("OnClick" , GRM.SetPromoDate );
        
        xPosDay = 10.5;
        yPosDay = -80;
        xPosMonth = -63.5;
        yPosMonth = -80;
        xPosYear = 69;
        yPosYear = -80
        xPosSubmit = -37;
        yPosSubmit = -106;
        xPosCancel = 37;
        yPosCancel = -106;

    elseif buttonName == "JoinDate" then

        DateSubmitButtonTxt:SetText ( joinDateText );
        DateSubmitButton:SetScript("OnClick" , GRM.SetJoinDate );
        
        xPosDay = 10.5;
        yPosDay = -80;
        xPosMonth = -63.5;
        yPosMonth = -80;
        xPosYear = 69;
        yPosYear = -80
        xPosSubmit = -37;
        yPosSubmit = -106;
        xPosCancel = 37;
        yPosCancel = -106;
    end

    MonthDropDownMenuSelected:SetPoint ( fposition , frame , xPosMonth , yPosMonth );
    YearDropDownMenuSelected:SetPoint ( fposition , frame , xPosYear , yPosYear );
    DayDropDownMenuSelected:SetPoint ( fposition , frame , xPosDay , yPosDay );
    DateSubmitButton:SetPoint ( fposition , frame , xPosSubmit , yPosSubmit );
    DateSubmitCancelButton:SetPoint ( fposition , frame , xPosCancel , yPosCancel );

    -- Show all Frames
    MonthDropDownMenuSelected:Show();
    YearDropDownMenuSelected:Show();
    DayDropDownMenuSelected:Show();
    DateSubmitButton:Show();
    DateSubmitCancelButton:Show();
end

-- Method:          GRM.GetRankIndex(string)
-- What it Does:    Returns the index of the dropdown menu selection
-- Purpose:         Flow control of drop down menus.
GRM.GetRankIndex = function ( rankName , buttons )
    local index = -1;
    for i = 1 , #buttons do
        if buttons[i][2]:GetText() == rankName then
            index = i;
            break;
        end
    end
    return index;
end

-- Method:          GRM.OnRankDropMenuClick ( self )
-- What it Does:    Logic on Rank Drop down select in main frame
-- Purpose:         UI feature and UX
GRM.OnRankDropMenuClick = function ( formerRank , newRank )
    local newRankIndex = GRM.GetRankIndex ( newRank , RankDropDownMenu.Buttons );
    local formerRankIndex = GRM.GetRankIndex ( formerRank , RankDropDownMenu.Buttons );

    if ( newRankIndex > formerRankIndex and CanGuildDemote() ) or ( newRankIndex < formerRankIndex and CanGuildPromote() ) then
        local numRanks = GuildControlGetNumRanks();
        local numChoices = ( numRanks - GR_AddonGlobals.playerIndex - 1 );
        local solution = newRankIndex + numRanks - numChoices;
            
        for i = 1 , GRM.GetNumGuildies() do
            local name = GetGuildRosterInfo ( i );
            
            if name == GR_AddonGlobals.tempName then
                SetGuildMemberRank ( i , solution );
                -- Now, let's make the changes immediate for the button date.
                if GRM_SetPromoDateButton:IsVisible() then
                    GRM_SetPromoDateButton:Hide();
                    GRM_MemberDetailRankDateTxt:SetText ( "Promoted: " .. GRM.Trim ( strsub(GRM.GetTimestamp() , 1 , 10 ) ) );
                    GRM_MemberDetailRankDateTxt:Show();
                end
                GR_AddonGlobals.pause = false;
                break;
            end
        end
    elseif newRankIndex > formerRankIndex and CanGuildDemote() ~= true then
        print ( "Player Does Not Have Permission to Demote!" );
    elseif newRankIndex < formerRankIndex and CanGuildPromote() ~= true then
        print ( "Player Does Not Have Permission to Promote!" );
    end
end

-- Method:          GRM.PopulateRank ( self , int )
-- What it Does:    Adds all the guild ranks to the drop down menu
-- Purpose:         UI Feature
GRM.PopulateRankDropDown = function ()
    -- populating the frames!
    local buffer = 3;
    local height = 0;
    RankDropDownMenu.Buttons = RankDropDownMenu.Buttons or {};

    -- Resetting the buttons!
    for i = 1 , #RankDropDownMenu.Buttons do
        RankDropDownMenu.Buttons[i][1]:Hide();
    end
    
    local i = 1;
    for count = 2 , ( GuildControlGetNumRanks() - GR_AddonGlobals.playerIndex ) do
        if not RankDropDownMenu.Buttons[i] then
            local tempButton = CreateFrame ( "Button" , "rankIndex" .. i , RankDropDownMenu );
            RankDropDownMenu.Buttons[i] = { tempButton , tempButton:CreateFontString ( "rankIndexText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) }
        end

        local RankButtons = RankDropDownMenu.Buttons[i][1];
        local RankButtonsText = RankDropDownMenu.Buttons[i][2];
        RankButtons:SetWidth ( 112 );
        RankButtons:SetHeight ( 10 );
        RankButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        RankButtonsText:SetText ( GuildControlGetRankName ( count + GR_AddonGlobals.playerIndex ) );
        RankButtonsText:SetWidth ( 112 );
        RankButtonsText:SetWordWrap ( false );
        RankButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
        RankButtonsText:SetPoint ( "CENTER" , RankButtons );
        RankButtonsText:SetJustifyH ( "CENTER" );

        if i == 1 then
            RankButtons:SetPoint ( "TOP" , RankDropDownMenu , 0 , -7 );
            height = height + RankButtons:GetHeight();
        else
            RankButtons:SetPoint ( "TOP" , RankDropDownMenu.Buttons[i - 1][1] , "BOTTOM" , 0 , -buffer );
            height = height + RankButtons:GetHeight() + buffer;
        end

        RankButtons:SetScript ( "OnClick" , function( _ , button ) 
            if button == "LeftButton" then
                local formerRank = guildRankDropDownMenuSelected.RankText:GetText();
                guildRankDropDownMenuSelected.RankText:SetText ( RankButtonsText:GetText() );
                RankDropDownMenu:Hide();
                guildRankDropDownMenuSelected:Show();
                GRM.OnRankDropMenuClick( formerRank , guildRankDropDownMenuSelected.RankText:GetText() );
            end
        end); 
        RankButtons:Show();
        i = i + 1;
    end
    RankDropDownMenu:SetHeight ( height + 15 );
end

-- Method:          GRM.CreateRankDropDown()
-- What it Does:    Builds the final rank drop down product
-- Purpose:         UI Feature
GRM.CreateRankDropDown = function ()
    GRM.PopulateRankDropDown();
    local numRanks = GuildControlGetNumRanks();
    local numChoices = ( numRanks - GR_AddonGlobals.playerIndex - 1 );
    local solution = GR_AddonGlobals.rankIndex - ( numRanks - numChoices ) + 1;   -- Calculating which rank to select based on flexible and scalable rank numbers.
    guildRankDropDownMenuSelected.RankText:SetText( RankDropDownMenu.Buttons[ solution ][2]:GetText() );
    
    RankDropDownMenuButton:SetScript ( "OnMouseDown" , function( _ , button ) 
        if button == "LeftButton" then
            if RankDropDownMenu:IsVisible() then
                RankDropDownMenu:Hide();
            else
                GRM.PopulateRankDropDown();
                RankDropDownMenu:Show();
            end
        end
    end);
    guildRankDropDownMenuSelected:Show();
end


-- Method:          GRM.PopulateOptionsRankDropDown ()
-- What it Does:    Adds all the guild ranks to the drop down menu
-- Purpose:         UI Feature
GRM.PopulateOptionsRankDropDown = function ()
    -- populating the frames!
    local buffer = 3;
    local height = 0;
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons = RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons or {};

    -- Resetting the buttons!
    for i = 1 , #RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons do
        RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i][1]:Hide();
    end
    
    local i = 1;
    for count = 1 , GuildControlGetNumRanks() do
        if not RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i] then
            local tempButton = CreateFrame ( "Button" , "rankIndex" .. i , RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu );
            RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i] = { tempButton , tempButton:CreateFontString ( "rankIndexText" .. i , "OVERLAY" , "GameFontWhiteTiny" ) }
        end

        local RankButtons = RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i][1];
        local RankButtonsText = RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i][2];
        RankButtons:SetWidth ( 110 );
        RankButtons:SetHeight ( 11 );
        RankButtons:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
        RankButtonsText:SetText ( GuildControlGetRankName ( count) );
        RankButtonsText:SetWidth ( 110 );
        RankButtonsText:SetWordWrap ( false );
        RankButtonsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
        RankButtonsText:SetPoint ( "CENTER" , RankButtons );
        RankButtonsText:SetJustifyH ( "CENTER" );

        if i == 1 then
            RankButtons:SetPoint ( "TOP" , RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu , 0 , -7 );
            height = height + RankButtons:GetHeight();
        else
            RankButtons:SetPoint ( "TOP" , RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons[i - 1][1] , "BOTTOM" , 0 , -buffer );
            height = height + RankButtons:GetHeight() + buffer;
        end

        RankButtons:SetScript ( "OnClick" , function( _ , button ) 
            if button == "LeftButton" then
                local formerRank = RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:GetText();
                RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:SetText ( RankButtonsText:GetText() );
                RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:Hide();
                RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:Show();
                GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][15] = GRM.GetRankIndex ( RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:GetText() , RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu.Buttons );
            end
        end); 
        RankButtons:Show();
        i = i + 1;
    end
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetHeight ( height + 15 );
end

-- Method:          GRM.CreateOptionsRankDropDown()
-- What it Does:    Builds the final rank drop down product for options panel
-- Purpose:         UI Feature for options to be able to filter who you will accept shared data from.
GRM.CreateOptionsRankDropDown = function ()
    GRM.PopulateOptionsRankDropDown();
    local setRankName = GuildControlGetRankName ( GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][15] );
    if setRankName == nil or setRankName == "" then
        setRankName = GuildControlGetRankName ( 1 )     -- Default it to guild leader. This scenario could happen if the rank was removed or you change guild but still have old settings.
    end

    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:SetText( setRankName );
    
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenuButton:SetScript ( "OnMouseDown" , function( _ , button ) 
        if button == "LeftButton" then
            if  RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:IsVisible() then
                 RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:Hide();
            else
                GRM.PopulateOptionsRankDropDown();
                 RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:Show();
            end
        end
    end);
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:Show();
end

-- Method:              GRM.ClearPromoDateHistory ( string )
-- What it Does:        Purges history of promotions as if they had just joined the guild.
-- Purpose:             Editing ability in case of user error.
GRM.ClearPromoDateHistory = function ( name )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == name then        -- Player found!
            -- Ok, let's clear the history now!
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][12] = nil;
            GR_AddonGlobals.rankDateSet = false;
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25] = nil;
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25] = {};
            table.insert ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25] , { GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][4] , strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][2] , 1 , string.find ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][2] , "'" ) + 2 ) , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][3] } );
            if GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex and ( CanGuildPromote() or CanGuildDemote() ) then
                GRM_SetPromoDateButton:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -75 ); -- slightly varied positioning due to drop down window or not.
            else
                GRM_SetPromoDateButton:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -67 );
            end
            
            GRM_MemberDetailRankDateTxt:Hide();
            GRM_SetPromoDateButton:Show();
            altDropDownOptions:Hide();
            break;
        end
    end
end

-- Method:              GRM.ClearJoinDateHistory ( string )
-- What it Does:        Clears the player's history on when they joined/left/rejoined the guild to be as if they were  a new member
-- Purpose:             Micromanagement of toons metadata.
GRM.ClearJoinDateHistory = function ( name )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == name then        -- Player found!
            -- Ok, let's clear the history now!
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] = nil;   -- oldJoinDate wiped!
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] = {};
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][21] = nil;
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][21] = {};
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][15] = nil;
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][15] = {};
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][16] = nil;
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][16] = {};
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][2] = GRM.GetTimestamp();
            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][3] = time();
            GRM_JoinDateText:Hide();
            altDropDownOptions:Hide();
            GRM_MemberDetailJoinDateButton:Show();
            break;
        end
    end
end

-- Method:              GRM.ResetPlayerMetaData ( string , string )
-- What it Does:        Purges all metadata from an alt up to that point and resets them as if they were just added to the guild roster
-- Purpose:             Metadata player management. QoL feature if ever needed.
GRM.ResetPlayerMetaData = function ( playerName , guildName )
    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerName then
            print ( GRM.SlimName ( playerName ) .. "'s saved data has been wiped!" );
            local memberInfo = { playerName , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][4] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][5] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][6] , 
                                    GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][7] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][8] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][9] , nil , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][28] , 
                                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][29] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][30] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][31] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][33] , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][34] };

            if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                GRM.RemoveAlt ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][1][1] , playerName , guildName );      -- Removing oneself from his alts list on clearing info so it clears him from them too.
            end
            table.remove ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] , j );         -- Remove the player!
            GRM.AddMemberRecord( memberInfo , false , nil , guildName )     -- Re-Add the player!
            MemberDetailMetaData:Hide();
            break;
        end
    end
end

-- Method:          GRM.ResetAllSavedData()
-- What it Does:    Purges literally ALL saved data, then rebuilds it from scratch as if addon was just installed.
-- Purpose:         Clear data for any purpose needed.
GRM.ResetAllSavedData = function()
    print ( "Wiping all saved Roster data! Rebuilding from scratch..." );

    GRM_GuildMemberHistory_Save = nil;
    GRM_GuildMemberHistory_Save = {};
    table.insert ( GRM_GuildMemberHistory_Save , { "Horde" } );
    table.insert ( GRM_GuildMemberHistory_Save , { "Alliance" } );

    GRM_PlayersThatLeftHistory_Save = nil;
    GRM_PlayersThatLeftHistory_Save = {};
    table.insert ( GRM_PlayersThatLeftHistory_Save , { "Horde" } );
    table.insert ( GRM_PlayersThatLeftHistory_Save , { "Alliance" } );

    GRM_LogReport_Save = nil;
    GRM_LogReport_Save = {};
    table.insert ( GRM_LogReport_Save , { "Horde" } );
    table.insert ( GRM_LogReport_Save , { "Alliance" } );

    GRM_CalendarAddQue_Save = nil;
    GRM_CalendarAddQue_Save = {};
    table.insert ( GRM_CalendarAddQue_Save , { "Horde" } );
    table.insert ( GRM_CalendarAddQue_Save , { "Alliance" } );

    -- Hide the window frame so it can quickly be reloaded.
    MemberDetailMetaData:Hide();

    -- Reset the important guild indexes for data tracking.
    GR_AddonGlobals.saveGID = 0;
    GR_AddonGlobals.logGID = 0;

    -- Now, let's rebuild...
    if IsInGuild() then
        GRM.BuildNewRoster();
    end
    -- Update the logFrame if it was open at the time too
    if RosterChangeLogFrame:IsVisible() then
        GRM.BuildLog();
    end
end

-- Method:          GRM.ResetLogReport()
-- What it Does:    Deletes the guild Log
-- Purpose:         In case player wishes to reset guild Log information.
GRM.ResetLogReport = function()
    if #GRM_LogReport_Save[GR_AddonGlobals.FID][GR_AddonGlobals.logGID] == 1 then
        print ( "There are No Log Entries to Delete, silly " .. GRM.SlimName( GR_AddonGlobals.addonPlayerName ) .. "!" );
    else
        print ( "Guild Log has been RESET!" );
        -- Actually resetting log. Just remove, then add back empty
        table.remove ( GRM_LogReport_Save[GR_AddonGlobals.FID] , GR_AddonGlobals.logGID );
        table.insert ( GRM_LogReport_Save[GR_AddonGlobals.FID] , { GR_AddonGlobals.guildName } );
        -- Need to reset Guild Index Location
        for i = 2 , #GRM_LogReport_Save[GR_AddonGlobals.FID] do
            if GRM_LogReport_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.guildName then
                GR_AddonGlobals.logGID = i;
                break;
            end
        end
        if RosterChangeLogFrame:IsVisible() then    -- if frame is open, let's rebuild it!
            GRM.BuildLog();
        end
    end
end
-------------------------------
----- UI SCRIPTING LOGIC ------
----- ALL THINGS UX ARE HERE --
-------------------------------

-- Method:          PopulateMemberDetails ( string )
-- What it Does:    Builds the details for the core MemberInfoFrame
-- Purpose:         Iterate on each mouseover... Furthermore, this is being kept in "Local" for even the most infinitesimal cost-saving on resources
--                  by not indexing it in a table. Buried in it will be mostly non-compartmentalized logic, few function calls.
local function PopulateMemberDetails( handle )
    GR_AddonGlobals.rankDateSet = false;        -- resetting tracker

    for r = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][1] == handle then   --- Player Found in MetaData Logs
            -- Trigger Check for Any Changes
            GuildRoster();

            --- CLASS
            local classColors = GRM.GetClassColorRGB ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][9] );
            GRM_MemberDetailNameText:SetTextColor ( classColors[1] , classColors[2] , classColors[3] , 1.0 );
            
            -- PLAYER NAME
            GRM_MemberDetailNameText:SetText ( GRM.SlimName ( handle ) );

            -- IS MAIN
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][10] then
                GRM_MemberDetailMainText:Show();
            else
                GRM_MemberDetailMainText:Hide();
            end

            --- LEVEL
            GRM_MemberDetailLevel:SetText ( "Level: " .. GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][6] );

            -- RANK
            GR_AddonGlobals.tempName = handle;
            GR_AddonGlobals.rankIndex = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][5];
            if GR_AddonGlobals.playerIndex == -1 then
                GR_AddonGlobals.playerIndex = GRM.GetGuildMemberRankID ( GR_AddonGlobals.addonPlayerName );
            end

            local canPromote = CanGuildPromote();
            local canDemote = CanGuildDemote();
            if GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex and ( canPromote or canDemote ) then
                GRM_MemberDetailRankTxt:Hide();
                GRM.CreateRankDropDown();
            else
                guildRankDropDownMenuSelected:Hide();
                GRM_MemberDetailRankTxt:SetText ( "\"" .. GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][4] .. "\"");
                GRM_MemberDetailRankTxt:Show();
            end

            -- STATUS TEXT
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] or handle == GR_AddonGlobals.addonPlayerName then
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][34] == 0 then
                    GRM_MemberDetailPlayerStatus:SetTextColor ( 0.12 , 1.0 , 0.0 , 1.0 );
                    GRM_MemberDetailPlayerStatus:SetText ( "( Active )" );
                elseif GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][34] == 1 then
                    GRM_MemberDetailPlayerStatus:SetTextColor ( 1.0 , 0.96 , 0.41 , 1.0 );
                    GRM_MemberDetailPlayerStatus:SetText ( "( AFK )" );
                else
                    GRM_MemberDetailPlayerStatus:SetTextColor ( 0.77 , 0.12 , 0.23 , 1.0 );
                    GRM_MemberDetailPlayerStatus:SetText ( "( Busy )" );
                end
                GRM_MemberDetailPlayerStatus:Show();
            elseif GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][30] then
                GRM_MemberDetailPlayerStatus:SetTextColor ( 0.87 , 0.44 , 0.0 , 1.0 );
                GRM_MemberDetailPlayerStatus:SetText ( "( Mobile )" );
                GRM_MemberDetailPlayerStatus:Show();
            else
                GRM_MemberDetailPlayerStatus:Hide();
            end

            -- ZONE INFORMATION
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] then
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] ~= nil then
                    MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetText ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][28] );                                     -- Zone
                    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetText ( GRM.GetTimePassed ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][32] ) );              -- Time Passed
                end
                MemberDetailMetaData.MemberDetailMetaZoneInfoText:Show();
                MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Show();
                MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Show();
                MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Show();
            else
                MemberDetailMetaData.MemberDetailMetaZoneInfoText:Hide();
                MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Hide();
                MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Hide();
                MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Hide();
            end

            --RANK PROMO DATE
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] == nil then      --- Promotion has never been recorded!
                GRM_MemberDetailRankDateTxt:Hide();
                if GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex and ( canPromote or canDemote ) then
                    GRM_SetPromoDateButton:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -75 ); -- slightly varied positioning due to drop down window or not.
                else
                    GRM_SetPromoDateButton:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -67 );
                end
                GRM_SetPromoDateButton:Show();
            else
                GRM_SetPromoDateButton:Hide();
                if GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex and ( canPromote or canDemote ) then
                    GRM_MemberDetailRankDateTxt:SetPoint ( "TOP" , 0 , -80 ); -- slightly varied positioning due to drop down window or not.
                else
                    GRM_MemberDetailRankDateTxt:SetPoint ( "TOP" , 0 , -68 );
                end
                GR_AddonGlobals.rankDateSet = true;
                GRM_MemberDetailRankDateTxt:SetTextColor ( 1 , 1 , 1 , 1.0 );
                GRM_MemberDetailRankDateTxt:SetText ( "Promoted: " .. GRM.Trim ( strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][12] , 1 , 10) ) );
                GRM_MemberDetailRankDateTxt:Show();
            end

            if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20] == 0 then
                GRM_JoinDateText:Hide();
                GRM_MemberDetailJoinDateButton:Show();
            else
                GRM_MemberDetailJoinDateButton:Hide();
                GRM_JoinDateText:SetText ( strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20][#GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][20]] , 1 , 10 ) );
                GRM_JoinDateText:Show();
            end

            -- PLAYER NOTE AND OFFICER NOTE EDIT BOXES
            local finalNote = "Click here to set a Public Note";
            local finalONote = "Click here to set an Officer's Note";
            GRM_PlayerNoteEditBox:Hide();
            GRM_PlayerOfficerNoteEditBox:Hide();

            -- Set Public Note if is One
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][7] ~= nil and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][7] ~= "" then
                finalNote = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][7];
            end
            GRM_noteFontString1:SetText ( finalNote );
            if CanEditPublicNote() then
                if finalNote ~= "Click here to set a Public Note" then
                    GRM_PlayerNoteEditBox:SetText( finalNote );
                else
                    GRM_PlayerNoteEditBox:SetText( "" );
                end
            elseif finalNote == "Click here to set a Public Note" then
                GRM_noteFontString1:SetText ( "Unable to Edit Public Note at Rank" );
            end

            -- Set O Note
            if CanViewOfficerNote() == true then
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8] ~= nil and GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8] ~= "" then
                    finalONote = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][8];
                end
                if finalONote == "Click here to set an Officer's Note" and CanEditOfficerNote() ~= true then
                    finalONote = "Unable to Add Officer Note at Rank";
                end
                GRM_noteFontString2:SetText ( finalONote );
                if finalONote ~= "Click here to set an Officer's Note" then
                    GRM_PlayerOfficerNoteEditBox:SetText( finalONote );
                else
                    GRM_PlayerOfficerNoteEditBox:SetText( "" );
                end
            else
                GRM_noteFontString2:SetText ( "Unable to View Officer Note at Rank" );
            end
            GRM_noteFontString2:Show();
            GRM_noteFontString1:Show();

            -- Last Online
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] then
                GR_MemberDetailLastOnlineTxt:SetText ( "Online" );
            else
                GR_MemberDetailLastOnlineTxt:SetText ( GRM.HoursReport ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][24] ) );
            end

            -- Group Invite Button -- Setting script here
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][33] and handle ~= GR_AddonGlobals.addonPlayerName then
                if GetNumGroupMembers() > 0  then            -- If > 0 then player is in either a raid or a party. (1 will show if in an instance by oneself)
                    local isGroupLeader = UnitIsGroupLeader ( "PLAYER" );                                       -- Party or Group
                    local isInRaidWithAssist = UnitIsGroupAssistant ( "PLAYER" , LE_PARTY_CATEGORY_HOME );      -- Player Has Assist in Raid group

                    if GRM.IsGuildieInSameGroup ( handle ) then
                        -- Player is already in group!
                        GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetText ( "In Group" );
                        GRM_GroupInviteButton:SetScript ("OnClick" , function ( _ , button , down )
                            if button == "LeftButton" then
                                print ( GRM.SlimName ( handle ) .. " is Already in Your Group!" );
                            end
                        end);
                    elseif isGroupLeader or isInRaidWithAssist then                                         -- Player has the ability to invite to group
                        GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetText ( "Group Invite" );
                        GRM_GroupInviteButton:SetScript ( "OnClick" , function ( _ , button , down )
                            if button == "LeftButton" then
                                if IsInRaid() and GetNumGroupMembers() == 40 then                               -- Helpful reporting to cleanup the raid in case players are offline and no room to invite.
                                    local afkList = GRM.GetGroupUnitsOfflineOrAFK();
                                    local report = ( "\nROSTER NOTIFICATION!!!\n40 players have already been invited to this Raid!" );
                                    if #afkList[1] > 0 then
                                        report = ( report .. "\nPlayers Offline: " );
                                        for i = 1 , #afkList[1]  do
                                            report = ( report .. "" .. afkList[1][i] );
                                            if i ~= #afkList[1] then
                                                report = ( report .. ", ");
                                            end
                                        end
                                    end

                                    if #afkList[2] > 0 then
                                        report = ( report .. "\nPlayers AFK:     " );
                                        for i = 1 , #afkList[2]  do
                                            report = ( report .. "" .. afkList[2][i] );
                                            if i ~= #afkList[2] then
                                                report = ( report .. ", ");
                                            end
                                        end
                                    end
                                    print ( report );

                                else
                                    InviteUnit ( handle );
                                end
                            end
                        end);
                    else            -- Player is in a group but does not have invite privileges
                        GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetText ( "No Invite" );
                        GRM_GroupInviteButton:SetScript ( "OnClick" , function ( _ , button , down )
                            if button == "LeftButton" then
                                print ( "Player must obtain group invite privileges." );
                            end
                        end);
                    end
                else
                    -- Player is not in any group, thus inviting them will create new group.
                    GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetText ( "Group Invite" );
                    GRM_GroupInviteButton:SetScript ( "OnClick" , function ( _ , button , down )
                        if button == "LeftButton" then
                            InviteUnit ( handle );
                        end
                    end);
                end

                GRM_GroupInviteButton:Show();
            else
                GRM_GroupInviteButton:Hide();
            end

            -- REMOVE SOMEONE FROM GUILD BUTTON.
            local isGuildieBanned = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][17];
            if handle ~= GR_AddonGlobals.addonPlayerName and GR_AddonGlobals.rankIndex > GR_AddonGlobals.playerIndex and CanGuildRemove() then
                local isGuildieBanned = GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][17];
                if isGuildieBanned then
                    GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:SetText ( "Re-Kick" );
                else
                    GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:SetText ( "Remove" );
                end
                GRM_RemoveGuildieButton:Show();
                GRM_RemoveGuildieButton:SetScript ( "OnClick" , function ( _ , button )
                    -- Inital check is to ensure clean UX - ensuring the next time window is closed on reload, but if already open, no need to close it.
                    if button == "LeftButton" then
                        GR_AddonGlobals.pause = true
                        if GR_PopupWindow:IsVisible() ~= true then
                            GR_MemberDetailEditBoxFrame:Hide();
                            GR_PopupWindowCheckButton1:SetChecked ( false ); -- Ensures it is always unchecked on load.
                            GR_PopupWindowCheckButton2:SetChecked ( false );
                        end
                        if GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:GetText() == "Re-Kick" then
                            GR_PopupWindowConfirmText:SetText ( "Are you sure you want to Re-Gkick " .. GRM.SlimName ( handle ) .. "?" );
                        else
                            GR_PopupWindowConfirmText:SetText ( "Are you sure you want to Gkick " .. GRM.SlimName ( handle ) .. "?" );
                        end
                        if GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:GetText() ~= "Re-Kick" then
                            GR_PopupWindowCheckButtonText:SetTextColor ( 1.0 , 0.0 , 0.0 , 1.0 );
                            GR_PopupWindowCheckButtonText:SetText ( "Ban Player" );
                            GR_PopupWindowCheckButtonText:Show();
                            GR_PopupWindowCheckButton1:Show();
                        else
                            GR_PopupWindowCheckButtonText:Hide();
                            GR_PopupWindowCheckButton1:Hide();
                        end
                        if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][11] > 0 then
                            GR_PopupWindowCheckButton2Text:SetTextColor ( 1.0 , 1.0 , 1.0 , 1.0 );
                            GR_PopupWindowCheckButton2Text:SetText ( "Kick Alts Too!" );
                            GR_PopupWindowCheckButton2Text:Show();
                            GR_PopupWindowCheckButton2:Show();
                        else
                            GR_PopupWindowCheckButton2Text:Hide();
                            GR_PopupWindowCheckButton2:Hide();
                        end
                        GR_PopupWindow:Show();

                        -- Create Button Logic
                        GR_PopupWindowButton1:SetScript ( "OnClick" , function( _ , button )
                            if button == "LeftButton" then
                                if GR_PopupWindowCheckButton1:IsVisible() and GR_PopupWindowCheckButton1:GetChecked() then          -- Box is checked, so YES player should be banned.
                                    -- Popup edit box
                                    
                                    local instructionNote = "Reason Banned? (Press ENTER when done)"
                                    MemberDetailPopupEditBox:SetText ( instructionNote );
                                    MemberDetailPopupEditBox:HighlightText ( 0 );
                                    MemberDetailPopupEditBox:SetScript ( "OnEnterPressed" , function ( _ )

                                        -- If kick alts button is checked...
                                        if GR_PopupWindowCheckButton2:IsVisible() and GR_PopupWindowCheckButton2:GetChecked() then
                                            GRM.KickAllAlts ( handle , GR_AddonGlobals.guildName );
                                        end
                                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][17] = true;      -- Banning Player.
                                        local result = MemberDetailPopupEditBox:GetText();
                                        if result ~= instructionNote and result ~= "" and result ~= nil then
                                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = result;
                                        elseif result == nil then
                                            GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = "";
                                        end
                                        -- Now let's kick the member
                                        GuildUninvite ( handle );
                                        GR_MemberDetailEditBoxFrame:Hide();
                                        GR_AddonGlobals.pause = false;                                                
                                    end);
                                    GR_MemberDetailEditBoxFrame:Show();
                                    MemberDetailPopupEditBox:Show();
                                else    -- Kicking the player ( not a ban )
                                    -- if button 2 is checked, kick the alts too.
                                    if GR_PopupWindowCheckButton2:IsVisible() and GR_PopupWindowCheckButton2:GetChecked() then
                                        GRM.KickAllAlts ( handle , GR_AddonGlobals.guildName );
                                    end
                                    GR_PopupWindow:Hide();
                                    GuildUninvite ( handle );
                                    GR_AddonGlobals.pause = false;
                                end
                            end
                        end);
                    end
                end);
            else
                GRM_RemoveGuildieButton:Hide();
            end

            -- Player was previous banned and rejoined logic! This will unban the player.
            if isGuildieBanned then
                GR_MemberDetailBannedIgnoreButton:SetScript ( "OnClick" , function ( _ , button ) 
                    if button == "LeftButton" then
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][17] = false;
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][r][18] = "";
                        GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:SetText( "Remove" );
                        GR_MemberDetailBannedText1:Hide();
                        GR_MemberDetailBannedIgnoreButton:Hide();
                        GR_PopupWindow:Hide();
                    end
                end);
                
                GR_MemberDetailBannedText1:Show();
                GR_MemberDetailBannedIgnoreButton:Show();
            else
                GR_MemberDetailBannedText1:Hide();
                GR_MemberDetailBannedIgnoreButton:Hide();
            end

            -- ALTS 
            GRM.PopulateAltFrames ( r );

            break;
        end
    end
end

-- Method:          GRM.ClearAllFrames()
-- What it Does:    Ensures frames are properly reset upon frame reload...
-- Purpose:         Logic time-saver for minimal costs... why check status of them all when you can just disable and build anew on each reload?
GRM.ClearAllFrames = function()
    MemberDetailMetaData:Hide();
    MonthDropDownMenuSelected:Hide();
    YearDropDownMenuSelected:Hide();
    DayDropDownMenuSelected:Hide();
    guildRankDropDownMenuSelected:Hide();
    DateSubmitButton:Hide();
    DateSubmitCancelButton:Hide();
    GR_PopupWindow:Hide();
    GRM_NoteCount:Hide();
    GR_CoreAltFrame:Hide();
    altDropDownOptions:Hide();
    AddAltButton:Hide();
    AddAltEditFrame:Hide();
end

-- Method:          GRM.SubFrameCheck()
-- What it Does:    Checks the core main frames, if they are open... and hides them
-- Purpose:         Questionable at this time... I might rewrite it with just 4 lines... It serves its purpose now
GRM.SubFrameCheck = function()
    -- wipe the frames...
    if DateSubmitCancelButton:IsVisible() then
        DateSubmitCancelButton:Click();
    end
    if AddAltEditFrame:IsVisible() then
        AddAltEditFrame:Hide();
    end
    if GR_PopupWindow:IsVisible() then
        GR_PopupWindow:Hide();
    end
    if GRM_NoteCount:IsVisible() then
        GRM_NoteCount:Hide();
    end
end

-- Method:          GRM.GetNumGuildiesOnline()
-- What it Does:    Returns the int number of players currently online.
-- Purpose:         So on mouseover, the index on the roster call can be determined properly as online people are indexed first.
GRM.GetNumGuildiesOnline = function()
    local count = 0;
    for i = 1 , GRM.GetNumGuildies() do 
        local _ , _ , _ , _ , _ , _ , _ , _ , online , _ , _ , _ , _ , isMobile = GetGuildRosterInfo ( i );
        if online or isMobile then
            count = count + 1;
        end
    end
    return count;
end


-- Method:              GR_RosterFrame(self,elapsed)
-- What it Does:        In the main guild window, guild roster screen, rather than having to select a guild member to see the additional window pop update
--                      all the player needs to do is just mousover it.
-- Purpose:             This is for more efficient "glancing" at info for guild leader, with more details.
--                      NOTE: Also going to keep this as a local variable, not in a table, just for purposes of the faster response time, albeit minimally.
local function GR_RosterFrame ( _ , elapsed )
    GR_AddonGlobals.timer = GR_AddonGlobals.timer + elapsed;
    if GR_AddonGlobals.timer >= 0.038 then
        -- Frame button logic for AddEvent
        if #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] > 1 and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][8] and GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][12] then
            AddEventLoadFrameButtonText:SetText ( "Calendar Que: " .. #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] - 1 );     -- First index will be nil.
            AddEventLoadFrameButton:Show();
        else
            AddEventLoadFrameButton:Hide();
        end
        -- control on whether to freeze the scanning.
        if GR_AddonGlobals.pause and MemberDetailMetaData:IsVisible() == false then
            GR_AddonGlobals.pause = false;
        end

        if GR_AddonGlobals.pause == false and not DropDownList1:IsVisible() and ( GuildRosterViewDropdownText:IsVisible() and GuildRosterViewDropdownText:GetText() ~= "Professions" ) then
            GRM.SubFrameCheck();
            local NotSameWindow = true;
            local mouseNotOver = true;
            local name = "";
            local length = 84;

            if ( GuildRosterContainerButton1:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 1 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton1 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 1;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton2:IsVisible() and GuildRosterContainerButton2:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 2 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton2 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 2;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton3:IsVisible() and GuildRosterContainerButton3:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 3 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton3 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 3;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton4:IsVisible() and GuildRosterContainerButton4:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 4 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton4 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 4;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton5:IsVisible() and GuildRosterContainerButton5:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 5 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton5 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 5;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton6:IsVisible() and GuildRosterContainerButton6:IsMouseOver(1,-1,-1,1) ) then
                if 6 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton6 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 6;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton7:IsVisible() and GuildRosterContainerButton7:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 7 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton7 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 7;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton8:IsVisible() and GuildRosterContainerButton8:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 8 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton8 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 8;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton9:IsVisible() and GuildRosterContainerButton9:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 9 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton9 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 9;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton10:IsVisible() and GuildRosterContainerButton10:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 10 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton10 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 10;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton11:IsVisible() and GuildRosterContainerButton11:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 11 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton11 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 11;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton12:IsVisible() and GuildRosterContainerButton12:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 12 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton12 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 12;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton13:IsVisible() and GuildRosterContainerButton13:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 13 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton13 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 13;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            elseif ( GuildRosterContainerButton14:IsVisible() and GuildRosterContainerButton14:IsMouseOver ( 1 , -1 , -1 , 1 ) ) then
                if 14 ~= GR_AddonGlobals.position then
                    name = GRM.GetMouseOverName ( GuildRosterContainerButton14 );
                    PopulateMemberDetails( name );
                    if MemberDetailMetaData:IsVisible() ~= true then
                        MemberDetailMetaData:Show();
                    end
                    GR_AddonGlobals.position = 14;
                    GR_AddonGlobals.pause = false;
                else
                    NotSameWindow = false;
                end
                mouseNotOver = false;
            end
            -- Logic on when to make Member Detail window disappear.
            if mouseNotOver and NotSameWindow and GR_AddonGlobals.pause == false then
                if ( GuildRosterFrame:IsMouseOver ( 2 , -2 , -2 , 2 ) ~= true and DropDownList1Backdrop:IsMouseOver ( 2 , -2 , -2 , 2 ) ~= true and MemberDetailMetaData:IsMouseOver ( 2 , -2 , -2 , 2 ) ~= true ) or 
                    ( MemberDetailMetaData:IsMouseOver ( 2 , -2 , -2 , 2 ) == true and MemberDetailMetaData:IsVisible() ~= true ) then  -- If player is moused over side window, it will not hide it!
                    GR_AddonGlobals.position = 0;
                    
                    GRM.ClearAllFrames();
                end
            end
        end
        if GuildRosterFrame:IsVisible() ~= true or ( GuildRosterViewDropdownText:IsVisible() and GuildRosterViewDropdownText:GetText() == "Professions" ) then
            
            GRM.ClearAllFrames();

        end
        GR_AddonGlobals.timer = 0;
    end
end

--- FINALLY!!!!!
--- TOOLTIPS ---
----------------

-- Method:          GRM.MemberDetailToolTips ( self , float )
-- What it Does:    Populates the tooltips on the "OnUpdate" check for the core Member Detail frame
-- Purpose:         UI Feature
GRM.MemberDetailToolTips = function ( self , elapsed )
    GR_AddonGlobals.timer2 = GR_AddonGlobals.timer2 + elapsed;
    if GR_AddonGlobals.timer2 >= 0.075 then
        local name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );

        -- Rank Text
        -- Only populate and show tooltip if mouse is over text frame and it is not already visible.
        if GRM_MemberDetailRankToolTip:IsVisible() ~= true and not RankDropDownMenu:IsVisible() and GRM_MemberDetailRankDateTxt:IsVisible() == true and altDropDownOptions:IsVisible() ~= true and GRM_MemberDetailRankDateTxt:IsMouseOver(1,-1,-1,1) == true then
            
            GRM_MemberDetailRankToolTip:SetOwner( GRM_MemberDetailRankDateTxt , "ANCHOR_CURSOR" );
            GRM_MemberDetailRankToolTip:AddLine( "|cFFFFFFFFRank History");

            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == name then   --- Player Found in MetaData Logs
                    -- Now, let's build the tooltip
                    for k = #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25] , 1 , -1 do
                        if k == 1 then
                            local timeAtRank = GRM.GetTimePassedUsingStringStamp ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][12] );
                            GRM_MemberDetailRankToolTip:AddDoubleLine ( "|cFFFF0000Time at Rank: " , timeAtRank[4] );
                            GRM_MemberDetailRankToolTip:AddDoubleLine ( " " , " " );
                        end
                        GRM_MemberDetailRankToolTip:AddDoubleLine( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25][k][1] .. ":" , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][25][k][2] , 0.38 , 0.67 , 1.0 );
                    end
                    break;
                end
            end

            GRM_MemberDetailRankToolTip:Show();
        elseif GRM_MemberDetailRankToolTip:IsVisible() == true and GRM_MemberDetailRankDateTxt:IsMouseOver(1,-1,-1,1) ~= true then
            GRM_MemberDetailRankToolTip:Hide();
        end

        -- JOIN DATE TEXT
        if GRM_MemberDetailJoinDateToolTip:IsVisible() ~= true and GRM_JoinDateText:IsVisible() == true and altDropDownOptions:IsVisible() ~= true and GRM_JoinDateText:IsMouseOver(1,-1,-1,1) == true then
           
            GRM_MemberDetailJoinDateToolTip:SetOwner( GRM_JoinDateText , "ANCHOR_CURSOR" );
            GRM_MemberDetailJoinDateToolTip:AddLine( "|cFFFFFFFFMembership History");
            local joinedHeader;

            for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == name then   --- Player Found in MetaData Logs
                    -- Ok, let's build the tooltip now.
                    for r = #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20] , 1 , -1 do                                       -- Starting with most recent join which will be at end of array.
                        if r > 1 then
                            joinedHeader = "Rejoined: ";
                        else
                            joinedHeader = "Joined: ";
                        end
                        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][15][r] ~= nil then
                            GRM_MemberDetailJoinDateToolTip:AddDoubleLine( "|CFFC41F3BLeft:    " ,  GRM.Trim ( strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][15][r] , 1 , 10 ) ) , 1 , 0 , 0 );
                        end
                        GRM_MemberDetailJoinDateToolTip:AddDoubleLine( joinedHeader , GRM.Trim ( strsub ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][20][r] , 1 , 10 ) ) , 0.38 , 0.67 , 1.0 );
                        -- If player once left, then this will add the line for it.
                    end
                break;
                end
            end

            GRM_MemberDetailJoinDateToolTip:Show();
        elseif GRM_MemberDetailJoinDateToolTip:IsVisible() == true and GRM_JoinDateText:IsMouseOver(1,-1,-1,1) ~= true then
            GRM_MemberDetailJoinDateToolTip:Hide();
        end

        GR_AddonGlobals.timer2 = 0;
    end
end


----------------------
--- FRAME VALUES -----
--- AND PARAMETERS ---
----------------------

-- Method:          GRM.LogOptionsFadeIn()
-- What it Does:    Fades in the Options frame and buttons on the guildRoster Log window
-- Purpose:         Really, just aesthetics for User Experience.
GRM.LogOptionsFadeIn = function()

    RosterCheckBoxSideFrame:SetAlpha ( RosterCheckBoxSideFrame:GetAlpha() + 0.025 );
    if RosterCheckBoxSideFrame.RosterSyncCheckButton:GetChecked() then
        RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:SetAlpha ( RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:GetAlpha() + 0.025 );
    end

    if RosterCheckBoxSideFrame:GetAlpha() < 1 then
        C_Timer.After ( 0.01 , GRM.LogOptionsFadeIn );
    else
        -- print("fade in complete!");
    end
end

-- Method:          GRM.LogOptionsFadeOut()
-- What it Does:    Fades OUT the Options frame and buttons on the guildRoster Log window
-- Purpose:         Really, just aesthetics for User Experience.
GRM.LogOptionsFadeOut = function()
    
    RosterCheckBoxSideFrame:SetAlpha ( RosterCheckBoxSideFrame:GetAlpha() - 0.05 );
    if RosterCheckBoxSideFrame.RosterSyncCheckButton:GetChecked() then
        RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:SetAlpha ( RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:GetAlpha() - 0.05 );
    end
    if RosterCheckBoxSideFrame:GetAlpha() > 0 then
        C_Timer.After ( 0.01 , GRM.LogOptionsFadeOut );
    else
        -- print("fade out complete!");
    end
end

-- Method:          GRM.LogFrameTransformationOpen()
-- What it Does:    Transforms the frame to be larger, revealing the "options" details
-- Purpose:         Really, just aesthetics for User Experience, but also for a concise framework.
GRM.LogFrameTransformationOpen = function ()
    RosterChangeLogFrame:SetSize ( 600 , RosterChangeLogFrame:GetHeight() + 3.5 );          -- reset size, slightly increment it up!
    -- Determine if I need to loop through again.
    local fading = false;
    local height = 522;
    if RosterCheckBoxSideFrame.RosterSyncCheckButton:GetChecked() then
        height = 542;
    end
    if math.floor ( RosterChangeLogFrame:GetHeight() ) < height then   
        if not fading and math.floor ( RosterChangeLogFrame:GetHeight() ) > 460 then        -- Trigger fade transition into already moving tile.
            GRM.LogOptionsFadeIn();
            fading = true;
        end
         C_Timer.After ( 0.01 , GRM.LogFrameTransformationOpen );
    else        -- Exit from Recursive Loop for transformation.
        RosterOptionsButton:Enable();
    end
end

-- Method:          GRM.LogFrameTransformationClose()
-- What it Does:    Transforms the frame back to normal side, hiding the "options" details
-- Purpose:         Really, just aesthetics for User Experience, but also for a concise framework.
GRM.LogFrameTransformationClose = function ()
    RosterChangeLogFrame:SetSize ( 600 , RosterChangeLogFrame:GetHeight() - 4.0 );          -- reset size, slightly increment it up!
    -- Determine if I need to loop through again.
    if math.floor ( RosterChangeLogFrame:GetHeight() ) > 440 then
         C_Timer.After ( 0.01 , GRM.LogFrameTransformationClose );
    else        -- Exit from Recursive Loop for transformation.
        RosterCheckBoxSideFrame:Hide();
        RosterOptionsButton:Enable();
    end
end

-- Method:          GRM.LogFrameTransformationCloseMinor()
-- What it Does:    Transforms the frame back to hide 1 layer of options
-- Purpose:         Really, just aesthetics for User Experience, but also for a concise framework.
GRM.LogFrameTransformationCloseMinor = function ()
    RosterChangeLogFrame:SetSize ( 600 , RosterChangeLogFrame:GetHeight() - 4.0 );          -- reset size, slightly increment it up!
    -- Determine if I need to loop through again.
    if math.floor ( RosterChangeLogFrame:GetHeight() ) > 524 then
         C_Timer.After ( 0.01 , GRM.LogFrameTransformationCloseMinor );
    end
end
-- Method:          GRM.UpdateGuildMemberInRaidStatus()
-- What it Does:    Updates the text frame on number of guild members in a current raid group
-- Purpose:         Update, on the fly, every 3 seconds, number of guildies present.
GRM.UpdateGuildMemberInRaidStatus = function ()
    -- Only trigger once per 3 seconds.
    if IsInGroup() and RaidFrame:IsVisible() and not RaidFrameNotInRaid:IsVisible() then
        local numGuildies = GRM.GetNumGuildiesInGroup();
        if numGuildies > 0 then
            UI_Events.NumGuildiesText:SetText ( "Guildies: " .. numGuildies );
            UI_Events.NumGuildiesText:Show();
        else
            UI_Events.NumGuildiesText:Hide();
        end
        C_Timer.After ( 1 , GRM.UpdateGuildMemberInRaidStatus );              -- Check for updates recursively
    elseif IsInGroup() then
        UI_Events.NumGuildiesText:Hide();
        C_Timer.After ( 1 , GRM.UpdateGuildMemberInRaidStatus );
    else
        UI_Events.NumGuildiesText:Hide();
        GR_AddonGlobals.RaidGCountBeingChecked = false;
    end
end

-- Method:                  GR_MetaDataInitializeUIFirst()
-- What it Does:            Initializes "some of the frames"
-- Purpose:                 Should only initialize as needed. Kept as local for speed
GRM.GR_MetaDataInitializeUIFirst = function()
    -- Frame Control
    MemberDetailMetaData:EnableMouse ( true );
    -- MemberDetailMetaData:SetMovable ( true );
    -- MemberDetailMetaData:RegisterForDrag ( "LeftButton" );
    -- MemberDetailMetaData:SetScript ( "OnDragStart" , MemberDetailMetaData.StartMoving );
    -- MemberDetailMetaData:SetScript ( "OnDragStop" , MemberDetailMetaData.StopMovingOrSizing );
    MemberDetailMetaData:SetToplevel ( true );

    -- Placement and Dimensions
    MemberDetailMetaData:SetPoint ( "TOPLEFT" , GuildRosterFrame , "TOPRIGHT" , -4 , 5 );
    MemberDetailMetaData:SetSize( 285 , 330 );
    MemberDetailMetaData:SetScript( "OnShow" , function() 
        MemberDetailMetaDataCloseButton:SetPoint( "TOPRIGHT" , MemberDetailMetaData , 3, 3 ); 
        MemberDetailMetaDataCloseButton:Show()
    end);
    MemberDetailMetaData:SetScript ( "OnUpdate" , GRM.MemberDetailToolTips );

    -- Logic handling: If pause is set, this unpauses it. If it is not paused, this will then hide the window.
    MemberDetailMetaData:SetScript ( "OnKeyDown" , function ( _ , key )
        MemberDetailMetaData:SetPropagateKeyboardInput ( true );
        if key == "ESCAPE" then
            MemberDetailMetaData:SetPropagateKeyboardInput ( false );
            if GR_AddonGlobals.pause then
                GR_AddonGlobals.pause = false;
            else
                MemberDetailMetaData:Hide();
            end
        end
    end);

    -- For Fontstring logic handling, particularly of the alts.
    MemberDetailMetaData:SetScript ( "OnMouseDown" , function ( _ , button ) 
        if button == "RightButton" then
            GR_AddonGlobals.selectedAlt = GRM.GetCoreFontStringClicked(); -- Setting to global the alt name chosen.
            if GR_AddonGlobals.selectedAlt[1] ~= nil then
                GR_AddonGlobals.pause = true;
                local cursorX , cursorY = GetCursorPosition();
                altDropDownOptions:ClearAllPoints();
                altDropDownOptions:SetPoint( "TOPLEFT" , UIParent , "BOTTOMLEFT" , cursorX , cursorY );

                altDropDownOptions:SetSize ( 65 , 92 );
                altDropDownOptions:Show();
                altOptionsText:SetText ( GRM.SlimName ( GR_AddonGlobals.selectedAlt[2] ) );

                if GR_AddonGlobals.selectedAlt[1] == GR_AddonGlobals.selectedAlt[2] then -- Not clicking an alt frame
                    if GRM_MemberDetailRankDateTxt:IsVisible() and GRM_MemberDetailRankDateTxt:IsMouseOver ( 2 , -2 , -2 , 2 ) then
                        GR_AddonGlobals.editPromoDate = true;
                        GR_AddonGlobals.editJoinDate = false;
                        GR_AddonGlobals.editFocusPlayer = false;
                    elseif GRM_JoinDateText:IsVisible() and GRM_JoinDateText:IsMouseOver ( 2 , -2 , -2 , 2 ) then
                        GR_AddonGlobals.editJoinDate = true;
                        GR_AddonGlobals.editPromoDate = false;
                        GR_AddonGlobals.editFocusPlayer = false;
                    elseif GRM_MemberDetailNameText:IsMouseOver ( 2 , -2 , -2 , 2 ) then
                        GR_AddonGlobals.editFocusPlayer = true;
                        GR_AddonGlobals.editJoinDate = false;
                        GR_AddonGlobals.editPromoDate = false;
                    end
                    GRM_MemberDetailRankToolTip:Hide();
                    GRM_MemberDetailJoinDateToolTip:Hide();
                    if GR_AddonGlobals.editFocusPlayer then
                        if GR_AddonGlobals.selectedAlt[4] ~= true then    -- player is not the main.
                            altSetMainButtonText:SetText ( "Set as Main" );
                        else -- player IS the main... place option to Demote From Main rahter than set as main.
                            altSetMainButtonText:SetText ( "Set as Alt" );
                        end
                        altRemoveButtonText:SetText ( "Reset Data!" );
                    else
                        altSetMainButtonText:SetText ( "Edit Date" );
                        altRemoveButtonText:SetText ( "Clear History" );
                    end
                else
                    if GR_AddonGlobals.selectedAlt[4] ~= true then    -- player is not the main.
                        altSetMainButtonText:SetText ( "Set as Main" );
                    else -- player IS the main... place option to Demote From Main rahter than set as main.
                        altSetMainButtonText:SetText ( "Set as Alt" );
                    end
                    altRemoveButtonText:SetText ( "Remove" );
                end
            end
        end
    end);

    -- Keyboard Control for easy ESC closeButtons
    tinsert( UISpecialFrames, "MemberDetailMetaData" );

    -- CORE FRAME CHILDREN FEATURES
    -- rank drop down 
    guildRankDropDownMenuSelected:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -50 );
    guildRankDropDownMenuSelected:SetSize (  135 , 22 );
    guildRankDropDownMenuSelected.RankText:SetPoint ( "CENTER" , guildRankDropDownMenuSelected );
    guildRankDropDownMenuSelected.RankText:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
    RankDropDownMenu:SetPoint ( "TOP" , guildRankDropDownMenuSelected , "BOTTOM" );
    RankDropDownMenu:SetWidth ( 135 );
    RankDropDownMenu:SetFrameStrata ( "HIGH" );

    RankDropDownMenuButton:SetPoint ( "RIGHT" , guildRankDropDownMenuSelected , 0 , -1 );
    RankDropDownMenuButton:SetSize ( 20 , 18 );

    RankDropDownMenu:SetScript ( "OnKeyDown" , function ( _ , key )
        RankDropDownMenu:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            RankDropDownMenu:SetPropagateKeyboardInput ( false );
            RankDropDownMenu:Hide();
            guildRankDropDownMenuSelected:Show();
        end
    end);

    guildRankDropDownMenuSelected:SetScript ( "OnShow" , function() 
        RankDropDownMenu:Hide();
    end)

    -- Day Dropdown
    DayDropDownButton:SetPoint ( "LEFT" , DayDropDownMenuSelected , "RIGHT" , -2 , 0 );
    DayDropDownButton:SetSize (20 , 20 );

    DayDropDownMenuSelected:SetSize ( 30 , 20 );
    DayDropDownMenu:SetPoint ( "TOP" , DayDropDownMenuSelected , "BOTTOM" );
    DayDropDownMenu:SetWidth ( 34 );
    DayDropDownMenu:SetFrameStrata ( "HIGH" );

    DayDropDownMenu:SetScript ( "OnKeyDown" , function ( _ , key )
        DayDropDownMenu:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            DayDropDownMenu:SetPropagateKeyboardInput ( false );
            DayDropDownMenu:Hide();
            DayDropDownMenuSelected:Show();
        end
    end);

    DayDropDownMenuSelected:SetScript ( "OnShow" , function()
        DayDropDownMenu:Hide();
    end);

    MonthDropDownMenuSelected:SetSize ( 83 , 20 );
    MonthDropDownMenu:SetPoint ( "TOP" , MonthDropDownMenuSelected , "BOTTOM" );
    MonthDropDownMenu:SetWidth ( 80 );
    MonthDropDownMenu:SetFrameStrata ( "HIGH" );
    
    MonthDropDownButton:SetPoint ( "LEFT" , MonthDropDownMenuSelected , "RIGHT" , -2 , 0 );
    MonthDropDownButton:SetSize (20 , 20 );

    MonthDropDownMenu:SetScript ( "OnKeyDown" , function ( _ , key )
        MonthDropDownMenu:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            MonthDropDownMenu:SetPropagateKeyboardInput ( false );
            MonthDropDownMenu:Hide();
            MonthDropDownMenuSelected:Show();
        end
    end);

    MonthDropDownMenuSelected:SetScript ( "OnShow" , function()
        MonthDropDownMenu:Hide();
    end);

    YearDropDownMenuSelected:SetSize ( 53 , 20 );
    YearDropDownMenu:SetPoint ( "TOP" , YearDropDownMenuSelected , "BOTTOM" );
    YearDropDownMenu:SetWidth ( 52 );
    YearDropDownMenu:SetFrameStrata ( "HIGH" );

    YearDropDownButton:SetPoint ( "LEFT" , YearDropDownMenuSelected , "RIGHT" , -2 , 0 );
    YearDropDownButton:SetSize (20 , 20 );

    YearDropDownMenu:SetScript ( "OnKeyDown" , function ( _ , key )
        YearDropDownMenu:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            YearDropDownMenu:SetPropagateKeyboardInput ( false );
            YearDropDownMenu:Hide();
            YearDropDownMenuSelected:Show();
        end
    end);

    YearDropDownMenuSelected:SetScript ( "OnShow" , function()
        YearDropDownMenu:Hide();
    end);

    --Rank Drop down submit and cancel
    GRM_SetPromoDateButton.GRM_SetPromoDateButtonText:SetPoint ( "CENTER" , GRM_SetPromoDateButton );
    GRM_SetPromoDateButton.GRM_SetPromoDateButtonText:SetText ( "Date Promoted?" );
    GRM_SetPromoDateButton.GRM_SetPromoDateButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    GRM_SetPromoDateButton:SetSize ( 90 , 18 );
    GRM_SetPromoDateButton:SetScript( "OnClick" , function( self , button , down ) 
        if button == "LeftButton" then
            GRM_SetPromoDateButton:Hide();
            GRM.SetDateSelectFrame ( "TOP" , MemberDetailMetaData , "PromoRank" );  -- Position, Frame, ButtonName
            GR_AddonGlobals.pause = true;
        end
    end);

    DateSubmitButton:SetWidth( 74 );
    DateSubmitCancelButton:SetWidth( 74 );
    DateSubmitCancelButtonTxt:SetPoint ( "CENTER" , DateSubmitCancelButton );
    DateSubmitCancelButtonTxt:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.9 );
    DateSubmitCancelButtonTxt:SetText ( "Cancel" );
    DateSubmitButtonTxt:SetPoint ( "CENTER" , DateSubmitButton );
    DateSubmitButtonTxt:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.9 );
    DateSubmitButton:SetScript ( "OnShow" , function()
        MemberDetailMetaData.MemberDetailMetaZoneInfoText:Hide();
        MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:Hide();
        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:Hide();
        MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:Hide();
    end);
    
    -- Name Text
    GRM_MemberDetailNameText:SetPoint( "TOP" , 0 , -20 );
    GRM_MemberDetailNameText:SetFont (  "Fonts\\FRIZQT__.TTF" , 16 );

    -- LEVEL Text
    GRM_MemberDetailLevel:SetPoint ( "TOP" , 0 , -38 );
    GRM_MemberDetailLevel:SetFont (  "Fonts\\FRIZQT__.TTF" , 10 );

    -- Rank promotion date text
    GRM_MemberDetailRankTxt:SetPoint ( "TOP" , 0 , -52 );
    GRM_MemberDetailRankTxt:SetFont (  "Fonts\\FRIZQT__.TTF" , 13 );
    GRM_MemberDetailRankTxt:SetTextColor ( 0.90 , 0.80 , 0.50 , 1.0 );

    -- "MEMBER SINCE"
    GRM_JoinDateText:SetPoint ( "TOPRIGHT" , MemberDetailMetaData , -21 , - 33 );
    GRM_JoinDateText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    GRM_JoinDateText:SetWidth ( 55 );
    GRM_JoinDateText:SetJustifyH ( "CENTER" );

    -- "LAST ONLINE" 
    GR_MemberDetailLastOnlineTitleTxt:SetPoint ( "TOPLEFT" , MemberDetailMetaData , 16 , -22 );
    GR_MemberDetailLastOnlineTitleTxt:SetText ( "Last Online" );
    GR_MemberDetailLastOnlineTitleTxt:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 , "THICKOUTLINE" );
    GR_MemberDetailLastOnlineTxt:SetPoint ( "TOPLEFT" , MemberDetailMetaData , 16 , -32 );
    GR_MemberDetailLastOnlineTxt:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    GR_MemberDetailLastOnlineTxt:SetWidth ( 65 );
    GR_MemberDetailLastOnlineTxt:SetJustifyH ( "CENTER" );
    
    -- PLAYER STATUS
    GRM_MemberDetailPlayerStatus:SetPoint ( "TOPLEFT" , MemberDetailMetaData , 23 , - 48 );
    GRM_MemberDetailPlayerStatus:SetWidth ( 50 );
    GRM_MemberDetailPlayerStatus:SetJustifyH ( "CENTER" );
    GRM_MemberDetailPlayerStatus:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );

    -- ZONE
    MemberDetailMetaData.MemberDetailMetaZoneInfoText:SetPoint ( "LEFT" , MemberDetailMetaData , 18 , 60 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 , "THICKOUTLINE" );
    MemberDetailMetaData.MemberDetailMetaZoneInfoText:SetText ( "Zone:" );
    MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetPoint ( "LEFT" , MemberDetailMetaData.MemberDetailMetaZoneInfoText , "RIGHT" , 2 , 0 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoZoneText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:SetPoint ( "TOP" , MemberDetailMetaData.MemberDetailMetaZoneInfoText , "BOTTOM" , 10 , -2 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1:SetText ( "Time In: " );
    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetPoint ( "LEFT" , MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText1 , "RIGHT" , 2 , 0 );
    MemberDetailMetaData.MemberDetailMetaZoneInfoTimeText2:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    
    -- Is Main Note!
    GRM_MemberDetailMainText:SetPoint ( "TOP" , MemberDetailMetaData , 0 , -12 );
    GRM_MemberDetailMainText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    GRM_MemberDetailMainText:SetText ( "( Main )" );
    GRM_MemberDetailMainText:SetTextColor ( 1.0 , 0.0 , 0.0 , 1.0 );

    -- Join Date Button Logic for visibility
    GR_MemberDetailDateJoinedTitleTxt:SetPoint ( "TOPRIGHT" , MemberDetailMetaData , -14 , -22 );
    GR_MemberDetailDateJoinedTitleTxt:SetText ( "Date Joined" );
    GR_MemberDetailDateJoinedTitleTxt:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 , "THICKOUTLINE" );
    GRM_MemberDetailJoinDateButton:SetPoint ( "TOPRIGHT" , MemberDetailMetaData , -19 , - 32 );
    GRM_MemberDetailJoinDateButton:SetSize ( 60 , 17 );
    GRM_MemberDetailJoinDateButtonText:SetPoint ( "CENTER" , GRM_MemberDetailJoinDateButton );
    GRM_MemberDetailJoinDateButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    GRM_MemberDetailJoinDateButtonText:SetText ( "Join Date?" )
    GRM_MemberDetailJoinDateButton:SetScript ( "OnClick" , function ( self , button , down )
        if button == "LeftButton" then
            GRM_MemberDetailJoinDateButton:Hide();
            if GRM_MemberDetailRankDateTxt:IsVisible() then
                GRM_MemberDetailRankDateTxt:Hide();
            elseif GRM_SetPromoDateButton:IsVisible() then
                GRM_SetPromoDateButton:Hide();
            end
            GRM.SetDateSelectFrame ( "TOP" , MemberDetailMetaData , "JoinDate" );  -- Position, Frame, ButtonName
            GR_AddonGlobals.pause = true;
        end
    end);

    -- GROUP INVITE BUTTON
    GRM_GroupInviteButton:SetPoint ( "BOTTOMLEFT" , MemberDetailMetaData , 16, 13 )
    GRM_GroupInviteButton:SetSize ( 88 , 19 );
    GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetPoint ( "CENTER" , GRM_GroupInviteButton );
    GRM_GroupInviteButton.GRM_GroupInviteButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
        
    -- REMOVE GUILDIE BUTTON
    GRM_RemoveGuildieButton:SetPoint ( "BOTTOMRIGHT" , MemberDetailMetaData , -15, 13 )
    GRM_RemoveGuildieButton:SetSize ( 88 , 19 );
    GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:SetPoint ( "CENTER" , GRM_RemoveGuildieButton );
    GRM_RemoveGuildieButton.GRM_RemoveGuildieButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );

    -- player note edit box and font string (31 characters)
    GRM_MemberDetailNoteTitle:SetPoint ( "LEFT" , MemberDetailMetaData , 21 , 32 );
    GRM_MemberDetailNoteTitle:SetText ( "Note:" );
    GRM_MemberDetailNoteTitle:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );

    GRM_MemberDetailONoteTitle:SetPoint ( "RIGHT" , MemberDetailMetaData , -70 , 32 );
    GRM_MemberDetailONoteTitle:SetText ( "Officer's Note:" );
    GRM_MemberDetailONoteTitle:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );

    -- OFFICER AND PLAYER NOTES
    GRM_PlayerNoteWindow:SetPoint( "LEFT" , MemberDetailMetaData , 15 , 10 );
    GRM_noteFontString1:SetPoint ( "TOPLEFT" , GRM_PlayerNoteWindow , 9 , -11 );
    GRM_noteFontString1:SetWordWrap ( true );
    GRM_noteFontString1:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    GRM_noteFontString1:SetSpacing ( 1 );
    GRM_noteFontString1:SetWidth ( 108 );
    GRM_noteFontString1:SetJustifyH ( "LEFT" );

    GRM_PlayerNoteWindow:SetBackdrop ( noteBackdrop );
    GRM_PlayerNoteWindow:SetSize ( 125 , 40 );
    
    GRM_PlayerNoteEditBox:SetPoint( "LEFT" , MemberDetailMetaData , 15 , 10 );
    GRM_PlayerNoteEditBox:SetSize ( 125 , 45 );
    GRM_PlayerNoteEditBox:SetTextInsets( 8 , 9 , 9 , 8 );
    GRM_PlayerNoteEditBox:SetMaxLetters ( 31 );
    GRM_PlayerNoteEditBox:SetMultiLine( true );
    GRM_PlayerNoteEditBox:SetSpacing ( 1 );
    GRM_PlayerNoteEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 9 );
    GRM_PlayerNoteEditBox:EnableMouse( true );
    GRM_PlayerNoteEditBox:SetFrameStrata ( "HIGH" );
    GRM_NoteCount:SetPoint ("TOPRIGHT" , GRM_PlayerNoteWindow , -6 , 8 );
    GRM_NoteCount:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );

    -- Officer Note
    GRM_PlayerOfficerNoteWindow:SetPoint( "RIGHT" , MemberDetailMetaData , -15 , 10 );
    GRM_noteFontString2:SetPoint ( "TOPLEFT" , GRM_PlayerOfficerNoteWindow , 9 , -11 );
    GRM_noteFontString2:SetWordWrap ( true );
    GRM_noteFontString2:SetSpacing ( 1 );
    GRM_noteFontString2:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    GRM_noteFontString2:SetWidth ( 108 );
    GRM_noteFontString2:SetJustifyH ( "LEFT" );

    GRM_PlayerOfficerNoteWindow:SetBackdrop ( noteBackdrop );
    GRM_PlayerOfficerNoteWindow:SetSize ( 125 , 40 );
    
    GRM_PlayerOfficerNoteEditBox:SetPoint( "RIGHT" , MemberDetailMetaData , -15 , 10 );
    GRM_PlayerOfficerNoteEditBox:SetSize ( 125 , 45 );
    GRM_PlayerOfficerNoteEditBox:SetTextInsets( 8 , 9 , 9 , 8 );
    GRM_PlayerOfficerNoteEditBox:SetMaxLetters ( 31 );
    GRM_PlayerOfficerNoteEditBox:SetMultiLine( true );
    GRM_PlayerOfficerNoteEditBox:SetSpacing ( 1 );
    GRM_PlayerOfficerNoteEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 9 );
    GRM_PlayerOfficerNoteEditBox:EnableMouse( true );
    GRM_PlayerOfficerNoteEditBox:SetFrameStrata ( "HIGH" );
    
    -- Script handlers on Note Edit Boxes
    local defNotes = {};
    defNotes.defaultNote = "Click here to set a Public Note";
    defNotes.defaultONote = "Click here to set an Officer's Note";
    defNotes.tempNote = "";
    defNotes.finalNote = "";

    -- Script handlers on Note Frames
    GRM_PlayerNoteWindow:SetScript ( "OnMouseDown" , function ( self , button ) 
        if button == "LeftButton" and CanEditPublicNote() then 
            GRM_NoteCount:SetPoint ("TOPRIGHT" , GRM_PlayerNoteWindow , -6 , 8 );
            GR_AddonGlobals.pause = true;
            GRM_noteFontString1:Hide();
            GRM_PlayerOfficerNoteEditBox:Hide();
            GRM_NoteCount:Hide();
            defNotes.tempNote = GRM_noteFontString2:GetText();
            if defNotes.tempNote ~= defNotes.defaultONote and defNotes.tempNote ~= "" then
                defNotes.finalNote = defNotes.tempNote;
            else
                defNotes.finalNote = "";
            end
            GRM_PlayerOfficerNoteEditBox:SetText( defNotes.finalNote );
            GRM_noteFontString2:Show();

            GRM_NoteCount:SetText( #GRM_PlayerNoteEditBox:GetText() .. "/31");
            GRM_PlayerNoteEditBox:Show();
            GRM_NoteCount:Show();
        end 
    end);

    GRM_PlayerOfficerNoteWindow:SetScript ( "OnMouseDown" , function ( self , button ) 
        if button == "LeftButton" and CanEditOfficerNote() then
            GRM_NoteCount:SetPoint ("TOPRIGHT" , GRM_PlayerOfficerNoteWindow , -6 , 8 );
            GR_AddonGlobals.pause = true;
            GRM_noteFontString2:Hide();
            GRM_PlayerNoteEditBox:Hide();
            defNotes.tempNote = GRM_noteFontString1:GetText();
            if defNotes.tempNote ~= defNotes.defaultNote and defNotes.tempNote ~= "" then
                defNotes.finalNote = defNotes.tempNote;
            else
                defNotes.finalNote = "";
            end
            GRM_PlayerNoteEditBox:SetText( defNotes.finalNote );
            GRM_noteFontString1:Show();

             -- How many characters initially
            GRM_NoteCount:SetText( #GRM_PlayerOfficerNoteEditBox:GetText() .. "/31" );
            GRM_PlayerOfficerNoteEditBox:Show();
            GRM_NoteCount:Show();
        end 
    end);

    -- Cancels editing in Note editbox
    GRM_PlayerNoteEditBox:SetScript ( "OnEscapePressed" , function ( self ) 
        GRM_PlayerNoteEditBox:Hide();
        GRM_NoteCount:Hide();
        defNotes.tempNote = GRM_noteFontString1:GetText();
        if defNotes.tempNote ~= defNotes.defaultNote and defNotes.tempNote ~= "" then
            defNotes.finalNote = defNotes.tempNote;
        else
            defNotes.finalNote = "";
        end
        GRM_PlayerNoteEditBox:SetText ( defNotes.finalNote );
        GRM_noteFontString1:Show();
        if DateSubmitButton:IsVisible() ~= true then            -- Does not unpause if the date still needs to be selected or canceled.
            GR_AddonGlobals.pause = false;
        end
    end);

    -- Updates char count as player types.
    GRM_PlayerNoteEditBox:SetScript ( "OnChar" , function ( self , text ) 
        local charCount = #GRM_PlayerNoteEditBox:GetText();
        charCount = charCount;
        GRM_NoteCount:SetText ( charCount .. "/31" );
    end);

    -- Update on backspace changes too
    GRM_PlayerNoteEditBox:SetScript ( "OnKeyDown" , function ( self , text )  -- While technically this one script handler could do all, this is more processor efficient to have 2.
        if text == "BACKSPACE" then
            local charCount = #GRM_PlayerNoteEditBox:GetText();
            charCount = charCount - 1;
            if charCount == -1 then
                charCount = 0;
            end
            GRM_NoteCount:SetText ( charCount .. "/31");
        end
    end);

    -- Updating the new information to Public Note
    GRM_PlayerNoteEditBox:SetScript ( "OnEnterPressed" , function ( self ) 
        local playerDetails = {};
        playerDetails.newNote = GRM_PlayerNoteEditBox:GetText();
        playerDetails.name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );
        
        for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerDetails.name then         -- Player Found and Located.
                -- -- First, let's add the change to the official server-sde note
                for h = 1 , GRM.GetNumGuildies() do
                    local playerName ,_,_,_,_,_, publicNote = GetGuildRosterInfo( h );
                    if playerName == playerDetails.name and publicNote ~= playerDetails.newNote and CanEditPublicNote() then      -- No need to update old note if it is the same.
                        GuildRosterSetPublicNote ( h , playerDetails.newNote );
                        -- To metadata save
                        GRM.RecordChanges ( 5 , { playerDetails.name , nil , nil , nil , playerDetails.newNote } , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j] , GR_AddonGlobals.guildName );
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][7] = playerDetails.newNote;
                        if #playerDetails.newNote == 0 then
                            GRM_noteFontString1:SetText ( defNotes.defaultNote );
                        else
                            GRM_noteFontString1:SetText ( playerDetails.newNote );
                        end
                        GRM_PlayerNoteEditBox:SetText( playerDetails.newNote );
                        break;
                    end
                end
                break;
            end
        end

        GRM_PlayerNoteEditBox:Hide();
        GRM_NoteCount:Hide();
        GRM_noteFontString1:Show();
        if DateSubmitButton:IsVisible() ~= true then            -- Does not unpause if the date still needs to be selected or canceled.
            GR_AddonGlobals.pause = false;
        end
    end);

    GRM_PlayerOfficerNoteEditBox:SetScript ( "OnEscapePressed" , function ( self ) 
        GRM_PlayerOfficerNoteEditBox:Hide();
        GRM_NoteCount:Hide();
        defNotes.tempNote = GRM_noteFontString2:GetText();
        if defNotes.tempNote ~= defNotes.defaultONote and defNotes.tempNote ~= "" then
            defNotes.finalNote = defNotes.tempNote;
        else
            defNotes.finalNote = "";
        end
        GRM_PlayerOfficerNoteEditBox:SetText( defNotes.finalNote );
        GRM_noteFontString2:Show();
        if DateSubmitButton:IsVisible() ~= true then            -- Does not unpause if the date still needs to be selected or canceled.
            GR_AddonGlobals.pause = false;
        end
    end);

    -- Updates char count as player types.
    GRM_PlayerOfficerNoteEditBox:SetScript ( "OnChar" , function ( self , text ) 
        local charCount = #GRM_PlayerOfficerNoteEditBox:GetText();
        charCount = charCount;
        GRM_NoteCount:SetText( charCount .. "/31" );
    end);

    -- Update on backspace changes too
    GRM_PlayerOfficerNoteEditBox:SetScript ( "OnKeyDown" , function ( self , text )  -- While technically this one script handler could do all, this is more processor efficient to have 2.
        if text == "BACKSPACE" then
            local charCount = #GRM_PlayerOfficerNoteEditBox:GetText();
            charCount = charCount - 1;
            if charCount == -1 then
                charCount = 0;
            end
            GRM_NoteCount:SetText( charCount .. "/31" );
        end
    end);

     -- Updating the new information to Public Note
    GRM_PlayerOfficerNoteEditBox:SetScript ( "OnEnterPressed" , function ( self ) 
        local playerDetails = {};
        playerDetails.newNote = GRM_PlayerOfficerNoteEditBox:GetText();
        playerDetails.name = GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() );
        
        for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
            if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == playerDetails.name then         -- Player Found and Located.
                -- -- First, let's add the change to the official server-sde note
                for h = 1 , GRM.GetNumGuildies() do
                    local playerName ,_,_,_,_,_,_, officerNote = GetGuildRosterInfo( h );
                    if playerName == playerDetails.name and officerNote ~= playerDetails.newNote and CanEditOfficerNote() then      -- No need to update old note if it is the same.
                        GuildRosterSetOfficerNote ( h , playerDetails.newNote );
                        -- To metadata save
                        GRM.RecordChanges ( 6 , { playerDetails.name , nil , nil , nil , nil , playerDetails.newNote } , GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j] , GR_AddonGlobals.guildName );
                        GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][8] = playerDetails.newNote;
                        if #playerDetails.newNote == 0 then
                            GRM_noteFontString2:SetText ( defNotes.defaultONote );
                        else
                            GRM_noteFontString2:SetText ( playerDetails.newNote );
                        end
                        GRM_PlayerOfficerNoteEditBox:SetText( playerDetails.newNote );
                        break;
                    end
                end
                break;
            end
        end

        GRM_PlayerOfficerNoteEditBox:Hide();
        GRM_NoteCount:Hide();
        GRM_noteFontString2:Show();
        if DateSubmitButton:IsVisible() ~= true then            -- Does not unpause if the date still needs to be selected or canceled.
            GR_AddonGlobals.pause = false;
        end
    end);
    
end

-- Method:                  GR_MetaDataInitializeUISecond()
-- What it Does:            Initializes "More of the frames values/scripts"
-- Purpose:                 Can only have 60 "up-values" in one function. This splits it up.
GRM.GR_MetaDataInitializeUISecond = function()

    -- CUSTOM POPUP
    GR_PopupWindow:SetPoint ( "CENTER" , UIParent );
    GR_PopupWindow:SetSize ( 240 , 120 );
    GR_PopupWindow:SetFrameStrata ( "HIGH" );
    GR_PopupWindow:EnableKeyboard ( true );
    GR_PopupWindow:SetToplevel ( true );
    GR_PopupWindowButton1:SetPoint ( "BOTTOMLEFT" , GR_PopupWindow , 15 , 14 );
    GR_PopupWindowButton1:SetSize ( 75 , 25 );
    GR_PopupWindowButton1.GR_PopupWindowButton1Text:SetPoint ( "CENTER" , GR_PopupWindowButton1 );
    GR_PopupWindowButton1.GR_PopupWindowButton1Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    GR_PopupWindowButton1.GR_PopupWindowButton1Text:SetText ( "YES" );
    GR_PopupWindowButton2:SetPoint ( "BOTTOMRIGHT" , GR_PopupWindow , -15 , 14 );
    GR_PopupWindowButton2:SetSize ( 75 , 25 );
    GR_PopupWindowButton2.GR_PopupWindowButton2Text:SetPoint ( "CENTER" , GR_PopupWindowButton2 );
    GR_PopupWindowButton2.GR_PopupWindowButton2Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    GR_PopupWindowButton2.GR_PopupWindowButton2Text:SetText ( "CANCEL" );
    GR_PopupWindowConfirmText:SetPoint ( "TOP" , GR_PopupWindow , 0 , -17.5 );
    GR_PopupWindowConfirmText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    GR_PopupWindowConfirmText:SetWidth ( 185 );
    GR_PopupWindowConfirmText:SetJustifyH ( "CENTER" );
    GR_PopupWindowCheckButton1:SetPoint ( "BOTTOMLEFT" , GR_PopupWindow , 15 , 55 );
    GR_PopupWindowCheckButtonText:SetPoint ( "RIGHT" , GR_PopupWindowCheckButton1 , 54 , 0 );
    GR_PopupWindowCheckButton2:SetPoint ( "BOTTOMLEFT" , GR_PopupWindow , 15 , 35 );
    GR_PopupWindowCheckButton2Text:SetPoint ( "RIGHT" , GR_PopupWindowCheckButton2 , 70 , 0 );

    GR_PopupWindowCheckButton1:HookScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            if GR_PopupWindowCheckButton1:GetChecked() ~= true then
                GR_MemberDetailEditBoxFrame:Hide();                 -- If editframe is up, and you uncheck the box, it hides the editbox too
                GR_PopupWindowCheckButton2Text:ClearAllPoints();
                GR_PopupWindowCheckButton2Text:SetPoint ( "RIGHT" , GR_PopupWindowCheckButton2 , 70 , 0 );
                GR_PopupWindowCheckButton2Text:SetTextColor ( 1.0 , 1.0 , 1.0 , 1.0 );
                GR_PopupWindowCheckButton2Text:SetText ( "Kick Alts Too!" );
                
            else
                GR_PopupWindowCheckButton2Text:ClearAllPoints();
                GR_PopupWindowCheckButton2Text:SetPoint ( "RIGHT" , GR_PopupWindowCheckButton2 , 112 , 0 );
                GR_PopupWindowCheckButton2Text:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
                GR_PopupWindowCheckButton2Text:SetText ( "Kick and Ban Alts too!" );
            end
        end
    end);

    -- Popup logic
    GR_PopupWindowButton2:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            GR_PopupWindow:Hide();
        end
    end);

    -- Backup logic with Escape key
    GR_PopupWindow:SetScript ( "OnKeyDown" , function ( _ , key )
        GR_PopupWindow:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            GR_PopupWindow:SetPropagateKeyboardInput ( false );
            GR_PopupWindow:Hide();
        end
    end);

    GR_PopupWindow:HookScript ( "OnHide" , function ( self ) 
        GR_PopupWindowCheckButton2Text:SetPoint ( "RIGHT" , GR_PopupWindowCheckButton2 , 70 , 0 );  -- Reset Position
    end);

    -- Popup EDIT BOX
    GR_MemberDetailEditBoxFrame:SetPoint ( "TOP" , GR_PopupWindow , "BOTTOM" , 0 , 2 );
    GR_MemberDetailEditBoxFrame:SetSize ( 240 , 45 );

    MemberDetailPopupEditBox:SetPoint( "CENTER" , GR_MemberDetailEditBoxFrame , 0 , 0 );
    MemberDetailPopupEditBox:SetSize ( 210 , 25 );
    MemberDetailPopupEditBox:SetTextInsets( 2 , 3 , 3 , 2 );
    MemberDetailPopupEditBox:SetMaxLetters ( 155 );
    MemberDetailPopupEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 9 );
    MemberDetailPopupEditBox:SetFrameStrata ( "HIGH" );
    MemberDetailPopupEditBox:EnableMouse( true );

    -- Script handler for General popup editbox.
    MemberDetailPopupEditBox:SetScript ( "OnEscapePressed" , function ( self )
        GR_MemberDetailEditBoxFrame:Hide();
    end);

    -- Heads-up text if player was previously banned
    GR_MemberDetailBannedText1:SetPoint ( "CENTER" , MemberDetailMetaData , -65 , -45.5 );
    GR_MemberDetailBannedText1:SetWordWrap ( true );
    GR_MemberDetailBannedText1:SetJustifyH ( "CENTER" );
    GR_MemberDetailBannedText1:SetTextColor ( 1.0 , 0.0 , 0.0 , 1.0 );
    GR_MemberDetailBannedText1:SetFont( "Fonts\\FRIZQT__.TTF" , 8.0 );
    GR_MemberDetailBannedText1:SetWidth ( 120 );
    GR_MemberDetailBannedText1:SetText ( "WARNING! WARNING!\nRejoining player was previously banned!" );
    GR_MemberDetailBannedIgnoreButton:SetPoint ( "CENTER" , MemberDetailMetaData , -65 , -70.5 );
    GR_MemberDetailBannedIgnoreButton:SetWidth ( 85 );
    GR_MemberDetailBannedIgnoreButton:SetHeight ( 19 );
    GR_MemberDetailBannedIgnoreButton:SetText ( "Ignore Ban" );
    
    -- ALT FRAME DETAILS!!!
    GR_CoreAltFrame:SetPoint ( "BOTTOMRIGHT" , MemberDetailMetaData , -13.5 , 16 );
    GR_CoreAltFrame:SetSize ( 128 , 140 );
    GR_CoreAltFrame:SetParent ( MemberDetailMetaData );
    altFrameTitleText:SetPoint ( "TOP" , GR_CoreAltFrame , 3 , -4 );
    altFrameTitleText:SetText ( "Player Alts" );    
    altFrameTitleText:SetFont ( "Fonts\\FRIZQT__.TTF" , 11 , "THICKOUTLINE" );

    AddAltButton:SetSize ( 60 , 17 );
    AddAltButtonText:SetPoint ( "CENTER" , AddAltButton );
    AddAltButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltButtonText:SetText( "Add Alt") ; 

    GR_AltName1:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -20 );
    GR_AltName1:SetWidth ( 60 );
    GR_AltName1:SetJustifyH ( "CENTER" );
    GR_AltName1:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName2:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -20 );
    GR_AltName2:SetWidth ( 60 );
    GR_AltName2:SetJustifyH ( "CENTER" );
    GR_AltName2:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName3:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -37 );
    GR_AltName3:SetWidth ( 60 );
    GR_AltName3:SetJustifyH ( "CENTER" );
    GR_AltName3:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName4:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -37 );
    GR_AltName4:SetWidth ( 60 );
    GR_AltName4:SetJustifyH ( "CENTER" );
    GR_AltName4:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName5:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -54 );
    GR_AltName5:SetWidth ( 60 );
    GR_AltName5:SetJustifyH ( "CENTER" );
    GR_AltName5:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName6:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -54 );
    GR_AltName6:SetWidth ( 60 );
    GR_AltName6:SetJustifyH ( "CENTER" );
    GR_AltName6:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName7:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -71 );
    GR_AltName7:SetWidth ( 60 );
    GR_AltName7:SetJustifyH ( "CENTER" );
    GR_AltName7:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName8:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -71 );
    GR_AltName8:SetWidth ( 60 );
    GR_AltName8:SetJustifyH ( "CENTER" );
    GR_AltName8:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName9:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -88 );
    GR_AltName9:SetWidth ( 60 );
    GR_AltName9:SetJustifyH ( "CENTER" );
    GR_AltName9:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName10:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -88 );
    GR_AltName10:SetWidth ( 60 );
    GR_AltName10:SetJustifyH ( "CENTER" );
    GR_AltName10:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName11:SetPoint ( "TOPLEFT" , GR_CoreAltFrame , 1 , -105 );
    GR_AltName11:SetWidth ( 60 );
    GR_AltName11:SetJustifyH ( "CENTER" );
    GR_AltName11:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    GR_AltName12:SetPoint ( "TOPRIGHT" , GR_CoreAltFrame , 0 , -105 );
    GR_AltName12:SetWidth ( 60 );
    GR_AltName12:SetJustifyH ( "CENTER" );
    GR_AltName12:SetFont ( "Fonts\\FRIZQT__.TTF" , 7.5 );

    -- ALT DROPDOWN OPTIONS
    altDropDownOptions:SetPoint ( "BOTTOMRIGHT" , MemberDetailMetaData , 15 , 0 );
    altDropDownOptions:SetSize ( 65 , 92 );
    altDropDownOptions:SetBackdrop ( noteBackdrop2 );
    altDropDownOptions:SetFrameStrata ( "FULLSCREEN_DIALOG" );
    altOptionsText:SetPoint ( "TOPLEFT" , altDropDownOptions , 7 , -13 );
    altOptionsText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    altOptionsText:SetText ( "Options" );
    altSetMainButton:SetPoint ("TOPLEFT" , altDropDownOptions , 7 , -22 );
    altSetMainButton:SetSize ( 60 , 20 );
    altSetMainButton:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    altSetMainButtonText:SetPoint ( "LEFT" , altSetMainButton );
    altSetMainButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    altRemoveButton:SetPoint ( "TOPLEFT" , altDropDownOptions , 7 , -36 );
    altRemoveButton:SetSize ( 60 , 20 );
    altRemoveButton:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    altRemoveButtonText:SetPoint ( "LEFT" , altRemoveButton );
    altRemoveButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    altRemoveButtonText:SetText( "Remove" );
    altOptionsDividerText:SetPoint ( "TOPLEFT" , altDropDownOptions , 7 , -55 );
    altOptionsDividerText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    altOptionsDividerText:SetText ("__");
    altFrameCancelButton:SetPoint ( "TOPLEFT" , altDropDownOptions , 7 , -65 );
    altFrameCancelButton:SetSize ( 60 , 20 );
    altFrameCancelButton:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    altFrameCancelButtonText:SetPoint ( "LEFT" , altFrameCancelButton );
    altFrameCancelButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    altFrameCancelButtonText:SetText ( "Cancel" );

end

-- Method:                  GR_MetaDataInitializeUIThird()
-- What it Does:            Initializes "More of the frames values/scripts"
-- Purpose:                 Can only have 60 "up-values" in one function. This splits it up.
GRM.GR_MetaDataInitializeUIThird = function()

    --ADD ALT FRAME
    AddAltEditFrame:SetPoint ( "BOTTOMLEFT" , MemberDetailMetaData , "BOTTOMRIGHT" ,  -7 , 0 );
    AddAltEditFrame:SetSize ( 130 + ( #GR_AddonGlobals.realmName * 3.5 ) , 170 );                -- Slightly wider for larger guild names.
    AddAltEditFrame:SetToplevel ( true );
    AddAltTitleText:SetPoint ( "TOP" , AddAltEditFrame , 0 , - 20 );
    AddAltTitleText:SetFont ( "Fonts\\FRIZQT__.TTF" , 11 , "THICKOUTLINE" );
    AddAltTitleText:SetText ( "Choose Alt" );
    AddAltNameButton1:SetPoint ( "TOP" , AddAltEditFrame , 7 , -54 );
    AddAltNameButton1:SetSize ( 100 , 15 );
    AddAltNameButton1:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton1:Disable();
    AddAltNameButton1Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton1Text:SetPoint ( "LEFT" , AddAltNameButton1 );
    AddAltNameButton1Text:SetJustifyH ( "LEFT" );
    AddAltNameButton2:SetPoint ( "TOP" , AddAltEditFrame , 7 , -69 );
    AddAltNameButton2:SetSize ( 100 , 15 );
    AddAltNameButton2:Disable();
    AddAltNameButton2:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton2Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton2Text:SetPoint ( "LEFT" , AddAltNameButton2 );
    AddAltNameButton2Text:SetJustifyH ( "LEFT" );
    AddAltNameButton3:SetPoint ( "TOP" , AddAltEditFrame , 7 , -84 );
    AddAltNameButton3:SetSize ( 100 , 15 );
    AddAltNameButton3:Disable();
    AddAltNameButton3:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton3Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton3Text:SetPoint ( "LEFT" , AddAltNameButton3 );
    AddAltNameButton3Text:SetJustifyH ( "LEFT" );
    AddAltNameButton4:SetPoint ( "TOP" , AddAltEditFrame , 7 , -99 );
    AddAltNameButton4:SetSize ( 100 , 15 );
    AddAltNameButton4:Disable();
    AddAltNameButton4:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton4Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton4Text:SetPoint ( "LEFT" , AddAltNameButton4 );
    AddAltNameButton4Text:SetJustifyH ( "LEFT" );
    AddAltNameButton5:SetPoint ( "TOP" , AddAltEditFrame , 7 , -114 );
    AddAltNameButton5:SetSize ( 100 , 15 );
    AddAltNameButton5:Disable();
    AddAltNameButton5:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton5Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton5Text:SetPoint ( "LEFT" , AddAltNameButton5 );
    AddAltNameButton5Text:SetJustifyH ( "LEFT" );
    AddAltNameButton6:SetPoint ( "TOP" , AddAltEditFrame , 7 , -129 );
    AddAltNameButton6:SetSize ( 100 , 15 );
    AddAltNameButton6:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );
    AddAltNameButton6:Disable();
    AddAltNameButton6Text:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltNameButton6Text:SetPoint ( "LEFT" , AddAltNameButton6 );
    AddAltNameButton6Text:SetJustifyH ( "LEFT" );
    AddAltEditFrameTextBottom:SetPoint ( "TOP" , AddAltEditFrame , -18 , -146 );
    AddAltEditFrameTextBottom:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltEditFrameTextBottom:SetTextColor ( 0.5 , 0.5 , 0.5 , 1.0 );
    AddAltEditFrameTextBottom:SetText ( "(Press Tab)" );
    AddAltEditFrameHelpText:SetPoint ( "CENTER" , AddAltEditFrame )
    AddAltEditFrameHelpText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltEditFrameHelpText:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    
    AddAltEditBox:SetPoint( "TOP" , AddAltEditFrame , 2.5 , -30 );
    AddAltEditBox:SetSize ( 95 + ( #GR_AddonGlobals.realmName * 3.5 ) , 25 );
    AddAltEditBox:SetTextInsets( 2 , 3 , 3 , 2 );
    AddAltEditBox:SetMaxLetters ( 35 );
    AddAltEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 8 );
    AddAltEditBox:EnableMouse( true );
    AddAltEditBox:SetAutoFocus( false );

    -- ALT EDIT BOX LOGIC
    AddAltButton:SetScript ( "OnClick" , function ( _ , button) 
        if button == "LeftButton" then
            GR_AddonGlobals.pause = true;
            AddAltEditBox:SetAutoFocus( true );
            AddAltEditBox:SetText( "" );
            GRM.AddAltAutoComplete();
            AddAltEditFrame:Show();
            AddAltEditBox:SetAutoFocus( false );
            
        end
    end)


    AddAltEditBox:SetScript ( "OnEscapePressed" , function( _ )
        AddAltEditBox:ClearFocus();    
    end);

    AddAltEditBox:SetScript ( "OnEnterPressed" , function( _ )
        if AddAltEditBox:HasFocus() then
            local currentText = AddAltEditBox:GetText();
            if AddAltEditFrameHelpText:IsVisible() and AddAltEditFrameHelpText:GetText() == "Player Not Found" then
                print ("Please choose a VALID character, in guild, to set as an alt.");
            else
                if currentText ~= nil and currentText ~= "" then
                    local notFound = true;
                    if GR_AddonGlobals.currentHighlightIndex == 1 and AddAltNameButton1Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton1Text:GetText() );
                        notFound = false;
                    elseif notFound and GR_AddonGlobals.currentHighlightIndex == 2 and AddAltNameButton2Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton2Text:GetText() );
                        notFound = false;
                    elseif notFound and GR_AddonGlobals.currentHighlightIndex == 3 and AddAltNameButton3Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton3Text:GetText() );
                        notFound = false;
                    elseif notFound and GR_AddonGlobals.currentHighlightIndex == 4 and AddAltNameButton4Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton4Text:GetText() );
                        notFound = false;
                    elseif notFound and GR_AddonGlobals.currentHighlightIndex == 5 and AddAltNameButton5Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton5Text:GetText() );
                        notFound = false;
                    elseif notFound and GR_AddonGlobals.currentHighlightIndex == 6 and AddAltNameButton6Text:GetText() ~= currentText then
                        AddAltEditBox:SetText ( AddAltNameButton6Text:GetText() );
                        notFound = false;
                    end

                    if notFound then
                        -- Add the alt here, Hide the frame
                        GRM.AddAlt ( GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) , AddAltEditBox:GetText() , GR_AddonGlobals.guildName );

                        -- Communicate the changes!
                        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
                            GRMsync.SendMessage ( "GRM_ADDALT" , GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) .. "?" .. AddAltEditBox:GetText() , "GUILD");
                        end

                        AddAltEditBox:ClearFocus();
                        AddAltEditFrame:Hide();
                    end
                else
                    print ( "Please choose a character to set as alt." );
                end
            end
        end
    end);

    AddAltNameButton1:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton1Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);
    AddAltNameButton2:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton2Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);
    AddAltNameButton3:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton3Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);
    AddAltNameButton4:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton4Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);
    AddAltNameButton5:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton5Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);
    AddAltNameButton6:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            AddAltEditBox:SetText ( AddAltNameButton6Text:GetText() );
            GRM.AddAltAutoComplete();
        end
    end);

    -- Updating with each character typed
    AddAltEditBox:SetScript ( "OnChar" , function ( _ , text ) 
        GRM.AddAltAutoComplete();
    end);

    -- When pressing backspace.
    AddAltEditBox:SetScript ( "OnKeyDown" , function ( _ , key)
        if key == "BACKSPACE" then
            local text = AddAltEditBox:GetText();
            if text ~= nil and #text > 0 then
                AddAltEditBox:SetText ( string.sub ( text , 0 , #text - 1 ) ); -- Bring it down by 1 for function, then return to normal.
            end
            GRM.AddAltAutoComplete();
            AddAltEditBox:SetText( text ); -- set back to normal for normal Backspace upkey function... if I do not do this, it will delete 2 characters.
        end
    end);

    AddAltEditBox:SetScript ( "OnTabPressed" , function ( _ )
        local notSet = true;
        if IsShiftKeyDown() ~= true then
            if GR_AddonGlobals.currentHighlightIndex == 1 and notSet then
                if AddAltNameButton2:IsVisible() then
                    GR_AddonGlobals.currentHighlightIndex = 2;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton2:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 2 and notSet then
                if AddAltNameButton3:IsVisible() then
                    GR_AddonGlobals.currentHighlightIndex = 3;
                    AddAltNameButton2:UnlockHighlight();
                    AddAltNameButton3:LockHighlight();
                    notSet = false;
                else
                    GR_AddonGlobals.currentHighlightIndex = 1;
                    AddAltNameButton2:UnlockHighlight();
                    AddAltNameButton1:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 3 and notSet then
                if AddAltNameButton4:IsVisible() then
                    GR_AddonGlobals.currentHighlightIndex = 4;
                    AddAltNameButton3:UnlockHighlight();
                    AddAltNameButton4:LockHighlight();
                    notSet = false;
                else
                    GR_AddonGlobals.currentHighlightIndex = 1;
                    AddAltNameButton3:UnlockHighlight();
                    AddAltNameButton1:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 4 and notSet then
                if  AddAltNameButton5:IsVisible() then
                    GR_AddonGlobals.currentHighlightIndex = 5;
                    AddAltNameButton4:UnlockHighlight();
                    AddAltNameButton5:LockHighlight();
                    notSet = false;
                else
                    GR_AddonGlobals.currentHighlightIndex = 1;
                    AddAltNameButton4:UnlockHighlight();
                    AddAltNameButton1:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 5 and notSet then
                if AddAltNameButton6:IsVisible() and AddAltNameButton6Text:GetText() ~= "..." then
                    GR_AddonGlobals.currentHighlightIndex = 6;
                    AddAltNameButton5:UnlockHighlight();
                    AddAltNameButton6:LockHighlight();
                    notSet = false;
                elseif ( AddAltNameButton6:IsVisible() and AddAltNameButton6Text:GetText() == "..." ) or AddAltNameButton6:IsVisible() ~= true then
                    GR_AddonGlobals.currentHighlightIndex = 1;
                    AddAltNameButton5:UnlockHighlight();
                    AddAltNameButton1:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 6 then
                GR_AddonGlobals.currentHighlightIndex = 1;
                AddAltNameButton6:UnlockHighlight();
                AddAltNameButton1:LockHighlight();
                notSet = false;
            end
        else
            -- if at position 1... shift-tab goes back to any position.
            if GR_AddonGlobals.currentHighlightIndex == 1 and notSet then
                if AddAltNameButton6:IsVisible() and AddAltNameButton6Text:GetText() ~= "..."  and notSet then
                    GR_AddonGlobals.currentHighlightIndex = 6;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton6:LockHighlight();
                    notSet = false;
                elseif ( ( AddAltNameButton6:IsVisible() and AddAltNameButton6Text:GetText() == "..." ) or ( AddAltNameButton5:IsVisible() ) ) and notSet then
                    GR_AddonGlobals.currentHighlightIndex = 5;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton5:LockHighlight();
                    notSet = false;
                elseif AddAltNameButton4:IsVisible() and notSet then
                    GR_AddonGlobals.currentHighlightIndex = 4;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton4:LockHighlight();
                    notSet = false;
                elseif AddAltNameButton3:IsVisible() and notSet then
                    GR_AddonGlobals.currentHighlightIndex = 3;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton3:LockHighlight();
                    notSet = false;
                elseif AddAltNameButton2:IsVisible() and notSet then
                    GR_AddonGlobals.currentHighlightIndex = 2;
                    AddAltNameButton1:UnlockHighlight();
                    AddAltNameButton2:LockHighlight();
                    notSet = false;
                end
            elseif GR_AddonGlobals.currentHighlightIndex == 2 and notSet then
                GR_AddonGlobals.currentHighlightIndex = 1;
                AddAltNameButton2:UnlockHighlight();
                AddAltNameButton1:LockHighlight();
                notSet = false;
            elseif GR_AddonGlobals.currentHighlightIndex == 3 and notSet then
                GR_AddonGlobals.currentHighlightIndex = 2;
                AddAltNameButton3:UnlockHighlight();
                AddAltNameButton2:LockHighlight();
                notSet = false;
            elseif GR_AddonGlobals.currentHighlightIndex == 4 and notSet then
                GR_AddonGlobals.currentHighlightIndex = 3;
                AddAltNameButton4:UnlockHighlight();
                AddAltNameButton3:LockHighlight();
                notSet = false;
            elseif GR_AddonGlobals.currentHighlightIndex == 5 and notSet then
                GR_AddonGlobals.currentHighlightIndex = 4;
                AddAltNameButton5:UnlockHighlight();
                AddAltNameButton4:LockHighlight();
                notSet = false;
            elseif GR_AddonGlobals.currentHighlightIndex == 6 and notSet then
                GR_AddonGlobals.currentHighlightIndex = 5;
                AddAltNameButton6:UnlockHighlight();
                AddAltNameButton5:LockHighlight();
                notSet = false;
            end
        end
    end);
    
    AddAltEditFrame:SetScript ( "OnKeyDown" , function ( _ , key )
        AddAltEditFrame:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            AddAltEditFrame:SetPropagateKeyboardInput ( false );
            AddAltEditFrame:Hide();
        end
    end);

    -- ALT FRAME LOGIC
    altSetMainButton:SetScript ( "OnClick" , function ( _ , button )
        
        if button == "LeftButton" then
            local altDetails = GR_AddonGlobals.selectedAlt;
            if altSetMainButtonText:GetText() == "Set as Main" then
                if altDetails[1] ~= altDetails[2] then
                    GRM.SetMain ( altDetails[1] , altDetails[2] , altDetails[3] );
                else
                    -- No need to set as main yet... let's set player to main here.
                      for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == altDetails[1] then
                            if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                                GRM.SetMain ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][1][1] , altDetails[1] , altDetails[3] );
                            else
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = true;
                            end
                            GRM_MemberDetailMainText:Show();
                            break;
                        end
                    end
                end
                if GRM_MemberDetailMainText:IsVisible() and GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) ~= altDetails[2] then
                    GRM_MemberDetailMainText:Hide();
                end
                print ( GRM.SlimName ( altDetails[2] ) .. " is now set as \"main\"" );
            elseif altSetMainButtonText:GetText() == "Set as Alt" then
                if altDetails[1] ~= altDetails[2] then
                    GRM.DemoteFromMain ( altDetails[1] , altDetails[2] , altDetails[3] );
                else
                    -- No need to set as main yet... let's set player to main here.
                    for j = 2 , #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ] do
                        if GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][1] == altDetails[1] then
                            if #GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11] > 0 then
                                GRM.DemoteFromMain ( GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][11][1][1] , altDetails[1] , altDetails[3] );
                            else
                                GRM_GuildMemberHistory_Save[ GR_AddonGlobals.FID ][ GR_AddonGlobals.saveGID ][j][10] = true;
                            end
                            GRM_MemberDetailMainText:Hide();
                            break;
                        end
                    end
                end
                print ( GRM.SlimName ( altDetails[2] ) .. " is no longer set as \"main\"" );
            elseif altSetMainButtonText:GetText() == "Edit Date" then
                GRM_MemberDetailRankDateTxt:Hide();
                if GR_AddonGlobals.editPromoDate then
                    GRM_SetPromoDateButton:Click();
                    DateSubmitButtonTxt:SetText ( "Edit Promo Date" );
                elseif GR_AddonGlobals.editJoinDate then
                    GRM_JoinDateText:Hide();
                    GRM_MemberDetailJoinDateButton:Click();
                    DateSubmitButtonTxt:SetText ( "Edit Join Date" );
                end
            end
            altDropDownOptions:Hide();
        end    
    end);

    -- Also functions to clear history...
    altRemoveButton:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            local buttonName = altRemoveButtonText:GetText();
            local altDetails = GR_AddonGlobals.selectedAlt;
            if buttonName == "Remove" then
                GRM.RemoveAlt ( altDetails[1] , altDetails[2] , altDetails[3] );
                -- Send comm out of the changes!
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
                    GRMsync.SendMessage ( "GRM_RMVALT" , altDetails[1] .. "?" .. altDetails[2] , "GUILD");
                end
                altDropDownOptions:Hide();
            elseif buttonName == "Clear History" then
                if GR_AddonGlobals.editPromoDate then
                    GRM.ClearPromoDateHistory ( altDetails[1] );
                elseif GR_AddonGlobals.editJoinDate then
                    GRM.ClearJoinDateHistory ( altDetails[1] );
                end
            elseif buttonName == "Reset Data!" then
                RosterConfirmFrameText:SetText( "Reset All of " .. altDetails[1] .. "'s Data?" );
                RosterConfirmYesButtonText:SetText ( "Yes!" );
                RosterConfirmYesButton:SetScript ( "OnClick" , function( self , button )
                    if button == "LeftButton" then
                        GRM.ResetPlayerMetaData ( altDetails[1] , altDetails[3] );
                        RosterConfirmFrame:Hide();
                    end
                end);
                RosterConfirmFrame:Show();
                altDropDownOptions:Hide();
            end
        end
    end);

    altFrameCancelButton:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            altDropDownOptions:Hide();
            GR_AddonGlobals.pause = false;
        end
    end);

    altDropDownOptions:SetScript ( "OnKeyDown" , function ( _ , key )
        altDropDownOptions:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            altDropDownOptions:SetPropagateKeyboardInput ( false );
            altDropDownOptions:Hide();
        end
    end);

    -- CALENDAR ADD EVENT FRAME
    -- SINCE PROTECTED FEATURE, PLAYER MUST MANUALLY ADD
    AddEventFrameTitleText:SetPoint ( "TOP" , AddEventFrame , 0 , - 3.5 );
    AddEventFrameTitleText:SetText ( "Event Calendar Manager" );
    AddEventFrameTitleText:SetFont ( "Fonts\\FRIZQT__.TTF" , 16 );
    AddEventFrameNameTitleText:SetPoint ( "TOPLEFT" , AddEventScrollBorderFrame , 17 , 8 );
    AddEventFrameNameTitleText:SetText ( "Name:                 Event:" );
    AddEventFrameNameTitleText:SetFont ( "Fonts\\FRIZQT__.TTF" , 14 );
    -- Scroll Frame Details
    AddEventScrollBorderFrame:SetSize ( 300 , 175 );
    AddEventScrollBorderFrame:SetPoint ( "Bottom" , AddEventFrame , 40 , 4 );
    AddEventScrollFrame:SetSize ( 280 , 153 );
    AddEventScrollFrame:SetPoint ( "RIGHT" , AddEventFrame , -25 , -21 );
    AddEventScrollFrame:SetScrollChild ( AddEventScrollChildFrame );
    -- Slider Parameters
    AddEventScrollFrameSlider:SetOrientation( "VERTICAL" );
    AddEventScrollFrameSlider:SetSize( 20 , 130 );
    AddEventScrollFrameSlider:SetPoint( "TOPLEFT" , AddEventScrollFrame , "TOPRIGHT" , 0 , -11 );
    AddEventScrollFrameSlider:SetValue( 0 );
    AddEventScrollFrameSlider:SetScript( "OnValueChanged" , function(self)
        AddEventScrollFrame:SetVerticalScroll( self:GetValue() )
    end);
    -- Buttons
    AddEventLoadFrameButton:SetSize ( 90 , 11 );
    AddEventLoadFrameButton:SetPoint ( "TOPRIGHT" , GuildRosterFrame , -20 , -16 );
    AddEventLoadFrameButton:SetFrameStrata ( "HIGH" );
    AddEventLoadFrameButtonText:SetPoint ( "CENTER" , AddEventLoadFrameButton );
    AddEventLoadFrameButtonText:SetFont( "Fonts\\FRIZQT__.TTF" , 8 );
    AddEventFrameSetAnnounceButton:SetPoint ( "LEFT" , AddEventFrame , 25 , -20 );
    AddEventFrameSetAnnounceButton:SetSize ( 60 , 50 );
    AddEventFrameSetAnnounceButtonText:SetPoint ( "CENTER" , AddEventFrameSetAnnounceButton );
    AddEventFrameSetAnnounceButtonText:SetText ( "Set\nEvent" );
    AddEventFrameSetAnnounceButtonText:SetFont( "Fonts\\FRIZQT__.TTF" , 12 );
    AddEventFrameIgnoreButton:SetPoint ( "LEFT" , AddEventFrame , 25 , -80 );
    AddEventFrameIgnoreButton:SetSize ( 60 , 50 );
    AddEventFrameIgnoreButtonText:SetPoint ( "CENTER" , AddEventFrameIgnoreButton );
    AddEventFrameIgnoreButtonText:SetText ( "Ignore" );
    AddEventFrameIgnoreButtonText :SetFont( "Fonts\\FRIZQT__.TTF" , 12 );
    -- STATUS TEXT
    AddEventFrameStatusMessageText:SetPoint ( "LEFT" , AddEventFrame , 6 , 35 );
    AddEventFrameStatusMessageText:SetJustifyH ( "CENTER" );
    AddEventFrameStatusMessageText:SetWidth ( 98 );
    AddEventFrameStatusMessageText:SetFont ( "Fonts\\FRIZQT__.TTF" , 14 );
    AddEventFrameStatusMessageText:SetText ( "Please Select\na Player" );
    AddEventFrameNameToAddText:SetPoint ( "LEFT" , AddEventFrame , 3 , 48 );
    AddEventFrameNameToAddText:SetWidth ( 105 );
    AddEventFrameNameToAddText:SetJustifyH ( "CENTER" );
    AddEventFrameNameToAddText:SetWordWrap ( true );
    AddEventFrameNameToAddText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    AddEventFrameNameToAddTitleText:SetText( "" );

    -- BUTTONS
    LoadLogButton:SetSize ( 90 , 11 );
    LoadLogButton:SetPoint ( "TOPRIGHT" , GuildRosterFrame , -114 , -16 );
    LoadLogButton:SetFrameStrata ( "HIGH" );
    LoadLogButtonText:SetPoint ( "CENTER" , LoadLogButton );
    LoadLogButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 8 );
    LoadLogButtonText:SetText ( "Guild Log" );

    LoadLogButton:SetScript ( "OnClick" , function ( _ , button)
        if button == "LeftButton" then
            if RosterChangeLogFrame:IsVisible() then
                RosterChangeLogFrame:Hide();
            else
                RosterChangeLogFrame:Show();
            end
        end
    end);

    AddEventFrame:SetScript ( "OnShow" , function ( _ )
        GRM.RefreshAddEventFrame();
    end);

    AddEventFrame:SetScript ( "OnKeyDown" , function ( _ , key )
        AddEventFrame:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            AddEventFrame:SetPropagateKeyboardInput ( false );
            AddEventFrame:Hide();
        end
    end);

    AddEventLoadFrameButton:SetScript ( "OnClick" , function ( _ , button)
        if button == "LeftButton" then
            if AddEventFrame:IsVisible() then
                AddEventFrame:Hide();
            else
                AddEventFrame:Show();
            end
        end
    end);

    AddEventFrameSetAnnounceButton:SetScript ( "OnClick" , function ( self , button ) 
        if button == "LeftButton" then
            if not AddEventFrameNameToAddText:IsVisible() then
                print ( "No Player Event Has Been Selected" );
            else
                local tempTime = time();
                if tempTime - GR_AddonGlobals.CalendarAddDelay > 5 then
                    for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] do
                        local name = GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][1];
                        local tempParsedTitle = ( GRM.SlimName ( string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , 0 , ( string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , " " ) - 1 ) ) ) ) .. "'s" .. string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , " " ) , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] );
                        if AddEventFrameNameToAddTitleText:GetText() == GRM.SlimName ( name ) and AddEventFrameNameToAddText:GetText() == tempParsedTitle then

                            -- Ensure it is not already on the calendar ( eventName , year , month , day )
                            if not GRM.IsCalendarEventAlreadyAdded (  GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][5] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][3] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][4] ) then
                                -- Add to Calendar
                                GRM.AddAnnouncementToCalendar ( GRM.SlimName ( name ) , tempParsedTitle , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][3] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][4] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][5] , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][6] );
                                -- Do I really need a "SlimName" here?
                                print ( GRM.SlimName ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] ) .. " Event Added to Calendar!" );
                                
                                -- Let's Broadcast the change to the other users now!
                                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
                                    GRMsync.SendMessage ( "GRM_AC" , name .. "?" .. GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , "GUILD");
                                end

                                -- Remove from que
                                GRM.RemoveFromCalendarQue ( name , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] );
                                -- Reset Frames
                                -- Clear the buttons first
                                if AddEventScrollChildFrame.allFrameButtons ~= nil then
                                    for i = 1 , #AddEventScrollChildFrame.allFrameButtons do
                                        AddEventScrollChildFrame.allFrameButtons[i][1]:Hide();
                                    end
                                end
                                -- Status Notification logic
                                if #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] > 1 then
                                    AddEventFrameStatusMessageText:SetText ( "Please Select\na Player" );
                                    AddEventFrameStatusMessageText:Show();
                                    AddEventFrameNameToAddText:Hide();
                                else
                                    AddEventFrameStatusMessageText:SetText ( "No Events\nto Add");
                                    AddEventFrameStatusMessageText:Show();
                                    AddEventFrameNameToAddText:Hide();
                                end
                    
                                -- Ok Building Frame!
                                GRM.BuildEventCalendarManagerScrollFrame();
                                -- Unlock the highlights too!
                                for i = 1 , #AddEventScrollChildFrame.allFrameButtons do
                                    AddEventScrollChildFrame.allFrameButtons[i][1]:UnlockHighlight();
                                end

                                GR_AddonGlobals.CalendarAddDelay = tempTime;
                                break;
                            else
                                print ( GRM.SlimName ( name ) .. "'s event has already been added to the calendar!" );
                                GRM.RemoveFromCalendarQue ( name , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] );
                            end
                        end
                    end
                else
                    print ( "Please wait " .. ( 6 - ( tempTime - GR_AddonGlobals.CalendarAddDelay ) ) .. " more seconds to Add Event to the Calendar!" );
                end
            end
        end
    end);

    AddEventFrameIgnoreButton:SetScript ( "OnClick" , function ( self , button )
        if button == "LeftButton" then
            if not AddEventFrameNameToAddText:IsVisible() then
                print ( "No Player Event Has Been Selected" );
            else
                for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] do
                    local name = GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][1];
                    local tempParsedTitle = ( GRM.SlimName( string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , 0 , ( string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , " " ) - 1 ) ) ) ) .. "'s" .. string.sub ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , string.find ( GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] , " " ) , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] );
                    if AddEventFrameNameToAddTitleText:GetText() == GRM.SlimName ( name ) and AddEventFrameNameToAddText:GetText() == tempParsedTitle then
                        -- Remove from que
                        GRM.RemoveFromCalendarQue ( name , GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID][i][2] );
                        -- Reset Frames
                        -- Clear the buttons first
                        if AddEventScrollChildFrame.allFrameButtons ~= nil then
                            for i = 1 , #AddEventScrollChildFrame.allFrameButtons do
                                AddEventScrollChildFrame.allFrameButtons[i][1]:Hide();
                            end
                        end
                        -- Status Notification logic
                        if #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][GR_AddonGlobals.saveGID] > 1 then
                            AddEventFrameStatusMessageText:SetText ( "Please Select\na Player" );
                            AddEventFrameStatusMessageText:Show();
                            AddEventFrameNameToAddText:Hide();
                        else
                            AddEventFrameStatusMessageText:SetText ( "No Events\nto Add");
                            AddEventFrameStatusMessageText:Show();
                            AddEventFrameNameToAddText:Hide();
                        end
                        -- Ok Building Frame!
                        GRM.BuildEventCalendarManagerScrollFrame();
                        -- Unlock the highlights too!
                        for i = 1 , #AddEventScrollChildFrame.allFrameButtons do
                            AddEventScrollChildFrame.allFrameButtons[i][1]:UnlockHighlight();
                        end
                        -- Report
                        print ( GRM.SlimName ( name ) .. "'s Event Removed From the Que!" );
                        break;
                    end                
                end
            end
        end
    end); 

    -- Hides both buttons.
    GuildRosterFrame:HookScript ( "OnHide" , function ( self ) 
        AddEventLoadFrameButton:Hide();
        LoadLogButton:Hide();
        GRM.ClearAllFrames();
    end);

    -- Needs to be initialized AFTER guild frame first logs or it will error, so only making it here now.
    GuildTextEditFrame.GuildMOTDcharCount = GuildTextEditFrame:CreateFontString ( "GuildMOTDcharCount" , "OVERLAY" , "GameFontNormalSmall" );
    GuildTextEditFrame.GuildMOTDcharCount:SetPoint ( "TOPRIGHT" , GuildTextEditBox , 15 , 19 )
    GuildTextEditFrame.GuildMOTDcharCount:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );

    -- MISC FRAMES INITIALZIATION AND LOGIC
    GuildTextEditBox:HookScript ( "OnEditFocusGained" , function()
        GuildTextEditFrame.GuildMOTDcharCount:SetText( tostring ( GuildTextEditBox:GetNumLetters() ) .. "/" .. GuildTextEditBox:GetMaxLetters() );
        GuildTextEditFrame.GuildMOTDcharCount:Show();
    
    end);
    GuildTextEditBox:HookScript ( "OnEditFocusLost" , function()
        GuildTextEditFrame.GuildMOTDcharCount:Hide();
    end);

    -- Updates char count as player types.
    GuildTextEditBox:HookScript ( "OnChar" , function ( self , text ) 
        local charCount = #GuildTextEditBox:GetText();
        charCount = charCount;
        GuildTextEditFrame.GuildMOTDcharCount:SetText( charCount .. "/" .. GuildTextEditBox:GetMaxLetters() );
    end);

    -- Update on backspace changes too
    GuildTextEditBox:HookScript ( "OnKeyDown" , function ( self , text )  -- While technically this one script handler could do all, this is more processor efficient to have 2.
        if text == "BACKSPACE" then
            local charCount = #GuildTextEditBox:GetText();
            charCount = charCount - 1;
            if charCount == -1 then
                charCount = 0;
            end
            GuildTextEditFrame.GuildMOTDcharCount:SetText( charCount .. "/" .. GuildTextEditBox:GetMaxLetters() );
        end
    end);

    -- TOOLTIP INIT
    GRM_MemberDetailRankToolTip:SetScale ( 0.85 );
    GRM_MemberDetailJoinDateToolTip:SetScale ( 0.85 );

end

-- Method:          GRM.PreAddonLoadUI()
-- What it Does:    Initializes the core Log Frame before the addon loads
-- Purpose:         One cannot use methods like "SetUserPlaced" to carry over between sessions sunless the frame is initalized BEFORE "ADDON_LOADED" event fires.
GRM.PreAddonLoadUI = function()
    RosterChangeLogFrame:SetPoint ( "CENTER" , UIParent );
    RosterChangeLogFrame:SetFrameStrata ( "HIGH" );
    RosterChangeLogFrame:SetSize ( 600 , 440 );
    RosterChangeLogFrame:EnableMouse ( true );
    RosterChangeLogFrame:SetMovable ( true );
    RosterChangeLogFrame:SetUserPlaced ( true );
    RosterChangeLogFrame:SetToplevel ( true );
    RosterChangeLogFrame:RegisterForDrag ( "LeftButton" );
    RosterChangeLogFrame:SetScript ( "OnDragStart" , RosterChangeLogFrame.StartMoving );
    RosterChangeLogFrame:SetScript ( "OnDragStop" , RosterChangeLogFrame.StopMovingOrSizing );

    AddEventFrame:SetPoint ( "CENTER" , UIParent );
    AddEventFrame:SetFrameStrata ( "HIGH" );
    AddEventFrame:SetSize ( 425 , 225 );
    AddEventFrame:EnableMouse ( true );
    AddEventFrame:SetMovable ( true );
    AddEventFrame:SetUserPlaced ( true );
    AddEventFrame:SetToplevel ( true );
    AddEventFrame:RegisterForDrag ( "LeftButton" );
    AddEventFrame:SetScript ( "OnDragStart" , AddEventFrame.StartMoving );
    AddEventFrame:SetScript( "OnDragStop" , AddEventFrame.StopMovingOrSizing );
end

-- Method           GRM.MetaDataInitializeUIrosterLog1()
-- What it Does:    Keeps the log initialization separate and part of the UIParent, so it can load upon logging in
-- Purpose:         Resource control. This loads upon login, but keeps the rest of the addon UI initialization from occuring unless as needed.
--                  In other words, this can be loaded upon logging, but the rest will only load if the guild roster window loads.
GRM.MetaDataInitializeUIrosterLog1 = function()

    -- MAIN GUILD LOG FRAME!!!
    RosterChangeLogFrameTitleText:SetPoint ( "TOP" , RosterChangeLogFrame , 0 , - 3.5 );
    RosterChangeLogFrameTitleText:SetText ( "Guild Roster Event Log" );
    RosterChangeLogFrameTitleText:SetFont ( "Fonts\\FRIZQT__.TTF" , 16 );
    RosterCheckBoxSideFrame:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , "TOPRIGHT" , -3 , 5 );
    RosterCheckBoxSideFrame:SetSize ( 200 , 365 ); -- 509 is flush height
    RosterCheckBoxSideFrame:Hide();
    RosterCheckBoxSideFrame:SetAlpha ( 0.0 );
    -- Scroll Frame Details
    RosterChangeLogScrollBorderFrame:SetSize ( 583 , 425 );
    RosterChangeLogScrollBorderFrame:SetPoint ( "Bottom" , RosterChangeLogFrame , "BOTTOM" , -9 , -2 );
    RosterChangeLogScrollFrame:SetSize ( 565 , 402 );
    RosterChangeLogScrollFrame:SetPoint (  "Bottom" , RosterChangeLogFrame , "BOTTOM" , -2 , 10 );
    RosterChangeLogScrollFrame:SetScrollChild ( RosterChangeLogScrollChildFrame );
    -- Slider Parameters
    RosterChangeLogScrollFrameSlider:SetOrientation ( "VERTICAL" );
    RosterChangeLogScrollFrameSlider:SetSize ( 20 , 382 );
    RosterChangeLogScrollFrameSlider:SetPoint ( "TOPLEFT" , RosterChangeLogScrollFrame , "TOPRIGHT" , -2.5 , -12 );
    RosterChangeLogScrollFrameSlider:SetValue ( 0 );
    RosterChangeLogScrollFrameSlider:SetScript ( "OnValueChanged" , function ( self )
        RosterChangeLogScrollFrame:SetVerticalScroll ( self:GetValue() );
    end);

    -- Options Buttons
    RosterOptionsButton:SetSize ( 90 , 16 );
    RosterOptionsButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 30 , -3 );
    RosterOptionsButton:SetFrameStrata ( "HIGH" );
    RosterOptionsButtonText:SetPoint ( "CENTER" , RosterOptionsButton );
    RosterOptionsButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 11.5 );
    RosterOptionsButtonText:SetText ( "Options" );

    RosterOptionsButton:SetScript ( "OnClick" , function ( self , button )
        if button == "LeftButton" then
            if math.floor ( RosterChangeLogFrame:GetHeight() ) >= 500 then -- Since the height is a double, returns it as an int using math.floor
                RosterOptionsButton:Disable();
                if RosterKickRecommendEditBox:IsVisible() then
                    RosterKickRecommendEditBox:Hide();
                    RosterKickOverlayNote:Show();
                end
                if ReportInactiveReturnEditBox:IsVisible() then
                    ReportInactiveReturnEditBox:Hide();
                    ReportInactiveReturnOverlayNote:Show();
                end
                if RosterReportUpcomingEventsEditBox:IsVisible() then
                    RosterReportUpcomingEventsEditBox:Hide();
                    RosterReportUpcomingEventsOverlayNote:Show();
                end
                GRM.LogOptionsFadeOut();
                GRM.LogFrameTransformationClose();
            else
                RosterOptionsButton:Disable();
                RosterCheckBoxSideFrame:Show();
                GRM.LogFrameTransformationOpen();   
            end
        end
    end);

    -- Clear Log Button
    RosterClearLogButton:SetSize ( 90 , 16 );
    RosterClearLogButton:SetPoint ( "TOPRIGHT" , RosterChangeLogFrame , -30 , -3 );
    RosterClearLogButton:SetFrameStrata ( "HIGH" );
    RosterClearLogButtonText:SetPoint ( "CENTER" , RosterClearLogButton );
    RosterClearLogButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 11.5 );
    RosterClearLogButtonText:SetText ( "Clear Log" );
    RosterClearLogButton:SetScript ( "OnClick" , function( self , button )
        if button == "LeftButton" then
            RosterChangeLogFrame:EnableMouse( false );
            RosterChangeLogFrame:SetMovable( false );
            RosterConfirmFrameText:SetText( "Really Clear the Guild Log?" );
            RosterConfirmYesButtonText:SetText ( "Yes!" );
            RosterConfirmYesButton:SetScript ( "OnClick" , function( self , button )
                if button == "LeftButton" then
                    GRM.ResetLogReport();       --Resetting!
                    RosterConfirmFrame:Hide();
                end
            end);
            RosterConfirmFrame:Show();
        end
    end);

    -- Popup window to confirm!
    RosterConfirmFrame:Hide();
    RosterConfirmFrame:SetPoint ( "CENTER" , UIPanel , 0 , 200 );
    RosterConfirmFrame:SetSize ( 275 , 90 );
    RosterConfirmFrame:SetFrameStrata ( "FULLSCREEN_DIALOG" );
    RosterConfirmFrameText:SetPoint ( "CENTER" , RosterConfirmFrame , 0 , 10 );
    RosterConfirmFrameText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterConfirmFrameText:SetWidth ( 265 );
    RosterConfirmFrameText:SetSpacing ( 1 );
    RosterConfirmFrameText:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    RosterConfirmYesButton:SetPoint ( "BOTTOMLEFT" , RosterConfirmFrame , 15 , 5 );
    RosterConfirmYesButton:SetSize ( 70 , 35 );
    RosterConfirmYesButtonText:SetPoint ( "CENTER" , RosterConfirmYesButton );
    RosterConfirmYesButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 14 );

    RosterConfirmCancelButton:SetPoint ( "BOTTOMRIGHT" , RosterConfirmFrame , -15 , 5 );
    RosterConfirmCancelButton:SetSize ( 70 , 35 );
    RosterConfirmCancelButtonText:SetPoint ( "CENTER" , RosterConfirmCancelButton );
    RosterConfirmCancelButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 14 );
    RosterConfirmCancelButtonText:SetText ( "Cancel" );
    RosterConfirmCancelButton:SetScript ( "OnClick" , function ( self , button )
        if button == "LeftButton" then
            RosterConfirmFrame:Hide();
        end
    end);
    RosterConfirmFrame:SetScript ( "OnHide" , function ( self )
        RosterChangeLogFrame:EnableMouse ( true );
        RosterChangeLogFrame:SetMovable ( true );
    end);
    RosterCheckBoxSideFrame:SetScript ( "OnHide" , function ( self )
        if RosterConfirmFrameText:GetText() == "Really Clear the Guild Log?" then
            RosterConfirmFrame:Hide();
        end
    end);
    


    -- CORE OPTIONS
    RosterLoadOnLogonCheckButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 14 , -22 );
    RosterLoadOnLogonCheckButtonText:SetPoint ( "LEFT" , RosterLoadOnLogonCheckButton , 27 , 0 );
    RosterLoadOnLogonCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterLoadOnLogonCheckButtonText:SetText ( "Show at Logon" );
    RosterLoadOnLogonCheckButton:SetScript ( "OnClick", function()
        if RosterLoadOnLogonCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][2] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][2] = false;
        end
    end);
    RosterAddTimestampCheckButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 14 , -42 );
    RosterAddTimestampCheckButtonText:SetPoint ( "LEFT" , RosterAddTimestampCheckButton , 27 , 0 );
    RosterAddTimestampCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterAddTimestampCheckButtonText:SetText ( "Add Join Date to Officer Note   " ); -- Don't ask me why, but this spacing is needed for tabs to line up right in UI. Lua lol'
    RosterAddTimestampCheckButton:SetScript ( "OnClick", function()              
        if RosterAddTimestampCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] = false;
        end
    end);

    -- Kick Recommendation!
    RosterRecommendKickCheckButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 14 , -62 );
    RosterRecommendKickCheckButtonText:SetPoint ( "LEFT" , RosterRecommendKickCheckButton , 27 , 0 );
    RosterRecommendKickCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterRecommendKickCheckButtonText:SetText ( "Kick Inactives Reminder at        Months" );
    RosterRecommendKickCheckButton:SetScript ( "OnClick", function()
        if RosterRecommendKickCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][10] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][10] = false;
        end
    end);
    RosterKickOverlayNote:SetPoint ( "RIGHT" , RosterRecommendKickCheckButton , 197.3 , 0 )
    RosterKickOverlayNote:SetBackdrop ( noteBackdrop2 );
    RosterKickOverlayNote:SetFrameStrata ( "HIGH" );
    RosterKickOverlayNote:SetSize ( 30 , 22 );
    RosterKickOverlayNoteText:SetPoint ( "CENTER" , RosterKickOverlayNote );
    RosterKickOverlayNoteText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterKickOverlayNoteText:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    RosterKickOverlayNoteText:SetText ( GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][9] );
    RosterKickRecommendEditBox:SetPoint ( "RIGHT" , RosterRecommendKickCheckButton , 201 , 0 );
    RosterKickRecommendEditBox:SetSize ( 35 , 22 );
    RosterKickRecommendEditBox:SetTextInsets ( 8 , 9 , 9 , 8 );
    RosterKickRecommendEditBox:SetMaxLetters ( 2 );
    RosterKickRecommendEditBox:SetNumeric ( true );
    RosterKickRecommendEditBox:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    RosterKickRecommendEditBox:SetFont ( "Fonts\\FRIZQT__.TTF" , 10 );
    RosterKickRecommendEditBox:EnableMouse ( true );

    RosterKickOverlayNote:SetScript ( "OnMouseDown" , function ( self , button )
        if button == "LeftButton" then
            if RosterKickRecommendEditBox:IsEnabled() then
                RosterKickOverlayNote:Hide();
                RosterKickRecommendEditBox:SetText ( "" );
                RosterKickRecommendEditBox:Show()
            end
        end    
    end);

    RosterKickRecommendEditBox:SetScript ( "OnEscapePressed" , function()
        RosterKickRecommendEditBox:Hide();
        RosterKickOverlayNote:Show();
    end);

    RosterKickRecommendEditBox:SetScript ( "OnEnterPressed" , function()
        local numMonths = tonumber ( RosterKickRecommendEditBox:GetText() );
        if numMonths > 0 and numMonths < 100 then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][9] = numMonths;
            RosterKickOverlayNoteText:SetText ( numMonths );
            RosterKickRecommendEditBox:Hide();
            RosterKickOverlayNote:Show();
        else
            print ("Please choose a month between 1 and 99" );
        end      
    end);

    RosterKickRecommendEditBox:SetScript ( "OnEditFocusLost" , function() 
        RosterKickRecommendEditBox:Hide();
        RosterKickOverlayNote:Show();
    end)

    -- Report Inactive Recommendation.
    RosterReportInactiveReturnButton:SetPoint ( "TOP" , RosterChangeLogFrame , 14 , -22 );
    RosterReportInactiveReturnButtonText:SetPoint ( "LEFT" , RosterReportInactiveReturnButton , 27 , 0 );
    RosterReportInactiveReturnButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterReportInactiveReturnButtonText:SetText ( "Report Inactive Return if Offline         Days" );
    RosterReportInactiveReturnButton:SetScript ( "OnClick", function()
        if RosterReportInactiveReturnButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][11] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][11] = false;
        end
    end);
    ReportInactiveReturnOverlayNote:SetPoint ( "RIGHT" , RosterReportInactiveReturnButton , 234.5 , 0 )
    ReportInactiveReturnOverlayNote:SetBackdrop ( noteBackdrop2 );
    ReportInactiveReturnOverlayNote:SetFrameStrata ( "HIGH" );
    ReportInactiveReturnOverlayNote:SetSize ( 30 , 22 );
    ReportInactiveReturnOverlayNoteText:SetPoint ( "CENTER" , ReportInactiveReturnOverlayNote );
    ReportInactiveReturnOverlayNoteText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    ReportInactiveReturnOverlayNoteText:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    ReportInactiveReturnOverlayNoteText:SetText ( math.floor ( GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][4] / 24 ) );
    ReportInactiveReturnEditBox:SetPoint( "RIGHT" , RosterReportInactiveReturnButton , 244 , 0 );
    ReportInactiveReturnEditBox:SetSize ( 45 , 22 );
    ReportInactiveReturnEditBox:SetTextInsets( 8 , 9 , 9 , 8 );
    ReportInactiveReturnEditBox:SetMaxLetters ( 3 );
    ReportInactiveReturnEditBox:SetNumeric ( true );
    ReportInactiveReturnEditBox:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    ReportInactiveReturnEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 10 );
    ReportInactiveReturnEditBox:EnableMouse( true );

    ReportInactiveReturnOverlayNote:SetScript ( "OnMouseDown" , function ( self , button )
        if button == "LeftButton" then
            ReportInactiveReturnOverlayNote:Hide();
            ReportInactiveReturnEditBox:SetText ( "" );
            ReportInactiveReturnEditBox:Show();
        end    
    end);

    ReportInactiveReturnEditBox:SetScript ( "OnEscapePressed" , function()
        ReportInactiveReturnEditBox:Hide();
        ReportInactiveReturnOverlayNote:Show();
    end);

    ReportInactiveReturnEditBox:SetScript ( "OnEnterPressed" , function()
        local numDays = tonumber ( ReportInactiveReturnEditBox:GetText() );
        if numDays > 0 and numDays < 181 then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][4] = numDays * 24;
            ReportInactiveReturnOverlayNoteText:SetText ( numDays );
            ReportInactiveReturnEditBox:Hide();
            ReportInactiveReturnOverlayNote:Show();
        else
            print("Please choose between 1 and 180 days!" );
        end      
    end);

    ReportInactiveReturnEditBox:SetScript ( "OnEditFocusLost" , function() 
        ReportInactiveReturnEditBox:Hide();
        ReportInactiveReturnOverlayNote:Show();
    end)

    -- Add Event Options on Announcing...
    RosterReportUpcomingEventsCheckButtonDays:SetPoint ( "TOP" , RosterChangeLogFrame , 14 , -42 );
    RosterReportUpcomingEventsCheckButtonDaysText:SetPoint ( "LEFT" , RosterReportUpcomingEventsCheckButtonDays , 27 , 0 );
    RosterReportUpcomingEventsCheckButtonDaysText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterReportUpcomingEventsCheckButtonDaysText:SetText ( "Announce Events         Days in Advance" );
    RosterReportUpcomingEventsCheckButtonDays:SetScript ( "OnClick", function()
        if RosterReportUpcomingEventsCheckButtonDays:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][12] = true;
            RosterReportUpcomingEventsCheckButton:Show();
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][12] = false;
            RosterReportUpcomingEventsCheckButton:Hide();
        end
    end);
    RosterReportUpcomingEventsOverlayNote:SetPoint ( "RIGHT" , RosterReportUpcomingEventsCheckButtonDays , 142 , 0 )
    RosterReportUpcomingEventsOverlayNote:SetBackdrop ( noteBackdrop2 );
    RosterReportUpcomingEventsOverlayNote:SetFrameStrata ( "HIGH" );
    RosterReportUpcomingEventsOverlayNote:SetSize ( 30 , 22 );
    RosterReportUpcomingEventsOverlayNoteText:SetPoint ( "CENTER" , RosterReportUpcomingEventsOverlayNote );
    RosterReportUpcomingEventsOverlayNoteText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterReportUpcomingEventsOverlayNoteText:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    RosterReportUpcomingEventsOverlayNoteText:SetText ( GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] ) ;
    RosterReportUpcomingEventsEditBox:SetPoint( "RIGHT" , RosterReportUpcomingEventsCheckButtonDays , 147 , 0 );
    RosterReportUpcomingEventsEditBox:SetSize ( 35 , 22 );
    RosterReportUpcomingEventsEditBox:SetTextInsets( 8 , 9 , 9 , 8 );
    RosterReportUpcomingEventsEditBox:SetMaxLetters ( 2 );
    RosterReportUpcomingEventsEditBox:SetNumeric ( true );
    RosterReportUpcomingEventsEditBox:SetTextColor ( 1.0 , 0 , 0 , 1.0 );
    RosterReportUpcomingEventsEditBox:SetFont( "Fonts\\FRIZQT__.TTF" , 10 );
    RosterReportUpcomingEventsEditBox:EnableMouse( true );

    RosterReportUpcomingEventsOverlayNote:SetScript ( "OnMouseDown" , function( self , button )
        if button == "LeftButton" then
            RosterReportUpcomingEventsOverlayNote:Hide();
            RosterReportUpcomingEventsEditBox:SetText ( "" );
            RosterReportUpcomingEventsEditBox:Show();
        end    
    end);

    RosterReportUpcomingEventsEditBox:SetScript ( "OnEscapePressed" , function()
        RosterReportUpcomingEventsEditBox:Hide();
        RosterReportUpcomingEventsOverlayNote:Show();
    end);

    RosterReportUpcomingEventsEditBox:SetScript ( "OnEnterPressed" , function()
        local numDays = tonumber ( RosterReportUpcomingEventsEditBox:GetText() );
        if numDays > 0 and numDays < 29 then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][5] = numDays;
            RosterReportUpcomingEventsOverlayNoteText:SetText ( numDays );
            RosterReportUpcomingEventsEditBox:Hide();
            RosterReportUpcomingEventsOverlayNote:Show();
        else
            print("Please choose between 1 and 28 days!" );
        end      
    end);

    RosterReportUpcomingEventsEditBox:SetScript ( "OnEditFocusLost" , function() 
        RosterReportUpcomingEventsEditBox:Hide();
        RosterReportUpcomingEventsOverlayNote:Show();
    end)


    -- Add Event Options Button to add events to calendar
    RosterReportUpcomingEventsCheckButton:SetPoint ( "TOP" , RosterChangeLogFrame , 14 , -62 );
    RosterReportUpcomingEventsCheckButtonText:SetPoint ( "LEFT" , RosterReportUpcomingEventsCheckButton , 27 , 0 );
    RosterReportUpcomingEventsCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterReportUpcomingEventsCheckButtonText:SetText ( "Add Events to Calendar" );
    RosterReportUpcomingEventsCheckButton:SetScript ( "OnClick", function()
        if RosterReportUpcomingEventsCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][8] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][8] = false;
        end
    end);

    -- SYNC WITH OTHER PLAYERS!
    RosterCheckBoxSideFrame.RosterSyncCheckButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 14 , -82 );
    RosterCheckBoxSideFrame.RosterSyncCheckButtonText:SetPoint ( "LEFT" , RosterCheckBoxSideFrame.RosterSyncCheckButton , 27 , 0)
    RosterCheckBoxSideFrame.RosterSyncCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterCheckBoxSideFrame.RosterSyncCheckButtonText:SetText ( "Receive Changes from Guildies ONLINE at Rank" );
    RosterCheckBoxSideFrame.RosterSyncCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterSyncCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] = true;
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Show();
            GRM.LogFrameTransformationOpen();
            GRMsync.Initialize();
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] = false;
            GRM.LogFrameTransformationCloseMinor();
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Hide();
            GRMsync.MessageTracking:UnregisterAllEvents();
            GRMsync.DatabaseLoaded = false;
            GRMsync.RulesSet = false;
        end
    end);

    -- RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:GetChecked()
    RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:SetPoint ( "TOPLEFT" , RosterChangeLogFrame , 14 , -102 );
    RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButtonText:SetPoint ( "LEFT" , RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton , 27 , 0)
    RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButtonText:SetText ( "Display Messages on Shared Updates" );
    RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][16] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][16] = false;
        end
    end);

    -- Rank Drop Down for Options Frame
        -- rank drop down 
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:SetPoint ( "RIGHT" , RosterCheckBoxSideFrame.RosterSyncCheckButtonText , 132 , 0 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:SetSize (  130 , 18 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:SetPoint ( "CENTER" , RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:SetWidth ( 130 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelectedText:SetFont ( "Fonts\\FRIZQT__.TTF" , 11 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetPoint ( "TOP" , RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected , "BOTTOM" );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetWidth ( 130 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetFrameStrata ( "HIGH" );

    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenuButton:SetPoint ( "LEFT" , RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected , "RIGHT" , -1 , -0.5 );
    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenuButton:SetSize ( 20 , 17 );

    RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetScript ( "OnKeyDown" , function ( _ , key )
        RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:SetPropagateKeyboardInput ( false );
            RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:Hide();
            RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:Show();
        end
    end);

    RosterCheckBoxSideFrame.RosterSyncRankDropDownSelected:SetScript ( "OnShow" , function() 
        RosterCheckBoxSideFrame.RosterSyncRankDropDownMenu:Hide();
    end)
end


-- Method           GRM.MetaDataInitializeUIrosterLog2()
-- What it Does:    Keeps the log initialization separate and part of the UIParent, so it can load upon logging in
-- Purpose:         Resource control. This loads upon login, but keeps the rest of the addon UI initialization from occuring unless as needed.
--                  In other words, this can be loaded upon logging, but the rest will only load if the guild roster window loads.
GRM.MetaDataInitializeUIrosterLog2 = function()
    -- CHECKBUTTONS for Logging Details
    RosterJoinedCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -45 );
    RosterCheckBoxSideFrame.RosterJoinedChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -45 );
    RosterJoinedCheckButtonText:SetPoint ( "LEFT" , RosterJoinedCheckButton , 27 , 0 );
    RosterJoinedCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterJoinedCheckButtonText:SetTextColor ( 0.5 , 1.0 , 0.0 , 1.0 );
    RosterJoinedCheckButtonText:SetText ( "Joined" );
    RosterJoinedCheckButton:SetScript ( "OnClick", function()
        if RosterJoinedCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][1] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][1] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterJoinedChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterJoinedChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] = false;
        end
    end);

    RosterLeveledChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -70 );
    RosterCheckBoxSideFrame.RosterLeveledChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -70 );
    RosterLeveledChangeCheckButtonText:SetPoint ( "LEFT" , RosterLeveledChangeCheckButton , 27 , 0 );
    RosterLeveledChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterLeveledChangeCheckButtonText:SetTextColor ( 0.0 , 0.44 , 0.87 , 1.0 );
    RosterLeveledChangeCheckButtonText:SetText ( "Leveled" );
    RosterLeveledChangeCheckButton:SetScript ( "OnClick", function()
        if RosterLeveledChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][2] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][2] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterLeveledChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterLeveledChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][2] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][2] = false;
        end
    end);


    RosterInactiveReturnCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -95 );
    RosterCheckBoxSideFrame.RosterInactiveReturnChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -95 );
    RosterInactiveReturnCheckButtonText:SetPoint ( "LEFT" , RosterInactiveReturnCheckButton , 27 , 0 );
    RosterInactiveReturnCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterInactiveReturnCheckButtonText:SetTextColor ( 0.0 , 1.0 , 0.87 , 1.0 );
    RosterInactiveReturnCheckButtonText:SetText ( "Inactive Return" );
    RosterInactiveReturnCheckButton:SetScript ( "OnClick", function()
        if RosterInactiveReturnCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][3] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][3] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterInactiveReturnChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterInactiveReturnChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][3] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][3] = false;
        end
    end);

    RosterPromotionChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -120 );
    RosterCheckBoxSideFrame.RosterPromotionChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -120 );
    RosterPromotionChangeCheckButtonText:SetPoint ( "LEFT" , RosterPromotionChangeCheckButton , 27 , 0 );
    RosterPromotionChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterPromotionChangeCheckButtonText:SetTextColor ( 1.0 , 0.914 , 0.0 , 1.0 );
    RosterPromotionChangeCheckButtonText:SetText ( "Promotions" );
    RosterPromotionChangeCheckButton:SetScript ( "OnClick", function()
        if RosterPromotionChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][4] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][4] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterPromotionChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterPromotionChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][4] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][4] = false;
        end
    end);

    RosterDemotionChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -145 );
    RosterCheckBoxSideFrame.RosterDemotionChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -145 );
    RosterDemotionChangeCheckButtonText:SetPoint ( "LEFT" , RosterDemotionChangeCheckButton , 27 , 0 );
    RosterDemotionChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterDemotionChangeCheckButtonText:SetTextColor ( 0.91 , 0.388 , 0.047 , 1.0 );
    RosterDemotionChangeCheckButtonText:SetText ( "Demotions" );
    RosterDemotionChangeCheckButton:SetScript ( "OnClick", function()
        if RosterDemotionChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][5] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][5] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterDemotionChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterDemotionChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][5] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][5] = false;
        end
    end);

    RosterNoteChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -170 );
    RosterCheckBoxSideFrame.RosterNoteChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -170 );
    RosterNoteChangeCheckButtonText:SetPoint ( "LEFT" , RosterNoteChangeCheckButton , 27 , 0 );
    RosterNoteChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterNoteChangeCheckButtonText:SetTextColor ( 1.0 , 0.6 , 1.0 , 1.0 );
    RosterNoteChangeCheckButtonText:SetText ( "Note" );
    RosterNoteChangeCheckButton:SetScript ( "OnClick", function()
        if RosterNoteChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][6] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][6] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterNoteChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterNoteChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][6] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][6] = false;
        end
    end);

    RosterOfficerNoteChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -195 );
    RosterCheckBoxSideFrame.RosterOfficerNoteChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -195 );
    RosterOfficerNoteChangeCheckButtonText:SetPoint ( "LEFT" , RosterOfficerNoteChangeCheckButton , 27 , 0 );
    RosterOfficerNoteChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterOfficerNoteChangeCheckButtonText:SetTextColor ( 1.0 , 0.094 , 0.93 , 1.0 );
    RosterOfficerNoteChangeCheckButtonText:SetText ( "Officer Note" );
    RosterOfficerNoteChangeCheckButton:SetScript ( "OnClick", function()
        if RosterOfficerNoteChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][7] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][7] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterOfficerNoteChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterOfficerNoteChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][7] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][7] = false;
        end
    end);

    RosterNameChangeCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -220 );
    RosterCheckBoxSideFrame.RosterNameChangeChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -220 );
    RosterNameChangeCheckButtonText:SetPoint ( "LEFT" , RosterNameChangeCheckButton , 27 , 0 );
    RosterNameChangeCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterNameChangeCheckButtonText:SetTextColor ( 0.90 , 0.82 , 0.62 , 1.0 );
    RosterNameChangeCheckButtonText:SetText ( "Name Change" );
    RosterNameChangeCheckButton:SetScript ( "OnClick", function()
        if RosterNameChangeCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][8] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][8] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterNameChangeChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterNameChangeChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][8] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][8] = false;
        end
    end);

    RosterRankRenameCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -245 );
    RosterCheckBoxSideFrame.RosterRankRenameChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -245 );
    RosterRankRenameCheckButtonText:SetPoint ( "LEFT" , RosterRankRenameCheckButton , 27 , 0 );
    RosterRankRenameCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterRankRenameCheckButtonText:SetTextColor ( 0.64 , 0.102 , 0.102 , 1.0 );
    RosterRankRenameCheckButtonText:SetText ( "Rank Renamed" );
    RosterRankRenameCheckButton:SetScript ( "OnClick", function()
        if RosterRankRenameCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][9] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][9] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterRankRenameChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterRankRenameChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][9] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][9] = false;
        end
    end);

    RosterEventCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -270 );
    RosterCheckBoxSideFrame.RosterEventChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -270 );
    RosterEventCheckButtonText:SetPoint ( "LEFT" , RosterEventCheckButton , 27 , 0 );
    RosterEventCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterEventCheckButtonText:SetTextColor ( 0.0 , 0.8 , 1.0 , 1.0 );
    RosterEventCheckButtonText:SetText ( "Event Announce" );
    RosterEventCheckButton:SetScript ( "OnClick", function()
        if RosterEventCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][10] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][10] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterEventChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterEventChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][10] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][10] = false;
        end
    end);
     
    RosterLeftGuildCheckButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -295 );
    RosterCheckBoxSideFrame.RosterLeftGuildChatCheckButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -295 );
    RosterLeftGuildCheckButtonText:SetPoint ( "LEFT" , RosterLeftGuildCheckButton , 27 , 0 );
    RosterLeftGuildCheckButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterLeftGuildCheckButtonText:SetTextColor ( 0.5 , 0.5 , 0.5 , 1.0 );
    RosterLeftGuildCheckButtonText:SetText ( "Left" );
    RosterLeftGuildCheckButton:SetScript ( "OnClick", function()
        if RosterLeftGuildCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][11] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][11] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterLeftGuildChatCheckButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterLeftGuildChatCheckButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][11] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][11] = false;
        end
    end);

    RosterRecommendationsButton:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -320 );
    RosterCheckBoxSideFrame.RosterRecommendationsChatButton:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -320 );
    RosterRecommendationsButtonText:SetPoint ( "LEFT" , RosterRecommendationsButton , 27 , 0 );
    RosterRecommendationsButtonText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterRecommendationsButtonText:SetTextColor ( 1.0 , 0.0 , 0.0 , 1.0 );
    RosterRecommendationsButtonText:SetText ( "Recommendations" );
    RosterRecommendationsButton:SetScript ( "OnClick", function()
        if RosterRecommendationsButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][12] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][12] = false;
        end
        GRM.BuildLog();
    end);
    RosterCheckBoxSideFrame.RosterRecommendationsChatButton:SetScript ( "OnClick", function()
        if RosterCheckBoxSideFrame.RosterRecommendationsChatButton:GetChecked() then
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][12] = true;
        else
            GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][12] = false;
        end
    end);

    -- Propagate for keyboard control of the frames!!!
    RosterChangeLogFrame:SetScript ( "OnKeyDown" , function ( _ , key )
        RosterChangeLogFrame:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            RosterChangeLogFrame:SetPropagateKeyboardInput ( false );
            RosterChangeLogFrame:Hide();
        end
    end);

    RosterConfirmFrame:SetScript ( "OnKeyDown" , function ( _ , key )
        RosterConfirmFrame:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" then
            RosterConfirmFrame:SetPropagateKeyboardInput ( false );
            RosterConfirmFrame:Hide();
        end
    end);

    RosterCheckBoxSideFrame:SetScript ( "OnKeyDown" , function ( _ , key )
        RosterCheckBoxSideFrame:SetPropagateKeyboardInput ( true );      -- Ensures keyboard access will default to the main chat window on / or Enter. UX feature.
        if key == "ESCAPE" and not RosterKickRecommendEditBox:HasFocus() then
            RosterCheckBoxSideFrame:SetPropagateKeyboardInput ( false );
            RosterOptionsButton:Click();
        end
    end);

    RosterChangeLogFrame:SetScript ( "OnShow" , function () 
        -- Button Positions
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][1] then
            RosterJoinedCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][1] then
            RosterCheckBoxSideFrame.RosterJoinedChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][2] then
            RosterLeveledChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][2] then
            RosterCheckBoxSideFrame.RosterLeveledChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][3] then
            RosterInactiveReturnCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][3] then
            RosterCheckBoxSideFrame.RosterInactiveReturnChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][4] then
            RosterPromotionChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][4] then
            RosterCheckBoxSideFrame.RosterPromotionChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][5] then
            RosterDemotionChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][5] then
            RosterCheckBoxSideFrame.RosterDemotionChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][6] then
            RosterNoteChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][6] then
            RosterCheckBoxSideFrame.RosterNoteChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][7] then
            RosterOfficerNoteChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][7] then
            RosterCheckBoxSideFrame.RosterOfficerNoteChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][8] then
            RosterNameChangeCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][8] then
            RosterCheckBoxSideFrame.RosterNameChangeChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][9] then
            RosterRankRenameCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][9] then
            RosterCheckBoxSideFrame.RosterRankRenameChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][10] then
            RosterEventCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][10] then
            RosterCheckBoxSideFrame.RosterEventChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][11] then
            RosterLeftGuildCheckButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][11] then
            RosterCheckBoxSideFrame.RosterLeftGuildChatCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][3][12] then
            RosterRecommendationsButton:SetChecked( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][13][12] then
            RosterCheckBoxSideFrame.RosterRecommendationsChatButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][2] then                                         -- Show at Logon Button
            RosterLoadOnLogonCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][7] then                                         -- Add Timestamp to Officer on Join Button
            RosterAddTimestampCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][8] then
            RosterReportUpcomingEventsCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][10] then
            RosterRecommendKickCheckButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][11] then
            RosterReportInactiveReturnButton:SetChecked ( true );
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][12] then
            RosterReportUpcomingEventsCheckButtonDays:SetChecked ( true );
            RosterReportUpcomingEventsCheckButton:Show();
        else
            RosterReportUpcomingEventsCheckButton:Hide();
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][14] then
            RosterCheckBoxSideFrame.RosterSyncCheckButton:SetChecked ( true );
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Show();
        else
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Hide();
        end
        if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][16] then
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:SetChecked ( true );
        end


        -- Display Information
        if RosterKickRecommendEditBox:IsVisible() then
            RosterKickRecommendEditBox:Hide();
            RosterKickOverlayNote:Show();
        end
        if ReportInactiveReturnEditBox:IsVisible() then
            ReportInactiveReturnEditBox:Hide();
            ReportInactiveReturnOverlayNote:Show();
        end
        if RosterReportUpcomingEventsEditBox:IsVisible() then
            RosterReportUpcomingEventsEditBox:Hide();
            RosterReportUpcomingEventsOverlayNote:Show();
        end
        if RosterCheckBoxSideFrame.RosterSyncCheckButton:GetChecked() then
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Show();
        else
            RosterCheckBoxSideFrame.RosterNotifyOnChangesCheckButton:Hide();
        end
        -- Permissions... if not, disable button.
        if CanEditOfficerNote() then
            RosterAddTimestampCheckButton:Enable();
        else
            RosterAddTimestampCheckButton:Disable();
        end
        if CanEditGuildEvent() then
            RosterReportUpcomingEventsCheckButton:Enable();
        else
            RosterReportUpcomingEventsCheckButton:Disable();
        end
        if CanGuildRemove() then
            RosterRecommendKickCheckButton:Enable();
            RosterKickRecommendEditBox:Enable();
        else
            RosterRecommendKickCheckButton:Disable();
            RosterKickRecommendEditBox:Disable();
        end

        -- Get that Dropdown Menu Populated!
        GRM.CreateOptionsRankDropDown();
        -- Ok rebuild the log after changes!
        GRM.BuildLog();
    end);

    RosterCheckBoxSideFrame.TitleSideFrameText:SetPoint ( "TOP" , RosterCheckBoxSideFrame , 0 , -12 );
    RosterCheckBoxSideFrame.TitleSideFrameText:SetText ( "Display Changes" );
    RosterCheckBoxSideFrame.TitleSideFrameText:SetFont ( "Fonts\\FRIZQT__.TTF" , 12 );
    RosterCheckBoxSideFrame.ShowOnChatSideFrameText:SetPoint ( "TOPRIGHT" , RosterCheckBoxSideFrame , -14 , -28 );
    RosterCheckBoxSideFrame.ShowOnChatSideFrameText:SetText ( "To Chat:" );
    RosterCheckBoxSideFrame.ShowOnLogSideFrameText:SetPoint ( "TOPLEFT" , RosterCheckBoxSideFrame , 14 , -28 );
    RosterCheckBoxSideFrame.ShowOnLogSideFrameText:SetText ( "To Log:" );


end

-- Method:          GRM.AllRemainingNonDelayFrameInitialization()
-- What it Does:    Initializes general important frames that are not in relations to the guild roster window.
-- Purpose:         By walling this off, it allows far greater resource control rather than needing to initialize entire UI.
GRM.AllRemainingNonDelayFrameInitialization = function()
    
    UI_Events.NumGuildiesText:SetPoint ( "TOP" , RaidFrame , 0 , -32 );
    UI_Events.NumGuildiesText:SetFont ( "Fonts\\FRIZQT__.TTF" , 9 );
    UI_Events.NumGuildiesText:SetTextColor ( 0.0 , 0.8 , 1.0 , 1.0 );
    UI_Events:SetFrameStrata ( "HIGH" );

    UI_Events:RegisterEvent ( "UPDATE_INSTANCE_INFO" );
    UI_Events:RegisterEvent ( "GROUP_ROSTER_UPDATE" );   
    -- UI_Events:RegisterEvent ( "UPDATE_INSTANCE_INFO" );
    UI_Events:HookScript ( "OnEvent" , function( self , event )
        if ( event == "UPDATE_INSTANCE_INFO" or event == "GROUP_ROSTER_UPDATE" ) and not GR_AddonGlobals.RaidGCountBeingChecked then
            GR_AddonGlobals.RaidGCountBeingChecked = true;
            GRM.UpdateGuildMemberInRaidStatus();
        end
    end);

    RaidFrame:HookScript ( "OnHide" , function()
        UI_Events.NumGuildiesText:Hide();
    end);

end

-- Method:              GRM.GR_Roster_Click ( self, string )
-- What it Does:        For logic on mouseover, instead of mouseover, it simulates a click on the item by bringing it to show.
--                      The "pause" is just a call to pause the hiding of the frame in the GR_RosterFrame() function until it finds a new window (to prevent wasteful clicking and resource hogging)
-- Purpose:             Smoother UI interface in the built-in Guild Roster in-game UI default window.
GRM.GR_Roster_Click = function ( self , button )

    if button == "LeftButton" then
        GuildMemberDetailFrame:Hide();
        local time = GetTime();
        local length = 84;
        if GR_AddonGlobals.timer3 == 0 or time - GR_AddonGlobals.timer3 > 0.1 then   -- 100ms
            local name = "";        -- Copy Player Name - Just UX and QoL features!
            local MobileIconCheck = "";
            if GuildRosterContainerButton1:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton1String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton1String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton1String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton1String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton1String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton2:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton2String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton2String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton2String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton2String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton2String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton3:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton3String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton3String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton3String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton3String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton3String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton4:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton4String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton4String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton4String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton4String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton4String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton5:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton5String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton5String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton5String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton5String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton5String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton6:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton6String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton6String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton6String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton6String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton6String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton7:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton7String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton7String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton7String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton7String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton7String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton8:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton8String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton8String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton8String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton8String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton8String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton9:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton9String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton9String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton9String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton9String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton9String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton10:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton10String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton10String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton10String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton10String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton10String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton11:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton11String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton11String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton11String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton11String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton11String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton12:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton12String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton12String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton12String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton12String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton12String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton13:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton13String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton13String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton13String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton13String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton13String1:GetText();
                    end
                end
            elseif GuildRosterContainerButton14:IsMouseOver ( 1 , -1 , -1 , 1 ) then
                name = GuildRosterContainerButton14String1:GetText();
                if tonumber ( name ) ~= nil then
                    MobileIconCheck = "\"" .. GuildRosterContainerButton14String2:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton14String2:GetText();
                    end
                else
                    MobileIconCheck = "\"" .. GuildRosterContainerButton14String1:GetText() .. "\"";
                    if #MobileIconCheck > 50 then
                        if string.sub ( MobileIconCheck , length - 1 , length - 1 ) ~= "t" then
                            length = 85
                        end
                        name = string.sub ( MobileIconCheck , length , #MobileIconCheck - 1 );
                    else
                        name = GuildRosterContainerButton14String1:GetText();
                    end
                end
            end

            -- We are going to be copying the name if the shift key is down!
            if IsShiftKeyDown() then                        
                if ( AddAltEditFrame:IsVisible() and AddAltEditBox:HasFocus() ) or ( ChatFrame1EditBox:IsVisible() and ChatFrame1EditBox:HasFocus() ) then
                    
                    if ChatFrame1EditBox:HasFocus() then                -- Default Message Chat Frame!
                        ChatFrame1EditBox:SetText ( name );
                    elseif AddAltEditBox:HasFocus() then                -- No No! Send to the altadd frame!
                        if name == GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
                            print ( GRM.SlimName ( name ) .. " cannot add themselves to alt list!" );  
                        else
                            AddAltEditBox:SetText ( name );
                            GRM.AddAltAutoComplete();
                        end
                    end                
                end
            else
                if GR_AddonGlobals.pause and name ~= GRM.GetMobileFreeName ( GuildMemberDetailName:GetText() ) then
                    GR_AddonGlobals.pause = false;
                    GR_RosterFrame ( _ , 0.075 );           -- Activate one time.
                    GR_AddonGlobals.pause = true;
                else
                    GR_AddonGlobals.pause = true;
                end
            end
            GR_AddonGlobals.timer3 = time;
        end
    end
end

-- SLASH COMMAND LOGIC
SlashCmdList["GRM"] = function ( input )
    -- if input is invalid or is just a blank info... print details on addon.
    if input == nil or input:trim() == "" then    
        if IsInGuild() and RosterChangeLogFrame ~= nil and not RosterChangeLogFrame:IsVisible() then
            RosterChangeLogFrame:Show();
        elseif RosterChangeLogFrame ~= nil and RosterChangeLogFrame:IsVisible() then
            RosterChangeLogFrame:Hide();
        elseif not IsInGuild() then
            print ( GRM.SlimName( GR_AddonGlobals.addonPlayerName ) .. " is not currently in a guild. No log to view!" );
        elseif RosterChangeLogFrame == nil then
            print ( "Please try again momentarily... Updating the Guild Event Log as we speak!" );
        end
    -- Clears all saved data and resets to as if the addon was just installed. The only thing not reset is the default settings.
    elseif string.lower ( input ) == "clearall" then 
        GRM.ResetAllSavedData();
   
    -- List of all the slash commands at player's disposal.
    elseif string.lower ( input ) == "help" then
        print ( "\nGuild Roster Manager\nVer: " .. Version .. "\n\n/roster                     - Opens Guild Log Window\n/roster clearall        - Resets ALL saved data, like it was just installed.\n/roster reset            - Re-centers the Log window to the middle of the screen" );
    
    -- Resets the poisition of the window back to the center.
    elseif string.lower ( input ) == "reset" then
        RosterChangeLogFrame:ClearAllPoints();
        RosterChangeLogFrame:SetPoint ( "CENTER" , UIParent );
        AddEventFrame:ClearAllPoints();
        AddEventFrame:SetPoint ( "CENTER" , UIParent );

    -- FOR FUN!!!
    elseif string.lower ( input ) == "hail" then
        print ( "SUBATOMIC PVP IS THE BEST GUILD OF ALL TIME!\nArkaan is SEXY! Mmmm Arkaan!" );
    -- Invalid slash command.
    else
        print ( "Invalid Command: Please type '/roster help' for More Info!" );
    end
end


-- Method:              GRM.InitiateMemberDetailFrame(self,event,msg)
-- What it Does:        Event Listener, it activates when the Guild Roster window is opened and interface is queried/triggered
--                      "GuildRoster()" needs to fire for this to activate as it creates the following 4 listeners this is looking for: GUILD_NEWS_UPDATE, GUILD_RANKS_UPDATE, GUILD_ROSTER_UPDATE, and GUILD_TRADESKILL_UPDATE
-- Purpose:             Create an Event Listener for the Guild Roster Frame in the guild window ('J' key)
GRM.InitiateMemberDetailFrame = function ()

    if not GR_AddonGlobals.FramesInitialized and GuildFrame ~= nil then
        
        -- Member Detail Frame Info
        GRM.GR_MetaDataInitializeUIFirst(); -- Initializing Frames
        GRM.GR_MetaDataInitializeUISecond(); -- To avoid 60 upvalue Lua cap, place them in second list.
        GRM.GR_MetaDataInitializeUIThird(); -- Also, to avoid another 60 upvalues!
        if not GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][2] then
            GRM.MetaDataInitializeUIrosterLog1();   -- 60 more upvalues :D
            GRM.MetaDataInitializeUIrosterLog2();   -- Wrapping up!
        end

        -- Roster Positions
        GuildRosterFrame:HookScript ( "OnUpdate" , GR_RosterFrame );
        
        -- For mouseover logic on all these buttons... using /click since there is not "OnMouseover" setscript function... on update (each frame) > if Mouseover > Click
        GuildRosterContainerButton1:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton2:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton3:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton4:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton5:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton6:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton7:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton8:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton9:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton10:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton11:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton12:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton13:HookScript ( "OnClick" , GRM.GR_Roster_Click );
        GuildRosterContainerButton14:HookScript ( "OnClick" , GRM.GR_Roster_Click );

        -- One time button placement ( rest will be determined on the OnUpdate for Roster Frame )
        
        GuildRosterFrame:HookScript ( "OnShow" , function( self )
            LoadLogButton:Show();
        end);
         
        -- Exit loop
        UI_Events:UnregisterEvent ( "GUILD_ROSTER_UPDATE" );
        UI_Events:UnregisterEvent ( "GUILD_RANKS_UPDATE" );
        UI_Events:UnregisterEvent ( "GUILD_NEWS_UPDATE" );
        UI_Events:UnregisterEvent ( "GUILD_TRADESKILL_UPDATE" );
    end
end



------------------------------------------------
------------------------------------------------
----- INITIALIZATION AND LIVE TRACKING ---------
------------------------------------------------
------------------------------------------------

-- Method:          GRM.TriggerTrackingCheck()
-- What it Does:    Helps regulate some resource and timed efficient server queries, 
-- Purpose:         to keep from spamming or double+ looping functions.
GRM.TriggerTrackingCheck = function()
    GR_AddonGlobals.trackingTriggered = false;
    QueryGuildEventLog();
    GuildRoster();
end

-- Method:          Tracking()
-- What it Does:    Checks the Roster once in a repeating time interval as long as player is in a guild
-- Purpose:         Constant checking for roster changes. Flexibility in timing changes. Default set to 10 now, could be 30 or 60.
--                  Keeping local
local function Tracking()
    if IsInGuild() and not GR_AddonGlobals.trackingTriggered then
        GR_AddonGlobals.trackingTriggered = true;
        local timeCallJustOnce = time();
        if GR_AddonGlobals.timeDelayValue == 0 or (timeCallJustOnce - GR_AddonGlobals.timeDelayValue ) > 5 then -- Initial scan is zero.
            GR_AddonGlobals.guildName = GetGuildInfo ( "PLAYER" );
            GR_AddonGlobals.timeDelayValue = timeCallJustOnce;

            -- Need to doublecheck Faction Index ID
            if GR_AddonGlobals.faction == 0 then
                if GR_AddonGlobals.faction == "Horde" then
                    GR_AddonGlobals.FID = 1;
                elseif GR_AddonGlobals.faction == "Alliance" then
                    GR_AddonGlobals.FID = 2;
                end
            end

            -- Need to doublecheck guild Index ID
            if GR_AddonGlobals.logGID == 0 then
                for i = 2 , #GRM_LogReport_Save[GR_AddonGlobals.FID] do
                    if GRM_LogReport_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.guildName then
                        GR_AddonGlobals.logGID = i;
                        break;
                    end
                end
            end

            -- Need to do the same for save index ID
            if GR_AddonGlobals.saveGID == 0 then
                for i = 2 , #GRM_CalendarAddQue_Save[GR_AddonGlobals.FID] do
                    if GRM_CalendarAddQue_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.guildName then
                        GR_AddonGlobals.saveGID = i;
                        break;
                    end
                end
            end

            -- for Settings
            if GR_AddonGlobals.setPID == 0 then
                for i = 2 , #GRM_AddonSettings_Save[GR_AddonGlobals.FID] do
                    if GRM_AddonSettings_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.addonPlayerName then
                        GR_AddonGlobals.setPID = i;
                        break;
                    end
                end
            end

            -- Checking Roster, tracking changes
            GRM.BuildNewRoster();
            -- Seeing if any upcoming notable events, like anniversaries/birthdays
            GRM.CheckPlayerEvents( GR_AddonGlobals.guildName );
            -- Printing Report, and sending report to log.
            GRM.FinalReport();
            -- Prevent from re-scanning changes
            -- On first load, bring up window.
            if GR_AddonGlobals.OnFirstLoad then
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][2] then
                    GRM.MetaDataInitializeUIrosterLog1();
                    GRM.MetaDataInitializeUIrosterLog2();
                    RosterChangeLogFrame:Show();
                end
                GR_AddonGlobals.OnFirstLoad = false;
                -- MISC frames to be loaded immediately, not on delay
                GRM.AllRemainingNonDelayFrameInitialization();
            end
        end
        GuildRoster();
        C_Timer.After( GRM_AddonSettings_Save[GR_AddonGlobals.FID][GR_AddonGlobals.setPID][2][6] , GRM.TriggerTrackingCheck ); -- Recursive check every X seconds.
    else
        GR_AddonGlobals.currentlyTracking = false;
    end
end

-- Method:          GRM.GR_LoadAddon()
-- What it Does:    Enables tracking of when a player joins the guild or leaves the guild. Also fires upon login.
-- Purpose:         Manage tracking guild info. No need if player is not in guild, or to reactivate when player joins guild.
GRM.GR_LoadAddon = function()
    GeneralEventTracking:RegisterEvent ( "PLAYER_GUILD_UPDATE" ); -- If player leaves or joins a guild, this should fire.
    GeneralEventTracking:SetScript ( "OnEvent" , GRM.ManageGuildStatus );

    -- The following event registartion is purely for UI registeration and activation... General tracking does not need the UI, but guildFrame should be visible bnefore triggering
    -- Each of the following events might trigger on event update.
    UI_Events:RegisterEvent ( "GUILD_ROSTER_UPDATE" );
    UI_Events:RegisterEvent ( "GUILD_RANKS_UPDATE" );
    UI_Events:RegisterEvent ( "GUILD_NEWS_UPDATE" );
    UI_Events:RegisterEvent ( "GUILD_TRADESKILL_UPDATE" );
    UI_Events:RegisterEvent ( "GUILD_EVENT_LOG_UPDATE" );
    UI_Events:SetScript ( "OnEvent" , function ( self , event )
        if event == "GUILD_EVENT_LOG_UPDATE" then
            Tracking();
        elseif event ~= "UPDATE_INSTANCE_INFO" then
            GRM.InitiateMemberDetailFrame();
        end
    end);
    QueryGuildEventLog();
    GuildRoster();

    -- Establish Message Sharing as well!
    GRMsync.Initialize();
end

-- Method           GRM.ManageGuildStatus()
-- What it Does:    If player leaves or joins the guild, it deactivates/reactivates tracking - as well as re-checks guild to see if rejoining or new guild.    
-- Purpose:         Efficiency in resource use to prevent unnecessary tracking of info if out of the guild.
GRM.ManageGuildStatus = function ( self , event )
    GeneralEventTracking:UnregisterEvent ( "PLAYER_GUILD_UPDATE" );
    if GR_AddonGlobals.guildStatusChecked ~= true then
       GR_AddonGlobals.timeDelayValue = time(); -- Prevents it from doing "IsInGuild()" too soon by resetting timer as server reaction is slow.
    end
    if GR_AddonGlobals.timeDelayValue == 0 or ( time() - GR_AddonGlobals.timeDelayValue ) > 3 then -- Let's do a recheck on guild status to prevent unnecessary scanning.
        if IsInGuild() then
            if GR_AddonGlobals.DelayedAtLeastOnce then
                GR_AddonGlobals.guildName = GetGuildInfo ( "PLAYER" );
                if not GR_AddonGlobals.currentlyTracking then
                    GuildRoster();
                    QueryGuildEventLog();
                    GRMsync.Initialize();
                    C_Timer.After ( 5 , Tracking );         -- Delay is for player to re-register the new guild info.
                end
            else
                GR_AddonGlobals.DelayedAtLeastOnce = true;
                C_Timer.After ( 2 , GRM.ManageGuildStatus );
            end
        else
            GR_AddonGlobals.guildName = nil;
            GR_AddonGlobals.DelayedAtLeastOnce = false;
            if GRMsync.MessageTracking ~= nil then
                GRMsync.MessageTracking:UnregisterAllEvents()
            end
            print( GRM.SlimName( GR_AddonGlobals.addonPlayerName ) .. " is Not in a Guild! Disabling Log Tracking..." ); -- Store the data.
            RosterChangeLogFrame:Hide();
            if not GR_AddonGlobals.currentlyTracking then
                GRM.GR_LoadAddon();
            end
        end
        GeneralEventTracking:RegisterEvent ( "PLAYER_GUILD_UPDATE" );
        GR_AddonGlobals.guildStatusChecked = false;
    else
        GR_AddonGlobals.guildStatusChecked = true;
        C_Timer.After ( 5 , GRM.ManageGuildStatus ); -- Recursively re-check on guild status trigger.
    end
end

-- Method:          ActivateAddon( self , string , string )
-- What it Does:    First, doesn't trigger to load until all variables of addon fully loaded.
--                  Then, it triggers to delay until player is fully in the world, in that order.
--                  Finally, it delays 5 seconds upon querying server as often initial Roster and Guild Event Log query takes a moment to return info.
-- Purpose:         To ensure the smooth handling and loading of the addon so all information is accurate before attempting to parse guild info.
function ActivateAddon ( self , event , addon )
    if event == "ADDON_LOADED" then
    -- initiate addon once all variable are loaded.
        if addon == GR_AddonGlobals.addonName then
            Initialization:RegisterEvent ( "PLAYER_ENTERING_WORLD" ); -- Ensures this check does not occur until after Addon is fully loaded. By registering, it acts recursively throug hthis method
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Initialize load settings! Don't need to be in a guild for this!
        -- Setting the index of the player's faction.
        if GR_AddonGlobals.faction == nil then
            GR_AddonGlobals.faction = UnitFactionGroup ( "PLAYER" );
        end

        if GR_AddonGlobals.faction == "Horde" then
            GR_AddonGlobals.FID = 1;
        else
            GR_AddonGlobals.FID = 2;
        end

        GRM.LoadSettings();
        
        -- Must get PID immediately after.
        if GR_AddonGlobals.setPID == 0 then
            for i = 2 , #GRM_AddonSettings_Save[GR_AddonGlobals.FID] do
                if GRM_AddonSettings_Save[GR_AddonGlobals.FID][i][1] == GR_AddonGlobals.addonPlayerName then
                    GR_AddonGlobals.setPID = i;
                    break;
                end
            end
        end

        if IsInGuild() then
            Initialization:UnregisterEvent ("PLAYER_ENTERING_WORLD");
            Initialization:UnregisterEvent ("ADDON_LOADED");     -- no need to keep scanning these after full loaded. 
            -- Setting the index of the player's guild         
            for i = 2 , #GRM_LogReport_Save[GR_AddonGlobals.FID] do
                if GRM_LogReport_Save[GR_AddonGlobals.FID][i][1] == GetGuildInfo ( "PLAYER" ) then
                    GR_AddonGlobals.logGID = i;
                    break;
                end
            end
            GuildRoster();                                     -- Initial queries...
            QueryGuildEventLog();
            C_Timer.After ( 2 , GRM.GR_LoadAddon );                 -- Queries do not return info immediately, gives server a 5 second delay.
        else
            GRM.ManageGuildStatus();
        end
    end
end

-- Initialize the first frames as game is being loaded.
GRM.PreAddonLoadUI();
Initialization:RegisterEvent ( "ADDON_LOADED" );
Initialization:SetScript ( "OnEvent" , ActivateAddon );




   
    -- Export to PDF
    -- Export to TXT
    -- Export to Excel?


    -------------------------------------   
    ----- FEATURES TO BE ADDED NEXT!! ---
    -------------------------------------

    -- Drop down menu on the Log Frame allowing you to choose which log to view, from any character, any faction you have... just the log. (maybe I will include maybe not. Seems mostly useless for high time effort)
    -- Guild achievement and loot NEWS window could be parsed for interesting info
    -- Customize notifications for guild promotions! ********** Big To-Do Project.
    -- BIRTHDAYS
    -- Custom Reminders
    -- Search of the History Window
    -- GUILD EVENT INFO -- Potential huge feature to add
            -- GUILD EVENT AND RAID GROUP INFO
            -- Mark attendance for all in raid +1
            -- Request Assist Button  -- Requests assist from raid leader 
            -- Invite everyone online to guild group
            -- On rank promotion, change the text right away!
            -- Add method that increments up by 1 a tracker on num events attended, the date, total events attended, for each person that is in the raid group.
    -- INTERESTING GUILD STATISTICS
        -- Like number of legendaries collected this weekly
        -- Notable achievements, like Prestige advancements
        -- If players have obtained recent impressive titles (100k or 250k kills, battlemaster)
        -- Total number of guild battlemasters
        -- Total number of guildies with certain achievements
        -- Notable high ilvl notifications with adjustable threshold to trigger it
    -- MAGIC TOOL BOX for guild leader
        -- useful tools only guild leader can see...

    -------------------------------------
    ----- KNOWN BUGS --------------------
    ------------------------------------

    -- Kick Inactives reminder not working
    -- In some instances it is reporting a player as demoted, and to the wrong rank
    -- Line 2915, got a bug from something, a leaving player perhaps? Log report will it consider full player-server name?
    -- Still unidentified bug crashing report, seems to be related to leaving players.

    -------------------------------------
    ----- Minor BUSY work ---------------
    -------------------------------------
    -- Fix scaling issue on the options panel by creating addtl. fontstrings.
    -- Change all the names of the frames to start with GRM_
    -- Notifications option for receiving notification when other players update the data.
    -- Create Viewable BAN window.
    -- GRM.ClearPermData() - Special notification to player as to why data being wiped
    -- Popup confirm window should be fullscreen strata
    -- "Reason for ban" should be wrapped.
    -- Check width of the name, if greater than desired gap width, then scale it down a little.
    -- Guild Namechange needs to be tested.
    -- Logentry, if player joins a new guild it breaks a couple of spaces in the entry, reports guild nameChange, with NEW guild name in center, then breaks a few more spaces. #Aesthetics

    -------------------------------------
    ----- POTENTIAL FEATURES ------------
    -------------------------------------
    
    -- Sort guild roster by "Time in guild" - possible in built-in UI? - need to complete "Total time in the guild".
    -- If there is a guild Request to join, this notifies that that exists...
    -- What player is currently doing, if online "Raiding" or "PVPing" or whatever... Logs that track how long the player has been in current zone.
    -- On syncing checkbox YES, on checking the box, add Event Listening register
    -- On NO, just unregister All Events!

--- Changelog
