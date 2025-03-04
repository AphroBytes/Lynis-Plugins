#!/bin/sh

#########################################################################
#
#    * DO NOT REMOVE *
#-----------------------------------------------------
# PLUGIN_AUTHOR=AphroBytes Team.
# PLUGIN_CATEGORY=security
# PLUGIN_DATE=2024-10-14
# PLUGIN_DESC=Docker and Container Security Checks
# PLUGIN_NAME=docker_security
# PLUGIN_PACKAGE=community
# PLUGIN_REQUIRED_TESTS=
# PLUGIN_VERSION=1.2.0
#-----------------------------------------------------
#
#########################################################################

# Add custom section to screen output
InsertSection "Docker and Container Security Checks"

# Helper function for logging
log_message() {
    level="$1"
    message="$2"
    LogText "[$level] $message"
}

# DOCKER-0001: Check if Docker is installed and up-to-date
Register --test-no DOCKER-0001 --weight L --network NO --description "Check Docker installation and version"
if [ "${SKIPTEST}" -eq 0 ]; then
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        LATEST_VERSION=$(curl -sS https://api.github.com/repos/docker/docker-ce/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        if [ "$DOCKER_VERSION" = "$LATEST_VERSION" ]; then
            Display --indent 2 --text "- Docker is installed and up-to-date (version $DOCKER_VERSION)" --result OK --color GREEN
        else
            Display --indent 2 --text "- Docker is installed but not up-to-date (current: $DOCKER_VERSION, latest: $LATEST_VERSION)" --result WARNING --color YELLOW
            ReportWarning "${TEST_NO}" "Docker is not up-to-date" "docker" "text:Update Docker to the latest version"
        fi
    else
        Display --indent 2 --text "- Docker is not installed" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker is not installed" "docker" "text:Install Docker"
    fi
fi

# DOCKER-0002: Check Docker daemon configuration
Register --test-no DOCKER-0002 --weight H --network NO --description "Check Docker daemon configuration"
if [ "${SKIPTEST}" -eq 0 ]; then
    DOCKER_DAEMON_CONFIG="${DOCKER_DAEMON_CONFIG:-/etc/docker/daemon.json}"
    if [ -f "$DOCKER_DAEMON_CONFIG" ]; then
        Display --indent 2 --text "- Docker daemon configuration file found" --result OK --color GREEN
        
        check_config_setting() {
            setting="$1"
            expected="$2"
            value=$(jq -r ".$setting // \"\"" "$DOCKER_DAEMON_CONFIG" 2>/dev/null)
            if [ "$value" = "$expected" ]; then
                Display --indent 4 --text "- Docker $setting is set correctly" --result OK --color GREEN
            else
                Display --indent 4 --text "- Docker $setting is not set correctly" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Docker $setting is not set correctly" "$DOCKER_DAEMON_CONFIG" "text:Set $setting to $expected"
            fi
        }

        check_config_setting "icc" "false"
        check_config_setting "userns-remap" "\"default\""
        check_config_setting "no-new-privileges" "true"
        check_config_setting "live-restore" "true"
        check_config_setting "userland-proxy" "false"
        check_config_setting "log-driver" "\"json-file\""
        check_config_setting "log-opts.max-size" "\"10m\""
        check_config_setting "log-opts.max-file" "\"5\""
        check_config_setting "storage-driver" "\"overlay2\""
        check_config_setting "tls" "true"
        check_config_setting "tlsverify" "true"
    else
        Display --indent 2 --text "- Docker daemon configuration file not found" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker daemon configuration file not found" "$DOCKER_DAEMON_CONFIG" "text:Create Docker daemon configuration file with secure settings"
    fi
fi

# DOCKER-0003: Check Docker container security
Register --test-no DOCKER-0003 --weight H --network NO --description "Check Docker container security"
if [ "${SKIPTEST}" -eq 0 ]; then
    RUNNING_CONTAINERS=$(docker ps -q)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        for CONTAINER_ID in $RUNNING_CONTAINERS; do
            Display --indent 2 --text "- Checking container: $CONTAINER_ID" --result INFO --color BLUE
            
            CONTAINER_INFO=$(docker inspect "$CONTAINER_ID" 2>/dev/null)
            
            # Check if container is running as non-root user
            CONTAINER_USER=$(echo "$CONTAINER_INFO" | jq -r '.[0].Config.User')
            if [ "$CONTAINER_USER" = "" ] || [ "$CONTAINER_USER" = "root" ]; then
                Display --indent 4 --text "- Container running as root user" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' is running as root user" "$CONTAINER_ID" "text:Run container as non-root user"
            fi
            
            # Check for read-only root filesystem
            CONTAINER_RO_FS=$(echo "$CONTAINER_INFO" | jq -r '.[0].HostConfig.ReadonlyRootfs')
            if [ "$CONTAINER_RO_FS" != "true" ]; then
                Display --indent 4 --text "- Container does not have a read-only file system" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' does not have a read-only file system" "$CONTAINER_ID" "text:Set container file system to read-only"
            fi
            
            # Check for privileged mode
            CONTAINER_PRIVILEGED=$(echo "$CONTAINER_INFO" | jq -r '.[0].HostConfig.Privileged')
            if [ "$CONTAINER_PRIVILEGED" = "true" ]; then
                Display --indent 4 --text "- Container is running in privileged mode" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' is running in privileged mode" "$CONTAINER_ID" "text:Avoid running containers in privileged mode"
            fi
            
            # Check for host network usage
            CONTAINER_HOST_NETWORK=$(echo "$CONTAINER_INFO" | jq -r '.[0].HostConfig.NetworkMode')
            if [ "$CONTAINER_HOST_NETWORK" = "host" ]; then
                Display --indent 4 --text "- Container is using host network" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' is using host network" "$CONTAINER_ID" "text:Avoid using host network for containers"
            fi
            
            # Check for exposed ports
            EXPOSED_PORTS=$(docker port "$CONTAINER_ID" 2>/dev/null)
            if [ -n "$EXPOSED_PORTS" ]; then
                Display --indent 4 --text "- Container has exposed ports" --result INFO --color YELLOW
                echo "$EXPOSED_PORTS" | while read -r PORT_MAPPING; do
                    Display --indent 6 --text "- $PORT_MAPPING" --result INFO --color YELLOW
                done
            fi
            
            # Check for resource limits
            MEMORY_LIMIT=$(echo "$CONTAINER_INFO" | jq -r '.[0].HostConfig.Memory')
            CPU_LIMIT=$(echo "$CONTAINER_INFO" | jq -r '.[0].HostConfig.NanoCpus')
            if [ "$MEMORY_LIMIT" = "0" ] || [ "$CPU_LIMIT" = "0" ]; then
                Display --indent 4 --text "- Container does not have resource limits set" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' does not have resource limits set" "$CONTAINER_ID" "text:Set memory and CPU limits for containers"
            fi
            
            # Check for mount propagation
            MOUNTS=$(echo "$CONTAINER_INFO" | jq -r '.[0].Mounts[].Propagation')
            if echo "$MOUNTS" | grep -q "shared"; then
                Display --indent 4 --text "- Container has shared mount propagation" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Container '$CONTAINER_ID' has shared mount propagation" "$CONTAINER_ID" "text:Avoid using shared mount propagation"
            fi
        done
    else
        Display --indent 2 --text "- No running containers found" --result INFO --color YELLOW
    fi
fi

# DOCKER-0004: Check Docker image vulnerabilities using Trivy.
Register --test-no DOCKER-0004 --weight H --network YES --description "Check Docker image vulnerabilities using Trivy"
if [ "${SKIPTEST}" -eq 0 ]; then
    if command -v trivy >/dev/null 2>&1; then
        TRIVY_CACHE_DIR="/tmp/trivy-cache"
        mkdir -p "$TRIVY_CACHE_DIR"

        RUNNING_CONTAINERS=$(docker ps -q)
        if [ -n "$RUNNING_CONTAINERS" ]; then
            echo "$RUNNING_CONTAINERS" | xargs -I {} -P "$(nproc)" sh -c "
                CONTAINER_ID=\"{}\"
                CONTAINER_IMAGE=\$(docker inspect --format \"{{.Config.Image}}\" \"$CONTAINER_ID\" 2>/dev/null)
                CACHE_FILE=\"$TRIVY_CACHE_DIR/\$(echo \"$CONTAINER_IMAGE\" | tr \":/\\\" \"-\").json\"

                Display --indent 2 --text \"- Scanning image: $CONTAINER_IMAGE for vulnerabilities\" --result INFO --color BLUE

                if [ -f \"$CACHE_FILE\" ] && [ \$(($(date +%s) - \$(date -r \"$CACHE_FILE\" +%s))) -lt 86400 ]; then
                    cat \"$CACHE_FILE\"
                else
                    trivy image --exit-code 1 --no-progress --format json --output \"$CACHE_FILE\" \"$CONTAINER_IMAGE\" >/dev/null 2>&1
                fi

                VULN_COUNT=\$(jq \".Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == \\\"HIGH\\\" or .Severity == \\\"CRITICAL\\\") | .VulnerabilityID\" \"$CACHE_FILE\" | wc -l)

                if [ \"\$VULN_COUNT\" -gt 0 ]; then
                    Display --indent 4 --text \"- Found \$VULN_COUNT HIGH/CRITICAL vulnerabilities\" --result WARNING --color RED
                    ReportWarning \"${TEST_NO}\" \"Found \$VULN_COUNT HIGH/CRITICAL vulnerabilities in $CONTAINER_IMAGE\" \"$CONTAINER_IMAGE\" \"text:Fix vulnerabilities in image\"
                else
                    Display --indent 4 --text \"- No HIGH/CRITICAL vulnerabilities found\" --result OK --color GREEN
                fi
            "
        else
            Display --indent 2 --text "- No running containers found" --result INFO --color YELLOW
        fi
    else
        Display --indent 2 --text "- Trivy is not installed" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Trivy is not installed" "trivy" "text:Install Trivy for vulnerability scanning"
    fi
fi

# DOCKER-0005: Check Docker daemon security
Register --test-no DOCKER-0005 --weight H --network NO --description "Check Docker daemon security"
if [ "${SKIPTEST}" -eq 0 ]; then
    # Check if Docker daemon is running with user namespace remapping
    if ! pgrep -f "dockerd.*--userns-remap" >/dev/null; then
        Display --indent 2 --text "- Docker daemon is not running with '--userns-remap' option" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker daemon is not running with '--userns-remap' option" "dockerd" "text:Enable '--userns-remap' option for better isolation"
    fi

    # Check Docker daemon user
    DOCKER_DAEMON_USER=$(ps -o user= -p "$(pgrep dockerd)")
    if [ "$DOCKER_DAEMON_USER" = "root" ]; then
        Display --indent 2 --text "- Docker daemon is running as root" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker daemon is running as root" "dockerd" "text:Consider running Docker daemon as non-root user"
    fi

    # Check Docker socket permissions
    DOCKER_SOCKET="/var/run/docker.sock"
    if [ -e "$DOCKER_SOCKET" ]; then
        DOCKER_SOCKET_PERM=$(stat -c %a "$DOCKER_SOCKET")
        if [ "$DOCKER_SOCKET_PERM" -gt 660 ]; then
            Display --indent 2 --text "- Docker socket permissions are too open: $DOCKER_SOCKET_PERM" --result WARNING --color RED
            ReportWarning "${TEST_NO}" "Docker socket permissions are too open: $DOCKER_SOCKET_PERM" "$DOCKER_SOCKET" "text:Restrict Docker socket permissions to 660 or less"
        fi
    fi

    # Check for experimental features
    if docker version | grep -q "Experimental: true"; then
        Display --indent 2 --text "- Docker is running with experimental features enabled" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker is running with experimental features enabled" "docker" "text:Disable experimental features in production environments"
    fi

    # Check for insecure registries
    if docker info | grep -q "Insecure Registries"; then
        Display --indent 2 --text "- Docker is configured with insecure registries" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker is configured with insecure registries" "docker" "text:Remove or secure insecure registries"
    fi

    # Check Docker content trust
    if ! docker info | grep -q "Content trust: true"; then
        Display --indent 2 --text "- Docker content trust is not enabled" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker content trust is not enabled" "docker" "text:Enable Docker content trust for image verification"
    fi

    # Check auditd rules for Docker
    if command -v auditctl >/dev/null 2>&1; then
        DOCKER_AUDIT_RULES=$(auditctl -l | grep -c docker)
        if [ "$DOCKER_AUDIT_RULES" -eq 0 ]; then
            Display --indent 2 --text "- No Docker-specific audit rules found" --result WARNING --color RED
            ReportWarning "${TEST_NO}" "No Docker-specific audit rules found" "auditd" "text:Add Docker-specific audit rules"
        fi
    fi
fi

# DOCKER-0006: Check Docker Compose security
Register --test-no DOCKER-0006 --weight M --network NO --description "Check Docker Compose security"
if [ "${SKIPTEST}" -eq 0 ]; then
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose version --short)
        Display --indent 2 --text "- Docker Compose is installed (version $COMPOSE_VERSION)" --result OK --color GREEN

        # Scan Docker Compose files
        COMPOSE_FILES=$(find / -name docker-compose.yml -o -name docker-compose.yaml 2>/dev/null)
        for COMPOSE_FILE in $COMPOSE_FILES; do
            Display --indent 4 --text "- Checking Compose file: $COMPOSE_FILE" --result INFO --color BLUE
            
            # Check for insecure configurations
            if grep -qE "privileged:\s*true" "$COMPOSE_FILE"; then
                Display --indent 6 --text "- Privileged mode detected" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Privileged mode detected in $COMPOSE_FILE" "$COMPOSE_FILE" "text:Avoid using privileged mode in Docker Compose"
            fi

            if grep -qE "network_mode:\s*host" "$COMPOSE_FILE"; then
                Display --indent 6 --text "- Host network mode detected" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Host network mode detected in $COMPOSE_FILE" "$COMPOSE_FILE" "text:Avoid using host network mode in Docker Compose"
            fi

            if ! grep -q "version:" "$COMPOSE_FILE"; then
                Display --indent 6 --text "- Docker Compose file version not specified" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Docker Compose file version not specified in $COMPOSE_FILE" "$COMPOSE_FILE" "text:Specify Docker Compose file version"
            fi

            if grep -qE "volumes:\s*-\s*/:/host" "$COMPOSE_FILE"; then
                Display --indent 6 --text "- Root filesystem mount detected" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Root filesystem mount detected in $COMPOSE_FILE" "$COMPOSE_FILE" "text:Avoid mounting the root filesystem in Docker Compose"
            fi
        done
    else
        Display --indent 2 --text "- Docker Compose is not installed" --result INFO --color YELLOW
    fi
fi

# DOCKER-0007: Check Docker network security
Register --test-no DOCKER-0007 --weight M --network NO --description "Check Docker network security"
if [ "${SKIPTEST}" -eq 0 ]; then
    CUSTOM_NETWORKS=$(docker network ls --filter driver=bridge --format '{{.Name}}' | grep -v '^bridge$')
    if [ -n "$CUSTOM_NETWORKS" ]; then
        Display --indent 2 --text "- Custom bridge networks found" --result OK --color GREEN
        echo "$CUSTOM_NETWORKS" | while read -r NETWORK; do
            Display --indent 4 --text "- $NETWORK" --result INFO --color BLUE
            
            # Check network encryption
            NETWORK_ENCRYPTED=$(docker network inspect "$NETWORK" --format '{{.EnableIPv6}}')
            if [ "$NETWORK_ENCRYPTED" != "true" ]; then
                Display --indent 6 --text "- Network encryption not enabled" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Network encryption not enabled for $NETWORK" "$NETWORK" "text:Enable network encryption for custom bridge networks"
            fi
        done
    else
        Display --indent 2 --text "- No custom bridge networks found" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "No custom bridge networks found" "docker" "text:Create custom bridge networks for better network segmentation"
    fi

    # Check for containers using the default bridge network
    DEFAULT_BRIDGE_CONTAINERS=$(docker network inspect bridge -f '{{range .Containers}}{{.Name}} {{end}}')
    if [ -n "$DEFAULT_BRIDGE_CONTAINERS" ]; then
        Display --indent 2 --text "- Containers found using default bridge network" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Containers using default bridge network" "docker" "text:Move containers to custom bridge networks"
    fi
fi

# DOCKER-0008: Check Docker volumes security
Register --test-no DOCKER-0008 --weight M --network NO --description "Check Docker volumes security"
if [ "${SKIPTEST}" -eq 0 ]; then
    VOLUMES=$(docker volume ls --format '{{.Name}}')
    if [ -n "$VOLUMES" ]; then
        Display --indent 2 --text "- Docker volumes found" --result OK --color GREEN
        echo "$VOLUMES" | while read -r VOLUME; do
            VOLUME_PATH=$(docker volume inspect --format '{{.Mountpoint}}' "$VOLUME")
            VOLUME_PERMS=$(stat -c '%a' "$VOLUME_PATH" 2>/dev/null)
            VOLUME_OWNER=$(stat -c '%U:%G' "$VOLUME_PATH" 2>/dev/null)
            
            Display --indent 4 --text "- Volume: $VOLUME" --result INFO --color BLUE
            Display --indent 6 --text "- Path: $VOLUME_PATH" --result INFO --color CYAN
            Display --indent 6 --text "- Permissions: $VOLUME_PERMS" --result INFO --color CYAN
            Display --indent 6 --text "- Owner: $VOLUME_OWNER" --result INFO --color CYAN

            if [ "$VOLUME_PERMS" != "700" ]; then
                Display --indent 6 --text "- Volume permissions are not restricted" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Volume $VOLUME has loose permissions: $VOLUME_PERMS" "$VOLUME" "text:Restrict volume permissions to 700"
            fi

            # Check for sensitive data in volume names
            if echo "$VOLUME" | grep -qiE '(password|secret|key|token|credential)'; then
                Display --indent 6 --text "- Volume name may contain sensitive information" --result WARNING --color RED
                ReportWarning "${TEST_NO}" "Volume name $VOLUME may contain sensitive information" "$VOLUME" "text:Avoid using sensitive information in volume names"
            fi
        done
    else
        Display --indent 2 --text "- No Docker volumes found" --result INFO --color YELLOW
    fi
fi

# DOCKER-0009: Check Docker logging configuration
Register --test-no DOCKER-0009 --weight L --network NO --description "Check Docker logging configuration"
if [ "${SKIPTEST}" -eq 0 ]; then
    LOG_DRIVER=$(docker info --format '{{.LoggingDriver}}')
    Display --indent 2 --text "- Docker logging driver: $LOG_DRIVER" --result INFO --color BLUE

    if [ "$LOG_DRIVER" = "json-file" ]; then
        LOG_MAX_SIZE=$(docker info --format '{{index .DriverStatus 2}}' | grep -oP 'max-size=\K.*')
        LOG_MAX_FILE=$(docker info --format '{{index .DriverStatus 3}}' | grep -oP 'max-file=\K.*')

        if [ -z "$LOG_MAX_SIZE" ] || [ -z "$LOG_MAX_FILE" ]; then
            Display --indent 4 --text "- Log rotation not configured" --result WARNING --color RED
            ReportWarning "${TEST_NO}" "Docker log rotation not configured" "docker" "text:Configure log rotation for the json-file logging driver"
        else
            Display --indent 4 --text "- Log rotation configured (max-size: $LOG_MAX_SIZE, max-file: $LOG_MAX_FILE)" --result OK --color GREEN
        fi
    fi
fi

# DOCKER-0010: Check for Docker rootless mode
Register --test-no DOCKER-0010 --weight H --network NO --description "Check for Docker rootless mode"
if [ "${SKIPTEST}" -eq 0 ]; then
    if docker info 2>/dev/null | grep -q "rootless"; then
        Display --indent 2 --text "- Docker is running in rootless mode" --result OK --color GREEN
    else
        Display --indent 2 --text "- Docker is not running in rootless mode" --result WARNING --color RED
        ReportWarning "${TEST_NO}" "Docker is not running in rootless mode" "docker" "text:Consider running Docker in rootless mode for improved security"
    fi
fi

# Wait for keypress (unless --quick is being used)
WaitForKeyPress
