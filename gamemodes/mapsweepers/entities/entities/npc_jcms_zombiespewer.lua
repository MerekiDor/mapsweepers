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
ENT.Base = "base_anim"
ENT.PrintName = "Zombie Spawner"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

--[[ TODO:
	Swap fogdist to foglevel (or something like that) define ranges in ENT. table, use foglevel to also scale colormod intensity

	Play a global sound on-spawn so that it's a little more obvious

	Emit sounds in general (Poison zombie hurt sounds, and something to help lure players to us.

	Need to also figure out ways to make this more obvious
--]]

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "FogDist")
end

if SERVER then 
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/antlionhill.mdl")
		--self:SetMaterial("models/barnacle/roots")
		self:SetModelScale(0.5)

		--TODO: Slightly depress so we're not elevated above the ground
		
		self:PhysicsInitBox( Vector(-50,-50,0),Vector(50,50,180) )
		self:SetMoveType(MOVETYPE_NONE)

		self:SetMaxHealth(1250)
		self:SetHealth(1250)

		self.jcms_flinchProgress = 0
		self.jcms_ignoreStraggling = true

		self:SetSequence("idle")
		self:SetCycle(math.random())
		self:SetBloodColor(BLOOD_COLOR_ANTLION)

		self:SetAngles( Angle(math.Rand(-2, 2), math.random()*360, math.Rand(-2, 2)) )
		
		self:SetNWString("jcms_boss", "zombie_spewer")

		self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
		
		self.jcms_DontCollideWithNPCs = true
		self:SetCustomCollisionCheck(true)

		--Tell every spewer to update their cap
		hook.Call("jcms_Spewer_UpdateRangeCap")
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:UpdateRangeCap()
		local spewCount = #ents.FindByClass("npc_jcms_zombiespewer")
		local spewValues = {
			[1] = 3000,
			[2] = 1750,
			[3] = 1000
		}

		local dist = spewValues[spewCount] or math.huge

		jcms.rangeCap_SetSource(self, dist)
		self:SetFogDist(dist) --TODO: LERP clientside.
	end

	function ENT:OnTakeDamage(dmgInfo)
		local dmg = dmgInfo:GetDamage()

		if self.dying then
			return
		end

		if dmg > 0 then
			if bit.band( dmgInfo:GetDamageType(), DMG_BLAST ) > 0 then
				dmgInfo:ScaleDamage(1.5)
			end

			self.jcms_flinchProgress = self.jcms_flinchProgress + dmg 
			self:SetHealth(self:Health() - dmg)
			
			if self.jcms_flinchProgress > 25 then

				self:SetSequence( math.random() < 0.5 and "flinch02" or "flinch01" )
				local dur = self:SequenceDuration()
				timer.Simple(dur, function()
					if IsValid(self) and self:GetSequenceName( self:GetSequence() ):match("flinch") then
						self:SetSequence("idle")
						self:SetCycle(0)
					end
				end)

				self.jcms_flinchProgress = 0
			end
		end

		if self:Health() <= 0 then
			self.dying = true
			self:SetSequence("death")
			self:SetCycle(0)
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())

			timer.Simple(1, function()
				if IsValid(self) then
					self:Remove()
				end
			end)
		end

		timer.Simple(0, function()
			if IsValid(self) then
				self:SetNWFloat("HealthFraction", self:Health() / self:GetMaxHealth())
			end
		end)
	end

	function ENT:OnRemove()
		--Tell every spewer to update their cap
		hook.Call("jcms_Spewer_UpdateRangeCap")
		jcms.rangeCap_SetSource(self, nil)
	end
end

hook.Add("jcms_Spewer_UpdateRangeCap", "jcms_Spewer_UpdateRangeCap", function()
	for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiespewer")) do 
		ent:UpdateRangeCap()
	end
end)

if CLIENT then
	function ENT:Initialize()
		hook.Add("PreDrawSkyBox", tostring(self), function()
			local data = {}
			data.fogCol = Color(50, 0, 0)
			data.fogMaxDensity = 1
			data.fogMode = MATERIAL_FOG_LINEAR
			data.fogStart = -2500
			data.fogEnd = self:GetFogDist()
			
			jcms.fogStack_push(data)
		end)
	end

	function ENT:Think()
		-- Burst in bloody particles.
		if FrameTime() > 0 and math.random() < 0.23 and self:GetSequenceName( self:GetSequence() ) == "death" then
			local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
			local boneMatrix = self:GetBoneMatrix(boneIndex)
			if boneMatrix then
				local ed = EffectData()
				ed:SetRadius(math.random(48, 96))
				ed:SetOrigin(boneMatrix:GetTranslation())
				ed:SetMagnitude(math.Rand(0.1, 0.3))
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		end

		--Color mod

		--TODO: These seem to stack(?). Might want to separate this into a hook added/removed when the first/last are spawned and removed.
		--local cSine = (1 + math.sin(CurTime()))/2
		--jcms.colormod_Hold("zombiespewer", Color(64, 0, 0), 0.7 + cSine * math.random() * 0.1 , 1, 2)
	end

	function ENT:DrawTranslucent()
		self:DrawModel()
	end

	function ENT:OnRemove()
		-- // Fog Cleanup {{{
			hook.Remove("PreDrawSkyBox", tostring(self))
		-- // }}}

		local ed = EffectData()
		ed:SetRadius(250)
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetScale(1)
		ed:SetMagnitude(0.5)
		ed:SetFlags(0)
		util.Effect("jcms_bigblast", ed)

		for i=1, 6 do
			local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
			local boneMatrix = self:GetBoneMatrix(boneIndex)
			if boneMatrix then
				local ed = EffectData()
				ed:SetRadius(math.random(65, 128))
				ed:SetOrigin(boneMatrix:GetTranslation())
				ed:SetMagnitude(math.Rand(0.3, 0.5))
				ed:SetScale(2)
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		end

		util.ScreenShake(self:GetPos(), 4, 60, 2, 500, false)
		self:EmitSound("Explo.ww2bomb")
	end


	--TODO: Needs to be adjusted when visual pass is done
	hook.Add("PostDrawTranslucentRenderables", "jcms_ZombieSpewerEyes", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
		render.MaterialOverride(jcms.zombieSpawnerEyeMat)
			for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiespewer")) do 
				ent:DrawModel()
			end
		render.MaterialOverride()
	end)
end