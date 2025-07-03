const ACHIEVEMENTS = [
    {
        "id": "capture_3_crystals",
        "name": "Кристальный магнат",
        "description": "Захватите 3 кристалла за одну игру.",
        "condition": "crystals_captured >= 3",
        "reward": "+100 энергии"
    },
    {
        "id": "flawless_defense",
        "name": "Безупречная оборона",
        "description": "Победите, не потеряв ни одного здания.",
        "condition": "buildings_lost == 0 and victory",
        "reward": "Уникальная иконка профиля"
    },
    {
        "id": "fast_killer",
        "name": "Молниеносный удар",
        "description": "Уничтожьте 10 вражеских юнитов за 1 минуту.",
        "condition": "enemy_units_killed_in_60s >= 10",
        "reward": "+50 кристаллов"
    }
] 