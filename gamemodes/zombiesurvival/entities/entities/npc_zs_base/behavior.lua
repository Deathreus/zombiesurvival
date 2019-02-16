-- Default behaviors every NPC will follow

Actions = {
	IDLE = 1,
	CHASE = 2
}

local ActionNames = {
	"IDLE",
	"CHASE"
}

ENT.Action = -1


function ENT:UpdateAction()
	if self.Action == Actions.IDLE then
		local pathopts = {
			lookahead = 100,
			tolerance = 10,
			draw = true
		}

		local areas = navmesh.Find(self:GetPos(), 800, 200, self.loco:GetStepHeight())
		if #areas < 1 then return end

		self:StartActivity(self.AnimSet.WalkAnim - 1 + math.ceil((CurTime() / 4 + self:EntIndex()) % 3))
		self:MoveToPos(table.Random(areas):GetRandomPoint(), pathopts)
		self:StartActivity(self.AnimSet.IdleAnim)

		coroutine.wait(math.Rand(3, 8))
	end
end

function ENT:OnActionStart()
	if self.Action == Actions.IDLE then
		self.SearchDistance = 900
		self.SightRange = 3400
		self.FieldOfView = 75
		self.loco:SetDesiredSpeed(self.Speed / 2)
		return true
	end

	if self.Action == Actions.CHASE then
		self.SearchDistance = 1800
		self.SightRange = 9000
		self.FieldOfView = 120
		self.loco:SetDesiredSpeed(self.Speed)

		if !self:HasEnemy() then
			self:OnActionEnd()
			print(self, "Trying to chase a non-existant enemy, reverting behavior")
			self.Action = Actions.IDLE
			self:OnActionStart()
			return false
		end

		return true
	end
end

function ENT:OnActionEnd()
	if self.Action == Actions.CHASE then
		self:SetEnemy(nil)
		self.IsInterrupted = false
	end
end

function ENT:ChangeAction(new_action, reason)
	if new_action == self.Action then
		return false
	end

	self:OnActionEnd()

	print(tostring(self) .. ": Changed action \"" .. tostring(ActionNames[self.Action]) .. "\" -> \"" .. tostring(ActionNames[new_action]) .. "\"\nReason: " .. reason .. "\n")

	self.Action = new_action

	return self:OnActionStart()
end

function ENT:HandleStuck()
	-- Move backwards a bit and try again
	print(self, "Stuck")
	for i = 1,10 do
		self.loco:Approach(self:GetPos() + (self:GetForward() * 400) * -1, 1000)
		coroutine.yield()
	end
	print(self, "Resetting")
	self.loco:ClearStuck()
end

function ENT:MoveToPos(pos, options)
	--	The same as the base_nextbot implementation,
	--	but it can be interrupted with various conditions

	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 20 )
	path:Compute(self, pos)

	if !path:IsValid() then return "failed" end

	while path:IsValid() do

		path:Update(self)

		if options.draw then
			path:Draw()
		end

		if self.loco:IsStuck() then
			self:HandleStuck()
			return "stuck"
		end

		if self.IsInterrupted then
			self:ChangeAction(Actions.CHASE, "Someone shot me, better chase them!")
			return "interrupted"
		end

		--[[if self:HasEnemy() then
			self:ChangeAction(Actions.CHASE, "I sense humans, giving chase!")
			return "interrupted"
		end--]]

		if options.maxage and path:GetAge() > options.maxage then
			return "timeout"
		end

		if options.repath and path:GetAge() > options.repath then
			path:Compute(self, pos)
		end

		coroutine.yield()
	end

	return "ok"
end
