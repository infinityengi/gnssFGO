#!/bin/bash

# gnssFGO Docker Container Runner
# Automatically manages container lifecycle: start if not running, attach if running, or use docker compose

set -e

CONTAINER_NAME="gnssfgo"
IMAGE_NAME="haomingac/gnssfgo:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
}

# Check if image exists
check_image() {
    if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        print_error "Docker image '$IMAGE_NAME' not found."
        echo "Please build the image first using:"
        echo "  cd $SCRIPT_DIR"
        echo "  docker build -t $IMAGE_NAME ."
        exit 1
    fi
}

# Check container status
get_container_status() {
    docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.State.Status}}' 2>/dev/null || echo "not_found"
}

# Main logic
main() {
    print_info "Checking Docker..."
    check_docker
    
    print_info "Checking image..."
    check_image
    
    print_info "Checking container status..."
    STATUS=$(get_container_status)
    
    case "$STATUS" in
        "running")
            print_success "Container '$CONTAINER_NAME' is already running."
            print_info "Attaching to container terminal..."
            docker exec -it "$CONTAINER_NAME" bash
            ;;
        "exited")
            print_warning "Container '$CONTAINER_NAME' is stopped."
            print_info "Starting container..."
            docker start "$CONTAINER_NAME"
            print_success "Container started. Attaching to terminal..."
            sleep 1
            docker exec -it "$CONTAINER_NAME" bash
            ;;
        "not_found")
            print_warning "Container '$CONTAINER_NAME' does not exist."
            
            # Check if compose.yaml exists
            if [ -f "$SCRIPT_DIR/compose.yaml" ]; then
                print_info "Found compose.yaml. Would you like to use docker compose? (y/n)"
                read -r USE_COMPOSE
                
                if [[ "$USE_COMPOSE" =~ ^[Yy]$ ]]; then
                    print_info "Starting container with docker compose..."
                    cd "$SCRIPT_DIR"
                    docker compose up -d
                    print_success "Container started with docker compose."
                    print_info "Attaching to container terminal..."
                    sleep 2
                    docker exec -it "$CONTAINER_NAME" bash
                    exit 0
                fi
            fi
            
            # Fallback: use docker run
            print_info "Starting container manually with docker run..."
            
            # Prepare environment variables for X11 forwarding
            DISPLAY_VAR="${DISPLAY:-:0}"
            SSH_AUTH_VAR="${SSH_AUTH_SOCK:-}"
            
            print_info "Using DISPLAY: $DISPLAY_VAR"
            
            # Build docker run command
            DOCKER_RUN_CMD="docker run -it --name $CONTAINER_NAME"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD --privileged"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD --net=host"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e DISPLAY=$DISPLAY_VAR"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e QT_X11_NO_MITSHM=1"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v /tmp/.X11-unix:/tmp/.X11-unix"
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v $(pwd)/../:/workspace/fgo_ws/src/gnssFGO"
            
            # Add USB/Serial devices for GNSS receivers
            if [ -e "/dev/ttyACM0" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD --device=/dev/ttyACM0:/dev/ttyACM0"
                print_info "Added device: /dev/ttyACM0"
            fi
            if [ -e "/dev/ttyACM1" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD --device=/dev/ttyACM1:/dev/ttyACM1"
                print_info "Added device: /dev/ttyACM1"
            fi
            if [ -e "/dev/ttyUSB0" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD --device=/dev/ttyUSB0:/dev/ttyUSB0"
                print_info "Added device: /dev/ttyUSB0"
            fi
            
            # Add SSH socket if available
            if [ -n "$SSH_AUTH_VAR" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e SSH_AUTH_SOCK=$SSH_AUTH_VAR"
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v $SSH_AUTH_VAR:$SSH_AUTH_VAR"
            fi
            
            # Add SSH directory if available
            if [ -d "$HOME/.ssh" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v $HOME/.ssh:/root/.ssh"
            fi
            
            # Add data volume if available
            if [ -d "/mnt/DataSmall" ]; then
                DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v /mnt/DataSmall:/Data"
            fi
            
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD $IMAGE_NAME"
            
            print_info "Running: $DOCKER_RUN_CMD"
            eval "$DOCKER_RUN_CMD"
            ;;
        *)
            print_error "Unknown container status: $STATUS"
            exit 1
            ;;
    esac
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTION]

gnssFGO Docker Container Runner

Options:
    -h, --help              Show this help message
    -c, --compose           Force using docker compose
    -r, --run               Force using docker run (manual)
    -s, --stop              Stop the running container
    -rm, --remove           Remove the container
    -status, --status       Show container status

Examples:
    $0                      # Auto-detect and start container
    $0 --compose            # Start using docker compose
    $0 --stop               # Stop the container
    $0 --status             # Show container status

EOF
}

# Parse command line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--compose)
            check_docker
            check_image
            print_info "Starting container with docker compose..."
            cd "$SCRIPT_DIR"
            docker compose up -d
            print_success "Container started with docker compose."
            print_info "Attaching to container terminal..."
            sleep 2
            docker exec -it "$CONTAINER_NAME" bash
            exit 0
            ;;
        -r|--run)
            check_docker
            check_image
            print_info "Starting container with docker run..."
            # Similar logic as above, can be extracted to function if needed
            main
            exit 0
            ;;
        -s|--stop)
            check_docker
            if [ "$(get_container_status)" = "running" ]; then
                print_info "Stopping container '$CONTAINER_NAME'..."
                docker stop "$CONTAINER_NAME"
                print_success "Container stopped."
            else
                print_warning "Container is not running."
            fi
            exit 0
            ;;
        -rm|--remove)
            check_docker
            STATUS=$(get_container_status)
            if [ "$STATUS" = "running" ]; then
                print_warning "Container is running. Stopping first..."
                docker stop "$CONTAINER_NAME"
            fi
            if [ "$STATUS" != "not_found" ]; then
                print_info "Removing container '$CONTAINER_NAME'..."
                docker rm "$CONTAINER_NAME"
                print_success "Container removed."
            else
                print_warning "Container does not exist."
            fi
            exit 0
            ;;
        -status|--status)
            check_docker
            STATUS=$(get_container_status)
            print_info "Container status: $STATUS"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
fi

# Default: run main logic
main
