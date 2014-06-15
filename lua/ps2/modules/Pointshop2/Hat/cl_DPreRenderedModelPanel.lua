local PANEL = {}

function PANEL:Init( )
	self.dirty = true
end

function PANEL:SetPacOutfit( outfit )
	self.pacOutfit = outfit
	if IsValid( self.Entity ) then
		self.Entity:AttachPACPart( self.pacOutfit )
	end
end

function PANEL:SetViewInfo( viewInfo )
	self.viewInfo = viewInfo
end

function PANEL:SetModel( mdl )
	DModelPanel.SetModel( self, mdl )
	pac.SetupENT( self.Entity )
	if self.pacOutfit then
		self.Entity:AttachPACPart( self.pacOutfit )
	end
end

function PANEL:Paint( w, h )
	if not self.rt then
		local uid = "PS2RT_PreRender" .. math.random( 0, 1000000000 ) --not the cleanest but should work
		self.rt = GetRenderTarget( uid, 128, 128 )
		self.mat = CreateMaterial( uid .. "mat", "UnlitGeneric", {
			["$basetexture"] = self.rt,
			--["$vertexcolor"] = 1,
			--["$vertexalpha"] = 1
		} )
	end
	
	if not self.dirty and not self.forceRender then
		render.PushFilterMin( TEXFILTER.ANISOTROPIC );
		render.PushFilterMag( TEXFILTER.ANISOTROPIC );
			surface.SetMaterial( self.mat )
			surface.DrawTexturedRect( 0, 0, w, h )
		render.PopFilterMag( )
		render.PopFilterMin( )
		return
	end
	

	
	local oldRt = render.GetRenderTarget( )
	render.SetRenderTarget( self.rt )
		render.Clear( 47, 47, 47, 255, true, true )
		self:PaintActual( w, h )
	render.SetRenderTarget( oldRt )
	
	self.mat:SetTexture( "$basetexture", self.rt )
	
	render.PushFilterMin( TEXFILTER.ANISOTROPIC );
	render.PushFilterMag( TEXFILTER.ANISOTROPIC );
		surface.SetMaterial( self.mat )
		surface.DrawTexturedRect( 0, 0, w, h )
	render.PopFilterMag( )
	render.PopFilterMin( )
	
	self.LastPaint = RealTime()
	self.dirty = false
end

function PANEL:PaintActual( w, h )
	if not IsValid( self.Entity ) or
	   not self.pacOutfit or
	   not self.viewInfo then 
		surface.SetDrawColor( 255, 0, 0, 150 )
		surface.DrawRect( 0, 0, w, h )
		return
	end
	
	pac.Think()
	cam.Start3D( self.viewInfo.origin, self.viewInfo.angles, self.viewInfo.fov - 30, 0, 0, w, h, 5, 4096 )
		cam.IgnoreZ( true )
		render.SuppressEngineLighting( true )
		render.SetLightingOrigin( self.Entity:GetPos() )
		render.ResetModelLighting( self.colAmbientLight.r/255, self.colAmbientLight.g/255, self.colAmbientLight.b/255 )
		render.SetColorModulation( self.colColor.r/255, self.colColor.g/255, self.colColor.b/255 )
		render.SetBlend( self.colColor.a/255 )
		
		for i=0, 6 do
			local col = self.DirectionalLight[ i ]
			if ( col ) then
				render.SetModelLighting( i, col.r/255, col.g/255, col.b/255 )
			end
		end
		
		--pac.HookEntityRender( self.Entity, self.pacOutfit )
		pac.ForceRendering( true )
			pac.RenderOverride( self.Entity, "opaque" )
			pac.RenderOverride( self.Entity, "translucent", true )
			self.Entity:DrawModel( )
			pac.RenderOverride( self.Entity, "translucent", true )
		pac.ForceRendering( false )
		--pac.UnhookEntityRender( self.Entity, self.pacOutfit )
		
		cam.IgnoreZ( false )
		render.SuppressEngineLighting( false )
	cam.End3D( )
end

vgui.Register( "DPreRenderedModelPanel", PANEL, "DModelPanel" )