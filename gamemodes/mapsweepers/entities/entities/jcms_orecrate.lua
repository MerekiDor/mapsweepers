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
ENT.PrintName = "Ore Crate"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.CrateType = 1
ENT.CrateTypes = {
	[1] = {
		model = "models/items/item_item_crate.mdl",
		capacity = 150,
		mass = 50,
		
		attachOffset = Vector(0,0,0),
		attachAngle = Angle(0,0,0),

		uiPos = Vector(0,3,16),
		uiAngle = Angle(0,180,90),
	},
	[2] = {
		model = "models/props_c17/furniturefridge001a.mdl",
		capacity = 300,
		mass = 150,

		attachOffset = Vector(0,0,10),
		attachAngle = Angle(-90,0,0),

		uiPos = Vector(0,5,15),
		uiAngle = Angle(270,90,180)
	},
	[3] = {
		model = "models/props_wasteland/controlroom_storagecloset001a.mdl",
		capacity = 450,
		mass = 250,
		
		attachOffset = Vector(0,0,0),
		attachAngle = Angle(-90,0,0),

		uiPos = Vector(0,5,25),
		uiAngle = Angle(270,90,180)
	},
}

ENT.VomitVectors = { --Directions to try place ores in when releasing
	Vector(0, 0, 1)
}
for i=1, 8 do
	local vec = Vector(1,0,0)
	vec:Rotate( Angle((i-1) * 45, 5, 0) )
	table.insert(ENT.VomitVectors, vec)

	local vec2 = Vector(vec)
	vec2:Rotate( Angle(0,30, 0) )
	table.insert(ENT.VomitVectors, vec2)
end

ENT.EjectionCooldown = 2.5 --How long until we can eat again after ejecting
ENT.AttachCooldown = 1 --How long until we can attach after being grabbed off a vehicle

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "MaxCapacity")
	self:NetworkVar("Int", 1, "HeldCapacity")

	self:NetworkVar("Angle", 0, "UIAngle")
	self:NetworkVar("Vector", 0, "UIPos")
end

if SERVER then
	function ENT:Initialize()
		local crateType = self.CrateTypes[self.CrateType]
		self:SetModel(crateType.model)
		self:SetMaterial("models/props_combine/metal_combinebridge001")
		self:PhysicsInit(SOLID_VPHYSICS)

		self:SetMaxCapacity(crateType.capacity)
		self:GetPhysicsObject():SetMass(crateType.mass)
		self:GetPhysicsObject():EnableGravity(true)

		self.lastEjected = 0
		self.lastVehicleAttached = 0

		self.crate_contents = {}
		--[[Structure:
			[i] = {type="oreType", model="modelName", owner = jcms_miner } 
		--]]

		self:SetUIPos(crateType.uiPos)
		self:SetUIAngle(crateType.uiAngle)

		self.jcms_attachedToVehicle = false
	end
	
	function ENT:UpdateForFaction(faction)
		if faction == "rgg" then
			self:SetColor( Color(162, 81, 255) )
		elseif faction == "mafia" then
			self:SetColor( Color(241, 212, 14) )
		else
			self:SetColor( Color(255, 32, 32) )
		end
	end

	function ENT:Use( activator, caller, useType, value )
		if self:IsPlayerHolding() or self.jcms_lastCarried and self.jcms_lastCarried + 0.15 > CurTime() then return end
		self:DetachFromVehicle()

		activator:PickupObject(self)
	end

	hook.Add("OnPlayerPhysicsDrop", "jcms_orecrate_drop", function(ply, ent, thrown)
		ent.jcms_lastCarried = CurTime()
	end)

	hook.Add("GravGunOnPickedUp", "jcms_orecrate_pickup", function(ply, ent)
		if not isfunction(ent.DetachFromVehicle) then return end
		ent:DetachFromVehicle()
	end)
 
	function ENT:PhysicsCollide( data, physObj )
		--Is the target an ore and do we have space for it?
		local hitEnt = data.HitEntity

		if not hitEnt.jcms_physAte and self.lastEjected + self.EjectionCooldown < CurTime() and (hitEnt:GetClass() == "jcms_orechunk") and self:GetHeldCapacity() + hitEnt.jcms_oreMass < self:GetMaxCapacity() then
			self:Eat(hitEnt)
		elseif not self.jcms_attachedToVehicle and self.lastVehicleAttached + self.AttachCooldown < CurTime() and hitEnt.jcms_attachedCrates and self:FindAttachSlot(hitEnt) then
			self:ForcePlayerDrop()
			self:AttachToVehicle(hitEnt, self:FindAttachSlot(hitEnt))
		end

		-- Make emptier noises when no ore is inside.
		local stuffed = math.Clamp(self:GetHeldCapacity() / self:GetMaxCapacity(), 0, 1)

		if data.Speed > 250 then
			if stuffed <= 0.25 then
				self:EmitSound("Metal_Box.ImpactHard")
			else
				self:EmitSound("Metal_Barrel.ImpactHard")
			end

			if stuffed > 0 then
				if math.random() < 1-stuffed then
					self:EmitSound("Rock.ImpactHard")
				end

				if stuffed > 0.75 then
					self:EmitSound("Boulder.ImpactHard")
				end
			end
		elseif data.Speed > 100 then
			if stuffed <= 0.4 then
				self:EmitSound("Metal_Box.ImpactSoft")
			else
				self:EmitSound("Metal_Barrel.ImpactSoft")

				if stuffed > 0 then
					if math.random() < stuffed then
						self:EmitSound("Rock.ImpactSoft")
					end
				end
			end
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		local attacker, inflictor = dmg:GetAttacker(), dmg:GetInflictor()

		if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) and self:GetHeldCapacity() > 0 then
			self:Vomit()
		end
	end

	function ENT:Eat( target )
		self:EmitSound("ambient/levels/outland/forklift_stop.wav", 75, 110 + math.Rand(-5, 5) - target.jcms_oreMass/5)

		target.jcms_physAte = true --We can get multiple physcollide calls at once, we don't want to eat the same object twice.

		local targetData = {
			type = target:GetOreName(),
			model = target:GetModel(),
			worth = target:GetWorth(),
			owner = target.jcms_miner
		}
		table.insert(self.crate_contents, targetData)

		--Add mass to capacity.
		self:SetHeldCapacity(self:GetHeldCapacity() + target.jcms_oreMass) --Actual physics object gets its mass fucked with while we're holding it for some reason
		target:Remove()
	end

	function ENT:Vomit()
		--TODO: These don't work.
		self:EmitSound("items/itempickup.wav", 75)
		self:EmitSound("vehicles/atv_ammo_close.wav", 75)

		--[[ --These work but suck.
		self:EmitSound("vehicles/tank_readyfire1.wav", 75)
		self:EmitSound("vehicles/tank_turret_stop1.wav", 75)--]]

		local selfPos = self:WorldSpaceCenter() + Vector(0,0,35)
		local filter = {self}
		local trData = {
			start = selfPos,
			filter = filter,
		}

		self.lastEjected = CurTime()

		local orePositions = {}
		for i, oreData in ipairs(self.crate_contents) do
			local dirVec = self.VomitVectors[ (i-1) % #self.VomitVectors + 1 ]
			trData.endpos = selfPos + dirVec * 45

			local ore = ents.Create("jcms_orechunk")
			ore:SetModel(oreData.model)
			ore:SetOreType(oreData.type)
			ore.jcms_miner = oreData.owner
			ore:Spawn()

			ore:SetWorth(oreData.worth) --Worth override (RGGium)

			local tr = util.TraceEntity(trData, ore)
			ore:SetPos(tr.HitPos) 

			ore:GetPhysicsObject():Wake()

			table.insert(filter, ore)
		end

		self.crate_contents = {}
		self:SetHeldCapacity(0)
	end


	function ENT:AttachToVehicle(target, slot)
		self:EmitSound("Metal_Box.ImpactHard")

		local vec = target.jcms_miningCrateAttaches[slot]
		local crateType = self.CrateTypes[self.CrateType]
		local angAdd, posAdd = crateType.attachAngle, crateType.attachOffset

		self:SetPos(target:LocalToWorld(vec + posAdd))


		self:SetAngles(jcms.util_AddAngles(target:GetAngles(), angAdd))
		
		timer.Simple(0, function()
			constraint.Weld(target, self, 0, 0, 0, true, true)
		end)

		self:GetPhysicsObject():SetMass(25) --Vehicles can't park properly if we're too heavy
		self:GetPhysicsObject():EnableGravity(false)

		local uiAng = target.jcms_miningCrateAngles[slot]
		local crateType = self.CrateTypes[self.CrateType]
		self:SetUIAngle(jcms.util_AddAngles(crateType.uiAngle, uiAng))

		self.jcms_attachedToVehicle = true
		self.jcms_attachedVehicle = target
		self.jcms_attachedSlot = slot

		target.jcms_attachedCrates[slot] = self
	end

	function ENT:DetachFromVehicle()
		constraint.RemoveConstraints( self, "Weld" )

		if self.jcms_attachedToVehicle then
			self:EmitSound("Metal_Box.BulletImpact")

			self.lastVehicleAttached = CurTime()
			
			local crateType = self.CrateTypes[self.CrateType]
			self:GetPhysicsObject():SetMass(crateType.mass)
			self:GetPhysicsObject():EnableGravity(true)

			if IsValid(self.jcms_attachedVehicle) then
				self.jcms_attachedVehicle.jcms_attachedCrates[self.jcms_attachedSlot] = nil 

				
				local crateType = self.CrateTypes[self.CrateType]
				self:SetUIAngle(crateType.uiAngle)

				self.jcms_attachedSlot = nil
				self.jcms_attachedVehicle = NULL
			end
		end

		self.jcms_attachedToVehicle = false
	end

	function ENT:FindAttachSlot(target)
		local selfPos = self:WorldSpaceCenter()

		local i = 1
		local closestSlot
		local closestDist = math.huge

		while target.jcms_miningCrateAttaches[i] do
			local dist = selfPos:DistToSqr( target:LocalToWorld(target.jcms_miningCrateAttaches[i]) )
			if dist < closestDist and not IsValid(target.jcms_attachedCrates[i]) then
				closestSlot = i
				closestDist = dist
			end
			i = i + 1
		end

		return closestSlot
	end
end

if CLIENT then
	ENT.jcms_infoStrictAngles = true
	ENT.ModelUIScales = {
		["models/items/item_item_crate.mdl"] = {
			x = 1,
			y = 1,
		},
		["models/props_c17/furniturefridge001a.mdl"] = {
			x = 2,
			y = 2,
		},
		["models/props_wasteland/controlroom_storagecloset001a.mdl"] = {
			x = 3,
			y = 3,
		},
	}
	
	function ENT:Draw(flags)
		self:DrawModel()

		local dist = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())
		if dist < 1000^2 then 
			self:DrawCounter(dist)
		end
	end

	function ENT:DrawCounter( eyeDistSqr )
		local uiScale = self.ModelUIScales[self:GetModel()]
		local scaleX = uiScale.x
		local scaleY = uiScale.y

		local posOffs = self:GetUIPos()
		local angOffs = self:GetUIAngle()


		local pos = self:WorldSpaceCenter()
		local ang = self:GetAngles()
		local selfTbl = self:GetTable()

		ang = jcms.util_AddAngles(ang, angOffs)

		posOffs:Rotate(ang)
		pos:Add(posOffs)


		--Stolen directly from turret code.
		cam.Start3D2D(pos, ang, 1/32)
			local clip, maxClip = selfTbl:GetHeldCapacity(), selfTbl:GetMaxCapacity()
			local f = 1 - clip / maxClip
			local x, y, w, h, p = -276*scaleX, 0*scaleY, 530*scaleX, 170*scaleY, 16
			
			local r, g, b = 255, 0, 0
			if self:GetNWInt("jcms_pvpTeam", -1) == 2 then 
				r, g, b = 241, 198, 0
			end

			surface.SetDrawColor(r, g, b)
			
			local ch = w - p*2
			surface.DrawRect(x+p,y+p,w-p*2-ch*f,h-p*2)
			if jcms.performanceEstimate > 40 or eyeDistSqr < 600^2 then --If lagging, LOD the text & outline more aggressively.
				surface.DrawOutlinedRect(x,y,w,h, p/3)
				draw.SimpleTextOutlined(("%d / %d"):format(clip, maxClip), "jcms_hud_big", x + w/2, y + h/2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, surface.GetDrawColor())
			end
		cam.End3D2D()
	end
end