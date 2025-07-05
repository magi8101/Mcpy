"""Main entry point for the MCPy server."""

import argparse
import logging
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Try to import uvloop for non-Windows systems
try:
    import uvloop
    uvloop.install()
    USING_UVLOOP = True
except ImportError:
    USING_UVLOOP = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ]
)

logger = logging.getLogger("mcpy")


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="MCPy Minecraft Server")
    parser.add_argument(
        "--config", type=str, default="config.toml", help="Path to config file"
    )
    parser.add_argument(
        "--world", type=str, default="world", help="World directory name"
    )
    parser.add_argument("--port", type=int, default=25565, help="Server port")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Server host")
    parser.add_argument(
        "--debug", action="store_true", help="Enable debug mode"
    )
    parser.add_argument(
        "--profile", action="store_true", help="Enable performance profiling"
    )
    parser.add_argument(
        "--profile-output", type=str, default="profile.out", help="Profiling output file"
    )
    return parser.parse_args()


def load_config(config_path: str) -> Dict[str, Any]:
    """Load configuration from a TOML file."""
    try:
        import tomli
    except ImportError:
        logger.error("tomli is required for TOML config files. Install with: pip install tomli")
        sys.exit(1)

    try:
        with open(config_path, "rb") as f:
            return tomli.load(f)
    except FileNotFoundError:
        logger.warning(f"Config file not found: {config_path}, using default settings")
        return {}
    except Exception as e:
        logger.error(f"Error loading config: {e}")
        sys.exit(1)


def main() -> None:
    """Run the MCPy server."""
    args = parse_args()
    
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logger.debug("Debug mode enabled")

    # Create world directory if it doesn't exist
    world_path = Path(args.world).absolute()
    world_path.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"MCPy server starting...")
    logger.info(f"Using Python {sys.version}")
    if USING_UVLOOP:
        logger.info("Using uvloop event loop")
    
    # Load configuration
    config = load_config(args.config)
    
    if args.profile:
        try:
            import cProfile
            logger.info(f"Profiling enabled, output: {args.profile_output}")
            cProfile.run("start_server(args, config)", args.profile_output)
        except ImportError:
            logger.error("cProfile is required for profiling")
            sys.exit(1)
    else:
        start_server(args, config)


def start_server(args: argparse.Namespace, config: Dict[str, Any]) -> None:
    """Initialize and start the server with the given configuration."""
    try:
        from mcpy.core.server_core import ServerInstance
        from mcpy.persistence.integration import PersistenceManager
        
        # Ensure database configuration is present
        if "database" not in config:
            config["database"] = {
                "type": "sqlite",
                "path": os.path.join(args.world, "mcpy.db"),
                "create_tables": True,
                "auto_save_interval": 300  # 5 minutes
            }
            logger.info("Using default SQLite database configuration")
        
        # Initialize persistence layer
        logger.info("Initializing persistence layer...")
        persistence_manager = PersistenceManager(config)
        
        # Initialize server with persistence
        server = ServerInstance(
            host=args.host,
            port=args.port,
            world_path=args.world,
            config=config
        )
        
        # Attach persistence manager to server
        server.persistence_manager = persistence_manager
        
        # Start the server
        server.start()
        
    except ImportError as e:
        logger.critical(f"Failed to import core modules: {e}")
        logger.critical("Make sure you've built the Cython extensions with: pip install -e .")
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Server shutting down...")
    except Exception as e:
        logger.critical(f"Server crashed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
