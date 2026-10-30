-- S5: register the entity types an edit cell may hold as 0-things Things, without intercepting construction, so the
-- spike decides which entities become Things. Cybersyn 2 registers its own combinator.
local names = data.raw["mod-data"]["things-names"].data
for _, name in pairs({
  "inserter", "fast-inserter", "assembling-machine-2", "assembling-machine-3", "constant-combinator",
  "decider-combinator", "arithmetic-combinator", "requester-chest", "buffer-chest", "transport-belt",
  "fast-transport-belt", "pipe", "medium-electric-pole", "wooden-chest", "iron-chest", "splitter",
}) do
  if not names[name] then
    names[name] = { name = name, custom_events = { on_tags_changed = "fabric-spike-on_tags_changed",
      on_initialized = "fabric-spike-on_initialized" } }
  end
end
data:extend({ { type = "custom-event", name = "fabric-spike-on_tags_changed" },
  { type = "custom-event", name = "fabric-spike-on_initialized" } })
