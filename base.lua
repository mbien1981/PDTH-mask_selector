local module = DMod:new("custom_mask_selector", {
	name = "Custom Mask Selector",
	author = "_atom",
	version = "1.1",
	dependencies = {
		"_sdk",
		"[drop_in_menu]",
		"[character_n_mask_in_loadout]",
	},
})

module:hook_post_require("lib/setups/setup", "QuickMaskMenu")
module:hook_post_require("lib/managers/menumanager", "QuickMaskMenu")

return module
