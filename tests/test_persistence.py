"""Test the persistence layer of MCPy."""

import os
import sys
import unittest
import tempfile
from pathlib import Path
from typing import Dict, Any
from unittest.mock import MagicMock

# Add project root to path to import from mcpy
sys.path.insert(0, str(Path(__file__).parent.parent))

from mcpy.persistence.database import initialize_db, get_session, session_scope
from mcpy.persistence.models import Base, World, Chunk, Player, Entity, ServerStatistics
from mcpy.persistence.operations import (
    save_world, get_world,
    save_player, get_player,
    save_chunk, get_chunk,
    save_entity, get_entities_in_chunk
)


class TestPersistence(unittest.TestCase):
    """Test the persistence layer."""
    
    def setUp(self):
        """Set up test environment with an in-memory SQLite database."""
        self.config = {
            "database": {
                "type": "sqlite",
                "echo": False
            }
        }
        
        # Use in-memory database for testing
        self.engine = initialize_db({"database": {"type": "sqlite", "path": ":memory:"}})
        
        # Create all tables
        Base.metadata.create_all(self.engine)
        
    def tearDown(self):
        """Clean up test environment."""
        Base.metadata.drop_all(self.engine)
        
    def test_world_crud(self):
        """Test CRUD operations for World model."""
        # Create a world
        world_data = {
            "name": "test_world",
            "seed": 12345,
            "spawn_x": 0,
            "spawn_y": 64,
            "spawn_z": 0,
            "world_type": "default",
            "hardcore": False,
            "game_rules": {"doMobSpawning": True, "doWeatherCycle": True}
        }
        
        # Save world
        world_id = save_world(world_data)
        self.assertIsNotNone(world_id)
        
        # Get world
        saved_world = get_world("test_world")
        self.assertIsNotNone(saved_world)
        self.assertEqual(saved_world["name"], "test_world")
        self.assertEqual(saved_world["seed"], 12345)
        
        # Update world
        updated_data = world_data.copy()
        updated_data["hardcore"] = True
        updated_id = save_world(updated_data)
        self.assertEqual(updated_id, world_id)  # Same ID for update
        
        # Get updated world
        updated_world = get_world("test_world")
        self.assertTrue(updated_world["hardcore"])
        
    def test_player_crud(self):
        """Test CRUD operations for Player model."""
        # Create world first
        world_data = {
            "name": "test_world",
            "seed": 12345
        }
        world_id = save_world(world_data)
        
        # Create player
        player_data = {
            "uuid": "00000000-0000-0000-0000-000000000001",
            "username": "TestPlayer",
            "world_id": world_id,
            "x": 100.0,
            "y": 64.0,
            "z": 100.0,
            "health": 20.0,
            "food_level": 20,
            "experience": 0.0,
            "level": 0,
            "inventory": {"0": {"id": "minecraft:stone", "count": 64}}
        }
        
        # Save player
        player_id = save_player(player_data)
        self.assertIsNotNone(player_id)
        
        # Get player
        saved_player = get_player(player_data["uuid"])
        self.assertIsNotNone(saved_player)
        self.assertEqual(saved_player["username"], "TestPlayer")
        
        # Update player
        player_data["health"] = 10.0
        updated_id = save_player(player_data)
        self.assertEqual(updated_id, player_id)  # Same ID for update
        
        # Get updated player
        updated_player = get_player(player_data["uuid"])
        self.assertEqual(updated_player["health"], 10.0)
        
    def test_chunk_crud(self):
        """Test CRUD operations for Chunk model."""
        # Create world first
        world_data = {
            "name": "test_world",
            "seed": 12345
        }
        save_world(world_data)
        
        # Create chunk
        chunk_data = {
            "x": 0,
            "z": 0,
            "generated": True,
            "populated": True,
            "data": b'test_data'
        }
        
        # Save chunk
        chunk_id = save_chunk("test_world", chunk_data)
        self.assertIsNotNone(chunk_id)
        
        # Get chunk
        saved_chunk = get_chunk("test_world", 0, 0)
        self.assertIsNotNone(saved_chunk)
        self.assertEqual(saved_chunk["x"], 0)
        self.assertEqual(saved_chunk["z"], 0)
        self.assertEqual(saved_chunk["data"], b'test_data')
        
        # Update chunk
        chunk_data["data"] = b'updated_data'
        updated_id = save_chunk("test_world", chunk_data)
        self.assertEqual(updated_id, chunk_id)  # Same ID for update
        
        # Get updated chunk
        updated_chunk = get_chunk("test_world", 0, 0)
        self.assertEqual(updated_chunk["data"], b'updated_data')
        
    def test_entity_crud(self):
        """Test CRUD operations for Entity model."""
        # Create world first
        world_data = {
            "name": "test_world",
            "seed": 12345
        }
        save_world(world_data)
        
        # Create entity
        entity_data = {
            "entity_uuid": "entity-00001",
            "entity_type": "mob.zombie",
            "x": 100.0,
            "y": 64.0,
            "z": 100.0,
            "yaw": 0.0,
            "pitch": 0.0,
            "health": 20.0,
            "max_health": 20.0,
            "hostile": True,
            "on_ground": True,
            "active": True,
            "data": {"custom_name": "Test Zombie"}
        }
        
        # Save entity
        entity_id = save_entity("test_world", entity_data)
        self.assertIsNotNone(entity_id)
        
        # Get entity via chunk
        chunk_x = entity_data["x"] // 16
        chunk_z = entity_data["z"] // 16
        entities = get_entities_in_chunk("test_world", int(chunk_x), int(chunk_z))
        self.assertEqual(len(entities), 1)
        self.assertEqual(entities[0]["entity_type"], "mob.zombie")
        
    def test_session_scope(self):
        """Test session_scope context manager."""
        with session_scope() as session:
            # Create a world
            world = World(
                name="test_scope",
                seed=12345,
                spawn_x=0,
                spawn_y=64,
                spawn_z=0
            )
            session.add(world)
            
        # Session should be committed now
        session = get_session()
        loaded_world = session.query(World).filter_by(name="test_scope").first()
        self.assertIsNotNone(loaded_world)
        self.assertEqual(loaded_world.seed, 12345)
        session.close()
        
    def test_session_scope_rollback(self):
        """Test session_scope rollback on exception."""
        try:
            with session_scope() as session:
                # Create a world
                world = World(
                    name="test_rollback",
                    seed=12345,
                    spawn_x=0,
                    spawn_y=64,
                    spawn_z=0
                )
                session.add(world)
                
                # Raise an exception
                raise ValueError("Test exception")
        except ValueError:
            pass
            
        # Session should be rolled back
        session = get_session()
        loaded_world = session.query(World).filter_by(name="test_rollback").first()
        self.assertIsNone(loaded_world)
        session.close()
        
        
if __name__ == "__main__":
    unittest.main()
