#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;

my @images = glob("./images/*");

open my $fh, '>>', "images.markdown";

for my $image (@images) {
    $image = basename($image);
    print $fh "$image\n";
    print $fh
"![moep] (https://raw.github.com/adeven/benchmarks/master/images/$image \"$image\")\n";
}

