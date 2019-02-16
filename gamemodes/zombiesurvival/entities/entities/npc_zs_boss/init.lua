AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("npc_zs_base")


ENT.BossType = 0

function ENT:Initialize()
	BaseClass.Initialize(self)
end
