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
ENT.PrintName = "Restock Crate"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/items/item_item_crate.mdl")
		self:PrecacheGibs()
		self:PhysicsInit(SOLID_VPHYSICS)
		self:GetPhysicsObject():SetMaterial("Wood_Crate")
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		phys:SetDamping(0.5, 0)
		phys:EnableDrag(false)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "OwnerNickname")
	self:NetworkVar("Int", 0, "AmmoCashInside")
	self:NetworkVar("Int", 1, "HealthInside")
	self:NetworkVar("Int", 2, "AntiradInside")
end

if SERVER then
	ENT.ShareRadius = 1256

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
	end

	function ENT:PhysicsCollide(colData, collider)
		if colData.Speed > 250 then
			self:EmitSound("Wood_Box.ImpactHard")
			self:EmitSound("weapon.ImpactSoft")
		elseif colData.Speed > 100 then
			self:EmitSound("Wood_Box.ImpactSoft")
		end
	end

	function jcms.util_TryGiveAmmo(ply, cash)
		if cash <= 0 or not IsValid(ply) then
			return false
		end	
		
		local typeCosts = {}
		local typesSortedByCost = {} --The types in order of cost (indexed)

		local typeCounts = {} --How much we already have
		local typeDemands = {} --How much the weapon ""wants"" for its mag

		--Get counts and types
		for i, wep in ipairs(ply:GetWeapons()) do
			--Primary then secondary
			for j=1,2 do
				local ammoType = j==1 and wep:GetPrimaryAmmoType() or wep:GetSecondaryAmmoType()
				local ammoTypeName = game.GetAmmoName(ammoType)
				if ammoTypeName and ammoType and ammoType >= 0 then
					ammoTypeName = ammoTypeName:lower()
					if not typeCosts[ammoTypeName] then
						local ammoPrice = jcms.weapon_ammoCosts[ ammoTypeName ] or jcms.weapon_ammoCosts._DEFAULT
						typeCosts[ammoTypeName] = ammoPrice
						table.insert(typesSortedByCost, ammoTypeName)
					end

					local clip = j==1 and wep:GetMaxClip1() or math.ceil(wep:GetMaxClip2()/2)
					clip = (clip > 0 and clip) or 100 --Belt fed weapons get treated as 100

					typeDemands[ammoTypeName] = (typeDemands[ammoTypeName] or 0) + math.max(1,clip)
					
					typeCounts[ammoTypeName] = ply:GetAmmoCount(ammoTypeName)
				end
			end
		end

		table.sort(typesSortedByCost, function(first, last)
			return typeCosts[first] > typeCosts[last]
		end)

		
		local avgAmmoCash = 0 -- 'ammoCash' is cost*count
		for i, ammoTypeName in ipairs(typesSortedByCost) do
			avgAmmoCash = avgAmmoCash + typeCounts[ammoTypeName] * typeCosts[ammoTypeName]
		end
		avgAmmoCash = avgAmmoCash / #typesSortedByCost

		--Reduce demand for ammo we already have a lot of.
		for i, ammoTypeName in ipairs(typesSortedByCost) do
			local ammoCash = typeCounts[ammoTypeName] * typeCosts[ammoTypeName]
			local deviation = avgAmmoCash - ammoCash

			typeDemands[ammoTypeName] = typeDemands[ammoTypeName] + math.ceil(deviation/10)
		end


		local totalGiven = {}
		local firstIteration = true
		repeat
			local gotAtLeastOne = false
			for i, ammoType in ipairs(typesSortedByCost) do
				local affordableDemand = math.min(typeDemands[ammoType], math.max(1, math.floor(cash/typeCosts[ammoType])))

				if affordableDemand > 0 then
					if firstIteration then
						cash = cash - affordableDemand
					else
						cash = cash - affordableDemand * typeCosts[ammoType]
					end
					totalGiven[ammoType] = (totalGiven[ammoType] or 0) + affordableDemand
					gotAtLeastOne = true
				end
			end

			if firstIteration then
				firstIteration = false
				typesSortedByCost = table.Reverse(typesSortedByCost)
			end
			
			if not gotAtLeastOne then
				break
			end
		until (cash <= 0)

		local worked = false
		for type, count in pairs(totalGiven) do
			ply:GiveAmmo(count, type)
			worked = worked or (count > 0)
		end
		
		return worked
	end

	function ENT:TryGiveAmmo(ply, cashOverride)
		local cash = cashOverride or self:GetAmmoCashInside()
		local worked = jcms.util_TryGiveAmmo(ply, cash)
		return worked
	end

	function ENT:TryGiveHealth(ply, healthOverride)
		local health = healthOverride or self:GetHealthInside()
		health = math.min(ply:GetMaxHealth() - ply:Health(), health)

		if health > 0 then
			ply:SetHealth( ply:Health() + health )
		end

		return health > 0, math.max(0, health)
	end

	function ENT:TryGiveAntirad(ply, radOverride)
		local rad = radOverride or self:GetAntiradInside()
		ply:SetNWInt("jcms_antirad", ply:GetNWInt("jcms_antirad", 0) + rad)

		return rad > 0
	end

	function ENT:TryGiveSuppliesAndBreak(ply)
		local workedHealth, givenHealth = self:TryGiveHealth(ply, math.min(25, self:GetHealthInside()))
		local workedAmmo = self:TryGiveAmmo(ply)
		local workedRad = self:TryGiveAntirad(ply)
		local pos = self:WorldSpaceCenter()

		if workedHealth then
			self:EmitSound("items/medshot4.wav", 75, 90, 1)
			self:SetHealthInside( self:GetHealthInside() - givenHealth )

			timer.Simple(0.02, function()
				if IsValid(ply) then
					local ed = EffectData()
					ed:SetEntity(ply)
					ed:SetOrigin(pos)
					ed:SetMagnitude(1)
					ed:SetScale(5)
					ed:SetFlags(5)
					util.Effect("jcms_chargebeam", ed)
				end
			end)
		end

		if workedAmmo then
			self:EmitSound("weapons/shotgun/shotgun_cock.wav")
			if not workedHealth then -- Don't want to emit too many sounds.
				self:EmitSound("items/ammopickup.wav")
			end
			self:SetAmmoCashInside(0)

			timer.Simple(0.02, function()
				if IsValid(ply) then
					local ed = EffectData()
					ed:SetEntity(ply)
					ed:SetOrigin(pos)
					ed:SetMagnitude(1)
					ed:SetScale(5)
					ed:SetFlags(4)
					util.Effect("jcms_chargebeam", ed)
				end
			end)
		end

		if workedRad then 
			self:EmitSound("items/suitchargeok1.wav", 75, 85, 0.3)
			self:EmitSound("items/nvg_on.wav")
			self:SetAntiradInside(0)

			timer.Simple(0.02, function() --Not sure why we're using a timer but the other 2 have it so I'm repeating it here - J
				if IsValid(ply) then
					local ed = EffectData()
					ed:SetEntity(ply)
					ed:SetOrigin(pos)
					ed:SetMagnitude(1)
					ed:SetScale(5)
					ed:SetFlags(5)
					util.Effect("jcms_chargebeam", ed)
					
					local ed = EffectData()
					ed:SetEntity(hackTarget)
					ed:SetFlags(1)
					ed:SetColor(jcms.util_ColorInteger(Color(55,255,55)))
					util.Effect("jcms_shieldeffect", ed)
				end
			end)
		end

		if not (workedHealth or workedAmmo or workedRad) then
			self:EmitSound("items/suitchargeno1.wav")
		end

		if self:GetAmmoCashInside() <= 0 and self:GetHealthInside() <= 0 then
			self:EmitSound("Wood_Panel.Break")
			self:GibBreakClient(vector_origin)
			self:Remove()
			return true
		end

		return workedAmmo or workedHealth
	end

	function ENT:TryShareWithTeammates(mainPly, shareHealthAmount, shareAmmoCashAmount)
		local pos = self:WorldSpaceCenter()
		local shareRadius2 = self.ShareRadius^2
		for i, sweeper in ipairs(jcms.GetAliveSweepers()) do
			if (sweeper ~= mainPly) and (sweeper:WorldSpaceCenter():DistToSqr(pos) <= shareRadius2) and (sweeper:Visible(self)) then
				if self:TryGiveAmmo(sweeper, shareAmmoCashAmount) then
					timer.Simple(0.02, function()
						if IsValid(sweeper) then
							local ed = EffectData()
							ed:SetEntity(sweeper)
							ed:SetOrigin(pos)
							ed:SetMagnitude(0.6)
							ed:SetScale(3)
							ed:SetFlags(4)
							util.Effect("jcms_chargebeam", ed)
						end
					end)
				end

				if self:TryGiveHealth(sweeper, shareHealthAmount) then
					timer.Simple(0.02, function()
						if IsValid(sweeper) then
							local ed = EffectData()
							ed:SetEntity(sweeper)
							ed:SetOrigin(pos)
							ed:SetMagnitude(0.6)
							ed:SetScale(3)
							ed:SetFlags(5)
							util.Effect("jcms_chargebeam", ed)
						end
					end)
				end
			end
		end
	end

	function ENT:Use(activator, caller)
		if IsValid(activator) and activator:IsPlayer() and activator:GetObserverMode() == OBS_MODE_NONE and jcms.team_JCorp_player(activator) then
			local hadHealthInside, hadAmmoInside = self:GetHealthInside(), self:GetAmmoCashInside()
			local worked = self:TryGiveSuppliesAndBreak(activator)

			if worked then
				self:TryShareWithTeammates(activator, hadHealthInside >= 25 and 5 or 0, math.ceil(hadAmmoInside/10))
			end

			if not worked then
				activator:PickupObject(self)
			end
		end
	end
end

if CLIENT then
	function ENT:DrawTranslucent()
		local v = self:WorldSpaceCenter()
		v.z = v.z + 32
		local a = (EyePos() - v):Angle()
		a:RotateAroundAxis(a:Right(), -90)
		a:RotateAroundAxis(a:Up(), 90)

		local nick = self:GetOwnerNickname()

		local strFirstAid = language.GetPhrase("jcms.firstaid")
		local strAmmo = language.GetPhrase("jcms.restockammo")
		local strAntirad = language.GetPhrase("jcms.antirad")

		local ammoCashInside = self:GetAmmoCashInside()
		local healthInside = self:GetHealthInside()
		local antiradInside = self:GetAntiradInside()
		local strFFirstaid = language.GetPhrase("jcms.firstaidtip"):format(healthInside)
		local strFAmmo = language.GetPhrase("jcms.restocktip")
		local strFAntirad = language.GetPhrase("jcms.antiradtip"):format(antiradInside)

		local binding = tostring(input.LookupBinding("+use") or "USE"):upper()

		cam.Start3D2D(v, a, 1 / 8)
			if #nick > 0 then
				draw.SimpleText(nick, "jcms_hud_small", 0, -48, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local _, bth = draw.SimpleText("[ " .. binding .. " ]", "jcms_hud_big", 0, 0, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			if healthInside > 0 then
				draw.SimpleText(strFFirstaid, "jcms_medium", 0, bth - 4, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			if ammoCashInside > 0 and healthInside > 0 then
				draw.SimpleText(strAmmo, "jcms_medium", 0, -16, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(strFirstAid, "jcms_medium", 0, -22, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(strFFirstaid, "jcms_medium", 0, bth - 4, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(strFAmmo, "jcms_medium", 0, bth - 4 + 16, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif healthInside > 0 then
				draw.SimpleText(strFirstAid, "jcms_hud_small", 0, -16, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFFirstaid, "jcms_medium", 0, bth - 4, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif ammoCashInside > 0 then
				draw.SimpleText(strAmmo, "jcms_hud_small", 0, -16, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFAmmo, "jcms_medium", 0, bth - 4, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif antiradInside > 0 then
				draw.SimpleText(strAntirad, "jcms_hud_small", 0, -16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFAntirad, "jcms_medium", 0, bth - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		cam.End3D2D()

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
		v:Add( a:Up() )
		cam.Start3D2D(v, a, 1 / 8)
			if #nick > 0 then
				draw.SimpleText(nick, "jcms_hud_small", 0, -49, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if ammoCashInside > 0 and healthInside > 0 then
				draw.SimpleText(strAmmo, "jcms_medium", 0, -16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(strFirstAid, "jcms_medium", 0, -22, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(strFFirstaid, "jcms_medium", 0, bth - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(strFAmmo, "jcms_medium", 0, bth - 4 + 16, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif healthInside > 0 then
				draw.SimpleText(strFirstAid, "jcms_hud_small", 0, -16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFFirstaid, "jcms_medium", 0, bth - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif ammoCashInside > 0 then
				draw.SimpleText(strAmmo, "jcms_hud_small", 0, -16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFAmmo, "jcms_medium", 0, bth - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif antiradInside > 0 then
				draw.SimpleText(strAntirad, "jcms_hud_small", 0, -16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(strFAntirad, "jcms_medium", 0, bth - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			draw.SimpleText("[ " .. binding .. " ]", "jcms_hud_big", 0, -1, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		cam.End3D2D()
		render.OverrideBlend(false)
	end
end
