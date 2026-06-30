# Nutanix Terraform Modules

This repository is Umicore's Terraform module library for Nutanix Infrastructure
as Code (IaC). It contains the reusable, versioned Terraform modules used to
provision and manage resources on Nutanix AHV across Umicore's environments.

## What this repo contains

Each top-level directory in this repository is a self-contained, reusable
Terraform module for Nutanix AHV (virtual machines, networks, storage
containers, etc.). Modules are designed to be composed by site environment
repositories rather than written inline, so that a fix or improvement made
once benefits every environment that consumes the module.

## How modules are distributed

Modules in this repository are **not** consumed directly via Terraform's
native module source mechanisms (git, registry). Instead:

1. On every change to a module folder on `main`, the Azure DevOps pipeline
   (`pipelines.yaml`) packages that module's directory into a zip archive and
   publishes it as an **Azure Artifacts Universal Package**, versioned using
   the module's `VERSION` file.
2. Site environment repositories declare which module versions they need and
   download them as part of their own build pipeline, placing each module
   under `./modules/<module_name>` in their working directory **before**
   running `terraform init`.

This keeps module versioning explicit and reproducible: a site environment
pins an exact module version, and upgrades are a deliberate, reviewed change.

## Module authoring guidelines

- Each module lives in its own directory, named in **lowercase**.
- Every module directory must contain the following files:
  - `VERSION` — no file extension, semantic version (e.g. `1.0.0`)
  - `CHANGELOG` — no file extension, human-readable history of changes
  - `README` — all caps, no file extension, module documentation
    (auto-generated/injected by `terraform-docs`)
  - `variables.tf` — input variable declarations
  - `locals.tf` — local value definitions
  - a main resource `.tf` file — the module's core resource definitions
  - `outputs.tf` — output value declarations
  - `provider.tf` — provider requirements/configuration for the module
- New modules start at version **`1.0.0`**.
- **Every change to a module must update its `CHANGELOG` and `VERSION`
  file.** A pipeline check on pull requests will flag PRs that don't.
- **One module per pull request.** The publishing pipeline detects which
  module changed by inspecting the folder of the changed files in the
  triggering commit — mixing changes to multiple modules in a single PR will
  produce ambiguous or incorrect publishes.

## Referencing a module from a site repo

A site environment repository references a module by name and pinned
version, after its build pipeline has downloaded the module into
`./modules/`:

```hcl
module "nutanix_vm" {
  version = "1.0.0"
  source  = "./modules/nutanix_vm"
  ...
}
```

The consuming pipeline downloads the Universal Package for each referenced
module and places it under `./modules/` before `terraform init` runs, so
that the relative `source` path resolves correctly.

## Branching strategy

- `main` always reflects the **latest** version of every module.
- For patch releases that must not pull in unrelated changes or bump a
  module's major version, use a `maintenance/[module]_v[version]` branch
  (e.g. `maintenance/nutanix_vm_v1`) to backport the fix and publish a patch
  release independently of `main`.
