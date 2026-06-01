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

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
 
ENT.Speed = 300
ENT.IsNPCTeam = false
ENT.IsIdleUntilActive = false

if SERVER then 
	function ENT:Initialize()
		self:DrawShadow(false)

		self.beamTime = 0
		self.beamRadius = 32
		self.beamVelocity = Vector(0,0,0)
		self.beamMultipliedVelocity = Vector(0,0,0)
		self.beamLifeTime = 15
		self.beamPrepTime = 2
		
		--The beam itself.
		local dRay = ents.Create("jcms_deathray")
		self.deathRay = dRay
		dRay:SetBeamIsSky(true)
		
		dRay:SetPos(self:GetPos())
		dRay:SetParent(self)
		dRay:Spawn()

		self.nextSlowThink = CurTime()

		local pos = self:GetBeamTrace().HitPos
		EmitSound("buttons/blip2.wav", pos, 0, CHAN_AUTO, 1, 75, 0, 110)
		timer.Simple(0.125, function()
			EmitSound("buttons/button17.wav", pos, 0, CHAN_AUTO, 1, 75, 0, 85)
		end)
	end

	function ENT:BeamMoveTo(v, target) --target is optional/potentially null.
		local speed = self.Speed
		local dmgrad = self.beamRadius

		if IsValid(target) then 
			if IsValid(self.jcms_owner) and not jcms.team_pvpSameTeam(self.jcms_owner, target) then
				speed = speed * 0.75
			end
		end

		local selfPos = self:GetPos()
		selfPos.z = v.z --ignore Z

		v:Sub(selfPos)
		local len = v:Length()
		v:Div(len)
		
		if len < dmgrad then
			v:Mul(math.min(len, dmgrad))
		else
			v:Mul(speed)
		end

		self.beamVelocity = v
		self.deathRay:SetBeamVelocity(v)
	end

	function ENT:DistanceToTrace(v, tr)
		tr = tr or self:GetBeamTrace()
		return math.Distance(v.x, v.y, tr.HitPos.x, tr.HitPos.y)
	end
	
	function ENT:DistanceSqrToTrace(v, tr)
		tr = tr or self:GetBeamTrace()
		return math.DistanceSqr(v.x, v.y, tr.HitPos.x, tr.HitPos.y)
	end
	
	function ENT:CalcTargetPriority(target, tr)
		-- The beam chases the entity with highest priority
		if jcms.team_GoodTarget(target) then
			local priority
			local tgpos = target:WorldSpaceCenter()
			if jcms.team_JCorp(target) then
				if not(self.IsNPCTeam and target:IsPlayer()) and (not IsValid(self.jcms_owner) or jcms.team_pvpSameTeam(self.jcms_owner, target)) then
					priority = math.min(target:GetMaxHealth(), target:Health()) - self:DistanceSqrToTrace(tgpos, tr)^(2/3) - 10000000
				else
					--Basically roughly treat enemy players like a 1500hp target
					priority = 1500^2 - self:DistanceSqrToTrace(tgpos, tr)/2
				end
			else
				priority = (2 * math.max(target:GetMaxHealth() - 15, 10)) - self:DistanceSqrToTrace(tgpos, tr)^(2/3)
			end
			
			--TODO: This trace is probably really expensive given how often this runs.
			local beampos = self:GetPos()
			beampos.x = tgpos.x
			beampos.y = tgpos.y
			
			local skytr = util.TraceLine {
				start = beampos,
				endpos = tgpos,
				mask = MASK_VISIBLE,
				filter = target
			}
			
			if skytr.Fraction < 1 then
				priority = (priority < 0 and priority or priority/2) - 10000000
			end
			
			return priority
		end
	end


	function ENT:SeekTargets(tr)
		tr = tr or self:GetBeamTrace()
		local bestPriority, bestTarget
		
		local function iterateEnts(entList) 
			for i, ent in ipairs(entList) do 
				if ent ~= self then
					local priority = self:CalcTargetPriority(ent, tr)
					
					if (priority) and (not bestPriority or priority > bestPriority) then
						bestPriority = priority
						bestTarget = ent
					end
				end
			end
		end

		--More optimised this way, avoids checking things like ai nodes.
		iterateEnts(ents.FindByClass("jcms_*"))
		iterateEnts(ents.FindByClass("npc_*"))
		iterateEnts(player.GetAll())
		
		if IsValid(bestTarget) then
			self:BeamMoveTo( bestTarget:WorldSpaceCenter(), bestTarget )
		end
	end
	
	function ENT:Think()
		local selfTbl = self:GetTable()
		if not IsValid(selfTbl.deathRay) then self:Remove() return end
		
		local selfPos = self:GetPos() 
		local sky = jcms.util_GetSky( selfPos )
		if sky then
			sky.z = sky.z - 100
			selfPos = sky --Optimisation
			self:SetPos(sky)
		end

		local iv = 1/66
		selfTbl.beamTime = selfTbl.beamTime + iv
		
		if selfTbl.beamTime <= selfTbl.beamLifeTime + selfTbl.beamPrepTime then
			if not(self.IsIdleUntilActive and selfTbl.beamTime < selfTbl.beamPrepTime) then
				selfTbl.SlowThink(self)

				local x,y,z = selfTbl.beamVelocity:Unpack()
				selfTbl.beamMultipliedVelocity:SetUnpacked( x*iv, y*iv, z*iv )
				selfTbl.beamMultipliedVelocity:Add(selfPos)

				self:SetPos(selfTbl.beamMultipliedVelocity)
			end
		else
			self:Remove()
		end
		
		self:NextThink(CurTime() + iv)
		return true 
	end

	function ENT:SlowThink()
		local selfTbl = self:GetTable()
		if selfTbl.nextSlowThink > CurTime() then return end

		local tr = self:GetBeamTrace()
		self:SeekTargets(tr)

		selfTbl.nextSlowThink = CurTime() + 1/2 
	end

	function ENT:GetBeamTrace()
		local skypos = jcms.util_GetSky(self:GetPos())

		if skypos then
			return util.TraceLine {
				start = skypos, endpos = self:GetPos() + Vector(0, 0, -32000), mask = MASK_VISIBLE
			}
		else
			return util.TraceLine {
				start = self:GetPos() + Vector(0, 0, 32000), endpos = self:GetPos() + Vector(0, 0, -32000), mask = MASK_VISIBLE
			}
		end
	end
end

if CLIENT then 
	function ENT:DrawTranslucent()
		--Hides us.
	end
end

