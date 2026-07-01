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

EFFECT.mat_ring1 = Material "jcms/ring"
EFFECT.mat_ring2 = Material "effects/fluttercore_gmod"
EFFECT.mat_fire1 = Material "effects/fire_cloud1.vtf"
EFFECT.mat_fire2 = Material "effects/fire_cloud2.vtf"
EFFECT.mat_fire3 = Material "particle/smokesprites_0002"
EFFECT.mat_ember1 = Material "effects/fire_embers2"
EFFECT.mat_ember2 = Material "effects/fire_embers3"
EFFECT.mat_discharge = Material "sprites/physbeama"

EFFECT.RenderGroup = RENDERGROUP_TRANSLUCENT
PrecacheParticleSystem("explosion_huge")

-- NOTE: This code is REALLY shitty, but this is pretty late into production, so I'll have to work with this.
function EFFECT:Init( data )
	self.pos = data:GetOrigin()
	self.size = data:GetRadius()
	self.normal = data:GetNormal()
	self.normal:Rotate(AngleRand(-16, 16))
	self.blasttype = data:GetFlags()
	-- 1: Normal blast
	-- 2: J-Blast
	-- 3: Smoke blast
	-- 4: Boomer blast
	-- 5: Electric explosion
	-- 6: Nuke
	-- 7: M-Blast (Type 2 but mafia)

	if self.blasttype == 6 then
		self.nukeEffect = CreateParticleSystem( self, "explosion_huge", PATTACH_ABSORIGIN_FOLLOW)
		
		self.t = 0
		self.tout = 0.25

		return
	end
	
	self.normal2 = VectorRand()
	self.normal2:Normalize()
	
	local durationMul = data:GetMagnitude() or 1
	
	self.t = 0
	self.tout = math.Rand(0.85, 1.12) * durationMul
	if self.blasttype == 5 then
		self.color = jcms.util_ColorFromInteger(data:GetColor())
		self.color_aux = Color( self.color.r, self.color.g, self.color.b )
	elseif self.blasttype == 3 then
		self.color = jcms.util_ColorFromInteger(data:GetColor())
		self.color_aux = Color(self.color.r, self.color.g, self.color.b)
		--self.color = Color(200, 200, 200, 255)
		--self.color_aux = Color(200, 200, 200, 255)
	else
		self.color = Color(255, 255, 255, 255)
		self.color_ring = Color(255, 255, 255, 255)
		self.color_ring2 = Color(255, 255, 255, 255)
		self.altmat = math.random() < 0.5
	end
	
	local dl = DynamicLight( data:GetFlags() )
	if dl then
		dl.pos = self.pos
		
		if self.blasttype == 1 or self.blasttype == 4 then
			dl.r = 255
			dl.g = 130
			dl.b = 50
			dl.brightness = 6
		elseif self.blasttype == 2 then
			dl.r = 255
			dl.g = 0
			dl.b = 32
			dl.brightness = 5
		elseif self.blasttype == 3 then
			dl.r = 255
			dl.g = 255
			dl.b = 255
			dl.brightness = 3
		elseif self.blasttype == 5 then
			dl.r = self.color.r
			dl.g = self.color.g
			dl.b = self.color.b
			dl.brightness = 2
		elseif self.blasttype == 7 then
			dl.r = 255
			dl.g = 160
			dl.b = 32
			dl.brightness = 5
		end
		
		dl.decay = 1000
		dl.size = self.size * 1.2
		dl.dietime = CurTime() + 1
	end
	
	self.pointsize = self.size/2
	if self.blasttype == 3 then
		self.smokepoints = {}
		for i=1, 32 do
			local v = VectorRand(-2, 2)
			v:Normalize()
			v.z = v.z*v.z
			v:Mul(math.Rand(32, self.size+i))
			v:Add(self.pos)
			v.z = v.z + 12
			
			local norm = Vector(0, 0, 1)
			norm:Normalize()
			table.insert(self.smokepoints, { util.TraceLine({ start = v, endpos = v, mask = MASK_SHOT_HULL }).HitPos, VectorRand(-4, 4), math.Rand(self.pointsize, self.pointsize*3), 0, render.ComputeLighting(v, norm) })
		end
		
		local sizevec = Vector(self.size+32, self.size+32, self.size+32)
		self:SetRenderBounds(-sizevec, sizevec)
	elseif self.blasttype == 4 then
		local mins = Vector(-8, -8, -8)
		local maxs = Vector(8, 8, 8)

		local startpos = self.pos + self.normal * 16
		self.nearPoint1 = startpos + VectorRand(-100, 100)
		self.nearPoint2 = startpos + VectorRand(-100, 100)
		self.nearSize1 = math.Rand(0.4, 0.6)
		self.nearSize2 = math.Rand(0.5, 0.7)

		for i=1, math.random(12, 16) do
			local len = math.Rand(100, 400)
			local normal = VectorRand()

			local tr = util.TraceHull {
				start = startpos,
				endpos = self.pos + normal * len,
				mask = MASK_DEADSOLID,
				mins = mins,
				maxs = maxs
			}

			tr.StartPos.x = tr.StartPos.x + math.Rand(-16, 16)
			tr.StartPos.y = tr.StartPos.y + math.Rand(-16, 16)
			tr.StartPos.z = tr.StartPos.z + math.Rand(-16, 16)

			local count = math.ceil((len * tr.Fraction) / 16)
			local speed =  math.Rand(0.004, 0.02)
			for j=1, count do
				timer.Simple(i/512 + j*speed, function()
					if IsValid(self) then
						local ed = EffectData()
						ed:SetEntity(self)
						local bv = Lerp((j-1)/(count-1), tr.StartPos, tr.HitPos)
						bv.x = bv.x + math.Rand(-16, 16)
						bv.y = bv.y + math.Rand(-16, 16)
						bv.z = bv.z + math.Rand(-16, 16) - 4
						ed:SetScale(math.random()*10)
						ed:SetOrigin(bv)
						ed:SetColor(math.random(1, 3))
						util.Effect("BloodImpact", ed)
					end
				end)
			end

			if IsValid(tr.Entity) or tr.HitWorld then
				util.Decal("Blood", tr.StartPos, tr.StartPos + tr.Normal*len*2)
			end
		end

		local ed = EffectData()
		ed:SetOrigin(self.pos)
		ed:SetScale(300)
		ed:SetEntity(self)
		util.Effect("ThumperDust", ed)
		util.Decal("Scorch", self.pos, self.pos + Vector(0, 0, -48))
	elseif self.blasttype == 5 then
		self:EmitSound("npc/scanner/scanner_electric2.wav", 100, 125, 1)
	end
end

function EFFECT:Think()
	if self.t < self.tout then
		if self.nukeEffect and not self.nuked then
			self.nukeEffect:StartEmission()
			self.nuked = true

			jcms.colormod_Add(Color(100,255,100), 0.75, 0, 0.05, 0, 0.15)
			jcms.colormod_Add(Color(0,60,0), 0.75, 0.05, 0.15, 0, 4.5)
		end

		self.t = math.min(self.tout, self.t + FrameTime())
		return true
	else
		return false
	end
end

function EFFECT:Render()
	local selfTbl = self:GetTable()

	local f = selfTbl.t / selfTbl.tout
	
	if selfTbl.blasttype == 3 then
		local intime = 0.2 / selfTbl.tout
		local f_insize = math.min(1, f/intime)
		local f_fadeout = f < intime and 1-f_insize or ( (f - intime) / (1 - intime) )^4
		selfTbl.color.a = 255 * (1-f_fadeout)
		
		local ep = jcms.EyePos_lowAccuracy
		for i, pt in ipairs(selfTbl.smokepoints) do
			pt[4] = pt[1]:DistToSqr(ep)
		end
		
		render.SetMaterial(selfTbl.mat_fire3)
		table.sort(selfTbl.smokepoints, selfTbl.SmokeSorter)
		
		local dt = FrameTime()
		for i, pt in ipairs(selfTbl.smokepoints) do
			local x, y, z = pt[5]:Unpack()
			local r, g, b, a = selfTbl.color_aux:Unpack()
			selfTbl.color_aux:SetUnpacked(r * math.min(1, (x + 0.5)/2), g * math.min(1, (y + 0.5)/2), b * math.min(1, (z + 0.5)/2), a)

			pt[1]:Add(pt[2] * dt)
			render.DrawSprite(pt[1], pt[3]*f_insize, pt[3]*f_insize, selfTbl.color_aux)
		end
		
		local distFrac = ep:DistToSqr(selfTbl.pos) / (selfTbl.size + 64)^2
		if distFrac < 1 then
			cam.Start2D()
				local r, g, b = selfTbl.color:Unpack()
				surface.SetDrawColor(r, g, b, math.sqrt(Lerp(math.min(1, distFrac*2), 1, 0))*selfTbl.color.a)
				surface.DrawRect(-4, -4, ScrW()+8, ScrH()+8)
			cam.End2D()
		end
	elseif selfTbl.blasttype == 4 then			
		f = math.ease.OutQuad(f)
		local a_ring = math.max(0, 1-f)
		local ringsize = Lerp(f, selfTbl.size*0.5, selfTbl.size*2 + 8)
		selfTbl.color_ring.r = 255*a_ring*a_ring
		selfTbl.color_ring.g = 255*a_ring
		selfTbl.color_ring.b = 255*a_ring*a_ring
		selfTbl.color_ring.a = 255*a_ring
		
		local a_ring2 = math.max(0, 1-f*2)
		local ringsize2 = Lerp(f, selfTbl.size*0.75, selfTbl.size*3 + 16)
		selfTbl.color_ring2.r = 200*a_ring2*a_ring
		selfTbl.color_ring2.g = 180*a_ring2
		selfTbl.color_ring2.b = 190*a_ring2*a_ring2
		selfTbl.color_ring2.a = 255*a_ring2
		
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.SetColorMaterial()
			render.DrawSphere(selfTbl.pos, ringsize/2, 7, 7, selfTbl.color_ring)
			
			render.SetMaterial(selfTbl.mat_ring1)
			render.DrawQuadEasy(selfTbl.pos, selfTbl.normal, ringsize, ringsize, selfTbl.color_ring)
			render.DrawQuadEasy(selfTbl.pos, selfTbl.normal2, ringsize2, ringsize2, selfTbl.color_ring2)
		render.OverrideBlend( false )
	elseif selfTbl.blasttype == 5 then
		local f_flash = 1 - 0.1 / (0.1 + f)
		local a_flash = math.max(0, 1-f*4)
		local e_flash = math.max(0, 1-f*3)

		if a_flash > 0 then
			selfTbl.color.r = selfTbl.color_aux.r*a_flash*a_flash
			selfTbl.color.g = selfTbl.color_aux.g*a_flash
			selfTbl.color.b = selfTbl.color_aux.b*a_flash

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				render.SetMaterial(selfTbl.mat_ring2)
				render.DrawSprite(selfTbl.pos, selfTbl.size*e_flash*2, selfTbl.size*e_flash*2, selfTbl.color)
				render.SetColorMaterial()
				selfTbl.color.a = 100 * a_flash
				render.DrawSphere(selfTbl.pos, selfTbl.size*f_flash, 4, 4, selfTbl.color)
			render.OverrideBlend(false)

			render.SetMaterial(selfTbl.mat_discharge)
			selfTbl.color.a = 255 * a_flash
			for i=1, math.random(4, 7) do
				local beamLen = math.random(2, 5)
				render.StartBeam(beamLen)
					local beamv = Vector(selfTbl.pos)
					local beamn = VectorRand(-1, 1)
					beamn:Normalize()
					beamn:Mul(32*a_flash)
					local beamw = math.Rand(4, 25)

					for j=1, beamLen do
						render.AddBeam(beamv, beamw, (j-1)/(beamLen-1), selfTbl.color)
						beamw = beamw * 0.9
						beamv:Add(beamn)

						beamn.x = beamn.x + math.Rand(-24, 24)
						beamn.y = beamn.y + math.Rand(-24, 24)
						beamn.z = beamn.z + math.Rand(-24, 24)
						beamn:Normalize()
						beamn:Mul(32)
					end
				render.EndBeam()
			end
		end
	elseif selfTbl.blasttype == 6 then
		local blastCol = Color(175, 255, 175, 200 * (1-f)^2)
		render.SetColorMaterial()
		render.DrawSphere( selfTbl.pos, 4500 * f^1.5, 12, 12, blastCol)
		render.DrawSphere( selfTbl.pos, -4500 * f^1.5, 12, 12, blastCol )

		local ringCol = Color(150, 255, 150, 200 * (1-f)^2)
		render.SetMaterial(selfTbl.mat_ring1)
		render.DrawQuadEasy(selfTbl.pos, jcms.vectorUp, 6500*f*4, 6500*f*4, ringCol)
	else
		local f_flash = 1 - 0.1 / (0.1 + f)
		local a_flash = math.max(0, 1-f*4)
		local e_flash = math.max(0, 1-f*3)
	
		if a_flash > 0 then
			if selfTbl.blasttype == 1 then
				selfTbl.color.r = 255*a_flash
				selfTbl.color.g = 255*a_flash*a_flash
				selfTbl.color.b = 255*a_flash*a_flash*a_flash
			elseif selfTbl.blasttype == 2 then
				selfTbl.color.r = 255*a_flash
				selfTbl.color.g = 150*a_flash*a_flash*a_flash
				selfTbl.color.b = 150*a_flash*a_flash*a_flash
			elseif selfTbl.blasttype == 7 then
				selfTbl.color.r = 255*a_flash
				selfTbl.color.g = 230*a_flash
				selfTbl.color.b = 150*a_flash*a_flash
			end
		
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			if selfTbl.blasttype == 1 then
				render.SetMaterial(selfTbl.altmat and selfTbl.mat_fire1 or selfTbl.mat_fire2)
				render.DrawSprite(selfTbl.pos, selfTbl.size*e_flash*2, selfTbl.size*e_flash*2, selfTbl.color)
				render.SetColorMaterial()
				render.DrawSphere(selfTbl.pos, selfTbl.size*f_flash, 7, 7, selfTbl.color)
			elseif selfTbl.blasttype == 2 or selfTbl.blasttype == 7 then
				render.SetMaterial(selfTbl.mat_fire3)
				render.DrawSprite(selfTbl.pos, selfTbl.size*e_flash*2, selfTbl.size*e_flash*2, selfTbl.color)
			end
			render.OverrideBlend( false )
		end
		
		if selfTbl.blasttype == 1 then
			render.SetMaterial(selfTbl.mat_ring1)
		elseif selfTbl.blasttype == 2 or selfTbl.blasttype == 7 then
			render.SetMaterial(selfTbl.mat_ring2)
		end
		
		local a_ring = math.max(0, 1-f)^2
		local ringsize = Lerp(math.ease.OutQuart(f), selfTbl.size*0.5, selfTbl.size*2 + 8)
		selfTbl.color_ring.r = 255*a_ring
		selfTbl.color_ring.g = 255*a_ring*a_ring
		selfTbl.color_ring.b = 255*a_ring*a_ring
		selfTbl.color_ring.a = 255*a_ring
		
		local a_ring2 = math.max(0, 1-f*2)
		local ringsize2 = Lerp(math.ease.OutQuart(f), selfTbl.size*0.75, selfTbl.size*3 + 16)
		selfTbl.color_ring2.r = 255*a_ring2
		selfTbl.color_ring2.g = 255*a_ring2*a_ring2
		selfTbl.color_ring2.b = 255*a_ring2*a_ring2
		selfTbl.color_ring2.a = 255*a_ring2
		
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.DrawQuadEasy(selfTbl.pos, selfTbl.normal, ringsize, ringsize, selfTbl.color_ring)
			render.DrawQuadEasy(selfTbl.pos, selfTbl.normal2, ringsize2, ringsize2, selfTbl.color_ring2)
		render.OverrideBlend( false )
	end
end

EFFECT.SmokeSorter = function(first, last)
	return first[4] > last[4]
end
