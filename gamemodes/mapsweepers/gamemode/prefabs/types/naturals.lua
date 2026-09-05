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

local prefabs = jcms.prefabs

-- // Ambient prefabs {{{
	prefabs.wall_charger = {
		natural = true,
		weight = 0.45,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 48, 32)
			
			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("item_healthcharger")
			if not IsValid(ent) then return end

			ent:SetPos(data.pos)
			ent:SetAngles(data.normal:Angle())
			ent:Spawn()
			return ent
		end
	}
	
	prefabs.barricades = {
		natural = true,
		weight = 0.12,

		check = function(area)
			return jcms.mapgen_AreaFlat(area) and ( area:GetSizeX()*area:GetSizeY() ) > 60000
		end,

		areaWeight = function(area)
			return (jcms.mapdata.areaDepths[area] or 0)/3 + (#area:GetVisibleAreas() / jcms.mapdata.visUnrestricted.max)*2 + 1
		end,

		stamp = function(area, data)
			local squareVariant = math.random() < 0.37
			
			if squareVariant then
				local squish = math.Rand(0.25, 0.5)
				local inverseVariant = math.random() < 0.15
				for i=1,4 do
					if math.random() < 0.25 then continue end
					local v = LerpVector(squish, area:GetCorner(i-1), area:GetCenter())
					
					for j=1,2 do
						local prop = ents.Create("jcms_breakable")
						local ang = Angle(0, (j==1 and 90 or 0) + (inverseVariant and (i*90) or (i*90+180)), 0)
						prop:SetPos(v + ang:Right()*64)
						prop:SetAngles(ang)
						prop:SetModel("models/props_phx/construct/concrete_barrier0"..(math.random() < 0.33 and 0 or 1)..".mdl")
						prop:SetMaxHealth(300)
						prop:SetHealth(300)
						prop:Spawn()
					end
					
					if math.random() < 0.3 then
						-- Extra
						local extrapos = LerpVector(math.Rand(0.05, 0.15), v, area:GetCenter()) + Vector(math.random(-32, 32), math.random(-32, 32), 0)
						local extraangle = Angle(0, math.random(1, 4)*90 + math.random(-15, 15), 0)
						if math.random() < 0.35 then
							local prop = ents.Create("item_item_crate")
							prop:SetPos(extrapos)
							prop:SetAngles(extraangle)
							prop:SetKeyValue("ItemClass", "jcms_dynamicsupply")
							prop:SetKeyValue("ItemCount", math.random()<0.1 and 2 or 1)
							prop:Spawn()
						else
							local prop = ents.Create("prop_physics")
							prop:SetPos(extrapos)
							prop:SetAngles(extraangle)
							prop:SetModel(math.random()<0.7 and "models/props_c17/oildrum001.mdl" or "models/props_c17/oildrum001_explosive.mdl")
							prop:Spawn()
						end
					end
				end
			else
				local v = area:GetRandomPoint()
				local prop = ents.Create("jcms_breakable")
				prop:SetPos(v)
				prop:SetAngles(Angle(0, math.random(1, 4)*90, 0))
				prop:SetModel("models/props_phx/construct/concrete_barrier0"..(math.random() < 0.33 and 0 or 1)..".mdl")
				prop:SetMaxHealth(350)
				prop:SetHealth(350)
				prop:Spawn()
			end
		end
	}
	
	prefabs.oil = {
		natural = true,
		weight = 0.23,

		check = function(area)
			return area:IsFlat() and ( area:GetSizeX()*area:GetSizeY() ) > 60000
		end,

		stamp = function(area, data)
			local v = area:GetCenter() + area:GetRandomPoint()
			v:Mul(0.5)

			local smallModels = {
				"models/props_junk/propane_tank001a.mdl",
				"models/props_junk/gascan001a.mdl",
				"models/props_explosive/explosive_butane_can.mdl",
				"models/props_explosive/explosive_butane_can02.mdl"
			}

			local function getModel(smallChance, dudChance)
				if math.random() < (smallChance or 0.2) then
					return smallModels[ math.random(1, #smallModels) ]
				elseif math.random() < (dudChance or 0.2) then
					return "models/props_c17/oildrum001.mdl"
				else
					return "models/props_c17/oildrum001_explosive.mdl"
				end
			end
			
			local prop = ents.Create("prop_physics")
			prop:SetPos(v)
			prop:SetAngles(Angle(0, math.random()*360, 0))
			prop:SetModel(getModel(0.1, 0.3))
			prop:Spawn()
			
			if math.random() < 1.3 then
				local prop = ents.Create("prop_physics")
				local a = math.random()*math.pi*2
				local away = math.random(31, 42)
				local cos, sin = math.cos(a)*away, math.sin(a)*away
				prop:SetPos(v + Vector(cos, sin, 0))
				prop:SetAngles(Angle(0, math.random()*360, 0))
				prop:SetModel(getModel(0.1, 0.4))
				prop:Spawn()
				
				if math.random() < 1 then
					local prop = ents.Create("prop_physics")
					local a = a + math.Rand(0.4, 0.6)*math.pi
					local away = math.random(30, 36)
					local cos, sin = math.cos(a)*away, math.sin(a)*away
					prop:SetPos(v + Vector(cos, sin, 16))
					prop:SetAngles(Angle(math.random()*360, math.random()*360, 90))
					prop:SetModel(getModel(0.25, 0.5))
					prop:Spawn()
				end
			end
		end
	}

	prefabs.supplies = {
		natural = true,
		weight = 1.5,

		check = function(area)
			return #area:GetVisibleAreas() <= jcms.mapgen_GetVisData().avg
		end,

		stamp = function(area, data)
			local v = area:GetCenter() + area:GetRandomPoint()
			v:Mul(0.5)

			local a = Angle( math.Rand(-5, 5), math.random() * 360, math.Rand(-5, 5) )
			local prop = ents.Create("item_item_crate")
			prop:SetPos(v)
			prop:SetAngles(a)
			prop:SetKeyValue("ItemClass", "jcms_dynamicsupply")
			prop:SetKeyValue("ItemCount", math.random() < 0.25 and 4 or 3)
			prop:Spawn()
		end
	}

	prefabs.ammocrate = {
		natural = true,
		weight = 0.11,

		check = function(area)
			if not jcms.mapgen_ValidArea(area) or not jcms.mapgen_AreaFlat(area) then return false end

			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 48, 128)
			
			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_ammo_crate")
			if not IsValid(ent) then return end

			data.pos = data.pos + data.normal * 24
			data.pos.z = data.pos.z - 32
			ent:Spawn()
			ent:SetPos(data.pos)
			ent:SetAngles(data.normal:Angle())
			return ent
		end
	}

	prefabs.emplacement = {
		natural = true,
		weight = 0.12,

		check = function(area)
			if not jcms.mapgen_ValidArea(area) then return false end

			if ( area:GetSizeX()*area:GetSizeY() ) <= 60000 then
				return false
			end

			if not jcms.mapgen_AreaFlat(area) then 
				return false 
			end

			return true
		end,
		
		areaWeight = function(area)
			local zheight = (area:GetCenter().z + 32768) / 32768
			return (math.max(#area:GetVisibleAreas(), 1) * math.sqrt(zheight)) / ((jcms.mapdata.areaDepths[area] or 0) + 1)^2
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_emplacement")
			if not IsValid(ent) then return end

			local ang, pos = jcms.prefab_CalcOverlooking(area, false)

			ent:SetAngles(ang)
			ent:SetPos(pos)
			ent:Spawn()

			return ent
		end
	}

	prefabs.npc_portal = {
		natural = true,
		weight = 0.3,
		
		onlyMainZone = true,

		check = function(area)
			return ( area:GetSizeX()*area:GetSizeY() ) > 400
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_npcportal")
			if not IsValid(ent) then return end

			if not jcms.director or math.random() < 0.1 or jcms.director.faction == "everyone" then
				local factionNames = jcms.factions_GetOrder()
				if not jcms.cvar_customfactions_hell:GetBool() and (jcms.director.missionType == "hell" or jcms.director.missionType == "eschaton")  then -- restrict spawners to only vanilla factions on hell/eschaton if the cvar for that is on.
					factionNames = table.GetKeys(jcms.vanillaFactions)
					table.sort(factionNames)
				end
				ent:SetSpawnerType(factionNames[ math.random(1, #factionNames) ])
			else
				ent:SetSpawnerType(jcms.director.faction)
			end

			local v = jcms.mapgen_AreaPointAwayFromEdges(area, 64)
			v.z = v.z + 24
			ent:SetPos(v)
			ent:Spawn()
			return ent
		end
	}

	prefabs.jalopy = {
		natural = true,
		weight = 0.01,

		check = function(area)
			return jcms.mapgen_AreaFlat(area) and ( area:GetSizeX()*area:GetSizeY() ) >= 250000
		end,

		areaWeight = function(area)
			return (jcms.mapdata.areaDepths[area] or 0)
		end,

		stamp = function(area, data)
			local jalopy = ents.Create("prop_vehicle_jeep")
			jalopy:SetModel("models/vehicle.mdl")
			jalopy:SetKeyValue("vehiclescript", "scripts/vehicles/jalopy.txt")

			local v = jcms.mapgen_AreaPointAwayFromEdges(area, 250)
			v.z = v.z + 24
			jalopy:SetPos(v)
			jalopy:SetAngles(Angle(0, math.random(1, 4)*90 + math.Rand(-12, 12), 0))

			jalopy:Spawn()
			jalopy:Activate()
		end
	}
-- // }}}

-- // Terminals {{{
	prefabs.cash_cache = {
		natural = true,
		weight = 0.27,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 48, 32)
			
			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_terminal")
			if not IsValid(ent) then return end

			ent:SetPos(data.pos)
			ent:SetAngles(data.normal:Angle())
			
			-- Ported over from previous 'jcms_cache' entity.
			local correctedAngle = ent:GetAngles()
			correctedAngle:RotateAroundAxis( correctedAngle:Up(), 180 )
			correctedAngle:RotateAroundAxis( correctedAngle:Right(), 90 )
			ent:SetAngles( correctedAngle )

			ent:Spawn()
			ent:SetColor(Color(255, 64, 64))
			ent:InitAsTerminal("models/props_combine/combine_emitter01.mdl", "cash_cache")
			return ent
		end
	}

	prefabs.gambling = {
		natural = true,
		weight = 0.012,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 48, 32)
			
			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_terminal")
			if not IsValid(ent) then return end

			ent:SetPos(data.pos + data.normal * 7)
			local correctedAngle = data.normal:Angle()
			correctedAngle:RotateAroundAxis( correctedAngle:Up(), -90 )
			correctedAngle:RotateAroundAxis( correctedAngle:Forward(), -4 )
			ent:SetAngles( correctedAngle )

			ent:Spawn()
			ent:SetColor(Color(121, 64, 255))
			ent:InitAsTerminal("models/props_c17/cashregister01a.mdl", "gambling")
			ent.jcms_hackType = nil
			return ent
		end
	}

	prefabs.upgrade_station = {
		natural = true,
		weight = 0.14,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 48, 32)

			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_terminal")
			if not IsValid(ent) then return end

			ent:SetPos(data.pos)
			ent:SetAngles(data.normal:Angle())

			ent:Spawn()
			ent:InitAsTerminal("models/props_combine/combine_intwallunit.mdl", "upgrade_station")
			ent.jcms_hackType = nil
			return ent
		end
	}

	prefabs.respawn_chamber = {
		natural = true,
		weight = 0.1,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 24, 32)

			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_terminal")
			if not IsValid(ent) then return end

			ent:SetPos(data.pos + data.normal * 32)
			ent:DropToFloor()
			ent:SetAngles(data.normal:Angle())

			ent:SetColor( Color(222, 104, 238) )

			ent.respawnBeaconUsedUp = false
			ent.initializedAsRespawnBeacon = false

			AccessorFunc(ent, "jcms_respawnBeaconBusy", "RespawnBusy", FORCE_BOOL)
			
			function ent:DoPreRespawnEffect(ply, duration)
				jcms.DischargeEffect(self:WorldSpaceCenter(), duration)
				self:SetSequence("close")
				self:EmitSound("doors/doormove2.wav")
			end

			function ent:DoPostRespawnEffect(ply)
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(ply)
				util.Effect("jcms_spawneffect", ed)
				jcms.net_SendRespawnEffect(ply)
				self.respawnBeaconUsedUp = true
				self:SetNWString("jcms_terminal_modeData", "0")
			end

			function ent:GetRespawnPosAng(ply)
				local ang = self:GetAngles()
				return self:GetPos() + ang:Up() * 9.175108 + ang:Forward() * 10
			end

			ent:Spawn()
			ent:InitAsTerminal("models/props_lab/hev_case.mdl", "respawn_chamber")
			return ent
		end
	}

	prefabs.gunlocker = {
		natural = true,
		weight = 0.09,

		check = function(area)
			local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 60, 32)
			
			if #wallspots > 0 then
				local rng = math.random(#wallspots)
				return true, { pos = wallspots[rng], normal = normals[rng] }
			else
				return false
			end
		end,

		stamp = function(area, data)
			local ent = ents.Create("jcms_terminal")
			if not IsValid(ent) then return end

			ent:Spawn()
			ent:InitAsTerminal("models/jcms/mafia_locker.mdl", "gunlocker")
			ent:SetPos(data.pos)
			ent:SetAngles(data.normal:Angle())

			return ent
		end
	}
-- // }}}
