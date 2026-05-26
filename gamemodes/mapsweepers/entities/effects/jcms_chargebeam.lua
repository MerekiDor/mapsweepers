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

EFFECT.mat_beam = Material "trails/plasma"
EFFECT.mat_soul = Material "effects/fluttercore_gmod"

EFFECT.RenderGroup = RENDERGROUP_TRANSLUCENT

function EFFECT:Init( data )
	self.origin = data:GetOrigin()
	self.ent = data:GetEntity()
	self.type = data:GetFlags()

	self.t = 0
	self.seed = math.random()*256

	self.color = Color(255, 255, 255)

	-- Type 0: shield charge
	-- Type 1: soul absorbed into the flashpoint
	-- Type 2: spirit's release/absorption effect
	-- Type 3: RGG grunt teleportation/phasing
	-- Type 4: Ammo restock
	-- Type 5: Health restock
	if self.type == 0 then
		self.tout = 0.25
	elseif self.type == 1 or self.type == 2 then
		self.tout = 1.85
		self:EmitSound("ambient/levels/citadel/portal_beam_shoot5.wav", 100, self.type == 2 and 200 or math.random(90, 110), 1)
	elseif self.type == 3 then
		self.tout = 1.5
		self:EmitSound("npc/vort/vort_attack_shoot4.wav", 80, 152, 1)
	elseif self.type == 4 or self.type == 5 then
		self.tout = data:GetMagnitude()
		self.nsprites = math.ceil(data:GetScale())
		self.mat = self.type == 4 and Material("jcms/beam_ammo.png") or Material("jcms/beam_heal.png")
	end

	if self.type == 3 then
		if IsValid(self.ent) then
			self.endpos = self.ent:WorldSpaceCenter()
		else
			self.endpos = Vector(self.origin)
		end
	elseif self.type == 3 or self.type == 4 then
		self:GenSprites()
	else
		self:GenPoints()
	end

	if IsValid(self.ent) then
		self:SetRenderBoundsWS(self.origin, self.ent:WorldSpaceCenter())
	end
end

function EFFECT:Think()
	local selfTbl = self:GetTable()
	if (selfTbl.t < selfTbl.tout) and IsValid(selfTbl.ent) then
		selfTbl.t = selfTbl.t + FrameTime()

		if selfTbl.type < 3 then
			self:GenPoints()
		elseif selfTbl.mat then
			self:GenSprites()
		end

		return true
	else
		return false
	end
end

function EFFECT:GenPoints()
	local selfTbl = self:GetTable()
	if not selfTbl.origin then return end

	if not selfTbl.points then
		if IsValid(selfTbl.ent) then
			local ent = selfTbl.ent
			local entTbl = ent:GetTable()

			selfTbl.points = { selfTbl.origin }
			selfTbl.targetpos = entTbl.jcms_GetChargeBeamPos and entTbl.jcms_GetChargeBeamPos(self) or ent:WorldSpaceCenter()

			local n = math.random(25, 30)
			for i=1, n do
				local f = math.TimeFraction(1, n, i)
				local parabolic = math.max(0,-4*(f*f)+4*f)
				local nv = LerpVector(math.Remap(i+math.random()-0.5,0,n+2,0,1), selfTbl.origin, selfTbl.targetpos)
				selfTbl.points[i+1] = nv
			end
			selfTbl.points[n+2] = selfTbl.entpos
		end
	else
		local n = #selfTbl.points
		local delta = FrameTime()*70
		local tSeed = selfTbl.t + selfTbl.seed

		for i, nv in ipairs(selfTbl.points) do
			local f = math.TimeFraction(1, n, i)
			local parabolic = math.max(0,-4*(f*f)+4*f)*delta
			
			local progress = tSeed + i/n
			local rx = math.sin(progress)
			local ry = math.sin(progress + 62)
			local rz = math.sin(progress + 523) --so true merekidor - j
			
			local nvx, nvy, nvz = nv:Unpack()
			nv:SetUnpacked(nvx + rx*parabolic, nvy + ry*parabolic, nvz + rz*parabolic)
		end
	end
end

function EFFECT:GenSprites()
	local selfTbl = self:GetTable()
	if not selfTbl.sprites then
		if not IsValid(selfTbl.ent) then
			return
		end
		selfTbl.sprites = {}

		for i=1, selfTbl.nsprites + math.random(0, 1) do
			local nv = selfTbl.ent:WorldSpaceCenter()
			local ox, oy, oz = nv:Unpack() --old x/y/z
			nv:SetUnpacked(math.Rand(-32, 32) + ox, math.Rand(-32, 32) + oy, math.Rand(-32, 32) + oz) 

			table.insert(selfTbl.sprites, nv)
		end
	else
		local n = #selfTbl.sprites
		local delta = FrameTime()*20
		local validEnt = IsValid(selfTbl.ent) and selfTbl.ent
		local tSeed = selfTbl.t + selfTbl.seed

		for i, nv in ipairs(selfTbl.sprites) do
			local f = math.TimeFraction(1, n, i)
			local parabolic = 1 + math.max(0,-4*(f*f)+4*f)/3
			
			local progress = tSeed + i/n
			local rx = math.sin(progress)
			local ry = math.sin(progress + 62)
			local rz = math.sin(progress + 523)
			
			local pbDelta = parabolic*delta
			local ox, oy, oz = nv:Unpack()
			nv:SetUnpacked(ox + rx*pbDelta, oy + ry*pbDelta, oz + rz*pbDelta)

			if validEnt then
				local towards = validEnt:WorldSpaceCenter() - nv
				towards:Div(50)
				towards:Mul(delta)
				nv:Add(towards)
			end
		end
	end
end

function EFFECT:Render()
	local selfTbl = self:GetTable()
	if IsValid(selfTbl.ent) then
		if selfTbl.type == 4 or selfTbl.type == 5 then
			local tf = selfTbl.t / selfTbl.tout
			local timeParabolic = math.max(0,-4*(tf*tf)+4*tf)
			local pinch = 3

			if selfTbl.type == 4 then
				selfTbl.color:SetUnpacked(255, 32, 37)
			else
				selfTbl.color:SetUnpacked(128, 255, 64)
			end

			local start = selfTbl.origin
			local endpos = selfTbl.ent:GetPos()
			local rad = selfTbl.ent:GetModelRadius() / 3
			local mins, maxs = selfTbl.ent:GetRenderBounds()

			local mat = selfTbl.mat
			render.SetMaterial(selfTbl.mat_beam)

			local spins = 3
			local n = spins * 8
			render.StartBeam(n+1)
				selfTbl.color.a = 128*timeParabolic
				render.AddBeam(start, 0, 0, selfTbl.color)
				for i=1,n do
					local f = math.TimeFraction(1, n, i)
					local alphamax = math.max(0, 1 - pinch*math.abs(Lerp(tf*2-0.5+1-i/n, 1+1/pinch, -1/pinch)))
					local parabolic = math.max(0,-4*(f*f)+4*f)*timeParabolic
					local ang = f*math.pi*2*spins + tf*math.pi*2
					local radi = rad/2 + rad/4*parabolic + rad/3*alphamax

					local v = Vector(endpos.x + math.cos(ang)*radi, endpos.y + math.sin(ang)*radi, endpos.z + Lerp(f/2+0.25, maxs.z, mins.z))
					selfTbl.color.a = math.max(64*timeParabolic, alphamax*255)
					render.AddBeam(v, parabolic*8 + 2 + (1-f)*8, f*4, selfTbl.color)
				end
			render.EndBeam()

			if selfTbl.sprites then
				render.SetMaterial(selfTbl.mat)
				local n = #selfTbl.sprites
				for i, nv in ipairs(selfTbl.sprites) do
					local f = math.TimeFraction(1, n, i)
					local parabolic = math.max(0,-4*(f*f)+4*f)*timeParabolic
					local size = Lerp(parabolic, 4, 16)
					render.DrawSprite(nv, size, size, selfTbl.color)
				end
			end
		elseif selfTbl.type == 3 then
			local tf1 = math.Clamp(selfTbl.t*4 / selfTbl.tout, 0, 1)
			local timeParabolic1 = math.max(0,-4*(tf1*tf1)+4*tf1)
			local tf2 = math.Clamp( (selfTbl.t-0.23)*5 / selfTbl.tout, 0, 1)
			local timeParabolic2 = math.max(0,-4*(tf2*tf2)+4*tf2)

			--[[selfTbl.color.r = 255*(1-tf1^2)
			selfTbl.color.g = 30 *(1-tf2)
			selfTbl.color.b = 255 - 55*tf2--]]
			
			local r = Lerp(timeParabolic1, 255, 230)
			local g = Lerp(tf1, 64, 14)
			local b = Lerp(tf1, 100, 14)
			local a = 255*(1-tf2^2)
			selfTbl.color:SetUnpacked(r,g,b,a)

			render.SetMaterial(selfTbl.mat_soul)
			render.DrawSprite(selfTbl.origin, 100 * timeParabolic1^2, 150 * timeParabolic1, selfTbl.color)
			render.DrawSprite(selfTbl.endpos, 100 * timeParabolic2^2, 150 * timeParabolic2, selfTbl.color)

			render.SetMaterial(selfTbl.mat_beam)
			render.StartBeam(2)
				render.AddBeam(selfTbl.origin, 100, 0, selfTbl.color)
				render.AddBeam(selfTbl.endpos, 100, 1, selfTbl.color)
			render.EndBeam()
		elseif selfTbl.points then
			render.SetMaterial(selfTbl.mat_beam)
			
			local n = #selfTbl.points
			local tf = selfTbl.t / selfTbl.tout
			if selfTbl.type == 2 then tf = 1-tf end
			local timeParabolic = math.max(0,-4*(tf*tf)+4*tf)
			
			local pinch = 1
			render.StartBeam(n)
			
			render.OverrideBlend( true, BLEND_SRC_COLOR, BLEND_ONE, BLENDFUNC_ADD )

			if selfTbl.type == 0 then
				selfTbl.color.r = Lerp(timeParabolic, 230, 14)
				selfTbl.color.g = Lerp(tf, 200, 0)
				selfTbl.color.b = Lerp(tf, 255, 230)
			elseif selfTbl.type == 1 or selfTbl.type == 2 then
				selfTbl.color.r = Lerp(timeParabolic, 255, 230)
				selfTbl.color.g = Lerp(tf, 64, 14)
				selfTbl.color.b = Lerp(tf, 100, 14)
			end

			for i, point in ipairs(selfTbl.points) do
				local f = math.TimeFraction(1, n, i)
				local alphamax = math.max(0, 1 - pinch*math.abs(Lerp(tf*2-1+1-i/n, 1+1/pinch, -1/pinch)))
				local parabolic = math.max(0,-4*(f*f)+4*f)*timeParabolic

				render.AddBeam(point, 15*parabolic + timeParabolic*8, math.Remap(i, 1, n, 0, tf), ColorAlpha(selfTbl.color, math.max(alphamax*255, parabolic*64)))
			end
			
			if selfTbl.type == 1 or selfTbl.type == 2 then 
				local tf = math.min(1, math.max(0, selfTbl.t - 0.15)*3 / selfTbl.tout)
				local timeParabolic = math.max(0,-4*(tf*tf)+4*tf)
			
				render.SetMaterial(selfTbl.mat_soul)
				render.DrawSprite(selfTbl.origin, 95 * timeParabolic^2, 64 * timeParabolic, selfTbl.color)
			end
			
			render.OverrideBlend( false )
			
			render.EndBeam()
		end
	end
end
