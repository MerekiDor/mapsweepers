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
ENT.PrintName = "Flashpoint"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/jcms/jcorp_flashpoint.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)

		self.chargeThinkInterval = (math.random(20, 35) * 60)/100 --will auto charge itself in 30-45 mins as a fallback
		self.nextSlowThink = CurTime() + 10 * 60 --Only start charging 10m in, avoids confusing people
	end
	
	if CLIENT then
		self.bladesOpen = 0
		self.rotatorAngle = 0
		self.chargeFraction = 0
		
		self:SetRenderBounds( self:GetRenderBounds() ) --Thank you Rubat very cool
		self.boneIdRotator = self:LookupBone("rotator")
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Charge")
	self:NetworkVar("Int", 1, "MaxCharge")
	self:NetworkVar("Bool", 0, "IsComplete")

	if SERVER then
		self:SetCharge(0)
		self:SetMaxCharge(2000)
	end
end

if SERVER then
	ENT.Radius = 2200

	function ENT:ReleaseMoreNPCs()
		if not jcms.director.faction then return end

		local function getNPCType()
			local weights = {}
			local hasEpisodes = jcms.HasEpisodes()
			
			for npctype, data in pairs(jcms.npc_types) do
				if data.portalSpawnWeight and (data.faction == "everyone" or data.faction == jcms.director.faction) and (not data.episodes or hasEpisodes) then
					weights[npctype] = data.portalSpawnWeight
				end
			end

			local randomtype = jcms.util_ChooseByWeight(weights)
			return randomtype or "antlion_drone"
		end

		jcms.npc_PortalReleaseXNPCs(self, 5, self:GetPos() + Vector(0,0,270), jcms.director.faction, getNPCType)
	end

	function ENT:ChargeFlashpoint(npc, attacker)
		local addedCharge = math.ceil(npc.jcms_bounty or 0)
		if npc.jcms_danger == jcms.NPC_DANGER_RAREBOSS then 
			addedCharge = 0
		end

		if addedCharge > 0 then
			local mult = 1 / (jcms.util_IsPVP() and jcms.util_GetLargestPvpTeamCount() or #team.GetPlayers(1) )^(2/3) 
			addedCharge = math.ceil( addedCharge * mult )
			self:SetCharge( math.min(self:GetCharge() + addedCharge, self:GetMaxCharge()) )

			local ed = EffectData()
			ed:SetFlags(1)
			ed:SetOrigin(npc:WorldSpaceCenter())
			ed:SetEntity(self)
			util.Effect("jcms_chargebeam", ed)

			self.lastChargeTime = CurTime()

			if self:GetCharge() >= self:GetMaxCharge() and not self:GetIsComplete() then
				self:ReleaseBoss()
				jcms.director_PvpObjectiveCompleted(attacker, self:GetPos())
			end
		end
	end

	function ENT:ReleaseBoss()
		self:SetIsComplete(true)
		self:EmitSound("npc/combine_gunship/gunship_pain.wav", 150, 75, 1)
		self:EmitSound("ambient/levels/citadel/portal_beam_shoot6.wav", 150, 100, 1)
		util.ScreenShake(self:WorldSpaceCenter(), 500, 25, 3, 500, true)

		local validTypes = {} 
		for npcType, data in pairs(jcms.npc_types) do
			if (not hasEpisodes and data.episodes) then continue end
			
			if (data.faction == "everyone" or data.faction == self.faction) and (not data.check or data.check()) then
				validTypes[ npcType ] = data.swarmWeight or 1
			end
		end

		local shuffled = jcms.util_GetShuffledByWeight(validTypes) --Get bosses
		local boss
		for j, spawnType in ipairs(shuffled) do
			local data = jcms.npc_types[ spawnType ]

			if data.danger == jcms.NPC_DANGER_RAREBOSS then
				boss = spawnType
				break
			end
		end

		if boss then
			jcms.npc_PortalReleaseXNPCs(self, 1, self:GetPos() + Vector(0,0,300), self.faction, boss, function(ent, npc)
				jcms.npc_SetupDecayingShield(npc, npc:GetMaxHealth(), 60, jcms.factions_GetColorInteger(self.faction)) --TODO: Diff colour
			end)
		end

		--Can't fucking think of an easy/good one for zombies so we're just gonna have them horde super hard yay!!!!
		if jcms.director.commander and jcms.director.commander.flashpointSummon then 
			jcms.director.commander:flashpointSummon(self, boss)
		end
	end

	function ENT:SlowThink()
		if self.nextSlowThink and (CurTime() < self.nextSlowThink) then
			return
		end

		self:SetCharge( math.min(self:GetCharge() + math.ceil(self:GetMaxCharge()/100), self:GetMaxCharge()) )

		self.nextSlowThink = CurTime() + self.chargeThinkInterval
	end

	function ENT:Think()
		self:SlowThink()

		if self:GetCharge() >= self:GetMaxCharge() then
			if not self:GetIsComplete() then
				self:ReleaseBoss()
			end
		elseif jcms.director then
			if (self.lastChargeTime and (CurTime() - self.lastChargeTime > 45)) or (self.lastChargeTime == nil and (jcms.director_GetMissionTime() > 120)) then
				local flashpointPos = self:WorldSpaceCenter()
				local shouldDeploy = false

				for i, swp in ipairs(jcms.GetAliveSweepers()) do
					if swp:WorldSpaceCenter():DistToSqr( flashpointPos ) < 2000^2 then
						shouldDeploy = true
						break
					end
				end

				if shouldDeploy then
					self.lastChargeTime = CurTime() + 5
					self:ReleaseMoreNPCs()
				end
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	hook.Add("MapSweepersDeathNPC", "jcms_FlashpointKill", function(ply_or_npc, attacker, inflictor, isPlayerNPC)
		if jcms.director and jcms.team_JCorp(attacker) then
			local npcpos = ply_or_npc:WorldSpaceCenter()

			local closest, mindist2
			for i, flashpoint in ipairs( ents.FindByClass("jcms_flashpoint") ) do
				if not flashpoint:GetIsComplete() then
					local dist2 = flashpoint:WorldSpaceCenter():DistToSqr(npcpos)

					if not closest or dist2 < mindist2 then
						closest = flashpoint
						mindist2 = dist2
					end
				end
			end

			if IsValid(closest) and mindist2 <= closest.Radius^2 then
				closest:ChargeFlashpoint(ply_or_npc, attacker)
			end
		end
	end)
end

if CLIENT then
	ENT.mat_beam = Material "sprites/physgbeamb.vmt"
	ENT.mat_glow = Material "particle/Particle_Glow_04"
	ENT.mat_ring = Material "effects/select_ring"
	ENT.mat_ring_hq = Material "jcms/ring"
	ENT.mat_tesla = Material "effects/tool_tracer"
	
	local rotatorAng = Angle(0,0,0)
	local bladeAng = Angle(0,0,0)
	function ENT:Think()
		local selfTbl = self:GetTable()
		local rotatorSpeed, bladesOpen = selfTbl:GetIsComplete() and 1000 or Lerp(selfTbl.chargeFraction, 0, 100), selfTbl:GetIsComplete() and 0.9 or selfTbl.chargeFraction*0.33
		local dt = FrameTime()
		
		selfTbl.bladesOpen = math.Approach(selfTbl.bladesOpen, bladesOpen, dt * 0.63)
		selfTbl.rotatorAngle = (selfTbl.rotatorAngle + rotatorSpeed*dt) % 360
		
		rotatorAng.p = selfTbl.rotatorAngle
		self:ManipulateBoneAngles(self.boneIdRotator, rotatorAng)
		
		for i=1, 2 do
			local boneIdBlade = self:LookupBone("blade" .. i)
			bladeAng.y = selfTbl.bladesOpen * 90 * (i==1 and -1 or 1)
			self:ManipulateBoneAngles(boneIdBlade, bladeAng, 0)
		end

		local W = 7
		selfTbl.chargeFraction = ((selfTbl.chargeFraction * W) + (selfTbl:GetCharge()/selfTbl:GetMaxCharge()))/(W+1)

		if not selfTbl.soundCharge and selfTbl.chargeFraction > 0 then
			selfTbl.soundCharge = CreateSound(self, "weapons/gauss/chargeloop.wav")
			selfTbl.soundCharge:PlayEx(1, 66)
		end
		
		if selfTbl.soundCharge then
			selfTbl.soundCharge:ChangePitch( selfTbl:GetIsComplete() and math.Remap(selfTbl.bladesOpen, 0.33, 0.9, 150, 200) or Lerp(selfTbl.chargeFraction^2, 66, 150) )
		end
	end

	function ENT:OnRemove()
		if self.soundCharge then
			self.soundCharge:Stop()
		end
	end
	
	function ENT:Draw()
		self:DrawModel()
	end
	
	function ENT:DrawTranslucent() --TODO: Significant lua lag in this function, probably want to optimise more
		local selfTbl = self:GetTable()

		local time = CurTime()*3 + self:EntIndex()*0.4
		local chargeFraction = selfTbl.chargeFraction
		local dt = FrameTime()
		
		local v, a = self:GetPos(), self:GetAngles()
		local colorLerpFraction = math.Remap(selfTbl.bladesOpen, 0.33, 0.9, 0, 1)
		local col = Color(Lerp(colorLerpFraction, 255, 64), Lerp(colorLerpFraction, 64, 180), Lerp(colorLerpFraction, 64, 255))
		local colBlack = Color(0, 0, 0)
		local colBrighter = Color( (col.r+255)/2, (col.g+255)/2, (col.b+255)/2 )
		
		local sphereRad = Lerp(chargeFraction, 4, 18)
		local sphereBigRad = sphereRad + 4
		local up = a:Up()
		local beamStartPos = v + up*135.6
		local beamEndPos = beamStartPos + up*Lerp( (math.sin(time)+1)/2, 117, 137 )
		local beamSpherePos = beamEndPos + up*sphereRad

		local dist2ToEyes = jcms.EyePos_lowAccuracy:DistToSqr(beamSpherePos)
		local lodRings = dist2ToEyes > 800^2
		local lodSphere = dist2ToEyes > 200^2

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.SetMaterial(selfTbl.mat_beam)
			render.DrawBeam(beamStartPos, beamEndPos, Lerp(chargeFraction, 2, 7), 0, 1, col)
			render.DrawBeam(beamStartPos, beamEndPos, Lerp(chargeFraction, 0, 2), 0, 1, colBrighter)

			if lodSphere then
				local size1 = sphereBigRad*2
				local size2 = (sphereBigRad + sphereRad)
				render.SetMaterial(jcms.mat_circle)
				render.DrawSprite(beamSpherePos, size1, size1, col)
				render.DrawSprite(beamSpherePos, size2, size2, colBrighter)
			else
				render.SetColorMaterial()
				render.DrawSphere(beamSpherePos, sphereBigRad, 13, 13, col)
				render.DrawSphere(beamSpherePos, (sphereBigRad + sphereRad)/2, 13, 13, colBrighter)
			end
		render.OverrideBlend( false )

		if not selfTbl.rings then
			selfTbl.rings = {}

			for i=1, 5 do
				local sizeRand = math.random()
				table.insert(selfTbl.rings, { 
					angle = Angle(math.random()*360, math.random()*360, math.random()*360), 
					pitchSpeed = math.Rand(60, 120), yawSpeed = math.Rand(60, 120), rollSpeed = math.Rand(60, 120),
					size1 = Lerp(sizeRand, 16, 48),
					size2 = Lerp(sizeRand, 2, 8),
					phase = math.random()*math.pi*2,
					col = Color( Lerp(sizeRand, colBrighter.r, col.r/2), Lerp(sizeRand, colBrighter.g, col.g/2), Lerp(sizeRand, colBrighter.b, col.b/2) )
				})
			end
		end

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.SetMaterial(lodRings and selfTbl.mat_ring or selfTbl.mat_ring_hq)
			for i, ring in ipairs(selfTbl.rings) do
				local size = sphereBigRad*2 +  Lerp( (math.sin( time + ring.phase ) + 1)/2, ring.size1, ring.size2 )
				ring.angle.pitch = ring.angle.pitch + ring.pitchSpeed*dt
				ring.angle.yaw = ring.angle.yaw + ring.yawSpeed*dt
				ring.angle.roll = ring.angle.roll + ring.rollSpeed*dt
				
				ring.col.r = col.r
				ring.col.g = col.g
				ring.col.b = col.b
				render.DrawQuadEasy(beamSpherePos, ring.angle:Forward(), size, size, ring.col)
			end

			if chargeFraction > 0.7 then
				render.SetMaterial(selfTbl.mat_tesla)
				for i=1, 2 do
					local boneId = self:LookupBone("blade" .. i)
					if boneId then
						local v, a = self:GetBonePosition(boneId)
						local teslaStartPos = v + a:Right()*-90
						render.DrawBeam(teslaStartPos, beamSpherePos, self:GetIsComplete() and 70 or 24, -time%1, -time%1+1, col)
					end
				end
			end
		render.OverrideBlend( false )

		local blackMul = self:GetIsComplete() and math.Remap(selfTbl.bladesOpen, 0.33, 0.9, 1, 0) or 1
		if blackMul > 0 then
			if lodSphere then
				local size = sphereRad*blackMul*2
				render.SetMaterial(jcms.mat_circle)
				render.DrawSprite(beamSpherePos, size, size, colBlack)
			else
				render.SetColorMaterial()
				render.DrawSphere(beamSpherePos, sphereRad*blackMul, 13, 13, colBlack)
			end
		end

		if dist2ToEyes < 4000^2 then
			selfTbl.DrawKillCounter(self, v, a) --thank you merkidor for always writgn coherent variable anems that I can rea d.
		end
	end

	function ENT:DrawKillCounter(pos, ang) --pos and ang are self:GetPos(), and self:GetAngles(), they're passed for optimsation.
		local selfTbl = self:GetTable()

		--local pos = self:GetPos()
		--local ang = self:GetAngles()

		if (selfTbl.chargeFraction + 0.0001) < selfTbl:GetCharge()/selfTbl:GetMaxCharge() or selfTbl.chargeFraction > 0.9999 then
			surface.SetDrawColor(64, 180, 255)
		else
			surface.SetDrawColor(255, 0, 0)
		end

		for i=1, 2 do
			local cpos = Vector(pos)
			local cang = Angle(ang)
			cang:RotateAroundAxis(ang:Right(), 90)
			cang:RotateAroundAxis(ang:Up(), (i==1 and -1 or 1)*45)
			cpos:Add(cang:Up()*-20)

			cam.Start3D2D(cpos, cang, 1/16)
				local x, y, w, h, p = 200, -40, 1410, 80, 16
				local f = 1 - math.Clamp(selfTbl.chargeFraction*(w+310)/w, 0, 1)
				
				local ch = w - p*2
				surface.DrawOutlinedRect(x,y,w,h, p/3)
				surface.DrawRect(x+p,y+p,w-p*2-ch*f,h-p*2)

				x = x + w + 120
				f = 1 - math.Clamp((selfTbl.chargeFraction*(w+310)-w)/310, 0, 1)
				w = 310
				ch = w - p*2
				surface.DrawOutlinedRect(x,y,w,h, p/3)
				surface.DrawRect(x+p,y+p,w-p*2-ch*f,h-p*2)
			cam.End3D2D()
		end
	end

	function ENT:jcms_GetChargeBeamPos()
		local time = CurTime()*3 + self:EntIndex()*0.4
		return self:GetPos() + self:GetAngles():Up()*(135.6 + Lerp( (math.sin(time)+1)/2, 117, 137 ))
	end
end
