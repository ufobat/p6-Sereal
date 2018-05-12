use v6.c;
use Test;
use Sereal;

my $data-dir = $?FILE.IO.parent.child('data');

$Sereal::DEBUG = True;

ok $data-dir.e, 'data-dir exists';

for $data-dir.dir -> $sereal-file {
    diag $sereal-file;
    my $data = decode_file($sereal-file);
    say $data.perl;
}

done-testing;
