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

# Install renv
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org')"

# Pre-clone the betAS repository
RUN git clone --branch v1.2.1 https://github.com/DiseaseTranscriptomicsLab/betAS.git /workspace/renv/sources/betAS

# Set the renv source directory to check local sources
RUN R -e "renv::settings$sources('/workspace/renv/sources')"

# Restore the R environment using renv
RUN R -e "Sys.setenv(GITHUB_PAT = Sys.getenv('GITHUB_PAT')); tryCatch(renv::restore(), error = function(e) { Sys.sleep(10); renv::restore() })"

# Inspect if the renv folder is created after restore
RUN ls -l /workspace/renv

# Clean up sensitive environment variables
RUN unset GITHUB_PAT

# By not setting an ENTRYPOINT, this Docker container is now ready to run any R script or RMarkdown file downstream.
