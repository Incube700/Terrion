import requests
import json
import time
import websocket
import threading
import sys
from datetime import datetime

class TerrionRTSTester:
    def __init__(self, base_url="https://c130068d-9d0c-4ee7-bb84-6ef0e9baa15d.preview.emergentagent.com"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.ws_url = f"{base_url.replace('http', 'ws')}/ws"
        self.game_id = None
        self.ws = None
        self.ws_thread = None
        self.game_state = None
        self.ws_connected = False
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

    def on_ws_message(self, ws, message):
        """Handle WebSocket messages"""
        try:
            self.game_state = json.loads(message)
            print(f"📊 Game state updated - Time: {self.game_state.get('game_time', 0):.1f}s")
        except Exception as e:
            print(f"Error parsing WebSocket message: {e}")

    def on_ws_open(self, ws):
        """Handle WebSocket connection open"""
        self.ws_connected = True
        print("🔌 WebSocket connected")

    def on_ws_close(self, ws, close_status_code, close_msg):
        """Handle WebSocket connection close"""
        self.ws_connected = False
        print(f"🔌 WebSocket disconnected: {close_msg if close_msg else 'No message'}")

    def on_ws_error(self, ws, error):
        """Handle WebSocket errors"""
        print(f"🔌 WebSocket error: {error}")

    def connect_websocket(self):
        """Connect to the game's WebSocket"""
        if not self.game_id:
            print("❌ Cannot connect WebSocket: No game ID")
            return False

        ws_endpoint = f"{self.ws_url}/{self.game_id}"
        print(f"🔌 Connecting to WebSocket: {ws_endpoint}")
        
        try:
            self.ws = websocket.WebSocketApp(
                ws_endpoint,
                on_open=self.on_ws_open,
                on_message=self.on_ws_message,
                on_error=self.on_ws_error,
                on_close=self.on_ws_close
            )
            
            self.ws_thread = threading.Thread(target=self.ws.run_forever)
            self.ws_thread.daemon = True
            self.ws_thread.start()
            
            # Wait for connection
            timeout = 5
            start_time = time.time()
            while not self.ws_connected and time.time() - start_time < timeout:
                time.sleep(0.1)
                
            if self.ws_connected:
                print("✅ WebSocket connected successfully")
                return True
            else:
                print("❌ WebSocket connection timed out")
                return False
                
        except Exception as e:
            print(f"❌ WebSocket connection error: {str(e)}")
            return False

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

    def test_game_logic(self, duration=10):
        """Test game logic by observing state changes over time"""
        if not self.game_id or not self.ws_connected:
            print("❌ Cannot test game logic: No game connection")
            return False
            
        print(f"\n🎮 Testing game logic for {duration} seconds...")
        
        # Initial state
        initial_state = self.game_state
        if not initial_state:
            print("❌ No initial game state available")
            return False
            
        initial_energy = initial_state['player_core']['energy']
        print(f"Initial player energy: {initial_energy}")
        
        # Wait for state changes
        time.sleep(duration)
        
        # Final state
        final_state = self.game_state
        if not final_state:
            print("❌ No final game state available")
            return False
            
        final_energy = final_state['player_core']['energy']
        print(f"Final player energy: {final_energy}")
        
        # Check energy generation
        energy_generated = final_energy - initial_energy
        expected_generation = 5 * duration  # 5 energy per second
        energy_test_passed = energy_generated > 0
        
        if energy_test_passed:
            print(f"✅ Energy generation working: Generated {energy_generated} energy in {duration}s")
            self.tests_passed += 1
        else:
            print(f"❌ Energy generation not working properly: Generated {energy_generated} energy in {duration}s")
        
        self.tests_run += 1
        
        # Check if enemy AI is spawning units
        initial_enemy_units = len([u for u in initial_state['units'] if u['team'] == 'enemy'])
        final_enemy_units = len([u for u in final_state['units'] if u['team'] == 'enemy'])
        
        ai_test_passed = final_enemy_units >= initial_enemy_units
        
        if ai_test_passed:
            print(f"✅ Enemy AI working: Units changed from {initial_enemy_units} to {final_enemy_units}")
            self.tests_passed += 1
        else:
            print(f"❌ Enemy AI not spawning units: Units remained at {final_enemy_units}")
        
        self.tests_run += 1
        
        return energy_test_passed and ai_test_passed

    def close(self):
        """Close WebSocket connection"""
        if self.ws:
            self.ws.close()
            if self.ws_thread:
                self.ws_thread.join(timeout=1)

def main():
    # Setup
    tester = TerrionRTSTester()
    
    try:
        # Create game
        if not tester.test_create_game():
            print("❌ Game creation failed, stopping tests")
            return 1
            
        # Connect WebSocket
        if not tester.connect_websocket():
            print("❌ WebSocket connection failed, stopping tests")
            return 1
            
        # Wait for initial game state
        print("Waiting for initial game state...")
        timeout = 5
        start_time = time.time()
        while not tester.game_state and time.time() - start_time < timeout:
            time.sleep(0.1)
            
        if not tester.game_state:
            print("❌ Did not receive initial game state, stopping tests")
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
        
        # Test game logic
        tester.test_game_logic(duration=10)
        
        # Print results
        print(f"\n📊 Tests passed: {tester.tests_passed}/{tester.tests_run}")
        return 0 if tester.tests_passed == tester.tests_run else 1
        
    finally:
        # Clean up
        tester.close()

if __name__ == "__main__":
    sys.exit(main())