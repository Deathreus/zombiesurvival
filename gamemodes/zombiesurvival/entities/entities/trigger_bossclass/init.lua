ENT.Type = "brush"

function ENT:Initialize()
	self:SetTrigger(true)
	self:NextThink(CurTime() + 0.1)
end

function ENT:Think()
	self:Remove()
end

function ENT:AcceptInput(name, activator, caller, args)
	
end

function ENT:KeyValue(key, value)
	
end
