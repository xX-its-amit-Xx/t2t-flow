process PURGEDUPS_PURGEDUPS {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::purge_dups=1.2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/purge_dups:1.2.6--h7132678_2' :
        'biocontainers/purge_dups:1.2.6--h7132678_2' }"

    input:
    tuple val(meta), path(basecov), path(cutoff), path(self_paf)

    output:
    tuple val(meta), path("*.dups.bed")     , emit: bed
    tuple val(meta), path("*.purgedups.log"), emit: log
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    purge_dups \\
        $args \\
        -2 \\
        -T $cutoff \\
        -c $basecov \\
        $self_paf \\
        > ${prefix}.dups.bed \\
        2> ${prefix}.purgedups.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: \$(purge_dups -h 2>&1 | grep -i version | sed 's/.*Version: //I' | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.dups.bed
    touch ${prefix}.purgedups.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: 1.2.6
    END_VERSIONS
    """
}
