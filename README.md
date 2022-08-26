# suicide-pm
Repository for Zhang, Carleton, Lin, and Zhou (2022) working paper on suicide and air pollution in China.  

## Structure
The `code/` directory contains all scripts used to clean and analyze data, as well as construct tables and figures shown in the paper. Subdirectories include `clean/`, which contains scripts to clean raw data, `analysis/`, which contains scripts that run all regression analyses, and `figures/`, which contains scripts that call outputs from scripts in `analysis/` to format and save figures shown in the main text and supplementary materials.


The `results/` directory contains all analysis results. Subdirectories include `figures/`, which contains all graphical figures, `ster/`, which contains `.ster` files containing STATA regression estimates, and `tables/`, which contains `.tex` files with LaTeX tabular output, as well as `.csv` files containing key summary statistics reported throughout the main text. 

## Data availability
The suicide data we use to estimate our econometric models are confidential. All regression outputs are stored in this repository, but results cannot be directly reproduced without obtaining access to the underlying dataset from the Chinese Center for Disease Control and Prevention (CCDC).
