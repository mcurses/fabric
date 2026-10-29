-- S2 mirroring: build a sample of entity types, blueprint it, mirror the blueprint in Lua, build the mirrored copy,
-- and check that everything landed and still connects the way the original does.
local util = require("util")
local S = {}

local function lab(surface, area)
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

-- The sample: {name, x, y, direction, extra}. Placed with create_entity; anything the game refuses is reported.
local SAMPLE = {
  { "straight-rail", 1, 1, defines.direction.north },
  { "straight-rail", 1, 3, defines.direction.north },
  { "curved-rail-a", 2, 8, defines.direction.north },
  { "curved-rail-b", 4, 14, defines.direction.north },
  { "half-diagonal-rail", 6, 20, defines.direction.northeast },
  { "inserter", 12, 2, defines.direction.east },
  { "long-handed-inserter", 12, 4, defines.direction.north },
  { "transport-belt", 14, 2, defines.direction.east },
  { "transport-belt", 15, 2, defines.direction.north },
  { "underground-belt", 17, 2, defines.direction.east, { type = "input" } },
  { "splitter", 19.5, 3, defines.direction.north, { priority = "left" } },
  { "assembling-machine-3", 24.5, 2.5, defines.direction.north, { recipe = "electric-engine-unit" } },
  { "chemical-plant", 30.5, 2.5, defines.direction.east, { recipe = "sulfuric-acid" } },
  { "oil-refinery", 37.5, 3.5, defines.direction.north, { recipe = "advanced-oil-processing" } },
  { "pipe", 24.5, 0.5, defines.direction.north },
  { "pipe-to-ground", 26.5, 0.5, defines.direction.east },
  { "pump", 28.5, 7, defines.direction.east },
  { "decider-combinator", 12.5, 8, defines.direction.east },
  { "cybersyn2-combinator", 14.5, 8.5, defines.direction.east },
  { "medium-electric-pole", 12.5, 10.5, defines.direction.north },
}

local function place(surface, origin)
  local placed, refused = {}, {}
  for _, s in ipairs(SAMPLE) do
    local spec = { name = s[1], position = { origin[1] + s[2], origin[2] + s[3] }, direction = s[4], force = "player" }
    local extra = s[5] or {}
    if extra.type then spec.type = extra.type end
    local ok, e = pcall(surface.create_entity, spec)
    if ok and e then
      if extra.recipe then e.set_recipe(extra.recipe) end
      if extra.priority then e.splitter_output_priority = extra.priority end
      placed[#placed + 1] = e
    else
      refused[#refused + 1] = s[1] .. (ok and "" or (": " .. tostring(e)))
    end
  end
  return placed, refused
end

-- Mirror left-right about the vertical line x = 0 of blueprint space.
local function mirror_entities(entities)
  local out = {}
  for i, be in ipairs(entities) do
    local m = util.table.deepcopy(be)
    m.position = { x = -be.position.x, y = be.position.y }
    local d = be.direction or 0
    local kind = be.name:gsub("^elevated%-", "")
    if kind == "straight-rail" then m.direction = (8 - d) % 8
    elseif kind == "half-diagonal-rail" then m.direction = (2 - d) % 8
    elseif kind == "curved-rail-a" or kind == "curved-rail-b" then m.direction = (18 - d) % 16
    else m.direction = (16 - d) % 16 end
    m.mirror = not be.mirror or nil
    if be.type == "input" or be.type == "output" then m.type = be.type end
    if be.output_priority == "left" then m.output_priority = "right"
    elseif be.output_priority == "right" then m.output_priority = "left" end
    if be.input_priority == "left" then m.input_priority = "right"
    elseif be.input_priority == "right" then m.input_priority = "left" end
    out[i] = m
  end
  return out
end

local function describe(e)
  local d = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction, mirroring = e.mirroring }
  -- Geometry relative to the entity's own position, so original and mirrored copy can be compared.
  local geo = {}
  local function rel(pos) return (pos.x - e.position.x) .. "," .. (pos.y - e.position.y) end
  if e.type == "straight-rail" or e.type == "curved-rail-a" or e.type == "curved-rail-b" or e.type == "half-diagonal-rail" then
    for _, dir in pairs(defines.rail_direction) do
      local ok, rend = pcall(e.get_rail_end, dir)
      if ok and rend then
        local loc = rend.location
        geo[#geo + 1] = "rail-end " .. rel(loc.position) .. " d" .. loc.direction
      end
    end
  end
  local i = 1
  while true do
    local ok, conns = pcall(e.get_fluid_box_pipe_connections, i)
    if not ok or not conns then break end
    for _, c in pairs(conns) do
      geo[#geo + 1] = "pipe " .. c.connection_type .. " " .. rel(c.position) .. " -> " .. rel(c.target_position)
    end
    i = i + 1
  end
  table.sort(geo)
  d.geo = geo
  if e.type == "inserter" then
    d.pickup = { e.pickup_position.x - e.position.x, e.pickup_position.y - e.position.y }
    d.drop = { e.drop_position.x - e.position.x, e.drop_position.y - e.position.y }
  end
  if e.type == "splitter" then d.priority = e.splitter_output_priority end
  return d
end

function S.run()
  local surface = game.surfaces.nauvis
  local A, B = { 0, 0 }, { 0, 64 }
  lab(surface, { { -10, -10 }, { 60, 110 } })
  local placed, refused = place(surface, A)

  local inv = game.create_inventory(1)
  local bp = inv[1]
  bp.set_stack("blueprint")
  bp.create_blueprint({ surface = surface, force = "player", area = { { A[1] - 5, A[2] - 5 }, { A[1] + 50, A[2] + 30 } } })
  local original = bp.get_blueprint_entities() or {}
  bp.set_blueprint_entities(mirror_entities(original))
  local ghosts = bp.build_blueprint({ surface = surface, force = "player", position = { B[1] + 20, B[2] + 10 },
    build_mode = defines.build_mode.forced })
  local revived = 0
  for _, g in pairs(ghosts) do
    if g.valid and g.name == "entity-ghost" then
      local _, ent = g.revive()
      if ent then revived = revived + 1 end
    end
  end
  inv.destroy()

  local function collect(origin)
    local list = {}
    for _, e in pairs(surface.find_entities_filtered({ area = { { origin[1] - 10, origin[2] - 10 }, { origin[1] + 55, origin[2] + 35 } } })) do
      if e.type ~= "character" and e.name ~= "entity-ghost" then list[#list + 1] = describe(e) end
    end
    table.sort(list, function(a, b) return a.name .. a.x .. a.y < b.name .. b.x .. b.y end)
    return list
  end
  return {
    placed = #placed, refused = refused, blueprint_entities = #original,
    mirrored_ghosts = #ghosts, revived = revived,
    original = collect(A), mirrored = collect(B),
  }
end

-- Rail end geometry for every rail type and direction, placed alone on a cleared spot.
function S.rail_table()
  local surface = game.surfaces.nauvis
  lab(surface, { { 100, -20 }, { 140, 20 } })
  local out = {}
  for _, name in pairs({ "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b",
                         "elevated-straight-rail", "elevated-half-diagonal-rail", "elevated-curved-rail-a",
                         "elevated-curved-rail-b", "rail-ramp" }) do
    for d = 0, 15 do
      local ok, e = pcall(surface.create_entity, { name = name, position = { 120, 0 }, direction = d, force = "player" })
      if ok and e then
        if e.direction == d then
          local geo = {}
          for _, rd in pairs(defines.rail_direction) do
            local okr, rend = pcall(e.get_rail_end, rd)
            if okr and rend then
              local l = rend.location
              geo[#geo + 1] = { l.position.x - e.position.x, l.position.y - e.position.y, l.direction }
            end
          end
          out[#out + 1] = { name = name, dir = d, geo = geo }
        end
        e.destroy()
      end
    end
  end
  return out
end

return S
