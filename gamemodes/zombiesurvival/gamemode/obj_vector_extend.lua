local meta = FindMetaTable("Vector")
if not meta then return end

function meta:DistanceZSkew(vec, skew)
	return math.sqrt((self.x - vec.x) ^ 2 + (self.y - vec.y) ^ 2 + ((self.z - vec.z) * skew) ^ 2)
end

function meta:IsDistToBetween(other, min, max)
	local distance = self:Distance(other)
	return distance >= min and distance <= max
end
