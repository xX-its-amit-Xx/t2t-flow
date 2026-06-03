process FLYE {
    tag "$meta.id"
    label 'process_high_memory'

    conda "bioconda::flye=2.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flye:2.9.5--py311h2de2dd3_2' :
        'biocontainers/flye:2.9.5--py311h2de2dd3_2' }"

    input:
    tuple val(meta), path(reads)
    val mode

    output:
    tuple val(meta), path("*.assembly.fasta")     , emit: assembly
    tuple val(meta), path("*.assembly_graph.gfa") , emit: gfa
    tuple val(meta), path("*.assembly_graph.gv")  , emit: gv
    tuple val(meta), path("*.assembly_info.txt")  , emit: txt
    tuple val(meta), path("*.flye.log")           , emit: log
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    flye \\
        $mode \\
        $reads \\
        --out-dir ${prefix}_flye \\
        --threads $task.cpus \\
        $args

    # Rename Flye's fixed output names to the sample prefix
    mv ${prefix}_flye/assembly.fasta       ${prefix}.assembly.fasta
    mv ${prefix}_flye/assembly_graph.gfa   ${prefix}.assembly_graph.gfa
    mv ${prefix}_flye/assembly_graph.gv    ${prefix}.assembly_graph.gv
    mv ${prefix}_flye/assembly_info.txt    ${prefix}.assembly_info.txt
    mv ${prefix}_flye/flye.log             ${prefix}.flye.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flye: \$(flye --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.assembly.fasta
    touch ${prefix}.assembly_graph.gfa
    touch ${prefix}.assembly_graph.gv
    touch ${prefix}.assembly_info.txt
    touch ${prefix}.flye.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flye: 2.9.5
    END_VERSIONS
    """
}
