#!/bin/bash

# MCPy Setup and Build Script
# =========================
echo "MCPy Setup and Build Script"
echo "========================="
echo

# Parse command line arguments
ACTION="all"
if [ ! -z "$1" ]; then
    ACTION="$1"
fi

if [ "$ACTION" = "help" ]; then
    echo "Usage: ./setup.sh [action]"
    echo
    echo "Available actions:"
    echo "  env        - Set up virtual environment and install dependencies"
    echo "  build      - Build Cython modules"
    echo "  run        - Run the server"
    echo "  all        - Perform all actions except run (default)"
    echo "  help       - Display this help message"
    exit 0
fi

# Function to setup virtual environment
setup_env() {
    echo "Setting up virtual environment and installing dependencies..."
    echo

    # Check if Python is installed
    python3 --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Python3 not found. Please install Python 3.9 or later."
        exit 1
    fi

    # Create virtual environment if it doesn't exist
    if [ ! -d ".venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv .venv
        if [ $? -ne 0 ]; then
            echo "Failed to create virtual environment."
            exit 1
        fi
    fi

    # Activate virtual environment
    source .venv/bin/activate
    if [ $? -ne 0 ]; then
        echo "Failed to activate virtual environment."
        exit 1
    fi

    # Install dependencies
    echo "Installing dependencies..."
    python -m pip install --upgrade pip
    if [ $? -ne 0 ]; then exit 1; fi

    pip install -r requirements.txt
    if [ $? -ne 0 ]; then exit 1; fi

    pip install -e ".[dev]"
    if [ $? -ne 0 ]; then exit 1; fi

    # Check dependencies
    echo "Checking dependencies..."
    python check_dependencies.py
    if [ $? -ne 0 ]; then
        echo "Some dependencies may be missing. Check the output above."
        echo "You may need to install system dependencies or rebuild Cython modules."
    fi

    echo
    echo "Virtual environment set up successfully."
    echo
    return 0
}

# Function to build Cython modules
build_cython() {
    echo "Building Cython modules..."
    echo

    # Activate virtual environment if not already activated
    if [ -z "$VIRTUAL_ENV" ]; then
        source .venv/bin/activate
    fi

    # Clean previous builds
    echo "Cleaning previous builds..."
    rm -rf build
    rm -f mcpy/core/*.c

    # Build Cython extensions
    python setup.py build_ext --inplace
    if [ $? -ne 0 ]; then
        echo "Failed to build Cython extensions."
        exit 1
    fi

    echo
    echo "Cython modules built successfully."
    echo
    return 0
}

# Function to run the server
run_server() {
    echo "Running the MCPy server..."
    echo

    # Activate virtual environment if not already activated
    if [ -z "$VIRTUAL_ENV" ]; then
        source .venv/bin/activate
    fi

    # Run the server
    python -m mcpy.server "$@"
    return $?
}

# Execute requested action
if [ "$ACTION" = "env" ]; then
    setup_env
elif [ "$ACTION" = "build" ]; then
    build_cython
elif [ "$ACTION" = "run" ]; then
    run_server "${@:2}"
elif [ "$ACTION" = "all" ]; then
    setup_env
    build_cython
else
    echo "Unknown action: $ACTION"
    echo "Run './setup.sh help' for usage information"
    exit 1
fi

echo
echo "Setup completed successfully!"
echo
echo "To run the server, use: ./setup.sh run"
echo "For other options, use: ./setup.sh help"
echo
