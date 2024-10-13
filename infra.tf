provider "google" {
  project = "molten-hall-435812-c3"
  region  = "us-central1"
}

# Create a GCS bucket for Terraform state
resource "google_storage_bucket" "state_bucket" {
  name     = "my-terraform-state-bucket"
  location = "US"
  
  # Set bucket lifecycle policy to auto-delete objects after 365 days (optional)
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }
}

# Terraform backend configuration to store the state file in the bucket
terraform {
  backend "gcs" {
    bucket = google_storage_bucket.state_bucket.name
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

# Firewall rule to allow SSH and ICMP traffic
resource "google_compute_firewall" "allow-ssh-icmp" {
  name    = "allow-ssh-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
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

# Create a VM instance
resource "google_compute_instance" "vm_instance" {
  name         = "my-vm"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }

  metadata = {
    ssh-keys = "your-ssh-username:${file("~/.ssh/id_rsa.pub")}"
  }

  depends_on = [
    google_compute_subnetwork.subnet,
    google_compute_firewall.allow-ssh-icmp,
    google_compute_address.external_ip
  ]
}

# Outputs
output "vm_external_ip" {
  value = google_compute_address.external_ip.address
}
