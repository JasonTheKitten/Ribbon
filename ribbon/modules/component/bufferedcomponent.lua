local ribbon = require()

local class = ribbon.require "class"
local bctx = ribbon.require "bufferedcontext"
local ctxu = ribbon.require "contextutils"
local debugger = ribbon.require "debugger"
local process = ribbon.require "process"
local util = ribbon.require "util"

local Size = ribbon.require("class/size").Size
local SizePosGroup = ribbon.require("class/sizeposgroup").SizePosGroup
local Position = ribbon.require("class/position").Position

local Component = ribbon.require("component/component").Component
local BlockComponent = ribbon.require("component/blockcomponent").BlockComponent

local runIFN = util.runIFN

local bufferedcomponent = ...
local BufferedComponent = {}
bufferedcomponent.BufferedComponent = BufferedComponent

BufferedComponent.cparents = {BlockComponent}
BufferedComponent.__call = BlockComponent.__call

function BufferedComponent:setParent(parent)
	Component.setParent(self, parent)
	if parent and parent.context then
		self.context = bctx.getContext(parent.context, 0, 0, 0, 0, parent.eventSystem)
	end
end

--IFN functions
function BufferedComponent:setContextInternal()
	self.context = self.context or bctx.getContext(self.parent.context, 0, 0, 0, 0, self.parent.eventSystem)
	self.context.parent = self.parent.context
end
function BufferedComponent.drawIFN(q, self, hbr)
	if not self.parent then return end
	
	local obg, ofg = self.context.getColors()
	local dbg, dfg = self.context.parent.getColors()
	local ocf = self.context.getClickFunction()
	self.context.setClickFunction(self.handlers.onclick)
	self.context.setColorsRaw(self.color or dbg, self.textColor or dfg)
	self.context.startDraw()
	q(function()
		self.context.endDraw()
		self.context.setColorsRaw(obg, ofg)
		self.context.setClickFunction(ocf)
		
		local ocfp
		if self.context.parent.setClickFunction then
			ocfp = self.context.parent.getClickFunction()
			self.context.parent.setClickFunction(self.context.triggers.onclick)
		end
		self.context.drawBuffer()
		if ocfp then
			self.context.parent.setClickFunction(ocfp)
		end
	end)
	
	self.context.clear()
	
	for k, v in util.ripairs(self.children) do
		q(v.drawIFN, v, size)
	end
end