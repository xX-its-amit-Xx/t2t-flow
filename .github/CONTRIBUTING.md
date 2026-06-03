# Contributing to t2t-flow

Thanks for your interest in improving **t2t-flow**, a Nextflow DSL2 pipeline for
telomere-to-telomere de novo genome assembly of non-model organisms from long
reads. Contributions of all kinds are welcome: bug reports, documentation,
new modules, and feature work.

## How to contribute

1. **Open an issue first** for anything non-trivial so we can agree on the
   approach before you invest time.
2. **Fork** the repository and create a feature branch off `dev`
   (`git checkout -b my-feature dev`). PRs target `dev`; releases are cut from
   `main`.
3. **Make your change** following the conventions below.
4. **Open a pull request** against `dev` with a clear description of what and why.

## Pipeline conventions

This pipeline follows [nf-core](https://nf-co.re) conventions:

- **One process per file** under `modules/local/`. File names are lowercase
  (e.g. `seqkit_stats.nf`); process names are UPPERCASE (e.g. `SEQKIT_STATS`).
- Every process declares: `tag`, exactly one resource `label`, a `conda`
  directive, a **dual** `container` directive (Galaxy depot Singularity image +
  biocontainers Docker image), `input:`, `output:` with named `emit:`, a
  `when:` guard, a `script:` block, and a `stub:` block.
- Every process **emits a `versions.yml`** capturing the tool version.
- Every `stub:` block must recreate **all** declared outputs using only POSIX
  coreutils (`touch`, `mkdir -p`, `echo`, `printf`) — no tool calls — and write
  a valid `versions.yml`. This is what keeps the stub CI gate container-free.
- Subworkflow and process names are UPPERCASE; channels carry
  `tuple val(meta), path(...)` where `meta = [ id: <sample> ]`.

## Continuous integration

Two workflows run on every push and pull request to `main`/`dev`:

- **`.github/workflows/ci.yml`**
  - `stub` (**required gate**): runs `nextflow run . -profile test -stub-run`
    across a Nextflow version matrix, using host coreutils only — no containers,
    so it finishes in minutes. **Your stub blocks must keep this green.**
  - `test-docker`: a real container run with `-profile test,docker`. It is
    gated to `workflow_dispatch` or a `test-docker` PR label and is
    `continue-on-error`, so it never blocks merges.
  - `lint`: byte-compiles `bin/*.py` and runs a `nextflow config` sanity check.
- **`.github/workflows/linting.yml`**: best-effort EditorConfig / Prettier /
  markdownlint checks (`continue-on-error`) plus a **required** assertion that
  the project ships GPLv3.

Before opening a PR, please run the stub locally:

```bash
nextflow run . -profile test -stub-run --outdir results
```

and byte-compile any Python helpers you touched:

```bash
python -m py_compile bin/*.py
```

## Coding style

- Respect the repository `.editorconfig`.
- Format YAML, JSON, and Markdown with Prettier where practical.
- Keep new parameters consistent with the authoritative params list in
  `nextflow.config` and document them in the schema.

## License

t2t-flow is released under the **GNU General Public License v3.0 (GPLv3)**. By
contributing, you agree that your contributions are licensed under the same
terms. See [`LICENSE`](../LICENSE).
