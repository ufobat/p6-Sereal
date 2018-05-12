use v6.c;
use Test;
use Sereal;

my $data-dir = $?FILE.IO.parent.child('data');

# $Sereal::DEBUG = True;

ok $data-dir.e, 'data-dir exists';

my %expectations = (
    '001_pos_int'      => 0,
    '002_pos_int'      => 16,
    '001_neg_int'      => -1,
    '002_neg_int'      => -16,
    '001_zig_zag'      => -17,
    '001_var_int'      => 17,
    '002_var_int'      => 1234567891011121314,
    '001_double'       => 0.1.Num, # sereal encodes floating point numbers, no Rats
    '001_undef'        => Nil,
    '001_short_binary' => Buf[uint8].new( 'random binary data'.encode('latin-1')),
    '001_utf8'         => 'random text with ümläuts', # because of the umlauts it will get the utf8
);

for $data-dir.dir -> $sereal-file {
    my $name = $sereal-file.basename;
    my $data = decode_file($sereal-file);
    if %expectations{$name}:exists {
        is-deeply(
            $data,
            %expectations{$name},
            "testing $sereal-file"
        );
    } else {
        todo "missing test for $name";
        flunk $data.perl;
    }
}

done-testing;
