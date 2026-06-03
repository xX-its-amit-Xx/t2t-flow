process SEQKIT_STATS {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::seqkit=2.8.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.8.2--h9ee0642_1' :
        'biocontainers/seqkit:2.8.2--h9ee0642_1' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.seqkit-stats.tsv"), emit: stats
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit stats -T -a $args $reads > ${prefix}.seqkit-stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version | sed 's/seqkit v//g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.seqkit-stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: 2.8.2
    END_VERSIONS
    """
}
