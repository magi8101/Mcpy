"""MCPy: High-performance Minecraft server engine.

A production-grade Minecraft server engine built with Python, Cython, 
and scientific computing libraries.

Key Components:
- core: High-performance Cython modules for the server engine
- persistence: ORM-based data persistence using SQLAlchemy
- server: Main server entry point and configuration
"""

__version__ = "0.1.0"

# Package metadata
__author__ = "MCPy Team"
__email__ = "mcpy@example.com"
__license__ = "MIT"
__url__ = "https://github.com/mcpy/mcpy"

# Check if Cython modules are available
try:
    from .core import ServerInstance, WorldEngine, EntitySystem, NetworkManager
    HAS_CYTHON = True
except ImportError:
    HAS_CYTHON = False
    import logging
    logging.getLogger("mcpy").warning(
        "Core Cython modules not available. Run 'pip install -e .' to build them."
    )
