local cplat = require()

local class = cplat.require "class"
local sctx = cplat.require "subcontext"
local ctxu = cplat.require "contextutils"
local debugger = cplat.require "debugger"
local process = cplat.require "process"
local util = cplat.require "util"

local Size = cplat.require("class/size").Size
local SizePosGroup = cplat.require("class/sizeposgroup").SizePosGroup
local Position = cplat.require("class/position").Position

local Component = cplat.require("component/component").Component

local runIFN = util.runIFN

local blockcomponent = ...
local BlockComponent = {}
blockcomponent.BlockComponent = BlockComponent

BlockComponent.cparents = {Component}
function BlockComponent:__call(parent)
	class.checkType(parent, Component, 3, "Component")
	
	Component.__call(self, parent)
	
	self.size = class.new(Size, 0, 0)
	self.autoSize = {}
end

function BlockComponent:setParent(parent)
	Component.setParent(self, parent)
	if parent and parent.context then
		self.context = sctx.getContext(parent.context, 0, 0, 0, 0)
	end
end

function BlockComponent:getSize()
	return self.size
end
function BlockComponent:setSize(size)
	class.checkType(size, Size, 3, "Size")
	self.size = size
end

function BlockComponent:setPreferredSize(size)
	if size then class.checkType(size, Size, 3, "Size") end
	self.preferredSize = size
end
function BlockComponent:getPreferredSize()
	return self.preferredSize
end

function BlockComponent:setMinSize(size)
	if size then class.checkType(size, Size, 3, "Size") end
	self.minSize = size
end
function BlockComponent:getMinSize()
	return self.minSize
end

function BlockComponent:setMaxSize(size)
	if size then class.checkType(size, Size, 3, "Size") end
	self.maxSize = size
end
function BlockComponent:getMaxSize()
	return self.maxSize
end

function BlockComponent:forceSize(size)
	class.checkType(size, Size, 3, "Size")
	self:setMinSize(size)
	self:setMaxSize(size)
	self:setPreferredSize(size)
	self:setSize(size)
end

function BlockComponent:setAutoSize(w, ow, h, oh)
	self.autoSize = {w, ow, h, oh}
end

--IFN functions
function BlockComponent.calcSizeIFN(q, self, size)
	if not self.parent then return end

	self.context = self.context or sctx.getContext(self.parent.context, 0, 0, 0, 0)
	self.context.parent = self.parent.context
	
	local osize = size
	if self.sizeAndLocation then
		local msize = self.sizeAndLocation[1]:clone()
		local x, y = ctxu.calcPos(self.parent.context, table.unpack(self.sizeAndLocation, 2))
		size = class.new(SizePosGroup, msize, class.new(Position, x, y), msize)
		self.size = size.size:clone()
	elseif self.sizePosGroup then
		size = self.sizePosGroup
	end
	if self.size.width==0 or self.size.height==0 then
		if self.preferredSize then
			self.size = self.preferredSize:clone()
		else
			self.size = class.new(Size, 0, 0)
		end
	end
	if self.autoSize[1] or self.autoSize[2] then
		self.size.width = osize.size.width*(self.autoSize[1] or 0) + (self.autoSize[2] or 0)
	end
	if self.autoSize[3] or self.autoSize[4] then
		self.size.height = osize.size.height*(self.autoSize[3] or 0) + (self.autoSize[4] or 0)
	end
	
	self.position = size.position:clone()
	local msize = class.new(SizePosGroup, self.size, nil, size.size)
	
	for k, v in util.ripairs(self.children) do
		if v.sizeAndLocation then q(v.calcSizeIFN, v, msize) end
	end
	q(function()
		if self.preferredSize then self.size:set(self.size:max(self.preferredSize)) end
		if self.minSize then self.size:set(self.size:max(self.minSize)) end
		if self.maxSize then self.size:set(self.size:min(self.maxSize)) end
		size:add(self.size)
		
		self.context.setPosition(self.position.x, self.position.y)
		self.context.setDimensions(self.size.width, self.size.height)
	end)
	for k, v in util.ripairs(self.children) do
		if not v.sizeAndLocation then q(v.calcSizeIFN, v, msize) end
	end
end
function BlockComponent.drawIFN(q, self, hbr)
	if not self.parent then return end
	
	local obg, ofg = self.context.getColors()
	local dbg, dfg = self.parent.context.getColors()
	local ocf = self.context.getClickFunction()
	self.context.setClickFunction(self.handlers.onclick)
	self.context.setColors(self.color or dbg, self.textColor or dfg)
	self.context.startDraw()
	q(function()
		self.context.endDraw()
		self.context.setColors(obg, ofg)
		self.context.setClickFunction(ocf)
	end)
	
	self.context.clear(self.color)
	
	for k, v in util.ripairs(self.children) do
		q(v.drawIFN, v, size)
	end
end