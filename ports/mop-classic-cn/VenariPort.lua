VenariPort = {
  client = {
    key = "mop-classic-cn",
    interface = 50504,
    enabled = false,
    reason = "Hunter mechanics and spell IDs need MoP validation before release.",
  },
}

VenariPort.spells = {}

function VenariPort.spells.getInfo(spellId)
  local name, rank
  if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if ok and type(info) == "table" then
      name = info.name
    end
  end
  if type(GetSpellInfo) == "function" then
    local ok, legacyName, legacyRank = pcall(GetSpellInfo, spellId)
    if ok then
      name = name or legacyName
      rank = legacyRank
    end
  end
  return name, rank
end

function VenariPort.spells.apply(spellBook)
  -- Placeholder target adapter. Keep MoP disabled in the package manager until
  -- hunter aspects, traps, pet happiness, and food rules are validated.
  return spellBook
end
