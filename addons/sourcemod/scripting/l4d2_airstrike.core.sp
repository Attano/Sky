#define PLUGIN_VERSION		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] F-18 Airstrike (Sky)
*	Author	:	SilverShot, JaneDoe
*	Descrp	:	Creates F-18 fly bys which shoot missiles to where they were triggered from.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=187567

========================================================================================
	Change Log:
	
1.2 (01-April-2015)
	- Fixed the jet/missile spawning on most maps with high or low skyboxes, should work fine now. (SilverShot)

1.1 (20-Jun-2012)
	- Added a hard limit of 8 AirStrikes at one time, in an attempt to prevent some players from crashing.
	- Added cvar "l4d2_airstrike_shake" to set the range at which the explosion can shake players screens.
	- Added cvar "l4d2_airstrike_vocalize" to set the chance to vocalize the player nearest the explosion.
	- Changed some default cvar values.
	- Small fixes.

1.0 (15-Jun-2012)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Downtown1", "ProdigySim" and "psychonic" for "[EXTENSION] Left 4 Downtown 2 L4D2 Only" - Used gamedata to stumble players.
	http://forums.alliedmods.net/showthread.php?t=134032

======================================================================================*/

#pragma semicolon 			1

#include <l4d2_airstrike>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define CHAT_TAG			"\x03[Airstrike] \x05"
#define MAX_ENTITIES		8

#define MODEL_AGM65			"models/missiles/f18_agm65maverick.mdl"
#define MODEL_F18			"models/f18/f18_sb.mdl"
#define MODEL_BOX			"models/props/cs_militia/silo_01.mdl"
#define SOUND_OVER1			"ambient/overhead/plane1.wav"
#define SOUND_OVER2			"ambient/overhead/plane2.wav"
#define SOUND_OVER3			"ambient/overhead/plane3.wav"
#define SOUND_PASS1			"animation/jets/jet_by_01_mono.wav"
#define SOUND_PASS2			"animation/jets/jet_by_02_mono.wav"
#define SOUND_PASS3			"animation/jets/jet_by_01_lr.wav"
#define SOUND_PASS4			"animation/jets/jet_by_02_lr.wav"
#define SOUND_PASS5			"animation/jets/jet_by_03_lr.wav"
#define SOUND_PASS6			"animation/jets/jet_by_04_lr.wav"
#define SOUND_PASS7			"animation/jets/jet_by_05_lr.wav"
#define SOUND_PASS8			"animation/jets/jet_by_05_rl.wav"

#define SOUND_EXPLODE3		"weapons/hegrenade/explode3.wav"
#define SOUND_EXPLODE4		"weapons/hegrenade/explode4.wav"
#define SOUND_EXPLODE5		"weapons/hegrenade/explode5.wav"

#define PARTICLE_BOMB1		"FluidExplosion_fps"
#define PARTICLE_BOMB2		"missile_hit1"
#define PARTICLE_BOMB3		"gas_explosion_main"
#define PARTICLE_BOMB4		"explosion_huge"
#define PARTICLE_BLUE		"flame_blue"
#define PARTICLE_FIRE		"fire_medium_01"
#define PARTICLE_SPARKS		"fireworks_sparkshower_01e"
#define PARTICLE_SMOKE		"rpg_smoke"

static	Handle:g_hCvarAllow, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog, Handle:g_hCvarDamage, Handle:g_hCvarDistance,
		Handle:g_hCvarHorde, Handle:g_hCvarShake, Handle:g_hCvarSpread, Handle:g_hCvarStumble, Handle:g_hCvarStyle, Handle:g_hCvarVocalize,
		bool:g_bCvarAllow, g_iCvarDamage, g_iCvarDistance, g_iCvarHorde, g_iCvarShake, g_iCvarSpread, g_iCvarStumble, g_iCvarStyle, g_iCvarVocalize;

static	Handle:g_hConfStagger, Handle:g_hForwardPluginState, Handle:g_hForwardRoundState, bool:g_bPluginTrigger,
		Handle:g_hMPGameMode, g_iPlayerSpawn, g_iRoundStart, bool:g_bLateLoad,
		g_iEntities[MAX_ENTITIES];



// ====================================================================================================
//					NATIVES
// ====================================================================================================
public Native_ShowAirstrike(Handle:hPlugin, iNumParams)
{
	decl Float:vPos[3];
	vPos[0] = Float:GetNativeCell(1);
	vPos[1] = Float:GetNativeCell(2);
	vPos[2] = Float:GetNativeCell(3);
	ShowAirstrike(vPos, Float:GetNativeCell(4));
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D2] F-18 Airstrike (Sky)",
	author = "SilverShot",
	description = "Creates F-18 fly bys which shoot missiles to where they were triggered from.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=187567"
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

	g_bLateLoad = late;
	RegPluginLibrary("l4d2_airstrike");
	CreateNative("F18_ShowAirstrike", Native_ShowAirstrike);

	return APLRes_Success;
}

public OnPluginStart()
{
	new Handle:hConf = LoadGameConfigFile("l4d2_airstrike");
	if( hConf == INVALID_HANDLE )
		SetFailState("Missing required 'gamedata/l4d2_airstrike.txt', please re-download.");		
	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
		SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	g_hConfStagger = EndPrepSDKCall();
	if( g_hConfStagger == INVALID_HANDLE )
		SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");

	g_hForwardPluginState = CreateGlobalForward("F18_OnPluginState", ET_Ignore, Param_Cell);
	g_hForwardRoundState = CreateGlobalForward("F18_OnRoundState", ET_Ignore, Param_Cell);

	g_hCvarAllow =			CreateConVar(	"l4d2_airstrike_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d2_airstrike_damage",		"200",			"Hurt players by this much at the center of the explosion. Damages falls off based on the maximum distance.", CVAR_FLAGS );
	g_hCvarDistance =		CreateConVar(	"l4d2_airstrike_distance",		"500",			"The range at which the airstrike explosion can hurt players.", CVAR_FLAGS );
	g_hCvarHorde =			CreateConVar(	"l4d2_airstrike_horde",			"5",			"0=Off. The chance out of 100 to make a panic event when the bomb explodes.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d2_airstrike_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d2_airstrike_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d2_airstrike_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarShake =			CreateConVar(	"l4d2_airstrike_shake",			"1000",			"The range at which the explosion can shake players screens.", CVAR_FLAGS );
	g_hCvarSpread =			CreateConVar(	"l4d2_airstrike_spread",		"100",			"The maximum distance to vary the missile target zone.", CVAR_FLAGS );
	g_hCvarStumble =		CreateConVar(	"l4d2_airstrike_stumble",		"400",			"0=Off, Range at which players are stumbled from the explosion.", CVAR_FLAGS );
	g_hCvarStyle =			CreateConVar(	"l4d2_airstrike_style",			"15",			"1=Blue Fire, 2=Flames, 4=Sparks, 8=RPG Smoke, 15=All.", CVAR_FLAGS );
	g_hCvarVocalize =		CreateConVar(	"l4d2_airstrike_vocalize",		"20",			"0=Off. The chance out of 100 to vocalize the player nearest the explosion.", CVAR_FLAGS );
	CreateConVar(							"l4d2_airstrike_version",		PLUGIN_VERSION,	"F-18 Airstrike plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d2_airstrike");

	g_hMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hMPGameMode,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesTog,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarDamage,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarDistance,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarHorde,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarShake,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarSpread,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarStumble,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarStyle,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarVocalize,		ConVarChanged_Cvars);

	RegAdminCmd("sm_strike",				CmdAirstrikeMenu,	ADMFLAG_ROOT,	"Displays a menu with options to show/save a airstrike and triggers.");
}

public OnPluginEnd()
{
	ResetPlugin();
}

public OnAllPluginsLoaded()
{
	if( LibraryExists("l4d2_airstrike.triggers") == true )
	{
		g_bPluginTrigger = true;
	}
}

public OnLibraryAdded(const String:name[])
{
	if( strcmp(name, "l4d2_airstrike.triggers") == 0 )
	{
		g_bPluginTrigger = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if( strcmp(name, "l4d2_airstrike.triggers") == 0 )
	{
		g_bPluginTrigger = false;
	}
}

public OnMapStart()
{
	PrecacheParticle(PARTICLE_BOMB1);
	PrecacheParticle(PARTICLE_BOMB2);
	PrecacheParticle(PARTICLE_BOMB3);
	PrecacheParticle(PARTICLE_BOMB4);
	PrecacheParticle(PARTICLE_BLUE);
	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_SMOKE);
	PrecacheParticle(PARTICLE_SPARKS);
	PrecacheModel(MODEL_AGM65, true);
	PrecacheModel(MODEL_F18, true);
	PrecacheModel(MODEL_BOX, true);
	PrecacheSound(SOUND_PASS1, true);
	PrecacheSound(SOUND_PASS2, true);
	PrecacheSound(SOUND_PASS3, true);
	PrecacheSound(SOUND_PASS4, true);
	PrecacheSound(SOUND_PASS5, true);
	PrecacheSound(SOUND_PASS6, true);
	PrecacheSound(SOUND_PASS7, true);
	PrecacheSound(SOUND_PASS8, true);
}

public OnMapEnd()
{
	ResetPlugin();
	OnRoundState(0);
}

ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
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
	g_iCvarDamage = GetConVarInt(g_hCvarDamage);
	g_iCvarDistance = GetConVarInt(g_hCvarDistance);
	g_iCvarHorde = GetConVarInt(g_hCvarHorde);
	g_iCvarShake = GetConVarInt(g_hCvarShake);
	g_iCvarSpread = GetConVarInt(g_hCvarSpread);
	g_iCvarStumble = GetConVarInt(g_hCvarStumble);
	g_iCvarStyle = GetConVarInt(g_hCvarStyle);
	g_iCvarVocalize = GetConVarInt(g_hCvarVocalize);
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);

		Call_StartForward(g_hForwardPluginState);
		Call_PushCell(1);
		Call_Finish();

		if( g_bLateLoad == true )
		{
			g_bLateLoad = false;
			OnRoundState(1);
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);

		Call_StartForward(g_hForwardPluginState);
		Call_PushCell(0);
		Call_Finish();
	}
}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hMPGameMode == INVALID_HANDLE )
		return false;

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
	OnRoundState(0);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
	{
		CreateTimer(1.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iRoundStart = 1;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
	{
		CreateTimer(1.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iPlayerSpawn = 1;
}

public Action:tmrStart(Handle:timer)
{
	OnRoundState(1);
}

OnRoundState(roundstate)
{
	static mystate;

	if( roundstate == 1 && mystate == 0 )
	{
		mystate = 1;
		Call_StartForward(g_hForwardRoundState);
		Call_PushCell(1);
		Call_Finish();
	}
	else if( roundstate == 0 && mystate == 1 )
	{
		mystate = 0;
		Call_StartForward(g_hForwardRoundState);
		Call_PushCell(0);
		Call_Finish();
	}
}



// ====================================================================================================
//					COMMANDS
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
	if( g_bPluginTrigger == true )
		AddMenuItem(hMenu, "3", "Airstrike Triggers");
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
				ShowAirstrike(vPos, direction);
			}

			CloseHandle(trace);
			ShowMenuMain(client);
		}
		else if( index == 1 )
		{
			decl Float:vPos[3], Float:vAng[3];
			GetClientAbsOrigin(client, vPos);
			GetClientEyeAngles(client, vAng);
			ShowAirstrike(vPos, vAng[1]);
			ShowMenuMain(client);
		}
		else if( index == 2 )
		{
			FakeClientCommand(client, "sm_strike_triggers");
		}
	}
}

public bool:TraceFilter(entity, contentsMask)
{
	return entity > MaxClients;
}



// ====================================================================================================
//					SHOW AIRSTRIKE
// ====================================================================================================
ShowAirstrike(Float:vPos[3], Float:direction)
{
	new index = -1;
	for( new i = 0; i < MAX_ENTITIES; i++ )
	{
		if( IsValidEntRef(g_iEntities[i]) == false )
		{
			index = i;
			break;
		}
	}

	if( index == -1 )
		return;

	decl Float:vAng[3], Float:vSkybox[3];
	vAng[0] = 0.0;
	vAng[1] = direction;
	vAng[2] = 0.0;

	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vSkybox);

	new entity = CreateEntityByName("prop_dynamic_override");
	g_iEntities[index] = EntIndexToEntRef(entity);
	DispatchKeyValue(entity, "targetname", "silver_f18_model");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_F18);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Data, "m_iHammerID", RoundToNearest(vPos[2]));
	new Float:height = vPos[2] + 1150.0;
	if( height > vSkybox[2] - 200 )
		vPos[2] = vSkybox[2] - 200;
	else
		vPos[2] = height;
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 5.0);

	new random = GetRandomInt(1, 5);
	if( random == 1 )
		SetVariantString("flyby1");
	else if( random == 2 )
		SetVariantString("flyby2");
	else if( random == 3 )
		SetVariantString("flyby3");
	else if( random == 4 )
		SetVariantString("flyby4");
	else if( random == 5 )
		SetVariantString("flyby5");
	AcceptEntityInput(entity, "SetAnimation");
	AcceptEntityInput(entity, "Enable");

	SetVariantString("OnUser1 !self:Kill::6.5.0:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	CreateTimer(1.5, tmrDrop, EntIndexToEntRef(entity));
}

public Action:TimerGrav(Handle:timer, any:entity)
{
	if( IsValidEntRef(entity) )
		CreateTimer(0.1, TimerGravity, entity, TIMER_REPEAT);
}

public Action:TimerGravity(Handle:timer, any:entity)
{
	if( IsValidEntRef(entity) )
	{
		new tick = GetEntProp(entity, Prop_Data, "m_iHammerID");
		if( tick > 10 )
		{
			SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
			return Plugin_Stop;
		}
		else
		{
			SetEntProp(entity, Prop_Data, "m_iHammerID", tick + 1);

			decl Float:vAng[3];
			GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vAng);
			vAng[2] -= 50.0;
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vAng);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action:tmrDrop(Handle:timer, any:f18)
{
	if( IsValidEntRef(f18) )
	{
		decl Float:vPos[3], Float:vAng[3], Float:vVec[3];
		GetEntPropVector(f18, Prop_Data, "m_vecAbsOrigin", vPos);
		GetEntPropVector(f18, Prop_Data, "m_angRotation", vAng);

		new entity = CreateEntityByName("grenade_launcher_projectile");
		DispatchSpawn(entity);
		SetEntityModel(entity, MODEL_AGM65);

		SetEntityMoveType(entity, MOVETYPE_NOCLIP);
		CreateTimer(0.9, TimerGrav, EntIndexToEntRef(entity));

		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, -800.0);
		MoveForward(vPos, vAng, vPos, 2400.0);
		vPos[0] += GetRandomFloat(-1.0 * g_iCvarSpread, float(g_iCvarSpread));
		vPos[1] += GetRandomFloat(-1.0 * g_iCvarSpread, float(g_iCvarSpread));
		TeleportEntity(entity, vPos, vAng, vVec);

		SDKHook(entity, SDKHook_Touch, OnBombTouch);

		SetVariantString("OnUser1 !self:Kill::10.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.3);

		new projectile = entity;


		// BLUE FLAMES
		if( g_iCvarStyle & (1<<0) )
		{
			entity = CreateEntityByName("info_particle_system");
			if( entity != -1 )
			{
				DispatchKeyValue(entity, "effect_name", PARTICLE_BLUE);
				DispatchSpawn(entity);
				ActivateEntity(entity);
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", projectile);

				SetVariantString("OnUser4 !self:Kill::10.0:1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser4");
				AcceptEntityInput(entity, "Start");
			}
		}


		// FLAMES
		if( g_iCvarStyle & (1<<1) )
		{
			entity = CreateEntityByName("info_particle_system");
			if( entity != -1 )
			{
				DispatchKeyValue(entity, "effect_name", PARTICLE_FIRE);
				DispatchSpawn(entity);
				ActivateEntity(entity);
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", projectile);

				SetVariantString("OnUser4 !self:Kill::10.0:1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser4");
				AcceptEntityInput(entity, "Start");
			}
		}


		// SPARKS
		if( g_iCvarStyle & (1<<2) )
		{
			entity = CreateEntityByName("info_particle_system");
			if( entity != -1 )
			{
				DispatchKeyValue(entity, "effect_name", PARTICLE_SPARKS);
				DispatchSpawn(entity);
				ActivateEntity(entity);
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", projectile);

				SetVariantString("OnUser4 !self:Kill::10.0:1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser4");
				AcceptEntityInput(entity, "Start");
			}
		}


		// RPG SMOKE
		if( g_iCvarStyle & (1<<3) )
		{
			entity = CreateEntityByName("info_particle_system");
			if( entity != -1 )
			{
				DispatchKeyValue(entity, "effect_name", PARTICLE_SMOKE);
				DispatchSpawn(entity);
				ActivateEntity(entity);
				AcceptEntityInput(entity, "start");
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", projectile);

				SetVariantString("OnUser3 !self:Kill::10.0:1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser3");

				// Refire
				SetVariantString("OnUser1 !self:Stop::0.65:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:FireUser2::0.7:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");

				SetVariantString("OnUser2 !self:Start::0:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser2 !self:FireUser1::0:-1");
				AcceptEntityInput(entity, "AddOutput");
			}
		}


		// SOUND
		new random = GetRandomInt(1, 8);
		if( random == 1 )
			EmitSoundToAll(SOUND_PASS1, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 2 )
			EmitSoundToAll(SOUND_PASS2, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 3 )
			EmitSoundToAll(SOUND_PASS3, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 4 )
			EmitSoundToAll(SOUND_PASS4, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 5 )
			EmitSoundToAll(SOUND_PASS5, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 6 )
			EmitSoundToAll(SOUND_PASS6, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 7 )
			EmitSoundToAll(SOUND_PASS7, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		else if( random == 8 )
			EmitSoundToAll(SOUND_PASS8, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
	}
}

MoveForward(const Float:vPos[3], const Float:vAng[3], Float:vReturn[3], Float:fDistance)
{
	decl Float:vDir[3];
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vReturn = vPos;
	vReturn[0] += vDir[0] * fDistance;
	vReturn[1] += vDir[1] * fDistance;
	vReturn[2] += vDir[2] * fDistance;
}

public OnBombTouch(entity, activator)
{
	SDKUnhook(entity, SDKHook_Touch, OnBombTouch);

	CreateTimer(0.1, TimerBombTouch, EntIndexToEntRef(entity));
}

public Action:TimerBombTouch(Handle:timer, any:entity)
{
	if( EntRefToEntIndex(entity) == INVALID_ENT_REFERENCE )
		return;

	if( g_iCvarHorde && GetRandomInt(1, 100) <= g_iCvarHorde )
	{
		SetVariantString("OnTrigger director:ForcePanicEvent::1:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnTrigger @director:ForcePanicEvent::1:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "Trigger");
	}

	decl Float:vPos[3], String:sTemp[64];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	AcceptEntityInput(entity, "Kill");
	IntToString(g_iCvarDamage, sTemp, sizeof(sTemp));


	// Create explosion, kills infected, hurts special infected/survivors, pushes physics entities.
	entity = CreateEntityByName("env_explosion");
	DispatchKeyValue(entity, "spawnflags", "1916");
	IntToString(g_iCvarDamage, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "iMagnitude", sTemp);
	IntToString(g_iCvarDistance, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "iRadiusOverride", sTemp);
	DispatchSpawn(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "Explode");


	// Shake!
	new shake  = CreateEntityByName("env_shake");
	if( shake != -1 )
	{
		DispatchKeyValue(shake, "spawnflags", "21");
		DispatchKeyValue(shake, "amplitude", "16.0");
		DispatchKeyValue(shake, "frequency", "1.5");
		DispatchKeyValue(shake, "duration", "0.9");
		IntToString(g_iCvarShake, sTemp, sizeof(sTemp));
		DispatchKeyValue(shake, "radius", sTemp);
		DispatchSpawn(shake);
		ActivateEntity(shake);
		AcceptEntityInput(shake, "Enable");

		TeleportEntity(shake, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(shake, "StartShake");

		SetVariantString("OnUser1 !self:Kill::1.1:1");
		AcceptEntityInput(shake, "AddOutput");
		AcceptEntityInput(shake, "FireUser1");
	}


	// Loop through survivors, work out distance and stumble/vocalize.
	if( g_iCvarStumble || g_iCvarVocalize )
	{
		new client, Float:fDistance, Float:fNearest = 1500.0;
		decl Float:vPos2[3];

		for( new i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				GetClientAbsOrigin(i, vPos2);
				fDistance = GetVectorDistance(vPos, vPos2);

				if( g_iCvarVocalize && fDistance <= fNearest )
				{
					client = i;
					fNearest = fDistance;
				}

				if( g_iCvarStumble && fDistance <= g_iCvarStumble )
				{
					SDKCall(g_hConfStagger, i, shake, vPos);
				}
			}
		}

		if( client )
		{
			Vocalize(client);
		}
	}


	// Explosion effect
	entity = CreateEntityByName("info_particle_system");
	if( entity != -1 )
	{
		new random = GetRandomInt(1, 4);
		if( random == 1 )
			DispatchKeyValue(entity, "effect_name", PARTICLE_BOMB1);
		else if( random == 2 )
			DispatchKeyValue(entity, "effect_name", PARTICLE_BOMB2);
		else if( random == 3 )
			DispatchKeyValue(entity, "effect_name", PARTICLE_BOMB3);
		else if( random == 4 )
			DispatchKeyValue(entity, "effect_name", PARTICLE_BOMB4);

		if( random == 1 )
			vPos[2] += 175.0;
		else if( random == 2 )
			vPos[2] += 100.0;
		else if( random == 4 )
			vPos[2] += 25.0;

		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "start");

		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}


	// Sound
	new random = GetRandomInt(0, 2);
	if( random == 0 )
		EmitSoundToAll(SOUND_EXPLODE3, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
	else if( random == 1 )
		EmitSoundToAll(SOUND_EXPLODE4, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
	else if( random == 2 )
		EmitSoundToAll(SOUND_EXPLODE5, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
}

static const String:g_sVocalize[][] =
{
	"scenes/Coach/WorldC5M4B04.vcd",		//Damn! That one was close!
	"scenes/Coach/WorldC5M4B05.vcd",		//Shit. Damn, that one was close!
	"scenes/Coach/WorldC5M4B02.vcd",		//STOP BOMBING US.
	"scenes/Gambler/WorldC5M4B09.vcd",		//Well, it's official: They're trying to kill US now.
	"scenes/Gambler/WorldC5M4B05.vcd",		//Christ, those guys are such assholes.
	"scenes/Gambler/World220.vcd",			//WHAT THE HELL ARE THEY DOING?  (reaction to bombing)
	"scenes/Gambler/WorldC5M4B03.vcd",		//STOP BOMBING US!
	"scenes/Mechanic/WorldC5M4B02.vcd",		//They nailed that.
	"scenes/Mechanic/WorldC5M4B03.vcd",		//What are they even aiming at?
	"scenes/Mechanic/WorldC5M4B04.vcd",		//We need to get the hell out of here.
	"scenes/Mechanic/WorldC5M4B05.vcd",		//They must not see us.
	"scenes/Mechanic/WorldC5M103.vcd",		//HEY, STOP WITH THE BOMBING!
	"scenes/Mechanic/WorldC5M104.vcd",		//PLEASE DO NOT BOMB US
	"scenes/Producer/WorldC5M4B04.vcd",		//Something tells me they're not checking for survivors anymore.
	"scenes/Producer/WorldC5M4B01.vcd",		//We need to keep moving.
	"scenes/Producer/WorldC5M4B03.vcd"		//That was close.
};

Vocalize(client)
{
	if( g_iCvarVocalize == 0 || GetRandomInt(1, 100) > g_iCvarVocalize )
		return;

	decl String:sTemp[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sTemp, 64);

	new random;
	if( sTemp[26] == 'c' )							// c = Coach
		random = GetRandomInt(0, 2);
	else if( sTemp[26] == 'g' )						// g = Gambler
		random = GetRandomInt(3, 6);
	else if( sTemp[26] == 'm' && sTemp[27] == 'e' )	// me = Mechanic
		random = GetRandomInt(7, 12);
	else if( sTemp[26] == 'p' )						// p = Producer
		random = GetRandomInt(13, 15);
	else
		return;

	new entity = CreateEntityByName("instanced_scripted_scene");
	DispatchKeyValue(entity, "SceneFile", g_sVocalize[random]);
	DispatchSpawn(entity);
	SetEntPropEnt(entity, Prop_Data, "m_hOwner", client);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start", client, client);
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

PrecacheParticle(const String:ParticleName[])
{
	new Particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(Particle, "effect_name", ParticleName);
	DispatchSpawn(Particle);
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	Particle = EntIndexToEntRef(Particle);
	SetVariantString("OnUser1 !self:Kill::0.1:-1");
	AcceptEntityInput(Particle, "AddOutput");
	AcceptEntityInput(Particle, "FireUser1");
}