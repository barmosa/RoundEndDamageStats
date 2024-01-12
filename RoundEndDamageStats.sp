#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "Round End Damage Stats",
	author = "Eyal282",
	description = "Round End Damage Stats",
	version = PLUGIN_VERSION,
	url = ""
};

enum struct enDamageStats 
{
	char Name[64];
	char AuthId[35];
	int ToDamageTotal;
	int ToHitsTotal;
	int FromDamageTotal;
	int FromHitsTotal;
}
ArrayList Array_Players[MAXPLAYERS+1];
StringMap Trie_PlayersHP;

public void OnClientDisconnect(int client)
{
	ClearArray(Array_Players[client]);
	
	char AuthId[35];
	
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	SetTrieValue(Trie_PlayersHP, AuthId, 0, true);
}

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	
	for (int i = 0; i < sizeof(Array_Players);i++)
		Array_Players[i] = CreateArray(sizeof(enDamageStats));
		
	Trie_PlayersHP = CreateTrie();
	
}

public Action Event_RoundStart(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(Array_Players);i++)
		ClearArray(Array_Players[i]);
		
	ClearTrie(Trie_PlayersHP);
	
	for (int i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(!IsPlayerAlive(i))
			continue;
			
		for (int a = 1; a <= MaxClients;a++)
		{
			if(a == i)
				continue;
				
			else if(!IsClientInGame(a))
				continue;
			
			else if(!IsPlayerAlive(a))
				continue;
			
			else if(GetClientTeam(a) == GetClientTeam(i))
				continue;
	
			char iAuthId[35], aAuthId[35];
			
			GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));
			GetClientAuthId(a, AuthId_Engine, aAuthId, sizeof(aAuthId));
			
			bool found = false;
	
			for (int b = 0; b < GetArraySize(Array_Players[i]);b++)
			{
				enDamageStats iStats;
				GetArrayArray(Array_Players[i], b, iStats);
				
				if(StrEqual(iStats.AuthId, aAuthId, false))
					found = true;
			}
			
			if(!found)
			{
				enDamageStats iDamageStats;
				
				GetClientName(a, iDamageStats.Name, sizeof(enDamageStats::Name));
				iDamageStats.AuthId = aAuthId;
				iDamageStats.ToHitsTotal = 0;
				iDamageStats.ToDamageTotal = 0;
				
				iDamageStats.FromHitsTotal = 0;
				iDamageStats.FromDamageTotal = 0;
				
				PushArrayArray(Array_Players[i], iDamageStats);
				
				enDamageStats aDamageStats;
				
				GetClientName(i, aDamageStats.Name, sizeof(enDamageStats::Name));
				aDamageStats.AuthId = iAuthId;
				aDamageStats.ToHitsTotal = 0;
				aDamageStats.ToDamageTotal = 0;
				
				aDamageStats.FromHitsTotal = 0;
				aDamageStats.FromDamageTotal = 0;
				
				PushArrayArray(Array_Players[a], aDamageStats);
				
				SetTrieValue(Trie_PlayersHP, iAuthId, GetEntityHealth(i), true);
				SetTrieValue(Trie_PlayersHP, aAuthId, GetEntityHealth(a), true);
			}
		}
	}
}

public Action Event_RoundEnd(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		for (int a = 0; a < GetArraySize(Array_Players[i]);a++)
		{
			enDamageStats damageStats;
			
			GetArrayArray(Array_Players[i], a, damageStats);
			
			int otherHealth;
			GetTrieValue(Trie_PlayersHP, damageStats.AuthId, otherHealth);
			
			char sOtherHealth[11];
			
			IntToString(otherHealth, sOtherHealth, sizeof(sOtherHealth));
			
			PrintToChat(i, " \x04[WePlay] \x01To: [\x04%i / %i hits\x01] From: [\x07%i / %i hits\x01] - %s [\x0B%s\x01]", damageStats.ToDamageTotal, damageStats.ToHitsTotal,
			damageStats.FromDamageTotal, damageStats.FromHitsTotal, damageStats.Name, otherHealth <= 0 ? "\x02DEAD" : sOtherHealth);
		}
	}
}
public Action Event_PlayerHurt(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0 || victim == attacker) // Self damage, nade or fall damage.
		return;
		
	int damage = GetEventInt(hEvent, "dmg_health");
	
	char victimAuthId[35], attackerAuthId[35];
	
	GetClientAuthId(attacker, AuthId_Engine, attackerAuthId, sizeof(attackerAuthId));
	GetClientAuthId(victim, AuthId_Engine, victimAuthId, sizeof(victimAuthId));
	
	SetTrieValue(Trie_PlayersHP, victimAuthId, GetEntityHealth(victim), true);
	SetTrieValue(Trie_PlayersHP, attackerAuthId, GetEntityHealth(attacker), true);
	
	
	bool found = false;
	
	for (int i = 0; i < GetArraySize(Array_Players[victim]);i++)
	{
		enDamageStats VictimStats;
		GetArrayArray(Array_Players[victim], i, VictimStats);
		
		if(StrEqual(VictimStats.AuthId, attackerAuthId, false))
		{
			VictimStats.FromHitsTotal++;
			VictimStats.FromDamageTotal += damage;
			
			SetArrayArray(Array_Players[victim], i, VictimStats);
			
			found = true;
		}
	}
	
	if(!found)
	{
		enDamageStats VictimStats;
		
		GetClientName(attacker, VictimStats.Name, sizeof(enDamageStats::Name));
		VictimStats.AuthId = attackerAuthId;
		VictimStats.ToHitsTotal = 0;
		VictimStats.ToDamageTotal = 0;
		
		VictimStats.FromHitsTotal = 1;
		VictimStats.FromDamageTotal = damage;
		
		PushArrayArray(Array_Players[victim], VictimStats);
	}
	
	found = false;
	
	for (int i = 0; i < GetArraySize(Array_Players[attacker]);i++)
	{
		enDamageStats AttackerStats;
		GetArrayArray(Array_Players[attacker], i, AttackerStats);
		
		if(StrEqual(AttackerStats.AuthId, victimAuthId, false))
		{
			AttackerStats.ToHitsTotal++;
			AttackerStats.ToDamageTotal += damage;
			
			SetArrayArray(Array_Players[attacker], i, AttackerStats);
			
			found = true;
		}
	}
	
	if(!found)
	{
		enDamageStats AttackerStats;
		
		GetClientName(victim, AttackerStats.Name, sizeof(enDamageStats::Name));
		
		AttackerStats.AuthId = victimAuthId;
		AttackerStats.ToHitsTotal = 1;
		AttackerStats.ToDamageTotal = damage;
		
		AttackerStats.FromHitsTotal = 0;
		AttackerStats.FromDamageTotal = 0;
		
		PushArrayArray(Array_Players[attacker], AttackerStats);
	}

}

stock int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}