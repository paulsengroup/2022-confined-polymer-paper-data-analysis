# Synopsis

This repository contains the source code and input data used to generate Figure 5 of "Association of flexible filaments under different confinement geometries" (preprint available soon).

Input data download and subsequent analyses are automated using Nextflow and Singularity/Apptainer.

## Docker images availability

Docker images are hosted on GHCR and can be found in the [Packages](https://github.com/orgs/paulsengroup/packages?repo_name=2022-confined-polymer-paper-data-analysis) page of this repository.

Images were generated using the `build-dockerfiles.yml` GHA workflow using the Dockerfiles from the `containers` folder.

## Nextflow workflows

Nextflow workflows under `workflows` were developed and tested using Nextflow v22.10.0, and should in principle work with any version supporting Nextflow DSL2.

Each workflow is paired with a config file (see `configs` folder). As an example, `workflows/fetch_data.nf` is paired with config `configs/fetch_data.config`.

## Requirements

- Access to an internet connection (required to download input files and Docker images)
- Nextflow v20.07.1 or newer
- Apptainer/Singularity (tested with Singularity v3.7.2)

## Running workflows

Workflows should be executed in the following order:
1. `fetch_data.nf`
2. `preprocess_data.nf`
3. `compute_histograms.nf`


Inside the `config` folder there are two base configs (`base_hovig.config` and `base_saga.config`). The first config can be used to run workflows on a single node/machine without using a job scheduler, while the second config can be used to run workflows on a compute cluster using the SLURM scheduler.

Both configs are specific to the machine and cluster we used during workflow development and data analysis, and will most likely need to be updated in order to run on other machines/clusters.

Refer to `run_*.sh` scripts for examples on how to run workflows.

Please make sure Nextflow is properly installed and configured before running any of the workflows.
