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
