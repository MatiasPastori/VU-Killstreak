-- Edit this to add other mods as Killstreaks. The Mod has to have a Invoke event wich only needs to be called without a parameter
-- The second row allows you to modifiy the keys which invoke the killstreak

local conf = {
    {
        "vu-artillerystrike",
        33,
        1000,
        "Artillery",
        "Left %NR",
        "Press Q to use", -- displayed when a user activates the killstreak
        "Ready to use"
      },
      {
        "vu-ks-tank",
        33,
        500,
        "Main Battle Tank",
        "Left %NR",
        "Press Q to use", -- displayed when a user activates the killstreak
        "Ready to use"
      },
      {
        "vu-ks-attackheli",
        33,
        500,
        "Attack Helicopter",
        "Left %NR",
        "Press Q to use", -- displayed when a user activates the killstreak
        "Ready to use"
      }
}



return conf
