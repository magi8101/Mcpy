"""Database session management for MCPy."""

import logging
import os
from contextlib import contextmanager
from typing import Dict, Any, Iterator, Optional, Union

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import NullPool, QueuePool

logger = logging.getLogger("mcpy.persistence")

# Global engine variable to be initialized
_engine: Optional[Engine] = None
DBSession: Optional[sessionmaker] = None


def initialize_db(config: Dict[str, Any]) -> Engine:
    """Initialize the database engine and session factory.
    
    Args:
        config: Database configuration from the server config file
        
    Returns:
        Engine: The SQLAlchemy engine
    """
    global _engine, DBSession
    
    # Extract database configuration
    db_config = config.get("database", {})
    db_type = db_config.get("type", "sqlite")
    
    # Create connection URL
    if db_type == "postgres" or db_type == "postgresql":
        host = db_config.get("host", "localhost")
        port = db_config.get("port", 5432)
        user = db_config.get("user", "postgres")
        password = db_config.get("password", "")
        dbname = db_config.get("dbname", "mcpy")
        
        connection_url = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
        poolclass = QueuePool
        
        # Advanced PostgreSQL settings
        pool_size = db_config.get("pool_size", 10)
        max_overflow = db_config.get("max_overflow", 20)
        pool_timeout = db_config.get("pool_timeout", 30)
        
    elif db_type == "sqlite":
        # SQLite is mainly for development and testing
        db_path = db_config.get("path", "world/mcpy.db")
        connection_url = f"sqlite:///{db_path}"
        poolclass = NullPool  # Safer for SQLite
        
        # Make sure the directory exists
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
    else:
        raise ValueError(f"Unsupported database type: {db_type}")
    
    # Create engine with appropriate configuration
    engine_kwargs = {
        "echo": db_config.get("echo", False),
        "poolclass": poolclass,
    }
    
    if db_type.startswith("postgres"):
        engine_kwargs.update({
            "pool_size": pool_size,
            "max_overflow": max_overflow,
            "pool_timeout": pool_timeout,
            "pool_pre_ping": True,  # Verify connections before usage
        })
    
    logger.info(f"Initializing database connection to {db_type}...")
    _engine = create_engine(connection_url, **engine_kwargs)
    
    # Create session factory
    DBSession = sessionmaker(bind=_engine)
    
    # Return engine for potential schema creation
    return _engine


def get_session() -> Session:
    """Get a new database session.
    
    Returns:
        Session: A new SQLAlchemy session
    
    Raises:
        RuntimeError: If the database has not been initialized
    """
    if DBSession is None:
        raise RuntimeError("Database not initialized. Call initialize_db first.")
    
    return DBSession()


@contextmanager
def session_scope() -> Iterator[Session]:
    """Context manager for database sessions.
    
    Yields:
        Session: A SQLAlchemy session that will be automatically committed
                or rolled back at the end of the context.
                
    Raises:
        RuntimeError: If the database has not been initialized
    """
    if DBSession is None:
        raise RuntimeError("Database not initialized. Call initialize_db first.")
    
    session = DBSession()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        logger.exception("Database error: %s", str(e))
        raise
    finally:
        session.close()
