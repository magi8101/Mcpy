"""Utility functions for persistence operations."""

import logging
from typing import Dict, Any, Optional, Tuple, List, Union

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .database import session_scope, get_session
from .models import World, Chunk, Player, Entity, MobEntity, ItemEntity, ServerStatistics

logger = logging.getLogger("mcpy.persistence")


def save_player(player_data: Dict[str, Any]) -> Optional[int]:
    """Save or update a player in the database.
    
    Args:
        player_data: Dictionary containing player data
        
    Returns:
        int: Player ID if save was successful, None otherwise
    """
    try:
        with session_scope() as session:
            # Check if player exists
            uuid = player_data.get("uuid")
            player = session.query(Player).filter(Player.uuid == uuid).first()
            
            if player:
                # Update existing player
                for key, value in player_data.items():
                    if hasattr(player, key) and key != "uuid":  # UUID can't change
                        setattr(player, key, value)
            else:
                # Create new player
                player = Player(**player_data)
                session.add(player)
                
            session.commit()
            return player.id
    except SQLAlchemyError as e:
        logger.error(f"Failed to save player data: {e}")
        return None


def get_player(uuid: str) -> Optional[Dict[str, Any]]:
    """Retrieve player data from the database.
    
    Args:
        uuid: Player UUID
        
    Returns:
        Dict: Player data as dictionary, or None if not found
    """
    try:
        with session_scope() as session:
            player = session.query(Player).filter(Player.uuid == uuid).first()
            if player:
                return player.to_dict()
            return None
    except SQLAlchemyError as e:
        logger.error(f"Failed to retrieve player data: {e}")
        return None


def save_chunk(world_name: str, chunk_data: Dict[str, Any]) -> Optional[int]:
    """Save or update a chunk in the database.
    
    Args:
        world_name: Name of the world
        chunk_data: Dictionary containing chunk data
        
    Returns:
        int: Chunk ID if save was successful, None otherwise
    """
    try:
        with session_scope() as session:
            # Get world ID
            world = session.query(World).filter(World.name == world_name).first()
            if not world:
                logger.error(f"World '{world_name}' not found.")
                return None
                
            # Check if chunk exists
            chunk = session.query(Chunk).filter(
                Chunk.world_id == world.id,
                Chunk.x == chunk_data["x"],
                Chunk.z == chunk_data["z"]
            ).first()
            
            if chunk:
                # Update existing chunk
                for key, value in chunk_data.items():
                    if hasattr(chunk, key) and key not in ("world_id", "x", "z"):
                        setattr(chunk, key, value)
            else:
                # Create new chunk
                chunk_data["world_id"] = world.id
                chunk = Chunk(**chunk_data)
                session.add(chunk)
                
            session.commit()
            return chunk.id
    except SQLAlchemyError as e:
        logger.error(f"Failed to save chunk data: {e}")
        return None


def get_chunk(world_name: str, x: int, z: int) -> Optional[Dict[str, Any]]:
    """Retrieve chunk data from the database.
    
    Args:
        world_name: Name of the world
        x: Chunk X coordinate
        z: Chunk Z coordinate
        
    Returns:
        Dict: Chunk data as dictionary, or None if not found
    """
    try:
        with session_scope() as session:
            # Get world ID
            world = session.query(World).filter(World.name == world_name).first()
            if not world:
                logger.error(f"World '{world_name}' not found.")
                return None
                
            chunk = session.query(Chunk).filter(
                Chunk.world_id == world.id,
                Chunk.x == x,
                Chunk.z == z
            ).first()
            
            if not chunk:
                return None
                
            return {
                "id": chunk.id,
                "x": chunk.x,
                "z": chunk.z,
                "generated": chunk.generated,
                "populated": chunk.populated,
                "last_saved": chunk.last_saved.isoformat(),
                "data": chunk.data,
            }
    except SQLAlchemyError as e:
        logger.error(f"Failed to retrieve chunk data: {e}")
        return None


def save_world(world_data: Dict[str, Any]) -> Optional[int]:
    """Save or update world data in the database.
    
    Args:
        world_data: Dictionary containing world data
        
    Returns:
        int: World ID if save was successful, None otherwise
    """
    try:
        with session_scope() as session:
            # Check if world exists
            name = world_data.get("name")
            world = session.query(World).filter(World.name == name).first()
            
            if world:
                # Update existing world
                for key, value in world_data.items():
                    if hasattr(world, key) and key != "name":  # Name can't change
                        setattr(world, key, value)
            else:
                # Create new world
                world = World(**world_data)
                session.add(world)
                
            session.commit()
            return world.id
    except SQLAlchemyError as e:
        logger.error(f"Failed to save world data: {e}")
        return None


def get_world(name: str) -> Optional[Dict[str, Any]]:
    """Retrieve world data from the database.
    
    Args:
        name: World name
        
    Returns:
        Dict: World data as dictionary, or None if not found
    """
    try:
        with session_scope() as session:
            world = session.query(World).filter(World.name == name).first()
            if world:
                return world.to_dict()
            return None
    except SQLAlchemyError as e:
        logger.error(f"Failed to retrieve world data: {e}")
        return None


def save_entity(world_name: str, entity_data: Dict[str, Any]) -> Optional[int]:
    """Save or update an entity in the database.
    
    Args:
        world_name: Name of the world
        entity_data: Dictionary containing entity data
        
    Returns:
        int: Entity ID if save was successful, None otherwise
    """
    try:
        with session_scope() as session:
            # Get world ID
            world = session.query(World).filter(World.name == world_name).first()
            if not world:
                logger.error(f"World '{world_name}' not found.")
                return None
                
            # Get chunk ID
            chunk_x = entity_data.get("chunk_x", int(entity_data["x"] // 16))
            chunk_z = entity_data.get("chunk_z", int(entity_data["z"] // 16))
            
            chunk = session.query(Chunk).filter(
                Chunk.world_id == world.id,
                Chunk.x == chunk_x,
                Chunk.z == chunk_z
            ).first()
            
            if not chunk:
                # Create new chunk if it doesn't exist
                chunk = Chunk(
                    world_id=world.id,
                    x=chunk_x,
                    z=chunk_z,
                    generated=True,
                    populated=False
                )
                session.add(chunk)
                session.flush()
                
            # Update entity data with IDs
            entity_data["world_id"] = world.id
            entity_data["chunk_id"] = chunk.id
            
            # Check if entity exists
            entity_uuid = entity_data.get("entity_uuid")
            if entity_uuid:
                entity = session.query(Entity).filter(Entity.entity_uuid == entity_uuid).first()
                if entity:
                    # Update existing entity
                    for key, value in entity_data.items():
                        if hasattr(entity, key) and key != "entity_uuid":  # UUID can't change
                            setattr(entity, key, value)
                    session.commit()
                    return entity.id
            
            # Determine entity class based on entity_type
            entity_type = entity_data.get("entity_type", "")
            entity_class = None
            
            if entity_type.startswith("mob."):
                entity_class = MobEntity
                # Add mob specific fields if not present
                if "health" not in entity_data:
                    entity_data["health"] = 20.0
                if "max_health" not in entity_data:
                    entity_data["max_health"] = 20.0
                if "hostile" not in entity_data:
                    entity_data["hostile"] = "hostile" in entity_type
            elif entity_type.startswith("item."):
                entity_class = ItemEntity
                # Add item specific fields if not present
                if "item_id" not in entity_data:
                    entity_data["item_id"] = entity_type.replace("item.", "")
                if "count" not in entity_data:
                    entity_data["count"] = 1
            else:
                entity_class = Entity
                
            # Create new entity
            entity = entity_class(**entity_data)
            session.add(entity)
            session.commit()
            return entity.id
            
    except SQLAlchemyError as e:
        logger.error(f"Failed to save entity data: {e}")
        return None


def get_entities_in_chunk(world_name: str, chunk_x: int, chunk_z: int) -> List[Dict[str, Any]]:
    """Retrieve all entities in a chunk from the database.
    
    Args:
        world_name: Name of the world
        chunk_x: Chunk X coordinate
        chunk_z: Chunk Z coordinate
        
    Returns:
        List[Dict]: List of entity data dictionaries
    """
    try:
        with session_scope() as session:
            # Get world ID
            world = session.query(World).filter(World.name == world_name).first()
            if not world:
                logger.error(f"World '{world_name}' not found.")
                return []
                
            # Get chunk ID
            chunk = session.query(Chunk).filter(
                Chunk.world_id == world.id,
                Chunk.x == chunk_x,
                Chunk.z == chunk_z
            ).first()
            
            if not chunk:
                return []
                
            # Get all entities in chunk
            entities = session.query(Entity).filter(Entity.chunk_id == chunk.id).all()
            
            return [{
                "id": entity.id,
                "entity_uuid": entity.entity_uuid,
                "entity_type": entity.entity_type,
                "x": entity.x,
                "y": entity.y,
                "z": entity.z,
                "yaw": entity.yaw,
                "pitch": entity.pitch,
                "velocity_x": entity.velocity_x,
                "velocity_y": entity.velocity_y,
                "velocity_z": entity.velocity_z,
                "on_ground": entity.on_ground,
                "active": entity.active,
                "data": entity.data,
                "entity_class": entity.entity_class
            } for entity in entities]
            
    except SQLAlchemyError as e:
        logger.error(f"Failed to retrieve entities: {e}")
        return []


def save_statistics(stats_data: Dict[str, Any]) -> Optional[int]:
    """Save server statistics to the database.
    
    Args:
        stats_data: Dictionary containing server statistics
        
    Returns:
        int: Statistics entry ID if save was successful, None otherwise
    """
    try:
        with session_scope() as session:
            stats = ServerStatistics(**stats_data)
            session.add(stats)
            session.commit()
            return stats.id
    except SQLAlchemyError as e:
        logger.error(f"Failed to save server statistics: {e}")
        return None
