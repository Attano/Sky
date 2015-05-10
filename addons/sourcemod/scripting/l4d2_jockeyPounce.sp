#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define HUNTER_DAMAGE_POUNCE_MSGID  12

new Handle:g_hEnabled;
new Handle:g_hBlindAmount;
new Handle:g_hPounceScale;
new Handle:g_hPounceCap;
new Handle:g_hPounceMinShow;
new Handle:g_hPounceDisplay;
new Handle:g_hPounceDisplayMax;

new Float:startPosition[MAXPLAYERS+1][3];
new Float:endPosition[MAXPLAYERS+1][3];

new UserMsg:g_FadeUserMsgId;

public Plugin:myinfo =
{
	name = "L4D2 Jockey Pounce Damage Confogl Edition",
	author = "N3wton, Visor, JaneDoe",
	description = "Inflicts distance bonus damage to the jockey's victim if the latter has been pounced from a great height.",
	version = "1.1"
};

public OnPluginStart()
{
    g_hEnabled = CreateConVar( "l4d2_JockeyPounce_enabled", "1", "Should the plugin be enabled", FCVAR_PLUGIN );
    g_hBlindAmount = CreateConVar( "l4d2_JockeyPounce_blind", "150", "How much the jockey should blind the player (0: non, 255:completely)", FCVAR_PLUGIN );
    g_hPounceScale = CreateConVar( "l4d2_JockeyPounce_scale", "1.0", "Scale how much damage the pounce does (e.g. 0.5 will half the default damage, 5 will make it 5 times more powerfull)", FCVAR_PLUGIN );
    g_hPounceCap = CreateConVar( "l4d2_JockeyPounce_cap", "25", "Cap of the maximum damage a pounce can do", FCVAR_PLUGIN );
    g_hPounceMinShow = CreateConVar( "l4d2_JockeyPounce_minshow", "1", "Minimum damage a pounce should do to show the pounce message", FCVAR_PLUGIN );
    g_hPounceDisplay = CreateConVar( "l4d2_JockeyPounce_display", "0", "How message should be shown, 0 - Disabled, 1 - Chat message, 2 - Hint Message", FCVAR_PLUGIN );
    g_hPounceDisplayMax = CreateConVar( "l4d2_JockeyPounce_display_max", "0", "Show the damagecap in the display message", FCVAR_PLUGIN );

    HookEvent( "jockey_ride", Event_JockeyRide );
    HookEvent( "jockey_ride_end", Event_JockeyRideEnd );
    HookEvent( "player_incapacitated", Event_Incap );
    HookEvent( "player_jump", Event_JockeyJump );

    g_FadeUserMsgId = GetUserMessageId( "Fade" );
}

public Action:Event_JockeyJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( GetConVarBool(g_hEnabled) )
	{
		decl String:ClientModel[128];
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		GetClientModel( client, ClientModel, 128 );
		if( StrContains( ClientModel, "jockey", false ) >= 0 )
		{
			GetClientAbsOrigin( client, startPosition[client] );
		}
	}
	return Plugin_Continue;
}

public Action:Event_Incap( Handle:event, const String:name[], bool:dontBroadcast )
{
	if( GetConVarBool(g_hEnabled) )
	{
		new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
		PerformBlind( client, 0 );
	}
	return Plugin_Continue;
}

public Action:Event_JockeyRideEnd( Handle:event, const String:name[], bool:dontBroadcast )
{
	if( GetConVarBool(g_hEnabled) )
	{
		new victim = GetClientOfUserId( GetEventInt( event, "victim" ) );
		PerformBlind( victim, 0 );
	}
	return Plugin_Continue;
}

public Action:Event_JockeyRide( Handle:event, const String:name[], bool:dontBroadcast )
{
	if( GetConVarBool(g_hEnabled) )
	{
		new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
		new victim = GetClientOfUserId( GetEventInt( event, "victim" ) );
		
		GetClientAbsOrigin( client, endPosition[client] );
		DistanceJumped( client, victim );		
		PerformBlind( victim, GetConVarInt(g_hBlindAmount) );
	}
	return Plugin_Continue;
}

stock DistanceJumped( client, victim )
{
	new damage = RoundFloat( startPosition[client][2] - endPosition[client][2] );
	
	if( damage < 0.0 )
	{
		return;
	}
	
	damage = RoundFloat( ( damage / 100.0 ) );

	damage = RoundFloat( ( ( ( damage * damage )*0.8 ) + 1 ) * GetConVarFloat( g_hPounceScale ) );
	
	if( damage > GetConVarInt(g_hPounceCap) ) damage = GetConVarInt(g_hPounceCap);
	
	if( damage >= GetConVarInt(g_hPounceMinShow) )
	{
		decl String:max[10];
		if( GetConVarBool( g_hPounceDisplayMax ) )
		{
			Format( max, 10, " Max %d", GetConVarInt(g_hPounceCap) );
		} else {
			Format( max, 10, "" );
		}
		if( !IsFakeClient( client ) )
		{
			if( GetConVarInt( g_hPounceDisplay ) == 1 ) PrintToChatAll( "\x03%N \x03>\x04jockey\x03<\x01 pounced \x03%N\x01 for [\x04%d\x01] damage%s", client, victim, damage, max );	
			if( GetConVarInt( g_hPounceDisplay ) == 2 ) PrintHintTextToAll( "%N jockey pounced %N for %d damage%s", client, victim, damage, max );	
		}
	}
	
    // timer idea by dirtyminuth, damage dealing by pimpinjuice http://forums.alliedmods.net/showthread.php?t=111684
    // added some L4D2 specific checks
	new Handle:dataPack = CreateDataPack();
	WritePackCell(dataPack, damage);  
	WritePackCell(dataPack, victim);
	WritePackCell(dataPack, client);
	
	CreateTimer(0.1, timer_stock_applyDamage, dataPack);
}

public Action:timer_stock_applyDamage(Handle:timer, Handle:dataPack)
{
    ResetPack(dataPack);
    new damage = ReadPackCell(dataPack);  
    new victim = ReadPackCell(dataPack);
    new attacker = ReadPackCell(dataPack);
    CloseHandle(dataPack);   

    decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];

    GetClientEyePosition(victim, victimPos);
    IntToString(damage, strDamage, sizeof(strDamage));
    Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);

    new entPointHurt = CreateEntityByName("point_hurt");
    if(!entPointHurt) return;

    // Config, create point_hurt
    DispatchKeyValue(victim, "targetname", strDamageTarget);
    DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
    DispatchKeyValue(entPointHurt, "Damage", strDamage);
    DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
    DispatchSpawn(entPointHurt);

    // Teleport, activate point_hurt
    TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);

    // Config, delete point_hurt
    DispatchKeyValue(entPointHurt, "classname", "point_hurt");
    DispatchKeyValue(victim, "targetname", "null");
    RemoveEdict(entPointHurt);

    // Dispatch global UserMessage notification of the event
    GlobalPounceAnnouncement(attacker, victim, damage);
}

PerformBlind(target, amount)
{
	new targets[2];
	targets[0] = target;
	
	new Handle:message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	BfWriteShort(message, 1536);
	BfWriteShort(message, 1536);
	
	if (amount == 0)
	{
		BfWriteShort(message, (0x0001 | 0x0010));
	}
	else
	{
		BfWriteShort(message, (0x0002 | 0x0008));
	}
	
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, amount);
	
	EndMessage();
}

GlobalPounceAnnouncement(attacker, victim, damage)
{
    new Handle:bf = StartMessageAll("PZDmgMsg");

    BfWriteByte(bf, HUNTER_DAMAGE_POUNCE_MSGID);
    BfWriteShort(bf, GetClientUserId(attacker));
    BfWriteShort(bf, GetClientUserId(victim));
    BfWriteShort(bf, 0);    // Unknown
    BfWriteShort(bf, damage);

    EndMessage();
}