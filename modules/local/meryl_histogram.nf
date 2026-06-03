process MERYL_HISTOGRAM {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::meryl=1.4.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/meryl:1.4.1--h4ac6f70_0' :
        'biocontainers/meryl:1.4.1--h4ac6f70_0' }"

    input:
    tuple val(meta), path(meryl_db)

    output:
    tuple val(meta), path("*.hist"), emit: hist
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    meryl \\
        histogram \\
        threads=$task.cpus \\
        $args \\
        $meryl_db > ${prefix}.hist

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meryl: \$(meryl --version 2>&1 | sed 's/meryl //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.hist

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meryl: 1.4.1
    END_VERSIONS
    """
}
