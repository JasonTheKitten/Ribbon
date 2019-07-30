local cplat = require()

local process = cplat.require "process"
local contextapi = cplat.require "context"
local displayapi = cplat.require "display"
local bctx = cplat.require "bufferedcontext"
local ctxu = cplat.require "contextutils"
local statics = cplat.require "statics"

local COLORS = statics.get("colors")

local display = displayapi.getDisplay(displayapi.getDefaultDisplayID())
local octx = contextapi.getNativeContext(display)
local ctx = bctx.getContext(octx, 0, 0, nil, nil, process)

octx.startDraw()
ctx.startDraw()

local timerLabel = " CPlat Timer "
local ttime = ""
local t = ""

local function draw(rst)
	octx.update()
	ctx.update()
	
	local titlePosX, titlePosY = ctxu.calcPos(ctx, 0, .5, 0, .3, #timerLabel, -.5, 1, 0)
	local timePosX, timePosY = ctxu.calcPos(ctx, 0, .5, 0, .6, 5, -.5, 1, 0)
	
	if rst then
		ctx.clear(COLORS.BLUE)
		ctx.drawRect(0, 0, ctx.width, ctx.height, false, COLORS.LIGHTBLUE, "%", COLORS.GREEN)
		ctx.drawText(titlePosX, titlePosY, timerLabel, COLORS.PINK, COLORS.WHITE)
	end
	local timeW0 = ctxu.align(t or "OUT", ctxu.ALIGN_RIGHT, 3, (#ttime~=3 and "X") or "0")
	local timePadded = ctxu.align(timeW0, ctxu.ALIGN_CENTER, 5)
	ctx.drawText(timePosX, timePosY, timePadded, COLORS.PINK, COLORS.WHITE)
	
	ctx.drawBuffer()
end
process.addEventListener("display_resize", function()draw(true)end)
process.addEventListener("device_connected", function()draw(true)end)

draw(true)
local ri = true
process.addEventListener("char", function(e)
	if not ri then return end
	if ("1234567890"):find(e.char) then
		ttime = ttime..e.char
		t = ttime
		draw(nil, "X")
		if #ttime == 3 then
			ri = false
		end
	end
end)
while ri do
	coroutine.yield()
end
sleep(1)
for i=0, tonumber(ttime) do
	t = i
	draw()
	--ctx.adjustScroll(1, 1)
	sleep(1)
	i=i+1
end
t = nil
draw()
sleep(5)

ctx.endDraw()
octx.endDraw()