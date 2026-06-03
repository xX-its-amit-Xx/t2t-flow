process QUAST {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::quast=5.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quast:5.2.0--py310pl5321hc8f18ef_3' :
        'biocontainers/quast:5.2.0--py310pl5321hc8f18ef_3' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${meta.id}_quast")            , emit: results
    tuple val(meta), path("${meta.id}_quast/report.tsv") , emit: tsv
    tuple val(meta), path("${meta.id}_quast/report.html"), emit: html
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    quast.py \\
        $args \\
        --threads $task.cpus \\
        -o ${prefix}_quast \\
        $assembly

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_quast
    touch ${prefix}_quast/report.tsv
    touch ${prefix}_quast/report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: 5.2.0
    END_VERSIONS
    """
}
