NPC.Class = "npc_zs_zombie"
NPC.Name = translate.Get("class_zombie")
NPC.Health = 200
NPC.Speed = 140
NPC.Model = Model("models/player/zombie_classic.mdl")
NPC.NumSkins = 3
NPC.Points = 3
NPC.Unlocked = true
NPC.Wave = 0 -- this is not what the name implies, only called this for lazy compatability

function NPC:SetupModel(npc)
	if not self.Model then return end

	local mdl = ""
	if type(self.Model) == "table" then
		local rand = math.Round(util.SharedRandom(npc:EntIndex().."_RandModel", 1, #self.Model))
		mdl = self.Model[rand]
	else
		mdl = self.Model
	end

	if (self.NumSkins or 0) > 0 then
		local rand = math.Round(util.SharedRandom(npc:EntIndex().."_RandSkin", 0, self.NumSkins))
		npc:SetSkin(rand)
	end

	npc:SetModel(mdl)
end