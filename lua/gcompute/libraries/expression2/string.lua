local Expression2 = GCompute.GlobalNamespace:AddNamespace ("Expression2")
local String = Expression2:AddType ("string")
String:SetPrimitive (true)
	
Expression2:AddFunction ("format", { { "string", "formatString" }, { "object", "..." } })
	:SetReturnType ("string")
	:SetNativeFunction (string.format)
	
Expression2:AddFunction ("print", { { "object", "..." } })
	:SetNativeFunction (
		function (...)
			local t = {...}
			for k, v in ipairs (t) do
				t [k] = tostring (v)
			end
			executionContext:GetProcess ():GetStdOut ():WriteLine (table.concat (t, "\t"))
		end
	)

String:AddFunction ("upper")
	:SetReturnType ("string")
	:SetNativeString ("string.upper (%self%)")
	:SetNativeFunction (string.upper)

String:AddFunction ("lower")
	:SetReturnType ("string")
	:SetNativeString ("string.lower (%self%)")
	:SetNativeFunction (string.lower)
	
String:AddFunction ("operator+", { { "string", "str" } })
	:SetReturnType ("string")
	:SetNativeString ("(%self% .. %str%)")
	:SetNativeFunction (
		function (self, str)
			return self .. str
		end
	)
	
String:AddFunction ("operator+", { { "number", "n" } })
	:SetReturnType ("string")
	:SetNativeString ("(%self% .. %n%")
	:SetNativeFunction (
		function (self, n)
			return self .. n
		end
	)
	
String:AddExplicitCast ("number", function (s) return tonumber (s) or 0 end)