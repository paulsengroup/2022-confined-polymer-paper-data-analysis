#!/usr/bin/env nextflow
// Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    generate_chrom_sizes(Channel.of(params.grch38_assembly_name_short,
    							    params.mgscv37_assembly_name_short),
						 Channel.of(file(params.grch38_assembly_report),
						            file(params.mgscv37_assembly_report)))

	chrom_sizes = \
	    generate_chrom_sizes.out.chrom_sizes
                            .branch {
                                  grch38: it =~ /^.*${params.grch38_assembly_name_short}.chrom.sizes$/
                                  mgscv37: it =~ /^.*${params.mgscv37_assembly_name_short}.chrom.sizes$/
                            }

    convert_hic_to_cool(chrom_sizes.grch38.first(),
                        Channel.fromPath(params.hic_files),
                        params.grch38_bin_size)

    convert_geo_txt_to_cool(chrom_sizes.mgscv37,
                            Channel.fromPath(file(params.txt_matrix_files)),
                            "mm9",
                            params.mgscv37_bin_size)
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
        path "*.mcool", emit: mcool

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

process convert_geo_txt_to_cool {
    publishDir "${params.output_dir}", mode: 'copy'

    label 'process_medium'

    input:
        path chrom_sizes
        path matrix_txt
        val assembly_name
        val bin_size

    output:
        path "*.mcool", emit: mcool

    shell:
        out = "${matrix_txt.baseName}.mcool"
        '''
        set -o pipefail

		zcat '!{matrix_txt}' |
		'!{params.script_dir}/geo_txt_matrix_to_bedpe.py' |
        cooler load -f bg2 \
        		    --count-as-float \
        		    --assembly='!{assembly_name}' \
        		    '!{chrom_sizes}:!{bin_size}' \
					- out.cool

		cooler zoomify -p '!{task.cpus}' -r N -o '!{out}' out.cool
        '''
}