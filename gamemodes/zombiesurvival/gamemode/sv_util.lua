function BroadcastLua(code)
	for _, pl in pairs(player.GetAll()) do
		pl:SendLua(code)
	end
end

player.GetByUniqueID = player.GetByUniqueID or function(uid)
	for _, pl in pairs(player.GetAll()) do
		if pl:UniqueID() == uid then return pl end
	end
end

function GM:WorldHint(hint, pos, ent, lifetime, filter)
	net.Start("zs_worldhint")
		net.WriteString(hint)
		net.WriteVector(pos or ent and ent:IsValid() and ent:GetPos() or vector_origin)
		net.WriteEntity(ent or NULL)
		net.WriteFloat(lifetime or 8)
	if filter then
		net.Send(filter)
	else
		net.Broadcast()
	end
end

function GM:DamageFloater(attacker, victim, dmginfo)
	local dmgpos = dmginfo:GetDamagePosition()
	if dmgpos == vector_origin then dmgpos = victim:NearestPoint(attacker:EyePos()) end

	net.Start(victim:IsPlayer() and "zs_dmg" or "zs_dmg_prop")
		if INFDAMAGEFLOATER then
			INFDAMAGEFLOATER = nil
			net.WriteUInt(9999, 16)
		else
			net.WriteUInt(math.ceil(dmginfo:GetDamage()), 16)
		end
		net.WriteVector(dmgpos)
	net.Send(attacker)
end

function GM:CreateGibs(pos, headoffset)
	headoffset = headoffset or 0

	local headpos = Vector(pos.x, pos.y, pos.z + headoffset)
	for i = 1, 2 do
		local ent = ents.CreateLimited("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(headpos + VectorRand() * 5)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(i)
			ent:Spawn()
		end
	end

	for i = 1, 4 do
		local ent = ents.CreateLimited("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(pos + VectorRand() * 12)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(math.random(3, #GAMEMODE.HumanGibs))
			ent:Spawn()
		end
	end
end

function GM:RemoveUnusedEntities()
	-- Causes a lot of needless lag.
	util.RemoveAll("prop_ragdoll")

	-- Remove NPCs because first of all this game is PvP and NPCs can cause crashes.
	util.RemoveAll("npc_maker")
	util.RemoveAll("npc_template_maker")
	util.RemoveAll("npc_zombie")
	util.RemoveAll("npc_zombie_torso")
	util.RemoveAll("npc_fastzombie")
	util.RemoveAll("npc_headcrab")
	util.RemoveAll("npc_headcrab_fast")
	util.RemoveAll("npc_headcrab_black")
	util.RemoveAll("npc_poisonzombie")

	-- Such a headache. Just remove them all.
	util.RemoveAll("item_ammo_crate")

	-- Shouldn't exist.
	util.RemoveAll("item_suitcharger")
end

function GM:ReplaceMapWeapons()
	for _, ent in pairs(ents.FindByClass("weapon_*")) do
		local wepclass = ent:GetClass()
		if wepclass ~= "weapon_map_base" then
			if string.sub(wepclass, 1, 10) == "weapon_zs_" then
				local wep = ents.Create("prop_weapon")
				if wep:IsValid() then
					wep:SetPos(ent:GetPos())
					wep:SetAngles(ent:GetAngles())
					wep:SetWeaponType(ent:GetClass())
					wep:SetShouldRemoveAmmo(false)
					wep:Spawn()
					wep.IsPreplaced = true
				end
			end
			ent:Remove()
		end
	end
end

local ammoreplacements = {
	["item_ammo_357"] = "357",
	["item_ammo_357_large"] = "357",
	["item_ammo_pistol"] = "pistol",
	["item_ammo_pistol_large"] = "pistol",
	["item_ammo_buckshot"] = "buckshot",
	["item_ammo_ar2"] = "ar2",
	["item_ammo_ar2_large"] = "ar2",
	["item_ammo_ar2_altfire"] = "pulse",
	["item_ammo_crossbow"] = "xbowbolt",
	["item_ammo_smg1"] = "smg1",
	["item_ammo_smg1_large"] = "smg1",
	["item_box_buckshot"] = "buckshot"
}
function GM:ReplaceMapAmmo()
	for classname, ammotype in pairs(ammoreplacements) do
		for _, ent in pairs(ents.FindByClass(classname)) do
			local newent = ents.Create("prop_ammo")
			if newent:IsValid() then
				newent:SetAmmoType(ammotype)
				newent.PlacedInMap = true
				newent:SetPos(ent:GetPos())
				newent:SetAngles(ent:GetAngles())
				newent:Spawn()
				newent:SetAmmo(self.AmmoCache[ammotype] or 1)
			end
			ent:Remove()
		end
	end

	util.RemoveAll("item_item_crate")
end

function GM:ReplaceMapBatteries()
	util.RemoveAll("item_battery")
end

function GM:TryHumanPickup(pl, entity)
	if self.ZombieEscape or pl.NoObjectPickup or not pl:Alive() or pl:Team() ~= TEAM_HUMAN then return end

	if entity:IsValid() and not entity.m_NoPickup then
		local entclass = string.sub(entity:GetClass(), 1, 12)
		if (entclass == "prop_physics" or entclass == "func_physbox" or entity.HumanHoldable and entity:HumanHoldable(pl)) and not entity:IsNailed() and entity:GetMoveType() == MOVETYPE_VPHYSICS and entity:GetPhysicsObject():IsValid() and entity:GetPhysicsObject():GetMass() <= CARRY_MAXIMUM_MASS and entity:GetPhysicsObject():IsMoveable() and entity:OBBMins():Length() + entity:OBBMaxs():Length() <= CARRY_MAXIMUM_VOLUME then
			local holder, _ = entity:GetHolder()
			if not holder and not pl:IsHolding() and CurTime() >= (pl.NextHold or 0)
			and pl:GetShootPos():Distance(entity:NearestPoint(pl:GetShootPos())) <= 64 and pl:GetGroundEntity() ~= entity then
				local newstatus = ents.Create("status_human_holding")
				if newstatus:IsValid() then
					pl.NextHold = CurTime() + 0.25
					pl.NextUnHold = CurTime() + 0.05
					newstatus:SetPos(pl:GetShootPos())
					newstatus:SetOwner(pl)
					newstatus:SetParent(pl)
					newstatus:SetObject(entity)
					newstatus:Spawn()
				end
			end
		end
	end
end

local function groupsort(a, b)
	return #a > #b
end
function GM:AttemptHumanDynamicSpawn(pl)
	if pl:IsValid() and pl:IsPlayer() and pl:Alive() and pl:Team() == TEAM_HUMAN and self.DynamicSpawning then
		local groups = self:GetTeamRallyGroups(TEAM_HUMAN)
		table.sort(groups, groupsort)
		for i=1, #groups do
			local group = groups[i]

			local allplayers = team.GetPlayers(TEAM_HUMAN)
			for _, otherpl in pairs(group) do
				if otherpl ~= pl then
					local pos = otherpl:GetPos() + Vector(0, 0, 1)
					if otherpl:Alive() and otherpl:GetMoveType() == MOVETYPE_WALK and not util.TraceHull({start = pos, endpos = pos + playerheight, mins = playermins, maxs = playermaxs, mask = MASK_SOLID, filter = allplayers}).Hit then
						local nearzombie = false
						for __, ent in pairs(team.GetPlayers(TEAM_UNDEAD)) do
							if ent:Alive() and ent:GetPos():Distance(pos) <= 256 then
								nearzombie = true
							end
						end

						if not nearzombie then
							pl:SetPos(otherpl:GetPos())
							return true
						end
					end
				end
			end
		end
	end

	return false
end

function GM:IsClassicMode()
	return self.ClassicMode
end

function GM:IsBabyMode()
	return self.BabyMode
end

function GM:CenterNotifyAll(...)
	net.Start("zs_centernotify")
		net.WriteTable({...})
	net.Broadcast()
end
GM.CenterNotify = GM.CenterNotifyAll

function GM:TopNotifyAll(...)
	net.Start("zs_topnotify")
		net.WriteTable({...})
	net.Broadcast()
end
GM.TopNotify = GM.TopNotifyAll

function GM:CalculateInfliction(victim, attacker)
	if self.RoundEnded or self:GetWave() == 0 then return self.CappedInfliction end

	local players = 0
	local zombies = 0
	local humans = 0
	local wonhumans = 0
	local hum
	for _, pl in pairs(player.GetAllActive()) do
		if not pl.Disconnecting then
			if pl:Team() == TEAM_UNDEAD then
				zombies = zombies + 1
			elseif pl:HasWon() then
				wonhumans = wonhumans + 1
			else
				humans = humans + 1
				hum = pl
			end
		end
	end

	players = humans + zombies

	if players == 0 then return self.CappedInfliction end

	local infliction = math.max(zombies / players, self.CappedInfliction)
	self.CappedInfliction = infliction

	if humans == 1 and 2 < zombies then
		gamemode.Call("LastHuman", hum)
	elseif 1 <= infliction then
		infliction = 1

		if wonhumans >= 1 then
			gamemode.Call("EndRound", TEAM_HUMAN)
		else
			gamemode.Call("EndRound", TEAM_UNDEAD)

			if attacker and attacker:IsValid() and attacker:IsPlayer() and attacker:Team() == TEAM_UNDEAD and attacker ~= victim then
				gamemode.Call("LastBite", victim, attacker)
			end
		end
	end

	if not self:IsClassicMode() and not self.ZombieEscape and not self:IsBabyMode() and not self.PantsMode then
		for k, v in ipairs(self:GetZombieClassTable()) do
			if v.Infliction and infliction >= v.Infliction and not self:IsClassUnlocked(k) then
				v.Unlocked = true

				if not self.PantsMode and not self:IsClassicMode() and not self:IsBabyMode() and not self.ZombieEscape and not v.Locked then
					for _, pl in pairs(player.GetHumans()) do
						pl:CenterNotify(COLOR_RED, translate.ClientFormat(pl, "infliction_reached", v.Infliction * 100))
						pl:CenterNotify(translate.ClientFormat(pl, "x_unlocked", k))
					end
				end
			end
		end
	end

	for _, ent in pairs(ents.FindByClass("logic_infliction")) do
		if ent.Infliction <= infliction then
			ent:Input("oninflictionreached", NULL, NULL, infliction)
		end
	end

	return infliction
end

-- Reevaluates a prop and its constraint system (or all props if no arguments) to determine if they should be frozen or not from nails.
function GM:EvaluatePropFreeze(ent, neighbors)
	if not ent then
		for _, e in pairs(ents.GetAll()) do
			if e and e:IsValid() then
				self:EvaluatePropFreeze(e)
			end
		end

		return
	end

	if ent:IsNailedToWorldHierarchy() then
		ent:SetNailFrozen(true)
	elseif ent:GetNailFrozen() then
		ent:SetNailFrozen(false)
	end

	neighbors = neighbors or {}
	table.insert(neighbors, ent)

	for _, nail in pairs(ent:GetNails()) do
		if nail:IsValid() then
			local baseent = nail:GetBaseEntity()
			local attachent = nail:GetAttachEntity()
			if baseent:IsValid() and not baseent:IsWorld() and not table.HasValue(neighbors, baseent) then
				self:EvaluatePropFreeze(baseent, neighbors)
			end
			if attachent:IsValid() and not attachent:IsWorld() and not table.HasValue(neighbors, attachent) then
				self:EvaluatePropFreeze(attachent, neighbors)
			end
		end
	end
end

function GM:RemoveDuplicateAmmo(pl)
	local AmmoCounts = {}
	local WepAmmos = {}
	for _, wep in pairs(pl:GetWeapons()) do
		if wep.Primary then
			local ammotype = wep:ValidPrimaryAmmo()
			if ammotype and wep.Primary.DefaultClip > 0 then
				AmmoCounts[ammotype] = (AmmoCounts[ammotype] or 0) + 1
				WepAmmos[wep] = wep.Primary.DefaultClip - wep.Primary.ClipSize
			end
			local ammotype2 = wep:ValidSecondaryAmmo()
			if ammotype2 and wep.Secondary.DefaultClip > 0 then
				AmmoCounts[ammotype2] = (AmmoCounts[ammotype2] or 0) + 1
				WepAmmos[wep] = wep.Secondary.DefaultClip - wep.Secondary.ClipSize
			end
		end
	end
	for ammotype, count in pairs(AmmoCounts) do
		if count > 1 then
			local highest = 0
			local highestwep
			for wep, extraammo in pairs(WepAmmos) do
				if wep.Primary.Ammo == ammotype then
					highest = math.max(highest, extraammo)
					highestwep = wep
				end
			end
			if highestwep then
				for wep, extraammo in pairs(WepAmmos) do
					if wep ~= highestwep and wep.Primary.Ammo == ammotype then
						pl:RemoveAmmo(extraammo, ammotype)
					end
				end
			end
		end
	end
end

local function TimedOut(pl)
	if pl:IsValid() and pl:Team() == TEAM_HUMAN and pl:Alive() and not GAMEMODE.CheckedOut[pl:UniqueID()] then
		gamemode.Call("GiveRandomEquipment", pl)
	end
end
function GM:GiveDefaultOrRandomEquipment(pl)
	if not self.CheckedOut[pl:UniqueID()] and not self.ZombieEscape then
		if self.StartingLoadout then
			self:GiveStartingLoadout(pl)
		else
			pl:SendLua("GAMEMODE:RequestedDefaultCart()")
			if self.StartingWorth > 0 then
				timer.Simple(4, function() TimedOut(pl) end)
			end
		end
	end
end

function GM:GiveStartingLoadout(pl)
	for item, amount in pairs(self.StartingLoadout) do
		for i = 1, amount do
			pl:Give(item)
		end
	end
end

function GM:GiveRandomEquipment(pl)
	if self.CheckedOut[pl:UniqueID()] or self.ZombieEscape then return end
	self.CheckedOut[pl:UniqueID()] = true

	if self.StartingLoadout then
		self:GiveStartingLoadout(pl)
	elseif GAMEMODE.OverrideStartingWorth then
		pl:Give("weapon_zs_swissarmyknife")
	elseif #self.StartLoadouts >= 1 then
		for _, id in pairs(self.StartLoadouts[math.random(#self.StartLoadouts)]) do
			local tab = FindStartingItem(id)
			if tab then
				if tab.Callback then
					tab.Callback(pl)
				elseif tab.SWEP then
					pl:StripWeapon(tab.SWEP)
					pl:Give(tab.SWEP)
				end
			end
		end
	end
end

function GM:PlayerCanCheckout(pl)
	return pl:IsValid() and pl:Team() == TEAM_HUMAN and pl:Alive() and not self.CheckedOut[pl:UniqueID()] and not self.StartingLoadout and not self.ZombieEscape and self.StartingWorth > 0 and self:GetWave() < 2
end

function GM:SetPantsMode(mode)
	if self.ZombieEscape then return end

	self.PantsMode = mode and self.ZombieClasses["Zombie Legs"] ~= nil and not self:IsClassicMode() and not self:IsBabyMode()

	if self.PantsMode then
		local index = self.ZombieClasses["Zombie Legs"].Index

		self.PreOverrideDefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass
		self.DefaultZombieClass = index

		for _, pl in pairs(player.GetAll()) do
			local classname = pl:GetZombieClassTable().Name
			if classname ~= "Zombie Legs" and classname ~= "Crow" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(index)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(index)
				end
			end
			pl.DeathClass = index
		end
	else
		self.DefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass

		for _, pl in pairs(player.GetAll()) do
			if pl:GetZombieClassTable().Name == "Zombie Legs" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(self.DefaultZombieClass or 1)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(self.DefaultZombieClass or 1)
				end
			end
		end
	end
end

function GM:SetClassicMode(mode)
	if self.ZombieEscape then return end

	self.ClassicMode = mode and self.ZombieClasses["Classic Zombie"] ~= nil and not self.PantsMode and not self:IsBabyMode()

	SetGlobalBool("classicmode", self.ClassicMode)

	if self:IsClassicMode() then
		util.RemoveAll("prop_nail")

		local index = self.ZombieClasses["Classic Zombie"].Index

		self.PreOverrideDefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass
		self.DefaultZombieClass = index

		for _, pl in pairs(player.GetAll()) do
			local classname = pl:GetZombieClassTable().Name
			if classname ~= "Classic Zombie" and classname ~= "Crow" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(index)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(index)
				end
			end
			pl.DeathClass = index
		end
	else
		self.DefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass

		for _, pl in pairs(player.GetAll()) do
			if pl:GetZombieClassTable().Name == "Classic Zombie" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(self.DefaultZombieClass or 1)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(self.DefaultZombieClass or 1)
				end
			end
		end
	end
end

function GM:SetBabyMode(mode)
	if self.ZombieEscape then return end

	self.BabyMode = mode and self.ZombieClasses["Gore Child"] ~= nil and not self.PantsMode and not self:IsClassicMode()

	SetGlobalBool("babymode", self.BabyMode)

	if self:IsBabyMode() then
		local index = self.ZombieClasses["Gore Child"].Index

		self.PreOverrideDefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass
		self.DefaultZombieClass = index

		for _, pl in pairs(player.GetAll()) do
			local classname = pl:GetZombieClassTable().Name
			if classname ~= "Gore Child" and classname ~= "Giga Gore Child" and classname ~= "Crow" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(index)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(index)
				end
			end
			pl.DeathClass = index
		end
	else
		self.DefaultZombieClass = self.PreOverrideDefaultZombieClass or self.DefaultZombieClass

		for _, pl in pairs(player.GetAll()) do
			if pl:GetZombieClassTable().Name == "Gore Child" then
				if pl:Team() == TEAM_UNDEAD then
					pl:KillSilent()
					pl:SetZombieClass(self.DefaultZombieClass or 1)
					pl:UnSpectateAndSpawn()
				else
					pl:SetZombieClass(self.DefaultZombieClass or 1)
				end
			end
		end
	end
end

function GM:GetDynamicSpawning()
	return self.DynamicSpawning
end

function GM:GetNearestSpawn(pos, teamid)
	local nearest = NULL

	local nearestdist = math.huge
	for _, ent in pairs(team.GetValidSpawnPoint(teamid)) do
		if ent.Disabled then continue end

		local dist = ent:GetPos():Distance(pos)
		if dist < nearestdist then
			nearestdist = dist
			nearest = ent
		end
	end

	return nearest
end

function GM:EntityWouldBlockSpawn(ent)
	local spawnpoint = self:GetNearestSpawn(ent:GetPos(), TEAM_UNDEAD)

	if spawnpoint:IsValid() then
		local spawnpos = spawnpoint:GetPos()
		if spawnpos:Distance(ent:NearestPoint(spawnpos)) <= 40 then return true end
	end

	return false
end

function GM:GetNearestSpawnDistance(pos, teamid)
	local nearest = self:GetNearestSpawn(pos, teamid)
	if nearest:IsValid() then
		return nearest:GetPos():Distance(pos)
	end

	return -1
end

function GM:DefaultRevive(pl)
	local status = pl:GiveStatus("revive")
	if status and status:IsValid() then
		status:SetReviveTime(CurTime() + 2)
	end
end