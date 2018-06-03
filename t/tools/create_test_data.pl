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

# test data definition
my $hash = {a => 1, b => 2};

# CHECKED:
# 0,1,2 - SRL_HDR_POS_HIGH
# 31 - SRL_HDR_NEG_HIGH
# 32 - SLR_HDR_VARINT
# 33 - SLR_HDR_ZIGZAG
# 35 - SLR_HDR_DOUBLE
# 37 - SLR_HDR_UNDEF
# 38 - SLR_HDR_BINARY
# 40 - SLR_HDR_REFN
# 41 - SLR_HDR_REFP
# 42 - SLR_HDR_HASH
# 43 - SLR_HDR_ARRAY
# 49 - SRL_HDR_REGEXP
# 114 - SRL_HDR_SHORT_BINARY

# MISSING:
# 34 - SRL_HDR_FLOAT
# 36 - SRL_HDR_LONG_DOUBLE
# 46 - SRL_HDR_ALIAS
# 47 - SRL_HDR_COPY
# 48 - SRL_HDR_WEAKEN - see https://github.com/Sereal/Sereal/issues/184
my $weak = $hash;
weaken($weak);
# 50 - SRL_HDR_OBJECT_FREEZE
# 51 - SRL_HDR_OBJECTV_FREEZE
# 57 - SRL_HDR_CANONICAL_UNDEF
# 58 - SRL_HDR_FALSE
# 59 - SRL_HDR_TRUE
# 63 - SRL_HDR_PAD
# SRL_HDR_ARRAYREF
# SRL_HDR_HASHREF


# name format for testcases
# <compression><version><id>_<name>
my %data = (
    '031_pos_int'         => 0,
    '032_pos_int'         => 16,
    '031_neg_int'         => -1,
    '032_neg_int'         => -16,
    '031_zig_zag'         => -17,
    '031_var_int'         => 17,
    '032_var_int'         => 1234567891011121314,
    '031_double'          => 0.1,
    '031_undef'           => undef,  # undef stored in a variable is no pl_sv_undef
    '031_short_binary'    => 'random binary data',
    '031_utf8'            => 'random text with ümläuts',    #because of the umlauts it will get the utf8 flag
    '031_regexp'          => qr/foo(?!bar)/i,
    '031_arrayref'        => [0,1,2],
    '031_hashref'         => $hash,
    '031_track_flag'      => [$hash, $hash],
    '011_track_flag'      => [$hash, $hash], # as version 1 because track flag is handled differently
    '031_track_weaken'    => [$hash, $weak],
    '031_canonical_undef' => 'this will not be used - special handling',
);

# write test data
foreach my $name (keys %data) {
    my ($compress, $protocol_version) = $name =~ m/^(\d)(\d)\d_/;
    my $data = $data{$name};
    my $file = File::Spec->catdir(@dirs, $name);

    my $encoded;
    # special case handling
    if ($name eq '031_canonical_undef') {
        $encoded = encode_canonical_undef();
    } else {
        $encoded = encode_sereal($data, $compress, $protocol_version);
    }

    say "writing $file with version $protocol_version ...";
    write_file($file, $encoded);
}

sub encode_canonical_undef {
    my $encoder = Sereal::Encoder->new({
        compress => Sereal::Encoder::SRL_UNCOMPRESSED,
        procotol_version => 3,
    });
    return $encoder->encode(undef);
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
