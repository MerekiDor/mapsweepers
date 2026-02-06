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

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Zombie Latcher"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "LatchTarget")
end


if SERVER then
	ENT.LatchRange = 600
	ENT.LatchSlow = 125 --Recon mains in shambles

	jcms.NPC_STATE_LATCHER_IDLE = 0
	jcms.NPC_STATE_LATCHER_CHASE = 1
	jcms.NPC_STATE_LATCHER_HOVER = 2
	
	function ENT:Initialize()
		self:SetModel("models/zombie/zombie_soldier.mdl")
		self:SetHealth(150)
		self:SetMaxHealth(150)

		self:SetHullType(HULL_HUMAN)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_BBOX)

		self:SetMaxLookDistance(3000)
		self:SetArrivalDistance(128)
		self:SetMaxYawSpeed(45)

		self:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_TURN_HEAD, CAP_OPEN_DOORS))
		self:SetMoveType(MOVETYPE_STEP)
		self:SetNavType(NAV_GROUND)
		self:SetNPCClass(CLASS_ZOMBIE)

		self.jcms_npcState = jcms.NPC_STATE_LATCHER_IDLE
	end


	function ENT:SelectSchedule() --Called when a schedule ends / new information gained
		local selfPos = self:WorldSpaceCenter()

		if self.jcms_npcState == jcms.NPC_STATE_LATCHER_CHASE then
			local enemy = self:GetEnemy()
			if IsValid(enemy) then
				self:SetSchedule(SCHED_CHASE_ENEMY)
				return
			end
		elseif self.jcms_npcState == jcms.NPC_STATE_LATCHER_HOVER then
			self:SetSchedule(SCHED_RUN_RANDOM)
			return
		end

		self:SetSchedule(SCHED_PATROL_RUN)
	end

	function ENT:Think()
		--Decision Making State Machine
		if self.jcms_npcState == jcms.NPC_STATE_LATCHER_IDLE then 
			self:ThinkIdle()
		elseif self.jcms_npcState == jcms.NPC_STATE_LATCHER_CHASE then 
			self:ThinkChase()
		elseif self.jcms_npcState == jcms.NPC_STATE_LATCHER_HOVER then
			self:ThinkHover()
		end

		--TODO: Should be nearest *visible* sweeper instead.
		local sweeper, dist = jcms.GetNearestSweeper(self:WorldSpaceCenter())
		
		if dist > self.LatchRange or not self:Visible(sweeper) then 
			local oldTarget = self:GetLatchTarget()
			if IsValid(oldTarget) then
				oldTarget.jcms_snares[self] = nil
			end

			self:SetLatchTarget(NULL)
		else
			local oldTarget = self:GetLatchTarget()
			if (not(sweeper == oldTarget) and IsValid(oldTarget)) then
				--Our old target is gone, stop latching them.
				oldTarget.jcms_snares[self] = nil
			end

			sweeper.jcms_snares = sweeper.jcms_snares or {}
			sweeper.jcms_snares[self] = self.LatchSlow --target can't move faster than this amount

			self:SetLatchTarget(sweeper)
		end
	end

	-- // State Machine States {{{
		function ENT:ThinkIdle()
			if IsValid(self:GetEnemy()) then 
				self.jcms_npcState = jcms.NPC_STATE_LATCHER_CHASE
				self:ClearSchedule()
				return
			end
		end

		function ENT:ThinkChase()
			local enemy = self:GetEnemy()
			if not IsValid(enemy) then --No target, patrol
				self.jcms_npcState = jcms.NPC_STATE_LATCHER_IDLE
				self:ClearSchedule()
				return 
			end

			local selfPos = self:WorldSpaceCenter()
			local enemyPos = enemy:WorldSpaceCenter()

			--Can't see our target or are too far, go back to chasing
			if enemyPos:DistToSqr(selfPos) < (self.LatchRange * 0.5)^2 and self:Visible(enemy) then
				self.jcms_npcState = jcms.NPC_STATE_LATCHER_HOVER
				self:ClearSchedule()
				return
			end
		end

		function ENT:ThinkHover()
			local enemy = self:GetEnemy()
			if not IsValid(enemy) then --No target, patrol
				self.jcms_npcState = jcms.NPC_STATE_LATCHER_IDLE
				self:ClearSchedule()
				return 
			end

			local selfPos = self:WorldSpaceCenter()
			local enemyPos = enemy:WorldSpaceCenter()
			--Can't see our target or are too far, go back to chasing
			if enemyPos:DistToSqr(selfPos) > (self.LatchRange * 0.5)^2 or not self:Visible(enemy) then
				self.jcms_npcState = jcms.NPC_STATE_LATCHER_CHASE
				self:ClearSchedule()
				return
			end
		end
	-- // }}}

	function ENT:HandleAnimEvent(event, eventTime, cycle, type, options)
		return true
	end

	
	function ENT:OnTakeDamage(dmgInfo)
		if self.jcms_dead then return end

		self:SetHealth( self:Health() - dmgInfo:GetDamage() )

		
		if self:Health() <= 0 then
			self.jcms_dead = true
			self:Death( dmgInfo )
			
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
		end
	end

	function ENT:Death(dmgInfo)
		self:CleanupSnares()
		self:BecomeRagdoll(dmgInfo)
	end

	function ENT:OnRemove()
		self:CleanupSnares()
	end

	function ENT:CleanupSnares()
		local latchTarget = self:GetLatchTarget()

		if IsValid(latchTarget) then 
			latchTarget.jcms_snares[self] = nil
		end
	end
end


if CLIENT then 
	function ENT:Draw()
		self:DrawModel()

		local latchTarget = self:GetLatchTarget()

		if IsValid(latchTarget) then
			render.SetColorMaterial()
			render.DrawBeam(self:WorldSpaceCenter(), latchTarget:WorldSpaceCenter(), 3, 0, 1, Color(55, 0, 0))
		end
	end
end
