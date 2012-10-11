local self = {}
GCompute.FunctionResolutionResult = GCompute.MakeConstructor (self)

function self:ctor ()
	self.Overloads = {}
	self.FilteredOverloads = {}
	self.OverloadCompatibilities = {}
end

--- Adds a FunctionDefinition to this FunctionResolutionResult
-- @param functionDefinition The FunctionDefinition to be added
function self:AddOverload (functionDefinition)
	self.Overloads [#self.Overloads + 1] = functionDefinition
	self.FilteredOverloads [#self.FilteredOverloads + 1] = functionDefinition
end

--- Adds the FunctionDefinitions in an OverloadedFunctionDefinition to this FunctionResolutionResult
-- @param overloadedFunctionDefinition The OverloadedFunctionDefinition whose FunctionDefinitions are to be added
function self:AddOverloads (overloadedFunctionDefinition)
	for functionDefinition in overloadedFunctionDefinition:GetEnumerator () do
		self:AddOverload (functionDefinition)
	end
end

function self:AddOverloadsFromType (type, functionName)
	type = type and type:UnwrapAlias ()
	type = type and type:UnwrapReference ()
	type = type and type:UnwrapAlias ()
	if not type then return end

	local typeDefinition = type:GetTypeDefinition ()
	if not typeDefinition then return end
	
	if typeDefinition:MemberExists (functionName) and
	   typeDefinition:GetMemberMetadata (functionName):GetMemberType () == GCompute.MemberTypes.Method then
		self:AddOverloads (typeDefinition:GetMember (functionName))
	end
	
	for _, baseType in ipairs (type:GetBaseTypes ()) do
		self:AddOverloadsFromType (baseType, functionName)
	end
end

function self:ComputeMemoryUsage (memoryUsageReport)
	memoryUsageReport = memoryUsageReport or GCompute.MemoryUsageReport ()
	if memoryUsageReport:IsCounted (self) then return end
	
	memoryUsageReport:CreditTableStructure ("Function Resolutions", self)
	memoryUsageReport:CreditTableStructure ("Function Resolutions", self.Overloads)
	memoryUsageReport:CreditTableStructure ("Function Resolutions", self.FilteredOverloads)
	memoryUsageReport:CreditTableStructure ("Function Resolutions", self.OverloadCompatibilities)
	return memoryUsageReport
end

--- Filters the FunctionDefinitions in this FunctionResolutionResult
-- @param filter The filtering function
function self:Filter (filter)
	local overloadCount = #self.FilteredOverloads
	local sourceIndex = 1
	local destIndex = 1
	while sourceIndex <= overloadCount do
		local functionDefinition = self.FilteredOverloads [sourceIndex]
		self.FilteredOverloads [sourceIndex] = nil
		if filter (functionDefinition) then
			self.FilteredOverloads [destIndex] = functionDefinition
			destIndex = destIndex + 1
		end
		sourceIndex = sourceIndex + 1
	end
	
	self:SortByCompatibility ()
end

--- Filters the FunctionDefinitions in this FunctionResolutionResult using an argument type list
-- @param argumentTypeArray The array of argument types to filter against
function self:FilterByArgumentTypes (argumentTypeArray)
	self:Filter (
		function (functionDefinition)
			local _, compatibility = functionDefinition:CanAcceptArgumentTypes (argumentTypeArray)
			if compatibility ~= -math.huge then
				self.OverloadCompatibilities [functionDefinition] = compatibility
			end
			return compatibility ~= -math.huge
		end
	)
end

function self:GetFilteredOverload (index)
	return self.FilteredOverloads [index]
end

--- Gets the number of FunctionDefinitions remaining after filtering
-- @return The number of FunctionDefinitions remaining after filtering
function self:GetFilteredOverloadCount ()
	return #self.FilteredOverloads
end

function self:GetOverloadCompatibility (functionDefinition)
	return self.OverloadCompatibilities [functionDefinition] or -math.huge
end

--- Gets the number of FunctionDefinitions before filtering
-- @return The number of FunctionDefinitions before filtering
function self:GetOverloadCount ()
	return #self.Overloads
end

--- Returns true if the top two FunctionDefinitions have the same compatibility
-- @return A boolean indicating whether the top two FunctionDefinitions have the same compatibility
function self:IsAmbiguous ()
	if self:IsEmpty () then return false end
	return self.OverloadCompatibilities [self.FilteredOverloads [1]] == self.OverloadCompatibilities [self.FilteredOverloads [2]]
end

--- Returns true if no FunctionDefinitions were found
-- @return A boolean indicating whether no FunctionDefinitions remained after filtering
function self:IsEmpty ()
	return #self.FilteredOverloads == 0
end

--- Sorts the FunctionDefinitions by compatibility
-- @param argumentTypeArray The array of argument types to sort for
function self:SortByCompatibility (argumentTypeArray)
	table.sort (self.FilteredOverloads,
		function (a, b)
			return self.OverloadCompatibilities [a] > self.OverloadCompatibilities [b]
		end
	)
end

--- Returns a string representation of this FunctionResolutionResult
-- @return A string representation of this FunctionResolutionResult
function self:ToString ()
	local functionResolutionResult = "[Function Resolution]\n"
	functionResolutionResult = functionResolutionResult .. "{\n"
	
	local filteredOverloads = {}
	for _, functionDefinition in ipairs (self.FilteredOverloads) do
		filteredOverloads [functionDefinition] = true
		functionResolutionResult = functionResolutionResult .. "    [Accepted] [" .. string.format ("%3d", self.OverloadCompatibilities [functionDefinition]) .."] " .. functionDefinition:ToString () .. "\n"
	end
	
	for _, functionDefinition in ipairs (self.Overloads) do
		if not filteredOverloads [functionDefinition] then
			functionResolutionResult = functionResolutionResult .. "    [Rejected] [---] " .. functionDefinition:ToString () .. "\n"
		end
	end
	
	functionResolutionResult = functionResolutionResult .. "}"
	return functionResolutionResult
end