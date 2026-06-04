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
ENT.PrintName = "Flare"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/items/flare.mdl")
		self:SetPos( self:GetPos() + Vector(0, 0, 1) )
		self:SetAngles( Angle(0, math.random()*360, 0) )
	end

	if CLIENT then
		self:EmitSound("Weapon_FlareGun.Single")
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "BeamColour")

	if SERVER then
		self:SetBeamColour(Vector(1, 0, 0))
	end
end

if SERVER then
	function ENT:DropThing(thingClass, delay, locatorName)
		local skyPos, isClear = jcms.util_GetSky(self:GetPos() + Vector(0, 0, 2))
		
		if skyPos and isClear then
			self.thing = ents.Create(thingClass)
			self.thing:SetPos(skyPos + Vector(0, 0, -32))

			local dist = self:GetPos():Distance( self.thing:GetPos() )
			local timeToArrive = dist / 980

			if timeToArrive > delay then
				-- Sky is too far away to make it in time. Spawn it lower.
				local fraction = delay / timeToArrive
				local adjustedDist = dist * fraction
				local adjustedPos = self:GetPos()
				adjustedPos.z = adjustedPos.z + adjustedDist
				self.thing:SetPos(adjustedPos)

				timer.Simple(0.1, function()
					if IsValid(self.thing) then
						self.thing:Spawn()

						if IsValid(self.thing:GetPhysicsObject()) then
							self.thing:GetPhysicsObject():Wake()
							self.thing:GetPhysicsObject():SetVelocity( Vector(0, 0, -200) )
						else
							jcms.printf("cant awaken physobj of dropped entity %s?", self.thing)
						end

						if CPPI then
							self.thing:CPPISetOwner( game.GetWorld() )
						end
					end
				end)
			else
				-- Low ceiling. Spawn the dropped-thing later.
				local excessTime = math.max(delay - timeToArrive, 0)
				
				timer.Simple(excessTime, function()
					if IsValid(self.thing) then
						self.thing:Spawn()

						if IsValid(self.thing:GetPhysicsObject()) then
							self.thing:GetPhysicsObject():Wake()
							self.thing:GetPhysicsObject():SetVelocity( Vector(0, 0, -250) )
						else
							jcms.printf("cant awaken physobj of dropped entity %s?", self.thing)
						end

						if CPPI then
							self.thing:CPPISetOwner( game.GetWorld() )
						end
					end
				end)
			end
		else
			delay = delay * 2 + 5
			self.thing = ents.Create(thingClass)
			self.thing:SetPos(self:GetPos() + Vector(0, 0, 45))
			
			local colVec = self:GetBeamColour()
			local colorInt = jcms.util_ColorIntegerFast(colVec.r*255, colVec.g*255, colVec.b*255)
			local ed = EffectData()
			ed:SetColor(colorInt)
			ed:SetFlags(1)
			ed:SetOrigin(self:GetPos())
			ed:SetStart(self.thing:GetPos())
			ed:SetMagnitude(delay)
			ed:SetScale(1.25)
			util.Effect("jcms_spawneffect", ed)

			timer.Simple(delay, function()
				if IsValid(self.thing) then
					self.thing:Spawn()

					if IsValid(self.thing:GetPhysicsObject()) then
						self.thing:GetPhysicsObject():Wake()
					else
						jcms.printf("cant awaken physobj of dropped entity %s?", self.thing)
					end
					
					local ed = EffectData()
					ed:SetColor(colorInt)
					ed:SetFlags(0)
					ed:SetEntity(self.thing)
					util.Effect("jcms_spawneffect", ed)

					if CPPI then
						self.thing:CPPISetOwner( game.GetWorld() )
					end
				end
			end)
		end

		self.removeTime = CurTime() + delay
		jcms.net_SendLocator("all", nil, locatorName, self:GetPos() + Vector(0, 0, 16), jcms.LOCATOR_TIMED, delay, nil, self.jcms_owner)
		
		return self.thing
	end
	
	function ENT:Think()
		if self.removeTime and CurTime() >= self.removeTime then
			self:Remove()
		end
	end
end

if CLIENT then
	ENT.mat = Material "trails/laser.vmt"
	ENT.mat_spark = Material "sprites/light_glow02_add.vmt"
	ENT.mat_light = Material("particle/fire")
	
	function ENT:Think()
		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		
		local tr = util.TraceLine {
			start = self:GetPos(),
			endpos = self:WorldSpaceCenter() + self:GetAngles():Up() * 16000,
			mask = MASK_NPCWORLDSTATIC,
			filter = self
		}
		
		self:SetRenderBoundsWS(tr.StartPos, tr.HitPos, Vector(4, 4, 4))
		self.beamStart = tr.StartPos
		self.beamEnd = tr.HitPos
		self.beamHitSky = tr.HitSky

		if self.beamHitSky then
			self.beamEnd.z = self.beamEnd.z + 32000
		end
	end
	
	function ENT:Draw()
		self:DrawModel()
	end
	
	function ENT:DrawTranslucent()
		local colVec = self:GetBeamColour()
		local col = Color(colVec.r*255, colVec.g*255, colVec.b*255)

		render.SetMaterial(self.mat_spark)
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
		render.DrawSprite(self:GetPos(), 64, 24, col)
		render.OverrideBlend(false)
		
		if self.beamStart and self.beamEnd then
			local distToEyes = util.DistanceToLine(self.beamStart, self.beamEnd, EyePos())
			local wmul = math.max(1, distToEyes/1000)
			render.SetMaterial(self.mat)
			render.DrawBeam(self.beamStart, self.beamEnd, math.Rand(4, 6)*wmul, 0, 1, col)
			
			local off = (-CurTime()*4)%4
			render.SetMaterial(self.mat_spark)
			render.DrawBeam(self.beamEnd, self.beamStart, 12*wmul, off/4-0.25, off/4, col)
		end
		
		local dl = DynamicLight(self:EntIndex())
		if dl then
			local pos = self:GetPos()
			pos.z = pos.z + 10
			dl.pos = pos
			dl.r = col.r
			dl.g = col.g
			dl.b = col.b
			dl.brightness = math.Rand(2, 4)
			dl.size = math.Rand(250, 260)
			dl.decay = 0.1
			dl.dietime = CurTime() + 0.1
		end
	end
end
