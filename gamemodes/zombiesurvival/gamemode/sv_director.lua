include("sh_options.lua")

local SpawningAllowed = CreateConVar("zs_spawningallowed", "1", FCVAR_CHEAT, "Disable or enable the AI director")
local BossesAllowed = CreateConVar("zs_bossspawningallowed", "1", FCVAR_CHEAT, "Toggle spawning bosses during finales")
local DebugDirector = CreateConVar("zs_debugdirector", "1", FCVAR_CHEAT, "Turn on debugging of spawn procedures (show spawn areas, spit out candidate errors, mention succesful spawns)")

local Rand = math.random

local zombieMins = Vector(-10,-10,0)
local zombieMaxs = Vector(10,10,64)

-- We don't actually use the path this makes in any way, this is just to theoretically determine if a spawn location can reach a target
local function BuildPath(start, goal, maxPathLength, teamID, ignoreNavBlockers)
	if not IsValid(start) or not IsValid(goal) then
		return false
	end
	if start == goal then
		return true
	end

	maxPathLength = maxPathLength or 0.0
	teamID = teamID or -2
	ignoreNavBlockers = ignoreNavBlockers or false

	if goal:IsBlocked(teamID, ignoreNavBlockers) then
		return false
	end

	start:ClearSearchLists()
	start:SetCostSoFar(0)
	start:SetTotalCost(start:GetCenter():Distance(goal:GetCenter()))

	start:AddToOpenList()
	start:UpdateOnOpenList()

	while not start:IsOpenListEmpty() do
		local current = start:PopOpenList()
		if current:IsBlocked(teamID, ignoreNavBlockers) then
			continue
		end

		if current == goal then
			return true
		end

		current:AddToClosedList()

		for _, neighbor in pairs(current:GetAdjacentAreas()) do
			local newCostSoFar = current:GetCostSoFar() + current:GetCenter():Distance(neighbor:GetCenter())

			if ( neighbor:IsOpen() or neighbor:IsClosed() ) and neighbor:GetCostSoFar() <= newCostSoFar then
				continue
			end

			if maxPathLength > 0.0 and maxPathLength < newCostSoFar then
				continue
			end

			neighbor:SetCostSoFar(newCostSoFar);
			neighbor:SetTotalCost(newCostSoFar + neighbor:GetCenter():Distance(goal:GetCenter()))

			if neighbor:IsClosed() then
				neighbor:RemoveFromClosedList()
			end

			if neighbor:IsOpen() then
				neighbor:UpdateOnOpenList()
			else
				neighbor:AddToOpenList()
			end
		end
	end
end

local function LineBetweenClear(startPos, endPos)
	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		mask = MASK_NPCSOLID_BRUSHONLY
	})

	return tr.Fraction == 1.0
end

local DIRECTOR = {}
DIRECTOR.__index = DIRECTOR

DIRECTOR.HordeDelay = -1.0
DIRECTOR.SpawnDelay = -1.0
DIRECTOR.SustainDuration = -1.0
DIRECTOR.ClusterInterval = -1.0
DIRECTOR.ZombieCount = 0
DIRECTOR.HordeCount = 0
DIRECTOR.UnlockedClasses = {}
DIRECTOR.BaseSpawnPoints = {} -- entities
DIRECTOR.DynamicSpawnPoints = {} -- nav areas
DIRECTOR.Zombies = {}

function DIRECTOR:Init()
	self.HordeDelay = -1.0
	self.SpawnDelay = -1.0
	self.SustainDuration = -1.0
	self.ClusterInterval = -1.0
	self.ZombieCount = 0
	self.HordeCount = 0
	self.IsFinale = false
	self.HordeEnabled = true
	self.WanderersEnabled = true
	self.BossesEnabled = BossesAllowed:GetBool()
	self.ReachedPeak = false
	self.UnlockedClasses = {}
	self.BaseSpawnPoints = {}
	self.DynamicSpawnPoints = {}
	self.Zombies = {}
	self.HordePosition = Vector(0,0,0)

	self:FindHordePosition()
end

function DIRECTOR:SetupDefaultSpawningPoints(spawntab)
	table.Add(self.BaseSpawnPoints, spawntab)
	if DebugDirector:GetBool() then
		PrintTable(self.BaseSpawnPoints)
	end
end

function DIRECTOR:MakeClassesAvailable(unlocktab)
	for _, id in pairs(unlocktab) do
		if not table.HasValue(self.UnlockedClasses, id) then
			table.insert(self.UnlockedClasses, id)
			if DebugDirector:GetBool() then
				PrintTable(self.UnlockedClasses)
			end
		end
	end
end

-- Just incase there's more than 1 player
function DIRECTOR:GetMaxStress()
	local maxStress = 0
	for _, pl in pairs(player.GetHumans()) do
		maxStress = math.max(pl:GetStress(), maxStress)
	end

	return maxStress
end

function DIRECTOR:AddZombie(type)
	self.Zombies[type] = (self.Zombies[type] or 0) + 1
	if DebugDirector:GetBool() then
		PrintTable(self.Zombies)
	end

	self.ZombieCount = self.ZombieCount + 1
end

function DIRECTOR:RemoveZombie(type)
	self.Zombies[type] = math.max((self.Zombies[type] or 0) - 1, 0) -- this shouldn't go below 0, but can't hurt to gaurd it anyway
	if DebugDirector:GetBool() then
		PrintTable(self.Zombies)
	end

	self.ZombieCount = math.max(self.ZombieCount - 1, 0)
end

function DIRECTOR:EndBreak()
	self.HordeEnabled = true
	self.WanderersEnabled = true

	self.BossesEnabled = BossesAllowed:GetBool()

	self.TimeBetweenSpawns = Rand(GAMEMODE.InitialIntervalMin, GAMEMODE.InitialIntervalMax) / gamemode.Call("GetWave")

	gamemode.Call("SetWaveActive", true)
end

function DIRECTOR:FindHordePosition()
	local epicentre = Vector(0,0,0)
	local plys = player.GetHumans()
	if #plys == 1 then
		epicentre = plys[1]:GetPos()
	else
		for _, pl in pairs(plys) do
			if pl:Alive() then
				epicentre = epicentre + pl:GetPos()
			end
		end
		epicentre = epicentre / #plys
	end

	if #self.DynamicSpawnPoints <= 0 then
		local spawn = table.Random(self.BaseSpawnPoints)
		if not IsValid(spawn) then
			return false
		end

		if BuildPath(navmesh.GetNavArea(spawn:GetPos(), 30), navmesh.GetNavArea(epicentre, 30)) then
			local point = spawn:GetPos() + Vector(0,0,16)
			if self:SpawnPointValid(point, zombieMins, zombieMaxs) then
				self.HordePosition = point
				return true
			end
		end
	else
		for i=0, 3 do
			local area = table.Random(self.DynamicSpawnPoints)
			if not IsValid(area) or area:IsBlocked(-2) then
				continue
			end

			if BuildPath(area, navmesh.GetNavArea(epicentre, 30)) then
				local point = area:GetRandomPoint() + Vector(0,0,16)
				if self:SpawnPointValid(point, zombieMins, zombieMaxs) then
					self.HordePosition = point
					return true
				end
			end
		end
	end

	return false
end

function DIRECTOR:SpawnPointValid(pos, mins, maxs, checkGround)
	checkGround = checkGround or true
	local tr = {}

	util.TraceHull({
		start = pos,
		endpos = pos,
		mins = mins,
		maxs = maxs,
		mask = MASK_NPCSOLID,
		output = tr
	})

	if tr.Fraction ~= 1.0 then
		return false
	end

	if checkGround then
		util.TraceHull({
			start = pos,
			endpos = pos - Vector(0,0,64),
			mins = mins,
			maxs = maxs,
			mask = MASK_NPCSOLID,
			output = tr
		})

		return tr.Hit
	end

	return true
end

function DIRECTOR:SpawnZombie(class, pos)
	if class ~= nil then
		local zombie = ents.Create(class.Class)
		if IsValid(zombie) then
			zombie:SetPos(pos)
			zombie:SetAngles(Vector(0, math.Rand(-1, 1), 0):Angle())
			zombie:Spawn()
			zombie:SetHealth(class.Health)
			zombie:SetMaxHealth(zombie:Health())
			zombie:SetModel(class.Model)
			zombie.loco:SetDesiredSpeed(class.Speed)

			return true
		end
	end

	return false
end

function DIRECTOR:SpawnZombieRandomly()
	local zombies = {}
	for k, class in pairs(GAMEMODE:GetZombieClassTable()) do
		if gamemode.Call("IsClassUnlocked", k) then
			table.insert(zombies, class)
		end
	end

	for i=1, 10 do
		if Rand(0, 3) == 0 then
			local spawn = table.Random(self.BaseSpawnPoints)
			if not IsValid(spawn) then
				continue
			end

			local zombie = table.Random(zombies) -- TODO: Weighted spawn list using self.Zombies table and current wave
			local pos = spawn:GetPos() + Vector(0,0,16)
			if self:SpawnPointValid(pos, zombieMins, zombieMaxs) and self:SpawnZombie(zombie, pos) then
				break
			end
		else
			local area = table.Random(self.DynamicSpawnPoints)
			if not IsValid(area) or area:IsBlocked(-2) then
				continue
			end

			local zombie = table.Random(zombies) -- TODO: Weighted spawn list using self.Zombies table and current wave
			local pos = area:GetRandomPoint() + Vector(0,0,16)
			if self:SpawnPointValid(pos, zombieMins, zombieMaxs) and self:SpawnZombie(zombie, pos) then
				break
			end
		end
	end
end

function DIRECTOR:SpawnZombieCluster(amount, pos)
	local spawned = 0

	if self:SpawnPointValid(pos, zombieMins, zombieMaxs) and self:SpawnZombie(GAMEMODE:GetZombieClassData("zombie"), pos) then
		spawned = spawned + 1
	end

	-- try to spawn a grid of at most 5x5
	for i=0, 4 do
		if spawned >= amount then break end

		local newPos = pos
		-- top and bottom
		for x=-i, i do
			if spawned >= amount then break end
			newPos = pos
			newPos.x = newPos.x + x * 20 -- (10 - -10)
			newPos.y = newPos.y + i * 20
			if LineBetweenClear(pos, newPos) and self:SpawnPointValid(newPos, zombieMins, zombieMaxs) then
				spawned = spawned + (self:SpawnZombie(GAMEMODE:GetZombieClassData("zombie"), newPos) and 1 or 0)
			end

			newPos = pos
			newPos.x = newPos.x - x * 20
			newPos.y = newPos.y + i * 20
			if LineBetweenClear(pos, newPos) and self:SpawnPointValid(newPos, zombieMins, zombieMaxs) then
				spawned = spawned + (self:SpawnZombie(GAMEMODE:GetZombieClassData("zombie"), newPos) and 1 or 0)
			end
		end

		-- left and right
		for y=(-i + 1), (i - 1) do
			if spawned >= amount then break end
			newPos = pos
			newPos.x = newPos.x - i * 20 -- (10 - -10)
			newPos.y = newPos.y + y * 20
			if LineBetweenClear(pos, newPos) and self:SpawnPointValid(newPos, zombieMins, zombieMaxs) then
				spawned = spawned + (self:SpawnZombie(GAMEMODE:GetZombieClassData("zombie"), newPos) and 1 or 0)
			end

			newPos = pos
			newPos.x = newPos.x + i * 20
			newPos.y = newPos.y + y * 20
			if LineBetweenClear(pos, newPos) and self:SpawnPointValid(newPos, zombieMins, zombieMaxs) then
				spawned = spawned + (self:SpawnZombie(GAMEMODE:GetZombieClassData("zombie"), newPos) and 1 or 0)
			end
		end
	end

	return spawned
end

function DIRECTOR:Update()
	for _, pl in pairs(player.GetHumans()) do
		pl:UpdateStress(FrameTime())
	end

	self:UpdateBreaks()

	if SpawningAllowed:GetBool() then
		self:UpdateSpawning()
	end
end

function DIRECTOR:UpdateBreaks()
	if not self.TimeBetweenBreaks then
		self.TimeBetweenBreaks = GAMEMODE.TimeLimit / 3
		self.NextBreak = self.TimeBetweenBreaks + CurTime()

		if DebugDirector:GetBool() then
			print(self.TimeBetweenBreaks, self.NextBreak)
		end
	end

	if CurTime() > self.NextBreak then
		self.WanderersEnabled = false
		self.HordeEnabled = false
		self.BossesEnabled = false
		self.IsFinale = false

		self.NextBreak = self.TimeBetweenBreaks + CurTime()

		timer.Simple(Rand(GAMEMODE.BreakTimeMin, GAMEMODE.BreakTimeMax),
			function()
				self:EndBreak()
			end)

		gamemode.Call("SetWaveActive", false)

		return
	end

	-- A minute before a break happens we'll go all out
	if self.NextBreak - CurTime() < 60 and not self.IsFinale then
		self.IsFinale = true
		if DebugDirector:GetBool() then
			print("Finale start")
		end
	end
end

function DIRECTOR:UpdateHorde()
	if self.HordeDelay <= 0 then
		local duration = Rand(GAMEMODE.HordeIntervalMin, GAMEMODE.HordeIntervalMax)
		if self.IsFinale then
			duration = duration / 4
		end
		if DebugDirector:GetBool() then
			local text = Format("Horde will start spawning in %f seconds", duration)
			print(text)
		end
		self.HordeDelay = CurTime() + duration
	end

	if self.HordeDelay < CurTime() then
		if self.ZombieCount < (GAMEMODE.MaxAliveWanderers * 2) then
			local num = Rand(GAMEMODE.HordeSizeMin, GAMEMODE.HordeSizeMax)
			if self:FindHordePosition() then
				self.HordeCount = num
				self.HordeDelay = -1.0
			else
				self.HordeDelay = CurTime() + 10
			end
		else
			self.HordeDelay = CurTime() + 10
		end
	end

	if self.HordeCount > 0 and not self.HordePosition:IsZero() and CurTime() > self.ClusterInterval then
		local toSpawn = math.min(self.HordeCount, GAMEMODE.BatchMaxCount)
		local spawned = self:SpawnZombieCluster(toSpawn, self.HordePosition)
		self.HordeCount = self.HordeCount - spawned

		if self.HordeCount <= 0 then
			self.HordePosition = Vector(0,0,0)
		elseif spawned == 0 then
			if DebugDirector:GetBool() then
				print("Failed to spawn as many zombies as we wanted to, trying a new position")
			end

			if not self:FindHordePosition() then
				self.HordeCount = 0
				self.HordePosition = Vector(0,0,0)
			end
		end

		self.ClusterInterval = CurTime() + 5
	end
end

function DIRECTOR:UpdateWanderers()
	if not self.Spawning then return end

	if CurTime() > self.SpawnDelay then
		if self.TimeBetweenSpawns == 0 then
			self.TimeBetweenSpawns = Rand(GAMEMODE.InitialIntervalMin, GAMEMODE.InitialIntervalMax) / gamemode.Call("GetWave")
		else
			self.TimeBetweenSpawns = math.max(GAMEMODE.IntervalMin, self.TimeBetweenSpawns * GAMEMODE.IntervalScale)
		end

		self.SpawnDelay = CurTime() + self.TimeBetweenSpawns

		if self.ZombieCount < GAMEMODE.MaxAliveWanderers then
			self:SpawnZombieRandomly()
		end
	end
end

function DIRECTOR:UpdateBosses()
	if CurTime() > ( self.NextBossSpawn or 0 ) and self.IsFinale then
		self.NextBossSpawn = CurTime() + Rand(10.0, 15.0)

		if Rand() <= 0.44 then
			local bosses = {}
			for k, class in pairs(GAMEMODE:GetZombieClassTable()) do
				if class.BossZombie then
					table.insert(bosses, class)
				end
			end

			if #bosses == 0 then
				return
			end

			local bossData = table.Random(bosses)
			local boss = ents.Create(bossData.Class)
			if IsValid(boss) then
				-- Bosses always use home spawns
				local spawnPoint = table.Random(self.BaseSpawnPoints)
				boss:SetPos(spawnPoint:GetPos() + Vector(0, 0, 16))
				boss:SetAngles(Vector(0, math.Rand(-1, 1), 0):Angle())
				boss:SetBossType(bossData.BossType)
				boss:Spawn()
				boss:SetModel(bossData.Model)
				boss:SetHealth(bossData.Health)
				boss:SetMaxHealth(boss:Health())
				boss.loco:SetDesiredSpeed(bossData.Speed)

				net.Start("zs_boss_spawned")
					net.WriteString(bossData.Name)
				net.Broadcast()
			end
		end
	end
end

function DIRECTOR:UpdateSpawning()
	self:UpdateDynamicSpawns()

	if #self.DynamicSpawnPoints <= 0 and #self.BaseSpawnPoints <= 0 then
		return
	end

	if self.HordeEnabled then
		TheDirector:UpdateHorde()
	end
	if self.BossesEnabled then
		TheDirector:UpdateBosses()
	end

	if self.IsFinale then self.Spawning = true end

	if not self.Spawning then
		if self.SustainDuration <= 0 then
			if self:GetMaxStress() < 1.0 then
				self.SustainDuration = CurTime() + Rand(GAMEMODE.RelaxedTimeMin, GAMEMODE.RelaxedTimeMax)
			end
		elseif CurTime() > self.SustainDuration then
			self.ReachedPeak = false
			self.Spawning = true
			self.SustainDuration = -1.0
			self.SpawnDelay = -1.0
			self.TimeBetweenSpawns = 0
		end
	else
		if self.ReachedPeak then
			if self.SustainDuration <= 0 then
				self.SustainDuration = CurTime() + Rand(GAMEMODE.PeakTimeMin, GAMEMODE.PeakTimeMax)
			elseif CurTime() > self.SustainDuration then
				self.Spawning = false
				self.SustainDuration = -1.0
			end
		elseif self:GetMaxStress() >= 1.0 then
			self.ReachedPeak = true
		end
	end

	if self.WanderersEnabled then
		TheDirector:UpdateWanderers()
	end
end

local function IgnoreProps(ent)
	if string.StartWith(ent:GetClass(), "prop_") then
		return false
	end
end
function DIRECTOR:UpdateDynamicSpawns()
	if CurTime() > ( self.UpdateDynamicThrottle or 0 ) then
		self.UpdateDynamicThrottle = CurTime() + 1.5

		local areas = {}
		local epicentre = Vector(0,0,0)
		local plys = player.GetHumans()
		if #plys == 1 then
			epicentre = plys[1]:GetPos()
		else
			for _, pl in pairs(plys) do
				if pl:Alive() then
					epicentre = epicentre + pl:GetPos()
				end
			end
			epicentre = epicentre / #plys
		end

		for _, area in pairs(navmesh.GetAllNavAreas()) do
			local closest = area:GetClosestPointOnArea(epicentre)
			if closest:IsDistToBetween(epicentre, GAMEMODE.HordeDistanceMin, GAMEMODE.HordeDistanceMax) then
				-- pick out decently sized areas so we end up with only a few areas
				local size = area:GetSizeX() + area:GetSizeY()
				if size < 200 then
					continue
				end
				-- don't spawn on screen
				local visible = false
				for _, pl in pairs(player.GetHumans()) do
					local tr = {}
					util.TraceLine({
						start = area:GetCenter(),
						endpos = pl:GetPos(),
						filter = pl,
						mask = MASK_SOLID_BRUSHONLY,
						output = tr
					})
					if tr.Fraction == 1 then
						visible = true
					end

					util.TraceLine({
						start = area:GetCenter() + Vector(0,0,64),
						endpos = pl:EyePos(),
						filter = pl,
						mask = MASK_SOLID_BRUSHONLY,
						output = tr
					})
					if tr.Fraction == 1 then
						visible = true
					end
				end

				if visible then
					continue
				end

				table.insert(areas, area)
				if DebugDirector:GetBool() then
					debugoverlay.Cross(area:GetCenter(), 8, 2, { 80, 255, 80 })
					debugoverlay.EntityTextAtPosition(area:GetCenter() + Vector(0,0,4), 1, "Spawn Area")
				end
			end
		end

		table.CopyFromTo(areas, self.DynamicSpawnPoints)

		if DebugDirector:GetBool() then
			PrintTable(self.DynamicSpawnPoints)
		end
	end
end

TheDirector = {}
setmetatable(TheDirector, DIRECTOR)


