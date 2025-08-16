# Nginx Reverse Proxy Setup for Path Based Routing

This guide explains how to configure **Nginx** as a reverse proxy for multiple applications
running inside Docker containers on the same VM.

## Overview
We will forward:
- `http://your-domain.com/app1` → **App 1** (running on `localhost:8000`)
- `http://your-domain.com/app2` → **App 2** (running on `localhost:8001`)

The root path `/` will redirect to `/app1`.

## Prerequisites
- A Linux VM with Nginx installed:
```bash
  sudo apt update && sudo apt install nginx -y
```
```docker
docker run -d --name app1 -p 8000:80 myimage1
docker run -d --name app2 -p 8001:80 myimage2
```
```nginx
server {
    listen 80;
    server_name your-domain.com;

    # App1 - Handles /app1 and subpaths
    location /app1 {
        proxy_pass http://localhost:8000/;  # Trailing slash strips /app1
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # App2 - Handles /app2 and subpaths
    location /app2 {
        proxy_pass http://localhost:8001/;  # Trailing slash strips /app2
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Optional: Redirect root to one app
    location = / {
        return 302 /app1;
    }
}

```
write above configuration in `/etc/nginx/sites-available/multi-app.conf`

## Enable the Configuration
```sh
sudo ln -s /etc/nginx/sites-available/multi-app.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```


