--Using GLib to allow LOADS of settings to be sent
local GLib = LibK.GLib

function Pointshop2Controller:loadSettings( noTransmit )
	local moduleInitPromises = {}
	for k, mod in pairs( Pointshop2.Modules ) do
		table.insert( moduleInitPromises, Pointshop2.InitializeModuleSettings( mod ) )
	end
	
	WhenAllFinished( moduleInitPromises )
	:Then( function( )
		local data = LibK.von.serialize( { Pointshop2.Settings.Shared } )
		local resource = LibK.GLib.Resources.RegisterData( "Pointshop2", "settings", data )
		resource:GetCompressedData( ) --Force compression now
		KLogf( 4, "[Pointshop2] Settings package loaded, version " .. resource:GetVersionHash( ) )
		
		if not noTransmit then
			self:startView( "Pointshop2View", "loadSettings", player.GetAll( ), resource:GetVersionHash( ) )
		end
	end )
end
Pointshop2.DatabaseConnectedPromise:Done( function( )
	Pointshop2Controller:getInstance( ):loadSettings( )
end )
hook.Add( "OnReloaded", "HandleModSettingsReload", function( )
	Pointshop2Controller:getInstance( ):loadSettings( )
end )

function Pointshop2Controller:SendInitialSettingsPackage( ply )
	local resource = LibK.GLib.Resources.Resources["Pointshop2/settings"]
	if not resource then
		KLogf( 4, "[Pointshop2] Settings package not loaded yet, trying again later" )
		timer.Simple( 1, function( ) self:SendInitialSettingsPackage( ply ) end )
		return
	end
	self:startView( "Pointshop2View", "loadSettings", ply, resource:GetVersionHash( ) )
end
hook.Add( "LibK_PlayerInitialSpawn", "InitialRequestSettings", function( ply )
	timer.Simple( 1, function( )
		Pointshop2Controller:getInstance( ):SendInitialSettingsPackage( ply )
	end )
end )

GLib.Transfers.RegisterHandler( "Pointshop2.Settings", GLib.NullCallback )
GLib.Transfers.RegisterRequestHandler( "Pointshop2.Settings", function( userId, data )
	local inBuffer = GLib.StringInBuffer( data )
	local modName = inBuffer:String( )
	
	local ply
	for k, v in pairs( player.GetAll( ) ) do
		if GLib.GetPlayerId( v ) == userId then
			ply = v
			break
		end
	end
	
	if not PermissionInterface.query( ply, "pointshop2 managemodules" ) then
		KLogf( 3, "[Pointshop2] Rejecting settings transfer for %i, not allowed", userId )
		return false
	end
	
	local settings = Pointshop2.Settings.Server[modName] 
	if not settings then
		KLogf( 3, "[Pointshop2] Rejecting settings transfer for %i, settings %s not found", userId, modName )
		return false
	end
	
	local outBuffer = GLib.StringOutBuffer( )
	outBuffer:LongString( LibK.von.serialize( settings ) )
	return true, outBuffer:GetString( )
end )

GLib.Transfers.RegisterInitialPacketHandler( "Pointshop2.SettingsUpdate", function( userId, data )
	local ply
	for k, v in pairs( player.GetAll( ) ) do
		if GLib.GetPlayerId( v ) == userId then
			ply = v
			break
		end
	end
	
	if not PermissionInterface.query( ply, "pointshop2 managemodules" ) then
		KLogf( 3, "[Pointshop2] Rejecting settings update from %s, insufficient permissions", ply:Nick( ) )
		return false
	end
	
	return true
end )

/*
	An admin sends us new settings
*/
GLib.Transfers.RegisterHandler( "Pointshop2.SettingsUpdate", function( userId, data )
	local inBuffer = GLib.StringInBuffer( data )
	local modName = inBuffer:String( )
	local realm = inBuffer:String( )
	local serializedData = inBuffer:LongString( )
	
	local newSettings = LibK.von.deserialize( serializedData )
	Pointshop2.StoredSetting.findAllByPlugin( modName )
	:Then( function( stored )
		local promises = {}
		
		for settingPath, settingValue in pairs( newSettings ) do
			local needsUpdate, settingToUpdate
			for k, storedSetting in pairs( stored ) do
				if storedSetting.path == settingPath then
					--Need to compare them as serialized versions, might be tables or other data structures
					if LibK.von.serialize( {settingValue} ) != LibK.von.serialize( {storedSetting.value} ) then
						needsUpdate = true
					end
					settingToUpdate = storedSetting
				end
			end
			if settingToUpdate then
				if needsUpdate then
					--setting exists and needs to be updated
					settingToUpdate.value = settingValue
					table.insert( promises, settingToUpdate:save( ) )
				end
				continue --Setting already exists in the database
			end
			
			--Doesn't exist, create new:
			local storedSetting = Pointshop2.StoredSetting:new( )
			storedSetting.plugin = modName
			storedSetting.path = settingPath
			storedSetting.value = settingValue
			table.insert( promises, storedSetting:save( ) )
		end
		return WhenAllFinished( promises )
	end )
	:Done( function( )
		local dontSendToClients = ( realm == "Server" ) 
		Pointshop2Controller:getInstance( ):loadSettings( dontSendToClients )
	end )
end )