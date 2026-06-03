process SALSA2 {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::salsa2=2.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/salsa2:2.3--py27hee570cb_4' :
        'biocontainers/salsa2:2.3--py27hee570cb_4' }"

    input:
    tuple val(meta), path(assembly), path(fai), path(hic_bed)
    val enzyme

    output:
    tuple val(meta), path("*scaffolds_FINAL.fasta"), emit: scaffolds_fasta
    tuple val(meta), path("*scaffolds_FINAL.agp")  , emit: scaffolds_agp
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def enzyme_arg = enzyme ? "-e ${enzyme}" : ''
    """
    run_pipeline.py \\
        $args \\
        -a $assembly \\
        -l $fai \\
        -b $hic_bed \\
        $enzyme_arg \\
        -o ${prefix}_salsa

    # Surface the final scaffolds with the expected glob at the top level
    cp ${prefix}_salsa/scaffolds_FINAL.fasta ${prefix}.scaffolds_FINAL.fasta
    cp ${prefix}_salsa/scaffolds_FINAL.agp   ${prefix}.scaffolds_FINAL.agp

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        salsa2: 2.3
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.scaffolds_FINAL.fasta
    touch ${prefix}.scaffolds_FINAL.agp

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        salsa2: 2.3
    END_VERSIONS
    """
}
