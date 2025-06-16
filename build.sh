#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    # Check for git
    if ! command -v git &> /dev/null; then
        print_error "git is not installed. Please install git first."
        exit 1
    fi
    
    # Check for cargo/rust
    if ! command -v cargo &> /dev/null; then
        print_error "cargo/rust is not installed. Please install Rust first."
        echo "Visit: https://rustup.rs/"
        exit 1
    fi
    
    print_success "All requirements satisfied"
}

# Clone the repository
clone_repo() {
    print_status "Cloning Privastead repository..."
    
    if [ -d "privastead" ]; then
        print_warning "Directory 'privastead' already exists. Removing it..."
        rm -rf privastead
    fi
    
    git clone --recursive https://github.com/privastead/privastead.git
    print_success "Repository cloned successfully"
}

# Generate user credentials
generate_credentials() {
    print_status "Generating user credentials..."
    
    cd privastead/config_tool
    cargo run -- --generate-user-credentials --dir .
    
    if [ -f "user_credentials" ] && [ -f "user_credentials_qrcode.png" ]; then
        print_success "Credentials generated successfully"
        print_status "Files created:"
        echo "  - user_credentials"
        echo "  - user_credentials_qrcode.png"
    else
        print_error "Failed to generate credentials"
        exit 1
    fi
    
    cd ../..
}

# Setup Firebase/FCM credentials
setup_fcm() {
    print_status "Setting up FCM credentials..."
    print_warning "You need to manually set up Firebase Console and download service_account_key.json"
    echo ""
    echo "Follow these steps:"
    echo "1. Go to: https://console.firebase.google.com/"
    echo "2. Create a project named 'Privastead'"
    echo "3. Add an Android app with package name: privastead.camera"
    echo "4. Download google-services.json (for the Android app)"
    echo "5. Go to Project Settings > Service accounts"
    echo "6. Generate new private key and save as 'service_account_key.json'"
    echo ""
    
    # Wait for user to place the service account key
    while true; do
        read -p "Have you placed service_account_key.json in the current directory? (y/n): " yn
        case $yn in
            [Yy]* ) 
                if [ -f "service_account_key.json" ]; then
                    mv service_account_key.json privastead/server/
                    print_success "service_account_key.json moved to server directory"
                    break
                else
                    print_error "service_account_key.json not found in current directory"
                fi
                ;;
            [Nn]* ) 
                print_error "Cannot proceed without service_account_key.json"
                exit 1
                ;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Build the server
build_server() {
    print_status "Building Privastead server..."
    
    cd privastead/server
    cargo build --release
    
    if [ $? -eq 0 ]; then
        print_success "Server built successfully"
    else
        print_error "Failed to build server"
        exit 1
    fi
    
    cd ../..
}

# Create systemd service (optional)
create_systemd_service() {
    print_status "Would you like to create a systemd service for auto-restart? (recommended for production)"
    
    read -p "Create systemd service? (y/n): " create_service
    
    if [[ $create_service =~ ^[Yy]$ ]]; then
        CURRENT_USER=$(whoami)
        PRIVASTEAD_PATH=$(pwd)/privastead/server
        CARGO_PATH=$(which cargo)
        
        # Create service file
        cat > privastead.service << EOF
[Unit]
Description=Privastead Server
After=network.target

[Service]
User=$CURRENT_USER
WorkingDirectory=$PRIVASTEAD_PATH
ExecStart=$CARGO_PATH run --release
Restart=always
RestartSec=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        print_status "Systemd service file created: privastead.service"
        echo ""
        echo "To install the service, run these commands as root:"
        echo "  sudo cp privastead.service /etc/systemd/system/"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable privastead.service"
        echo "  sudo systemctl start privastead.service"
        echo ""
        echo "To check service status:"
        echo "  sudo systemctl status privastead.service"
    fi
}

# Display final instructions
show_final_instructions() {
    print_success "Privastead server setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. To run the server manually:"
    echo "   cd privastead/server"
    echo "   cargo run --release"
    echo ""
    echo "2. Files you'll need for other components:"
    echo "   - privastead/config_tool/user_credentials (for camera hub)"
    echo "   - privastead/config_tool/user_credentials_qrcode.png (for mobile app)"
    echo ""
    echo "3. For camera hub setup, you'll need to:"
    echo "   - Configure your IP cameras"
    echo "   - Copy user_credentials to camera_hub directory"
    echo "   - Configure cameras.yaml"
    echo ""
    echo "4. For mobile app setup, you'll need:"
    echo "   - The google-services.json file from Firebase"
    echo "   - Build and install the Android app"
    echo ""
    echo "Server IP: Make sure your server has a public IP address"
    echo "accessible by both the camera hub and mobile app."
}

# Main execution
main() {
    echo "=============================================="
    echo "       Privastead Server Setup Script"
    echo "=============================================="
    echo ""
    
    check_requirements
    clone_repo
    generate_credentials
    setup_fcm
    build_server
    create_systemd_service
    show_final_instructions
}

# Run main function
main "$@"
