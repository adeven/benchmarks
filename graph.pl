#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Chart::Clicker;
use Chart::Clicker::Context;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Series;
use Geometry::Primitive;
use Graphics::Color::RGB;
use Geometry::Primitive::Circle;

use JSON;

my @files = glob('./result/*');

my $results = [];

for my $file (@files) {
    push( @$results, create_data_object($file) );
}
my $uniq_specs = uniq_specs($results);

write_chart_rwratio( $uniq_specs, $results );
write_chart_job( $uniq_specs, $results );
write_chart_bs( $uniq_specs, $results );

sub read_json {
    my $file = shift;
    open my $fh, '<', $file;
    local $/ = undef;
    my $json = decode_json(<$fh>);
    close($fh);
    $json->{jobs}->[0]->{summed}->{bw} =
      $json->{jobs}->[0]->{read}->{bw} + $json->{jobs}->[0]->{write}->{bw};
    $json->{jobs}->[0]->{summed}->{iops} =
      $json->{jobs}->[0]->{read}->{iops} + $json->{jobs}->[0]->{write}->{iops};

    return $json;
}

sub create_data_object {
    my $file = shift;
    my ( $hostname, $bs, $jobs, $rw_ratio ) = split( '_', basename($file) );
    $bs =~ s/kbs//;
    $jobs =~ s/jobs//;
    $rw_ratio =~ s/rw\.json//;
    return {
        json     => read_json($file),
        hostname => $hostname,
        bs       => $bs,
        jobs     => $jobs,
        rw_ratio => $rw_ratio,
    };
}

sub uniq_specs {
    my $result    = shift;
    my $hostnames = [];
    my $bss       = [];
    my $jobs      = [];
    my $rw_ratios = [];

    for (@$result) {
        push( @$hostnames, $_->{hostname} );
        push( @$bss,       $_->{bs} );
        push( @$jobs,      $_->{jobs} );
        push( @$rw_ratios, $_->{rw_ratio} );
    }

    return {
        hostnames => uniq_array($hostnames),
        bss       => uniq_array($bss),
        jobs      => uniq_array($jobs),
        rw_ratios => uniq_array($rw_ratios),
    };
}

sub uniq_array {
    my $array = shift;
    my %hash = map { $_, 1 } @$array;
    @$array = keys %hash;
    @$array = sort { $a <=> $b } @$array;
    return $array;
}

sub write_chart_bs {
    my $uniq_specs = shift;
    my $results    = shift;
    my $series     = {};
    my $scenarios  = [ 'read', 'write', 'summed' ];
    my $kinds      = [ 'iops', 'bw' ];

    ##fixed rw_ratio fixed job

    for my $kind (@$kinds) {
        for my $scenario (@$scenarios) {
            for my $bs ( @{ $uniq_specs->{bss} } ) {
                for my $entry (@$results) {
                    if ( $entry->{bs} == $bs ) {
                        my $hostname = $entry->{hostname};
                        my $job      = $entry->{jobs};
                        my $rw_ratio = $entry->{rw_ratio};
                        push(
                            @{
                                $series->{$job}->{$rw_ratio}->{$hostname}
                                  ->{$scenario}->{$kind}->{keys}
                            },
                            $bs,
                        );
                        push(
                            @{
                                $series->{$job}->{$rw_ratio}->{$hostname}
                                  ->{$scenario}->{$kind}->{vals}
                            },
                            $entry->{json}->{jobs}->[0]->{$scenario}->{$kind}
                        );
                    }
                }
            }
        }
    }

    for my $kind (@$kinds) {
        for my $scenario (@$scenarios) {
            foreach my $jobs ( keys %{$series} ) {
                foreach my $rw_ratio ( keys %{ $series->{$jobs} } ) {
                    my $charts = [];
                    foreach my $host ( keys %{ $series->{$jobs}->{$rw_ratio} } )
                    {
                        my $serie = Chart::Clicker::Data::Series->new(
                            keys => $series->{$jobs}->{$rw_ratio}->{$host}
                              ->{$scenario}->{$kind}->{keys},
                            values => $series->{$jobs}->{$rw_ratio}->{$host}
                              ->{$scenario}->{$kind}->{vals},
                            name => $host . "_${scenario}_${kind}",
                        );
                        push( @$charts, $serie );
                    }
                    write_series(
                        $charts,    "rw_ratio_$rw_ratio",
                        "job$jobs", "bs_${scenario}_${kind}",
                    );
                }
            }
        }
    }
}

sub write_chart_job {
    my $uniq_specs = shift;
    my $results    = shift;
    my $series     = {};
    my $scenarios  = [ 'read', 'write', 'summed' ];

    ##fixed rw_ratio fixed blocksize

    for my $scenario (@$scenarios) {
        for my $jobs ( @{ $uniq_specs->{jobs} } ) {
            for my $entry (@$results) {
                if ( $entry->{jobs} == $jobs ) {
                    my $hostname = $entry->{hostname};
                    my $bs       = $entry->{bs};
                    my $rw_ratio = $entry->{rw_ratio};
                    push(
                        @{
                            $series->{$bs}->{$rw_ratio}->{$hostname}
                              ->{$scenario}->{iops}->{keys}
                        },
                        $jobs,
                    );
                    push(
                        @{
                            $series->{$bs}->{$rw_ratio}->{$hostname}
                              ->{$scenario}->{iops}->{vals}
                        },
                        $entry->{json}->{jobs}->[0]->{$scenario}->{iops}
                    );
                }
            }
        }
    }

    for my $scenario (@$scenarios) {
        foreach my $bs ( keys %{$series} ) {
            foreach my $rw_ratio ( keys %{ $series->{$bs} } ) {
                my $charts = [];
                foreach my $host ( keys %{ $series->{$bs}->{$rw_ratio} } ) {
                    my $iops_serie = Chart::Clicker::Data::Series->new(
                        keys =>
                          $series->{$bs}->{$rw_ratio}->{$host}->{$scenario}
                          ->{iops}->{keys},
                        values =>
                          $series->{$bs}->{$rw_ratio}->{$host}->{$scenario}
                          ->{iops}->{vals},
                        name => $host . "_${scenario}_iops",
                    );
                    push( @$charts, $iops_serie );
                }
                write_series(
                    $charts, "rw_ratio_$rw_ratio",
                    "bs$bs", "jobs_${scenario}_iops",
                );
            }
        }
    }
}

sub write_chart_rwratio {
    my $uniq_specs = shift;
    my $results    = shift;
    my $series     = {};
    my $scenarios  = [ 'read', 'write', 'summed' ];

    ##fixed job fixed blocksize

    for my $scenario (@$scenarios) {
        for my $rw_ratio ( @{ $uniq_specs->{rw_ratios} } ) {
            for my $entry (@$results) {
                if ( $entry->{rw_ratio} == $rw_ratio ) {
                    my $hostname = $entry->{hostname};
                    my $bs       = $entry->{bs};
                    my $jobs     = $entry->{jobs};
                    push(
                        @{
                            $series->{$bs}->{$jobs}->{$hostname}->{$scenario}
                              ->{iops}->{keys}
                        },
                        $rw_ratio,
                    );
                    push(
                        @{
                            $series->{$bs}->{$jobs}->{$hostname}->{$scenario}
                              ->{iops}->{vals}
                        },
                        $entry->{json}->{jobs}->[0]->{$scenario}->{iops}
                    );
                }
            }
        }
    }

    for my $scenario (@$scenarios) {
        foreach my $bs ( keys %{$series} ) {
            foreach my $job ( keys %{ $series->{$bs} } ) {
                my $charts = [];
                foreach my $host ( keys %{ $series->{$bs}->{$job} } ) {
                    my $iops_serie = Chart::Clicker::Data::Series->new(
                        keys =>
                          $series->{$bs}->{$job}->{$host}->{$scenario}->{iops}
                          ->{keys},
                        values =>
                          $series->{$bs}->{$job}->{$host}->{$scenario}->{iops}
                          ->{vals},
                        name => $host . "_${scenario}_iops",
                    );
                    push( @$charts, $iops_serie );
                }
                write_series( $charts, "job$job", "bs$bs",
                    "rw_ratio_${scenario}_iops", );
            }
        }
    }
}

sub write_series {
    my $charts  = shift;
    my $fixed_1 = shift;
    my $fixed_2 = shift;
    my $var     = shift;
    my $cc      = Chart::Clicker->new(
        width  => 1000,
        height => 500,
        format => 'png',
    );
    $cc->title->text("fixed_${fixed_1}_fixed_${fixed_2}_var_${var}");

    $cc->border->width(0);
    $cc->background_color(
        Graphics::Color::RGB->new( red => .95, green => .94, blue => .92 ) );
    my $grey = Graphics::Color::RGB->new(
        red   => .36,
        green => .36,
        blue  => .36,
        alpha => 1
    );
    my $moregrey = Graphics::Color::RGB->new(
        red   => .71,
        green => .71,
        blue  => .71,
        alpha => 1
    );
    my $orange = Graphics::Color::RGB->new(
        red   => .88,
        green => .48,
        blue  => .09,
        alpha => 1
    );
    $cc->color_allocator->colors( [ $grey, $moregrey, $orange ] );

    $cc->plot->grid->background_color->alpha(0);
    my $ds = Chart::Clicker::Data::DataSet->new( series => [@$charts] );

    $cc->add_to_datasets($ds);

    my $defctx = $cc->get_context('default');

    $defctx->range_axis->label('iops');
    $defctx->domain_axis->label('rw ratio');

    $defctx->domain_axis->tick_label_angle(0.785398163);
    $defctx->range_axis->fudge_amount(.05);
    $defctx->domain_axis->fudge_amount(.05);
    $defctx->range_axis->label_font->family('Hoefler Text');
    $defctx->range_axis->tick_font->family('Gentium');
    $defctx->domain_axis->tick_font->family('Gentium');
    $defctx->domain_axis->label_font->family('Hoefler Text');

    # $defctx->range_axis->show_ticks(0);
    $defctx->renderer->shape(
        Geometry::Primitive::Circle->new(
            {
                radius => 5,
            }
        )
    );
    $defctx->renderer->shape_brush(
        Graphics::Primitive::Brush->new(
            width => 2,
            color => Graphics::Color::RGB->new(
                red   => .95,
                green => .94,
                blue  => .92
            )
        )
    );

    # $defctx->renderer->additive(1);
    $defctx->renderer->brush->width(2);

    $cc->legend->font->family('Hoefler Text');

    $cc->draw;
    $cc->write("images/fixed_${fixed_1}_fixed_${fixed_2}_var_${var}.png");
}
