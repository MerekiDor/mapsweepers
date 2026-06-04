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
ENT.PrintName = "Drop Pod"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
	sound.Add( {
		name = "jcms_droppod_launch",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 140,
		pitch = 100,
		sound = "^thrusters/rocket04.wav"
	} )

	sound.Add( {
		name = "jcms_droppod_land",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 162,
		pitch = 105,
		sound = {
			"^phx/explode01.wav",
			"^phx/explode02.wav",
			"^phx/explode03.wav",
			"^phx/explode04.wav",
			"^phx/explode05.wav",
			"^phx/explode06.wav"
		}
	} )
end

local function lerpColor(f, c1, c2)
	local r1,g1,b1,a1 = c1:Unpack()
	local r2,g2,b2,a1 = c2:Unpack()
	return Color(Lerp(f, r1, r2), Lerp(f, g1, g2), Lerp(f, b1, b2), Lerp(f, a1 or 255, a2 or a1 or 255))
end

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_combine/headcrabcannister01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NicknameInside")
end

if SERVER then
	function ENT:FixatePod(static)
		local player_pod = self._pod
		local angle = self:GetAngles()
		angle:RotateAroundAxis( angle:Right(), 90 )
		angle:RotateAroundAxis( angle:Up(), 180 )
		player_pod:SetPos(self:GetPos() + angle:Forward() + angle:Up()*-9)
		player_pod:SetAngles(angle)

		if static then
			player_pod:PhysicsInitStatic(SOLID_NONE)
		else
			constraint.Weld(player_pod, self, 0, 0, 0, true, true)
		end
	end

	function ENT:Drop(ply, destination, from)
		self:SetNicknameInside(ply:Nick())

		local color
		if ply:GetNWInt("jcms_pvpTeam", -1) == 2 then
			color = Color(255, 238, 0)
		else
			color = Color(100, 10, 10)
		end

		self._dropping = true

		self:PhysicsInit(SOLID_VPHYSICS)
		local myrad = 210
		local trace = util.TraceHull {
			mins = Vector(-4, -4, -myrad),
			maxs = Vector(4, 4, myrad),
			start = from,
			endpos = destination,
			mask = MASK_PLAYERSOLID_BRUSHONLY
		}

		self:SetPos(trace.StartPos)
		self:SetColor(color)
		local vel = trace.HitPos - trace.StartPos
		local dist = vel:Length()
		vel:Mul(math.random(15, 200) / dist)
		self:Spawn()
		self:PhysWake()
		self:GetPhysicsObject():SetAngleVelocity(Vector( (math.random()<0.5 and 1 or -1)*math.random(8, 19), 0, 0))
		self:GetPhysicsObject():SetMass(3500)
		self:GetPhysicsObject():SetVelocity(vel)

		local allPlayers = RecipientFilter()
		allPlayers:AddAllPlayers()
		
		if self._rocketsnd then
			self._rocketsnd:Stop()
		end

		timer.Simple(math.random(), function()
			if IsValid(self) and self._dropping then
				self._rocketsnd = CreateSound(self, "jcms_droppod_launch", allPlayers)
				self._rocketsnd:Play()
			end
		end)

		vel:Normalize()
		local angle = vel:Angle()
		angle.y = math.random(360)
		self:SetAngles(angle)

		if IsValid(self._pod) then
			self._pod:Remove()
		end

		local player_pod = ents.Create("prop_vehicle_prisoner_pod")
		player_pod:SetModel("models/vehicles/prisoner_pod_inner.mdl")
		player_pod:Spawn()
		ply:EnterVehicle(player_pod)
		player_pod:GetPhysicsObject():SetMass(10)
		player_pod:SetColor(color)
		player_pod:DrawShadow(false)
		player_pod.droppod = self
		self._pod = player_pod
		
		self:FixatePod()
		self.boardingPlayer = ply
		ply:SetAngles(player_pod:GetAngles())
		
		constraint.NoCollide(ply, self, 0, 0)
	end 
	
	function ENT:Think()
		if self._dropping == false and IsValid(self.boardingPlayer) and self.boardingPlayer:GetVehicle() ~= self._pod then
			if self.cleanupTime and CurTime() > self.cleanupTime then
				self:EmitSound("ambient/machines/teleport3.wav")
				self:Remove()
				
				local ed = EffectData()
				ed:SetOrigin(self:GetPos())
				ed:SetFlags(1)
				util.Effect("jcms_evacbeam", ed)
			end
		elseif IsValid(self.boardingPlayer) and self.forceExitTime and self.forceExitTime < CurTime() then
			self.boardingPlayer:ExitVehicle()
		end
	end

	function ENT:PhysicsCollide(data, phys)
		if data.HitEntity:IsWorld() and data.Speed > 10 and self._dropping then
			util.ScreenShake(data.HitPos, 10, 35, math.Rand(1.7, 2.6), 660, true)

			if self._rocketsnd then
				self._rocketsnd:Stop()
			end

			if self._blastsnd then
				self._blastsnd:Stop()
			end

			local allPlayers = RecipientFilter()
			allPlayers:AddAllPlayers()
			self._blastsnd = CreateSound(self, "jcms_droppod_land", allPlayers)
			self._blastsnd:Play()
			self._dropping = false

			local ed = EffectData()
			ed:SetOrigin(data.HitPos)
			ed:SetScale(200)
			ed:SetEntity(self)
			util.Effect("ThumperDust", ed)
			util.Decal("Scorch", self:GetPos(), data.HitPos + data.HitNormal*32, { self, self._pod })
			if IsValid(self.boardingPlayer) then
				util.BlastDamage(self.boardingPlayer, self.boardingPlayer, data.HitPos, 128, 40)
			end

			timer.Simple(0, function()
				if IsValid(self) then
					self:SetPos(data.HitPos)
					self:PhysicsInitStatic(SOLID_VPHYSICS)
					self:FixatePod(true)
				end
			end)

			--Announcer Lines
			timer.Simple(10, function()
				if IsValid(self.boardingPlayer) and self.boardingPlayer:GetVehicle() == self._pod then 
					jcms.announcer_Speak(jcms.ANNOUNCER_EXITPOD1, self.boardingPlayer)
				end
			end)
			
			timer.Simple(25, function()
				if IsValid(self.boardingPlayer) and self.boardingPlayer:GetVehicle() == self._pod then 
					jcms.announcer_Speak(jcms.ANNOUNCER_EXITPOD2, self.boardingPlayer)
				end
			end)

			if not game.SinglePlayer() then
				self.forceExitTime = CurTime() + 40
			end
			self.cleanupTime = CurTime() + 180
		end
	end
end

if CLIENT then
	function ENT:Draw(flags)
		local distToEyes = EyePos():DistToSqr(self:GetPos())

		if distToEyes <= 6000*6000 then
			if self:GetVelocity():LengthSqr() > 100 then
				local f = 1 - math.ease.OutCubic( math.Clamp(math.Remap(distToEyes, 6000*6000, 300*300, 1, 0), 0, 1 ) )
				render.SetBlend(f)
			end
			self:DrawModel()
		end
		render.SetBlend(1)

		if bit.band(flags, STUDIO_RENDER) and distToEyes<2000*2000 then
			local colDark = Color(32, 0, 0)
			local colBright = Color(255, 0, 0)

			if self:GetNWInt("jcms_pvpTeam", -1) == 2 then
				colBright:SetUnpacked(255, 230, 0)
			else
				colBright:SetUnpacked(255, 0, 0)
			end

			local pos = self:GetPos()
			local ang = self:GetAngles()
			ang:RotateAroundAxis(ang:Right(), 180)
			ang:RotateAroundAxis(ang:Up(), -90)
			pos = pos + ang:Up()*23 + ang:Right()*-40

			local matrix = Matrix()
			matrix:Translate(Vector(0,0,0.25))
			cam.Start3D2D(pos, ang, 1/32)
				draw.SimpleText("#jcms.pod_text", "jcms_hud_small", 0, -32, colDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(self:GetNicknameInside(), "jcms_hud_huge", 0, 48, colDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				cam.PushModelMatrix(matrix, true)
					draw.SimpleText("#jcms.pod_text", "jcms_hud_small", 0, -32, colBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(self:GetNicknameInside(), "jcms_hud_huge", 0, 48, colBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				cam.PopModelMatrix()
				render.OverrideBlend(false)
			cam.End3D2D()

			ang:RotateAroundAxis(ang:Right(), -35)
			local bw = 7

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			for i=1,2 do
				cam.Start3D2D(pos + ang:Up()*5 + ang:Forward()*(i==1 and 1 or -1)*15, ang, 1)
					for j=0, 4 do
						surface.SetDrawColor(lerpColor(TimedCos(1, 0.5, 1, j), colDark, colBright))
						surface.DrawRect(-1, -7 + j*(bw+1), 2, bw)
					end
				cam.End3D2D()
				ang:RotateAroundAxis(ang:Right(), 70)
			end
			render.OverrideBlend(false)
		end
	end

	local mat_beam = Material "sprites/physbeama.vmt"
	local mat_lamp = Material "effects/lamp_beam.vmt"
	local mat_glow = Material "sprites/light_glow02_add"

	function ENT:DrawTranslucent(flags)
		local pos = self:WorldSpaceCenter()
		local normal = self:GetVelocity()

		if normal:LengthSqr() <= 100 then return end

		local distToEyes = EyePos():Distance( self:GetPos() )
		local f = math.ease.OutCubic( math.Clamp(math.Remap(distToEyes, 5000, 300, 1, 0), 0, 1 ) )
		
		if f > 0 then
			normal:Mul(Lerp(f, 0.0001, 0.0003))

			if self:GetNWInt("jcms_pvpTeam", -1) == 2 then
				col = Color(255, 195, 30)
				colBrighter = Color(235, 255, 120)
			else
				col = Color(255, 30, 30)
				colBrighter = Color(255, 130, 120)
			end

			local scale = 16 * f
			render.SetMaterial(mat_beam)
			render.StartBeam(2)
				render.AddBeam(pos, math.Rand(3, 7)*scale, 0, colBrighter)
				render.AddBeam(pos - normal*math.random(64, 100)*scale, 0, 1, col)
			render.EndBeam()

			render.SetMaterial(mat_lamp)
			render.StartBeam(2)
				local width = math.Rand(12, 24)*scale
				render.AddBeam(pos, width, 0, colBrighter)
				render.AddBeam(pos - normal*math.random(64, 100)*scale, width, 1, col)
			render.EndBeam()

			local ff = math.Clamp(math.Remap(distToEyes, 1300, 750, 1, 0), 0, 1 )
			col.r = Lerp(ff, col.r, colBrighter.r)
			col.g = Lerp(ff, col.g, colBrighter.g)
			col.b = Lerp(ff, col.b, colBrighter.b)

			scale = 16 * ff
			render.SetMaterial(mat_glow)
			render.DrawSprite(pos, math.Rand(32, 48)*scale, math.Rand(16, 24)*scale, col)
		end
	end
end
