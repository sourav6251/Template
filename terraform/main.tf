terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "google" {
  credentials = file("/home/sourav/Downloads/woven-acolyte-468813-q9-daeda0347e70.json") # replace with actual path
  project     = "woven-acolyte-468813-q9"   # replace with your project ID
  region      = "us-central1"               # region
  zone        = "us-central1-a"             # zone
}

# Reserve a static external IP
resource "google_compute_address" "static_ip" {
  name   = "todo-static-ip"
  region = "us-central1"  # must match provider region
}

# VM Instance
resource "google_compute_instance" "default" {
  name         = "todo-vm"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"  # image family (always latest Debian 11)
      size  = 10
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata = {
    ssh-keys = "sourav:${file("~/.ssh/jenkinsagent.pub")}"
  }

  tags = ["http-server", "https-server"]
}

# Allow HTTP/HTTPS firewall
resource "google_compute_firewall" "default" {
  name    = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags = ["http-server", "https-server"]
}

# Output static IP
output "static_ip_address" {
  value = google_compute_address.static_ip.address
}
