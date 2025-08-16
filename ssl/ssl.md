# 1. Install Certbot
```bash
sudo apt install certbot python3-certbot-nginx -y
```
# 2. Obtain SSL Certificates
```bash
sudo certbot --nginx -d domain1.com -d domain2.com
```

# 3. Auto Renewal
```bash  
sudo certbot renew --dry-run
```