-- S1 overrides: can a template update change one setting of an entity while a hand-changed setting on the same entity
-- stays in place, without the entity being rebuilt or reset?
--
-- Method under test ("per-setting merge"): the world entity's settings are read as a blueprint entity table (W), the
-- old and new template tables are T1 and T2. For every field: W differs from T1 -> hand change, keep W; otherwise take
-- T2. Tables merge by key, arrays are atomic. If the result differs from W, a one-entity blueprint with the result is
-- pasted superforced over the entity through 0-things' cooperative API.
local util = require("util")
local S = {}
local COOP = "cooperative-blueprinting-v1"

local function surface() return game.surfaces.nauvis end

local function clear(area)
  local cx, cy = (area[1][1] + area[2][1]) / 2, (area[1][2] + area[2][2]) / 2
  local r = math.ceil(math.max(area[2][1] - area[1][1], area[2][2] - area[1][2]) / 64) + 1
  surface().request_to_generate_chunks({ cx, cy }, r)
  surface().force_generate_chunk_requests()
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } } end
  end
  surface().set_tiles(tiles)
  for _, e in pairs(surface().find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

-- Read one entity's settings as a blueprint entity table (with 0-things tags).
local function read(e)
  local inv = game.create_inventory(1)
  local st = inv[1]
  st.set_stack({ name = "blueprint" })
  local p = e.position
  local params = { surface = e.surface, force = "player", area = { { p.x - 0.1, p.y - 0.1 }, { p.x + 0.1, p.y + 0.1 } },
    include_station_names = true, include_modules = true }
  if remote.interfaces[COOP] and remote.interfaces[COOP].create_blueprint then
    remote.call(COOP, "create_blueprint", st, params)
  else
    st.create_blueprint(params)
  end
  local list = st.is_blueprint_setup() and st.get_blueprint_entities() or {}
  inv.destroy()
  for _, be in pairs(list) do
    if be.name == e.name then
      be.entity_number, be.position, be.wires = nil, nil, nil
      return be
    end
  end
end

-- Paste a settings table over the entity at its position, in place.
local function write(e, settings)
  local inv = game.create_inventory(1)
  local st = inv[1]
  st.set_stack({ name = "blueprint" })
  local be = util.table.deepcopy(settings)
  be.entity_number, be.position = 1, { x = 0, y = 0 }
  be.name, be.direction = e.name, e.direction
  st.set_blueprint_entities({ be })
  local params = { surface = e.surface, force = "player", position = e.position, build_mode = defines.build_mode.superforced,
    skip_fog_of_war = false }
  local built
  if remote.interfaces[COOP] and remote.interfaces[COOP].build_blueprint then
    built = remote.call(COOP, "build_blueprint", st, params)
  else
    built = st.build_blueprint(params)
  end
  inv.destroy()
  return built
end

local function is_array(t)
  if type(t) ~= "table" then return false end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

local function equal(a, b) return serpent.line(a, { sortkeys = true, comment = false }) == serpent.line(b, { sortkeys = true, comment = false }) end

-- Arrays whose elements carry an `index` (logistic sections, their filters, ...) merge per index.
local function by_index(t)
  if type(t) ~= "table" or not is_array(t) or #t == 0 then return nil end
  local out = {}
  for _, v in ipairs(t) do
    if type(v) ~= "table" or v.index == nil then return nil end
    out[v.index] = v
  end
  return out
end

-- Merge per key; returns merged table and the list of paths kept from the world (the overrides).
local function merge(t1, t2, w, path, kept)
  local function list_ok(t) return t == nil or (type(t) == "table" and is_array(t) and (#t == 0 or by_index(t) ~= nil)) end
  local i1, i2, iw = by_index(t1), by_index(t2), by_index(w)
  if list_ok(t1) and list_ok(t2) and list_ok(w) and (i1 or i2 or iw) then
    i1, i2, iw = i1 or {}, i2 or {}, iw or {}
    local keys, out = {}, {}
    for k in pairs(i1) do keys[#keys + 1] = k end
    for k in pairs(i2) do if not i1[k] then keys[#keys + 1] = k end end
    for k in pairs(iw) do if not i1[k] and not i2[k] then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = merge(i1[k], i2[k], iw[k], path .. "[" .. k .. "]", kept)
      if v ~= nil then out[#out + 1] = v end
    end
    return out
  end
  if type(t1) == "table" and type(t2) == "table" and type(w) == "table"
      and not is_array(t1) and not is_array(t2) and not is_array(w) then
    local out, keys = {}, {}
    for k in pairs(t1) do keys[k] = true end
    for k in pairs(t2) do keys[k] = true end
    for k in pairs(w) do keys[k] = true end
    for k in pairs(keys) do
      out[k] = merge(t1[k], t2[k], w[k], path .. "." .. tostring(k), kept)
    end
    return out
  end
  if not equal(w, t1) then
    kept[#kept + 1] = path
    return util.table.deepcopy(w)
  end
  return util.table.deepcopy(t2)
end

-- Cases: build the template entity with `setup`, capture T1; T2 = T1 changed by `template_change`; the player's change
-- is `hand`; `check` reads the outcome from the live entity.
local function signal(name) return { type = "item", name = name } end

local CASES = {
  {
    name = "inserter: hand filter, template changes circuit condition",
    entity = { name = "fast-inserter", direction = defines.direction.north },
    setup = function(e)
      e.use_filters = true
      e.set_filter(1, "iron-plate")
      local cb = e.get_or_create_control_behavior()
      cb.circuit_enable_disable = true
      cb.circuit_condition = { first_signal = signal("iron-plate"), comparator = ">", constant = 10 }
    end,
    hand = function(e) e.set_filter(1, "copper-plate") end,
    template_change = function(e) e.get_control_behavior().circuit_condition = { first_signal = signal("iron-plate"), comparator = ">", constant = 99 } end,
    check = function(e)
      local f = e.get_filter(1)
      local cb = e.get_control_behavior()
      return { filter = f and (type(f) == "table" and f.name or f),
               constant = cb and cb.circuit_condition and cb.circuit_condition.constant }
    end,
    want = { filter = "copper-plate", constant = 99 },
  },
  {
    name = "assembler: hand recipe, template changes nothing else; contents survive",
    entity = { name = "assembling-machine-2" },
    setup = function(e) e.set_recipe("iron-gear-wheel") end,
    hand = function(e) e.set_recipe("pipe"); e.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-plate", count = 50 }) end,
    template_change = function(e) e.set_recipe("copper-cable") end,
    check = function(e)
      local r = e.get_recipe()
      return { recipe = r and r.name, plates = e.get_inventory(defines.inventory.crafter_input).get_item_count("iron-plate") }
    end,
    want = { recipe = "pipe", plates = 50 },
  },
  {
    name = "constant combinator: hand edits a value, template adds a second signal",
    entity = { name = "constant-combinator", direction = defines.direction.north },
    setup = function(e)
      local s = e.get_control_behavior().get_section(1)
      s.set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal" }, min = 10 })
    end,
    hand = function(e) e.get_control_behavior().get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal" }, min = 40000 }) end,
    template_change = function(e) e.get_control_behavior().get_section(1).set_slot(2, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 5 }) end,
    check = function(e)
      local s = e.get_control_behavior().get_section(1)
      local a, b = s.get_slot(1), s.get_slot(2)
      return { iron = a and a.min, copper = b and b.min }
    end,
    want = { iron = 40000, copper = 5 },
  },
  {
    name = "requester chest: hand edits a request, template adds another; chest contents survive",
    entity = { name = "requester-chest" },
    setup = function(e)
      e.get_requester_point().get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal" }, min = 100 })
    end,
    hand = function(e)
      e.get_requester_point().get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal" }, min = 400 })
      e.insert({ name = "iron-plate", count = 77 })
    end,
    template_change = function(e) e.get_requester_point().get_section(1).set_slot(2, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 50 }) end,
    check = function(e)
      local s = e.get_requester_point().get_section(1)
      local a, b = s.get_slot(1), s.get_slot(2)
      return { iron = a and a.min, copper = b and b.min, stored = e.get_item_count("iron-plate") }
    end,
    want = { iron = 400, copper = 50, stored = 77 },
  },
  {
    name = "splitter: hand priority, template sets a filter",
    entity = { name = "splitter", direction = defines.direction.north },
    setup = function(e) end,
    hand = function(e) e.splitter_output_priority = "left" end,
    template_change = function(e) e.splitter_filter = { name = "iron-plate" }; e.splitter_output_priority = "right" end,
    check = function(e)
      local f = e.splitter_filter
      return { priority = e.splitter_output_priority, filter = f and f.name }
    end,
    want = { priority = "left", filter = "iron-plate" },
  },
}

local function build(spec, pos)
  local e = surface().create_entity({ name = spec.name, position = pos, direction = spec.direction, force = "player" })
  return e
end

function S.run()
  clear({ { 200, -10 }, { 260, 60 } })
  local results = {}
  for i, c in ipairs(CASES) do
    local r = { case = c.name }
    local ok, err = pcall(function()
      -- Template versions captured from configured scratch entities.
      local a = build(c.entity, { 205, i * 8 })
      c.setup(a)
      local t1 = read(a)
      c.template_change(a)
      local t2 = read(a)
      a.destroy()
      -- The world entity: placed from T1, then changed by hand.
      local e = build(c.entity, { 220, i * 8 })
      write(e, t1)
      c.hand(e)
      local unit = e.unit_number
      local w = read(e)
      local kept = {}
      local merged = merge(t1, t2, w, "", kept)
      local changed = not equal(merged, w)
      if changed then write(e, merged) end
      local live = surface().find_entities_filtered({ name = c.entity.name, position = { 220, i * 8 }, radius = 1 })[1]
      r.kept = kept
      r.pasted = changed
      r.same_entity = live ~= nil and live.unit_number == unit
      r.got = live and c.check(live)
      r.want = c.want
      r.pass = r.same_entity and equal(r.got, c.want)
      -- Baseline: what a plain paste of T2 does to the hand change.
      local b = build(c.entity, { 240, i * 8 })
      write(b, t1)
      c.hand(b)
      write(b, t2)
      r.naive_paste = c.check(b)
    end)
    if not ok then r.error = err end
    results[#results + 1] = r
  end
  return results
end

-- Cybersyn 2 combinator, in steps because 0-things registers a combinator one tick after it is built.
function S.cs2_step(step)
  storage.cs2 = storage.cs2 or {}
  local st = storage.cs2
  local function tags(e) local _, t = remote.call("things", "get", e) return t and t.tags end
  if step == 1 then
    clear({ { 330, -5 }, { 360, 25 } })
    local function make(x)
      local g = surface().create_entity({ name = "entity-ghost", inner_name = "cybersyn2-combinator", position = { x, 10 },
        direction = defines.direction.north, force = "player", raise_built = true })
      local _, e = g.revive({ raise_revive = true })
      return e
    end
    st.a, st.e, st.b = make(335), make(345), make(355)
    return "built"
  elseif step == 2 then
    -- Template v1 = default settings; v2 = reserved_slots 2. Hand change on e and b: provider only (pr = 1).
    st.t1 = read(st.a)
    remote.call("things", "set_tag", st.a, "reserved_slots", 2)
    return { t1_tags = st.t1.tags }
  elseif step == 3 then
    st.t2 = read(st.a)
    write(st.e, st.t1); write(st.b, st.t1)
    return { t2_tags = st.t2.tags }
  elseif step == 3.5 then
    remote.call("things", "set_tag", st.e, "pr", 1)
    remote.call("things", "set_tag", st.b, "pr", 1)
    return { hand = tags(st.e) }
  elseif step == 4 then
    st.unit = st.e.unit_number
    local w = read(st.e)
    local kept = {}
    local merged = merge(st.t1, st.t2, w, "", kept)
    write(st.e, merged)
    write(st.b, st.t2)
    return { kept = kept, merged_tags = merged.tags }
  elseif step == 5 then
    return { same_entity = st.e.valid and st.e.unit_number == st.unit, merged = tags(st.e), plain_paste = tags(st.b) }
  end
end

-- Does a pasted settings table land on an existing splitter at x?
function S.probe(x)
  clear({ { x - 2, 98 }, { x + 2, 102 } })
  local e = surface().create_entity({ name = "splitter", position = { x, 100 }, direction = defines.direction.north, force = "player" })
  local t = read(e)
  t.output_priority, t.filter = "right", { name = "iron-plate", quality = "normal", comparator = "=" }
  local built = write(e, t)
  return { priority = e.splitter_output_priority, filter = e.splitter_filter and e.splitter_filter.name, built = #(built or {}) }
end

-- Show what the blueprint tables look like for one entity type (to understand field granularity).
function S.sample(name)
  clear({ { 300, -5 }, { 310, 5 } })
  local e = surface().create_entity({ name = name, position = { 305, 0 }, force = "player" })
  return read(e)
end

return S
