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
ENT.PrintName = "J Corp Jump Pad"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Overclocked")
end

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/jcms/jcorp_jumppad.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
	end
end

function ENT:UpdateForFaction(faction)
	for i, matname in ipairs(self:GetMaterials()) do
		self:SetSubMaterial(i-1, matname:gsub("jcorp_", tostring(faction) .. "_"))
	end
end

if SERVER then
    function ENT:Think()
        local state = not not (self.overclockedUntil and CurTime() < self.overclockedUntil)
        if self:GetOverclocked() ~= state then
            self:SetOverclocked(state)

            if state then
                self:EmitSound("ambient/levels/citadel/zapper_warmup4.wav", 100, 170)
            else
                self:EmitSound("weapons/physcannon/superphys_small_zap3.wav", 100, 110)
            end
        end
    end

    function ENT:OnTakeDamage(dmg)
        if jcms.util_IsStunstick( dmg:GetInflictor() ) then
            self.overclockedUntil = CurTime() + 5

            local ed = EffectData()
			ed:SetEntity(self)
			ed:SetScale(5)
            ed:SetMagnitude(10)
            ed:SetColor( jcms.util_ColorIntegerFast(150, 255, 255) )
            ed:SetMaterialIndex(1)
			util.Effect("jcms_electricarcs", ed)
        end
    end

    function ENT:BreakByBreach(forceVector)
        self:EmitSound("physics/metal/metal_box_break2.wav", 80, 103)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        local physObj = self:GetPhysicsObject()
        if IsValid(physObj) and forceVector then
            physObj:SetVelocity( forceVector )
        end

        timer.Simple(2.75, function()
            if IsValid(self) then
                self:SetModelScale(0, 0.25)
            end
        end)

        timer.Simple(3, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    end
end

function ENT:JumpEffect()
    if SERVER then
        self:EmitSound("weapons/physcannon/superphys_launch"..math.random(1,4)..".wav")
    end

    local ed = EffectData()
    ed:SetOrigin(self:GetPos() + Vector(0, 0, 12))
    ed:SetNormal(Vector(0,0,1))
    ed:SetRadius(42)
    util.Effect("AR2Explosion", ed)
end

function ENT:LaunchPlayer(ply)
    self:JumpEffect()

    if SERVER then
        ply.noFallDamage = true
    end

    local isOverclocked = self:GetOverclocked()
    
    local vector = Vector(0, 0, isOverclocked and (ply:Crouching() and 950 or 1300) or (ply:Crouching() and 260 or 580))
    local ev = ply:EyeAngles():Forward()
    ev:Mul(isOverclocked and 0 or 128)
    ev:Add(vector)

    if isOverclocked or self.jcms_isSingleUse then
        local oldVel = ply:GetVelocity()
        oldVel:Mul(0.8)
        ev:Sub(oldVel)

        if SERVER then
            self:BreakByBreach(-ev)
        end
    end
    ply:SetVelocity(ev)
end

hook.Add("OnPlayerJump", "jcms_BoostJump", function(ply)
    if SERVER or IsFirstTimePredicted() then
        local radius = 72
        local radius2 = radius*radius

        for i, pad in ipairs(ents.FindByClass "jcms_jumppad") do
            local dif = ply:GetPos()-pad:GetPos()
            if (dif.z > 0 and dif.z < 32) and (dif.x^2 + dif.y^2) < radius2 then
                pad:LaunchPlayer(ply)
                break
            end
        end
    end
end)
