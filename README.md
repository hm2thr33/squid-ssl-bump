# Squid SSL-Bump Proxy

A containerized Squid proxy with SSL bump (HTTPS interception) support, running on Alpine Linux. This proxy allows you to transparently inspect both HTTP and HTTPS traffic while maintaining certificate validity.

## Features

- **Dual-port proxy**: Port 3128 (standard proxy) and port 4128 (SSL bump enabled)
- **SSL/TLS Interception**: Dynamically generates per-host certificates for HTTPS inspection
- **Docker containerized**: Lightweight Alpine Linux base with automated setup
- **Configurable**: Customizable CA certificate subject, cache size, and ACLs
- **Production-ready**: Includes logging, cache management, and error handling
- **Easy deployment**: Docker Compose ready

## Prerequisites

- Docker and Docker Compose installed
- Ports 3128 and 4128 available on your host
- Permission to modify system trust stores (for CA certificate installation)

## Quick Start

### 1. Start the Proxy

```bash
docker compose up -d
```

### 2. Configure Your Client

Configure your application or system to use the proxy:
- **HTTP/HTTPS proxy**: `localhost:3128` (standard proxy, no SSL inspection)
- **HTTPS proxy with SSL bump**: `localhost:4128` (intercepts HTTPS traffic)

### 3. Trust the CA Certificate (for HTTPS inspection)

The container generates a CA certificate on first boot and saves it to:

```
squid/ssl/ca-cert.der
```

**For port 4128 (SSL bump) to work without certificate warnings**, install this CA in your system trust store:

#### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain squid/ssl/ca-cert.der
```

#### Linux (Ubuntu/Debian)

```bash
sudo cp squid/ssl/ca-cert.der /usr/local/share/ca-certificates/squid-ca.crt
sudo update-ca-certificates
```

#### Windows

1. Right-click `squid/ssl/ca-cert.der`
2. Select "Install Certificate"
3. Choose "Local Machine" and "Trusted Root Certification Authorities"

#### Verify Certificate Installation

```bash
openssl x509 -in squid/ssl/ca-cert.der -inform DER -text -noout | grep -E "Subject:|Issuer:"
```

## Configuration

### Certificate Customization

The container generates a self-signed CA certificate on first boot using these defaults:

```dockerfile
ENV CN=proxy.squid.com
    O=squid
    OU=squid
    C=US
```

To customize the certificate subject, edit `docker-compose.yml`:

```yaml
services:
  squid:
    environment:
      CN: proxy.example.com
      O: ExampleCorp
      OU: Security
      C: US
```

Then regenerate the certificate:

```bash
rm -f squid/ssl/ca-cert.pem squid/ssl/ca-key.pem squid/ssl/ca-cert.der
docker compose up -d
```

**Note:** If certificate files already exist in `squid/ssl/`, the environment variables will be **ignored**. Delete them first to use new values.

### Using Pre-existing Certificates

To use your own CA certificates, place them in `squid/ssl/` before starting the container:

- `squid/ssl/ca-key.pem` - Private key
- `squid/ssl/ca-cert.pem` - Certificate

When these files exist, the entrypoint skips certificate generation.

### Cache Configuration

Edit `squid/conf/squid.conf` to adjust cache settings:

```nginx
# Cache directory size (1000 MB)
cache_dir ufs /var/cache/squid 1000 16 256

# Memory cache (256 MB)
cache_mem 256 MB

# Maximum object size (50 MB)
maximum_object_size 50 MB

# Minimum object size (0 KB)
minimum_object_size 0 KB
```

### Network ACLs

The configuration allows connections from private networks by default:

```nginx
acl localnet src 192.168.0.0/16
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
```

Modify `squid/conf/squid.conf` to restrict or expand allowed networks.

### DNS Settings

Default DNS servers are Google's (8.8.8.8, 8.8.4.4). Override in `squid/conf/squid.conf`:

```nginx
dns_nameservers 1.1.1.1 1.0.0.1
```

## Usage

### Test the Proxy

Using curl:

```bash
# Standard proxy (no SSL inspection)
curl -x http://localhost:3128 https://example.com

# SSL bump proxy (intercepts HTTPS - requires trusted CA)
curl -x http://localhost:4128 https://example.com
```

### View Logs

Access logs:

```bash
tail -f squid/logs/access.log
```

Cache logs:

```bash
tail -f squid/logs/cache.log
```

Storage logs:

```bash
tail -f squid/logs/store.log
```

### Container Logs

```bash
docker compose logs --tail=100 squid
docker compose logs -f squid
```

### Check Certificate Details

```bash
openssl x509 -in squid/ssl/ca-cert.pem -text -noout
```

## Troubleshooting

### "Connection refused" on ports 3128 or 4128

- Verify ports are not in use: `lsof -i :3128 -i :4128` (macOS/Linux)
- Ensure Docker is running: `docker ps`

### SSL certificate warnings when accessing HTTPS sites via port 4128

- The CA certificate may not be installed in your system trust store
- Verify the CA is trusted: See "Trust the CA Certificate" section above
- Check certificate exists: `ls -la squid/ssl/ca-cert.der`

### Proxy appears to work but no HTTPS interception

- Confirm you're using port 4128 (not 3128)
- Verify the CA certificate is trusted on your system
- Check squid logs: `docker compose logs squid`

### Permission errors on squid/ssl or squid/cache directories

```bash
sudo chown -R 1001:1001 squid/
sudo chmod -R u+rw squid/
docker compose down
docker compose up -d
```

### Proxy is slow or not caching

- Check available disk space for cache
- Increase `cache_mem` in squid.conf if memory-bound
- Review access logs for repeated requests: `grep -c "TCP_" squid/logs/access.log`

### Container won't start

```bash
docker compose logs squid
```

Common causes:
- Invalid squid.conf syntax (test: `docker compose run squid squid -k check`)
- Port conflicts
- Permission issues on mounted directories

## Performance Tuning

For high-traffic deployments, consider:

1. **Increase cache size**:
   ```nginx
   cache_dir ufs /var/cache/squid 10000 16 256  # 10GB
   cache_mem 1024 MB
   ```

2. **Adjust helper processes**:
   ```nginx
   sslcrtd_children 20  # Default is 5
   ```

3. **Enable compression**:
   ```nginx
   request_header_add Via off
   vary_ignore_accept_encoding on
   ```

4. **Optimize refresh patterns** in squid.conf for your use case

## Security Considerations

⚠️ **SSL bump is an HTTPS interception technique.** Use only where you have:

- Explicit authorization from network users
- Legal compliance with local regulations
- Proper logging and monitoring for audits
- Strong data privacy policies in place

This proxy should **not** be exposed to untrusted networks without authentication and strict ACLs.

## Project Structure

```
.
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # Alpine-based image definition
├── docker-entrypoint.sh        # Container startup script
├── squid/
│   ├── conf/
│   │   └── squid.conf          # Squid proxy configuration
│   ├── cache/                  # Cache directory (created at runtime)
│   ├── logs/                   # Log files (created at runtime)
│   └── ssl/                    # CA certificates (created at runtime)
└── README.md                   # This file
```

## Maintenance

### Rebuild the Image

```bash
docker compose down
docker compose up -d --build
```

### Clear Cache

```bash
docker compose down
rm -rf squid/cache/*
docker compose up -d
```

### Reset to Defaults

```bash
docker compose down
rm -rf squid/cache squid/logs squid/ssl/ca-*.* squid/ssl/*.db
docker compose up -d
```

## License

This project is provided as-is for educational and authorized security purposes.

## References

- [Squid Proxy Documentation](http://www.squid-cache.org/)
- [SSL Bump](https://wiki.squid-cache.org/Features/SslBump)
- [Alpine Linux](https://alpinelinux.org/)
