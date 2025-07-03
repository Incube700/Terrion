const ABILITIES = {
    "orbital_shield": {
        "type": "active",
        "cooldown": 60,
        "duration": 10,
        "effect": "invulnerable_buildings"
    },
    "emp_blast": {
        "type": "active",
        "cooldown": 45,
        "radius": 8,
        "effect": "disable_enemy_structures"
    },
    "rapid_deployment": {
        "type": "passive",
        "effect": "spawn_speed_bonus",
        "value": 0.2
    },
    "resourceful": {
        "type": "passive",
        "effect": "building_cost_reduction",
        "value": 0.1
    },
    "mass_teleport": {
        "type": "ultimate",
        "cooldown": 120,
        "effect": "teleport_all_to_core",
        "description": "Люди: Телепортирует все ваши войска к ядру. Особая способность."
    },
    "orc_warcry": {
        "type": "ultimate",
        "cooldown": 120,
        "effect": "orc_mass_berserk",
        "description": "Орки: Все ваши юниты получают берсерк и ускорение на 15 сек."
    },
    "elf_nature_rebirth": {
        "type": "ultimate",
        "cooldown": 120,
        "effect": "elf_revive_all",
        "description": "Эльфы: Мгновенно воскрешает всех павших юнитов и лечит их."
    },
    "undead_dark_swarm": {
        "type": "ultimate",
        "cooldown": 120,
        "effect": "undead_summon_swarm",
        "description": "Некроны: Призывает рой теней, атакующих врагов по всей карте."
    }
} 