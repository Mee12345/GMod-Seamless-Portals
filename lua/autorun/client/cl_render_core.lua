-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

AddCSLuaFile()

if SERVER then return end

local sky_cvar = GetConVar("sv_skyname")
local sky_name = ""
local sky_materials = {}

local portals = {}
local oldHalo = 0
local timesRendered = 0

local skysize = 16384	--2^14, default zfar limit
local angle_zero = Angle(0, 0, 0)

local renderViewTable = {
	x = 0,
	y = 0,
	w = ScrW(),
	h = ScrH(),
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
}

-- sort the portals by distance since draw functions do not obey the z buffer
timer.Create("seamless_portal_distance_fix", 0.25, 0, function()
	portals = ents.FindByClass("seamless_portal")
	local eyePos = EyePos()
	table.sort(portals, function(a, b) 
		return a:GetPos():DistToSqr(eyePos) < b:GetPos():DistToSqr(eyePos)
	end)

	-- update sky material (I guess it can change?)
	if sky_name != sky_cvar:GetString() then
		sky_name = sky_cvar:GetString()

		local prefix = "skybox/" .. sky_name
		sky_materials[1] = Material(prefix .. "bk")
		sky_materials[2] = Material(prefix .. "dn")
		sky_materials[3] = Material(prefix .. "ft")
		sky_materials[4] = Material(prefix .. "lf")
		sky_materials[5] = Material(prefix .. "rt")
		sky_materials[6] = Material(prefix .. "up")
	end
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
local physgun_halo = GetConVar("physgun_halo")
local render_PushRenderTarget = render.PushRenderTarget
local render_PopRenderTarget = render.PopRenderTarget
local render_PushCustomClipPlane = render.PushCustomClipPlane
local render_PopCustomClipPlane = render.PopCustomClipPlane
local render_RenderView = render.RenderView
local render_EnableClipping = render.EnableClipping

local ply = LocalPlayer()
hook.Add("RenderScene", "seamless_portals_draw", function(eyePos, eyeAngles, fov)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	SeamlessPortals.Rendering = true

	-- black halo clipping plane fix (Thanks to homonovus)
	physgun_halo = physgun_halo or GetConVar("physgun_halo")
	--local oldHalo = physgun_halo:GetInt()
	--physgun_halo:SetInt(0)

	render.DepthRange(1, 0)
	print(#portals)
	for k, v in ipairs(portals) do
		if timesRendered >= SeamlessPortals.MaxRTs then break end
		if !v:IsValid() or !v:GetExitPortal():IsValid() then continue end
		if timesRendered < SeamlessPortals.MaxRTs and SeamlessPortals.ShouldRender(v, eyePos, eyeAngles) then
			local exitPortal = v:GetExitPortal()
			local editedPos, editedAng = SeamlessPortals.TransformPortal(v, exitPortal, eyePos, eyeAngles)
			
			-- Areaportals
			ply = LocalPlayer() -- FIXME: this is a hack
			
			local oldCamPos = ply:GetViewOffset()
			renderViewTable.origin = editedPos
			renderViewTable.angles = editedAng
			renderViewTable.fov = fov

			timesRendered = timesRendered + 1
			v.PORTAL_RT_NUMBER = timesRendered	-- the number index of the rendertarget it will use in rendering

			-- render the scene
			local up = exitPortal:GetUp()
			local oldClip = render.EnableClipping(true)

			ply:SetViewOffset(eyePos - editedPos)

			render_PushRenderTarget(SeamlessPortals.PortalRTs[timesRendered])
			render_PushCustomClipPlane(up, up:Dot(exitPortal:GetPos() + up * 0.49))
			render_RenderView(renderViewTable)
			render_PopCustomClipPlane()
			render_EnableClipping(oldClip)
			render_PopRenderTarget()

			ply:SetViewOffset(oldCamPos)
		end
	end

	-- physgun_halo:SetInt(oldHalo)

	SeamlessPortals.Rendering = false
	timesRendered = 0
end)

hook.Add("PreDrawHalos", "seamless_portal_blackfix", function()
	if SeamlessPortals.Rendering then
		return true
	end
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if SeamlessPortals.Rendering and !SeamlessPortals.DrawPlayerInView then 
		return true 
	end
end)

-- (REWRITE THIS!)
-- draw the 2d skybox in place of the black (Thanks to Fafy2801)
local function drawsky(pos, ang, size, size_2, color, materials)
	-- BACK
	render.SetMaterial(materials[1])
	render.DrawQuadEasy(pos + Vector(0, size, 0), ang:Right(), size_2, size_2, color, 0)
	-- DOWN
	render.SetMaterial(materials[2])
	render.DrawQuadEasy(pos - Vector(0, 0, size), ang:Up(), size_2, size_2, color, 180)
	-- FRONT
	render.SetMaterial(materials[3])
	render.DrawQuadEasy(pos - Vector(0, size, 0), -ang:Right(), size_2, size_2, color, 0)
	-- LEFT
	render.SetMaterial(materials[4])
	render.DrawQuadEasy(pos - Vector(size, 0, 0), ang:Forward(), size_2, size_2, color, 0)
	-- RIGHT
	render.SetMaterial(materials[5])
	render.DrawQuadEasy(pos + Vector(size, 0, 0), -ang:Forward(), size_2, size_2, color, 0)
	-- UP
	render.SetMaterial(materials[6])
	render.DrawQuadEasy(pos + Vector(0, 0, size), -ang:Up(), size_2, size_2, color, 180)
end

hook.Add("PostDrawTranslucentRenderables", "seamless_portal_skybox", function()
	if !SeamlessPortals.Rendering or util.IsSkyboxVisibleFromPoint(renderViewTable.origin) then return end
	-- render.OverrideDepthEnable(true, false)
	drawsky(renderViewTable.origin, angle_zero, skysize, -skysize * 2, color_white, sky_materials)
	-- render.OverrideDepthEnable(false , false)
end)