process NANOPLOT {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::nanoplot=1.42.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoplot:1.42.0--pyhdfd78af_0' :
        'biocontainers/nanoplot:1.42.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html")         , emit: html
    tuple val(meta), path("*.png")          , emit: png  , optional: true
    tuple val(meta), path("*NanoStats.txt") , emit: txt
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // NanoPlot autodetects fastq/fasta/bam; pass reads via --fastq for long-read inputs
    """
    NanoPlot \\
        $args \\
        -t $task.cpus \\
        --prefix ${prefix}_ \\
        --fastq $reads

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version | sed -e 's/NanoPlot //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_NanoPlot-report.html
    touch ${prefix}_LengthvsQualityScatterPlot_dot.png
    touch ${prefix}_NanoStats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: 1.42.0
    END_VERSIONS
    """
}
