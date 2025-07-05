"""
Tests for the MCPy entity system.
"""

import os
import shutil
import tempfile
import unittest
from unittest import mock
import uuid

import numpy as np

from mcpy.core.entity_system import (
    EntitySystem, Entity, PlayerEntity, MobEntity, ItemEntity,
    HostileMobEntity, PassiveMobEntity, VehicleEntity, FallingBlockEntity,
    ProjectileEntity, EntityFactory, EntityTracker,
    EntityError, EntityOperationError, EntityNotFoundError, EntityLimitExceededError
)
from mcpy.core.world_engine import WorldEngine


class MockWorld:
    """Mock world for testing."""
    
    def __init__(self):
        """Initialize the mock world."""
        self.blocks = {}
        
    def get_block(self, x, y, z):
        """Get a block from the world."""
        return self.blocks.get((x, y, z), 0)
        
    def set_block(self, x, y, z, block_id):
        """Set a block in the world."""
        self.blocks[(x, y, z)] = block_id
        return True


class TestEntity(unittest.TestCase):
    """Test the Entity class."""
    
    def test_initialization(self):
        """Test entity initialization."""
        entity = Entity(0, 100.5, 64.0, 200.5)
        
        self.assertEqual(entity.entity_type, 0)
        self.assertEqual(entity.x, 100.5)
        self.assertEqual(entity.y, 64.0)
        self.assertEqual(entity.z, 200.5)
        self.assertEqual(entity.velocity_x, 0.0)
        self.assertEqual(entity.velocity_y, 0.0)
        self.assertEqual(entity.velocity_z, 0.0)
        self.assertTrue(entity.active)
        self.assertTrue(entity.affected_by_gravity)
        self.assertFalse(entity.on_ground)
        
    def test_to_from_data(self):
        """Test conversion to and from data dictionaries."""
        entity = Entity(0, 100.5, 64.0, 200.5)
        entity.velocity_x = 0.1
        entity.velocity_y = 0.2
        entity.velocity_z = 0.3
        entity.yaw = 45.0
        entity.pitch = 30.0
        entity.data = {'custom': 'data'}
        
        data = entity.to_data()
        self.assertEqual(data['type'], 0)
        self.assertEqual(data['x'], 100.5)
        self.assertEqual(data['y'], 64.0)
        self.assertEqual(data['z'], 200.5)
        self.assertEqual(data['velocity_x'], 0.1)
        self.assertEqual(data['velocity_y'], 0.2)
        self.assertEqual(data['velocity_z'], 0.3)
        self.assertEqual(data['yaw'], 45.0)
        self.assertEqual(data['pitch'], 30.0)
        self.assertEqual(data['data'], {'custom': 'data'})
        
        new_entity = Entity.from_data(data)
        self.assertEqual(new_entity.entity_type, 0)
        self.assertEqual(new_entity.x, 100.5)
        self.assertEqual(new_entity.y, 64.0)
        self.assertEqual(new_entity.z, 200.5)
        self.assertEqual(new_entity.velocity_x, 0.1)
        self.assertEqual(new_entity.velocity_y, 0.2)
        self.assertEqual(new_entity.velocity_z, 0.3)
        self.assertEqual(new_entity.yaw, 45.0)
        self.assertEqual(new_entity.pitch, 30.0)
        self.assertEqual(new_entity.data, {'custom': 'data'})


class TestPlayerEntity(unittest.TestCase):
    """Test the PlayerEntity class."""
    
    def test_initialization(self):
        """Test player initialization."""
        player_uuid = uuid.uuid4()
        player = PlayerEntity("TestPlayer", player_uuid, 100.5, 64.0, 200.5)
        
        self.assertEqual(player.username, "TestPlayer")
        self.assertEqual(player.uuid, player_uuid)
        self.assertEqual(player.entity_type, 0)  # PLAYER
        self.assertEqual(player.x, 100.5)
        self.assertEqual(player.y, 64.0)
        self.assertEqual(player.z, 200.5)
        self.assertEqual(player.health, 20)
        self.assertEqual(player.food_level, 20)
        self.assertEqual(player.experience, 0.0)
        self.assertEqual(player.level, 0)
        
    def test_update(self):
        """Test player update."""
        player_uuid = uuid.uuid4()
        player = PlayerEntity("TestPlayer", player_uuid, 100.5, 64.0, 200.5)
        
        # Test regeneration at high food level
        player.health = 19
        player.food_level = 20
        player.update(80)  # Multiple of 80 to trigger regeneration
        self.assertEqual(player.health, 20)
        
        # Test no regeneration at low food level
        player.health = 19
        player.food_level = 17
        player.update(80)
        self.assertEqual(player.health, 19)
        
    def test_to_from_data(self):
        """Test conversion to and from data dictionaries."""
        player_uuid = uuid.uuid4()
        player = PlayerEntity("TestPlayer", player_uuid, 100.5, 64.0, 200.5)
        player.health = 15
        player.food_level = 18
        player.experience = 0.5
        player.level = 5
        player.inventory = {'slot_1': {'id': 1, 'count': 64}}
        
        data = player.to_data()
        self.assertEqual(data['username'], "TestPlayer")
        self.assertEqual(data['uuid'], str(player_uuid))
        self.assertEqual(data['health'], 15)
        self.assertEqual(data['food_level'], 18)
        self.assertEqual(data['experience'], 0.5)
        self.assertEqual(data['level'], 5)
        self.assertEqual(data['inventory'], {'slot_1': {'id': 1, 'count': 64}})
        
        new_player = PlayerEntity.from_data(data)
        self.assertEqual(new_player.username, "TestPlayer")
        self.assertEqual(str(new_player.uuid), str(player_uuid))
        self.assertEqual(new_player.health, 15)
        self.assertEqual(new_player.food_level, 18)
        self.assertEqual(new_player.experience, 0.5)
        self.assertEqual(new_player.level, 5)
        self.assertEqual(new_player.inventory, {'slot_1': {'id': 1, 'count': 64}})


class TestMobEntity(unittest.TestCase):
    """Test the MobEntity class."""
    
    def test_initialization(self):
        """Test mob initialization."""
        mob = MobEntity(1, 100.5, 64.0, 200.5, 20, True)  # ZOMBIE
        
        self.assertEqual(mob.entity_type, 1)
        self.assertEqual(mob.x, 100.5)
        self.assertEqual(mob.y, 64.0)
        self.assertEqual(mob.z, 200.5)
        self.assertEqual(mob.health, 20)
        self.assertEqual(mob.max_health, 20)
        self.assertTrue(mob.hostile)
        
    def test_damage_heal(self):
        """Test damaging and healing mobs."""
        mob = MobEntity(1, 100.5, 64.0, 200.5, 20, True)
        
        # Test damage
        mob.damage(5)
        self.assertEqual(mob.health, 15)
        
        # Test healing
        mob.heal(3)
        self.assertEqual(mob.health, 18)
        
        # Test healing beyond max health
        mob.heal(10)
        self.assertEqual(mob.health, 20)
        
        # Test fatal damage
        mob.damage(30)
        self.assertEqual(mob.health, 0)
        self.assertFalse(mob.active)


class TestItemEntity(unittest.TestCase):
    """Test the ItemEntity class."""
    
    def test_initialization(self):
        """Test item initialization."""
        item = ItemEntity(1, 64, 100.5, 64.0, 200.5)
        
        self.assertEqual(item.entity_type, 10)  # ITEM
        self.assertEqual(item.x, 100.5)
        self.assertEqual(item.y, 64.0)
        self.assertEqual(item.z, 200.5)
        self.assertEqual(item.item_id, 1)
        self.assertEqual(item.count, 64)
        self.assertTrue(hasattr(item, 'pickup_delay'))
        self.assertTrue(hasattr(item, 'despawn_time'))
        
    @mock.patch('mcpy.core.entity_system.time')
    def test_despawn(self, mock_time):
        """Test item despawning."""
        mock_time.return_value = 1000  # Current time
        
        item = ItemEntity(1, 64, 100.5, 64.0, 200.5)
        self.assertTrue(item.active)
        
        # Time hasn't advanced, so item should still be active
        mock_time.return_value = 1000
        item.update(0)
        self.assertTrue(item.active)
        
        # Time has advanced, but not enough to despawn
        mock_time.return_value = 1200
        item.update(0)
        self.assertTrue(item.active)
        
        # Time has advanced enough to despawn
        mock_time.return_value = 1500
        item.update(0)
        self.assertFalse(item.active)


class TestEntitySystem(unittest.TestCase):
    """Test the EntitySystem class."""
    
    def setUp(self):
        """Set up test environment."""
        self.world = MockWorld()
        self.entity_system = EntitySystem(self.world, max_entities=100)
        
    def test_spawn_entity(self):
        """Test spawning an entity."""
        entity = self.entity_system.spawn_entity(1, 100.5, 64.0, 200.5)  # ZOMBIE
        
        self.assertIsNotNone(entity)
        self.assertEqual(entity.entity_type, 1)
        self.assertEqual(entity.x, 100.5)
        self.assertEqual(entity.y, 64.0)
        self.assertEqual(entity.z, 200.5)
        
        # Check that the entity was added to tracking
        self.assertIn(entity.id, self.entity_system.entities)
        chunk_key = f"{entity.chunk_x},{entity.chunk_z}"
        self.assertIn(entity.id, self.entity_system.entities_by_chunk[chunk_key])
        
    def test_add_remove_player(self):
        """Test adding and removing a player."""
        player_uuid = uuid.uuid4()
        player = self.entity_system.add_player("TestPlayer", player_uuid, 100.5, 64.0, 200.5)
        
        self.assertIsNotNone(player)
        self.assertEqual(player.username, "TestPlayer")
        self.assertEqual(player.uuid, player_uuid)
        
        # Check that the player was added to tracking
        self.assertIn(player.id, self.entity_system.entities)
        self.assertIn(player.id, self.entity_system.players)
        chunk_key = f"{player.chunk_x},{player.chunk_z}"
        self.assertIn(player.id, self.entity_system.entities_by_chunk[chunk_key])
        
        # Remove the player
        self.entity_system.remove_player(player.id)
        
        # Check that the player was removed from tracking
        self.assertNotIn(player.id, self.entity_system.entities)
        self.assertNotIn(player.id, self.entity_system.players)
        self.assertNotIn(player.id, self.entity_system.entities_by_chunk.get(chunk_key, set()))
        
    def test_get_entities_in_range(self):
        """Test getting entities in range."""
        # Spawn entities at different positions
        entity1 = self.entity_system.spawn_entity(1, 100.0, 64.0, 100.0)
        entity2 = self.entity_system.spawn_entity(1, 105.0, 64.0, 100.0)
        entity3 = self.entity_system.spawn_entity(1, 120.0, 64.0, 100.0)
        
        # Get entities within a 10-block radius
        entities = self.entity_system.get_entities_in_range(100.0, 100.0, 10.0)
        self.assertEqual(len(entities), 2)
        self.assertIn(entity1, entities)
        self.assertIn(entity2, entities)
        self.assertNotIn(entity3, entities)
        
    def test_get_entities_in_chunks(self):
        """Test getting entities in specific chunks."""
        # Spawn entities in different chunks
        entity1 = self.entity_system.spawn_entity(1, 10.0, 64.0, 10.0)  # Chunk 0,0
        entity2 = self.entity_system.spawn_entity(1, 25.0, 64.0, 10.0)  # Chunk 1,0
        
        # Get entities in chunk 0,0
        entities = self.entity_system.get_entities_in_chunks([(0, 0)])
        self.assertEqual(len(entities), 1)
        self.assertIn(entity1, entities)
        
        # Get entities in chunks 0,0 and 1,0
        entities = self.entity_system.get_entities_in_chunks([(0, 0), (1, 0)])
        self.assertEqual(len(entities), 2)
        self.assertIn(entity1, entities)
        self.assertIn(entity2, entities)
        
    def test_get_entity_by_id(self):
        """Test getting an entity by ID."""
        entity = self.entity_system.spawn_entity(1, 100.0, 64.0, 100.0)
        
        # Get the entity by ID
        found_entity = self.entity_system.get_entity_by_id(entity.id)
        self.assertIs(found_entity, entity)
        
        # Try to get a non-existent entity
        found_entity = self.entity_system.get_entity_by_id(999999)
        self.assertIsNone(found_entity)
        
    def test_get_player_by_name(self):
        """Test getting a player by name."""
        player_uuid = uuid.uuid4()
        player = self.entity_system.add_player("TestPlayer", player_uuid, 100.0, 64.0, 100.0)
        
        # Get the player by name
        found_player = self.entity_system.get_player_by_name("TestPlayer")
        self.assertIs(found_player, player)
        
        # Try case-insensitive lookup
        found_player = self.entity_system.get_player_by_name("testplayer")
        self.assertIs(found_player, player)
        
        # Try to get a non-existent player
        found_player = self.entity_system.get_player_by_name("NonExistentPlayer")
        self.assertIsNone(found_player)


class TestExtendedEntities(unittest.TestCase):
    """Test the newly added entity classes."""
    
    def setUp(self):
        """Set up the test environment."""
        self.mock_world = MockWorld()
        self.entity_system = EntitySystem(self.mock_world)
    
    def test_hostile_mob_entity(self):
        """Test hostile mob entity creation and behaviors."""
        # Test zombie creation
        zombie = HostileMobEntity(1, 100.0, 64.0, 100.0, 20)
        self.assertEqual(zombie.entity_type, 1)  # ZOMBIE
        self.assertEqual(zombie.health, 20)
        self.assertTrue(zombie.hostile)
        self.assertGreater(zombie.attack_damage, 0)
        
        # Test attack cooldown
        self.assertTrue(zombie.can_attack(0))
        
        # Test attack
        player = PlayerEntity("TestPlayer", uuid.uuid4(), 100.0, 64.0, 101.0)
        player.health = 20
        zombie.attack(player, 0)
        self.assertLess(player.health, 20)
        
        # Test attack cooldown
        self.assertFalse(zombie.can_attack(0))  # Can't attack again immediately
        self.assertTrue(zombie.can_attack(30))  # Can attack after cooldown
    
    def test_passive_mob_entity(self):
        """Test passive mob entity creation and behaviors."""
        # Test cow creation
        cow1 = PassiveMobEntity(51, 100.0, 64.0, 100.0, 10)
        self.assertEqual(cow1.entity_type, 51)  # COW
        self.assertEqual(cow1.health, 10)
        self.assertFalse(cow1.hostile)
        self.assertFalse(cow1.is_baby)
        
        # Test breeding
        cow2 = PassiveMobEntity(51, 101.0, 64.0, 100.0, 10)
        
        # Should be able to breed initially
        self.assertTrue(cow1.can_breed(0))
        self.assertTrue(cow2.can_breed(0))
        
        # Breed cows
        baby_cow = cow1.breed(cow2, 0)
        
        # Verify baby properties
        self.assertIsNotNone(baby_cow)
        self.assertEqual(baby_cow.entity_type, 51)
        self.assertTrue(baby_cow.is_baby)
        self.assertEqual(baby_cow.health, 5)  # Half of parent's health
        
        # Parents should have breeding cooldown
        self.assertFalse(cow1.can_breed(0))
        self.assertFalse(cow2.can_breed(0))
        
        # After cooldown, should be able to breed again
        self.assertTrue(cow1.can_breed(10000))
    
    def test_vehicle_entity(self):
        """Test vehicle entity creation and behaviors."""
        # Test boat creation
        boat = VehicleEntity(200, 100.0, 64.0, 100.0)
        self.assertEqual(boat.entity_type, 200)  # BOAT
        self.assertGreater(boat.width, 0.6)  # Wider than player
        self.assertEqual(len(boat.passengers), 0)
        
        # Add passenger
        player = PlayerEntity("TestPlayer", uuid.uuid4(), 100.0, 64.0, 100.0)
        self.assertTrue(boat.add_passenger(player))
        self.assertEqual(len(boat.passengers), 1)
        self.assertEqual(boat.passengers[0].id, player.id)
        self.assertEqual(player.data.get('vehicle'), boat.id)
        
        # Remove passenger
        self.assertTrue(boat.remove_passenger(player))
        self.assertEqual(len(boat.passengers), 0)
        self.assertNotIn('vehicle', player.data)
    
    def test_falling_block_entity(self):
        """Test falling block entity creation and behaviors."""
        # Test falling sand
        sand_block = FallingBlockEntity(12, 0, 100.0, 70.0, 100.0)
        self.assertEqual(sand_block.entity_type, 12)  # FALLING_BLOCK
        self.assertEqual(sand_block.block_id, 12)  # Sand block ID
        self.assertEqual(sand_block.data_value, 0)
        self.assertEqual(sand_block.time_existed, 0)
        
        # Update should increment time
        sand_block.update(1)
        self.assertEqual(sand_block.time_existed, 1)
        
        # Simulate falling for a while
        sand_block.update(2)
        self.assertEqual(sand_block.time_existed, 2)
        
        # After 6000 ticks, should despawn
        sand_block.time_existed = 6000
        sand_block.update(6001)
        self.assertFalse(sand_block.active)


class TestEntityTracker(unittest.TestCase):
    """Test the EntityTracker class."""
    
    def setUp(self):
        """Set up the test environment."""
        self.tracker = EntityTracker(100)
        self.entity1 = Entity(0, 10.0, 64.0, 10.0)
        self.entity2 = Entity(1, 20.0, 64.0, 20.0)
        self.entity3 = Entity(2, 30.0, 64.0, 30.0)
    
    def test_add_entity(self):
        """Test adding entities to the tracker."""
        self.tracker.add_entity(self.entity1)
        self.assertEqual(self.tracker.get_entity_count(), 1)
        self.assertTrue(self.tracker.entity_exists(self.entity1.id))
        
        self.tracker.add_entity(self.entity2)
        self.assertEqual(self.tracker.get_entity_count(), 2)
        self.assertTrue(self.tracker.entity_exists(self.entity2.id))
        
        with self.assertRaises(EntityOperationError):
            self.tracker.add_entity(None)
    
    def test_remove_entity(self):
        """Test removing entities from the tracker."""
        # Add entities
        self.tracker.add_entity(self.entity1)
        self.tracker.add_entity(self.entity2)
        self.assertEqual(self.tracker.get_entity_count(), 2)
        
        # Remove entity
        self.tracker.remove_entity(self.entity1.id)
        self.assertEqual(self.tracker.get_entity_count(), 1)
        self.assertFalse(self.tracker.entity_exists(self.entity1.id))
        self.assertTrue(self.tracker.entity_exists(self.entity2.id))
        
        # Try to remove non-existent entity
        with self.assertRaises(EntityNotFoundError):
            self.tracker.remove_entity(999)
    
    def test_get_entities_in_range(self):
        """Test getting entities within a range."""
        # Add entities
        self.tracker.add_entity(self.entity1)
        self.tracker.add_entity(self.entity2)
        self.tracker.add_entity(self.entity3)
        
        # Get entities in range
        entities = self.tracker.get_entities_in_range(15.0, 64.0, 15.0, 10.0)
        self.assertEqual(len(entities), 1)
        self.assertEqual(entities[0].id, self.entity1.id)
        
        # Larger range
        entities = self.tracker.get_entities_in_range(20.0, 64.0, 20.0, 15.0)
        self.assertEqual(len(entities), 2)
        
        # Even larger range
        entities = self.tracker.get_entities_in_range(20.0, 64.0, 20.0, 30.0)
        self.assertEqual(len(entities), 3)
    
    def test_get_entities_of_type(self):
        """Test getting entities by type."""
        # Add entities
        self.tracker.add_entity(self.entity1)  # Type 0
        self.tracker.add_entity(self.entity2)  # Type 1
        self.tracker.add_entity(Entity(1, 25.0, 64.0, 25.0))  # Another Type 1
        
        # Get entities by type
        entities = self.tracker.get_entities_of_type(0)
        self.assertEqual(len(entities), 1)
        self.assertEqual(entities[0].id, self.entity1.id)
        
        entities = self.tracker.get_entities_of_type(1)
        self.assertEqual(len(entities), 2)
        
        entities = self.tracker.get_entities_of_type(999)  # Non-existent type
        self.assertEqual(len(entities), 0)
    
    def test_update_entity_chunk(self):
        """Test updating entity chunks."""
        # Add entity
        self.tracker.add_entity(self.entity1)
        old_chunk_x, old_chunk_z = self.entity1.chunk_x, self.entity1.chunk_z
        
        # Move entity to new chunk
        self.entity1.x += 32.0  # Move 2 chunks over
        
        # Update chunk tracking
        self.tracker.update_entity_chunk(self.entity1)
        self.assertNotEqual(old_chunk_x, self.entity1.chunk_x)
        
        # Entity should still be tracked
        self.assertTrue(self.tracker.entity_exists(self.entity1.id))
        
        # Try to update None entity
        with self.assertRaises(EntityOperationError):
            self.tracker.update_entity_chunk(None)


class TestEntityFactory(unittest.TestCase):
    """Test the EntityFactory class."""
    
    def setUp(self):
        """Set up the test environment."""
        self.mock_world = MockWorld()
        self.factory = EntityFactory(self.mock_world)
    
    def test_create_hostile_mob(self):
        """Test creating hostile mobs."""
        # Test zombie
        zombie = self.factory.create_entity(1, 100.0, 64.0, 100.0)
        self.assertEqual(zombie.entity_type, 1)  # ZOMBIE
        self.assertEqual(zombie.__class__.__name__, "MobEntity")
        self.assertTrue(zombie.hostile)
        
        # Test creeper
        creeper = self.factory.create_entity(3, 100.0, 64.0, 100.0)
        self.assertEqual(creeper.entity_type, 3)  # CREEPER
        self.assertTrue(creeper.hostile)
        
        # Test with additional data
        enderman = self.factory.create_entity(6, 100.0, 64.0, 100.0, {"held_block": 1})
        self.assertEqual(enderman.entity_type, 6)  # ENDERMAN
        self.assertTrue(enderman.hostile)
        self.assertEqual(enderman.data.get("held_block"), 1)
    
    def test_create_passive_mob(self):
        """Test creating passive mobs."""
        # Test cow
        cow = self.factory.create_entity(51, 100.0, 64.0, 100.0)
        self.assertEqual(cow.entity_type, 51)  # COW
        self.assertEqual(cow.__class__.__name__, "MobEntity")
        self.assertFalse(cow.hostile)
        
        # Test sheep with additional data
        sheep = self.factory.create_entity(52, 100.0, 64.0, 100.0, {"color": 0})
        self.assertEqual(sheep.entity_type, 52)  # SHEEP
        self.assertFalse(sheep.hostile)
        self.assertEqual(sheep.data.get("color"), 0)
    
    def test_create_projectile(self):
        """Test creating projectiles."""
        # Create a shooter entity
        player = PlayerEntity("TestPlayer", uuid.uuid4(), 100.0, 64.0, 100.0)
        
        # Test arrow
        arrow = self.factory.create_entity(100, 100.0, 65.0, 100.0, {
            "shooter": player,
            "velocity_x": 1.0,
            "velocity_y": 0.1,
            "velocity_z": 0.0
        })
        self.assertEqual(arrow.entity_type, 100)  # ARROW
        self.assertEqual(arrow.__class__.__name__, "ProjectileEntity")
        self.assertEqual(arrow.shooter, player)
        self.assertEqual(arrow.velocity_x, 1.0)
        
    def test_create_item(self):
        """Test creating item entities."""
        # Test item
        item = self.factory.create_entity(150, 100.0, 64.0, 100.0, {
            "item_id": 264,  # Diamond
            "count": 5
        })
        self.assertEqual(item.entity_type, 150)  # ITEM
        self.assertEqual(item.__class__.__name__, "ItemEntity")
        self.assertEqual(item.item_id, 264)
        self.assertEqual(item.count, 5)
    
    def test_create_falling_block(self):
        """Test creating falling block entities."""
        # Test falling block
        block = self.factory.create_entity(151, 100.0, 70.0, 100.0, {
            "block_id": 12,  # Sand
            "data_value": 0
        })
        self.assertEqual(block.entity_type, 151)  # FALLING_BLOCK
        self.assertEqual(block.data.get("block_id"), 12)
        self.assertEqual(block.data.get("data_value"), 0)
    
    def test_invalid_entity(self):
        """Test creating invalid entity types."""
        # Player should return None (use add_player instead)
        player = self.factory.create_entity(0, 100.0, 64.0, 100.0)
        self.assertIsNone(player)
        
        # Invalid type should return a generic entity
        generic = self.factory.create_entity(999, 100.0, 64.0, 100.0)
        self.assertEqual(generic.entity_type, 999)
        self.assertEqual(generic.__class__.__name__, "Entity")
