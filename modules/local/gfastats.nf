process GFASTATS {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::gfastats=1.3.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gfastats:1.3.6--hdcf5f25_3' :
        'biocontainers/gfastats:1.3.6--hdcf5f25_3' }"

    input:
    tuple val(meta), path(assembly)
    val genome_size

    output:
    tuple val(meta), path("*.gfastats.txt"), emit: stats
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // genome_size may be an empty string -> only pass it when provided
    def gsize = genome_size ? "$genome_size" : ''
    """
    gfastats \\
        $assembly \\
        $gsize \\
        $args \\
        > ${prefix}.gfastats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gfastats: \$(gfastats --version | sed 's/^gfastats v//g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.gfastats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gfastats: 1.3.6
    END_VERSIONS
    """
}
