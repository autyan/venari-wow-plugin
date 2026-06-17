VenariPort = {
  client = {
    key = "tbc-anniversary-cn",
    interface = 20505,
  },
}

VenariPort.spells = {}

function VenariPort.spells.apply(spellBook)
  -- TBC is the source behavior today. Keep this as an explicit target adapter
  -- so future client branches can replace spell IDs without touching the HUD.
  return spellBook
end

