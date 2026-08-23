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
ENT.PrintName = "Anchored NPC Portal"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/mechanics/robotics/claw.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		self:SetSubMaterial(2, "metal4")

		local adjustedAngle = self:GetAngles()
		adjustedAngle:RotateAroundAxis(adjustedAngle:Right(), 90)
		adjustedAngle:RotateAroundAxis(adjustedAngle:Up(), -70)
		adjustedAngle:RotateAroundAxis(vector_up, math.random()*360)
		self:SetAngles( adjustedAngle )

		self:SetMaxHealth(250)
		self:SetHealth(250)
		self.IsDestroyed = false
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "SpawnerType")
	self:NetworkVar("Bool", 0, "IsProvoked")
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "DestructionTime")
	self:NetworkVar("Int", 0, "NetworkedNextSpawnTime")
	
	self:SetHealthFraction(1)
	self:SetDestructionTime(0)
	self:SetNetworkedNextSpawnTime(0)
end

if SERVER then
	ENT.NextNPCSpawnTime = 0
	ENT.LastNPCSpawnTime = 0
	ENT.QueuedSpawns = 0
	ENT.MyNPCs = {}
	ENT.NPCLimit = 5
	ENT.NPCLimitProvoked = 15
	
	function ENT:TrySpawnXNPCs(x, dontDoQueue)
		self.LastNPCSpawnTime = CurTime()

		local function callback(ent, npc)
			if not IsValid(ent) then return end 

			if IsValid(npc) then 
				table.insert(self.MyNPCs, npc)
			elseif not dontDoQueue then 
				ent.QueuedSpawns = ent.QueuedSpawns + 1 
			end
		end

		local function getKind()
			return self:GetRandomNPC()
		end

		if not dontDoQueue then
			self.QueuedSpawns = math.max(self.QueuedSpawns - 1, 0)
		end
		
		local origin = self:GetPos() + Vector(0, 0, 48)
		jcms.npc_PortalReleaseXNPCs(self, x, origin, self:GetSpawnerType(), getKind, callback)
	end

	function ENT:Think()
		if not jcms.director then return end
		if self.NextNPCSpawnTime < 1 then
			self.NextNPCSpawnTime = self:GetCreationTime() + math.Rand(120, 300)
		end
		
		for i=#self.MyNPCs, 1, -1 do
			local npc = self.MyNPCs[i]
			if not IsValid(npc) or npc:Health() <= 0 then
				table.remove(self.MyNPCs, i)
			end
		end
		
		if (#self.MyNPCs == 0) and (self.LastNPCSpawnTime > 1) and (CurTime() - self.LastNPCSpawnTime > 5) then
			self.NextNPCSpawnTime = math.min(self.NextNPCSpawnTime, CurTime() + 8)
		end

		local nearestSwpr, nearestDist = jcms.GetNearestSweeper(self:WorldSpaceCenter())
		if (CurTime() > self.NextNPCSpawnTime) and #self.MyNPCs < self.NPCLimit and nearestDist < 8000 then
			if self:GetIsProvoked() then
				self.QueuedSpawns = math.min(math.random(5, 11), self.NPCLimit - #self.MyNPCs)
				self.NextNPCSpawnTime = CurTime() + math.Rand(10, 30)
			else
				local npcCount = math.random(1, 4)
				self.QueuedSpawns = math.min(npcCount, self.NPCLimit - #self.MyNPCs)
				self.NextNPCSpawnTime = CurTime() + 20 * npcCount
			end
		end

		if self.QueuedSpawns > 0 then
			self:TrySpawnXNPCs(self.QueuedSpawns, false)
			self:EmitSound("ambient/levels/labs/electric_explosion"..math.random(1,5)..".wav", 100, 100)
		end

		local floored = math.floor(self.NextNPCSpawnTime)
		if self:GetNetworkedNextSpawnTime() ~= floored then
			self:SetNetworkedNextSpawnTime(floored)
		end
    end

	function ENT:GetRandomNPC()
		local weights = {}
		local hasEpisodes = jcms.HasEpisodes()
		
		for npctype, data in pairs(jcms.npc_types) do
			if data.portalSpawnWeight and (data.faction == "everyone" or data.faction == self:GetSpawnerType()) and (not data.episodes or hasEpisodes) then
				weights[npctype] = data.portalSpawnWeight
			end
		end

		local randomtype = jcms.util_ChooseByWeight(weights)
		return randomtype or "antlion_drone"
	end

	function ENT:OnTakeDamage(dmg)
		if self.IsDestroyed then return end
		if jcms.team_NPC( dmg:GetAttacker() ) then return 0 end
		if bit.band( dmg:GetDamageType(), bit.bor(DMG_BURN, DMG_SLOWBURN) ) > 0 then return 0 end

		if self:Health() < 0 then
			timer.Simple(1.5, function()
				if IsValid(self) then
					self:Remove()
					
					local ed2 = EffectData()
					ed2:SetOrigin(self:GetPos())
					ed2:SetNormal(vector_up)
					util.Effect("Explosion", ed2)
				end
			end)
			self.IsDestroyed = true

			local ed = EffectData()
			ed:SetOrigin(self:GetPos())
			ed:SetNormal(vector_up)
			util.Effect("Explosion", ed)

			self:TrySpawnXNPCs(math.random(self.NPCLimit, self.NPCLimitProvoked), true)

			self:EmitSound("npc/stalker/go_alert2.wav", 100, 80, 1)
			util.ScreenShake(self:GetPos(), 599, 30, 2.5, 512, true)

			jcms.giveCash(dmg:GetAttacker(), 250)
			
			self:SetDestructionTime( CurTime() + 1.5 )
		end

		
		self:SetHealth( self:Health() - math.max(math.min(1, dmg:GetDamage()), dmg:GetDamage() - 5) )

		if not self:GetIsProvoked() then
			if jcms.team_JCorp( dmg:GetAttacker() ) then
				self:SetIsProvoked(true)
				self:EmitSound("ambient/explosions/exp"..math.random(1,4)..".wav", 100, 120, 1)
				util.ScreenShake(self:GetPos(), 250, 40, 1.5, 1000, true)
				self.NextNPCSpawnTime = CurTime() + math.Rand(0.5, 2.5)
			end
		end

		self:SetHealthFraction( math.Clamp(self:Health() / self:GetMaxHealth(), 0, 1) )
		
		return 0
	end

	function ENT:StartTouch(ent)
		local pushAway = ent:GetPos() - self:GetPos()
		pushAway:Normalize()
		pushAway:Mul(523)

		self:EmitSound("ambient/energy/weld2.wav", 100, 110)

		local dmg = DamageInfo()
		dmg:SetDamagePosition(ent:GetPos())
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamage(15)
		dmg:SetDamageType(DMG_DISSOLVE)
		ent:TakeDamageInfo(dmg)

		if ent:IsPlayer() then
			if ent:IsOnGround() then
				pushAway.z = pushAway.z + math.random(400, 500)
			end
			
			ent:ViewPunch(AngleRand(-32, 32))
		end
		
		ent:SetVelocity(pushAway)
	end
end

if CLIENT then
	ENT.mat = Material "effects/spark"
	ENT.mat_ring = Material "effects/select_ring"
	ENT.mat_light = Material "sprites/light_glow02_add"
	ENT.mat_lodportal = jcms.mat_circle

	function ENT:FillSparkInfo(t)
		t.thickness = math.random(8, 48)
		t.length = math.random(150, 300)
		t.progress = 0
		t.speed = math.random()*1.5 + 1
		t.ang = AngleRand()
	end

	function ENT:OnRemove()
		if self.soundPortal then
			self.soundPortal:Stop()
		end
	end
	
	function ENT:Think()
		local selfTbl = self:GetTable()
		if not selfTbl.sparks then
			selfTbl.sparks = {}
			for i=1, 12 do
				local t = {}
				selfTbl:FillSparkInfo(t)
				t.progress = math.random()
				selfTbl.sparks[i] = t
			end
		else
			local dt = FrameTime()
			
			for i=#selfTbl.sparks, 1, -1 do
				local spark = selfTbl.sparks[i]
				
				if spark.progress > 1 then
					selfTbl:FillSparkInfo(spark)
				else
					spark.progress = spark.progress + dt * spark.speed
				end
			end
		end

		if selfTbl.soundPortal and selfTbl.soundPortal:IsPlaying() then
			local remtime = self:GetNetworkedNextSpawnTime() - CurTime()
			selfTbl.soundPortal:ChangePitch(100 + 50/(remtime+1), 0.1)
		else
			selfTbl.soundPortal = CreateSound(self, "ambient/machines/laundry_machine1_amb.wav")
			selfTbl.soundPortal:Play()
		end
	end
	
	function ENT:GetDeathAnim()
		local dstTime = self:GetDestructionTime()
		if dstTime < 1 then
			return 0
		else
			local diff = dstTime - CurTime()
			return 1-math.Clamp(diff / 1.5, 0, 1)
		end
	end
	
	function ENT:Draw()
		local selfTbl = self:GetTable()
		local deathAnim = selfTbl:GetDeathAnim()
		if deathAnim > 0 then
			local col = jcms.factions_GetColor( selfTbl:GetSpawnerType() )
			local mul = Lerp(deathAnim^3, 0, 50)/255
			render.SetColorModulation(1 + col.r*mul,  1 + col.g*mul, 1 + col.b*mul)
			self:DrawModel()
			render.SetColorModulation(1, 1, 1)
		else
			self:DrawModel()
		end
	end
	
	function ENT:DrawTranslucent()
		if render.GetRenderTarget() then return end
		
		local selfTbl = self:GetTable()
		local selfPos = self:GetPos()
		local selfIndex = self:EntIndex()

		local deathAnim = selfTbl:GetDeathAnim()
		local eyePos = EyePos()
		local lod = eyePos:DistToSqr(selfPos) > 1500^2
		local lodSphere = eyePos:DistToSqr(selfPos) > 300^2
		local col = jcms.factions_GetColor( selfTbl:GetSpawnerType() )
		
		local isProvoked = selfTbl:GetIsProvoked()
		local healthFrac = selfTbl:GetHealthFraction()
		local mul = Lerp(healthFrac*healthFrac, 1, isProvoked and 1/6 or 1/10)
		local hfSqrt = math.sqrt(healthFrac)
		local colBlack = Color(Lerp(hfSqrt, 255, col.r*mul), Lerp(hfSqrt, 255, col.g*mul), Lerp(hfSqrt, 255, col.b*mul))
		
		local ang = self:GetAngles()
		local right, fwd = ang:Right(), ang:Forward()
		
		if not lod then 
			local dl = DynamicLight(selfIndex)
			if dl then
				dl.pos = selfPos + fwd*5 + right*-56
				dl.r = col.r
				dl.g = col.g
				dl.b = col.b
				dl.brightness = Lerp(healthFrac, 5, 3)
				dl.decay = 0.05
				dl.dietime = CurTime() + 0.05
			end
		end
		
		local sphereRad = Lerp(deathAnim, Lerp(healthFrac, 17, 12), 0)
		
		local portalPos
		if lod then
			portalPos = selfPos + fwd*5 + right*-40
			
			local sprSize = sphereRad*2/0.8
			if lodSphere then
				local lodSprSize = sprSize * 0.86
				render.SetMaterial(self.mat_lodportal)
				render.DrawSprite(portalPos, lodSprSize, lodSprSize, colBlack)
			else
				render.SetColorMaterial()
				render.DrawSphere(portalPos, sphereRad, 5, 5, colBlack)
			end
			
			render.SetMaterial(selfTbl.mat_ring)
			render.DrawSprite(portalPos, sprSize, sprSize, col)
			
			if dl then dl.size = 200 end
		else
			local time = CurTime() + selfIndex
			local sinemul = isProvoked and 6 or 2
			local sine = (math.sin( time*sinemul ) + 1)/2

			portalPos = selfPos + fwd*5 + right*(-40 - sine*2)
			
			if healthFrac < 1 then
				local mag = 4 * (1-healthFrac)
				portalPos.x = portalPos.x + (math.random() - 0.5)*mag
				portalPos.y = portalPos.y + (math.random() - 0.5)*mag
				portalPos.z = portalPos.z + (math.random() - 0.5)*mag
			end
			
			if selfTbl.sparks then
				surface.SetMaterial(selfTbl.mat)
				surface.SetDrawColor(col)
				
				for i, spark in ipairs(selfTbl.sparks) do
					cam.Start3D2D(portalPos, spark.ang, Lerp(hfSqrt, 1/5, 1/8))
						local u = isProvoked and 1-spark.progress*2 or spark.progress*2-1
						surface.DrawTexturedRectUV(32, -spark.thickness, spark.length, spark.thickness, u, 0, u + 1, 1)
					cam.End3D2D()
				end
			end
			
			local sprSize = (sphereRad + sine)*2 / 0.8
			if lodSphere then
				local lodSprSize = sprSize * 0.86
				render.SetMaterial(self.mat_lodportal)
				render.DrawSprite(portalPos, lodSprSize, lodSprSize, colBlack)
			else
				render.SetColorMaterial()
				render.DrawSphere(portalPos, sphereRad + sine, 11, 11, colBlack)
			end
			
			render.SetMaterial(selfTbl.mat_ring)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				render.DrawSprite(portalPos, sprSize, sprSize, col)
				
				local subCol = Color(col.r, col.g, col.b, 255)
				
				local ringCount = isProvoked and 5 or 3
				
				for i=1, ringCount do
					local f = (time + i/ringCount)%1
					f = math.ease.OutQuint(f)
					local subsprSize = sprSize * (isProvoked and Lerp(f, 0.1, 1.2) or Lerp(f, 0.6, 1.1))
					
					if f > 0.6 then
						f = 1-(f-0.4)/0.6
					end
					subCol.a = 150 * f
					
					render.DrawSprite(portalPos, subsprSize, subsprSize, subCol)
				end
			render.OverrideBlend( false )
			
			if dl then dl.size = Lerp(sine, 180, 250) end
		end
		
		if deathAnim > 0 then
			render.SetMaterial(selfTbl.mat_light)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				local parabolic = math.max(0,-4*(deathAnim*deathAnim)+4*deathAnim)
				local size = Lerp(parabolic, 0, 200) + 48*(1-deathAnim^2)
				render.DrawSprite(portalPos, size^1.1, size, col)
			render.OverrideBlend( false )
		end
	end
end
