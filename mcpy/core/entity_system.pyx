# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True
"""
Entity system for MCPy.

This module handles all entity-related operations, including:
- Entity lifecycle management
- Physics simulation
- AI and behavior
- Entity-world interaction
"""

# Import from standard libraries
from libc.stdlib cimport malloc, free, calloc, realloc
from libc.string cimport memset, memcpy
from cpython cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from libc.time cimport time_t, time
from libc.math cimport sqrt, pow, cos, sin, fabs, fmod, ceil, floor

# NumPy imports
import numpy as np
cimport numpy as np
np.import_array()

# Python imports
import logging
import os
import threading
import time as py_time
import uuid
from collections import defaultdict
from typing import Dict, List, Optional, Set, Tuple, Any, Union

# Define constants
DEF MAX_ENTITIES = 10000
DEF ENTITY_INACTIVE_THRESHOLD = 60  # Seconds before an entity is considered inactive
DEF CHUNK_SIZE = 16
DEF PHYSICS_SUBSTEPS = 4
DEF GRAVITY = -9.8
DEF TERMINAL_VELOCITY = -78.4

# Define entity types
cdef enum EntityType:
    # Players
    PLAYER = 0
    
    # Hostile Mobs
    ZOMBIE = 1
    SKELETON = 2
    CREEPER = 3
    SPIDER = 4
    CAVE_SPIDER = 5
    ENDERMAN = 6
    SLIME = 7
    MAGMA_CUBE = 8
    BLAZE = 9
    WITCH = 10
    WITHER_SKELETON = 11
    GHAST = 12
    GUARDIAN = 13
    ELDER_GUARDIAN = 14
    PHANTOM = 15
    DROWNED = 16
    VINDICATOR = 17
    PILLAGER = 18
    RAVAGER = 19
    
    # Passive Mobs
    PIG = 50
    COW = 51
    SHEEP = 52
    CHICKEN = 53
    HORSE = 54
    DONKEY = 55
    RABBIT = 56
    VILLAGER = 57
    WOLF = 58
    CAT = 59
    PARROT = 60
    TURTLE = 61
    PANDA = 62
    FOX = 63
    BEE = 64
    AXOLOTL = 65
    GOAT = 66
    
    # Neutral Mobs (attack when provoked)
    IRON_GOLEM = 80
    SNOW_GOLEM = 81
    LLAMA = 82
    POLAR_BEAR = 83
    DOLPHIN = 84
    PIGLIN = 85
    ENDERMITE = 86
    SILVERFISH = 87
    
    # Projectiles
    ARROW = 100
    TRIDENT = 101
    FIREBALL = 102
    SMALL_FIREBALL = 103
    EGG = 104
    SNOWBALL = 105
    ENDER_PEARL = 106
    SPLASH_POTION = 107
    
    # Items and Blocks
    ITEM = 150
    FALLING_BLOCK = 151
    ITEM_FRAME = 152
    ARMOR_STAND = 153
    PAINTING = 154
    EXPERIENCE_ORB = 155
    
    # Vehicles
    BOAT = 200
    MINECART = 201
    MINECART_CHEST = 202
    MINECART_FURNACE = 203
    MINECART_HOPPER = 204
    MINECART_TNT = 205
    
    # Special
    LIGHTNING_BOLT = 250
    FISHING_BOBBER = 251
    AREA_EFFECT_CLOUD = 252
    TNT = 253
    FIREWORK_ROCKET = 254
    EVOKER_FANGS = 255

# Logger
logger = logging.getLogger("mcpy.entity_system")

cdef class EntityPhysics:
    """Handles physics simulation for entities."""
    def __cinit__(self, object world_engine):
        self.world_engine = world_engine
        
    cpdef bint update_position(self, Entity entity, double delta_time) except? False:
        """Update the entity's position based on physics."""
        cdef double old_x = entity.x
        cdef double old_y = entity.y
        cdef double old_z = entity.z
        cdef double step_time = delta_time / PHYSICS_SUBSTEPS
        
        # Declare variables outside the loop
        cdef double new_x, new_y, new_z
        
        # Apply physics in smaller substeps for stability
        for _ in range(PHYSICS_SUBSTEPS):
            # Apply gravity if entity is affected by it
            if entity.affected_by_gravity and not entity.on_ground:
                entity.velocity_y += GRAVITY * step_time
                
                # Limit to terminal velocity
                if entity.velocity_y < TERMINAL_VELOCITY:
                    entity.velocity_y = TERMINAL_VELOCITY
                    
            # Apply velocity
            new_x = entity.x + entity.velocity_x * step_time
            new_y = entity.y + entity.velocity_y * step_time
            new_z = entity.z + entity.velocity_z * step_time
            
            # Apply collision detection
            self._handle_collision(entity, new_x, new_y, new_z)
        
        # Check if entity moved to a new chunk
        cdef int32_t old_chunk_x = <int32_t>(old_x / CHUNK_SIZE)
        cdef int32_t old_chunk_z = <int32_t>(old_z / CHUNK_SIZE)
        cdef int32_t new_chunk_x = <int32_t>(entity.x / CHUNK_SIZE)
        cdef int32_t new_chunk_z = <int32_t>(entity.z / CHUNK_SIZE)
        
        if old_chunk_x != new_chunk_x or old_chunk_z != new_chunk_z:
            entity.chunk_x = new_chunk_x
            entity.chunk_z = new_chunk_z
            return True  # Entity changed chunks
            
        return False
        
    cdef void _handle_collision(self, Entity entity, double new_x, double new_y, double new_z):
        """Handle collisions with the world."""
        cdef double entity_width = entity.width
        cdef double entity_height = entity.height
        
        # Check for collisions with blocks
        cdef bint x_collision = self._check_collision(entity, new_x, entity.y, entity.z, entity_width, entity_height)
        cdef bint y_collision = self._check_collision(entity, entity.x, new_y, entity.z, entity_width, entity_height)
        cdef bint z_collision = self._check_collision(entity, entity.x, entity.y, new_z, entity_width, entity_height)
        
        # Update position if no collision
        if not x_collision:
            entity.x = new_x
        else:
            entity.velocity_x = 0
            
        if not y_collision:
            entity.y = new_y
            entity.on_ground = False
        else:
            # If collision while moving down, entity is on ground
            if entity.velocity_y < 0:
                entity.on_ground = True
            entity.velocity_y = 0
            
        if not z_collision:
            entity.z = new_z
        else:
            entity.velocity_z = 0
            
        # Check if entity is standing on ground
        if not entity.on_ground:
            entity.on_ground = self._check_on_ground(entity)
            
    cdef bint _check_collision(self, Entity entity, double x, double y, double z, double width, double height) except? True:
        """Check if the entity collides with blocks at the given position."""
        cdef int min_x = <int>floor(x - width / 2)
        cdef int max_x = <int>ceil(x + width / 2)
        cdef int min_y = <int>floor(y)
        cdef int max_y = <int>ceil(y + height)
        cdef int min_z = <int>floor(z - width / 2)
        cdef int max_z = <int>ceil(z + width / 2)
        
        # Check each block in the entity's bounding box
        for bx in range(min_x, max_x):
            for by in range(min_y, max_y):
                for bz in range(min_z, max_z):
                    block = self.world_engine.get_block(bx, by, bz)
                    
                    # Check if block is solid
                    if self._is_solid_block(block):
                        return True
                        
        return False
        
    cdef bint _check_on_ground(self, Entity entity) except? False:
        """Check if the entity is standing on a solid block."""
        cdef int min_x = <int>floor(entity.x - entity.width / 2)
        cdef int max_x = <int>ceil(entity.x + entity.width / 2)
        cdef int y = <int>floor(entity.y - 0.1)  # Just below the entity
        cdef int min_z = <int>floor(entity.z - entity.width / 2)
        cdef int max_z = <int>ceil(entity.z + entity.width / 2)
        
        # Check blocks below the entity
        for bx in range(min_x, max_x):
            for bz in range(min_z, max_z):
                block = self.world_engine.get_block(bx, y, bz)
                
                # Check if block is solid
                if self._is_solid_block(block):
                    return True
                    
        return False
        
    cdef bint _is_solid_block(self, uint8_t block_id) except? True:
        """Check if a block is solid."""
        # This would be replaced with a proper block property lookup
        # For now, just a simple check
        return block_id != 0 and block_id != 8  # Not air and not water

cdef class Entity:
    """Base class for all entities in the game."""
        
    def __cinit__(self, int entity_type, double x, double y, double z):
        self.entity_type = entity_type
        self.x = x
        self.y = y
        self.z = z
        self.yaw = 0.0
        self.pitch = 0.0
        self.velocity_x = 0.0
        self.velocity_y = 0.0
        self.velocity_z = 0.0
        self.width = 0.6  # Default size
        self.height = 1.8  # Default size
        self.on_ground = False
        self.affected_by_gravity = True
        self.active = True
        self.last_active_time = <uint64_t>time(NULL)
        self.data = {}
        self.chunk_x = <int32_t>(x / CHUNK_SIZE)
        self.chunk_z = <int32_t>(z / CHUNK_SIZE)
        
        # Generate a unique ID for the entity
        self.id = hash(uuid.uuid4())
        
    cpdef void update(self, uint64_t tick_number):
        """Update the entity state for this tick."""
        # To be implemented by subclasses
        pass
        
    cpdef dict to_data(self):
        """Convert the entity to a data dictionary for serialization."""
        return {
            'id': self.id,
            'type': self.entity_type,
            'x': self.x,
            'y': self.y,
            'z': self.z,
            'yaw': self.yaw,
            'pitch': self.pitch,
            'velocity_x': self.velocity_x,
            'velocity_y': self.velocity_y,
            'velocity_z': self.velocity_z,
            'data': self.data,
        }
        
    @staticmethod
    def from_data(dict data):
        """Create an entity from a data dictionary."""
        entity = Entity(data['type'], data['x'], data['y'], data['z'])
        entity.id = data['id']
        entity.yaw = data['yaw']
        entity.pitch = data['pitch']
        entity.velocity_x = data['velocity_x']
        entity.velocity_y = data['velocity_y']
        entity.velocity_z = data['velocity_z']
        entity.data = data['data']
        return entity
        
    cpdef void mark_active(self):
        """Mark the entity as active."""
        self.active = True
        self.last_active_time = <uint64_t>time(NULL)

cdef class PlayerEntity(Entity):
    """Represents a player in the game."""
        
    def __cinit__(self, *args, **kwargs):
        # Skip Entity.__cinit__ by using different signature
        pass
        
    def __init__(self, str username, object uuid_obj, double x, double y, double z):
        # Manually initialize Entity fields since we have different constructor signature
        self.entity_type = EntityType.PLAYER
        self.x = x
        self.y = y
        self.z = z
        self.yaw = 0.0
        self.pitch = 0.0
        self.velocity_x = 0.0
        self.velocity_y = 0.0
        self.velocity_z = 0.0
        self.width = 0.6  # Player width
        self.height = 1.8  # Player height
        self.on_ground = False
        self.affected_by_gravity = True
        self.active = True
        self.last_active_time = <uint64_t>time(NULL)
        self.data = {}
        self.chunk_x = <int32_t>(x / CHUNK_SIZE)
        self.chunk_z = <int32_t>(z / CHUNK_SIZE)
        
        # Generate a unique ID for the entity
        self.id = hash(uuid.uuid4())
        
        # Initialize PlayerEntity-specific fields
        self.username = username
        self.uuid = uuid_obj
        self.health = 20
        self.food_level = 20
        self.experience = 0.0
        self.level = 0
        self.inventory = {}
        self.connection = None
        
        # Override entity properties
        self.width = 0.6
        self.height = 1.8
        
    cpdef void update(self, uint64_t tick_number):
        """Update the player entity."""
        # Player state updates
        self.mark_active()  # Players are always active
        
        # Handle player regeneration
        if self.health < 20 and self.food_level >= 18 and tick_number % 80 == 0:  # Every 4 seconds
            self.health = min(20, self.health + 1)
            
        # Handle hunger
        if tick_number % 400 == 0:  # Every 20 seconds
            # Decrease food level based on activity
            if self.velocity_x != 0 or self.velocity_z != 0:
                self.food_level = max(0, self.food_level - 1)
                
    cpdef dict to_data(self):
        """Convert the player to a data dictionary."""
        data = super().to_data()
        data.update({
            'username': self.username,
            'uuid': str(self.uuid),
            'health': self.health,
            'food_level': self.food_level,
            'experience': self.experience,
            'level': self.level,
            'inventory': self.inventory,
        })
        return data
        
    @staticmethod
    def from_data(dict data):
        """Create a player from a data dictionary."""
        import uuid as uuid_module
        player = PlayerEntity(
            data['username'],
            uuid_module.UUID(data['uuid']),
            data['x'],
            data['y'],
            data['z']
        )
        player.id = data['id']
        player.yaw = data['yaw']
        player.pitch = data['pitch']
        player.velocity_x = data['velocity_x']
        player.velocity_y = data['velocity_y']
        player.velocity_z = data['velocity_z']
        player.health = data['health']
        player.food_level = data['food_level']
        player.experience = data['experience']
        player.level = data['level']
        player.inventory = data['inventory']
        player.data = data['data']
        return player

cdef class MobEntity(Entity):
    """Base class for mobile entities with AI."""
        
    def __cinit__(self, int entity_type, double x, double y, double z, int health, bint hostile):
        # Call Entity.__cinit__ explicitly with proper args
        Entity.__cinit__(self, entity_type, x, y, z)
        self.health = health
        self.max_health = health
        self.ai_controller = None
        self.hostile = hostile
        
    cpdef void update(self, uint64_t tick_number):
        """Update the mob entity."""
        # Handle AI and behavior
        if self.ai_controller is not None:
            self.ai_controller.update(self, tick_number)
            
        # Check for inactivity
        cdef uint64_t current_time = <uint64_t>time(NULL)
        if current_time - self.last_active_time > ENTITY_INACTIVE_THRESHOLD:
            self.active = False
            
    cpdef dict to_data(self):
        """Convert the mob to a data dictionary."""
        data = super().to_data()
        data.update({
            'health': self.health,
            'max_health': self.max_health,
            'hostile': self.hostile,
        })
        return data
        
    @staticmethod
    def from_data(dict data):
        """Create a mob from a data dictionary."""
        mob = MobEntity(
            data['type'],
            data['x'],
            data['y'],
            data['z'],
            data['health'],
            data['hostile']
        )
        mob.id = data['id']
        mob.yaw = data['yaw']
        mob.pitch = data['pitch']
        mob.velocity_x = data['velocity_x']
        mob.velocity_y = data['velocity_y']
        mob.velocity_z = data['velocity_z']
        mob.max_health = data['max_health']
        mob.data = data['data']
        return mob
        
    cpdef void damage(self, int amount, Entity source=None):
        """Apply damage to the mob."""
        self.health = max(0, self.health - amount)
        self.mark_active()
        
        # Handle death
        if self.health <= 0:
            self.on_death(source)
            
    cpdef void heal(self, int amount):
        """Heal the mob."""
        self.health = min(self.max_health, self.health + amount)
        self.mark_active()
        
    cpdef void on_death(self, Entity source=None):
        """Handle mob death."""
        # Drop items, award experience, etc.
        self.active = False

cdef class HostileMobEntity(MobEntity):
    """Hostile mob entities that can attack."""
    
    def __cinit__(self, int entity_type, double x, double y, double z, int health):
        # Call MobEntity.__cinit__ explicitly with proper args
        MobEntity.__cinit__(self, entity_type, x, y, z, health, True)
        self.attack_damage = 1.0
        self.attack_range = 2.0
        self.detection_range = 16.0
        self.attack_cooldown = 20  # 1 second at 20 TPS
        self.last_attack_time = 0
        
    cpdef void update(self, uint64_t tick_number):
        """Update the hostile mob entity."""
        super().update(tick_number)
        # Add hostile AI logic here
        
    cpdef dict to_data(self):
        """Convert the hostile mob to a data dictionary."""
        data = super().to_data()
        data.update({
            'attack_damage': self.attack_damage,
            'attack_range': self.attack_range,
            'detection_range': self.detection_range,
            'attack_cooldown': self.attack_cooldown,
            'last_attack_time': self.last_attack_time,
        })
        return data
        
    cpdef bint can_attack(self, uint64_t current_tick) except? False:
        """Check if the mob can attack."""
        return (current_tick - self.last_attack_time) >= self.attack_cooldown
        
    cpdef void attack(self, Entity target, uint64_t current_tick):
        """Attack a target entity."""
        if self.can_attack(current_tick) and target is not None:
            # Apply damage to target if it's a mob or player
            if isinstance(target, MobEntity):
                (<MobEntity>target).damage(<int>self.attack_damage, self)
            elif isinstance(target, PlayerEntity):
                # Handle player damage
                player = <PlayerEntity>target
                player.health = max(0, player.health - <int>self.attack_damage)
            self.last_attack_time = current_tick
            
    cdef double _get_attack_damage(self, int entity_type):
        """Get the attack damage for a specific entity type."""
        # Basic damage values - can be expanded
        if entity_type == EntityType.ZOMBIE:
            return 3.0
        elif entity_type == EntityType.SKELETON:
            return 2.5
        elif entity_type == EntityType.CREEPER:
            return 8.0  # Explosion damage
        elif entity_type == EntityType.SPIDER:
            return 2.0
        else:
            return 1.0

cdef class PassiveMobEntity(MobEntity):
    """Passive mob entities that can breed."""
    
    def __cinit__(self, int entity_type, double x, double y, double z, int health):
        # Call MobEntity.__cinit__ explicitly with proper args
        MobEntity.__cinit__(self, entity_type, x, y, z, health, False)
        self.breeding_cooldown = 6000  # 5 minutes at 20 TPS
        self.last_bred_time = 0
        self.is_baby = False
        self.growth_time = 24000  # 20 minutes at 20 TPS
        
    cpdef void update(self, uint64_t tick_number):
        """Update the passive mob entity."""
        super().update(tick_number)
        # Handle baby growth
        if self.is_baby and (tick_number - self.last_bred_time) >= self.growth_time:
            self.is_baby = False
            
    cpdef dict to_data(self):
        """Convert the passive mob to a data dictionary."""
        data = super().to_data()
        data.update({
            'breeding_cooldown': self.breeding_cooldown,
            'last_bred_time': self.last_bred_time,
            'is_baby': self.is_baby,
            'growth_time': self.growth_time,
        })
        return data
        
    cpdef bint can_breed(self, uint64_t current_tick) except? False:
        """Check if the mob can breed."""
        return not self.is_baby and (current_tick - self.last_bred_time) >= self.breeding_cooldown
        
    cpdef PassiveMobEntity breed(self, PassiveMobEntity partner, uint64_t current_tick):
        """Breed with another passive mob."""
        if self.can_breed(current_tick) and partner.can_breed(current_tick):
            # Create a baby mob of the same type
            baby = PassiveMobEntity(self.entity_type, self.x, self.y, self.z, self.max_health)
            baby.is_baby = True
            baby.last_bred_time = current_tick
            
            # Update parent breeding times
            self.last_bred_time = current_tick
            partner.last_bred_time = current_tick
            
            return baby
        return None

cdef class VehicleEntity(Entity):
    """Vehicle entities that can carry passengers."""
    
    def __cinit__(self, int entity_type, double x, double y, double z):
        # Call Entity.__cinit__ explicitly with proper args
        Entity.__cinit__(self, entity_type, x, y, z)
        self.passengers = []
        self.max_speed = 8.0
        self.acceleration = 0.1
        self.deceleration = 0.05
        self.is_powered = False
        
    cpdef void update(self, uint64_t tick_number):
        """Update the vehicle entity."""
        super().update(tick_number)
        # Handle vehicle physics and passenger updates
        
    cpdef dict to_data(self):
        """Convert the vehicle to a data dictionary."""
        data = super().to_data()
        data.update({
            'passengers': [p.id for p in self.passengers],
            'max_speed': self.max_speed,
            'acceleration': self.acceleration,
            'deceleration': self.deceleration,
            'is_powered': self.is_powered,
        })
        return data
        
    cpdef bint add_passenger(self, Entity entity) except? False:
        """Add a passenger to the vehicle."""
        if entity is not None and entity not in self.passengers:
            self.passengers.append(entity)
            return True
        return False
        
    cpdef bint remove_passenger(self, Entity entity) except? False:
        """Remove a passenger from the vehicle."""
        if entity is not None and entity in self.passengers:
            self.passengers.remove(entity)
            return True
        return False

cdef class FallingBlockEntity(Entity):
    """Falling block entities."""
    
    def __cinit__(self, uint8_t block_id, uint8_t data_value, double x, double y, double z):
        # Call Entity.__cinit__ explicitly with proper args
        Entity.__cinit__(self, EntityType.FALLING_BLOCK, x, y, z)
        self.block_id = block_id
        self.data_value = data_value
        self.time_existed = 0
        self.can_hurt_entities = True
        
    cpdef void update(self, uint64_t tick_number):
        """Update the falling block entity."""
        super().update(tick_number)
        self.time_existed += 1
        
        # Check if block should stop falling
        if self.on_ground or self.time_existed > 6000:  # 5 minutes max fall time
            self.active = False
            
    cpdef dict to_data(self):
        """Convert the falling block to a data dictionary."""
        data = super().to_data()
        data.update({
            'block_id': self.block_id,
            'data_value': self.data_value,
            'time_existed': self.time_existed,
            'can_hurt_entities': self.can_hurt_entities,
        })
        return data

cdef class EntityFactory:
    """Factory for creating entities."""
    
    def __cinit__(self, object world_engine):
        self.world_engine = world_engine
        
    cpdef Entity create_entity(self, int entity_type, double x, double y, double z, dict additional_data=None):
        """Create an entity of the specified type."""
        if additional_data is None:
            additional_data = {}
            
        cdef Entity entity = None
        
        # Create different entity types
        if entity_type == EntityType.PLAYER:
            # Players should be created via EntitySystem.add_player
            return None
        elif entity_type in [EntityType.ZOMBIE, EntityType.SKELETON, EntityType.CREEPER, EntityType.SPIDER]:
            # Hostile mobs
            health = self._get_mob_health(entity_type)
            entity = HostileMobEntity(entity_type, x, y, z, health)
            self._configure_mob_properties(<MobEntity>entity, entity_type, additional_data)
        elif entity_type in [EntityType.PIG, EntityType.COW, EntityType.SHEEP, EntityType.CHICKEN]:
            # Passive mobs
            health = self._get_mob_health(entity_type)
            entity = PassiveMobEntity(entity_type, x, y, z, health)
            self._configure_mob_properties(<MobEntity>entity, entity_type, additional_data)
        elif entity_type == EntityType.ITEM:
            # Items
            item_id = additional_data.get('item_id', 1)
            count = additional_data.get('count', 1)
            entity = ItemEntity(item_id, count, x, y, z)
        elif entity_type in [EntityType.BOAT, EntityType.MINECART]:
            # Vehicles
            entity = VehicleEntity(entity_type, x, y, z)
        elif entity_type == EntityType.FALLING_BLOCK:
            # Falling blocks
            block_id = additional_data.get('block_id', 1)
            data_value = additional_data.get('data_value', 0)
            entity = FallingBlockEntity(block_id, data_value, x, y, z)
        else:
            # Default to basic entity
            entity = Entity(entity_type, x, y, z)
            
        return entity
        
    cdef void _configure_mob_properties(self, MobEntity mob, int entity_type, dict additional_data):
        """Configure mob-specific properties."""
        if mob is None:
            return
            
        # Set entity-specific properties
        if entity_type == EntityType.ZOMBIE:
            mob.width = 0.6
            mob.height = 1.95
        elif entity_type == EntityType.SKELETON:
            mob.width = 0.6
            mob.height = 1.99
        elif entity_type == EntityType.CREEPER:
            mob.width = 0.6
            mob.height = 1.7
        elif entity_type == EntityType.PIG:
            mob.width = 0.9
            mob.height = 0.9
        elif entity_type == EntityType.COW:
            mob.width = 0.9
            mob.height = 1.4
            
    cdef int _get_mob_health(self, int entity_type):
        """Get the health for a specific mob type."""
        if entity_type == EntityType.ZOMBIE:
            return 20
        elif entity_type == EntityType.SKELETON:
            return 20
        elif entity_type == EntityType.CREEPER:
            return 20
        elif entity_type == EntityType.SPIDER:
            return 16
        elif entity_type == EntityType.PIG:
            return 10
        elif entity_type == EntityType.COW:
            return 10
        elif entity_type == EntityType.SHEEP:
            return 8
        elif entity_type == EntityType.CHICKEN:
            return 4
        else:
            return 20  # Default health

cdef class ItemEntity(Entity):
    """Represents an item in the world."""
        
    def __cinit__(self, int item_id, int count, double x, double y, double z):
        # Call Entity.__cinit__ explicitly with proper args
        Entity.__cinit__(self, EntityType.ITEM, x, y, z)
        self.item_id = item_id
        self.count = count
        self.metadata = {}
        self.pickup_delay = <uint64_t>time(NULL) + 1  # 1 second pickup delay
        self.despawn_time = <uint64_t>time(NULL) + 300  # 5 minutes before despawn
        
        # Override entity properties
        self.width = 0.25
        self.height = 0.25
        
    cpdef void update(self, uint64_t tick_number):
        """Update the item entity."""
        # Check if the item should despawn
        cdef uint64_t current_time = <uint64_t>time(NULL)
        if current_time >= self.despawn_time:
            self.active = False
            
    cpdef dict to_data(self):
        """Convert the item to a data dictionary."""
        data = super().to_data()
        data.update({
            'item_id': self.item_id,
            'count': self.count,
            'metadata': self.metadata,
            'pickup_delay': self.pickup_delay,
            'despawn_time': self.despawn_time,
        })
        return data
        
    @staticmethod
    def from_data(dict data):
        """Create an item from a data dictionary."""
        item = ItemEntity(
            data['item_id'],
            data['count'],
            data['x'],
            data['y'],
            data['z']
        )
        item.id = data['id']
        item.yaw = data['yaw']
        item.pitch = data['pitch']
        item.velocity_x = data['velocity_x']
        item.velocity_y = data['velocity_y']
        item.velocity_z = data['velocity_z']
        item.metadata = data['metadata']
        item.pickup_delay = data['pickup_delay']
        item.despawn_time = data['despawn_time']
        item.data = data['data']
        return item

cdef class ProjectileEntity(Entity):
    """Base class for projectiles like arrows."""
        
    def __cinit__(self, int entity_type, Entity shooter, double x, double y, double z, double velocity_x, double velocity_y, double velocity_z):
        # Call Entity.__cinit__ explicitly with proper args
        Entity.__cinit__(self, entity_type, x, y, z)
        self.shooter = shooter
        self.velocity_x = velocity_x
        self.velocity_y = velocity_y
        self.velocity_z = velocity_z
        self.damage = 1.0
        self.creation_time = <uint64_t>time(NULL)
        self.max_age = 30  # 30 seconds max age
        
    cpdef void update(self, uint64_t tick_number):
        """Update the projectile entity."""
        # Check if the projectile should despawn
        cdef uint64_t current_time = <uint64_t>time(NULL)
        if current_time - self.creation_time >= self.max_age:
            self.active = False
            
    cpdef dict to_data(self):
        """Convert the projectile to a data dictionary."""
        data = super().to_data()
        data.update({
            'shooter_id': self.shooter.id if self.shooter else 0,
            'damage': self.damage,
            'creation_time': self.creation_time,
            'max_age': self.max_age,
        })
        return data

cdef class EntityError(Exception):
    """Base exception for entity-related errors."""
    pass

cdef class EntityTypeMismatchError(EntityError):
    """Raised when an entity of the wrong type is provided."""
    pass

cdef class EntityLimitExceededError(EntityError):
    """Raised when the maximum entity count is exceeded."""
    pass

cdef class EntityNotFoundError(EntityError):
    """Raised when an entity cannot be found."""
    pass

cdef class EntityOperationError(EntityError):
    """Raised when an operation on an entity fails."""
    pass

cdef class EntityTracker:
    """
    Tracks and manages entities in the world with safe operations.
    Provides thread-safe operations on the entity collection.
    """
        
    def __cinit__(self, int max_entities=MAX_ENTITIES):
        self.entities = {}
        self.entities_by_type = {}
        self.entities_by_chunk = defaultdict(set)
        self.max_entities = max_entities
        self.entity_lock = threading.RLock()
        
    cpdef void add_entity(self, Entity entity) except *:
        """Add an entity to tracking."""
        if entity is None:
            raise EntityOperationError("Cannot add None entity")
            
        if len(self.entities) >= self.max_entities:
            raise EntityLimitExceededError(f"Maximum entity count ({self.max_entities}) reached")
            
        with self.entity_lock:
            # Add to main entities dict
            self.entities[entity.id] = entity
            
            # Add to type tracking
            if entity.entity_type not in self.entities_by_type:
                self.entities_by_type[entity.entity_type] = {}
            self.entities_by_type[entity.entity_type][entity.id] = entity
            
            # Add to chunk tracking
            chunk_key = f"{entity.chunk_x},{entity.chunk_z}"
            self.entities_by_chunk[chunk_key].add(entity.id)
            
    cpdef void remove_entity(self, uint64_t entity_id) except *:
        """Remove an entity from tracking."""
        with self.entity_lock:
            if entity_id not in self.entities:
                raise EntityNotFoundError(f"Entity with ID {entity_id} not found")
                
            entity = self.entities[entity_id]
            
            # Remove from main entities dict
            del self.entities[entity_id]
            
            # Remove from type tracking
            if entity.entity_type in self.entities_by_type and entity_id in self.entities_by_type[entity.entity_type]:
                del self.entities_by_type[entity.entity_type][entity_id]
                
                # Clean up empty type dicts
                if not self.entities_by_type[entity.entity_type]:
                    del self.entities_by_type[entity.entity_type]
                    
            # Remove from chunk tracking
            chunk_key = f"{entity.chunk_x},{entity.chunk_z}"
            if chunk_key in self.entities_by_chunk and entity_id in self.entities_by_chunk[chunk_key]:
                self.entities_by_chunk[chunk_key].remove(entity_id)
                
                # Clean up empty chunk sets
                if not self.entities_by_chunk[chunk_key]:
                    del self.entities_by_chunk[chunk_key]
                    
    cpdef void update_entity_chunk(self, Entity entity) except *:
        """Update the chunk tracking for an entity."""
        if entity is None:
            raise EntityOperationError("Cannot update chunk for None entity")
            
        cdef str old_chunk_key = f"{entity.chunk_x},{entity.chunk_z}"
        cdef int32_t new_chunk_x = <int32_t>(entity.x / CHUNK_SIZE)
        cdef int32_t new_chunk_z = <int32_t>(entity.z / CHUNK_SIZE)
        cdef str new_chunk_key = f"{new_chunk_x},{new_chunk_z}"
        
        if old_chunk_key == new_chunk_key:
            return  # No change
            
        with self.entity_lock:
            # Remove from old chunk
            if old_chunk_key in self.entities_by_chunk and entity.id in self.entities_by_chunk[old_chunk_key]:
                self.entities_by_chunk[old_chunk_key].remove(entity.id)
                
                # Clean up empty chunk sets
                if not self.entities_by_chunk[old_chunk_key]:
                    del self.entities_by_chunk[old_chunk_key]
                    
            # Add to new chunk
            self.entities_by_chunk[new_chunk_key].add(entity.id)
            
            # Update entity's chunk coordinates
            entity.chunk_x = new_chunk_x
            entity.chunk_z = new_chunk_z
            
    cpdef Entity get_entity(self, uint64_t entity_id) except *:
        """Get an entity by ID."""
        with self.entity_lock:
            if entity_id not in self.entities:
                raise EntityNotFoundError(f"Entity with ID {entity_id} not found")
            return self.entities[entity_id]
            
    cpdef list get_entities_of_type(self, int entity_type):
        """Get all entities of a specific type."""
        with self.entity_lock:
            if entity_type not in self.entities_by_type:
                return []
            return list(self.entities_by_type[entity_type].values())
            
    cpdef list get_entities_in_chunks(self, list chunk_coords):
        """Get all entities in the specified chunks."""
        cdef list result = []
        
        with self.entity_lock:
            for chunk_x, chunk_z in chunk_coords:
                chunk_key = f"{chunk_x},{chunk_z}"
                if chunk_key in self.entities_by_chunk:
                    for entity_id in self.entities_by_chunk[chunk_key]:
                        if entity_id in self.entities:
                            result.append(self.entities[entity_id])
                            
        return result
        
    cpdef list get_entities_in_range(self, double x, double y, double z, double radius):
        """Get all entities within a radius of the given position."""
        cdef list result = []
        cdef double squared_radius = radius * radius
        cdef Entity entity
        
        with self.entity_lock:
            for entity in self.entities.values():
                dx = entity.x - x
                dy = entity.y - y
                dz = entity.z - z
                
                # Quick distance check using squared distance
                if dx*dx + dy*dy + dz*dz <= squared_radius:
                    result.append(entity)
                    
        return result
        
    cpdef int get_entity_count(self):
        """Get the total number of entities."""
        with self.entity_lock:
            return len(self.entities)
            
    cpdef int get_entity_count_of_type(self, int entity_type):
        """Get the number of entities of a specific type."""
        with self.entity_lock:
            if entity_type not in self.entities_by_type:
                return 0
            return len(self.entities_by_type[entity_type])
            
    cpdef bint entity_exists(self, uint64_t entity_id) except? -1:
        """Check if an entity exists."""
        with self.entity_lock:
            return entity_id in self.entities

cdef class EntitySystem:
    """Main entity management system with improved error handling and tracking."""
        
    def __cinit__(self, object world_engine, int max_entities=MAX_ENTITIES):
        self.world_engine = world_engine
        self.players = {}
        self.physics = EntityPhysics(world_engine)
        self.factory = EntityFactory(world_engine)
        self.tracker = EntityTracker(max_entities)
        self.max_entities = max_entities
        
        logger.info(f"Entity system initialized with max entities: {max_entities}")
        
    cpdef void update(self, uint64_t tick_number):
        """Update all entities for this tick."""
        cdef double delta_time = 1.0 / 20.0  # Assuming 20 TPS
        cdef Entity entity
        cdef list to_remove = []
        
        try:
            # Get a copy of entities to iterate safely
            entities_copy = list(self.tracker.entities.values())
            
            # Update all entities
            for entity in entities_copy:
                if not entity.active:
                    to_remove.append(entity.id)
                    continue
                    
                try:
                    # Update entity state
                    entity.update(tick_number)
                    
                    # Update physics
                    if entity.affected_by_gravity or entity.velocity_x != 0 or entity.velocity_y != 0 or entity.velocity_z != 0:
                        chunk_changed = self.physics.update_position(entity, delta_time)
                        
                        # Update chunk tracking if the entity moved to a new chunk
                        if chunk_changed:
                            self.tracker.update_entity_chunk(entity)
                except Exception as e:
                    logger.error(f"Error updating entity {entity.id}: {str(e)}")
                    # If update fails critically, mark for removal
                    if isinstance(e, (RuntimeError, MemoryError, SystemError)):
                        to_remove.append(entity.id)
                        
            # Remove inactive or errored entities
            for entity_id in to_remove:
                try:
                    self._remove_entity(entity_id)
                except Exception as e:
                    logger.error(f"Error removing entity {entity_id}: {str(e)}")
                    
        except Exception as e:
            logger.error(f"Critical error in entity system update: {str(e)}")
            
    cpdef Entity spawn_entity(self, int entity_type, double x, double y, double z, dict additional_data=None):
        """
        Spawn a new entity in the world with improved error handling.
        
        Parameters:
        -----------
        entity_type : int
            The type of entity to spawn (from EntityType enum)
        x, y, z : double
            The position to spawn the entity at
        additional_data : dict, optional
            Additional data to initialize the entity with
            
        Returns:
        --------
        Entity
            The spawned entity, or None if the entity could not be spawned
        """
        cdef Entity entity
        
        # Special case for players
        if entity_type == EntityType.PLAYER:
            logger.warning("Cannot spawn player entity directly. Use add_player instead.")
            return None
            
        try:
            # Use the factory to create the entity
            entity = self.factory.create_entity(entity_type, x, y, z, additional_data)
            
            if entity is None:
                logger.error(f"Failed to create entity of type {entity_type}")
                return None
                
            # Add the entity to tracking
            self.tracker.add_entity(entity)
            
            logger.debug(f"Spawned entity of type {entity_type} at ({x:.2f}, {y:.2f}, {z:.2f}) with ID {entity.id}")
            
            return entity
            
        except EntityLimitExceededError as e:
            logger.warning(f"Cannot spawn entity: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error spawning entity of type {entity_type}: {str(e)}")
            return None
            
    cpdef PlayerEntity add_player(self, str username, object uuid_obj, double x, double y, double z):
        """Add a player to the world with improved error handling."""
        try:
            # Check if player already exists
            for player in self.players.values():
                if player.username == username or player.uuid == uuid_obj:
                    return player
                    
            # Create the player
            player = PlayerEntity(username, uuid_obj, x, y, z)
            
            # Add the player to tracking
            self.tracker.add_entity(player)
            self.players[player.id] = player
            
            logger.info(f"Player {username} added at ({x}, {y}, {z})")
            
            return player
            
        except EntityLimitExceededError as e:
            logger.warning(f"Cannot add player {username}: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error adding player {username}: {str(e)}")
            return None
            
    cpdef void remove_player(self, uint64_t player_id):
        """Remove a player from the world with improved error handling."""
        try:
            if player_id in self.players:
                player = self.players[player_id]
                logger.info(f"Player {player.username} removed")
                
                # Remove from players dict
                del self.players[player_id]
                
                # Remove from entity tracking
                self._remove_entity(player_id)
        except Exception as e:
            logger.error(f"Error removing player {player_id}: {str(e)}")
            
    def _remove_entity(self, uint64_t entity_id):
        """Remove an entity from tracking with proper error handling."""
        try:
            self.tracker.remove_entity(entity_id)
        except EntityNotFoundError:
            # Already removed or never existed
            pass
            
    cpdef list get_entities_in_range(self, double x, double z, double radius):
        """Get all entities within a radius of the given position."""
        try:
            return self.tracker.get_entities_in_range(x, 64.0, z, radius)
        except Exception as e:
            logger.error(f"Error getting entities in range: {str(e)}")
            return []
            
    cpdef list get_entities_in_chunks(self, list chunk_coords):
        """Get all entities in the specified chunks."""
        try:
            return self.tracker.get_entities_in_chunks(chunk_coords)
        except Exception as e:
            logger.error(f"Error getting entities in chunks: {str(e)}")
            return []
            
    cpdef Entity get_entity_by_id(self, uint64_t entity_id):
        """Get an entity by its ID."""
        try:
            return self.tracker.get_entity(entity_id)
        except EntityNotFoundError:
            return None
        except Exception as e:
            logger.error(f"Error getting entity {entity_id}: {str(e)}")
            return None
            
    cpdef PlayerEntity get_player_by_name(self, str username):
        """Get a player by username."""
        try:
            for player in self.players.values():
                if player.username.lower() == username.lower():
                    return player
            return None
        except Exception as e:
            logger.error(f"Error getting player by name {username}: {str(e)}")
            return None
            
    cpdef int get_active_entity_count(self):
        """Get the number of active entities."""
        try:
            return self.tracker.get_entity_count()
        except Exception as e:
            logger.error(f"Error getting entity count: {str(e)}")
            return 0
            
    cpdef list get_entities_of_type(self, int entity_type):
        """Get all entities of a specific type."""
        try:
            return self.tracker.get_entities_of_type(entity_type)
        except Exception as e:
            logger.error(f"Error getting entities of type {entity_type}: {str(e)}")
            return []
            
    cpdef void cleanup(self):
        """Clean up resources."""
        logger.info("Cleaning up entity system resources")
        # Nothing special to clean up currently
