//
// INPUT_CHECK: parse the input samplesheet and emit typed read channels.
//
// Prefers nf-schema's samplesheetToList (validates against the JSON schema in
// assets/samplesheet_schema.json). Falls back to a plain splitCsv parser if the
// plugin import is unavailable so the subworkflow stays robust.
//

include { samplesheetToList } from 'plugin/nf-schema'

workflow INPUT_CHECK {

    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:

    ch_versions = Channel.empty()

    //
    // Build a channel of parsed rows. Each row becomes a Groovy map keyed by the
    // samplesheet column headers (sample, hifi, ont, hic_1, hic_2, ...).
    //
    def schema_file = file("${projectDir}/assets/samplesheet_schema.json")

    ch_rows = Channel
        .fromList( samplesheetToList(samplesheet, schema_file) )
        .map { row -> normalise_row(row) }

    //
    // HiFi reads: rows that declare a hifi path.
    //
    ch_hifi = ch_rows
        .filter { it.hifi }
        .map { row -> tuple( [ id: row.sample ], file(row.hifi, checkIfExists: true) ) }

    //
    // ONT (ultra-long) reads: rows that declare an ont path.
    //
    ch_ont = ch_rows
        .filter { it.ont }
        .map { row -> tuple( [ id: row.sample ], file(row.ont, checkIfExists: true) ) }

    //
    // Hi-C reads: rows that declare BOTH hic_1 and hic_2 (paired-end).
    //
    ch_hic = ch_rows
        .filter { it.hic_1 && it.hic_2 }
        .map { row ->
            tuple(
                [ id: row.sample ],
                [ file(row.hic_1, checkIfExists: true), file(row.hic_2, checkIfExists: true) ]
            )
        }

    emit:
    hifi     = ch_hifi     // channel: [ val(meta), path(hifi) ]
    ont      = ch_ont      // channel: [ val(meta), path(ont) ]
    hic      = ch_hic      // channel: [ val(meta), [ path(hic_1), path(hic_2) ] ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}

//
// Normalise a parsed samplesheet row to a uniform map. samplesheetToList may
// return either a List (positional, when schema items are tuples) or a Map
// (keyed by column header). Handle both, and coerce empty strings to null.
//
def normalise_row(row) {
    def m
    if (row instanceof Map) {
        m = row
    }
    else if (row instanceof List) {
        // Positional fallback: sample, hifi, ont, hic_1, hic_2
        m = [
            sample: row.size() > 0 ? row[0] : null,
            hifi  : row.size() > 1 ? row[1] : null,
            ont   : row.size() > 2 ? row[2] : null,
            hic_1  : row.size() > 3 ? row[3] : null,
            hic_2  : row.size() > 4 ? row[4] : null,
        ]
    }
    else {
        m = [ sample: row ]
    }
    // Coerce empty / placeholder values to null so downstream filters work.
    def clean = { v -> (v == null || v == '' || v == 'NA' || v == '.') ? null : v }
    return [
        sample: m.sample,
        hifi  : clean(m.hifi),
        ont   : clean(m.ont),
        hic_1  : clean(m.hic_1),
        hic_2  : clean(m.hic_2),
    ]
}
