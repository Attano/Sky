#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

new String:sLadderSounds[][] = 
{
	"player/footsteps/survivor/walk/ladder1.wav", 
	"player/footsteps/survivor/walk/ladder2.wav", 
	"player/footsteps/survivor/walk/ladder3.wav", 
	"player/footsteps/survivor/walk/ladder4.wav"
};

new bool:soundCooldown[MAXPLAYERS+1];
new onLadder[MAXPLAYERS+1];
new Float:lastZ[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "L4D2 Sky/Nexus Custom Ladders",
	author = "Originally by Monospace; adapted for L4D2 by Visor",
	description = "Allows to create custom triggers with func_ladder behaviour",
	version = "1.1",
	url = ""
}

public OnPluginStart()
{
	HookEntityOutput("trigger_multiple", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_multiple", "OnEndTouch", EndTouchTrigger);
}

public OnMapStart()
{
	PrecacheSound(sLadderSounds[0]);
	PrecacheSound(sLadderSounds[1]);
	PrecacheSound(sLadderSounds[2]);
	PrecacheSound(sLadderSounds[3]);
}

public OnClientPutInServer(client)
{
	onLadder[client] = 0;
}

public StartTouchTrigger(const String:name[], caller, activator, Float:delay)
{
	decl String:entityName[32];
	GetEntPropString(caller, Prop_Data, "m_iName", entityName, sizeof(entityName));
	
	if(StrContains(entityName, "ladder") != -1) {
		// Occasionally I get 2 StartTouchTrigger events before an EndTouchTrigger when 
		// 2 ladders are placed close together.  The onLadder accumulator works around this. 
		if (++onLadder[activator] == 1) {
			MountLadder(activator);
		}
	}
}

public EndTouchTrigger(const String:name[], caller, activator, Float:delay)
{
	decl String:entityName[32];
	GetEntPropString(caller, Prop_Data, "m_iName", entityName, sizeof(entityName));

	if(StrContains(entityName, "ladder") != -1) {
		// Occasionally I get 2 StartTouchTrigger events before an EndTouchTrigger when 
		// 2 ladders are placed close together.  The onLadder accumulator works around this. 
		if (--onLadder[activator] <= 0) {
			DismountLadder(activator);
		}
	}
}

MountLadder(client)
{
	SetEntityGravity(client, 0.001);
	SDKHook(client, SDKHook_PreThink, MoveOnLadder);
}

DismountLadder(client)
{
	SetEntityGravity(client, 1.0);
	SDKUnhook(client, SDKHook_PreThink, MoveOnLadder);
}

PlayClimbSound(client)
{
	if(soundCooldown[client])
		return;

	EmitSoundToClient(client, sLadderSounds[GetRandomInt(0,3)]);

	soundCooldown[client] = true;
	CreateTimer(0.35, Timer_Cooldown, client);
}

/*
614-615 Rochelle
605-606 Nick
606-607 Coach
610-611 Ellis
514-515 Zoey
517-518 Francis
514-515 Louis
514-515 Bill
*/

public Action:Timer_Cooldown(Handle:timer, any:client)
{
	soundCooldown[client] = false;
}

public MoveOnLadder(client)
{
	new Float:speed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

	decl buttons;
	buttons = GetClientButtons(client);
    
	decl Float:origin[3];
	GetClientAbsOrigin(client, origin);
	
	new bool:movingUp = (origin[2] > lastZ[client]);
	lastZ[client] = origin[2];

	decl Float:angles[3];
	GetClientEyeAngles(client, angles);

	decl Float:velocity[3];

	if(buttons & IN_FORWARD || buttons & IN_JUMP) {
		velocity[0] = speed * Cosine(DegToRad(angles[1]));
		velocity[1] = speed * Sine(DegToRad(angles[1]));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		// Soldier and heavy do not achieve the required velocity to get off the 
		// ground.  The calculation below provides a boost when necessary.
		if (!movingUp && angles[0] < -25.0 && velocity[2] > 0 && velocity[2] < 250.0) {
			//LogMessage("Client %i: BOOST", client);
			// is friction on different surfaces an issue?
			velocity[2] = 251.0;
		}
		
		//LogMessage("Client %i: Forward %f %f", client, angles[0], velocity[2]);
		PlayClimbSound(client);
	} else if(buttons & IN_MOVELEFT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] + 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] + 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		//LogMessage("Client %i: Left", client);
		PlayClimbSound(client);
	} else if(buttons & IN_MOVERIGHT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] - 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] - 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		//LogMessage("Client %i: Right", client);
		PlayClimbSound(client);
	} else if(buttons & IN_BACK) {
		velocity[0] = -1 * speed * Cosine(DegToRad(angles[1]));
		velocity[1] = -1 * speed * Sine(DegToRad(angles[1]));
		velocity[2] = speed * Sine(DegToRad(angles[0]));

		//LogMessage("Client %i: Backwards", client);
		PlayClimbSound(client);
	} else {
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;
	
		//LogMessage("Client %i: Hold", client);
	}
	
	TeleportEntity(client, origin, NULL_VECTOR, velocity);
	
}