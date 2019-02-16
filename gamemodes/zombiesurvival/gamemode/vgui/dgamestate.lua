local PANEL = {}

function PANEL:Init()
	self.m_HumanCount = vgui.Create("DTeamCounter", self)
	self.m_HumanCount:SetTeam(TEAM_HUMAN)
	self.m_HumanCount:SetImage("zombiesurvival/humanhead")

	self.m_ZombieCount = vgui.Create("DTeamCounter", self)
	self.m_ZombieCount:SetTeam(TEAM_UNDEAD)
	self.m_ZombieCount:SetImage("zombiesurvival/zombiehead")

	self.m_Text1 = vgui.Create("DLabel", self)
	self.m_Text2 = vgui.Create("DLabel", self)
	self.m_Text3 = vgui.Create("DLabel", self)
	self:SetTextFont("ZSHUDFontTiny")

	self.m_Text1.Paint = self.Text1Paint
	self.m_Text2.Paint = self.Text2Paint
	self.m_Text3.Paint = self.Text3Paint

	self:InvalidateLayout()
end

function PANEL:SetTextFont(font)
	self.m_Text1.Font = font
	self.m_Text1:SetFont(font)
	self.m_Text2.Font = font
	self.m_Text2:SetFont(font)
	self.m_Text3.Font = font
	self.m_Text3:SetFont(font)

	self:InvalidateLayout()
end

function PANEL:PerformLayout()
	local hs = self:GetTall() * 0.5
	self.m_HumanCount:SetSize(hs, hs)
	self.m_ZombieCount:SetSize(hs, hs)
	self.m_ZombieCount:AlignTop(hs)

	self.m_Text1:SetWide(self:GetWide())
	self.m_Text1:SizeToContentsY()
	self.m_Text1:MoveRightOf(self.m_HumanCount, 12)
	self.m_Text1:AlignTop(4)
	self.m_Text2:SetWide(self:GetWide())
	self.m_Text2:SizeToContentsY()
	self.m_Text2:MoveRightOf(self.m_HumanCount, 12)
	self.m_Text2:CenterVertical()
	self.m_Text3:SetWide(self:GetWide())
	self.m_Text3:SizeToContentsY()
	self.m_Text3:MoveRightOf(self.m_HumanCount, 12)
	self.m_Text3:AlignBottom(4)
end

function PANEL:Text1Paint()
	local text = ""
	local override = MySelf:IsValid() and GetGlobalString("hudoverride" .. MySelf:Team(), "")

	if override and #override > 0 then
		text = override
	else
		if GAMEMODE:GetWave() <= 0 then
			text = translate.Get("prepare_yourself")
		elseif GAMEMODE.ZombieEscape then
			text = translate.Get("zombie_escape")
		else
			if not GAMEMODE:GetWaveActive() then
				text = translate.Get("intermission")
			end
		end
	end

	if text then
		draw.SimpleText(text, self.Font, 0, 0, COLOR_GRAY)
	end

	return true
end

function PANEL:Text2Paint()
	if GAMEMODE:GetWave() <= 0 then
		local col
		local timeleft = math.max(0, GAMEMODE:GetWaveStart() - CurTime())
		if timeleft < 10 then
			local glow = math.sin(RealTime() * 8) * 200 + 255
			col = Color(255, glow, glow)
		else
			col = COLOR_GRAY
		end

		draw.SimpleText(translate.Format("zombie_invasion_in_x", util.ToMinutesSeconds(timeleft)), self.Font, 0, 0, col)
	end

	return true
end

function PANEL:Text3Paint()
	if MySelf:IsValid() then
		draw.SimpleText(translate.Format("points_x", MySelf:GetPoints().." / "..MySelf:Frags()), self.Font, 0, 0, COLOR_DARKRED)
	end

	return true
end

function PANEL:Paint()
	return true
end

vgui.Register("DGameState", PANEL, "DPanel")
