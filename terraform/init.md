## Install required dependencies
```bash
sudo apt install -y gnupg software-properties-common curl
```
## Add HashiCorp’s official GPG key
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```
## Add the HashiCorp repo
```bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
```
## Install Terraform
```bash
sudo apt update
sudo apt install terraform -y
```

```bash
terraform init      # initialise project (do this once or after changing providers)
terraform validate  # optional: check syntax
terraform plan      # preview what resources will be created/changed
terraform apply     # apply changes (you’ll be asked to confirm)
terraform destroy   # remove everything (be careful!)

```