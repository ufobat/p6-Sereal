unit class Sereal::Decoder;

use Sereal::Header;

has Blob $!data;
has Int $!position;
has Int $!size;

# TODO: just a blob of bytes
method decode(Blob[uint8] $blob) {
    self!set-data($blob);
    self!parse-header();
}

method !set-data($blob) {
    $!data = $blob;
    $!size = $blob.elems;
    $!position = 0;
}

method !parse-header() {
    self!check-header();
}

method !check-header() {
    if $!size - $!position < 4 {
        die 'Invalid Sereal header: too few bytes';
    }

    my $magic = $!data[ $!position + 0 ] +< 24 +
                $!data[ $!position + 1 ] +< 16 +
                $!data[ $!position + 2 ] +<  8 +
                $!data[ $!position + 3 ] +<  0;
    $!position += 4;

    if $magic != MAGIC && $magic != MAGIC_V3 {
        die "Invalid Seareal header: $magic doesn't match magic"
    }
}
