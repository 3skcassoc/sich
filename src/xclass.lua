local new = function (class, ...)
	return setmetatable({__class = class}, class.__objmt):__create(...)
end

xclass = setmetatable(
{
	__create = function (self)
		return self
	end,
},
{
	__call = function (xclass, class)
		class.__objmt = {__index = class}
		return setmetatable(class, {
			__index = class.__parent or xclass,
			__call = new,
		})
	end,
})
