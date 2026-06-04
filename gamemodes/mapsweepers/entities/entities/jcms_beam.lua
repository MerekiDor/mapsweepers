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
ENT.PrintName = "Damaging Beam"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Damage = 8

function ENT:Initialize()
	if SERVER then
		self:DrawShadow(false)
		self.DamagedEntities = {}
		self.friendlyFireCutoff = math.huge
	end

	if CLIENT then
		self.BeamColor = Color(255, 200, 0)
		self.BeamColorInner = Color(255, 200, 0)
	end
end

if SERVER then
	function jcms.beam_GetBeamAngles(origin, targetVec, sweepVerticality, sweepDistance)
		local norm = targetVec - origin
		norm:Normalize()
		
		local ang = norm:Angle()
		
		local dAng1 = Angle(ang)
		local dAng2 = Angle(ang)
		local up, right = ang:Up(), ang:Right()
		dAng1:RotateAroundAxis(right, Lerp(sweepVerticality, 0, sweepDistance))
		dAng2:RotateAroundAxis(right, Lerp(sweepVerticality, 0, -sweepDistance))
		dAng1:RotateAroundAxis(up, Lerp(sweepVerticality, sweepDistance, 0))
		dAng2:RotateAroundAxis(up, Lerp(sweepVerticality, -sweepDistance, 0))
		
		return dAng1, dAng2
	end

	function ENT:FireBeam(fromAngle, toAngle, overTime)
		self:SetBeamTime(0)
		self:SetBeamLifeTime(overTime or 1)
		self:SetBeamFromAngle(fromAngle)
		self:SetBeamToAngle(toAngle)
	end

	function ENT:FireBeamSweep(targetVector, sweepVerticality, sweepDistance, overTime)
		self:SetBeamTime(0)
		self:SetBeamLifeTime(overTime or 1)
		
		local dAng1, dAng2 = jcms.beam_GetBeamAngles(self:GetPos(), targetVector, sweepVerticality, sweepDistance)
		
		self:SetBeamFromAngle(dAng1)
		self:SetBeamToAngle(dAng2)
	end

	function ENT:DealBeamDamage()
		local tr = self:GetBeamTrace()
		if IsValid(tr.Entity) and tr.Entity:Health() > 0 and not self.DamagedEntities[tr.Entity] then
			self.DamagedEntities[tr.Entity] = true
			local dmg = DamageInfo()
			dmg:SetDamage(self.Damage)

			local beamAttacker = self:GetBeamAttacker()
			if IsValid(beamAttacker) then
				dmg:SetAttacker(beamAttacker)
				if jcms.team_SameTeam(beamAttacker, tr.Entity) and tr.Entity:GetMaxHealth() > self.friendlyFireCutoff then
					return --No friendly fire
				end
			end
			dmg:SetInflictor(self)
			dmg:SetReportedPosition(self:GetPos())
			dmg:SetDamageType(DMG_ENERGYBEAM)
			tr.Entity:DispatchTraceAttack(dmg, tr)

			EmitSound("ambient/levels/citadel/weapon_disintegrate"..math.random(2, 3)..".wav", tr.HitPos, 0, CHAN_AUTO, 1, 75, 0, 150)

			if tr.Entity:IsPlayer() then
				tr.Entity:ViewPunch( Angle(math.Rand(-2, 2), math.Rand(-2, 2), 0) )
			end
		end
	end

	function ENT:Think()
		local selfTbl = self:GetTable()

		local iv = 1/15
		selfTbl:SetBeamTime(selfTbl:GetBeamTime() + iv)

		if selfTbl:GetBeamTime() >= selfTbl:GetBeamLifeTime() then
			self:Remove()
		else
			selfTbl.DealBeamDamage(self)
		end

		self:NextThink(CurTime() + iv)
		return true 
	end
end

if CLIENT then
	ENT.MatBeam = Material("sprites/physgbeamb.vmt")
	ENT.MatGlow = Material("particle/Particle_Glow_04")

	function ENT:DrawTranslucent()
		local selfTbl = self:GetTable()

		local fraction = math.Clamp(selfTbl:GetBeamTime() / selfTbl:GetBeamLifeTime(), 0, 1)
		if fraction >= 1 then return end
		
		local distToEyes = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())

		render.SetMaterial(selfTbl.MatBeam)
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
		
		local tr = selfTbl.tr or self:GetBeamTrace()
		local distEndToEyes = jcms.EyePos_lowAccuracy:DistToSqr(tr.HitPos)
		local scroll = math.random()
		local startPos = selfTbl.StartPosOverride or tr.StartPos
		local lenfactor = tr.HitPos:Distance(startPos)/64
		local wm = math.max(0,-4*(fraction*fraction)+4*fraction)

		local beamColor = selfTbl.BeamColor
		local innerBeamColor = selfTbl.BeamColorInner
		local bcR, bcG, bcB = beamColor:Unpack()
		innerBeamColor:SetUnpacked(Lerp(wm, bcR, 255), Lerp(wm, bcG, 255), Lerp(wm, bcB, 255), wm*wm*255)

		render.DrawBeam(startPos, tr.HitPos, math.Rand(10, 12)*wm, scroll*lenfactor, (scroll+1)*lenfactor, beamColor)
		if distToEyes < 1500^2 and distEndToEyes < 1500^2 then 
			render.DrawBeam(startPos, tr.HitPos, math.Rand(3, 4)*wm, scroll*lenfactor, (scroll+1)*lenfactor, innerBeamColor)
		end
	
		if distEndToEyes < 2500^2 then 
			render.SetMaterial(selfTbl.MatGlow)
			render.DrawQuadEasy(tr.HitPos, tr.HitNormal, 64*wm, 64*wm, beamColor, fraction*360)
			render.DrawSprite(tr.HitPos, 64*wm, 24*wm, innerBeamColor)
		end
		render.OverrideBlend(false)
	end

		
	function ENT:Think()
		local selfTbl = self:GetTable()

		local tr = selfTbl.GetBeamTrace(self)
		selfTbl.tr = tr

		selfTbl:SetBeamTime(selfTbl:GetBeamTime() + FrameTime())
		self:SetRenderBoundsWS(tr.StartPos, tr.HitPos)

		self:SetNextClientThink(CurTime() + 1/66)
		return true
	end
end


function ENT:GetBeamTrace()
	local selfTbl = self:GetTable()
	local fraction = math.Clamp(selfTbl:GetBeamTime() / selfTbl:GetBeamLifeTime(), 0, 1)
	local normal = LerpAngle(fraction, selfTbl:GetBeamFromAngle(), selfTbl:GetBeamToAngle()):Forward()
	normal:Mul(selfTbl:GetBeamLength()) 

	local selfPos = self:GetPos()
	return util.TraceLine {
		start = selfPos, endpos = selfPos + normal, mask = MASK_SHOT, filter = selfTbl:GetBeamAttacker()
	}
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "BeamTime")
	self:NetworkVar("Float", 1, "BeamLifeTime")
	self:NetworkVar("Float", 2, "BeamLength")
	self:NetworkVar("Angle", 0, "BeamFromAngle")
	self:NetworkVar("Angle", 1, "BeamToAngle")
	self:NetworkVar("Entity", 0, "BeamAttacker")

	if SERVER then
		self:SetBeamLifeTime(1)
	end
end
