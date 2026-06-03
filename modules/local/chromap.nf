process CHROMAP {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::chromap=0.2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chromap:0.2.6--hdcf5f25_1' :
        'biocontainers/chromap:0.2.6--hdcf5f25_1' }"

    input:
    tuple val(meta), path(reads1), path(reads2)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(index)

    output:
    tuple val(meta), path("*.sam"), emit: sam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    chromap \\
        --preset hic \\
        $args \\
        -x $index \\
        -r $fasta \\
        -1 $reads1 \\
        -2 $reads2 \\
        -t $task.cpus \\
        --SAM \\
        -o ${prefix}.sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chromap: \$(echo \$(chromap --version 2>&1))
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chromap: 0.2.6
    END_VERSIONS
    """
}
