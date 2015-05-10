#define PLUGIN_VERSION		"1.2-tr"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] F-18 Airstrike (Sky)
*	Author	:	SilverShot
*	Descrp	:	Creates F-18 fly bys which shoot missiles to where they were triggered from.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=181517

========================================================================================
	Change Log:
1.2-tr (01-Apr-2015)
	- Added RegAdminCmd "sm_show_airstrike" for sky.cfg

1.1-tr (20-Jun-2012)
	- Prevents setting the Refire Time and Count values lower than 0.

1.0-tr (15-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 			1

#include <l4d2_airstrike>
#include <sdktools>
#include <sdkhooks>

#define CHAT_TAG			"\x03[Airstrike] \x05"
#define CONFIG_SPAWNS		"data/l4d2_airstrike.cfg"

#define MODEL_BOX			"models/props/cs_militia/silo_01.mdl"

#define MAX_ENTITIES		14

static	Handle:g_hMenuVMaxs, Handle:g_hMenuVMins, Handle:g_hMenuPos, Handle:g_hTimerBeam, g_iLaserMaterial, g_iHaloMaterial, g_iSelectedTrig, g_iTriggers[MAX_ENTITIES],
		Handle:g_hMenuRefire, Handle:g_hMenuTime, Handle:g_hMenuAtOnce, g_iRefireCount[MAX_ENTITIES], Float:g_fRefireTime[MAX_ENTITIES], g_iRefireAtOnce[MAX_ENTITIES],
		Handle:g_hTimerEnable[MAX_ENTITIES], Float:g_vTargetZone[MAX_ENTITIES][3], Float:g_fTargetAng[MAX_ENTITIES], g_iMenuSelected[MAXPLAYERS+1], bool:g_bLoaded;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D2] F-18 Airstrike - Triggers (Sky)",
	author = "SilverShot",
	description = "Creates F-18 fly bys which shoot missiles to where they were triggered from.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=181517"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead2", false) )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	RegPluginLibrary("l4d2_airstrike.triggers");
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	if( LibraryExists("l4d2_airstrike") == false )
	{
		SetFailState("F-18 Airstrike 'l4d2_airstrike.core.smx' plugin not loaded.");
	}
}

public OnPluginStart()
{
	RegAdminCmd("sm_strike_triggers",		CmdAirstrikeMenu,		ADMFLAG_ROOT,	    "Displays a menu with options to show/save a airstrike and triggers.");
	RegAdminCmd("sm_show_airstrike",		Cmd_ShowAirstrikeById,	ADMFLAG_CONVARS,	"Usage: sm_show_airstrike <index>");

	CreateConVar("l4d2_strike_triggers",	PLUGIN_VERSION,			"F-18 Airstrike Triggers plugin version",	FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hMenuVMaxs = CreateMenu(VMaxsMenuHandler);
	AddMenuItem(g_hMenuVMaxs, "", "10 x 10 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "25 x 25 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "50 x 50 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "100 x 100 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "150 x 150 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "200 x 200 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "250 x 250 x 100");
	SetMenuTitle(g_hMenuVMaxs, "Airstrike: Trigger Box - VMaxs");
	SetMenuExitBackButton(g_hMenuVMaxs, true);

	g_hMenuVMins = CreateMenu(VMinsMenuHandler);
	AddMenuItem(g_hMenuVMins, "", "-10 x -10 x 0");
	AddMenuItem(g_hMenuVMins, "", "-25 x -25 x 0");
	AddMenuItem(g_hMenuVMins, "", "-50 x -50 x 0");
	AddMenuItem(g_hMenuVMins, "", "-100 x -100 x 0");
	AddMenuItem(g_hMenuVMins, "", "-150 x -150 x 0");
	AddMenuItem(g_hMenuVMins, "", "-200 x -200 x 0");
	AddMenuItem(g_hMenuVMins, "", "-250 x -250 x 0");
	SetMenuTitle(g_hMenuVMins, "Airstrike: Trigger Box - VMins");
	SetMenuExitBackButton(g_hMenuVMins, true);

	g_hMenuPos = CreateMenu(PosMenuHandler);
	AddMenuItem(g_hMenuPos, "", "X + 1.0");
	AddMenuItem(g_hMenuPos, "", "Y + 1.0");
	AddMenuItem(g_hMenuPos, "", "Z + 1.0");
	AddMenuItem(g_hMenuPos, "", "X - 1.0");
	AddMenuItem(g_hMenuPos, "", "Y - 1.0");
	AddMenuItem(g_hMenuPos, "", "Z - 1.0");
	AddMenuItem(g_hMenuPos, "", "SAVE");
	SetMenuTitle(g_hMenuPos, "Airstrike: Trigger Box - Origin");
	SetMenuExitBackButton(g_hMenuPos, true);

	g_hMenuRefire = CreateMenu(RefireMenuHandler);
	AddMenuItem(g_hMenuRefire, "", "1");
	AddMenuItem(g_hMenuRefire, "", "2");
	AddMenuItem(g_hMenuRefire, "", "3");
	AddMenuItem(g_hMenuRefire, "", "5");
	AddMenuItem(g_hMenuRefire, "", "- 1");
	AddMenuItem(g_hMenuRefire, "", "+ 1");
	AddMenuItem(g_hMenuRefire, "", "Unlimited");
	SetMenuTitle(g_hMenuRefire, "Airstrike: Trigger Box - Refire Count");
	SetMenuExitBackButton(g_hMenuRefire, true);

	g_hMenuTime = CreateMenu(TimeMenuHandler);
	AddMenuItem(g_hMenuTime, "", "0.5");
	AddMenuItem(g_hMenuTime, "", "1.0");
	AddMenuItem(g_hMenuTime, "", "2.0");
	AddMenuItem(g_hMenuTime, "", "3.0");
	AddMenuItem(g_hMenuTime, "", "5.0");
	AddMenuItem(g_hMenuTime, "", "- 0.5");
	AddMenuItem(g_hMenuTime, "", "+ 0.5");
	SetMenuTitle(g_hMenuTime, "Airstrike: Trigger Box - Refire Time");
	SetMenuExitBackButton(g_hMenuTime, true);

	g_hMenuAtOnce = CreateMenu(AtOnceMenuHandler);
	AddMenuItem(g_hMenuAtOnce, "", "1");
	AddMenuItem(g_hMenuAtOnce, "", "2");
	AddMenuItem(g_hMenuAtOnce, "", "3");
	AddMenuItem(g_hMenuAtOnce, "", "4");
	AddMenuItem(g_hMenuAtOnce, "", "5");
	AddMenuItem(g_hMenuAtOnce, "", "6");
	AddMenuItem(g_hMenuAtOnce, "", "7");
	SetMenuTitle(g_hMenuAtOnce, "Airstrike: Trigger Box - Max At Once");
	SetMenuExitBackButton(g_hMenuAtOnce, true);
}

public Action:Cmd_ShowAirstrikeById(client, args)
{
    decl String:index[4];
    GetCmdArg(1, index, sizeof(index));
    ShowAirStrike(StringToInt(index) - 1);
    return Plugin_Handled;
}

public F18_OnPluginState(pluginstate)
{
	if( pluginstate == 1 )
	{
		LoadAirstrikes();
	}
	else
	{
		ResetPlugin();
	}

	static mystate;

	if( pluginstate == 1 && mystate == 0 )
	{
		mystate = 1;
	}
	else if( pluginstate == 0 && mystate == 1 )
	{
		mystate = 0;
	}
	else
		LogError("############ ERROR :: AIRSTRIKE TRIGGERS :: <PLUGIN> STATE %d MINE %d", pluginstate, mystate);
}

public F18_OnRoundState(roundstate)
{
	if( roundstate == 1 )
		LoadAirstrikes();
	else
		ResetPlugin();

	static mystate;

	if( roundstate == 1 && mystate == 0 )
	{
		mystate = 1;
	}
	else if( roundstate == 0 && mystate == 1 )
	{
		mystate = 0;
	}
	else
		LogError("############ ERROR :: AIRSTRIKE TRIGGERS :: ROUND STATE %d MINE %d", roundstate, mystate);
}

public OnPluginEnd()
{
	ResetPlugin();
}

public OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheModel(MODEL_BOX, true);
}

ResetPlugin()
{
	g_bLoaded = false;
	g_iSelectedTrig = 0;

	for( new i = 0; i < MAX_ENTITIES; i++ )
	{
		g_vTargetZone[i] = Float:{ 0.0, 0.0, 0.0 };
		g_iRefireCount[i] = 0;
		g_fRefireTime[i] = 3.0;
		g_iRefireAtOnce[i] = 1;
		g_fTargetAng[i] = 0.0;

		if( IsValidEntRef(g_iTriggers[i]) )
			AcceptEntityInput(g_iTriggers[i], "Kill");
		g_iTriggers[i] = 0;
	}
}



// ====================================================================================================
//					LOAD
// ====================================================================================================
LoadAirstrikes()
{
	if( g_bLoaded == true )
		return;
	g_bLoaded = true;

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	new Handle:hFile = CreateKeyValues("airstrike");
	FileToKeyValues(hFile, sPath);

	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !KvJumpToKey(hFile, sMap) )
	{
		CloseHandle(hFile);
		return;
	}

	decl String:sTemp[16], Float:fAng, Float:vPos[3], Float:vMax[3], Float:vMin[3];

	for( new i = 1; i <= MAX_ENTITIES; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( KvJumpToKey(hFile, sTemp, false) )
		{
			// AIRSTRIKE POSITION
			fAng = KvGetFloat(hFile, "ang");
			KvGetVector(hFile, "pos", vPos);
			g_vTargetZone[i-1] = vPos;
			g_fTargetAng[i-1] = fAng;
			g_fRefireTime[i-1] = 3.0;

			// TRIGGER BOXES
			KvGetVector(hFile, "vpos", vPos);
			if( vPos[0] != 0.0 && vPos[1] != 0.0 && vPos[2] != 0.0 )
			{
				KvGetVector(hFile, "vmin", vMin);
				KvGetVector(hFile, "vmax", vMax);
				g_fRefireTime[i-1] = KvGetFloat(hFile, "time", 3.0);
				g_iRefireCount[i-1] = KvGetNum(hFile, "trig");
				g_iRefireAtOnce[i-1] = KvGetNum(hFile, "once", 1);

				CreateTriggerMultiple(i, vPos, vMax, vMin);
			}

			KvGoBack(hFile);
		}
	}

	CloseHandle(hFile);
}



// ====================================================================================================
//					MENU - MAIN
// ====================================================================================================
public Action:CmdAirstrikeMenu(client, args)
{
	ShowMenuMain(client);
	return Plugin_Handled;
}

ShowMenuMain(client)
{
	new Handle:hMenu = CreateMenu(MainMenuHandler);
	AddMenuItem(hMenu, "1", "Airstrike on Crosshair");
	AddMenuItem(hMenu, "2", "Airstrike on Position");
	AddMenuItem(hMenu, "3", "Target Zone");
	AddMenuItem(hMenu, "4", "Trigger Box");
	SetMenuTitle(hMenu, "F-18 Airstrike");
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
		if( index == 0 )
		{
			decl Float:vPos[3], Float:vAng[3], Float:direction;
			GetClientEyePosition(client, vPos);
			GetClientEyeAngles(client, vAng);
			direction = vAng[1];

			new Handle:trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, TraceFilter);

			if( TR_DidHit(trace) )
			{
				decl Float:vStart[3];
				TR_GetEndPosition(vStart, trace);
				GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
				vPos[0] = vStart[0] + vAng[0];
				vPos[1] = vStart[1] + vAng[1];
				vPos[2] = vStart[2] + vAng[2];
				F18_ShowAirstrike(vPos[0], vPos[1], vPos[2], direction);
			}

			CloseHandle(trace);
			ShowMenuMain(client);
		}
		else if( index == 1 )
		{
			decl Float:vPos[3], Float:vAng[3];
			GetClientAbsOrigin(client, vPos);
			GetClientEyeAngles(client, vAng);
			F18_ShowAirstrike(vPos[0], vPos[1], vPos[2], vAng[1]);
			ShowMenuMain(client);
		}
		else if( index == 2 )
		{
			ShowMenuTarget(client);
		}
		else if( index == 3 )
		{
			ShowMenuTrigger(client);
		}
	}
}

public bool:TraceFilter(entity, contentsMask)
{
	return entity > MaxClients;
}



// ====================================================================================================
//					MENU - TARGET ZONE
// ====================================================================================================
ShowMenuTarget(client)
{
	new Handle:hMenu = CreateMenu(TargetMenuHandler);

	AddMenuItem(hMenu, "0", "Create/Replace");
	AddMenuItem(hMenu, "1", "Show Airstrike");
	AddMenuItem(hMenu, "2", "Delete");
	AddMenuItem(hMenu, "3", "Go To");

	SetMenuTitle(hMenu, "Airstrike - Target Zone:");
	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TargetMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);
		ShowMenuTargetList(client, index);
	}
}

ShowMenuTargetList(client, index)
{
	g_iMenuSelected[client] = index;

	new count;
	new Handle:hMenu = CreateMenu(TargetListMenuHandler);
	decl String:sIndex[8], String:sTemp[32];

	if( index == 0 )
		AddMenuItem(hMenu, "-1", "NEW");

	for( new i = 0; i < MAX_ENTITIES; i++ )
	{
		if( index == 0 )
		{
			count++;
			if( g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0 )
			{
				Format(sTemp, sizeof(sTemp), "Replace %d", i+1);
				IntToString(i, sIndex, sizeof(sIndex));
				AddMenuItem(hMenu, sIndex, sTemp);
			}
			else if( IsValidEntRef(g_iTriggers[i]) == true )
			{
				Format(sTemp, sizeof(sTemp), "Pair to Trigger %d", i+1);
				IntToString(i, sIndex, sizeof(sIndex));
				AddMenuItem(hMenu, sIndex, sTemp);
			}
		}
		else if( g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0 )
		{
			count++;
			if( index == 0 )
				Format(sTemp, sizeof(sTemp), "Replace %d", i+1);
			else
				Format(sTemp, sizeof(sTemp), "Target %d", i+1);

			IntToString(i, sIndex, sizeof(sIndex));
			AddMenuItem(hMenu, sIndex, sTemp);
		}
	}

	if( index != 0 && count == 0 )
	{
		PrintToChat(client, "%sError: No saved Airstrikes were found.", CHAT_TAG);
		CloseHandle(hMenu);
		ShowMenuMain(client);
		return;
	}

	if( index == 0 )
		SetMenuTitle(hMenu, "Airstrike: Target Zone - Create/Replace:");
	else if( index == 1 )
		SetMenuTitle(hMenu, "Airstrike: Target Zone - Show:");
	else if( index == 2 )
		SetMenuTitle(hMenu, "Airstrike: Target Zone - Delete:");
	else if( index == 3 )
		SetMenuTitle(hMenu, "Airstrike: Target Zone - Go To:");

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TargetListMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTarget(client);
	}
	else if( action == MenuAction_Select )
	{
		new type = g_iMenuSelected[client];
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( type == 0 )
		{
			if( index == -1 )
				SaveAirstrike(client, 0);
			else
				SaveAirstrike(client, index + 1);
			ShowMenuTarget(client);
		}
		else if( type == 1 )
		{
			// F18_ShowAirstrike(g_vTargetZone[index][0], g_vTargetZone[index][1], g_vTargetZone[index][2], g_fTargetAng[index]);
			ShowAirStrike(index);
			ShowMenuTarget(client);
		}
		else if( type == 2 )
		{
			DeleteTrigger(client, false, index+1);
			ShowMenuTarget(client);
		}
		else if( type == 3 )
		{
			decl Float:vPos[3];
			vPos = g_vTargetZone[index];

			if( vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0 )
			{
				PrintToChat(client, "%sCannot teleport you, the Target Zone is missing.", CHAT_TAG);
			}
			else
			{
				vPos[2] += 10.0;
				TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			}
			ShowMenuTarget(client);
		}
	}
}



// ====================================================================================================
//					SAVE AIRSTRIKE
// ====================================================================================================
SaveAirstrike(client, index)
{
	new Handle:hFile = ConfigOpen();

	if( hFile != INVALID_HANDLE )
	{
		decl String:sMap[64], String:sTemp[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( index == 0 )
		{
			if( KvJumpToKey(hFile, sMap, true) == true )
			{
				for( new i = 1; i <= MAX_ENTITIES; i++ )
				{
					IntToString(i, sTemp, sizeof(sTemp));
					if( KvJumpToKey(hFile, sTemp) == false )
					{
						index = i;
						break;
					}
					else
					{
						KvGoBack(hFile);
					}
				}
			}

			if( index == 0 )
			{
				CloseHandle(hFile);
				PrintToChat(client, "%sCould not save airstrike, no free index or other error.", CHAT_TAG);
				return;
			}
		}
		else
		{
			if( KvJumpToKey(hFile, sMap, true) == false )
			{
				CloseHandle(hFile);
				PrintToChat(client, "%sCould not save airstrike, no free index or other error.", CHAT_TAG);
				return;
			}
		}

		IntToString(index, sTemp, sizeof(sTemp));
		if( KvJumpToKey(hFile, sTemp, true) == true )
		{
			decl Float:vAng[3], Float:vPos[3];
			GetClientEyeAngles(client, vAng);
			GetClientAbsOrigin(client, vPos);

			KvSetFloat(hFile, "ang", vAng[1]);
			KvSetVector(hFile, "pos", vPos);

			g_fTargetAng[index-1] = vAng[1];
			g_vTargetZone[index-1] = vPos;

			ConfigSave(hFile);

			PrintToChat(client, "%sSaved airstrike to this map.", CHAT_TAG);
		}
		else
		{
			PrintToChat(client, "%sCould not save airstrike to this map.", CHAT_TAG);
		}

		CloseHandle(hFile);
	}
}



// ====================================================================================================
//					MENU - TRIGGER BOX
// ====================================================================================================
ShowMenuTrigger(client)
{
	new Handle:hMenu = CreateMenu(TrigMenuHandler);

	AddMenuItem(hMenu, "0", "Create/Replace");
	if( g_hTimerBeam == INVALID_HANDLE )
		AddMenuItem(hMenu, "1", "Show");
	else
		AddMenuItem(hMenu, "1", "Hide");
	AddMenuItem(hMenu, "2", "Delete");
	AddMenuItem(hMenu, "3", "VMaxs");
	AddMenuItem(hMenu, "4", "VMins");
	AddMenuItem(hMenu, "5", "Origin");
	AddMenuItem(hMenu, "6", "Go To");
	AddMenuItem(hMenu, "7", "Refire Count");
	AddMenuItem(hMenu, "8", "Refire Time");
	AddMenuItem(hMenu, "9", "Max At Once");

	SetMenuTitle(hMenu, "Airstrike - Trigger Box:");
	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TrigMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 1 )
		{
			if( g_hTimerBeam != INVALID_HANDLE )
			{
				CloseHandle(g_hTimerBeam);
				g_hTimerBeam = INVALID_HANDLE;
				g_iSelectedTrig = 0;
			}
			ShowMenuTrigList(client, index);
		}
		else
		{
			ShowMenuTrigList(client, index);
		}
	}
}

ShowMenuTrigList(client, index)
{
	g_iMenuSelected[client] = index;

	new count;
	new Handle:hMenu = CreateMenu(TrigListMenuHandler);
	decl String:sIndex[8], String:sTemp[32];

	if( index == 0 )
		AddMenuItem(hMenu, "-1", "NEW");

	for( new i = 0; i < MAX_ENTITIES; i++ )
	{
		if( index == 0 )
		{
			count++;
			if( IsValidEntRef(g_iTriggers[i]) == true )
			{
				Format(sTemp, sizeof(sTemp), "Replace %d", i+1);
				IntToString(i, sIndex, sizeof(sIndex));
				AddMenuItem(hMenu, sIndex, sTemp);
			}
			else if( g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0 )
			{
				Format(sTemp, sizeof(sTemp), "Pair to Target %d", i+1);
				IntToString(i, sIndex, sizeof(sIndex));
				AddMenuItem(hMenu, sIndex, sTemp);
			}
		}
		else if( IsValidEntRef(g_iTriggers[i]) == true )
		{
			count++;
			if( index == 0 )
				Format(sTemp, sizeof(sTemp), "Replace %d", i+1);
			else
				Format(sTemp, sizeof(sTemp), "Trigger %d", i+1);

			IntToString(i, sIndex, sizeof(sIndex));
			AddMenuItem(hMenu, sIndex, sTemp);
		}
	}

	if( index != 0 && count == 0 )
	{
		PrintToChat(client, "%sError: No saved Triggers were found.", CHAT_TAG);
		CloseHandle(hMenu);
		ShowMenuMain(client);
		return;
	}

	if( index == 0 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Create/Replace:");
	else if( index == 1 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Show:");
	else if( index == 2 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Delete:");
	else if( index == 3 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Maxs:");
	else if( index == 4 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Mins:");
	else if( index == 5 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Origin:");
	else if( index == 6 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Go To:");
	else if( index == 7 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Refire Count:");
	else if( index == 8 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Refire Time:");
	else if( index == 9 )
		SetMenuTitle(hMenu, "Airstrike: Trigger Box - Max At Once:");

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TrigListMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new type = g_iMenuSelected[client];
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( type == 0 )
		{
			if( index == -1 )
				CreateTrigger(index, client); // NEW
			else
				CreateTrigger(index, client); // REPLACE

			ShowMenuTrigger(client);
		}
		else if( type == 1 )
		{
			g_iSelectedTrig = g_iTriggers[index];

			if( IsValidEntRef(g_iSelectedTrig) )
				g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
			else
				g_iSelectedTrig = 0;

			ShowMenuTrigger(client);
		}
		else if( type == 2 )
		{
			DeleteTrigger(client, true, index+1);
			ShowMenuTrigger(client);
		}
		else if( type == 3 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuVMaxs, client, MENU_TIME_FOREVER);
		}
		else if( type == 4 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuVMins, client, MENU_TIME_FOREVER);
		}
		else if( type == 5 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
		}
		else if( type == 6 )
		{
			new trigger = g_iTriggers[index];
			if( IsValidEntRef(trigger) )
			{
				new Float:vPos[3];
				GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);

				if( vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0 )
				{
					PrintToChat(client, "%sCannot teleport you, the Target Zone is missing.", CHAT_TAG);
				}
				else
				{
					vPos[2] += 10.0;
					TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
				}
			}
			ShowMenuTrigger(client);
		}
		else if( type == 7 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuRefire, client, MENU_TIME_FOREVER);
		}
		else if( type == 8 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuTime, client, MENU_TIME_FOREVER);
		}
		else if( type == 9 )
		{
			g_iMenuSelected[client] = index;
			DisplayMenu(g_hMenuAtOnce, client, MENU_TIME_FOREVER);
		}
	}
}



// ====================================================================================================
//					MENU - TRIGGER BOX - REFIRE COUNT
// ====================================================================================================
public RefireMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new cfgindex = g_iMenuSelected[client];
		new trigger = g_iTriggers[cfgindex];

		new value;
		if( index <= 2 )		value = index + 1;
		else if( index == 3 )	value = 5;
		else if( index == 4 )	value = g_iRefireCount[cfgindex] - 1;
		else if( index == 5 )	value = g_iRefireCount[cfgindex] + 1;
		else if( index == 6 )	value = 0;
		if( value < 0 )			value = 0;


		new Handle:hFile = ConfigOpen();

		if( hFile != INVALID_HANDLE )
		{
			decl String:sTemp[64];
			GetCurrentMap(sTemp, sizeof(sTemp));

			if( KvJumpToKey(hFile, sTemp) == true )
			{
				IntToString(cfgindex+1, sTemp, sizeof(sTemp));

				if( KvJumpToKey(hFile, sTemp) == true )
				{
					if( value == 0 )
					{
						g_iRefireCount[cfgindex] = 0;
						KvDeleteKey(hFile, "trig");
						PrintToChat(client, "%sRemoved trigger box '\x03%d\x05' refire count. Set to unlimited.", CHAT_TAG, cfgindex+1);

						if( IsValidEntRef(trigger) )
						{
							if( g_hTimerEnable[cfgindex] != INVALID_HANDLE )
								CloseHandle(g_hTimerEnable[cfgindex]);
							g_hTimerEnable[cfgindex] = CreateTimer(g_fRefireTime[cfgindex], TimerEnable, cfgindex);
						}
					}
					else
					{
						g_iRefireCount[cfgindex] = value;
						KvSetNum(hFile, "trig", value);
						PrintToChat(client, "%sSet trigger box '\x03%d\x05' refire count to \x03%d", CHAT_TAG, cfgindex+1, value);

						if( IsValidEntRef(trigger) && GetEntProp(trigger, Prop_Data, "m_iHammerID") <= value )
						{
							if( g_hTimerEnable[cfgindex] != INVALID_HANDLE )
								CloseHandle(g_hTimerEnable[cfgindex]);
							g_hTimerEnable[cfgindex] = CreateTimer(g_fRefireTime[cfgindex], TimerEnable, cfgindex);
						}
					}

					ConfigSave(hFile);
				}
			}

			CloseHandle(hFile);
		}

		DisplayMenu(g_hMenuRefire, client, MENU_TIME_FOREVER);
	}
}



// ====================================================================================================
//					MENU - TRIGGER BOX - REFIRE TIME
// ====================================================================================================
public TimeMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new cfgindex = g_iMenuSelected[client];
		new trigger = g_iTriggers[cfgindex];

		new Float:value;
		if( index == 0 )		value = 0.5;
		else if( index == 1 )	value = 1.0;
		else if( index == 2 )	value = 2.0;
		else if( index == 3 )	value = 3.0;
		else if( index == 4 )	value = 5.0;
		else if( index == 5 )	value = g_fRefireTime[cfgindex] - 0.5;
		else if( index == 6 )	value = g_fRefireTime[cfgindex] + 0.5;
		if( value < 0.5 )		value = 0.5;


		new Handle:hFile = ConfigOpen();

		if( hFile != INVALID_HANDLE )
		{
			decl String:sTemp[64];
			GetCurrentMap(sTemp, sizeof(sTemp));

			if( KvJumpToKey(hFile, sTemp) == true )
			{
				IntToString(cfgindex+1, sTemp, sizeof(sTemp));

				if( KvJumpToKey(hFile, sTemp) == true )
				{
					g_fRefireTime[cfgindex] = value;
					KvSetFloat(hFile, "time", value);
					PrintToChat(client, "%sSet trigger box '\x03%d\x05' refire time to \x03%0.1f", CHAT_TAG, cfgindex+1, value);

					ConfigSave(hFile);

					if( IsValidEntRef(trigger) && GetEntProp(trigger, Prop_Data, "m_iHammerID") <= g_iRefireCount[cfgindex] )
					{
						if( g_hTimerEnable[cfgindex] != INVALID_HANDLE )
							CloseHandle(g_hTimerEnable[cfgindex]);
						g_hTimerEnable[cfgindex] = CreateTimer(value, TimerEnable, cfgindex);
					}
				}
			}

			CloseHandle(hFile);
		}

		DisplayMenu(g_hMenuTime, client, MENU_TIME_FOREVER);
	}
}



// ====================================================================================================
//					MENU - TRIGGER BOX - MAX AT ONCE
// ====================================================================================================
public AtOnceMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new cfgindex = g_iMenuSelected[client];

		new Handle:hFile = ConfigOpen();

		if( hFile != INVALID_HANDLE )
		{
			decl String:sTemp[64];
			GetCurrentMap(sTemp, sizeof(sTemp));

			if( KvJumpToKey(hFile, sTemp) == true )
			{
				IntToString(cfgindex+1, sTemp, sizeof(sTemp));

				if( KvJumpToKey(hFile, sTemp) == true )
				{
					if( index == 0 )
					{
						g_iRefireAtOnce[cfgindex] = 1;
						KvDeleteKey(hFile, "once");
					}
					else
					{
						g_iRefireAtOnce[cfgindex] = index + 1;
						KvSetNum(hFile, "once", index + 1);
					}

					PrintToChat(client, "%sSet trigger box '\x03%d\x05' maximum airstrikes at once to \x03%d", CHAT_TAG, cfgindex+1, index + 1);
					ConfigSave(hFile);
				}
			}

			CloseHandle(hFile);
		}

		DisplayMenu(g_hMenuAtOnce, client, MENU_TIME_FOREVER);
	}
}



// ====================================================================================================
//					MENU - TRIGGER BOX - VMINS/VMAXS/VPOS - CALLBACKS
// ====================================================================================================
public VMaxsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		decl Float:vVec[3];

		if( index == 0 )
			vVec = Float:{ 10.0, 10.0, 100.0 };
		else if( index == 1 )
			vVec = Float:{ 25.0, 25.0, 100.0 };
		else if( index == 2 )
			vVec = Float:{ 50.0, 50.0, 100.0 };
		else if( index == 3 )
			vVec = Float:{ 100.0, 100.0, 100.0 };
		else if( index == 4 )
			vVec = Float:{ 150.0, 150.0, 100.0 };
		else if( index == 5 )
			vVec = Float:{ 200.0, 200.0, 100.0 };
		else if( index == 6 )
			vVec = Float:{ 300.0, 300.0, 100.0 };

		new cfgindex = g_iMenuSelected[client];
		new trigger = g_iTriggers[cfgindex];

		SaveTrigger(client, cfgindex + 1, "vmax", vVec);

		if( IsValidEntRef(trigger) )
			SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vVec);

		g_iSelectedTrig = trigger;
		if( g_hTimerBeam == INVALID_HANDLE )
			g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);

		DisplayMenu(g_hMenuVMaxs, client, MENU_TIME_FOREVER);
	}
}

public VMinsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		decl Float:vVec[3];

		if( index == 0 )
			vVec = Float:{ -10.0, -10.0, -100.0 };
		else if( index == 1 )
			vVec = Float:{ -25.0, -25.0, -100.0 };
		else if( index == 2 )
			vVec = Float:{ -50.0, -50.0, -100.0 };
		else if( index == 3 )
			vVec = Float:{ -100.0, -100.0, -100.0 };
		else if( index == 4 )
			vVec = Float:{ -150.0, -150.0, -100.0 };
		else if( index == 5 )
			vVec = Float:{ -200.0, -200.0, -100.0 };
		else if( index == 6 )
			vVec = Float:{ -300.0, -300.0, -100.0 };

		new cfgindex = g_iMenuSelected[client];
		new trigger = g_iTriggers[cfgindex];

		SaveTrigger(client, cfgindex + 1, "vmin", vVec);

		if( IsValidEntRef(trigger) )
			SetEntPropVector(trigger, Prop_Send, "m_vecMins", vVec);

		g_iSelectedTrig = trigger;
		if( g_hTimerBeam == INVALID_HANDLE )
			g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);

		DisplayMenu(g_hMenuVMins, client, MENU_TIME_FOREVER);
	}
}

public PosMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new cfgindex = g_iMenuSelected[client];
		new trigger = g_iTriggers[cfgindex];

		decl Float:vPos[3];
		GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);

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
			TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);
		else
			SaveTrigger(client, cfgindex + 1, "vpos", vPos);

		g_iSelectedTrig = trigger;
		if( g_hTimerBeam == INVALID_HANDLE )
		{
			g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
		}

		DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
	}
}



// ====================================================================================================
//					TRIGGER BOX - SAVE / DELETE
// ====================================================================================================
SaveTrigger(client, index, String:sKey[], Float:vVec[3])
{
	new Handle:hFile = ConfigOpen();

	if( hFile != INVALID_HANDLE )
	{
		decl String:sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));
		if( KvJumpToKey(hFile, sTemp, true) )
		{
			IntToString(index, sTemp, sizeof(sTemp));

			if( KvJumpToKey(hFile, sTemp, true) )
			{
				KvSetVector(hFile, sKey, vVec);

				ConfigSave(hFile);

				if( client )
					PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Saved trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
			}
			else if( client )
			{
				PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
			}
		}
		else if( client )
		{
			PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
		}

		CloseHandle(hFile);
	}
}

DeleteTrigger(client, bool:trigger, cfgindex)
{
	new Handle:hFile = ConfigOpen();

	if( hFile != INVALID_HANDLE )
	{
		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( KvJumpToKey(hFile, sMap) )
		{
			decl String:sTemp[16];
			IntToString(cfgindex, sTemp, sizeof(sTemp));

			if( KvJumpToKey(hFile, sTemp) )
			{
				if( trigger == true )
				{
					if( IsValidEntRef(g_iTriggers[cfgindex-1]) )
						AcceptEntityInput(g_iTriggers[cfgindex-1], "Kill");
					g_iTriggers[cfgindex-1] = 0;

					KvDeleteKey(hFile, "vpos");
					KvDeleteKey(hFile, "vmax");
					KvDeleteKey(hFile, "vmin");
				}
				else
				{
					g_fTargetAng[cfgindex-1] = 0.0;
					g_vTargetZone[cfgindex-1] = Float:{ 0.0, 0.0, 0.0 };

					KvDeleteKey(hFile, "pos");
					KvDeleteKey(hFile, "ang");
				}

				decl Float:vPos[3];
				if( trigger == true )
					KvGetVector(hFile, "pos", vPos);
				else
					KvGetVector(hFile, "vpos", vPos);

				KvGoBack(hFile);

				if( vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0 )
				{
					for( new i = cfgindex; i < MAX_ENTITIES; i++ )
					{
						g_iTriggers[i-1] = g_iTriggers[i];
						g_iTriggers[i] = 0;

						g_fTargetAng[i-1] = g_fTargetAng[i];
						g_fTargetAng[i] = 0.0;

						g_vTargetZone[i-1] = g_vTargetZone[i];
						g_vTargetZone[i] = Float:{ 0.0, 0.0, 0.0 };

						IntToString(i+1, sTemp, sizeof(sTemp));

						if( KvJumpToKey(hFile, sTemp) )
						{
							IntToString(i, sTemp, sizeof(sTemp));
							KvSetSectionName(hFile, sTemp);
							KvGoBack(hFile);
						}
					}
				}

				ConfigSave(hFile);

				PrintToChat(client, "%sAirstrike TriggerBox removed from config.", CHAT_TAG);
			}
		}

		CloseHandle(hFile);
	}
}



// ====================================================================================================
//					TRIGGER BOX - SPAWN TRIGGER / TOUCH CALLBACK
// ====================================================================================================
CreateTrigger(index = -1, client)
{
	if( index == -1 )
	{
		for( new i = 0; i < MAX_ENTITIES; i++ )
		{
			if( g_vTargetZone[i][0] == 0.0 && g_vTargetZone[i][1] == 0.0 && g_vTargetZone[i][2] == 0.0 && IsValidEntRef(g_iTriggers[i]) == false )
			{
				index = i;
				break;
			}
		}
	}
	if( index == -1 )
	{
		PrintToChat(client, "%sError: Cannot create a new group, you must pair to a Target Zone or replace/delete triggers.", CHAT_TAG);
		return;
	}

	decl Float:vPos[3];
	GetClientAbsOrigin(client, vPos);

	g_iRefireCount[index] = 0;
	index += 1;

	CreateTriggerMultiple(index, vPos, Float:{ 25.0, 25.0, 100.0}, Float:{ -25.0, -25.0, 0.0 });

	SaveTrigger(client, index, "vpos", vPos);
	SaveTrigger(client, index, "vmax", Float:{ 25.0, 25.0, 100.0});
	SaveTrigger(client, index, "vmin", Float:{ -25.0, -25.0, 0.0 });

	g_iSelectedTrig = g_iTriggers[index-1];

	if( g_hTimerBeam == INVALID_HANDLE )
	{
		g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
	}
}

CreateTriggerMultiple(index, Float:vPos[3], Float:vMaxs[3], Float:vMins[3])
{
	new trigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(trigger, "StartDisabled", "1");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "entireteam", "0");
	DispatchKeyValue(trigger, "allowincap", "0");
	DispatchKeyValue(trigger, "allowghost", "0");

	DispatchSpawn(trigger);
	SetEntityModel(trigger, MODEL_BOX);

	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
	TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);

	if( g_hTimerEnable[index-1] != INVALID_HANDLE )
		CloseHandle(g_hTimerEnable[index-1]);
	g_hTimerEnable[index-1] = CreateTimer(g_fRefireTime[index-1], TimerEnable, index-1);

	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	g_iTriggers[index-1] = EntIndexToEntRef(trigger);
}

public Action:TimerEnable(Handle:timer, any:index)
{
	g_hTimerEnable[index] = INVALID_HANDLE;

	new entity = g_iTriggers[index];
	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "Enable");
}

public OnStartTouch(const String:output[], caller, activator, Float:delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 )
	{
		caller = EntIndexToEntRef(caller);

		for( new i = 0; i < MAX_ENTITIES; i++ )
		{
			if( caller == g_iTriggers[i] )
			{
				AcceptEntityInput(caller, "Disable");

				if( g_iRefireCount[i] == 0 ) // Unlimited refires or limited, create timer to enable the trigger.
				{
					// F18_ShowAirstrike(g_vTargetZone[i][0], g_vTargetZone[i][1], g_vTargetZone[i][2], g_fTargetAng[i]);
					ShowAirStrike(i);

					if( g_hTimerEnable[i] != INVALID_HANDLE )
						CloseHandle(g_hTimerEnable[i]);
					g_hTimerEnable[i] = CreateTimer(g_fRefireTime[i], TimerEnable, i);
				}
				else
				{
					new fired = GetEntProp(caller, Prop_Data, "m_iHammerID");

					if( g_iRefireCount[i] > fired )
					{
						ShowAirStrike(i);

						SetEntProp(caller, Prop_Data, "m_iHammerID", fired + 1);
						if( fired + 1 != g_iRefireCount[i] )
						{
							if( g_hTimerEnable[i] != INVALID_HANDLE )
								CloseHandle(g_hTimerEnable[i]);
							g_hTimerEnable[i] = CreateTimer(g_fRefireTime[i], TimerEnable, i);
						}
					}
				}

				break;
			}
		}
	}
}

ShowAirStrike(i)
{
	new count = g_iRefireAtOnce[i];

	if( count > 1 )
	{
		if( count > 7 ) count = 7;
		
		for( new loop = 1; loop < count; loop++ )
		{
			CreateTimer(0.3 * loop, TimerCreate, i);
		}
	}

	F18_ShowAirstrike(g_vTargetZone[i][0], g_vTargetZone[i][1], g_vTargetZone[i][2], g_fTargetAng[i]);
}

public Action:TimerCreate(Handle:timer, any:i)
{
	F18_ShowAirstrike(g_vTargetZone[i][0], g_vTargetZone[i][1], g_vTargetZone[i][2], g_fTargetAng[i]);
}



// ====================================================================================================
//					TRIGGER BOX - DISPLAY BEAM BOX
// ====================================================================================================
public Action:TimerBeam(Handle:timer)
{
	if( IsValidEntRef(g_iSelectedTrig) )
	{
		decl Float:vMaxs[3], Float:vMins[3], Float:vPos[3];
		GetEntPropVector(g_iSelectedTrig, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(g_iSelectedTrig, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(g_iSelectedTrig, Prop_Send, "m_vecMins", vMins);
		AddVectors(vPos, vMaxs, vMaxs);
		AddVectors(vPos, vMins, vMins);
		TE_SendBox(vMins, vMaxs);
		return Plugin_Continue;
	}

	g_hTimerBeam = INVALID_HANDLE;
	return Plugin_Stop;
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
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.2, 1.0, 1.0, 1, 0.0, { 255, 155, 0, 255 }, 0);
	TE_SendToAll();
}



// ====================================================================================================
//					CONFIG - OPEN
// ====================================================================================================
Handle:ConfigOpen()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	new Handle:hFile = CreateKeyValues("airstrike");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return INVALID_HANDLE;
	}

	return hFile;
}



// ====================================================================================================
//					CONFIG - SAVE
// ====================================================================================================
ConfigSave(Handle:hFile)
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);

	if( !FileExists(sPath) )
		return;

	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
}



// ====================================================================================================
//					OTHER
// ====================================================================================================
bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}