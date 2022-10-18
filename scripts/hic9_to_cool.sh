#!/usr/bin/env bash

# Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

set -e
set -u
set -o pipefail

argc=$#

if [ $argc -lt 5 ]; then
>&2 echo "Usage:   $0 chrom_sizes path_to_straw_bin path_to_input_hic bin_size path_to_output_mcool chromosomes_to_extract..."
>&2 echo "Example: $0 bin/straw hg38.chrom.sizes input.hic 200 output.mcool chr10 chr11 chr20"
exit 1
fi

straw_bin="$1"
chrom_sizes="$2"
hic_file="$3"
bin_size="$4"
output_mcool="$5"
# shellcheck disable=SC2206
chroms=(${@:6})

tmp_cool="${output_mcool%.mcool}.cool"
zstd_wrapper="$(mktemp "${TMPDIR-/tmp}/zstd_wrapper.XXXXXX.sh")"

# shellcheck disable=SC2064
trap "rm -rf '$zstd_wrapper'" EXIT

printf '#!/usr/bin/env bash\n; if [[ $# == 0 ]]; then zstd --adapt -T0; else zstd -d; fi' >> "$zstd_wrapper"
chmod 755 "$zstd_wrapper"

for chrom in "${chroms[@]}"; do
"$straw_bin" observed NONE "$hic_file" "$chrom" "$chrom" BP "$bin_size" |
  sort -k1,1n -k2,2n -S 80% -T "${TMPDIR-/tmp}" --compress-program="$zstd_wrapper" --parallel $(nproc) |
  awk -F $'\t' -v chrom="$chrom"       \
               -v bin_size="$bin_size" \
        'BEGIN {OFS=FS} $2 >= $1{ print chrom,$1,$1+bin_size,chrom,$2,$2+bin_size,$3}'
done |
cooler load -f bg2 --assembly hg38 --input-copy-status unique <(cooler makebins "$chrom_sizes" "$bin_size") - "$tmp_cool"

cooler zoomify -r N --balance --balance-args="-p $(nproc) --cis-only --max-iters 300" -p $(nproc) -o "$output_mcool" "$tmp_cool"

rm -f "$tmp_cool"