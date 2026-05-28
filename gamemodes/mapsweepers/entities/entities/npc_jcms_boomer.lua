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
ENT.PrintName = "Boomer"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsExploding")
	self:NetworkVar("Float", 0, "ExplodeTime")
	self:NetworkVar("Float", 1, "HealthFraction")
end

if SERVER then
	sound.Add( {
		name = "NPC_JCMSBoomer.Idle",
		channel = CHAN_STATIC,
		volume = 0.9,
		level = 75,
		pitch = 90,
		sound = {
			"npc/barnacle/barnacle_digesting1.wav",
			"npc/barnacle/barnacle_gulp1.wav",
			"npc/barnacle/barnacle_digesting2.wav",
			"npc/barnacle/barnacle_gulp2.wav"
		}
	} )

	sound.Add( {
		name = "NPC_JCMSBoomer.Angry",
		channel = CHAN_STATIC,
		volume = 1,
		level = 90,
		pitch = 90,
		sound = {
			"npc/barnacle/barnacle_pull1.wav",
			"npc/barnacle/barnacle_pull2.wav",
			"npc/barnacle/barnacle_pull3.wav",
			"npc/barnacle/barnacle_pull4.wav"
		}
	} )

	ENT.BurstRadius = 350
	ENT.BurstForce = 1400

	function ENT:Initialize()
		self:SetModel("models/zombie/classic.mdl")

		self:SetHullType(HULL_HUMAN)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_BBOX)

		self:SetMaxHealth(37)
		self:SetHealth(37)

		self:SetMaxLookDistance(3000)
		self:SetMoveInterval(0.01)
		self:SetArrivalDistance(128)
		self:SetMaxYawSpeed(45)
		self:SetPlaybackRate(1.25)

		self:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_TURN_HEAD, CAP_OPEN_DOORS))
		self:SetMoveType(MOVETYPE_STEP)
		self:SetNavType(NAV_GROUND)
		self:SetNPCClass(CLASS_ZOMBIE)
		self:SetBloodColor(BLOOD_COLOR_RED)

		if SERVER then
			self.lastPhraseTime = 0
			self.wasObliterated = false
			self.wasPrimed = false
		end
	end

	function ENT:OnTakeDamage(dmg)
		local dmgAmount = dmg:GetDamage()
		if dmgAmount > 0 then
			self:SetHealth( self:Health() - dmgAmount )
		end
		
		local isObliterating = bit.band(dmg:GetDamageType(), bit.bor(DMG_BLAST, DMG_RADIATION, DMG_DISSOLVE)) > 0
		if dmgAmount >= (isObliterating and 75 or 300) then
			self.wasObliterated = true
		end

		local inflictor = dmg:GetInflictor()
		if IsValid(inflictor) and inflictor ~= self and bit.band( dmg:GetDamageType(), bit.bor(DMG_BLAST, DMG_SONIC, DMG_CLUB) ) > 0 then
			local forceMul = 12
			local baseForce = 2050
			self.wasPrimed = true

			local norm = inflictor:GetAngles():Forward()
			norm.z = math.max(0, norm.z) + 0.05
			norm:Normalize()
			norm.z = norm.z*0.2 + 0.05
			norm:Mul(baseForce + dmg:GetDamage() * forceMul)
			norm:Add( self:GetVelocity() )
			self:SetVelocity(norm)
		end

		if self:GetIsExploding() then
			self:SetExplodeTime( self:GetExplodeTime() - dmg:GetDamage() / 60 )
		else
			if bit.band(dmg:GetDamageType(), bit.bor(DMG_BULLET, DMG_BUCKSHOT)) > 0 then
				dmg:SetDamage( dmg:GetDamage() + 1.5 )
			end

			if self:Health() <= 0 then
				self.lastAttacker = dmg:GetAttacker()
				self.lastInflictor = dmg:GetInflictor()
				self:SetIsExploding(true)
				self:SetExplodeTime(CurTime() + (self.wasObliterated and 0.09 or (self.wasPrimed and 1 or 0.25)))
			end
		end
	end

	function ENT:HandleAnimEvent(event, eventTime, cycle, type, options)
		if event == 85 then
			self:EmitSound("NPC_FastZombie.GallopLeft")
			return true
		elseif event == 87 then
			self:EmitSound("NPC_FastZombie.GallopRight")
			return true
		end

		if event == 86 or event == 88 then
			return true
		end
	end

	function ENT:Think()
		local selfTbl = self:GetTable()
		local cTime = CurTime()

		if selfTbl:GetIsExploding() and cTime > selfTbl:GetExplodeTime() then
			self:Burst()
		else
			local enemy = self:GetEnemy()
			local isAngry = false
			if IsValid(enemy) then
				isAngry = true
				local viscon = enemy:Visible(enemy) and (cTime-self:GetEnemyLastTimeSeen(enemy)) < 1

				if viscon and self:GetPos():DistToSqr( self:GetEnemyLastKnownPos(enemy) ) < 200^2 then
					if not selfTbl:GetIsExploding() then
						selfTbl:SetIsExploding(true)
						selfTbl:SetExplodeTime(cTime + 2.5)
					end
				end
			end

			if cTime - selfTbl.lastPhraseTime > 5 then
				self:EmitSound(isAngry and "NPC_JCMSBoomer.Angry" or "NPC_JCMSBoomer.Idle")
				selfTbl.lastPhraseTime = cTime + math.random()
			end
		end
	end

	function ENT:SelectSchedule()
		local enemy = self:GetEnemy()
		if IsValid(enemy) then
			local enemypos = self:GetEnemyLastKnownPos(enemy)
			local viscon = enemy:Visible(enemy) and (CurTime()-self:GetEnemyLastTimeSeen(enemy)) < 1
			self:SetSchedule(SCHED_CHASE_ENEMY)
		else
			self:SetSchedule(SCHED_COMBAT_PATROL)
		end
	end

	function ENT:Burst()
		local selfTbl = self:GetTable()

		self:Remove()
		hook.Call("OnNPCKilled", GAMEMODE, self, selfTbl.lastAttacker, selfTbl.lastInflictor)
		local pos = self:WorldSpaceCenter()

		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetRadius(selfTbl.BurstRadius)
		ed:SetNormal(vector_up)
		ed:SetMagnitude(0.6)
		ed:SetFlags(4)
		util.Effect("jcms_blast", ed)
		if selfTbl.wasPrimed then
			ed:SetFlags(1)
			util.Effect("Explosion", ed)
		end

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetReportedPosition(pos)

		local enemyBurst = ( IsValid(selfTbl.lastAttacker) and self:Disposition(selfTbl.lastAttacker) == D_HT ) or ( self:Health() <= 0 )
		local primedMul = (selfTbl.wasPrimed and 150 or 1)
		for i, ent in ipairs(ents.FindInSphere(pos, selfTbl.BurstRadius)) do
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				local entpos = ent:WorldSpaceCenter()
				local diff = entpos - pos
				local dist = diff:Length()
				diff:Normalize()

				local falloff = math.Clamp(1 - (dist / selfTbl.BurstRadius), 0, 1)
				dmg:SetDamage(falloff * primedMul)
				dmg:SetDamagePosition(entpos)
				dmg:SetDamageType(DMG_CRUSH)

				diff:Mul(falloff*selfTbl.BurstForce)

				local mt = ent:GetMoveType()
				if mt == MOVETYPE_VPHYSICS then
					diff:Mul(phys:GetMass())
					phys:ApplyForceOffset(diff, self:GetPos())
				elseif mt == MOVETYPE_WALK then
					diff:Mul(0.6)
					ent:SetVelocity(diff)
				elseif mt ~= MOVETYPE_PUSH then
					local vel = ent:GetVelocity()
					vel:Add(diff)
					ent:SetVelocity(vel)
				end

				if not ent:IsPlayer() then
					ent:TakeDamageInfo(dmg)
				end
			end
		end

		if not selfTbl.wasObliterated then
			local vel = Vector(0, 0, 0)
			for i=1, enemyBurst and 3 or 7 do
				local crabNPC = jcms.npc_Spawn("zombie_explodingcrab", pos + VectorRand(-25, 25))

				local ang = math.random() * math.pi * 2
				local cos, sin = math.cos(ang), math.sin(ang)
				local mag = math.random() * 320

				vel:SetUnpacked(cos*mag, sin*mag, math.Rand(-150, 420))
				crabNPC:SetVelocity(vel)
			end
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		self:ManipulateBoneAngles(9, Angle(0,5,0))
		self:ManipulateBoneAngles(10, Angle(0,12.5,0))
	end

	function ENT:OnRemove()
		if IsValid(self.csmodel) then
			self.csmodel:Remove()
		end

		if IsValid(self.csmodelhead) then 
			self.csmodelhead:Remove()
		end
	end

	function ENT:GetCSModel()
		if not IsValid(self.csmodel) then
			self.csmodel = ClientsideModel("models/player/zombie_soldier.mdl")
			self.csmodel:SetParent(self)
			self.csmodel:AddEffects(EF_BONEMERGE)
			self.csmodel:SetNoDraw(true)
		end

		return self.csmodel
	end

	function ENT:GetCSHeadModel()
		if not IsValid(self.csmodelhead) then
			self.csmodelhead = ClientsideModel("models/Zombie/Fast.mdl")
			self.csmodelhead:SetParent(self)
			self.csmodelhead:AddEffects(EF_BONEMERGE)
			self.csmodelhead:SetNoDraw(true)

			self.csmodelhead:SetMaterial("models/jcms/explosiveheadcrab/body")

			for i=1, self:GetBoneCount(), 1 do
				self.csmodelhead:ManipulateBoneScale( i-1, vector_origin)
			end
			self.csmodelhead:SetBodygroup( 1,1 )

			for i=40, 51, 1 do 
				self.csmodelhead:ManipulateBoneScale( i, jcms.vectorOne)
			end
			
			self.csmodelhead:ManipulateBoneAngles( 40, Angle(-24, 3.3, 21.8) )
			self.csmodelhead:ManipulateBonePosition( 40, -Vector(-0.9, -4.3, 3) )
		end

		return self.csmodelhead
	end

	function ENT:Think()
		if self:GetIsExploding() and FrameTime() > 0 then
			if not self.didSound then
				self.didSound = true
				self:EmitSound("physics/flesh/flesh_bloody_break.wav", 100, 100, 1)
			end

			local frac = math.Clamp( (2.5 - self:GetExplodeTime() + CurTime())/2.5, 0, 0.9) + 0.1
			local sc = 1 + math.ease.InQuart(frac)*0.9
			local vscale = Vector(sc, sc, sc)

			local span = frac * 10
			local mdl = self:GetCSModel()
			for i=1, self:GetBoneCount() do
				mdl:ManipulateBoneScale(i, vscale)
				self:ManipulateBoneAngles(i, AngleRand(-5*sc, 5*sc))
			end

			headmdl = self:GetCSHeadModel()
			for i=40, 51, 1 do 
				headmdl:ManipulateBoneScale( i, vscale)
			end

			if math.random() < frac^2 then
				local ed = EffectData()
				ed:SetEntity(self)
				local v = self:WorldSpaceCenter()

				local ang = math.random()*math.pi*2
				local cos, sin = math.cos(ang), math.sin(ang)
				local dist = math.Rand(5, 16)
				v.x = v.x + cos * dist
				v.y = v.y + sin * dist
				v.z = v.z + math.Rand(-32, 24)

				ed:SetOrigin(v)
				ed:SetColor(math.random(1,3))
				util.Effect("BloodImpact", ed)

				if math.random() < 0.8 then
					self:EmitSound("physics/flesh/flesh_squishy_impact_hard"..math.random(1,4)..".wav", 100, 70 + frac*60, 1)
				end
			end
		end
	end

	function ENT:Draw()
		local selfTbl = self:GetTable()

		local mdl = selfTbl.GetCSModel(self)
		mdl:SetParent(self) --todo: Still not quite a full solution but prevents invisible boomers. This may leave the ent behind / is inefficient (though the impact is minimal)

		local headmdl = selfTbl.GetCSHeadModel(self)
		headmdl:SetParent(self)

		if selfTbl:GetIsExploding() then
			local frac = math.Clamp((2.5 - selfTbl:GetExplodeTime() + CurTime())/2.5, 0, 1)
			render.SetColorModulation(3 + frac*5, 2 + (frac^2)*4, 1)
		elseif jcms.performanceEstimate > 45 then
			for i=1, self:GetBoneCount() , 1 do
				local tF = math.sin( 2.5 * (CurTime() + i/5) )
				self:ManipulateBoneScale( i-1, Vector(1 + 0.075*tF,1 + 0.075*tF,1 + 0.05*tF))
			end
			render.SetColorModulation(3, 2, 1)
		end

		mdl:DrawModel()
		headmdl:DrawModel()

		render.SetColorModulation(1, 1, 1)
	end
end
