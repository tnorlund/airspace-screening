# Setup

This script sets up the python library used in the lambda layer.

# How to Run
In this directory, run the bash script.
```bash
% bash setup.sh
```

# What It Does
1. Downloads the python packages from PYPI
2. Unpacks the '.whl' into their respective packages
3. Creates the necessary file structure for the Lambda Layer
4. Moves the packages into the file structure
5. Builds the local library
6. Moves the local library to the file structure
7. Zips the file structure
8. Cleans the environment