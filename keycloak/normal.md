```sh
sudo docker run -d --name keycloak \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=AdminPass123 \
  -e KC_HOSTNAME=<yourdomain.com> \
  -e KC_PROXY=edge \
  quay.io/keycloak/keycloak:25.0.0 start-dev

```