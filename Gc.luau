getgenv().filtergc = newcclosure(function(...)
    local args = {...}
    local type_or_callback = args[1]
    
    -- Handle callback-style API: filtergc(function(obj) return condition end)
    if typeof(type_or_callback) == "function" then
        local callback = type_or_callback
        local matches = {}

        for i, v in getgc(true) do
            local success, passed = pcall(callback, v)
            if success and passed then
                table.insert(matches, v)
            end
        end

        return matches
    end
    
    -- Handle structured API
    local filterType = type_or_callback
    local filterOptions = args[2] or {}
    local returnOne = args[3]
    local matches = {}
    
    if filterType == "table" then
        for i, v in getgc(true) do
            if typeof(v) ~= "table" then
                continue
            end
    
            local passed = true
    
            -- Check Keys filter
            if filterOptions.Keys and typeof(filterOptions.Keys) == "table" and passed then
                for _, key in filterOptions.Keys do
                    if rawget(v, key) == nil then
                        passed = false
                        break
                    end
                end
            end
    
            -- Check Values filter
            if filterOptions.Values and typeof(filterOptions.Values) == "table" and passed then
                local tableVals = {}
                for _, value in next, v do
                    table.insert(tableVals, value)
                end
                for _, value in filterOptions.Values do
                    if not table.find(tableVals, value) then
                        passed = false
                        break
                    end
                end
            end
    
            -- Check KeyValuePairs filter
            if filterOptions.KeyValuePairs and typeof(filterOptions.KeyValuePairs) == "table" and passed then
                for key, value in filterOptions.KeyValuePairs do
                    if rawget(v, key) ~= value then
                        passed = false
                        break
                    end
                end
            end
    
            -- Check Metatable filter
            if filterOptions.Metatable and passed then
                local success, mt = pcall(getrawmetatable, v)
                if success then
                    passed = filterOptions.Metatable == mt
                else
                    passed = false
                end
            end
    
            if passed then
                if returnOne then
                    return v
                else
                    table.insert(matches, v)
                end
            end
        end

    elseif filterType == "function" then
        -- Default IgnoreExecutor to true if not specified
        if filterOptions.IgnoreExecutor == nil then
            filterOptions.IgnoreExecutor = true
        end

        for i, v in getgc(false) do
            if typeof(v) ~= "function" then
                continue
            end
    
            local passed = true
            local isCClosure = pcall(function() return iscclosure(v) end) and iscclosure(v) or false
    
            -- Check Name filter
            if filterOptions.Name and passed then
                local success, funcName = pcall(function()
                    local info = debug.info(v, "n")
                    return info
                end)
                if success and funcName then
                    passed = funcName == filterOptions.Name
                else
                    -- Try alternative method for function names
                    local success2, funcString = pcall(function()
                        return tostring(v)
                    end)
                    if success2 and funcString then
                        passed = string.find(funcString, filterOptions.Name) ~= nil
                    else
                        passed = false
                    end
                end
            end
    
            -- Check IgnoreExecutor filter
            if filterOptions.IgnoreExecutor == true and passed then
                local success, isExec = pcall(function() return isexecutorclosure(v) end)
                if success then
                    passed = not isExec
                else
                    passed = true -- If can't check, assume it's not executor
                end
            end
    
            -- Skip C closure specific filters for C functions
            if isCClosure and (filterOptions.Hash or filterOptions.Constants or filterOptions.Upvalues) then
                passed = false
            end
    
            -- Handle non-C closure filters
            if not isCClosure and passed then
                -- Check Hash filter
                if filterOptions.Hash and passed then
                    local success, hash = pcall(function()
                        return getfunctionhash and getfunctionhash(v) or nil
                    end)
                    if success and hash then
                        passed = hash == filterOptions.Hash
                    else
                        passed = false
                    end
                end
        
                -- Check Constants filter
                if filterOptions.Constants and typeof(filterOptions.Constants) == "table" and passed then
                    local success, constants = pcall(function()
                        return debug.getconstants and debug.getconstants(v) or {}
                    end)
                    if success and constants then
                        local funcConsts = {}
                        for idx, constant in constants do
                            if constant ~= nil then
                                table.insert(funcConsts, constant)
                            end
                        end
                        for _, constant in filterOptions.Constants do
                            if not table.find(funcConsts, constant) then
                                passed = false
                                break
                            end
                        end
                    else
                        passed = false
                    end
                end
        
                if filterOptions.Upvalues and typeof(filterOptions.Upvalues) == "table" and passed then
                    local success, upvalues = pcall(function()
                        return debug.getupvalues and debug.getupvalues(v) or {}
                    end)
                    if success and upvalues then
                        local funcUpvals = {}
                        for idx, upval in upvalues do
                            if upval ~= nil then
                                table.insert(funcUpvals, upval)
                            end
                        end
                        for _, upval in filterOptions.Upvalues do
                            if not table.find(funcUpvals, upval) then
                                passed = false
                                break
                            end
                        end
                    else
                        passed = false
                    end
                end
            end
    
            if passed then
                if returnOne then
                    return v
                else
                    table.insert(matches, v)
                end
            end
        end

    else
        error("Expected type 'function' or 'table', got '" .. tostring(filterType) .. "'")
    end
    
    return returnOne and nil or matches
end, 'filtergc')
