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
ENT.PrintName = "Download Pillar"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "ChargeFraction")
	self:NetworkVar("Bool", 0, "IsActive")
	self:NetworkVar("Bool", 1, "IsDisrupted")
	self:NetworkVar("String", 0, "LabelSymbol")
end

function ENT:Initialize()
	self:SetModel("models/jcms/jcorp_downloadpillar.mdl")

	if SERVER then
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		
		self:SetMaxHealth(500)
		self:SetHealth(500)
		 
		self.nextDamageAllowed = 0
		self.nextHealthThreshold = 0.95

		self.bullseyes = {}
		local pos = self:WorldSpaceCenter()
		local ang = self:GetAngles()
		for i=1, 6, 1 do 
			local ent = ents.Create("jcms_bullseye")

			local nPos, nAng = Vector(pos), Angle(ang)
			nAng:RotateAroundAxis(nAng:Up(), 360 / 6 * (i-1))
			nPos:Add(nAng:Forward()*24)
			nPos:Add(nAng:Up()*12)
			
			ent:SetPos(nPos)
			ent:Spawn()
			ent.DamageTarget = self

			ent:AddFlags(FL_NOTARGET)
			table.insert(self.bullseyes, ent)
		end
	end

	if CLIENT then
		local mins, maxs = self:GetRenderBounds()
		local skyPos = jcms.util_GetSky(self:GetPos())

		if skyPos then
			maxs.z = math.max(skyPos.z, maxs.z + 32)
		else
			maxs.z = maxs.z + 1024
		end
		self:SetRenderBounds(mins, maxs)
	end
end

if SERVER then
	function ENT:OnRemove()
		for i, ent in ipairs(self.bullseyes) do
			if IsValid(ent) then
				ent:Remove()
			end
		end
	end

	function ENT:Think()
		local active = self:Health() > 0 and self:GetIsActive() and not self:GetIsDisrupted()
		
		for i, ent in ipairs(self.bullseyes) do
			if IsValid(ent) then
				if active then
					ent:RemoveFlags( FL_NOTARGET )
				else
					ent:AddFlags( FL_NOTARGET )
				end
			end
		end
	end

	function ENT:OnTakeDamage(dmg)
		if not self:GetIsActive() then
			return 0
		end

		local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
		if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) and jcms.team_pvpSameTeam(self, attacker) then
			jcms.util_PerformRepairs(self, attacker, 25)

			if self:Health() >= self:GetMaxHealth() then
				self.nextHealthThreshold = 0.5
				self.nextDamageAllowed = CurTime() + 3

				local wasDisrupted = self:GetIsDisrupted()
				self:SetIsDisrupted(false)
			end

			self:SetHealthFraction( self:Health() / self:GetMaxHealth() )
			return 0
		end


		if jcms.team_JCorp(attacker) and jcms.team_pvpSameTeam(self, attacker) then
			dmg:SetDamage( dmg:GetDamage() * 0.5 * jcms.cvar_ffmul:GetFloat() )
		end

		dmg:SetDamage( math.ceil(math.max(dmg:GetDamage() - 1, 0)^0.8) ) 

		if not self.nextDamageAllowed or CurTime() > self.nextDamageAllowed then
			local newHealth = math.Clamp(self:Health() - dmg:GetDamage(), 0, self:Health())

			local limit = self:GetMaxHealth() * self.nextHealthThreshold
			if newHealth < limit then
				newHealth = limit
				self.nextHealthThreshold = self.nextHealthThreshold - 0.25
				self.nextDamageAllowed = CurTime() + 2
			end

			self:SetHealth(newHealth)
			self:SetHealthFraction( self:Health() / self:GetMaxHealth() )
			
			if newHealth == 0 then
				if not self:GetIsDisrupted() then
					self:EmitSound("ambient/energy/newspark10.wav")
					local ed = EffectData()
					ed:SetEntity(self)
					ed:SetMagnitude(20)
					ed:SetScale(1)
					util.Effect("TeslaHitBoxes", ed)
				end
				
				self:SetIsDisrupted(true)
			end
		else
			return 0
		end
	end
end

if CLIENT then
	ENT.mat_elec = Material("sprites/physbeama")
	ENT.mat_flare = Material("sprites/orangeflare1_gmod")
	ENT.mat_lamp = Material("effects/lamp_beam.vmt")
	ENT.mat_cloud = CreateMaterial("jcms_downloadpillar_cloud", "UnlitGeneric", {
		["$basetexture"] = "models/props_combine/cit_cloud003",
		["$nofog"] = 1,
		["$additive"] = 1
	})

	ENT.labelColour1 = Color(32, 192, 255)
	ENT.labelColour2 = Color(168, 230, 255)

	ENT.disruptedColour1 = Color(255, 87, 87)
	ENT.disruptedColour2 = Color(255, 215, 83)

	ENT.pvpColors = {
		[1] = Color(255, 32, 32),
		[2] = Color(255, 195, 32)
	}

	ENT.healthbarMatName = "!jcms_downloadpillarhealthbar"
	ENT.healthbarRT = GetRenderTarget("jcms_downloadpillarhealthbar_rt", 8, 200)
	ENT.healthbarRTMat = CreateMaterial("jcms_downloadpillarhealthbar", "VertexLitGeneric", {
		["$basetexture"] = ENT.healthbarRT:GetName(),
		["$pointsamplemagfilter"] = 1,
		["$selfillum"] = 1
	})

	ENT.downNormal = Vector(0, 0, -1)

	function ENT:RenderScreen()
		local active = self:GetIsActive()
		local disrupted = self:GetIsDisrupted()
		local healthFrac = self:GetHealthFraction()
		local healthHeight = math.Round(healthFrac*200)

		render.PushRenderTarget(self.healthbarRT)
		cam.Start2D()
		if active then
			if disrupted then
				if (CurTime()+0.03)%0.5<0.25 then
					surface.SetDrawColor(99, 53, 0)
					surface.DrawRect(0, 0, 8, 200 - healthHeight, 1)
					surface.SetDrawColor(252, 255, 82)
					surface.DrawRect(0, 200 - healthHeight, 8, healthHeight, 1)
					surface.SetDrawColor(255, 211, 13)
					surface.DrawOutlinedRect(0, 200 - healthHeight, 8, healthHeight, 1)
				else
					surface.SetDrawColor(99, 0, 30)
					surface.DrawRect(0, 0, 8, 200 - healthHeight, 1)
					surface.SetDrawColor(255, 169, 40)
					surface.DrawRect(0, 200 - healthHeight, 8, healthHeight, 1)
					surface.SetDrawColor(207, 124, 0)
					surface.DrawOutlinedRect(0, 200 - healthHeight, 8, healthHeight, 1)
				end
			else
				surface.SetDrawColor(15, 0, 99)
				surface.DrawRect(0, 0, 8, 200 - healthHeight, 1)

				if math.random() < healthFrac*2 then
					surface.SetDrawColor(99, 255, 247)
				else
					surface.SetDrawColor(9, 218, 255)
				end
				surface.DrawRect(0, 200 - healthHeight, 8, healthHeight, 1)
				surface.SetDrawColor(108, 135, 255)
				surface.DrawOutlinedRect(0, 200 - healthHeight, 8, healthHeight, 1)
			end
		else
			surface.SetDrawColor(9, 0, 43)
			surface.DrawRect(0, 0, 8, 200, 1)
			surface.SetDrawColor(0, 13, 71)
			surface.DrawOutlinedRect(0, 0, 8, 200, 1)
		end
		cam.End2D()
		render.PopRenderTarget()
	end

	function ENT:OnRemove()
		if self.soundTransmit then
			self.soundTransmit:Stop()
			self.soundTransmit = nil
		end
	end

	function ENT:Think()
		if self:GetIsActive() and not self:GetIsDisrupted() then
			if not self.soundTransmit then
				self.soundTransmit = CreateSound(self, "ambient/levels/labs/teleport_active_loop1.wav")
				self.soundTransmit:PlayEx(1, 137)
			end
		elseif self.soundTransmit then
			self.soundTransmit:Stop()
			self.soundTransmit = nil
			self:EmitSound("ambient/energy/power_off1.wav", 75, 137, 1)
		end
	end

	function ENT:Draw()
		self:RenderScreen()
		render.MaterialOverrideByIndex(1, self.healthbarRTMat)
		self:DrawModel()
		render.MaterialOverrideByIndex()
	end

	function ENT:DrawTranslucent(flags)
		local t = CurTime() + self:EntIndex()*math.pi/7

		local sym = self:GetLabelSymbol()
		if sym then
			local d = 14
			local pos = self:GetPos()
			local ang = self:GetAngles()
			pos = pos + ang:Up() * 120
			ang:RotateAroundAxis(ang:Forward(), 90)
			pos:Add(ang:Up() * d)
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			for i=1, 2 do
				cam.Start3D2D(pos, ang, 1/4)
					draw.SimpleText(sym, "jcms_hud_huge", math.Rand(-1, 1), math.Rand(-1, 1), self.labelColour1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(sym, "jcms_hud_huge", math.Rand(-3, 3), math.Rand(-2, 2), self.labelColour2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				cam.End3D2D()

				if i == 1 then
					ang:RotateAroundAxis(ang:Right(), 180)
					pos:Add(ang:Up() * (d * 2))
				end
			end
			render.OverrideBlend( false )
		end

		local v = self:GetPos()
		local a = self:GetAngles()
		local up = a:Up()
		v:Add( a:Forward()*30.5 )
		v:Add( a:Right()*-1 )
		v:Add( up*19 )

		if self:GetIsActive() then
			local sizeMul = math.sin(t*2)/2 + 1.5

			local v2 = Vector(v)
			v2.z = math.min(26681, jcms.EyePos_lowAccuracy.z + 24000)

			local distToEyes = util.DistanceToLine(v, v2, EyePos())
			local wmul = math.max(1, distToEyes/700)*sizeMul
			if self:GetIsDisrupted() then
				local disruptColor = t%0.5<0.25 and self.disruptedColour1 or self.disruptedColour2
				render.SetMaterial(self.mat_flare)
				render.DrawQuadEasy(v, jcms.vectorUp, math.random(36, 42), math.random(36, 42), disruptColor, math.random()*360)
				render.SetMaterial(self.mat_lamp)
				render.DrawBeam(v, v2, 75, 0, 1, disruptColor)
			else
				local col = self.pvpColors[ self:GetNWInt("jcms_pvpTeam", -1) ] or self.labelColour1
				local offset = (t*4)%1
				local size = 10000 + 1000*sizeMul
				render.SetMaterial(self.mat_flare)
				render.DrawQuadEasy(v, jcms.vectorUp, math.random(16, 38), math.random(24, 38), col, math.random()*360)
				render.SetMaterial(self.mat_elec)
				render.DrawBeam(v, v2, 10*wmul, -offset, 30 - 10*sizeMul - offset, col)
				render.SetMaterial(self.mat_cloud)
				render.DrawQuadEasy(v2, self.downNormal, size, size, col, t*32)
				render.DrawQuadEasy(v2, self.downNormal, size*1.5, size*1.5, col, t*16)
			end
		else
			local v2 = Vector(v)
			v2.z = math.min(20681, jcms.EyePos_lowAccuracy.z + 20000)

			local distToEyes = util.DistanceToLine(v, v2, EyePos())
			local wmul = math.max(1, distToEyes/750)
			local size = 1000
			
			render.SetMaterial(self.mat_lamp)
			render.DrawBeam(v, v2, 6*wmul, 0, 1, self.labelColour1)

			render.SetMaterial(self.mat_cloud)
			render.DrawQuadEasy(v2, self.downNormal, size, size, self.labelColour1, t*40)
		end
	end
end