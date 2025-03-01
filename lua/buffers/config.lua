local Config = {}

function Config:new(config)
	local instance = {
		_value = config,
	}

	setmetatable(instance, {
		__index = Config,
	})

	return instance
end

function Config:set(new_config)
	self._value = vim.tbl_deep_extend("force", self._value, new_config)
end

function Config:get()
	return self._value
end

local defaul_config = {
	enable = function()
		return true
	end,
	keymap = {
		close_buffer = "x",
		quit = "q",
		enter = "<cr>",
	},
	window = {
		width = 60,
	},
}

return Config:new(defaul_config)
