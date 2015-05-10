#define PLUGIN_VERSION		"1.4"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Plane Crash
*	Author	:	SilverShot
*	Descrp	:	Creates the Dead Air Plane Crash on any map.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=181517

========================================================================================
	Change Log:

1.4 (30-Jun-2012)
	- Added cvar "l4d_plane_crash_clear" to remove the plane crash after it stops moving.
	- Command "sm_crash" changed to "sm_plane".
	- Command "sm_crash_clear" changed to "sm_plane_clear".
	- Command "sm_crash_time" changed to "sm_plane_time".
	- Fixed the plane crash not being created when the server starts.

1.3 (10-May-2012)
	- Added "Show Saved Crash" and "Clear Crash" to the menu.

1.2 (01-Apr-2012)
	- Really fixed cvar "l4d_plane_crash_damage" not working.

1.1 (01-Apr-2012)
	- Added command "sm_crash_clear" to clear crashes from the map (does not delete from the config).
	- Added cvar "l4d_plane_crash_angle" to control if the plane spawns infront or crashes infront.
	- Fixed cvar "l4d_plane_crash_damage" not working.

1.0 (30-Mar-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 			1

#include <sdktools>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define CHAT_TAG			"\x03[PlaneCrash] \x05"
#define CONFIG_SPAWNS		"data/l4d_plane_crash.cfg"
#define MAX_ENTITIES		25

#define MODEL_PLANE01		"models/hybridphysx/precrash_airliner.mdl"
#define MODEL_PLANE02		"models/hybridphysx/airliner_fuselage_secondary_1.mdl"
#define MODEL_PLANE03		"models/hybridphysx/airliner_fuselage_secondary_2.mdl"
#define MODEL_PLANE04		"models/hybridphysx/airliner_fuselage_secondary_3.mdl"
#define MODEL_PLANE05		"models/hybridphysx/airliner_fuselage_secondary_4.mdl"
#define MODEL_PLANE06		"models/hybridphysx/airliner_left_wing_secondary.mdl"
#define MODEL_PLANE07		"models/hybridphysx/airliner_right_wing_secondary_1.mdl"
#define MODEL_PLANE08		"models/hybridphysx/airliner_right_wing_secondary_2.mdl"
#define MODEL_PLANE09		"models/hybridphysx/airliner_tail_secondary.mdl"
#define MODEL_PLANE10		"models/hybridphysx/airliner_primary_debris_4.mdl"
#define MODEL_PLANE11		"models/hybridphysx/airliner_primary_debris_1.mdl"
#define MODEL_PLANE12		"models/hybridphysx/airliner_primary_debris_2.mdl"
#define MODEL_PLANE13		"models/hybridphysx/airliner_primary_debris_3.mdl"
#define MODEL_PLANE14		"models/hybridphysx/airliner_fire_emit1.mdl"
#define MODEL_PLANE15		"models/hybridphysx/airliner_fire_emit2.mdl"
#define MODEL_PLANE16		"models/hybridphysx/airliner_sparks_emit.mdl"
#define MODEL_PLANE17		"models/hybridphysx/airliner_endstate_vcollide_dummy.mdl"
#define MODEL_BOUNDING		"models/props/cs_militia/silo_01.mdl"
#define SOUND_CRASH			"animation/airport_rough_crash_seq.wav"

static	Handle:g_hMPGameMode, Handle:g_hCvarAllow, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog, bool:g_bCvarAllow,
		Handle:g_hCvarDamage, Handle:g_hCvarHorde, Handle:g_hCvarTime, Handle:g_hCvarAngle, Handle:g_hCvarClear, 
		g_iCvarAngle, g_iCvarClear, g_iCvarDamage, g_iCvarHorde, Float:g_fCvarTime,
		Handle:g_hTimerBeam, Handle:g_hMenuVMaxs, Handle:g_hMenuVMins, Handle:g_hMenuPos,
		g_iEntities[MAX_ENTITIES], g_iTrigger, g_iLaserMaterial, g_iHaloMaterial,
		bool:g_bLeft4Dead2, bool:g_bLoaded, g_iPlayerSpawn, g_iRoundStart, g_iSaved;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D & L4D2] Plane Crash",
	author = "SilverShot",
	description = "Creates the Dead Air Plane Crash on any map.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=181517"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead", false) == 0 ) g_bLeft4Dead2 = false;
	else if( strcmp(sGameName, "left4dead2", false) == 0 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d_plane_crash_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarAngle =			CreateConVar(	"l4d_plane_crash_angle",		"1",			"0=Spawn the plane infront of you (crashes to the left), 1=Spawn so the plane crashes infront of you.", CVAR_FLAGS );
	g_hCvarClear =			CreateConVar(	"l4d_plane_crash_clear",		"0",			"0=Off, Remove the plane crash this many seconds after the plane hits the ground.", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d_plane_crash_damage",		"20",			"0=Off, Other value will hurt players if they get crushed by some debris.", CVAR_FLAGS );
	g_hCvarHorde =			CreateConVar(	"l4d_plane_crash_horde",		"24",			"0=Off, Trigger a panic event this many seconds after the plane spawns.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_plane_crash_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_plane_crash_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarModesTog =	CreateConVar(	"l4d_plane_crash_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarTime =			CreateConVar(	"l4d_plane_crash_time",			"0",			"0=Off, Otherwise creates a crash this many seconds after round start (triggers and custom map times override this cvar).", CVAR_FLAGS );
	CreateConVar(							"l4d_plane_crash_version",		PLUGIN_VERSION, "Plane Crash plugin version.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_plane_crash");

	g_hMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hMPGameMode,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	if( g_bLeft4Dead2 )
		HookConVarChange(g_hCvarModesTog,	ConVarChanged_Allow);
	HookConVarChange(g_hCvarAngle,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarClear,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarDamage,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarHorde,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarTime,			ConVarChanged_Cvars);

	RegAdminCmd("sm_plane",			CmdPlaneMenu,	ADMFLAG_ROOT,	"Displays a menu with options to show/save a crash and triggers.");
	RegAdminCmd("sm_plane_clear",	CmdPlaneClear,	ADMFLAG_ROOT,	"Clears crashes from the map (does not delete from the config).");
	RegAdminCmd("sm_plane_time",	CmdPlaneTime,	ADMFLAG_ROOT,	"Sets the time after round start to show a saved crash. sm_plane_time 0 removes the time trigger.");

	g_hMenuVMaxs = CreateMenu(VMaxsMenuHandler);
	AddMenuItem(g_hMenuVMaxs, "", "10 x 10 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "25 x 25 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "50 x 50 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "100 x 100 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "150 x 150 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "200 x 200 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "250 x 250 x 100");
	SetMenuTitle(g_hMenuVMaxs, "PlaneCrash - Trigger VMaxs");
	SetMenuExitBackButton(g_hMenuVMaxs, true);

	g_hMenuVMins = CreateMenu(VMinsMenuHandler);
	AddMenuItem(g_hMenuVMins, "", "-10 x -10 x 0");
	AddMenuItem(g_hMenuVMins, "", "-25 x -25 x 0");
	AddMenuItem(g_hMenuVMins, "", "-50 x -50 x 0");
	AddMenuItem(g_hMenuVMins, "", "-100 x -100 x 0");
	AddMenuItem(g_hMenuVMins, "", "-150 x -150 x 0");
	AddMenuItem(g_hMenuVMins, "", "-200 x -200 x 0");
	AddMenuItem(g_hMenuVMins, "", "-250 x -250 x 0");
	SetMenuTitle(g_hMenuVMins, "PlaneCrash - Trigger VMins");
	SetMenuExitBackButton(g_hMenuVMins, true);

	g_hMenuPos = CreateMenu(PosMenuHandler);
	AddMenuItem(g_hMenuPos, "", "X + 1.0");
	AddMenuItem(g_hMenuPos, "", "Y + 1.0");
	AddMenuItem(g_hMenuPos, "", "Z + 1.0");
	AddMenuItem(g_hMenuPos, "", "X - 1.0");
	AddMenuItem(g_hMenuPos, "", "Y - 1.0");
	AddMenuItem(g_hMenuPos, "", "Z - 1.0");
	AddMenuItem(g_hMenuPos, "", "SAVE");
	SetMenuTitle(g_hMenuPos, "PlaneCrash - Set Origin");
	SetMenuExitBackButton(g_hMenuPos, true);
}

public OnPluginEnd()
{
	ResetPlugin();
}

public OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");

	PrecacheModel(MODEL_PLANE01, true);
	PrecacheModel(MODEL_PLANE02, true);
	PrecacheModel(MODEL_PLANE03, true);
	PrecacheModel(MODEL_PLANE04, true);
	PrecacheModel(MODEL_PLANE05, true);
	PrecacheModel(MODEL_PLANE06, true);
	PrecacheModel(MODEL_PLANE07, true);
	PrecacheModel(MODEL_PLANE08, true);
	PrecacheModel(MODEL_PLANE09, true);
	PrecacheModel(MODEL_PLANE10, true);
	PrecacheModel(MODEL_PLANE11, true);
	PrecacheModel(MODEL_PLANE12, true);
	PrecacheModel(MODEL_PLANE13, true);
	PrecacheModel(MODEL_PLANE14, true);
	PrecacheModel(MODEL_PLANE15, true);
	PrecacheModel(MODEL_PLANE16, true);
	PrecacheModel(MODEL_PLANE17, true);
	PrecacheModel(MODEL_BOUNDING, true);

	PrecacheSound(SOUND_CRASH, true);
}

public OnMapEnd()
{
	ResetPlugin();
}

ResetPlugin()
{
	new entity = g_iEntities[0];
	g_iEntities[0] = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bLoaded = false;

	if( IsValidEntRef(entity) )
	{
		AcceptEntityInput(entity, "CancelPending");
		AcceptEntityInput(entity, "Disable");
		SetVariantString("OnUser1 !self:Kill::1.0:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}

	entity = g_iEntities[1];
	g_iEntities[1] = 0;
	if( IsValidEntRef(entity) )
	{
		SetVariantInt(0);
		AcceptEntityInput(entity, "Volume");
		AcceptEntityInput(entity, "Kill");
	}

	for( new i = 1; i < MAX_ENTITIES; i++ )
	{
		if( IsValidEntRef(g_iEntities[i]) )
			AcceptEntityInput(g_iEntities[i], "Kill");
		g_iEntities[i] = 0;
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
	IsAllowed();

public ConVarChanged_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
	GetCvars();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

GetCvars()
{
	g_iCvarAngle = GetConVarInt(g_hCvarAngle);
	g_iCvarClear = GetConVarInt(g_hCvarClear);
	g_iCvarDamage = GetConVarInt(g_hCvarDamage);
	g_iCvarHorde = GetConVarInt(g_hCvarHorde);
	g_fCvarTime = GetConVarFloat(g_hCvarTime);
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		CreateCrash(0);
		g_bCvarAllow = true;
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hMPGameMode == INVALID_HANDLE )
		return false;

	if( g_bLeft4Dead2 )
	{
		new iCvarModesTog = GetConVarInt(g_hCvarModesTog);
		if( iCvarModesTog != 0 )
		{
			g_iCurrentMode = 0;

			new entity = CreateEntityByName("info_gamemode");
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			AcceptEntityInput(entity, "PostSpawnActivate");
			AcceptEntityInput(entity, "Kill");

			if( g_iCurrentMode == 0 )
				return false;

			if( !(iCvarModesTog & g_iCurrentMode) )
				return false;
		}
	}

	decl String:sGameModes[64], String:sGameMode[64];
	GetConVarString(g_hMPGameMode, sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	GetConVarString(g_hCvarModes, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	GetConVarString(g_hCvarModesOff, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public OnGamemode(const String:output[], caller, activator, Float:delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetPlugin();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
	{
		CreateTimer(1.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iRoundStart = 1;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
	{
		CreateTimer(1.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iPlayerSpawn = 1;
}

public Action:TimerLoad(Handle:timer)
{
	if( g_bLoaded )	return;
	g_bLoaded = true;
	CreateCrash(0);
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action:CmdPlaneClear(client, args)
{
	ResetPlugin();
	if( client )
		PrintToChat(client, "%sCleared from this map.", CHAT_TAG);
	else
		PrintToChat(client, "[PlaneCrash] Cleared from this map.");
	return Plugin_Handled;
}

public Action:CmdPlaneTime(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[PlaneCrash] Command can only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( args != 1 )
	{
		PrintToChat(client, "%sUsage: sm_plane_time <number of seconds, 0 removes time trigger>", CHAT_TAG);
		return Plugin_Handled;
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( FileExists(sPath) )
	{
		new Handle:hFile = CreateKeyValues("crash");
		FileToKeyValues(hFile, sPath);

		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( KvJumpToKey(hFile, sMap) )
		{
			decl String:sTemp[8];
			GetCmdArg(1, sTemp, sizeof(sTemp));
			new value = StringToInt(sTemp);

			if( value == 0 )
			{
				KvDeleteKey(hFile, "time");
				PrintToChat(client, "%sRemoved time trigger.", CHAT_TAG);
			}
			else
			{
				KvSetNum(hFile, "time", value);
				PrintToChat(client, "%sSaved number of seconds until the plane crash is triggered.", CHAT_TAG);
			}

			KvRewind(hFile);
			KeyValuesToFile(hFile, sPath);
		}
		else
		{
			PrintToChat(client, "%sNone saved to this map.", CHAT_TAG);
		}

		CloseHandle(hFile);
	}

	return Plugin_Handled;
}

public Action:CmdPlaneMenu(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[PlaneCrash] Command can only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	ShowMenuMain(client);
	return Plugin_Handled;
}

ShowMenuMain(client)
{
	new Handle:hMenu = CreateMenu(MainMenuHandler);
	AddMenuItem(hMenu, "1", "Temp Crash");

	if( g_iSaved )
	{
		AddMenuItem(hMenu, "2", "Delete Crash");
	}
	else
	{
		AddMenuItem(hMenu, "2", "Save Crash");
	}

	AddMenuItem(hMenu, "3", "Show Saved Crash");
	AddMenuItem(hMenu, "4", "Clear Crash");

	if( IsValidEntRef(g_iTrigger) )
	{
		AddMenuItem(hMenu, "5", "Trigger Delete");
		if( g_hTimerBeam == INVALID_HANDLE )
			AddMenuItem(hMenu, "6", "Trigger Show");
		else
			AddMenuItem(hMenu, "6", "Trigger Hide");
		AddMenuItem(hMenu, "7", "Trigger VMaxs");
		AddMenuItem(hMenu, "8", "Trigger VMins");
		AddMenuItem(hMenu, "9", "Trigger Origin");
	}
	else
	{
		AddMenuItem(hMenu, "5", "Trigger Create");
	}
	SetMenuTitle(hMenu, "Plane Crash");

	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MainMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Select )
	{
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( index == 1 )
		{
			CreateCrash(client);
			ShowMenuMain(client);
		}
		else if( index == 2 )
		{
			SaveCrash(client);
			ShowMenuMain(client);
		}
		else if( index == 3 )
		{
			if( IsValidEntRef(g_iEntities[0]) )
				AcceptEntityInput(g_iEntities[0], "Trigger");
			else
			{
				CreateCrash(0);
				if( IsValidEntRef(g_iEntities[0]) )
					AcceptEntityInput(g_iEntities[0], "Trigger");
				else
					PrintToChat(client, "%sNo saved plane crash", CHAT_TAG);
			}
			ShowMenuMain(client);
		}
		else if( index == 4 )
		{
			ResetPlugin();
			ShowMenuMain(client);
		}
		else if( index == 5 )
		{
			CreateTrigger(client);
			ShowMenuMain(client);
		}
		else if( index == 6 )
		{
			if( g_hTimerBeam == INVALID_HANDLE )
			{
				g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
			}
			else
			{
				CloseHandle(g_hTimerBeam);
				g_hTimerBeam = INVALID_HANDLE;
			}

			ShowMenuMain(client);
		}
		else if( index == 7 )
		{
			DisplayMenu(g_hMenuVMaxs, client, MENU_TIME_FOREVER);
		}
		else if( index == 8 )
		{
			DisplayMenu(g_hMenuVMins, client, MENU_TIME_FOREVER);
		}
		else if( index == 9 )
		{
			DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
		}
	}
}

public VMaxsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(1, Float:{ 10.0, 10.0, 100.0 });
		else if( index == 1 )
			SaveMaxMin(1, Float:{ 25.0, 25.0, 100.0 });
		else if( index == 2 )
			SaveMaxMin(1, Float:{ 50.0, 50.0, 100.0 });
		else if( index == 3 )
			SaveMaxMin(1, Float:{ 100.0, 100.0, 100.0 });
		else if( index == 4 )
			SaveMaxMin(1, Float:{ 150.0, 150.0, 100.0 });
		else if( index == 5 )
			SaveMaxMin(1, Float:{ 200.0, 200.0, 100.0 });
		else if( index == 6 )
			SaveMaxMin(1, Float:{ 300.0, 300.0, 100.0 });

		ShowMenuMain(client);
	}
}

public VMinsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(2, Float:{ -10.0, -10.0, 0.0 });
		else if( index == 1 )
			SaveMaxMin(2, Float:{ -25.0, -25.0, 0.0 });
		else if( index == 2 )
			SaveMaxMin(2, Float:{ -50.0, -50.0, 0.0 });
		else if( index == 3 )
			SaveMaxMin(2, Float:{ -100.0, -100.0, 0.0 });
		else if( index == 4 )
			SaveMaxMin(2, Float:{ -150.0, -150.0, 0.0 });
		else if( index == 5 )
			SaveMaxMin(2, Float:{ -200.0, -200.0, 0.0 });
		else if( index == 6 )
			SaveMaxMin(2, Float:{ -300.0, -300.0, 0.0 });

		ShowMenuMain(client);
	}
}

public PosMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		decl Float:vPos[3];
		GetEntPropVector(g_iTrigger, Prop_Send, "m_vecOrigin", vPos);

		if( index == 0 )
			vPos[0] += 1.0;
		else if( index == 1 )
			vPos[1] += 1.0;
		else if( index == 2 )
			vPos[2] += 1.0;
		else if( index == 3 )
			vPos[0] -= 1.0;
		else if( index == 4 )
			vPos[1] -= 1.0;
		else if( index == 5 )
			vPos[2] -= 1.0;

		if( index != 6 )
		{
			TeleportEntity(g_iTrigger, vPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			decl String:sPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
			if( !FileExists(sPath) )
				return;

			new Handle:hFile = CreateKeyValues("crash");
			FileToKeyValues(hFile, sPath);

			decl String:sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( KvJumpToKey(hFile, sMap, true) )
			{
				KvSetVector(hFile, "vpos", vPos);

				KvRewind(hFile);
				KeyValuesToFile(hFile, sPath);
				PrintToChat(client, "%sSaved trigger origin.", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%sCould not save trigger origin.", CHAT_TAG);
			}

			CloseHandle(hFile);
		}

		DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
	}
}

SaveCrash(client)
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( g_iSaved )
	{
		g_iSaved = 0;
		ResetPlugin();

		if( FileExists(sPath) )
		{
			new Handle:hFile = CreateKeyValues("crash");
			FileToKeyValues(hFile, sPath);

			decl String:sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( KvJumpToKey(hFile, sMap) )
			{
				KvDeleteKey(hFile, "ang");
				KvDeleteKey(hFile, "pos");

				KvRewind(hFile);
				KeyValuesToFile(hFile, sPath);

				PrintToChat(client, "%sRemoved from this map.", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%sNone saved to this map.", CHAT_TAG);
			}

			CloseHandle(hFile);
		}
	}
	else
	{
		if( !FileExists(sPath) )
		{
			new Handle:hCfg = OpenFile(sPath, "w");
			WriteFileLine(hCfg, "");
			CloseHandle(hCfg);
		}

		new Handle:hFile = CreateKeyValues("crash");
		FileToKeyValues(hFile, sPath);

		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( KvJumpToKey(hFile, sMap, true) )
		{
			g_iSaved = 1;

			decl Float:vAng[3], Float:vPos[3];
			GetClientEyeAngles(client, vAng);
			GetClientAbsOrigin(client, vPos);

			KvSetFloat(hFile, "ang", vAng[1]);
			KvSetVector(hFile, "pos", vPos);
			KvSetNum(hFile, "method", g_iCvarAngle);

			KvRewind(hFile);
			KeyValuesToFile(hFile, sPath);

			PrintToChat(client, "%sSaved to this map.", CHAT_TAG);
		}
		else
		{
			PrintToChat(client, "%sCould not save to this map.", CHAT_TAG);
		}

		CloseHandle(hFile);
	}
}

CreateTrigger(client)
{
	if( IsValidEntRef(g_iTrigger) == true )
	{
		AcceptEntityInput(g_iTrigger, "Kill");
		g_iTrigger = 0;

		decl String:sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

		if( FileExists(sPath) )
		{
			new Handle:hFile = CreateKeyValues("crash");
			FileToKeyValues(hFile, sPath);

			decl String:sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( KvJumpToKey(hFile, sMap) )
			{
				KvDeleteKey(hFile, "vmax");
				KvDeleteKey(hFile, "vmin");
				KvDeleteKey(hFile, "vpos");

				KvRewind(hFile);
				KeyValuesToFile(hFile, sPath);

				PrintToChat(client, "%sDeleted trigger from to this map.", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%sNo trigger to delete!", CHAT_TAG);
			}

			CloseHandle(hFile);
		}

		return;
	}

	decl Float:vPos[3];
	GetClientAbsOrigin(client, vPos);
	CreateTriggerMultiple(vPos, Float:{ 50.0, 50.0, 100.0}, Float:{ 0.0, 0.0, 0.0 });

	SaveMaxMin(1, Float:{ 50.0, 50.0, 100.0});
	SaveMaxMin(2, Float:{ 0.0, 0.0, 0.0 });

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	new Handle:hFile = CreateKeyValues("crash");
	FileToKeyValues(hFile, sPath);

	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( KvJumpToKey(hFile, sMap, true) )
	{
		KvSetVector(hFile, "vpos", vPos);

		KvRewind(hFile);
		KeyValuesToFile(hFile, sPath);
		CloseHandle(hFile);
	}

	if( g_hTimerBeam == INVALID_HANDLE )
	{
		g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
	}
}

CreateTriggerMultiple(Float:vPos[3], Float:vMaxs[3], Float:vMins[3])
{
	g_iTrigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(g_iTrigger, "StartDisabled", "1");
	DispatchKeyValue(g_iTrigger, "spawnflags", "1");
	DispatchKeyValue(g_iTrigger, "entireteam", "0");
	DispatchKeyValue(g_iTrigger, "allowincap", "0");
	DispatchKeyValue(g_iTrigger, "allowghost", "0");

	DispatchSpawn(g_iTrigger);
	SetEntityModel(g_iTrigger, MODEL_BOUNDING);

	SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(g_iTrigger, Prop_Send, "m_nSolidType", 2);

	TeleportEntity(g_iTrigger, vPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("OnUser1 !self:Enable::5.0:-1");
	AcceptEntityInput(g_iTrigger, "AddOutput");
	AcceptEntityInput(g_iTrigger, "FireUser1");

	HookSingleEntityOutput(g_iTrigger, "OnStartTouch", OnStartTouch);
	g_iTrigger = EntIndexToEntRef(g_iTrigger);
}

public OnStartTouch(const String:output[], caller, activator, Float:delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 && IsValidEntRef(g_iEntities[0]) )
	{
		AcceptEntityInput(g_iEntities[0], "Trigger");
		AcceptEntityInput(caller, "Disable");
	}
}

SaveMaxMin(type, Float:vVec[3])
{
	if( IsValidEntRef(g_iTrigger) )
	{
		if( type == 1 )
			SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vVec);
		else
			SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vVec);
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	new Handle:hFile = CreateKeyValues("crash");
	FileToKeyValues(hFile, sPath);

	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( KvJumpToKey(hFile, sMap, true) )
	{
		if( type == 1 )
			KvSetVector(hFile, "vmax", vVec);
		else
			KvSetVector(hFile, "vmin", vVec);

		KvRewind(hFile);
		KeyValuesToFile(hFile, sPath);
	}
	CloseHandle(hFile);
}

public Action:TimerBeam(Handle:timer)
{
	if( IsValidEntRef(g_iTrigger) == false )
	{
		g_hTimerBeam = INVALID_HANDLE;
		return Plugin_Stop;
	}

	decl Float:vMaxs[3], Float:vMins[3], Float:vPos[3];
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vMaxs);
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecOrigin", vPos);
	AddVectors(vPos, vMaxs, vMaxs);
	AddVectors(vPos, vMins, vMins);
	TE_SendBox(vMins, vMaxs);

	return Plugin_Continue;
}

TE_SendBox(Float:vMins[3], Float:vMaxs[3])
{
	decl Float:vPos1[3], Float:vPos2[3], Float:vPos3[3], Float:vPos4[3], Float:vPos5[3], Float:vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

TE_SendBeam(const Float:vMins[3], const Float:vMaxs[3])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.2, 1.0, 1.0, 1, 0.0, { 255, 0, 0, 255 }, 0);
	TE_SendToAll();
}

CreateCrash(client)
{
	decl Float:vPos[3], Float:vAng[3];
	new time;
	new method;

	if( client )
	{
		method = g_iCvarAngle;
		GetClientAbsOrigin(client, vPos);
		GetClientEyeAngles(client, vAng);
	}
	else
	{
		g_iSaved = 0;

		decl String:sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
		if( !FileExists(sPath) )
			return;

		new Handle:hFile = CreateKeyValues("crash");
		FileToKeyValues(hFile, sPath);

		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( !KvJumpToKey(hFile, sMap) )
		{
			CloseHandle(hFile);
			return;
		}

		time = KvGetNum(hFile, "time");
		method = KvGetNum(hFile, "method");

		if( time == 0 )
		{
			decl Float:vVec[3];
			KvGetVector(hFile, "vpos", vVec, Float:{ 999.9, 999.9, 999.9 });

			if( vVec[0] != 999.9 && vVec[1] != 999.9 )
			{
				decl Float:vMaxs[3], Float:vMins[3];
				KvGetVector(hFile, "vmax", vMaxs);
				KvGetVector(hFile, "vmin", vMins);

				if( IsValidEntRef(g_iTrigger) )
				{
					AcceptEntityInput(g_iTrigger, "Kill");
					g_iTrigger = 0;
				}

				CreateTriggerMultiple(vVec, vMaxs, vMins);
			}

			time = -1;
		}

		vAng[1] = KvGetFloat(hFile, "ang");
		KvGetVector(hFile, "pos", vPos, Float:{ 999.9, 999.9, 999.9 });

		if( vPos[0] == 999.9 && vPos[1] == 999.9 )
		{
			CloseHandle(hFile);
			return;
		}

		CloseHandle(hFile);
	}


	CreatePlaneCrash(vPos, vAng, method);


	if( client )
	{
		AcceptEntityInput(g_iEntities[0], "Trigger");
	}
	else
	{
		g_iSaved = 1;

		if( time != -1 && (time || g_fCvarTime) )
		{
			decl String:sTemp[64];

			if( time )
				Format(sTemp, sizeof(sTemp), "OnUser1 silver_planecrash_trigger:Trigger::%d:-1", time);
			else
				Format(sTemp, sizeof(sTemp), "OnUser1 silver_planecrash_trigger:Trigger::%0.1f:-1", g_fCvarTime);

			SetVariantString(sTemp);
			AcceptEntityInput(g_iEntities[0], "AddOutput");
			AcceptEntityInput(g_iEntities[0], "FireUser1");
		}
	}
}

CreatePlaneCrash(Float:vPos[3], Float:vAng[3], method)
{
	decl Float:vLoc[3];

	if( method == 0 )
	{
		vLoc = vPos;
		vLoc[0] += vAng[1] * 1200.0 / 180.0;
		vLoc[1] += vAng[1] * 1200.0 / 180.0;
		vLoc[2] -= 50.0;
		vAng[0] = 0.0;
		vAng[1] += 75.0;
		vAng[2] = 0.0;
	}
	else
	{
		vLoc = vPos;

		new Float:p, Float:x, Float:y;

		if( vAng[1] <= -90.0 )
		{
			p = (vAng[1] * -1.0) * 100 / 90;
			x = -1500 * (200 - p) / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 0.0 )
		{			
			p = (vAng[1] * -1.0) * 100 / 90;
			x = -1500 * p / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 90.0 )
		{
			p = vAng[1] * 100 / 90;
			x = 1500 * p / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 180.0 )
		{
			p = vAng[1] * 100 / 90;
			x = 1500 * (200 - p) / 100;
			y = -1500 * (100 - p) / 100;
		}

		vLoc[0] += x;
		vLoc[1] += y;
		vLoc[2] -= 50.0;
		vAng[0] = 0.0;
		vAng[1] += 30;
		vAng[2] = 0.0;
	}

	vPos = vLoc;

	new count;
	new entity;

	entity = CreateEntityByName("logic_relay");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_trigger");
	DispatchKeyValue(entity, "spawnflags", "1");
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = entity;

	if( g_iCvarHorde )
	{
		decl String:sTemp[64];
		Format(sTemp, sizeof(sTemp), "OnTrigger director:ForcePanicEvent::%d:-1",g_iCvarHorde);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger @director:ForcePanicEvent::%d:-1",g_iCvarHorde);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
	}

	SetVariantString("OnTrigger silver_planecrash_collision:FireUser2::27:-1");
	AcceptEntityInput(entity, "AddOutput");

	SetVariantString("OnTrigger silver_plane_crash_sound:PlaySound::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::20.5:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::23:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::24:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::26:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:Kill::30:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:SetAnimation:approach:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:Kill::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:Kill::16:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:TurnOn::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_tail:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_tail:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_engine:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_engine:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_wing:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_wing:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_emitters:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	DispatchSpawn(entity);


	entity = CreateEntityByName("ambient_generic");
	DispatchKeyValue(entity, "targetname", "silver_plane_crash_sound");
	DispatchKeyValue(entity, "volume", "2");
	DispatchKeyValue(entity, "spawnflags", "49");
	DispatchKeyValue(entity, "radius", "3250");
	DispatchKeyValue(entity, "pitchstart", "100");
	DispatchKeyValue(entity, "pitch", "100");
	DispatchKeyValue(entity, "message", "airport.planecrash");
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("env_shake");
	DispatchKeyValue(entity, "targetname", "silver_plane_crash_shake");
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "duration", "4");
	DispatchKeyValue(entity, "amplitude", "4");
	DispatchKeyValue(entity, "frequency", "100");
	DispatchKeyValue(entity, "radius", "3117");
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_plane_precrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE01);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE02);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE03);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE04);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE05);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE06);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE07);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE08);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE09);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE10);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_tailsection");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE11);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_engine");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE12);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_wing");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE13);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE14);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE15);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE16);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	vPos = vLoc;
	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_collision");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "RandomAnimation", "0");
	DispatchKeyValue(entity, "model", MODEL_PLANE17);
	DispatchSpawn(entity);
	vPos[2] += 9999.9;
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	vPos[2] -= 9999.9;
	g_iEntities[count++] = EntIndexToEntRef(entity);
	HookSingleEntityOutput(entity, "OnUser2", OnUserCollision, true);


	if( g_iCvarDamage )
	{
		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_tail");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		DispatchKeyValue(entity, "damage", "20");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", Float:{ 300.0, 300.0, 300.0});
		SetEntPropVector(entity, Prop_Send, "m_vecMins", Float:{ -300.0, -300.0, -300.0 });
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_tailsection");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("HullDebris1");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);


		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_engine");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		decl String:sTemp[6];
		IntToString(g_iCvarDamage, sTemp, sizeof(sTemp));
		DispatchKeyValue(entity, "damage", sTemp);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", Float:{ 300.0, 300.0, 300.0});
		SetEntPropVector(entity, Prop_Send, "m_vecMins", Float:{ -300.0, -300.0, -300.0 });
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_engine");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("particleEmitter2");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);


		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_wing");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		DispatchKeyValue(entity, "damage", "20");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", Float:{ 300.0, 300.0, 300.0});
		SetEntPropVector(entity, Prop_Send, "m_vecMins", Float:{ -300.0, -300.0, -300.0 });
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_wing");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("new_spark_joint_1");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);
	}
}

public OnUserCollision(const String:output[], caller, activator, Float:delay)
{
	if( g_iCvarClear )
		CreateTimer(float(g_iCvarClear), TimerReset);

	decl Float:vPos[3];
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", vPos);
	vPos[2] -= 9999.9;
	TeleportEntity(caller, vPos, NULL_VECTOR, NULL_VECTOR);
}

public Action:TimerReset(Handle:timer)
{
	ResetPlugin();
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}