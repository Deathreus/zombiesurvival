-- Weapon sets that humans can start with if they choose RANDOM.
GM.StartLoadouts = {
	{"pshtr", "3pcp", "2pcp", "csknf"},
	{"btlax", "3pcp", "zpaxe", "stone"},
	{"stbbr", "3rcp", "zpcpot", "stone"},
	{"tossr", "3smgcp", "2smgcp", "zpplnk", "stone"},
	{"blstr", "3sgcp", "2sgcp", "csknf"},
	{"owens", "3pcp", "2pcp", "csknf"},
	{"zpcpot", "medkit", "150mkit"},
	{"crklr", "3arcp", "2arcp", "zpplnk", "stone"},
	{"crphmr", "6nails", "hook"},
	{"blstr", "pipe"}
}


GM.BossZombies = CreateConVar("zs_bosszombies", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Summon a boss zombie in the middle of each wave break."):GetBool()
cvars.AddChangeCallback("zs_bosszombies", function(cvar, oldvalue, newvalue)
	GAMEMODE.BossZombies = tonumber(newvalue) == 1
end)

GM.OutnumberedHealthBonus = CreateConVar("zs_outnumberedhealthbonus", "4", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Give zombies some extra maximum health if there are less than or equal to this many zombies. 0 to disable."):GetInt()
cvars.AddChangeCallback("zs_outnumberedhealthbonus", function(cvar, oldvalue, newvalue)
	GAMEMODE.OutnumberedHealthBonus = tonumber(newvalue) or 0
end)

-- Might get used later --

GM.PantsMode = CreateConVar("zs_pantsmode", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Only the dead can know peace from this evil."):GetBool()
cvars.AddChangeCallback("zs_pantsmode", function(cvar, oldvalue, newvalue)
	GAMEMODE:SetPantsMode(tonumber(newvalue) == 1)
end)

GM.ClassicMode = CreateConVar("zs_classicmode", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "No nails, no class selection, final destination."):GetBool()
cvars.AddChangeCallback("zs_classicmode", function(cvar, oldvalue, newvalue)
	GAMEMODE:SetClassicMode(tonumber(newvalue) == 1)
end)

GM.BabyMode = CreateConVar("zs_babymode", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Babby mode."):GetBool()
cvars.AddChangeCallback("zs_babymode", function(cvar, oldvalue, newvalue)
	GAMEMODE:SetBabyMode(tonumber(newvalue) == 1)
end)

--------------------------------------------------------------------

GM.EndWaveHealthBonus = CreateConVar("zs_endwavehealthbonus", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Humans will get this much health after every wave. 0 to disable."):GetInt()
cvars.AddChangeCallback("zs_endwavehealthbonus", function(cvar, oldvalue, newvalue)
	GAMEMODE.EndWaveHealthBonus = tonumber(newvalue) or 0
end)

GM.GibLifeTime = CreateConVar("zs_giblifetime", "25", FCVAR_ARCHIVE, "Specifies how many seconds player gibs will stay in the world if not eaten or destroyed."):GetFloat()
cvars.AddChangeCallback("zs_giblifetime", function(cvar, oldvalue, newvalue)
	GAMEMODE.GibLifeTime = tonumber(newvalue) or 1
end)

GM.MaxPropsInBarricade = CreateConVar("zs_maxpropsinbarricade", "8", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Limits the amount of props that can be in one 'contraption' of nails."):GetInt()
cvars.AddChangeCallback("zs_maxpropsinbarricade", function(cvar, oldvalue, newvalue)
	GAMEMODE.MaxPropsInBarricade = tonumber(newvalue) or 8
end)

GM.MaxDroppedItems = CreateConVar("zs_maxdroppeditems", "32", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Maximum amount of dropped items. Prevents spam or lag when lots of people die."):GetInt()
cvars.AddChangeCallback("zs_maxdroppeditems", function(cvar, oldvalue, newvalue)
	GAMEMODE.MaxDroppedItems = tonumber(newvalue) or 32
end)

GM.NailHealthPerRepair = CreateConVar("zs_nailhealthperrepair", "10", FCVAR_ARCHIVE + FCVAR_NOTIFY, "How much health a nail gets when being repaired."):GetInt()
cvars.AddChangeCallback("zs_nailhealthperrepair", function(cvar, oldvalue, newvalue)
	GAMEMODE.NailHealthPerRepair = tonumber(newvalue) or 1
end)

GM.NoPropDamageFromHumanMelee = CreateConVar("zs_nopropdamagefromhumanmelee", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Melee from humans doesn't damage props."):GetBool()
cvars.AddChangeCallback("zs_nopropdamagefromhumanmelee", function(cvar, oldvalue, newvalue)
	GAMEMODE.NoPropDamageFromHumanMelee = tonumber(newvalue) == 1
end)

GM.MedkitPointsPerHealth = CreateConVar("zs_medkitpointsperhealth", "5", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Specifies the amount of healing for players to be given a point. For use with the medkit and such."):GetInt()
cvars.AddChangeCallback("zs_medkitpointsperhealth", function(cvar, oldvalue, newvalue)
	GAMEMODE.MedkitPointsPerHealth = tonumber(newvalue) or 1
end)

GM.RepairPointsPerHealth = CreateConVar("zs_repairpointsperhealth", "30", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Specifies the amount of repairing for players to be given a point. For use with nails and such."):GetInt()
cvars.AddChangeCallback("zs_repairpointsperhealth", function(cvar, oldvalue, newvalue)
	GAMEMODE.RepairPointsPerHealth = tonumber(newvalue) or 1
end)
