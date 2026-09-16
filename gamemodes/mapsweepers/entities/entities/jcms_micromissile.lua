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
ENT.PrintName = "Micro-Missile"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Speed = 1750
ENT.Radius = 75
ENT.Proximity = 38
ENT.Damage = 25
ENT.Damping = 1
ENT.ActivationTime = 0
ENT.Arc = 0

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl") --Trace detection is separate to collision detection

		if self.AntiAir then
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetMaxHealth(30)
			self:SetHealth(30)
			util.SpriteTrail(self, 0, Color(255, 66, 66), true, 3, 0, 3, 1, "trails/smoke")
			self.Speed = 2300
			self:SetBlinkScale(0)

			self.jcms_isPlayerMissile = true 
		else
			self:PhysicsInitSphere(6, "metal")

			self:SetModelScale(0.66)
			self:SetMaxHealth(5)
			self:SetHealth(5)
			util.SpriteTrail(self, 0, Color(255, 230, 200), true, 48, 0, 0.65, 0.01, "trails/laser")

			--flashing light
			self:SetBlinkScale(4)
			self:SetBlinkPeriod( 0.75 )

			self.jcms_isPlayerMissile = jcms.team_JCorp(self.jcms_owner)
		end
		
		self:SetColor( Color(255, 120, 120) )
		self.spinoutCycle = math.random()*64

		self.creationTime = CurTime()
		
		self:GetPhysicsObject():Wake()
	elseif CLIENT then 
		--Make sure we render the actual visual model, not the trace-thing.
		--NOTE: This is also in the think, as having it only here is unreliable and caused issues.
		self:SetModel( "models/weapons/w_missile_closed.mdl" )
	end

end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "BlinkPeriod")
	self:NetworkVar("Float", 1, "BlinkScale")
	self:NetworkVar("Vector", 0, "BlinkColor")
	self:NetworkVar("Angle", 0, "BlinkDirection")
end


if SERVER then
	function ENT:PhysicsUpdate(phys)
		local selfTbl = self:GetTable()
		local selfPos = self:GetPos()
		selfTbl.spinoutCycle = ( (selfTbl.spinoutCycle or 0) + FrameTime()*5 ) % 15
		local spinout = (math.sin(selfTbl.spinoutCycle) * math.cos(selfTbl.spinoutCycle/math.pi)) / (selfTbl.spinoutCycle+1)
		if selfTbl.spinoutCycle > 5 then
			spinout = 0
		end
	
		local pathCond = selfTbl.Path and #selfTbl.Path > 0 and not (isentity(selfTbl.Target) and IsValid(selfTbl.Target) and self:Visible(selfTbl.Target))
		local targetVector = selfTbl.lastTargetVector
		if pathCond then
			targetVector = selfTbl.Path[ #selfTbl.Path ]
			if type(targetVector) == "table" and isvector(targetVector.pos) then
				targetVector = targetVector.pos
			end

			if selfPos:DistToSqr(targetVector) < selfTbl.Proximity^2 then
				table.remove(selfTbl.Path)

				if selfTbl.LoweredDampingPath then
					selfTbl.LoweredDampingPath = selfTbl.LoweredDampingPath - 1
					if selfTbl.LoweredDampingPath <= 0 then
						selfTbl.LoweredDampingPath = nil
					end
				end

				if #selfTbl.Path == 0 then
					selfTbl.Path = nil
					pathCond = false
					selfTbl.LoweredDampingPath = nil
				end
			end
		end

		if not selfTbl.AntiAir and pathCond then 
			local tPos = selfTbl.Path[1] 
			if type(tPos) == "table" and isvector(tPos.pos) then
				tPos = tPos.pos
			end

			local distToTarg = tPos:Distance(selfPos)
			if distToTarg < 1500 then 
				self:SetBlinkPeriod(0.5)
			end
		end

		if not pathCond then
			if isentity(selfTbl.Target) then
				if IsValid(selfTbl.Target) and (selfTbl.NeverLoseTarget or selfTbl.Target:Health() > 0) then
					targetVector = selfTbl.Target:WorldSpaceCenter() + selfTbl.Target:GetVelocity()
				else
					local targets = ents.FindInSphere(selfPos, 1024)
					table.Shuffle(targets)
					for i, tg in ipairs(targets) do
						if tg:Health() > 0 and jcms.team_NPC(tg) and jcms.team_GoodTarget(tg) then
							selfTbl.Target = tg
							targetVector = selfTbl.Target:WorldSpaceCenter()
							break
						end
					end
				end
				
				if not selfTbl.jcms_isPlayerMissile then --NPC missiles don't track continuously.
					selfTbl.Target = targetVector
				end
			elseif isvector(selfTbl.Target) then
				targetVector = selfTbl.Target
			end
			
			if not selfTbl.AntiAir then 
				self:SetBlinkPeriod(0.2)
			end
		end
		
		if (IsValid(selfTbl.Target) or isvector(selfTbl.Target)) and isvector(targetVector) then
			local dif = targetVector - selfPos
			if not pathCond and (dif:LengthSqr() < (selfTbl.Proximity)^2) and selfTbl.ActivationTime < CurTime() then
				self:Detonate(isentity(selfTbl.Target) and selfTbl.Target or nil)
			else
				local norm = dif:GetNormalized()
				local rand = VectorRand(-2, 2)
				rand:Mul(spinout)
				norm:Add(rand)

				local frac = dif:Length() / 2500
				local arc = Lerp(frac, 0, selfTbl.Arc )
				norm:Add(jcms.vectorUp * arc)
				norm:Normalize()

				local realDamping = (pathCond and selfTbl.LoweredDampingPath) and math.max(selfTbl.Damping*1.33, 2) or selfTbl.Damping
				
				if not selfTbl.AntiAir then
					phys:AddVelocity(-self:GetVelocity() * realDamping * FrameTime())
				end

				local idealVelocity = norm * selfTbl.Speed
				local addedVelocity = idealVelocity - self:GetVelocity() * realDamping
				
				phys:AddVelocity(addedVelocity * FrameTime())
			end
			
			phys:EnableGravity(false)
			selfTbl.lastTargetVector = targetVector
		else
			phys:EnableGravity(true)
		end
	end
	
	function ENT:PhysicsCollide(data, collider)
		if self.ActivationTime > CurTime() then return end

		if IsValid(self.Target) and (data.HitEntity == self.Target or data.HitEntity:GetClass() == "phys_bone_follower" and data.HitEntity:GetOwner() == self.Target) then
			self:Detonate(self.Target)
		elseif not(self.AntiAir and IsValid(self.Target) and CurTime() - self.creationTime < 30) then --antiair missiles only detonate on other objects after 30s of life.
			self:Detonate()
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		if self.ActivationTime > CurTime() or self.AntiAir then return end

		local attacker = dmg:GetAttacker()
		local inflictor = dmg:GetInflictor() 
		self.turretHits = self.turretHits or 0
		if IsValid(inflictor) and inflictor:GetClass() == "jcms_turret" and self.turretHits < 5 then
			self.turretHits = self.turretHits + math.ceil( dmg:GetDamage() / 25 )
			return
		end

		if dmg:GetDamage() >= 2 and inflictor ~= self and dmg:GetDamageType() ~= DMG_BLAST and not (IsValid(attacker) and attacker:IsNPC()) then
			-- This effect produces a clang sound, and a nigh-invisible large trasparent yellow flash (2x the size of explosion)
			-- It's so transparent and large to the point it's just not there. It's very easy to mistake with the explosion's own flash.
			local ed = EffectData()
			ed:SetOrigin(self:GetPos())
			ed:SetStart(self:GetPos())
			ed:SetEntity(self)
			ed:SetMagnitude(1)
			ed:SetScale(1)
			ed:SetColor(1)
			ed:SetFlags(0)
			util.Effect("RPGShotDown", ed)

			if IsValid(dmg:GetAttacker()) then
				self.jcms_owner = dmg:GetAttacker()
			end

			self:Detonate()
		end
	end

	function ENT:GravGunPunt(ply)
		local tr = util.TraceLine {
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:EyeAngles():Forward() * 16000,
			filter = { ply, self }
		}

		self.Path = nil
		self.Target = IsValid(tr.Entity) and tr.Entity or tr.HitPos
		self.Arc = 0

		self:SetBlinkColor( Vector(1, 0, 0) ) -- we're JCorp now.

		return true
	end
	
	function ENT:Detonate(hitEntity)
		if not self.detonated then
			self.detonated = true
			local pos = self:GetPos()
			
			if self.AntiAir then
				local ed = EffectData()
				if IsValid(hitEntity) then
					ed:SetOrigin(hitEntity:WorldSpaceCenter())

					local movetype = hitEntity:GetMoveType()
					local flying = movetype == MOVETYPE_FLY or movetype == MOVETYPE_FLYGRAVITY

					if flying or jcms.team_flyingEntityClasses[ hitEntity:GetClass() ] then
						hitEntity:TakeDamage(self.Damage, IsValid(self.jcms_owner) and self.jcms_owner or self, self)
						ed:SetMagnitude(1.64)
						ed:SetRadius(320)
					else
						ed:SetMagnitude(1)
						ed:SetRadius(self.Radius)
						util.BlastDamage(self, IsValid(self.jcms_owner) and self.jcms_owner or self, pos, self.Radius, self.Damage/8)
					end
				else
					ed:SetMagnitude(1)
					ed:SetOrigin(self:GetPos())
					ed:SetRadius(self.Radius)
					util.BlastDamage(self, IsValid(self.jcms_owner) and self.jcms_owner or self, pos, self.Radius, self.Damage/8)
				end
				ed:SetNormal(self:GetAngles():Up())
				ed:SetFlags(1)
				util.Effect("jcms_blast", ed)
				self:EmitSound("explode_"..math.random(3,4))
				self:Remove()
			else
				local ed = EffectData()
				ed:SetOrigin(pos)
				ed:SetRadius(self.Radius)
				ed:SetNormal(self:GetAngles():Up())
				ed:SetMagnitude(1)
				ed:SetFlags(1)
				util.Effect("jcms_blast", ed)
				if self.Damage > 80 then
					util.Effect("Explosion", ed)
				else
					self:EmitSound("ambient/fire/gascan_ignite1.wav", 90)
				end
				self:Remove()
				
				util.BlastDamage(self, IsValid(self.jcms_owner) and self.jcms_owner or self, pos, self.Radius, self.Damage)

				if self.incendiary then 
					local selfPos = self:GetPos()
					local tr = util.TraceLine({
						start = selfPos + jcms.vectorUp,
						endpos = selfPos - Vector(0,0,250),
						mask = MASK_SOLID_BRUSHONLY
					})
					if tr.Hit then
						local fire = ents.Create("jcms_fire")
						fire:SetPos(tr.HitPos)
						fire:Spawn()

						fire:SetRadius(250)
						fire:SetActivationTime(CurTime() + 3)
						fire.dieTime = CurTime() + 23
					end
				end

				if IsValid(hitEntity) then
					local movetype = hitEntity:GetMoveType()
					local flying = movetype == MOVETYPE_FLY or movetype == MOVETYPE_FLYGRAVITY

					if flying or jcms.team_flyingEntityClasses[ hitEntity:GetClass() ] then
						local di = DamageInfo()
						di:SetDamage(self.Damage or 10)
						di:SetAttacker( IsValid(self.jcms_owner) and self.jcms_owner or self )
						di:SetInflictor(self)
						di:SetReportedPosition(self:GetPos())
						di:SetDamagePosition(self:GetPos())
						di:SetDamageForce(self:GetVelocity())
						di:SetDamageType( bit.bor(DMG_BLAST, DMG_AIRBOAT) )
						hitEntity:TakeDamageInfo(di)
					end
				end
			end
		end
	end

	function ENT:GetHackedByRebels() --todo: Jank.
		if not IsValid(self) then return false end

		local selfTbl = self:GetTable()
		return IsValid(selfTbl.jcms_owner) and not jcms.team_JCorp(selfTbl.jcms_owner)
	end
end

if CLIENT then
	ENT.mat = Material "effects/fire_cloud1.vtf"
	ENT.mat_glow = Material "sprites/light_glow02_add"
	ENT.mat_glow2 = Material "particle/Particle_Glow_04"

	function ENT:Think()
		local a = self:GetVelocity()
		
		if a:LengthSqr() > 4 then
			a:Normalize()
			a = a:Angle()
			self:SetAngles(a)
		end

		self:SetModel( "models/weapons/w_missile_closed.mdl" )
	end
	
	function ENT:Draw()
		local mypos = self:GetPos()
		local dist2 = jcms.EyePos_lowAccuracy:DistToSqr(self:GetPos())
		
		if dist2 < 1500*1500 then
			self:DrawModel()
			local a = self:GetAngles()
			local inormal = a:Forward()
			inormal:Mul(-1)
			
			local col = Color(math.random(250, 255), math.random(150, 200), 32)
			mypos:Add(inormal*12)
			render.SetMaterial(self.mat)
			render.DrawQuadEasy(mypos, inormal, math.Rand(4, 24), math.Rand(4, 24), col, math.random()*360)
			col.a = 50
			render.DrawSprite(mypos, math.Rand(32, 48), math.Rand(16, 24), col)
		end
		
		local frac = math.Clamp(math.Remap(dist2, 1500*1500, 1000*1000, 1, 0), 0, 1)
		if frac > 0 then
			local a = self:GetAngles()
			local inormal = a:Forward()
			frac = frac * math.Clamp(jcms.EyeFwd_lowAccuracy:Dot(inormal), 0.2, 1)
			local col = Color(math.random(250, 255), math.random(150, 200), 32)
			render.SetMaterial(self.mat_glow)
			render.DrawSprite(mypos, frac*400, frac*128, col)
		end
	end

	function ENT:DrawTranslucent()
		local selfTbl = self:GetTable()
		local colVector = selfTbl:GetBlinkColor()

		local period = selfTbl:GetBlinkPeriod()
		local flashfraction = 0.6
		local timefrac = ( (CurTime() + self:EntIndex()) / (period*flashfraction) ) % (1/flashfraction)
		local f = timefrac < 1 and math.ease.InQuart(1-timefrac) or 0 

		local col = Color(255*colVector.x, 255*colVector.y, 255*colVector.z, 255 * f)
		local colBright = Color( Lerp(f, 255*colVector.x, 255), Lerp(f, 255*colVector.y, 255), Lerp(f, 255*colVector.z, 255), 255*f )

		local norm = self:GetAngles():Up()
		norm:Rotate( selfTbl:GetBlinkDirection() )
		local selfPos = self:WorldSpaceCenter()
		local boundingRadius = self:BoundingRadius()
		local v1 = selfPos + norm * boundingRadius/6
		local v2 = selfPos + norm * boundingRadius*f

		local sizef = (f + 1)/2
		local scale = selfTbl:GetBlinkScale()
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.SetMaterial(self.mat_glow2)
			render.DrawSprite(v2, 96*scale*f, 32*scale*sizef, col)
			render.DrawQuadEasy(v1, norm, 32*scale*sizef, 24*scale*sizef, colBright, 0)
		render.OverrideBlend( false )
	end
end
