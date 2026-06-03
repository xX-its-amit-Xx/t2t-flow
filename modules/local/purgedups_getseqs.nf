process PURGEDUPS_GETSEQS {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::purge_dups=1.2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/purge_dups:1.2.6--h577a1d6_3' :
        'biocontainers/purge_dups:1.2.6--h577a1d6_3' }"

    input:
    tuple val(meta), path(assembly), path(bed)

    output:
    tuple val(meta), path("*.purged.fa"), emit: purged
    tuple val(meta), path("*.hap.fa")   , emit: haplotigs
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    get_seqs \\
        $args \\
        -e \\
        -p ${prefix} \\
        $bed \\
        $assembly

    # get_seqs writes <prefix>.purged.fa and <prefix>.hap.fa
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: \$(purge_dups -h 2>&1 | grep -i version | sed 's/.*Version: //I' | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.purged.fa
    touch ${prefix}.hap.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: 1.2.6
    END_VERSIONS
    """
}
