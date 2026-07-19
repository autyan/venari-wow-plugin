local addonName = ...
local port = assert(VenariPort, "VenariPort must be loaded before Venari.lua")
assert(port.spells and port.spells.apply and port.spells.getInfo, "VenariPort.spells adapter is required")

VenariDB = VenariDB or AutyanHunterDB or {}
AutyanHunterDB = nil

local ADDON_PATH = "Interface\\AddOns\\Venari\\"
local MEDIA = ADDON_PATH .. "Media\\"
local HUNTER_R, HUNTER_G, HUNTER_B = 0.67, 0.83, 0.45
local UI_BASE_SCALE = 0.68
local SHOT_RING_RADIUS = 68
local CENTER_SIZE = 92
local ASPECT_SLOT_COUNT = 2
local TRAP_SLOT_COUNT = 4

local function L(key)
  if VenariLocale and type(VenariLocale.Get) == "function" then
    return VenariLocale:Get(key)
  end
  return key
end

local defaults = {
  enabled = true,
  locked = false,
  debug = false,
  clickDebug = false,
  scale = 1,
  petFood = {
    preference = "lowest",
    allowRaw = true,
    allowPrepared = true,
  },
  position = {
    point = "BOTTOMRIGHT",
    relativePoint = "BOTTOMRIGHT",
    x = -390,
    y = 240,
  },
  aspects = { "hawk", "viper" },
  traps = { "freezing", "frost", "explosive", "immolation" },
}

local spellBook = {
  feedPet = { id = 6991, fallback = L("spell.feedPet") },
  autoShot = { id = 75, fallback = L("spell.autoShot") },
  callPet = { id = 883, fallback = L("spell.callPet") },
  revivePet = { id = 982, fallback = L("spell.revivePet") },
  dismissPet = { id = 2641, fallback = L("spell.dismissPet") },

  hawk = { id = 27044, ranks = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }, fallback = L("spell.aspectHawk"), icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
  monkey = { id = 13163, fallback = L("spell.aspectMonkey"), icon = "Interface\\Icons\\Ability_Hunter_AspectOfTheMonkey" },
  cheetah = { id = 5118, fallback = L("spell.aspectCheetah"), icon = "Interface\\Icons\\Ability_Mount_JungleTiger" },
  pack = { id = 13159, fallback = L("spell.aspectPack"), icon = "Interface\\Icons\\Ability_Mount_WhiteTiger" },
  beast = { id = 13161, fallback = L("spell.aspectBeast"), icon = "Interface\\Icons\\Ability_Mount_PinkTiger" },
  wild = { id = 27045, ranks = { 27045, 20190, 20043, 20042, 20041, 20040, 20039 }, fallback = L("spell.aspectWild"), icon = "Interface\\Icons\\Spell_Nature_ProtectionformNature" },
  viper = { id = 34074, fallback = L("spell.aspectViper"), icon = "Interface\\Icons\\Ability_Hunter_AspectoftheViper" },

  freezing = { id = 14311, ranks = { 14311, 14310, 1499 }, fallback = L("spell.freezingTrap"), icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
  frost = { id = 13809, fallback = L("spell.frostTrap"), icon = "Interface\\Icons\\Spell_Frost_FreezingBreath" },
  explosive = { id = 27025, ranks = { 27025, 14317, 14316, 13813 }, fallback = L("spell.explosiveTrap"), icon = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
  immolation = { id = 27023, ranks = { 27023, 14305, 14304, 14303, 14302, 13795 }, fallback = L("spell.immolationTrap"), icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
  snake = { id = 34600, fallback = L("spell.snakeTrap"), icon = "Interface\\Icons\\Ability_Hunter_SnakeTrap" },

  eagleEye = { id = 6197, fallback = L("spell.eagleEye"), icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
  scareBeast = { id = 1513, ranks = { 14327, 14326, 1513 }, fallback = L("spell.scareBeast"), icon = "Interface\\Icons\\Ability_Druid_Cower" },
  flare = { id = 1543, fallback = L("spell.flare"), icon = "Interface\\Icons\\Spell_Fire_Flare" },
  beastLore = { id = 1462, fallback = L("spell.beastLore"), icon = "Interface\\Icons\\Ability_Physical_Taunt" },
  tameBeast = { id = 1515, fallback = L("spell.tameBeast"), icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
  bandage = { fallback = L("resource.bandage"), icon = "Interface\\Icons\\INV_Misc_Bandage_Netherweave_Heavy" },
  petFood = { fallback = L("resource.petFood"), icon = "Interface\\Icons\\INV_Misc_Food_48" },
}

port.spells.apply(spellBook)

local aspectOptions = { "hawk", "monkey", "cheetah", "pack", "beast", "wild", "viper" }
local trapOptions = { "freezing", "frost", "explosive", "immolation", "snake" }
local petFoodPreferenceOptions = {
  { key = "lowest", label = L("food.prefLowest") },
  { key = "highest", label = L("food.prefHighest") },
}

local petFoodDB = VenariPetFoodDB or {}
local petFoodTypeAliases = petFoodDB.foodTypeAliases or {}
local foodConsumableSubTypes = petFoodDB.foodConsumableSubTypes or {}
local knownPetFoodItems = petFoodDB.foodItems or {}
local petFoodNameHints = petFoodDB.nameHints or {}

local bandages = {
  21991, -- Heavy Netherweave Bandage
  21990, -- Netherweave Bandage
  14530, -- Heavy Runecloth Bandage
  14529, -- Runecloth Bandage
  8545, -- Heavy Mageweave Bandage
  8544, -- Mageweave Bandage
  6451, -- Heavy Silk Bandage
  6450, -- Silk Bandage
  3531, -- Heavy Wool Bandage
  3530, -- Wool Bandage
  2581, -- Heavy Linen Bandage
  1251, -- Linen Bandage
}

local state = {
  initialized = false,
  inCombat = false,
  autoRepeat = false,
  lastAutoRepeatStart = nil,
  lastAutoRepeatStop = nil,
  lastAutoShot = nil,
  lastAutoShotSource = nil,
  shotPulseStart = nil,
  shotBurstStart = nil,
  autoShotCount = 0,
  autoShotTimerStart = nil,
  autoShotTimerDuration = nil,
  autoShotTimerSource = nil,
  autoShotPending = false,
  autoShotArmed = false,
  autoShotSyncLockUntil = nil,
  autoShotTraceLastKey = nil,
  rangedSpeed = nil,
  lastRangedSpeed = nil,
  petExists = false,
  petDead = false,
  petName = nil,
  petLevel = nil,
  petHealth = nil,
  petHealthMax = nil,
  petHappiness = nil,
  playerClass = nil,
  activeAspect = nil,
  aspectDrawerOpen = false,
  selectedFood = nil,
  selectedFoodIcon = nil,
  selectedFoodItemId = nil,
  petFoodLockItemId = nil,
  petFoodLockUntil = nil,
  petFoodBestCandidate = nil,
  petFoodMatchCount = 0,
  selectedBandage = nil,
  selectedBandageName = nil,
  selectedBandageIcon = nil,
  selectedAmmo = nil,
  selectedAmmoName = nil,
  selectedAmmoIcon = nil,
  selectedAmmoCount = nil,
  selectedAmmoSource = nil,
  configDirty = false,
  scaleDirty = false,
  petRevivePending = false,
  petReviveDeadGuardUntil = nil,
  lastEvent = "none",
}

local ui = {
  buttons = {},
  ringDots = {},
  shotRingSegments = {},
}

local careMacroDirty = true
local lastCareMacroUpdate = 0
local ammoDirty = true
local lastAmmoUpdate = 0
local resourceRefreshSerial = 0
local PET_FOOD_LOCK_SECONDS = 6
local updateVisuals
local applyConfiguredButtons
local setTooltip
local refresh
local schedulePetRefresh
local updateSnapshot
local shortValue

local function optionContains(options, key)
  if not key then
    return false
  end
  for _, optionKey in ipairs(options) do
    if optionKey == key then
      return true
    end
  end
  return false
end

local function normalizeSpellSlots(slots, options, fallback, count)
  if type(slots) ~= "table" then
    slots = {}
  end
  for index = 1, count do
    if not optionContains(options, slots[index]) then
      slots[index] = fallback[index]
    end
  end
  for index = count + 1, #slots do
    slots[index] = nil
  end
  return slots
end

local function copyDefaults(target, source)
  for key, value in pairs(source) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = {}
        copyDefaults(target[key], value)
      else
        target[key] = value
      end
    elseif type(value) == "table" and type(target[key]) == "table" then
      copyDefaults(target[key], value)
    end
  end
end

local function db()
  copyDefaults(VenariDB, defaults)
  VenariDB.aspects = normalizeSpellSlots(VenariDB.aspects, aspectOptions, defaults.aspects, ASPECT_SLOT_COUNT)
  VenariDB.traps = normalizeSpellSlots(VenariDB.traps, trapOptions, defaults.traps, TRAP_SLOT_COUNT)
  if type(VenariDB.petFood) ~= "table" then
    VenariDB.petFood = {}
  end
  copyDefaults(VenariDB.petFood, defaults.petFood)
  if VenariDB.petFood.preference ~= "lowest" and VenariDB.petFood.preference ~= "highest" then
    VenariDB.petFood.preference = defaults.petFood.preference
  end
  VenariDB.petFood.allowRaw = VenariDB.petFood.allowRaw ~= false
  VenariDB.petFood.allowPrepared = VenariDB.petFood.allowPrepared ~= false
  return VenariDB
end

local function printMsg(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffabd473Venari|r: " .. tostring(message))
  end
end

local function after(delay, callback)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, callback)
  else
    callback()
  end
end

local function lockedDown()
  return InCombatLockdown and InCombatLockdown()
end

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if ok then
    return result
  end
  return nil
end

local function spellName(key)
  local name = nil
  local entry = spellBook[key]
  if not entry then
    return nil
  end

  if entry.ranks then
    for _, spellId in ipairs(entry.ranks) do
      local known = false
      if type(IsSpellKnown) == "function" then
        known = safeCall(IsSpellKnown, spellId) and true or false
      elseif type(IsPlayerSpell) == "function" then
        known = safeCall(IsPlayerSpell, spellId) and true or false
      end
      if known then
        name = port.spells.getInfo(spellId)
        if name then
          return name
        end
      end
    end
  end

  local entry = spellBook[key]
  if entry.id then
    name = port.spells.getInfo(entry.id)
    if name then
      return name
    end
  end
  return entry.fallback
end

local function spellTooltipId(key)
  local entry = spellBook[key]
  if not entry then
    return nil
  end

  local ids = entry.ranks or { entry.id }
  for _, spellId in ipairs(ids) do
    if spellId then
      if type(IsSpellKnown) == "function" and safeCall(IsSpellKnown, spellId) then
        return spellId
      end
      if type(IsPlayerSpell) == "function" and safeCall(IsPlayerSpell, spellId) then
        return spellId
      end
    end
  end

  return entry.id
end

local function spellRankText(key, apiRank)
  if apiRank and apiRank ~= "" then
    return apiRank
  end

  local entry = spellBook[key]
  if not entry or not entry.ranks then
    return nil
  end

  local spellId = spellTooltipId(key)
  if not spellId then
    return nil
  end

  for index, rankSpellId in ipairs(entry.ranks) do
    if rankSpellId == spellId then
      local rank = #entry.ranks - index + 1
      return (L("tooltip.rankFormat")):format(rank)
    end
  end
  return nil
end

local function spellBookSlot(name)
  if not name or type(GetNumSpellBookItems) ~= "function" or type(GetSpellBookItemName) ~= "function" then
    return nil
  end

  local bookType = BOOKTYPE_SPELL or "spell"
  local count = GetNumSpellBookItems(bookType) or 0
  for slot = 1, count do
    local slotName, slotRank = GetSpellBookItemName(slot, bookType)
    if slotName == name then
      return slot, bookType, slotRank
    end
  end
  return nil
end

local function spellKnown(key)
  local entry = spellBook[key]
  if not entry then
    return false
  end

  local ids = entry.ranks or { entry.id }
  local checkedKnownApi = false
  for _, spellId in ipairs(ids) do
    if spellId then
      if type(IsSpellKnown) == "function" then
        checkedKnownApi = true
      end
      if type(IsSpellKnown) == "function" and safeCall(IsSpellKnown, spellId) then
        return true
      end
      if type(IsPlayerSpell) == "function" then
        checkedKnownApi = true
      end
      if type(IsPlayerSpell) == "function" and safeCall(IsPlayerSpell, spellId) then
        return true
      end
    end
  end

  if checkedKnownApi then
    return false
  end

  return entry.id and port.spells.getInfo(entry.id) ~= nil
end

local function petReviveMacro()
  return table.concat({
    "#showtooltip " .. spellName("revivePet"),
    "/cast " .. spellName("revivePet"),
  }, "\n")
end

local function petActionMacroForState()
  if state.petExists and state.petDead then
    return petReviveMacro(), "revivePet"
  end
  if state.petExists then
    local dismissName = spellName("dismissPet")
    return "#showtooltip " .. dismissName .. "\n/cast [nocombat] " .. dismissName, "dismissPet"
  end

  local callName = spellName("callPet")
  return "#showtooltip " .. callName .. "\n/cast " .. callName, "callPet"
end

local function feedPetMacro()
  return "#showtooltip " .. spellName("feedPet") .. "\n/cast " .. spellName("feedPet")
end

local function feedPetFoodMacro(candidate)
  local itemId = candidate and candidate.itemId
  if not itemId then
    return feedPetMacro()
  end
  return "#showtooltip item:" .. itemId .. "\n/cast " .. spellName("feedPet") .. "\n/use item:" .. itemId
end

local function petInfoMacro()
  return "/run if ToggleCharacter then ToggleCharacter('PetPaperDollFrame') elseif CharacterFrame and ShowUIPanel then ShowUIPanel(CharacterFrame) end"
end

local function castSpellMacro(name)
  if not name or name == "" then
    return "/run UIErrorsFrame:AddMessage('" .. L("macro.noSpell") .. "', 1.0, 0.5, 0.0)"
  end
  return "#showtooltip " .. name .. "\n/cast " .. name
end

local function itemName(itemId)
  if type(GetItemInfo) ~= "function" then
    return nil
  end
  local name = GetItemInfo(itemId)
  return name
end

local function itemIcon(item)
  if not item then
    return nil
  end
  if C_Item and type(C_Item.GetItemIconByID) == "function" then
    local ok, texture = pcall(C_Item.GetItemIconByID, item)
    if ok and texture then
      return texture
    end
  end
  if type(GetItemIcon) == "function" then
    local texture = GetItemIcon(item)
    if texture then
      return texture
    end
  end
  if type(GetItemInfoInstant) == "function" then
    local texture = select(5, GetItemInfoInstant(item))
    if texture then
      return texture
    end
  end
  if type(GetItemInfo) == "function" then
    local texture = select(10, GetItemInfo(item))
    return texture
  end
  return nil
end

local function itemIdFromLink(item)
  if type(item) == "number" then
    return item
  end
  if type(item) ~= "string" then
    return nil
  end
  return tonumber(item:match("item:(%d+)"))
end

local function itemCount(item)
  if not item then
    return nil
  end

  if C_Item and type(C_Item.GetItemCount) == "function" then
    local ok, count = pcall(C_Item.GetItemCount, item, nil, true)
    if ok and type(count) == "number" then
      return count
    end
  end

  if type(GetItemCount) == "function" then
    local ok, count = pcall(GetItemCount, item)
    if ok and type(count) == "number" then
      return count
    end
  end

  return nil
end

local function containerNumSlots(bag)
  if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
    local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
    if ok then
      return slots or 0
    end
  end
  if type(GetContainerNumSlots) == "function" then
    local ok, slots = pcall(GetContainerNumSlots, bag)
    if ok then
      return slots or 0
    end
  end
  return 0
end

local function containerItemLink(bag, slot)
  if C_Container and type(C_Container.GetContainerItemLink) == "function" then
    local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
    if ok then
      return link
    end
  end
  if type(GetContainerItemLink) == "function" then
    local ok, link = pcall(GetContainerItemLink, bag, slot)
    if ok then
      return link
    end
  end
  return nil
end

local function containerItemCount(bag, slot)
  if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then
      return info.stackCount or info.count or 0
    end
  end
  if type(GetContainerItemInfo) == "function" then
    local values = { pcall(GetContainerItemInfo, bag, slot) }
    if values[1] then
      return values[3] or 0
    end
  end
  return 0
end

local function isAmmoItem(item)
  local itemId = itemIdFromLink(item)
  if itemId and type(GetItemInfoInstant) == "function" then
    local ok, _, _, _, equipLoc, _, classId, subClassId = pcall(GetItemInfoInstant, itemId)
    if ok then
      if equipLoc == "INVTYPE_AMMO" then
        return true
      end
      if classId == 6 or (LE_ITEM_CLASS_PROJECTILE and classId == LE_ITEM_CLASS_PROJECTILE) then
        return subClassId == nil or subClassId == 2 or subClassId == 3
      end
    end
  end

  if type(GetItemInfo) == "function" then
    local ok, _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = pcall(GetItemInfo, item)
    if ok then
      local typeText = tostring(itemType or "")
      local subTypeText = tostring(itemSubType or "")
      if itemEquipLoc == "INVTYPE_AMMO" then
        return true
      end
      if typeText == "Projectile" or typeText == "弹药" or typeText == "弹藥" then
        return true
      end
    end
  end
  return false
end

local function addCountOverlay(button, anchor, x, y)
  local countFrame = CreateFrame("Frame", nil, button)
  countFrame:SetAllPoints(button)
  local level = button.GetFrameLevel and button:GetFrameLevel() or 0
  if button.cooldown and button.cooldown.GetFrameLevel then
    level = math.max(level, button.cooldown:GetFrameLevel() or level)
  end
  countFrame:SetFrameLevel(level + 10)
  button.countFrame = countFrame

  local countText = countFrame:CreateFontString(nil, "OVERLAY")
  if NumberFontNormalSmall then
    countText:SetFontObject(NumberFontNormalSmall)
  elseif NumberFontNormal then
    countText:SetFontObject(NumberFontNormal)
  end
  if type(countText.SetDrawLayer) == "function" then
    countText:SetDrawLayer("OVERLAY", 7)
  end
  countText:SetSize(button:GetWidth() or 40, 14)
  countText:SetJustifyH("RIGHT")
  countText:SetJustifyV("BOTTOM")
  countText:SetPoint("BOTTOMRIGHT", anchor or countFrame, "BOTTOMRIGHT", x or -4, y or 2)
  countText:SetTextColor(1, 0.95, 0.55, 1)
  countText:SetShadowColor(0, 0, 0, 1)
  countText:SetShadowOffset(1, -1)
  countText:SetText("")
  countText:Show()
  button.countText = countText
  return countText
end

local function setButtonCount(button, count)
  if not button or not button.countText then
    return
  end
  local text = count and count > 0 and tostring(count) or ""
  button.countText:SetText(text)
  if text ~= "" then
    button.countText:Show()
  else
    button.countText:Hide()
  end
end

local function setSolidTexture(texture, r, g, b, a)
  if not texture then
    return
  end
  if type(texture.SetColorTexture) == "function" then
    local ok = pcall(texture.SetColorTexture, texture, r, g, b, a)
    if ok then
      return
    end
  end
  texture:SetTexture("Interface\\Buttons\\WHITE8X8")
  texture:SetVertexColor(r, g, b, a)
end

local function blendColor(a, b, amount)
  amount = math.max(0, math.min(1, amount or 0))
  return a + (b - a) * amount
end

local function setItemCooldown(button, item)
  if not button or not button.cooldown or not item or type(GetItemCooldown) ~= "function" then
    if button and button.cooldown and type(CooldownFrame_Set) == "function" then
      CooldownFrame_Set(button.cooldown, 0, 0, 0)
    end
    return
  end

  local start, duration, enabled = GetItemCooldown(item)
  if type(CooldownFrame_Set) == "function" then
    CooldownFrame_Set(button.cooldown, start or 0, duration or 0, enabled or 0)
  end
end

local function bestBandage()
  for _, itemId in ipairs(bandages) do
    local count = itemCount(itemId) or 0
    if count > 0 then
      return itemId, itemName(itemId), count
    end
  end
  return nil, nil
end

local function bandageMacro()
  local itemId, name = bestBandage()
  if not itemId then
    return "/run UIErrorsFrame:AddMessage('" .. L("macro.noBandage") .. "', 1.0, 0.5, 0.0)"
  end
  return "#showtooltip item:" .. itemId .. "\n/use [@player] item:" .. itemId
end

local function petBandageMacro()
  local itemId = bestBandage()
  if not itemId then
    return "/run UIErrorsFrame:AddMessage('" .. L("macro.noBandage") .. "', 1.0, 0.5, 0.0)"
  end
  return "#showtooltip item:" .. itemId .. "\n/use [@pet,exists,nodead] item:" .. itemId
end

local function refreshBandageVisual()
  if not ui.bandageButton then
    return
  end
  local itemId, name, bandageCount = bestBandage()
  state.selectedBandage = itemId
  state.selectedBandageName = name
  state.selectedBandageIcon = itemIcon(itemId) or spellBook.bandage.icon
  state.selectedBandageCount = bandageCount
  if ui.bandageButton.icon then
    ui.bandageButton.icon:SetTexture(state.selectedBandageIcon)
    if type(ui.bandageButton.icon.SetDesaturated) == "function" then
      ui.bandageButton.icon:SetDesaturated(itemId == nil)
    end
    ui.bandageButton.icon:SetAlpha(itemId and 0.9 or 0.36)
  end
  setButtonCount(ui.bandageButton, bandageCount)
  setItemCooldown(ui.bandageButton, itemId)
  if itemId then
    setTooltip(
      ui.bandageButton,
      L("tooltip.bandageTitle"),
      ("%s\n%s: %s\n%s: %s\n%s: %s"):format(
        L("tooltip.bandageDefault"),
        L("tooltip.selected"),
        tostring(name or ("item:" .. itemId)),
        L("tooltip.count"),
        tostring(bandageCount or 0),
        L("tooltip.combatLocked"),
        tostring(lockedDown())
      ),
      itemId
    )
  else
    setTooltip(ui.bandageButton, L("tooltip.bandageTitle"), L("tooltip.noBandage") .. "\n" .. L("tooltip.bandageDefault"))
  end
end

local function equippedAmmo()
  if type(GetInventorySlotInfo) ~= "function" then
    return nil, nil, nil, nil
  end

  local slot = GetInventorySlotInfo("AmmoSlot")
  if not slot then
    return nil, nil, nil, nil
  end

  local link = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slot) or nil
  local icon = nil
  if type(GetInventoryItemTexture) == "function" then
    icon = GetInventoryItemTexture("player", slot)
  end
  icon = icon or itemIcon(link)

  local equippedCount = 0
  if type(GetInventoryItemCount) == "function" then
    equippedCount = GetInventoryItemCount("player", slot) or 0
  end

  local totalCount = nil
  if link then
    local bagCount = itemCount(link)
    if type(bagCount) == "number" then
      totalCount = bagCount
      if equippedCount > totalCount then
        totalCount = equippedCount
      end
    else
      totalCount = equippedCount
    end
  elseif equippedCount > 0 then
    totalCount = equippedCount
  end

  local name = nil
  if link and type(GetItemInfo) == "function" then
    name = GetItemInfo(link)
  end
  if not link or not totalCount or totalCount <= 0 then
    return nil, nil, nil, nil
  end
  return link, name, icon, totalCount
end

local function bagAmmo()
  local bestLink, bestName, bestIcon, bestCount = nil, nil, nil, 0
  local totals = {}
  local metadata = {}

  for bag = 0, 4 do
    for slot = 1, containerNumSlots(bag) do
      local link = containerItemLink(bag, slot)
      if link and isAmmoItem(link) then
        local itemId = itemIdFromLink(link) or link
        local count = containerItemCount(bag, slot) or 0
        if count > 0 then
          totals[itemId] = (totals[itemId] or 0) + count
          if not metadata[itemId] then
            local name = type(GetItemInfo) == "function" and GetItemInfo(link) or nil
            metadata[itemId] = {
              link = link,
              name = name,
              icon = itemIcon(link) or "Interface\\Icons\\INV_Ammo_Bullet_02",
            }
          end
        end
      end
    end
  end

  for itemId, count in pairs(totals) do
    if count > bestCount then
      bestCount = count
      bestLink = metadata[itemId] and metadata[itemId].link or itemId
      bestName = metadata[itemId] and metadata[itemId].name or nil
      bestIcon = metadata[itemId] and metadata[itemId].icon or nil
    end
  end

  if bestLink then
    return bestLink, bestName, bestIcon, bestCount
  end
  return nil, nil, nil, nil
end

local function joinValues(values, empty)
  if type(values) ~= "table" or #values == 0 then
    return empty or "-"
  end
  local out = {}
  for index, value in ipairs(values) do
    out[index] = tostring(value)
  end
  return table.concat(out, ", ")
end

local function boolText(value)
  return value and L("tooltip.yes") or L("tooltip.no")
end

local function petFoodPreferenceText(value)
  for _, option in ipairs(petFoodPreferenceOptions) do
    if option.key == value then
      return option.label
    end
  end
  return petFoodPreferenceOptions[1].label
end

local function normalizePetFoodType(value)
  if value == nil then
    return nil
  end
  local text = tostring(value):lower()
  for canonical, aliases in pairs(petFoodTypeAliases) do
    if text == canonical:lower() then
      return canonical
    end
    for _, alias in ipairs(aliases) do
      if text == alias or text:find(alias, 1, true) then
        return canonical
      end
    end
  end
  return nil
end

local function classifyPetFoodItem(info, fallbackLink)
  if not info then
    return nil, "missing-info"
  end

  local itemId = itemIdFromLink(info.link or fallbackLink)
  local dbItem = itemId and knownPetFoodItems[itemId] or nil
  if dbItem and dbItem.type then
    return dbItem.type, "id"
  end

  local bySubtype = normalizePetFoodType(info.itemSubType)
  if bySubtype then
    return bySubtype, "subtype"
  end

  local name = tostring(info.name or info.link or ""):lower()
  for foodType, hints in pairs(petFoodNameHints) do
    for _, hint in ipairs(hints) do
      if name:find(hint, 1, true) then
        return foodType, "name:" .. hint
      end
    end
  end

  return nil, "unknown"
end

local function currentPetFoodTypes()
  local rawTypes = {}
  local normalized = {}
  local seen = {}

  if type(GetPetFoodTypes) ~= "function" then
    return rawTypes, normalized, "GetPetFoodTypes unavailable"
  end

  local values = { pcall(GetPetFoodTypes) }
  if not values[1] then
    return rawTypes, normalized, values[2]
  end

  for index = 2, #values do
    local raw = values[index]
    if raw ~= nil then
      rawTypes[#rawTypes + 1] = raw
      local canonical = normalizePetFoodType(raw)
      if canonical and not seen[canonical] then
        normalized[#normalized + 1] = canonical
        seen[canonical] = true
      end
    end
  end

  return rawTypes, normalized, nil
end

local function petFoodTypeSet(types)
  local set = {}
  for _, foodType in ipairs(types or {}) do
    set[foodType] = true
  end
  return set
end

local function resolvePetFamily(family)
  if not family then
    return nil
  end
  if petFoodDB.petFamilies and petFoodDB.petFamilies[family] then
    return family
  end
  if petFoodDB.petFamilyAliases and petFoodDB.petFamilyAliases[family] then
    return petFoodDB.petFamilyAliases[family]
  end
  for _, names in pairs(petFoodDB.localizedFamilyNames or {}) do
    for canonical, localizedName in pairs(names) do
      if localizedName == family then
        return canonical
      end
    end
  end
  return nil
end

local function resolvePetFamilyFromIcon(icon)
  if not icon then
    return nil
  end
  local text = tostring(icon)
  if petFoodDB.petIcons and petFoodDB.petIcons[text] then
    return petFoodDB.petIcons[text]
  end
  local fileId = text:match("(%d+)$")
  return fileId and petFoodDB.petIcons and petFoodDB.petIcons[fileId] or nil
end

local function currentAllowedPetFoodTypes()
  local rawTypes, normalizedTypes, err = currentPetFoodTypes()
  local unitFamily = type(UnitCreatureFamily) == "function" and UnitCreatureFamily("pet") or nil
  local stableIcon, _, _, stableFamily = nil, nil, nil, nil
  if type(GetStablePetInfo) == "function" then
    stableIcon, _, _, stableFamily = GetStablePetInfo(0)
  end

  local dbFamily = resolvePetFamily(unitFamily or stableFamily) or resolvePetFamilyFromIcon(stableIcon)
  local dbFamilyDiet = dbFamily and petFoodDB.petFamilies and petFoodDB.petFamilies[dbFamily] or nil
  local allowedTypes = (#normalizedTypes > 0 and normalizedTypes) or dbFamilyDiet or {}
  local allowedSource = #normalizedTypes > 0 and "api" or dbFamilyDiet and "db-family" or "none"

  return allowedTypes, allowedSource, rawTypes, normalizedTypes, err, dbFamily, dbFamilyDiet
end

local function itemInfo(item)
  if type(GetItemInfo) ~= "function" then
    return nil
  end

  local values = { pcall(GetItemInfo, item) }
  if not values[1] then
    return nil
  end

  return {
    name = values[2],
    link = values[3],
    quality = values[4],
    itemLevel = values[5],
    minLevel = values[6],
    itemType = values[7],
    itemSubType = values[8],
    stackCount = values[9],
    equipLoc = values[10],
    icon = values[11],
    sellPrice = values[12],
    classId = values[13],
    subClassId = values[14],
  }
end

local function isFoodConsumable(info)
  if not info then
    return false
  end

  if info.classId == 0 and info.subClassId == 5 then
    return true
  end

  local itemType = tostring(info.itemType or ""):lower()
  local itemSubType = tostring(info.itemSubType or ""):lower()
  if itemType == "consumable" or itemType == "消耗品" then
    return foodConsumableSubTypes[itemSubType] or itemSubType:find("food", 1, true) or itemSubType:find("食物", 1, true)
  end

  return false
end

local function dbFoodFlag(dbItem, flag)
  local flags = dbItem and dbItem.flags
  return flags and flags[flag] or false
end

local function petFoodCandidateAllowed(dbItem)
  if not dbItem then
    return true
  end
  local cfg = db().petFood or defaults.petFood
  if dbFoodFlag(dbItem, "raw") and cfg.allowRaw == false then
    return false
  end
  if dbFoodFlag(dbItem, "prepared") and cfg.allowPrepared == false then
    return false
  end
  return true
end

local function petFoodHappinessGain(petLevel, foodLevel)
  if not petLevel or not foodLevel then
    return nil, "unknown"
  end
  local delta = petLevel - foodLevel
  if delta <= 0 then
    return 35, "full"
  end
  if delta <= 10 then
    return 17, "medium"
  end
  if delta < 30 then
    return 8, "low"
  end
  return 0, "too-low"
end

local function petFoodItemFeedable(dbItem)
  if not dbItem then
    return false, "unknown-db"
  end
  local flags = dbItem.flags or {}
  if flags.notFeedable then
    return false, "db-not-feedable"
  end
  if flags.prepared then
    return true, "prepared"
  end
  if flags.petRaw then
    return true, "pet-raw"
  end
  if flags.cookable then
    return false, "cookable-reagent"
  end
  return false, "not-feedable"
end

local function scanPetFoodCandidates(allowedTypes)
  local allowed = petFoodTypeSet(allowedTypes)
  local candidates = {}
  local preference = db().petFood and db().petFood.preference or defaults.petFood.preference

  for bag = 0, 4 do
    for slot = 1, containerNumSlots(bag) do
      local link = containerItemLink(bag, slot)
      if link then
        local info = itemInfo(link)
        local itemId = itemIdFromLink((info and info.link) or link)
        local dbItem = itemId and knownPetFoodItems[itemId] or nil
        if info and (dbItem or isFoodConsumable(info)) and petFoodCandidateAllowed(dbItem) then
          local normalized, reason = classifyPetFoodItem(info, link)
          local count = containerItemCount(bag, slot) or itemCount(link) or 0
          local foodLevel = dbItem and dbItem.foodLevel or info.itemLevel
          local happinessGain, happinessTier = petFoodHappinessGain(state.petLevel, foodLevel)
          local feedable, feedableReason = petFoodItemFeedable(dbItem)
          candidates[#candidates + 1] = {
            bag = bag,
            slot = slot,
            itemId = itemId,
            link = info.link or link,
            name = info.name or tostring(link),
            count = count,
            icon = dbItem and itemIcon(itemId) or info.icon,
            itemType = info.itemType,
            itemSubType = info.itemSubType,
            foodType = normalized,
            foodTypeReason = reason,
            candidateSource = dbItem and "db" or "api",
            itemLevel = dbItem and dbItem.itemLevel or info.itemLevel,
            requiredLevel = dbItem and dbItem.requiredLevel or info.minLevel,
            foodLevel = foodLevel,
            happinessGain = happinessGain,
            happinessTier = happinessTier,
            feedable = feedable,
            feedableReason = feedableReason,
            raw = dbFoodFlag(dbItem, "raw"),
            prepared = dbFoodFlag(dbItem, "prepared"),
            cookable = dbFoodFlag(dbItem, "cookable"),
            matchesPet = normalized and allowed[normalized] and happinessTier ~= "too-low" and feedable or false,
          }
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    if a.matchesPet ~= b.matchesPet then
      return a.matchesPet
    end
    local aLevel = a.foodLevel or 0
    local bLevel = b.foodLevel or 0
    if aLevel ~= bLevel then
      if preference == "highest" then
        return aLevel > bLevel
      end
      return aLevel < bLevel
    end
    if (a.count or 0) ~= (b.count or 0) then
      return (a.count or 0) > (b.count or 0)
    end
    return tostring(a.name) < tostring(b.name)
  end)

  return candidates
end

local function selectPetFoodCandidate(candidates)
  local matchCount = 0
  local best = nil

  for _, candidate in ipairs(candidates or {}) do
    if candidate.matchesPet then
      matchCount = matchCount + 1
      if not best then
        best = candidate
      end
    end
  end

  state.petFoodBestCandidate = best
  state.petFoodMatchCount = matchCount
  return best, matchCount
end

local function lockedPetFoodCandidate(candidates)
  local itemId = state.petFoodLockItemId
  local untilTime = state.petFoodLockUntil
  if not itemId or not untilTime or not GetTime or GetTime() > untilTime then
    state.petFoodLockItemId = nil
    state.petFoodLockUntil = nil
    return nil
  end

  for _, candidate in ipairs(candidates or {}) do
    if candidate.itemId == itemId and candidate.matchesPet and (candidate.count or 0) > 0 then
      return candidate
    end
  end

  state.petFoodLockItemId = nil
  state.petFoodLockUntil = nil
  return nil
end

local function lockSelectedPetFood()
  local itemId = state.selectedFoodItemId
  if not itemId or InCombatLockdown and InCombatLockdown() then
    return
  end

  state.petFoodLockItemId = itemId
  state.petFoodLockUntil = (GetTime and GetTime() or 0) + PET_FOOD_LOCK_SECONDS
end

local function clearPetFoodLock()
  state.petFoodLockItemId = nil
  state.petFoodLockUntil = nil
end

local function logPetFoodScan()
  updateSnapshot("foodlog")

  local stableIcon, stableName, stableLevel, stableFamily = nil, nil, nil, nil
  if type(GetStablePetInfo) == "function" then
    stableIcon, stableName, stableLevel, stableFamily = GetStablePetInfo(0)
  end

  local unitFamily = type(UnitCreatureFamily) == "function" and UnitCreatureFamily("pet") or nil
  local unitCreatureType = type(UnitCreatureType) == "function" and UnitCreatureType("pet") or nil
  local dbFamily = resolvePetFamily(unitFamily or stableFamily) or resolvePetFamilyFromIcon(stableIcon)
  local dbFamilyDiet = dbFamily and petFoodDB.petFamilies and petFoodDB.petFamilies[dbFamily] or nil

  local dbFamilyCount = 0
  local dbFoodCount = 0
  for _ in pairs(petFoodDB.petFamilies or {}) do
    dbFamilyCount = dbFamilyCount + 1
  end
  for _ in pairs(knownPetFoodItems) do
    dbFoodCount = dbFoodCount + 1
  end

  printMsg(("pet food scan: db families=%d foodItems=%d"):format(dbFamilyCount, dbFoodCount))
  printMsg(("pet food scan: exists=%s dead=%s name=%s level=%s family=%s creature=%s stable=%s/%s"):format(
    tostring(state.petExists),
    tostring(state.petDead),
    shortValue(state.petName),
    shortValue(state.petLevel),
    shortValue(unitFamily or stableFamily),
    shortValue(unitCreatureType),
    shortValue(stableName),
    shortValue(stableLevel)
  ))
  printMsg(("pet food scan: db family=%s diet=%s"):format(shortValue(dbFamily), joinValues(dbFamilyDiet, "none")))

  local rawTypes, normalizedTypes, err = currentPetFoodTypes()
  if err then
    printMsg("pet food scan: food type API error: " .. tostring(err))
  end
  printMsg("pet food scan: raw food types=" .. joinValues(rawTypes, "none"))
  printMsg("pet food scan: normalized food types=" .. joinValues(normalizedTypes, "none"))

  local allowedTypes = (#normalizedTypes > 0 and normalizedTypes) or dbFamilyDiet or {}
  local allowedSource = #normalizedTypes > 0 and "api" or dbFamilyDiet and "db-family" or "none"
  printMsg(("pet food scan: allowed food types=%s source=%s"):format(joinValues(allowedTypes, "none"), allowedSource))
  printMsg(("pet food scan: config preference=%s raw=%s prepared=%s"):format(
    tostring(db().petFood.preference),
    tostring(db().petFood.allowRaw),
    tostring(db().petFood.allowPrepared)
  ))

  local candidates = scanPetFoodCandidates(allowedTypes)
  local bestCandidate, matchCount = selectPetFoodCandidate(candidates)
  printMsg(("pet food scan: bag food candidates=%d matches=%d showing=%d"):format(#candidates, matchCount, math.min(#candidates, 12)))
  if bestCandidate then
    printMsg(("pet food scan: best=%s x%s id=%s bag=%s slot=%s foodType=%s foodLevel=%s gain=%s tier=%s raw=%s prepared=%s cookable=%s feedable=%s feedReason=%s reason=%s"):format(
      shortValue(bestCandidate.link or bestCandidate.name),
      tostring(bestCandidate.count or 0),
      tostring(bestCandidate.itemId or "-"),
      tostring(bestCandidate.bag),
      tostring(bestCandidate.slot),
      shortValue(bestCandidate.foodType),
      tostring(bestCandidate.foodLevel or "-"),
      tostring(bestCandidate.happinessGain or "-"),
      tostring(bestCandidate.happinessTier or "-"),
      tostring(bestCandidate.raw),
      tostring(bestCandidate.prepared),
      tostring(bestCandidate.cookable),
      tostring(bestCandidate.feedable),
      shortValue(bestCandidate.feedableReason),
      shortValue(bestCandidate.foodTypeReason)
    ))
  else
    printMsg("pet food scan: best=none")
  end
  for index = 1, math.min(#candidates, 12) do
    local item = candidates[index]
    printMsg(("%02d %s x%s id=%s bag=%s slot=%s source=%s type=%s subtype=%s level=%s req=%s food=%s gain=%s tier=%s raw=%s prepared=%s cookable=%s feedable=%s feedReason=%s normalized=%s reason=%s match=%s"):format(
      index,
      shortValue(item.link or item.name),
      tostring(item.count or 0),
      tostring(item.itemId or "-"),
      tostring(item.bag),
      tostring(item.slot),
      shortValue(item.candidateSource),
      shortValue(item.itemType),
      shortValue(item.itemSubType),
      tostring(item.itemLevel or "-"),
      tostring(item.requiredLevel or "-"),
      tostring(item.foodLevel or "-"),
      tostring(item.happinessGain or "-"),
      tostring(item.happinessTier or "-"),
      tostring(item.raw),
      tostring(item.prepared),
      tostring(item.cookable),
      tostring(item.feedable),
      shortValue(item.feedableReason),
      shortValue(item.foodType),
      shortValue(item.foodTypeReason),
      tostring(item.matchesPet)
    ))
  end
end

local function refreshAmmoVisual()
  if not ammoDirty then
    return
  end
  local now = GetTime and GetTime() or 0
  if now - lastAmmoUpdate < 0.25 then
    return
  end
  ammoDirty = false
  lastAmmoUpdate = now

  local link, name, icon, count = equippedAmmo()
  local source = "equipped"
  if not link then
    link, name, icon, count = bagAmmo()
    source = link and "bags" or nil
  end
  state.selectedAmmo = link
  state.selectedAmmoName = name
  state.selectedAmmoIcon = icon or "Interface\\Icons\\INV_Ammo_Bullet_02"
  state.selectedAmmoCount = count
  state.selectedAmmoSource = source

  if ui.ammoIcon then
    ui.ammoIcon:SetTexture(state.selectedAmmoIcon)
    if type(ui.ammoIcon.SetDesaturated) == "function" then
      ui.ammoIcon:SetDesaturated(link == nil)
    end
    ui.ammoIcon:SetAlpha(link and 0.9 or 0.32)
  end
  if ui.ammoCount then
    local text = count and count > 0 and tostring(count) or ""
    ui.ammoCount:SetText(text)
    if text ~= "" then
      ui.ammoCount:Show()
    else
      ui.ammoCount:Hide()
    end
  end
  if ui.ammoFrame then
    if link then
      setTooltip(
        ui.ammoFrame,
        L("tooltip.ammoTitle"),
        ("%s: %s\n%s: %s\n%s: %s"):format(
          L("tooltip.selected"),
          tostring(name or link),
          L("tooltip.count"),
          tostring(count or 0),
          L("tooltip.source"),
          source == "equipped" and L("tooltip.equipped") or L("tooltip.bags")
        ),
        link
      )
    else
      setTooltip(ui.ammoFrame, L("tooltip.ammoTitle"), L("tooltip.noAmmo"))
    end
  end
end

local function refreshFoodMacro()
  if not ui.foodButton or InCombatLockdown and InCombatLockdown() then
    return
  end

  local macro = feedPetMacro()
  local icon = spellBook.petFood.icon
  local selectedFood = nil
  local selectedFoodCount = 0
  local tooltipDetail = L("tooltip.noFood")
  local tooltipItem = nil

  local allowedTypes, allowedSource = currentAllowedPetFoodTypes()
  local candidates = scanPetFoodCandidates(allowedTypes)
  local bestCandidate, matchCount = selectPetFoodCandidate(candidates)
  local lockedCandidate = lockedPetFoodCandidate(candidates)
  if lockedCandidate then
    bestCandidate = lockedCandidate
  end
  if bestCandidate then
    selectedFood = bestCandidate.link or bestCandidate.name
    selectedFoodCount = bestCandidate.count or 0
    icon = bestCandidate.icon or itemIcon(bestCandidate.itemId) or icon
    macro = feedPetFoodMacro(bestCandidate)
    tooltipItem = bestCandidate.link or bestCandidate.itemId
    tooltipDetail = table.concat({
      L("tooltip.petFoodDefault"),
      "",
      L("tooltip.selection"),
      L("tooltip.selected") .. ": " .. tostring(bestCandidate.name or bestCandidate.link or "-") .. " x" .. tostring(selectedFoodCount),
      L("tooltip.matches") .. ": " .. tostring(matchCount or 0),
      L("tooltip.preference") .. ": " .. petFoodPreferenceText(db().petFood and db().petFood.preference or defaults.petFood.preference),
      "",
      L("tooltip.pet"),
      L("tooltip.pet") .. ": " .. tostring(state.petName or "-") .. "  " .. L("tooltip.level") .. " " .. tostring(state.petLevel or "-"),
      L("tooltip.diet") .. ": " .. joinValues(allowedTypes, "none") .. " (" .. tostring(allowedSource or "-") .. ")",
      "",
      L("tooltip.food"),
      L("tooltip.foodType") .. ": " .. tostring(bestCandidate.foodType or "-") .. " (" .. tostring(bestCandidate.foodTypeReason or "-") .. ")",
      L("tooltip.foodLevel") .. ": " .. tostring(bestCandidate.foodLevel or "-"),
      L("tooltip.gain") .. ": " .. tostring(bestCandidate.happinessGain or "-") .. "/" .. tostring(bestCandidate.happinessTier or "-"),
      "",
      L("tooltip.flags"),
      L("tooltip.raw") .. ": " .. boolText(bestCandidate.raw) .. "  " .. L("tooltip.prepared") .. ": " .. boolText(bestCandidate.prepared),
      L("tooltip.cookable") .. ": " .. boolText(bestCandidate.cookable) .. "  " .. L("tooltip.feedable") .. ": " .. boolText(bestCandidate.feedable),
      L("tooltip.reason") .. ": " .. tostring(bestCandidate.feedableReason or "-"),
      "",
      L("tooltip.status"),
      L("tooltip.combatLocked") .. ": " .. boolText(lockedDown()),
    }, "\n")
  else
    tooltipDetail = table.concat({
      L("tooltip.noFood"),
      "",
      L("tooltip.pet"),
      L("tooltip.pet") .. ": " .. tostring(state.petName or "-") .. "  " .. L("tooltip.level") .. " " .. tostring(state.petLevel or "-"),
      L("tooltip.diet") .. ": " .. joinValues(allowedTypes, "none") .. " (" .. tostring(allowedSource or "-") .. ")",
      L("tooltip.candidates") .. ": " .. tostring(#candidates),
      "",
      L("tooltip.flags"),
      L("tooltip.rawAllowed") .. ": " .. boolText(db().petFood and db().petFood.allowRaw) .. "  " .. L("tooltip.preparedAllowed") .. ": " .. boolText(db().petFood and db().petFood.allowPrepared),
      L("tooltip.combatLocked") .. ": " .. boolText(lockedDown()),
    }, "\n")
  end

  ui.foodButton:SetAttribute("macrotext", macro)
  ui.foodButton:SetAttribute("macrotext1", macro)
  state.selectedFood = selectedFood
  state.selectedFoodItemId = bestCandidate and bestCandidate.itemId or nil
  state.selectedFoodIcon = icon
  state.selectedFoodCount = selectedFoodCount
  if ui.foodButton.icon then
    ui.foodButton.icon:SetTexture(icon)
    if type(ui.foodButton.icon.SetDesaturated) == "function" then
      ui.foodButton.icon:SetDesaturated(selectedFood == nil)
    end
    ui.foodButton.icon:SetAlpha(selectedFood and 0.9 or 0.6)
  end
  setButtonCount(ui.foodButton, selectedFoodCount)
  setItemCooldown(ui.foodButton, selectedFood)
  setTooltip(ui.foodButton, L("tooltip.petFoodTitle"), tooltipDetail, tooltipItem)
end

local function refreshBandageMacro()
  if not ui.bandageButton then
    return
  end
  refreshBandageVisual()
  if not (InCombatLockdown and InCombatLockdown()) then
    ui.bandageButton:SetAttribute("macrotext1", bandageMacro())
    ui.bandageButton:SetAttribute("macrotext2", petBandageMacro())
  end
end

local function refreshCareMacros()
  if not careMacroDirty then
    return
  end
  if lockedDown() then
    refreshBandageVisual()
    return
  end
  local now = GetTime and GetTime() or 0
  if now - lastCareMacroUpdate < 0.25 then
    return
  end
  careMacroDirty = false
  lastCareMacroUpdate = now
  refreshFoodMacro()
  refreshBandageMacro()
end

local function forceRefreshCareAndAmmo()
  careMacroDirty = true
  ammoDirty = true
  lastCareMacroUpdate = -999
  lastAmmoUpdate = -999
  refreshFoodMacro()
  refreshBandageMacro()
  refreshAmmoVisual()
  if updateVisuals then
    updateVisuals()
  end
end

local function markResourcesDirty(reason, force)
  careMacroDirty = true
  ammoDirty = true
  if force then
    lastCareMacroUpdate = -999
    lastAmmoUpdate = -999
  end

  resourceRefreshSerial = resourceRefreshSerial + 1
  local serial = resourceRefreshSerial
  after(0.05, function()
    if serial == resourceRefreshSerial and refresh then
      refresh(reason or "resources")
    end
  end)
  after(0.45, function()
    if serial == resourceRefreshSerial then
      forceRefreshCareAndAmmo()
    end
  end)
end

local function getRangedSpeed()
  if type(UnitRangedDamage) ~= "function" then
    return nil
  end

  local values = { pcall(UnitRangedDamage, "player") }
  if not values[1] then
    return nil
  end

  for index = 2, #values do
    local value = values[index]
    if type(value) == "number" and value > 0.5 and value < 10 then
      return value
    end
  end

  return nil
end

local function getPetHappiness()
  if type(GetPetHappiness) ~= "function" then
    return nil
  end
  local happiness = safeCall(GetPetHappiness)
  if type(happiness) == "number" then
    return happiness
  end
  return nil
end

local function unitIsDead(unit, health)
  if type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unit) then
    return true
  end
  if type(UnitIsDead) == "function" and UnitIsDead(unit) then
    return true
  end
  return type(health) == "number" and health <= 0
end

local function nowTime()
  return GetTime and GetTime() or 0
end

local function setPetReviveDeadGuard(duration)
  state.petReviveDeadGuardUntil = nowTime() + (duration or 2)
end

local function clearPetReviveDeadGuard()
  state.petRevivePending = false
  state.petReviveDeadGuardUntil = nil
end

local function petReviveDeadGuardActive()
  if not state.petReviveDeadGuardUntil then
    return false
  end
  if nowTime() <= state.petReviveDeadGuardUntil then
    return true
  end
  state.petReviveDeadGuardUntil = nil
  return false
end

local function getAuraName(unit, index)
  if type(UnitAura) == "function" then
    local name = UnitAura(unit, index)
    if name then
      return name
    end
  end
  if type(UnitBuff) == "function" then
    local name = UnitBuff(unit, index)
    if name then
      return name
    end
  end
  return nil
end

local function updateActiveAspect()
  state.activeAspect = nil
  for index = 1, 40 do
    local auraName = getAuraName("player", index)
    if not auraName then
      return
    end
    for _, key in ipairs(db().aspects) do
      if auraName == spellName(key) then
        state.activeAspect = key
        return
      end
    end
  end
end

local function updateRangedSpeed()
  local oldSpeed = state.rangedSpeed
  local newSpeed = getRangedSpeed()
  if oldSpeed and newSpeed and state.autoRepeat and state.autoShotTimerStart and state.autoShotTimerDuration and math.abs(oldSpeed - newSpeed) > 0.03 then
    local now = GetTime and GetTime() or 0
    local elapsed = now - state.autoShotTimerStart
    local progress = math.min(1, math.max(0, elapsed / state.autoShotTimerDuration))
    local start = now - progress * newSpeed
    state.autoShotTimerStart = start
    state.autoShotTimerDuration = newSpeed
    state.autoShotTimerSource = "speed-change"
    state.autoShotPending = false
    state.lastAutoRepeatStart = start
    state.lastAutoShotSource = "speed-change"
  end
  state.lastRangedSpeed = oldSpeed
  state.rangedSpeed = newSpeed
end

local function readAutoShotCooldown()
  if type(GetSpellCooldown) ~= "function" then
    return nil, nil, nil
  end

  local start, duration, enabled = GetSpellCooldown(spellBook.autoShot.id)
  if (not start or start == 0 or not duration or duration == 0) then
    local name = spellName("autoShot")
    if name then
      start, duration, enabled = GetSpellCooldown(name)
    end
  end

  if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0 then
    return start, duration, enabled
  end
  return nil, nil, enabled
end

local function traceAutoShot(kind, data)
  if VenariDebug and type(VenariDebug.TraceAutoShot) == "function" then
    VenariDebug.TraceAutoShot(state, readAutoShotCooldown, kind, data)
  end
end

local function traceAutoShotState(kind, data)
  if VenariDebug and type(VenariDebug.TraceAutoShotState) == "function" then
    VenariDebug.TraceAutoShotState(state, readAutoShotCooldown, kind, data)
  end
end

local function updateAutoShotTimer()
  if not state.autoRepeat then
    traceAutoShotState("timer-clear", { reason = "not-auto-repeat" })
    state.autoShotTimerStart = nil
    state.autoShotTimerDuration = nil
    state.autoShotTimerSource = nil
    state.autoShotPending = false
    state.autoShotArmed = false
    state.autoShotSyncLockUntil = nil
    return
  end

  if not state.lastAutoShot then
    state.autoShotTimerStart = nil
    state.autoShotTimerDuration = nil
    state.autoShotTimerSource = "armed"
    state.autoShotPending = false
    state.autoShotArmed = true
    traceAutoShotState("timer-armed")
    return
  end

  local start, duration, enabled = readAutoShotCooldown()
  local now = GetTime and GetTime() or 0
  if start and duration and enabled ~= 0 then
    local elapsed = now - start
    local shotGuardDuration = math.max(duration, state.rangedSpeed or 0, 0.35)
    local shotGuardActive = state.lastAutoShot and (now - state.lastAutoShot) < shotGuardDuration + 0.15
    local staleAfterShot = shotGuardActive and start < state.lastAutoShot - 0.03
    local stalePending = state.autoShotPending and state.autoShotTimerStart and start <= state.autoShotTimerStart + 0.03
    if elapsed >= 0 and elapsed <= duration + 0.15 and not staleAfterShot and not stalePending then
      state.autoShotTimerStart = start
      state.autoShotTimerDuration = duration
      state.autoShotTimerSource = "cooldown"
      state.autoShotPending = false
      state.autoShotArmed = false
      state.lastAutoRepeatStart = start
      traceAutoShotState("timer-cooldown", { cdStart = start, cdDuration = duration, cdEnabled = enabled })
      return
    elseif staleAfterShot or stalePending then
      traceAutoShot("cooldown-reject", {
        reason = staleAfterShot and "stale-after-shot" or "stale-pending",
        cdStart = start,
        cdDuration = duration,
        cdEnabled = enabled,
      })
    end
  end

  if state.lastAutoRepeatStart and state.rangedSpeed then
    state.autoShotTimerStart = state.lastAutoRepeatStart
    state.autoShotTimerDuration = state.rangedSpeed
    if state.lastAutoShot and state.autoShotTimerStart < state.lastAutoShot - 0.03 then
      state.autoShotTimerStart = state.lastAutoShot
      state.lastAutoRepeatStart = state.lastAutoShot
      state.autoShotTimerSource = "combat-correct"
      state.autoShotPending = false
      state.autoShotArmed = false
      traceAutoShotState("timer-combat-correct")
      return
    end
    if now >= state.autoShotTimerStart + state.autoShotTimerDuration then
      state.autoShotTimerSource = "pending"
      state.autoShotPending = true
      state.autoShotArmed = false
      traceAutoShotState("timer-pending")
    else
      state.autoShotTimerSource = "fallback"
      state.autoShotPending = false
      state.autoShotArmed = false
      traceAutoShotState("timer-fallback")
    end
  else
    state.autoShotTimerStart = nil
    state.autoShotTimerDuration = nil
    state.autoShotTimerSource = nil
    state.autoShotPending = false
    state.autoShotArmed = false
    traceAutoShotState("timer-clear", { reason = "no-anchor" })
  end
end

updateSnapshot = function(event)
  state.lastEvent = event or state.lastEvent
  local autoShotName = spellName("autoShot")
  if type(IsAutoRepeatSpell) == "function" and autoShotName then
    state.autoRepeat = IsAutoRepeatSpell(autoShotName)
  end
  updateRangedSpeed()
  updateAutoShotTimer()
  state.petExists = UnitExists and UnitExists("pet") or false
  state.petName = state.petExists and UnitName and UnitName("pet") or nil
  state.petLevel = state.petExists and UnitLevel and UnitLevel("pet") or nil
  state.petHealth = state.petExists and UnitHealth and UnitHealth("pet") or nil
  state.petHealthMax = state.petExists and UnitHealthMax and UnitHealthMax("pet") or nil
  state.petDead = state.petExists and (unitIsDead("pet", state.petHealth) or petReviveDeadGuardActive()) or false
  state.petHappiness = state.petExists and getPetHappiness() or nil
  updateActiveAspect()
end

local function petHealthPercent()
  if not state.petHealth or not state.petHealthMax or state.petHealthMax <= 0 then
    return nil
  end
  return math.floor((state.petHealth / state.petHealthMax) * 100 + 0.5)
end

local function markAutoShot(source)
  local now = GetTime and GetTime() or nil
  state.lastAutoShot = now
  state.lastAutoShotSource = source
  state.autoShotCount = (state.autoShotCount or 0) + 1
  state.shotPulseStart = now
  state.shotBurstStart = now
  state.autoRepeat = true
  state.autoShotPending = false
  state.autoShotArmed = false
  state.autoShotSyncLockUntil = now and (now + 0.25) or nil

  local start, duration, enabled = readAutoShotCooldown()
  if now and start and duration and enabled ~= 0 and start >= now - 0.03 and start <= now + 0.15 then
    state.autoShotTimerStart = start
    state.autoShotTimerDuration = duration
    state.autoShotTimerSource = "cooldown"
    state.lastAutoRepeatStart = start
    traceAutoShot("combat-shot", { source = source, decision = "cooldown", cdStart = start, cdDuration = duration, cdEnabled = enabled })
  else
    state.lastAutoRepeatStart = now
    state.autoShotTimerStart = now
    state.autoShotTimerDuration = state.rangedSpeed or duration
    state.autoShotTimerSource = "combat-log"
    traceAutoShot("combat-shot", { source = source, decision = "combat-log", cdStart = start, cdDuration = duration, cdEnabled = enabled })
    after(0.05, function()
      updateSnapshot("shot-sync")
      updateVisuals()
    end)
  end
end

local function readCombatLogEvent()
  if type(CombatLogGetCurrentEventInfo) == "function" then
    return CombatLogGetCurrentEventInfo()
  end
  return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function handleCombatLog()
  local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellId, spellNameValue = readCombatLogEvent()
  if not sourceGUID or sourceGUID ~= UnitGUID("player") then
    return false
  end
  if subevent ~= "RANGE_DAMAGE" and subevent ~= "RANGE_MISSED" and subevent ~= "SPELL_DAMAGE" and subevent ~= "SPELL_MISSED" then
    return false
  end

  local autoShotName = spellName("autoShot")
  if spellId == spellBook.autoShot.id or spellNameValue == autoShotName then
    markAutoShot(subevent)
    return true
  end
  return false
end

local function petOrbTexture()
  if not state.petExists then
    return MEDIA .. "orb-nopet"
  end
  if state.petDead then
    return MEDIA .. "orb-dead"
  end
  if state.petHappiness == 1 then
    return MEDIA .. "orb-unhappy"
  end
  if state.petHappiness == 2 then
    return MEDIA .. "orb-neutral"
  end
  return MEDIA .. "orb-happy"
end

local function petStatusText()
  if not state.petExists then
    return L("pet.noPet")
  end
  if state.petDead then
    return L("pet.dead")
  end
  if state.petHappiness == 1 then
    return L("pet.unhappy")
  end
  if state.petHappiness == 2 then
    return L("pet.content")
  end
  if state.petHappiness == 3 then
    return L("pet.happy")
  end
  return L("pet.active")
end

local function autoShotRemaining()
  if not state.autoRepeat or not state.autoShotTimerStart or not state.autoShotTimerDuration then
    return nil
  end
  local elapsed = GetTime() - state.autoShotTimerStart
  local remaining = state.autoShotTimerDuration - elapsed
  if remaining < 0 then
    return 0
  end
  return remaining
end

local function autoShotProgress()
  if not state.autoRepeat or not state.autoShotTimerStart or not state.autoShotTimerDuration then
    return 0
  end
  local elapsed = GetTime() - state.autoShotTimerStart
  return math.min(1, math.max(0, elapsed / state.autoShotTimerDuration))
end

setTooltip = function(button, title, detail, item, spellKey)
  if not button then
    return
  end
  button.tooltipTitle = title
  button.tooltipDetail = detail
  button.tooltipItem = item
  button.tooltipSpellKey = spellKey
end

local function addTooltipLines(text, r, g, b)
  if not GameTooltip or not text then
    return
  end
  local value = tostring(text)
  for line in value:gmatch("([^\n]+)") do
    GameTooltip:AddLine(line, r or 0.75, g or 0.75, b or 0.75, true)
  end
end

local function setTooltipRank(rank)
  if not GameTooltip or not rank or rank == "" then
    return
  end
  local right = _G and _G.GameTooltipTextRight1 or nil
  if right and type(right.SetText) == "function" then
    right:SetText(rank)
    if type(right.SetTextColor) == "function" then
      right:SetTextColor(0.58, 0.58, 0.58)
    end
    if type(right.Show) == "function" then
      right:Show()
    end
    return
  end
  GameTooltip:AddLine(rank, 0.58, 0.58, 0.58, true)
end

local function showNativeSpellTooltip(spellKey)
  if not GameTooltip or not spellKey then
    return false
  end

  local name = spellName(spellKey)
  local slot, bookType, rank = spellBookSlot(name)
  if slot and type(GameTooltip.SetSpellBookItem) == "function" then
    local ok = pcall(GameTooltip.SetSpellBookItem, GameTooltip, slot, bookType)
    if ok then
      setTooltipRank(spellRankText(spellKey, rank))
      return true
    end
  end

  local spellId = spellTooltipId(spellKey)
  if spellId and type(GameTooltip.SetSpellByID) == "function" then
    local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellId)
    if ok then
      local _, spellRank = port.spells.getInfo(spellId)
      setTooltipRank(spellRankText(spellKey, spellRank))
      return true
    end
  end

  if name and type(GameTooltip.SetSpell) == "function" then
    local ok = pcall(GameTooltip.SetSpell, GameTooltip, name)
    if ok then
      setTooltipRank(spellRankText(spellKey, rank))
      return true
    end
  end

  return false
end

local function setGlow(button, active, texture, r, g, b)
  if not button or not button.glow then
    return
  end
  if active then
    button.glow:SetTexture(texture or MEDIA .. "ring-highlight-hunter")
    button.glow:SetVertexColor(r or HUNTER_R, g or HUNTER_G, b or HUNTER_B, 1)
    button.glow:Show()
  else
    button.glow:Hide()
  end
end

local function setAspectActive(button, active)
  if not button then
    return
  end
  setGlow(button, false)
  if button.activeRing then
    if active then
      button.activeRing:Show()
    else
      button.activeRing:Hide()
    end
  end
  if button.icon then
    button.icon:SetAlpha(active and 1 or 0.82)
  end
end

local function commonAspectPrimary()
  local cfg = db()
  return cfg.aspects and cfg.aspects[1] or defaults.aspects[1]
end

local function commonAspectSecondary()
  local cfg = db()
  return cfg.aspects and cfg.aspects[2] or defaults.aspects[2]
end

local function aspectCastMacro(name)
  if not name or name == "" then
    return "/run UIErrorsFrame:AddMessage('" .. L("macro.noSpell") .. "', 1.0, 0.5, 0.0)"
  end
  return "#showtooltip " .. name .. "\n/cast !" .. name
end

local function updateAspectMainButton()
  local button = ui.buttons and ui.buttons.aspectMain
  if not button then
    return
  end

  local primaryKey = commonAspectPrimary()
  local secondaryKey = commonAspectSecondary()
  local leftKey = state.activeAspect == primaryKey and secondaryKey or primaryKey
  local visualKey = (state.activeAspect == primaryKey or state.activeAspect == secondaryKey) and state.activeAspect or leftKey
  local secondaryVisualKey = visualKey == primaryKey and secondaryKey or primaryKey
  if button.icon and spellBook[visualKey] then
    button.icon:SetTexture(spellBook[visualKey].icon)
    button.icon:SetAlpha(0.94)
  end
  if button.secondaryIcon and spellBook[secondaryVisualKey] then
    button.secondaryIcon:SetTexture(spellBook[secondaryVisualKey].icon)
    button.secondaryIcon:SetShown(primaryKey ~= secondaryKey)
  end
  if button.secondaryFrame then
    button.secondaryFrame:SetShown(primaryKey ~= secondaryKey)
  end

  local primaryName = spellName(primaryKey)
  local leftName = spellName(leftKey)
  local secondaryName = spellName(secondaryKey)
  if (leftName or secondaryName) and not (InCombatLockdown and InCombatLockdown()) then
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext", aspectCastMacro(leftName))
    button:SetAttribute("macrotext1", aspectCastMacro(leftName))
    button:SetAttribute("type2", "macro")
    button:SetAttribute("macrotext2", aspectCastMacro(secondaryName))
    button.secureSpellName = leftName
    button.secureAspectRightName = secondaryName
  end

  local visualName = spellName(visualKey) or leftName or primaryName or primaryKey or "Aspect"
  local tooltipLines = {}
  if leftName then
    tooltipLines[#tooltipLines + 1] = L("tooltip.leftClick") .. ": " .. leftName
  end
  if secondaryName then
    tooltipLines[#tooltipLines + 1] = L("tooltip.rightClick") .. ": " .. secondaryName
  end
  setTooltip(button, visualName, #tooltipLines > 0 and table.concat(tooltipLines, "\n") or L("tooltip.commonAspect"), nil, visualKey)
  setGlow(button, false)
end

local function updatePetActionButton()
  local button = ui.center
  if not button or InCombatLockdown and InCombatLockdown() then
    return
  end

  local macro, action = petActionMacroForState()
  if macro and button.securePetAction ~= action then
    button:SetAttribute("macrotext2", macro)
    button.securePetAction = action
  end
  if spellName("revivePet") then
    button:SetAttribute("ctrl-macrotext2", petReviveMacro())
  end
end

local function configureSpellButton(button, spellKey)
  if not button or not spellKey or not spellBook[spellKey] then
    return
  end
  button.spellKey = spellKey
  button.secureSpellName = nil
  if button.icon then
    button.icon:SetTexture(spellBook[spellKey].icon)
  end
  local name = spellName(spellKey)
  if name then
    button:SetAttribute("macrotext", castSpellMacro(name))
    button:SetAttribute("macrotext1", castSpellMacro(name))
    button.secureSpellName = name
    setTooltip(button, name, button.kind == "aspect" and L("tooltip.hunterAspect") or button.kind == "trap" and L("tooltip.hunterTrap") or L("tooltip.hunterUtility"), nil, spellKey)
  end
end

applyConfiguredButtons = function(silent)
  if InCombatLockdown and InCombatLockdown() then
    state.configDirty = true
    if not silent then
      printMsg(L("msg.configAfterCombat"))
    end
    return false
  end

  if ui.buttons.aspectMain then
    local cfg = db()
    configureSpellButton(ui.buttons.trap1, cfg.traps[1])
    configureSpellButton(ui.buttons.trap2, cfg.traps[2])
    configureSpellButton(ui.buttons.trap3, cfg.traps[3])
    configureSpellButton(ui.buttons.trap4, cfg.traps[4])
    state.configDirty = false
    updateActiveAspect()
    updateVisuals()
  end
  return true
end

local function updateSpellButton(button)
  if not button or not button.spellKey then
    return
  end
  local name = spellName(button.spellKey)
  local known = spellKnown(button.spellKey)

  if name and button.secureSpellName ~= name and not (InCombatLockdown and InCombatLockdown()) then
    button:SetAttribute("macrotext", castSpellMacro(name))
    button:SetAttribute("macrotext1", castSpellMacro(name))
    button.secureSpellName = name
    setTooltip(button, name, button.tooltipDetail, nil, button.spellKey)
  end

  local start, duration, enabled = 0, 0, 0
  if name and type(GetSpellCooldown) == "function" then
    start, duration, enabled = GetSpellCooldown(name)
  end
  if button.cooldown and type(CooldownFrame_Set) == "function" then
    CooldownFrame_Set(button.cooldown, start or 0, duration or 0, enabled or 0)
  end
  local usable = known
  if known and name and type(IsUsableSpell) == "function" then
    local ok, noMana = IsUsableSpell(name)
    usable = ok and not noMana
  end
  if button.icon then
    if type(button.icon.SetDesaturated) == "function" then
      button.icon:SetDesaturated(not usable)
    end
    button.icon:SetAlpha(usable and 0.9 or 0.38)
  end
  if not (InCombatLockdown and InCombatLockdown()) then
    button:SetAlpha(usable and 1 or 0.55)
  end
end

local function updateDebugText()
  if not ui.debugText then
    return
  end
  if not db().debug then
    ui.debugText:SetText("")
    ui.debugText:Hide()
    return
  end

  local remaining = autoShotRemaining()
  ui.debugText:SetText(
    ("event=%s\ncombat=%s locked=%s\npet=%s dead=%s happy=%s hp=%s/%s\nauto=%s speed=%s timer=%s pending=%s armed=%s remain=%s count=%s source=%s aspect=%s"):format(
      tostring(state.lastEvent),
      tostring(state.inCombat),
      tostring(db().locked),
      tostring(state.petExists),
      tostring(state.petDead),
      tostring(state.petHappiness),
      tostring(state.petHealth),
      tostring(state.petHealthMax),
      tostring(state.autoRepeat),
      tostring(state.rangedSpeed),
      tostring(state.autoShotTimerSource),
      tostring(state.autoShotPending),
      tostring(state.autoShotArmed),
      remaining and ("%.1f"):format(remaining) or "-",
      tostring(state.autoShotCount),
      tostring(state.lastAutoShotSource),
      tostring(state.activeAspect)
    )
  )
  ui.debugText:Show()
end

updateVisuals = function()
  if not ui.root then
    return
  end

  local cfg = db()
  local lockedDown = InCombatLockdown and InCombatLockdown()
  if cfg.enabled then
    if not ui.root:IsShown() and not lockedDown then
      ui.root:Show()
    end
  else
    if ui.root:IsShown() and not lockedDown then
      ui.root:Hide()
    end
    return
  end

  if ui.orb then
    ui.orb:SetTexture(petOrbTexture())
    if state.petExists and not state.petDead then
      ui.orb:SetAlpha(0)
    else
      ui.orb:SetAlpha(1)
    end
  end
  if ui.petPortrait then
    if state.petExists and not state.petDead and type(SetPortraitTexture) == "function" then
      SetPortraitTexture(ui.petPortrait, "pet")
      ui.petPortrait:SetAlpha(0.92)
      ui.petPortrait:Show()
    else
      ui.petPortrait:Hide()
    end
  end
  if ui.petText then
    ui.petText:SetText("")
  end

  local progress = autoShotProgress()
  local visualLead = 0
  if state.autoRepeat and state.autoShotTimerDuration and state.autoShotTimerDuration > 0 then
    visualLead = math.min(0.08 / state.autoShotTimerDuration, 0.08)
  end
  local visualProgress = math.min(1, progress + visualLead)
  local charge = 0
  if state.autoRepeat then
    charge = math.max(0, math.min(1, (visualProgress - 0.68) / 0.32))
  end
  local segmentCount = #ui.shotRingSegments
  local activeSegments = math.ceil(visualProgress * segmentCount)
  for index, segment in ipairs(ui.shotRingSegments) do
    local whiteHeat = state.autoRepeat and math.max(0, (visualProgress - 0.82) / 0.18) or 0
    if index == 1 and state.autoRepeat then
      local alpha = 0.72 + visualProgress * 0.16 + whiteHeat * 0.12
      segment:SetTexture(MEDIA .. "v4-shot-dot-active")
      segment:SetVertexColor(1, 1, 1, 1)
      segment:SetAlpha(alpha)
      segment:SetSize(11 + whiteHeat * 4, 11 + whiteHeat * 4)
    elseif state.autoRepeat and index <= activeSegments then
      local path = activeSegments > 1 and (index / activeSegments) or 1
      local leadGlow = math.max(0, 1 - (activeSegments - index) / 5)
      local heat = math.max(whiteHeat, path * 0.28 + leadGlow * 0.35)
      segment:SetTexture(MEDIA .. "v4-shot-dot-active")
      segment:SetVertexColor(1, 1, 1, 1)
      segment:SetAlpha(0.46 + heat * 0.5)
      segment:SetSize(11 + leadGlow * 2 + whiteHeat * 2, 11 + leadGlow * 2 + whiteHeat * 2)
    else
      segment:SetTexture(MEDIA .. "v4-shot-dot-bg")
      segment:SetVertexColor(1, 1, 1, 1)
      segment:SetAlpha(0.58 + charge * 0.14)
      segment:SetSize(11, 11)
    end
  end

  if ui.shotLead then
    if state.autoRepeat and segmentCount > 0 and activeSegments > 1 then
      local angle = math.rad((activeSegments - 1) * 360 / segmentCount - 90)
      local radius = SHOT_RING_RADIUS
      local whiteHeat = math.max(0, (visualProgress - 0.8) / 0.2)
      ui.shotLead:ClearAllPoints()
      ui.shotLead:SetPoint("CENTER", ui.root, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
      ui.shotLead:SetVertexColor(1, 1, 1, 1)
      ui.shotLead:SetSize(16 + whiteHeat * 9, 16 + whiteHeat * 9)
      ui.shotLead:SetAlpha(0.65 + whiteHeat * 0.3)
      ui.shotLead:Show()
    else
      ui.shotLead:Hide()
    end
  end

  if ui.shotBurst then
    local now = GetTime and GetTime() or 0
    local burstElapsed = state.shotBurstStart and (now - state.shotBurstStart) or 999
    if burstElapsed >= 0 and burstElapsed < 0.26 then
      local burst = burstElapsed / 0.26
      ui.shotBurst:SetAlpha((1 - burst) * 0.86)
      ui.shotBurst:SetSize(22 + burst * 38, 22 + burst * 38)
      ui.shotBurst:Show()
    else
      ui.shotBurst:Hide()
    end
  end

  if ui.shotCharge then
    ui.shotCharge:Hide()
  end

  if ui.shotPulse then
    local now = GetTime and GetTime() or 0
    local pulseElapsed = state.shotPulseStart and (now - state.shotPulseStart) or 999
    if pulseElapsed >= 0 and pulseElapsed < 0.34 then
      local pulse = pulseElapsed / 0.34
      ui.shotPulse:SetAlpha((1 - pulse) * 0.42)
      ui.shotPulse:SetSize(108 + pulse * 58, 108 + pulse * 58)
      ui.shotPulse:Show()
    else
      ui.shotPulse:Hide()
    end
  end

  local remaining = autoShotRemaining()
  if ui.shotText then
    if remaining then
      ui.shotText:SetText(("%.1f"):format(remaining))
      ui.shotText:SetTextColor(0.72 + charge * 0.2, 0.86 + charge * 0.14, 0.56 + charge * 0.16, 0.78 + charge * 0.22)
    else
      ui.shotText:SetText("-")
      ui.shotText:SetTextColor(0.55, 0.6, 0.52, 1)
    end
  end

  updateAspectMainButton()
  updatePetActionButton()

  for _, button in pairs(ui.buttons) do
    updateSpellButton(button)
    if button.kind == "aspect" then
      setAspectActive(button, state.activeAspect == button.spellKey)
    elseif button.kind == "trap" then
      setGlow(button, false)
    end
  end

  refreshCareMacros()

  if ui.lockOverlay then
    ui.lockOverlay:Hide()
  end
  updateDebugText()
end

local function savePosition()
  if not ui.root then
    return
  end
  local point, _, relativePoint, x, y = ui.root:GetPoint(1)
  local pos = db().position
  pos.point = point or defaults.position.point
  pos.relativePoint = relativePoint or defaults.position.relativePoint
  pos.x = math.floor((x or defaults.position.x) + 0.5)
  pos.y = math.floor((y or defaults.position.y) + 0.5)
end

local function applyPosition()
  if not ui.root then
    return
  end
  local cfg = db()
  local pos = cfg.position
  ui.root:ClearAllPoints()
  ui.root:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
  ui.root:SetScale((cfg.scale or 1) * UI_BASE_SCALE)
end

local function applyLock()
  if not ui.root then
    return
  end
  local locked = db().locked
  ui.root:SetMovable(not locked)
  ui.root:EnableMouse(not locked)
  if locked then
    ui.root:RegisterForDrag()
  else
    ui.root:RegisterForDrag("LeftButton")
  end
  updateVisuals()
end

local function attachTooltip(button)
  button:SetScript("OnEnter", function(self)
    if self.base then
      self.base:SetVertexColor(1.22, 1.22, 1.18, 1)
    end
    if self.icon then
      self.icon:SetAlpha(1)
    end
    if self.hover then
      self.hover:Show()
    end
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local showedNative = showNativeSpellTooltip(self.tooltipSpellKey)
      if not showedNative and self.tooltipItem and GameTooltip.SetHyperlink then
        local item = type(self.tooltipItem) == "number" and ("item:" .. tostring(self.tooltipItem)) or tostring(self.tooltipItem)
        showedNative = pcall(GameTooltip.SetHyperlink, GameTooltip, item)
      end
      if not showedNative then
        GameTooltip:SetText(self.tooltipTitle or self:GetName() or addonName)
      elseif self.tooltipTitle then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.tooltipTitle, 0.86, 0.94, 0.76, true)
      end
      addTooltipLines(self.tooltipDetail, 0.75, 0.75, 0.75)
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function(self)
    if self.base then
      self.base:SetVertexColor(1, 1, 1, 1)
    end
    if self.icon then
      self.icon:SetAlpha(0.9)
    end
    if self.hover then
      self.hover:Hide()
    end
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

shortValue = function(value)
  if value == nil then
    return "nil"
  end
  value = tostring(value)
  value = value:gsub("\n", "\\n")
  if #value > 72 then
    return value:sub(1, 69) .. "..."
  end
  return value
end

local function attachClickDebug(button, label)
  button.VenariDiagLabel = label
  button:SetScript("PostClick", function(self, mouseButton, down)
    if db().clickDebug then
      printMsg(("clicked %s button=%s down=%s type=%s type1=%s type2=%s ctrl-type2=%s"):format(
        tostring(self.VenariDiagLabel),
        tostring(mouseButton),
        tostring(down),
        shortValue(self.GetAttribute and self:GetAttribute("type")),
        shortValue(self.GetAttribute and self:GetAttribute("type1")),
        shortValue(self.GetAttribute and self:GetAttribute("type2")),
        shortValue(self.GetAttribute and self:GetAttribute("ctrl-type2"))
      ))
    end
    if self.VenariPostClick then
      self:VenariPostClick(mouseButton, down)
    end
  end)
end

local function addCircleMask(owner, region, size)
  if not owner or not region or type(region.AddMaskTexture) ~= "function" or type(owner.CreateMaskTexture) ~= "function" then
    return false
  end

  local mask = owner:CreateMaskTexture()
  mask:SetTexture(MEDIA .. "circle-alpha-mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetPoint("CENTER", region, "CENTER")
  mask:SetSize(size, size)

  local ok = pcall(region.AddMaskTexture, region, mask)
  if ok then
    region.VenariCircleMask = mask
    return true
  end
  return false
end

local function skinButton(button, size, iconPath, toolStyle, circularIcon, framed)
  button:SetSize(size, size)
  button:RegisterForClicks("AnyUp", "AnyDown")

  local base = button:CreateTexture(nil, "BACKGROUND")
  base:SetAllPoints()
  if framed then
    base:SetTexture(circularIcon and MEDIA .. "v4-aspect-small-ring" or MEDIA .. "v4-square-slot")
  else
    base:SetTexture(nil)
  end
  button.base = base

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", size * 0.17, -size * 0.17)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -size * 0.17, size * 0.17)
  icon:SetTexture(iconPath)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon
  if circularIcon then
    addCircleMask(button, icon, size * 0.62)
  end

  if circularIcon then
    local activeRing = button:CreateTexture(nil, "OVERLAY", nil, 1)
    activeRing:SetPoint("CENTER")
    activeRing:SetSize(size * 1.06, size * 1.06)
    activeRing:SetTexture(MEDIA .. "v4-aspect-active-ring")
    activeRing:SetBlendMode("ADD")
    activeRing:Hide()
    button.activeRing = activeRing
  end

  local glow = button:CreateTexture(nil, "OVERLAY")
  glow:SetPoint("CENTER")
  glow:SetSize(size * 1.28, size * 1.28)
  glow:SetTexture(MEDIA .. "ring-highlight-hunter")
  glow:Hide()
  button.glow = glow

  local hover = button:CreateTexture(nil, "OVERLAY")
  hover:SetPoint("CENTER")
  hover:SetSize(size * 0.9, size * 0.9)
  hover:SetTexture(MEDIA .. "glow-white")
  hover:SetVertexColor(1.1, 0.86, 0.44, 0.24)
  hover:SetBlendMode("ADD")
  hover:Hide()
  button.hover = hover

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
  cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
  if type(cooldown.SetFrameLevel) == "function" and type(button.GetFrameLevel) == "function" then
    cooldown:SetFrameLevel(button:GetFrameLevel())
  end
  button.cooldown = cooldown

  addCountOverlay(button, button, -6, 5)
  attachTooltip(button)
end

local function skinCareButton(button, texturePath, iconPath)
  button:SetSize(34, 34)
  button:RegisterForClicks("AnyUp", "AnyDown")

  local base = button:CreateTexture(nil, "BACKGROUND")
  base:SetAllPoints()
  base:SetTexture(MEDIA .. "v3-square-button")
  button.base = base

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetSize(21, 21)
  icon:SetTexture(iconPath)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon

  local hover = button:CreateTexture(nil, "OVERLAY")
  hover:SetAllPoints(base)
  hover:SetTexture(MEDIA .. "v3-square-button")
  hover:SetVertexColor(1.35, 1.35, 1.2, 0.22)
  hover:SetBlendMode("ADD")
  hover:Hide()
  button.hover = hover

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
  cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
  if type(cooldown.SetFrameLevel) == "function" and type(button.GetFrameLevel) == "function" then
    cooldown:SetFrameLevel(button:GetFrameLevel())
  end
  button.cooldown = cooldown
  addCountOverlay(button, button, -6, 3)
  attachTooltip(button)
end

local function skinResourceIconButton(button, iconPath)
  button:SetSize(30, 30)
  button:RegisterForClicks("AnyUp", "AnyDown")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetSize(23, 23)
  icon:SetTexture(iconPath)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon

  local hover = button:CreateTexture(nil, "OVERLAY")
  hover:SetPoint("CENTER", button, "CENTER")
  hover:SetSize(28, 28)
  hover:SetTexture(MEDIA .. "glow-white")
  hover:SetVertexColor(1, 0.82, 0.42, 0.24)
  hover:SetBlendMode("ADD")
  hover:Hide()
  button.hover = hover

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
  cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
  if type(cooldown.SetFrameLevel) == "function" and type(button.GetFrameLevel) == "function" then
    cooldown:SetFrameLevel(button:GetFrameLevel())
  end
  button.cooldown = cooldown
  addCountOverlay(button, button, -2, 1)
  attachTooltip(button)
end

local function skinAspectMainButton(button)
  button:SetSize(70, 70)
  button:RegisterForClicks("AnyUp", "AnyDown")

  local base = button:CreateTexture(nil, "BACKGROUND")
  base:SetPoint("CENTER")
  base:SetSize(70, 70)
  base:SetTexture(MEDIA .. "v4-aspect-main-ring")
  button.base = base

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetSize(40, 40)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon
  addCircleMask(button, icon, 40)

  local secondaryFrame = button:CreateTexture(nil, "OVERLAY")
  secondaryFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
  secondaryFrame:SetSize(30, 30)
  secondaryFrame:SetTexture(MEDIA .. "v4-aspect-small-ring")
  button.secondaryFrame = secondaryFrame

  local secondaryIcon = button:CreateTexture(nil, "OVERLAY", nil, 1)
  secondaryIcon:SetPoint("CENTER", secondaryFrame, "CENTER")
  secondaryIcon:SetSize(18, 18)
  secondaryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  secondaryIcon:SetAlpha(0.82)
  button.secondaryIcon = secondaryIcon
  addCircleMask(button, secondaryIcon, 18)

  local glow = button:CreateTexture(nil, "OVERLAY", nil, 2)
  glow:SetPoint("CENTER")
  glow:SetSize(72, 72)
  glow:SetTexture(MEDIA .. "ring-highlight-hunter")
  glow:SetVertexColor(HUNTER_R, HUNTER_G, HUNTER_B, 0.75)
  glow:SetBlendMode("ADD")
  glow:Hide()
  button.glow = glow

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
  cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
  button.cooldown = cooldown
  attachTooltip(button)
end

local function makeAspectMainButton(parent)
  local button = CreateFrame("Button", "VenariAspectMain", parent, "SecureActionButtonTemplate")
  button.kind = "aspectMain"
  skinAspectMainButton(button)
  attachClickDebug(button, "aspect-main")
  return button
end

local function makeSpellButton(parent, name, spellKey, kind, size, iconPath, toolStyle)
  local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  button.spellKey = spellKey
  button.kind = kind
  skinButton(button, size, iconPath or (spellBook[spellKey] and spellBook[spellKey].icon), toolStyle, kind == "aspect", kind == "aspect")
  local name = spellName(spellKey)
  button:SetAttribute("type", "macro")
  button:SetAttribute("macrotext", castSpellMacro(name))
  button:SetAttribute("type1", "macro")
  button:SetAttribute("macrotext1", castSpellMacro(name))
  button.secureSpellName = name
  setTooltip(button, name, kind == "aspect" and L("tooltip.hunterAspect") or kind == "trap" and L("tooltip.hunterTrap") or L("tooltip.hunterUtility"), nil, spellKey)
  attachClickDebug(button, name)
  return button
end

local function makeCenterButton(parent)
  local button = CreateFrame("Button", "VenariPetOrbButton", parent, "SecureActionButtonTemplate")
  button:SetSize(CENTER_SIZE, CENTER_SIZE)
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("type1", "macro")
  button:SetAttribute("macrotext1", petInfoMacro())
  button:SetAttribute("type2", "macro")
  button:SetAttribute("macrotext2", select(1, petActionMacroForState()))
  button:SetAttribute("ctrl-type2", "macro")
  button:SetAttribute("ctrl-macrotext2", petReviveMacro())
  button.securePetAction = select(2, petActionMacroForState())
  button.VenariPostClick = function(_, mouseButton)
    if mouseButton == "RightButton" and schedulePetRefresh then
      if IsControlKeyDown and IsControlKeyDown() and state.petExists and state.petDead then
        state.petRevivePending = true
        setPetReviveDeadGuard(0.5)
      end
      schedulePetRefresh("pet-action-click")
    end
  end
  attachClickDebug(button, "center")

  local shadow = button:CreateTexture(nil, "BACKGROUND")
  shadow:SetPoint("CENTER")
  shadow:SetSize(122, 122)
  shadow:SetTexture(MEDIA .. "v4-center-orb-ring")
  shadow:SetVertexColor(1, 1, 1, 1)
  button.shadow = shadow

  local orb = button:CreateTexture(nil, "ARTWORK")
  orb:SetAllPoints()
  orb:SetTexture(MEDIA .. "orb-nopet")
  ui.orb = orb

  local portrait = button:CreateTexture(nil, "ARTWORK", nil, 1)
  portrait:SetPoint("CENTER")
  portrait:SetSize(52, 52)
  portrait:SetTexCoord(0.17, 0.83, 0.17, 0.83)
  portrait:Hide()
  ui.petPortrait = portrait
  addCircleMask(button, portrait, 52)

  local centerFrame = button:CreateTexture(nil, "OVERLAY", nil, 2)
  centerFrame:SetPoint("CENTER")
  centerFrame:SetSize(122, 122)
  centerFrame:SetTexture(MEDIA .. "v4-center-orb-ring")
  centerFrame:SetVertexColor(1, 1, 1, 1)
  ui.centerFrame = centerFrame

  local hover = button:CreateTexture(nil, "OVERLAY")
  hover:SetAllPoints()
  hover:SetTexture(MEDIA .. "orb-happy")
  hover:SetVertexColor(1.25, 1.25, 1.1, 0.18)
  hover:SetBlendMode("ADD")
  hover:Hide()
  button.hover = hover

  button:SetScript("OnEnter", function(self)
    if self.hover then
      self.hover:Show()
    end
    if self.shadow then
      self.shadow:SetVertexColor(1, 1, 1, 1)
    end
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(state.petName or L("pet.defaultName"))
      if state.petLevel and state.petLevel > 0 then
        GameTooltip:AddLine(L("tooltip.level") .. " " .. tostring(state.petLevel), 0.75, 0.75, 0.75, true)
      end
      GameTooltip:AddLine(L("pet.openInfo"), 0.75, 0.9, 0.65, true)
      GameTooltip:AddLine(L("pet.action"), 0.75, 0.75, 0.75, true)
      GameTooltip:AddLine(petStatusText(), 0.95, 0.95, 0.75, true)
      local hp = petHealthPercent()
      if hp then
        GameTooltip:AddLine(L("pet.health") .. ": " .. tostring(hp) .. "%", 0.75, 0.95, 0.75, true)
      end
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function(self)
    if self.hover then
      self.hover:Hide()
    end
    if self.shadow then
      self.shadow:SetVertexColor(1, 1, 1, 1)
    end
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return button
end

local function createRing(parent)
  local count = 36
  local radius = SHOT_RING_RADIUS
  for index = 1, count do
    local angle = math.rad((index - 1) * 360 / count - 90)
    local segment = parent:CreateTexture(nil, "OVERLAY")
    segment:SetSize(11, 11)
    segment:SetPoint("CENTER", parent, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    segment:SetTexture(MEDIA .. "v4-shot-dot-bg")
    segment:SetVertexColor(1, 1, 1, 1)
    segment:SetAlpha(0.62)
    ui.shotRingSegments[index] = segment
  end

  local lead = parent:CreateTexture(nil, "OVERLAY")
  lead:SetTexture(MEDIA .. "glow-white")
  lead:SetBlendMode("ADD")
  lead:SetVertexColor(1, 1, 1, 1)
  lead:SetSize(16, 16)
  lead:SetPoint("CENTER", parent, "CENTER", 0, -radius)
  lead:Hide()
  ui.shotLead = lead

  local burst = parent:CreateTexture(nil, "OVERLAY")
  burst:SetTexture(MEDIA .. "glow-white")
  burst:SetBlendMode("ADD")
  burst:SetVertexColor(1, 1, 0.86, 1)
  burst:SetSize(22, 22)
  burst:SetPoint("CENTER", parent, "CENTER", 0, -radius)
  burst:Hide()
  ui.shotBurst = burst
end

local function place(button, parent, x, y)
  button:SetPoint("CENTER", parent, "CENTER", x, y)
end

local function setAspectDrawerOpen(open)
  if InCombatLockdown and InCombatLockdown() then
    state.aspectDrawerOpen = false
    if ui.aspectDrawerArrow then
      ui.aspectDrawerArrow:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      ui.aspectDrawerArrow:SetAlpha(0.74)
    end
    return false
  end
  state.aspectDrawerOpen = open and true or false

  if ui.aspectDrawer then
    if state.aspectDrawerOpen then
      ui.aspectDrawer:Show()
    else
      ui.aspectDrawer:Hide()
    end
  end

  if ui.aspectDrawerArrow then
    if state.aspectDrawerOpen then
      ui.aspectDrawerArrow:SetTexCoord(0.08, 0.92, 0.92, 0.08)
      ui.aspectDrawerArrow:SetAlpha(1)
    else
      ui.aspectDrawerArrow:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      ui.aspectDrawerArrow:SetAlpha(0.74)
    end
  end
  return true
end

local function toggleAspectDrawer()
  if InCombatLockdown and InCombatLockdown() then
    printMsg(L("msg.aspectDrawerCombat"))
    return
  end
  setAspectDrawerOpen(not state.aspectDrawerOpen)
end

local function createUI()
  if ui.root then
    return
  end

  local root = CreateFrame("Frame", "VenariFrame", UIParent)
  root:SetSize(390, 260)
  root:SetClampedToScreen(true)
  root:SetFrameStrata("MEDIUM")
  root:SetScript("OnDragStart", function(self)
    if not db().locked then
      self:StartMoving()
    end
  end)
  root:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition()
    printMsg(("position saved: %s %s %d %d"):format(
      db().position.point,
      db().position.relativePoint,
      db().position.x,
      db().position.y
    ))
  end)

  ui.lockOverlay = nil

  local resourceBar = root:CreateTexture(nil, "BACKGROUND")
  resourceBar:SetPoint("CENTER", root, "CENTER", 0, 98)
  resourceBar:SetSize(220, 50)
  resourceBar:SetTexture(MEDIA .. "v4-resource-bar")
  ui.resourceBar = resourceBar

  local trapPanel = root:CreateTexture(nil, "BACKGROUND")
  trapPanel:SetPoint("CENTER", root, "CENTER", 132, -4)
  trapPanel:SetSize(118, 118)
  trapPanel:SetTexture(MEDIA .. "v4-trap-panel")
  ui.trapPanel = trapPanel

  local toolPanel = root:CreateTexture(nil, "BACKGROUND")
  toolPanel:SetPoint("CENTER", root, "CENTER", 0, -100)
  toolPanel:SetSize(238, 52)
  toolPanel:SetTexture(MEDIA .. "v4-tool-bar")
  ui.toolPanel = toolPanel

  createRing(root)

  local shotCharge = root:CreateTexture(nil, "ARTWORK")
  shotCharge:SetPoint("CENTER", root, "CENTER", 0, 0)
  shotCharge:SetSize(122, 122)
  shotCharge:SetTexture(MEDIA .. "ring-highlight-hunter")
  shotCharge:SetVertexColor(HUNTER_R, HUNTER_G, HUNTER_B, 1)
  shotCharge:SetBlendMode("ADD")
  shotCharge:Hide()
  ui.shotCharge = shotCharge

  local shotPulse = root:CreateTexture(nil, "OVERLAY")
  shotPulse:SetPoint("CENTER", root, "CENTER", 0, 0)
  shotPulse:SetSize(108, 108)
  shotPulse:SetTexture(MEDIA .. "ring-highlight-hunter")
  shotPulse:SetVertexColor(0.82, 1, 0.58, 1)
  shotPulse:SetBlendMode("ADD")
  shotPulse:Hide()
  ui.shotPulse = shotPulse

  local center = makeCenterButton(root)
  center:SetPoint("CENTER", root, "CENTER", 0, 0)
  ui.center = center

  local shotText = root:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  shotText:SetPoint("CENTER", root, "CENTER", 0, -52)
  shotText:SetText("-")
  shotText:Hide()
  ui.shotText = shotText

  local petText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  petText:SetPoint("TOP", center, "BOTTOM", 0, -5)
  petText:SetTextColor(0.76, 0.92, 0.56, 1)
  ui.petText = petText

  local food = CreateFrame("Button", "VenariCareFood", root, "SecureActionButtonTemplate")
  skinResourceIconButton(food, spellBook.petFood.icon)
  food:SetAttribute("type1", "macro")
  food:SetAttribute("type", "macro")
  food:SetAttribute("macrotext", feedPetMacro())
  food:SetAttribute("macrotext1", feedPetMacro())
  food:SetPoint("CENTER", root, "CENTER", -77, 98)
  setTooltip(food, L("tooltip.petFoodTitle"), L("tooltip.petFoodDefault"))
  attachClickDebug(food, "food")
  food.VenariPostClick = function(_, mouseButton, down)
    if mouseButton == "LeftButton" and not down then
      lockSelectedPetFood()
    end
  end
  ui.foodButton = food

  local bandage = CreateFrame("Button", "VenariCareBandage", root, "SecureActionButtonTemplate")
  skinResourceIconButton(bandage, spellBook.bandage.icon)
  bandage:SetAttribute("type1", "macro")
  bandage:SetAttribute("macrotext1", bandageMacro())
  bandage:SetAttribute("type2", "macro")
  bandage:SetAttribute("macrotext2", petBandageMacro())
  bandage:SetPoint("CENTER", root, "CENTER", 26, 98)
  setTooltip(bandage, L("tooltip.bandageTitle"), L("tooltip.bandageDefault"))
  attachClickDebug(bandage, "bandage")
  ui.bandageButton = bandage

  local ammoFrame = CreateFrame("Frame", "VenariAmmoFrame", root)
  ammoFrame:SetSize(30, 30)
  ammoFrame:SetPoint("CENTER", root, "CENTER", 77, 98)
  ammoFrame:EnableMouse(true)
  attachTooltip(ammoFrame)
  ui.ammoFrame = ammoFrame

  local ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
  ammoIcon:SetPoint("CENTER", ammoFrame, "CENTER", 0, 0)
  ammoIcon:SetSize(23, 23)
  ammoIcon:SetTexture("Interface\\Icons\\INV_Ammo_Bullet_02")
  ammoIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ammoIcon:SetAlpha(0.32)
  ui.ammoIcon = ammoIcon

  local ammoCountFrame = CreateFrame("Frame", nil, ammoFrame)
  ammoCountFrame:SetAllPoints(ammoFrame)
  if ammoFrame.GetFrameLevel and ammoCountFrame.SetFrameLevel then
    ammoCountFrame:SetFrameLevel((ammoFrame:GetFrameLevel() or 0) + 10)
  end
  local ammoCount = ammoCountFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  ammoCount:SetPoint("BOTTOMRIGHT", ammoFrame, "BOTTOMRIGHT", -1, 1)
  ammoCount:SetJustifyH("RIGHT")
  ammoCount:SetSize(30, 12)
  ammoCount:SetText("")
  ammoCount:SetTextColor(1, 0.95, 0.58, 1)
  ammoCount:SetShadowColor(0, 0, 0, 1)
  ammoCount:SetShadowOffset(1, -1)
  ammoCount:Hide()
  ui.ammoCount = ammoCount

  local buttons = ui.buttons
  buttons.aspectMain = makeAspectMainButton(root)
  buttons.trap1 = makeSpellButton(root, "VenariTrap1", db().traps[1], "trap", 44, spellBook[db().traps[1]].icon)
  buttons.trap2 = makeSpellButton(root, "VenariTrap2", db().traps[2], "trap", 44, spellBook[db().traps[2]].icon)
  buttons.trap3 = makeSpellButton(root, "VenariTrap3", db().traps[3], "trap", 44, spellBook[db().traps[3]].icon)
  buttons.trap4 = makeSpellButton(root, "VenariTrap4", db().traps[4], "trap", 44, spellBook[db().traps[4]].icon)

  place(buttons.aspectMain, root, -110, 8)
  place(buttons.trap1, root, 108, 20)
  place(buttons.trap2, root, 156, 20)
  place(buttons.trap3, root, 108, -28)
  place(buttons.trap4, root, 156, -28)

  local aspectDrawerToggle = CreateFrame("Button", "VenariAspectDrawerToggle", root)
  aspectDrawerToggle:SetSize(34, 34)
  aspectDrawerToggle:SetPoint("CENTER", root, "CENTER", -110, -54)
  aspectDrawerToggle:RegisterForClicks("LeftButtonUp")
  aspectDrawerToggle:SetScript("OnClick", toggleAspectDrawer)
  local aspectDrawerToggleBase = aspectDrawerToggle:CreateTexture(nil, "BACKGROUND")
  aspectDrawerToggleBase:SetAllPoints()
  aspectDrawerToggleBase:SetTexture(MEDIA .. "v4-aspect-small-ring")
  aspectDrawerToggleBase:SetVertexColor(1, 1, 1, 1)
  local aspectDrawerArrow = aspectDrawerToggle:CreateTexture(nil, "ARTWORK")
  aspectDrawerArrow:SetPoint("CENTER")
  aspectDrawerArrow:SetSize(14, 14)
  aspectDrawerArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  aspectDrawerArrow:SetVertexColor(HUNTER_R, HUNTER_G, HUNTER_B, 1)
  aspectDrawerArrow:SetAlpha(0.74)
  ui.aspectDrawerArrow = aspectDrawerArrow
  setTooltip(aspectDrawerToggle, L("tooltip.aspects"), L("tooltip.aspectDrawer"))
  attachTooltip(aspectDrawerToggle)

  local aspectDrawer = CreateFrame("Frame", "VenariAspectDrawer", root)
  aspectDrawer:SetSize(64, 372)
  aspectDrawer:SetPoint("CENTER", root, "CENTER", -176, 113)
  local aspectDrawerBg = aspectDrawer:CreateTexture(nil, "BACKGROUND")
  aspectDrawerBg:SetAllPoints()
  aspectDrawerBg:SetTexture(nil)
  ui.aspectDrawer = aspectDrawer
  ui.aspectDrawerButtons = {}
  local drawerPositions = {
    { 0, 156 },
    { 0, 104 },
    { 0, 52 },
    { 0, 0 },
    { 0, -52 },
    { 0, -104 },
    { 0, -156 },
  }
  for index, aspectKey in ipairs(aspectOptions) do
    local button = makeSpellButton(aspectDrawer, "VenariAspectDrawer" .. index, aspectKey, "aspect", 56, spellBook[aspectKey].icon)
    local pos = drawerPositions[index]
    place(button, aspectDrawer, pos[1], pos[2])
    buttons["aspectDrawer" .. index] = button
    ui.aspectDrawerButtons[index] = button
  end
  aspectDrawer:Hide()

  buttons.eagleEye = makeSpellButton(root, "VenariToolEagleEye", "eagleEye", "tool", 40, spellBook.eagleEye.icon, true)
  buttons.scareBeast = makeSpellButton(root, "VenariToolScareBeast", "scareBeast", "tool", 40, spellBook.scareBeast.icon, true)
  buttons.flare = makeSpellButton(root, "VenariToolFlare", "flare", "tool", 40, spellBook.flare.icon, true)
  buttons.beastLore = makeSpellButton(root, "VenariToolBeastLore", "beastLore", "tool", 40, spellBook.beastLore.icon, true)
  buttons.tameBeast = makeSpellButton(root, "VenariToolTameBeast", "tameBeast", "tool", 40, spellBook.tameBeast.icon, true)

  place(buttons.eagleEye, root, -77, -100)
  place(buttons.scareBeast, root, -39, -100)
  place(buttons.flare, root, 0, -100)
  place(buttons.beastLore, root, 39, -100)
  place(buttons.tameBeast, root, 77, -100)

  local debugText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  debugText:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -8)
  debugText:SetJustifyH("LEFT")
  debugText:SetTextColor(0.75, 0.9, 0.65, 1)
  debugText:Hide()
  ui.debugText = debugText

  ui.root = root
  applyPosition()
  applyLock()
end

local function configGroupOptions(group)
  return group == "aspects" and aspectOptions or trapOptions
end

local function configSlotLabel(group, slot)
  return (group == "aspects" and "Aspect " or "Trap ") .. tostring(slot)
end

local function petFoodPreferenceLabel(value)
  for _, option in ipairs(petFoodPreferenceOptions) do
    if option.key == value then
      return option.label
    end
  end
  return petFoodPreferenceOptions[1].label
end

local refreshConfigPanel

local function clampScale(value)
  value = tonumber(value) or defaults.scale
  return math.max(0.7, math.min(1.4, value))
end

local function scalePercent(value)
  return tostring(math.floor((clampScale(value) * 100) + 0.5)) .. "%"
end

local function setConfiguredScale(value, silent)
  local cfg = db()
  cfg.scale = clampScale(value)
  if InCombatLockdown and InCombatLockdown() then
    state.scaleDirty = true
    if not silent then
      printMsg(L("msg.scaleAfterCombat"))
    end
  else
    state.scaleDirty = false
    applyPosition()
  end
  refreshConfigPanel()
end

local function captureConfigSnapshot()
  local cfg = db()
  ui.configSnapshot = {
    scale = cfg.scale or defaults.scale,
    aspects = { cfg.aspects[1], cfg.aspects[2] },
    traps = { cfg.traps[1], cfg.traps[2], cfg.traps[3], cfg.traps[4] },
    petFood = {
      preference = cfg.petFood.preference,
      allowRaw = cfg.petFood.allowRaw,
      allowPrepared = cfg.petFood.allowPrepared,
    },
  }
end

local function restoreConfigSnapshot()
  if not ui.configSnapshot then
    return false
  end
  local cfg = db()
  cfg.scale = ui.configSnapshot.scale or defaults.scale
  cfg.aspects = {
    ui.configSnapshot.aspects[1] or defaults.aspects[1],
    ui.configSnapshot.aspects[2] or defaults.aspects[2],
  }
  cfg.traps = {
    ui.configSnapshot.traps[1] or defaults.traps[1],
    ui.configSnapshot.traps[2] or defaults.traps[2],
    ui.configSnapshot.traps[3] or defaults.traps[3],
    ui.configSnapshot.traps[4] or defaults.traps[4],
  }
  cfg.petFood = {
    preference = ui.configSnapshot.petFood and ui.configSnapshot.petFood.preference or defaults.petFood.preference,
    allowRaw = ui.configSnapshot.petFood and ui.configSnapshot.petFood.allowRaw ~= false,
    allowPrepared = ui.configSnapshot.petFood and ui.configSnapshot.petFood.allowPrepared ~= false,
  }
  careMacroDirty = true
  return true
end

local function closeConfigFrame()
  if InCombatLockdown and InCombatLockdown() then
    if restoreConfigSnapshot() then
      state.configDirty = true
      state.scaleDirty = true
      refreshConfigPanel()
      printMsg(L("msg.configDiscarded"))
    end
  else
    ui.configSnapshot = nil
  end
  if ui.configFrame then
    ui.configFrame:Hide()
  end
end

refreshConfigPanel = function()
  if not ui.configFrame or not ui.configDropdowns then
    return
  end

  local cfg = db()
  for _, dropdown in ipairs(ui.configDropdowns) do
    local key = cfg[dropdown.configGroup] and cfg[dropdown.configGroup][dropdown.configSlot]
    local name = spellName(key) or key or "-"
    if UIDropDownMenu_SetText then
      UIDropDownMenu_SetText(dropdown, name)
    end
  end

  if ui.configScaleValue then
    ui.configScaleValue:SetText(scalePercent(cfg.scale or defaults.scale))
  end
  if ui.configScaleFill then
    local sliderWidth = ui.configScaleSlider and ui.configScaleSlider:GetWidth() or 185
    local amount = (clampScale(cfg.scale or defaults.scale) - 0.7) / 0.7
    ui.configScaleFill:SetWidth(math.max(1, sliderWidth * amount))
  end
  if ui.configScaleSlider and not ui.configScaleSlider.VenariUpdating then
    ui.configScaleSlider.VenariUpdating = true
    ui.configScaleSlider:SetValue(clampScale(cfg.scale or defaults.scale))
    ui.configScaleSlider.VenariUpdating = false
  end
  if ui.configFoodPreferenceDropdown and UIDropDownMenu_SetText then
    UIDropDownMenu_SetText(ui.configFoodPreferenceDropdown, petFoodPreferenceLabel(cfg.petFood.preference))
  end
  if ui.configAllowRaw then
    ui.configAllowRaw:SetChecked(cfg.petFood.allowRaw ~= false)
  end
  if ui.configAllowPrepared then
    ui.configAllowPrepared:SetChecked(cfg.petFood.allowPrepared ~= false)
  end

  if ui.configStatus then
    if InCombatLockdown and InCombatLockdown() then
      ui.configStatus:SetText(L("config.combatSaved"))
      ui.configStatus:SetTextColor(0.95, 0.78, 0.42, 1)
    else
      ui.configStatus:SetText(L("config.ready"))
      ui.configStatus:SetTextColor(0.62, 0.68, 0.6, 1)
    end
  end
end

local function setConfiguredSlot(group, slot, key)
  local options = configGroupOptions(group)
  if not optionContains(options, key) then
    return
  end

  local cfg = db()
  cfg[group][slot] = key
  applyConfiguredButtons()
  refreshConfigPanel()
end

local function setPetFoodPreference(value)
  if value ~= "lowest" and value ~= "highest" then
    return
  end
  clearPetFoodLock()
  db().petFood.preference = value
  careMacroDirty = true
  refreshConfigPanel()
  refresh("pet-food-config")
end

local function setPetFoodFlag(key, value)
  if key ~= "allowRaw" and key ~= "allowPrepared" then
    return
  end
  clearPetFoodLock()
  db().petFood[key] = value and true or false
  careMacroDirty = true
  refreshConfigPanel()
  refresh("pet-food-config")
end

local function initializeConfigDropdown(dropdown, level)
  local group = dropdown.configGroup
  local slot = dropdown.configSlot
  local cfg = db()
  local current = cfg[group] and cfg[group][slot]
  local shown = 0

  for _, key in ipairs(configGroupOptions(group)) do
    if spellKnown(key) or key == current then
      local info = UIDropDownMenu_CreateInfo()
      info.text = spellName(key) or key
      info.value = key
      info.checked = key == current
      info.disabled = not spellKnown(key)
      info.func = function(self)
        setConfiguredSlot(group, slot, self.value)
      end
      UIDropDownMenu_AddButton(info, level)
      shown = shown + 1
    end
  end

  if shown == 0 then
    local info = UIDropDownMenu_CreateInfo()
    info.text = L("config.noKnownSpells")
    info.disabled = true
    UIDropDownMenu_AddButton(info, level)
  end
end

local function initializeFoodPreferenceDropdown(_, level)
  local current = db().petFood.preference
  for _, option in ipairs(petFoodPreferenceOptions) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = option.label
    info.value = option.key
    info.checked = option.key == current
    info.func = function(self)
      setPetFoodPreference(self.value)
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

local function makeConfigDropdown(parent, name, group, slot, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
  label:SetSize(78, 18)
  label:SetJustifyH("LEFT")
  label:SetText(configSlotLabel(group, slot))
  label:SetTextColor(0.78, 0.86, 0.72, 1)

  local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 82, y + 2)
  dropdown.configGroup = group
  dropdown.configSlot = slot
  UIDropDownMenu_SetWidth(dropdown, 166)
  UIDropDownMenu_Initialize(dropdown, initializeConfigDropdown)

  ui.configDropdowns[#ui.configDropdowns + 1] = dropdown
  return dropdown
end

local function makeConfigCheckbox(parent, name, labelText, key, x, y)
  local button = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  button:SetSize(24, 24)
  local label = _G[name .. "Text"]
  if label then
    label:SetText(labelText)
    label:SetTextColor(0.78, 0.86, 0.72, 1)
  end
  button:SetScript("OnClick", function(self)
    setPetFoodFlag(key, self:GetChecked())
  end)
  return button
end

local function makeConfigDivider(parent, x, y, width)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  line:SetSize(width, 1)
  setSolidTexture(line, 0.45, 0.52, 0.38, 0.22)
  return line
end

local function createConfigFrame()
  if ui.configFrame then
    return
  end

  local frame = CreateFrame("Frame", "VenariConfigFrame", UIParent)
  frame:SetSize(620, 390)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  setSolidTexture(bg, 0.022, 0.024, 0.021, 0.97)

  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  setSolidTexture(border, 0.56, 0.64, 0.46, 0.08)

  local header = frame:CreateTexture(nil, "BORDER")
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  header:SetSize(1, 52)
  setSolidTexture(header, 0.06, 0.07, 0.055, 0.86)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
  title:SetText(L("config.title"))
  title:SetTextColor(0.86, 0.94, 0.76, 1)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", closeConfigFrame)

  local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  note:SetPoint("RIGHT", close, "LEFT", -10, 0)
  note:SetJustifyH("LEFT")
  note:SetText(L("config.note"))
  note:SetTextColor(0.62, 0.68, 0.6, 1)

  local aspectTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  aspectTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -72)
  aspectTitle:SetText(L("config.aspects"))
  aspectTitle:SetTextColor(0.86, 0.94, 0.76, 1)

  local trapTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  trapTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 332, -72)
  trapTitle:SetText(L("config.traps"))
  trapTitle:SetTextColor(0.86, 0.94, 0.76, 1)

  makeConfigDivider(frame, 28, -96, 260)
  makeConfigDivider(frame, 332, -96, 260)

  ui.configDropdowns = {}
  makeConfigDropdown(frame, "VenariAspectDropdown1", "aspects", 1, 28, -112)
  makeConfigDropdown(frame, "VenariAspectDropdown2", "aspects", 2, 28, -152)
  makeConfigDropdown(frame, "VenariTrapDropdown1", "traps", 1, 332, -112)
  makeConfigDropdown(frame, "VenariTrapDropdown2", "traps", 2, 332, -152)
  makeConfigDropdown(frame, "VenariTrapDropdown3", "traps", 3, 332, -192)
  makeConfigDropdown(frame, "VenariTrapDropdown4", "traps", 4, 332, -232)

  local scaleTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scaleTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -218)
  scaleTitle:SetText(L("config.hudScale"))
  scaleTitle:SetTextColor(0.86, 0.94, 0.76, 1)

  local scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  scaleValue:SetPoint("LEFT", scaleTitle, "RIGHT", 24, 0)
  scaleValue:SetTextColor(1, 0.95, 0.58, 1)
  scaleValue:SetText(scalePercent(db().scale or defaults.scale))
  ui.configScaleValue = scaleValue

  local scaleSlider = CreateFrame("Slider", "VenariScaleSlider", frame, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -254)
  scaleSlider:SetWidth(185)
  scaleSlider:SetMinMaxValues(0.7, 1.4)
  scaleSlider:SetValueStep(0.05)
  if scaleSlider.SetObeyStepOnDrag then
    scaleSlider:SetObeyStepOnDrag(true)
  end
  scaleSlider:SetValue(clampScale(db().scale or defaults.scale))
  if _G.VenariScaleSliderLow then
    _G.VenariScaleSliderLow:SetText("70%")
  end
  if _G.VenariScaleSliderHigh then
    _G.VenariScaleSliderHigh:SetText("140%")
  end
  if _G.VenariScaleSliderText then
    _G.VenariScaleSliderText:SetText("")
  end

  local scaleTrack = frame:CreateTexture(nil, "ARTWORK")
  scaleTrack:SetPoint("LEFT", scaleSlider, "LEFT", 0, 0)
  scaleTrack:SetSize(185, 6)
  setSolidTexture(scaleTrack, 0.12, 0.13, 0.1, 0.95)
  ui.configScaleTrack = scaleTrack

  local scaleFill = frame:CreateTexture(nil, "OVERLAY")
  scaleFill:SetPoint("LEFT", scaleTrack, "LEFT", 0, 0)
  scaleFill:SetSize(1, 6)
  setSolidTexture(scaleFill, HUNTER_R, HUNTER_G, HUNTER_B, 0.9)
  ui.configScaleFill = scaleFill

  local scaleLeftCap = frame:CreateTexture(nil, "OVERLAY")
  scaleLeftCap:SetPoint("CENTER", scaleTrack, "LEFT", 0, 0)
  scaleLeftCap:SetSize(3, 14)
  setSolidTexture(scaleLeftCap, 0.76, 0.67, 0.42, 1)

  local scaleRightCap = frame:CreateTexture(nil, "OVERLAY")
  scaleRightCap:SetPoint("CENTER", scaleTrack, "RIGHT", 0, 0)
  scaleRightCap:SetSize(3, 14)
  setSolidTexture(scaleRightCap, 0.76, 0.67, 0.42, 1)

  scaleSlider:SetScript("OnValueChanged", function(self, value)
    if self.VenariUpdating then
      return
    end
    local stepped = math.floor((value / 0.05) + 0.5) * 0.05
    setConfiguredScale(stepped, true)
  end)
  ui.configScaleSlider = scaleSlider

  local foodTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  foodTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 332, -258)
  foodTitle:SetText(L("config.petFood"))
  foodTitle:SetTextColor(0.86, 0.94, 0.76, 1)

  local foodPreferenceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  foodPreferenceLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 332, -286)
  foodPreferenceLabel:SetSize(78, 18)
  foodPreferenceLabel:SetJustifyH("LEFT")
  foodPreferenceLabel:SetText(L("config.preference"))
  foodPreferenceLabel:SetTextColor(0.78, 0.86, 0.72, 1)

  local foodPreference = CreateFrame("Frame", "VenariFoodPreferenceDropdown", frame, "UIDropDownMenuTemplate")
  foodPreference:SetPoint("TOPLEFT", frame, "TOPLEFT", 414, -278)
  UIDropDownMenu_SetWidth(foodPreference, 166)
  UIDropDownMenu_Initialize(foodPreference, initializeFoodPreferenceDropdown)
  ui.configFoodPreferenceDropdown = foodPreference

  ui.configAllowRaw = makeConfigCheckbox(frame, "VenariAllowRawFood", L("config.raw"), "allowRaw", 332, -320)
  ui.configAllowPrepared = makeConfigCheckbox(frame, "VenariAllowPreparedFood", L("config.prepared"), "allowPrepared", 420, -320)

  local footer = frame:CreateTexture(nil, "BORDER")
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
  footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  footer:SetSize(1, 43)
  setSolidTexture(footer, 0.035, 0.04, 0.032, 0.72)

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("LEFT", frame, "BOTTOMLEFT", 18, 22)
  status:SetSize(370, 18)
  status:SetJustifyH("LEFT")
  status:SetTextColor(0.62, 0.68, 0.6, 1)
  status:SetText(L("config.ready"))
  ui.configStatus = status

  local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  reset:SetSize(82, 22)
  reset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -104, 12)
  reset:SetText(L("config.reset"))
  reset:SetScript("OnClick", function()
    local cfg = db()
    cfg.aspects = { defaults.aspects[1], defaults.aspects[2] }
    cfg.traps = { defaults.traps[1], defaults.traps[2], defaults.traps[3], defaults.traps[4] }
    cfg.petFood = {
      preference = defaults.petFood.preference,
      allowRaw = defaults.petFood.allowRaw,
      allowPrepared = defaults.petFood.allowPrepared,
    }
    careMacroDirty = true
    setConfiguredScale(defaults.scale, true)
    applyConfiguredButtons()
    refresh("pet-food-reset")
    refreshConfigPanel()
  end)

  local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  done:SetSize(82, 22)
  done:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  done:SetText(L("config.done"))
  done:SetScript("OnClick", closeConfigFrame)

  frame:Hide()
  ui.configFrame = frame
end

local function toggleConfigFrame()
  createConfigFrame()
  refreshConfigPanel()
  if ui.configFrame:IsShown() then
    closeConfigFrame()
  else
    captureConfigSnapshot()
    ui.configFrame:Show()
    refreshConfigPanel()
  end
end

refresh = function(event)
  updateSnapshot(event)
  refreshAmmoVisual()
  updateVisuals()
end

local function isRevivePetSpell(unit, ...)
  if unit and unit ~= "player" then
    return false
  end

  local reviveName = spellName("revivePet")
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value == spellBook.revivePet.id or (reviveName and value == reviveName) then
      return true
    end
  end

  return false
end

schedulePetRefresh = function(reason)
  local function run(delay)
    after(delay, function()
      careMacroDirty = true
      if refresh then
        refresh(reason or "pet-refresh")
      end
    end)
  end

  run(0.1)
  run(0.6)
  run(1.2)
end

local tickerElapsed = 0
local eventFrame = CreateFrame("Frame")

local function registerEvent(frame, event)
  local ok = pcall(frame.RegisterEvent, frame, event)
  if not ok then
    state.unavailableEvents = state.unavailableEvents or {}
    state.unavailableEvents[event] = true
  end
end

registerEvent(eventFrame, "PLAYER_LOGIN")
registerEvent(eventFrame, "PLAYER_ENTERING_WORLD")
registerEvent(eventFrame, "PLAYER_REGEN_DISABLED")
registerEvent(eventFrame, "PLAYER_REGEN_ENABLED")
registerEvent(eventFrame, "UNIT_PET")
registerEvent(eventFrame, "UNIT_HEALTH")
registerEvent(eventFrame, "UNIT_MAXHEALTH")
registerEvent(eventFrame, "UNIT_HAPPINESS")
registerEvent(eventFrame, "UNIT_AURA")
registerEvent(eventFrame, "UNIT_ATTACK_SPEED")
registerEvent(eventFrame, "UNIT_INVENTORY_CHANGED")
registerEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
registerEvent(eventFrame, "BAG_UPDATE")
registerEvent(eventFrame, "BAG_UPDATE_DELAYED")
registerEvent(eventFrame, "BAG_UPDATE_COOLDOWN")
registerEvent(eventFrame, "ITEM_LOCK_CHANGED")
registerEvent(eventFrame, "SPELLS_CHANGED")
registerEvent(eventFrame, "LEARNED_SPELL_IN_TAB")
registerEvent(eventFrame, "START_AUTOREPEAT_SPELL")
registerEvent(eventFrame, "STOP_AUTOREPEAT_SPELL")
registerEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
registerEvent(eventFrame, "COMBAT_LOG_EVENT_UNFILTERED")
registerEvent(eventFrame, "UNIT_HEALTH_FREQUENT")
registerEvent(eventFrame, "UNIT_SPELLCAST_STOP")
registerEvent(eventFrame, "UNIT_SPELLCAST_FAILED")
registerEvent(eventFrame, "UNIT_SPELLCAST_INTERRUPTED")
registerEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED")
registerEvent(eventFrame, "MERCHANT_SHOW")
registerEvent(eventFrame, "MERCHANT_CLOSED")
registerEvent(eventFrame, "BANKFRAME_CLOSED")
registerEvent(eventFrame, "MAIL_CLOSED")
registerEvent(eventFrame, "TRADE_CLOSED")
registerEvent(eventFrame, "LOOT_CLOSED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    db()
    markResourcesDirty(event, true)
    if VenariDB.debug == true and VenariDB.debugCommandVersion ~= 1 then
      VenariDB.debug = false
    end
    VenariDB.debugCommandVersion = 1
    local _, classFile = UnitClass("player")
    state.playerClass = classFile
    createUI()
    refresh(event)
    after(0.2, forceRefreshCareAndAmmo)
    after(1.0, forceRefreshCareAndAmmo)
    after(2.5, forceRefreshCareAndAmmo)
    state.initialized = true
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    markResourcesDirty(event, true)
    after(0.2, function() refresh(event) end)
    after(0.6, forceRefreshCareAndAmmo)
    after(2.0, forceRefreshCareAndAmmo)
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    state.inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    state.inCombat = false
    setAspectDrawerOpen(false)
    markResourcesDirty(event, true)
    if state.scaleDirty then
      applyPosition()
      state.scaleDirty = false
      refreshConfigPanel()
    end
    if state.configDirty then
      applyConfiguredButtons(true)
      printMsg(L("msg.configApplied"))
    end
  elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "ITEM_LOCK_CHANGED" then
    if event == "UNIT_INVENTORY_CHANGED" then
      local unit = ...
      if unit and unit ~= "player" and unit ~= "pet" then
        return
      end
    end
    markResourcesDirty(event)
  elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
    markResourcesDirty(event)
    if event == "SPELL_UPDATE_COOLDOWN" then
      traceAutoShot("spell-cooldown-event")
    end
  elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" or event == "BANKFRAME_CLOSED" or event == "MAIL_CLOSED" or event == "TRADE_CLOSED" or event == "LOOT_CLOSED" then
    markResourcesDirty(event, true)
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
    markResourcesDirty(event, true)
    refreshConfigPanel()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if handleCombatLog() then
      refresh(event)
    end
    return
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED" then
    if isRevivePetSpell(...) then
      if event == "UNIT_SPELLCAST_SUCCEEDED" then
        clearPetReviveDeadGuard()
      elseif state.petRevivePending then
        state.petRevivePending = false
        setPetReviveDeadGuard(2.5)
      end
      schedulePetRefresh(event)
    else
      return
    end
  elseif event == "START_AUTOREPEAT_SPELL" then
    state.autoRepeat = true
    state.lastAutoRepeatStart = GetTime()
    state.autoShotPending = false
    state.autoShotArmed = true
    state.autoShotSyncLockUntil = nil
    state.autoShotTimerStart = nil
    state.autoShotTimerDuration = nil
    state.autoShotTimerSource = "armed"
    traceAutoShot("auto-repeat-start")
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    state.autoRepeat = false
    state.lastAutoRepeatStop = GetTime()
    state.lastAutoShot = nil
    state.autoShotTimerStart = nil
    state.autoShotTimerDuration = nil
    state.autoShotTimerSource = nil
    state.autoShotPending = false
    state.autoShotArmed = false
    state.autoShotSyncLockUntil = nil
    traceAutoShot("auto-repeat-stop")
  elseif event == "UNIT_PET" then
    local unit = ...
    if unit ~= "player" then
      return
    end
    markResourcesDirty(event, true)
  elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" or event == "UNIT_AURA" or event == "UNIT_ATTACK_SPEED" then
    local unit = ...
    if unit ~= "pet" and unit ~= "player" and unit ~= "target" then
      return
    end
    if event == "UNIT_ATTACK_SPEED" and unit == "player" then
      traceAutoShot("attack-speed-event")
    end
  end

  refresh(event)
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
  tickerElapsed = tickerElapsed + elapsed
  local now = GetTime and GetTime() or 0
  local pulseActive = state.shotPulseStart and now - state.shotPulseStart < 0.34
  local interval = (pulseActive or state.autoRepeat) and 0.03 or 0.1
  if tickerElapsed < interval then
    return
  end
  tickerElapsed = 0
  if db().debug or state.autoRepeat or pulseActive then
    refresh("ticker")
  end
end)

local function printStatus()
  updateSnapshot("status")
  printMsg(("enabled=%s locked=%s debug=%s scale=%.2f"):format(
    tostring(db().enabled),
    tostring(db().locked),
    tostring(db().debug),
    db().scale or 1
  ))
  printMsg(("position=%s UIParent %s %d %d"):format(
    db().position.point,
    db().position.relativePoint,
    db().position.x,
    db().position.y
  ))
  printMsg(("pet=%s dead=%s happy=%s hp=%s/%s auto=%s speed=%s aspect=%s event=%s"):format(
    tostring(state.petExists),
    tostring(state.petDead),
    tostring(state.petHappiness),
    tostring(state.petHealth),
    tostring(state.petHealthMax),
    tostring(state.autoRepeat),
    tostring(state.rangedSpeed),
    tostring(state.activeAspect),
    tostring(state.lastEvent)
  ))
end

local function printButtonDiag(label, button)
  if not button then
    printMsg(label .. ": missing")
    return
  end
  printMsg(("%s shown=%s enabled=%s mouse=%s type=%s type1=%s type2=%s ctrl-type2=%s spell=%s macro=%s macro1=%s macro2=%s ctrl-macro2=%s"):format(
    label,
    tostring(button:IsShown()),
    tostring(button.IsEnabled and button:IsEnabled()),
    tostring(button.IsMouseEnabled and button:IsMouseEnabled()),
    shortValue(button.GetAttribute and button:GetAttribute("type")),
    shortValue(button.GetAttribute and button:GetAttribute("type1")),
    shortValue(button.GetAttribute and button:GetAttribute("type2")),
    shortValue(button.GetAttribute and button:GetAttribute("ctrl-type2")),
    shortValue(button.GetAttribute and button:GetAttribute("spell")),
    shortValue(button.GetAttribute and button:GetAttribute("macrotext")),
    shortValue(button.GetAttribute and button:GetAttribute("macrotext1")),
    shortValue(button.GetAttribute and button:GetAttribute("macrotext2")),
    shortValue(button.GetAttribute and button:GetAttribute("ctrl-macrotext2"))
  ))
end

local function printCountDiag(label, button)
  if not button then
    printMsg(label .. " count: missing button")
    return
  end
  local text = button.countText
  printMsg(("%s countText=%s shown=%s text=%s buttonLevel=%s cooldownLevel=%s countLevel=%s icon=%s"):format(
    label,
    tostring(text ~= nil),
    tostring(text and text.IsShown and text:IsShown()),
    shortValue(text and text.GetText and text:GetText()),
    shortValue(button.GetFrameLevel and button:GetFrameLevel()),
    shortValue(button.cooldown and button.cooldown.GetFrameLevel and button.cooldown:GetFrameLevel()),
    shortValue(button.countFrame and button.countFrame.GetFrameLevel and button.countFrame:GetFrameLevel()),
    shortValue(button.icon and button.icon.GetTexture and button.icon:GetTexture())
  ))
end

local function printDiag()
  refresh("diag")
  printMsg(("diag combat=%s lockdown=%s root=%s"):format(
    tostring(state.inCombat),
    tostring(InCombatLockdown and InCombatLockdown()),
    tostring(ui.root and ui.root:IsShown())
  ))
  printMsg(("care food=%s count=%s bandage=%s:%s count=%s ammo=%s:%s count=%s source=%s"):format(
    shortValue(state.selectedFood),
    shortValue(state.selectedFoodCount),
    shortValue(state.selectedBandage),
    shortValue(state.selectedBandageName),
    shortValue(state.selectedBandageCount),
    shortValue(state.selectedAmmo),
    shortValue(state.selectedAmmoName),
    shortValue(state.selectedAmmoCount),
    shortValue(state.selectedAmmoSource)
  ))
  printCountDiag("food", ui.foodButton)
  printCountDiag("bandage", ui.bandageButton)
  printMsg(("pet name=%s level=%s health=%s%% autoCount=%s autoSource=%s timer=%s lastAuto=%s speed=%s prevSpeed=%s"):format(
    shortValue(state.petName),
    shortValue(state.petLevel),
    shortValue(petHealthPercent()),
    shortValue(state.autoShotCount),
    shortValue(state.lastAutoShotSource),
    shortValue(state.autoShotTimerSource),
    shortValue(state.lastAutoShot),
    shortValue(state.rangedSpeed),
    shortValue(state.lastRangedSpeed)
  ))
  printMsg(("spells aspects=%s/%s traps=%s/%s/%s/%s tools=%s/%s/%s/%s/%s"):format(
    shortValue(spellName(db().aspects[1])),
    shortValue(spellName(db().aspects[2])),
    shortValue(spellName(db().traps[1])),
    shortValue(spellName(db().traps[2])),
    shortValue(spellName(db().traps[3])),
    shortValue(spellName(db().traps[4])),
    shortValue(spellName("eagleEye")),
    shortValue(spellName("scareBeast")),
    shortValue(spellName("flare")),
    shortValue(spellName("beastLore")),
    shortValue(spellName("tameBeast"))
  ))
  printButtonDiag("food", ui.foodButton)
  printButtonDiag("bandage", ui.bandageButton)
  printButtonDiag("center", ui.center)
  printButtonDiag("aspectMain", ui.buttons.aspectMain)
  printButtonDiag("trap1", ui.buttons.trap1)
  printButtonDiag("trap2", ui.buttons.trap2)
  printButtonDiag("trap3", ui.buttons.trap3)
  printButtonDiag("trap4", ui.buttons.trap4)
  for index = 1, #aspectOptions do
    printButtonDiag("aspectDrawer" .. tostring(index), ui.buttons["aspectDrawer" .. tostring(index)])
  end
  printButtonDiag("tool1", ui.buttons.eagleEye)
end

local function resetPosition()
  local cfg = db()
  cfg.position = {}
  copyDefaults(cfg.position, defaults.position)
  applyPosition()
  savePosition()
  printMsg(L("msg.positionReset"))
end

local function handleCommand(input)
  input = input and input:lower() or ""

  if input == "" or input == "help" then
    printMsg(L("msg.commands"))
    return
  end

  if input == "config" or input == "options" then
    toggleConfigFrame()
    return
  end

  if input == "foodlog" or input == "feedlog" then
    logPetFoodScan()
    return
  end

  if VenariDebug and type(VenariDebug.HandleCommand) == "function" and VenariDebug.HandleCommand(input, {
    db = db,
    refresh = refresh,
    printMsg = printMsg,
    L = L,
    state = state,
    readAutoShotCooldown = readAutoShotCooldown,
  }) then
    return
  end

  printMsg(L("msg.unknownCommand"))
end

SLASH_VENARI1 = "/venari"
SlashCmdList.VENARI = function(input)
  local ok, err = pcall(handleCommand, input)
  if not ok then
    printMsg(L("msg.commandFailed") .. ": " .. tostring(err))
  end
end
