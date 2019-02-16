AddCSLuaFile()

ENT.Base = "npc_zs_base"
if SERVER then
ENT.Type = "nextbot"
else
ENT.Type = "anim"
end

DEFINE_BASECLASS("npc_zs_base")

local Rand = math.random


ENT.Health = 200
ENT.Speed = 140
ENT.Points = 3

ENT.MeleeDelay = 0.74
ENT.MeleeReach = 48
ENT.MeleeSize = 1.5
ENT.MeleeDamage = 23
ENT.MeleeForceScale = 1
ENT.MeleeDamageType = DMG_SLASH

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.Arousal = 0.33 * Rand(0.8, 1.2)
end