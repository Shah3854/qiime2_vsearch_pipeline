FROM quay.io/qiime2/amplicon:2024.10

# Install Nextflow
RUN apt-get update && apt-get install -y \
    wget \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && wget -qO- https://get.nextflow.io | bash \
    && mv nextflow /usr/local/bin/

# Set working directory
WORKDIR /pipeline

# Copy pipeline files
COPY . .

# Set default command
CMD ["nextflow", "run", "main.nf"]
