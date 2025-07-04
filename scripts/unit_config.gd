const UNIT_STATS = {
    "warrior": { "hp": 300, "speed": 8, "damage": 35, "vision": 10, "cost": 25 },
    "heavy": { "hp": 800, "speed": 5, "damage": 60, "armor": 15, "cost": 60 },
    "fast": { "hp": 240, "speed": 12, "damage": 40, "vision": 12, "cost": 30 },
    "sniper": { "hp": 180, "speed": 6, "damage": 60, "range": 8, "cost": 45 },
    "collector": { "hp": 280, "speed": 10, "damage": 15, "vision": 5, "cost": 40 }
}

const HERO_STATS = {
    "hero": {
        "hp": 1000,
        "speed": 12,
        "damage": 100,
        "armor": 50,
        "cost": 0,
        "attack_range": 8.0,
        "special_abilities": ["heroic_strike", "inspire_aura", "ultimate_rage"],
        "description": "Ультимативный юнит, призываемый при захвате обоих центральных триггеров"
    }
}
