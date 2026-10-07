--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025-2026 MerekiDor

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

	See the full GNU GPL v3 in the LICENSE file.
	Contact E-Mail: merekidorian@gmail.com
--]]
AddCSLuaFile()

ENT.Type = "ai"
ENT.Base = "base_anim"
ENT.PrintName = "Gas Cloud"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "GasColour")
	self:NetworkVar("Int", 0, "GasRadius")
	self:NetworkVar("String", 0, "ExtraParticles")

	if SERVER then
		self:SetGasRadius(200)
	end
end

if SERVER then
	ENT.GasPower = 15
	ENT.GasDamageType = bit.bor(DMG_NERVEGAS, DMG_NEVERGIB)
	ENT.GasInterval = 0.33

	jcms.gascloud_funcs = {
		["damage"] = function(self, entsInRad)
			local dmg = DamageInfo()
			dmg:SetReportedPosition(self:GetPos())
			dmg:SetDamageType(self.GasDamageType)
			dmg:SetDamageForce(jcms.vectorOrigin)
			dmg:SetInflictor(self)
			if IsValid(self.jcms_owner) then
				dmg:SetAttacker(self.jcms_owner)
			else
				dmg:SetAttacker(self)
			end

			local attacker = dmg:GetAttacker()
			for i, ent in ipairs(entsInRad) do
				if ent == self or not IsValid(ent) then continue end
				if ent:Health() > 0 and ( ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() ) then
					dmg:SetDamagePosition(ent:WorldSpaceCenter())
					
					if jcms.team_SameTeam(ent, attacker) then
						dmg:SetDamage(self.GasPower * 0.2)
					else
						dmg:SetDamage(self.GasPower)
					end

					ent:TakeDamageInfo(dmg)
				end
			end
		end,

		["heal"] = function(self, entsInRad)
			for i, ent in ipairs(entsInRad) do
				if ent == self or not IsValid(ent) then continue end
				if ent:IsPlayer() and ent:Alive() and jcms.team_JCorp_player_valid(ent) then
					local hp, hpMax = ent:Health(), ent:GetMaxHealth()

					if hp < hpMax then
						ent:SetHealth( math.Clamp(hp + self.GasPower, 0, hpMax) )
					end
				end
			end
		end,

		["bubblemantle"] = function(self, entsInRad)
			for i, ent in ipairs(entsInRad) do
				if ent == self or not IsValid(ent) then continue end
				if jcms.team_JCorp(ent) then
					jcms.AddBubbleMantle(ent, 1, 3)
				end
			end
		end
	}

	function ENT:Initialize()
		self:SetNoDraw(true)
		self:DrawShadow(false)
		self.DeathTime = CurTime() + 10
	end

	function ENT:Think()
		if self.DeathTime and CurTime() > self.DeathTime then
			self:Remove()
		end

		local targets = ents.FindInSphere( self:GetPos(), self:GetGasRadius() )
		local gasFunc = self.GasFunc or jcms.gascloud_funcs[ self.GasFuncName ]
		if type(gasFunc) == "function" then
			gasFunc(self, targets)
		end

		self:NextThink( CurTime() + self.GasInterval )
		return true
	end
end

if CLIENT then 
	local function gasParticleThinkFunc(p)
		local alpha = 32*math.sin(p:GetLifeTime() / p:GetDieTime() * math.pi)
		p:SetStartAlpha(alpha)
		p:SetEndAlpha(alpha)
		p:SetNextThink(CurTime() + 0.03)
	end

	local function gasExtraParticleThinkFunc(p)
		local frac = math.sin(p:GetLifeTime() / p:GetDieTime() * math.pi)
		local alpha = 180 * frac
		local size = 4 + frac*2
		p:SetStartAlpha(alpha)
		p:SetEndAlpha(alpha)
		p:SetStartSize(size)
		p:SetEndSize(size)
		p:SetNextThink(CurTime() + 0.03)
	end

	function ENT:Initialize()
		self:SetNoDraw(true)
		self:DrawShadow(false)
		self.ticksSoFar = 0
	end

	function ENT:GetPosAround(pos, radius)
		local pos_p = Vector(pos)
		local a = math.random()*math.pi*2
		local r = math.sqrt( math.random() ) * radius
		pos_p:SetUnpacked( pos.x + math.sin(a)*r, pos.y + math.cos(a)*r, pos.z + 32 )
		return pos_p
	end

	function ENT:Think()
		if FrameTime() <= 0 then return end

		local selfTbl = self:GetTable()
		local pos = self:GetPos()
		if not selfTbl.emitter then
			selfTbl.emitter = ParticleEmitter(pos)
		end

		local eyeDist = jcms.EyePos_lowAccuracy:DistToSqr(pos)

		local dist2_lod1 = 750^2 -- Closer than this is best quality 
		local dist2_lod2 = 3000^2 -- Farther than this is invisible
		local lodFrac = math.Clamp(math.Remap(eyeDist, dist2_lod1, dist2_lod2, 0, 1), 0, 1)

		if lodFrac >= 1 then return end

		local colourVector = self:GetGasColour()
		colourVector:Mul(255)
		
		local radius = self:GetGasRadius()
		local radiusSqrt = math.sqrt(radius)

		local extraParticlesName = self:GetExtraParticles()
		if selfTbl._extraParticlesName ~= extraParticlesName then
			selfTbl._extraParticlesName = extraParticlesName
			selfTbl._extraParticlesMat = Material(extraParticlesName)
		end
		
		selfTbl.ticksSoFar = (selfTbl.ticksSoFar or 0) + 1
		local doFromOrigin = selfTbl.ticksSoFar <= 5

		for i=1, (lodFrac > 0.5 and 2 or 3) do
			local pos_p = self:GetPosAround(pos, radius)
			local p = self.emitter:Add("particle/smokesprites_000" .. math.random(1, 5), doFromOrigin and pos or pos_p)
			if p then
				if doFromOrigin then
					pos_p:Sub(pos)
					pos_p:Div(2.5)
					p:SetVelocity(pos_p)
				else
					p:SetVelocity(Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-radiusSqrt, radiusSqrt)*3))
				end
				p:SetAirResistance(math.random()*10)

				if doFromOrigin then
					p:SetStartSize(0)
				else
					p:SetStartSize(radius/3)
				end
				p:SetEndSize(radius/2)

				p:SetStartAlpha(0)
				p:SetEndAlpha(0)

				p:SetRoll(math.random()*360)
				p:SetRollDelta(math.random()*2 - 1)

				p:SetDieTime(2)
				p:SetColor(colourVector:Unpack())

				p:SetThinkFunction(gasParticleThinkFunc)
				p:SetNextThink(CurTime())
			end

			if i == 3 and selfTbl._extraParticlesMat then
				local pos_pe = self:GetPosAround(pos, radius)
				local pe = self.emitter:Add(selfTbl._extraParticlesMat, doFromOrigin and pos or pos_pe)
				if pe then
					pe:SetVelocity(VectorRand(-20, 20))
					pe:SetAirResistance(math.random()*10)

					pe:SetThinkFunction(gasExtraParticleThinkFunc)
					pe:SetNextThink(CurTime())

					pe:SetRoll(math.Rand(-0.05, 0.05))
					pe:SetRollDelta(math.Rand(-0.1, 0.1))
					
					pe:SetDieTime(2)
					pe:SetColor(colourVector:Unpack())
				end
			end
		end

		self:SetNextClientThink(CurTime() + (0.2 + lodFrac*0.3))
	end
end