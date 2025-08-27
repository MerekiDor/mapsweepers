--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025  MerekiDor

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
ENT.PrintName = "J Corp Laser Cannon Emplacement"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.SentinelAnchor = true

if CLIENT then
	sound.Add( {
		name = "jcms_emplacement_fire",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 162,
		pitch = 100,
		sound = "^jcms/jcorp_emplacement_fire.wav"
	} )

	sound.Add( {
		name = "jcms_emplacement_fire_end",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 162,
		pitch = 100,
		sound = "^jcms/jcorp_emplacement_fire_end.wav"
	} )
end

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Man")
	self:NetworkVar("Bool", 0, "Firing")
	self:NetworkVar("Float", 0, "Heat")
end

function ENT:SetDriver(v)
	return self:SetMan(v)
end

function ENT:GetDriver()
	return self:GetMan()
end

function ENT:Initialize()
	self:SetModel("models/jcms/jcorp_emplacement.mdl")
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physobj = self:GetPhysicsObject()
		if IsValid(physobj) then
			physobj:EnableMotion(false)
		end

		self.onCooldown = false

		self:NetworkVarNotify("Man", function(self, name, old, new)
			if IsValid(old) and old:GetNWEntity("jcms_vehicle") == self then
				old:SetNWEntity("jcms_vehicle", NULL)
			end

			if IsValid(new) and not IsValid(new:GetNWEntity("jcms_vehicle")) then
				new:SetNWEntity("jcms_vehicle", self)
			end
		end)
	end

	if CLIENT then
		self.manAngleCached = Angle(0, 0, 0)
		self.manAngleCachedReal = Angle(0, 0, 0)
	end

	self.traceHullMins = Vector(-1, -1, -1)
	self.traceHullMaxs = Vector(1, 1, 2)
end

function ENT:GetTurretManAngles()
	local man = self:GetMan()
	if IsValid(man) then
		local firingOrigin = self:GetBonePosition(1) or self:WorldSpaceCenter()

		local tr = util.TraceHull {
			mins = self.traceHullMins,
			maxs = self.traceHullMaxs,
			filter = { self, man },
			mask = MASK_SHOT_HULL,
			start = man:EyePos(),
			endpos = man:EyePos() + man:EyeAngles():Forward()*7500
		}

		local v = tr.HitPos - firingOrigin
		local a = v:Angle()

		local myang = self:GetAngles()
		a:Sub(myang)
		a:Normalize()
		a:SetUnpacked(math.Clamp(a.p, -56, 50), math.Clamp(a.y, -84, 84), 0)
		a:Add(myang)

		return a
	else
		return angle_zero
	end
end

if SERVER then
	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) and self:CheckInRange(activator) then
			if self.onCooldown then
				self:EmitSound("common/wpn_denyselect.wav", 75, 100)
			else
				local man = self:GetMan()
				if man == activator then
					self:SetMan()
				elseif not IsValid(man) then
					self:SetMan(activator)
				end
			end
		end
	end

	function ENT:CheckInRange(ply)
		local origin = self:WorldSpaceCenter()
		local fwd = self:GetAngles():Forward()
		fwd:Mul(-37)
		origin:Add(fwd)
		origin.z = origin.z + 6
		return ply:WorldSpaceCenter():DistToSqr(origin) <= 2500
	end

	function ENT:FireLaser(attacker)
		self.altBarrel = not self.altBarrel
		local heat = self:GetHeat() -- JUST LIKE THE 1995 MOVIE!!!!!!!

		local v = self:GetBonePosition(1)
		local a = self:GetTurretManAngles()

		local effectdata3 = EffectData()
		effectdata3:SetEntity(self)
		effectdata3:SetScale(math.Rand(0.9, 1.4)+heat)
		effectdata3:SetFlags(2)
		util.Effect("jcms_muzzleflash", effectdata3)

		local mypos = self:GetPos()

		for i=1, 3 do
			local phi = math.random()*math.pi*2
			local cos, sin = math.cos(phi)*(1+heat), math.sin(phi)*(1-heat*0.2)
			local mul = math.random()*(i*0.8+heat*0.7) * 0.75

			local spreadAngle = Angle(a)
			spreadAngle.p = spreadAngle.p + sin*mul 
			spreadAngle.y = spreadAngle.y + cos*mul 

			local tr = util.TraceLine {
				start = v + a:Right()*( (self.altBarrel and -1 or 1)*2 ), 
				endpos = v + spreadAngle:Forward()*7500,
				mask = MASK_SHOT,
				filter = self
			}

			local ed = EffectData()
			ed:SetStart(tr.StartPos)
			ed:SetScale(50)
			ed:SetAngles(spreadAngle)
			ed:SetOrigin(tr.HitPos)
			ed:SetFlags(0)
			util.Effect("jcms_laser", ed)

			if IsValid(tr.Entity) then
				local isGunship = tr.Entity:GetClass() == "npc_combinegunship"
				local dmg = DamageInfo()
				dmg:SetDamagePosition(tr.HitPos)
				dmg:SetDamageForce(tr.Normal)
				dmg:SetDamage(isGunship and 2+heat or (12 + i*(1+heat*2)))
				dmg:SetReportedPosition(self:GetPos())
				dmg:SetDamageType(isGunship and DMG_BLAST or bit.bor(DMG_BULLET, DMG_AIRBOAT) )
				dmg:SetInflictor(self)
				dmg:SetAttacker(attacker)
				tr.Entity:DispatchTraceAttack(dmg, tr)
			end
		end
	end

	function ENT:Think()
		local man = self:GetMan()
		
		if IsValid(man) then
			if not self:CheckInRange(man) then
				self:SetMan()
			else
				local wep = man:GetActiveWeapon()
				if IsValid(wep) then
					wep:SetNextPrimaryFire( CurTime() + 1 )
					wep:SetNextSecondaryFire( CurTime() + 1 )
				end
			end
		end

		local shouldFire = IsValid(man) and self.attacking1
		if shouldFire ~= self:GetFiring() then
			self:SetFiring(shouldFire)
		end
		
		local onFire = self:IsOnFire()
		if shouldFire then
			self:FireLaser(man)

			local newHeat = math.min(1, self:GetHeat() + (onFire and 0.00499 or 0.00238)) 
			self:SetHeat(newHeat)
			
			if newHeat >= 1 then
				self.onCooldown = true
				self.didHeatBlip = false
				self:SetMan()
			elseif newHeat >= 0.8 and not self.didHeatBlip then
				self:EmitSound("buttons/blip2.wav", 120, 150)
				self.didHeatBlip = true
			end
		else
			self:SetHeat( math.max(0, self:GetHeat() - (onFire and 0 or (self.onCooldown and 0.0015 or 0.001))) )

			if self.onCooldown and self:GetHeat() <= 0 then
				self.onCooldown = false
				self:EmitSound("buttons/lever5.wav", 120, 150)
			end
		end

		self:NextThink(CurTime() + (shouldFire and 0.1 or 0.083))

		return true
	end
end

if CLIENT then
	ENT.BeamColor = Color(255, 102, 102)
	ENT.BeamMat = Material "effects/spark"

	local function weighedAngleApproach(n,to,weight)
		if n-to > 180 then
			n = n - 360
		elseif to-n > 180 then
			n = n + 360
		end

		return (n*weight + to)/(weight + 1)
	end

	function ENT:Draw(flags)
		self:DrawModel()
	end

	function ENT:DrawTranslucent(flags)
		local v, a = self:GetBonePosition(1)
		if not v then return end
		local eyeDist = jcms.EyePos_lowAccuracy:DistToSqr(v)

		if eyeDist < 250000 then
			local heat = self:GetHeat()

			local ol = 5
			local sc = 4
			a:RotateAroundAxis(a:Forward(), 80)
			cam.Start3D2D(v, a, 1/(8*sc))
				surface.SetDrawColor(255, 255*(1-heat*heat*heat*heat), 0)
				surface.DrawOutlinedRect(-48*sc, -36*sc, 96*sc, 10*sc, ol)

				surface.SetDrawColor(255, 255 - 175*heat*heat*heat, 0)
				surface.DrawRect(-48*sc+ol*2, -36*sc+ol*2, (96*sc-ol*4)*heat, 10*sc-ol*4)
			cam.End3D2D()
		end

		if self:GetMan() == jcms.locPly then
			local v = self:GetBonePosition(1)
			local a = self.manAngleCachedReal

			local tr = util.TraceLine {
				start = v,
				endpos = v + a:Forward() * 7500,
				mask = MASK_SHOT_HULL,
				filter = self
			}

			local dist = tr.StartPos:Distance(tr.HitPos)
			render.SetMaterial(self.BeamMat)
			render.DrawBeam(tr.StartPos, tr.HitPos, 4, 0.2, 0.7, self.BeamColor)
		end
	end

	function ENT:OnRemove()
		if self.sfxFiring then
			self.sfxFiring:Stop()
			self.sfxFiring = nil
		end

		if self.sfxHeat then
			self.sfxHeat:Stop()
			self.sfxHeat = nil
		end
	end

	function ENT:Think()
		local ang = self.manAngleCached
		local angReal = self.manAngleCachedReal

		local man = self:GetMan()
		if IsValid(man) then
			if not self.previousManMode then
				self:EmitSound("ambient/machines/combine_terminal_idle4.wav", 75, 180)
				self.previousManMode = true
			end

			local W = 5
			local ea = self:GetTurretManAngles()
			ea:Sub(self:GetAngles())
			ang:SetUnpacked(0, weighedAngleApproach(ang[2], ea.y, W), weighedAngleApproach(ang[3],-ea.p,W))
		else
			if self.previousManMode then
				self:EmitSound("npc/turret_floor/die.wav", 75, 200)
				self.previousManMode = false
			end

			local W = 14
			ang:SetUnpacked(0, weighedAngleApproach(ang[2], 0, W), weighedAngleApproach(ang[3], -40, W))
		end

		angReal:SetUnpacked(-ang.r, ang.y, 0)
		angReal:Add(self:GetAngles())

		if self:GetFiring() then
			if not self.sfxFiring then
				self.sfxFiring = CreateSound(self, "jcms_emplacement_fire")
				self.sfxFiring:Play()
			end
		else
			if self.sfxFiring then
				self:EmitSound("jcms_emplacement_fire_end")
				self.sfxFiring:Stop()
				self.sfxFiring = nil
			end
		end

		local heatSoundThreshold = 0.44
		if self:GetHeat() > heatSoundThreshold then
			local frac = math.TimeFraction(heatSoundThreshold, 1, self:GetHeat())
			if not self.sfxHeat then
				self.sfxHeat = CreateSound(self, "ambient/gas/steam2.wav")
				self.sfxHeat:PlayEx(0, 153)
			else
				self.sfxHeat:ChangeVolume(frac, 0.01)
				self.sfxHeat:ChangePitch(Lerp(frac, 153, 164), 0.01)
			end
		elseif self.sfxHeat then
			self.sfxHeat:Stop()
			self.sfxHeat = nil
		end

		self:ManipulateBoneAngles(1, self.manAngleCached)
	end

	function ENT:DrawHUDCenter()
		jcms.draw_Crosshair()
	end

	ENT.DoDrawHealthbar = true
end
