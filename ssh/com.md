# SSH Cheat Sheet & Security Configuration

## File Transfer

Use `scp` to securely transfer files to a remote server:

```sh
scp -i <ssh_key> <local_file_path> dassourav3738@34.67.188.124:<remote_directory>
```

---

## Create SSH Key

Generate a secure 4096-bit RSA key pair:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

---

## SSH Hardening Configuration

Apply the following settings in `/etc/ssh/sshd_config` to protect your server:

```ssh
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin prohibit-password
```

---

## Brute-Force Prevention (Fail2ban)

### Step 1: Install Fail2ban

```sh
sudo apt update && sudo apt install fail2ban -y
```

### Step 2: Copy Default Configuration

Create a local configuration override:

```sh
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

### Step 3: Configure SSH Protection

Edit the configuration file:

```sh
sudo nano /etc/fail2ban/jail.local
```

Add or update the following block:

```ini
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s

maxretry = 3
findtime = 10m
bantime = 24h
```

* **`maxretry = 3`**: Ban the IP after 3 failed login attempts.
* **`findtime = 10m`**: Count failed attempts within a 10-minute window.
* **`bantime = 24h`**: Ban the offending IP for 24 hours.

### Step 4: Enable and Restart Service

```sh
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

### Unbanning an IP

To manually unban an IP address:

```sh
sudo fail2ban-client set sshd unbanip <ip_address>
```
