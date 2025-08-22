-- init.lua

local RunService = game:GetService("RunService")

-------------------------------------------------
-- HOOK LIBRARY
-------------------------------------------------
local hook = {}
local hooks = {}
local connections = {}

local add = function(event, id, func, priority)
	if not hooks[event] then hooks[event] = {} end
	hooks[event][id] = {func = func, priority = priority or 0, once = false}
end

local add_once = function(event, id, func, priority)
	if not hooks[event] then hooks[event] = {} end
	hooks[event][id] = {func = func, priority = priority or 0, once = true}
end

local remove = function(event, id)
	if hooks[event] then
		hooks[event][id] = nil
		if next(hooks[event]) == nil then hooks[event] = nil end
	end
end

local sort_list = function(tbl)
	table.sort(tbl, function(a,b) return a.priority > b.priority end)
end

local exec = function(list, stop_on_return, ...)
	for _, data in ipairs(list) do
		local ok, res = pcall(data.func, ...)
		if not ok then warn("[hook] error in '" .. tostring(data.id) .. "': ".. tostring(res)) end
		if data.once and hooks[data.event] then
			hooks[data.event][data.id] = nil
		end
		if stop_on_return and res ~= nil then return res end
	end
end

local call = function(event, ...)
	local list = {}
	if hooks[event] then
		for id,data in pairs(hooks[event]) do
			table.insert(list, {id=id, func=data.func, priority=data.priority, once=data.once, event=event})
		end
	end
	if hooks["*"] then
		for id,data in pairs(hooks["*"]) do
			table.insert(list, {id=id, func=data.func, priority=data.priority, once=data.once, event="*"})
		end
	end
	if #list == 0 then return end
	sort_list(list)
	return exec(list, true, ...)
end

local run = function(event, ...)
	local list = {}
	if hooks[event] then
		for id,data in pairs(hooks[event]) do
			table.insert(list, {id=id, func=data.func, priority=data.priority, once=data.once, event=event})
		end
	end
	if hooks["*"] then
		for id,data in pairs(hooks["*"]) do
			table.insert(list, {id=id, func=data.func, priority=data.priority, once=data.once, event="*"})
		end
	end
	if #list == 0 then return end
	sort_list(list)
	exec(list, false, ...)
end

local bind_signal = function(event, signal)
	if connections[event] then connections[event]:Disconnect() end
	connections[event] = signal:Connect(function(...) call(event, ...) end)
end

local unbind_signal = function(event)
	if connections[event] then connections[event]:Disconnect() connections[event]=nil end
end

hook.add = add
hook.add_once = add_once
hook.remove = remove
hook.call = call
hook.run = run
hook.bind_signal = bind_signal
hook.unbind_signal = unbind_signal

-------------------------------------------------
-- TIMER LIBRARY
-------------------------------------------------
local timer = {}
local timers = {}
local heartbeat_conn

local new_timer = function(id, delay, reps, func)
	return {
		id = id,
		delay = delay,
		reps = reps,
		func = func,
		next_fire = os.clock() + delay,
		paused = false,
		removed = false
	}
end

local simple = function(delay, func)
	local t = new_timer(nil, delay, 1, func)
	table.insert(timers, t)
	return t
end

local create = function(id, delay, reps, func)
	timer.remove(id)
	local t = new_timer(id, delay, reps, func)
	timers[id] = t
	return t
end

local remove = function(id)
	if timers[id] then
		timers[id].removed = true
		timers[id] = nil
	end
end

local destroy = function(id) remove(id) end
local exists = function(id) return timers[id] ~= nil end

local pause = function(id)
	if timers[id] then timers[id].paused = true return true end
	return false
end

local unpause = function(id)
	if timers[id] then
		timers[id].paused = false
		timers[id].next_fire = os.clock() + timers[id].delay
		return true
	end
	return false
end

local toggle = function(id)
	if timers[id] then
		if timers[id].paused then return unpause(id) else return pause(id) end
	end
	return false
end

local start = function(id)
	if timers[id] then
		timers[id].next_fire = os.clock() + timers[id].delay
		timers[id].paused = false
		return true
	end
	return false
end

local stop = function(id)
	if timers[id] then
		timers[id].paused = true
		timers[id].next_fire = os.clock() + timers[id].delay
		return true
	end
	return false
end

local adjust = function(id, delay, reps, func)
	if not timers[id] then return false end
	local t = timers[id]
	if delay then t.delay = delay end
	if reps ~= nil then t.reps = reps end
	if func then t.func = func end
	t.next_fire = os.clock() + t.delay
	return true
end

local reps_left = function(id)
	if timers[id] and timers[id].reps then return timers[id].reps end
	return 0
end

local time_left = function(id)
	if not timers[id] then return 0 end
	if timers[id].paused then return -1 end
	return timers[id].next_fire - os.clock()
end

local check = function() end

local step = function()
	local now = os.clock()
	for id, t in pairs(timers) do
		if t.removed then
			timers[id] = nil
		elseif not t.paused and now >= t.next_fire then
			local ok, err = pcall(t.func)
			if not ok then warn("[timer] error: " .. tostring(err)) end
			if t.reps then
				t.reps -= 1
				if t.reps <= 0 then timers[id] = nil continue end
			end
			t.next_fire = now + t.delay
		end
	end
end

if not heartbeat_conn then heartbeat_conn = RunService.Heartbeat:Connect(step) end

timer.simple = simple
timer.create = create
timer.remove = remove
timer.destroy = destroy
timer.exists = exists
timer.pause = pause
timer.unpause = unpause
timer.toggle = toggle
timer.start = start
timer.stop = stop
timer.adjust = adjust
timer.reps_left = reps_left
timer.time_left = time_left
timer.check = check

-------------------------------------------------
-- INJECT GLOBALS
-------------------------------------------------
getgenv().hook = hook
getgenv().timer = timer

return {
	hook = hook,
	timer = timer
}
