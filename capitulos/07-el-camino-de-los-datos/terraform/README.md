# Terraform baseline — Chapter 07

This baseline creates encrypted/versioned S3 raw and curated buckets with public access blocked, an AWS Glue Data Catalog database, and an Athena workgroup with an enforced scan cutoff.

It intentionally does not grant Lake Formation permissions because production principals, domains, LF-Tags, and cross-account boundaries are workload-specific. Add those grants explicitly rather than shipping wildcard access.

```bash
terraform init
terraform plan
terraform apply
```

For production, evaluate customer-managed KMS keys, lifecycle policies, access logging, Lake Formation registration/grants, data-quality pipelines, and state/backend controls.
