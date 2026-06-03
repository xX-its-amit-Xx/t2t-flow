process GENOMESCOPE2 {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::genomescope2=2.0.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/genomescope2:2.0.1--py310r43hdfd78af_5' :
        'biocontainers/genomescope2:2.0.1--py310r43hdfd78af_5' }"

    input:
    tuple val(meta), path(hist)
    val kmer
    val ploidy

    output:
    tuple val(meta), path("*_summary.txt"), emit: summary
    tuple val(meta), path("*_model.txt")  , emit: model
    tuple val(meta), path("*.png")         , emit: plots
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    genomescope2 \\
        --input $hist \\
        --output ${prefix} \\
        --kmer_length $kmer \\
        --ploidy $ploidy \\
        --name_prefix ${prefix} \\
        $args

    # Surface the GenomeScope outputs from the output directory into the work dir
    cp ${prefix}/${prefix}_summary.txt ${prefix}_summary.txt
    cp ${prefix}/${prefix}_model.txt   ${prefix}_model.txt
    cp ${prefix}/*.png                 .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        genomescope2: \$(genomescope2 --version 2>&1 | sed 's/GenomeScope //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_summary.txt
    touch ${prefix}_model.txt
    touch ${prefix}_linear_plot.png
    touch ${prefix}_log_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        genomescope2: 2.0.1
    END_VERSIONS
    """
}
