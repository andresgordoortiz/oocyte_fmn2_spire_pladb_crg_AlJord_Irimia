# Use a base R image
FROM rocker/r-ver:4.3.1

# Set build argument for the GitHub Personal Access Token
ARG GITHUB_PAT
ENV GITHUB_PAT=${GITHUB_PAT}

# Install system dependencies for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev \
    pandoc \
    git \
    libxml2 \
    libxt6 \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libpcre3-dev \
    libicu-dev \
    libjpeg-dev \
    libpng-dev \
    libglpk-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create the workspace folder
RUN mkdir /workspace

# Set environment variables
ENV RENV_VERSION=0.17.3
ENV R_LIBS_USER=/workspace/renv/library

# Copy renv.lock and other files to the container
COPY renv.lock /workspace/renv.lock
WORKDIR /workspace

# Install renv and jsonlite
RUN R -e "install.packages(c('renv', 'jsonlite'), repos='https://cloud.r-project.org')"

# Pre-clone GitHub repositories listed in renv.lock
RUN Rscript -e " \
  library(jsonlite); \
  lockfile <- fromJSON('renv.lock'); \
  github_packages <- lockfile[['Packages']][sapply(lockfile[['Packages']], function(pkg) pkg[['Source']] == 'GitHub')]; \
  github_urls <- sapply(github_packages, function(pkg) pkg[['RemoteUrl']]); \
  dir.create('/workspace/renv/sources', recursive = TRUE); \
  for (repo in github_urls) { \
    repo_name <- basename(repo); \
    system(sprintf('git clone %s /workspace/renv/sources/%s', repo, repo_name)); \
  }"

# Restore the R environment using renv
RUN R -e "Sys.setenv(GITHUB_PAT = Sys.getenv('GITHUB_PAT')); tryCatch(renv::restore(), error = function(e) { Sys.sleep(10); renv::restore() })"

# Inspect if the renv folder is created after restore
RUN ls -l /workspace/renv

# Clean up sensitive environment variables
RUN unset GITHUB_PAT

# By not setting an ENTRYPOINT, this Docker container is now ready to run any R script or RMarkdown file downstream.
