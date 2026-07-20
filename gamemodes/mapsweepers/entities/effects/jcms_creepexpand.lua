
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
EFFECT.v_gravity = Vector(0, 0, -720)
EFFECT.v_gravityHeavy = Vector(0, 0, -1440)

function EFFECT:Init( data )
	local cell = jcms.zombieCreep_GetCell(data:GetOrigin())
	local pos = jcms.zombieCreep_GetCellPos(cell)
	self.pos = pos
	pos.z = pos.z + jcms.zombieCreep_cellSize.z
	self:SetPos(pos)

	self.t = 0
	self.tout = data:GetMagnitude()
	
	local sizevec = jcms.zombieCreep_cellSize / 2
	self:SetRenderBounds(-sizevec, sizevec)

	self:EmitSound("physics/flesh/flesh_squishy_impact_hard"..math.random(1,4)..".wav", 100, math.random(80, 90), 1)

	self.groundPoints = {}
	local sizeX, sizeY, _ = jcms.zombieCreep_cellSize:Unpack()
	for i=1, 36 do 
		--This isn't correct but probably close enough.
		local x = (i%6) * sizeX/6
		local y = math.floor(i/6) * sizeY/6
		local startpos = self.pos + Vector(x + math.Rand(-24,24), y + math.Rand(-24,24), 0)--Vector(math.Rand(0, sizeX), math.Rand(0, sizeY),0)
		local endpos = Vector(startpos)
		endpos.z = -32768

		local tr = util.TraceLine({
			start = startpos,
			endpos = endpos,
			mask = MASK_SOLID_BRUSHONLY
		})

		table.insert(self.groundPoints, tr.HitPos)
	end

	self.emitter = ParticleEmitter(self.pos)
	for i, pos in ipairs(self.groundPoints) do 
		local p = self.emitter:Add("effects/blood_drop", self.pos)
		if p then
			p:SetPos(pos)

			local vel = VectorRand(-64*4, 64*4)
			vel.z = vel.z + 8*8
			p:SetVelocity(vel)
			p:SetGravity(self.v_gravityHeavy)
			p:SetCollide(true)

			p:SetStartSize(math.Rand(64, 96))
			p:SetEndSize(0)

			p:SetRoll(math.random()*360)

			p:SetDieTime(2.3 + math.random()*3)
			p:SetColor(90, 30, 30)
		end

		local p = self.emitter:Add("effects/blood", self.pos)
		if p then
			p:SetPos(pos)

			p:SetVelocity(VectorRand(-64, 64))
			p:SetRoll(math.random()*360)
			p:SetRollDelta(math.random()*2)

			p:SetStartSize(math.Rand(0.8, 1.2)*96)
			p:SetEndSize(math.Rand(0.2, 1.4)*96)
			p:SetDieTime(self.tout + math.random())
			p:SetColor(96, 36, 36)
		end

	end

	self.emitter:Finish()
end


function EFFECT:Think()
	return false
end

function EFFECT:Render()

end