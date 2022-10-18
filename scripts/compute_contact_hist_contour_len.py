#!/usr/bin/env python3

# Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import cooler
import numpy as np
import argparse
import pandas as pd
from collections import namedtuple
import sys


def make_cli():
    class SplitContourLengths(argparse.Action):
        def __call__(self, parser, namespace, values, option_string=None):
            ContourLengthsT = namedtuple("ContourLengthsT", ["start", "end", "step"])
            setattr(namespace, self.dest, ContourLengthsT(*(int(v) for v in values.split(","))))

    cli = argparse.ArgumentParser()

    cli.add_argument("coolers",
                     help="Path to one or more file in .cool format (URI syntax supported).",
                     nargs="+")
    cli.add_argument("--regions-of-interest",
                     help="BED file with one or more region(s) of interest.")
    cli.add_argument("--contour-lengths", "--cl",
                     action=SplitContourLengths,
                     default=[0, 1000, 1],
                     help="Comma-separated list of start, end and step for the contour lengths used to compute contact probabilities.\n"
                          "Values should be expressed in term of the bin size of the contact matrix given as input.\n"
                          "Example: Given a matrix with binsize=1000, passing --cl='10,50,10' will result in computing the contact"
                          "probabilities for contour lengths of 10000, 20000, 30000, 40000 and 50000.")
    cli.add_argument("--use-balanced",
                     action="store_true",
                     default=False,
                     help="Use balanced contacts.")
    cli.add_argument("--normalize",
                     choices={"none", "relative", "smallest"},
                     default="smallest",
                     help="Contact normalization strategy:\n"
                          " - none: use raw contacts\n"
                          " - relative: normalize each query individualy by dividing pixels by the largest pixel value in the query (i.e. use n1 for cooler #1, n2 for cooler #2 and so on)"
                          " - smallest: normalize each query individually such that each query has the same total number of contacts.")
    cli.add_argument("--labels",
                     nargs="+",
                     type=str,
                     help="Labels to use instead of file names to name columns in the output file.")
    return cli


def normalize(matrices, how):
    assert how in {"none", "relative", "smallest"}
    if how == "none":
        return matrices

    how = str(how).lower()

    if how == "relative":
        return [m / np.max(m) for m in matrices]

    # Same as:
    # https://hicexplorer.readthedocs.io/en/latest/content/tools/hicNormalize.html#normalize-to-smallest-read-count
    tot_contacts = [np.sum(m) for m in matrices]
    smallest_tot_contacts = np.min(tot_contacts)

    if smallest_tot_contacts == 0:
        return [np.zeros_like(m) for m in matrices]

    return [m / (tot / smallest_tot_contacts) for m, tot in zip(matrices, tot_contacts)]
    # for m in matrices:
    #     assert np.allclose(np.sum(m), np.sum(matrices[0]))
    # return matrices


def kth_diag_indices(a, k):
    """
    https://stackoverflow.com/a/18081653
    """
    rows, cols = np.diag_indices_from(a)
    if k < 0:
        return rows[-k:], cols[:k]
    elif k > 0:
        return rows[:-k], cols[k:]
    else:
        return rows, cols


def compute_contact_histogram(matrices, contour_lb, contour_ub, contour_stride):
    for m in matrices:
        assert m.shape == matrices[0].shape
        assert np.alltrue(m >= 0)

    contour_ub = min(contour_ub, matrices[0].shape[0])
    counts = {}
    for contour_len in range(contour_lb, contour_ub, contour_stride):
        rows, cols = kth_diag_indices(matrices[0], contour_len)
        counts[contour_len] = [np.sum(m[rows, cols]) for m in matrices]

    return counts


def get_bin_size(coolers):
    bin_size = coolers[0].binsize
    if len(coolers) == 1:
        return bin_size

    for c in coolers[1:]:
        assert c.binsize == bin_size, "ensure all coolers have the same resolution"

    return bin_size


def fetch_matrix(coolerf, chrom, start, end, balanced):
    query = f"{chrom}:{start}-{end}"
    matrix = coolerf.matrix(balance=balanced).fetch(query)
    return np.triu(np.nan_to_num(matrix))


def import_regions_of_interest(cooler, bed):
    if bed is None:
        chroms = [[name, 0, size] for name, size in zip(cooler.chromnames, cooler.chromsizes)]
        return pd.DataFrame(chroms, columns=["chrom", "start", "end"])

    return pd.read_table(bed, sep="\t", names=["chrom", "start", "end"], usecols=(0, 1, 2))


if __name__ == "__main__":
    args = vars(make_cli().parse_args())
    assert args["labels"] is None or len(args["labels"]) == len(args["coolers"])

    clen_start, clen_end, clen_stride = args["contour_lengths"]

    coolers = {str(file): cooler.Cooler(file) for file in args["coolers"]}
    bin_size = get_bin_size(list(coolers.values()))

    data = []

    for (_, (chrom, start, end)) in import_regions_of_interest(list(coolers.values())[0],
                                                               args["regions_of_interest"]).iterrows():
        matrices = {path: fetch_matrix(c, chrom, start, end, args["use_balanced"]) for path, c in coolers.items()}

        # Normalize matrices
        matrices = {path: m for path, m in
                    zip(matrices.keys(), normalize(matrices.values(), how=args["normalize"]))}

        # Compute histogram
        res = compute_contact_histogram(tuple(matrices.values()), clen_start, clen_end + 1, clen_stride)
        for contour_len, counts in res.items():
            data.append([chrom, start, end, contour_len] + counts)

    columns = ["chrom", "start", "end", "contour_length"]
    if args["labels"] is not None:
        columns += args["labels"]
    else:
        columns += list(coolers.keys())

    pd.DataFrame(data, columns=columns) \
        .to_csv(sys.stdout, sep="\t", index=False, na_rep="nan")
