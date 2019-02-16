local zombieData = {}
function GM:RegisterZombieClass(name, data)
	if zombieData["zombie"] ~= nil then
		table.inherit(data, zombieData["zombie"])
	end

	zombieData[name] = data
end

function GM:GetZombieClassTable()
	return table.Copy(zombieData)
end

function GM:GetZombieClassData(classname)
	if zombieData[classname] ~= nil then
		return zombieData[classname]
	end

	return zombieData["zombie"]
end

function GM:CallZombieFunction(npc, func, ...)
	if not (npc and npc:IsValid()) then return end

	local zombie = self:GetZombieData(npc:GetClass())
	if not zombie then return end

	local func_tocall = zombie[func]
	if func_tocall then
		return func_tocall(zombie, npc, ...)
	end
end

function GM:IsClassUnlocked(classname)
	local classtab = self:GetZombieClassData(classname)
	if not classtab or classtab.BossZombie then return false end

	if classtab.IsClassUnlocked then
		local ret = classtab:IsClassUnlocked()
		if ret ~= nil then return ret end
	end

	return not classtab.Locked and (classtab.Unlocked or classtab.Wave and self:GetWave() >= classtab.Wave or not self:GetWaveActive() and self:GetWave() + 1 >= classtab.Wave)
end

local classes = file.Find(GM.FolderName .. "/gamemode/zombieclasses/*.lua", "LUA")
for i, filename in ipairs(classes) do

	NPC = {}
	include("zombieclasses/" .. filename)

	if NPC.Class then
		GM:RegisterZombieClass(string.StripExtension(filename), NPC)
	else
		ErrorNoHalt("NPC " .. filename .. " has no 'Class' member!")
	end

	NPC = nil
end
