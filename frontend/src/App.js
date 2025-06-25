import React, { useEffect, useRef, useState, useCallback } from 'react';
import './App.css';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;
const WS_URL = BACKEND_URL.replace('https://', 'wss://').replace('http://', 'ws://');

// Game constants
const CANVAS_WIDTH = 1000;
const CANVAS_HEIGHT = 800;

const UNIT_COLORS = {
  player: {
    soldier: '#3B82F6',    // Blue
    tank: '#1E40AF',       // Dark blue
    drone: '#60A5FA'       // Light blue
  },
  enemy: {
    soldier: '#EF4444',    // Red
    tank: '#B91C1C',       // Dark red
    drone: '#F87171'       // Light red
  }
};

const BUILDING_COLORS = {
  player: {
    tower: '#3B82F6',
    barracks: '#1D4ED8'
  },
  enemy: {
    tower: '#EF4444',
    barracks: '#DC2626'
  }
};

const UNIT_COSTS = {
  soldier: 20,
  tank: 50,
  drone: 35
};

const BUILDING_COSTS = {
  tower: 50,
  barracks: 80
};

function GameCanvas() {
  const canvasRef = useRef(null);
  const wsRef = useRef(null);
  const [gameState, setGameState] = useState(null);
  const [gameId, setGameId] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('Disconnected');
  const [selectedBuildingType, setSelectedBuildingType] = useState(null);

  // Initialize game
  useEffect(() => {
    createGame();
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  const createGame = async () => {
    try {
      const response = await fetch(`${API}/game/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      const data = await response.json();
      setGameId(data.game_id);
      connectWebSocket(data.game_id);
    } catch (error) {
      console.error('Failed to create game:', error);
    }
  };

  const connectWebSocket = (gameId) => {
    const ws = new WebSocket(`${WS_URL}/ws/${gameId}`);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnectionStatus('Connected');
      console.log('WebSocket connected');
    };

    ws.onmessage = (event) => {
      try {
        const gameState = JSON.parse(event.data);
        setGameState(gameState);
      } catch (error) {
        console.error('Failed to parse game state:', error);
      }
    };

    ws.onclose = () => {
      setConnectionStatus('Disconnected');
      console.log('WebSocket disconnected');
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      setConnectionStatus('Error');
    };
  };

  // Spawn unit
  const spawnUnit = async (unitType) => {
    if (!gameId) return;
    
    try {
      await fetch(`${API}/game/${gameId}/spawn/${unitType}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });
    } catch (error) {
      console.error('Failed to spawn unit:', error);
    }
  };

  // Build structure
  const buildStructure = async (buildingType, x, y) => {
    if (!gameId) return;
    
    try {
      await fetch(`${API}/game/${gameId}/build/${buildingType}?x=${x}&y=${y}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      setSelectedBuildingType(null);
    } catch (error) {
      console.error('Failed to build structure:', error);
    }
  };

  // Canvas click handler
  const handleCanvasClick = useCallback((event) => {
    if (!selectedBuildingType) return;
    
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    
    buildStructure(selectedBuildingType, x, y);
  }, [selectedBuildingType, gameId]);

  // Render game
  useEffect(() => {
    if (!gameState || !canvasRef.current) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    
    // Clear canvas
    ctx.fillStyle = '#0F172A';
    ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

    // Draw cores
    drawCore(ctx, gameState.player_core, 'player');
    drawCore(ctx, gameState.enemy_core, 'enemy');

    // Draw units
    gameState.units.forEach(unit => {
      drawUnit(ctx, unit);
    });

    // Draw buildings
    gameState.buildings.forEach(building => {
      drawBuilding(ctx, building);
    });

    // Draw building placement preview
    if (selectedBuildingType) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 5]);
      ctx.strokeRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
      ctx.setLineDash([]);
    }

  }, [gameState, selectedBuildingType]);

  const drawCore = (ctx, core, team) => {
    const color = team === 'player' ? '#3B82F6' : '#EF4444';
    
    // Draw core
    ctx.fillStyle = color;
    ctx.fillRect(core.position.x - 25, core.position.y - 25, 50, 50);
    
    // Draw health bar
    const healthPercent = core.health / core.max_health;
    ctx.fillStyle = '#DC2626';
    ctx.fillRect(core.position.x - 30, core.position.y - 40, 60, 8);
    ctx.fillStyle = '#16A34A';
    ctx.fillRect(core.position.x - 30, core.position.y - 40, 60 * healthPercent, 8);
    
    // Draw energy bar
    const energyPercent = core.energy / core.max_energy;
    ctx.fillStyle = '#4B5563';
    ctx.fillRect(core.position.x - 30, core.position.y - 50, 60, 6);
    ctx.fillStyle = '#FBBF24';
    ctx.fillRect(core.position.x - 30, core.position.y - 50, 60 * energyPercent, 6);
    
    // Draw labels
    ctx.fillStyle = '#FFFFFF';
    ctx.font = '12px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.round(core.health)}/${core.max_health}`, core.position.x, core.position.y - 55);
    ctx.fillText(`Energy: ${Math.round(core.energy)}`, core.position.x, core.position.y + 45);
  };

  const drawUnit = (ctx, unit) => {
    const color = UNIT_COLORS[unit.team][unit.type];
    const size = unit.type === 'tank' ? 16 : unit.type === 'drone' ? 10 : 12;
    
    ctx.fillStyle = color;
    
    // Draw different shapes for different unit types
    if (unit.type === 'soldier') {
      // Square
      ctx.fillRect(unit.position.x - size/2, unit.position.y - size/2, size, size);
    } else if (unit.type === 'tank') {
      // Rectangle
      ctx.fillRect(unit.position.x - size/2, unit.position.y - size/2, size, size * 0.6);
    } else if (unit.type === 'drone') {
      // Circle
      ctx.beginPath();
      ctx.arc(unit.position.x, unit.position.y, size/2, 0, 2 * Math.PI);
      ctx.fill();
    }
    
    // Draw health bar for damaged units
    if (unit.health < unit.max_health) {
      const healthPercent = unit.health / unit.max_health;
      ctx.fillStyle = '#DC2626';
      ctx.fillRect(unit.position.x - 15, unit.position.y - 20, 30, 4);
      ctx.fillStyle = '#16A34A';
      ctx.fillRect(unit.position.x - 15, unit.position.y - 20, 30 * healthPercent, 4);
    }
  };

  const drawBuilding = (ctx, building) => {
    const color = BUILDING_COLORS[building.team][building.type];
    const size = 30;
    
    ctx.fillStyle = color;
    
    if (building.type === 'tower') {
      // Triangle
      ctx.beginPath();
      ctx.moveTo(building.position.x, building.position.y - size/2);
      ctx.lineTo(building.position.x - size/2, building.position.y + size/2);
      ctx.lineTo(building.position.x + size/2, building.position.y + size/2);
      ctx.closePath();
      ctx.fill();
    } else if (building.type === 'barracks') {
      // Hexagon
      const sides = 6;
      const radius = size/2;
      ctx.beginPath();
      for (let i = 0; i < sides; i++) {
        const angle = (i * 2 * Math.PI) / sides;
        const x = building.position.x + radius * Math.cos(angle);
        const y = building.position.y + radius * Math.sin(angle);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.fill();
    }
    
    // Draw health bar for damaged buildings
    if (building.health < building.max_health) {
      const healthPercent = building.health / building.max_health;
      ctx.fillStyle = '#DC2626';
      ctx.fillRect(building.position.x - 20, building.position.y - 25, 40, 5);
      ctx.fillStyle = '#16A34A';
      ctx.fillRect(building.position.x - 20, building.position.y - 25, 40 * healthPercent, 5);
    }
  };

  const canAfford = (cost) => {
    return gameState && gameState.player_core.energy >= cost;
  };

  if (!gameState) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">
          Загрузка игры... {connectionStatus}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 flex flex-col">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex justify-between items-center">
        <h1 className="text-white text-2xl font-bold">TERRION RTS-lite</h1>
        <div className="text-white">
          <span className={`px-2 py-1 rounded ${connectionStatus === 'Connected' ? 'bg-green-600' : 'bg-red-600'}`}>
            {connectionStatus}
          </span>
        </div>
      </div>

      <div className="flex flex-1">
        {/* Game Canvas */}
        <div className="flex-1 flex justify-center items-center bg-gray-800 p-4">
          <canvas
            ref={canvasRef}
            width={CANVAS_WIDTH}
            height={CANVAS_HEIGHT}
            className="border border-gray-600 cursor-crosshair"
            onClick={handleCanvasClick}
            style={{ 
              cursor: selectedBuildingType ? 'crosshair' : 'default',
              maxWidth: '100%',
              maxHeight: '100%'
            }}
          />
        </div>

        {/* Control Panel */}
        <div className="w-80 bg-gray-700 p-4 overflow-y-auto">
          <h2 className="text-white text-xl font-bold mb-4">Управление</h2>
          
          {/* Game Status */}
          <div className="mb-6 p-3 bg-gray-600 rounded">
            <h3 className="text-white font-semibold mb-2">Статус игры</h3>
            {gameState.winner ? (
              <div className={`p-2 rounded text-center font-bold ${
                gameState.winner === 'player' ? 'bg-green-600 text-white' : 'bg-red-600 text-white'
              }`}>
                {gameState.winner === 'player' ? 'ПОБЕДА!' : 'ПОРАЖЕНИЕ!'}
              </div>
            ) : (
              <div className="text-green-400">Битва идет...</div>
            )}
            <div className="text-white mt-2">
              Время: {Math.round(gameState.game_time)}с
            </div>
          </div>

          {/* Energy Display */}
          <div className="mb-6 p-3 bg-gray-600 rounded">
            <h3 className="text-yellow-400 font-semibold">
              Энергия: {Math.round(gameState.player_core.energy)}/{gameState.player_core.max_energy}
            </h3>
            <div className="w-full bg-gray-800 rounded-full h-3 mt-2">
              <div 
                className="bg-yellow-400 h-3 rounded-full transition-all"
                style={{ 
                  width: `${(gameState.player_core.energy / gameState.player_core.max_energy) * 100}%` 
                }}
              ></div>
            </div>
          </div>

          {/* Unit Spawning */}
          <div className="mb-6">
            <h3 className="text-white font-semibold mb-3">Призвать юнитов</h3>
            <div className="space-y-2">
              <button
                onClick={() => spawnUnit('soldier')}
                disabled={!canAfford(UNIT_COSTS.soldier) || gameState.winner}
                className={`w-full p-3 rounded font-semibold transition-colors ${
                  canAfford(UNIT_COSTS.soldier) && !gameState.winner
                    ? 'bg-blue-600 hover:bg-blue-700 text-white'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                }`}
              >
                🟦 Солдат ({UNIT_COSTS.soldier} энергии)
                <div className="text-sm">HP: 100, Урон: 15, Скорость: 100</div>
              </button>
              
              <button
                onClick={() => spawnUnit('tank')}
                disabled={!canAfford(UNIT_COSTS.tank) || gameState.winner}
                className={`w-full p-3 rounded font-semibold transition-colors ${
                  canAfford(UNIT_COSTS.tank) && !gameState.winner
                    ? 'bg-blue-800 hover:bg-blue-900 text-white'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                }`}
              >
                ⬛ Танк ({UNIT_COSTS.tank} энергии)
                <div className="text-sm">HP: 200, Урон: 40, Скорость: 60</div>
              </button>
              
              <button
                onClick={() => spawnUnit('drone')}
                disabled={!canAfford(UNIT_COSTS.drone) || gameState.winner}
                className={`w-full p-3 rounded font-semibold transition-colors ${
                  canAfford(UNIT_COSTS.drone) && !gameState.winner
                    ? 'bg-blue-400 hover:bg-blue-500 text-white'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                }`}
              >
                🔵 Дрон ({UNIT_COSTS.drone} энергии)
                <div className="text-sm">HP: 60, Урон: 10, Скорость: 160</div>
              </button>
            </div>
          </div>

          {/* Building Construction */}
          <div className="mb-6">
            <h3 className="text-white font-semibold mb-3">Построить здания</h3>
            <div className="space-y-2">
              <button
                onClick={() => setSelectedBuildingType('tower')}
                disabled={!canAfford(BUILDING_COSTS.tower) || gameState.winner}
                className={`w-full p-3 rounded font-semibold transition-colors ${
                  selectedBuildingType === 'tower' 
                    ? 'bg-blue-800 text-white ring-2 ring-white'
                    : canAfford(BUILDING_COSTS.tower) && !gameState.winner
                    ? 'bg-blue-600 hover:bg-blue-700 text-white'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                }`}
              >
                🔺 Башня ({BUILDING_COSTS.tower} энергии)
                <div className="text-sm">HP: 200, Урон: 25, Дальность: 200</div>
              </button>
              
              <button
                onClick={() => setSelectedBuildingType('barracks')}
                disabled={!canAfford(BUILDING_COSTS.barracks) || gameState.winner}
                className={`w-full p-3 rounded font-semibold transition-colors ${
                  selectedBuildingType === 'barracks'
                    ? 'bg-blue-800 text-white ring-2 ring-white'
                    : canAfford(BUILDING_COSTS.barracks) && !gameState.winner
                    ? 'bg-blue-600 hover:bg-blue-700 text-white'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                }`}
              >
                ⬢ Барак ({BUILDING_COSTS.barracks} энергии)
                <div className="text-sm">HP: 150, Производит солдат каждые 5с</div>
              </button>
            </div>
            
            {selectedBuildingType && (
              <div className="mt-3 p-2 bg-yellow-600 rounded text-center">
                <div className="text-white font-semibold">
                  Режим строительства: {selectedBuildingType === 'tower' ? 'Башня' : 'Барак'}
                </div>
                <div className="text-yellow-100 text-sm">
                  Кликните на карте для размещения
                </div>
                <button
                  onClick={() => setSelectedBuildingType(null)}
                  className="mt-2 px-3 py-1 bg-red-600 text-white rounded text-sm"
                >
                  Отмена
                </button>
              </div>
            )}
          </div>

          {/* Army Stats */}
          <div className="p-3 bg-gray-600 rounded">
            <h3 className="text-white font-semibold mb-2">Ваша армия</h3>
            <div className="text-white text-sm space-y-1">
              <div>Солдаты: {gameState.units.filter(u => u.team === 'player' && u.type === 'soldier').length}</div>
              <div>Танки: {gameState.units.filter(u => u.team === 'player' && u.type === 'tank').length}</div>
              <div>Дроны: {gameState.units.filter(u => u.team === 'player' && u.type === 'drone').length}</div>
              <div>Башни: {gameState.buildings.filter(b => b.team === 'player' && b.type === 'tower').length}</div>
              <div>Бараки: {gameState.buildings.filter(b => b.team === 'player' && b.type === 'barracks').length}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <div className="App">
      <GameCanvas />
    </div>
  );
}

export default App;