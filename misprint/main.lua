----------------------------------------------
-- Misprint Deck
-- Standalone port of Cryptid's Misprint Deck.
-- All card values randomized between X0.1 and X10.
-- Hands blacklisted for Multiplayer safety.
----------------------------------------------

SMODS.Atlas({
	key = "back",
	path = "back.png",
	px = 71,
	py = 95,
})

----------------------------------------------
-- Core randomization
----------------------------------------------

-- Safe format: handles both plain numbers and Talisman big number objects
local function safe_fmt(value)
	if type(value) == "number" then
		return tonumber(string.format("%.2g", value))
	end
	return value
end

-- Log-uniform random distribution (from Cryptid)
local function log_random(seed, min, max)
	math.randomseed(seed)
	local lmin = math.log(min)
	local lmax = math.log(max)
	local poll = math.random() * (lmax - lmin) + lmin
	return math.exp(poll)
end

-- Fields that must NEVER be randomized
local value_blacklist = {
	-- Standard blacklist (from Cryptid's misprintize_value_blacklist)
	perish_tally = true,
	id = true,
	suit_nominal = true,
	base_nominal = true,
	face_nominal = true,
	qty = true,
	h_x_chips = true,
	d_size = true,
	colour = true,
	suit_nominal_original = true,
	times_played = true,
	extra_slots_used = true,
	card_limit = true,
	-- MP safety: fractional hands breaks Multiplayer
	hands = true,
	-- Index/selector fields (used as table keys, not scaling values)
	form = true,
}

-- Should this value be randomized?
local function can_randomize(key, value)
	if value_blacklist[key] then return false end
	if value == 0 then return false end
	-- x_mult and x_chips of 1 mean "no multiplier" — don't touch
	if (key == "x_mult" or key == "x_chips") and value == 1 then return false end
	return true
end

-- Randomize all numeric values on a card.
-- Stores multipliers on card.mis_factors so they survive evolution.
local function misprintize(card)
	if not card or not card.ability then return end

	local min = G.GAME.modifiers.misprint_min or 1
	local max = G.GAME.modifiers.misprint_max or 1
	if min == 1 and max == 1 then return end

	-- Generate and store multiplier factors (or reuse existing ones)
	if not card.mis_factors then
		card.mis_factors = {}
	end

	-- Randomize ability values
	for k, v in pairs(card.ability) do
		if type(v) == "number" and can_randomize(k, v) then
			if not card.mis_factors[k] then
				local seed = pseudoseed("misprint" .. G.GAME.round_resets.ante)
				card.mis_factors[k] = log_random(seed, min, max)
			end
			card.ability[k] = safe_fmt(v * card.mis_factors[k])
		elseif type(v) == "table" and k ~= "immutable" and k ~= "colour" then
			if not card.mis_factors[k] then
				card.mis_factors[k] = {}
			end
			for k2, v2 in pairs(v) do
				if type(v2) == "number" and can_randomize(k2, v2) then
					if not card.mis_factors[k][k2] then
						local seed = pseudoseed("misprint" .. G.GAME.round_resets.ante)
						card.mis_factors[k][k2] = log_random(seed, min, max)
					end
					card.ability[k][k2] = safe_fmt(v2 * card.mis_factors[k][k2])
				end
			end
		end
	end

	-- Randomize base values (chip values on playing cards)
	if card.base then
		if not card.mis_factors._base then
			card.mis_factors._base = {}
		end
		for k, v in pairs(card.base) do
			if type(v) == "number" and not value_blacklist[k] and v ~= 0 then
				if not card.mis_factors._base[k] then
					local seed = pseudoseed("misprint" .. G.GAME.round_resets.ante)
					card.mis_factors._base[k] = log_random(seed, min, max)
				end
				card.base[k] = safe_fmt(v * card.mis_factors._base[k])
			end
		end
	end
end

----------------------------------------------
-- Hook create_card to apply randomization
----------------------------------------------

local create_card_ref = create_card
function create_card(_type, area, ...)
	local card = create_card_ref(_type, area, ...)
	if G.GAME and G.GAME.modifiers and G.GAME.modifiers.misprint_min then
		misprintize(card)
	end
	return card
end

----------------------------------------------
-- Hook Card.set_ability to re-randomize after
-- ANY ability reset (evolution, form change, etc.)
-- Uses a deferred event so re-randomization runs
-- AFTER all post-set_ability processing (e.g.
-- poke_backend_evolve's value restoration).
----------------------------------------------

local set_ability_ref = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
	local saved_factors = self.mis_factors
	set_ability_ref(self, center, initial, delay_sprites)
	-- Only re-randomize cards that were previously randomized
	if saved_factors and G.GAME and G.GAME.modifiers and G.GAME.modifiers.misprint_min then
		-- Defer to next event tick so we run AFTER any
		-- post-set_ability value restoration (poke_backend_evolve etc.)
		local card_ref = self
		G.E_MANAGER:add_event(Event({
			blocking = false,
			func = function()
				card_ref.mis_factors = saved_factors
				misprintize(card_ref)
				return true
			end,
		}))
	end
end

----------------------------------------------
-- Fix hardcoded voucher effects.
-- Most vouchers already use center_table.extra
-- (which we randomize via create_card hook).
-- A few hardcode their values — we correct them.
----------------------------------------------

local apply_to_run_ref = Card.apply_to_run
function Card:apply_to_run(center)
	-- Capture the randomized extra before original runs
	local extra = (center and center.config and center.config.extra)
		or (self and self.ability and self.ability.extra)
	local name = (center and center.name)
		or (self and self.ability and self.ability.name)

	apply_to_run_ref(self, center)

	if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.misprint_min) then return end
	if type(extra) ~= "number" then return end

	local rounded = math.floor(extra)
	local diff = rounded - 1
	if diff == 0 then return end

	-- Paint Brush / Palette: vanilla hardcodes change_size(1)
	if name == "Paint Brush" or name == "Palette" then
		G.hand:change_size(diff)
	end
	-- Overstock / Overstock Plus: vanilla hardcodes change_shop_size(1)
	if name == "Overstock" or name == "Overstock Plus" then
		change_shop_size(diff)
	end
	-- Antimatter: vanilla hardcodes joker card_limit + 1
	if name == "Antimatter" then
		G.E_MANAGER:add_event(Event({func = function()
			if G.jokers then
				G.jokers.config.card_limit = G.jokers.config.card_limit + diff
			end
			return true end}))
	end
	-- Crystal Ball: vanilla hardcodes consumable card_limit + 1
	if name == "Crystal Ball" then
		G.E_MANAGER:add_event(Event({func = function()
			G.consumeables.config.card_limit = G.consumeables.config.card_limit + diff
			return true end}))
	end
end

----------------------------------------------
-- Hook tooltip generation for vouchers with
-- hardcoded descriptions (no #1# in vanilla).
-- Sets center.vars so generate_card_ui uses
-- the card's randomized ability.extra value.
----------------------------------------------

local gen_uibox_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(vars_only)
	if self.ability and self.ability.set == "Voucher"
		and G.GAME and G.GAME.modifiers and G.GAME.modifiers.misprint_min then
		local name = self.ability.name
		if name == "Overstock" or name == "Overstock Plus"
			or name == "Crystal Ball"
			or name == "Antimatter" then
			self.config.center.vars = { self.ability.extra }
		end
	end
	local result = gen_uibox_ref(self, vars_only)
	-- Clean up to avoid stale vars persisting on center
	if self.ability and self.ability.set == "Voucher" then
		self.config.center.vars = nil
	end
	return result
end

----------------------------------------------
-- Deck registration
----------------------------------------------

SMODS.Back({
	key = "misprint",
	config = { misprint_min = 0.1, misprint_max = 10 },
	atlas = "back",
	pos = { x = 0, y = 0 },

	apply = function(self)
		G.GAME.modifiers.misprint_min = (G.GAME.modifiers.misprint_min or 1) * self.config.misprint_min
		G.GAME.modifiers.misprint_max = (G.GAME.modifiers.misprint_max or 1) * self.config.misprint_max

		-- Fix voucher configs so extra = the hardcoded effect value (1).
		-- Without this, Overstock has no extra, and Crystal Ball/Antimatter
		-- have extra values unrelated to their +1 slot effects.
		local voucher_fixes = {
			"v_overstock_norm", "v_overstock_plus",
			"v_crystal_ball", "v_antimatter",
		}
		for _, key in ipairs(voucher_fixes) do
			if G.P_CENTERS[key] then
				G.P_CENTERS[key].config.extra = 1
			end
		end

		-- Override localization text for vouchers with hardcoded "+1"
		-- so they show the randomized value via #1# placeholder
		local vloc = G.localization.descriptions.Voucher
		if vloc then
			if vloc.v_overstock_norm then
				vloc.v_overstock_norm.text = { "{C:attention}+#1#{} card slot", "available in shop" }
			end
			if vloc.v_overstock_plus then
				vloc.v_overstock_plus.text = { "{C:attention}+#1#{} card slot", "available in shop" }
			end
			if vloc.v_antimatter then
				vloc.v_antimatter.text = { "{C:dark_edition}+#1#{} Joker Slot" }
			end
			if vloc.v_crystal_ball then
				vloc.v_crystal_ball.text = { "{C:attention}+#1#{} consumable slot" }
			end
		end

		-- DEBUG: start with money and voucher tags for testing
		G.E_MANAGER:add_event(Event({
			func = function()
				ease_dollars(4000)
				for i = 1, 40 do
					add_tag(Tag("tag_voucher"))
				end
				return true
			end
		}))

		-- Randomize poker hand base values
		-- (Cryptid does this via Lovely patch on game.lua)
		local min = G.GAME.modifiers.misprint_min
		local max = G.GAME.modifiers.misprint_max
		for _, v in pairs(G.GAME.hands) do
			local seed = pseudoseed("misprint")
			if type(v.chips) == "number" then
				v.chips = safe_fmt(v.chips * log_random(seed, min, max))
			end
			if type(v.mult) == "number" then
				v.mult = safe_fmt(v.mult * log_random(seed, min, max))
			end
			if type(v.l_chips) == "number" then
				v.l_chips = safe_fmt(v.l_chips * log_random(seed, min, max))
			end
			if type(v.l_mult) == "number" then
				v.l_mult = safe_fmt(v.l_mult * log_random(seed, min, max))
			end
			v.s_chips = v.chips
			v.s_mult = v.mult
		end
	end,
})
