ENT.Base = "base_nextbot"

if SERVER then
ENT.Type = "nextbot"
-- Uncomment for testing purposes
-- ENT.Spawnable = true
else
ENT.Type = "anim"
end


function ENT:GetEnemy()
	return self.Enemy
end

function ENT:SetEnemy(ent)
	self.Enemy = ent
end

function ENT:Classify()
	return CLASS_ZOMBIE
end

function ENT:IsNPC()
	return true
end

function ENT:Alive()
	return self:Health() > 0
end

function ENT:CheckValid()
	return IsValid(self) or self:Alive()
end

function ENT:PlayGestureSequence( sequence )
	local seqid = self:LookupSequence( sequence )
	self:AddGestureSequence( seqid, true )
end


if SERVER then

include("behavior.lua")

ENT.FeetBones = {
	["left"] = "ValveBiped.Bip01_L_Foot",
	["right"] = "ValveBiped.Bip01_R_Foot",
}

ENT.FeetOnGround = {
	["left"] = false,
	["right"] = false,
}

local Rand = math.random
local TraceLine = util.TraceLine

local StepSounds = {
	"npc/zombie/foot1.wav",
	"npc/zombie/foot2.wav",
	"npc/zombie/foot3.wav"
}
local ScuffSounds = {
	"npc/zombie/foot_slide1.wav",
	"npc/zombie/foot_slide2.wav",
	"npc/zombie/foot_slide3.wav"
}

function ENT:HasEnemy()
	local enemy = self:GetEnemy()
	if IsValid(enemy) and enemy:Alive() then
		if self:GetRangeTo(enemy:GetPos()) > self.SearchDistance then
			local dot = self:GetForward():Dot(enemy:GetPos() - self:GetPos())
			if enemy:GetPos():Distance(self:GetPos()) < self.SightRange and dot > math.cos(math.rad(self.FieldOfView)) and enemy:Visible(self) then
				return true
			end

			return self:FindEnemy()
		end

		return true
	else
		return self:FindEnemy()
	end
end

function ENT:FindEnemy()
	local _ents = ents.FindInSphere(self:GetPos(), self.SearchDistance)
	for k, v in pairs(_ents) do
		if v:IsPlayer() then
			self:SetEnemy(v)
			return true
		end
	end

	self:SetEnemy(nil)
	return false
end

function ENT:RunBehaviour()
	if Rand() < self.Arousal then
		self:ChangeAction(Actions.CHASE, "I'm already pissed off, chasing the player")
	else
		self:ChangeAction(Actions.IDLE, "Beginning behavior")
	end

	while true do
		self:UpdateAction()
		coroutine.wait(0.1)
	end
end

function ENT:Think()
	if not IsValid(self) then return end

	if self.UseFootSteps then
		for k, v in pairs(self.FeetBones) do
			if type(v) != "string" then continue end

			local bone = self:LookupBone(v)
			if not bone then continue end

			local pos, ang = self:GetBonePosition(bone)
			local tr = TraceLine({
				start = pos,
				endpos = pos - ang:Right()*5 + ang:Forward()*6,
				filter = self
			})

			if tr.Hit and not self.FeetOnGround[k] then
				if Rand() < 0.15 then
					self:EmitSound(ScuffSounds[Rand(#ScuffSounds)], 70)
				else
					self:EmitSound(StepSounds[Rand(#StepSounds)], 70)
				end
			end

			self.FeetOnGround[k] = tr.Hit
		end
	end

	self:NextThink(CurTime() + 0.1)
end

function ENT:BodyUpdate()
	if self:GetActivity() != self.AnimSet.IdleAnim then
		self:BodyMoveXY()
	end

	self:FrameAdvance()
end

function ENT:OnLeaveGround(ent)
	self:RestartGesture(self.AnimSet.JumpAnim)
end

function ENT:OnInjured(dmginfo)
	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		self.IsInterrupted = true
		self:SetEnemy(attacker)

		self.DamagedBy[attacker] = ( self.DamagedBy[attacker] or 0 ) + dmginfo:GetDamage()

		if dmginfo:IsBulletDamage() then
			local tr = util.TraceLine({
				start = attacker:EyePos(),
				endpos = attacker:EyePos() + (dmginfo:GetDamagePosition() - attacker:EyePos()) * 2,
				mask = MASK_SHOT,
				filter = attacker
			})
			local hitgroup = tr.HitGroup

			if hitgroup == HITGROUP_HEAD then
				dmginfo:ScaleDamage(2.0)
			elseif hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG or hitgroup == HITGROUP_GEAR then
				dmginfo:ScaleDamage(0.25)
			elseif hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM then
				dmginfo:ScaleDamage(0.75)
			end

			if ( self.NextFlinch or 0 ) < CurTime() then
				if hitgroup == HITGROUP_HEAD then
					self:PlayGestureSequence( "flinch_head_0" .. Rand(1,2) )
				elseif hitgroup == HITGROUP_RIGHTARM then
					self:PlayGestureSequence( "flinch_shoulder_r" )
				elseif hitgroup == HITGROUP_LEFTARM then
					self:PlayGestureSequence( "flinch_shoulder_l" )
				elseif hitgroup == HITGROUP_CHEST then
					self:PlayGestureSequence( "flinch_phys_0" .. Rand(1,2) )
				elseif hitgroup == HITGROUP_GEAR or  hitgroup == HITGROUP_STOMACH then
					self:PlayGestureSequence( "flinch_stomach_0" .. Rand(1,2) )
				elseif hitgroup == HITGROUP_RIGHTLEG or hitgroup == HITGROUP_LEFTLEG then
					self:PlayGestureSequence( "flinch_0" .. Rand(1,2) )
				end

				self.NextFlinch = CurTime() + Rand(0.5, 1.0)
			end
		end

		attacker.m_PointQueue = ( attacker.m_PointQueue or 0 ) + dmginfo:GetDamage() / self:GetMaxHealth() * ( self.Points or 0 )
		attacker.m_LastDamageDealtPosition = self:GetPos()
		attacker.m_LastDamageDealt = CurTime()
	end
end

function ENT:OnKilled(dmginfo)
	hook.Run("OnNPCKilled", self, dmginfo:GetAttacker(), dmginfo:GetInflictor())
	gamemode.Call("HumanKilledZombie", self, dmginfo:GetAttacker(), dmginfo:GetInflictor(), dmginfo)

	self:BecomeRagdoll(dmginfo)

	TheDirector:RemoveZombie(string.sub(self:GetClass(), 8)) -- -npc_zs_
end

function ENT:OnOtherKilled(ent, dmginfo)
	local attacker = dmginfo:GetAttacker()
	if not IsValid(attacker) then attacker = dmginfo:GetInflictor() end

	if IsValid(attacker) and attacker:IsPlayer() and ent:IsNPC() and self:GetRangeTo(ent:GetPos()) < self.SearchDistance then
		local tr = TraceLine({
			start = self:GetPos() + Vector(0,0,32),
			endpos = ent:GetPos() + Vector(0,0,32),
			mask = MASK_SHOT,
			filter = self
		})

		if tr.Fraction == 1.0 or tr.Entity == ent then
			self:SetEnemy(attacker)
		end
	end
end


end

function ENT:HandleAnimEvent(event, eventTime, cycle, type, options)
	print(self, event, eventTime, type, options)
end

if CLIENT then
	language.Add("npc_zs_base", "Base NextBot")
end
