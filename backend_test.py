import requests
import json
import time
import sys
import asyncio
import websockets
from datetime import datetime

class TerrionRTSTester:
    def __init__(self, base_url="https://c130068d-9d0c-4ee7-bb84-6ef0e9baa15d.preview.emergentagent.com"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.ws_url = base_url.replace('https://', 'wss://').replace('http://', 'ws://')
        self.game_id = None
        self.tests_run = 0
        self.tests_passed = 0

    def run_test(self, name, method, endpoint, expected_status, data=None, params=None):
        """Run a single API test"""
        url = f"{self.api_url}/{endpoint}"
        headers = {'Content-Type': 'application/json'}

        self.tests_run += 1
        print(f"\n🔍 Testing {name}...")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, params=params)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers, params=params)

            success = response.status_code == expected_status
            if success:
                self.tests_passed += 1
                print(f"✅ Passed - Status: {response.status_code}")
                try:
                    return success, response.json()
                except:
                    return success, {}
            else:
                print(f"❌ Failed - Expected {expected_status}, got {response.status_code}")
                try:
                    print(f"Response: {response.text}")
                    return False, response.json()
                except:
                    return False, {}

        except Exception as e:
            print(f"❌ Failed - Error: {str(e)}")
            return False, {}

    def test_create_game(self):
        """Test creating a new game"""
        success, response = self.run_test(
            "Create Game",
            "POST",
            "game/create",
            200
        )
        
        if success and 'game_id' in response:
            self.game_id = response['game_id']
            print(f"📝 Game created with ID: {self.game_id}")
            return True
        return False

    def test_spawn_unit(self, unit_type):
        """Test spawning a unit"""
        if not self.game_id:
            print("❌ Cannot spawn unit: No game ID")
            return False
            
        success, response = self.run_test(
            f"Spawn {unit_type}",
            "POST",
            f"game/{self.game_id}/spawn/{unit_type}",
            200
        )
        
        if success:
            print(f"🎮 {unit_type.capitalize()} spawned successfully")
        return success

    def test_build_structure(self, building_type, x, y):
        """Test building a structure"""
        if not self.game_id:
            print("❌ Cannot build structure: No game ID")
            return False
            
        success, response = self.run_test(
            f"Build {building_type}",
            "POST",
            f"game/{self.game_id}/build/{building_type}",
            200,
            params={"x": x, "y": y}
        )
        
        if success:
            print(f"🏗️ {building_type.capitalize()} built at ({x}, {y})")
        return success

    def test_get_game_state(self):
        """Test getting the game state"""
        if not self.game_id:
            print("❌ Cannot get game state: No game ID")
            return False
            
        success, response = self.run_test(
            "Get Game State",
            "GET",
            f"game/{self.game_id}/state",
            200
        )
        
        if success:
            print(f"🎮 Game state retrieved successfully")
            # Print some game state info
            if 'player_core' in response:
                print(f"Player energy: {response['player_core']['energy']}")
                print(f"Player health: {response['player_core']['health']}")
            if 'enemy_core' in response:
                print(f"Enemy health: {response['enemy_core']['health']}")
            if 'units' in response:
                print(f"Total units: {len(response['units'])}")
            if 'buildings' in response:
                print(f"Total buildings: {len(response['buildings'])}")
        return success

    def test_api_sequence(self):
        """Test a sequence of API calls to verify game logic"""
        if not self.game_id:
            print("❌ Cannot test API sequence: No game ID")
            return False
            
        print("\n🎮 Testing API sequence...")
        
        # Get initial state
        success, initial_state = self.run_test(
            "Get Initial State",
            "GET",
            f"game/{self.game_id}/state",
            200
        )
        
        if not success:
            return False
            
        initial_energy = initial_state['player_core']['energy']
        initial_units = len(initial_state['units'])
        print(f"Initial energy: {initial_energy}, Initial units: {initial_units}")
        
        # Spawn a soldier
        success, _ = self.run_test(
            "Spawn Soldier",
            "POST",
            f"game/{self.game_id}/spawn/soldier",
            200
        )
        
        if not success:
            return False
            
        # Get state after spawning
        success, after_spawn_state = self.run_test(
            "Get State After Spawn",
            "GET",
            f"game/{self.game_id}/state",
            200
        )
        
        if not success:
            return False
            
        after_spawn_energy = after_spawn_state['player_core']['energy']
        after_spawn_units = len(after_spawn_state['units'])
        
        # Verify energy was deducted (soldier costs 20)
        energy_deducted = initial_energy - after_spawn_energy
        energy_test_passed = energy_deducted > 0
        
        if energy_test_passed:
            print(f"✅ Energy deduction working: Used {energy_deducted} energy to spawn soldier")
            self.tests_passed += 1
        else:
            print(f"❌ Energy not deducted properly: Before {initial_energy}, After {after_spawn_energy}")
        
        self.tests_run += 1
        
        # Verify unit was added
        units_added = after_spawn_units - initial_units
        units_test_passed = units_added > 0
        
        if units_test_passed:
            print(f"✅ Unit spawning working: Added {units_added} units")
            self.tests_passed += 1
        else:
            print(f"❌ Unit not added properly: Before {initial_units}, After {after_spawn_units}")
        
        self.tests_run += 1
        
        # Build a tower
        success, _ = self.run_test(
            "Build Tower",
            "POST",
            f"game/{self.game_id}/build/tower",
            200,
            params={"x": 300, "y": 400}
        )
        
        if not success:
            return False
            
        # Get state after building
        success, after_build_state = self.run_test(
            "Get State After Building",
            "GET",
            f"game/{self.game_id}/state",
            200
        )
        
        if not success:
            return False
            
        after_build_energy = after_build_state['player_core']['energy']
        after_build_buildings = len(after_build_state['buildings'])
        
        # Verify energy was deducted for building (tower costs 50)
        building_energy_deducted = after_spawn_energy - after_build_energy
        building_energy_test_passed = building_energy_deducted > 0
        
        if building_energy_test_passed:
            print(f"✅ Building energy deduction working: Used {building_energy_deducted} energy to build tower")
            self.tests_passed += 1
        else:
            print(f"❌ Building energy not deducted properly: Before {after_spawn_energy}, After {after_build_energy}")
        
        self.tests_run += 1
        
        # Verify building was added
        buildings_test_passed = after_build_buildings > 0
        
        if buildings_test_passed:
            print(f"✅ Building construction working: Now have {after_build_buildings} buildings")
            self.tests_passed += 1
        else:
            print(f"❌ Building not added properly: Have {after_build_buildings} buildings")
        
        self.tests_run += 1
        
        return energy_test_passed and units_test_passed and building_energy_test_passed and buildings_test_passed
        
    async def test_websocket_connection(self):
        """Test WebSocket connection and real-time updates"""
        if not self.game_id:
            print("❌ Cannot test WebSocket: No game ID")
            return False
            
        print(f"\n🔌 Testing WebSocket connection to {self.ws_url}/ws/{self.game_id}...")
        self.tests_run += 1
        
        try:
            # Connect to WebSocket
            async with websockets.connect(f"{self.ws_url}/ws/{self.game_id}") as websocket:
                print("✅ WebSocket connection established")
                
                # Wait for initial game state
                initial_state = await websocket.recv()
                try:
                    game_state = json.loads(initial_state)
                    print("✅ Received initial game state via WebSocket")
                    print(f"Player energy: {game_state['player_core']['energy']}")
                    print(f"Game time: {game_state['game_time']}")
                    
                    # Wait for a few updates to verify real-time updates
                    print("Waiting for real-time updates...")
                    start_time = game_state['game_time']
                    
                    # Wait for 3 seconds to get updates
                    for i in range(3):
                        update = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                        updated_state = json.loads(update)
                        print(f"Update {i+1}: Game time: {updated_state['game_time']}, Player energy: {updated_state['player_core']['energy']}")
                    
                    end_time = updated_state['game_time']
                    time_passed = end_time - start_time
                    
                    # Verify time is advancing
                    if time_passed > 0:
                        print(f"✅ Game time advancing: {time_passed:.2f} seconds passed")
                        
                        # Verify energy generation
                        initial_energy = game_state['player_core']['energy']
                        final_energy = updated_state['player_core']['energy']
                        energy_generated = final_energy - initial_energy
                        
                        if energy_generated > 0:
                            print(f"✅ Energy generation working: Generated {energy_generated:.2f} energy")
                            self.tests_passed += 1
                            return True
                        else:
                            print(f"❌ Energy generation not working properly")
                            return False
                    else:
                        print(f"❌ Game time not advancing properly")
                        return False
                    
                except json.JSONDecodeError:
                    print(f"❌ Received invalid JSON from WebSocket: {initial_state}")
                    return False
                    
        except Exception as e:
            print(f"❌ WebSocket connection failed: {str(e)}")
            return False

def main():
    # Setup
    tester = TerrionRTSTester()
    
    try:
        # Create game
        if not tester.test_create_game():
            print("❌ Game creation failed, stopping tests")
            return 1
            
        # Get game state via API
        tester.test_get_game_state()
        
        # Test spawning units
        tester.test_spawn_unit("soldier")
        tester.test_spawn_unit("tank")
        tester.test_spawn_unit("drone")
        
        # Test building structures
        tester.test_build_structure("tower", 300, 400)
        tester.test_build_structure("barracks", 200, 300)
        
        # Test API sequence to verify game logic
        tester.test_api_sequence()
        
        # Print results
        print(f"\n📊 Tests passed: {tester.tests_passed}/{tester.tests_run}")
        return 0 if tester.tests_passed == tester.tests_run else 1
        
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())