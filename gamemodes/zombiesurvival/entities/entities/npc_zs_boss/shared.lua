ENT.Base = "npc_zs_base"
if SERVER then
ENT.Type = "nextbot"
else
ENT.Type = "anim"
end

function ENT:SetBossType(type)
	self.BossType = type

	if type == 1 then
		self.Points = 30
	end
end