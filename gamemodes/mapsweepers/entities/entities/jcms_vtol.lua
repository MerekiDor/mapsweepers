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
ENT.PrintName = "DS-2 VTOL"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Damage = 15
ENT.Firerate = 0.07
ENT.Spread = 1.7

ENT.jcms_miningCrateAttaches = {
	Vector(-100,0,-30)
}

ENT.jcms_miningCrateAngles = { --UI ANGLES ONLY
	Angle(0,0,0)
}

function ENT:Initialize()
	self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)
	
	if SERVER then
		self:SetModel("models/jcms/jcorp_vtol.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:GetPhysicsObject():Wake()
		self:StartMotionController()
		self:AddEFlags(EFL_DONTBLOCKLOS)
		--self:AddFlags(FL_NOTARGET)
		
		self.soundEngine = CreateSound(self, "^thrusters/rocket00.wav")
		self.soundEngine:SetSoundLevel(150)
		self.soundEngine:Play()
		self.soundEngine:ChangePitch(0)
		
		self.soundTurbo = CreateSound(self, "^thrusters/jet02.wav")
		self.soundEngine:SetSoundLevel(150)
		self.soundTurbo:ChangePitch(0)
		self.soundTurbo:Play()
		
		self:SetMaxHealth(850)
		self:SetHealth(850)

		self.nextInteract = 0
		self:CreatePassengerSeats()
		self:SetUseType(SIMPLE_USE)

		self.jcms_attachedCrates = {}
	elseif CLIENT then 
		self.jetTransition = 0
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsWorking")
	self:NetworkVar("Bool", 1, "JetMode")
	self:NetworkVar("Float", 0, "Throttle")
	self:NetworkVar("Float", 1, "HealthFraction")
	self:NetworkVar("Entity", 0, "DriverEntity")
	self:NetworkVar("Int", 0, "MachinegunAmmo")

	for i=1, 6 do
		self:NetworkVar("Bool", 1+i, "SeatOccupied" .. i)
	end
	
	if SERVER then
		self:SetJetMode(false)
		self:SetIsWorking(true)
		self:SetHealthFraction(1)
		self:SetMachinegunAmmo(400)
		
		for i=1, 6 do
			self["SetSeatOccupied" .. i](false)
		end
	end
end

function ENT:UpdateForFaction(faction)
	for i, matname in ipairs(self:GetMaterials()) do
		self:SetSubMaterial(i-1, matname:gsub("jcorp_", tostring(faction) .. "_"))
	end
end

if SERVER then
	function ENT:Think()
		if self.jcms_destroyed or not self:GetIsWorking() then
			if self.soundTurbo then
				self.soundTurbo:Stop()
				self.soundTurbo = nil
			end
			
			if self.soundEngine then
				self:EmitSound("npc/turret_floor/die.wav", 75, 75)
				self.soundEngine:Stop()
				self.soundEngine = nil
			end
			
			if not self.jcms_destroyed and IsValid(self:GetPhysicsObject()) and IsValid(self:GetDriver()) and self:GetPhysicsObject():IsAsleep() then
				self:GetPhysicsObject():Wake()
			end
			

			if not self.despawning then
				for slot, _ in ipairs(self.jcms_miningCrateAttaches) do 
					local crate = self.jcms_attachedCrates[slot]
					if IsValid(crate) then 
						crate:DetachFromVehicle()
					end
				end
				self.jcms_attachedCrates = nil

				local despawnAfter = 15
				
				timer.Simple(despawnAfter, function()
					if IsValid(self) then
						local ed = EffectData()
						ed:SetColor(jcms.util_GetColorIntegerPvP(self))
						ed:SetFlags(2)
						ed:SetEntity(self)
						util.Effect("jcms_spawneffect", ed)
					end
				end)

				timer.Simple(despawnAfter + 2, function()
					if IsValid(self) then
						self:Remove()
					end
				end)

				self.despawning = true
			end
		else
			for i=1,6 do
				self["SetSeatOccupied" .. i](self, IsValid(self.seats[i]) and IsValid(self.seats[i]:GetDriver()))
			end
			
			local speed = self:GetVelocity():Length()
			if self.soundEngine then
				self.soundEngine:ChangePitch(90 + speed/1000*120, 0.1)
			end
			
			if self.soundTurbo then
				self.soundTurbo:ChangePitch(math.Clamp((speed-150)/8, 75, 150), 0.1)
			end
			
			local driver = self:GetDriver()
			if IsValid(driver) then
				driver:SetPos(self:GetPos())
				
				local wep = driver:GetActiveWeapon()
				if IsValid(wep) then
					wep:SetNextPrimaryFire( CurTime() + 1 )
					wep:SetNextSecondaryFire( CurTime() + 1 )
				end
				
				if self:GetPhysicsObject():IsAsleep() then
					self:GetPhysicsObject():Wake()
				end
			end
			
			self:NextThink(CurTime() + 0.1)
			return true
		end
	end
	
	function ENT:OnRemove()
		self:SetDriver()
		self:StopMotionController()
		
		if self.soundEngine then
			self.soundEngine:Stop()
		end
		
		if self.soundTurbo then
			self.soundTurbo:Stop()
		end
		
		if self.soundCrashing then
			self.soundCrashing:Stop()
		end
		
		if self.soundCrashed then
			self.soundCrashed:Stop()
		end
	end
	
	function ENT:CreatePassengerSeats()
		if self.seats then
			for i, seat in ipairs(self.seats) do
				if IsValid(seat) then
					seat:Remove()
				end
			end
			
			table.Empty(self.seats)
		else
			self.seats = {}
		end
		
		local i = 0
		for side=1,2 do
			for seat=1,3 do
				i = i + 1
				local ent = ents.Create("prop_vehicle_prisoner_pod")
				local ang = self:GetAngles()
				
				ang:RotateAroundAxis(ang:Up(), side==1 and 0 or 180)
				ent:SetPos(self:GetPos() + ang:Up()*-22 + ang:Right()*-72 + ang:Forward()*( (side == 1 and 1 or -1)*(32*seat - 40) ))
				ent:SetAngles(ang)
				
				ent:SetModel("models/nova/airboat_seat.mdl")
				ent:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
				ent:SetKeyValue("limitview", "0")
				
				ent:SetParent(self)
				ent:Spawn()
				ent:Activate()
				
				local seatPhys = ent:GetPhysicsObject()
				ent:SetMoveType(MOVETYPE_PUSH)
				ent:SetNotSolid(true)
				ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
				seatPhys:Sleep()
				seatPhys:EnableMotion(false)
				seatPhys:EnableCollisions(false)
				seatPhys:EnableGravity(false)
				seatPhys:SetMass(1)
				ent:CollisionRulesChanged()
				ent:DrawShadow(false)
				
				self.seats[i] = ent
			end
		end
	end
	
	function ENT:Shoot()
		local driver = self:GetDriver()
		if not IsValid(driver) then return end 

		if self:GetMachinegunAmmo() > 0 then
			self:EmitSound("Weapon.jcms_mg")
			local v, a = self:GetTurretShootPos(), self:GetTurretAngleFromDriver(driver, true)
			
			local spread = math.random()*self.Spread
			local spreadAng = math.random()*math.pi*2
			
			a.p = a.p + math.cos(spreadAng)*spread
			a.y = a.y + math.sin(spreadAng)*spread
			local tr = util.TraceLine { start = v, endpos = v + a:Forward()*5000, filter = self, mask = MASK_SHOT }
			
			local effectdata = EffectData()
			effectdata:SetStart(tr.StartPos)
			effectdata:SetScale(math.random(6500, 9000))
			effectdata:SetAngles(tr.Normal:Angle())
			effectdata:SetOrigin(tr.HitPos)
			effectdata:SetFlags(2)
			util.Effect("jcms_bolt", effectdata)
			
			if IsValid(tr.Entity) then
				local dmgInfo = DamageInfo()
				dmgInfo:SetAttacker(driver)
				dmgInfo:SetInflictor(self)
				dmgInfo:SetDamage(self.Damage)
				dmgInfo:SetDamageType(DMG_BULLET)
				dmgInfo:SetReportedPosition(v)
				dmgInfo:SetDamagePosition(tr.HitPos)
				dmgInfo:SetDamageForce(tr.Normal)
				tr.Entity:DispatchTraceAttack(dmgInfo, tr, tr.Normal)
			end

			local dmgInfo = DamageInfo()
			dmgInfo:SetAttacker(driver)
			dmgInfo:SetInflictor(self)
			dmgInfo:SetDamage(self.Damage / 2)
			dmgInfo:SetDamageType(DMG_BLAST)
			dmgInfo:SetReportedPosition(v)
			dmgInfo:SetDamagePosition(tr.HitPos)
			util.BlastDamageInfo( dmgInfo, tr.HitPos, 75 )
			
			self:SetMachinegunAmmo(self:GetMachinegunAmmo() - 1)
		else
			self:EmitSound("Weapon_Pistol.Empty")
		end
	end
	
	function ENT:PhysicsSimulate(phys, dt)
		if self.jcms_destroyed then
			if IsValid(self:GetDriver()) then
				self:SetDriver()
			end
			return
		end
		
		local crashtime = self.jcms_crashtime and (CurTime() - self.jcms_crashtime) or 0
		
		local driver = self:GetDriver()
		if not self:GetIsWorking() and IsValid(driver) then
			if driver:KeyDown(IN_USE) and CurTime() > self.nextInteract then
				self:SetDriver()
				self.nextInteract = CurTime() + 1
			end
			
			return
		end

		local mass = phys:GetMass()
		local mypos = self:GetPos()
		local myang = self:GetAngles()
		
		local damp = math.max(0, 0.034 - crashtime*0.011)
		
		local curAV = phys:GetAngleVelocity()
		
		local curVel = phys:GetVelocity()
		local sideVel = phys:GetVelocity():Dot(myang:Right())
		local fwdVel = phys:GetVelocity():Dot(myang:Forward())
		local upVel = phys:GetVelocity():Dot(myang:Up())
		
		if bit.band( util.PointContents(mypos), CONTENTS_WATER ) > 0 then
			self:SetIsWorking(false)
			return -curAV*0.5, -curVel*0.5
		end
		
		local addUp = 0
		local addFwd = 0
		local addLeft = 0
		
		local addPitch = 0
		local addYaw = 0
		local addRoll = 0
		
		local jetMode = false
		local throttle = 0
		
		if IsValid(driver) then
			if driver:KeyDown(IN_USE) and CurTime() > self.nextInteract then
				self:SetDriver()
				self.nextInteract = CurTime() + 1
			else
				jetMode = driver:KeyDown(IN_SPEED)
				
				if driver:KeyDown(IN_FORWARD) then
					addFwd = 1
				elseif driver:KeyDown(IN_BACK) then
					addFwd = -1
				end
				
				if driver:KeyDown(IN_MOVERIGHT) then
					addLeft = 1
				elseif driver:KeyDown(IN_MOVELEFT) then
					addLeft = -1
				end
				
				throttle = throttle + math.Distance(addFwd, addLeft, 0, 0)/3
				
				if driver:KeyDown(IN_JUMP) then
					addUp = 1
					throttle = throttle + 0.4
				elseif driver:KeyDown(IN_DUCK) then
					addUp = -1
					throttle = throttle - 0.1
				end
				
				if jetMode then
					throttle = 1
				end
				
				if self.attacking1 then
					local t = CurTime()
					if not self.nextAttack or (t > self.nextAttack) then
						self.nextAttack = t + self.Firerate
						self:Shoot()
					end
				end
			end
			
			local intendedAngle = driver:EyeAngles()
			addPitch = math.AngleDifference(intendedAngle.p, myang.p) - curAV:Dot(myang:Right()) * 0.23
			addYaw = math.AngleDifference(intendedAngle.y, myang.y) - curAV:Dot(myang:Up()) * 0.23
			addRoll = math.AngleDifference(intendedAngle.r, myang.r) - curAV:Dot(myang:Forward()) * 0.23
		end
		
		local responsiveness = crashtime > 1 and math.max(0, 1 - (crashtime-1)*0.1) or 1
		if responsiveness < 1 then
			addFwd = Lerp(responsiveness, 0.6, addFwd)
			addLeft = Lerp(responsiveness, addLeft*0.1, addLeft)
			addUp = Lerp(responsiveness, addUp*0.1, addUp)
			
			addPitch = Lerp(responsiveness, math.cos( CurTime() )*18, addPitch)
			addRoll = Lerp(responsiveness, math.sin( CurTime() )*18, addRoll)
			addYaw = Lerp(responsiveness, math.Rand(-1, 1)*18, addYaw)
			
			curAV:Mul(responsiveness)
		end
		
		if math.abs(self:GetThrottle() - throttle) > 0.05 then
			self:SetThrottle(throttle)
		end
		
		if self:GetJetMode() ~= jetMode then
			self:SetJetMode(jetMode)
		end
		
		local gravity = physenv.GetGravity()
		
		if jetMode then
			damp = math.max(0, 0.01 - crashtime*0.0011)
			local speed = Lerp(responsiveness, 1, 15)
			local apower = Lerp(responsiveness, 0.003, 0.06)
			local gravresist = gravity:Dot(myang:Forward()) * responsiveness
			
			return Vector(-curAV.x + addRoll*mass*dt*apower, -curAV.y + addPitch*mass*dt*apower, -curAV.z + addYaw*mass*dt*apower), Vector(speed*mass*dt - gravresist, sideVel*mass*dt*damp - addLeft*mass*dt*speed/4, -upVel*mass*dt*damp + addUp*mass*dt*speed/4 - gravity.z*mass/34*dt), SIM_LOCAL_ACCELERATION
		else
			curAV.x = curAV.x + myang.roll*mass*dt*0.4
			curAV.y = curAV.y + myang.pitch*mass*dt*0.4
			
			local speed = 9
			local len = math.max(1, math.sqrt(addUp*addUp + addFwd*addFwd + addLeft*addLeft))
			
			addUp = addUp/len*speed
			addFwd = addFwd/len*speed
			addLeft = addLeft/len*speed
			
			local clampedAddYaw = (addYaw > 0 and 1 or -1) * math.abs(addYaw)^0.8
			return Vector(-curAV.x-clampedAddYaw*mass*dt*0.1+addLeft*mass*dt*0.3, -curAV.y+addFwd*mass*dt*0.3, -curAV.z + clampedAddYaw*mass*dt*0.1), Vector(-fwdVel*mass*dt*damp + addFwd*mass*dt, sideVel*mass*dt*damp - addLeft*mass*dt, -upVel*mass*dt*damp - gravity.z*mass/34*dt + addUp*mass*dt), SIM_LOCAL_ACCELERATION
		end
	end
	
	function ENT:PhysicsCollide(data, phys)
		if self.jcms_crashtime and not self.jcms_destroyed and data.HitEntity:IsWorld() then
			util.ScreenShake(data.HitPos, 10, 35, math.Rand(1.7, 2.6), 660, true)
			
			local allPlayers = RecipientFilter()
			allPlayers:AddAllPlayers()
			self:EmitSound("jcms_droppod_land", 75, 100, 1, CHAN_AUTO, 0, 0, allPlayers)
			self:EmitSound("npc/combine_gunship/gunship_explode2.wav", 150, 110)

			if self.soundCrashing then
				self.soundCrashing:Stop()
			end
			
			local ed = EffectData()
			ed:SetOrigin(data.HitPos)
			ed:SetScale(400)
			ed:SetEntity(self)
			util.Effect("ThumperDust", ed)
			util.BlastDamage(self, self, data.HitPos, 300, 15)
			
			local ed = EffectData()
			ed:SetMagnitude(1.3)
			ed:SetOrigin(data.HitPos)
			ed:SetRadius(600)
			ed:SetNormal(data.HitNormal)
			ed:SetFlags(1)
			util.Effect("jcms_bigblast", ed)
			util.Effect("Explosion", ed)
			
			self.jcms_destroyed = true
			self:SetIsWorking(false)
			
			self:SetDriver()
			
			self.soundCrashed = CreateSound(self, "ambient/gas/steam2.wav")
			self.soundCrashed:PlayEx(75, 90)
			
			timer.Simple(0, function()
				if IsValid(self) then
					self:SetPos(LerpVector(0.6, self:GetPos(), data.HitPos))
					self:PhysicsInitStatic(SOLID_VPHYSICS)
					self:StopMotionController()
				end
			end)
		elseif data.Speed > 10 then
			if data.Speed > 150 then
				local dmg = DamageInfo()
				dmg:SetAttacker(game.GetWorld())
				dmg:SetInflictor(game.GetWorld())
				dmg:SetDamageType(DMG_CRUSH)
				dmg:SetDamage(data.Speed / 17)
				dmg:SetDamagePosition(data.HitPos)
				dmg:SetDamageForce(data.HitNormal*data.Speed)
				self:TakeDamageInfo(dmg)
			end
			
			if data.Speed > 1300 then
				self:EmitSound("ATV_rollover")
			elseif data.Speed > 600 then
				self:EmitSound("ATV_impact_heavy")
			else
				self:EmitSound("ATV_impact_medium")
			end
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		if self.jcms_destroyed or self.jcms_crashtime then return end
		
		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then
				jcms.util_PerformRepairs(self, attacker, 20)
				self:SetHealthFraction(self:Health()/self:GetMaxHealth())
				return 0
			end
		end

		local dmgAmount = dmg:GetDamage()
		local difficultyMultiplier = IsValid(self:GetDriver()) and (1 / (math.max(jcms.runprogress_GetDifficulty(), 1)^0.75)) or 1
		dmgAmount = dmgAmount * difficultyMultiplier

		if bit.band( dmg:GetDamageType(), bit.bor(DMG_BUCKSHOT, DMG_BULLET) ) > 0 then
			dmgAmount = math.max(math.min(dmgAmount, 0.1), dmgAmount - 2)
		end
		
		self:SetHealth( self:Health() - dmgAmount )
		self:SetHealthFraction(math.max(0, self:Health() / self:GetMaxHealth()))
		
		self:TakePhysicsDamage(dmg)
		if self:Health() <= 0 then
			self.soundCrashing = CreateSound(self, "npc/combine_gunship/gunship_crashing1.wav")
			self.soundCrashing:PlayEx(100, 100)
			self.soundCrashing:SetSoundLevel(150)
			
			for i=1, math.random(3, 4) do
				timer.Simple(2/i + math.Rand(-0.2, 0.1), function()
					if IsValid(self) then
						local ed = EffectData()
						ed:SetMagnitude(1)
						ed:SetOrigin(self:WorldSpaceCenter() + VectorRand(-128, 128))
						ed:SetRadius(150)
						ed:SetNormal(self:GetAngles():Up())
						ed:SetFlags(1)
						util.Effect("jcms_blast", ed)
						util.Effect("Explosion", ed)
					end
				end)
			end
			
			self.jcms_crashtime = CurTime()
		end
	end
	
	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and (not jcms.team_JCorp_player(activator)) then return end
		
		if not IsValid(activator:GetNWEntity("jcms_vehicle")) and (not self.jcms_destroyed) and (self:GetIsWorking()) then
			local driver = self:GetDriver()
			if IsValid(driver) then
				local activatorPos = activator:WorldSpaceCenter()
				local best, mindist2 = nil, 1024*1024
				
				for i, seat in ipairs(self.seats) do
					if IsValid(seat) and not IsValid(seat:GetDriver()) then
						local dist2 = seat:WorldSpaceCenter():DistToSqr(activatorPos)
						if dist2 < mindist2 then
							mindist2 = dist2
							best = seat
						end
					end
				end
				
				if IsValid(best) then
					activator:EnterVehicle(best)
					best:EmitSound("physics/body/body_medium_impact_soft3.wav")
					self.nextInteract = CurTime() + 0.25
					
					for i=1,6 do
						self["SetSeatOccupied" .. i](IsValid(self.seats[i]) and IsValid(self.seats[i]:GetDriver()))
					end
				end
			elseif (CurTime() > self.nextInteract) then
				self:SetDriver(activator)
				self.nextInteract = CurTime() + 1
			end
		end
	end

	function ENT:GetExitPos()
		local driver = self:GetDriver()
		local filter = { self, driver }
		local angle = self:GetAngles()
		
		local pos = self:GetPos()
		pos.z = pos.z - 54
		
		local tr
		-- Check sides first. If the drop is safe, dismount the player there
		for i=1,4 do
			local v = pos + angle:Right()*( (i>=3 and -1 or 1)*110 ) + angle:Forward()*(i%2 == 0 and 70 or -50)
			
			tr = util.TraceHull {
				start = pos, endpos = v, filter = filter, mins = driver:OBBMins(), maxs = driver:OBBMaxs(), mask = MASK_PLAYERSOLID
			}
			
			if not tr.Hit then
				tr = util.TraceHull {
					start = v, endpos = v + Vector(0, 0, -220), filter = filter, mins = driver:OBBMins(), maxs = driver:OBBMaxs(), mask = MASK_PLAYERSOLID
				}
				
				if tr.HitWorld then
					return v
				end
			end
		end
		
		-- We're probably midair. Let's try to dismount on top of the VTOL.
		pos.z = pos.z + 54
		for i=1, 3 do
			local v = Vector(pos.x, pos.y, pos.z + self:OBBMaxs().z + 8)
			
			if i > 1 then
				v:Add( angle:Forward() * ( -72 * (i-1) ) )
			end
			
			pos.x, pos.y = v.x, v.y
			
			tr = util.TraceHull {
				start = pos, endpos = v, filter = filter, mins = driver:OBBMins(), maxs = driver:OBBMaxs(), mask = MASK_PLAYERSOLID
			}
			
			if not tr.Hit then
				return v
			end
		end
		
		-- One last thing, let's just drop the driver from the cargo hatch
		pos = self:GetPos()
		local v = pos + -90*angle:Forward() + -70*angle:Up()
		
		tr = util.TraceHull {
			start = pos, endpos = v, filter = filter, mins = driver:OBBMins(), maxs = driver:OBBMaxs(), mask = MASK_PLAYERSOLID
		}

		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end

		return pos
	end
	
	function ENT:SetDriver(ply)
		-- Carjacking
		local driver = self:GetDriver()
		if IsValid(driver) and driver:IsPlayer() then
			driver:SetMoveType(MOVETYPE_WALK)
			driver:DrawViewModel(true)
			driver:DrawWorldModel(true)
			driver:SetNoDraw(false)
			driver:SetNWEntity("jcms_vehicle", NULL)
			
			if ply == nil then
				driver:SetPos(self:GetExitPos())
				driver.noFallDamage = true
				driver:EmitSound("physics/body/body_medium_impact_soft3.wav")
			end

			local ea = driver:EyeAngles()
			ea.r = 0
			driver:SetEyeAngles(ea)

			self:SetDriverEntity(NULL)
		end
		
		if IsValid(ply) and ply:IsPlayer() and ply:GetNWEntity("jcms_vehicle") == NULL then
			self:SetDriverEntity(ply)
			ply:SetMoveType( MOVETYPE_NOCLIP )
			ply:DrawViewModel(false)
			ply:DrawWorldModel(false)
			ply:SetNoDraw(true)
			ply:SetNWEntity("jcms_vehicle", self)
			ply:SetEyeAngles(self:GetAngles())
			self:EmitSound("physics/body/body_medium_impact_soft4.wav")
		end
	end

	function ENT:RedirectDamage(driver, dmg)
		self:TakeDamageInfo( dmg )
		dmg:SetDamage(0)
	end
end

if CLIENT then
	ENT.mat_light = Material "particle/fire"
	ENT.mat_pointer = Material "effects/spark"
	ENT.mat_ring = Material "effects/select_ring"
	ENT.mats_flame = {}
	
	for i=1, 5 do
		local mat = Material("particles/flamelet" .. i)
		ENT.mats_flame[i] = mat
	end
	
	function ENT:DrawTranslucent()
		if self:GetIsWorking() then
			local col = Color(0, 150, 255)
			local col2 = Color(0, 100, 255)
			local frame = ( CurTime()*6 )%1
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			local throttle = self.throttle or 0
			
			for wing=1, 2 do
				local boneId = self:LookupBone( "wing_" .. (wing==1 and "right" or "left") )
				if boneId then
					local v, a = self:GetBonePosition(boneId)
					local normal = a:Forward()*(wing==1 and -1 or 1)
					v:Add(a:Right()*182 + a:Up()*-11 + normal*40)
					
					render.SetMaterial(self.mat_light)
					render.DrawSprite(v, 230, 120, col)
					
					v:Add(normal*-20)
					local v2 = v + normal*20
					local v3 = v + normal*Lerp(throttle, 32, 128)
					
					render.SetMaterial(self.mat_light)
					render.DrawQuadEasy(v2, normal, 400, 300, col2)
					
					local mat = self.mats_flame[ math.floor(frame*#self.mats_flame+1) ]
					render.SetMaterial(mat)
					render.DrawBeam(v, v3, 48, 0.3, 1, col)
				end
			end
			render.OverrideBlend( false )
		end
	end
	
	function ENT:OnRemove()
		if self.soundAlarm then
			self.soundAlarm:Stop()
		end
		
		if self.soundWater then
			self.soundWater:Stop()
		end
	end
	
	function ENT:Think()
		if FrameTime() <= 0 then return end
		local targetThrottle = 0
		
		local onWater = false
		if self:GetIsWorking() then
			local driver = self:GetDriver()
			if IsValid(driver) then
				local boneId = self:LookupBone("gun")
				if boneId then
					local ang = self:GetTurretAngleFromDriver(driver)
					self:ManipulateBoneAngles(boneId, ang)
				end
			end
			
			self.jetTransition = math.Approach(self.jetTransition or 0, self:GetJetMode() and 1 or 0, FrameTime()*2)
			
			local t = CurTime()
			
			local vel = self:GetVelocity()
			local angvel = self:GetLocalAngularVelocity()
			
			local ang = self:GetAngles()
			
			local fwd = ang:Forward()
			local right = ang:Right()
			
			local fwdVel = vel:Dot(fwd)
			local rightVel = vel:Dot(right)
			
			right:Mul(200)
			local speed = 500
			local fwdSpeedFrac = 1-speed/(fwdVel+speed)
			local rightSpeedFrac = 1-speed/(rightVel+speed)
			
			for wing=1, 2 do
				local pos = self:GetPos()
				pos:Add(right)
				
				local boneId = self:LookupBone( "wing_" .. (wing==1 and "right" or "left") )
				if boneId then
					local ang = Angle(
						Lerp(math.ease.InCubic(self.jetTransition), 32*fwdSpeedFrac, 90)*(wing==1 and -1 or 1),
						math.Clamp(24*rightSpeedFrac, -1.5, 1.5) + math.sin(t*16)*0.2+math.Rand(-0.3, 0.3), 
						math.cos(t*16)*0.2+math.Rand(-0.3, 0.3)
					)
					
					self:ManipulateBoneAngles(boneId, ang)
					
					local rang = self:GetAngles()
					local up, fwd, right = rang:Up(), rang:Forward(), rang:Right()
					rang:RotateAroundAxis(right, ang.p*(wing==1 and 1 or -1))
					rang:RotateAroundAxis(fwd, ang.y)
					rang:RotateAroundAxis(up, ang.r)
					
					local tr = util.TraceLine { 
						start = pos, 
						endpos = pos + rang:Up() * -700, 
						mask = bit.bor(MASK_WATER, MASK_SHOT_HULL), 
						filter = self 
					}
					
					if tr.MatType == MAT_SLOSH then
						onWater = onWater or true
							
						if (FrameNumber() + wing)%10 == 0 then
							local ed = EffectData()
							ed:SetOrigin(tr.HitPos)
							ed:SetScale(Lerp(tr.Fraction, 20, 35))
							ed:SetMagnitude(0.1)
							util.Effect("waterripple", ed)
						end
					end
				end
				
				if wing == 1 then
					right:Mul(-1)
				end
			end
			
			targetThrottle = self:GetThrottle()
			local dist = self:WorldSpaceCenter():Distance(EyePos())
			local distFrac = math.Clamp(1 - (dist / 1000), 0, 1)
			
			if distFrac > 0 then
				util.ScreenShake(jcms.vectorOrigin, Lerp(self.throttle or 0, 1, 2)*distFrac*1.4, 5, 0.1, 512, true)
			end
		end
		
		if onWater then
			if not self.soundWater then
				self.soundWater = CreateSound(self, "vehicles/airboat/pontoon_fast_water_loop1.wav")
				self.soundWater:PlayEx(1, 1)
			end
			
			self.soundWater:ChangePitch(80)
		else
			if self.soundWater then
				self.soundWater:Stop()
				self.soundWater = nil
			end
		end
		
		local healthFrac = self:GetHealthFraction()
		if healthFrac > 0 and healthFrac <= 0.4 then
			if not self.soundAlarm then
				self.soundAlarm = CreateSound(self, "npc/attack_helicopter/aheli_crash_alert2.wav")
				self.soundAlarm:PlayEx(100, 105)
			end
		else
			if self.soundAlarm then
				self.soundAlarm:Stop()
				self.soundAlarm = nil
			end
		end
		
		local hfrac = healthFrac^5
		if FrameTime() > 0 and math.random() < (hfrac<=0 and 0.75 or (1 - hfrac)*0.25)*0.2 then
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter() + VectorRand(-16, 16))
			ed:SetMagnitude(1-hfrac)
			ed:SetScale(2-hfrac)
			ed:SetRadius(10-hfrac)
			ed:SetNormal(VectorRand())
			util.Effect("Sparks", ed)
		end
		
		local W = 7
		self.throttle = ((self.throttle or 0)*W + targetThrottle)/(W+1)
	end
	
	function ENT:CalcViewDriver(ply, origin, angles, fov, znear, zfar)
		local mypos = self:GetPos()
		local myang = self:GetAngles()
		local speed = self:GetVelocity():Length()
		
		local tr = math.ease.InOutQuart(1-self.jetTransition)
		
		fov = fov * Lerp(tr, 0.9, 0.67)
		origin = mypos + myang:Up()*Lerp(tr, 30, 60) + angles:Forward() * Lerp(tr, -400, -500) + angles:Up() * 72 + angles:Right() * 100 * tr
		angles.roll = math.AngleDifference(angles.roll, -myang.roll)*0.25
		
		return {
			origin = origin,
			angles = angles,
			fov = fov,
			
			znear = znear,
			zfar = zfar,
			
			drawviewer = false
		}
	end
	
	function ENT:DrawHUDBottom()
		local healthWidth = 700
		local healthFrac = math.Clamp(self:GetHealthFraction(), 0, 1)
		local off = 6
		surface.SetDrawColor(jcms.color_dark)
		surface.DrawRect(-healthWidth/2, -114, healthWidth, 32)

		local maxammo = 400
		local ammoString = self:GetMachinegunAmmo() .. " / " .. maxammo
		draw.SimpleText(ammoString, "jcms_hud_medium", 0, -150, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		
		local baseX = 260

		surface.DrawRect(healthWidth/2+baseX, -200, 64, 64)
		surface.DrawRect(healthWidth/2+baseX+200, -200, 64, 64)
		surface.DrawRect(healthWidth/2+baseX+100, -210, 64, 120)
		surface.DrawRect(healthWidth/2+baseX+100+8, -90, 48, 64)
		do
			local i = 0
			for side=1,2 do
				for seat=1,3 do
					i = i + 1
					local occupied = self["GetSeatOccupied"..i]()
					if occupied then
						surface.DrawRect(healthWidth/2+baseX + (side == 1 and -64 or 290), -48-seat*64, 48, 48)
					else
						surface.DrawOutlinedRect(healthWidth/2+baseX + (side == 1 and -64 or 290), -48-seat*64, 48, 48, 4)
					end
				end
			end
		end

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			surface.SetDrawColor(jcms.color_pulsing)
			surface.DrawRect(-256, -64, 512, 6)
			surface.DrawRect(-400, -64+16, 800, 4)
			surface.SetDrawColor(healthFrac < 0.4 and jcms.color_alert or jcms.color_bright)
			jcms.hud_DrawStripedRect(-healthWidth/2, -114-off+2, healthWidth, 32-4)
			surface.DrawRect(-healthWidth/2, -114-off, healthWidth*healthFrac, 32)

			draw.SimpleText(ammoString, "jcms_hud_medium", 0, -150-off, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

			surface.DrawRect(healthWidth/2+baseX+off, -200-off, 64, 64)
			surface.DrawRect(healthWidth/2+baseX+200+off, -200-off, 64, 64)
			surface.DrawRect(healthWidth/2+baseX+100+off, -210-off, 64, 120)
			surface.DrawRect(healthWidth/2+baseX+100+8+off, -90-off, 48, 64)

			local i = 0
			for side=1,2 do
				for seat=1,3 do
					i = i + 1
					local occupied = self["GetSeatOccupied"..i]()
					if occupied then
						surface.SetDrawColor(jcms.color_bright_alt)
						surface.DrawRect(healthWidth/2+baseX+off + (side == 1 and -64 or 290), -48-seat*64, 48, 48, 4)
					else
						surface.SetDrawColor(jcms.color_bright)
						surface.DrawOutlinedRect(healthWidth/2+baseX+off + (side == 1 and -64 or 290), -48-seat*64, 48, 48, 4)
					end
				end
			end
		render.OverrideBlend( false )
	end
	
	function ENT:DrawHUD()
		if self:GetMachinegunAmmo() <= 0 then return end

		local v, a = self:GetTurretShootPos(), self:GetTurretAngleFromDriver(LocalPlayer(), true)
		
		local tr = util.TraceLine { start = v, endpos = v + a:Forward()*5000, filter = self, mask = MASK_SHOT }
		cam.Start3D()
			local t = CurTime()
			render.SetMaterial(self.mat_pointer)
			render.DrawBeam(tr.StartPos, tr.HitPos, 12, -0.1, 1.1, jcms.color_bright_alt)
			
			render.SetMaterial(self.mat_ring)
			render.DrawSprite(tr.HitPos, 64, 64, jcms.color_bright_alt)
			tr.HitPos:Add(tr.HitNormal)
			render.DrawQuadEasy(tr.HitPos, tr.HitNormal, 48, 48, jcms.color_bright_alt)
		cam.End3D()
	end
end

function ENT:GetDriver()
	return self:GetDriverEntity()
end

function ENT:GetTurretShootPos()
	local boneId = self:LookupBone("gun")
	if boneId then
		local v, a = self:GetBonePosition(boneId)
		return v + a:Right()*-50
	else
		return self:GetPos()
	end
end

function ENT:GetTurretAngleFromDriver(driver, global)
	local realAng = self:GetAngles()
	local ang = driver:EyeAngles()
	ang:Sub(realAng)
	ang:Normalize()
	ang.p = math.Clamp(ang.p, -25, 85)
	
	if global then
		ang:Add(realAng)
	else
		ang.r = ang.p
		ang.p = 0
		ang.y = -ang.y
	end
	return ang
end
