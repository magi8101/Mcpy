"""SQLAlchemy models for MCPy."""

import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional

from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, 
    ForeignKey, Table, Text, LargeBinary, Index, CheckConstraint,
    UniqueConstraint, JSON, BigInteger
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.schema import MetaData

# Create a metadata object with naming conventions for constraints
metadata = MetaData(naming_convention={
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s"
})

# Create base class for all models
Base = declarative_base(metadata=metadata)


class World(Base):
    """World data model representing a Minecraft world."""
    
    __tablename__ = "worlds"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(64), nullable=False, unique=True)
    seed = Column(BigInteger, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_accessed = Column(DateTime, default=datetime.utcnow, nullable=False)
    spawn_x = Column(Integer, default=0, nullable=False)
    spawn_y = Column(Integer, default=64, nullable=False)
    spawn_z = Column(Integer, default=0, nullable=False)
    world_type = Column(String(32), default="default", nullable=False)
    hardcore = Column(Boolean, default=False, nullable=False)
    game_rules = Column(JSON, default={}, nullable=False)
    
    # Relationships
    chunks = relationship("Chunk", back_populates="world", cascade="all, delete-orphan")
    players = relationship("Player", back_populates="world")
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert world data to dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "seed": self.seed,
            "created_at": self.created_at.isoformat(),
            "last_accessed": self.last_accessed.isoformat(),
            "spawn": (self.spawn_x, self.spawn_y, self.spawn_z),
            "world_type": self.world_type,
            "hardcore": self.hardcore,
            "game_rules": self.game_rules,
        }


class Chunk(Base):
    """Chunk data model representing a 16x16 chunk in the world."""
    
    __tablename__ = "chunks"
    __table_args__ = (
        UniqueConstraint('world_id', 'x', 'z', name='uq_chunk_coords'),
    )
    
    id = Column(Integer, primary_key=True)
    world_id = Column(Integer, ForeignKey('worlds.id'), nullable=False)
    x = Column(Integer, nullable=False)
    z = Column(Integer, nullable=False)
    generated = Column(Boolean, default=False, nullable=False)
    populated = Column(Boolean, default=False, nullable=False)
    last_saved = Column(DateTime, default=datetime.utcnow, nullable=False)
    data = Column(LargeBinary)  # Compressed chunk data
    
    # Relationships
    world = relationship("World", back_populates="chunks")
    entities = relationship("Entity", back_populates="chunk")
    
    # Indexes for fast chunk lookups
    __table_args__ = (
        Index('ix_chunks_coords', 'world_id', 'x', 'z'),
    )


class Player(Base):
    """Player data model representing a player in the Minecraft server."""
    
    __tablename__ = "players"
    
    id = Column(Integer, primary_key=True)
    uuid = Column(String(36), unique=True, nullable=False)
    username = Column(String(32), nullable=False)
    world_id = Column(Integer, ForeignKey('worlds.id'), nullable=False)
    x = Column(Float, default=0.0, nullable=False)
    y = Column(Float, default=64.0, nullable=False)
    z = Column(Float, default=0.0, nullable=False)
    yaw = Column(Float, default=0.0, nullable=False)
    pitch = Column(Float, default=0.0, nullable=False)
    health = Column(Float, default=20.0, nullable=False)
    food_level = Column(Integer, default=20, nullable=False)
    experience = Column(Float, default=0.0, nullable=False)
    level = Column(Integer, default=0, nullable=False)
    game_mode = Column(String(20), default="survival", nullable=False)
    inventory = Column(JSON, default={}, nullable=False)
    ender_chest = Column(JSON, default={}, nullable=False)
    first_joined = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_joined = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=False)
    playtime_ticks = Column(BigInteger, default=0, nullable=False)
    ip_address = Column(String(45), nullable=True)  # IPv6 can be up to 45 chars
    
    # Relationships
    world = relationship("World", back_populates="players")
    
    # Statistics and achievements
    statistics = Column(JSON, default={}, nullable=False)
    advancements = Column(JSON, default={}, nullable=False)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert player data to dictionary."""
        return {
            "id": self.id,
            "uuid": self.uuid,
            "username": self.username,
            "position": (self.x, self.y, self.z),
            "rotation": (self.yaw, self.pitch),
            "health": self.health,
            "food_level": self.food_level,
            "experience": self.experience,
            "level": self.level,
            "game_mode": self.game_mode,
            "inventory": self.inventory,
            "first_joined": self.first_joined.isoformat(),
            "last_seen": self.last_seen.isoformat(),
            "playtime_ticks": self.playtime_ticks,
        }


class Entity(Base):
    """Entity data model representing any non-player entity in the world."""
    
    __tablename__ = "entities"
    
    id = Column(Integer, primary_key=True)
    entity_uuid = Column(String(36), default=lambda: str(uuid.uuid4()), unique=True, nullable=False)
    entity_type = Column(String(64), nullable=False)
    world_id = Column(Integer, ForeignKey('worlds.id'), nullable=False)
    chunk_id = Column(Integer, ForeignKey('chunks.id'), nullable=False)
    x = Column(Float, nullable=False)
    y = Column(Float, nullable=False)
    z = Column(Float, nullable=False)
    yaw = Column(Float, default=0.0, nullable=False)
    pitch = Column(Float, default=0.0, nullable=False)
    velocity_x = Column(Float, default=0.0, nullable=False)
    velocity_y = Column(Float, default=0.0, nullable=False)
    velocity_z = Column(Float, default=0.0, nullable=False)
    on_ground = Column(Boolean, default=True, nullable=False)
    active = Column(Boolean, default=True, nullable=False)
    despawn_timer = Column(Integer, default=0, nullable=False)
    data = Column(JSON, default={}, nullable=False)  # Entity-specific data
    
    # Discriminator for entity type
    entity_class = Column(String(50))
    
    # Relationships
    chunk = relationship("Chunk", back_populates="entities")
    
    # Use SQLAlchemy's polymorphic identity for entity type inheritance
    __mapper_args__ = {
        'polymorphic_identity': 'entity',
        'polymorphic_on': entity_class
    }
    
    # Index for fast entity lookup in chunk
    __table_args__ = (
        Index('ix_entities_chunk', 'chunk_id'),
    )


class MobEntity(Entity):
    """Mob entity data model for creatures in the world."""
    
    __tablename__ = "mob_entities"
    
    id = Column(Integer, ForeignKey('entities.id'), primary_key=True)
    health = Column(Float, nullable=False)
    max_health = Column(Float, nullable=False)
    hostile = Column(Boolean, default=False, nullable=False)
    ai_type = Column(String(50), nullable=True)
    
    __mapper_args__ = {
        'polymorphic_identity': 'mob',
    }


class ItemEntity(Entity):
    """Item entity data model for dropped items in the world."""
    
    __tablename__ = "item_entities"
    
    id = Column(Integer, ForeignKey('entities.id'), primary_key=True)
    item_id = Column(String(64), nullable=False)  # Item identifier
    count = Column(Integer, default=1, nullable=False)
    metadata = Column(JSON, default={}, nullable=False)
    pickup_delay = Column(Integer, default=0, nullable=False)
    despawn_time = Column(Integer, default=6000, nullable=False)  # 5 minutes in ticks
    
    __mapper_args__ = {
        'polymorphic_identity': 'item',
    }


class ServerStatistics(Base):
    """Server statistics for monitoring and analytics."""
    
    __tablename__ = "server_statistics"
    
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    players_online = Column(Integer, default=0, nullable=False)
    cpu_usage = Column(Float, nullable=True)
    memory_usage = Column(Float, nullable=True)
    tick_duration = Column(Float, nullable=True)  # milliseconds
    chunks_loaded = Column(Integer, nullable=True)
    entities_loaded = Column(Integer, nullable=True)
    
    # Index for time-series data
    __table_args__ = (
        Index('ix_statistics_timestamp', 'timestamp'),
    )
