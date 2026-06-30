# Module Authoring Reference

Quick reference for contributing to this repository. See `README.md` for the
full overview.

## Versioning policy

- Modules use [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`)
  stored in each module's `VERSION` file.
- New modules start at `1.0.0`.
- Bump:
  - **PATCH** for backwards-compatible bug fixes.
  - **MINOR** for backwards-compatible new functionality (e.g. a new
    optional variable).
  - **MAJOR** for breaking changes (e.g. removing/renaming a variable,
    changing a resource's behavior in an incompatible way).

## Pull request process

- **One module per PR.** The publishing pipeline determines which module
  changed by looking at the folder of the files in the triggering commit; a
  PR that touches more than one module's directory cannot be published
  unambiguously.
- **Every PR must update `VERSION` and `CHANGELOG`.** A pipeline check
  (`pipeline-mandatory-files.yaml`) scans all commits in the PR and comments
  on the PR if neither file was changed, asking the author to confirm
  whether that's intentional.

## Branching strategy

- `main` always reflects the **latest** version of every module and is what
  the publish pipeline (`pipelines.yaml`) packages and publishes from.
- To release a **patch** for an older major version without pulling in
  unrelated `main` changes or bumping the major version, use a branch named
  `maintenance/[module]_v[version]` (e.g. `maintenance/nutanix_vm_v1`).
  Backport the fix there, bump the `PATCH` version, and publish from that
  branch.

## Documentation generation

- Each module's `README` (no extension) is partially auto-generated.
- The publish pipeline runs
  [`terraform-docs`](https://terraform-docs.io/) in `inject` mode, which
  writes the generated variables/outputs/resources documentation between
  the following markers in the module's `README`:

  ```
  <!-- BEGIN_TF_DOCS -->
  ...auto-generated content...
  <!-- END_TF_DOCS -->
  ```

- Content outside these markers (e.g. a hand-written description at the top
  of the `README`) is preserved across regenerations. Always include the
  marker pair in a new module's `README` so the pipeline has somewhere to
  inject documentation.
