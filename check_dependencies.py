#!/usr/bin/env python
"""
Dependency checker for MCPy.
This script checks if all required dependencies are installed correctly.
"""

import importlib
import sys
from pathlib import Path


def check_dependency(module_name, min_version=None, optional=False):
    """Check if a dependency is installed and meets the minimum version requirement."""
    try:
        module = importlib.import_module(module_name)
        if not min_version:
            status = "✓"
        else:
            if hasattr(module, "__version__"):
                version = module.__version__
                if version >= min_version:
                    status = "✓"
                else:
                    status = f"⚠ (version {version} < {min_version})"
            else:
                status = "? (version unknown)"
        
        print(f"{module_name:.<30} {status}")
        return True
    except ImportError:
        status = "optional" if optional else "MISSING"
        print(f"{module_name:.<30} {status}")
        return optional


def check_all_dependencies():
    """Check all required and optional dependencies."""
    print("Checking MCPy dependencies...")
    print("-" * 50)
    
    all_good = True
    
    # Core dependencies
    core_deps = [
        ("numpy", "1.24.0"),
        ("scipy", "1.10.0"),
        ("Cython", "3.0.0"),
        ("tomli", "2.0.0"),
        ("polars", "0.18.0"),
    ]
    
    print("Core dependencies:")
    for dep, version in core_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Database dependencies
    db_deps = [
        ("sqlalchemy", "2.0.0"),
        ("psycopg2", "2.9.5"),
    ]
    
    print("\nDatabase dependencies:")
    for dep, version in db_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Monitoring dependencies
    monitoring_deps = [
        ("prometheus_client", "0.16.0"),
        ("psutil", "5.9.0"),
    ]
    
    print("\nMonitoring dependencies:")
    for dep, version in monitoring_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Networking dependencies
    networking_deps = [
        ("msgpack", "1.0.5"),
    ]
    if sys.platform != "win32":
        networking_deps.append(("uvloop", "0.17.0"))
    
    print("\nNetworking dependencies:")
    for dep, version in networking_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Testing and benchmarking dependencies
    testing_deps = [
        ("pytest", "7.3.1"),
        ("pytest_benchmark", None),
        ("memory_profiler", "0.61.0"),
    ]
    
    print("\nTesting and benchmarking dependencies:")
    for dep, version in testing_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Data visualization dependencies
    viz_deps = [
        ("matplotlib", "3.7.0"),
    ]
    
    print("\nData visualization dependencies:")
    for dep, version in viz_deps:
        if not check_dependency(dep, version):
            all_good = False
    
    # Development tools
    dev_deps = [
        ("black", "23.3.0"),
        ("isort", "5.12.0"),
        ("mypy", "1.3.0"),
        ("ruff", "0.0.270"),
    ]
    
    print("\nDevelopment tools (optional):")
    for dep, version in dev_deps:
        check_dependency(dep, version, optional=True)
    
    # Optional AI features
    ai_deps = [
        ("torch", "2.0.0"),
        ("tensorboard", "2.13.0"),
    ]
    
    print("\nAI features (optional):")
    for dep, version in ai_deps:
        check_dependency(dep, version, optional=True)
    
    # Check if MCPy package is importable
    try:
        import mcpy
        print("\nMCPy package is installed.")
    except ImportError:
        print("\nMCPy package is not installed.")
        print("Run: pip install -e .")
        all_good = False
    
    print("-" * 50)
    if all_good:
        print("All required dependencies are installed correctly!")
    else:
        print("Some dependencies are missing. Please install them using:")
        print("pip install -r _requirements.txt")
    
    return all_good


if __name__ == "__main__":
    sys.exit(0 if check_all_dependencies() else 1)
