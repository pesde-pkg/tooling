local function eq(this: any, that: any): boolean
	if type(this) ~= type(that) then
		return false
	end

	if type(this) == "table" then
		local visited = {}

		for key, value in pairs(this) do
			if not eq(value, that[key]) then
				return false
			end
			visited[key] = true
		end

		for key, _ in pairs(that) do
			if not visited[key] then
				return false
			end
		end

		return true
	end

	return this == that
end

return eq
