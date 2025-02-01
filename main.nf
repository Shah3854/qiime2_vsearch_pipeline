#!/usr/bin/env nextflow

// Define parameters with defaults
params {
    manifest = null  // Required
    outputDir = "output"
    silva_seqs = null  // Required
    classifier = null  // Required
    metadata = null  // Required
    threads = 18
}

// Parameter validation
def required_params = ['manifest', 'silva_seqs', 'classifier', 'metadata']
for (param in required_params) {
    if (params[param] == null) {
        error "Parameter '${param}' is required but missing"
    }
}

// Print pipeline info
log.info """
         QIIME2 VSEARCH PIPELINE    
         =====================
         Input Parameters:
         ----------------
         Manifest: ${params.manifest}
         Silva Sequences: ${params.silva_seqs}
         Classifier: ${params.classifier}
         Metadata: ${params.metadata}
         Output directory: ${params.outputDir}
         Threads: ${params.threads}
         """

// Process definitions
process import_sequences {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/import_sequences", mode: 'copy'
    
    input:
    path manifest
    
    output:
    path "paired-end-demux.qza"

    script:
    """
    qiime tools import \
      --type 'SampleData[PairedEndSequencesWithQuality]' \
      --input-path $manifest \
      --output-path paired-end-demux.qza \
      --input-format PairedEndFastqManifestPhred33V2
    """
}

process merge_pairs {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/merge_pairs", mode: 'copy'
    
    input:
    path demux_qza

    output:
    path "merged-paired-end-demux.qza"
    path "unmerged-paired-end-demux.qza"

    script:
    """
    qiime vsearch merge-pairs \
      --i-demultiplexed-seqs $demux_qza \
      --o-merged-sequences merged-paired-end-demux.qza \
      --o-unmerged-sequences unmerged-paired-end-demux.qza \
      --p-threads ${params.threads}
    """
}

process quality_filter {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/quality_filter", mode: 'copy'
    
    input:
    path merged_qza

    output:
    path "demux-filtered.qza"
    path "demux-filter-stats.qza"

    script:
    """
    qiime quality-filter q-score \
      --i-demux $merged_qza \
      --o-filtered-sequences demux-filtered.qza \
      --o-filter-stats demux-filter-stats.qza
    """
}

process dereplicate_sequences {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/dereplicate_sequences", mode: 'copy'
    
    input:
    path filtered_qza

    output:
    path "dereplicated_table.qza"
    path "dereplicated_feature_data.qza"

    script:
    """
    qiime vsearch dereplicate-sequences \
      --i-sequences $filtered_qza \
      --o-dereplicated-table dereplicated_table.qza \
      --o-dereplicated-sequences dereplicated_feature_data.qza
    """
}

process cluster_features {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/cluster_features", mode: 'copy'
    
    input:
    path derep_seqs
    path derep_table
    path silva_seqs

    output:
    path "clustered_table.qza"
    path "clustered_sequences.qza"
    path "new_reference_seqs.qza"

    script:
    """
    qiime vsearch cluster-features-open-reference \
      --i-sequences $derep_seqs \
      --i-table $derep_table \
      --i-reference-sequences $silva_seqs \
      --p-perc-identity 0.97 \
      --p-threads ${params.threads} \
      --o-clustered-table clustered_table.qza \
      --o-clustered-sequences clustered_sequences.qza \
      --o-new-reference-sequences new_reference_seqs.qza
    """
}

process chimera_check {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/chimera_check", mode: 'copy'
    
    input:
    path clustered_table
    path clustered_seqs

    output:
    path "chimeras.qza"
    path "nonchimeric_seqs.qza"
    path "chimera_stats.qza"

    script:
    """
    qiime vsearch uchime-denovo \
      --i-table $clustered_table \
      --i-sequences $clustered_seqs \
      --o-chimeras chimeras.qza \
      --o-nonchimeras nonchimeric_seqs.qza \
      --o-stats chimera_stats.qza
    """
}

process filter_chimeras {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/filter_chimeras", mode: 'copy'
    
    input:
    path clustered_table
    path nonchimeric_seqs

    output:
    path "filtered_table.qza"

    script:
    """
    qiime feature-table filter-features \
      --i-table $clustered_table \
      --m-metadata-file $nonchimeric_seqs \
      --o-filtered-table filtered_table.qza
    """
}

process filter_low_freq {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/filter_low_freq", mode: 'copy'
    
    input:
    path filtered_table

    output:
    path "final_table.qza"

    script:
    """
    qiime feature-table filter-features \
      --i-table $filtered_table \
      --p-min-frequency 10 \
      --o-filtered-table final_table.qza
    """
}

process classify_taxonomy {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/classify_taxonomy", mode: 'copy'
    
    input:
    path nonchimeric_seqs
    path classifier

    output:
    path "taxonomy.qza"

    script:
    """
    qiime feature-classifier classify-sklearn \
      --i-classifier $classifier \
      --i-reads $nonchimeric_seqs \
      --o-classification taxonomy.qza
    """
}

process taxa_barplot {
    container 'quay.io/qiime2/amplicon:2024.10'
    publishDir "${params.outputDir}/visualization", mode: 'copy'
    
    input:
    path table
    path taxonomy
    path metadata

    output:
    path "taxa-bar-plots.qzv"

    script:
    """
    qiime taxa barplot \
      --i-table $table \
      --i-taxonomy $taxonomy \
      --m-metadata-file $metadata \
      --o-visualization taxa-bar-plots.qzv
    """
}

// Workflow
workflow {
    // Channel creation
    ch_manifest = Channel.fromPath(params.manifest)
    ch_silva_seqs = Channel.fromPath(params.silva_seqs)
    ch_classifier = Channel.fromPath(params.classifier)
    ch_metadata = Channel.fromPath(params.metadata)

    // Workflow execution
    import_sequences(ch_manifest)
    merge_pairs(import_sequences.out)
    quality_filter(merge_pairs.out[0])
    dereplicate_sequences(quality_filter.out[0])
    
    cluster_features(
        dereplicate_sequences.out[1],
        dereplicate_sequences.out[0],
        ch_silva_seqs
    )
    
    chimera_check(
        cluster_features.out[0],
        cluster_features.out[1]
    )
    
    filter_chimeras(
        cluster_features.out[0],
        chimera_check.out[1]
    )
    
    filter_low_freq(filter_chimeras.out)
    
    classify_taxonomy(
        chimera_check.out[1],
        ch_classifier
    )

    taxa_barplot(
        filter_low_freq.out,
        classify_taxonomy.out,
        ch_metadata
    )
}
