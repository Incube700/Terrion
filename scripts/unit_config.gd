const UNIT_STATS = {
    "scout": { "hp": 120, "speed": 18, "damage": 10, "vision": 20, "cost": 30 },
    "engineer": { "hp": 200, "speed": 8, "damage": 5, "repair": 30, "cost": 40 },
    "heavy_mech": { "hp": 1200, "speed": 4, "damage": 80, "armor": 30, "cost": 120 },
    "medic": { "hp": 150, "speed": 10, "heal": 25, "cost": 35 }
}

const HERO_STATS = {
    "hero": {
        "hp": 2000,
        "speed": 12,
        "damage": 150,
        "armor": 50,
        "cost": 0,
        "attack_range": 8.0,
        "special_abilities": ["heroic_strike", "inspire_aura", "ultimate_rage"],
        "description": "Ультимативный юнит, призываемый при захвате обоих центральных триггеров"
    }
}
