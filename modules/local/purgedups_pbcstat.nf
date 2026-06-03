process PURGEDUPS_PBCSTAT {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::purge_dups=1.2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/purge_dups:1.2.6--h577a1d6_3' :
        'biocontainers/purge_dups:1.2.6--h577a1d6_3' }"

    input:
    tuple val(meta), path(paf)

    output:
    tuple val(meta), path("PB.stat")    , emit: stat
    tuple val(meta), path("PB.base.cov"), emit: basecov
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    pbcstat \\
        $args \\
        $paf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: \$(purge_dups -h 2>&1 | grep -i version | sed 's/.*Version: //I' | head -n1)
    END_VERSIONS
    """

    stub:
    """
    touch PB.stat
    touch PB.base.cov

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: 1.2.6
    END_VERSIONS
    """
}
