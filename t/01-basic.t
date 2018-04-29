use v6.c;
use Test;
use Sereal;

lives-ok {
    my $data = decode_file('sereal.example');
    diag $data.perl;
}

done-testing;
