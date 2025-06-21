#!/bin/bash
# run-tests.sh - Ejecuta las pruebas usando el contenedor de testing
# Funciona en cualquier OS (Mac, Windows, Linux)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "\n${CYAN}============================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================${NC}\n"
}

# Check if test container exists
check_test_container() {
    if ! docker ps -a --format "{{.Names}}" | grep -q "^datalive-test$"; then
        return 1
    fi
    return 0
}

# Build test container if needed
build_test_container() {
    print_header "Building Test Container"
    
    cd "$PROJECT_ROOT/docker"
    
    # Build the test image
    docker build -f Dockerfile.test -t datalive-test:latest .
    
    # Start with docker-compose
    docker-compose -f docker-compose.yml -f docker-compose-functionality-test.yml up -d test-runner
    
    # Wait for container to be ready
    echo "Waiting for test container to be ready..."
    sleep 5
}

# Main menu
show_menu() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        DataLive Test Suite v2.0              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "Select test to run:"
    echo
    echo "  1) System Health Check"
    echo "  2) RAG Functionality Test"
    echo "  3) Run All Tests"
    echo "  4) Interactive Shell (debug)"
    echo "  5) Continuous Testing (every 5 min)"
    echo "  6) View Latest Test Report"
    echo "  7) Rebuild Test Container"
    echo "  0) Exit"
    echo
}

# Run test in container
run_test() {
    local test_command=$1
    local test_name=$2
    
    print_header "Running $test_name"
    
    # Execute test in container
    docker exec -it datalive-test python3 /tests/scripts/$test_command
    
    echo -e "\n${GREEN}Test completed. Check logs in: logs/${NC}"
}

# Main loop
main() {
    # Check if DataLive stack is running
    if ! docker ps --format "{{.Names}}" | grep -q "^datalive-n8n$"; then
        echo -e "${RED}Error: DataLive stack is not running!${NC}"
        echo "Please run: ./scripts/setup-datalive.sh first"
        exit 1
    fi
    
    # Check/build test container
    if ! check_test_container; then
        echo -e "${YELLOW}Test container not found. Building...${NC}"
        build_test_container
    else
        # Check if running
        if ! docker ps --format "{{.Names}}" | grep -q "^datalive-test$"; then
            echo "Starting test container..."
            docker start datalive-test
            sleep 2
        fi
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice [0-7]: " choice
        
        case $choice in
            1)
                run_test "test-health.py" "System Health Check"
                read -p "Press Enter to continue..."
                ;;
            2)
                run_test "test-rag.py" "RAG Functionality Test"
                read -p "Press Enter to continue..."
                ;;
            3)
                run_test "test-health.py" "System Health Check"
                echo -e "\n${CYAN}Waiting 3 seconds before next test...${NC}\n"
                sleep 3
                run_test "test-rag.py" "RAG Functionality Test"
                read -p "Press Enter to continue..."
                ;;
            4)
                print_header "Interactive Test Shell"
                echo "Type 'exit' to return to menu"
                docker exec -it datalive-test bash
                ;;
            5)
                print_header "Continuous Testing Mode"
                echo -e "${YELLOW}Tests will run every 5 minutes. Press Ctrl+C to stop.${NC}\n"
                while true; do
                    run_test "test-health.py" "System Health Check"
                    echo -e "\n${CYAN}Next test in 5 minutes...${NC}"
                    sleep 300
                done
                ;;
            6)
                print_header "Latest Test Reports"
                if [ -d "$PROJECT_ROOT/logs" ]; then
                    echo "Recent test logs:"
                    ls -la "$PROJECT_ROOT/logs" | grep -E "test-results|test-rag" | tail -10
                else
                    echo "No test logs found"
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                print_header "Rebuilding Test Container"
                docker-compose -f "$PROJECT_ROOT/docker/docker-compose.yml" \
                               -f "$PROJECT_ROOT/docker/docker-compose-functionality-test.yml" \
                               down test-runner
                docker rmi datalive-test:latest 2>/dev/null || true
                build_test_container
                echo -e "${GREEN}Test container rebuilt successfully${NC}"
                read -p "Press Enter to continue..."
                ;;
            0)
                echo -e "\n${CYAN}Exiting test suite. Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main
main "$@"