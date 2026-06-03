process MINIMAP2_ALIGN {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::minimap2=2.28"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--h577a1d6_4' :
        'biocontainers/minimap2:2.28--h577a1d6_4' }"

    input:
    tuple val(meta), path(reads)
    // Stage the reference in its own subdir so a self-alignment (purge_dups, where
    // query == target) does not trigger an input file-name collision.
    tuple val(meta2), path(reference, stageAs: 'reference/*')
    val bam_format
    val preset

    output:
    tuple val(meta), path("*.paf"), emit: paf, optional: true
    tuple val(meta), path("*.bam"), emit: bam, optional: true
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // samtools is NOT in the minimap2 image. For bam_format we emit minimap2's
    // own uncompressed/SAM-style BAM via `-a` redirected to a .bam file; the PAF
    // path (bam_format=false) is the primary mode used by purge_dups.
    def output_cmd = bam_format ?
        "-a -o ${prefix}.bam" :
        "-o ${prefix}.paf"
    """
    minimap2 \\
        -t $task.cpus \\
        -x $preset \\
        $args \\
        $output_cmd \\
        $reference \\
        $reads

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_file = bam_format ? "${prefix}.bam" : "${prefix}.paf"
    """
    touch ${output_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: 2.28
    END_VERSIONS
    """
}
