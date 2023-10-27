rawset(_G, "QuickMaskMenuClass", class())
----* helper functions
--
function QuickMaskMenuClass:is_open()
	return self._active
end

function QuickMaskMenuClass:is_mouse_in_panel(panel)
	if not alive(panel) then
		return false
	end

	return panel:inside(self.menu_mouse_x, self.menu_mouse_y)
end

-- menu box/background design
function QuickMaskMenuClass:make_box(panel, with_grow)
	local panel_w, panel_h = panel:w(), panel:h()
	local grow = with_grow and "grow" or nil
	local alpha = 0.4
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w,
		h = panel_h,
		x = 0,
		y = 0,
		alpha = alpha,
		color = self._sdk:rgb255(10, 10, 10),
	})
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w - 2,
		h = panel_h - 2,
		x = 1,
		y = 1,
		alpha = alpha,
		color = self._sdk:rgb255(60, 60, 60),
	})
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w - 6,
		h = panel_h - 6,
		x = 3,
		y = 3,
		alpha = alpha,
		color = self._sdk:rgb255(10, 10, 10),
	})
end

----* animation helpers
--
-- mouse hover animations
function QuickMaskMenuClass:unhighlight_element()
	if not alive(self._current_hover) then
		return
	end

	local rect_item = self._current_hover
	rect_item:stop()
	rect_item:animate(function(o)
		self._sdk:animate_ui(5, function(p)
			o:set_alpha(math.lerp(o:alpha(), 0, p))
		end)
		o:set_alpha(0)
		o:parent():remove(o)
	end)

	self._current_hover = nil
end

function QuickMaskMenuClass:highlight_element(mouse_check_panel, size, color)
	size = size or {}

	self:unhighlight_element()
	if alive(self._current_hover) then
		return
	end

	local rect_item = mouse_check_panel:rect({
		x = size.x or 0,
		y = size.y or 0,
		w = mouse_check_panel:w() - (size.w or 0),
		h = mouse_check_panel:h() - (size.h or 0),
		layer = size.layer or 100,
		Color = color or Color(1, 1, 1),
		alpha = 0,
	})
	rect_item:stop()
	rect_item:animate(function(o)
		self._sdk:animate_ui(0.1, function(p)
			o:set_alpha(math.lerp(o:alpha(), 0.2, p))
		end)
	end)

	self._current_hover = rect_item
end

-- scroll animations
function QuickMaskMenuClass:do_over_scroll(panel, amount, target)
	panel:stop()
	panel:animate(function(o)
		self._sdk:animate_ui(0.1, function(p)
			o:set_y(math.lerp(o:y(), target + amount, p))
			self:check_feature_hover()
			self:check_bitmap_hover()
		end)

		panel:animate(function(o)
			self._sdk:animate_ui(0.1, function(p)
				o:set_y(math.lerp(o:y(), target, p))
				self:check_feature_hover()
				self:check_bitmap_hover()
			end)
		end)
	end)
end

function QuickMaskMenuClass:do_panel_scroll(panel, target, amount)
	if panel:parent():h() > panel:h() then
		return target
	end

	if (target + amount) > 0 then
		if target == 0 then
			self:do_over_scroll(panel, amount, target)
			return target
		end

		target = 0
		amount = 0
	end

	if ((target + panel:h()) + amount) < panel:parent():h() then
		if target + panel:h() == panel:parent():h() then
			self:do_over_scroll(panel, amount, target)
			return target
		end

		amount = panel:parent():h() - (target + panel:h())
	end

	target = target + amount
	panel:stop()
	panel:animate(function(o)
		self._sdk:animate_ui(0.1, function(p)
			o:set_y(math.lerp(o:y(), target, p))
			self:check_feature_hover()
			self:check_bitmap_hover()
		end)
	end)

	return target
end

----* menu setup
--
function QuickMaskMenuClass:init()
	self._ws = managers.gui_data:create_fullscreen_workspace()
	self._panel = self._ws:panel():panel({
		visible = false,
		alpha = 0,
		layer = 1151,
	})

	self.menu_mouse_id = managers.mouse_pointer:get_id()
	self._sound_source = SoundDevice:create_source("quick_mask_select")
	self.font = {
		path = "fonts/font_univers_530_bold",
		size = 20,
	}

	self._mask_sets = {}
	self._selected_mask = 0
	self._selected_character = 0
	self._sdk = _G._sdk

	self:setup_panels()
	self:build_feature_panel()
end

function QuickMaskMenuClass:setup_panels()
	self.main_panel = self._panel:panel()
	self.menu_panel = self.main_panel:panel()

	self.feature_panel = self.menu_panel:panel({
		layer = 5,
		w = self.main_panel:w() / 2,
		h = self.main_panel:h() / 2,
	})
	self.feature_panel:set_center(self.main_panel:center())

	self.item_panel = self.feature_panel:panel({
		layer = 20,
		x = 2,
		y = 2,
		h = self.feature_panel:h() - 4,
		w = self.feature_panel:w() - 4,
		alpha = 1,
	})
	self.item_container = self.item_panel:panel({
		y = 4,
		w = self.item_panel:w() - 4,
		h = self.item_panel:h() - 8,
	})

	self:make_box(self.feature_panel)
	self:make_box(self.item_panel)
end

----* open/close functions + animations
--
function QuickMaskMenuClass:open()
	if self._active then
		return
	end

	self._active = true

	self._sound_source:post_event("prompt_enter")

	self._panel:stop()
	self._panel:animate(function(o)
		o:show()
		o:set_alpha(0)

		self._sdk:animate_ui(1, function(p)
			o:set_alpha(math.lerp(o:alpha(), 1, p))
		end)

		o:set_alpha(1)
	end)

	managers.menu._input_enabled = false
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:disable()
	end

	if not self._controller then
		self._controller = managers.controller:create_controller("mask_select_controller", nil, false)
		self._controller:add_trigger("cancel", callback(self, self, "keyboard_cancel"))

		managers.mouse_pointer:use_mouse({
			mouse_move = callback(self, self, "mouse_move"),
			mouse_press = callback(self, self, "mouse_press"),
			id = self.menu_mouse_id,
			1,
		})
	end
	self._controller:enable()
end

function QuickMaskMenuClass:close()
	if not self:is_open() then
		return
	end

	self._active = false

	managers.gui_data:layout_fullscreen_workspace(managers.mouse_pointer._ws)
	managers.mouse_pointer:remove_mouse(self.menu_mouse_id)
	if self._controller then
		self._controller:destroy()
		self._controller = nil
	end

	managers.menu._input_enabled = true
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:enable()
	end

	self._sound_source:post_event("prompt_exit")

	self._panel:stop()
	self._panel:animate(function(o)
		self._sdk:animate_ui(1, function(p)
			o:set_alpha(math.lerp(o:alpha(), 0, p))
		end)
		o:set_alpha(0)
		o:hide()
	end)
end

----* feature panel
--
function QuickMaskMenuClass:create_mask_item(data)
	local item = data.item
	if not item.mask_set then
		return
	end

	local selected_character = self._selected_character or 4
	if self._active_items[item.id] then
		return
	end

	local item_panel = data.parent:panel({
		halign = "grow",
		h = data.height,
		layer = 1,
	})
	local icon_container = item_panel:panel()
	local panel_center = (item_panel:h() / 2)

	-- random mugshot icon
	local image, texture_rect = tweak_data.hud_icons:get_icon_data("mugshot_random")
	icon_container:bitmap({
		name = "random",
		texture = image,
		texture_rect = texture_rect,
		layer = 5,
		alpha = ((selected_character == 1) and 1) or 0.4,
		x = 4,
		y = 4,
		w = texture_rect[3],
		h = texture_rect[4],
	})

	local total_x = texture_rect[3] + 8
	local character_names = { "russian", "american", "german", "spanish" }
	for i, character in ipairs({ 3, 1, 2, 4 }) do
		local set_data = tweak_data.mask_sets[item.mask_set]
		local character_data = set_data and set_data[character]

		local icon = character_data and character_data.mask_icon or "mugshot_random"
		image, texture_rect = tweak_data.hud_icons:get_icon_data(icon)
		icon_container:bitmap({
			name = character_names[i],
			texture = image,
			texture_rect = texture_rect,
			layer = 1,
			alpha = (selected_character == (i + 1) and 1) or 0.4,
			x = total_x,
			y = 4,
			w = texture_rect[3],
			h = texture_rect[4],
		})

		total_x = total_x + texture_rect[3] + 4
	end

	-- resize and center the icon container
	icon_container:set_w(total_x)
	icon_container:set_center_x(item_panel:center_x())

	-- create mask set title
	local text = item_panel:text({
		text = managers.localization:text(item.text_id),
		font = "fonts/font_univers_latin_530_bold",
		font_size = 18,
		align = "left",
		halign = "grow",
		color = Color(0.7, 0.7, 0.7),
		layer = 2,
		x = 5,
	})
	self._sdk:update_text_rect(text)
	text:set_center_y(panel_center)

	-- register item
	self._active_items[item.id] = {
		panel = item_panel:parent(),
		icon_container = icon_container,
		target_y = item_panel:parent():y(),
		table_ptr = item,
		row = data.row,
	}
end

function QuickMaskMenuClass:build_feature_panel()
	self.item_container:clear()

	self._active_items = {}

	self.feature_scroll_panel = self.item_container:panel({
		halign = "grow",
		h = 2000,
	})

	local max_h = 0
	local column_panel = self.feature_scroll_panel:panel({
		halign = "grow",
		y = 0,
		x = 5,
		w = self.item_container:w() - 5,
		alpha = 1,
	})

	local total_h = 0
	for i, item in pairs(self._mask_sets) do
		item.id = item.id or ("item_" .. i)

		local add_amount = 56
		local y_offset = 2

		local button_panel = column_panel:panel({ halign = "grow" })
		button_panel:set_y(total_h + y_offset)
		button_panel:set_h(add_amount)
		self:make_box(button_panel)

		self:create_mask_item({
			parent = button_panel,
			height = add_amount,
			item = item,
			row = i,
		})

		total_h = total_h + add_amount + y_offset
	end

	if total_h > max_h then
		max_h = total_h
	end

	column_panel:set_h(total_h)

	self.feature_scroll_panel:set_h(max_h)
	self.feature_scroll_target = 0

	if self._selected_mask > 1 then
		self.feature_scroll_target =
			self:do_panel_scroll(self.feature_scroll_panel, self.feature_scroll_target, (-56 * self._selected_mask))
	end
end

----* callbacks
--
function QuickMaskMenuClass:select_mask_set(mask_set)
	if not self._mask_item_node then
		return
	end

	self._mask_item_node:set_value(mask_set)
	self._mask_item_node:trigger()

	self:close()
end

function QuickMaskMenuClass:select_character(character_name)
	if not self._character_item_node then
		return
	end

	self._character_item_node:set_value(character_name)
	self._character_item_node:trigger()

	self:close()
end

----* mouse input
--
function QuickMaskMenuClass:check_feature_hover()
	if not self:is_mouse_in_panel(self.feature_panel) then
		if self._current_feature_hover then
			self:unhighlight_element()
			self._current_feature_hover = nil
			return
		end
		return
	end

	if self._current_feature_hover then
		if not self:is_mouse_in_panel(self._current_feature_hover.panel) then
			self:unhighlight_element()
			self._current_feature_hover = nil
		end
		return
	end

	if not self._active_items or self._active_items and not next(self._active_items) then
		return
	end

	for _, item in pairs(self._active_items) do
		if self:is_mouse_in_panel(item.panel) then
			self._current_feature_hover = { panel = item.panel }
			self:highlight_element(item.panel, { layer = 1, x = 4, y = 4, w = 8, h = 8 })
			return
		end
	end
end

function QuickMaskMenuClass:check_bitmap_hover()
	for _, item in pairs(self._active_items) do
		if self:is_mouse_in_panel(item.panel) then
			if self:is_mouse_in_panel(item.icon_container) then
				for _, child in pairs(item.icon_container:children()) do
					local inside = self:is_mouse_in_panel(child)
					child:set_alpha(inside and 1 or 0.4)
				end
			else
				local bitmaps = { "random", "russian", "american", "german", "spanish" }
				local child = item.icon_container:child(bitmaps[self._selected_character])
				if alive(child) then
					child:set_alpha(1)
				end
			end
		else
			local bitmaps = { "random", "russian", "american", "german", "spanish" }
			for _, child in pairs(item.icon_container:children()) do
				child:set_alpha(child:name() == bitmaps[self._selected_character] and 1 or 0.4)
			end
		end
	end
end

function QuickMaskMenuClass:mouse_move(_, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y

	self:check_feature_hover()
	self:check_bitmap_hover()
end

function QuickMaskMenuClass:mouse_press(_, button, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y
	if button == Idstring("0") then
		if not self:is_mouse_in_panel(self.feature_panel) then
			self:close()
			return
		end

		for _, item in pairs(self._active_items) do
			if self:is_mouse_in_panel(item.panel) then
				self:select_mask_set(item.table_ptr.mask_set)

				for _, child in pairs(item.icon_container:children()) do
					if self:is_mouse_in_panel(child) then
						self:select_character(child:name())
					end
				end
				return
			end
		end
		return
	elseif button == Idstring("mouse wheel up") then
		if not self:is_mouse_in_panel(self.feature_panel) then
			return
		end

		if self:is_mouse_in_panel(self.feature_panel) then
			self.feature_scroll_target = self:do_panel_scroll(self.feature_scroll_panel, self.feature_scroll_target, 56)
			return
		end
	elseif button == Idstring("mouse wheel down") then
		if not self:is_mouse_in_panel(self.feature_panel) then
			return
		end

		if self:is_mouse_in_panel(self.feature_panel) then
			self.feature_scroll_target =
				self:do_panel_scroll(self.feature_scroll_panel, self.feature_scroll_target, -56)
			return
		end
	end
end

----* keyboard input
--
function QuickMaskMenuClass:keyboard_cancel()
	if not self:is_open() then
		return
	end

	self:close()
end

----* destroy menu
--
function QuickMaskMenuClass:destroy()
	if not alive(self._panel) then
		return
	end

	self._panel:parent():remove(self._panel)
	managers.gui_data:destroy_workspace(self._ws)
end

local module = ... or D:module("custom_mask_selector")
if RequiredScript == "lib/setups/setup" then
	local Setup = module:hook_class("Setup")
	module:post_hook(50, Setup, "init_managers", function()
		rawset(_G, "QuickMaskMenu", QuickMaskMenuClass:new())
	end)
end

if RequiredScript == "lib/managers/menumanager" then
	local MenuManager = module:hook_class("MenuManager")
	module:hook(MenuManager, "toggle_menu_state", function(self)
		if QuickMaskMenu and QuickMaskMenu:is_open() then
			return
		end

		module:call_orig(MenuManager, "toggle_menu_state", self)
	end, false)

	local MaskOptionInitiator = module:hook_class("MaskOptionInitiator")
	module:post_hook(MaskOptionInitiator, "modify_node", function(_, node)
		local character_item = node:item("choose_character")
		local choose_mask_item = node:item("choose_mask")
		if not character_item or not choose_mask_item then
			return
		end

		choose_mask_item:set_parameter("item_confirm_callback", function(item)
			if not rawget(_G, "QuickMaskMenu") then
				return
			end

			QuickMaskMenu._mask_item_node = choose_mask_item
			QuickMaskMenu._character_item_node = character_item

			local bl = {}
			-- add item for every mask available
			for i, mask_item in ipairs(item._all_options) do
				local params = mask_item:parameters()
				table.insert(bl, { text_id = params.text_id, mask_set = params.value })
			end

			table.insert(bl, 1, { text_id = "menu_character_random", mask_set = "random" })

			QuickMaskMenu._mask_sets = bl
			QuickMaskMenu._selected_character = character_item._current_index or 1
			QuickMaskMenu._selected_mask = choose_mask_item._current_index or 1
			QuickMaskMenu:build_feature_panel()
			QuickMaskMenu:open()
		end)
	end, false)
end
