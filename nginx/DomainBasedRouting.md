
# Nginx Reverse Proxy for Domain Based Routing

This guide shows how to configure **Nginx** to serve two different Docker-based applications
on two different domains from the same VM.

## Overview
We will forward:
- `http://domain1.com` → **App 1** (running on `localhost:8000`)
- `http://domain2.com` → **App 2** (running on `localhost:8001`)

## Prerequisites
- A Linux VM with Nginx installed:
```bash
sudo apt update && sudo apt install nginx -y
```


# App1 - domain1.com
```nginx
server {
    listen 80;
    server_name domain1.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

# App2 - domain2.com
```nginx
server {
    listen 80;
    server_name domain2.com;

    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
