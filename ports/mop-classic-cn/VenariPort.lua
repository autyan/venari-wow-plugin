VenariPort = {
  client = {
    key = "mop-classic-cn",
    interface = 50504,
    enabled = false,
    reason = "Hunter mechanics and spell IDs need MoP validation before release.",
  },
}

VenariPort.spells = {}

function VenariPort.spells.apply(spellBook)
  -- Placeholder target adapter. Keep MoP disabled in the package manager until
  -- hunter aspects, traps, pet happiness, and food rules are validated.
  return spellBook
end

