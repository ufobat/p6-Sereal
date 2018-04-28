use v6.c;
use Test;
use Sereal;

lives-ok {
    decode_file('sereal.example')
}

done-testing;
