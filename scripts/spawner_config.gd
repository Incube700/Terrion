const SPAWNER_CONFIG = {
    "spawner": {
        "build_time": 3.0,
        "group_spawn_interval": 5.0,
        "max_active_groups": 5,
        "group_size": 4,
        "cost": 30,
        "hp": 500,
        "description": "Спавнит группы юнитов каждые 5 секунд"
    }
}

const GROUP_UNIT_CONFIG = {
    "group_unit": {
        "hp": 100,
        "damage": 10,
        "speed": 60,
        "attack_range": 3.0,
        "vision_range": 8.0,
        "unit_count": 4,
        "formation_spacing": 1.5,
        "ai_behavior": "aggressive",
        "description": "Группа из 4 юнитов, действующая как единая логическая сущность"
    }
}
