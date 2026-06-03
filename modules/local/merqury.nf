process MERQURY {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::merqury=1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/merqury:1.3--hdfd78af_3' :
        'biocontainers/merqury:1.3--hdfd78af_3' }"

    input:
    tuple val(meta), path(meryl_db), path(assembly)

    output:
    tuple val(meta), path("*.qv")                  , emit: qv
    tuple val(meta), path("*.completeness.stats")  , emit: completeness
    tuple val(meta), path("*.spectra-cn.*.png")    , emit: spectra_cn_png , optional: true
    tuple val(meta), path("*.spectra-asm.*.png")   , emit: spectra_asm_png, optional: true
    tuple val(meta), path("*.hist")                , emit: hist           , optional: true
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    merqury.sh \\
        $meryl_db \\
        $assembly \\
        $prefix

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        merqury: \$(echo \$MERQURY | sed 's/.*merqury//; s/[^0-9.].*\$//' || echo 1.3)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.qv
    touch ${prefix}.completeness.stats
    touch ${prefix}.spectra-cn.fl.png
    touch ${prefix}.spectra-asm.fl.png
    touch ${prefix}.hist

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        merqury: 1.3
    END_VERSIONS
    """
}
