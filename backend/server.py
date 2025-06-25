from fastapi import FastAPI, WebSocket, WebSocketDisconnect, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
import json
import asyncio
import uuid
from datetime import datetime
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Tuple
import math
import random

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app
app = FastAPI()
api_router = APIRouter(prefix="/api")

# Game Models
class Position(BaseModel):
    x: float
    y: float

class Unit(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str  # "soldier", "tank", "drone"
    position: Position
    health: int
    max_health: int
    damage: int
    speed: int
    team: str  # "player" or "enemy"
    target_id: Optional[str] = None
    last_attack: float = 0
    attack_speed: float = 1.0  # attacks per second

class Building(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str  # "tower", "barracks"
    position: Position
    health: int
    max_health: int
    team: str  # "player" or "enemy"
    last_production: float = 0
    production_interval: float = 5.0  # seconds
    target_id: Optional[str] = None
    last_attack: float = 0

class Core(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    team: str
    position: Position
    health: int = 500
    max_health: int = 500
    energy: int = 100
    max_energy: int = 200
    energy_generation: float = 5.0  # per second
    last_energy_update: float = 0

class GameState(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    player_core: Core
    enemy_core: Core
    units: List[Unit] = []
    buildings: List[Building] = []
    game_time: float = 0
    is_active: bool = True
    winner: Optional[str] = None

# Game Configuration
UNIT_CONFIGS = {
    "soldier": {"health": 100, "damage": 15, "speed": 100, "cost": 20, "attack_speed": 1.0},
    "tank": {"health": 200, "damage": 40, "speed": 60, "cost": 50, "attack_speed": 0.5},
    "drone": {"health": 60, "damage": 10, "speed": 160, "cost": 35, "attack_speed": 1.5}
}

BUILDING_CONFIGS = {
    "tower": {"health": 200, "damage": 25, "cost": 50, "range": 200, "attack_speed": 0.5},
    "barracks": {"health": 150, "cost": 80, "production_interval": 5.0, "unit_cost": 10}
}

# Game Logic
class GameEngine:
    def __init__(self):
        self.games: Dict[str, GameState] = {}
        self.connections: Dict[str, WebSocket] = {}
        
    def create_game(self, game_id: str) -> GameState:
        # Initialize cores
        player_core = Core(
            team="player",
            position=Position(x=100, y=400),
            last_energy_update=0
        )
        
        enemy_core = Core(
            team="enemy", 
            position=Position(x=900, y=400),
            last_energy_update=0
        )
        
        game_state = GameState(
            id=game_id,
            player_core=player_core,
            enemy_core=enemy_core
        )
        
        self.games[game_id] = game_state
        return game_state
    
    def spawn_unit(self, game_id: str, unit_type: str, team: str) -> bool:
        if game_id not in self.games:
            return False
            
        game = self.games[game_id]
        config = UNIT_CONFIGS.get(unit_type)
        if not config:
            return False
            
        # Check energy cost
        core = game.player_core if team == "player" else game.enemy_core
        if core.energy < config["cost"]:
            return False
            
        # Deduct energy
        core.energy -= config["cost"]
        
        # Spawn near core
        spawn_offset = random.uniform(-50, 50)
        spawn_pos = Position(
            x=core.position.x + (50 if team == "player" else -50),
            y=core.position.y + spawn_offset
        )
        
        unit = Unit(
            type=unit_type,
            position=spawn_pos,
            health=config["health"],
            max_health=config["health"],
            damage=config["damage"],
            speed=config["speed"],
            team=team,
            attack_speed=config["attack_speed"]
        )
        
        game.units.append(unit)
        return True
    
    def build_structure(self, game_id: str, building_type: str, team: str, position: Position) -> bool:
        if game_id not in self.games:
            return False
            
        game = self.games[game_id]
        config = BUILDING_CONFIGS.get(building_type)
        if not config:
            return False
            
        # Check energy cost
        core = game.player_core if team == "player" else game.enemy_core
        if core.energy < config["cost"]:
            return False
            
        # Deduct energy
        core.energy -= config["cost"]
        
        building = Building(
            type=building_type,
            position=position,
            health=config["health"],
            max_health=config["health"],
            team=team,
            production_interval=config.get("production_interval", 5.0)
        )
        
        game.buildings.append(building)
        return True
    
    def update_game(self, game_id: str, delta_time: float):
        if game_id not in self.games:
            return
            
        game = self.games[game_id]
        if not game.is_active:
            return
            
        game.game_time += delta_time
        
        # Update energy generation
        self.update_energy(game, delta_time)
        
        # Update units
        self.update_units(game, delta_time)
        
        # Update buildings
        self.update_buildings(game, delta_time)
        
        # Check win conditions
        self.check_win_condition(game)
    
    def update_energy(self, game: GameState, delta_time: float):
        # Update player energy
        game.player_core.energy = min(
            game.player_core.max_energy,
            game.player_core.energy + game.player_core.energy_generation * delta_time
        )
        
        # Update enemy energy
        game.enemy_core.energy = min(
            game.enemy_core.max_energy,
            game.enemy_core.energy + game.enemy_core.energy_generation * delta_time
        )
    
    def update_units(self, game: GameState, delta_time: float):
        for unit in game.units[:]:  # Copy list to safely modify
            if unit.health <= 0:
                game.units.remove(unit)
                continue
                
            # Find target
            if not unit.target_id:
                unit.target_id = self.find_target(game, unit)
            
            # Move towards target or enemy core
            target = self.get_target_object(game, unit)
            if target:
                self.move_unit_towards_target(unit, target, delta_time)
                
                # Attack if in range
                distance = self.calculate_distance(unit.position, target.position)
                if distance < 50:  # Attack range
                    if game.game_time - unit.last_attack >= (1.0 / unit.attack_speed):
                        self.attack_target(game, unit, target)
                        unit.last_attack = game.game_time
    
    def update_buildings(self, game: GameState, delta_time: float):
        current_time = game.game_time
        
        for building in game.buildings[:]:
            if building.health <= 0:
                game.buildings.remove(building)
                continue
                
            if building.type == "barracks":
                # Auto-produce units
                if current_time - building.last_production >= building.production_interval:
                    core = game.player_core if building.team == "player" else game.enemy_core
                    unit_cost = BUILDING_CONFIGS["barracks"]["unit_cost"]
                    
                    if core.energy >= unit_cost:
                        core.energy -= unit_cost
                        
                        # Spawn soldier near barracks
                        spawn_pos = Position(
                            x=building.position.x + random.uniform(-30, 30),
                            y=building.position.y + random.uniform(-30, 30)
                        )
                        
                        unit = Unit(
                            type="soldier",
                            position=spawn_pos,
                            health=UNIT_CONFIGS["soldier"]["health"],
                            max_health=UNIT_CONFIGS["soldier"]["health"],
                            damage=UNIT_CONFIGS["soldier"]["damage"],
                            speed=UNIT_CONFIGS["soldier"]["speed"],
                            team=building.team,
                            attack_speed=UNIT_CONFIGS["soldier"]["attack_speed"]
                        )
                        
                        game.units.append(unit)
                        building.last_production = current_time
                        
            elif building.type == "tower":
                # Auto-attack enemies in range
                if not building.target_id:
                    building.target_id = self.find_target_for_building(game, building)
                
                target = self.get_target_object(game, building)
                if target:
                    distance = self.calculate_distance(building.position, target.position)
                    tower_range = BUILDING_CONFIGS["tower"]["range"]
                    
                    if distance <= tower_range:
                        if current_time - building.last_attack >= (1.0 / BUILDING_CONFIGS["tower"]["attack_speed"]):
                            self.attack_target(game, building, target)
                            building.last_attack = current_time
                    else:
                        building.target_id = None
    
    def find_target(self, game: GameState, unit: Unit) -> Optional[str]:
        enemy_team = "enemy" if unit.team == "player" else "player"
        min_distance = float('inf')
        closest_target = None
        
        # Check enemy units
        for enemy_unit in game.units:
            if enemy_unit.team == enemy_team:
                distance = self.calculate_distance(unit.position, enemy_unit.position)
                if distance < min_distance:
                    min_distance = distance
                    closest_target = enemy_unit.id
        
        # Check enemy buildings
        for building in game.buildings:
            if building.team == enemy_team:
                distance = self.calculate_distance(unit.position, building.position)
                if distance < min_distance:
                    min_distance = distance
                    closest_target = building.id
        
        # Check enemy core
        enemy_core = game.enemy_core if unit.team == "player" else game.player_core
        distance = self.calculate_distance(unit.position, enemy_core.position)
        if distance < min_distance:
            closest_target = enemy_core.id
            
        return closest_target
    
    def find_target_for_building(self, game: GameState, building: Building) -> Optional[str]:
        enemy_team = "enemy" if building.team == "player" else "player"
        min_distance = float('inf')
        closest_target = None
        tower_range = BUILDING_CONFIGS["tower"]["range"]
        
        # Check enemy units in range
        for enemy_unit in game.units:
            if enemy_unit.team == enemy_team:
                distance = self.calculate_distance(building.position, enemy_unit.position)
                if distance <= tower_range and distance < min_distance:
                    min_distance = distance
                    closest_target = enemy_unit.id
                    
        return closest_target
    
    def get_target_object(self, game: GameState, attacker):
        target_id = attacker.target_id
        if not target_id:
            return None
            
        # Check units
        for unit in game.units:
            if unit.id == target_id:
                return unit
                
        # Check buildings
        for building in game.buildings:
            if building.id == target_id:
                return building
                
        # Check cores
        if game.player_core.id == target_id:
            return game.player_core
        if game.enemy_core.id == target_id:
            return game.enemy_core
            
        return None
    
    def move_unit_towards_target(self, unit: Unit, target, delta_time: float):
        dx = target.position.x - unit.position.x
        dy = target.position.y - unit.position.y
        distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 0:
            # Normalize direction
            dx /= distance
            dy /= distance
            
            # Move towards target
            move_distance = unit.speed * delta_time
            unit.position.x += dx * move_distance
            unit.position.y += dy * move_distance
    
    def attack_target(self, game: GameState, attacker, target):
        if hasattr(attacker, 'damage'):
            damage = attacker.damage
        else:
            damage = BUILDING_CONFIGS[attacker.type]["damage"]
            
        target.health -= damage
        
        # Clear target if destroyed
        if target.health <= 0:
            attacker.target_id = None
    
    def calculate_distance(self, pos1: Position, pos2: Position) -> float:
        dx = pos2.x - pos1.x
        dy = pos2.y - pos1.y
        return math.sqrt(dx*dx + dy*dy)
    
    def check_win_condition(self, game: GameState):
        if game.player_core.health <= 0:
            game.is_active = False
            game.winner = "enemy"
        elif game.enemy_core.health <= 0:
            game.is_active = False
            game.winner = "player"

# Global game engine
game_engine = GameEngine()

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, websocket: WebSocket, game_id: str):
        await websocket.accept()
        self.active_connections[game_id] = websocket
        
    def disconnect(self, game_id: str):
        if game_id in self.active_connections:
            del self.active_connections[game_id]
    
    async def send_game_state(self, game_id: str, game_state: GameState):
        if game_id in self.active_connections:
            try:
                await self.active_connections[game_id].send_text(game_state.json())
            except:
                self.disconnect(game_id)

manager = ConnectionManager()

# API Routes
@api_router.get("/")
async def root():
    return {"message": "TERRION RTS-lite Game Server"}

@api_router.post("/game/create")
async def create_game():
    game_id = str(uuid.uuid4())
    game_state = game_engine.create_game(game_id)
    return {"game_id": game_id, "status": "created"}

@api_router.post("/game/{game_id}/spawn/{unit_type}")
async def spawn_unit(game_id: str, unit_type: str):
    success = game_engine.spawn_unit(game_id, unit_type, "player")
    return {"success": success}

@api_router.post("/game/{game_id}/build/{building_type}")
async def build_structure(game_id: str, building_type: str, x: float, y: float):
    position = Position(x=x, y=y)
    success = game_engine.build_structure(game_id, building_type, "player", position)
    return {"success": success}

@api_router.get("/game/{game_id}/state")
async def get_game_state(game_id: str):
    if game_id in game_engine.games:
        return game_engine.games[game_id]
    return {"error": "Game not found"}

# WebSocket endpoint - move before including router
@app.websocket("/ws/{game_id}")
async def websocket_endpoint(websocket: WebSocket, game_id: str):
    print(f"WebSocket connection attempt for game {game_id}")
    await websocket.accept()
    print(f"WebSocket connection accepted for game {game_id}")
    
    # Create game if doesn't exist
    if game_id not in game_engine.games:
        print(f"Creating new game {game_id}")
        game_engine.create_game(game_id)
    
    try:
        # Game loop
        last_update = asyncio.get_event_loop().time()
        
        while True:
            try:
                current_time = asyncio.get_event_loop().time()
                delta_time = current_time - last_update
                last_update = current_time
                
                # Update game state
                game_engine.update_game(game_id, delta_time)
                
                # Send updated state to client
                if game_id in game_engine.games:
                    game_state = game_engine.games[game_id]
                    await websocket.send_text(game_state.json())
                
                # AI actions for enemy
                await game_ai_actions(game_id)
                
                await asyncio.sleep(1/30)  # 30 FPS
                
            except Exception as e:
                print(f"Error in game loop: {e}")
                break
            
    except WebSocketDisconnect:
        print(f"WebSocket disconnected for game {game_id}")
    except Exception as e:
        print(f"WebSocket error for game {game_id}: {e}")
        await websocket.close()

# Simple Enemy AI
async def game_ai_actions(game_id: str):
    if game_id not in game_engine.games:
        return
        
    game = game_engine.games[game_id]
    
    # Simple AI logic - spawn units when energy is available
    if game.enemy_core.energy >= 50 and random.random() < 0.02:  # 2% chance per frame
        unit_types = ["soldier", "tank", "drone"]
        unit_type = random.choice(unit_types)
        if game.enemy_core.energy >= UNIT_CONFIGS[unit_type]["cost"]:
            game_engine.spawn_unit(game_id, unit_type, "enemy")
    
    # Build structures occasionally
    if game.enemy_core.energy >= 80 and len([b for b in game.buildings if b.team == "enemy"]) < 3:
        if random.random() < 0.005:  # 0.5% chance per frame
            building_type = random.choice(["tower", "barracks"])
            if game.enemy_core.energy >= BUILDING_CONFIGS[building_type]["cost"]:
                # Build near enemy core
                pos = Position(
                    x=game.enemy_core.position.x + random.uniform(-100, -50),
                    y=game.enemy_core.position.y + random.uniform(-50, 50)
                )
                game_engine.build_structure(game_id, building_type, "enemy", pos)

# Include router
app.include_router(api_router)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()