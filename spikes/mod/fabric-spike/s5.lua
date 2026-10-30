-- S5 piece identity in an edit cell: after a player's edit, can Commit tell which entity is which template piece
-- (same, moved, replaced, copied, deleted, new)? Each scenario builds pieces, applies an edit with known ground truth,
-- and grades approaches against that truth. Grades: "ok" (right without asking), "ask" (Commit is blocked until the
-- player answers), "WRONG" (silently wrong). A regression run must have no WRONG for the two prototypes:
--   P1 things  Fabric's own map (piece -> unit, Thing) as the truth; 0-things tags carry the piece id through
--              blueprints, overwritten tags are repaired at once; Fabric's move and replace tools log their changes
--   P2 tools   Fabric's own map and Fabric's move and replace tools only; nothing travels through blueprints
-- Both end in the same Commit rule: a piece that is gone while an unidentified entity that could be it is in the cell
-- (same name, or a replacement on its spot) blocks Commit. Reference approaches from the first round (not prototypes):
--   guess   no ids: match by name, settings and position
--   carrier ids in the entity's own settings: combinator description, or a disabled request section in chests
local util = require("util")
local S = {}
local COOP = "cooperative-blueprinting-v1"
local TAG = "fp"

local function surface() return game.surfaces.nauvis end
local function key(p) return string.format("%.1f,%.1f", p.x or p[1], p.y or p[2]) end

local function clear(area)
  local s = surface()
  s.request_to_generate_chunks({ (area[1][1] + area[2][1]) / 2, (area[1][2] + area[2][2]) / 2 }, 2)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } } end
  end
  s.set_tiles(tiles)
  for _, e in pairs(s.find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" then e.destroy({ raise_destroy = true }) end
  end
end

local function thing_of(e)
  local _, id = remote.call("things", "get_thing_id", e)
  if not id then return nil, nil end
  local _, sum = remote.call("things", "get", id)
  return id, sum and sum.tags and sum.tags[TAG]
end

local CARRIER_ITEM = "iron-plate"
local CARRIER_BASE = 900000

-- The id an entity carries in its own settings, if any.
local function carrier_of(e)
  local ok, d = pcall(function() return e.combinator_description end)
  if ok and d and d:match("^fabric:") then return tonumber(d:sub(8)) end
  local okp, point = pcall(e.get_requester_point)
  if okp and point then
    for _, sec in pairs(point.sections) do
      if not sec.active then
        local f = sec.filters[1]
        if f and f.value and f.value.name == CARRIER_ITEM and f.min and f.min >= CARRIER_BASE then
          return f.min - CARRIER_BASE
        end
      end
    end
  end
end

local function set_carrier(e, pid)
  local ok = pcall(function() e.combinator_description = "fabric:" .. pid end)
  if ok then return "description" end
  local okp, point = pcall(e.get_requester_point)
  if okp and point then
    local sec = point.add_section()
    sec.set_slot(1, { value = { type = "item", name = CARRIER_ITEM, quality = "normal" }, min = CARRIER_BASE + pid })
    sec.active = false
    return "request"
  end
end

-- Settings as a blueprint table, without position and without the ids under test.
local function settings(e)
  local inv = game.create_inventory(1)
  local st = inv[1]
  st.set_stack({ name = "blueprint" })
  local p = e.position
  remote.call(COOP, "create_blueprint", st, { surface = e.surface, force = "player",
    area = { { p.x - 0.1, p.y - 0.1 }, { p.x + 0.1, p.y + 0.1 } } })
  local list = st.is_blueprint_setup() and st.get_blueprint_entities() or {}
  inv.destroy()
  for _, be in pairs(list) do
    if be.name == e.name then
      be.entity_number, be.position, be.tags, be.player_description, be.wires = nil, nil, nil, nil, nil
      if be.request_filters and be.request_filters.sections then
        local keep = {}
        for _, sec in pairs(be.request_filters.sections) do
          if sec.active ~= false then sec.index = nil; keep[#keep + 1] = sec end
        end
        be.request_filters.sections = keep
      end
      return serpent.line(be, { sortkeys = true, comment = false })
    end
  end
  return ""
end

local function entities(area)
  local list = {}
  for _, e in pairs(surface().find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" and e.type ~= "entity-ghost" then list[#list + 1] = e end
  end
  return list
end

-- Blueprint of an area (Things tags included), kept in a script inventory.
local function copy(area, only)
  local inv = game.create_inventory(1)
  local st = inv[1]
  st.set_stack({ name = "blueprint" })
  remote.call(COOP, "create_blueprint", st, { surface = surface(), force = "player", area = area })
  if only then
    local list = {}
    for _, be in pairs(st.get_blueprint_entities()) do
      if only(be) then be.entity_number = #list + 1; list[#list + 1] = be end
    end
    st.set_blueprint_entities(list)
  end
  return inv
end

local function paste(inv, pos)
  remote.call(COOP, "build_blueprint", inv[1], { surface = surface(), force = "player", position = pos,
    build_mode = defines.build_mode.forced })
end

local function revive_all(area)
  for _, g in pairs(surface().find_entities_filtered({ area = area, type = "entity-ghost" })) do
    g.revive({ raise_revive = true })
  end
end

local function mk(name, x, y, pid, area_base)
  local e = surface().create_entity({ name = name, position = { area_base[1] + x, area_base[2] + y }, force = "player",
    raise_built = true })
  return e
end

-- Scenario state lives in storage.s5[name].
local function st(name) storage.s5 = storage.s5 or {}; storage.s5[name] = storage.s5[name] or {}; return storage.s5[name] end

-- Register the pieces the template had before the edit.
-- Piece ids are unique in a real cell; scenarios share one map, so the id a tag carries is scenario * 10000 + piece.
local function global_id(s, pid) return s.i * 10000 + pid end
local function local_id(s, gid) if gid and math.floor(gid / 10000) == s.i then return gid % 10000 end end

local function register(name, list)
  local s = st(name)
  s.pieces, s.log = {}, {}
  for _, it in ipairs(list) do
    local e, pid = it[1], it[2]
    local gid = global_id(s, pid)
    local err, sum = remote.call("things", "create_thing", { entity = e, tags = { [TAG] = gid } })
    local thing = sum and sum.id
    if not thing then
      -- Already a Thing (Cybersyn 2 makes its combinator one): add our tag next to its own.
      local _, id = remote.call("things", "get_thing_id", e)
      if id then remote.call("things", "set_tag", id, TAG, gid); thing, err = id, nil end
    end
    if thing then
      storage.s5_map = storage.s5_map or {}; storage.s5_map[thing] = gid
      storage.s5_thing_of = storage.s5_thing_of or {}; storage.s5_thing_of[gid] = thing
    end
    s.pieces[pid] = { unit = e.unit_number, name = e.name, pos = key(e.position), hash = settings(e),
      thing = thing, carrier = set_carrier(e, pid), thing_err = err and err.code }
  end
end

local function find_unit(area, unit)
  for _, e in pairs(entities(area)) do if e.unit_number == unit then return e end end
end

-- Approaches. Each returns verdict[poskey] = pid | "new" | "ask", and deleted[pid] = true | "ask".
local function by_guess(s, area)
  local verdict, used, deleted = {}, {}, {}
  local ents = entities(area)
  local info = {}
  for _, e in pairs(ents) do info[e] = { k = key(e.position), name = e.name, hash = settings(e) } end
  -- Same spot and same name: taken as the same piece (a hand rebuild there looks identical).
  for pid, p in pairs(s.pieces) do
    for _, e in pairs(ents) do
      if not used[e] and info[e].k == p.pos and info[e].name == p.name then verdict[info[e].k] = pid; used[e] = pid end
    end
  end
  local matched = {}
  for _, pid in pairs(used) do matched[pid] = true end
  for pid, p in pairs(s.pieces) do
    if not matched[pid] then
      local cands = {}
      for _, e in pairs(ents) do
        if not used[e] and info[e].name == p.name and info[e].hash == p.hash then cands[#cands + 1] = e end
      end
      if #cands == 0 then deleted[pid] = true
      elseif #cands == 1 then
        -- Unique only if no other unmatched piece could claim it as well.
        local rivals = 0
        for pid2, p2 in pairs(s.pieces) do
          if pid2 ~= pid and not matched[pid2] and p2.name == p.name and p2.hash == p.hash then rivals = rivals + 1 end
        end
        if rivals == 0 then verdict[info[cands[1]].k] = pid; used[cands[1]] = pid
        else for _, e in pairs(cands) do verdict[info[e].k] = "ask" end; deleted[pid] = "ask" end
      else
        for _, e in pairs(cands) do verdict[info[e].k] = "ask"; used[e] = "ask" end
        deleted[pid] = "ask"
      end
    end
  end
  for _, e in pairs(ents) do if not used[e] then verdict[info[e].k] = "new" end end
  return verdict, deleted
end

-- Shared logic for id-carrying approaches: identity first (unit or Thing id), then carried ids.
local function by_ids(s, area, ident_of, carried_of)
  local verdict, deleted, seen = {}, {}, {}
  local ents = entities(area)
  local carriers = {}
  for _, e in pairs(ents) do
    local pid = ident_of(e)
    if pid then verdict[key(e.position)] = pid; seen[pid] = true end
  end
  for _, e in pairs(ents) do
    local k = key(e.position)
    if not verdict[k] then
      local c = carried_of(e)
      if c and s.pieces[c] then carriers[c] = carriers[c] or {}; table.insert(carriers[c], k)
      else verdict[k] = "new" end
    end
  end
  for pid, ks in pairs(carriers) do
    if seen[pid] then for _, k in pairs(ks) do verdict[k] = "new" end      -- original still there: these are copies
    elseif #ks == 1 then verdict[ks[1]] = pid; seen[pid] = true            -- the only carrier: moved
    else for _, k in pairs(ks) do verdict[k] = "ask" end; seen[pid] = "ask" end
  end
  for pid in pairs(s.pieces) do
    if not seen[pid] then deleted[pid] = true elseif seen[pid] == "ask" then deleted[pid] = "ask" end
  end
  return verdict, deleted
end

local function unit_ident(s)
  local by_unit = {}
  for pid, p in pairs(s.pieces) do by_unit[p.unit] = pid end
  for old, new in pairs(s.log or {}) do if by_unit[old] then by_unit[new] = by_unit[old] end end
  return function(e) return by_unit[e.unit_number] end
end

local APPROACHES = {
  guess = by_guess,
  carrier = function(s, area)
    -- Entities that cannot carry an id fall back to guessing.
    local v, d = by_ids(s, area, unit_ident(s), carrier_of)
    local gv, gd = by_guess(s, area)
    for pid, p in pairs(s.pieces) do
      if not p.carrier and d[pid] then
        -- Lost by unit_number and nothing carried: only a guess is left.
        for k, g in pairs(gv) do if g == pid or (g == "ask" and v[k] == "new") then v[k] = g end end
        d[pid] = gd[pid]
      end
    end
    return v, d
  end,
}

-- The Commit rule both prototypes share: never call a piece deleted while an unidentified entity in the cell could be
-- it; block instead.
local function block_unclear(s, ar, v, d)
  local at_key = {}
  for _, e in pairs(entities(ar)) do at_key[key(e.position)] = e end
  local function group(name) local pr = prototypes.entity[name]; return pr and pr.fast_replaceable_group end
  for pid, gone in pairs(d) do
    if gone == true then
      local p = s.pieces[pid]
      for k, val in pairs(v) do
        local e = at_key[k]
        if (val == "new" or val == "ask") and e and (e.name == p.name or (k == p.pos and group(e.name) and group(e.name) == group(p.name))) then
          v[k] = "ask"; d[pid] = "ask"
        end
      end
    end
  end
  return v, d
end

APPROACHES.P1_things = function(s, ar)
  local by_thing = {}
  for pid, p in pairs(s.pieces) do if p.thing then by_thing[p.thing] = pid end end
  local by_unit = unit_ident(s)
  local v, d = by_ids(s, ar, function(e)
    local id = thing_of(e)
    return (id and by_thing[id]) or by_unit(e)
  end, function(e) local _, tag = thing_of(e); return local_id(s, tag) end)
  return block_unclear(s, ar, v, d)
end

APPROACHES.P2_tools = function(s, ar)
  local v, d = by_ids(s, ar, unit_ident(s), function() end)
  return block_unclear(s, ar, v, d)
end

local function grade(truth, verdict, deleted)
  verdict, deleted = verdict or {}, deleted or {}
  local out = {}
  local worst = "ok"
  local function note(g, what)
    out[#out + 1] = g .. " " .. what
    if g == "WRONG" then worst = "WRONG" elseif g == "ask" and worst == "ok" then worst = "ask" end
  end
  for k, want in pairs(truth.at) do
    local got = verdict[k]
    if got == want then note("ok", k .. "=" .. tostring(want))
    elseif got == "ask" then note("ask", k .. " (truth " .. tostring(want) .. ")")
    else note("WRONG", k .. " got " .. tostring(got) .. " truth " .. tostring(want)) end
  end
  for pid, d in pairs(deleted) do
    local want = truth.deleted[pid]
    if d == "ask" then note("ask", "deleted? p" .. pid)
    elseif not want then note("WRONG", "p" .. pid .. " called deleted") end
  end
  for pid in pairs(truth.deleted) do
    if not deleted[pid] then note("WRONG", "p" .. pid .. " deletion missed") end
  end
  if truth.intent_unclear and worst == "ok" then note("ok", "(intent unclear: an answer without asking is a policy)") end
  return worst, out
end

-- Scenarios: setup builds and registers pieces; steps run one per call (Things applies tags a tick after a paste).
local SC = {}
local function base(i) return { 1000 + i * 40, 1000 + (i == 13 and 200 or 0) } end
local function area(i) local b = base(i); return { { b[1], b[2] }, { b[1] + 30, b[2] + 20 } } end
local function at(i, x, y) local b = base(i); return key({ b[1] + x, b[2] + y }) end

-- 1. Two identical combinators swapped with the mod's move tool (teleport).
SC.swap_tool = { i = 1,
  setup = function(n, b)
    local a = mk("constant-combinator", 2.5, 2.5, 1, b); local c = mk("constant-combinator", 6.5, 2.5, 2, b)
    register(n, { { a, 1 }, { c, 2 } })
  end,
  steps = { function(n, b, ar)
    local s = st(n)
    local a, c = find_unit(ar, s.pieces[1].unit), find_unit(ar, s.pieces[2].unit)
    a.teleport({ b[1] + 2.5, b[2] + 10.5 }, nil, true); c.teleport({ b[1] + 2.5, b[2] + 2.5 }, nil, true)
    a.teleport({ b[1] + 6.5, b[2] + 2.5 }, nil, true)
  end },
  truth = function(i) return { at = { [at(i, 6.5, 2.5)] = 1, [at(i, 2.5, 2.5)] = 2 }, deleted = {} } end }

-- 2. The same swap by hand with cut and paste.
SC.swap_cut = { i = 2,
  setup = function(n, b)
    local a = mk("constant-combinator", 2.5, 2.5, 1, b); local c = mk("constant-combinator", 6.5, 2.5, 2, b)
    register(n, { { a, 1 }, { c, 2 } })
  end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      s.bp1 = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }); find_unit(ar, s.pieces[1].unit).destroy({ raise_destroy = true })
      s.bp2 = copy({ { b[1] + 6, b[2] + 2 }, { b[1] + 7, b[2] + 3 } }); find_unit(ar, s.pieces[2].unit).destroy({ raise_destroy = true })
    end,
    function(n, b, ar) local s = st(n); paste(s.bp1, { b[1] + 6.5, b[2] + 2.5 }); paste(s.bp2, { b[1] + 2.5, b[2] + 2.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 6.5, 2.5)] = 1, [at(i, 2.5, 2.5)] = 2 }, deleted = {} } end }

-- 3. A requester chest moved by cut and paste, then its request changed.
SC.move_edit_cut = { i = 3,
  setup = function(n, b)
    local r = mk("requester-chest", 2.5, 2.5, 3, b)
    r.get_requester_point().get_section(1).set_slot(1, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 100 })
    register(n, { { r, 3 } })
  end,
  steps = {
    function(n, b, ar) local s = st(n); s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }); find_unit(ar, s.pieces[3].unit).destroy({ raise_destroy = true }) end,
    function(n, b) paste(st(n).bp, { b[1] + 10.5, b[2] + 5.5 }) end,
    function(n, b, ar) revive_all(ar) end,
    function(n, b, ar)
      for _, e in pairs(entities(ar)) do e.get_requester_point().get_section(1).set_slot(1, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 400 }) end
    end,
  },
  truth = function(i) return { at = { [at(i, 10.5, 5.5)] = 3 }, deleted = {} } end }

-- 4. An inserter moved with the move tool, then its filter changed.
SC.move_edit_tool = { i = 4,
  setup = function(n, b) register(n, { { mk("fast-inserter", 2.5, 2.5, 4, b), 4 } }) end,
  steps = { function(n, b, ar)
    local e = find_unit(ar, st(n).pieces[4].unit)
    e.teleport({ b[1] + 9.5, b[2] + 4.5 }, nil, true)
    e.use_filters = true; e.set_filter(1, { name = "copper-plate", quality = "normal" })
  end },
  truth = function(i) return { at = { [at(i, 9.5, 4.5)] = 4 }, deleted = {} } end }

-- 5. A piece deleted and an identical entity built by hand elsewhere (no copy): truly deleted plus new.
SC.delete_add = { i = 5,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, 5, b), 5 } }) end,
  steps = { function(n, b, ar)
    find_unit(ar, st(n).pieces[5].unit).destroy({ raise_destroy = true })
    mk("constant-combinator", 12.5, 6.5, nil, b)
  end },
  truth = function(i) return { at = { [at(i, 12.5, 6.5)] = "new" }, deleted = { [5] = true }, intent_unclear = true } end }

-- 6. Copy and paste twice: the original stays, two new pieces.
SC.copy_twice = { i = 6,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, 6, b), 6 } }) end,
  steps = {
    function(n, b) local s = st(n); s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }) end,
    function(n, b) local s = st(n); paste(s.bp, { b[1] + 8.5, b[2] + 2.5 }); paste(s.bp, { b[1] + 12.5, b[2] + 2.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 2.5, 2.5)] = 6, [at(i, 8.5, 2.5)] = "new", [at(i, 12.5, 2.5)] = "new" }, deleted = {} } end }

-- 7. Cut and paste twice: one of the two is the piece, which one is the player's intent.
SC.cut_twice = { i = 7,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, 7, b), 7 } }) end,
  steps = {
    function(n, b, ar) local s = st(n); s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }); find_unit(ar, s.pieces[7].unit).destroy({ raise_destroy = true }) end,
    function(n, b) local s = st(n); paste(s.bp, { b[1] + 8.5, b[2] + 2.5 }); paste(s.bp, { b[1] + 12.5, b[2] + 2.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 8.5, 2.5)] = "ask", [at(i, 12.5, 2.5)] = "ask" }, deleted = { }, intent_unclear = true } end }

-- 8. Three pieces cut, only two pasted back elsewhere.
SC.partial_paste = { i = 8,
  setup = function(n, b)
    register(n, { { mk("constant-combinator", 2.5, 2.5, 81, b), 81 }, { mk("inserter", 3.5, 2.5, 82, b), 82 },
      { mk("requester-chest", 4.5, 2.5, 83, b), 83 } })
  end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 5, b[2] + 3 } }, function(be) return be.name ~= "requester-chest" end)
      for _, pid in pairs({ 81, 82, 83 }) do find_unit(ar, s.pieces[pid].unit).destroy({ raise_destroy = true }) end
    end,
    function(n, b) paste(st(n).bp, { b[1] + 10, b[2] + 8 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i, ar)
    local t = { at = {}, deleted = { [83] = true } }
    for _, e in pairs(entities(ar)) do t.at[key(e.position)] = ({ ["constant-combinator"] = 81, inserter = 82 })[e.name] end
    return t
  end }

-- 9. Same-spot replacement by the game's fast replace (upgrade inserter -> fast, requester -> buffer).
SC.replace_same_spot = { i = 9,
  setup = function(n, b) register(n, { { mk("inserter", 2.5, 2.5, 91, b), 91 }, { mk("requester-chest", 4.5, 2.5, 92, b), 92 } }) end,
  steps = { function(n, b)
    surface().create_entity({ name = "fast-inserter", position = { b[1] + 2.5, b[2] + 2.5 }, force = "player", fast_replace = true, spill = false, raise_built = true })
    surface().create_entity({ name = "buffer-chest", position = { b[1] + 4.5, b[2] + 2.5 }, force = "player", fast_replace = true, spill = false, raise_built = true })
  end },
  truth = function(i) return { at = { [at(i, 2.5, 2.5)] = 91, [at(i, 4.5, 2.5)] = 92 }, deleted = {}, intent_unclear = true } end }

-- 10. Same-spot replacement through the mod's replace tool (it logs old unit -> new unit).
SC.replace_tool = { i = 10,
  setup = function(n, b) register(n, { { mk("inserter", 2.5, 2.5, 101, b), 101 }, { mk("requester-chest", 4.5, 2.5, 102, b), 102 } }) end,
  steps = { function(n, b, ar)
    local s = st(n)
    for pid, nm in pairs({ [101] = "fast-inserter", [102] = "buffer-chest" }) do
      local old = find_unit(ar, s.pieces[pid].unit)
      local u, pos = old.unit_number, old.position
      local new = surface().create_entity({ name = nm, position = pos, force = "player", fast_replace = true, spill = false, raise_built = true })
      s.log[u] = new.unit_number
    end
  end },
  truth = function(i) return { at = { [at(i, 2.5, 2.5)] = 101, [at(i, 4.5, 2.5)] = 102 }, deleted = {} } end }

-- 11. Deleted and rebuilt fresh on the same spot by hand: a new piece by intent, or the old one?
SC.rebuild_same_spot = { i = 11,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, 11, b), 11 } }) end,
  steps = { function(n, b, ar)
    find_unit(ar, st(n).pieces[11].unit).destroy({ raise_destroy = true })
    mk("constant-combinator", 2.5, 2.5, nil, b)
  end },
  truth = function(i) return { at = { [at(i, 2.5, 2.5)] = "new" }, deleted = { [11] = true }, intent_unclear = true } end }

-- 12. A player edits the visible id: one combinator's description changed to another piece's id.
SC.edited_id = { i = 12,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, 121, b), 121 }, { mk("constant-combinator", 6.5, 2.5, 122, b), 122 } }) end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      find_unit(ar, s.pieces[121].unit).combinator_description = "fabric:122"
      s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } })
      find_unit(ar, s.pieces[121].unit).destroy({ raise_destroy = true })
    end,
    function(n, b) paste(st(n).bp, { b[1] + 10.5, b[2] + 2.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 10.5, 2.5)] = 121, [at(i, 6.5, 2.5)] = 122 }, deleted = {} } end }

-- 13. Move tool on entity types that may refuse teleport (belts, assembler with contents, pipes, poles).
SC.teleport_types = { i = 13,
  setup = function(n, b)
    clear({ { b[1], b[2] }, { b[1] + 80, b[2] + 20 } })
    local list = {}
    for j, nm in ipairs({ "transport-belt", "underground-belt", "splitter", "pipe", "pipe-to-ground", "pump",
      "medium-electric-pole", "assembling-machine-2", "inserter", "constant-combinator", "decider-combinator",
      "requester-chest", "cybersyn2-combinator", "straight-rail", "train-stop", "rail-signal", "small-lamp" }) do
      local e = surface().create_entity({ name = nm, position = { b[1] + 2 + (j - 1) * 4, b[2] + 4 }, force = "player",
        raise_built = true })
      if not e then storage.s5_unplaced = (storage.s5_unplaced or "") .. nm .. " "; goto continue end
      if nm == "assembling-machine-2" then e.set_recipe("iron-gear-wheel"); e.insert({ name = "iron-plate", count = 20 }) end
      list[#list + 1] = { e, 130 + j }
      ::continue::
    end
    register(n, list)
  end,
  steps = { function(n, b, ar)
    local s = st(n)
    s.tp = {}
    for pid, p in pairs(s.pieces) do
      local e = find_unit({ { b[1], b[2] }, { b[1] + 80, b[2] + 20 } }, p.unit)
      local name = e.name
      local ok = e.teleport({ e.position.x, e.position.y + 8 }, nil, true)
      s.tp[name] = { ok = ok, unit_kept = e.valid and e.unit_number == p.unit,
        contents = name == "assembling-machine-2" and e.get_item_count("iron-plate") or nil }
    end
  end },
  truth = nil }

-- 14. Move tool on entities that refuse teleport: the tool rebuilds them (copy, remove, paste) and logs the mapping.
SC.move_rebuild_tool = { i = 14,
  setup = function(n, b)
    local belt = surface().create_entity({ name = "transport-belt", position = { b[1] + 2.5, b[2] + 2.5 }, force = "player", direction = defines.direction.east, raise_built = true })
    local spl = surface().create_entity({ name = "splitter", position = { b[1] + 5.5, b[2] + 3 }, force = "player", direction = defines.direction.east, raise_built = true })
    spl.splitter_output_priority = "left"
    register(n, { { belt, 141 }, { spl, 142 } })
  end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      s.bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 6, b[2] + 4 } })
      s.old = {}
      for pid, p in pairs(s.pieces) do
        local e = find_unit(ar, p.unit)
        s.old[pid] = { unit = p.unit, dest = key({ e.position.x + 10, e.position.y + 6 }) }
        e.destroy({ raise_destroy = true })
      end
    end,
    function(n, b) paste(st(n).bp, { b[1] + 14, b[2] + 9 }) end,
    function(n, b, ar)
      revive_all(ar)
      local s = st(n)
      for _, e in pairs(entities(ar)) do
        for pid, o in pairs(s.old) do if key(e.position) == o.dest then s.log[o.unit] = e.unit_number end end
      end
    end,
  },
  truth = function(i) return { at = { [at(i, 12.5, 8.5)] = 141, [at(i, 15.5, 9)] = 142 }, deleted = {} } end }

-- Repair: Fabric's own map (Thing id -> piece id) is authoritative. When 0-things replaces a piece's tags (settings
-- paste, blueprint overlap), the piece id is written back at once; other mods' tags are left as they are.
function S.on_tags_changed(ev)
  if storage.s5_repair_off then return end
  local pid = storage.s5_map and storage.s5_map[ev.thing.id]
  if pid and (ev.new_tags or {})[TAG] ~= pid then
    remote.call("things", "set_tag", ev.thing.id, TAG, pid)
    storage.s5_repairs = (storage.s5_repairs or 0) + 1
  end
end

-- A new Thing that arrives carrying a piece id while that piece's own entity still stands (and is not about to be
-- removed, as by a cut) is a copy: its claim is dropped at once, so it can never later pass for the piece.
function S.on_initialized(ev)
  if storage.s5_repair_off then return end
  local claim = ev.tags and ev.tags[TAG]
  if not claim or (storage.s5_map and storage.s5_map[ev.id]) then return end
  local orig = storage.s5_thing_of and storage.s5_thing_of[claim]
  if not orig then return end
  local _, sum = remote.call("things", "get", orig)
  local alive = sum and (sum.status == "real" or sum.status == "ghost")
  if alive and sum.entity and sum.entity.valid and sum.entity.to_be_deconstructed() then alive = false end
  if alive then
    remote.call("things", "remove_tag", ev.id, TAG)
    storage.s5_copies = (storage.s5_copies or 0) + 1
  end
end

-- 15/16. Seppi's sequence: blueprint of A pasted over B (0-things gives B A's tags), then B cut and pasted elsewhere,
-- then A deleted. Truth: B moved, A deleted. Without repair B's copy claims to be A.
local function overlap_then_cut(repair, name)
  name = name or "constant-combinator"
  return {
    setup = function(n, b)
      storage.s5_repair_off = not repair or nil
      register(n, { { mk(name, 2.5, 2.5, nil, b), 151 }, { mk(name, 6.5, 2.5, nil, b), 152 } })
    end,
    steps = {
      function(n, b) local s = st(n); s.bpa = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }) end,
      function(n, b)
        remote.call(COOP, "build_blueprint", st(n).bpa[1], { surface = surface(), force = "player",
          position = { b[1] + 6.5, b[2] + 2.5 }, build_mode = defines.build_mode.superforced })
      end,
      function(n, b, ar)
        local s = st(n)
        local bb = find_unit(ar, s.pieces[152].unit)
        local _, tag = thing_of(bb)
        s.tag_after_overlap = tag
        s.bpb = copy({ { b[1] + 6, b[2] + 2 }, { b[1] + 7, b[2] + 3 } })
        bb.destroy({ raise_destroy = true })
      end,
      function(n, b, ar)
        local s = st(n)
        find_unit(ar, s.pieces[151].unit).destroy({ raise_destroy = true })
        paste(s.bpb, { b[1] + 12.5, b[2] + 8.5 })
      end,
      function(n, b, ar) revive_all(ar); storage.s5_repair_off = nil end,
    },
    truth = function(i) return { at = { [at(i, 12.5, 8.5)] = 152 }, deleted = { [151] = true }, control = not repair } end }
end
SC.overlap_cut = overlap_then_cut(false); SC.overlap_cut.i = 15
SC.overlap_cut_repaired = overlap_then_cut(true); SC.overlap_cut_repaired.i = 16
SC.overlap_cut_cs2_repaired = overlap_then_cut(true, "cybersyn2-combinator"); SC.overlap_cut_cs2_repaired.i = 18

-- 17. Overlap from a Thing without a Fabric tag (a plain combinator that is a Thing) wipes B's id; then B is cut.
SC.overlap_untagged_repaired = { i = 17,
  setup = function(n, b)
    register(n, { { mk("constant-combinator", 6.5, 2.5, nil, b), 171 } })
    local plain = mk("constant-combinator", 2.5, 2.5, nil, b)
    remote.call("things", "create_thing", { entity = plain, tags = { other = 1 } })
  end,
  steps = {
    function(n, b) local s = st(n); s.bpa = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }) end,
    function(n, b)
      remote.call(COOP, "build_blueprint", st(n).bpa[1], { surface = surface(), force = "player",
        position = { b[1] + 6.5, b[2] + 2.5 }, build_mode = defines.build_mode.superforced })
    end,
    function(n, b, ar)
      local s = st(n)
      local bb = find_unit(ar, s.pieces[171].unit)
      local _, tag = thing_of(bb)
      s.tag_after_overlap = tag
      s.bpb = copy({ { b[1] + 6, b[2] + 2 }, { b[1] + 7, b[2] + 3 } })
      bb.destroy({ raise_destroy = true })
    end,
    function(n, b) paste(st(n).bpb, { b[1] + 12.5, b[2] + 8.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 12.5, 8.5)] = 171, [at(i, 2.5, 2.5)] = "new" }, deleted = {} } end }

-- 19. Nested and repeated components: two instances of the same component in one cell, each with an identical
-- combinator (piece ids 1901 and 2901: instance 1 and 2, piece 1). The two combinators are swapped by cut and paste.
SC.repeated_components_swap = { i = 19,
  setup = function(n, b)
    register(n, { { mk("constant-combinator", 2.5, 2.5, nil, b), 1901 }, { mk("inserter", 3.5, 2.5, nil, b), 1902 },
      { mk("constant-combinator", 2.5, 8.5, nil, b), 2901 }, { mk("inserter", 3.5, 8.5, nil, b), 2902 } })
  end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      s.bp1 = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }); find_unit(ar, s.pieces[1901].unit).destroy({ raise_destroy = true })
      s.bp2 = copy({ { b[1] + 2, b[2] + 8 }, { b[1] + 3, b[2] + 9 } }); find_unit(ar, s.pieces[2901].unit).destroy({ raise_destroy = true })
    end,
    function(n, b) local s = st(n); paste(s.bp1, { b[1] + 2.5, b[2] + 8.5 }); paste(s.bp2, { b[1] + 2.5, b[2] + 2.5 }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 2.5, 8.5)] = 1901, [at(i, 2.5, 2.5)] = 2901, [at(i, 3.5, 2.5)] = 1902,
    [at(i, 3.5, 8.5)] = 2902 }, deleted = {} } end }

-- 20. Missing metadata: cut and paste through a plain blueprint (no cooperative extraction, as when a blueprint
-- string comes from outside), so no tags travel.
SC.cut_plain_blueprint = { i = 20,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, nil, b), 20 } }) end,
  steps = {
    function(n, b, ar)
      local s = st(n)
      s.inv = game.create_inventory(1); s.inv[1].set_stack({ name = "blueprint" })
      s.inv[1].create_blueprint({ surface = surface(), force = "player", area = { { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } } })
      find_unit(ar, s.pieces[20].unit).destroy({ raise_destroy = true })
    end,
    function(n, b) st(n).inv[1].build_blueprint({ surface = surface(), force = "player", position = { b[1] + 10.5, b[2] + 4.5 }, build_mode = defines.build_mode.forced }) end,
    function(n, b, ar) revive_all(ar) end,
  },
  truth = function(i) return { at = { [at(i, 10.5, 4.5)] = 20 }, deleted = {} } end }

-- 21. Duplicated metadata: a copy of a piece (it carries the piece's id) while the original stays, then the original
-- is deleted: the copy is a new piece that happens to carry a deleted piece's id.
SC.copy_then_delete_original = { i = 21,
  setup = function(n, b) register(n, { { mk("constant-combinator", 2.5, 2.5, nil, b), 21 } }) end,
  steps = {
    function(n, b) st(n).bp = copy({ { b[1] + 2, b[2] + 2 }, { b[1] + 3, b[2] + 3 } }) end,
    function(n, b) paste(st(n).bp, { b[1] + 10.5, b[2] + 4.5 }) end,
    function(n, b, ar) revive_all(ar) end,
    function(n, b, ar) find_unit(ar, st(n).pieces[21].unit).destroy({ raise_destroy = true }) end,
  },
  truth = function(i) return { at = { [at(i, 10.5, 4.5)] = "new" }, deleted = { [21] = true }, intent_unclear = true } end }

function S.setup(name)
  local sc = SC[name]
  clear(area(sc.i))
  st(name).i = sc.i
  sc.setup(name, base(sc.i))
  local s = st(name)
  s.step = 0
  local out = {}
  for pid, p in pairs(s.pieces) do out[#out + 1] = { pid = pid, name = p.name, carrier = p.carrier, thing = p.thing, thing_err = p.thing_err } end
  return out
end

function S.step(name)
  local sc, s = SC[name], st(name)
  s.step = s.step + 1
  local f = sc.steps[s.step]
  if not f then return "done" end
  f(name, base(sc.i), area(sc.i))
  return sc.steps[s.step + 1] and "more" or "done"
end

function S.eval(name)
  local sc, s = SC[name], st(name)
  if not sc.truth then return { tp = s.tp, unplaced = storage.s5_unplaced } end
  local truth = sc.truth(sc.i, area(sc.i))
  local out = { scenario = name, control = truth.control }
  for an, f in pairs(APPROACHES) do
    local v, d = f(s, area(sc.i))
    local worst, detail = grade(truth, v, d)
    out[an] = worst .. ": " .. table.concat(detail, "; ")
  end
  return out
end

function S.names()
  local l = {}
  for n, sc in pairs(SC) do l[sc.i] = n end
  return l
end

-- In-game check with a real player (cut tool, undo, redo, upgrade planner): `play_setup` builds tagged pieces near the
-- spawn, the player edits them by hand, `play_report` lists what every entity in the cell is now.
local PLAY = { { -8, -8 }, { 8, 8 } }
function S.play_setup()
  clear(PLAY)
  st("play").i = 99
  local b = { -6, -6 }
  register("play", {
    { mk("constant-combinator", 0.5, 0.5, nil, b), 1 }, { mk("constant-combinator", 2.5, 0.5, nil, b), 2 },
    { mk("inserter", 4.5, 0.5, nil, b), 3 }, { mk("requester-chest", 6.5, 0.5, nil, b), 4 },
    { mk("assembling-machine-2", 1.5, 4.5, nil, b), 5 },
  })
  return S.play_report()
end

function S.play_report()
  local s = st("play")
  local lines = {}
  for _, e in pairs(entities(PLAY)) do
    local id, tag = thing_of(e)
    local was
    for pid, p in pairs(s.pieces) do if p.unit == e.unit_number then was = pid end end
    lines[#lines + 1] = string.format("%s at %s: thing %s, tag p%s, same entity as p%s", e.name, key(e.position),
      tostring(id), tostring(tag), tostring(was))
  end
  for _, g in pairs(surface().find_entities_filtered({ area = PLAY, type = "entity-ghost" })) do
    local id, tag = thing_of(g)
    lines[#lines + 1] = string.format("ghost %s at %s: thing %s, tag p%s", g.ghost_name, key(g.position), tostring(id), tostring(tag))
  end
  table.sort(lines)
  return lines
end

-- Leak check: what a carrier does to the entity's real behaviour.
function S.leak()
  local b = { 2000, 1000 }
  clear({ { b[1], b[2] }, { b[1] + 10, b[2] + 10 } })
  local r = mk("requester-chest", 2.5, 2.5, nil, b)
  r.get_requester_point().get_section(1).set_slot(1, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 50 })
  set_carrier(r, 7)
  local c = mk("constant-combinator", 4.5, 2.5, nil, b)
  set_carrier(c, 7)
  local filters = r.get_requester_point().filters
  return { requester_filters = filters, sections = r.get_requester_point().sections_count,
    combinator_signals = c.get_control_behavior().sections_count, description = c.combinator_description }
end

return S
