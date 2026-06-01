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

hook.Remove("PostDrawTranslucentRenderables", "jcms_ArenaPreview")
-- hook.Add("PostDrawTranslucentRenderables", "jcms_ArenaPreview", function()
--     local tr = LocalPlayer():GetEyeTrace()

--     local gs = 16
--     local v = Vector( tr.HitPos )
--     v.x = math.Round(v.x / gs) * gs
--     v.y = math.Round(v.y / gs) * gs

--     render.SetColorMaterial()
--     render.DrawSphere(v, 4, 7, 7, jcms.color_bright)
--     local text = ("Vector(%d, %d, %d)"):format(v:Unpack())

--     cam.Start2D()
--         draw.SimpleText(text, "jcms_hud_small", ScrW()/2, ScrH()/3, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
--     cam.End2D()
-- end)