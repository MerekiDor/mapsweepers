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
			elseif ent:GetClass() == "jcms_shieldcharger" then
				ent:SetHealth(ent:Health() - 1)
				ent:SetHealthFraction(math.Clamp(ent:Health() / ent:GetMaxHealth(), 0, 1))
				
				--TODO: These are probably a decent bit of unnecessary network strain, would be better to let the shieldcharger itself handle it clientside

				--Shield-break
				local ed = EffectData()
				ed:SetEntity(ent)
				ed:SetFlags(1)
				ed:SetColor(jcms.util_ColorIntegerFast(0, 225, 0))
				util.Effect("jcms_shieldeffect", ed)
				
				--Arcs
				local ed = EffectData()
				ed:SetEntity(ent)
				ed:SetScale(1)
				ed:SetMagnitude(9)
				ed:SetColor( jcms.util_ColorIntegerFast(0, 255, 0) )
				ed:SetMaterialIndex(1)
				util.Effect("jcms_electricarcs", ed)
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

if CLIENT then 
	jcms.radSphere_matGlow = Material "particle/Particle_Glow_04"
	ENT.distanceToEyes = 500


	function ENT:Initialize()
		local range = self:GetCloudRange() + self.distanceToEyes * 2
		self:SetRenderBounds( jcms.vectorOrigin, jcms.vectorOrigin, Vector(range/2, range/2, range/2) )
		self:SetNoDraw(true)
		self:DrawShadow(false)

		--Radspheres exist, set up the render hook
		hook.Add("PostDrawTranslucentRenderables", "jcms_radSpheres", jcms.radSphere_Draw)
	end

	function ENT:OnRemove()
		if #ents.FindByClass("jcms_radSphere") <= 1 then
			--We're the last one, remove the hook to save perf.
			hook.Remove("PostDrawTranslucentRenderables", "jcms_radSpheres")
		end
	end

	-- // Embers {{{
		jcms.radSphere_embers = {}
		for i=1, 64 do
			local ember = {}
			ember.inited = false
			ember.pos = Vector()
			ember.oldpos = Vector()
			ember.vel = Vector()

			ember.t = 0
			ember.tout = 0
			ember.scale = 0
			ember.scale = 0

			jcms.radSphere_embers[i] = ember
		end

		function jcms.radSphere_ThinkEmbers(radSpheres)
			local dt = FrameTime()
			if dt <= 0 then	return end

			local ep = jcms.EyePos_lowAccuracy

			-- // Prioritise closer spheres for spawns {{{
				local eyeDists = {}
				for i, sphere in ipairs(radSpheres) do 
					eyeDists[sphere] = ep:Distance(sphere:GetPos())
				end

				table.sort( radSpheres, function(a, b) 
					return eyeDists[a] < eyeDists[b]
				end)
			-- // }}}

			for i, radSphere in ipairs(radSpheres) do --Create new embers
				local spherePos = radSphere:GetPos()
				local range = radSphere:GetCloudRange()
				local distToEyes = eyeDists[radSphere]

				local origin = spherePos

				--Stop creating new embers if we're >2000u from the sphere
				local noNewEmbers = false
				if distToEyes > range + radSphere.distanceToEyes * 4 then
					noNewEmbers = true
				else
					--Dir from origin to eyepos
					origin = ep - spherePos
					origin:Normalize()

					--Set origin to be at eyes if within range, 250u inside the sphere otherwise.
					origin:Mul( math.min(distToEyes, range - radSphere.distanceToEyes/2) )
					origin:Add(spherePos)
					range = radSphere.distanceToEyes --Set range to be our eye dist offset (Why? This is needlessly confusing and functionally no different to making a separate local
				end

				--Initialise new embers if we're close enough
				for i, ember in ipairs(jcms.radSphere_embers) do 
					if not noNewEmbers and not ember.inited then 
						--Time and scale
						ember.inited = true
						ember.t = 0
						ember.tout = 0.2 + math.random() * 2.8
						ember.scale = 0.1 + math.random()

						--Random start pos
						ember.pos:SetUnpacked(math.random()*2 - 1, math.random()*2 - 1, math.random()*2 - 1)
						
						ember.pos:Normalize()
						ember.pos:Mul( (math.random() ^ 0.5) * range )
						ember.pos:Add(origin)

						--Random start velocity
						local vel = math.random() * 200 + 32
						ember.vel:SetUnpacked(math.random()*vel - vel/2, math.random()*vel - vel/2, math.random()*vel - vel/2)
						
						--Set up initial trail
						ember.oldpos = ember.pos - ember.vel
					end
				end
			end

			for i, ember in ipairs(jcms.radSphere_embers) do
				if not ember.inited then continue end
				
				if ember.t > ember.tout then	--Die
					ember.inited = false
				else
					ember.oldpos:Set( ember.pos )

					--Advance us by velocity
					local vx, vy, vz = ember.vel:Unpack()
					ember.vel:Mul(dt)
					ember.pos:Add(ember.vel)
					
					--Set "oldPos" (presumably used for the trail) to be behind us 10x the distance we moved.
					ember.vel:Mul(10 * ember.scale)
					ember.oldpos:Sub(ember.vel / (dt * 10))

					--Set our new velocity to our old + random acceleration
					ember.vel:SetUnpacked(vx + math.Rand(-64, 64)*dt, vy + math.Rand(-64, 64)*dt, vz + math.Rand(-64, 64)*dt)
					ember.t = ember.t + dt
				end
			end
		end

		function jcms.radSphere_DrawEmbers()
			local col = Color(0,255,0,0) --Optimisation, re-use the col object

			render.SetMaterial(jcms.radSphere_matGlow)
			for i, ember in ipairs(jcms.radSphere_embers) do
				if not ember.inited then continue end

				--Progress
				local f = ember.t / ember.tout
				local parabolic = math.max(0,-4*(f*f)+4*f)	

				-- // Trail col/draw {{{
					--Surprisingly this is actually CHEAPER than using :SetUnpacked, because Color's :SetUnpacked is defined in lua and just does this but with extra branches for error checking
					col.r = 128*parabolic
					--col.g = 255
					col.b = 100*parabolic
					col.a = 100*parabolic
				-- // }}}

				local sc = ember.scale
				render.DrawBeam(ember.pos, ember.oldpos, 8*sc*parabolic, 0.5, 1, col)

				-- // Sprite col/draw {{{
					--Surprisingly this is actually CHEAPER than using :SetUnpacked, because Color's :SetUnpacked is defined in lua and just does this but with extra branches for error checking
					col.r = col.r + 24
					--col.g = 255
					col.b = col.b + 25
					col.a = 255*parabolic

					render.DrawSprite(ember.pos, 12*sc*parabolic, 8*sc*parabolic, col)
				-- // }}}
			end
		end
		
		--MAIN RENDER HOOK FOR PostDrawTranslucent. Adding/removing this hook is managed by the entity's Init/OnRemove so that it isn't wasting perf when none are present.
		function jcms.radSphere_Draw()
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				local radSpheres = ents.FindByClass("jcms_radSphere")
				local ep = jcms.EyePos_lowAccuracy

				jcms.radSphere_ThinkEmbers(radSpheres) --TODO: Experiment with moving this out of draw / running it much less often.
				jcms.radSphere_DrawEmbers()
				
				--Static Overlay
				local frac = 0
				for i, radSphere in ipairs(radSpheres) do
					frac = frac + math.sqrt( math.max(1 - (ep:Distance( radSphere:GetPos() ) / radSphere:GetCloudRange()), 0))
				end

				if frac > 0 then
					cam.Start2D()
						surface.SetMaterial(jcms.mat_noise)
						surface.SetDrawColor(128, 255, 128, frac * 256)
						jcms.hud_DrawNoiseRect(0, 0, ScrW(), ScrH())
					cam.End2D()
				end
			render.OverrideBlend(false)
		end
	-- // }}}

	function ENT:Think()
		if math.random() < 0.1 then
			local me = jcms.locPly
			if IsValid(me) and ( me:Alive() or IsValid(me:GetObserverTarget()) ) then
				local distToEyes = self:GetPos():DistToSqr(jcms.EyePos_lowAccuracy)
				local range = self:GetCloudRange()

				if distToEyes <= range^2 then
					me:EmitSound("player/geiger" .. math.random(1, 3) .. ".wav")
				end
			end
		end

		self:SetNextClientThink(CurTime() + 1/66)
		return true
	end
end