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
ENT.PrintName = "Refinery"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsSecondary")
	self:NetworkVar("Int", 0, "ValueInside")
	self:NetworkVar("Int", 1, "TimesGround")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/jcms/jcorp_orerefinery.mdl")

		if self:GetIsSecondary() then
			self:SetModel("models/jcms/jcorp_orerefinerymini.mdl")
		end

        self:PhysicsInitStatic(SOLID_VPHYSICS)
	end

	function ENT:IsDamagingVector(v)
		local radius = 32
		local selfPos = self:GetPos()
		--debugoverlay.Sphere(Vector(selfPos.x, selfPos.y, selfPos.z+30), radius, 1, Color(255,0,0), false)
		return (v.z > selfPos.z + 30) and (math.DistanceSqr(v.x, v.y, selfPos.x, selfPos.y) <= radius*radius)
	end

	function ENT:StartTouch(ent)
		if IsValid(ent) and ( ent:IsPlayer() or ent:IsNPC() ) then
			if (ent.jcms_oreMass or ent.jcms_oreValue) then return end
			local entPos = ent:GetPos()
			
			if self:IsDamagingVector(entPos) then
				self:EmitSound("NPC_Manhack.Slice")
				ent:SetVelocity( Vector(math.random(-100, 100), math.random(-100, 100), 350) )

				local dmginfo = DamageInfo()
				dmginfo:SetDamage(10)
				dmginfo:SetDamageType(DMG_SLASH)
				dmginfo:SetDamageForce(jcms.vectorUp)
				dmginfo:SetInflictor(self)
				dmginfo:SetDamagePosition(entPos)
				dmginfo:SetReportedPosition(entPos)
				dmginfo:SetAttacker(self)
				ent:TakeDamageInfo(dmginfo)
			end
		end
	end

	function ENT:PhysicsCollide(colData, collider)
		local ent = colData.HitEntity

		local selfPos = self:GetPos()
		if not self:IsDamagingVector(colData.HitPos) then
			return
		end
		
		local mass = tonumber(ent.jcms_oreMass) or 0
		local value = tonumber(ent.jcms_oreValue) or 1

		if mass and mass*value > 0 then
			local obtained = math.max(0, ent:GetWorth())
			self:SetValueInside( self:GetValueInside() + obtained )

			ent.jcms_oreMass = nil
			ent.jcms_oreValue = nil
			ent.jcms_physAte = true
			ent:Remove()

			local ed = EffectData()
			ed:SetOrigin(ent:WorldSpaceCenter())
			ed:SetColor(ent:GetOreColourInt())
			ed:SetRadius(obtained)
			util.Effect("jcms_oremine", ed)

			if type(self.OnRefine) == "function" then
				local miner = IsValid(ent.jcms_miner) and ent.jcms_miner or nil
				local bringer = IsValid(ent.jcms_lastPickedUp) and ent.jcms_lastPickedUp or nil

				local canRefine = false
				if miner and bringer then
					canRefine = true
				elseif miner and not bringer then
					bringer = miner
					canRefine = true
				elseif not miner and bringer then
					bringer = miner
					canRefine = true
				end

				if canRefine then
					if not self:GetIsSecondary() then
						self:EmitSound("buttons/bell1.wav", 90, 137)
					end
					self:OnRefine(ent, miner, bringer, obtained, mass, value)
				end
			end

			self:SetTimesGround(self:GetTimesGround() + 1)
		else
			self:EmitSound("NPC_Manhack.Grind")
			local invNormal = -colData.HitNormal

			local ed = EffectData()
			ed:SetOrigin(colData.HitPos)
			ed:SetMagnitude(1)
			ed:SetScale(2)
			ed:SetRadius(4)
			ed:SetNormal(invNormal)
			util.Effect("Sparks", ed)

			local dmginfo = DamageInfo()
			dmginfo:SetDamage(10)
			dmginfo:SetDamageType(DMG_SLASH)
			dmginfo:SetDamageForce(invNormal)
			dmginfo:SetInflictor(self)
			dmginfo:SetDamagePosition(colData.HitPos)
			dmginfo:SetReportedPosition(colData.HitPos)
			dmginfo:SetAttacker(self)
			ent:TakeDamageInfo(dmginfo)

			colData.HitObject:AddVelocity(invNormal*100)
		end
	end

	function ENT:Think()
		local magnetPos = self:GetPos() + Vector(0,0,60)
		local radius = 50
		local foundEnts = ents.FindInSphere(magnetPos, radius)
		--debugoverlay.Sphere(magnetPos, radius, 0.2, Color(255,0,0), false)

		for i, ent in ipairs(foundEnts) do 
			if ent:GetClass() == "jcms_orechunk" then 
				local entPos = ent:WorldSpaceCenter()
				local force = (magnetPos - entPos)
				force:Normalize()
				force:Mul(1000)
				ent:GetPhysicsObject():ApplyForceCenter( force )
			end
		end

		self:SetSaveValue("m_vecAbsVelocity", Vector(0,0,0))

		self:NextThink(CurTime() + 0.1)
		return true
	end

	function ENT:OnTakeDamage(dmgInfo)
		local attacker = dmgInfo:GetAttacker()
		if not IsValid(attacker) or attacker:Health() <= 0 or not attacker.jcms_oreType then return end 

		local dmg = 200

		-- // FX {{{
			self:EmitSound("NPC_Manhack.Grind")

			local obtained = jcms.ore_GetValue(attacker.jcms_oreType, dmg/3)
			self:SetValueInside( self:GetValueInside() + obtained )

			local ed = EffectData()
			ed:SetOrigin(dmgInfo:GetDamagePosition())
			ed:SetColor( jcms.util_ColorInteger(jcms.oreTypes[attacker.jcms_oreType].color) or 0 ) 
			ed:SetRadius(obtained)
			util.Effect("jcms_oremine", ed)

			self:SetTimesGround(self:GetTimesGround() + 1)
		-- // }}}

		local newDmgInfo = DamageInfo()
		newDmgInfo:SetAttacker(self)
		newDmgInfo:SetInflictor(self)
		newDmgInfo:SetDamageType(DMG_SLASH)
		newDmgInfo:SetReportedPosition(self:WorldSpaceCenter())
		newDmgInfo:SetDamagePosition(self:WorldSpaceCenter())
		newDmgInfo:SetDamage(dmg)
		
		attacker:TakeDamageInfo(newDmgInfo)
	end
end

if CLIENT then
	ENT.colourRed = Color(255, 42, 42)

	function ENT:OnRemove()
		if self.sfxGrind then
			self.sfxGrind:Stop()
			self.sfxGrind = nil
		end
	end
	
	function ENT:DrawTranslucent()
		self:DrawModel()
		if not self:GetIsSecondary() then return end
		
		local eyeDist = jcms.EyePos_lowAccuracy:DistToSqr(self:GetPos())
		if eyeDist >= 1500*1500 then return end

		local tipPos = self:WorldSpaceCenter()
		local tipAngle = self:GetAngles()

		local str1 = "#jcms.personalrefinery_title"
		local str2 = "#jcms.personalrefinery_desc1"
		local str3 = "#jcms.personalrefinery_desc2"

		tipAngle:RotateAroundAxis(tipAngle:Up(), 90)
		tipAngle:RotateAroundAxis(tipAngle:Forward(), 90)
		tipPos:Add( tipAngle:Up()*-28 )

		local bx, by, bw, bh = -340, -330, 500, 230
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
		cam.Start3D2D(tipPos, tipAngle, 1/12)
			surface.SetDrawColor(self.colourRed)
			jcms.hud_DrawNoiseRect(bx-108, by, bw+216, bh, 2048)

			if eyeDist <= 800*800 then
				draw.SimpleText(str1, "jcms_hud_small", bx + bw/2, by + 16, self.colourRed, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				local _, th = draw.SimpleText(str3, "jcms_hud_medium", bx + bw/2, by + bh - 8, self.colourRed, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(str2, "jcms_hud_medium", bx + bw/2, by + bh - th - 8, self.colourRed, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end
		cam.End3D2D()
		render.OverrideBlend( false )
	end

	function ENT:Think()
		local dist2 = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())

		if dist2 <= 1000000 then
			if not self.sfxGrind then
				if self:GetIsSecondary() then
					self.sfxGrind = CreateSound(self, "vehicles/crane/crane_idle_loop3.wav")
				else
					self.sfxGrind = CreateSound(self, "vehicles/digger_grinder_loop1.wav")
				end
				self.sfxGrind:PlayEx(0, 80)
			end

			self.grindFactor = math.max(0, (self.grindFactor or 0) - FrameTime()*0.4)

			if self.grindFactor > 0 and (not self.nextBoulderSFX or CurTime() > self.nextBoulderSFX) then
				self:EmitSound("Breakable.Concrete")
				self.nextBoulderSFX = CurTime() + math.Rand(0.06, 0.2) 
			end

			local timesGround = self:GetTimesGround()
			if timesGround ~= self.timesGroundCl and timesGround > 0 then
				self.timesGroundCl = timesGround
				self.grindFactor = math.min(self.grindFactor + 0.6, 1)
			end

			local pitch = 80 + self.grindFactor*40
			local vol = math.Clamp(math.Remap(dist2, 1000000, 10000, 0, 1), 0, self:GetIsSecondary() and 1 or (0.5+self.grindFactor*0.5))
			self.sfxGrind:ChangePitch(pitch, 0.1)
			self.sfxGrind:ChangeVolume(vol, 0.1)

			self.grindAnim = ((self.grindAnim or 0) + FrameTime() * (50 + self.grindFactor*200)) % (math.pi*2)
			local grindAnimSin = math.sin(self.grindAnim)
			local grindAnimCos = math.cos(self.grindAnim)

			local shakeVector = VectorRand(-1, 1)
			shakeVector:Mul(0.06 + self.grindFactor*0.28)

			self:ManipulateBonePosition(0, shakeVector)
			self:ManipulateBonePosition(1, Vector(0, -grindAnimSin*2-self.grindFactor, 0))
			self:ManipulateBonePosition(2, Vector(0, grindAnimCos*2+self.grindFactor, 0))
		else
			if self.sfxGrind then
				self.sfxGrind:Stop()
				self.sfxGrind = nil
			end
		end
	end
end