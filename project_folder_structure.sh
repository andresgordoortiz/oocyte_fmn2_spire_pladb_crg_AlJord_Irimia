#!/bin/bash


# Create directories
mkdir -p {config/{docker},data/{raw,processed,metadata},notebooks/{exploratory,final,archive},scripts/{R,python,bash},workflows/modules,results/{tables,figures,logs},docs,tests/{data_tests,workflow_tests},.github/workflows, logs}

# Notify completion
echo "Folder structure created successfully."
