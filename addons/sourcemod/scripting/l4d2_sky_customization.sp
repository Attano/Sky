#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_direct>
#include <l4d_stocks>
#include <left4downtown>
#include <l4d2lib>
#include <l4d2_penalty_bonus>
#include <bosspercent>

/*
* Version 2.0
* - Changed canister bonus to rely on penalty_bonus instead of custom logic, for the sake of compatibility l4d2_penalty_bonus.smx
* - Added compatibility with l4d2_boss_manager.smx/l4d_boss_percent.smx
*
* Version 1.9.2
* - Fixed c2m3_coaster event subtletie: killed survivors drop a glowing pipebomb, making it easier to spot
* - Fixed silent_cvar being 'vocal' when used with cvars that have the FCVAR_NOTIFY flag
* - Added c8m4_interior event subtletie: dropped cola bottles have a special glow, making them easier to spot
* 
* Version 1.9.1
* - Added a console command to reflect current Scavenge bonus
* - Added a round_end print to reflect the obtained Scavenge bonus
* 
* Version 1.9
* - Added functionality for rewarding linear Survivor progress on Scavenge sections 
* - Replaced method of selective tank extinguishing with an appropriate one
* 
* Version 1.8
* - Added static tank spawn at 40% on c2m4_barns
* 
* Version 1.7
* - Restructured internal complex event handlers
* - Added support for C12m2_traintunnel train lever/roll event subtleties
* 
* Version 1.6
* - Added static tank spawn at 21% on ñ12m4_barn
* - Added support for silent convar changes(any flags)
* 
* Version 1.5
* - Added Survivor corpse ragdolls functionality, enabled by default
* - Implemented a wider use of l4d_stocks functions where feasible
* - Moved manual late weapon spawner to l4d2_sky_weaponry
* 
* Version 1.4
* - Added manual late weapon spawner for the unprecached(by default) CSS weapons using console command syntax
* 
* Version 1.3 [l4d2_sky_customization] (Visor, JaneDoe)
* - Added handling of c2m3_coaster pipe bomb wall event subtleties
* 
* Version 1.2
* - Added an auto fire extinguisher feature for Tanks on maps with scavenge sections, due to the possibility of canister misuse
* 
* Version 1.1
* - Added static tank spawn at 21% on c4m4_milltown_b
* 
* Version 1.0 [l4d2_custom_bosses] (vintik)
* - Initial Release
* - Witch bride & Sacrifice Tank: Changes witch and tank models on certain maps
*/

#define BRIDE_MODEL                 "models/infected/witch_bride.mdl"
#define TANK_S_MODEL                "models/infected/hulk_dlc3.mdl"

#define L4D2_WEAPONSLOT_GRENADE     2

#define C2M3_EVENT_ID               1
#define C2M3_PIPEBOMB_WALL_BUTTON   "sky_button_01"
#define C2M3_BODY_LOOT_BUTTON       "sky_button_02"
#define L4D2_ANIMATION_REVIVE       44
#define L4D2_ANIMATION_IDLE         20

#define C12M2_EVENT_ID              2
#define C12M2_LEVER                 "sky_train_button_model_a"
#define C12M2_LEVER_TRIGGER         "sky_train_lever_button"
#define C12M2_LEVER_OWNER           "player_owner"
#define C12M2_LEVER_BUTTON          "sky_train_button"

#define C8M4_EVENT_ID              	3
#define C8M4_COLA_BOTTLES			"cola_bottles"
#define C8M4_COLA_BOTTLES_GLOW_COLOR	{220, 60, 120}

new Handle:hWitchMapTrie = INVALID_HANDLE;
new Handle:hTankMapTrie = INVALID_HANDLE;
new Handle:hFixedTankSpawnsMapTrie = INVALID_HANDLE;
new Handle:hComplexEventMapTrie = INVALID_HANDLE;
new Handle:hRagdollCorpsesEnabled = INVALID_HANDLE;
new Handle:hScavengeMapTrie = INVALID_HANDLE;

new bool:bShouldReplaceWitch;
new bool:bShouldReplaceTank;
new bool:bRagdollCorpsesEnabled;
new bool:bCorpseLootAnimationRunning[MAXPLAYERS + 1] = false;
new bool:bScavengeOnMap;

new iComplexEventID;
new iComplexEventEntity;
new iComplexEventClient;
new iMaxIncaps;
new iScavengeBonus[2];

new bool:bRoundOver;

public Plugin:myinfo = 
{
	name = "Confogl Sky Customization Plugin",
	author = "Visor, JaneDoe",
	description = "Everything Stripper can't do",
	version = "2.0e",
	url = "http://shantisbitches.ru/confogl-sky/"
}

public OnPluginStart()
{
	decl String:sGame[128];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	
	hRagdollCorpsesEnabled = CreateConVar("sky_ragdoll_survivors", "0", "Enable Survivor ragdoll corpses", FCVAR_PLUGIN);
	
	bRagdollCorpsesEnabled = GetConVarBool(hRagdollCorpsesEnabled);
	iMaxIncaps = GetConVarInt(FindConVar("survivor_max_incapacitated_count"));
	
	HookEvent("witch_spawn", OnBossSpawn);
	HookEvent("tank_spawn", OnBossSpawn);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_use", OnPlayerUse);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEndEvent, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", OnBotReplacePlayer, EventHookMode_Pre);
	HookEvent("player_team", OnTeamChange);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("weapon_drop", OnWeaponDrop, EventHookMode_Pre);
	HookEvent("server_cvar", OnServerCvar, EventHookMode_Pre);
	
	hWitchMapTrie = BuildWitchMapTrie();
	hTankMapTrie = BuildTankMapTrie();
	hFixedTankSpawnsMapTrie = BuildFixedTankSpawnsMapTrie();
	hComplexEventMapTrie = BuildComplexEventTrie();
	hScavengeMapTrie = BuildScavengeMapTrie();
	
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.basecommands");
	
	RegConsoleCmd("sm_health", Command_Scavenge_Bonus);
	
	RegAdminCmd("sm_cvar_silent", Command_Silent_Cvar, ADMFLAG_CONVARS, "sm_cvar_silent <cvar> [value]");
	RegAdminCmd("sm_add_canister_points", Command_Canister_Poured_Add_Points, ADMFLAG_CONVARS, "sm_add_canister_points [amount of points]");
}

public Action:OnServerCvar(Handle:event, const String:name[], bool:dontBroadcast)
{
    return Plugin_Handled;
}

public Action:Command_Scavenge_Bonus(client, args)
{
	if (bScavengeOnMap)
		ReplyToCommand(client, "\x01<\x05ScoreMod\x01> Scavenge Bonus: \x05%d\x01", iScavengeBonus[GameRules_GetProp("m_bInSecondHalfOfRound")]);
}

public Action:RoundEndEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bScavengeOnMap && !bRoundOver)
	{
		bRoundOver = true;
		
		PrintToChatAll("\x01<\x05ScoreMod\x01> Round 1 Scavenge Bonus: \x05%d\x01", iScavengeBonus[0]);
		if (GameRules_GetProp("m_bInSecondHalfOfRound")) PrintToChatAll("\x01<\x05ScoreMod\x01> Round 2 Scavenge Bonus: \x05%d\x01", iScavengeBonus[1]);
	}
}

public Action:Command_Canister_Poured_Add_Points(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "sm_add_canister_points [amount of points]");
		return Plugin_Handled;
	}

	decl String:buffer[16];
	GetCmdArg(1, buffer, sizeof(buffer));
	new iPoints = StringToInt(buffer);
	
	iScavengeBonus[GameRules_GetProp("m_bInSecondHalfOfRound")] += iPoints;
	PBONUS_AddRoundBonus(iPoints);
	return Plugin_Handled;
}

public Action:Command_Silent_Cvar(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cvar_silent <cvar> [value]");
		return Plugin_Handled;
	}

	decl String:cvarname[64];
	GetCmdArg(1, cvarname, sizeof(cvarname));

	new Handle:hndl = FindConVar(cvarname);
	if (hndl == INVALID_HANDLE)
	{
		ReplyToCommand(client, "[SM] %t", "Unable to find cvar", cvarname);
		return Plugin_Handled;
	}

	decl String:value[255];
	if (args < 2)
	{
		GetConVarString(hndl, value, sizeof(value));

		ReplyToCommand(client, "[SM] %t", "Value of cvar", cvarname, value);
		return Plugin_Handled;
	}

	GetCmdArg(2, value, sizeof(value));
	SetConVarString(hndl, value);
	ReplyToCommand(client, "[SM] %t", "Cvar changed", cvarname, value);

	return Plugin_Handled;
}

public OnMapStart()
{
	new String:sBuffer[128];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	
	bShouldReplaceWitch = false;
	bShouldReplaceTank = false;
	bScavengeOnMap = false;
	iComplexEventID = -1;
	iComplexEventEntity = -1;
	iComplexEventClient = -1;
	iScavengeBonus[0] = 0;
	iScavengeBonus[1] = 0;
		
	GetTrieValue(hWitchMapTrie, sBuffer, bShouldReplaceWitch);
	GetTrieValue(hTankMapTrie, sBuffer, bShouldReplaceTank);
	GetTrieValue(hComplexEventMapTrie, sBuffer, iComplexEventID);
	GetTrieValue(hScavengeMapTrie, sBuffer, bScavengeOnMap);
	
	if (!IsModelPrecached(BRIDE_MODEL)) PrecacheModel(BRIDE_MODEL);
	if (!IsModelPrecached(TANK_S_MODEL)) PrecacheModel(TANK_S_MODEL);
}

public OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (L4DTeam:GetClientTeam(client) == L4DTeam_Infected && L4D2ZombieClassType:L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
	{
		if (GetEntityFlags(client) & FL_ONFIRE) ExtinguishEntity(client);
	}

	if (bRagdollCorpsesEnabled)
	{
		if (client <= 0 || client > MaxClients || !IsClientInGame(client) || L4DTeam:GetClientTeam(client) != L4DTeam_Survivor || !IsPlayerAlive(client))
			return;

		new damage = GetEventInt(event, "dmg_health");
		new health = GetClientHealth(client) + L4D_GetPlayerTempHealth(client);

		if (damage < health || damage == 0)
			return;

		/* Witch only deals damage if she instant kills, otherwise player_hurt does not trigger at all for witch target */
		new witch = GetEventInt(event, "attackerentid");
		decl String:classname[64];
		new bool:isWitchAttack = false;
		if (witch > 0 && witch < 2048 && IsValidEntity(witch))
		{
			GetEdictClassname(witch, classname, sizeof(classname));
			isWitchAttack = StrEqual(classname, "witch") || StrEqual(classname, "witch_bride");
		}

		if (!isWitchAttack && !L4D_IsPlayerIncapacitated(client) && L4D_GetPlayerReviveCount(client) < iMaxIncaps)
			return;

		SetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1);
	}
}

public Action:RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:sBuffer[128];
	GetCurrentMap(sBuffer, sizeof(sBuffer));

	// Static tank spawn
	new Float:fFlow;
	if (GetTrieValue(hFixedTankSpawnsMapTrie, sBuffer, fFlow))
	{
		CreateTimer(2.1, AdjustTankSpawn, fFlow, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(6.1, DeleteTankSpawn, TIMER_FLAG_NO_MAPCHANGE);
	}

	// Reset defib penalty cvar
	SetConVarInt(FindConVar("vs_defib_penalty"), 0);
	bRoundOver = false;
}

public Action:AdjustTankSpawn(Handle:timer, any:flow)
{
	L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	L4D2Direct_SetVSTankFlowPercent(0, flow);
	L4D2Direct_SetVSTankFlowPercent(1, flow);
	UpdateBossPercents();
}

public Action:DeleteTankSpawn(Handle:timer)
{
	L4D2Direct_SetVSTankToSpawnThisRound(0, false);
	L4D2Direct_SetVSTankToSpawnThisRound(1, false);
}

public Action:OnBossSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (StrEqual(name, "witch_spawn"))
	{
		if (bShouldReplaceWitch)
		{
			new iWitch = GetEventInt(event, "witchid");
			SetEntityModel(iWitch, BRIDE_MODEL);
		}
	}
	else if (StrEqual(name, "tank_spawn"))
	{
		if (bShouldReplaceTank)
		{
			new iTank = GetEventInt(event, "tankid");
			SetEntityModel(iTank, TANK_S_MODEL);
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (iComplexEventID == C2M3_EVENT_ID)
	{
		if (buttons & IN_ATTACK)
		{
			new String:classname[64];
			GetClientWeapon(client, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_pipe_bomb"))
			{
				buttons &= ~IN_ATTACK;
				PrintHintText(client, "Item cannot be used outside of its related event.");
			}
		}

		if (!(buttons & IN_USE))
		{
			if (bCorpseLootAnimationRunning[client])
			{
				L4D2Direct_DoAnimationEvent(client, L4D2_ANIMATION_IDLE);
				bCorpseLootAnimationRunning[client] = false;
			}
		}
	}
	
	return Plugin_Continue;
}

public OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	if (iComplexEventID == C12M2_EVENT_ID)
	{
		if (L4D2_Team:GetEventInt(event, "team") != L4D2_Team:L4DTeam_Survivor)
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			if (client > 0)
			{
				if (IsClientInGame(client))
				{
					decl String:sTargetName[64];
					GetEntPropString(client, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName), 0);
					if (StrEqual(sTargetName, C12M2_LEVER_OWNER))
					{
						ResetEventStageC12M2(client, iComplexEventEntity);
					}
				}
			}
		}
	}
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if (iComplexEventID == C12M2_EVENT_ID)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client <= 0)
			return Plugin_Continue;

		decl String:sTargetName[64];
		GetEntPropString(client, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName), 0);
		if (StrEqual(sTargetName, C12M2_LEVER_OWNER))
		{
			ResetEventStageC12M2(client, iComplexEventEntity);
		}
	}
	
	return Plugin_Continue;
}

public Action:OnPlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch (iComplexEventID)
	{
		case C2M3_EVENT_ID:
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			new entid = GetEventInt(event, "targetid");
			
			decl String:TargetName[64];
			GetEntPropString(entid, Prop_Data, "m_iName", TargetName, sizeof(TargetName), 0);
		
			if (StrEqual(TargetName, C2M3_PIPEBOMB_WALL_BUTTON))
			{
				if (IsValidEntity(GetPlayerWeaponSlot(client, L4D2_WEAPONSLOT_GRENADE)))
				{
					AcceptEntityInput(entid, "unlock");
				}
			}
			
			if (StrEqual(TargetName, C2M3_BODY_LOOT_BUTTON))
			{
				L4D2Direct_DoAnimationEvent(client, L4D2_ANIMATION_REVIVE);
				bCorpseLootAnimationRunning[client] = true;
			}
		}
		case C12M2_EVENT_ID:
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			new entid = GetEventInt(event, "targetid");
			
			decl String:TargetName[64];
			GetEntPropString(entid, Prop_Data, "m_iName", TargetName, sizeof(TargetName), 0);
		
			// Picking up the lever
			if (StrEqual(TargetName, C12M2_LEVER_TRIGGER))
			{
				new iEntity;
				while ((iEntity = FindEntityByClassname(iEntity, "prop_dynamic")) != -1)
				{
					GetEntPropString(iEntity, Prop_Data, "m_iName", TargetName, sizeof(TargetName), 0);
					if (StrEqual(TargetName, C12M2_LEVER))
					{
						iComplexEventEntity = iEntity;
						break;
					}
				}
				iComplexEventClient = client;
			}
			
			// Attempting to launch up the train roll
			if (StrEqual(TargetName, C12M2_LEVER_BUTTON))
			{
				GetEntPropString(client, Prop_Data, "m_iName", TargetName, sizeof(TargetName), 0);
				if (StrEqual(TargetName, C12M2_LEVER_OWNER))
				{
					AcceptEntityInput(entid, "unlock");
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:OnWeaponDrop(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch (iComplexEventID)
	{
		case C2M3_EVENT_ID:
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			new PipeBomb = GetPlayerWeaponSlot(client, L4D2_WEAPONSLOT_GRENADE);
			if (!IsValidEntity(PipeBomb)) return Plugin_Continue;
			
			L4D2_SetEntityGlow(PipeBomb, L4D2Glow_Constant, 0, 22, {255, 102, 51}, true);
			SDKHooks_DropWeapon(client, PipeBomb);
		}
		case C8M4_EVENT_ID:
		{
			decl String:classname[64];
			GetEventString(event, "item", classname, sizeof(classname));
			
			// Setting up glow
			if (StrEqual(classname, C8M4_COLA_BOTTLES))
			{
				L4D2_SetEntityGlow(GetEventInt(event, "propid"), L4D2Glow_Constant, 0, 22, C8M4_COLA_BOTTLES_GLOW_COLOR, true);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_SetTransmit(entity, client)
{ 
	if (client == iComplexEventClient)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action:OnBotReplacePlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (iComplexEventID == C2M3_EVENT_ID)
	{
		new bot = GetClientOfUserId(GetEventInt(event, "bot"));
		new PipeBomb = GetPlayerWeaponSlot(bot, L4D2_WEAPONSLOT_GRENADE);
		if (!IsValidEntity(PipeBomb)) return Plugin_Continue;
		
		L4D2_SetEntityGlow(PipeBomb, L4D2Glow_Constant, 0, 22, {255, 102, 51}, true);
		SDKHooks_DropWeapon(bot, PipeBomb);
	}
	else if (iComplexEventID == C12M2_EVENT_ID)
	{
		new player = GetClientOfUserId(GetEventInt(event, "player"));
		if (player == iComplexEventClient)
		{
			ResetEventStageC12M2(player, iComplexEventEntity);
		}
	}
	
	return Plugin_Continue;
}

ResetEventStageC12M2(client, entity)
{
	DispatchKeyValue(client, "targetname", "");
	AcceptEntityInput(entity, "ClearParent");
	AcceptEntityInput(entity, "StartGlowing");
	
	//SDKUnHook(iComplexEventEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	iComplexEventClient = -1;
}

Handle:BuildWitchMapTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c1m1_hotel", true);
	SetTrieValue(trie, "c1m2_streets", true);
	SetTrieValue(trie, "c2m1_highway", true);
	SetTrieValue(trie, "c2m2_fairgrounds", true);
	SetTrieValue(trie, "c2m3_coaster", true);
	SetTrieValue(trie, "c2m4_barns", true);
	SetTrieValue(trie, "c4m1_milltown_a", true);
	SetTrieValue(trie, "c4m3_sugarmill_b", true);
	SetTrieValue(trie, "c5m1_waterfront", true);
	SetTrieValue(trie, "c5m2_park", true);
	SetTrieValue(trie, "c5m3_cemetery", true);
	SetTrieValue(trie, "c8m1_apartment", true);
	SetTrieValue(trie, "c10m4_mainstreet", true);
	SetTrieValue(trie, "c11m1_greenhouse", true);
	SetTrieValue(trie, "c11m2_offices", true);
	SetTrieValue(trie, "C12m4_barn", true);
	return trie;    
}

Handle:BuildTankMapTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c1m2_streets", true);
	SetTrieValue(trie, "c2m1_highway", true);
	SetTrieValue(trie, "c2m3_coaster", true);
	SetTrieValue(trie, "c2m4_barns", true);
	SetTrieValue(trie, "c3m1_plankcountry", true);
	SetTrieValue(trie, "c4m4_milltown_b", true);
	SetTrieValue(trie, "c5m2_park", true);
	SetTrieValue(trie, "c5m3_cemetery", true);
	SetTrieValue(trie, "c8m2_subway", true);
	SetTrieValue(trie, "c8m4_interior", true);
	SetTrieValue(trie, "c10m2_drainage", true);
	SetTrieValue(trie, "c11m3_garage", true);
	SetTrieValue(trie, "c11m4_terminal", true);
	SetTrieValue(trie, "C12m1_hilltop", true);
	SetTrieValue(trie, "C12m4_barn", true);
	return trie;    
}

Handle:BuildFixedTankSpawnsMapTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c2m4_barns", 0.40);
	SetTrieValue(trie, "c4m4_milltown_b", 0.21);
	SetTrieValue(trie, "C12m4_barn", 0.21);
	return trie;
}

Handle:BuildComplexEventTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c2m3_coaster", C2M3_EVENT_ID);
	SetTrieValue(trie, "C12m2_traintunnel", C12M2_EVENT_ID);
	SetTrieValue(trie, "c8m4_interior", C8M4_EVENT_ID);
	return trie;
}

Handle:BuildScavengeMapTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c2m2_fairgrounds", true);
	SetTrieValue(trie, "c3m1_plankcountry", true);
	SetTrieValue(trie, "c4m2_sugarmill_a", true);
	SetTrieValue(trie, "c5m4_quarter", true);
	SetTrieValue(trie, "c8m4_interior", true);
	SetTrieValue(trie, "c10m2_drainage", true);
	SetTrieValue(trie, "c11m4_terminal", true);
	SetTrieValue(trie, "C12m3_bridge", true);
	return trie;
}