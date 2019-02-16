AddCSLuaFile("shared.lua")

-- Animations --
ENT.AnimSet = {
	IdleAnim = ACT_HL2MP_IDLE_ZOMBIE,
	WalkAnim = ACT_HL2MP_WALK_ZOMBIE_01,
	RunAnim = ACT_HL2MP_RUN_ZOMBIE,
	JumpAnim = ACT_HL2MP_JUMP_ZOMBIE,
	CrouchIdle = ACT_HL2MP_IDLE_CROUCH_ZOMBIE_01,
	CrouchWalk = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01,
	AttackAnim = ACT_GMOD_GESTURE_RANGE_ZOMBIE
}

-- Sounds --
ENT.PropHitSound = Sound("npc/zombie/zombie_pound_door.wav")

-- Footsteps --
ENT.UseFootSteps = true
ENT.FootStepInterval = 1

-- Immunities --
ENT.ImmuneToElectricity = false
ENT.ImmuneToFire = false
ENT.ImmuneToIce = false
ENT.CanDrown = false
ENT.BreathTime = 30

-- Misc --
ENT.IdleNoiseInterval = 10
ENT.IdleSounds = {}
ENT.CanJump = true
ENT.JumpHeight = 58
ENT.CanCrouch = true
ENT.CrouchSpeed = 50
ENT.Enemy = nil
ENT.DamagedBy = {}

include("shared.lua")

function ENT:Initialize()
	self:SetCollisionBounds(Vector(-10,-10,0), Vector(10,10,64))
	self:SetSolidMask(bit.bor(MASK_PLAYERSOLID, CONTENTS_TEAM2))

	if SERVER then
		self.loco:SetStepHeight(20)
		self.loco:SetAcceleration(1700)
		self.loco:SetDeceleration(900)
		self.loco:SetMaxYawRate(180)
		if self.CanJump then
			self.loco:SetJumpHeight(self.JumpHeight)
		end

		self.Arousal = 0

		self:NextThink(CurTime() + 0.1)

		TheDirector:AddZombie(string.sub(self:GetClass(), 8)) -- -npc_zs_
	end
end
