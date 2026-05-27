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

EFFECT.MatBeam = Material "sprites/physbeama"
EFFECT.MatGlow = Material "particle/Particle_Glow_04"
EFFECT.MatLight = Material "particle/fire"
EFFECT.MatColor = Material "models/wireframe"
EFFECT.RenderGroup = RENDERGROUP_TRANSLUCENT

function EFFECT:Init( data )
	self.color = jcms.util_ColorFromInteger(data:GetColor())
	self.colorCached = Color(self.color:Unpack())
	self.alphaout = 1

	if data:GetFlags() == 1 then -- originates from a portal
		self.isPortal = true
		self.origin = data:GetOrigin()
		self.entpos = data:GetStart()
		self.scale = data:GetScale()
		self:GenPoints()
		self.t = -data:GetMagnitude() or 0 -- preparation/pre-spawn glow to warn the player
		self.tout = 1
		self.fadein = 0
		self.fadeinSpeed = math.random(5, 23)
		
		self:EmitSound("ambient/fire/ignite.wav", 75, 200)
		if self.scale > 0.5 then
			self.emitter = ParticleEmitter(self.entpos)
		end
		
		self:SetRenderBoundsWS(self.origin, self.entpos, Vector(16, 16, 16))
	elseif data:GetFlags() == 0 or data:GetFlags() == 2 or data:GetFlags() == 3 then -- 0: appear, 2: disappear 3: disappear (ragdoll)
		self.isPortal = false
		self.ent = data:GetEntity()
		self.entpos = IsValid(self.ent) and self.ent:WorldSpaceCenter() or jcms.vectorOrigin
		self.t = 0
		
		self.tout = 3
		self.fadein = 1
		self.fadeinSpeed = 2
		self.reverse = data:GetFlags() == 2 or data:GetFlags() == 3
		self.useCollisionBounds = data:GetFlags() == 3

		if not self.entRenderOverride then
			self.entRenderOverride = self.ent.RenderOverride
			self.ent.RenderOverride = self.RenderEntity
			self.ent.jcms_spawneffect = self
		end
		
		self:EmitSound("ambient/fire/mtov_flame2.wav", 75, 160)
	end
	
	local ourPos = (self.origin or self.entpos) + Vector(0,0,5)
	if jcms.EyePos_lowAccuracy:DistToSqr(ourPos) > 400^2 then
		local tr = util.TraceLine({
			start = ourPos,
			endpos = jcms.EyePos_lowAccuracy,
			mask = MASK_VISIBLE
		})
		self.visibleAtStart = not tr.Hit
	else
		self.visibleAtStart = true
	end
end

function EFFECT:GenPoints()
	local selfTbl = self:GetTable()
	if not selfTbl.origin then return end

	if not selfTbl.points then
		selfTbl.points = {}
	else
		table.Empty(selfTbl.points)
	end

	selfTbl.points[1] = selfTbl.origin

	local n = math.random(4, 7)
	local distToOrigin = selfTbl.entpos:Distance(selfTbl.origin)
	for i=1, n do
		local nv = LerpVector(math.Remap(i+math.random()-0.5, 0, n+2, 0, 1), selfTbl.origin, selfTbl.entpos)
		local ox, oy, oz = nv:Unpack()

		local f = math.Remap(i, 0, n+1, 0, 1)
		local parabolic = math.max(0,-4*(f*f)+4*f)
	
		nv:SetUnpacked(ox+math.Rand(-10,10), oy+math.Rand(-10,10), oz+math.Rand(-10, 10) + parabolic*distToOrigin/2)
		selfTbl.points[i+1] = nv
	end
	selfTbl.points[n+2] = selfTbl.entpos
end

function EFFECT:Think()
	local selfTbl = self:GetTable()
	if selfTbl.t < selfTbl.tout then
		if selfTbl.isPortal then
			self:GenPoints()
		elseif not selfTbl.entRenderOverride then
			selfTbl.entRenderOverride = selfTbl.ent.RenderOverride
			selfTbl.ent.RenderOverride = selfTbl.RenderEntity
			selfTbl.ent.jcms_spawneffect = self
		end

		selfTbl.fadein = selfTbl.t > 0 and (selfTbl.fadein*16 + 2)/15 or (selfTbl.fadein*selfTbl.fadeinSpeed + 1)/(selfTbl.fadeinSpeed+1)
		if selfTbl.t > 0 then
			selfTbl.alphaout = selfTbl.alphaout / 1.5
		end

		selfTbl.t = math.min(selfTbl.tout, selfTbl.t + FrameTime())
		return true
	else
		if not selfTbl.isPortal and IsValid(selfTbl.ent) then
			selfTbl.ent.RenderOverride = selfTbl.entRenderOverride
		end

		if selfTbl.emitter then
			selfTbl.emitter:Finish()
		end

		return false
	end
end

function EFFECT:Render()
	local selfTbl = self:GetTable()
	if selfTbl.isPortal and selfTbl.t <= 1 then
		local whiteFactor = math.Clamp( (2 + selfTbl.t)/2, 0, 1)
		local dist = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())

		local clr = selfTbl.colorCached

		local lodLevel = dist < (1000*selfTbl.scale)^2 and 0 or dist < (2500*selfTbl.scale)^2 and 1 or 2
		if selfTbl.points then

			if lodLevel == 0 and selfTbl.visibleAtStart then
				if IsValid(selfTbl.emitter) and math.random() < selfTbl.alphaout and FrameTime() > 0 then
					local p = selfTbl.emitter:Add("Effects/blueflare1", selfTbl.entpos)
					if p then
						local vec = VectorRand()
						vec:Normalize()
						vec:Mul( math.Rand(16, 32) )
						vec:Mul(selfTbl.scale)
						p:SetVelocity(vec)
						
						vec:SetUnpacked(math.random()-0.5, math.random()-0.5, math.random()-0.5)
						vec:Normalize()
						vec:Mul( math.Rand(64, 128) )
						vec:Mul(selfTbl.scale)
						p:SetGravity(VectorRand(-32, 32))
		
						local size = math.Rand(0.2, math.max(4, selfTbl.scale*2))
						p:SetStartSize(size*size)
						p:SetEndSize(0)
						p:SetStartLength(size*size) 
						p:SetEndLength(size*size*1.25)
						p:SetDieTime(0.5 + math.random()*selfTbl.scale)
		
						local r,g,b = selfTbl.color:Unpack()
						r = Lerp(whiteFactor, r, 255)
						g = Lerp(whiteFactor, g, 255)
						b = Lerp(whiteFactor, b, 255)
						p:SetColor(r,g,b)
					end
				end
			end

			render.SetMaterial(selfTbl.MatBeam)
			
			if lodLevel == 0 or (lodLevel == 1 and selfTbl.alphaout > 0.5) then
				local n = #selfTbl.points
				render.StartBeam(n)
				for i, point in ipairs(selfTbl.points) do
					clr:SetUnpacked(selfTbl.color:Unpack())
					clr.a = selfTbl.alphaout * 255 / n*i
					render.AddBeam(point, math.Remap(i, 1, n, 7, 8*selfTbl.scale), math.Remap(i, 1, n, 0, 1), clr)
				end
				render.EndBeam()
			else
				clr:SetUnpacked(selfTbl.color:Unpack())
			end

			local center = selfTbl.entpos
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				render.SetMaterial(selfTbl.MatGlow)
				local f = selfTbl.fadein * (selfTbl.scale + whiteFactor^2)

				if lodLevel <= 1 then
					clr.a = selfTbl.alphaout*255
				end

				if lodLevel == 0 then
					render.DrawSprite(center, f*(128 + math.random()*16), f*(48 + math.random()*4), clr)
				end

				if lodLevel <= 1 then
					render.DrawSprite(center, f*(64 + math.random()*6), f*(72 + math.random()*18), clr)
				end

				clr:SetUnpacked(255, 255, 255, selfTbl.alphaout*255)
				render.DrawSprite(center, f*(32 + math.random()*8), f*(32 + math.random()*8), clr)
			render.OverrideBlend(false)
			render.SetBlend(1)
		end
	end
end

local dn = -jcms.vectorUp
function EFFECT:RenderEntity()
	if not IsValid(self) then
		return
	end
	
	local effect = self.jcms_spawneffect
	if not IsValid(effect) then 
		self.RenderOverride = nil 
		self.jcms_spawneffect = nil 
		self:DrawModel()
		return 
	end

	local mins, maxs
	if effect.useCollisionBounds then --needed to work with ragdolls
		mins, maxs = self:GetCollisionBounds()
		mins:Sub(jcms.vectorOne)
		maxs:Add(jcms.vectorOne)
	else
		mins, maxs = self:GetModelRenderBounds()
	end
	
	local mypos = self:GetPos()
	mins:Add(mypos)
	maxs:Add(mypos)

	local eyeDist = jcms.EyePos_lowAccuracy:DistToSqr(mypos)

	local time = effect.reverse and math.max(0, 2-effect.t) or effect.t

	local modelIn = time-1 < 1 and math.ease.InOutCubic(math.Clamp(time-1, 0, 1)) or time-1
	local wireIn = time < 1 and math.ease.InOutCubic(math.Clamp(math.sqrt(time), 0, 1)) or time
	local vbound = LerpVector(modelIn, mins, maxs)
	local vbound2 = LerpVector(wireIn, mins, maxs)
	local old = render.EnableClipping(true)

	if eyeDist < 3000^2 then
		if time < 2 and eyeDist < 1500^2 then
			local centered = Vector(mypos)
			centered.z = (time>1 and vbound or vbound2).z

			local f = time%1
			local parabolic = math.max(0,-4*(f*f)+4*f)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				render.SetMaterial(effect.MatGlow)
				render.DrawQuadEasy(centered, jcms.vectorUp, math.Rand(48,72)*parabolic, math.Rand(48,72)*parabolic, effect.color)
				render.SetMaterial(effect.MatLight)
				render.DrawSprite(centered, 96*parabolic, 12*parabolic, effect.color)
			render.OverrideBlend(false)
		end

		if effect.visibleAtStart or modelIn == 0 then
			-- Model
			render.PushCustomClipPlane(dn, dn:Dot(vbound2))
				render.PushCustomClipPlane(jcms.vectorUp, jcms.vectorUp:Dot(vbound))
					render.MaterialOverride(effect.MatColor)
						local mr,mg,mb = render.GetColorModulation()
						local mod = Lerp(time-1,128,48)

						local cr, cg, cb = effect.color:Unpack()
						render.SetColorModulation(cr/mod, cg/mod, cb/mod)
						self:DrawModel()
						render.SetColorModulation(mr,mg,mb)
					render.MaterialOverride()
				render.PopCustomClipPlane()
			render.PopCustomClipPlane()
		end
	end

	if modelIn > 0 then 
		-- Overlay
		render.PushCustomClipPlane(dn, dn:Dot(vbound))
			self:DrawModel()
		render.PopCustomClipPlane()
	end

	render.EnableClipping(old)
end
