process KRAKENTOOLS_EXTRACT {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::krakentools=1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/krakentools:1.2--pyh7e72e81_1' :
        'biocontainers/krakentools:1.2--pyh7e72e81_1' }"

    input:
    tuple val(meta), path(reads), path(kraken_assignment), path(kraken_report)
    val   taxids
    val   exclude

    output:
    tuple val(meta), path("*.fastq.gz"), emit: extracted_reads
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // exclude=true -> remove the listed contaminant taxids (keep everything else)
    def exclude_flag = exclude ? "--exclude" : ""
    def taxid_list   = taxids.toString().replaceAll(',', ' ')
    """
    extract_kraken_reads.py \\
        -k $kraken_assignment \\
        -r $kraken_report \\
        -s $reads \\
        -o ${prefix}.extracted.fastq \\
        --taxid $taxid_list \\
        --include-children \\
        $exclude_flag \\
        --fastq-output \\
        $args

    gzip --no-name ${prefix}.extracted.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        krakentools: \$(extract_kraken_reads.py --version 2>&1 | sed 's/^.*KrakenTools //; s/ .*\$//' || echo 1.2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip --no-name > ${prefix}.extracted.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        krakentools: 1.2
    END_VERSIONS
    """
}
