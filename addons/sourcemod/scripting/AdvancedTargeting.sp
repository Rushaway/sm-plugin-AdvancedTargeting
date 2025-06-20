#pragma semicolon 1

#pragma dynamic 128*1024

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <utilshelper>
#include <ripext>

#undef REQUIRE_PLUGIN
#tryinclude <vip_core>
#tryinclude <zombiereloaded>
#tryinclude <PlayerManager>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#tryinclude <Voice>
#define REQUIRE_EXTENSIONS
#define TAG_COLOR "{green}[SM]{default}"

#pragma newdecls required

Handle g_FriendsArray[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
bool g_bLateLoad = false;

bool g_Plugin_ZR = false;
bool g_Plugin_PM = false;
bool g_Plugin_VIP = false;
bool g_bZombieSpawned = false;

char g_sMotherZombies[1024];
char g_sPreviousMotherZombies[1024];

public Plugin myinfo =
{
	name = "Advanced Targeting Extended",
	author = "BotoX, Obus, inGame, maxime1907, .Rushaway",
	description = "Adds extra targeting methods",
	version = "1.5.1",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("IsClientFriend", Native_IsClientFriend);
	CreateNative("ReadClientFriends", Native_ReadClientFriends);
	RegPluginLibrary("AdvancedTargeting");

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
	g_Plugin_PM = LibraryExists("PlayerManager");
	g_Plugin_VIP = LibraryExists("vip_core");

#if defined _Voice_included
	AddMultiTargetFilter("@talking", Filter_Talking, "Talking", false);
#endif
	AddMultiTargetFilter("@admins", Filter_Admin, "Admins", false);
	AddMultiTargetFilter("@!admins", Filter_NotAdmin, "Not Admins", false);
	AddMultiTargetFilter("@friends", Filter_Friends, "Steam Friends", false);
	AddMultiTargetFilter("@!friends", Filter_NotFriends, "Not Steam Friends", false);
	AddMultiTargetFilter("@random", Filter_Random, "a Random Player", false);
	AddMultiTargetFilter("@randomct", Filter_RandomCT, "a Random CT", false);
	AddMultiTargetFilter("@randomt", Filter_RandomT, "a Random T", false);
	AddMultiTargetFilter("@vips", Filter_VIP, "VIPs", false);
	AddMultiTargetFilter("@!vips", Filter_NotVIP, "VIPs", false);
#if defined _zr_included
	AddMultiTargetFilter("@mzombies", Filter_MotherZombie, "Mother Zombies", false);
	AddMultiTargetFilter("@!mzombies", Filter_NotMotherZombie, "Not Mother Zombies", false);
#endif

#if defined _PlayerManager_included
	AddMultiTargetFilter("@steam", Filter_Steam, "Steam Players", false);
	AddMultiTargetFilter("@nosteam", Filter_NoSteam, "No-Steam Players", false);

	RegConsoleCmd("sm_steam", Command_Steam, "Currently online No-Steam players");
	RegConsoleCmd("sm_nosteam", Command_NoSteam, "Currently online No-Steam players");
#endif

	RegConsoleCmd("sm_admins", Command_Admins, "Currently online admins.");
	RegConsoleCmd("sm_friends", Command_Friends, "Currently online friends.");
	RegConsoleCmd("sm_vips", Command_VIPs, "Currently online vips.");
#if defined _zr_included
	RegConsoleCmd("sm_mzombies", Command_MotherZombies, "Currently online mother zombies.");
#endif

#if defined _zr_included
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
#endif

	if(g_bLateLoad)
	{
		char sSteam32ID[32];
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i) &&
				GetClientAuthId(i, AuthId_Steam2, sSteam32ID, sizeof(sSteam32ID)))
			{
				OnClientAuthorized(i, sSteam32ID);
			}
		}
	}
}

public void OnPluginEnd()
{
#if defined _Voice_included
	RemoveMultiTargetFilter("@talking", Filter_Talking);
#endif

	RemoveMultiTargetFilter("@admins", Filter_Admin);
	RemoveMultiTargetFilter("@!admins", Filter_NotAdmin);
	RemoveMultiTargetFilter("@friends", Filter_Friends);
	RemoveMultiTargetFilter("@!friends", Filter_NotFriends);
	RemoveMultiTargetFilter("@random", Filter_Random);
	RemoveMultiTargetFilter("@randomct", Filter_RandomCT);
	RemoveMultiTargetFilter("@randomt", Filter_RandomT);
	RemoveMultiTargetFilter("@vips", Filter_VIP);
	RemoveMultiTargetFilter("@!vips", Filter_NotVIP);

#if defined _zr_included
	RemoveMultiTargetFilter("@mzombies", Filter_MotherZombie);
	RemoveMultiTargetFilter("@!mzombies", Filter_NotMotherZombie);
#endif

#if defined _PlayerManager_included
	RemoveMultiTargetFilter("@steam", Filter_Steam);
	RemoveMultiTargetFilter("@nosteam", Filter_NoSteam);
#endif

	g_sPreviousMotherZombies = "\0";
	g_sMotherZombies = "\0";
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = true;
	else if (strcmp(sName, "PlayerManager", false) == 0)
		g_Plugin_PM = true;
	else if (strcmp(sName, "vip_core", false) == 0)
		g_Plugin_VIP = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = false;
	else if (strcmp(sName, "PlayerManager", false) == 0)
		g_Plugin_PM = false;
	else if (strcmp(sName, "vip_core", false) == 0)
		g_Plugin_VIP = false;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bZombieSpawned = false;
	strcopy(g_sPreviousMotherZombies, sizeof(g_sPreviousMotherZombies), g_sMotherZombies);
	g_sMotherZombies = "\0";
}

public Action Command_Admins(int client, int args)
{
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetAdminFlag(GetUserAdmin(i), Admin_Generic))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "%s Admins currently online : {green}%s{default}.", TAG_COLOR, aBuf);
	}
	else
		CReplyToCommand(client, "%s Admins currently online : {green}none{default}.", TAG_COLOR);

	return Plugin_Handled;
}

public Action Command_VIPs(int client, int args)
{
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetAdminFlag(GetUserAdmin(i), Admin_Custom1) && !GetAdminFlag(GetUserAdmin(i), Admin_Cheats))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "%s VIPs currently online : {orchid}%s{default}.", TAG_COLOR, aBuf);
	}
	else
		CReplyToCommand(client, "%s VIPs currently online : {orchid}none{default}.", TAG_COLOR);

	return Plugin_Handled;
}

#if defined _zr_included
public Action Command_MotherZombies(int client, int args)
{
	if (!g_Plugin_ZR || GetFeatureStatus(FeatureType_Native, "ZR_IsClientMotherZombie") != FeatureStatus_Available)
		return Plugin_Handled;

	if (!g_bZombieSpawned && strlen(g_sPreviousMotherZombies) > 0)
	{
		CReplyToCommand(client, "%s Mother zombies have not spawned yet.", TAG_COLOR);
		CReplyToCommand(client, "%s Previous mother zombies: %s", TAG_COLOR, g_sPreviousMotherZombies);
		return Plugin_Handled;
	}

	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	int iZombiesCount = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientMotherZombie(i))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			Format(aBuf, sizeof(aBuf), "%s{darkred}%s{default}, ", aBuf, aBuf2);
			iZombiesCount++;
		}
	}

	if (iZombiesCount > 0)
		aBuf[strlen(aBuf) - 11] = 0;

	g_sMotherZombies = aBuf;

	if (iZombiesCount > 0)
		CReplyToCommand(client, "%s Mother zombies currently alive: %s", TAG_COLOR, aBuf);
	else
		CReplyToCommand(client, "%s Mother zombies currently alive: {darkred}none{default}.", TAG_COLOR);

	if (strlen(g_sPreviousMotherZombies) > 0)
		CReplyToCommand(client, "%s Previous mother zombies: %s", TAG_COLOR, g_sPreviousMotherZombies);

	return Plugin_Handled;
}
#endif

public Action Command_Friends(int client, int args)
{
	if(!client)
		return Plugin_Handled;

	if(g_FriendsArray[client] == INVALID_HANDLE)
	{
		CPrintToChat(client, "%s Could not read your friendslist, your profile must be set to public!", TAG_COLOR);
		return Plugin_Handled;
	}

	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
		{
			int Steam3ID = GetSteamAccountID(i);

			if(FindValueInArray(g_FriendsArray[client], Steam3ID) != -1)
			{
				GetClientName(i, aBuf2, sizeof(aBuf2));
				StrCat(aBuf, sizeof(aBuf), aBuf2);
				StrCat(aBuf, sizeof(aBuf), ", ");
			}
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CPrintToChat(client, "%s Friends currently online : {lightblue}%s{default}.", TAG_COLOR, aBuf);
	}
	else
		CPrintToChat(client, "%s Friends currently online : {lightblue}none{default}.", TAG_COLOR);

	return Plugin_Handled;
}

public Action Command_Steam(int client, int args)
{
	if (!g_Plugin_PM || GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") != FeatureStatus_Available)
		return Plugin_Handled;

	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && PM_IsPlayerSteam(i))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "%s Steam clients online : {lightblue}%s{default}.", TAG_COLOR, aBuf);
	}
	else
		CReplyToCommand(client, "%s Steam clients online : {lightblue}none{default}.", TAG_COLOR);

	return Plugin_Handled;
}

public Action Command_NoSteam(int client, int args)
{
	if (!g_Plugin_PM || GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") != FeatureStatus_Available)
		return Plugin_Handled;

	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !PM_IsPlayerSteam(i))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "%s No-Steam clients online : {lightblue}%s{default}.", TAG_COLOR, aBuf);
	}
	else
		CReplyToCommand(client, "%s No-Steam clients online : {lightblue}none{default}.", TAG_COLOR);

	return Plugin_Handled;
}

public bool Filter_Steam(const char[] sPattern, Handle hClients)
{
	if (!g_Plugin_PM || GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") != FeatureStatus_Available)
		return false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && PM_IsPlayerSteam(i))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

public bool Filter_NoSteam(const char[] sPattern, Handle hClients)
{
	if (!g_Plugin_PM || GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") != FeatureStatus_Available)
		return false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !PM_IsPlayerSteam(i))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

#if defined _Voice_included
public bool Filter_Talking(const char[] sPattern, Handle hClients, int client)
{
	if (GetFeatureStatus(FeatureType_Native, "IsClientTalking") != FeatureStatus_Available)
		return false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsClientTalking(i))
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}
#endif

public bool Filter_Admin(const char[] sPattern, Handle hClients, int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetAdminFlag(GetUserAdmin(i), Admin_Generic))
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}

public bool Filter_NotAdmin(const char[] sPattern, Handle hClients, int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !GetAdminFlag(GetUserAdmin(i), Admin_Generic))
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}

#if defined _zr_included
public bool Filter_MotherZombie(const char[] sPattern, Handle hClients, int client)
{
	if (!g_Plugin_ZR || GetFeatureStatus(FeatureType_Native, "ZR_IsClientMotherZombie") != FeatureStatus_Available)
		return false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && ZR_IsClientMotherZombie(i))
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}
#endif

#if defined _zr_included
public bool Filter_NotMotherZombie(const char[] sPattern, Handle hClients, int client)
{
	if (!g_Plugin_ZR || GetFeatureStatus(FeatureType_Native, "ZR_IsClientMotherZombie") != FeatureStatus_Available || GetFeatureStatus(FeatureType_Native, "ZR_IsClientZombie") != FeatureStatus_Available)
		return false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !ZR_IsClientMotherZombie(i) && ZR_IsClientZombie(i))
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}
#endif

public bool Filter_VIP(const char[] sPattern, Handle hClients, int client)
{
	bool bNative = GetFeatureStatus(FeatureType_Native, "VIP_IsClientVIP") == FeatureStatus_Available;

	for(int i = 1; i <= MaxClients; i++)
	{
#if defined _vip_core_included
		if(g_Plugin_VIP && bNative && IsClientInGame(i) && !IsFakeClient(i) && VIP_IsClientVIP(i))
#else
		if(IsClientInGame(i) && !IsFakeClient(i) && GetAdminFlag(GetUserAdmin(i), Admin_Custom1))
#endif
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}

public bool Filter_NotVIP(const char[] sPattern, Handle hClients, int client)
{
	bool bNative = GetFeatureStatus(FeatureType_Native, "VIP_IsClientVIP") == FeatureStatus_Available;

	for(int i = 1; i <= MaxClients; i++)
	{
#if defined _vip_core_included
		if(g_Plugin_VIP && bNative && IsClientInGame(i) && !IsFakeClient(i) && !VIP_IsClientVIP(i))
#else
		if(IsClientInGame(i) && !IsFakeClient(i) && !GetAdminFlag(GetUserAdmin(i), Admin_Custom1))
#endif
		{
			PushArrayCell(hClients, i);
		}
	}

	return true;
}

public bool Filter_Friends(const char[] sPattern, Handle hClients, int client)
{
	if(g_FriendsArray[client] == INVALID_HANDLE)
	{
		CPrintToChat(client, "%s Could not read your friendslist, your profile must be set to public!", TAG_COLOR);
		return false;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
		{
			int Steam3ID = GetSteamAccountID(i);

			if(FindValueInArray(g_FriendsArray[client], Steam3ID) != -1)
				PushArrayCell(hClients, i);
		}
	}

	return true;
}

public bool Filter_NotFriends(const char[] sPattern, Handle hClients, int client)
{
	if(g_FriendsArray[client] == INVALID_HANDLE)
	{
		CPrintToChat(client, "%s Could not read your friendslist, your profile must be set to public!", TAG_COLOR);
		return false;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
		{
			int Steam3ID = GetSteamAccountID(i);

			if(FindValueInArray(g_FriendsArray[client], Steam3ID) == -1)
				PushArrayCell(hClients, i);
		}
	}

	return true;
}

stock bool GetRandomPlayer(Handle hClients, int team = -1)
{
	if(team == -1)
		team = GetRandomInt(0, 1) ? CS_TEAM_CT : CS_TEAM_T;

	int playerCount = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		if(GetClientTeam(i) != team)
			continue;

		playerCount++;
	}

	if(!playerCount)
		return false;

	int[] validPlayers = new int[playerCount];
	int currentIndex = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		if(GetClientTeam(i) != team)
			continue;

		validPlayers[currentIndex] = i;
		currentIndex++;
	}

	PushArrayCell(hClients, validPlayers[GetRandomInt(0, playerCount-1)]);
	return true;
}

public bool Filter_Random(const char[] sPattern, Handle hClients, int client)
{
	return GetRandomPlayer(hClients);
}

public bool Filter_RandomCT(const char[] sPattern, Handle hClients, int client)
{
	return GetRandomPlayer(hClients, CS_TEAM_CT);
}

public bool Filter_RandomT(const char[] sPattern, Handle hClients, int client)
{
	return GetRandomPlayer(hClients, CS_TEAM_T);
}

#if defined _zr_included
public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if (motherInfect)
		g_bZombieSpawned = true;

	return Plugin_Continue;
}
#endif

public void OnClientAuthorized(int client, const char[] auth)
{
	if(IsFakeClient(client))
		return;

	char sSteam64ID[32];
	GetClientAuthId(client, AuthId_SteamID64, sSteam64ID, sizeof(sSteam64ID));

	char sSteamAPIKey[64];
	GetSteamAPIKey(sSteamAPIKey, sizeof(sSteamAPIKey));

	static char sRequest[256];
	FormatEx(sRequest, sizeof(sRequest), "http://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key=%s&steamid=%s&relationship=friend&format=json", sSteamAPIKey, sSteam64ID);

	HTTPRequest request = new HTTPRequest(sRequest);

	request.Get(OnFriendsReceived, client);
}

public void OnClientDisconnect(int client)
{
	if(g_FriendsArray[client] != INVALID_HANDLE)
		CloseHandle(g_FriendsArray[client]);

	g_FriendsArray[client] = INVALID_HANDLE;
}

void OnFriendsReceived(HTTPResponse response, any client)
{
	if (response.Status != HTTPStatus_OK)
		return;

	// Indicate that the response contains a JSON object
	JSONObject responseData = view_as<JSONObject>(response.Data);

	JSONObject friendslist = view_as<JSONObject>(responseData.Get("friendslist"));

	APIWebResponse(friendslist, client);
}

public void APIWebResponse(JSONObject friendslist, int client)
{
	// No friends or private profile
	if (!friendslist.Size)
	{
		delete friendslist;
		return;
	}

	JSONArray friends = view_as<JSONArray>(friendslist.Get("friends"));

	if(g_FriendsArray[client] != INVALID_HANDLE)
		CloseHandle(g_FriendsArray[client]);

	g_FriendsArray[client] = CreateArray();

	char sCommunityID[32];
	for (int i = 0; i < friends.Length; i++)
	{
		JSONObject friend = view_as<JSONObject>(friends.Get(i));
		friend.GetString("steamid", sCommunityID, sizeof(sCommunityID));
		PushArrayCell(g_FriendsArray[client], Steam64toSteam3(sCommunityID));
		delete friend;
	}

	delete friends;
	delete friendslist;
}

public int Native_IsClientFriend(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int friend = GetNativeCell(2);

	if(client > MaxClients || client <= 0 || friend > MaxClients || friend <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not valid.");
		return -1;
	}

	if(!IsClientInGame(client) || !IsClientInGame(friend))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not in-game.");
		return -1;
	}

	if(IsFakeClient(client) || IsFakeClient(friend))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is fake-client.");
		return -1;
	}

	if(g_FriendsArray[client] == INVALID_HANDLE)
		return -1;

	if(IsClientAuthorized(friend))
	{
		int Steam3ID = GetSteamAccountID(friend);

		if(FindValueInArray(g_FriendsArray[client], Steam3ID) != -1)
			return 1;
	}

	return 0;
}

public int Native_ReadClientFriends(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client > MaxClients || client <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not valid.");
		return -1;
	}

	if(g_FriendsArray[client] != INVALID_HANDLE)
		return 1;

	return 0;
}
