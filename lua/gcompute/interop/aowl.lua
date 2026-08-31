if not SERVER then return end

local function RegisterAowlCommands ()
	local function ExecuteExpression (ownerId, hostId, expression)
		if GLib.CallSelfInThread () then return end
		
		-- Execution context
		local executionContext, returnCode = GCompute.Execution.ExecutionService:CreateExecutionContext (ownerId, hostId, "GLua", GCompute.Execution.ExecutionContextOptions.EasyContext + GCompute.Execution.ExecutionContextOptions.Repl)
		if not executionContext then
			print ("Failed to create execution context (" .. GCompute.ReturnCode [returnCode] .. ").")
			return
		end
		
		local executionInstance, returnCode = executionContext:CreateExecutionInstance (expression, nil, GCompute.Execution.ExecutionInstanceOptions.EasyContext + GCompute.Execution.ExecutionInstanceOptions.ExecuteImmediately + GCompute.Execution.ExecutionInstanceOptions.CaptureOutput + GCompute.Execution.ExecutionInstanceOptions.SuppressHostOutput)
		if executionInstance then
			executionInstance:GetCompilerStdOut ():ChainTo (GCompute.Text.ConsoleTextSink)
			executionInstance:GetCompilerStdErr ():ChainTo (GCompute.Text.ConsoleTextSink)
			executionInstance:GetStdOut ():AddEventListener ("Text",
				function (_, text, color)
					color = color or GLib.Colors.White
					
					-- Translate color
					local colorId = GCompute.SyntaxColoring.PlaceholderSyntaxColoringScheme:GetIdFromColor (color)
					if colorId then
						color = GCompute.SyntaxColoring.DefaultSyntaxColoringScheme:GetColor (colorId) or color
					end
					
					GCompute.Text.ConsoleTextSink:WriteColor (text, color)
				end
			)
			executionInstance:GetStdErr ():ChainTo (GCompute.Text.ConsoleTextSink)
			
			-- Line break
			GCompute.Text.ConsoleTextSink:WriteOptionalLineBreak ()
		else
			print ("Failed to create execution instance (" .. GCompute.ReturnCode [returnCode] .. ").")
		end
	end
	
	-- Every one of these commands is an alias spelling of the same
	-- evaluate-and-print operation, so what a command does is decided entirely
	-- by the host its expression runs on.
	local hostDescriptions =
	{
		[GLib.GetServerId ()] = "Runs an expression and prints the result on the server",
		["Clients"          ] = "Runs an expression and prints the result on every client",
		["Shared"           ] = "Runs an expression and prints the result on the server and every client",
		["^"                ] = "Runs an expression and prints the result on your own client",
		["Client"           ] = "Runs an expression and prints the result on another player's client",
		["Both"             ] = "Runs an expression and prints the result on the server and your own client",
	}
	
	local executionCommands =
	{
		["p"      ] = GLib.GetServerId (),
		["t2"     ] = GLib.GetServerId (),
		["tbl"    ] = GLib.GetServerId (),
		["print2" ] = GLib.GetServerId (),
		["table2" ] = GLib.GetServerId (),
		
		["pc"     ] = "Clients",
		["tc2"    ] = "Clients",
		["tblc"   ] = "Clients",
		["printc2"] = "Clients",
		["tablec" ] = "Clients",
		["tablec2"] = "Clients",
		
		["ps"     ] = "Shared",
		["ts"     ] = "Shared",
		["tbls"   ] = "Shared",
		["prints" ] = "Shared",
		["tables" ] = "Shared",
		["prints2"] = "Shared",
		["tables2"] = "Shared",
		
		["pm2"    ] = "^",
		["tm"     ] = "^",
		["tblm"   ] = "^",
		["printm2"] = "^",
		["tablem" ] = "^",
		["tablem2"] = "^",
		
		["psc"    ] = "Client",
		["pb"     ] = "Both",
	}
	
	for command, defaultHostId in pairs (executionCommands) do
		aowl.AddCommand (
			command,
			hostDescriptions [defaultHostId],
			function (ply, expression, target)
				local expression = expression or ""
				
				local userId
				if ply == NULL then
					-- Console
					userId = GLib.GetServerId ()
					aowlMsg("!" .. command .. " CONSOLE", expression)
				else
					userId = GLib.GetPlayerId (ply)
					aowlMsg("!" .. command .. " " .. ply:Nick () .. " (" .. ply:SteamID () .. ")", expression)
				end
				
				local hostId = defaultHostId
				if hostId == "^" then -- self
					hostId = userId
					
				elseif hostId == "Client" then
					expression = string.sub (expression, string.find (expression, target, 1, true) + (#target + 1))
					target = easylua.FindEntity (target)
					
					if istable(target) and target.get then
						local targets = {}
						
						for _, pl in next, target.get() do
							targets[#targets+1] = GLib.GetPlayerId (pl)
						end
						
						if #targets == 0 then return false end
						hostId = targets
						
					elseif type (target) == "Player" then
						hostId = GLib.GetPlayerId (target)
						
					else
						return false
					end
						
				elseif hostId == "Both" then
					if ply == NULL then
						-- Console
						hostId = userId
					else
						hostId =
						{
							GLib.GetServerId (),
							userId,
						}
					end
				end
				
				ExecuteExpression (userId, hostId, expression)
			end,
			"developers",
			false
		)
	end
end

if aowl then
	RegisterAowlCommands ()
end

hook.Add ("AowlInitialized", "GCompute.AowlCommands",
	function ()
		RegisterAowlCommands ()
	end
)
