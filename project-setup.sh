#!/bin/bash

# Function to prompt and install a package
install_package() {
    local package=$1
    read -p "Do you want to install $package? (yes/no): " response
    if [[ "$response" == "yes" ]]; then
        echo "Installing $package..."
        sudo apt update -y &>/dev/null
        sudo apt install -y $package &>/dev/null
        echo "$package has been installed."
    else
        echo "Skipping $package installation."
    fi
}

# Function to install Docker
install_docker() {
    read -p "Do you want to install Docker? (yes/no): " response
    if [[ "$response" == "yes" ]]; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh &>/dev/null
        sudo sh get-docker.sh &>/dev/null
        sudo usermod -aG docker $USER
        echo "Docker has been installed."
    else
        echo "Skipping Docker installation."
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    read -p "Do you want to install Docker Compose? (yes/no): " response
    if [[ "$response" == "yes" ]]; then
        echo "Installing Docker Compose..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &>/dev/null
        sudo chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose has been installed."
    else
        echo "Skipping Docker Compose installation."
    fi
}

# Prompt for each installation
install_docker
install_docker_compose
install_package "net-tools"
install_package "tree"

# Final message
echo "Script execution completed."


#!/bin/bash

# Function to create a directory if it doesn't exist
create_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        sudo mkdir -p "$dir"
        echo "Created directory: $dir"
    else
        echo "Directory already exists: $dir"
    fi
}

# Function to create a file with specific content
create_file_with_content() {
    local file=$1
    local content=$2
    if [[ ! -f "$file" ]]; then
        echo "$content" > "$file"
        echo "Created file: $file"
    else
        echo "File already exists: $file"
    fi
}

# Base directory
BASE_DIR="$HOME/docker"

# Ensure proper permissions for the base directory
if [[ -d "$BASE_DIR" ]]; then
    echo "Setting permissions for $BASE_DIR..."
    sudo chown -R $USER:$USER "$BASE_DIR"
    sudo chmod -R u+w "$BASE_DIR"
else
    echo "$BASE_DIR does not exist yet. It will be created with appropriate permissions."
    mkdir -p "$BASE_DIR"
    sudo chown -R $USER:$USER "$BASE_DIR"
    sudo chmod -R u+w "$BASE_DIR"
fi


# Directory and file structure
create_directory "$BASE_DIR"
create_directory "$BASE_DIR/proxy"
create_directory "$BASE_DIR/proxy/nginx-config"
create_directory "$BASE_DIR/proxy/default"
create_directory "$BASE_DIR/proxy/app"
create_directory "$BASE_DIR/project"

# Update permissions after creating directories
echo "Setting permissions for directories..."
sudo chown -R $USER:$USER "$BASE_DIR"
sudo chmod -R u+w "$BASE_DIR"


# File content
DOCKER_COMPOSE_CONTENT=$(cat <<EOF
services:
  proxy_server:
    container_name: proxy_server
    build: ./app
    ports:
      - '80:80'
      - '443:443'
    restart: always
    networks:
      - shared
    volumes:
      - ./default/nginx.conf:/etc/nginx/nginx.conf:rw
      - ./default/proxy.conf:/etc/nginx/proxy.conf:rw
      - ./nginx-config:/etc/nginx/conf.d:rw
      - ./certs/letsencrypt:/etc/letsencrypt
#      - ./static_images:/data/images
    logging:
        driver: "json-file"
        options:
            max-file: "5"
            max-size: "10m"

networks:
  shared:
    external:
      name: shared
EOF
)

NGINX_CONF_CONTENT=$(cat <<EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {

    include    /etc/nginx/proxy.conf;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"'
		      'upstream_response_time=\$upstream_response_time';

    access_log  /var/log/nginx/access.log  main;

    server_names_hash_bucket_size 128;
    server_names_hash_max_size 512;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  65;
    proxy_connect_timeout         900s;
    proxy_send_timeout            900s;
    proxy_read_timeout            3600s;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;

    client_max_body_size 250M;

}
EOF
)

PROXY_CONF_CONTENT=$(cat <<EOF
proxy_headers_hash_max_size 512;
proxy_headers_hash_bucket_size 128;
proxy_max_temp_file_size 250m;
EOF
)

DOCKERFILE_CONTENT=$(cat <<EOF
FROM nginx:latest
RUN apt-get update && apt-get install python3-certbot-nginx -y
EOF
)

# Creating files with content
create_file_with_content "$BASE_DIR/proxy/docker-compose.yml" "$DOCKER_COMPOSE_CONTENT"
create_file_with_content "$BASE_DIR/proxy/nginx-config/frontend.conf" ""
create_file_with_content "$BASE_DIR/proxy/nginx-config/backend.conf" ""
create_file_with_content "$BASE_DIR/proxy/default/nginx.conf" "$NGINX_CONF_CONTENT"
create_file_with_content "$BASE_DIR/proxy/default/proxy.conf" "$PROXY_CONF_CONTENT"
create_file_with_content "$BASE_DIR/proxy/app/Dockerfile" "$DOCKERFILE_CONTENT"

# Final message
echo "Directory and file setup completed."

#!/bin/bash

# Function to set permissions for a directory
set_permissions() {
    local dir=$1
    echo "Setting ownership and permissions for $dir..."
    sudo chown -R $USER:$USER "$dir"
    sudo chmod -R u+w "$dir"
    echo "Permissions set for $dir."
}
# Function to create a directory if it doesn't exist
create_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        sudo mkdir -p "$dir"
        echo "Created directory: $dir"
    else
        echo "Directory already exists: $dir"
    fi
 set_permissions "$dir"  # Ensure permissions are set after creation

}

# Function to create a file with specific content
create_file_with_content() {
    local file=$1
    local content=$2
    if [[ ! -f "$file" ]]; then
        echo "$content" > "$file"
        echo "Created file: $file"
    else
        echo "File already exists: $file"
    fi

set_permissions "$(dirname "$file")" 
}

# Base project directory
BASE_DIR="$HOME/docker/project"
FRONTEND_DIR="$BASE_DIR/frontend"

# Ensure proper permissions for the base directory
if [[ -d "$BASE_DIR" ]]; then
    echo "Setting permissions for $BASE_DIR..."
    sudo chown -R $USER:$USER "$BASE_DIR"
    sudo chmod -R u+w "$BASE_DIR"
else
    echo "$BASE_DIR does not exist yet. It will be created with appropriate permissions."
    mkdir -p "$BASE_DIR"
    sudo chown -R $USER:$USER "$BASE_DIR"
    sudo chmod -R u+w "$BASE_DIR"
fi

# Frontend directories and files
create_directory "$FRONTEND_DIR"
create_directory "$FRONTEND_DIR/app"
create_directory "$FRONTEND_DIR/app/code"
create_directory "$FRONTEND_DIR/nginx"

# File content for default.conf
DEFAULT_CONF_CONTENT=$(cat <<EOF
server {
    listen  80;
    server_name _;
    server_tokens off;
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html?q=\$uri&\$args;
    }
}
EOF
)

# File content for nginx.conf
NGINX_CONF_CONTENT=$(cat <<EOF
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    include /etc/nginx/conf.d/*.conf;
}
EOF
)

# File content for Dockerfile in app directory
APP_DOCKERFILE_CONTENT=$(cat <<EOF
FROM node:20.15.1-alpine AS builder

WORKDIR /app

COPY ./code/ui/package*.json ./

RUN npm install -g npm@10.8.2

RUN npm install -g @angular/cli

RUN npm install -f

COPY ./code/ui/ ./

#RUN node  --max-old-space-size=4096
RUN npm run build

CMD npm start


FROM nginx:alpine

COPY --from=builder app/dist/ui/browser/. /usr/share/nginx/html

#EXPOSE 4200
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
)

# File content for docker-compose.yml
DOCKER_COMPOSE_CONTENT=$(cat <<EOF
services:
  project-fe:
    container_name: project-fe
    restart: always
    build:
      context: ./app
      dockerfile: Dockerfile
    expose:
      - 80
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - shared

networks:
  shared:
    external: true
EOF
)

# Create the backend directory structure and set permissions
create_backend() {
    BACKEND_DIR="$BASE_DIR/backend"
    
    echo "Creating backend directory structure..."
    mkdir -p "$BACKEND_DIR/app/code"

    # Create backend Dockerfile
    cat <<EOF > "$BACKEND_DIR/app/Dockerfile"
FROM python:3.11.10-slim
RUN apt-get update && apt-get install -y \\
    tk-dev \\
    tcl-dev \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./code/requirements.txt .
COPY .env .
RUN pip3 install -r requirements.txt --no-deps
COPY ./code/ .
RUN pip3 install requests python-dotenv 
EXPOSE 5000
# Command to run the Flask application
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
EOF
    echo "Created file: $BACKEND_DIR/app/Dockerfile"

    # Create backend docker-compose.yml
    cat <<EOF > "$BACKEND_DIR/docker-compose.yml"
services:
  project-be:
    container_name: project-be
    restart: always
    build:
      context: ./app
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
    env_file:
      - ./app/.env
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf

    networks:
      - shared

networks:
  shared:
     external: true
EOF
    echo "Created file: $BACKEND_DIR/docker-compose.yml"

    # Set permissions
    echo "Setting permissions for backend files and directories..."
    chmod -R 700 "$BACKEND_DIR"                     # Directories and contents
    find "$BACKEND_DIR" -type f -exec chmod 600 {} \;  # Files only
    echo "Permissions set: Directories (700), Files (600)"
}

# Base directory
BASE_DIR="/home/ubuntu/docker/project"

# Run backend creation
create_backend

