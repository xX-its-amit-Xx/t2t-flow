process MULTIQC {
    label 'process_single'

    conda "bioconda::multiqc=1.25.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.25.1--pyhdfd78af_0' :
        'biocontainers/multiqc:1.25.1--pyhdfd78af_0' }"

    input:
    path multiqc_files, stageAs: "?/*"
    path(multiqc_config)
    path(logo)

    output:
    path "*multiqc_report.html", emit: report
    path "multiqc_data"        , emit: data
    path "multiqc_plots"       , emit: plots, optional: true
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def config = multiqc_config ? "--config $multiqc_config" : ''
    def logo_arg = logo ? "--cl-config 'custom_logo: \"${logo}\"'" : ''
    """
    multiqc \\
        --force \\
        $args \\
        $config \\
        $logo_arg \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(multiqc --version | sed 's/multiqc, version //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p multiqc_data
    mkdir -p multiqc_plots
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: 1.25.1
    END_VERSIONS
    """
}
