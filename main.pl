#!/usr/bin/perl

use strict;
use warnings;

use File::Path;
use Cwd;
use Sys::Hostname;
use Template;

my $blocksizes = ["4k"];    #, "8k", "16k", ];
my $jobs       = [1];       # .. 16 ];
my $rw_mixes   = [10];      #, 20, 30, 40, 50, 60, 70, 80, 90 ];

my $base_dir = getcwd;
mkpath("$base_dir/bench");
mkpath("$base_dir/result");
mkpath("$base_dir/fio_files");

my $tt = Template->new( ABSOLUTE => 1, );

for my $blocksize (@$blocksizes) {
    for my $job_count (@$jobs) {
        for my $rw_mix (@$rw_mixes) {

            my $fio_file =
                hostname
              . "_${blocksize}bs"
              . "_${job_count}jobs"
              . "_${rw_mix}rw";
            my $data = {
                name  => $fio_file,
                size  => '1G',
                bs    => $blocksize,
                rwmix => $rw_mix,
                jobs  => $job_count,
            };

            $tt->process( "$base_dir/template.fio.tt", $data,
                "$base_dir/fio_files/$fio_file",
            ) or die $!;

            my $result = "./result/$fio_file.json";
            my $command =
              "fio fio_files/$fio_file --output=$result --output-format=json";

            system($command) == 0 or die $!;
            system("rm ./bench/*") == 0 or die $!;
        }
    }
}
