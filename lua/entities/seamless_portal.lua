-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true

local EyePos, EyeAngles = EyePos, EyeAngles

-- create global table
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.VarDrawDistance = CreateClientConVar("seamless_portal_drawdistance", "2500", true, false, "Sets the size of the portal along the Y axis", 0)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "ExitPortal")
	self:NetworkVar("Vector", 0, "PortalSize")
	self:NetworkVar("Bool", 0, "DisableBackface")
end

function ENT:LinkPortal(ent)
	if !ent or !ent:IsValid() then return end
	self:SetExitPortal(ent)
	ent:SetExitPortal(self)
end

-- custom size for portal
function ENT:SetExitSize(n)
	self:SetPortalSize(n)
	self:UpdatePhysmesh(n)
end

-- (for older api compatibility)
function ENT:ExitPortal()
	return self:GetExitPortal()
end

function ENT:GetExitSize()
	return self:GetPortalSize()
end

local function incrementPortal(ent)
	if CLIENT then
		if ent.UpdatePhysmesh then
			ent:UpdatePhysmesh()
		else
			-- takes a minute to try and find the portal, if it cant, oh well...
			timer.Create("seamless_portal_init" .. SeamlessPortals.PortalIndex, 1, 60, function()
				if !ent or !ent:IsValid() or !ent.UpdatePhysmesh then return end

				ent:UpdatePhysmesh()
				timer.Remove("seamless_portal_init" .. SeamlessPortals.PortalIndex)
			end)
		end
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function ENT:Initialize()
	if CLIENT then
		incrementPortal(self)
	else
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetMaterial("debug/debugempty")	-- missing texture
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
		if self:GetExitSize() == Vector() then
			self:SetExitSize(Vector(1, 1, 1))
		else
			self:SetExitSize(self:GetExitSize())
		end
		SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
	end
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("seamless_portal")
	portal1:SetPos(tr.HitPos + tr.HitNormal * 150)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:Spawn()

	if CPPI then portal2:CPPISetOwner(ply) end

	portal1:LinkPortal(portal2)
	portal2:LinkPortal(portal1)
	portal1.PORTAL_REMOVE_EXIT = true
	portal2.PORTAL_REMOVE_EXIT = true

	return portal1
end

function ENT:OnRemove()
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex - 1
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetExitPortal())
	end
end

local function DrawQuadEasier(e, multiplier, offset, rotate)
	local ex, ey, ez = e:GetForward(), e:GetRight(), e:GetUp()
	local rotate = rotate
	local mx = ey * multiplier.x
	local my = ex * multiplier.y
	local mz = ez * multiplier.z
	local ox = ey * offset.x -- currently zero
	local oy = ex * offset.y -- currently zero
	local oz = ez * offset.z

	local pos = e:GetPos() + ox + oy + oz
	if rotate == 0 then
		-- What the fuck is this?
		-- TODO: Comment what this does
		render.DrawQuad(
			pos + mx - my + mz,
			pos - mx - my + mz,
			pos - mx + my + mz,
			pos + mx + my + mz
		)
	elseif rotate == 1 then
		-- What the fuck is this?
		-- TODO: Comment what this does
		render.DrawQuad(
			pos + mx + my - mz,
			pos - mx + my - mz,
			pos - mx + my + mz,
			pos + mx + my + mz
		)
	elseif rotate == 2 then
		-- What the fuck is this?
		-- TODO: Comment what this does
		render.DrawQuad(
			pos + mx - my + mz,
			pos + mx - my - mz,
			pos + mx + my - mz,
			pos + mx + my + mz
		)
	else
		print("Failed processing rotation:", tostring(rotate))
	end
end


if CLIENT then
	local render_ClearStencil = render.ClearStencil
	local render_SetStencilEnable = render.SetStencilEnable
	local render_SetStencilWriteMask = render.SetStencilWriteMask
	local render_SetStencilTestMask = render.SetStencilTestMask
	local render_SetStencilReferenceValue = render.SetStencilReferenceValue
	local render_SetStencilFailOperation = render.SetStencilFailOperation
	local render_SetStencilZFailOperation = render.SetStencilZFailOperation
	local render_SetStencilPassOperation = render.SetStencilPassOperation
	local render_SetStencilCompareFunction = render.SetStencilCompareFunction

	local renderedEntity = halo.RenderedEntity
	local render_DrawBox = render.DrawBox

	local drawMat = Material("models/props_combine/combine_interface_disp")
	function ENT:Draw()
		local backAmt = 3 * self:GetExitSize()[3]
		local backVec = Vector(0, 0, -backAmt + 0.5)
		local scalex = (self:OBBMaxs().x - self:OBBMins().x) * 0.5 - 0.1
		local scaley = (self:OBBMaxs().y - self:OBBMins().y) * 0.5 - 0.1
		local exitInvalid = !self:GetExitPortal() or !self:GetExitPortal():IsValid()

		render.SetMaterial(drawMat)

		if SeamlessPortals.Rendering or exitInvalid or renderedEntity() == self or not SeamlessPortals.ShouldRender(self, EyePos(), EyeAngles()) then
			if !self:GetDisableBackface() then
				render_DrawBox(self:GetPos(), self:LocalToWorldAngles(Angle(0, 90, 0)), Vector(-scaley, -scalex, -backAmt * 2 + 0.5), Vector(scaley, scalex, 0.5))
			end
			return
		end

		-- outer quads
		if !self:GetDisableBackface() then
			DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec, 0)
			DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 1)
			DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec, 1)
			DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 2)
			DrawQuadEasier(self, Vector(-scaley, -scalex, -backAmt), backVec, 2)
		end

		-- do cursed stencil stuff
		render_ClearStencil()
		render_SetStencilEnable(true)
		render_SetStencilWriteMask(1)
		render_SetStencilTestMask(1)
		render_SetStencilReferenceValue(1)
		render_SetStencilFailOperation(STENCIL_KEEP)
		render_SetStencilZFailOperation(STENCIL_KEEP)
		render_SetStencilPassOperation(STENCIL_REPLACE)
		render_SetStencilCompareFunction(STENCIL_ALWAYS)

		-- draw the quad that the 2d texture will be drawn on
		-- teleporting causes flashing if the quad is drawn right next to the player, so we offset it
		DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec, 0)
		DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 1)
		DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec, 1)
		DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 2)
		DrawQuadEasier(self, Vector(-scaley,  scalex, -backAmt), backVec, 2)

		-- draw the actual portal texture
		local portalmat = SeamlessPortals.PortalMaterials
		render.SetMaterial(portalmat[self.PORTAL_RT_NUMBER or 1])
		render.SetStencilCompareFunction(STENCIL_EQUAL)

		-- draw quad reversed if the portal is linked to itself
		if self.ExitPortal and self:GetExitPortal() == self then
			render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())
		else
			render.DrawScreenQuadEx(0, 0, ScrW(), ScrH())
		end

		render.SetStencilEnable(false)
	end
end

-- scale the physmesh
function ENT:UpdatePhysmesh()
	self:PhysicsInit(6)
	if self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		for k, tri in pairs(self:GetPhysicsObject():GetMeshConvexes()[1]) do
			local pos = tri.pos * self:GetExitSize()
			pos[3] = pos[3] > 0 and 0.5 or -0.5
			table.insert(finalMesh, pos)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		self:GetPhysicsObject():EnableMotion(false)
		self:GetPhysicsObject():SetMaterial("glass")
		self:GetPhysicsObject():SetMass(250)

		if CLIENT then 
			local mins, maxs = self:GetModelBounds()
			self:SetRenderBounds(mins * self:GetExitSize(), maxs * self:GetExitSize())
		end
	else
		self:PhysicsDestroy()
		self:EnableCustomCollisions(false)
		print("Failure to create a portal physics mesh " .. self:EntIndex())
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

local Vector = Vector
local Angle = Angle
local MIRROR_CONSTANT = Vector(1, 1, -1)
SeamlessPortals.PortalIndex = 0 --#ents.FindByClass("seamless_portal")
SeamlessPortals.MaxRTs = 6
SeamlessPortals.TransformPortal = function(a, b, pos, ang)
	if !a or !b or !b:IsValid() or !a:IsValid() then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		-- What the fuck is this?
		-- TODO: Comment what this does
		editedPos = a:WorldToLocal(pos) * (b:GetExitSize()[1] / a:GetExitSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp()
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	-- mirror portal
	if a == b then
		if pos then
			editedPos = a:LocalToWorld(a:WorldToLocal(pos) * MIRROR_CONSTANT) 
		end

		if ang then
			local localAng = a:WorldToLocalAngles(ang)
			-- What the fuck is this?
			-- TODO: Comment what this does
			editedAng = a:LocalToWorldAngles(Angle(-localAng[1], localAng[2], -localAng[3] + 180))
		end
	end

	return editedPos, editedAng
end

-- set physmesh pos on client
if CLIENT then
	-- only render the portals that are in the frustum, or should be rendered
	SeamlessPortals.ShouldRender = function(portal, eyePos, eyeAngle)
		local portalPos, portalUp, exitSize = portal:GetPos(), portal:GetUp(), portal:GetExitSize()
		-- What the fuck is this?
		-- TODO: Comment what this does
		local infrontPortal = (eyePos - portalPos):Dot(portalUp) > (-10 * exitSize[1]) -- true if behind the portal, false otherwise
		-- What the fuck is this?
		-- TODO: Comment what this does
		local distPortal = eyePos:DistToSqr(portalPos) < SeamlessPortals.VarDrawDistance:GetFloat()^2 * exitSize[1] -- true if close enough
		-- What the fuck is this?
		-- TODO: Comment what this does
		local portalLooking = (eyePos - portalPos):Dot(eyeAngle:Forward()) < 50 * exitSize[1] -- true if looking at the portal, false otherwise

		return infrontPortal and distPortal and portalLooking
	end

	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		end
	end

	hook.Add("InitPostEntity", "seamless_portal_init", function()
		for k, v in ipairs(ents.FindByClass("seamless_portal")) do
			print("Initializing portal " .. v:EntIndex())
			incrementPortal(v)
		end

		-- this code creates the rendertargets to be used for the portals
		SeamlessPortals.PortalRTs = {}
		SeamlessPortals.PortalMaterials = {}
		SeamlessPortals.PixelVis = {}

		for i = 1, SeamlessPortals.MaxRTs do
			SeamlessPortals.PortalRTs[i] = GetRenderTarget("SeamlessPortal" .. i, ScrW(), ScrH())
			SeamlessPortals.PortalMaterials[i] = CreateMaterial("SeamlessPortalsMaterial" .. i, "GMODScreenspace", {
				["$basetexture"] = SeamlessPortals.PortalRTs[i]:GetName(),
				["$model"] = "1"
			})
			SeamlessPortals.PixelVis[i] = util.GetPixelVisibleHandle()
		end
	end)

	--funny flipped scene
	local rendering = false
	local cursedRT = GetRenderTarget("Portal_Flipscene", ScrW(), ScrH())
	local cursedMat = CreateMaterial("Portal_Flipscene", "GMODScreenspace", {
		["$basetexture"] = cursedRT:GetName(),
	})

	local mirrored = false
	function SeamlessPortals.ToggleMirror(enable)
		if enable then
			hook.Add("PreRender", "portal_flip_scene", function()
				rendering = true
				render.PushRenderTarget(cursedRT)
				render.RenderView({drawviewmodel = false})
				render.PopRenderTarget()
				rendering = false
			end)

			hook.Add("PostDrawTranslucentRenderables", "portal_flip_scene", function(_, sky, sky3d)
				if rendering or SeamlessPortals.Rendering then return end
				render.SetMaterial(cursedMat)
				render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())

				if LocalPlayer():Health() <= 0 then
					SeamlessPortals.ToggleMirror(false)
				end
			end)

			-- invert mouse x
			hook.Add("InputMouseApply", "portal_flip_scene", function(cmd, x, y, ang)
				if LocalPlayer():WaterLevel() < 3 then
					-- What the fuck is this?
					-- TODO: Comment what this does
					cmd:SetViewAngles(ang + Angle(0, x / 22.5, 0))
				end
			end)

			-- invert movement x
			hook.Add("CreateMove", "portal_flip_scene", function(cmd)
				if LocalPlayer():WaterLevel() < 3 then
					cmd:SetSideMove(-cmd:GetSideMove())
				end
			end)

			mirrored = true
		elseif enable == false then
			hook.Remove("PreRender", "portal_flip_scene")
			hook.Remove("PostDrawTranslucentRenderables", "portal_flip_scene")
			hook.Remove("InputMouseApply", "portal_flip_scene")
			hook.Remove("CreateMove", "portal_flip_scene")

			mirrored = false
		end

		return mirrored
	end

	SeamlessPortals.ToggleMirror(false)
end
