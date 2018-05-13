use v5.10;
use strict;
use warnings;
use utf8;

use Sereal::Encoder;
use Scalar::Util qw/weaken/;
use File::Slurp qw/write_file/;
use File::Spec;
use File::Path qw/mkpath remove_tree/;
use Data::Dumper;

# setup parent dir
my @dirs = File::Spec->splitdir(__FILE__);
pop @dirs;          # remove script
pop @dirs;          # remove tools
push @dirs, 'data'; # push data directory

my $data_dir = File::Spec->catdir(@dirs);
remove_tree($data_dir) if -e $data_dir;
mkpath($data_dir,1);

# MISSING:
# SRL_HDR_FLOAT
# SRL_HDR_LONG_DOUBLE

# test data definition
my $hash = {a => 1, b => 2};
my $weak = $hash;
weaken($weak);

# name format for testcases
# <compression><version><id>_<name>
my %data = (
    '031_pos_int'      => 0,
    '032_pos_int'      => 16,
    '031_neg_int'      => -1,
    '032_neg_int'      => -16,
    '031_zig_zag'      => -17,
    '031_var_int'      => 17,
    '032_var_int'      => 1234567891011121314,
    '031_double'       => 0.1,
    '031_undef'        => undef,
    '031_short_binary' => 'random binary data',
    '031_utf8'         => 'random text with ümläuts',    #because of the umlauts it will get the utf8 flag
    '031_regexp'       => qr/foo(?!bar)/i,
    '031_arrayref'     => [0,1,2],
    '031_hashref'      => $hash,
    '031_track_flag'   => [$hash, $hash],
    '031_track_weaken' => [$hash, $weak],
    '011_track_flag'   => [$hash, $hash], # as version 1 because track flag is handled differently
);

# write test data
foreach my $name (keys %data) {
    my ($compress, $protocol_version) = $name =~ m/^(\d)(\d)\d_/;
    my $data = $data{$name};
    my $file = File::Spec->catdir(@dirs, $name);
    my $encoded = encode_sereal($data, $compress, $protocol_version);
    say "writing $file ...";
    write_file($file, $encoded);
}

sub encode_sereal {
    my $data             = shift;
    my $compress         = shift // Sereal::Encoder::SRL_UNCOMPRESSED;
    my $protocol_version = shift // 3;
    my $encoder          = Sereal::Encoder->new({
        compress         => $compress,
        protocol_version => $protocol_version,
    });
    return $encoder->encode($data);
}
