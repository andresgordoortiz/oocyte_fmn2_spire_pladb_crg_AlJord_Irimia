# Use a base R image
FROM rocker/r-ver:4.3.1

# Install system dependencies for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev \
    pandoc \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV RENV_VERSION=0.17.3
ENV R_LIBS_USER=/renv/library

# Copy renv.lock and other files to the container
WORKDIR /workspace
COPY . /workspace

# Install renv
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org')"

# Set up GitHub authentication for private repos
ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      git config --global url."https://${GITHUB_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"; \
    fi

# Restore R packages from renv.lock with retry logic
RUN R -e "tryCatch(renv::restore(), error = function(e) { Sys.sleep(10); renv::restore() })"

# Default command to allow specifying the RMarkdown file at runtime
ENTRYPOINT ["Rscript", "-e", "rmarkdown::render(commandArgs(trailingOnly = TRUE)[1], output_format = 'html_document')"]
