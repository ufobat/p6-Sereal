use v6.c;
use Test;
use Sereal;

my $data-dir = $?FILE.IO.parent.child('data');

# $Sereal::DEBUG = True;

ok $data-dir.e, 'data-dir exists';

my %hash = (
    a => 1,
    b => 2,
);
my @expectations = (
    '031_pos_int'      => 0,
    '032_pos_int'      => 16,
    '031_neg_int'      => -1,
    '032_neg_int'      => -16,
    '031_zig_zag'      => -17,
    '031_var_int'      => 17,
    '032_var_int'      => 1234567891011121314,
    '031_double'       => 0.1.Num, # sereal encodes floating point numbers, no Rats
    '031_undef'        => Nil,
    '031_short_binary' => Buf[uint8].new( 'random binary data'.encode('latin-1')),
    '031_utf8'         => 'random text with ümläuts', # because of the umlauts it will get the utf8
    '031_arrayref'     => [0,1,2],
    '031_hashref'      => %hash,
    '031_track_flag'   => [%hash, %hash],
    '011_track_flag'   => [%hash, %hash], # as version 1 because track flag is handled differently
);

for @expectations {
    my $name = .key;
    my $expected = .value;
    my $file = $data-dir.child($name);
    if $file.e {
        my $data = decode_file($file);
        is-deeply(
            $data,
            $expected,
            "testing $file"
        );
    } else {
        todo "missing test for $name";
        flunk $name;
    }
}

done-testing;
