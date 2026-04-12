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
ENT.PrintName = "Radiation Sphere"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.Damage = 2

hook.Add("MapSweepers_MapAnalysisDone", "jcms_RadSphere_CalcSize", function()
	local areaMult, volMult, densityMult, avgSizeMult = jcms.mapgen_GetMapSizeMultiplier()
	local sizeMult = math.min(areaMult, volMult)
	local densityMult = avgSizeMult / densityMult

	jcms.radSphereSize = 2500 * sizeMult * densityMult
end)

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "CloudRange")

	if SERVER then 
		self:SetCloudRange(jcms.radSphereSize)
	end
end

if SERVER then 
	function ENT:Initialize()
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Think()
		local selfPos = self:WorldSpaceCenter()

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamageType( bit.bor(DMG_GENERIC, DMG_DIRECT, DMG_RADIATION) )
		dmg:SetDamage(self.Damage)

		local cloudRange = self:GetCloudRange() 
		for i, ent in ipairs(ents.FindInSphere(selfPos , cloudRange)) do
			if ent:IsPlayer() and ent:GetObserverMode() == OBS_MODE_NONE and ent:Team() == 1 and ent:Alive() then
				local entPos = ent:GetPos()
				--local dist = selfPos:Distance(entPos)
				--dmg:SetDamage( math.ceil(Lerp( dist/cloudRange , 10, 1)) )

				dmg:SetDamagePosition(entPos)
				dmg:SetReportedPosition(entPos)
				ent:TakeDamageInfo(dmg)
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

if CLIENT then 
	ENT.mat_trail = Material "materials/trails/laser.vmt"
	ENT.mat_glow = Material "particle/Particle_Glow_04"
	ENT.distanceToEyes = 500

	function ENT:Initialize()
		local range = self:GetCloudRange() + self.distanceToEyes * 2
		self:SetRenderBounds( jcms.vectorOrigin, jcms.vectorOrigin, Vector(range/2, range/2, range/2) )
	end

	function ENT:DrawTranslucent()
		self:ThinkEmbers()
		self:DrawEmbers()
		--self:DrawStaticOverlay()
	end

	function ENT:ThinkEmbers()
		if not self.embers then
			self.embers = {}

			for i=1, 64 do
				self.embers[i] = {}
			end
		end

		local dt = FrameTime()

		if dt <= 0 then
			return
		end

		local ep = EyePos()
		local origin = self:GetPos()
		local distToEyes = ep:Distance(origin)
		local range = self:GetCloudRange()

		local noNewEmbers = false
		if distToEyes > range + self.distanceToEyes * 4 then
			noNewEmbers = true
		else
			origin = ep - origin
			origin:Normalize()
			origin:Mul( math.min(distToEyes, range - self.distanceToEyes/2) )
			origin:Add(self:GetPos())
			range = self.distanceToEyes
		end

		for i, ember in ipairs(self.embers) do
			if not ember.inited then
				if not noNewEmbers then
					ember.inited = true
					ember.t = 0
					ember.tout = 0.2 + math.random() * 2.8
					ember.scale = 0.1 + math.random()

					if ember.pos then
						ember.pos.x = math.random()*2 - 1
						ember.pos.y = math.random()*2 - 1
						ember.pos.z = math.random()*2 - 1
					else
						ember.pos = VectorRand()
					end
					ember.pos:Normalize()
					ember.pos:Mul( (math.random() ^ 0.5) * range )
					ember.pos:Add(origin)

					if ember.vel then
						local vel = math.random() * 200 + 32
						ember.vel.x = math.random()*vel - vel/2
						ember.vel.y = math.random()*vel - vel/2
						ember.vel.z = math.random()*vel - vel/2
					else
						ember.vel = VectorRand(-128, 128)
					end

					ember.oldpos = ember.pos - ember.vel
				end
			end

			if ember.t then
				if ember.t > ember.tout then
					ember.inited = false
				else
					ember.oldpos:SetUnpacked( ember.pos:Unpack() )

					local vx, vy, vz = ember.vel:Unpack()
					ember.vel:Mul(dt)
					ember.pos:Add(ember.vel)
					ember.vel:Mul(10 * ember.scale)
					ember.oldpos:Sub(ember.vel)
					ember.vel:SetUnpacked(vx + math.Rand(-64, 64)*dt, vy + math.Rand(-64, 64)*dt, vz + math.Rand(-64, 64)*dt)
					ember.t = ember.t + dt
				end
			end
		end
	end

	function ENT:DrawEmbers()
		render.SetMaterial(self.mat_glow)
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
		for i, ember in ipairs(self.embers) do
			if ember.inited then
				local f = ember.t / ember.tout
				local parabolic = math.max(0,-4*(f*f)+4*f)
				local col = Color(128*parabolic, 255, 100*parabolic, parabolic*100)
				local sc = ember.scale
				render.DrawBeam(ember.pos, ember.oldpos, 8*sc*parabolic, 0.5, 1, col)

				col.a = parabolic * 255
				col.r = col.r + 24
				col.b = col.b + 24
				render.DrawSprite(ember.pos, 12*sc*parabolic, 8*sc*parabolic, col)
			end
		end

		cam.Start2D()
			local frac = math.sqrt(1 - EyePos():Distance( self:GetPos() ) / self:GetCloudRange())

			if frac > 0 then
				surface.SetMaterial(jcms.mat_noise)
				surface.SetDrawColor(128, 255, 128, frac * 256)
				jcms.hud_DrawNoiseRect(0, 0, ScrW(), ScrH())
			end
		cam.End2D()

		render.OverrideBlend(false)
	end

	--[[
	--This has been sitting un-committed on my end for a few weeks. I'm still not sure whether it's a good idea, but I have to
	--commit other stuff from this file, so I'm leaving it here commented.
	--Its purpose was to make radiation zones more obvious. It doesn't look great, but does achieve that. 

	function ENT:DrawStaticOverlay()
		render.SetStencilEnable(true)
		render.ClearStencil()
		render.SetStencilTestMask(255)
		render.SetStencilWriteMask(255)

		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilReferenceValue(1)
		
		render.OverrideBlend(true, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)

		local range = self:GetCloudRange()
		if EyePos():DistToSqr(self:GetPos()) > range^2 then 
			render.SetColorMaterial()
			render.DrawSphere(self:GetPos(), self:GetCloudRange(), 22, 22, color_white)
			
			render.SetStencilReferenceValue(0)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.DrawSphere(self:GetPos(), -self:GetCloudRange(), 22, 22, color_white)
		else
			render.ClearStencilBufferRectangle( 0,0, ScrW(), ScrH(), 1 )

			render.SetStencilReferenceValue(0)
			render.SetStencilPassOperation(STENCIL_REPLACE)

			render.SetColorMaterial()
			render.DrawSphere(self:GetPos(), -self:GetCloudRange(), 22, 22, color_white)
		end
		
		render.OverrideBlend(false)
		
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilReferenceValue(1)

		render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
			cam.Start2D()
				surface.SetMaterial(self.mat_noise)
				surface.SetDrawColor(75, 150, 75, 32)
				jcms.hud_DrawNoiseRect(0, 0, ScrW(), ScrH())
			cam.End2D()
		render.OverrideBlend(false)
		
		render.SetStencilEnable( false )
		render.ClearStencil()
	end
	--]]

	function ENT:Think()
		if math.random() < 0.1 then
			local me = LocalPlayer()
			if IsValid(me) and ( me:Alive() or IsValid(me:GetObserverTarget()) ) then
				local distToEyes = self:GetPos():Distance( EyePos() )
				local range = self:GetCloudRange()

				if distToEyes <= range then
					me:EmitSound("player/geiger" .. math.random(1, 3) .. ".wav")
				end
			end
		end

		self:SetNextClientThink(CurTime() + 1/66)
		return true
	end
end