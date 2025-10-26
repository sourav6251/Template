# Keycloak Deployment Template (Docker + PostgreSQL + NGINX)

This is a reusable template to deploy Keycloak with Docker, PostgreSQL, and NGINX reverse proxy. Fill in your values where indicated.

---

## 1️⃣ Docker Network

```bash
# Create a Docker network for Keycloak
sudo docker network create <NETWORK_NAME>
```
## Docker 
```bash
sudo docker run -d --name <CONTAINER_NAME> \
  --network <NETWORK_NAME> \
  -p <HOST_PORT>:8080 \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://<DB_HOST>:<DB_PORT>/<DB_NAME> \
  -e KC_DB_USERNAME=<DB_USERNAME> \
  -e KC_DB_PASSWORD=<DB_PASSWORD> \
  -e KC_DB_SCHEMA=<DB_SCHEMA> \
  -e KC_PROXY=edge \
  -e KC_PROXY_HEADERS=xforwarded \
  -e KC_HOSTNAME=<HOSTNAME> \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=<ADMIN_USERNAME> \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=<ADMIN_PASSWORD> \
  quay.io/keycloak/keycloak:<KEYCLOAK_VERSION> start
```
## check logs
```sh
sudo docker logs -f <CONTAINER_NAME>
```
## 3️⃣ Install NGINX & Certbot
```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```
## 4️⃣ Configure NGINX Reverse Proxy
```bash
sudo nano /etc/nginx/sites-available/<HOSTNAME>


server {
    listen 80;
    server_name <HOSTNAME>;

    location / {
        proxy_pass http://127.0.0.1:<HOST_PORT>;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        # proxy_set_header Connection "upgrade";
        proxy_set_header Connection $connection_upgrade;
    }
}


sudo ln -s /etc/nginx/sites-available/<HOSTNAME> /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

```

## 5️⃣ Enable HTTPS (Optional)
```bash
sudo certbot --nginx -d <HOSTNAME>
```