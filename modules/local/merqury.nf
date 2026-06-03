process MERQURY {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::merqury=1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/merqury:1.3--hdfd78af_4' :
        'biocontainers/merqury:1.3--hdfd78af_4' }"

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
    # merqury.sh sources \$MERQURY/util/util.sh. That env var is set in the docker
    # image and by the bioconda activation, but NOT in the Galaxy-depot singularity
    # image — derive it from merqury.sh's install prefix so every engine works.
    export MERQURY=\${MERQURY:-\$(dirname \$(dirname \$(which merqury.sh)))/share/merqury}

    merqury.sh \\
        $meryl_db \\
        $assembly \\
        $prefix

    # merqury writes an overall "${prefix}.qv" plus a per-assembly "${prefix}.<asm>.qv".
    # Keep only the overall QV so a single value flows downstream (assembly_stats).
    find . -maxdepth 1 -name "*.qv" ! -name "${prefix}.qv" -delete

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        merqury: 1.3
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
