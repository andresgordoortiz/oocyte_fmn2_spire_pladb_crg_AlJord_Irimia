# Instructions on How to Run this code
This notebook is meant to be used by the **Al Jord** team at the **Centre for Genomic Regulation**. Everything in this repository runs in a *Virtual Machine* (either Docker or Singularity), which means that it should run the same regardless of when or where it is downloaded, as long as the the working directory is the root of this repository.

## Get Access to the HPC Cluster
As of 2024-2025, Emyr James is the head of Scientific IT, and he should be able to help you out regarding setting up your cluster access. Basically, you will need:
1. (Optional to work outside CRG) [Forticlient VPN](https://www.fortinet.com/lat/support/product-downloads): Select *Add New connection*, choose *SSL-VPN*, write any name and description for the connection, write ***https://vpn.crg.es:10000/sslvpn/*** as the *Remote Gateaway* and use your CRG credentials for the *Username* and *Password*.
2. SSH Client: If you use *MacOS* or *Linux* just open the Terminal and run:

    ```bash
    ssh login1.hpc.crg.es -l <your-CRG-username>
    # You will be prompted to introduce your CRG password
    ```
If using *Windows* instead, open *Powershell* or the *Terminal* as Administrator and run:

```powershell
wsl --install
wsl --set-default-version 2
wsl --install Ubuntu-20.04
```
This will install Ubuntu. Follow the instructions and after installation run:

```bash
ssh login1.hpc.crg.es -l <your-CRG-username>
# You will be prompted to introduce your CRG password
```
You will be now within your personal folder that resides within the lab team folder

## Download Repository

```bash
# Clone the repository to your HPC folder
git clone https://github.com/andresgordoortiz/24CRG_ADEL_MANU_OOCYTE_SPLICING.git
cd 24CRG_ADEL_MANU_OOCYTE_SPLICING
```

Now you are within the GitHub repo and can explore the folders using *ls* to *see them*:

```bash
ls
```

**Important**: All these folders are the ones existing in *Isilon*, and files can be uploaded and downloaded if needed through it, as usual.

## Run the Analysis performed by me
Running the following pipelines will do everything from downloading the samples up to getting the final Report and Excel tables.

```bash
# Important: you must pass a suitable VASTDB database as absolute path to run the pipelines
sbatch workflows/full_processing_pipeline_fmndko.sh /users/mirimia/projects/vast-tools/VASTDB
sbatch workflows/full_processing_pipeline_pladb.sh /users/mirimia/projects/vast-tools/VASTDB
sbatch workflows/full_processing_pipeline_spire.sh /users/mirimia/projects/vast-tools/VASTDB
```
**Important**: you must provide the workflow with a suitable path to the VASTDB database. If Manu has not changed it there should be one on his folder and, therefore, the code above should run smoothly. Otherwise, download it running this:

```bash
# This wll download the VASTDB for the mouse assembly.
mkdir VASTDB
wget https://vastdb.crg.eu/libs/vastdb.mm2.23.06.20.tar.gz
tar -xzvf vastdb.mm2.23.06.20.tar.gz -C VASTDB
```
And then run the pipelines with the new VASTDB:

```bash
sbatch workflows/full_processing_pipeline_fmndko.sh $(pwd)/VASTDB
sbatch workflows/full_processing_pipeline_pladb.sh $(pwd)/VASTDB
sbatch workflows/full_processing_pipeline_spire.sh $(pwd)/VASTDB
```

After a few hours the analysis should finish, but you can check the estatus of your query using:

```bash
squeue -u <your-CRG-user>
```
After it has finished, run the R Report (it will take an hour or so)

```bash
sbatch scripts/R/run_notebook.sh
```

