local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)
if type(bootstrap) ~= "table" or type(bootstrap.AppendItemChunk) ~= "function" then
    return
end

bootstrap.AppendItemChunk({
    { itemID = 286292, name = "Tirion Fordring's Gold Coin" },
    { itemID = 286293, name = "Archimonde's Gold Coin" },
    { itemID = 286294, name = "Valdrus Blackthorne's Gold Coin" },
    { itemID = 286298, name = "Umbrinoth's Gold Coin" },
    { itemID = 286299, name = "Thrall's Gold Coin" },
    { itemID = 286300, name = "Sonya Darkhallow's Gold Coin" },
    { itemID = 286302, name = "Zarla Ober's Gold Coin" },
    { itemID = 286304, name = "A Footman's Copper Coin" },
    { itemID = 286306, name = "Vargoth's Copper Coin" },
    { itemID = 286307, name = "Ansirem's Copper Coin" },
    { itemID = 286308, name = "Attumen's Copper Coin" },
    { itemID = 286309, name = "Danath's Copper Coin" },
    { itemID = 286310, name = "Elling Trias' Copper Coin" },
    { itemID = 286311, name = "Falstad Wildhammer's Copper Coin" },
    { itemID = 286312, name = "Inigo's Copper Coin" },
    { itemID = 286313, name = "Landro Longshot's Copper Coin" },
    { itemID = 286314, name = "Squire Rowan's Copper Coin" },
    { itemID = 286315, name = "Rath'mael's Copper Coin" },
    { itemID = 286316, name = "Mason's Copper Coin" },
    { itemID = 286317, name = "Ofalo's Copper Coin" },
    { itemID = 286318, name = "Sair's Copper Coin" },
    { itemID = 286325, name = "Avala's Core" },
    { itemID = 286326, name = "Riptear's Heart" },
    { itemID = 286327, name = "Rhonin's Gold Coin" },
    { itemID = 286328, name = "Elaadrin Evengale's Silver Coin" },
    { itemID = 286339, name = "Mostly Dry Firewood" },
    { itemID = 286355, name = "Crate of Candles" },
    { itemID = 286358, name = "Coalbeard's Rifle" },
    { itemID = 286359, name = "Sunhammer's Rifle" },
    { itemID = 286360, name = "Stoneanvil's Rifle" },
    { itemID = 286405, name = "Blooming Heart" },
    { itemID = 286411, name = "Plant Stem" },
    { itemID = 286415, name = "Reliquary of Tyr" },
    { itemID = 286424, name = "Monster - Sword, Scimitar Basic" },
    { itemID = 286425, name = "Monster - Sword, Scimitar Basic" },
    { itemID = 286426, name = "Honorbound Cloak" },
    { itemID = 286427, name = "Cloak of the Honored Guest" },
    { itemID = 286647, name = "Depleted Crystal Heart" },
    { itemID = 286648, name = "Depleted Crystal Heart" },
    { itemID = 286737, name = "Avala's Binding" },
    { itemID = 287090, name = "Sharpened Letter Opener" },
})
