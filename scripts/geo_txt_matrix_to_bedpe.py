#!/usr/bin/env python3

# Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import sys


def parse_coord_str(coords, offset = 0):
    chrom, _, pos = coords.partition(":")
    start, _, end = pos.partition("-")

    return f"{chrom}\t{int(start) + offset}\t{int(end) + offset}"


if __name__ == "__main__":
    header = None
    i = 0
    for line in sys.stdin:
        line = line.rstrip()
        if line.startswith("#"):
            continue

        if header is None:
            header = tuple([parse_coord_str(tok.split("|")[-1], -1) for tok in line.split("\t")[1:]])
            continue

        coord1 = line.partition("\t")[0].split("|")[-1]
        coord1 = parse_coord_str(coord1, -1)

        for coord2, tok in zip(header[i:], line.split("\t")[i+1:]):
            if tok != "NULL" and tok != "0.0":
                print(f"{coord1}\t{coord2}\t{float(tok)}")

        i += 1
