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
ENT.PrintName = "APC"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
	ENT.vectorOffsets = {
		{ -58, -50 },
		{ 65, -50 },

		{ -58, 50 },
		{ 65, 50 }
	}
end

ENT.jcms_miningCrateAttaches = {
	Vector(0,80,0),
	Vector(0,-80,0),
}

ENT.jcms_miningCrateAngles = { --UI ANGLES ONLY
	Angle(0,0,0),
	Angle(180,0,0)
}

function ENT:Initialize()
	self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)
	
	if SERVER then
		self:SetModel("models/jcms/jcorp_apc.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:GetPhysicsObject():Wake()
		self:StartMotionController()
		
		self.soundEngine = CreateSound(self, "plats/elevator_move_loop1.wav")
		self.soundEngine:Play()
		self.soundEngine:ChangePitch(82)
		self.soundTurbo = CreateSound(self, "vehicles/airboat/fan_motor_fullthrottle_loop1.wav")
		self.soundTurbo:Play()
		self.soundTurbo:ChangePitch(12)
		self.soundWater = CreateSound(self, "vehicles/airboat/pontoon_fast_water_loop1.wav")
		
		self:SetMaxHealth(1250)
		self:SetHealth(1250)

		self:AddEFlags(EFL_DONTBLOCKLOS)
		--self:AddFlags(FL_NOTARGET)

		self.nextInteract = 0
		self:SetUseType(SIMPLE_USE)

		self.delayedForces = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }

		local selfPos = self:WorldSpaceCenter()
		local selfAng = self:GetAngles()

		self.jcms_bullseyes = {}
		for x=1, 3 do
			for y=1, 2 do
				local bs = ents.Create("jcms_bullseye")
				bs:SetParent(self)
				bs:SetPos(selfPos + Vector(-200+100*x, -80+(y-1)*160, -25))
				bs.DamageTarget = self
				bs:Spawn()

				bs:AddFlags(FL_NOTARGET)
				bs:SetModel("models/hunter/plates/plate.mdl") --These can get in the way of entering the APC and this is basically only for zombies/ants, so smaller is better.

				table.insert(self.jcms_bullseyes, bs)
			end
		end

		constraint.Keepupright( self, angle_zero, 0, 3 )
		self.PassengersAPC = {}
		
		self.jcms_attachedCrates = {}
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "PassengerCount")
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "ShieldPower")
	self:NetworkVar("Bool", 0, "IsDestroyed")
	self:NetworkVar("Bool", 1, "ShieldReady")
	self:NetworkVar("Bool", 2, "ShieldActive")
	if SERVER then
		self:SetHealthFraction(1)
		self:SetIsDestroyed(false)
		self:SetShieldReady(true)
		self:SetShieldPower(1)
	end
end

function ENT:UpdateForFaction(faction)
	if self:Health() <= 0 then
		self:SetMaterial("models/jcms/"..faction.."_apc_destroyed")
	else
		for i, matname in ipairs(self:GetMaterials()) do
			self:SetSubMaterial(i-1, matname:gsub("jcorp_", tostring(faction) .. "_"))
		end
	end
end

if SERVER then
	ENT.HoverDistance = 92
	ENT.Speed = 485
	ENT.SpeedTurbo = 690
	ENT.TurnSpeed = 130
	ENT.TurnSpeedTurbo = 110
	ENT.SpeedLooseMul = 0.772
	ENT.MoveTurnSpeedMul = 0.9
	ENT.MaxDampForce = 3000
	ENT.ShieldDuration = 8
	ENT.ShieldRechargeTime = 15

	function ENT:Think()
		local selfTbl = self:GetTable()
		if selfTbl.jcms_destroyed then
			if selfTbl.GetShieldActive(self) then
				selfTbl.SetShieldActive(self, false)
				selfTbl.SetShieldPower(self, 0)
			end

			if self.soundEngine then
				self.soundEngine:Stop()
				self.soundEngine = nil
			end

			if self.soundTurbo then
				self.soundTurbo:Stop()
				self.soundTurbo = nil
			end
			
			if self.soundWater then
				self.soundWater:Stop()
				self.soundWater = nil
			end

			if not self.despawning then	
				for slot, _ in ipairs(self.jcms_miningCrateAttaches) do 
					local crate = self.jcms_attachedCrates[slot]
					if IsValid(crate) then 
						crate:DetachFromVehicle()
					end
				end
				self.jcms_attachedCrates = nil

				local despawnAfter = 7
				
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
			self:GetPhysicsObject():Wake()
			local speed = self:GetVelocity():Length()
			if selfTbl.soundEngine then
				selfTbl.soundEngine:ChangePitch(75 + speed/300*20, 0.1)
			end

			if selfTbl.soundTurbo then
				selfTbl.soundTurbo:ChangePitch(32 + speed/10, 0.1)
			end
			
			if selfTbl.soundWater then
				if selfTbl.onWater then
					if not selfTbl.soundWater:IsPlaying() then
						selfTbl.soundWater:Play()
						selfTbl.soundWater:ChangeVolume(0)
					end
					
					selfTbl.soundWater:ChangeVolume(1, 0.1)
				else
					if selfTbl.soundWater:IsPlaying() and selfTbl.soundWater:GetVolume() <= 0 then
						selfTbl.soundWater:Stop()
					else
						selfTbl.soundWater:ChangeVolume(0, 0.1)
					end
				end
				
				selfTbl.soundWater:ChangePitch(math.Clamp(speed/300*90 + 90, 0, 125), 0.1)
			end
			
			local driver = selfTbl.GetDriver(self)
			if IsValid(driver) then
				driver:SetPos(self:GetPos())
				
				local wep = driver:GetActiveWeapon()
				if IsValid(wep) then
					wep:SetNextPrimaryFire( CurTime() + 1 )
					wep:SetNextSecondaryFire( CurTime() + 1 )
				end

				local roll = driver:EyeAngles().r
				if math.abs(roll) > 160 then
					jcms.director_TryShowTip(driver, jcms.HINT_FLIPOVER)
				end

				local range = 230 + math.min(500, speed/3)
				if speed > 230 then
					sound.EmitHint(SOUND_DANGER, self:GetPos(), range, 0.1, self)
				end
			end

			for i=#self.PassengersAPC, 1, -1 do
				local ply = self.PassengersAPC[i]
				if IsValid(ply) then
					if ply:KeyDown(IN_USE) and (CurTime() - (ply.jcms_lastEnteredAsPassenger or 0)) > 1 then
						self:RemovePassenger(ply)
					else
						ply:SetPos(self:GetPos())
					
						local wep = ply:GetActiveWeapon()
						if IsValid(wep) then
							wep:SetNextPrimaryFire( CurTime() + 1 )
							wep:SetNextSecondaryFire( CurTime() + 1 )
						end
					end
				else
					table.remove(self.PassengersAPC, i)
				end
			end

			if self:GetPassengerCount() ~= #self.PassengersAPC then
				self:SetPassengerCount(#self.PassengersAPC)
			end

			local t = CurTime()
			local dt = 0.1
			if not selfTbl.nextShieldThink or t > selfTbl.nextShieldThink then
				local power = selfTbl.GetShieldPower(self)
				if selfTbl.GetShieldActive(self) then
					selfTbl.SetShieldPower(self, math.max(0, power - dt/selfTbl.ShieldDuration))
					if selfTbl.GetShieldPower(self) == 0 then
						selfTbl.SetShieldActive(self, false)
						selfTbl.SetShieldReady(self, false)
						self:EmitSound("ambient/energy/powerdown2.wav", 120, 160, 1)
					end
				elseif not selfTbl.GetShieldReady(self) then
					selfTbl.SetShieldPower(self, math.min(1, power + dt/selfTbl.ShieldRechargeTime))
					if selfTbl.GetShieldPower(self) == 1 then
						selfTbl.SetShieldReady(self, true)
					end
				end
				
				selfTbl.nextShieldThink = t + dt
			end
		end
	end
	
	function ENT:OnRemove()
		self:SetDriver()
		self:RemoveAllPassengers()
		self:StopMotionController()

		if self.soundEngine then
			self.soundEngine:Stop()
		end

		if self.soundTurbo then
			self.soundTurbo:Stop()
		end

		if self.soundWater then
			self.soundWater:Stop()
		end
	end
	
	function ENT:PhysicsCollide(data, phys)
		local speed = data.OurOldVelocity
		speed:Sub(data.OurNewVelocity)
		speed = speed:Length()
		local shieldOn = self:GetShieldActive()

		if data.HitEntity:IsNPC() then
			local shieldMul = shieldOn and 2 or 1
			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage( (speed/8 + (IsValid(self:GetDriver()) and 10 or 0)) * shieldMul )
			dmgInfo:SetAttacker(self:GetDriver() or self)
			dmgInfo:SetInflictor(self)
			dmgInfo:SetDamageType(bit.bor(DMG_CRUSH, DMG_VEHICLE))
			dmgInfo:SetReportedPosition(self:GetPos())
			dmgInfo:SetDamagePosition(data.HitPos)
			data.HitEntity:TakeDamageInfo(dmgInfo)
		end

		
		if speed > 700 then
			if shieldOn then
				self:EmitSound("weapons/physcannon/energy_bounce2.wav", 100, 113, 1)
			else
				self:EmitSound("ATV_rollover")
			end
			self:TakeDamage(math.Remap(speed, 700, 1400, 75, 500), data.HitEntity, data.HitEntity)
		elseif speed > 300 then
			if shieldOn then
				self:EmitSound("weapons/physcannon/energy_bounce1.wav", 100, 107, 1)
			else
				self:EmitSound("ATV_impact_heavy")
			end
			self:TakeDamage(math.Remap(speed, 300, 700, 15, 75), data.HitEntity, data.HitEntity)
		elseif speed > 50 and not shieldOn then
			self:TakeDamage(math.Remap(speed, 50, 300, 0, 15), data.HitEntity, data.HitEntity)
			self:EmitSound("ATV_impact_medium")
		end
	end

	function ENT:PhysicsSimulate(phys, dt)
		if self.jcms_destroyed then
			if IsValid(self:GetDriver()) then
				self:SetDriver()
			end
			self:RemoveAllPassengers()
			return
		end

		local creepedRatio = 0

		local mass = phys:GetMass()
		local mypos = self:WorldSpaceCenter()
		local myang = phys:GetAngles()

		local myfwd = myang:Forward()
		local myright = myang:Right()
		local myup = myang:Up()
		
		local hoverDistance = self.HoverDistance
		local mins, maxs = Vector(-16, -16, -6), Vector(16, 16, 4)
		
		local driver = self:GetDriver()
		local trFilter = { self }
		if IsValid(driver) then 
			table.insert(trFilter, driver)
		end
		
		phys:Wake()

		-- Traces {{{
			self.onWater = false

			local vecAngularSum = Vector(0, 0, 0)
			local vecLinearSum = Vector(0, 0, 0)

			local vectorNumber = #self.vectorOffsets
			for i=1, vectorNumber do
				local tr1pos = mypos + myang:Forward() * self.vectorOffsets[i][1] + myang:Right() * self.vectorOffsets[i][2]
				local tr1 = util.TraceHull {
					start = tr1pos, endpos = tr1pos + myup*(-hoverDistance),
					mins = mins, maxs = maxs, mask = bit.bor(MASK_WATER, MASK_DEADSOLID),
					filter = trFilter
				}

				self.onWater = self.onWater or tr1.MatType == MAT_SLOSH
				
				local force = 0
				if tr1.Fraction < 1 then
					force = (1 - tr1.Fraction^0.5) * mass * 5
				end

				if force > self.delayedForces[i] then
					self.delayedForces[i] = ( self.delayedForces[i] * 2 + force ) / 3
				else
					self.delayedForces[i] = self.delayedForces[i] * 0.3
				end

				--debugoverlay.SweptBox(tr1pos, tr1.HitPos, mins, maxs, Angle(0,0,0), 0.1, Color(255, 0, 0))
				
				local cell = jcms.zombieCreep_GetCell( tr1.HitPos )
				if IsValid(jcms.zombieCreepCells[cell]) then
					creepedRatio = creepedRatio + 1/#self.vectorOffsets
				end

				if self.delayedForces[i] > 0 then
					local lImp, aImp = phys:CalculateForceOffset(myup * ( self.delayedForces[i] / vectorNumber ) , tr1pos)

					vecAngularSum:Add(aImp)
					vecLinearSum:Add(lImp)
				end
			end
		-- }}}

		-- Damp {{{
			local myvel = phys:GetVelocity()
			local xyDamp = Vector( -myvel:Dot(myfwd), myvel:Dot(myright) * 1.5, 0 )
			
			local myangvel = phys:GetAngleVelocity()

			myangvel:Negate()
			myangvel:Mul(2)
			myangvel.x = myangvel.x * 2
			local angDamp = myangvel
		-- }}}

		-- Controls {{{
			local ctrlFwd = 0
			local ctrlSpin = 0
			local ctrlTurbo = 0
			local ctrlDrift = 0
			
			if driver then
				if driver:KeyDown(IN_USE) and CurTime() > self.nextInteract then
					self:SetDriver()
					self.nextInteract = CurTime() + 1
				else
					if driver:KeyDown(IN_FORWARD) then
						if driver:KeyDown(IN_SPEED) then
							ctrlTurbo = 1
						end
						ctrlFwd = 1
					elseif driver:KeyDown(IN_BACK) then
						ctrlFwd = -1
					elseif driver:KeyDown(IN_SPEED) then
						ctrlDrift = 1
					end
					
					if driver:KeyDown(IN_MOVELEFT) then
						ctrlSpin = -1
						ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
					elseif driver:KeyDown(IN_MOVERIGHT) then
						ctrlSpin = 1
						ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
					end

					if self.attacking1 then
						if self:GetShieldReady() then
							self:SetShieldReady(false)
							self:SetShieldActive(true)
							self:SetShieldPower(1)
							self:EmitSound("ambient/machines/thumper_startup1.wav", 120, 200, 1)
						end
					end
				end
				
				if looseTraction then
					ctrlFwd = ctrlFwd * self.SpeedLooseMul
				end
			end

			if math.abs(ctrlFwd) < 0.1 then
				xyDamp.x = xyDamp.x * Lerp(ctrlDrift, 0.8, 0)
				xyDamp.y = xyDamp.y * Lerp(ctrlDrift, 2.1, 3)
			end

			xyDamp.x = math.Clamp(xyDamp.x, -500, 500)
			xyDamp.y = math.Clamp(xyDamp.y, -500, 500)

			if ctrlFwd == 0 and ctrlTurbo == 0 and ctrlDrift == 0 then
				xyDamp:Mul(2.3)
			end
		-- }}}

		-- Final {{{
			local speedScalar = Lerp(creepedRatio, 1, 0.4)

			local vecAngular = Vector(0, 0, 0)
			vecAngular:Add(vecAngularSum)
			vecAngular:Add(angDamp)
			vecAngular.z = vecAngular.z - ctrlSpin * Lerp(ctrlTurbo, self.TurnSpeed, self.TurnSpeedTurbo) * speedScalar

			local vecLinear = Vector(0, 0, 0)
			vecLinear:Add(vecLinearSum)
			vecLinear:Add(xyDamp)
			vecLinear.x = vecLinear.x + ctrlFwd * Lerp(ctrlTurbo, self.Speed, self.SpeedTurbo) * speedScalar
			
			return vecAngular, vecLinear, SIM_LOCAL_ACCELERATION
		-- }}}
	end
	
	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and (not jcms.team_JCorp_player(activator)) then return end

		if (not self.jcms_destroyed) then
			if (not (IsValid(self.driver) and self.driver:IsPlayer())) then
				if (CurTime() > self.nextInteract) then
					self:SetDriver(activator)
					self.nextInteract = CurTime() + 1
				end
			elseif activator ~= self.driver then
				self:TryEnterAsPassenger(activator)
			end
		end
	end

	function ENT:TryEnterAsPassenger(ply)
		local passengers = self.PassengersAPC

		if #passengers < 4 and not table.HasValue(passengers, ply) then
			table.insert(passengers, ply)
			
			ply:DrawViewModel(false)
			ply:DrawWorldModel(false)
			ply:SetNoDraw(true)
			ply:SetNWEntity("jcms_vehicle", self)
			ply:SetEyeAngles(self:GetAngles())
			ply:SetMoveType( MOVETYPE_NOCLIP )

			self:SetPassengerCount(#passengers)
			ply.jcms_lastEnteredAsPassenger = CurTime()
			ply:EmitSound("physics/body/body_medium_impact_soft3.wav")
		end
	end

	function ENT:RemoveAllPassengers()
		for i=#self.PassengersAPC, 1, -1 do
			self:RemovePassenger(self.PassengersAPC[i])
		end
		self:SetPassengerCount(0)
	end

	function ENT:RemovePassenger(ply)
		local passengers = self.PassengersAPC
		table.RemoveByValue(passengers, ply)

		ply:DrawViewModel(true)
		ply:DrawWorldModel(true)
		ply:SetNoDraw(false)
		ply:SetNWEntity("jcms_vehicle", NULL)
		ply:SetMoveType(MOVETYPE_WALK)

		ply:SetPos(self:GetExitPos(ply))
	end

	function ENT:GetExitPos(forPly)
		-- Hull traces
		local filter = { self, forPly }
		if IsValid(self.driver) then
			table.insert(filter, self.driver)
		end
		for i, passenger in ipairs(self.PassengersAPC) do
			if IsValid(passenger) then
				table.insert(filter, passenger)
			end
		end

		local angle = self:GetAngles()
		local pos = self:WorldSpaceCenter()
		for i=0, 3 do
			local a = math.pi/2*i
			local cos, sin = math.cos(a), math.sin(a)
			
			local v = pos + angle:Right()*(cos*120) + angle:Forward()*(sin*150)
			local tr = util.TraceHull {
				start = pos, endpos = v, filter = filter, mins = forPly:OBBMins(), maxs = forPly:OBBMaxs()
			}

			if tr.Fraction > 0.85 then
				return tr.HitPos
			end
		end

		local uptrace = util.TraceHull {
			start = pos, endpos = pos + Vector(0, 0, 62), filter = filter, mins = forPly:OBBMins(), maxs = forPly:OBBMaxs()
		}

		if uptrace.Fraction > 0.5 then
			return uptrace.HitPos
		else
			uptrace = util.TraceHull {
				start = pos, endpos = pos + Vector(0, 0, -100), filter = filter, mins = forPly:OBBMins(), maxs = forPly:OBBMaxs()
			}
			if uptrace.Fraction > 0.5 then
				return uptrace.HitPos
			end
		end

		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end

		return pos
	end
	
	function ENT:SetDriver(ply)
		-- Carjacking
		if IsValid(self.driver) and self.driver:IsPlayer() then
			self.driver:DrawViewModel(true)
			self.driver:DrawWorldModel(true)
			self.driver:SetNoDraw(false)
			self.driver:SetNWEntity("jcms_vehicle", NULL)
			self.driver:SetMoveType(MOVETYPE_WALK)
			
			if ply == nil then
				self.driver:SetPos(self:GetExitPos(self.driver))
			end

			local ea = self.driver:EyeAngles()
			ea.r = 0
			self.driver:SetEyeAngles(ea)

			self.driver = nil

			for i, bullseye in ipairs(self.jcms_bullseyes) do 
				bullseye:AddFlags(FL_NOTARGET)
			end
		end
		
		if IsValid(ply) and ply:IsPlayer() and ply:GetNWEntity("jcms_vehicle") == NULL then
			self.driver = ply
			ply:DrawViewModel(false)
			ply:DrawWorldModel(false)
			ply:SetNoDraw(true)
			ply:SetNWEntity("jcms_vehicle", self)
			ply:SetEyeAngles(self:GetAngles())
			ply:SetMoveType( MOVETYPE_NOCLIP )

			for i, bullseye in ipairs(self.jcms_bullseyes) do 
				bullseye:RemoveFlags(FL_NOTARGET)
			end
		end
	end
	
	function ENT:GetDriver()
		if IsValid(self.driver) then
			return self.driver
		else
			self.driver = nil
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		local dmgAmount = dmg:GetDamage()
		if self:GetShieldActive() then
			jcms_util_shieldDamageEffect(dmg, dmgAmount)
			return
		end

		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then
				jcms.util_PerformRepairs(self, attacker, 20)
				self:SetHealthFraction(self:Health()/self:GetMaxHealth())
				return 0
			end
		end

		if bit.band(dmg:GetDamageType(), bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_BLAST, DMG_ENERGYBEAM)) > 0 then
			dmgAmount = math.max(dmgAmount*0.66 - 4, 0.01)
		elseif bit.band(dmg:GetDamageType(), DMG_CRUSH) > 0 then
			dmgAmount = dmgAmount*1.13
		end
		
		self:TakePhysicsDamage(dmg)
		if self.jcms_destroyed then return end
		
		local difficultyMultiplier = IsValid(self:GetDriver()) and (1 / (math.max(jcms.runprogress_GetDifficulty(), 1)^0.75)) or 1
		self:SetHealth( self:Health() - dmgAmount*difficultyMultiplier )
		self:SetHealthFraction(math.max(0, self:Health() / self:GetMaxHealth()))
		dmg:SetDamage(dmgAmount)

		if self:Health() <= 0 then
			self.jcms_destroyed = true
			self:SetIsDestroyed(true)

			local ed = EffectData()
			ed:SetMagnitude(1.6)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetRadius(260)
			ed:SetNormal(self:GetAngles():Up())
			ed:SetFlags(1)
			util.Effect("jcms_blast", ed)
			util.Effect("Explosion", ed)

			jcms.util_TryUpdateForPVP(self)
			self:SetBodygroup(0, 1)
		end
	end
	
	function ENT:RedirectDamage(driver, dmg)
		self:TakeDamageInfo( dmg )
		dmg:ScaleDamage(0)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
		if not self:GetIsDestroyed() and FrameTime() > 0 and jcms.performanceEstimate >= 30 then
			local e = self.emitter
			if not e or not IsValid(e) then
				e = ParticleEmitter(self:WorldSpaceCenter())
				self.emitter = e
			end

			local exhaustPos = self:WorldSpaceCenter()
			local ang = self:GetAngles()
			local fwd, up, right = ang:Forward(), ang:Up(), ang:Right()
			fwd:Mul(-108)
			up:Mul(-52)
			exhaustPos:Add(fwd)
			exhaustPos:Add(up)
			right:Mul(FrameNumber()%2==0 and 30 or -30)
			exhaustPos:Add(right)
			e:SetPos(exhaustPos)

			local speed = self:GetVelocity():Length()

			local p = e:Add("particle/smokesprites_0001", exhaustPos)
			if IsValid(p) then
				local fadefactor = math.sqrt(speed/300)
				p:SetVelocity(ang:Forward()*-128)
				p:SetAirResistance(150)
				
				p:SetStartAlpha(255-fadefactor*100)
				p:SetEndAlpha(0)

				p:SetStartSize(fadefactor*8)
				p:SetEndSize(32+fadefactor*48)

				p:SetRoll(math.random()*360)
				p:SetRollDelta(math.random()*5 - 2.5)

				p:SetDieTime(fadefactor+0.15)
				p:SetColor(32, 32, 32)
			end
		end
	end

	ENT.mat_shield = jcms.render_matShield
	ENT.scalematrix = Matrix()
	ENT.scalematrix:Scale(Vector(1.05, 1.05, 1.08))

	function ENT:DrawTranslucent()
		if self:GetShieldActive() then
			local shieldPower = self:GetShieldPower()
			local shieldPowerExp = shieldPower*shieldPower*shieldPower*shieldPower

			self:RemoveAllDecals()

			self:EnableMatrix("RenderMultiply", self.scalematrix)
			render.SetColorModulation(0, Lerp(shieldPowerExp, 0, 10), Lerp(shieldPowerExp, 1, 20))
			render.MaterialOverride(jcms.render_matShield)
				self:SetupBones()
				self:DrawModel()
			render.MaterialOverride()
			render.SetColorModulation(1, 1, 1)
			self:DisableMatrix("RenderMultiply")
			self:SetupBones()
		end
	end

	function ENT:OnRemove()
		if IsValid(self.emitter) then
			self.emitter:Finish()
		end
	end

	function ENT:DrawHUDBottom()
		local healthWidth = 1200
		local healthFrac = math.Clamp(self:GetHealthFraction(), 0, 1)
		local off = 6

		local shieldActive = self:GetShieldActive()
		local shieldFrac = math.Clamp(self:GetShieldPower(), 0, 1)

		local str1 = language.GetPhrase("jcms.apc_tip")
		local str2 = language.GetPhrase("jcms.apc_tip_ready")
		local str3 = language.GetPhrase("jcms.apc_tip_active")
		local str4 = language.GetPhrase("jcms.apc_tip_charging")
		local str = string.format(str1, shieldActive and str3 or (shieldFrac >= 1 and str2 or str4))
		local str_passengers = language.GetPhrase("jcms.apc_passengers")
		local str_passengerscount = self:GetPassengerCount() .. "/4"

		surface.SetDrawColor(jcms.color_dark_alt)
		surface.DrawRect(-healthWidth/2 + 200, -114-64, healthWidth - 128, 32)
		if not shieldActive then
			surface.SetDrawColor(jcms.color_dark)
		end
		surface.DrawRect(-healthWidth/2, -114, healthWidth, 32)
		draw.SimpleText(str, "jcms_hud_medium", -healthWidth/2 + 200, -114-64-8, jcms.color_dark_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		local tw,th = draw.SimpleText(str_passengerscount, "jcms_hud_huge", -healthWidth/2 + 150, -114-32, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(str_passengers, "jcms_hud_small", -healthWidth/2 + 150 - tw/2, -114-32-th, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetDrawColor(jcms.color_pulsing)
			surface.DrawRect(-400, -64, 800, 4)
			surface.DrawRect(-256, -64+16, 512, 6)

			surface.SetDrawColor(jcms.color_bright_alt)
			if self:GetShieldReady() or shieldActive then
				surface.DrawRect(-healthWidth/2 + 200, -114-off-64, (healthWidth-128)*shieldFrac, 32)
			else
				jcms.hud_DrawStripedRect(-healthWidth/2 + 200, -114-off-64, (healthWidth-128)*shieldFrac, 16, 128, CurTime()*-128)
			end

			if not shieldActive then
				surface.SetDrawColor(healthFrac < 0.4 and jcms.color_alert or jcms.color_bright)
			end
			jcms.hud_DrawStripedRect(-healthWidth/2, -114-off+2, healthWidth, 32-4, 128, shieldActive and CurTime()*-32 or 0)
			surface.DrawRect(-healthWidth/2, -114-off, healthWidth*healthFrac, 32)
			draw.SimpleText(str, "jcms_hud_medium", -healthWidth/2 + 200, -114-64-8-off, jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		
			draw.SimpleText(str_passengerscount, "jcms_hud_huge", -healthWidth/2 + 150, -114-32-6, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(str_passengers, "jcms_hud_small", -healthWidth/2 + 150 - tw/2, -114-32-th-4, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		render.OverrideBlend(false)
	end
	
	function ENT:CalcViewDriver(ply, origin, angles, fov, znear, zfar)
		local mypos = self:GetPos()
		local myang = self:GetAngles()
		local speed = self:GetVelocity():Length()
		
		origin = mypos + myang:Up()*24 + angles:Forward() * -210 + angles:Up() * 32
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
end
