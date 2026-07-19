VenariPort = {
  client = {
    key = "tbc-anniversary-cn",
    interface = 20506,
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
  -- TBC is the source behavior today. Keep this as an explicit target adapter
  -- so future client branches can replace spell IDs without touching the HUD.
  return spellBook
end
