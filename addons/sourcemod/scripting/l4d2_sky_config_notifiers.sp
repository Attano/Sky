#pragma semicolon 1

#include <sourcemod>
#include <colors>

new Handle:trie;

public Plugin:myinfo =
{
	name = "Sky Config Notifiers",
	author = "Visor",
	description = "Displays different lines on round start",
	version = "0.1",
	url = "https://github.com/Attano"
};

public OnPluginStart()
{
	trie = CreateTrie();

	RegServerCmd("sm_add_info_line", Cmd_AddLine);
}

public Action:Cmd_AddLine(args)
{
	decl String:map[128];
	decl String:info[1024];
	GetCmdArg(1, map, sizeof(map));
	GetCmdArg(2, info, sizeof(info));
	
	SetTrieString(trie, map, info);
	
	return Plugin_Handled;
}

public OnRoundIsLive() 
{
	decl String:map[128];
	decl String:info[1024];
	GetCurrentMap(map, sizeof(map));
	if (GetTrieString(trie, map, info, sizeof(info)))
	{
		CPrintToChatAll(info);
	}
}