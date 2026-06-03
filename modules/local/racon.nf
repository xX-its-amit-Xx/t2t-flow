process RACON {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::racon=1.5.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/racon:1.5.0--h21ec9f0_2' :
        'biocontainers/racon:1.5.0--h21ec9f0_2' }"

    input:
    tuple val(meta), path(reads), path(paf), path(assembly)

    output:
    tuple val(meta), path("*.racon.fasta"), emit: polished
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    racon \\
        $args \\
        -t $task.cpus \\
        $reads \\
        $paf \\
        $assembly \\
        > ${prefix}.racon.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        racon: \$(echo \$(racon --version 2>&1) | sed 's/^v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.racon.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        racon: 1.5.0
    END_VERSIONS
    """
}
