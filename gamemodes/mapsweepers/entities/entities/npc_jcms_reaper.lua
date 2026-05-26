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
ENT.Base = "base_ai"
ENT.PrintName = "Antlion Reaper"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
	ENT.BeamRange = 1250
	
	ENT.NextAttack1Time = 0
	ENT.LastBeam1 = NULL

	ENT.NextAttack2Time = 0
	ENT.LastBeam2 = NULL

	ENT.SoundDiscoveredEnemy = Sound("NPC_Antlion.Distracted")
	ENT.LastDiscoverSound = 0
	
	function ENT:Initialize()
		self:SetModel("models/antlion.mdl")
		self:SetMaterial("metal2")

		self:SetColor(Color(math.random(190, 200), math.random(148, 152), math.random(36, 42)))
		self:SetHullType(HULL_MEDIUM)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_BBOX)

		self:SetMaxHealth(200)
		self:SetHealth(200)

		self:SetMaxLookDistance(3000)
		self:SetMoveInterval(0.01)
		self:SetArrivalSpeed(500)
		self:SetArrivalDistance(128)
		self:SetMaxYawSpeed(90)

		self:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_TURN_HEAD, CAP_OPEN_DOORS))
		self:SetMoveType(MOVETYPE_STEP)
		self:SetNavType(NAV_GROUND)
		self:SetNPCClass(CLASS_ANTLION)
		self:SetBloodColor(BLOOD_COLOR_ANTLION)
	end

	function ENT:OnTakeDamage(dmg)
		local armorMul = math.random() < 0.8 and math.Rand(0.2, 0.4) or math.Rand(0.8, 1.0)
		self:SetHealth(self:Health() - dmg:GetDamage())

		if armorMul < 0.5 then
			local ed = EffectData()
			ed:SetOrigin(dmg:GetDamagePosition())
			ed:SetNormal( (dmg:GetDamagePosition() - self:WorldSpaceCenter()):GetNormalized() )
			util.Effect("MetalSpark", ed)

			self:EmitSound("Computer.BulletImpact")
		end
		
		self:SetActivity(ACT_FLINCH)

		if self:Health() <= 0 then
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetRadius(120)
			ed:SetNormal(VectorRand(-1, 1))
			ed:SetMagnitude(1.75)
			ed:SetFlags(1)
			util.Effect("jcms_blast", ed)

			self:EmitSound("NPC_Vortigaunt.Explode")
			self:EmitSound("NPC_Antlion.RunOverByVehicle")

			local epos = self:WorldSpaceCenter()
			for i=1, math.random(5, 8) do
				timer.Simple( (math.random()^2)*0.15, function()
					local ed = EffectData()
					local gibpos = epos + VectorRand(-16, 16)
					ed:SetOrigin(gibpos)
					ed:SetMagnitude(3)
					ed:SetScale(1)
					ed:SetNormal( (gibpos - epos):GetNormalized() )
					util.Effect(math.random()<0.5 and "StriderBlood" or "AntlionGib", ed)
				end)
			end

			if IsValid(self.LastBeam1) then
				self.LastBeam1:Remove() 
			end

			if IsValid(self.LastBeam2) then
				self.LastBeam2:Remove() 
			end

			self:Remove()
			hook.Call("OnNPCKilled", GAMEMODE, self, dmg:GetAttacker(), dmg:GetInflictor())
		end

		if IsValid(dmg:GetAttacker()) and dmg:GetAttacker() ~= self then
			self:UpdateEnemyMemory(dmg:GetAttacker(), dmg:GetReportedPosition())
		end

		return 0
	end

	function ENT:Think()
		local enemy = self:GetEnemy()
		
		if IsValid(enemy)  then
			if self:Visible(enemy) then
				self:SetGlarePos(enemy:EyePos())
				
				if ( CurTime() - self:GetEnemyLastTimeSeen(enemy) ) < 1 and self:IsFacingIdealYaw() then
					if CurTime() > self.LastDiscoverSound + 10 then
						self:EmitSound(self.SoundDiscoveredEnemy)
					end

					self.LastDiscoverSound = CurTime()

					if self:WorldSpaceCenter():DistToSqr(enemy:WorldSpaceCenter()) < (self.BeamRange*0.9)^2 then
						if CurTime() > self.NextAttack1Time then
							self:BeamAttack(false)
						elseif CurTime() > self.NextAttack2Time then
							self:BeamAttack(true)
						end
					end
				end

				local adjustedAngle = self:GetAngles()
				local towardEnemy = self:GetEnemyLastKnownPos() - self:WorldSpaceCenter()
				towardEnemy:Normalize()
				towardEnemy = towardEnemy:Angle()
				self:SetIdealYawAndUpdate(towardEnemy.y)
			end
		else
			self:SetGlarePos(self:WorldSpaceCenter())
		end

		if IsValid(self.LastBeam1) then
			self.LastBeam1:SetPos(self:WorldSpaceCenter())
		end

		if IsValid(self.LastBeam2) then
			self.LastBeam2:SetPos(self:WorldSpaceCenter())
		end
	end

	function ENT:BeamAttack(isSecond)
		local beam = ents.Create("jcms_beam")
		beam:SetPos(self:WorldSpaceCenter())
		beam:SetBeamAttacker(self)
		beam:Spawn()
		beam.Damage = 20
		beam.friendlyFireCutoff = 100 --Don't hurt guards/other high-HP targets. Fodder's fine though.
		beam:SetBeamLength(self.BeamRange)

		if isSecond then
			self.NextAttack1Time = self.NextAttack1Time + 0.5
			self.NextAttack2Time = CurTime() + math.Rand(1.9, 4.5)
			self.LastBeam2 = beam
			self:SetBeam2(beam)
		else
			self.NextAttack1Time = CurTime() + math.Rand(1.9, 4.5)
			self.NextAttack2Time = self.NextAttack2Time + 0.5
			self.LastBeam1 = beam
			self:SetBeam1(beam)
		end

		self:EmitSound("ambient/energy/weld"..math.random(1,2)..".wav", 140, 105, 1)

		local enemy = self:GetEnemy()
		if IsValid(enemy) then
			local epos = self:Visible(enemy) and enemy:WorldSpaceCenter() + enemy:GetVelocity()*0.5 or self:GetEnemyLastSeenPos(enemy)
			beam:FireBeamSweep(epos, math.random()<0.5 and math.Rand(0, 0.15) or math.Rand(0.85, 1), (math.random()<0.5 and 1 or -1)*math.Rand(20, 32), math.Rand(3.5, 4.25))
		else
			beam:Remove()
		end
	end

	function ENT:SelectSchedule()
		local enemy = self:GetEnemy()
		if IsValid(enemy) then
			local enemypos = self:GetEnemyLastKnownPos(enemy)
			local viscon = enemy:Visible(enemy) and (CurTime()-self:GetEnemyLastTimeSeen(enemy))<1
			local dist = self:GetPos():Distance(enemypos)

			if viscon then
				if dist > self.BeamRange then
					self:SetSaveValue("m_vecLastPosition", enemypos)
					self:SetSchedule(SCHED_FORCED_GO)
				elseif dist < self.BeamRange*0.2 then
					self:SetSchedule(SCHED_RUN_FROM_ENEMY)
				else
					self:SetSchedule(SCHED_COMBAT_WALK)
				end
			else
				self:SetSchedule(SCHED_COMBAT_PATROL)
			end
		else
			self:SetSchedule(SCHED_COMBAT_PATROL)
		end
	end

	function ENT:HandleAnimEvent(event, eventTime, cycle, type, options)
		if event == 54 then
			self:EmitSound("NPC_Antlion.FootstepHeavy")
			return true
		elseif event == 55 then
			self:EmitSound("NPC_Antlion.Footstep")
			return true
		elseif event == 61 then
			self:EmitSound("NPC_Antlion.MeleeAttackDouble")
			return true
		end
	end
end

if CLIENT then
	ENT.MatGlow = Material("particle/fire")

	ENT.EyeAnglePitch = { 0, 0, 0, 0}
	ENT.EyeAngleYaw = { 0, 0, 0, 0}

	ENT.EyeAngleTargetPitch = { 0, 0, 0, 0}
	ENT.EyeAngleTargetYaw = { 0, 0, 0, 0}

	function ENT:Think()
		local dt = 0.2 --Run 5 times per second (not every frame)

		local selfTbl = self:GetTable()
		local glarePos = selfTbl:GetGlarePos()
		local selfPos = self:WorldSpaceCenter()

		--Only look at target if lookat target isn't selfpos
		local lookAtTarget = selfPos:DistToSqr(glarePos) > 32*32
		local eyeang = self:EyeAngles()

		if lookAtTarget then
			eyeang = glarePos - selfPos
			eyeang:Normalize()
			eyeang = eyeang:Angle()
			eyeang:Sub(self:GetAngles())
		end

		local eyeP, eyeY, eyeR = eyeang:Unpack()
		local lookAtChance = (lookAtTarget and 0.5 or 0.02)
		for i = 1, 4 do
			if math.random() < lookAtChance then
				selfTbl.EyeAngleTargetPitch[i] = lookAtTarget and eyeP or math.Rand(-32, 32)
				selfTbl.EyeAngleTargetYaw[i] = lookAtTarget and eyeY or math.Rand(-48, 48)
			end
		end

		local appr = dt * 720
		for i = 1, 4 do
			selfTbl.EyeAnglePitch[i] = math.ApproachAngle(selfTbl.EyeAnglePitch[i], selfTbl.EyeAngleTargetPitch[i], appr)
			selfTbl.EyeAngleYaw[i] = math.ApproachAngle(selfTbl.EyeAngleYaw[i], selfTbl.EyeAngleTargetYaw[i], appr)
		end
		
		self:SetNextClientThink( CurTime() + dt )
		return true
	end

	--Optimisation
	local eyeMat = Matrix()
	local pupilMat = Matrix()
	local eyeAng = Angle()

	local eyeCol = Color(255,230,0)
	local eyeGlowCol = Color(255, 200, 0)
	local eyePupilCol = Color(32,0,0)

	local eyePupilScale = Vector(0.3, 0.2, 0.6)
	local eyePupilOffset = Vector(3,0,0) 
	function ENT:DrawEyes(eyeGlowMat)
		local selfTbl = self:GetTable()
		local selfCentre = self:WorldSpaceCenter()
		local distToPlayer = jcms.EyePos_lowAccuracy:DistToSqr(selfCentre)
		if distToPlayer > 3000^2 then return end --LOD, don't draw at all

		--Optimisation
		local a = self:GetAngles()
		local fw = a:Forward()
		local right = a:Right()
		local up = a:Up()
		local ap, ay, ar = a:Unpack()

		local pos = selfCentre + fw*14

		local eyeid = 0
		for smul=-1,1,2 do
			for eye=1,2 do
				eyeid = eyeid + 1
				
				--Eye position
				local eyepos = pos + right*(smul*(eye==1 and 9 or 16)) + up*(eye==1 and 4 or 7) + fw*(eye==1 and 0 or -4)
				eyepos:Add(VectorRand(-0.1, 0.1))

				if distToPlayer < 1000^2 then --LOD, don't draw glow if far
					render.SetMaterial(eyeGlowMat or selfTbl.MatGlow)
					render.DrawSprite(eyepos, math.Rand(32, 48), math.Rand(24, 32), eyeGlowCol )
				end

				render.OverrideDepthEnable(true, true)
					eyeMat:Identity()
					eyeMat:Translate(eyepos)
					eyeAng:SetUnpacked(ap + selfTbl.EyeAnglePitch[eyeid], ay + selfTbl.EyeAngleYaw[eyeid], ar)
					eyeMat:Rotate(eyeAng)

					cam.PushModelMatrix(eyeMat)
						if eye == 2 then
							local beam = smul==-1 and selfTbl:GetBeam1() or selfTbl:GetBeam2()

							if IsValid(beam) then
								beam.StartPosOverride = eyepos
							end
						end
						
						render.SetColorMaterial()
						render.DrawSphere(vector_origin, 4, 9, 9, eyeCol)
						
						if distToPlayer < 1500^2 then
							pupilMat:Identity()
							pupilMat:Translate(eyePupilOffset)
							pupilMat:Scale(eyePupilScale)

							cam.PushModelMatrix(pupilMat, true)
								render.DrawSphere(vector_origin, 4, 13, 13, eyePupilCol)
							cam.PopModelMatrix()
						end
					cam.PopModelMatrix()
				render.OverrideDepthEnable(false)
			end
		end
	end

	function ENT:DrawTranslucent()
		self:DrawModel()
		self:DrawEyes()
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "GlarePos")
	self:NetworkVar("Entity", 0, "Beam1")
	self:NetworkVar("Entity", 1, "Beam2")
end
