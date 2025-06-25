import asyncio
import websockets
import json
import sys

async def test_websocket_connection():
    # Create a game first to get a game_id
    import requests
    
    base_url = "https://c130068d-9d0c-4ee7-bb84-6ef0e9baa15d.preview.emergentagent.com"
    api_url = f"{base_url}/api"
    
    print("Creating a game...")
    response = requests.post(f"{api_url}/game/create")
    if response.status_code != 200:
        print(f"Failed to create game: {response.text}")
        return
    
    game_data = response.json()
    game_id = game_data.get("game_id")
    
    if not game_id:
        print("No game_id returned from API")
        return
    
    print(f"Game created with ID: {game_id}")
    
    # Now try to connect to the WebSocket
    ws_url = f"wss://c130068d-9d0c-4ee7-bb84-6ef0e9baa15d.preview.emergentagent.com/ws/{game_id}"
    print(f"Connecting to WebSocket at {ws_url}")
    
    try:
        async with websockets.connect(ws_url) as websocket:
            print("WebSocket connection established!")
            
            # Wait for a message
            print("Waiting for game state message...")
            message = await asyncio.wait_for(websocket.recv(), timeout=5)
            
            # Try to parse the message as JSON
            try:
                game_state = json.loads(message)
                print("Received game state:")
                print(f"- Player energy: {game_state.get('player_core', {}).get('energy')}")
                print(f"- Enemy energy: {game_state.get('enemy_core', {}).get('energy')}")
                print(f"- Units: {len(game_state.get('units', []))}")
                print(f"- Buildings: {len(game_state.get('buildings', []))}")
                print(f"- Game time: {game_state.get('game_time')}")
                return True
            except json.JSONDecodeError:
                print(f"Received non-JSON message: {message}")
                return False
    
    except asyncio.TimeoutError:
        print("Timeout waiting for WebSocket message")
        return False
    except websockets.exceptions.ConnectionClosed as e:
        print(f"WebSocket connection closed: {e}")
        return False
    except Exception as e:
        print(f"WebSocket error: {e}")
        return False

if __name__ == "__main__":
    result = asyncio.run(test_websocket_connection())
    sys.exit(0 if result else 1)