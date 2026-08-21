#!/usr/bin/awk -f
BEGIN {
    nbins = 30
}
{
    data[NR] = $1
    if (NR == 1) {
        min = $1
        max = $1
    } else {
        if ($1 < min) min = $1
        if ($1 > max) max = $1
    }
}
END {
    if (max == min) {
        bin_width = 1
    } else {
        bin_width = (max - min) / nbins
    }
    
    # Count occurrences for each bin
    for (i = 1; i <= NR; i++) {
        bin = int((data[i] - min) / bin_width)
        if (bin >= nbins) bin = nbins - 1  # Ensure max goes in the last bin
        counts[bin]++
    }
    
    # Output each bin with a rounded interval label and count
    for (i = 0; i < nbins; i++) {
        lb = min + i * bin_width
        ub = min + (i + 1) * bin_width
        # Round lb and ub to whole numbers using "%.0f"
        printf "[%.0f,%.0f]\t%d\n", lb, ub, counts[i]+0
    }
}
