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
	h_size = true,
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
