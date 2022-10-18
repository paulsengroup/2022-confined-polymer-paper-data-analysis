#!/usr/bin/env nextflow
// Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    // Group files by prefix (i.e. by assembly)
    mcools = Channel.fromPath(params.mcools)
                    .map { tuple(it.getName().replaceAll(/^(.+?)_.*/, '$1'), it) }
                    .groupTuple()
	compute_contact_histogram(mcools,
							  params.bin_size)
}

process compute_contact_histogram {
    publishDir "${params.output_dir}", mode: 'copy'

    label 'process_short'

    input:
        tuple val(prefix), path(matrices)
        val resolution

    output:
        path "*.tsv", emit: tsv

    shell:
        '''
        set -o pipefail
        set -u

		if [ !{resolution} -eq 0 ]; then
        	coolers=(!{matrices})
        else
        	coolers=()
        	for m in !{matrices}; do
				if [ !{resolution} -ne 0 ]; then
					coolers+=("$m::/resolutions/!{resolution}")
				fi
        	done
        fi

        labels=()
		for m in !{matrices}; do
			labels+=("$(basename "$m")")
		done

		'!{params.script_dir}/compute_contact_hist_contour_len.py' \
			"${coolers[@]}" \
			--labels "${labels[@]}" |
			tee '!{prefix}_contact_histogram_by_contour_length.tsv' > /dev/null
        '''
}
