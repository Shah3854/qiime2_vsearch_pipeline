# Qiime2_Vsearch_Pipeline

A Nextflow pipeline for 16S rRNA gene sequencing analysis using QIIME2 2024.10 and VSEARCH.

## Pipeline Overview

This pipeline performs the following steps:
1. Imports paired-end sequences
2. Merges paired reads
3. Filters sequences based on quality scores
4. Dereplicates sequences
5. Clusters features using VSEARCH
6. Performs chimera detection and filtering
7. Classifies taxonomy
8. Generates taxa bar plots

## Prerequisites

- Docker
- Nextflow (>=23.10.0)
- Input Data:
  - Paired-end sequencing data
  - Manifest file
  - Metadata file
  - SILVA reference sequences
  - Trained classifier

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/Shah3854/qiime2_vsearch_pipeline.git
cd qiime2_vsearch_pipeline
```

2. Pull the QIIME2 Docker image:
```bash
docker pull quay.io/qiime2/amplicon:2024.10
```

3. Build the pipeline Docker image:
```bash
docker build -t qiime2_vsearch-pipeline .
```

4. Run the pipeline:
```bash
nextflow run main.nf \
  --manifest path/to/manifest.tsv \
  --silva_seqs path/to/silva_sequences.qza \
  --classifier path/to/classifier.qza \
  --metadata path/to/metadata.tsv
```

## Input Files

1. Manifest file (TSV format):
```
sample-id,forward-absolute-filepath,reverse-absolute-filepath
sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz
```

2. Metadata file (TSV format):
```
#SampleID	Source
#q2:types	Categorical
Sample1  Sample1
```

## Parameters

- `--manifest`: Path to manifest file (required)
- `--silva_seqs`: Path to SILVA reference sequences (required)
- `--classifier`: Path to trained classifier (required)
- `--metadata`: Path to metadata file (required)
- `--outputDir`: Output directory (default: "output")
- `--threads`: Number of threads (default: 18)

## Output

The pipeline generates a structured output directory containing:
- Imported sequences (QZA format)
- Merged paired-end reads
- Quality filtered sequences
- Dereplicated sequences
- Clustered features
- Chimera detection results
- Taxonomy classifications
- Taxa bar plots (QZV format)
