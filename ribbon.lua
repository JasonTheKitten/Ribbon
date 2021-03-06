--TODO: Finish sandboxing

--Ribbon Core
local ribbon = {}

--Compatibility
local require = require or function()
	error("Require is not supported")
end

--Execution environment header
local env = {}

--App Info
local nAPP = {
	PATHS={},
	TYPE = "",
	CONTEXT = nil
}
local APP = {}
for k, v in pairs(nAPP) do APP[k] = v end
ribbon.setAppInfo = function(inf)
    APP = inf
	APP.TYPE = APP.TYPE or nAPP.TYPE

    return ribbon
end
ribbon.getAppInfo = function()
    return APP
end

--OC/CC
local isOC = not not pcall(require, "term")

--Paths
ribbon.setPaths = function(paths)
    if not paths then
        appInfo.PATHS = {}
    else
        for k, v in pairs(paths) do
            if type(k)~="string" then
                appInfo.PATHS[v] = nil
            else
                appInfo.PATHS[k] = v
            end
        end
    end
end
ribbon.resolvePath = function(path, ftable, maxTries)
    if path:sub(1, 1) == "!" then return path:sub(2, #path) end
    if path:sub(1, 1) == "#" then path = path:sub(2, #path) end

	maxTries = maxTries or APP.PATHRESOLUTIONTRIES or 50

    local pathreps = {}
    for k, v in pairs(APP.PATHS) do pathreps[k] = v end
    for k, v in pairs(ftable or {}) do pathreps[k] = v end

	--We must resolve multiple times, as some paths may reference others
	local oldpath, tries = "", 0
	while oldpath~=path do
		if tries>maxTries and maxTries>0 then error("Path resolve failed", 2) end
		tries=tries+1
		oldpath = path
		for k, v in pairs(pathreps) do path = path:gsub("${"..k.."}", v) end
	end
    return "/"..path:gsub("$#", "$")
end

--Require Ribbon modules
local required, triedFS, fsDone = {}, nil, false
local mi = 0
ribbon.require = function(p, e)
	--print("About to load module! (debug="..tostring(mi)..","..p..")")
	local mid = mi
	mi=mi+1
    if not required[p] then
        local plist = {
            ribbon.resolvePath("${RIBBON}/modules/${module}.lua", {module=p})
        }

		if not triedFS then
			triedFS = true
			local ok, err = pcall(ribbon.require, "filesystem", false)
			if not ok then
				required["filesystem"] = nil
			else
				fsDone = true
			end
		end
        if required["filesystem"] and fsDone and elibs~=false then
			local libsPath = ribbon.resolvePath("${RIBBON}/libraries")
            local list = required["filesystem"].list(libsPath)
            for i=1, #list do
                local resolved = libsPath.."/"..list[i].."/"..p..".lua"
                if required["filesystem"].isFile(resolved) then
                    plist[#plist+1] = resolved
                end
            end
        end

        local m, err = nil, "File Not Found"
        for i=1, #plist do
            m,err=env.loadfile(plist[i], "tb", env)
            if m then break end
        end

        if not m then error("Failed to load module \""..p.."\" because:\n"..err, 2) end

        required[p] = {}
    	local extramethods=m(required[p])

    	setmetatable(required[p], {__index=extramethods})
		
		--print("Module done loading! (debug="..tostring(mid)..","..p..")")
	else
		--print("Module was already cached! (debug="..tostring(mid)..","..p..")")
    end

    return required[p]
end

--Ribbon path loading
local reqpaths = {}
ribbon.reqpath = function(path, resolve, useLua)
    if resolve~=false then
        resolve = (type(resolve)=="table" and resolve) or {}
        path = ribbon.resolvePath(path, resolve)..(useLua~=false and ".lua" or "")
    end
    path = ribbon.require("filesystem").getFullPath(path) --TODO: Support relative paths
    if not reqpaths[path] then
        reqpaths[path] = {}
        local m, err = env.loadfile(path, "tb", env)
        if not m then error("Failed to require path \""..path.."\" because:\n"..err, 2) end
    	local extramethods=m(reqpaths[path])
        setmetatable(reqpaths[path], {
    		__index=extramethods
    	})
    end
    return reqpaths[path]
end

--Execute
ribbon.execute = function(path, ...)
	if not path then error("No path supplied", 2) end
	local func, err = env.loadfile(ribbon.resolvePath(path), "t", env)
    if not func then error(err, 2) end
	
	pcall(ribbon.require, "ribbonos")

    ribbon.require("process").execute(func, ...)
end

--Arg passing
local passArgs = {}
ribbon.getPassArgs = function()
	local mpa = passArgs
	passArgs = {}
	return env.table.unpack(mpa)
end
ribbon.setPassArgs = function(...)
	passArgs = {...}
end

--Other stuff
ribbon.installGlobals = function(tbl)
    (tbl or env)._G = _ENV or _G
    return (tbl or env)._G
end

--Functions for env
local nloadfile = loadfile
local function loadfile(f, m, e)
    if type(m) == "table" then e=m m="t" end
    if fs then return nloadfile(f, e)
    else return nloadfile(f, m, e)
    end
end
local rawlen = rawlen or function(v)
    return #v
end
local dofile = dofile --TODO

local mos = {}
for k, v in pairs(os) do mos[k] = v end
local function sleep(t)
	local time = mos.clock()+t
	while mos.clock()<time do
		coroutine.yield()
	end
end

--Execution environment
env._ENV = env
env._VERSION = _VERSION or "Lua 5.2"
env._G = env
env.assert = assert
env.collectgarbage = collectgarbage or function() end
env.dofile = dofile
env.error = error
env.getmetatable = getmetatable
env.ipairs = ipairs
env.load = load
env.loadfile = loadfile
env.next = next
env.pairs = pairs
env.pcall = pcall
env.print = print
env.rawequal = rawequal
env.rawget = rawget
env.rawlen = rawlen
env.rawset = rawset
env.read = function() return io.read() end
env.select = select
env.setmetatable = setmetatable
env.sleep = sleep
env.tonumber = tonumber
env.tostring = tostring
env.type = type
env.xpcall = xpcall

--TODO: Sandbox these, install/fix missing/outdated functions
env.bit32 = bit32
env.coroutine = coroutine
env.debug = debug
env.io = io
env.math = math
env.os = mos
env.string = string
env.table = {}
for k, v in pairs(table) do env.table[k] = v end
env.table.unpack = table.unpack or unpack

local package = {
    loaded = {},
    config = "/\n;\n?\n!\n-",
    path = "?;?.lua;",
    preload = {}
}
env.package = package
env.require = function(arg)
    if (not arg) or (arg=="") then
        return ribbon
    end
    if package.loaded[arg] then
        return package.loaded[arg]
    end
    --TODO: Require
end
--TODO: Package

--Fix time
if isOC then
	mos.clock = require("computer").uptime
end

--Return functions
return ribbon