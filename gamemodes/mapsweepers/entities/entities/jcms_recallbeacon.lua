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
ENT.PrintName = "Recall Beacon"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false

ENT.ChargeTime = 2

--TODO: Only allow one per player.

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsCharging")
end

if SERVER then
	function ENT:Initialize()
		self.jcms_DontCollideWithNPCs = true
		self:SetCustomCollisionCheck(true)
		
		self:SetModel("models/jcms/jcorp_jumppad.mdl")
		--TODO: Diff material
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		
		--Charging
		self.lastTouchedPly = NULL
		self.lastCharge = 0
		self.chargeLevel = 0

		self.teleportPoint = jcms.director_GetRecallPoint()
	end

	function ENT:Think()
		--Reset charge state if we've been idle too long
		local cTime = CurTime() 
		if cTime - self.lastCharge > 0.25 then
			self.chargeLevel = 0
			self:SetIsCharging(false)
		end
	end

	function ENT:Touch(otherEnt)
		if otherEnt:IsPlayer() then --Start charging if a player is touching us.
			self:SetIsCharging(true)
			self.chargeLevel = self.chargeLevel + 1/66
			
			self.lastCharge = CurTime()

			if self.chargeLevel > self.ChargeTime then
				self:TeleportPlayer(otherEnt)
			end
		end
	end

	function ENT:TeleportPlayer(ply)
		-- // Teleport effect (Source) {{{
			local ed = EffectData() --Same as dog death
			ed:SetMagnitude(1.5)
			ed:SetOrigin(ply:WorldSpaceCenter())
			ed:SetRadius(150)
			ed:SetNormal(ply:GetAngles():Up())
			ed:SetFlags(5)
			ed:SetColor( jcms.util_ColorIntegerFast(230, 185, 255) )
			util.Effect("jcms_blast", ed)
		-- // }}}

		ply:SetPos(self.teleportPoint or ply:GetPos()) --Send us to the destination (fall back to no tele if it's missing somehow).

		ply:EmitSound("ambient/machines/teleport4.wav")

		timer.Simple(0, function()
			self:BreakByBreach( VectorRand(-100,100) + Vector(0,0,200) )
		end)
	end

	function ENT:BreakByBreach(forceVector)
		self:EmitSound("physics/metal/metal_box_break2.wav", 80, 103)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		local physObj = self:GetPhysicsObject()
		if IsValid(physObj) and forceVector then
			physObj:SetVelocity( forceVector )
		end

		timer.Simple(2.75, function()
			if IsValid(self) then
				self:SetModelScale(0, 0.25)
			end
		end)

		timer.Simple(3, function()
			if IsValid(self) then
				self:Remove()
			end
		end)
	end
end

if CLIENT then 
	--TODO:
end