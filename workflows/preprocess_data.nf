#!/usr/bin/env nextflow
// Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    generate_chrom_sizes("${params.grch38_assembly_name_short}",
                         file(params.grch38_assembly_report))

    grch38_chrom_sizes = generate_chrom_sizes.out.chrom_sizes
                         .filter { it =~ /^.*${params.grch38_assembly_name_short}.chrom.sizes$/ }
                         .first()

    convert_hic_to_cool(grch38_chrom_sizes,
                        Channel.fromPath(file("${params.hic_files}")),
                        params.bin_size)
}

process generate_chrom_sizes {
    publishDir "${params.output_dir}", mode: 'copy'

    label 'process_short'

    input:
        val assembly_name
        path assembly_report

    output:
        path "${assembly_name}.bed", emit: bed
        path "${assembly_name}.chrom.sizes", emit: chrom_sizes

    shell:
        out_bed = "${assembly_name}.bed"
        out = "${assembly_name}.chrom.sizes"
        '''
         # Extract chromosome sizes from assembly report
         gzip -dc "!{assembly_report}" |
         awk -F $'\t' 'BEGIN { OFS=FS } $2 == "assembled-molecule" { print "chr"$1,0,$9,$7 }' |
         grep -v 'chrMT' | sort -V > "!{out_bed}"

         # Convert chromosome sizes from bed to chrom.sizes format
         cut -f 1,3 "!{out_bed}" | sort -V > "!{out}"
        '''
}

process convert_hic_to_cool {
    publishDir "${params.output_dir}", mode: 'copy'

    label 'process_long'

    input:
        path chrom_sizes
        path hic
        val bin_size

    output:
        path "*.mcool", emit: cool

    shell:
        out = "${hic.baseName}.mcool"
        '''
        chroms="$(cut -f 1 '!{chrom_sizes}' | tr '\\n' ' ')"

        '!{params.script_dir}/hic9_to_cool.sh' \
         				      "$(which straw)" \
                              '!{chrom_sizes}' \
                              '!{hic}'         \
                              '!{bin_size}'    \
                              '!{out}'         \
                              "$chroms"
        '''
}
