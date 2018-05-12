use v5.10;
use strict;
use warnings;
use utf8;

use Sereal::Encoder 'encode_sereal';
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
my %data = (
    '001_pos_int'      => 0,
    '002_pos_int'      => 16,
    '001_neg_int'      => -1,
    '002_neg_int'      => -16,
    '001_zig_zag'      => -17,
    '001_var_int'      => 17,
    '002_var_int'      => 1234567891011121314,
    '001_double'       => 0.1,
    '001_undef'        => undef,
    '001_short_binary' => 'random binary data',
    '001_utf8'         => 'random text with ümläuts',    #because of the umlauts it will get the utf8 flag
);

# write test data
foreach my $name (keys %data) {
    my $data = $data{$name};
    my $file = File::Spec->catdir(@dirs, $name);
    my $encoded = encode_sereal($data);
    say "writing $file ...";
    write_file($file, $encoded);
}
