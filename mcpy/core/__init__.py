"""Core modules for the MCPy server engine.

This package contains the high-performance Cython implementations of the core
server components:

- server_core: Server management and lifecycle
- world_engine: World generation and chunk management 
- entity_system: Entity physics and management
- network_core: Networking and packet handling
"""

# Import key classes for easier access
try:
    # Server core
    from .server_core import ServerInstance, ServerConfiguration, PerformanceMetrics
    
    # World engine
    from .world_engine import WorldEngine, Chunk, ChunkSection, TerrainGenerator
    
    # Entity system
    from .entity_system import (
        EntitySystem, Entity, PlayerEntity, MobEntity, 
        ItemEntity, ProjectileEntity, EntityPhysics
    )
    
    # Network core
    from .network_core import NetworkManager, Packet, NetworkBuffer
    
    # Define what should be available when using "from mcpy.core import *"
    __all__ = [
        # Server core
        'ServerInstance', 'ServerConfiguration', 'PerformanceMetrics',
        
        # World engine
        'WorldEngine', 'Chunk', 'ChunkSection', 'TerrainGenerator',
        
        # Entity system
        'EntitySystem', 'Entity', 'PlayerEntity', 'MobEntity',
        'ItemEntity', 'ProjectileEntity', 'EntityPhysics',
        
        # Network core
        'NetworkManager', 'Packet', 'NetworkBuffer',
    ]

except ImportError as e:
    import logging
    logging.getLogger("mcpy.core").warning(
        f"Could not import some core modules: {e}. "
        "Make sure you've built the Cython extensions with: pip install -e ."
    )
