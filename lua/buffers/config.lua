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
		close_buffer = { "d" },
		quit = { "q", "<esc>" },
		jump = {
			"a",
			"b",
			"c",
			"e",
			"f",
			"g",
			"h",
			"i",
			"l",
			"m",
			"n",
			"o",
			"p",
			"r",
			"s",
			"t",
			"u",
			"v",
			"w",
			"x",
			"y",
			"z",
			"A",
			"B",
			"C",
			"D",
			"E",
			"F",
			"H",
			"I",
			"J",
			"K",
			"L",
			"M",
			"N",
			"O",
			"P",
			"Q",
			"R",
			"S",
			"T",
			"U",
			"V",
			"W",
			"X",
			"Y",
			"Z",
		},
		search = { "<C-f>" },
	},
}

return Config:new(defaul_config)
