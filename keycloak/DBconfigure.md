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
sudo docker run -d --name keycloak \
  --restart=always \
  --network keycloak-network \
  -p 8080:8080 \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://103.49.131.57:5432/mydb \
  -e KC_DB_USERNAME=myuser \
  -e KC_DB_PASSWORD=sourav \
  -e KC_DB_SCHEMA=keycloak \
  -e KC_HTTP_ENABLED=true \
  -e KC_PROXY=edge  \
  -e KC_HOSTNAME=login.sourav.fun \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_HOSTNAME_STRICT_HTTPS=false \
  -e KC_HTTP_PORT=8080 \
  -e KC_HOSTNAME_ADMIN_URL=https://login.sourav.fun \
  -e KC_HOSTNAME_URL=https://login.sourav.fun \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=Admin@123 \
  quay.io/keycloak/keycloak:26.0.0 start

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
    server_name login.sourav.fun;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";  # Fixed this line
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