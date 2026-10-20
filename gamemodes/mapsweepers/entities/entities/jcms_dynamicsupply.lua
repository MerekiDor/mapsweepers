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

ENT.Type = "point"
ENT.Base = "base_point"
ENT.PrintName = "Map Sweepers Dynamic Items"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false

if SERVER then

	function ENT:GetLootClass(demand)
		local entClasses = jcms.dynamicsupply_lootTable[ demand ]
		if not entClasses then return end

		local shuffled = jcms.util_GetShuffledByWeight(entClasses)
		for i, className in ipairs(shuffled) do
			if jcms.dynamicsupply_existingClasses[ className ] or type( scripted_ents.GetStored(className) ) == "table" then
				jcms.dynamicsupply_existingClasses[ className ] = true
				return className
			end
		end
	end

	function ENT:CreateDemandsTable(ply)
		local demands = {}

		local hp, hpMax = ply:Health(), ply:GetMaxHealth()
		local hpLowPoint = hpMax / 2
		if hp < hpLowPoint then
			demands["health_low"] = Lerp( math.Clamp(math.TimeFraction(0, hpLowPoint, hp), 0, 1), 3, 1 )
			demands["health_high"] = 0.02
		elseif hp < hpMax then
			demands["health_high"] = Lerp( math.Clamp(math.TimeFraction(hpLowPoint, hpMax, hp), 0, 1), 1, 0.5 )
		else
			demands["health_high"] = 0.0001
			demands["health_low"] = 0.0001
		end

		for i, wep in ipairs( ply:GetWeapons() ) do
			local ammoType1 = game.GetAmmoName( wep:GetPrimaryAmmoType() )
			if type(ammoType1) == "string" and self:GetLootClass("ammo_" .. ammoType1) then
				demands[ "ammo_" .. ammoType1 ] = (demands[ "ammo_" .. ammoType1 ] or 0) + 1
			end
			
			local ammoType2 = game.GetAmmoName( wep:GetSecondaryAmmoType() )
			if type(ammoType2) == "string" and self:GetLootClass("ammo_" .. ammoType2) then
				demands[ "ammo_" .. ammoType2 ] = (demands[ "ammo_" .. ammoType2 ] or 0) + 0.5
			end
		end

		return demands
	end

	function ENT:CreateAllDemandsTable()
		local demands = {}

		for key in pairs(self.LootTable) do
			demands[key] = 1
		end
		
		return demands
	end

	function ENT:SpawnLootFromDemand(demand)
		local itemClass = self:GetLootClass(demand)

		if itemClass then
			local item = ents.Create(itemClass)

			if IsValid(item) then
				local pos = self:GetPos()
				pos.z = pos.z + 4 + math.random()*2
				pos.x = pos.x + math.Rand(-1, 1)
				pos.y = pos.y + math.Rand(-1, 1)
				item:SetPos(pos)
				
				item:SetAngles( AngleRand() )
				item:Spawn()

				local phys = item:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity( VectorRand(-54, 54) )
				end
			end
		elseif demand then
			jcms.printf("unknown demanded item type '%s'", demand)
		end
	end

	function ENT:Initialize()
		timer.Simple(0.05, function()
			if IsValid(self) then
				local sweepers = jcms.GetAliveSweepers()
				
				if #sweepers > 0 then
					local ply = jcms.director_PickClosestPlayer(self:GetPos(), sweepers)

					local demands = IsValid(ply) and self:CreateDemandsTable(ply) or self:CreateAllDemandsTable()
					for i = 1, tonumber(self.ItemCount) or 1 do
						local randomDemand = jcms.util_ChooseByWeight(demands)
						self:SpawnLootFromDemand(randomDemand)
					end
				end

				self:Remove()
			end
		end)
	end

end