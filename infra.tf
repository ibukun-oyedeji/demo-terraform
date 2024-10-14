provider "google" {
  project = "molten-hall-435812-c3"
  region  = "us-central1"
}

# Terraform backend configuration to store the state file in a GCS bucket
terraform {
  backend "gcs" {
    bucket = "my-unique-terraform-state-bucket"  # Manually specify a unique bucket name
    prefix = "terraform/state"
  }
}

# Create VPC
resource "google_compute_network" "vpc_network" {
  name = "my-vpc"
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.name
}

# Firewall rule to allow HTTP, SSH, and ICMP traffic
resource "google_compute_firewall" "allow-http-ssh-icmp" {
  name    = "allow-http-ssh-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create External IP
resource "google_compute_address" "external_ip" {
  name   = "vm-external-ip"
  region = "us-central1"
}

# Generate SSH key pair
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a VM instance with the generated SSH public key and NGINX setup
resource "google_compute_instance" "vm_instance" {
  name         = "my-vm"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
  EOF

  metadata = {
    ssh-keys = "your-ssh-username:${tls_private_key.vm_ssh.public_key_openssh}"
  }

  depends_on = [
    google_compute_subnetwork.subnet,
    google_compute_firewall.allow-http-ssh-icmp,
    google_compute_address.external_ip
  ]
}

# Cloud SQL (PostgreSQL) Instance
resource "google_sql_database_instance" "sql_instance" {
  name             = "my-sql-instance"
  database_version = "POSTGRES_13"
  region           = "us-central1"
  settings {
    tier = "db-f1-micro"
  }
}

# Cloud SQL Database
resource "google_sql_database" "my_database" {
  name     = "myapp_db"
  instance = google_sql_database_instance.sql_instance.name
}

# Outputs to retrieve the private key for SSH access
output "vm_private_key" {
  sensitive = true
  value     = tls_private_key.vm_ssh.private_key_pem
}

output "vm_public_ip" {
  value = google_compute_address.external_ip.address
}

output "cloud_sql_instance_name" {
  value = google_sql_database_instance.sql_instance.name
}
