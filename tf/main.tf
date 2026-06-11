terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.23.0"
    }
  }

  # Remote state — shared infra must not live on one laptop. Bucket is created
  # out-of-band (it can't live in the state it backs) and has versioning enabled.
  backend "gcs" {
    bucket = "squadquest-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "squadquest-d8665"
  region  = "us-central1"
}
