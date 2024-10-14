# Advanced Docker Security Scanner Plugin for Lynis

## What's This?

This enhanced Lynis plugin is your comprehensive toolkit for Docker security automation. It performs a wide range of checks to ensure your Docker environment adheres to best practices and security standards.

## Quick Start

1. **Download the Plugin**:
   ```bash
   wget https://example.com/path/to/dockers-001.sh
   ```

2. **Make it Executable and Move it to the Lynis Plugins Directory**:
   ```bash
   chmod +x dockers-001.sh
   sudo mv dockers-001.sh /usr/local/lynis/include/plugins/
   ```

3. **Run Lynis with the Plugin**:
   ```bash
   sudo lynis audit system --plugins
   ```

## Why You Need This

Docker simplifies containerization, but it introduces unique security challenges. This plugin acts as your security-conscious assistant, performing thorough checks on your Docker setup to identify potential vulnerabilities and misconfigurations.

## What It Does

### Docker Installation Check (DOCKER-0001)
- **Verifies Docker Installation**: Ensures Docker is installed on the system.
- **Alerts if Docker is Missing**: Warns if Docker is not installed.

### Daemon Configuration Audit (DOCKER-0002)
- **Examines `/etc/docker/daemon.json`**: Checks for iptables support and JSON file logging.

### Container Security Scan (DOCKER-0003)
- **Analyzes Running Containers**: Checks for root user execution and read-only filesystem usage.
- **Health Checks**: Verifies configured health checks in containers.

### Image Vulnerability Scan (DOCKER-0004)
- **Utilizes Trivy**: Scans container images for vulnerabilities.
- **Focuses on High and Critical Vulnerabilities**: Identifies critical security issues.

### Daemon Security Audit (DOCKER-0005)
- **Checks Various Daemon Settings**: Includes user namespace remapping, socket permissions, and experimental features.

### Docker Compose Check (DOCKER-0006)
- **Verifies Docker Compose Version**: Recommends upgrades if necessary.

### Network Configuration Check (DOCKER-0007)
- **Identifies Use of Host Network and MacVLAN Driver**: Warns about potential security risks.

### Volume Permissions Check (DOCKER-0008)
- **Examines Docker Volume Permissions**: Alerts on overly permissive settings.

### Image Signing and Verification Check (DOCKER-0009)
- **Verifies Docker Content Trust**: Encourages use of image signing for enhanced security.

### Secrets Usage Check in Swarm Mode (DOCKER-0010)
- **Checks for Docker Secrets Usage**: Recommends using secrets for sensitive data.

### Logging Driver Configuration Check (DOCKER-0011)
- **Identifies Current Logging Driver**: Warns about potential disk space issues with unbounded JSON file logging.


## How to Use It

After installation, run Lynis with plugins enabled:

```bash
sudo lynis audit system --plugins
```

Look for "DOCKERS" in the output for our specific checks.

## Customizing

The script is written in Bash and is highly customizable. Feel free to review and adjust as needed, ensuring to test your changes thoroughly.

## Contributing

We welcome contributions! Here's how to get involved:

1. **Fork the Repo**
2. **Create a New Branch**: `git checkout -b my-new-feature`
3. **Make Your Changes**
4. **Commit Them**: `git commit -am 'Added a new feature'`
5. **Push to the Branch**: `git push origin my-new-feature`
6. **Create a New Pull Request**

Your ideas and improvements are valuable to us!

## Compatibility

- **Compatible with Lynis 3.0.0 and Later**
- **Tested on Major Linux Distributions**: Ubuntu, CentOS, Debian, Alpine
- **Requires Bash 4.0+** (Standard on Most Systems)
- **Works with Docker 19.03 and Later**

## License

This plugin is released under the MIT License. Use, modify, and share freely – just keep the license intact.

## Need Help?

If you encounter issues or have questions:

- **Consult the Lynis Documentation First**
- **For Plugin-Specific Queries, Use github issues**

## Final Thoughts

Security in containerized environments is crucial and ever-evolving. This plugin is a tool in your Docker security arsenal, but it's not a silver bullet. Use it as part of a comprehensive security strategy, stay updated with the latest Docker security best practices, and always be proactive in securing your containerized infrastructure.

Good luck and stay safe,

-AphroBytes