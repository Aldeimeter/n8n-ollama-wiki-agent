resource "yandex_storage_bucket" "state" {
  bucket    = "${var.project}-terraform-state-${var.folder_id}"
  folder_id = var.folder_id 

  versioning {
    enabled = true
  }
}
