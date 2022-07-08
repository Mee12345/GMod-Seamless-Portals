TOOL.Category = "Seamless Portals"
TOOL.Name = "#Tool.portal_creator_tool.name"

TOOL.Information = {
	{ name = "left" },
	{ name = "right1", stage = 1 },
	{ name = "right2", stage = 2 },
	{ name = "reload" }
}

TOOL.LinkTarget = NULL

-- Yoink! smiley :)
local function VectorAngle(vec1, vec2)
	local costheta = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	local theta = math.acos(costheta)
	return math.deg(theta)
end

function TOOL:GetPlacementPosition(tr)
	local ply = self:GetOwner()
	if not tr then tr = ply:GetEyeTrace() end
	if not tr.Hit then return false end
	-- Yoink! smiley :)
	local rotatedAng = tr.HitNormal:Angle() + Angle(90, 0, 0)

	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle < 1 or (elevationangle > 179 and elevationangle < 181) then 
		rotatedAng.y = ply:EyeAngles().y + 180
	end

	return (tr.HitPos + tr.HitNormal * ply:GetInfoNum("seamless_portal_size_z", 1) * 10), rotatedAng
end

function TOOL:GetLinkTarget()
	if ( SERVER ) then
		return self.LinkTarget
	else
		return self:GetOwner():GetNWEntity("pct_linkTarget")
	end
end

if ( CLIENT ) then

	local green = Color(0, 255, 0, 50)

	language.Add("Tool.portal_creator_tool.name", "Portal Creator")
	language.Add("Tool.portal_creator_tool.desc", "Creates and links portals")
	language.Add("Tool.portal_creator_tool.left", "Left Click: Create portal")
	language.Add("Tool.portal_creator_tool.right1", "Right Click: Start linking a portal")
	language.Add("Tool.portal_creator_tool.right2", "Right Click: Create link to another portal")
	language.Add("Tool.portal_creator_tool.reload", "Reload: Remove your portals. Press SHIFT to clear all")

	-- Yoink! smiley :)
	local xVar = CreateClientConVar("seamless_portal_size_x", "1", false, true, "Sets the size of the portal along the X axis", 0.01, 10)
	local yVar = CreateClientConVar("seamless_portal_size_y", "1", false, true, "Sets the size of the portal along the Y axis", 0.01, 10)
	local zVar = CreateClientConVar("seamless_portal_size_z", "1", false, true, "Sets the size of the portal along the Z axis", 0.01, 10)
	local sidesVar = CreateClientConVar("seamless_portal_sides", "4", false, true, "Sets the number of sides the portal has", 3, 100)
	local backVar = CreateClientConVar("seamless_portal_backface", "1", false, true, "Sets whether to spawn with a backface or not", 0, 1)
	local gtConvars = {}

	-- The tool is not using /ClientConVar/ that utilizes tool mode prefix. Populate manually
	gtConvars["seamless_portal_size_x"  ] = 1
	gtConvars["seamless_portal_size_y"  ] = 1
	gtConvars["seamless_portal_size_z"  ] = 1
	gtConvars["seamless_portal_sides"   ] = 4
	gtConvars["seamless_portal_backface"] = 1

	function TOOL.BuildCPanel(panel)
		-- dvdvideo1234: We should not use AddControl
		panel:SetName(language.GetPhrase("Tool.portal_creator_tool.name"))
		panel:Help   (language.GetPhrase("Tool.portal_creator_tool.desc"))
		-- dvdvideo1234: Implement a proper preset storage
		local item = vgui.Create("ControlPresets", panel)
		item:SetPreset("seamless_portal")
		item:AddOption("Default", gtConvars)
		for k, v in pairs(table.GetKeys(gtConvars)) do item:AddConVar(v) end
		panel:AddItem(item)

		item = panel:NumSlider("Portal Size X", "seamless_portal_size_x", 0.05, 10, 2)
		item:SetDefaultValue(gtConvars["seamless_portal_size_x"])
		item = panel:NumSlider("Portal Size Y", "seamless_portal_size_y", 0.05, 10, 2)
		item:SetDefaultValue(gtConvars["seamless_portal_size_y"])
		item = panel:NumSlider("Portal Size Z", "seamless_portal_size_z", 0.1, 10, 2)
		item:SetDefaultValue(gtConvars["seamless_portal_size_z"])
		item = panel:NumSlider("Portal Sides", "seamless_portal_sides", 3, 100, 0)
		item:SetDefaultValue(gtConvars["seamless_portal_sides"])
		panel:CheckBox("Has Backface (Invisible until linked!)", "seamless_portal_backface")
	end

	local beamMat = Material("cable/blue_elec")
	function TOOL:DrawHUD()
		local pos, angles = self:GetPlacementPosition()
		if not pos then return end

		cam.Start3D()
			if self:GetStage() == 2 then
				local target = self:GetLinkTarget()
				if IsValid(target) then
					local from = target:GetPos()
					local to = pos
					local tr = self.Owner:GetEyeTrace()
					-- The tower of if statements
					if tr.Hit then
						local ent = tr.Entity
						if IsValid(ent) then
							if ent:GetClass() == "seamless_portal" then
								if ent:EntIndex() ~= target:EntIndex() then
									to = ent:GetPos()
								end
							end
						end
					end
					render.SetMaterial(beamMat)
					render.DrawBeam(from, to, 3, 0, 1)
					cam.End3D()
					return
				end
			end
			local xScale = xVar:GetFloat()
			local yScale = yVar:GetFloat()
			local zScale = zVar:GetFloat()
			render.SetColorMaterial()
			render.DrawBox(pos, angles, Vector(-47.45 * xScale, -47.45 * yScale, -zScale * 5), Vector(47.45 * xScale, 47.45 * yScale, 0), green)
		cam.End3D()
	end

	function TOOL:LeftClick()
		return true
	end

	function TOOL:RightClick()
		return true
	end

	function TOOL:Reload()
		return true
	end

elseif ( SERVER ) then

	function TOOL:Deploy()
		self:SetStage(1)
	end

	function TOOL:LeftClick(trace)
		local pos, angles = self:GetPlacementPosition(trace)
		if not pos then return false end
		local ply = self:GetOwner()
		local ent = ents.Create("seamless_portal")
		if not (ent and ent:IsValid()) then return false end
		ent:SetPos(pos)
		ent:SetCreator(ply)
		ent:SetAngles(angles + Angle(270, 0, 0))
		ent:Spawn()
		if CPPI then ent:CPPISetOwner(ply) end
		-- Yoink! smiley
		local sizex = ply:GetInfoNum("seamless_portal_size_x", 1)
		local sizey = ply:GetInfoNum("seamless_portal_size_y", 1)
		local sizez = ply:GetInfoNum("seamless_portal_size_z", 1)
		ent:SetExitSize(Vector(sizex, sizey, sizez))
		ent:SetDisableBackface(ply:GetInfoNum("seamless_portal_backface", 1) == 0)
		ent:SetSides(ply:GetInfoNum("seamless_portal_sides", 4))
		cleanup.Add(ply, "props", ent)
        undo.Create("Seamless Portal ["..ent:EntIndex().."]")
            undo.AddEntity(ent)
            undo.SetPlayer(ply)
        undo.Finish()
		return true
	end

	function TOOL:SetLinkTarget(ent)
		self.LinkTarget = ent
		self:GetOwner():SetNWEntity("pct_linkTarget", ent)
	end

	function TOOL:GetTarget(trace)
		if not trace.Hit then return NULL end
		local ent = trace.Entity
		if not ent then return NULL end
		if ent:GetClass() ~= "seamless_portal" then return NULL end
		if CPPI then
			if not ent:CPPICanTool(self:GetOwner(), "portal_creator_tool") then return NULL end
		end
		return ent
	end

	function TOOL:RightClick(trace)
		local ent = self:GetTarget(trace)
		if not IsValid(ent) then
			self:SetStage(1)
			return false
		end
		local stage = self:GetStage()
		if (stage <= 1) then
			self:SetLinkTarget(ent)
			self:SetStage(2)
		else
			local linkTarget = self:GetLinkTarget()
			--[[if (ent:EntIndex() == linkTarget:EntIndex()) then
				self:SetStage(1)
				return false
			end]]
			-- LinkPortal already contains an IsValid check
			ent:LinkPortal(linkTarget)
			self:SetStage(1)
		end
		return true
	end


	function TOOL:Reload(tr)
		local ply = self:GetOwner()
		if ply:KeyDown(IN_SPEED) then
			local arr, rdx = ents.GetAll()
			for idx, ent in pairs(arr) do
				if ent:GetClass() == "seamless_portal" and
				   ent:GetCreator() == ply
				then -- We have removed atleast one entity
					rdx = idx -- Store the index to proof
					SafeRemoveEntity(ent) -- Remove
				end
			end -- Remove all the portals that are ours
			if rdx then return true end
			return false -- Do not soot effect
		else
			local tre = tr.Entity
			if !tre or !tre:IsValid() then return end
			if tre:GetClass() != "seamless_portal" then return end
			if tre:GetCreator() != ply then return end
			SafeRemoveEntity(tre)
			return true
		end
	end

end
