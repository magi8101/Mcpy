"""Integration with core modules for persistence."""

import logging
import time
from datetime import datetime
from typing import Dict, Any, Optional, Tuple, List

from ..core.entity_system import Entity, PlayerEntity, EntitySystem
from ..core.world_engine import Chunk, WorldEngine
from .database import initialize_db
from .models import Base
from .operations import (
    save_player, get_player, 
    save_chunk, get_chunk,
    save_world, get_world,
    save_entity, get_entities_in_chunk,
    save_statistics
)

logger = logging.getLogger("mcpy.persistence.integration")


class PersistenceManager:
    """Manager class for integrating persistence with core modules."""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize persistence manager.
        
        Args:
            config: Server configuration
        """
        self.config = config
        self.db_config = config.get("database", {})
        self.world_name = config.get("world", {}).get("name", "world")
        self.auto_save_interval = self.db_config.get("auto_save_interval", 300)  # 5 minutes
        self.last_auto_save = time.time()
        
        # Initialize database
        engine = initialize_db(config)
        
        # Create tables if they don't exist
        if self.db_config.get("create_tables", True):
            Base.metadata.create_all(engine)
            
        # Save world information
        self._initialize_world(config)
            
    def _initialize_world(self, config: Dict[str, Any]) -> None:
        """Initialize world data in the database.
        
        Args:
            config: Server configuration
        """
        world_config = config.get("world", {})
        world_data = {
            "name": self.world_name,
            "seed": world_config.get("seed", 0),
            "world_type": world_config.get("type", "default"),
            "hardcore": world_config.get("hardcore", False),
            "spawn_x": world_config.get("spawn_x", 0),
            "spawn_y": world_config.get("spawn_y", 64),
            "spawn_z": world_config.get("spawn_z", 0),
            "game_rules": world_config.get("game_rules", {}),
            "last_accessed": datetime.utcnow(),
        }
        
        # Get existing world or create new one
        existing_world = get_world(self.world_name)
        if existing_world:
            # Update only last_accessed time
            world_data = {"name": self.world_name, "last_accessed": datetime.utcnow()}
            
        save_world(world_data)
        logger.info(f"World '{self.world_name}' {'updated' if existing_world else 'created'} in database")
    
    def check_auto_save(self, world_engine: WorldEngine, entity_system: EntitySystem) -> bool:
        """Check if it's time for auto-save and perform it if necessary.
        
        Args:
            world_engine: The world engine instance
            entity_system: The entity system instance
            
        Returns:
            bool: True if auto-save was performed, False otherwise
        """
        current_time = time.time()
        if current_time - self.last_auto_save >= self.auto_save_interval:
            self.save_state(world_engine, entity_system)
            self.last_auto_save = current_time
            return True
        return False
    
    def save_state(self, world_engine: WorldEngine, entity_system: EntitySystem) -> None:
        """Save the current state of the world and entities.
        
        Args:
            world_engine: The world engine instance
            entity_system: The entity system instance
        """
        logger.info("Starting server state auto-save...")
        start_time = time.time()
        
        # Save active chunks
        saved_chunks = 0
        for chunk_coords, chunk in world_engine.chunks.items():
            if chunk.modified:
                self.save_chunk_data(chunk)
                saved_chunks += 1
                
        # Save entities
        saved_entities = 0
        for entity_id, entity in entity_system.entities.items():
            if isinstance(entity, PlayerEntity):
                self.save_player_data(entity)
            else:
                self.save_entity_data(entity)
            saved_entities += 1
        
        # Save server statistics
        self.save_server_stats(world_engine, entity_system)
        
        duration = time.time() - start_time
        logger.info(f"Auto-save completed in {duration:.2f}s: {saved_chunks} chunks, {saved_entities} entities")
    
    def save_player_data(self, player: PlayerEntity) -> None:
        """Save player data to the database.
        
        Args:
            player: Player entity to save
        """
        player_data = {
            "uuid": str(player.uuid),
            "username": player.username,
            "world_id": 1,  # This would need to be properly set based on world
            "x": float(player.x),
            "y": float(player.y),
            "z": float(player.z),
            "yaw": float(player.yaw),
            "pitch": float(player.pitch),
            "health": player.health,
            "food_level": player.food_level,
            "experience": float(player.experience),
            "level": player.level,
            "inventory": player.inventory,
            "last_seen": datetime.utcnow(),
        }
        
        save_player(player_data)
    
    def load_player_data(self, uuid_str: str) -> Dict[str, Any]:
        """Load player data from the database.
        
        Args:
            uuid_str: Player UUID string
            
        Returns:
            Dict: Player data, or empty dict if not found
        """
        player_data = get_player(uuid_str)
        if player_data:
            return player_data
        return {}
    
    def save_chunk_data(self, chunk: Chunk) -> None:
        """Save chunk data to the database.
        
        Args:
            chunk: Chunk object to save
        """
        # Convert to binary data
        import zlib
        import pickle
        
        try:
            # Serialize chunk data (this would be optimized in production)
            chunk_data_binary = zlib.compress(pickle.dumps(chunk.to_data()))
            
            chunk_data = {
                "x": chunk.x,
                "z": chunk.z,
                "generated": chunk.generated,
                "populated": chunk.populated,
                "data": chunk_data_binary,
                "last_saved": datetime.utcnow(),
            }
            
            save_chunk(self.world_name, chunk_data)
            
            # Reset modified flag after successful save
            chunk.modified = False
            
        except Exception as e:
            logger.error(f"Failed to save chunk data: {e}")
    
    def load_chunk_data(self, chunk_x: int, chunk_z: int) -> Dict[str, Any]:
        """Load chunk data from the database.
        
        Args:
            chunk_x: Chunk X coordinate
            chunk_z: Chunk Z coordinate
            
        Returns:
            Dict: Chunk data, or empty dict if not found
        """
        chunk_data = get_chunk(self.world_name, chunk_x, chunk_z)
        if not chunk_data:
            return {}
            
        try:
            # Deserialize chunk data
            import zlib
            import pickle
            
            binary_data = chunk_data.get("data")
            if binary_data:
                return pickle.loads(zlib.decompress(binary_data))
            return {}
        except Exception as e:
            logger.error(f"Failed to deserialize chunk data: {e}")
            return {}
    
    def save_entity_data(self, entity: Entity) -> None:
        """Save entity data to the database.
        
        Args:
            entity: Entity object to save
        """
        entity_data = {
            "entity_uuid": f"ent-{entity.id}",  # Generate a UUID from entity ID
            "entity_type": f"entity.type.{entity.__class__.__name__.lower()}",
            "x": float(entity.x),
            "y": float(entity.y),
            "z": float(entity.z),
            "yaw": float(entity.yaw),
            "pitch": float(entity.pitch),
            "velocity_x": float(entity.velocity_x),
            "velocity_y": float(entity.velocity_y),
            "velocity_z": float(entity.velocity_z),
            "on_ground": entity.on_ground,
            "active": entity.active,
            "data": entity.to_data(),
            "chunk_x": entity.chunk_x,
            "chunk_z": entity.chunk_z,
        }
        
        save_entity(self.world_name, entity_data)
    
    def load_entities_in_chunk(self, chunk_x: int, chunk_z: int) -> List[Dict[str, Any]]:
        """Load entities in a specific chunk from the database.
        
        Args:
            chunk_x: Chunk X coordinate
            chunk_z: Chunk Z coordinate
            
        Returns:
            List[Dict]: List of entity data
        """
        return get_entities_in_chunk(self.world_name, chunk_x, chunk_z)
    
    def save_server_stats(self, world_engine: WorldEngine, entity_system: EntitySystem) -> None:
        """Save server statistics to the database.
        
        Args:
            world_engine: The world engine instance
            entity_system: The entity system instance
        """
        try:
            # Get memory usage
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            memory_mb = memory_info.rss / (1024 * 1024)  # Convert to MB
            
            stats_data = {
                "timestamp": datetime.utcnow(),
                "players_online": len(entity_system.players),
                "memory_usage": memory_mb,
                "chunks_loaded": len(world_engine.chunks),
                "entities_loaded": entity_system.get_active_entity_count(),
                # These would come from the server metrics
                # "cpu_usage": server_metrics.cpu_usage,
                # "tick_duration": server_metrics.last_tick_duration,
            }
            
            save_statistics(stats_data)
        except Exception as e:
            logger.error(f"Failed to save server statistics: {e}")
